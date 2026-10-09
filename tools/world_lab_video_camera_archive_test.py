#!/usr/bin/env python3
"""Encoded-byte camera provenance at the participant archive boundary."""
from __future__ import annotations

import base64
import copy
import json
import os
from pathlib import Path
import tempfile
import unittest
import uuid

import world_lab_participant_feed as Feed
import world_lab_video_archive as Archive


def watcher_path():
    return Path(os.environ.get("SAO_PARTICIPANT_WATCHER", str(Path(__file__).resolve().parents[2]
        / "speakeasy-r88-video-observation/tools/world_watch.py")))


def fixture_path():
    return Path(os.environ.get("SAO_PARTICIPANT_VIDEO_FIXTURE",
        str(watcher_path().with_name("fixtures") / "native_video.json")))


class CameraArchive(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="sao-camera-archive-encoded-")
        self.root = Path(self.temporary.name)
        self.session = str(uuid.uuid4())
        self.study = str(uuid.uuid4())
        self.module, self.pin = Feed.load_video_module(watcher_path())
        fixture = json.loads(fixture_path().read_text())
        self.video = copy.deepcopy(fixture["manifest"])
        self.segment = self.video["segments"][0]
        self.segment["sequence"] = 1
        self.segment["file"] = f"video-{self.video['streamId']}-0000000000000001.m4s"
        self.segment["cameraFrames"] = [{"frameSequence": sequence, "camera": {
            "schema": "sao.native-frame-camera/1", "mode": "viewpoint-third", "ready": True}}
            for sequence in range(self.segment["firstFrameSequence"], self.segment["lastFrameSequence"] + 1)]
        self.source = self.root / "participant-run/attempts/0001/native-view"
        self.source.mkdir(parents=True)
        self.source.joinpath(self.video["init"]["file"]).write_bytes(base64.b64decode(
            fixture["files"][self.video["init"]["file"]]))
        original_file = fixture["manifest"]["segments"][0]["file"]
        self.source.joinpath(self.segment["file"]).write_bytes(base64.b64decode(fixture["files"][original_file]))
        defaults = self.module.init_info((self.source / self.video["init"]["file"]).read_bytes(), self.video)
        self.assertEqual(self.module.media_info((self.source / self.segment["file"]).read_bytes(),
            {key: value for key, value in self.segment.items() if key != "cameraFrames"}, defaults), 15)
        self.receipt = {"schema": "sao-study-run/1", "sessionId": self.session,
            "launchNumber": 1, "status": "completed", "packageSha256": "controlled-package",
            "definitionSha256": "controlled-definition", "videoBridge": self.pin}
        Feed.atomic(self.root / "participant-run/run.json", self.receipt)
        self.owner = Archive.Archive(self.root, self.study, min_free_bytes=0, run_name="participant-run")
        self.owner.acquire()
        self.owner.initialize()

    def tearDown(self):
        self.owner.close()
        self.temporary.cleanup()

    def publish_source(self):
        Feed.atomic(self.source / "latest-video.json", self.video)

    def report(self):
        return Feed.read(self.root / "video-archive/0001" / self.video["streamId"] / "stream.json")[1]

    def ended_view(self):
        feed = self.root / "feeds/0001"
        feed.mkdir(parents=True, exist_ok=True)
        view = {"state": "ended", "sessionId": self.session, "sequence": 1,
                "study": {"id": self.study, "attempt": 1},
                "video": {**self.video, "schema": "mousecat.native-video/1"}}
        Feed.atomic(feed / "latest.json", view)
        return feed

    def test_exact_encoded_samples_admit_complete_archive_and_projection(self):
        self.publish_source()
        self.owner.poll()
        self.assertEqual(self.report()["coverage"], "complete-published-segments")
        feed = self.ended_view()
        Archive.project_archive(self.root, feed)
        index = Feed.read(feed / "archive-index.json")[1]
        self.assertEqual(index["coverage"], "complete-published-segments")
        page = Feed.read(feed / index["pages"][0]["file"])[1]
        self.assertEqual(page["video"]["segments"][0]["cameraFrames"], self.segment["cameraFrames"])
        self.assertEqual((feed / self.segment["file"]).read_bytes(),
                         (self.source / self.segment["file"]).read_bytes())

    def test_dropped_capture_sequence_keeps_one_label_per_encoded_sample(self):
        self.segment["lastFrameSequence"] += 1
        self.segment["cameraFrames"][-1]["frameSequence"] += 1
        destination = self.root / "camera-publisher"
        destination.mkdir()
        published = Feed.publish_video_with_cameras(self.module.VideoRelay(self.source, destination), self.video)
        self.assertEqual(published["segments"][0]["cameraFrames"][-1]["frameSequence"], 89)
        self.publish_source()
        self.owner.poll()
        self.assertEqual(self.report()["coverage"], "complete-published-segments")

    def test_missing_encoded_camera_row_never_completes(self):
        self.segment["cameraFrames"] = [self.segment["cameraFrames"][0], self.segment["cameraFrames"][-1]]
        self.publish_source()
        with self.assertRaisesRegex(ValueError, "encoded sample count"):
            self.owner.poll()
        self.owner.fail(ValueError("camera sample count refused"))
        self.assertEqual(Feed.read(self.root / "video-archive/archive.json")[1]["status"], "failed")
        self.assertFalse(list((self.root / "video-archive/0001" / self.video["streamId"] / "manifests").glob("*.json")))
        self.assertFalse((self.root / "feeds/0001/archive-index.json").exists())

    def test_explicit_null_camera_rows_are_refused(self):
        self.segment["cameraFrames"] = None
        self.publish_source()
        with self.assertRaisesRegex(ValueError, "camera frame count"):
            self.owner.poll()
        self.assertFalse(list((self.root / "video-archive/0001" / self.video["streamId"] / "manifests").glob("*.json")))

    def test_projection_rechecks_retained_media_before_index(self):
        self.publish_source()
        self.owner.poll()
        retained = self.root / "video-archive/0001" / self.video["streamId"]
        manifests = retained / "manifests"
        self.segment["cameraFrames"] = [self.segment["cameraFrames"][0], self.segment["cameraFrames"][-1]]
        for path in manifests.glob("*.json"):
            path.unlink()  # Controlled test tamper, followed by a correctly named manifest.
        raw = Archive.encoded(self.video)
        (manifests / (Archive.sha(raw) + ".json")).write_bytes(raw)
        state = self.report()
        state["firstSegment"] = copy.deepcopy(self.segment)
        state["lastSegment"] = copy.deepcopy(self.segment)
        Feed.atomic(retained / "stream.json", state)
        feed = self.ended_view()
        with self.assertRaisesRegex(ValueError, "encoded sample count"):
            Archive.project_archive(self.root, feed)
        self.assertFalse((feed / "archive-index.json").exists())

    def test_retained_parser_pin_survives_live_receipt_turnover(self):
        self.publish_source()
        self.owner.poll()
        later = {**self.receipt, "sessionId": str(uuid.uuid4()), "launchNumber": 2,
                 "videoBridge": {**self.pin, "sha256": "0" * 64}}
        Feed.atomic(self.root / "participant-run/run.json", later)
        restored = Archive.Archive(self.root, self.study, min_free_bytes=0, run_name="participant-run")
        restored.initialize()
        self.assertEqual(Feed.read(restored.root / "0001" / self.video["streamId"] / "stream.json")[1]["coverage"],
                         "complete-published-segments")
        feed = self.ended_view()
        Archive.project_archive(self.root, feed)
        self.assertEqual(Feed.read(feed / "archive-index.json")[1]["coverage"],
                         "complete-published-segments")

    def test_unpinned_live_parser_is_refused(self):
        Feed.atomic(self.root / "participant-run/run.json",
                    {**self.receipt, "videoBridge": {**self.pin, "sha256": "0" * 64}})
        self.publish_source()
        with self.assertRaisesRegex(ValueError, "parser source changed"):
            self.owner.poll()
        self.assertFalse(list((self.root / "video-archive/0001" / self.video["streamId"] / "manifests").glob("*.json")))


if __name__ == "__main__":
    unittest.main(verbosity=2)
