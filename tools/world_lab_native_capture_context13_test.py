#!/usr/bin/env python3
"""Native capture-context and terminal receipt controls; no game or encoder runs."""
import copy
import hashlib
import tempfile
from pathlib import Path
from types import SimpleNamespace
import unittest
import uuid

import world_lab_native_play as Native
import world_lab_participant_feed as Feed
from world_lab_native_play04_test import Fixture


def context(fixture, epoch, *, observed=False, persisted=False, stream=None, world_hours=None):
    value = {"schema": "sao.native-capture-context/1", "namespace": "native-play",
             "sessionId": fixture.session, "pid": 12345, "attempt": 1, "captureEpoch": epoch,
             "saveMode": "Sandbox" if observed else None,
             "save": "fixture-save" if observed else None,
             "bodyObserved": observed, "binding": "persisted" if persisted else "unbound",
             "worldClock": "observed" if observed else "unavailable",
             "worldHours": world_hours if observed else None}
    if persisted:
        value.update(playerIndex=0, playerSqlId=1)
    if stream:
        value["streamId"] = stream
    return value


class ExactRelay:
    admitted = []

    def __init__(self, source, destination):
        self.source, self.destination = source, destination

    def publish(self, value):
        assert set(value) == {"schema", "streamId", "state", "segments"}
        assert value["schema"] == "sao-study-video/1"
        self.admitted.append(copy.deepcopy(value))
        return {**value, "schema": "mousecat.native-video/1"}


class CaptureContext13(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="sao-native-context13-")
        self.fixture = Fixture(Path(self.temporary.name))
        f = self.fixture
        f.out.mkdir()
        Feed.atomic(f.out / "participant-run/run.json", f.receipt())
        ExactRelay.admitted = []
        self.feed = Native.NativePlayFeed(f.out / "participant-run", f.destination,
                                          f.receipt(), f.session, SimpleNamespace(VideoRelay=ExactRelay))

    def tearDown(self):
        self.temporary.cleanup()

    def write_frame(self, body, sequence, capture):
        f = self.fixture
        f.write_sources(body, sequence)
        frame = Feed.read(f.native / "native.json")[1]
        frame["captureContext"] = copy.deepcopy(capture)
        if capture["worldClock"] == "unavailable": frame["hours"] = 0
        Feed.atomic(f.native / "native.json", frame)
        return frame

    def test_unbound_then_persisted_frame_and_separate_video_epoch(self):
        f = self.fixture
        unbound = f.body(0, ready=False, alive=False, save="", saveMode="", playerSqlId=-1)
        unbound.pop("body")
        menu = context(f, 1)
        self.write_frame(unbound, 1, menu)
        self.assertTrue(self.feed.publish_play())
        view = Feed.read(f.destination / "latest.json")[1]
        self.assertEqual(view["captureContext"], menu)
        self.assertEqual(view["people"], [])
        self.assertNotIn("inspection", view)
        self.assertNotIn("videoCaptureContext", view)

        body = f.body(200)
        selected = context(f, 2, observed=True, persisted=True, world_hours=body["worldHours"])
        self.write_frame(body, 2, selected)
        stream = str(uuid.uuid4())
        manifest = {"schema": "sao-study-video/1", "streamId": stream,
                    "state": "starting", "segments": []}
        Feed.atomic(f.native / "latest-video.json", manifest)
        sidecar = context(f, 1, stream=stream)
        sidecar_path = f.native / f"video-{stream}-native-context.json"
        Feed.atomic(sidecar_path, sidecar)
        raw = sidecar_path.read_bytes()
        self.assertTrue(self.feed.publish_play())
        view = Feed.read(f.destination / "latest.json")[1]
        self.assertEqual(view["captureContext"], selected)
        self.assertEqual(view["videoCaptureContext"], sidecar)
        self.assertNotEqual(view["captureContext"]["captureEpoch"], view["videoCaptureContext"]["captureEpoch"])
        self.assertEqual((f.destination / sidecar_path.name).read_bytes(), raw)
        self.assertEqual(view["people"][0]["label"], body["body"]["label"])
        self.assertEqual(len(ExactRelay.admitted), 1)
        self.assertNotIn("captureContext", ExactRelay.admitted[0])

    def test_foreign_changed_and_missing_sidecar_refuse_without_view_rewrite(self):
        f = self.fixture
        body = f.body()
        selected = context(f, 2, observed=True, persisted=True, world_hours=body["worldHours"])
        self.write_frame(body, 1, selected)
        self.feed.publish_play()
        before = (f.destination / "latest.json").read_bytes()
        stream = str(uuid.uuid4())
        manifest = {"schema": "sao-study-video/1", "streamId": stream,
                    "state": "running", "segments": [{"sequence": 1}]}
        Feed.atomic(f.native / "latest-video.json", manifest)
        with self.assertRaisesRegex(ValueError, "lack capture context"):
            self.feed.publish_play()
        self.assertEqual((f.destination / "latest.json").read_bytes(), before)
        sidecar_path = f.native / f"video-{stream}-native-context.json"
        foreign = context(f, 2, observed=True, persisted=True, stream=stream,
                          world_hours=body["worldHours"])
        foreign["pid"] += 1
        Feed.atomic(sidecar_path, foreign)
        with self.assertRaisesRegex(ValueError, "owner differs"):
            self.feed.publish_play()
        self.assertEqual((f.destination / "latest.json").read_bytes(), before)
        correct = context(f, 2, observed=True, persisted=True, stream=stream,
                          world_hours=body["worldHours"])
        Feed.atomic(sidecar_path, correct)
        self.feed.publish_play()
        admitted = (f.destination / "latest.json").read_bytes()
        altered = copy.deepcopy(correct); altered["save"] = "other-save"
        Feed.atomic(sidecar_path, altered)
        with self.assertRaisesRegex(ValueError, "context changed"):
            self.feed.publish_play()
        self.assertEqual((f.destination / "latest.json").read_bytes(), admitted)

    def test_png_context_identity_and_epoch_inverses(self):
        f = self.fixture
        body = f.body()
        selected = context(f, 2, observed=True, persisted=True, world_hours=body["worldHours"])
        self.write_frame(body, 1, selected)
        self.feed.publish_play()
        before = (f.destination / "latest.json").read_bytes()
        vectors = [
            ("foreign session", lambda c: c.update(sessionId=str(uuid.uuid4()))),
            ("invented SQL", lambda c: c.update(playerSqlId=99)),
            ("world unavailable with value", lambda c: c.update(worldClock="unavailable")),
            ("regressed epoch", lambda c: c.update(captureEpoch=1)),
        ]
        for label, mutate in vectors:
            with self.subTest(label=label):
                candidate = copy.deepcopy(selected); mutate(candidate)
                self.write_frame(body, 2, candidate)
                with self.assertRaises(ValueError): self.feed.publish_play()
                self.assertEqual((f.destination / "latest.json").read_bytes(), before)


class TerminalStatus13(unittest.TestCase):
    def run_case(self, **options):
        with tempfile.TemporaryDirectory(prefix="sao-native-final13-") as directory:
            f = Fixture(Path(directory))
            writes = []
            def observe(path, value):
                if path.name == "run.json":
                    writes.append((value["status"], "archive-close:ended" in f.trace))
            result = f.run([f.body()], fault=observe, **options)
            receipt = Feed.read(f.out / "participant-run/run.json")[1]
            completion = Feed.read(f.out / "recording-completion.json")[1]
            return result, writes, receipt, completion

    def test_final_completed_receipt_is_written_after_archive_close(self):
        result, writes, receipt, completion = self.run_case()
        self.assertEqual(result, 0)
        self.assertEqual(writes[-1], ("completed", True))
        self.assertEqual(receipt["status"], "completed")
        self.assertTrue(completion["complete"])

    def test_archive_close_and_qualification_failure_correct_final_receipt(self):
        for options in ({"close_error": "controlled catalog failure"}, {"incomplete_epoch": True}):
            with self.subTest(options=options):
                result, writes, receipt, completion = self.run_case(**options)
                self.assertEqual(result, 0)
                self.assertEqual(writes[-1], ("incomplete", True))
                self.assertEqual(receipt["status"], "incomplete")
                self.assertFalse(completion["complete"])
                self.assertTrue(receipt["recordingError"])


if __name__ == "__main__": unittest.main(verbosity=2)
