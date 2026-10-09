#!/usr/bin/env python3
"""Controlled menu/body stream sidecars through the real archive producer."""
from __future__ import annotations

import argparse
import base64
import copy
import json
from pathlib import Path
import tempfile
import uuid

import world_lab_video_archive as Archive
import world_lab_video_archive_test as Fixtures


def check(label, condition):
    assert condition, label


def refused(label, operation):
    try:
        operation()
    except (ValueError, OSError):
        return
    raise AssertionError(label)


def context(session, stream, pid, epoch, *, bound):
    value = {"schema": "sao.native-capture-context/1", "namespace": "native-play",
             "sessionId": session, "pid": pid, "attempt": 1, "captureEpoch": epoch,
             "streamId": stream, "saveMode": "Sandbox" if bound else None,
             "save": "selected-in-game" if bound else None, "bodyObserved": bound,
             "binding": "persisted" if bound else "unbound",
             "worldClock": "observed" if bound else "unavailable",
             "worldHours": 2.25 if bound else None}
    if bound:
        value.update(playerIndex=0, playerSqlId=17)
    return value


def run(root):
    recording, pid = str(uuid.uuid4()), 27003
    owner = Archive.Archive(root, recording, run_name="participant-run", min_free_bytes=0)
    owner.initialize()
    originals, videos, contexts, session = {}, [], [], None
    for ordinal, bound in enumerate((False, True), 1):
        source, video, current_session = Fixtures.fixture(root, run_name="participant-run")
        session = session or current_session
        check("one native session through menu/body", current_session == session)
        receipt = Archive.read(root / "participant-run/run.json")[1]
        receipt.update(launchMode="native-menu", pid=pid, packageSha256=None,
                       definitionSha256=None)
        Archive.atomic(root / "participant-run/run.json", receipt)
        video.update(mimeType="video/mp4", codecs="avc1.640033", width=2560,
                     height=720, fps=120, message="", stats={"capturedFrames": 20,
                     "encodedFrames": 20, "droppedFrames": 0})
        native = context(session, video["streamId"], pid, ordinal, bound=bound)
        name = f"video-{video['streamId']}-native-context.json"
        Archive.atomic(source / name, native)
        original = (source / name).read_bytes()
        Fixtures.publish(source, video, [1], "ended")
        video["segments"][0].update(sites=[], crops=[])
        Archive.atomic(source / "latest-video.json", video)
        if ordinal == 1:
            (source / name).unlink()
            refused("menu stream without a sidecar is refused before retention", owner.poll)
            (source / name).write_bytes(original)
        else:
            Archive.atomic(source / name, {**native, "pid": pid + 1})
            refused("body stream with another native process is refused", owner.poll)
            (source / name).write_bytes(original)
        owner.poll()
        originals[video["streamId"]] = original
        videos.append(copy.deepcopy(video))
        contexts.append(native)

    receipt = Archive.read(root / "participant-run/run.json")[1]
    receipt["status"] = "completed"
    Archive.atomic(root / "participant-run/run.json", receipt)
    owner.poll()
    feed = root / "feeds/0001"
    feed.mkdir(parents=True)
    png = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNwS2n6DwAETAIsoJ1HtQAAAABJRU5ErkJggg==")
    (feed / "frame.png").write_bytes(png)
    Archive.atomic(feed / "latest.json", {"schema": "mousecat.native-view/1",
        "sessionId": session, "sequence": 1, "capturedAtUnixMs": 1500,
        "image": {"file": "frame.png", "sha256": Archive.sha(png), "width": 1, "height": 1},
        "state": "ended", "title": "Native context fixture", "summary": "Controlled stream rollover",
        "people": [], "lastCommandSequence": 0,
        "recording": {"schema": "mousecat.native-recording/1", "id": recording, "attempt": 1,
                      "mode": "interactive", "status": "ended"},
        "video": {**videos[-1], "schema": "mousecat.native-video/1"},
        "videoCaptureContext": contexts[-1]})
    owner.finished = True
    owner.publish()
    view = Archive.read(feed / "latest.json")[1]
    catalog = Archive.read(feed / view["archiveCatalog"]["file"])[1]
    check("both ended streams appear in native recording order",
          [row["streamId"] for row in catalog["streams"]]
          == [video["streamId"] for video in videos])
    for ordinal, row in enumerate(catalog["streams"]):
        index = Archive.read(feed / row["indexFile"])[1]
        descriptor = index.get("nativeCaptureContext")
        name = f"video-{row['streamId']}-native-context.json"
        archived = root / "video-archive/0001" / row["streamId"] / name
        check("stream sidecar retained and exported unchanged " + str(ordinal),
              descriptor == {"file": name, "sha256": Archive.sha(originals[row["streamId"]])}
              and archived.read_bytes() == (feed / name).read_bytes()
              == originals[row["streamId"]])
        report = Archive.read(archived.parent / "stream.json")[1]
        check("stream report binds original sidecar " + str(ordinal),
              report["nativeCaptureContext"] == descriptor)
    check("menu context stays unbound while body context names native identity",
          contexts[0]["worldHours"] is None and contexts[0]["binding"] == "unbound"
          and contexts[1]["playerSqlId"] == 17)
    stable_view = (feed / "latest.json").read_bytes()
    Archive.project_archive(root, feed)
    check("repeat projection preserves catalog pointer", (feed / "latest.json").read_bytes() == stable_view)
    target = feed / f"video-{videos[0]['streamId']}-native-context.json"
    original = target.read_bytes()
    target.write_bytes(b"altered sidecar")
    refused("altered retired context refused", lambda: Archive.project_archive(root, feed))
    target.write_bytes(original)
    check("inverse restoration retains original sidecar", target.read_bytes() == original)

    return {"schema": "sao.native-video-archive-context-proof/1", "status": "PASS_SOURCE_CONTROLLED",
            "streamCount": 2, "menuContext": contexts[0], "bodyContext": contexts[1],
            "fixture": str(root), "mediaDecoded": False, "nativeGameRun": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--retain", type=Path)
    args = parser.parse_args()
    if args.retain:
        root = args.retain.resolve()
        if root.exists():
            raise ValueError("retained fixture destination must be new")
        root.mkdir(parents=True)
        result = run(root)
    else:
        with tempfile.TemporaryDirectory() as directory:
            result = run(Path(directory))
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
