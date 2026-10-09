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
from decimal import Decimal
import struct

import world_lab_participant_feed as ParticipantFeed

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


def read_capture_context(path):
    """Read one immutable native-play sidecar without ambiguous JSON fields."""
    raw, _ = read(path, 64 * 1024)
    def unique(pairs):
        value = {}
        for key, item in pairs:
            if key in value:
                raise ValueError("duplicate native capture context field")
            value[key] = item
        return value
    value = json.loads(raw, object_pairs_hook=unique,
                       parse_constant=lambda _: (_ for _ in ()).throw(ValueError("nonfinite native capture context")))
    if not isinstance(value, dict):
        raise ValueError("native capture context is not an object")
    return raw, value


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


def canonical_uuid(value):
    try:
        return type(value) is str and str(uuid.UUID(value)) == value
    except (ValueError, TypeError, AttributeError):
        return False


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
    ParticipantFeed.validate_video_camera_frames(value)
    return stream


def camera_video_module(session, run_name, attempt, session_id, study_id, *, receipt=None):
    """Recover the exact recorded source parser only for camera-labeled media."""
    if receipt is None:
        _, receipt = read(session / run_name / "run.json")
    if (receipt.get("sessionId") != session_id or receipt.get("launchNumber") != attempt):
        raise ValueError("native camera parser run owner differs")
    pin = receipt.get("videoBridge")
    if pin is None and run_name == "participant-run":
        _, bridge = read(session / "participant-bridge.json")
        if (bridge.get("studyId") != study_id or bridge.get("sessionId") != session_id
                or bridge.get("attempt") != attempt):
            raise ValueError("native camera parser bridge owner differs")
        pin = bridge.get("videoValidator")
    if (not isinstance(pin, dict) or set(pin) != {"file", "sha256"}
            or not isinstance(pin["file"], str) or not Path(pin["file"]).is_absolute()
            or not isinstance(pin["sha256"], str) or len(pin["sha256"]) != 64):
        raise ValueError("native camera parser provenance is absent")
    module, current = ParticipantFeed.load_video_module(Path(pin["file"]).with_name("world_watch.py"))
    if current != pin:
        raise ValueError("native camera parser source changed")
    return module


def check_camera_sample_count(module, defaults, descriptor, data):
    if "cameraFrames" not in descriptor:
        return
    original = {key: value for key, value in descriptor.items() if key != "cameraFrames"}
    count = module.media_info(data, original, defaults)
    if len(descriptor["cameraFrames"]) != count:
        raise ValueError("native video camera encoded sample count differs")


def canonical_projection(value):
    """Sorted source JSON; generation encodes numbers independently of JSON text."""
    def normalize(item):
        if isinstance(item, dict):
            return "{" + ",".join(json.dumps(key, ensure_ascii=False) + ":" + normalize(item[key]) for key in sorted(item)) + "}"
        if isinstance(item, list):
            return "[" + ",".join(normalize(child) for child in item) + "]"
        if type(item) is float:
            if not math.isfinite(item): raise ValueError("nonfinite archive projection number")
            if item == 0: return "0"
            if 1e-6 <= abs(item) < 1e21:
                return format(Decimal(repr(item)), "f").rstrip("0").rstrip(".") if "." in format(Decimal(repr(item)), "f") else format(Decimal(repr(item)), "f")
            mantissa, exponent = repr(item).split("e") if "e" in repr(item) else (repr(item), "0")
            return mantissa.removesuffix(".0") + "e" + ("+" if int(exponent) >= 0 else "-") + str(abs(int(exponent)))
        return json.dumps(item, ensure_ascii=False, allow_nan=False, separators=(",", ":"))
    return normalize(value).encode("utf-8")


def projection_generation(value):
    def numeric_bits(item):
        if type(item) in (int, float):
            if not math.isfinite(item): raise ValueError("nonfinite archive generation number")
            return {"@number": struct.pack(">d", 0 if item == 0 else item).hex()}
        if isinstance(item, list): return [numeric_bits(child) for child in item]
        if isinstance(item, dict): return {key: numeric_bits(child) for key, child in item.items()}
        return item
    return sha(canonical_projection(numeric_bits({key: child for key, child in value.items() if key != "generation"})))


def immutable_projection(path, data):
    """Write an immutable feed artifact, or verify its already published bytes."""
    if path.exists():
        if path.is_symlink() or sharing_read(path.read_bytes) != data:
            raise ValueError("archive projection immutable target differs")
        return
    pending = path.with_name(path.name + "." + uuid.uuid4().hex + ".tmp")
    pending.write_bytes(data)
    try:
        os.replace(pending, path)
    finally:
        if pending.exists(): pending.unlink()


def terminal_video(source, stream):
    """Return an actual ended producer manifest, if this stream has one."""
    terminal = None
    for path in sorted((source / "manifests").glob("*.json")):
        raw, value = read(path)
        if path.stem != sha(raw) or validate_manifest(value) != stream:
            raise ValueError("archive projection manifest differs")
        if value.get("state") == "ended":
            if terminal is not None and terminal != value:
                raise ValueError("archive projection terminal manifest differs")
            terminal = value
    return {**terminal, "schema": "mousecat.native-video/1"} if terminal else None


def terminal_receipt_digest(source, provenance):
    digest = None
    for path in sorted((source.parent / "provenance").glob("*.json")):
        raw, receipt = read(path)
        if path.stem != sha(raw):
            raise ValueError("archive projection run receipt differs")
        if (all(receipt.get(key) == provenance.get(key) for key in
                ("sessionId", "launchNumber", "packageSha256", "definitionSha256"))
                and receipt.get("status") in ("completed", "failed", "incomplete")):
            digest = sha(raw)
    if digest is None:
        raise ValueError("archive projection lacks a terminal native run receipt")
    return digest


def project_stream(feed, view, study, attempt, stream, source, report, video, receipt_digest):
    """Verify and publish one stream's original media, pages and index bytes."""
    provenance = report["nativeProvenance"]
    formats = ("init", "mimeType", "codecs", "width", "height", "fps", "stats")
    rows, owners, terminal = {}, {}, None
    for path in sorted((source / "manifests").glob("*.json")):
        raw, manifest = read(path)
        digest = sha(raw)
        if path.stem != digest or validate_manifest(manifest) != stream:
            raise ValueError("archive projection manifest differs")
        if (manifest.get("init") or manifest["segments"]) and any(manifest.get(key) != video.get(key) for key in formats[:-1]):
            raise ValueError("archive projection format differs")
        if manifest.get("state") == "ended" and manifest.get("stats") == video.get("stats"):
            terminal = manifest
        for row in manifest["segments"]:
            number = row["sequence"]
            if number in rows and rows[number] != row:
                raise ValueError("archive projection descriptor was rewritten")
            rows[number], owners[number] = row, digest
    ordered = [rows[number] for number in sorted(rows)]
    if (terminal is None or not ordered or len(ordered) != report.get("retainedSegments")
            or ordered[-1] != video.get("segments", [None])[-1]
            or ordered[0] != report.get("firstSegment") or ordered[-1] != report.get("lastSegment")):
        raise ValueError("archive projection terminal coverage differs")
    linked, copied = 0, 0

    labeled = any("cameraFrames" in row for row in ordered)
    module = defaults = None
    if labeled:
        session = source.parents[2]
        run_name = "participant-run" if (session / "participant-run" / "run.json").is_file() else "native-run"
        retained_raw, retained_receipt = read(source.parent / "provenance" / (receipt_digest + ".json"))
        if sha(retained_raw) != receipt_digest:
            raise ValueError("archive projection camera receipt hash differs")
        module = camera_video_module(session, run_name, attempt, view["sessionId"], study["id"],
                                     receipt=retained_receipt)
        init_path = source / video["init"]["file"]
        if init_path.is_symlink() or init_path.stat().st_size > module.MAX_INIT:
            raise ValueError("unsafe archive projection camera initialization")
        init_bytes = sharing_read(init_path.read_bytes)
        if sha(init_bytes) != video["init"]["sha256"]:
            raise ValueError("archive projection camera initialization hash differs")
        defaults = module.init_info(init_bytes, video)

    # Verify every advertised byte before publishing any descriptor index.
    for row in [video["init"]] + ordered:
        original, target = source / row["file"], feed / row["file"]
        if original.is_symlink() or original.stat().st_size > 16 * 1024**2:
            raise ValueError("unsafe archive projection media")
        raw = sharing_read(original.read_bytes)
        if not raw or sha(raw) != row["sha256"]:
            raise ValueError("archive projection media hash differs")
        if module is not None and row is not video["init"]:
            check_camera_sample_count(module, defaults, row, raw)
        if target.exists():
            if target.is_symlink() or sha(sharing_read(target.read_bytes)) != row["sha256"]:
                raise ValueError("archive projection existing media differs")
        else:
            try:
                os.link(original, target); linked += 1
            except OSError:
                if shutil.disk_usage(feed).free - len(raw) < DEFAULT_MIN_FREE_BYTES:
                    raise OSError("archive projection free-space reserve reached")
                immutable_projection(target, raw); copied += 1
    groups = []
    for row in ordered:
        if not groups or len(groups[-1]) == 8 or row["sequence"] != groups[-1][-1]["sequence"] + 1:
            groups.append([])
        groups[-1].append(row)
    identity = {"sessionId": view["sessionId"], "studyId": study["id"], "attempt": attempt, "streamId": stream}
    pages = []
    for group in groups:
        page = {"schema": "mousecat.native-video-archive-page/1", **identity,
                "video": {**video, "segments": group},
                "sourceManifestDigests": sorted({owners[row["sequence"]] for row in group})}
        raw = canonical_projection(page) + b"\n"
        digest = sha(raw)
        name = f"archive-page-{stream}-{group[0]['sequence']}-{group[-1]['sequence']}-{digest}.json"
        immutable_projection(feed / name, raw)
        pages.append({"file": name, "sha256": digest, "firstSequence": group[0]["sequence"],
                      "lastSequence": group[-1]["sequence"], "ptsStartMs": group[0]["ptsStartMs"],
                      "ptsEndMs": group[-1]["ptsStartMs"] + group[-1]["durationMs"]})
    capture = report.get("nativeCaptureContext")
    if capture is not None:
        name = f"video-{stream}-native-context.json"
        if capture.get("file") != name or not isinstance(capture.get("sha256"), str):
            raise ValueError("archive projection native context descriptor differs")
        raw, context = read_capture_context(source / name)
        if sha(raw) != capture["sha256"]:
            raise ValueError("archive projection native context hash differs")
        receipt_raw, receipt = read(source.parent / "provenance" / (receipt_digest + ".json"))
        if sha(receipt_raw) != receipt_digest:
            raise ValueError("archive projection native receipt hash differs")
        ParticipantFeed.validate_capture_context(context, receipt, stream_id=stream)
        if stream == view["video"]["streamId"] and view.get("videoCaptureContext") != context:
            raise ValueError("archive projection final video context differs")
        immutable_projection(feed / name, raw)
    elif stream == view["video"]["streamId"] and view.get("videoCaptureContext") is not None:
        raise ValueError("archive projection final video context was not retained")
    index = {"schema": "mousecat.native-video-archive/1", "generationAlgorithm": "sha256-json-f64be/1", **identity,
             **{key: video[key] for key in formats}, "coverage": report["coverage"],
             "tailConfirmed": report["tailConfirmed"], "segmentCount": len(ordered),
             "ptsStartMs": ordered[0]["ptsStartMs"],
             "ptsEndMs": ordered[-1]["ptsStartMs"] + ordered[-1]["durationMs"],
             "sourceProvenance": {**{key: provenance[key] for key in
                 ("sessionId", "launchNumber", "packageSha256", "definitionSha256")}, "runReceiptSha256": receipt_digest},
             "lateAttachment": report["lateAttachment"], "missingSequences": report["missingSequences"],
             "ptsGaps": report["ptsGaps"], "pages": pages}
    if capture is not None:
        index["nativeCaptureContext"] = capture
    index["generation"] = projection_generation(index)
    return index, canonical_projection(index) + b"\n", {"generation": index["generation"],
        "segmentCount": len(ordered), "pageCount": len(pages), "linkedMedia": linked,
        "copiedMedia": copied, "ptsStartMs": index["ptsStartMs"], "ptsEndMs": index["ptsEndMs"]}


def project_archive(session_root, feed_root):
    """Publish source-bound stream indexes, then a complete ended-view catalog.

    Retired streams without an ended producer manifest remain in the retained
    source archive but receive no playback claim. A native recording advertises
    its immutable catalog only after every listed index and media byte exists.
    Existing single-stream studies retain their original index/view contract.
    """
    session, feed = Path(session_root).resolve(), Path(feed_root).resolve()
    if not feed.is_relative_to(session / "feeds"):
        raise ValueError("archive projection feed is outside its session")
    _, view = read(feed / "latest.json")
    video, study = view.get("video") or {}, view.get("recording") or view.get("study") or {}
    if view.get("state") != "ended" or video.get("state") != "ended":
        raise ValueError("archive projection requires an ended source")
    attempt, final_stream = study.get("attempt"), video.get("streamId")
    if (type(attempt) is not int or attempt < 1
            or not all(canonical_uuid(value) for value in
                       (view.get("sessionId"), study.get("id"), final_stream))):
        raise ValueError("archive projection attempt/stream differs")
    attempt_root = session / "video-archive" / f"{attempt:04d}"
    candidates, epochs = [], []
    for source in sorted(attempt_root.iterdir()):
        if not source.is_dir() or source.name == "provenance":
            continue
        if source.is_symlink() or not canonical_uuid(source.name):
            raise ValueError("unsafe archive projection stream")
        if not (source / "stream.json").exists():
            raise ValueError("archive projection stream report is absent")
        report_raw, report = read(source / "stream.json")
        provenance = report.get("nativeProvenance") or {}
        if (report.get("studyId") != study.get("id") or report.get("streamId") != source.name
                or report.get("attempt") != attempt or provenance.get("sessionId") != view.get("sessionId")
                or provenance.get("launchNumber") != attempt):
            raise ValueError("archive projection owner differs")
        report_digest = sha(report_raw)
        report_name = f"archive-report-{source.name}-{report_digest}.json"
        epochs.append({"streamId": source.name, "reportFile": report_name,
                       "reportSha256": report_digest, "reportBytes": report_raw,
                       "coverage": report.get("coverage"), "tailConfirmed": report.get("tailConfirmed"),
                       "lateAttachment": report.get("lateAttachment"),
                       "retainedSegments": report.get("retainedSegments"),
                       "firstCapturedAtUnixMs": (report.get("firstSegment") or {}).get("capturedAtUnixMs")})
        stream_video = terminal_video(source, source.name)
        if source.name == final_stream:
            if stream_video is None or stream_video.get("stats") != video.get("stats"):
                raise ValueError("archive projection terminal coverage differs")
            stream_video = video
        elif stream_video is None or not report.get("retainedSegments"):
            continue
        if report.get("firstSegment") is None:
            raise ValueError("archive projection stream lacks source clock")
        candidates.append((report["firstSegment"]["capturedAtUnixMs"], source.name,
                           source, report, stream_video, terminal_receipt_digest(source, provenance)))
    if not any(item[1] == final_stream for item in candidates):
        raise ValueError("archive projection final stream unavailable")
    candidates.sort(key=lambda item: (item[0], item[1] == final_stream, item[1]))
    if candidates[-1][1] != final_stream:
        raise ValueError("archive projection final stream order differs")
    recording_owner = bool(view.get("recording"))
    catalog_enabled = recording_owner or len(candidates) > 1
    published = []
    totals = {"linkedMedia": 0, "copiedMedia": 0}
    final_result = None
    for _, stream, source, report, stream_video, receipt_digest in candidates:
        index, index_raw, result = project_stream(feed, view, study, attempt, stream, source,
                                                   report, stream_video, receipt_digest)
        if catalog_enabled:
            name = f"archive-index-{stream}.json"
            immutable_projection(feed / name, index_raw)
            published.append({"streamId": stream, "indexFile": name,
                              "indexSha256": sha(index_raw), "generation": index["generation"]})
        for key in totals:
            totals[key] += result[key]
        if stream == final_stream:
            final_result = result
            atomic(feed / "archive-index.json", index)
    if catalog_enabled:
        playable = {row["streamId"] for row in published}
        aggregate_epochs = []
        for epoch in epochs:
            immutable_projection(feed / epoch["reportFile"], epoch["reportBytes"])
            aggregate_epochs.append({key: value for key, value in epoch.items() if key != "reportBytes"}
                                    | {"published": epoch["streamId"] in playable})
        aggregate_epochs.sort(key=lambda epoch: (epoch["firstCapturedAtUnixMs"] is None,
            epoch["firstCapturedAtUnixMs"] if epoch["firstCapturedAtUnixMs"] is not None else 0,
            epoch["streamId"]))
        unavailable = sum(not epoch["published"] for epoch in aggregate_epochs)
        aggregate = {"schema": "mousecat.native-video-archive-coverage/1",
            "epochCount": len(aggregate_epochs), "publishedCount": len(published),
            "unavailableCount": unavailable,
            "complete": bool(aggregate_epochs) and all(
                epoch["published"] and epoch["coverage"] == "complete-published-segments"
                and epoch["tailConfirmed"] is True and epoch["lateAttachment"] is False
                and type(epoch["retainedSegments"]) is int and epoch["retainedSegments"] > 0
                for epoch in aggregate_epochs),
            "epochs": aggregate_epochs}
        catalog = {"schema": "mousecat.native-video-archive-catalog/1",
                   "sessionId": view["sessionId"],
                   "recordingId" if recording_owner else "studyId": study["id"],
                   "attempt": attempt, "finalStreamId": final_stream, "streams": published}
        if recording_owner:
            catalog["aggregateCoverage"] = aggregate
        catalog_raw = canonical_projection(catalog) + b"\n"
        immutable_projection(feed / "archive-catalog.json", catalog_raw)
        pointer = {"file": "archive-catalog.json", "sha256": sha(catalog_raw)}
        if view.get("archiveCatalog") not in (None, pointer):
            raise ValueError("archive projection catalog pointer differs")
        if view.get("archiveCatalog") != pointer:
            current_raw, current = read(feed / "latest.json")
            if current != view:
                raise ValueError("archive projection ended view changed")
            sequence = view.get("sequence")
            if type(sequence) is not int or sequence < 1 or sequence >= 2**53 - 1:
                raise ValueError("archive projection view sequence unavailable")
            atomic(feed / "latest.json", {**view, "sequence": sequence + 1,
                                           "archiveCatalog": pointer})
    return {**final_result, **totals, "streamCount": len(candidates),
            "unavailableRetiredStreams": len(epochs) - len(candidates)}


def recording_catalog(session, feed, view):
    """Verify a published recording catalog and every aggregate source report."""
    pointer = view.get("archiveCatalog")
    if pointer is None:
        return None, None
    if (not isinstance(pointer, dict) or pointer.get("file") != "archive-catalog.json"
            or not isinstance(pointer.get("sha256"), str) or len(pointer["sha256"]) != 64):
        raise ValueError("native recording catalog pointer differs")
    raw, catalog = read(feed / pointer["file"])
    recording = view.get("recording") or {}
    video = view.get("video") or {}
    if (sha(raw) != pointer["sha256"] or catalog.get("schema") != "mousecat.native-video-archive-catalog/1"
            or catalog.get("sessionId") != view.get("sessionId")
            or catalog.get("recordingId") != recording.get("id")
            or catalog.get("attempt") != recording.get("attempt")
            or catalog.get("finalStreamId") != video.get("streamId")):
        raise ValueError("native recording catalog owner or hash differs")
    aggregate = catalog.get("aggregateCoverage") or {}
    epochs, rows = aggregate.get("epochs"), catalog.get("streams")
    if (aggregate.get("schema") != "mousecat.native-video-archive-coverage/1"
            or not isinstance(epochs, list) or not epochs or not isinstance(rows, list) or not rows
            or aggregate.get("epochCount") != len(epochs)
            or aggregate.get("publishedCount") != len(rows)):
        raise ValueError("native recording aggregate coverage differs")
    published = set()
    for row in rows:
        stream = row.get("streamId")
        if (not canonical_uuid(stream) or stream in published
                or row.get("indexFile") != f"archive-index-{stream}.json"):
            raise ValueError("native recording playable stream identity differs")
        index_raw, index = read(feed / row["indexFile"], 4 * 1024**2)
        if (sha(index_raw) != row.get("indexSha256") or index.get("generation") != row.get("generation")
                or index.get("sessionId") != view.get("sessionId")
                or index.get("studyId") != recording.get("id")
                or index.get("attempt") != recording.get("attempt")
                or index.get("streamId") != stream):
            raise ValueError("native recording playable stream hash differs")
        published.add(stream)
    seen = set()
    for epoch in epochs:
        stream = epoch.get("streamId")
        digest = epoch.get("reportSha256")
        if (not canonical_uuid(stream) or stream in seen or not isinstance(digest, str)
                or len(digest) != 64
                or epoch.get("reportFile") != f"archive-report-{stream}-{digest}.json"
                or epoch.get("published") is not (stream in published)):
            raise ValueError("native recording epoch identity differs")
        report_raw, report = read(feed / epoch["reportFile"], 4 * 1024**2)
        source_raw, _ = read(session / "video-archive" / f"{recording['attempt']:04d}" / stream / "stream.json",
                             4 * 1024**2)
        if (sha(report_raw) != digest or source_raw != report_raw
                or report.get("studyId") != recording.get("id")
                or report.get("streamId") != stream or report.get("attempt") != recording.get("attempt")
                or (report.get("nativeProvenance") or {}).get("sessionId") != view.get("sessionId")
                or any(epoch.get(key) != report.get(key) for key in
                       ("coverage", "tailConfirmed", "lateAttachment", "retainedSegments"))
                or epoch.get("firstCapturedAtUnixMs") !=
                    (report.get("firstSegment") or {}).get("capturedAtUnixMs")):
            raise ValueError("native recording epoch report hash differs")
        seen.add(stream)
    attempt_root = session / "video-archive" / f"{recording['attempt']:04d}"
    actual = {path.name for path in attempt_root.iterdir()
              if path.is_dir() and path.name != "provenance"}
    if actual != seen:
        raise ValueError("native recording aggregate omitted a retained stream")
    complete = len(seen) == len(published) and all(
        epoch["published"] and epoch["coverage"] == "complete-published-segments"
        and epoch["tailConfirmed"] is True and epoch["lateAttachment"] is False
        and type(epoch["retainedSegments"]) is int and epoch["retainedSegments"] > 0
        for epoch in epochs)
    if (aggregate.get("unavailableCount") != len(seen - published)
            or aggregate.get("complete") is not complete):
        raise ValueError("native recording aggregate verdict differs")
    return pointer, catalog


def publish_native_play_finality(session_root, feed_root):
    """Bind the post-close run and qualification without changing media claims."""
    session, feed = Path(session_root).resolve(), Path(feed_root).resolve()
    if not feed.is_relative_to(session / "feeds"):
        raise ValueError("native recording finality feed is outside its session")
    view_raw, view = read(feed / "latest.json")
    recording, video = view.get("recording") or {}, view.get("video") or {}
    run_raw, run = read(session / "participant-run" / "run.json", 4 * 1024**2)
    completion_raw, completion = read(session / "recording-completion.json", 4 * 1024**2)
    if (view.get("state") != "ended" or video.get("state") != "ended"
            or not canonical_uuid(view.get("sessionId"))
            or recording.get("schema") != "mousecat.native-recording/1"
            or recording.get("id") != view.get("sessionId") or recording.get("attempt") != 1
            or not canonical_uuid(video.get("streamId"))
            or run.get("sessionId") != view.get("sessionId") or run.get("launchNumber") != 1
            or run.get("terminal") != "native-exit" or run.get("status") not in ("completed", "failed", "incomplete")
            or completion.get("schema") != "sao.native-play-recording-completion/1"
            or completion.get("sessionId") != view.get("sessionId")
            or type(completion.get("complete")) is not bool
            or completion.get("nativeSaveReturned") is not run.get("nativeSaveReturned")):
        raise ValueError("native recording finality owner or terminal state differs")
    catalog_pointer, catalog = recording_catalog(session, feed, view)
    if completion["complete"] and (
            run["status"] != "completed" or catalog is None
            or catalog["aggregateCoverage"]["complete"] is not True):
        raise ValueError("native recording finality lacks complete aggregate coverage")
    final_row = next((row for row in catalog["streams"]
                      if row["streamId"] == video["streamId"]), None) if catalog else None
    if catalog is not None and final_row is None:
        raise ValueError("native recording final stream is absent from catalog")
    projection_receipt = None
    if final_row:
        _, final_index = read(feed / final_row["indexFile"], 4 * 1024**2)
        projection_receipt = (final_index.get("sourceProvenance") or {}).get("runReceiptSha256")
        if not isinstance(projection_receipt, str) or len(projection_receipt) != 64:
            raise ValueError("native recording projection receipt is absent")
    run_hash, completion_hash = sha(run_raw), sha(completion_raw)
    run_file = f"archive-run-final-{run_hash}.json"
    completion_file = f"archive-completion-final-{completion_hash}.json"
    immutable_projection(feed / run_file, run_raw)
    immutable_projection(feed / completion_file, completion_raw)
    finality = {"schema": "sao.native-play-archive-finality/1",
        "sessionId": view["sessionId"], "recordingId": recording["id"], "attempt": 1,
        "finalStreamId": video["streamId"],
        "catalog": catalog_pointer, "finalStreamIndexSha256": final_row["indexSha256"] if final_row else None,
        "projectionRunReceiptSha256": projection_receipt,
        "runReceipt": {"file": run_file, "sha256": run_hash, "status": run["status"]},
        "completionReceipt": {"file": completion_file, "sha256": completion_hash},
        "recordingComplete": completion["complete"],
        "qualification": {"complete": completion["complete"],
                          "reason": None if completion["complete"] else
                              str(completion.get("archiveError") or "recording qualification was incomplete")[:1000]}}
    finality_raw = canonical_projection(finality) + b"\n"
    immutable_projection(feed / "archive-finality.json", finality_raw)
    finality_pointer = {"file": "archive-finality.json", "sha256": sha(finality_raw)}
    latest_raw, latest = read(feed / "latest.json")
    if latest_raw != view_raw or latest.get("archiveFinality") not in (None, finality_pointer):
        raise ValueError("native recording ended view changed before finality publication")
    if latest.get("archiveFinality") is None:
        sequence = latest.get("sequence")
        if type(sequence) is not int or sequence < 1 or sequence >= 2**53 - 1:
            raise ValueError("native recording finality view sequence unavailable")
        atomic(feed / "latest.json", {**latest, "sequence": sequence + 1,
                                       "archiveFinality": finality_pointer})
    return finality_pointer, finality


class Archive:
    def __init__(self, session_root, study_id, max_bytes=DEFAULT_MAX_BYTES,
                 min_free_bytes=DEFAULT_MIN_FREE_BYTES, interval=.1, run_name="native-run"):
        if run_name not in ("native-run", "participant-run"):
            raise ValueError("invalid native archive run directory")
        self.run_name = run_name
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
        self.capture_receipts = {}
        self.total_bytes = 0
        self.error = None
        self.started = int(time.time() * 1000)
        self.finished = False
        self.lock = None
        self.body_samples = 0
        self.prior_failures = []
        self.projection_stamps = {}

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
            self.bind_capture_receipt(number, receipt)
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

    def bind_capture_receipt(self, attempt, receipt):
        if self.run_name != "participant-run" or receipt.get("launchMode") != "native-menu":
            return
        owner = (receipt.get("sessionId"), receipt.get("pid"), receipt.get("launchNumber"))
        if not canonical_uuid(owner[0]) or type(owner[1]) is not int or owner[1] <= 0 or owner[2] != attempt:
            raise ValueError("native capture receipt owner differs")
        previous = self.capture_receipts.get(attempt)
        if previous and owner != (previous["sessionId"], previous["pid"], previous["launchNumber"]):
            raise ValueError("native capture receipt owner changed")
        self.capture_receipts[attempt] = receipt

    def retain_capture_context(self, attempt, stream, destination, *, segments, restoring):
        receipt = self.capture_receipts.get(int(attempt))
        if receipt is None:
            return None  # Historical participant archives did not carry this sidecar.
        name = f"video-{stream}-native-context.json"
        source = destination / name if restoring else self.session / self.run_name / "attempts" / attempt / "native-view" / name
        if not source.exists():
            if segments:
                raise ValueError("native video segments lack their capture context")
            return None
        raw, context = read_capture_context(source)
        ParticipantFeed.validate_capture_context(context, receipt, stream_id=stream)
        if restoring and source.is_symlink():
            raise ValueError("retained native capture context is unsafe")
        if not restoring:
            self.store(destination / name, raw)
        return {"file": name, "sha256": sha(raw)}

    def accept(self, attempt, raw, value, destination, restoring=False):
        stream = validate_manifest(value)
        key = attempt + "/" + stream
        state = self.streams.setdefault(key, {"attempt": int(attempt), "streamId": stream,
            "segments": {}, "manifests": set(), "firstSeenAtUnixMs": int(time.time()*1000),
            "initialSequence": None, "producerState": "unknown", "lastSequence": 0,
            "producerStats": {}, "source": str(self.session / self.run_name / "attempts" / attempt / "native-view")})
        rows = value["segments"]
        capture = self.retain_capture_context(attempt, stream, destination,
                                              segments=bool(rows), restoring=restoring)
        if capture is not None:
            if state.get("nativeCaptureContext") not in (None, capture):
                raise ValueError("native stream capture context changed")
            state["nativeCaptureContext"] = capture
        if rows:
            state["initialSequence"] = min(state["initialSequence"] or rows[0]["sequence"], rows[0]["sequence"])
        labeled = any("cameraFrames" in row for row in rows)
        module = defaults = None
        if labeled:
            provenance = self.provenance.get(int(attempt)) or {}
            camera_receipt = None
            if restoring:
                for receipt_path in sorted((destination.parent / "provenance").glob("*.json")):
                    receipt_raw, candidate = read(receipt_path)
                    if receipt_path.stem != sha(receipt_raw):
                        raise ValueError("retained native camera receipt hash differs")
                    if (candidate.get("sessionId") != provenance.get("sessionId")
                            or candidate.get("launchNumber") != int(attempt)):
                        continue
                    if (camera_receipt is not None and camera_receipt.get("videoBridge") is not None
                            and candidate.get("videoBridge") is not None
                            and candidate["videoBridge"] != camera_receipt["videoBridge"]):
                        raise ValueError("retained native camera parser pin changed")
                    if camera_receipt is None or candidate.get("videoBridge") is not None:
                        camera_receipt = candidate
            module = camera_video_module(self.session, self.run_name, int(attempt),
                                         provenance.get("sessionId"), self.study_id,
                                         receipt=camera_receipt)
            init = value["init"]
            init_target = destination / init["file"]
            init_asset = init_target if init_target.exists() else Path(state["source"]) / init["file"]
            if init_asset.is_symlink() or init_asset.stat().st_size > module.MAX_INIT:
                raise ValueError("unsafe native camera initialization")
            init_bytes = sharing_read(init_asset.read_bytes)
            if sha(init_bytes) != init["sha256"]:
                raise ValueError("native camera initialization hash differs")
            defaults = module.init_info(init_bytes, value)
        for row in ([value["init"]] if value.get("init") else []) + rows:
            target = destination / row["file"]
            asset = target if target.exists() else Path(state["source"]) / row["file"]
            data = sharing_read(asset.read_bytes)
            if not data or sha(data) != row["sha256"]:
                raise ValueError("published video asset hash differs: " + row["file"])
            if module is not None and "sequence" in row:
                check_camera_sample_count(module, defaults, row, data)
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
            if b["sequence"] == a["sequence"] + 1 and abs(b["ptsStartMs"] - a["ptsStartMs"] - a["durationMs"]) > 1:
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
        body = self.sample(self.session / self.run_name / "cache/Lua/StudyWorldLive.json",
                           self.root / "body-inspection")
        if body is not None:
            self.body_samples += 1
        attempts = self.session / self.run_name / "attempts"
        for source in sorted(attempts.glob("[0-9][0-9][0-9][0-9]")):
            if source.is_symlink():
                raise ValueError("unsafe native attempt")
            target = self.root / source.name
            # Each immutable sample retains its own producer clock. Full run
            # provenance is archived on change, without copying saves or logs.
            report_path = source / "report.json"
            run_path = self.session / self.run_name / "run.json"
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
                    self.bind_capture_receipt(int(source.name), receipt)
                    self.provenance[int(source.name)] = {k: receipt.get(k) for k in
                        ("sessionId", "launchNumber", "packageSha256", "definitionSha256", "status", "terminal")}
            self.sample(source / "observer-state.json", target / "observer-mapping")
            manifest = source / "native-view/latest-video.json"
            if manifest.parent.is_symlink():
                raise ValueError("unsafe native view directory")
            # A participant geometry epoch relinquishes the shared manifest
            # before its asynchronous encoder drain. Its immutable terminal
            # manifest preserves that tail even after a new epoch takes over.
            retired = sorted([*manifest.parent.glob("video-*-tail-*.json"),
                              *manifest.parent.glob("video-*-closed.json")]) if self.run_name == "participant-run" else []
            manifests = [*retired, *([manifest] if manifest.exists() else [])]
            for current in manifests:
                raw, value = read(current)
                stream = validate_manifest(value)
                if current != manifest:
                    rows = value["segments"]
                    closed = current.name == f"video-{stream}-closed.json" and value.get("state") in ("ended", "failed")
                    tail = bool(rows) and current.name == f"video-{stream}-tail-{rows[-1]['sequence']:016d}.json" and value.get("state") in ("starting", "running")
                    if not (closed or tail):
                        raise ValueError("participant retired video manifest identity differs")
                state = self.streams.get(source.name + "/" + stream)
                if state and sha(raw) in state["manifests"]:
                    continue
                try:
                    self.accept(source.name, raw, value, target / stream)
                except FileNotFoundError:
                    # Live rolling assets can retire between metadata and byte
                    # reads; a durable terminal tail must remain available.
                    if current != manifest:
                        raise
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
                "source": self.run_name + "/cache/Lua/StudyWorldLive.json", "nativeAttemptAssigned": False,
                "clock": "source inspection.capturedAtUnixMs, hours, save and definitionSha256; separate from video"},
            "attempts": [{"attempt": number, "nativeProvenance": value,
                "video": "observed" if any(s["attempt"] == number for s in self.streams.values()) else "unavailable"}
                for number, value in sorted(self.provenance.items())],
            "streams": [{k: r[k] for k in ("attempt", "streamId", "coverage", "retainedSegments", "lateAttachment", "tailConfirmed")}
                        for r in reports]})
        # The watcher owns its registered feed. Add a normalized archive beside
        # an ended publication, never extend or rewrite its live rolling list.
        for feed in sorted((self.session / "feeds").glob("[0-9][0-9][0-9][0-9]")):
            if not (feed / "latest.json").exists():
                continue
            raw, view = read(feed / "latest.json")
            if view.get("state") != "ended" or (view.get("video") or {}).get("state") != "ended":
                continue
            # Native play can retire and drain a producer on the final process
            # boundary. The last bounded poll must finish before its catalog
            # claims which streams were available for this recording.
            if self.run_name == "participant-run" and not self.finished:
                continue
            key = f"{(view.get('recording') or view.get('study') or {}).get('attempt', 0):04d}/" + (view.get("video") or {}).get("streamId", "")
            if key in self.streams and (self.provenance.get(self.streams[key]["attempt"]) or {}).get("status") in ("completed", "failed", "incomplete"):
                stamp = (sha(raw), len(self.streams[key]["segments"]), self.streams[key]["producerState"])
                if self.projection_stamps.get(str(feed)) != stamp:
                    project_archive(self.session, feed)
                    self.projection_stamps[str(feed)] = stamp

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
