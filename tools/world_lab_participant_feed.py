#!/usr/bin/env python3
"""Publish one source-bound player attempt using Mousecat's native-view protocol.

Pixels are copied unchanged. Participant identity is a separately timed native
sample and never claims that a person is visible in a particular video frame.
Registry locking follows Speakeasy world_watch.register_feed's existing source.
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import stat
import time
import uuid

import world_lab as Lab

MAX_JSON = 1024 * 1024
MAX_RUN_JSON = 32 * 1024 * 1024
MAX_IMAGE = 16 * 1024 * 1024
MAX_NATIVE_VIEWS = 128
MAX_RUN_READ_ATTEMPTS = 3
STUDY_FIELDS = ("id", "label", "status", "attempt", "attemptDurationSeconds",
    "autoContinue", "worldHours", "accumulatedWorldHours", "canCheckpoint",
    "canContinue", "updatedAtUnixMs", "lastStopReason")


def encoded(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, allow_nan=False,
                       separators=(",", ":")) + "\n").encode("utf-8")


def atomic(path, value):
    import world_lab_session as Session
    Session.atomic(Path(path), value)


def read(path, maximum=MAX_JSON):
    path = Path(path)
    Lab.require(not path.is_symlink() and path.is_file() and path.stat().st_size <= maximum,
                "unsafe participant source file")
    raw = path.read_bytes()
    Lab.require(len(raw) <= maximum, "oversized participant source file")

    def pairs(items):
        result = {}
        for key, value in items:
            Lab.require(key not in result, "duplicate participant source field")
            result[key] = value
        return result

    value = json.loads(raw, object_pairs_hook=pairs,
                       parse_constant=lambda _: (_ for _ in ()).throw(ValueError("nonfinite participant JSON")))
    return raw, value


def source_version(path, maximum=MAX_JSON, *, optional=False):
    """Track atomic file replacement without reopening an unchanged payload."""
    try:
        info = Path(path).lstat()
    except FileNotFoundError:
        if optional: return None
        raise
    Lab.require(stat.S_ISREG(info.st_mode) and info.st_size <= maximum,
                "unsafe participant source file")
    return (info.st_dev, info.st_ino, info.st_mtime_ns, info.st_ctime_ns, info.st_size)


def canonical_uuid(value):
    Lab.require(isinstance(value, str) and str(uuid.UUID(value)) == value,
                "participant UUID differs")
    return value


def text(value, maximum, empty=False):
    Lab.require(isinstance(value, str) and len(value) <= maximum and (empty or len(value) > 0)
                and not any(ord(c) < 32 or ord(c) == 127 for c in value), "participant text differs")
    return value


def number(value, low=0, high=2**53 - 1):
    Lab.require(type(value) in (int, float) and math.isfinite(value) and low <= value <= high,
                "participant number differs")
    return value


def validate_receipt(value, expected_session=None):
    Lab.require(isinstance(value, dict) and value.get("schema") == "sao-study-run/1"
                and value.get("host") == "player" and value.get("participantInput") is True
                and value.get("window") == "visible" and value.get("watch") is True,
                "participant run binding differs")
    canonical_uuid(value.get("sessionId"))
    Lab.require(expected_session is None or value["sessionId"] == expected_session,
                "participant native session changed")
    Lab.integer(value.get("pid"), 1, 2**31 - 1, "participant native pid")
    Lab.require(value.get("launchNumber") == 1 and type(value.get("launchNumber")) is int
                and value.get("observerDirectory") == "attempts/0001", "participant attempt differs")
    Lab.require(value.get("status") in ("running", "exited", "timed-out", "completed", "failed", "incomplete"),
                "participant run status differs")
    return value


def validate_body(value, receipt, *, now=None):
    now = int(time.time() * 1000) if now is None else now
    required = {"schema", "sessionId", "pid", "attempt", "save", "playerIndex", "playerSqlId",
                "capturedAtUnixMs", "worldHours", "ready", "displayFocused", "alive"}
    Lab.require(isinstance(value, dict) and required <= set(value) <= required | {"body", "saveMode", "startContext"}
                and value["schema"] == "sao-native-participant/1", "participant state fields differ")
    Lab.require(value["sessionId"] == receipt["sessionId"] and value["pid"] == receipt["pid"]
                and type(value["pid"]) is int and value["attempt"] == 1 and type(value["attempt"]) is int,
                "participant state owner differs")
    Lab.integer(value["playerIndex"], 0, 0, "participant player slot")
    Lab.integer(value["playerSqlId"], -1, 2**31 - 1, "participant SQL identity")
    Lab.integer(value["capturedAtUnixMs"], 1, now + 2000, "participant state time")
    number(value["worldHours"])
    Lab.require(all(type(value[key]) is bool for key in ("ready", "displayFocused", "alive")),
                "participant state switches differ")
    if "body" in value:
        Lab.require(isinstance(value["body"], dict) and set(value["body"]) == {"x", "y", "z", "label"},
                    "participant body fields differ")
        for key in ("x", "y"): number(value["body"][key], -(2**31), 2**31)
        number(value["body"]["z"], -32, math.nextafter(32, -math.inf))
        text(value["body"]["label"], 160, empty=True)
    if value["ready"]:
        text(value["save"], 180)
        Lab.require(value["playerSqlId"] > 0 and "body" in value, "participant body identity unavailable")
        if receipt.get("save"):
            Lab.require(value["save"] == receipt["save"], "participant state save differs from native receipt")
    else:
        # The engine can expose the real body before allocating its persisted
        # SQL id. Preserve capture while leaving person/input admission closed.
        text(value["save"], 180, empty=True)
        Lab.require(value["playerSqlId"] == -1, "unready participant SQL identity differs")
    if "saveMode" in value:
        Lab.require(receipt.get("launchMode") == "native-menu", "native save mode requires an interactive source")
        text(value["saveMode"], 180, empty=not value["ready"])
        if value["ready"] and receipt.get("saveMode"):
            Lab.require(value["saveMode"] == receipt["saveMode"], "native saved game mode changed")
    if receipt.get("launchMode") == "native-menu":
        Lab.require("saveMode" in value, "native save namespace unavailable")
    if "startContext" in value:
        Lab.require(receipt.get("launchMode") == "native-menu", "native start context requires an interactive source")
        import world_lab_start_context as StartContext
        StartContext.validate_sample(value["startContext"], value)
    return value


def validate_capture_context(value, receipt, *, stream_id=None):
    """Admit an actual native-play capture lifetime without inventing a body."""
    base = {"schema", "namespace", "sessionId", "pid", "attempt", "captureEpoch",
            "saveMode", "save", "bodyObserved", "binding", "worldClock", "worldHours"}
    required = base | ({"streamId"} if stream_id is not None else set())
    Lab.require(receipt.get("launchMode") == "native-menu" and isinstance(value, dict)
                and required <= set(value) <= required | {"playerIndex", "playerSqlId"}
                and value["schema"] == "sao.native-capture-context/1"
                and value["namespace"] == "native-play", "native capture context fields differ")
    Lab.require(value["sessionId"] == receipt["sessionId"] and value["pid"] == receipt["pid"]
                and type(value["pid"]) is int and value["attempt"] == 1
                and type(value["attempt"]) is int, "native capture context owner differs")
    Lab.integer(value["captureEpoch"], 1, 2**53 - 1, "native capture epoch")
    if stream_id is not None:
        Lab.require(canonical_uuid(value["streamId"]) == canonical_uuid(stream_id),
                    "native capture stream differs")
    for field in ("saveMode", "save"):
        if value[field] is not None: text(value[field], 180, empty=True)
    Lab.require(type(value["bodyObserved"]) is bool and value["binding"] in ("persisted", "unbound")
                and value["worldClock"] in ("observed", "unavailable"),
                "native capture state differs")
    if value["worldClock"] == "observed":
        number(value["worldHours"])
    else:
        Lab.require(value["worldHours"] is None, "unavailable native world clock differs")
    if value["binding"] == "persisted":
        Lab.require(set(value) == required | {"playerIndex", "playerSqlId"}
                    and value["bodyObserved"] and value["worldClock"] == "observed"
                    and isinstance(value["save"], str) and bool(value["save"]),
                    "persisted native capture identity differs")
        Lab.integer(value["playerIndex"], 0, 0, "native capture player slot")
        Lab.integer(value["playerSqlId"], 1, 2**31 - 1, "native capture SQL identity")
    else:
        Lab.require(set(value) == required and value["bodyObserved"] == (value["worldClock"] == "observed"),
                    "unbound native capture identity differs")
    return value


def validate_native_camera(value):
    """A render/swap-owned pixel label; no later Viewpoint toggle is consulted."""
    Lab.require(isinstance(value, dict) and set(value) == {"schema", "mode", "ready"}
                and value["schema"] == "sao.native-frame-camera/1",
                "native camera fields differ")
    mode = value["mode"]
    Lab.require(type(mode) is str and mode in ("isometric", "viewpoint-first",
                "viewpoint-third", "viewpoint-free", "unavailable")
                and type(value["ready"]) is bool
                and value["ready"] == (mode != "unavailable"),
                "native camera readiness differs")
    return value


def validate_video_camera_frames(manifest):
    """Validate each encoded sample's source-owned frame camera if advertised."""
    for segment in manifest.get("segments", []):
        if "cameraFrames" not in segment: continue
        rows = segment["cameraFrames"]
        Lab.require(isinstance(rows, list) and rows
                    and len(rows) <= segment["lastFrameSequence"] - segment["firstFrameSequence"] + 1,
                    "native video camera frame count differs")
        previous = segment["firstFrameSequence"] - 1
        for row in rows:
            Lab.require(isinstance(row, dict) and set(row) == {"frameSequence", "camera"},
                        "native video camera frame fields differ")
            Lab.integer(row["frameSequence"], segment["firstFrameSequence"],
                        segment["lastFrameSequence"], "native video camera sequence")
            Lab.require(row["frameSequence"] > previous, "native video camera sequence regressed")
            validate_native_camera(row["camera"])
            previous = row["frameSequence"]
        Lab.require(rows[0]["frameSequence"] == segment["firstFrameSequence"]
                    and previous == segment["lastFrameSequence"],
                    "native video camera endpoints differ")


def publish_video_with_cameras(relay, manifest, *, now=None):
    """Carry verified frame labels through the pinned legacy video byte relay."""
    validate_video_camera_frames(manifest)
    # The relay checks the same fMP4 bytes before copying them, but discards
    # media_info's actual trun sample count. Check that count before admitting
    # labels or advancing its publication state. Frame sequence may have gaps
    # when captures were dropped before encoding.
    labeled = [segment for segment in manifest["segments"] if "cameraFrames" in segment]
    if labeled:
        parser = type(relay).publish.__globals__
        Lab.require(all(callable(parser.get(name)) for name in ("init_info", "media_info"))
                    and "MAX_INIT" in parser and "MAX_MEDIA" in parser
                    and manifest.get("init") is not None,
                    "native video camera byte parser unavailable")
        defaults = parser["init_info"](relay.data(manifest["init"], parser["MAX_INIT"]), manifest)
        for segment in labeled:
            source = {key: value for key, value in segment.items() if key != "cameraFrames"}
            count = parser["media_info"](relay.data(source, parser["MAX_MEDIA"]), source, defaults)
            Lab.require(len(segment["cameraFrames"]) == count,
                        "native video camera encoded sample count differs")
    # The installed source relay owns fMP4 bytes, clocks, retention and file
    # identity. Its pinned schema predates cameraFrames, so give it exactly its
    # original descriptor and restore only the independently checked labels.
    source_segments = manifest["segments"]
    relay_manifest = {**manifest, "segments": [
        {key: value for key, value in segment.items() if key != "cameraFrames"}
        for segment in source_segments]}
    published = relay.publish(relay_manifest, now=now)
    expected = {**relay_manifest, "schema": "mousecat.native-video/1"}
    Lab.require(published == expected, "native video relay changed source descriptors")
    segments = []
    for source, accepted in zip(source_segments, published["segments"]):
        row = dict(accepted)
        if "cameraFrames" in source: row["cameraFrames"] = source["cameraFrames"]
        segments.append(row)
    return {**published, "segments": segments}


def load_video_module(watcher):
    """Reuse the installed bridge's byte/MP4 validator, with explicit provenance."""
    path = Path(watcher).resolve().with_name("native_video.py")
    Lab.require(path.is_file() and not path.is_symlink(), "native video bridge unavailable")
    spec = importlib.util.spec_from_file_location("sao_participant_native_video", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module, {"file": str(path), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def register_feed(registry, view_id, label, project_ref, destination, session):
    """Use the existing registry lock and atomic replace; preserve all other rows."""
    Lab.require(isinstance(view_id, str) and re.fullmatch(r"[a-z0-9][a-z0-9-]{0,79}", view_id),
                "invalid Mousecat participant view id")
    text(label, 160); canonical_uuid(session)
    if project_ref is not None: text(project_ref, 160)
    registry = Path(registry)
    Lab.require(not registry.is_symlink(), "unsafe Mousecat participant registry")
    registry.parent.mkdir(parents=True, exist_ok=True)
    lock = registry.with_name(registry.name + ".lock")
    Lab.require(not lock.is_symlink(), "unsafe Mousecat participant registry lock")
    with lock.open("a+b") as lease:
        if lease.seek(0, 2) == 0: lease.write(b"0"); lease.flush()
        lease.seek(0)
        if os.name == "nt":
            import msvcrt
            msvcrt.locking(lease.fileno(), msvcrt.LK_LOCK, 1)
        else:
            import fcntl
            fcntl.flock(lease, fcntl.LOCK_EX)
        try:
            rows = read(registry)[1] if registry.exists() else []
            Lab.require(isinstance(rows, list) and len(rows) <= MAX_NATIVE_VIEWS
                        and all(isinstance(row, dict) and isinstance(row.get("id"), str) for row in rows),
                        "invalid Mousecat participant registry")
            Lab.require(len({row["id"] for row in rows}) == len(rows),
                        "duplicate Mousecat participant registry ids")
            row = {"id": view_id, "label": label, "directory": str(Path(destination).resolve()), "sessionId": session}
            if project_ref is not None: row["projectRef"] = project_ref
            rows = [row, *(old for old in rows if old["id"] != view_id)]
            Lab.require(len(rows) <= MAX_NATIVE_VIEWS, "Mousecat participant registry is full")
            atomic(registry, rows)
        finally:
            lease.seek(0)
            if os.name == "nt": msvcrt.locking(lease.fileno(), msvcrt.LK_UNLCK, 1)
            else: fcntl.flock(lease, fcntl.LOCK_UN)


class ParticipantFeed:
    def __init__(self, run, destination, receipt, study_id, video_module=None):
        self.run, self.destination = Path(run).resolve(), Path(destination).resolve()
        self.receipt = validate_receipt(receipt)
        self.session, self.study_id = receipt["sessionId"], canonical_uuid(study_id)
        self.native = self.run / "attempts/0001/native-view"
        self.destination.mkdir(parents=True, exist_ok=False)
        (self.destination / "commands").mkdir()
        self.video = video_module.VideoRelay(self.native, self.destination) if video_module else None
        self.sequence = 0
        self.body_sequence = 0
        self.last_input = self.previous_frame = self.previous_body = self.identity = None
        self.previous_video = self.video_view = None
        self.receipt_version = None
        self.images = {}

    def run_receipt(self):
        path = self.run / "run.json"
        for _ in range(MAX_RUN_READ_ATTEMPTS):
            before = source_version(path, MAX_RUN_JSON)
            if before == self.receipt_version: return self.receipt
            _, value = read(path, MAX_RUN_JSON)
            after = source_version(path, MAX_RUN_JSON)
            if before != after: continue
            validate_receipt(value, self.session)
            Lab.require(value["pid"] == self.receipt["pid"], "participant producer PID changed")
            if value.get("save") and self.identity:
                Lab.require(value["save"] == self.identity[0], "participant receipt save changed")
            self.receipt = value
            self.receipt_version = after
            return value
        # No unstable source acquires cached ownership. The supervisor retries
        # on its next source poll while input and stop checks keep their cadence.
        raise PermissionError("participant run receipt changed during every read")

    def publication_sources(self):
        return (source_version(self.run / "run.json", MAX_RUN_JSON),
                source_version(self.native / "native.json"),
                source_version(self.native.parent / "participant-state.json", 64 * 1024, optional=True),
                source_version(self.native / "latest-video.json", optional=True))

    def frame(self, *, now=None):
        now = int(time.time() * 1000) if now is None else now
        raw, value = read(self.native / "native.json")
        required = {"schema", "sequence", "observerSequence", "capturedAtUnixMs", "hours", "image"}
        Lab.require(isinstance(value, dict) and required <= set(value) <= required | {"participant", "captureContext", "nativeCamera"}
                    and value["schema"] == "sao-native-viewport/1", "participant frame fields differ")
        Lab.integer(value["sequence"], 1, 2**53 - 1, "participant pixel sequence")
        Lab.integer(value["observerSequence"], 0, 0, "participant observer sequence")
        Lab.integer(value["capturedAtUnixMs"], 1, now + 2000, "participant pixel time")
        number(value["hours"])
        if "nativeCamera" in value: validate_native_camera(value["nativeCamera"])
        if "participant" in value: validate_body(value["participant"], self.receipt, now=now)
        if "captureContext" in value:
            context = validate_capture_context(value["captureContext"], self.receipt)
            Lab.require("participant" in value, "native pixel participant context unavailable")
            Lab.require(context["worldHours"] == (value["hours"] if context["worldClock"] == "observed" else None),
                        "native pixel world clock differs")
            if context["worldClock"] == "unavailable":
                Lab.require(value["hours"] == 0, "native pixel unavailable clock placeholder differs")
            participant = value["participant"]
            Lab.require(context["bodyObserved"] == ("body" in participant)
                        and (context["binding"] == "persisted") == participant["ready"],
                        "native pixel body binding differs")
            if participant["ready"]:
                Lab.require(context["save"] == participant["save"]
                            and context["playerIndex"] == participant["playerIndex"]
                            and context["playerSqlId"] == participant["playerSqlId"],
                            "native pixel persisted identity differs")
        descriptor = value["image"]
        Lab.require(isinstance(descriptor, dict) and set(descriptor) == {"file", "sha256", "width", "height"}
                    and re.fullmatch(r"study-live-\d{16}\.png", str(descriptor["file"]))
                    and re.fullmatch(r"[0-9a-f]{64}", str(descriptor["sha256"])), "participant image descriptor differs")
        Lab.integer(descriptor["width"], 1, 4096, "participant image width")
        Lab.integer(descriptor["height"], 1, 2160, "participant image height")
        if self.previous_frame:
            previous_raw, previous = self.previous_frame
            Lab.require(value["sequence"] >= previous["sequence"]
                        and value["capturedAtUnixMs"] >= previous["capturedAtUnixMs"], "participant pixels regressed")
            Lab.require(value["sequence"] != previous["sequence"] or raw == previous_raw,
                        "participant pixel sequence reused")
            before, after = previous.get("captureContext"), value.get("captureContext")
            if before is not None and after is not None:
                Lab.require(after["captureEpoch"] >= before["captureEpoch"],
                            "native pixel capture epoch regressed")
                if after["captureEpoch"] == before["captureEpoch"]:
                    for field in ("saveMode", "save", "bodyObserved", "binding", "worldClock", "playerIndex", "playerSqlId"):
                        Lab.require(after.get(field) == before.get(field),
                                    "native pixel capture identity changed within epoch")
            if raw == previous_raw: return value
        path = self.native / descriptor["file"]
        Lab.require(path.resolve().parent == self.native and not path.is_symlink() and path.is_file()
                    and 24 <= path.stat().st_size <= MAX_IMAGE, "unsafe participant image")
        data = path.read_bytes()
        Lab.require(len(data) <= MAX_IMAGE and hashlib.sha256(data).hexdigest() == descriptor["sha256"],
                    "participant pixels differ")
        import world_lab_run as Run
        Lab.require(Run.native_png(data) == (descriptor["width"], descriptor["height"]),
                    "participant PNG dimensions differ")
        name = descriptor["file"]
        Lab.require(name not in self.images or self.images[name] == descriptor, "participant image name reused")
        if name not in self.images:
            target = self.destination / name
            temporary = target.with_name(name + ".tmp")
            temporary.write_bytes(data); os.replace(temporary, target)
            self.images[name] = dict(descriptor)
        self.previous_frame = raw, value
        while len(self.images) > 8:
            oldest = next(iter(self.images))
            self.images.pop(oldest); (self.destination / oldest).unlink(missing_ok=True)
        return value

    def body(self, *, now=None):
        path = self.run / "attempts/0001/participant-state.json"
        if not path.exists(): return None
        raw, value = read(path, 64 * 1024)
        validate_body(value, self.receipt, now=now)
        if self.previous_body:
            previous_raw, previous = self.previous_body
            Lab.require(value["capturedAtUnixMs"] >= previous["capturedAtUnixMs"], "participant body clock regressed")
            Lab.require(value["capturedAtUnixMs"] != previous["capturedAtUnixMs"] or raw == previous_raw,
                        "participant body clock reused")
            if value["ready"] and previous["ready"]:
                Lab.require(value["worldHours"] >= previous["worldHours"], "participant world clock regressed")
        if value["ready"]:
            identity = (value["save"], value["playerIndex"], value["playerSqlId"])
            Lab.require(self.identity is None or self.identity == identity, "participant body identity changed")
            self.identity = identity
        if self.previous_body is None or raw != self.previous_body[0]: self.body_sequence += 1
        self.previous_body = raw, value
        return value

    def publish(self, study, acknowledged=0, result=None, *, now=None):
        import world_lab_session as Session
        Session.public_state(study)
        Lab.require(study["id"] == self.study_id and study["attempt"] == 1 and not study["autoContinue"],
                    "participant study binding differs")
        self.run_receipt()
        frame, body = self.frame(now=now), self.body(now=now)
        ended = study["status"] in ("closed", "failed")
        people = []
        summary = "Native player view. Keyboard and mouse input stay with the visible game. Unreviewed."
        if body and body["ready"]:
            person_id = f"native-player-{body['playerIndex']}-sql-{body['playerSqlId']}"
            people = [{"id": person_id, "label": body["body"]["label"],
                "summary": f"Native participant sample at world hour {body['worldHours']:.3f}; independently timed from video.",
                "sections": [{"id": "participant-body", "label": "Native body", "source": "Native participant adapter",
                    "perspective": "Engine body sample", "status": "available", "message": "This sample has its own observation clock.",
                    "rows": [{"label": "Position", "value": ", ".join(str(body['body'][key]) for key in ('x', 'y', 'z'))},
                        {"label": "Alive", "value": str(body['alive']).lower()},
                        {"label": "Observed at", "value": str(body['capturedAtUnixMs'])},
                        {"label": "Native slot / SQL id", "value": f"{body['playerIndex']} / {body['playerSqlId']}"}]}]}]
        else: summary += " Participant identity awaits a native body sample."
        if ended: summary += " This attempt has ended; its save is retained."
        video = None
        if self.video and (self.native / "latest-video.json").exists():
            video_raw, source_video = read(self.native / "latest-video.json")
            for segment in source_video.get("segments", []):
                Lab.require(type(segment.get("observerSequence")) is int and segment["observerSequence"] == 0
                            and segment.get("sites") == [], "participant video contains observer regions")
                crops = segment.get("crops", [])
                # This source crop identifies the whole native framebuffer.
                # It does not assert a body location or an observer camera.
                expected = {"id": "participant-viewport", "slot": 0, "left": 0, "top": 0,
                            "width": source_video.get("width"), "height": source_video.get("height")}
                Lab.require(crops == [] or (isinstance(crops, list) and len(crops) == 1
                            and isinstance(crops[0], dict) and set(crops[0]) == set(expected)
                            and all(type(crops[0][key]) is int for key in ("slot", "left", "top", "width", "height"))
                            and type(expected["width"]) is int and 1 <= expected["width"] <= 4096
                            and type(expected["height"]) is int and 1 <= expected["height"] <= 2160
                            and crops[0] == expected), "participant video viewport crop differs")
            if video_raw != self.previous_video:
                self.video_view = publish_video_with_cameras(self.video, source_video, now=now)
                self.previous_video = video_raw
            video = self.video_view
        snapshot = {"schema": "mousecat.native-view/1", "sessionId": self.session,
            "sequence": self.sequence + 1, "capturedAtUnixMs": frame["capturedAtUnixMs"],
            "image": frame["image"], "state": "ended" if ended else "running",
            "title": "Player study", "summary": summary, "people": people, "lastCommandSequence": acknowledged,
            "commandActions": [] if ended else ["checkpoint", "stop"],
            "camera": {"mode": "automatic", "personIds": [], "summary": "Whole native framebuffer; native player camera"},
            "study": {key: study[key] for key in STUDY_FIELDS}}
        if "nativeCamera" in frame:
            snapshot["nativeCamera"] = frame["nativeCamera"]
        if people:
            snapshot["inspection"] = {"sequence": self.body_sequence, "capturedAtUnixMs": body["capturedAtUnixMs"],
                "worldHours": body["worldHours"], "status": "available", "message": "Participant sample is independent of the video clock.",
                "omittedPeople": 0, "omittedEvents": 0}
        if video is not None: snapshot["video"] = video
        if result is not None: snapshot["commandResult"] = dict(result)
        comparison = encoded({key: value for key, value in snapshot.items() if key != "sequence"})
        if comparison == self.last_input: return False
        self.sequence += 1
        snapshot["sequence"] = self.sequence
        atomic(self.destination / "latest.json", snapshot)
        self.last_input = comparison
        return True
