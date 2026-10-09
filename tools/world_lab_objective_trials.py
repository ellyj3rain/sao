#!/usr/bin/env python3
"""Source-bound objective research, separate from native control and model training.

Sources are retained native run/body/events and immutable archive manifests.
An outcome is an interpretation of those observations, with an explicit author;
human review determines whether its evidence can become a learning candidate.
The CLI accepts the same JSON objects as the callable API. It never controls a
body, changes a save, supplies pixels, or starts training.
"""
from __future__ import annotations

import argparse
from collections import OrderedDict
from contextlib import contextmanager
import errno
import hashlib
import json
import math
import os
from pathlib import Path, PurePosixPath
import re
import stat
import sys
import threading
import time
import uuid

import world_lab_participant_feed as Participant
import world_lab_participant_session as ParticipantSession
import world_lab_video_archive as Video
import world_lab_native_play as NativePlay

SOURCE_SCHEMA = "sao.objective-source/1"
TRIAL_SCHEMA = "sao.objective-trial/1"
CANDIDATE_SCHEMA = "sao.objective-candidate/1"
MAX_JSON = Participant.MAX_RUN_JSON
MAX_TRIAL_JSON = 4 * 1024 * 1024
MAX_OBSERVATIONS = 4096
KINDS = {"context", "attempt", "cost", "outcome", "return", "review", "end"}
TERMINAL = {"completed", "failed", "incomplete", "exited", "timed-out"}
SHA = re.compile(r"[0-9a-f]{64}\Z")
_SOURCE_CACHE = OrderedDict()
_CUSTODY_CACHE = OrderedDict()
_CACHE_LOCK = threading.RLock()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def _text(value, limit=2048, *, multiline=False):
    require(isinstance(value, str) and 0 < len(value) <= limit
            and not any((ord(c) < 32 and not (multiline and c in "\n\r\t")) or ord(c) == 127
                        for c in value), "invalid objective text")
    return value


def _number(value, *, integer=False):
    require(type(value) in ((int,) if integer else (int, float))
            and math.isfinite(value) and 0 <= value <= 2**53-1, "invalid objective clock")
    return value


def _hash(value):
    require(isinstance(value, str) and SHA.fullmatch(value), "invalid source hash")
    return value


def encoded(value):
    return Participant.encoded(value)


def _digest(value):
    return hashlib.sha256(encoded(value)).hexdigest()


def _regular(path):
    info = path.lstat()
    require(stat.S_ISREG(info.st_mode) and not path.is_symlink()
            and not getattr(info, "st_file_attributes", 0) & 0x400, "unsafe source file")
    return (info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_ctime_ns)


def _safe_path(root, relative):
    require(isinstance(relative, str) and relative and "\\" not in relative
            and ":" not in relative, "invalid source relative path")
    parts = PurePosixPath(relative).parts
    require(not PurePosixPath(relative).is_absolute() and all(p not in (".", "..") for p in parts)
            and "/".join(parts) == relative, "unsafe source relative path")
    path = root
    for part in parts:
        path = path / part
        if path.exists() or path.is_symlink():
            info = path.lstat()
            require(not path.is_symlink() and not getattr(info, "st_file_attributes", 0) & 0x400,
                    "source path is a link")
    require(path.resolve().is_relative_to(root), "source escapes its session")
    return path


def _source_root(value):
    root = Path(_text(value, 4096))
    require(root.is_absolute() and root.is_dir() and not root.is_symlink(), "invalid source session root")
    return root.resolve()


def _bytes(path, maximum=MAX_JSON):
    before = _regular(path)
    require(before[2] <= maximum, "oversized JSON source")
    with path.open("rb") as file:
        raw = file.read(maximum+1)
    require(len(raw) <= maximum and _regular(path) == before, "source changed during read")
    return raw


def _json(raw):
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, "duplicate source JSON field")
            result[key] = value
        return result
    try:
        return json.loads(raw, object_pairs_hook=pairs,
                          parse_constant=lambda _: (_ for _ in ()).throw(ValueError("nonfinite JSON source")))
    except (UnicodeError, RecursionError) as error:
        raise ValueError("invalid JSON source encoding or depth") from error


def source_reference(session_root, relative, *, line=None):
    """Pin a retained source file; JSONL references use a one-based record line."""
    root = _source_root(str(session_root))
    raw = _bytes(_safe_path(root, relative))
    result = {"file": relative, "sha256": hashlib.sha256(raw).hexdigest()}
    if line is not None:
        _number(line, integer=True)
        require(line > 0, "invalid event line")
        result["line"] = line
    return result


def _read_ref(root, ref):
    require(isinstance(ref, dict) and {"file", "sha256"} <= set(ref)
            <= {"file", "sha256", "line"}, "invalid source reference")
    path = _safe_path(root, ref["file"])
    expected = _hash(ref["sha256"])
    before = Participant.source_version(path, MAX_JSON)
    key = (str(path), expected, ref.get("line"))
    with _CACHE_LOCK:
        cached = _SOURCE_CACHE.get(key)
        if cached and cached[0] == before and Participant.source_version(path, MAX_JSON) == before:
            _SOURCE_CACHE.move_to_end(key)
            return cached[1]
    raw = _bytes(path)
    require(Participant.source_version(path, MAX_JSON) == before, "source changed during read")
    require(hashlib.sha256(raw).hexdigest() == expected, "stale or altered source")
    source_bytes = len(raw)
    if "line" in ref:
        _number(ref["line"], integer=True)
        rows = raw.splitlines()
        require(0 < ref["line"] <= len(rows), "missing source event line")
        raw = rows[ref["line"]-1]
    value = _json(raw)
    require(isinstance(value, dict), "source record must be an object")
    with _CACHE_LOCK:
        # Reuse the existing bounded source/version contract. Cache serialized
        # source sizes within the same maximum JSON input allowance.
        _SOURCE_CACHE[key] = (before, value, source_bytes)
        while sum(row[2] for row in _SOURCE_CACHE.values()) > MAX_JSON:
            _SOURCE_CACHE.popitem(last=False)
    return value


def _clear_source_cache(root):
    # Candidate admission starts with fresh original source hashes. Subsequent
    # reads in that validation can reuse version-qualified decoded snapshots.
    with _CACHE_LOCK:
        for key in list(_SOURCE_CACHE):
            if Path(key[0]).is_relative_to(root):
                del _SOURCE_CACHE[key]
        for key in list(_CUSTODY_CACHE):
            if Path(key[0]).is_relative_to(root):
                del _CUSTODY_CACHE[key]


def _body_identity(body, run):
    Participant.validate_body(body, run)
    require(body["ready"], "source body is not bound")
    return {"sessionId": body["sessionId"], "attempt": body["attempt"], "pid": body["pid"],
            "save": body["save"], "saveMode": body.get("saveMode"),
            "playerIndex": body["playerIndex"], "playerSqlId": body["playerSqlId"]}




def _qualified_native_log(root, relative, expected, marker=None):
    path = _safe_path(root, relative)
    before = _regular(path)
    digest = hashlib.sha256()
    tail = b""
    found = marker is None
    with path.open("rb") as file:
        while chunk := file.read(1024 * 1024):
            digest.update(chunk)
            if marker is not None:
                found = found or marker in tail + chunk
                tail = (tail + chunk)[-len(marker)+1:]
    return _regular(path) == before and digest.hexdigest() == _hash(expected) and found



def _native_chain_contains(root, run, cache_key, accept):
    """Check a stable native-started to native-ended event chain."""
    try:
        path = _safe_path(root, "events.jsonl")
        before = _regular(path)
        key = (str(path), before, *cache_key)
        with _CACHE_LOCK:
            cached = _CUSTODY_CACHE.get(key)
            if cached is not None and _regular(path) == before:
                _CUSTODY_CACHE.move_to_end(key)
                return cached
        started = ended = matched = False
        with path.open("rb") as file:
            while True:
                raw = file.readline(128 * 1024 + 1)
                if not raw:
                    break
                if len(raw) > 128 * 1024 or not raw.endswith(b"\n"):
                    return False
                event = _json(raw)
                if (not isinstance(event, dict)
                        or event.get("schema") != "sao.native-play-event/1"
                        or event.get("sessionId") != run["sessionId"]):
                    return False
                kind = event.get("kind")
                if kind == "native-started":
                    if (started or ended or type(event.get("pid")) is not int
                            or event["pid"] != run["pid"] or event.get("nativeMenu") is not True):
                        return False
                    started = True
                elif kind == "native-ended":
                    if (not started or ended or type(event.get("exitCode")) is not int
                            or event["exitCode"] != 0 or event.get("nativeSaveReturned") is not True
                            or event.get("recordingComplete") is not True):
                        return False
                    ended = True
                elif started and not ended:
                    current = accept(event, raw)
                    matched = matched or current
        if _regular(path) != before:
            return False
        result = started and ended and matched
        with _CACHE_LOCK:
            _CUSTODY_CACHE[key] = result
            while len(_CUSTODY_CACHE) > 256:
                _CUSTODY_CACHE.popitem(last=False)
        return result
    except (OSError, ValueError, KeyError, TypeError, AttributeError):
        return False


def _native_body_custody(root, run, body_ref, body):
    """Find this exact retained sample in the native producer's event chain."""
    if body_ref.get("file") != "body-samples/" + body_ref.get("sha256", "") + ".json":
        return False
    def accept(event, raw):
        kind = event.get("kind")
        if kind not in ("native-body-sample", "native-player-interval-started",
                        "native-objective-review", "native-objective-review-omitted"):
            return False
        same = (event.get("sampleSha256") == body_ref["sha256"]
                and type(event.get("sourceObservedAtUnixMs")) is int
                and event["sourceObservedAtUnixMs"] == body["capturedAtUnixMs"]
                and all(type(event.get(key)) is type(body[key]) and event[key] == body[key]
                        for key in ("saveMode", "save", "playerIndex", "playerSqlId")))
        if not same:
            return False
        if kind == "native-body-sample":
            return (type(event.get("pid")) is int and event["pid"] == run["pid"]
                    and type(event.get("attempt")) is int
                    and event["attempt"] == run["launchNumber"])
        if kind == "native-player-interval-started":
            return (type(event.get("interval")) is int and event["interval"] > 0
                    and event.get("label") == body["body"]["label"])
        source_hash = event.get("objectiveSourceSha256")
        _hash(source_hash)
        if (type(event.get("pid")) is not int or event["pid"] != run["pid"]
                or type(event.get("attempt")) is not int
                or event["attempt"] != run["launchNumber"]
                or event.get("objectiveSourceFile") !=
                "objective-reviews/" + source_hash + ".json"):
            return False
        review = _read_ref(root, {"file": event["objectiveSourceFile"],
                                  "sha256": source_hash})
        return NativePlay.validate_objective_review_source(review, run) == body
    return _native_chain_contains(root, run,
        ("body", body_ref["sha256"], run["pid"], run["launchNumber"],
         body["capturedAtUnixMs"], body["saveMode"], body["save"],
         body["playerIndex"], body["playerSqlId"]), accept)


def _native_review_event_custody(root, run, source_ref, event):
    """A detached review is admissible only if its exact bytes were logged."""
    relative = source_ref.get("file")
    digest = source_ref.get("sha256")
    if relative != "events.jsonl":
        if relative != "objective-reviews/events/" + str(digest) + ".json":
            return False
        try:
            raw = _bytes(_safe_path(root, relative))
        except (OSError, ValueError, TypeError):
            return False
        if hashlib.sha256(raw).hexdigest() != digest or raw != encoded(event):
            return False
    event_raw = encoded(event)
    return _native_chain_contains(root, run,
        ("review-event", hashlib.sha256(event_raw).hexdigest(), run["pid"], run["launchNumber"]),
        lambda row, raw: row.get("kind") == "native-objective-review" and raw == event_raw)


def _qualified_native_origin(root, run_ref, body_ref, archive):
    """Require the producer's launch, complete recording, and finality receipts."""
    try:
        if (run_ref.get("file") != "participant-run/run.json"
                or body_ref.get("file") != "body-samples/" + body_ref.get("sha256", "") + ".json"):
            return False
        run = _read_ref(root, run_ref)
        body = _read_ref(root, body_ref)
        if not _native_body_custody(root, run, body_ref, body):
            return False
        if (run.get("sourceSchema") != NativePlay.RUN_SCHEMA
                or run.get("launchMode") != "native-menu"
                or run.get("evidenceScope") != "native-player-recording"
                or run.get("authoredStudy") is not False
                or run.get("status") != "completed"
                or run.get("terminal") != "native-exit"
                or type(run.get("exitCode")) is not int or run["exitCode"] != 0
                or run.get("nativeSaveReturned") is not True
                or run.get("recordingError") is not None):
            return False
        logs = run.get("logs")
        if (not isinstance(logs, dict) or set(logs) != {"stdout.log", "stderr.log"}
                or not _qualified_native_log(root, "participant-run/attempts/0001/stdout.log",
                                             logs["stdout.log"],
                                             b"[StudyLaunch] native-save-returned attempt=1")
                or not _qualified_native_log(root, "participant-run/attempts/0001/stderr.log",
                                             logs["stderr.log"])):
            return False
        launch = _json(_bytes(_safe_path(root, "launch.json")))
        if (run.get("launcher") != launch or launch.get("schema") != "sao.native-play-launch/1"
                or launch.get("sessionId") != run["sessionId"] or launch.get("mode") != "native-menu"
                or launch.get("saveSelection") != "native-LoadGameScreen"
                or launch.get("nativeModsOverride") is not False
                or launch.get("nativeSoundDisabled") is not False
                or not isinstance(launch.get("command"), list)
                or f"-Dstudy.participantSession={run['sessionId']}" not in launch["command"]
                or "-Dstudy.nativePlay=true" not in launch["command"]
                or "-Dstudy.attempt=1" not in launch["command"]):
            return False
        pins = launch.get("sourcePins")
        if not isinstance(pins, dict) or not pins:
            return False
        for digest in (*pins.values(), *(launch.get(key) for key in
                         ("engineSha256", "adapterSha256", "launcherSha256"))):
            _hash(digest)
        if (archive.get("status") != "stopped" or archive.get("error") is not None
                or archive.get("priorFailureCount") != 0
                or not isinstance(archive.get("attempts"), list) or len(archive["attempts"]) != 1):
            return False
        attempt = archive["attempts"][0]
        provenance = attempt.get("nativeProvenance") or {}
        if (type(attempt.get("attempt")) is not int or attempt["attempt"] != 1
                or attempt.get("video") != "observed"
                or any(provenance.get(key) != run.get(key) for key in
                       ("sessionId", "launchNumber", "packageSha256", "definitionSha256", "status", "terminal"))):
            return False
        completion_raw = _bytes(_safe_path(root, "recording-completion.json"))
        completion = _json(completion_raw)
        if (completion.get("schema") != "sao.native-play-recording-completion/1"
                or completion.get("sessionId") != run["sessionId"]
                or completion.get("complete") is not True
                or completion.get("nativeSaveReturned") is not True
                or completion.get("archiveError") is not None):
            return False
        feed = _safe_path(root, "feeds/0001")
        view = _json(_bytes(_safe_path(root, "feeds/0001/latest.json")))
        pointer = view.get("archiveFinality")
        if (not isinstance(pointer, dict) or set(pointer) != {"file", "sha256"}
                or pointer["file"] != "archive-finality.json"):
            return False
        finality = _read_ref(root, {"file": "feeds/0001/archive-finality.json",
                                   "sha256": pointer["sha256"]})
        if (finality.get("schema") != "sao.native-play-archive-finality/1"
                or finality.get("sessionId") != run["sessionId"]
                or finality.get("recordingId") != run["sessionId"]
                or type(finality.get("attempt")) is not int or finality["attempt"] != 1
                or finality.get("finalStreamId") != (view.get("video") or {}).get("streamId")
                or finality.get("recordingComplete") is not True
                or (finality.get("qualification") or {}).get("complete") is not True
                or finality.get("catalog") != view.get("archiveCatalog")):
            return False
        run_final = finality.get("runReceipt") or {}
        completion_final = finality.get("completionReceipt") or {}
        completion_sha = hashlib.sha256(completion_raw).hexdigest()
        if (run_final != {"file": "archive-run-final-" + run_ref["sha256"] + ".json",
                          "sha256": run_ref["sha256"], "status": "completed"}
                or completion_final != {"file": "archive-completion-final-" + completion_sha + ".json",
                                        "sha256": completion_sha}
                or _read_ref(root, {"file": "feeds/0001/" + run_final["file"],
                                    "sha256": run_final["sha256"]}) != run
                or _read_ref(root, {"file": "feeds/0001/" + completion_final["file"],
                                    "sha256": completion_final["sha256"]}) != completion):
            return False
        projected = finality.get("projectionRunReceiptSha256")
        _hash(projected)
        projected_receipt = _read_ref(root, {"file": "video-archive/0001/provenance/" + projected + ".json",
                                             "sha256": projected})
        if (projected_receipt.get("status") != "completed"
                or projected_receipt.get("terminal") != "native-exit"
                or any(projected_receipt.get(key) != run.get(key) for key in
                       ("sessionId", "launchNumber", "packageSha256", "definitionSha256"))):
            return False
        catalog_pointer, catalog = Video.recording_catalog(root, feed, view)
        if (catalog_pointer != finality["catalog"]
                or (catalog.get("aggregateCoverage") or {}).get("complete") is not True
                or completion.get("recording") !=
                ParticipantSession.require_recording(feed, archive["studyId"], run["sessionId"])):
            return False
        return True
    except (OSError, ValueError, KeyError, TypeError, AttributeError):
        return False

def build_source_manifest(session_root, body_file, *, run_file="participant-run/run.json",
                          evidence_origin=None):
    """Prepare a descriptor from retained files and qualify its evidence origin."""
    root = _source_root(str(session_root))
    run_ref, body_ref = source_reference(root, run_file), source_reference(root, body_file)
    run = _read_ref(root, run_ref)
    Participant.validate_receipt(run)
    body = _read_ref(root, body_ref)
    _body_identity(body, run)
    archive = _json(_bytes(_safe_path(root, "video-archive/archive.json")))
    require(archive.get("schema") == Video.SCHEMA and Path(archive.get("source", "")).resolve() == root,
            "archive source session differs")
    study = Participant.canonical_uuid(archive.get("studyId"))
    require(evidence_origin in (None, "actual-native", "synthetic-control", "unverified"),
            "unknown evidence origin")
    qualified = _qualified_native_origin(root, run_ref, body_ref, archive)
    require(evidence_origin != "actual-native" or qualified,
            "actual-native origin requires qualified native launch and recording provenance")
    origin = evidence_origin or ("actual-native" if qualified else "unverified")
    descriptor = {"schema": SOURCE_SCHEMA, "sessionRoot": str(root), "studyId": study,
                  "sessionId": run["sessionId"], "attempt": run["launchNumber"],
                  "runReceipt": run_ref, "bodySource": body_ref, "evidenceOrigin": origin,
                  "producerPins": {k: run[k] for k in ("packageSha256", "definitionSha256",
                                   "engineJarSha256", "loadingAgentSha256", "launchSha256")
                                   if run.get(k) is not None}}
    _source(descriptor)
    return descriptor


def _source(source):
    require(isinstance(source, dict) and set(source) == {"schema", "sessionRoot", "studyId", "sessionId",
            "attempt", "runReceipt", "bodySource", "evidenceOrigin", "producerPins"}
            and source["schema"] == SOURCE_SCHEMA, "objective source schema differs")
    require(source["evidenceOrigin"] in ("actual-native", "synthetic-control", "unverified"), "unknown evidence origin")
    root = _source_root(source["sessionRoot"])
    Participant.canonical_uuid(source["studyId"])
    archive = _json(_bytes(_safe_path(root, "video-archive/archive.json")))
    require(isinstance(archive, dict) and archive.get("schema") == Video.SCHEMA
            and archive.get("studyId") == source["studyId"]
            and Path(archive.get("source", "")).resolve() == root, "archive owner differs")
    run = _read_ref(root, source["runReceipt"])
    Participant.validate_receipt(run, source["sessionId"])
    require(type(source["attempt"]) is int and source["attempt"] == run["launchNumber"], "source attempt differs")
    require(isinstance(source["producerPins"], dict), "source pins differ")
    expected = {k: run[k] for k in ("packageSha256", "definitionSha256", "engineJarSha256",
                                   "loadingAgentSha256", "launchSha256") if run.get(k) is not None}
    require(source["producerPins"] == expected, "producer source pins differ")
    for value in expected.values():
        _hash(value)
    body = _read_ref(root, source["bodySource"])
    identity = _body_identity(body, run)
    require(source["evidenceOrigin"] != "actual-native"
            or _qualified_native_origin(root, source["runReceipt"], source["bodySource"], archive),
            "actual-native source lacks qualified native launch and recording provenance")
    return root, run, body, identity


def _actor(binding, identity):
    require(isinstance(binding, dict) and set(binding) == set(identity) | {"actorId", "controllerId", "origin"},
            "actor binding fields differ")
    require(all(binding[k] == v and type(binding[k]) is type(v) for k, v in identity.items()),
            "actor native identity differs")
    _text(binding["actorId"], 160)
    _text(binding["origin"], 2048, multiline=True)
    if binding["controllerId"] is not None:
        _text(binding["controllerId"], 160)
    return binding


def actor_binding(source_manifest, actor_id, controller_id, origin):
    """Native identity plus declared controller/origin; no appearance is inferred."""
    _, _, _, identity = _source(source_manifest)
    return _actor({**identity, "actorId": actor_id, "controllerId": controller_id, "origin": origin}, identity)


def _objective(objective):
    require(isinstance(objective, dict) and set(objective) == {"instruction", "successCriteria", "returnCriteria",
            "assignedBy", "assignedAtUnixMs", "mode"}, "objective fields differ")
    for field in ("instruction", "successCriteria", "returnCriteria"):
        _text(objective[field], multiline=True)
    _text(objective["assignedBy"], 160)
    _number(objective["assignedAtUnixMs"], integer=True)
    require(objective["mode"] in ("prospective", "retrospective"), "objective mode differs")
    return objective


def _outside_source(path, root):
    path = Path(path).absolute()
    require(not path.resolve().is_relative_to(root), "research writes would alter retained source")
    for item in (path, *path.parents):
        if item.exists():
            info = item.lstat()
            require(not item.is_symlink() and not getattr(info, "st_file_attributes", 0) & 0x400,
                    "research destination is a link")
    return path


@contextmanager
def _lock(path):
    path.parent.mkdir(parents=True, exist_ok=True)
    require(not path.is_symlink(), "unsafe trial lock")
    with path.open("a+b") as file:
        if file.seek(0, os.SEEK_END) == 0:
            file.write(b"0"); file.flush()
        deadline = time.monotonic()+3
        while True:
            file.seek(0)
            try:
                if os.name == "nt":
                    import msvcrt
                    msvcrt.locking(file.fileno(), msvcrt.LK_NBLCK, 1)
                else:
                    import fcntl
                    fcntl.flock(file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except OSError as error:
                if error.errno not in (errno.EACCES, errno.EAGAIN, errno.EDEADLK) or time.monotonic() >= deadline:
                    raise
                time.sleep(.01)
        try:
            yield
        finally:
            file.seek(0)
            if os.name == "nt":
                import msvcrt
                msvcrt.locking(file.fileno(), msvcrt.LK_UNLCK, 1)
            else:
                import fcntl
                fcntl.flock(file.fileno(), fcntl.LOCK_UN)


def _atomic(path, raw):
    require(len(raw) <= MAX_TRIAL_JSON, "trial JSON storage limit reached")
    path.parent.mkdir(parents=True, exist_ok=True)
    require(not path.is_symlink(), "unsafe trial destination")
    pending = path.parent / (path.name+"."+uuid.uuid4().hex+".tmp")
    try:
        with pending.open("xb") as file:
            file.write(raw); file.flush(); os.fsync(file.fileno())
        os.replace(pending, path)
    finally:
        pending.unlink(missing_ok=True)


def _commit(path, trial):
    trial["integritySha256"] = _digest({k: v for k, v in trial.items() if k != "integritySha256"})
    _atomic(path, encoded(trial))
    return trial


def read_trial(trial):
    path = Path(trial)
    if path.is_dir():
        path = path / "trial.json"
    value = _json(_bytes(path, MAX_TRIAL_JSON))
    require(isinstance(value, dict) and value.get("schema") == TRIAL_SCHEMA, "trial schema differs")
    require(value.get("integritySha256") == _digest({k: v for k, v in value.items() if k != "integritySha256"}),
            "trial state was altered")
    return value


def _trial_path(trial):
    path = Path(trial)
    return path / "trial.json" if path.is_dir() else path


def _write_trial_path(trial):
    # Check custody before even creating the advisory lock file.
    path = _trial_path(trial)
    value = read_trial(path)
    return _outside_source(path, _source_root(value["source"]["sessionRoot"]))


def create_trial(source_manifest, actor_binding, objective, destination):
    root, _, body, identity = _source(source_manifest)
    _actor(actor_binding, identity); _objective(objective)
    destination = _outside_source(destination, root)
    destination.mkdir(parents=True, exist_ok=True)
    path = destination / "trial.json"
    with _lock(destination / "trial.lock"):
        if path.exists():
            old = read_trial(path)
            require((old["source"], old["actor"], old["objective"]) == (source_manifest, actor_binding, objective),
                    "trial destination belongs to another objective")
            return old
        basis = {"source": source_manifest, "actor": actor_binding, "objective": objective}
        trial = {"schema": TRIAL_SCHEMA, "trialId": str(uuid.uuid5(uuid.NAMESPACE_URL, _digest(basis))),
                 **basis, "revision": 0, "status": "collecting", "observations": [],
                 "completion": None, "evaluation": None, "trainingStatus": "not-run",
                 "uncertainties": ["Source and video clocks are independent; association does not prove actor visibility."]}
        if identity["saveMode"] is None:
            trial["uncertainties"].append("Legacy source does not record the native save namespace.")
        if source_manifest["evidenceOrigin"] == "unverified":
            trial["uncertainties"].append("Native launch and recording origin are unverified.")
        return _commit(path, trial)


def replay_reference(session_root, manifest_file, sequence):
    root = _source_root(str(session_root))
    manifest = source_reference(root, manifest_file)
    report_file = str(PurePosixPath(manifest_file).parent.parent / "stream.json")
    return {"manifest": manifest, "streamReport": source_reference(root, report_file), "sequence": sequence}


def _media_hash(path, expected):
    before = _regular(path)
    require(before[2] > 0, "empty replay artifact")
    digest = hashlib.sha256()
    with path.open("rb") as file:
        while chunk := file.read(1024 * 1024):
            digest.update(chunk)
    require(_regular(path) == before and digest.hexdigest() == _hash(expected), "missing or altered replay artifact")


def _replay(source, replay, clock):
    require(isinstance(replay, dict) and set(replay) == {"manifest", "streamReport", "sequence"},
            "replay reference fields differ")
    root = _source_root(source["sessionRoot"])
    manifest = _read_ref(root, replay["manifest"])
    stream = Video.validate_manifest(manifest)
    _number(replay["sequence"], integer=True)
    require(replay["sequence"] > 0, "invalid replay segment sequence")
    directory = f"video-archive/{source['attempt']:04d}/{stream}"
    require(replay["manifest"]["file"] == directory+"/manifests/"+replay["manifest"]["sha256"]+".json"
            and replay["streamReport"]["file"] == directory+"/stream.json", "foreign replay path")
    report = _read_ref(root, replay["streamReport"])
    require(report.get("schema") == Video.SCHEMA and report.get("studyId") == source["studyId"]
            and report.get("attempt") == source["attempt"] and report.get("streamId") == stream,
            "foreign replay study or attempt")
    native = report.get("nativeProvenance") or {}
    require(native.get("sessionId") == source["sessionId"] and native.get("launchNumber") == source["attempt"]
            and all(native.get(k) == source["producerPins"].get(k) for k in ("packageSha256", "definitionSha256")),
            "foreign replay native source")
    rows = [r for r in manifest["segments"] if r["sequence"] == replay["sequence"]]
    require(len(rows) == 1, "replay segment absent from pinned manifest")
    row = rows[0]
    require(row["capturedAtUnixMs"] <= clock["capturedAtUnixMs"] <= row["endCapturedAtUnixMs"]
            and row["worldHours"] <= clock["worldHours"] <= row["endWorldHours"], "source observation falls outside replay clocks")
    for media in (manifest["init"], row):
        _media_hash(_safe_path(root, directory+"/"+media["file"]), media["sha256"])
    return {"reference": replay, "streamId": stream, "segment": row, "init": manifest["init"],
            "coverage": report.get("coverage"), "association": "independent source clocks; actor visibility unverified"}


def _pointer(value, pointer):
    require(isinstance(pointer, str) and (pointer == "" or pointer.startswith("/")) and len(pointer) <= 1024,
            "invalid measurement pointer")
    if pointer:
        for part in pointer[1:].split("/"):
            require(not re.search(r"~(?![01])", part), "invalid measurement pointer escape")
            key = part.replace("~1", "/").replace("~0", "~")
            if isinstance(value, dict):
                require(key in value, "measurement field unavailable")
                value = value[key]
            elif isinstance(value, list):
                require(re.fullmatch(r"0|[1-9][0-9]*", key) and int(key) < len(value), "measurement index unavailable")
                value = value[int(key)]
            else:
                raise ValueError("measurement path unavailable")
    require(value is None or type(value) in (bool, int, float, str), "measurement must be a scalar source value")
    if type(value) in (int, float):
        require(math.isfinite(value), "nonfinite measurement")
    if isinstance(value, str):
        require(len(value) <= 2048, "oversized measurement")
    return value


def _observation(trial, observation):
    require(isinstance(observation, dict) and set(observation) == {"id", "kind", "source", "bodySource",
            "replay", "annotation", "measurements"}, "observation fields differ")
    _text(observation["id"], 100)
    require(observation["kind"] in KINDS, "unknown objective observation kind")
    require(isinstance(observation["annotation"], str) and len(observation["annotation"]) <= 2048,
            "invalid observation annotation")
    root, run, binding_body, identity = _source(trial["source"])
    _actor(trial["actor"], identity)
    event = _read_ref(root, observation["source"])
    body = _read_ref(root, observation["bodySource"])
    require(_body_identity(body, run) == identity, "observation actor changed")
    require(trial["source"]["evidenceOrigin"] != "actual-native"
            or _native_body_custody(root, run, observation["bodySource"], body),
            "actual-native observation lacks recorded body custody")
    schema = event.get("schema")
    review_source_ref = None
    review_clock = None
    if schema == "sao-native-participant/1":
        require(observation["kind"] != "review", "review requires native source receipt")
        require(event == body, "body event differs from its binding")
    elif schema == "sao.native-play-event/1":
        require(event.get("sessionId") == identity["sessionId"], "event native session differs")
        if "pid" in event:
            require(type(event["pid"]) is int and event["pid"] == identity["pid"], "event native pid differs")
        for field in ("save", "saveMode", "playerIndex", "playerSqlId", "attempt"):
            if field in event:
                require(type(event[field]) is type(identity[field]) and event[field] == identity[field],
                        "event native body identity differs")
        if "identity" in event:
            expected_identity = [identity[k] for k in ("saveMode", "save", "playerIndex", "playerSqlId")]
            require(isinstance(event["identity"], list) and len(event["identity"]) == len(expected_identity)
                    and all(type(a) is type(b) and a == b for a, b in zip(event["identity"], expected_identity)),
                    "event native body interval differs")
        if "sampleSha256" in event:
            require(event["sampleSha256"] == observation["bodySource"]["sha256"], "event body sample differs")
        if "sourceObservedAtUnixMs" in event:
            require(type(event["sourceObservedAtUnixMs"]) is int
                    and event["sourceObservedAtUnixMs"] == body["capturedAtUnixMs"], "event body clock differs")
        if event.get("kind") == "native-objective-review":
            require(observation["kind"] == "review", "objective review observation kind differs")
            required_event = {"pid", "attempt", "save", "saveMode", "playerIndex", "playerSqlId",
                "sampleSha256", "sourceObservedAtUnixMs", "atUnixMs", "worldHours", "countyHours",
                "captureEpoch",
                "objectiveSourceFile", "objectiveSourceSha256", "objectiveSourceRecord",
                "objectiveReviewSha256", "processId", "revision", "playerId", "helperId",
                "returnReceiptId", "reviewedAtHours"}
            require(required_event <= set(event), "objective review event fields differ")
            require(type(event["atUnixMs"]) is int and event["atUnixMs"] >= body["capturedAtUnixMs"],
                    "objective review event clock differs")
            source_hash = _hash(event.get("objectiveSourceSha256"))
            source_file = "objective-reviews/" + source_hash + ".json"
            require(event.get("objectiveSourceFile") == source_file,
                    "objective review source file differs")
            review_source_ref = {"file": source_file, "sha256": source_hash}
            source = _read_ref(root, review_source_ref)
            require(NativePlay.validate_objective_review_source(source, run) == body,
                    "objective review body source differs")
            require(source["sampleSha256"] == observation["bodySource"]["sha256"],
                    "objective review body sample differs")
            index = event.get("objectiveSourceRecord")
            require(type(index) is int and 0 <= index < len(source["reviews"]),
                    "objective review source record differs")
            review = source["reviews"][index]
            require(_digest(review) == event.get("objectiveReviewSha256"),
                    "objective review record hash differs")
            require(review["playerId"] == trial["actor"]["actorId"],
                    "objective review player differs from trial actor")
            review_clock = {"countyHours": source["countyHours"],
                            "reviewedAtHours": review["review"]["reviewedAt"]}
            for event_key, source_value in (("processId", review["processId"]),
                    ("revision", review["revision"]), ("playerId", review["playerId"]),
                    ("helperId", review["helperId"]), ("returnReceiptId", review["returnReceiptId"]),
                    ("reviewedAtHours", review["review"]["reviewedAt"]),
                    ("worldHours", source["worldHours"]),
                    ("countyHours", source["countyHours"]),
                    ("captureEpoch", source["captureEpoch"])):
                require(type(event.get(event_key)) is type(source_value)
                        and event[event_key] == source_value, "objective review event binding differs")
            require(trial["source"]["evidenceOrigin"] != "actual-native"
                    or _native_review_event_custody(root, run, observation["source"], event),
                    "actual-native objective review event is absent from native events")
        else:
            require(observation["kind"] != "review", "review requires native source receipt")
    elif schema == "sao-study-run/1":
        require(observation["kind"] == "end" and event.get("status") in TERMINAL, "run source is not an observed end")
        Participant.validate_receipt(event, identity["sessionId"])
        require(event["pid"] == identity["pid"] and event.get("save") in (None, identity["save"])
                and event.get("saveMode") in (None, identity["saveMode"]), "end source body differs")
        require(all(event.get(k) == v for k, v in trial["source"]["producerPins"].items()),
                "end producer source differs")
    else:
        raise ValueError("unsupported native observation source")
    clock = {"capturedAtUnixMs": body["capturedAtUnixMs"], "worldHours": body["worldHours"]}
    require(clock["capturedAtUnixMs"] >= binding_body["capturedAtUnixMs"]
            and clock["worldHours"] >= binding_body["worldHours"], "observation clocks regressed before binding epoch")
    if trial["objective"]["mode"] == "prospective":
        require(clock["capturedAtUnixMs"] >= trial["objective"]["assignedAtUnixMs"], "observation predates its objective")
    require(isinstance(observation["replay"], list) and len(observation["replay"]) <= 8, "invalid observation replay list")
    replays = [_replay(trial["source"], value, clock) for value in observation["replay"]]
    measurements = observation["measurements"]
    require(isinstance(measurements, dict) and len(measurements) <= 64, "invalid source measurements")
    values = {_text(label, 160): {"pointer": pointer, "value": _pointer(event, pointer)}
              for label, pointer in measurements.items()}
    return {**observation,
            **({"objectiveReviewSource": review_source_ref, "sourceClock": review_clock}
               if review_source_ref else {}),
            "clock": clock, "sourceRecordSha256": _digest(event),
            "measurementsObserved": values, "replayObserved": replays,
            "annotationBasis": "interpretation; original source is retained separately"}


def append_observation(trial, observation):
    path = _write_trial_path(trial)
    with _lock(path.parent / "trial.lock"):
        value = read_trial(path)
        root, _, _, _ = _source(value["source"]); _outside_source(path, root)
        row = _observation(value, observation)
        for old in value["observations"]:
            if old["id"] == row["id"]:
                require(old == row, "observation id reused with different evidence")
                return value
        require(value["status"] == "collecting", "trial is already complete")
        require(len(value["observations"]) < MAX_OBSERVATIONS, "objective timeline limit reached")
        if value["observations"]:
            previous = value["observations"][-1]["clock"]
            require(row["clock"]["capturedAtUnixMs"] >= previous["capturedAtUnixMs"]
                    and row["clock"]["worldHours"] >= previous["worldHours"], "observation clocks regressed")
        value["observations"].append(row); value["revision"] += 1
        return _commit(path, value)


def _evidence(value, ids, kinds=None, *, empty=False):
    require(isinstance(ids, list) and (empty or ids) and len(ids) <= MAX_OBSERVATIONS
            and len(ids) == len(set(ids)), "invalid or missing observation evidence")
    rows = {row["id"]: row for row in value["observations"]}
    require(all(name in rows and (kinds is None or rows[name]["kind"] in kinds) for name in ids),
            "evidence belongs to another trial or kind")
    return [rows[name] for name in ids]


def _completion(value, completion):
    require(isinstance(completion, dict) and set(completion) == {"reportedBy", "outcome", "return", "costs", "uncertainties"},
            "completion fields differ")
    _text(completion["reportedBy"], 160)
    require(any(r["kind"] == "attempt" for r in value["observations"]), "objective attempt not observed")
    for key, choices, kind in (("outcome", {"met", "not-met", "undetermined"}, "outcome"),
                              ("return", {"returned", "not-returned", "unobserved"}, "return")):
        item = completion[key]
        require(isinstance(item, dict) and set(item) == {"status", "evidence", "interpretation"}
                and item["status"] in choices, "invalid objective result")
        _text(item["interpretation"], multiline=True)
        allowed = {kind, "review", "end"} if item["status"] in ("undetermined", "unobserved") else {kind, "review"}
        _evidence(value, item["evidence"], allowed)
    costs = completion["costs"]
    require(isinstance(costs, dict) and set(costs) == {"status", "evidence"}
            and costs["status"] in ("observed", "unmeasured"), "invalid objective costs")
    _evidence(value, costs["evidence"], {"cost"}, empty=costs["status"] == "unmeasured")
    require(costs["status"] != "unmeasured" or not costs["evidence"], "unmeasured costs carry observations")
    unknowns = completion["uncertainties"]
    require(isinstance(unknowns, list) and len(unknowns) <= 64, "invalid completion uncertainties")
    for item in unknowns:
        _text(item, multiline=True)
    require((completion["outcome"]["status"] != "undetermined" and completion["return"]["status"] != "unobserved"
             and costs["status"] != "unmeasured") or unknowns, "unknown result needs an explicit uncertainty")


def _validate_timeline(value):
    _source(value["source"]); _objective(value["objective"])
    previous = None
    for stored in value["observations"]:
        input_row = {k: stored[k] for k in ("id", "kind", "source", "bodySource", "replay", "annotation", "measurements")}
        row = _observation(value, input_row)
        require(stored == row, "stored observation differs from source")
        if previous:
            require(row["clock"]["capturedAtUnixMs"] >= previous["capturedAtUnixMs"]
                    and row["clock"]["worldHours"] >= previous["worldHours"], "stored timeline clocks regressed")
        previous = row["clock"]


def complete_trial(trial, completion):
    path = _write_trial_path(trial)
    with _lock(path.parent / "trial.lock"):
        value = read_trial(path); _outside_source(path, _source_root(value["source"]["sessionRoot"]))
        _validate_timeline(value); _completion(value, completion)
        if value["completion"] is not None:
            require(value["completion"] == completion, "completion already records another result")
            return value
        value.update(completion=completion, status="complete", revision=value["revision"]+1)
        return _commit(path, value)


def evaluate_trial(trial, evaluation):
    path = _write_trial_path(trial)
    with _lock(path.parent / "trial.lock"):
        value = read_trial(path); _outside_source(path, _source_root(value["source"]["sessionRoot"]))
        _validate_timeline(value)
        require(value["completion"] is not None, "incomplete objective trial cannot be reviewed")
        _completion(value, value["completion"])
        require(isinstance(evaluation, dict) and set(evaluation) == {"reviewer", "disposition", "evidence", "rationale", "reviewedAtUnixMs"},
                "human evaluation fields differ")
        require(isinstance(evaluation["reviewer"], dict) and set(evaluation["reviewer"]) == {"kind", "id"}
                and evaluation["reviewer"]["kind"] == "human", "explicit human reviewer required")
        _text(evaluation["reviewer"]["id"], 160); _text(evaluation["rationale"], multiline=True)
        require(evaluation["disposition"] in ("candidate", "retain", "exclude", "more-context"), "unknown human disposition")
        _evidence(value, evaluation["evidence"])
        if evaluation["disposition"] == "candidate":
            result_ids = {name for section in ("outcome", "return", "costs")
                          for name in value["completion"][section]["evidence"]}
            require(result_ids <= set(evaluation["evidence"])
                    and any(row["kind"] == "attempt" for row in _evidence(value, evaluation["evidence"])),
                    "candidate review omits attempt, result or cost evidence")
        _number(evaluation["reviewedAtUnixMs"], integer=True)
        require(evaluation["reviewedAtUnixMs"] >= value["observations"][-1]["clock"]["capturedAtUnixMs"], "review predates observed evidence")
        if value["evaluation"] is not None:
            require(value["evaluation"] == evaluation, "human review already records another disposition")
            return value
        value.update(evaluation=evaluation, status="reviewed", revision=value["revision"]+1)
        return _commit(path, value)


def export_candidate(trial, destination):
    path = _write_trial_path(trial)
    with _lock(path.parent / "trial.lock"):
        value = read_trial(path)
        root = _source_root(value["source"]["sessionRoot"])
        destination = _outside_source(destination, root)
        _clear_source_cache(root)
        _validate_timeline(value)
        require(value["status"] == "reviewed" and value["completion"] is not None
                and value["evaluation"] is not None and value["evaluation"]["disposition"] == "candidate"
                and value["evaluation"]["reviewer"]["kind"] == "human", "explicit candidate review required")
        _completion(value, value["completion"])
        require(all(row["replayObserved"] for row in value["observations"]), "candidate evidence lacks replay")
        require(value["actor"]["saveMode"] is not None, "candidate native save namespace is unknown")
        # A completed research record may describe a failed or interrupted attempt.
        # Its outcome remains the reviewed interpretation, never a success label.
        candidate = {"schema": CANDIDATE_SCHEMA, "trialId": value["trialId"], "trialSha256": value["integritySha256"],
                     "source": value["source"], "actor": value["actor"], "objective": value["objective"],
                     "observations": value["observations"], "completion": value["completion"],
                     "humanEvaluation": value["evaluation"], "uncertainties": value["uncertainties"],
                     "admission": "reviewed-learning-candidate", "trainingStatus": "not-run"}
        raw = encoded(candidate)
        require(destination != path and destination.name != "trial.lock", "candidate would replace trial state")
        with _lock(destination.parent / (destination.name+".lock")):
            if destination.exists():
                require(_bytes(destination, MAX_TRIAL_JSON) == raw, "candidate destination already contains other evidence")
            else:
                _atomic(destination, raw)
        return {"schema": "sao.objective-export/1", "file": str(destination),
                "sha256": hashlib.sha256(raw).hexdigest(), "trialId": value["trialId"],
                "evidenceOrigin": value["source"]["evidenceOrigin"], "trainingStatus": "not-run"}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    subs = parser.add_subparsers(dest="command", required=True)
    build = subs.add_parser("source"); build.add_argument("session"); build.add_argument("body")
    build.add_argument("--run", default="participant-run/run.json")
    build.add_argument("--origin", choices=("auto", "actual-native", "synthetic-control", "unverified"), default="auto")
    create = subs.add_parser("create")
    for name in ("source", "actor", "objective", "destination"):
        create.add_argument(name)
    for name in ("append", "complete", "evaluate"):
        sub = subs.add_parser(name); sub.add_argument("trial"); sub.add_argument("input")
    export = subs.add_parser("export"); export.add_argument("trial"); export.add_argument("destination")
    show = subs.add_parser("show"); show.add_argument("trial")
    args = parser.parse_args(argv)
    def input_json(name):
        return _json(_bytes(Path(name)))
    try:
        if args.command == "source":
            result = build_source_manifest(args.session, args.body, run_file=args.run,
                                           evidence_origin=None if args.origin == "auto" else args.origin)
        elif args.command == "create":
            result = create_trial(input_json(args.source), input_json(args.actor), input_json(args.objective), args.destination)
        elif args.command in ("append", "complete", "evaluate"):
            result = {"append": append_observation, "complete": complete_trial,
                      "evaluate": evaluate_trial}[args.command](args.trial, input_json(args.input))
        elif args.command == "export":
            result = export_candidate(args.trial, args.destination)
        else:
            result = read_trial(args.trial)
        sys.stdout.buffer.write(encoded(result)); return 0
    except (ValueError, OSError, KeyError, TypeError) as error:
        print(json.dumps({"schema": "sao.objective-error/1", "message": str(error)}), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
