#!/usr/bin/env python3
"""Retain native published video for a persistent study, without controlling it.

The encoder owns pixels, PTS and capture clocks. This collector retains those
claims and bytes separately per attempt/stream. Observer samples have their own
clock: they are mapping evidence, never asserted to be synchronized video frames.
"""
from __future__ import annotations

import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import sys
import threading
import time
import uuid

SCHEMA = "sao.native-video-archive/1"
DEFAULT_MAX_BYTES = 64 * 1024**3
DEFAULT_MIN_FREE_BYTES = 1024**3
READ_ATTEMPTS = 20
READ_RETRY_SECONDS = .01


def sha(data):
    return hashlib.sha256(data).hexdigest()


def encoded(value):
    return (json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False) + "\n").encode()


def sharing_read(operation):
    """Bound a Windows producer's replace/read sharing conflict, then fail visibly.

    Only access denial is retried. Missing rolling assets, corrupt bytes and
    malformed metadata retain their own admission/failure paths.
    """
    for attempt in range(READ_ATTEMPTS):
        try:
            return operation()
        except PermissionError:
            if attempt == READ_ATTEMPTS - 1:
                raise
            time.sleep(READ_RETRY_SECONDS)


def read(path, limit=16 * 1024**2):
    def source_bytes():
        if path.is_symlink() or path.stat().st_size > limit:
            raise ValueError("unsafe archive source: " + str(path))
        return path.read_bytes()
    raw = sharing_read(source_bytes)
    if len(raw) > limit:
        raise ValueError("unsafe archive source: " + str(path))
    return raw, json.loads(raw)


def atomic(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    pending = path.with_suffix(path.suffix + ".tmp")
    pending.write_bytes(encoded(value))
    for attempt in range(20):
        try:
            os.replace(pending, path)
            return
        except PermissionError:
            if attempt == 19:
                raise
            time.sleep(.01)


def gaps(sequences):
    result, previous = [], 0
    for value in sorted(sequences):
        if value > previous + 1:
            result.append({"first": previous + 1, "last": value - 1})
        previous = value
    return result


def validate_manifest(value):
    if value.get("schema") != "sao-study-video/1":
        raise ValueError("unknown native video schema")
    stream = value["streamId"]
    if str(uuid.UUID(stream)) != stream:
        raise ValueError("invalid native stream identity")
    rows = value["segments"]
    if not isinstance(rows, list) or len(rows) > 8:
        raise ValueError("invalid native rolling segment list")
    previous = 0
    for row in rows:
        seq = row["sequence"]
        if type(seq) is not int or seq <= previous or seq > 2**53:
            raise ValueError("invalid native segment order")
        previous = seq
        if row["file"] != f"video-{stream}-{seq:016d}.m4s":
            raise ValueError("segment belongs to another stream")
        for field in ("ptsStartMs", "durationMs", "capturedAtUnixMs", "endCapturedAtUnixMs",
                      "observerSequence", "worldHours", "endWorldHours", "firstFrameSequence", "lastFrameSequence"):
            number = row[field]
            if type(number) not in (int, float) or not math.isfinite(number) or number < 0:
                raise ValueError("invalid native video clock: " + field)
        if row["durationMs"] <= 0 or row["endCapturedAtUnixMs"] < row["capturedAtUnixMs"]:
            raise ValueError("invalid native video interval")
    init = value.get("init")
    if rows and not init:
        raise ValueError("native segments lack initialization")
    if init and init["file"] != f"video-{stream}-init.mp4":
        raise ValueError("initialization belongs to another stream")
    for row in ([init] if init else []) + rows:
        if not isinstance(row.get("sha256"), str) or len(row["sha256"]) != 64:
            raise ValueError("native asset lacks hash")
    return stream


class Archive:
    def __init__(self, session_root, study_id, max_bytes=DEFAULT_MAX_BYTES,
                 min_free_bytes=DEFAULT_MIN_FREE_BYTES, interval=.1):
        self.session = Path(session_root).resolve()
        self.root = self.session / "video-archive"
        self.study_id = study_id
        self.max_bytes, self.min_free = max_bytes, min_free_bytes
        if type(max_bytes) is not int or max_bytes <= 0 or type(min_free_bytes) is not int or min_free_bytes < 0:
            raise ValueError("invalid native archive storage bounds")
        self.interval = interval
        self.stop_event = threading.Event()
        self.thread = None
        self.streams, self.stamps, self.provenance = {}, {}, {}
        self.receipts = {}
        self.total_bytes = 0
        self.error = None
        self.started = int(time.time() * 1000)
        self.finished = False
        self.lock = None
        self.body_samples = 0
        self.prior_failures = []

    def acquire(self):
        self.root.mkdir(parents=True, exist_ok=True)
        handle = (self.root / "owner.lock").open("a+b")
        try:
            if not handle.seek(0, 2):
                handle.write(b"0"); handle.flush()
            handle.seek(0)
            if sys.platform == "win32":
                import msvcrt
                msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl
                fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.lock = handle
        except OSError:
            handle.close()
            raise OSError("native video archive already has a live owner")

    def store(self, path, data):
        if path.exists():
            if path.is_symlink() or sharing_read(path.read_bytes) != data:
                raise ValueError("archive immutable file changed: " + str(path))
            return
        if self.total_bytes + len(data) > self.max_bytes:
            raise OSError("native video archive storage limit reached")
        if shutil.disk_usage(self.root).free - len(data) < self.min_free:
            raise OSError("native video archive free-space reserve reached")
        path.parent.mkdir(parents=True, exist_ok=True)
        pending = path.with_suffix(path.suffix + ".tmp")
        pending.write_bytes(data)
        pending.replace(path)
        self.total_bytes += len(data)

    def initialize(self):
        self.root.mkdir(parents=True, exist_ok=True)
        state_path = self.root / "archive.json"
        old_raw, old = None, {}
        if state_path.exists():
            old_raw, old = read(state_path)
            if old.get("studyId") != self.study_id or old.get("source") != str(self.session):
                raise ValueError("archive belongs to another study")
        self.total_bytes = sum(p.stat().st_size for p in self.root.rglob("*") if p.is_file())
        if old.get("status") == "failed":
            self.store(self.root / "failures" / (sha(old_raw) + ".json"), old_raw)
        for path in sorted((self.root / "failures").glob("*.json")):
            raw, failure = read(path)
            if path.stem != sha(raw) or failure.get("status") != "failed" or (
                    failure.get("studyId") != self.study_id or failure.get("source") != str(self.session)):
                raise ValueError("retained collector failure provenance differs")
            self.prior_failures.append({"file": str(path.relative_to(self.root)).replace("\\", "/"),
                "sha256": sha(raw), "error": failure.get("error"), "updatedAtUnixMs": failure.get("updatedAtUnixMs")})
        self.prior_failures.sort(key=lambda value: value.get("updatedAtUnixMs") or 0)
        self.body_samples = len(list((self.root / "body-inspection").glob("*.json")))
        for path in self.root.glob("[0-9][0-9][0-9][0-9]/provenance/*.json"):
            raw, receipt = read(path)
            if path.stem != sha(raw):
                raise ValueError("retained native provenance hash differs")
            number = int(path.parent.parent.name)
            if receipt.get("launchNumber") != number:
                raise ValueError("retained native attempt identity differs")
            previous = self.provenance.get(number)
            if previous and previous["sessionId"] != receipt.get("sessionId"):
                raise ValueError("native session changed within an attempt")
            if previous is None or receipt.get("status") in ("completed", "failed", "incomplete"):
                self.provenance[number] = {k: receipt.get(k) for k in
                    ("sessionId", "launchNumber", "packageSha256", "definitionSha256", "status", "terminal")}
        # Reconstruct only from immutable retained manifests; do not trust an
        # interrupted summary as proof that bytes were copied.
        for path in sorted(self.root.glob("[0-9][0-9][0-9][0-9]/*/manifests/*.json")):
            raw, value = read(path)
            if path.stem != sha(raw):
                raise ValueError("retained native manifest hash differs")
            stream = validate_manifest(value)
            if path.parent.parent.name != stream:
                raise ValueError("retained stream directory differs")
            self.accept(path.parent.parent.parent.name, raw, value, path.parent.parent, restoring=True)
        self.publish()

    def fail(self, error):
        self.error = {"type": type(error).__name__, "reason": str(error)[:1000],
                      "atUnixMs": int(time.time() * 1000)}
        print("world_lab_video_archive: " + str(error), file=sys.stderr, flush=True)
        if self.lock is None:
            # A refused collector cannot overwrite the active owner's evidence.
            try:
                atomic(self.session / f"video-archive-refusal-{os.getpid()}.json", self.error)
            except OSError:
                pass
            return
        try:
            self.publish()
        except OSError as failure:
            print("world_lab_video_archive: failure receipt unavailable: " + str(failure), file=sys.stderr, flush=True)

    def accept(self, attempt, raw, value, destination, restoring=False):
        stream = validate_manifest(value)
        key = attempt + "/" + stream
        state = self.streams.setdefault(key, {"attempt": int(attempt), "streamId": stream,
            "segments": {}, "manifests": set(), "firstSeenAtUnixMs": int(time.time()*1000),
            "initialSequence": None, "producerState": "unknown", "lastSequence": 0,
            "producerStats": {}, "source": str(self.session / "native-run/attempts" / attempt / "native-view")})
        rows = value["segments"]
        if rows:
            state["initialSequence"] = min(state["initialSequence"] or rows[0]["sequence"], rows[0]["sequence"])
        for row in ([value["init"]] if value.get("init") else []) + rows:
            target = destination / row["file"]
            asset = target if target.exists() else Path(state["source"]) / row["file"]
            data = sharing_read(asset.read_bytes)
            if not data or sha(data) != row["sha256"]:
                raise ValueError("published video asset hash differs: " + row["file"])
            if restoring and not target.exists():
                raise ValueError("retained manifest has missing video bytes")
            self.store(target, data)
            if "sequence" in row:
                seq = row["sequence"]
                if seq in state["segments"] and state["segments"][seq] != row:
                    raise ValueError("native segment identity was rewritten")
                state["segments"][seq] = row
        self.store(destination / "manifests" / (sha(raw) + ".json"), raw)
        state["manifests"].add(sha(raw))
        latest = rows[-1]["sequence"] if rows else 0
        if (latest, value["state"] in ("ended", "failed")) >= (state["lastSequence"], state["producerState"] in ("ended", "failed")):
            state.update(lastSequence=latest, producerState=value["state"], producerStats=value.get("stats", {}))
        if not restoring:
            self.stream_report(key, state)

    def stream_report(self, key, state):
        rows = state["segments"]
        missing = gaps(rows)
        timing_gaps = []
        ordered = [rows[n] for n in sorted(rows)]
        for a, b in zip(ordered, ordered[1:]):
            if b["sequence"] == a["sequence"] + 1 and abs(b["ptsStartMs"] - a["ptsStartMs"] - a["durationMs"]) > 1.1:
                timing_gaps.append({"afterSequence": a["sequence"], "beforeSequence": b["sequence"]})
        terminal = state["producerState"] in ("ended", "failed")
        run_terminal = (self.provenance.get(state["attempt"]) or {}).get("status") in ("completed", "failed", "incomplete")
        collector_stopped = self.finished or self.error is not None
        coverage = "unavailable" if not rows and (terminal or collector_stopped or run_terminal) else "partial" if missing or timing_gaps or state["producerState"] == "failed" or ((collector_stopped or run_terminal) and not terminal) else (
            "complete-published-segments" if terminal and rows else "recording")
        report = {k: v for k, v in state.items() if k not in ("segments", "manifests")}
        report.update(schema=SCHEMA, studyId=self.study_id, coverage=coverage,
                      retainedSegments=len(rows), manifestCount=len(state["manifests"]), missingSequences=missing,
                      ptsGaps=timing_gaps, lateAttachment=bool(state["initialSequence"] and state["initialSequence"] > 1),
                      tailConfirmed=terminal, mappingClock="separate observer samples; join by source clocks and site identity",
                      firstSegment=ordered[0] if ordered else None, lastSegment=ordered[-1] if ordered else None,
                      nativeProvenance=self.provenance.get(state["attempt"]))
        atomic(self.root / key / "stream.json", report)
        return report

    def sample(self, source, destination):
        if not source.exists():
            return None
        stat = sharing_read(source.stat)
        stamp = (stat.st_mtime_ns, stat.st_size)
        if self.stamps.get(str(source)) == stamp:
            return None
        raw, value = read(source)
        target = destination / (sha(raw) + ".json")
        fresh = not target.exists()
        self.store(target, raw)
        self.stamps[str(source)] = stamp
        return value if fresh else None

    def poll(self):
        # This source has no native session UUID and may still describe the
        # preceding attempt. Preserve original identity/clock at study level;
        # consumers must join its capture time/save/definition explicitly.
        body = self.sample(self.session / "native-run/cache/Lua/StudyWorldLive.json",
                           self.root / "body-inspection")
        if body is not None:
            self.body_samples += 1
        attempts = self.session / "native-run/attempts"
        for source in sorted(attempts.glob("[0-9][0-9][0-9][0-9]")):
            if source.is_symlink():
                raise ValueError("unsafe native attempt")
            target = self.root / source.name
            # Each immutable sample retains its own producer clock. Full run
            # provenance is archived on change, without copying saves or logs.
            report_path = source / "report.json"
            run_path = self.session / "native-run/run.json"
            chosen = report_path if report_path.exists() else run_path
            if chosen.exists():
                stat = sharing_read(chosen.stat)
                stamp = (stat.st_mtime_ns, stat.st_size)
                cached = self.receipts.get(str(chosen))
                if cached and cached[0] == stamp:
                    receipt = cached[1]
                else:
                    _, receipt = read(chosen)
                    self.receipts[str(chosen)] = (stamp, receipt)
                if receipt.get("launchNumber") == int(source.name):
                    previous = self.provenance.get(int(source.name))
                    if previous and previous["sessionId"] != receipt.get("sessionId"):
                        raise ValueError("native session changed within an attempt")
                    self.sample(chosen, target / "provenance")
                    self.provenance[int(source.name)] = {k: receipt.get(k) for k in
                        ("sessionId", "launchNumber", "packageSha256", "definitionSha256", "status", "terminal")}
            self.sample(source / "observer-state.json", target / "observer-mapping")
            manifest = source / "native-view/latest-video.json"
            if manifest.parent.is_symlink():
                raise ValueError("unsafe native view directory")
            if not manifest.exists():
                continue
            raw, value = read(manifest)
            stream = validate_manifest(value)
            state = self.streams.get(source.name + "/" + stream)
            if state and sha(raw) in state["manifests"]:
                continue
            try:
                self.accept(source.name, raw, value, target / stream)
            except FileNotFoundError:
                # The producer may retire a rolling segment between metadata
                # and byte reads. Retry newer metadata; sequence gaps remain.
                continue
        self.publish()

    def publish(self):
        reports = [self.stream_report(key, state) for key, state in self.streams.items()]
        atomic(self.root / "archive.json", {"schema": SCHEMA, "studyId": self.study_id,
            "source": str(self.session), "startedAtUnixMs": self.started,
            "updatedAtUnixMs": int(time.time()*1000), "status": "failed" if self.error else (
                "stopped" if self.finished else "recording"), "error": self.error,
            "priorFailureCount": len(self.prior_failures), "priorFailures": self.prior_failures[-32:],
            "maxBytes": self.max_bytes, "minFreeBytes": self.min_free, "retainedBytes": self.total_bytes,
            "bodyInspection": {"samples": self.body_samples, "directory": "body-inspection",
                "source": "native-run/cache/Lua/StudyWorldLive.json", "nativeAttemptAssigned": False,
                "clock": "source inspection.capturedAtUnixMs, hours, save and definitionSha256; separate from video"},
            "attempts": [{"attempt": number, "nativeProvenance": value,
                "video": "observed" if any(s["attempt"] == number for s in self.streams.values()) else "unavailable"}
                for number, value in sorted(self.provenance.items())],
            "streams": [{k: r[k] for k in ("attempt", "streamId", "coverage", "retainedSegments", "lateAttachment", "tailConfirmed")}
                        for r in reports]})

    def run(self):
        try:
            while not self.stop_event.wait(self.interval):
                self.poll()
            self.poll()  # Native owner has returned; retain its final manifest.
            self.finished = True
            self.publish()
        except Exception as error:
            self.fail(error)

    def start(self):
        try:
            self.acquire()
            self.initialize()
            self.poll()
            self.thread = threading.Thread(target=self.run, name="study-video-archive", daemon=True)
            self.thread.start()
        except Exception as error:
            self.fail(error)
        return self

    def close(self):
        self.stop_event.set()
        if self.thread:
            self.thread.join(timeout=10)
            if self.thread.is_alive():
                self.fail(TimeoutError("native archive did not finish its bounded close"))
                return  # Keep its lock while the writer is still alive.
        if self.lock:
            self.lock.close()  # Kernel releases this lock on process death too.
            self.lock = None


def start(session_root, study_id, **limits):
    return Archive(session_root, study_id, **limits).start()
