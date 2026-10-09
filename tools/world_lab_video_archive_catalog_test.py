#!/usr/bin/env python3
"""Synthetic multi-stream projection controls; fragment bytes are not decoded video."""
import argparse
import copy
from contextlib import nullcontext
import json
from pathlib import Path
import tempfile
import uuid

import world_lab_video_archive as Archive
import world_lab_video_archive_test as Fixtures


checks = []


def check(label, condition):
    checks.append({"name": label, "passed": bool(condition)})
    assert condition, label


def refused(label, operation):
    try:
        operation()
    except (ValueError, OSError):
        check(label, True)
    else:
        check(label, False)


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--retain", type=Path, help="new output directory for cross-consumer read-only controls")
arguments = parser.parse_args()
if arguments.retain:
    if arguments.retain.exists():
        raise ValueError("retained fixture directory must be new")
    arguments.retain.mkdir(parents=True)
first_fixture = nullcontext(str(arguments.retain)) if arguments.retain else tempfile.TemporaryDirectory()

with first_fixture as directory:
    root, recording = Path(directory), str(uuid.uuid4())
    owner = Archive.Archive(root, recording, run_name="participant-run", min_free_bytes=0)
    owner.initialize()
    values, original_media = [], {}
    source = root / "participant-run/attempts/0001/native-view"
    session = None
    for ordinal, producer_state in enumerate(("ended", "ended", "running", "ended"), 1):
        source, value, current_session = Fixtures.fixture(root, run_name="participant-run")
        session = session or current_session
        check("one source session across stream rollover " + str(ordinal), current_session == session)
        value.update(mimeType="video/mp4", codecs="avc1.640033", width=2560, height=720,
                     fps=120, message="Synthetic original-stream bytes")
        Fixtures.publish(source, value, [1, 2], producer_state)
        value["stats"] = {"capturedFrames": 30, "encodedFrames": 30, "droppedFrames": 0}
        for row in value["segments"]:
            row["capturedAtUnixMs"] += ordinal * 10000
            row["endCapturedAtUnixMs"] += ordinal * 10000
            row["sites"] = []
            row["crops"] = []
            original_media[row["file"]] = (source / row["file"]).read_bytes()
        Archive.atomic(source / "latest-video.json", value)
        if ordinal < 4:
            suffix = (f"tail-{value['segments'][-1]['sequence']:016d}"
                      if producer_state == "running" else "closed")
            (source / f"video-{value['streamId']}-{suffix}.json").write_bytes(
                (source / "latest-video.json").read_bytes())
        owner.poll()
        values.append(copy.deepcopy(value))
    receipt = json.loads((root / "participant-run/run.json").read_text())
    receipt.update(status="completed", packageSha256=None, definitionSha256=None)
    Archive.atomic(root / "participant-run/run.json", receipt)
    owner.poll()
    final = values[-1]
    feed = root / "feeds/0001"
    feed.mkdir(parents=True)
    view = {"schema": "mousecat.native-view/1", "state": "ended", "sessionId": session,
            "sequence": 1, "capturedAtUnixMs": 1000,
            "recording": {"id": recording, "attempt": 1},
            "video": {**final, "schema": "mousecat.native-video/1"}}
    Archive.atomic(feed / "latest.json", view)
    owner.publish()
    check("live collector does not advertise a still draining recording",
          "archiveCatalog" not in Archive.read(feed / "latest.json")[1])
    owner.finished = True
    owner.publish()
    check("catalog pointer advances publication sequence without changing source capture clock",
          Archive.read(feed / "latest.json")[1]["sequence"] == 2
          and Archive.read(feed / "latest.json")[1]["capturedAtUnixMs"] == 1000)
    check("bounded final collector publication advertises the catalog",
          "archiveCatalog" in Archive.read(feed / "latest.json")[1])
    source_snapshot = {str(path.relative_to(root)): Archive.sha(path.read_bytes())
                       for path in (root / "video-archive").rglob("*") if path.is_file()}
    result = Archive.project_archive(root, feed)
    _, published_view = Archive.read(feed / "latest.json")
    pointer = published_view["archiveCatalog"]
    catalog_raw, catalog = Archive.read(feed / pointer["file"])
    check("catalog pointer binds exact immutable bytes", pointer == {
        "file": "archive-catalog.json", "sha256": Archive.sha(catalog_raw)})
    check("recording ownership and final stream", catalog["sessionId"] == session
          and catalog["recordingId"] == recording and "studyId" not in catalog
          and catalog["attempt"] == 1 and catalog["finalStreamId"] == final["streamId"])
    expected = [values[i]["streamId"] for i in (0, 1, 3)]
    check("all ended menu game return streams ordered; unavailable retired stream omitted",
          [row["streamId"] for row in catalog["streams"]] == expected
          and result["streamCount"] == 3 and result["unavailableRetiredStreams"] == 1)
    aggregate = catalog["aggregateCoverage"]
    check("catalog binds all four source epochs and names the unavailable opening",
          aggregate["epochCount"] == 4 and aggregate["publishedCount"] == 3
          and aggregate["unavailableCount"] == 1 and aggregate["complete"] is False
          and {row["streamId"] for row in aggregate["epochs"]}
              == {value["streamId"] for value in values}
          and [row["streamId"] for row in aggregate["epochs"] if not row["published"]]
              == [values[2]["streamId"]])
    for epoch in aggregate["epochs"]:
        report = root / "video-archive/0001" / epoch["streamId"] / "stream.json"
        check("published report retains exact source hash " + epoch["streamId"],
              (feed / epoch["reportFile"]).read_bytes() == report.read_bytes()
              and Archive.sha(report.read_bytes()) == epoch["reportSha256"])
    check("recording catalog verifies against all retained source epochs",
          Archive.recording_catalog(root, feed, published_view)[1] == catalog)
    missing_catalog = copy.deepcopy(catalog)
    missing_catalog["aggregateCoverage"]["epochs"] = [row for row in aggregate["epochs"]
        if row["streamId"] != values[2]["streamId"]]
    missing_catalog["aggregateCoverage"].update(epochCount=3, unavailableCount=0,
                                                   complete=True)
    Archive.atomic(feed / "archive-catalog.json", missing_catalog)
    missing_raw = (feed / "archive-catalog.json").read_bytes()
    Archive.atomic(feed / "latest.json", {**published_view,
        "archiveCatalog": {"file": "archive-catalog.json", "sha256": Archive.sha(missing_raw)}})
    refused("omitted earlier source epoch rejected even with rehashed catalog",
            lambda: Archive.recording_catalog(root, feed, Archive.read(feed / "latest.json")[1]))
    (feed / "archive-catalog.json").write_bytes(catalog_raw)
    Archive.atomic(feed / "latest.json", published_view)
    check("inverse restores exact catalog pointer and bytes",
          (feed / "archive-catalog.json").read_bytes() == catalog_raw
          and Archive.read(feed / "latest.json")[1] == published_view)
    check("unavailable retired source remains explicit in original archive",
          (root / "video-archive/0001" / values[2]["streamId"] / "stream.json").exists())
    check("legacy final alias remains byte-identical",
          (feed / "archive-index.json").read_bytes() ==
          (feed / f"archive-index-{final['streamId']}.json").read_bytes())
    for ordinal, row in enumerate(catalog["streams"]):
        raw, index = Archive.read(feed / row["indexFile"])
        check("stream index hash, generation and source identity " + str(ordinal),
              Archive.sha(raw) == row["indexSha256"] and index["generation"] == row["generation"]
              and index["sessionId"] == session and index["studyId"] == recording
              and index["streamId"] == row["streamId"] and index["attempt"] == 1)
        check("retained two original segments in stream " + str(ordinal),
              index["segmentCount"] == 2 and index["coverage"] == "complete-published-segments"
              and index["sourceProvenance"]["packageSha256"] is None
              and index["sourceProvenance"]["definitionSha256"] is None)
        for descriptor in index["pages"]:
            page_raw, page = Archive.read(feed / descriptor["file"])
            check("immutable page binds exact stream " + str(ordinal),
                  Archive.sha(page_raw) == descriptor["sha256"]
                  and page["streamId"] == row["streamId"]
                  and page["video"]["streamId"] == row["streamId"])
            for segment in page["video"]["segments"]:
                check("original media bytes and hash " + str(ordinal),
                      (feed / segment["file"]).read_bytes() == original_media[segment["file"]]
                      and Archive.sha(original_media[segment["file"]]) == segment["sha256"])
    check("source archive bytes unchanged", source_snapshot == {
        str(path.relative_to(root)): Archive.sha(path.read_bytes())
        for path in (root / "video-archive").rglob("*") if path.is_file()})
    stable_view = (feed / "latest.json").read_bytes()
    again = Archive.project_archive(root, feed)
    check("repeat projection is byte-stable and adds no media",
          (feed / "latest.json").read_bytes() == stable_view
          and again["copiedMedia"] == again["linkedMedia"] == 0)
    index_path = feed / catalog["streams"][0]["indexFile"]
    index_before = index_path.read_bytes()
    index_path.write_bytes(b"corrupted immutable index")
    refused("mutated retired index cannot be readmitted", lambda: Archive.project_archive(root, feed))
    check("index refusal preserves advertised catalog pointer", (feed / "latest.json").read_bytes() == stable_view)
    index_path.write_bytes(index_before)
    check("retained fixture restores checked index after inverse", index_path.read_bytes() == index_before)

with tempfile.TemporaryDirectory() as directory:
    root, recording = Path(directory), str(uuid.uuid4())
    owner = Archive.Archive(root, recording, run_name="participant-run", min_free_bytes=0)
    owner.initialize()
    source, value, session = Fixtures.fixture(root, run_name="participant-run")
    value.update(mimeType="video/mp4", codecs="avc1.640033", width=2560, height=720, fps=120,
                 message="Synthetic original-stream bytes")
    Fixtures.publish(source, value, [1], "ended")
    value["stats"] = {"capturedFrames": 20, "encodedFrames": 20, "droppedFrames": 0}
    value["segments"][0].update(sites=[], crops=[])
    Archive.atomic(source / "latest-video.json", value)
    owner.poll()
    receipt = json.loads((root / "participant-run/run.json").read_text())
    receipt.update(status="completed", packageSha256=None, definitionSha256=None)
    Archive.atomic(root / "participant-run/run.json", receipt)
    owner.poll()
    feed = root / "feeds/0001"
    feed.mkdir(parents=True)
    Archive.atomic(feed / "latest.json", {"state": "ended", "sessionId": session,
        "sequence": 1, "capturedAtUnixMs": 1000,
        "recording": {"id": recording, "attempt": 1},
        "video": {**value, "schema": "mousecat.native-video/1"}})
    retained_file = root / "video-archive/0001" / value["streamId"] / value["segments"][0]["file"]
    original_fragment = retained_file.read_bytes()
    retained_file.unlink()
    refused("missing retained media prevents any catalog advertisement",
            lambda: Archive.project_archive(root, feed))
    check("interrupted export did not advertise catalog", "archiveCatalog" not in
          Archive.read(feed / "latest.json")[1])
    retained_file.write_bytes(original_fragment)
    single = Archive.project_archive(root, feed)
    check("one ended native recording also has a catalog and final alias",
          single["streamCount"] == 1 and "archiveCatalog" in Archive.read(feed / "latest.json")[1]
          and (feed / "archive-index.json").read_bytes() ==
              (feed / f"archive-index-{value['streamId']}.json").read_bytes())

print(json.dumps({"schema": "sao.native-video-archive-catalog-proof/1", "status": "PASS",
                  "fixture": "synthetic fragment bytes; no native playback claim", "checks": checks}, indent=2))
