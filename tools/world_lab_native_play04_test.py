#!/usr/bin/env python3
"""Focused native-menu/participant controls. No native process is executed.

All executables, processes and archive delivery in controlled main() runs are
explicit fixtures. Recording checks exercise real metadata guards, not encoding
or save durability. An optional retained native source is only read.
"""
from __future__ import annotations

from contextlib import ExitStack
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import time
import unittest
from unittest.mock import patch
import uuid

import world_lab_native_play as Native
import world_lab_participant_feed as Feed
import world_lab_participant_session as Pipeline
import world_lab_session as Session
from world_lab_participant_pipeline_test import png, protocol_recording


# Explicit historical source substitution is for restored-defect qualification.
if os.environ.get("SAO_NATIVE_PLAY04_PREIMAGE"):
    _path = Path(os.environ["SAO_NATIVE_PLAY04_PREIMAGE"]).resolve()
    _spec = importlib.util.spec_from_file_location("native_play04_preimage", _path)
    Native = importlib.util.module_from_spec(_spec)
    _spec.loader.exec_module(Native)

RECORDED_SOURCE_RECEIPTS = []


def pin(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()


class ControlledProcess:
    """An in-memory lifetime, with no operating-system process behind its PID."""
    pid = 12345

    def __init__(self, fixture, bodies=None, exit_code=0, save_returned=True):
        self.fixture = fixture
        self.bodies = copy.deepcopy(bodies) if bodies is not None else None
        self.index = 0
        self.returncode = None
        self.exit_code = exit_code
        self.save_returned = save_returned
        self.handles = []

    def poll(self):
        if self.bodies is None: return None
        if self.index < len(self.bodies):
            self.fixture.write_sources(self.bodies[self.index], self.index + 1)
            self.index += 1
            return None
        self.returncode = self.exit_code
        return self.returncode

    def terminate(self): raise AssertionError("Native play must preserve the player's process")
    def kill(self): raise AssertionError("Native play must preserve the player's process")
    def wait(self, *args, **kwargs): raise AssertionError("No native wait was authorized by this fixture")


class ControlledArchive:
    """Explicit metadata delivery; this never claims encoded media exists."""
    def __init__(self, fixture, close_error=None, incomplete_epoch=False):
        self.fixture = fixture
        self.error = None
        self.close_error = close_error
        self.incomplete_epoch = incomplete_epoch
        self.closed = 0
        self.source_state_at_close = None

    def close(self):
        self.closed += 1
        latest = self.fixture.destination / "latest.json"
        if latest.exists():
            self.source_state_at_close = Feed.read(latest)[1]["state"]
            self.fixture.trace.append("archive-close:" + self.source_state_at_close)
            protocol_recording(self.fixture.destination, self.fixture.session, self.fixture.session)
            if self.incomplete_epoch:
                path = self.fixture.out / "video-archive/archive.json"
                archive = Feed.read(path)[1]
                archive["streams"].append({"attempt": 1, "streamId": str(uuid.uuid4()),
                    "coverage": "partial", "tailConfirmed": False, "lateAttachment": True,
                    "retainedSegments": 1})
                Feed.atomic(path, archive)
            self.fixture.publish_protocol_catalog()
        if self.close_error is not None: self.error = self.close_error


class Fixture:
    def __init__(self, root):
        self.root = root
        self.out = root / "session"
        self.game = root / "installed-game"
        self.jdk = root / "compiler"
        self.encoder = root / "fixture-encoder.exe"
        self.watcher = root / "fixture-watcher.py"
        self.registry = root / "fixture-registry.json"
        self.sao = root / "fixture-SAOAgent.jar"
        for path in [self.game / "projectzomboid.jar", self.game / "ZombieBuddy.jar",
                     self.game / "jre64/bin/java.exe", self.jdk / "javac.exe",
                     self.encoder, self.watcher, self.sao]:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"explicit inert dependency fixture; never executed")
        self.definition = {"mainClass": "zombie/gameStates/MainScreenState",
            "classpath": [".", "projectzomboid.jar"],
            "vmArgs": ["-Xmx8192m", "-Dsteam=1", "-Djava.library.path=win64;win64/natives;."]}
        self.write_definition()
        self.registry.write_text("[]", encoding="utf-8")
        self.session = str(uuid.uuid4())
        self.native = self.out / "participant-run/attempts/0001/native-view"
        self.destination = self.out / "feeds/0001"
        self.now = int(time.time() * 1000) - 200
        self.image = png()
        self.trace = []
        self.spawned = []
        self.archive = None
        self.process = None
        self.view_publications = []

    def write_definition(self):
        (self.game / "ProjectZomboid64.json").write_text(json.dumps(self.definition), encoding="utf-8")

    def publish_protocol_catalog(self):
        """Bind controlled metadata epochs without claiming encoded playback."""
        feed = self.destination
        view = Feed.read(feed / "latest.json")[1]
        index = Feed.read(feed / "archive-index.json")[1]
        stream = index["streamId"]
        run_raw = (self.out / "participant-run/run.json").read_bytes()
        index["sourceProvenance"] = {"runReceiptSha256": hashlib.sha256(run_raw).hexdigest()}
        Feed.atomic(feed / "archive-index.json", index)
        index_raw = (feed / "archive-index.json").read_bytes()
        index_name = f"archive-index-{stream}.json"
        (feed / index_name).write_bytes(index_raw)
        archive = Feed.read(self.out / "video-archive/archive.json")[1]
        epochs = []
        for ordinal, state in enumerate(archive["streams"], 1):
            epoch_stream = state["streamId"]
            report = {"schema": "sao.native-video-archive/1", "studyId": self.session,
                "attempt": 1, "streamId": epoch_stream,
                "nativeProvenance": {"sessionId": self.session, "launchNumber": 1},
                "coverage": state["coverage"], "tailConfirmed": state["tailConfirmed"],
                "lateAttachment": state["lateAttachment"],
                "retainedSegments": state["retainedSegments"],
                "firstSegment": {"capturedAtUnixMs": ordinal * 1000}}
            source = self.out / "video-archive/0001" / epoch_stream
            Feed.atomic(source / "stream.json", report)
            report_raw = (source / "stream.json").read_bytes()
            report_sha = hashlib.sha256(report_raw).hexdigest()
            report_name = f"archive-report-{epoch_stream}-{report_sha}.json"
            (feed / report_name).write_bytes(report_raw)
            epochs.append({"streamId": epoch_stream, "reportFile": report_name,
                "reportSha256": report_sha, "coverage": state["coverage"],
                "tailConfirmed": state["tailConfirmed"],
                "lateAttachment": state["lateAttachment"],
                "retainedSegments": state["retainedSegments"],
                "firstCapturedAtUnixMs": ordinal * 1000, "published": epoch_stream == stream})
        rows = [{"streamId": stream, "indexFile": index_name,
            "indexSha256": hashlib.sha256(index_raw).hexdigest(), "generation": index["generation"]}]
        aggregate = {"schema": "mousecat.native-video-archive-coverage/1",
            "epochCount": len(epochs), "publishedCount": 1,
            "unavailableCount": len(epochs) - 1,
            "complete": len(epochs) == 1, "epochs": epochs}
        catalog = {"schema": "mousecat.native-video-archive-catalog/1",
            "sessionId": self.session, "recordingId": self.session, "attempt": 1,
            "finalStreamId": stream, "streams": rows, "aggregateCoverage": aggregate}
        Feed.atomic(feed / "archive-catalog.json", catalog)
        catalog_raw = (feed / "archive-catalog.json").read_bytes()
        view["archiveCatalog"] = {"file": "archive-catalog.json",
            "sha256": hashlib.sha256(catalog_raw).hexdigest()}
        Feed.atomic(feed / "latest.json", view)

    def body(self, step=0, **changes):
        value = {"schema": "sao-native-participant/1", "sessionId": self.session,
            "pid": ControlledProcess.pid, "attempt": 1, "saveMode": "Sandbox", "save": "fixture-save",
            "playerIndex": 0, "playerSqlId": 1, "capturedAtUnixMs": self.now + step,
            "worldHours": 10 + step / 1000, "ready": True, "displayFocused": True, "alive": True,
            "body": {"x": 10.25, "y": 22.75, "z": 0, "label": "Fixture native character"}}
        value.update(changes)
        return value

    def receipt(self):
        return {"schema": "sao-study-run/1", "sessionId": self.session, "pid": ControlledProcess.pid,
            "host": "player", "participantInput": True, "window": "visible", "watch": True,
            "launchNumber": 1, "observerDirectory": "attempts/0001", "status": "running",
            "launchMode": "native-menu", "save": None}

    def write_sources(self, body, sequence=1):
        self.native.mkdir(parents=True, exist_ok=True)
        name = f"study-live-{sequence:016d}.png"
        (self.native / name).write_bytes(self.image)
        frame = {"schema": "sao-native-viewport/1", "sequence": sequence, "observerSequence": 0,
            "capturedAtUnixMs": body["capturedAtUnixMs"] - 100, "hours": body["worldHours"],
            "image": {"file": name, "sha256": hashlib.sha256(self.image).hexdigest(), "width": 2, "height": 2},
            "participant": copy.deepcopy(body)}
        Feed.atomic(self.native / "native.json", frame)
        Feed.atomic(self.native.parent / "participant-state.json", body)

    def args(self, *extras):
        return ["--out", str(self.out), "--session", self.session,
            "--game", str(self.game), "--jdk", str(self.jdk), "--video-encoder", str(self.encoder),
            "--watcher", str(self.watcher), "--registry", str(self.registry), *extras]

    def builder(self, destination, *args, **kwargs):
        assert Path(destination).is_dir(), "launcher must create its adapter parent"
        target = Path(destination) / "fixture-participant-agent.jar"
        target.write_bytes(b"controlled adapter fixture; no compilation or execution")
        return target

    def spawn(self, command, **kwargs):
        self.spawned.append({"command": command, "javaOptionsPresent": "_JAVA_OPTIONS" in kwargs["env"]})
        self.process.handles = [kwargs["stdout"], kwargs["stderr"]]
        if self.process.save_returned:
            kwargs["stdout"].write(b"[StudyLaunch] native-save-returned attempt=1\n")
            kwargs["stdout"].flush()
        return self.process

    def run(self, bodies=None, save_returned=True, exit_code=0, close_error=None,
            incomplete_epoch=False, fault=None):
        self.process = ControlledProcess(self, bodies, exit_code, save_returned)
        self.archive = ControlledArchive(self, close_error, incomplete_epoch)
        atomic = Session.atomic
        def observe_write(path, value):
            if fault: fault(Path(path), value)
            if Path(path).name == "latest.json" and value.get("schema") == "mousecat.native-view/1":
                self.view_publications.append(copy.deepcopy(value))
                self.trace.append("feed:" + value["state"])
            return atomic(Path(path), value)
        qualify = Pipeline.require_recording
        def observe_qualification(*args):
            self.trace.append("qualify")
            return qualify(*args)
        with ExitStack() as stack:
            stack.enter_context(patch.object(Native, "existing_game", return_value=[]))
            stack.enter_context(patch.object(Native.Run, "build_participant_adapter", side_effect=self.builder))
            stack.enter_context(patch.object(Native.Feed, "load_video_module", return_value=(None, {"fixture": True})))
            stack.enter_context(patch.object(Native.subprocess, "Popen", side_effect=self.spawn))
            stack.enter_context(patch.object(Native.Archive, "start", return_value=self.archive))
            stack.enter_context(patch.object(Session, "atomic", side_effect=observe_write))
            stack.enter_context(patch.object(Pipeline, "require_recording", side_effect=observe_qualification))
            stack.enter_context(patch.object(Native.time, "sleep", return_value=None))
            stack.enter_context(patch.dict(os.environ, {"_JAVA_OPTIONS": "controlled conflict", "SteamAppId": "108600"}))
            return Native.main(self.args("--sao-jar", str(self.sao)))

    def events(self):
        return [json.loads(line) for line in (self.out / "events.jsonl").read_text(encoding="utf-8").splitlines()]


class NativePlay04(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="sao-native-play04-controlled-")
        self.root = Path(self.temporary.name).resolve()
        self.fixture = Fixture(self.root)

    def tearDown(self):
        process = self.fixture.process
        if process:
            for handle in process.handles:
                if not handle.closed: handle.close()
        self.assertTrue(self.root.is_relative_to(Path(tempfile.gettempdir()).resolve()))
        self.assertTrue(self.root.name.startswith("sao-native-play04-controlled-"))
        self.temporary.cleanup()

    def new_feed(self):
        f = self.fixture
        f.out.mkdir()
        Feed.atomic(f.out / "participant-run/run.json", f.receipt())
        return Native.NativePlayFeed(f.out / "participant-run", f.destination, f.receipt(), f.session)

    def latest(self): return Feed.read(self.fixture.destination / "latest.json")[1]

    def objective_source(self, body=None):
        f = self.fixture
        body = body or f.body()
        sample = Feed.encoded(body).decode("utf-8")
        row = {"processId": "process-1", "revision": 2, "playerId": "player:fixture",
            "helperId": "helper-1", "commitmentId": "commitment-1",
            "outboundReceiptId": "route-out", "watchReceiptId": "watch-1",
            "returnReceiptId": "route-home",
            "report": {"status": "completed", "channel": "spoken", "deliveredAt": 9.5},
            "review": {"status": "inspected", "reviewedAt": 9.75,
                "attempts": [{"id": "route-home", "stepId": "return", "owner": "ManualRoute",
                    "status": "arrived", "x": 10, "y": 22, "z": 0,
                    "startedAt": 9, "endedAt": 9.4}]}}
        source = {"schema": Native.OBJECTIVE_REVIEW_SCHEMA, "sessionId": body["sessionId"],
            "pid": body["pid"], "attempt": body["attempt"], "captureEpoch": 1, "save": body["save"],
            "saveMode": body["saveMode"], "playerIndex": body["playerIndex"],
            "playerSqlId": body["playerSqlId"], "capturedAtUnixMs": body["capturedAtUnixMs"],
            "worldHours": body["worldHours"], "countyHours": body["worldHours"],
            "sampleSha256": hashlib.sha256(sample.encode()).hexdigest(),
            "bodySample": sample, "omittedReviews": 0, "reviews": [row]}
        return source

    def test_objective_review_snapshot_retains_exact_body_and_one_event(self):
        f = self.fixture; f.out.mkdir()
        events = []
        archive = Native.ObjectiveReviewArchive(f.out, f.receipt(),
            lambda kind, **fields: events.append({"kind": kind, **fields}))
        path = f.out / "participant-run/attempts/0001/objective-review-state.json"
        path.parent.mkdir(parents=True)
        source = self.objective_source()
        Feed.atomic(path, source)
        self.assertTrue(archive.collect(path))
        self.assertFalse(archive.collect(path))
        self.assertEqual(len(events), 1)
        event = events[0]
        self.assertEqual(event["kind"], "native-objective-review")
        self.assertEqual(event["sampleSha256"], source["sampleSha256"])
        self.assertEqual(event["countyHours"], source["countyHours"])
        self.assertEqual(event["processId"], source["reviews"][0]["processId"])
        self.assertEqual((f.out / event["objectiveSourceFile"]).read_bytes(), path.read_bytes())
        self.assertEqual((f.out / "body-samples" / (source["sampleSha256"] + ".json")).read_bytes(),
            source["bodySample"].encode())
        capture = {"binding": "persisted", "captureEpoch": 1,
            **{field: source[field] for field in ("saveMode", "save", "playerIndex", "playerSqlId")}}
        sections = archive.sections_for(f.body(), capture)
        self.assertEqual(len(sections), 1)
        self.assertEqual(sections[0]["id"].startswith("objective-review-"), True)
        self.assertIn(event["objectiveSourceSha256"], sections[0]["source"])
        self.assertEqual(next(row["value"] for row in sections[0]["rows"]
            if row["label"] == "Player inspection"), "Inspected at county hour 9.75")
        self.assertEqual(archive.sections_for(f.body(), {**capture, "captureEpoch": 2}), [])
        self.assertEqual(archive.sections_for(f.body(), {**capture, "playerSqlId": 8}), [])
        changed = copy.deepcopy(source); changed["reviews"][0]["returnReceiptId"] = "different-return"
        Feed.atomic(path, changed)
        with self.assertRaisesRegex(ValueError, "changed after recording"):
            archive.collect(path)

    def test_objective_projection_respects_mousecat_utf16_limits(self):
        f = self.fixture; f.out.mkdir()
        path = f.out / "participant-run/attempts/0001/objective-review-state.json"
        path.parent.mkdir(parents=True)
        source = self.objective_source()
        long_id = "🐭" * 193
        source["reviews"][0]["helperId"] = long_id
        source["reviews"][0]["returnReceiptId"] = long_id
        Feed.atomic(path, source)
        archive = Native.ObjectiveReviewArchive(f.out, f.receipt(), lambda kind, **fields: None)
        self.assertTrue(archive.collect(path))
        capture = {"binding": "persisted", "captureEpoch": 1,
            **{field: source[field] for field in ("saveMode", "save", "playerIndex", "playerSqlId")}}
        section = archive.sections_for(f.body(), capture)[0]
        self.assertGreater(len(long_id.encode("utf-16-le")) // 2, 384)
        self.assertLessEqual(len(section["label"].encode("utf-16-le")) // 2, 160)
        self.assertLessEqual(max(len(row["value"].encode("utf-16-le")) // 2
            for row in section["rows"]), 384)

    def test_objective_review_reaches_bound_native_person_inspector(self):
        f = self.fixture; f.out.mkdir()
        body = f.body()
        Feed.atomic(f.out / "participant-run/run.json", f.receipt())
        f.write_sources(body)
        frame = Feed.read(f.native / "native.json")[1]
        capture = {"schema": "sao.native-capture-context/1", "namespace": "native-play",
            "sessionId": f.session, "pid": body["pid"], "attempt": 1, "captureEpoch": 1,
            "saveMode": body["saveMode"], "save": body["save"], "bodyObserved": True,
            "binding": "persisted", "worldClock": "observed", "worldHours": body["worldHours"],
            "playerIndex": body["playerIndex"], "playerSqlId": body["playerSqlId"]}
        frame["captureContext"] = capture
        Feed.atomic(f.native / "native.json", frame)
        path = f.native.parent / "objective-review-state.json"
        Feed.atomic(path, self.objective_source(body))
        archive = Native.ObjectiveReviewArchive(f.out, f.receipt(), lambda kind, **fields: None)
        self.assertTrue(archive.collect(path))
        feed = Native.NativePlayFeed(f.out / "participant-run", f.destination,
            f.receipt(), f.session, objective_archive=archive)
        self.assertTrue(feed.publish_play())
        view = self.latest()
        self.assertEqual(view["captureContext"], capture)
        section = next(section for section in view["people"][0]["sections"]
            if section["id"].startswith("objective-review-"))
        self.assertIn("Inspected at county hour 9.75",
            [row["value"] for row in section["rows"]])

    def test_objective_review_duplicate_logical_key_is_refused_before_publication(self):
        f = self.fixture; f.out.mkdir()
        path = f.out / "participant-run/attempts/0001/objective-review-state.json"
        path.parent.mkdir(parents=True)
        source = self.objective_source()
        source["reviews"].append(copy.deepcopy(source["reviews"][0]))
        Feed.atomic(path, source)
        events = []
        archive = Native.ObjectiveReviewArchive(f.out, f.receipt(),
            lambda kind, **fields: events.append({"kind": kind, **fields}))
        with self.assertRaisesRegex(ValueError, "duplicate review key"):
            archive.collect(path)
        self.assertEqual(events, [])
        self.assertFalse((f.out / "objective-reviews").exists())

    def test_objective_review_omission_growth_retains_each_higher_count(self):
        f = self.fixture; f.out.mkdir()
        path = f.out / "participant-run/attempts/0001/objective-review-state.json"
        path.parent.mkdir(parents=True)
        events = []
        archive = Native.ObjectiveReviewArchive(f.out, f.receipt(),
            lambda kind, **fields: events.append({"kind": kind, **fields}))
        source = self.objective_source(); source["omittedReviews"] = 1
        Feed.atomic(path, source)
        self.assertTrue(archive.collect(path))
        source["omittedReviews"] = 2
        Feed.atomic(path, source)
        self.assertTrue(archive.collect(path))
        self.assertFalse(archive.collect(path))
        self.assertEqual([event["kind"] for event in events],
            ["native-objective-review", "native-objective-review-omitted",
             "native-objective-review-omitted"])
        self.assertEqual([event["omittedReviews"] for event in events[1:]], [1, 2])
        self.assertEqual(len(list((f.out / "objective-reviews").glob("*.json"))), 2)

    def test_objective_review_foreign_body_clock_and_missing_report_are_refused(self):
        f = self.fixture; f.out.mkdir()
        path = f.out / "participant-run/attempts/0001/objective-review-state.json"
        path.parent.mkdir(parents=True)
        for change, message in ((lambda s: s.update(playerSqlId=8), "body identity or clock"),
                (lambda s: s.update(worldHours=11), "body identity or clock"),
                (lambda s: s["reviews"][0]["report"].update(status="pending"), "returned report"),
                (lambda s: s["reviews"][0]["review"].update(reviewedAt=11), "review clock"),
                (lambda s: s.update(sampleSha256="0"*64), "body sample differs")):
            source = self.objective_source(); change(source); Feed.atomic(path, source)
            archive = Native.ObjectiveReviewArchive(f.out, f.receipt(), lambda *a, **k: None)
            with self.assertRaisesRegex(ValueError, message): archive.collect(path)

    def test_objective_review_county_clock_preserves_mature_world_offset(self):
        f = self.fixture; f.out.mkdir()
        path = f.out / "participant-run/attempts/0001/objective-review-state.json"
        path.parent.mkdir(parents=True)
        source = self.objective_source()
        source["countyHours"] = 100
        source["reviews"][0]["report"]["deliveredAt"] = 99.5
        source["reviews"][0]["review"]["reviewedAt"] = 99.75
        Feed.atomic(path, source)
        events = []
        archive = Native.ObjectiveReviewArchive(f.out, f.receipt(),
            lambda kind, **fields: events.append({"kind": kind, **fields}))
        self.assertTrue(archive.collect(path))
        self.assertEqual(events[0]["worldHours"], 10)
        self.assertEqual(events[0]["countyHours"], 100)

    def test_native_host_retains_objective_review_event_once(self):
        f = self.fixture
        original = f.write_sources
        def with_review(body, sequence=1):
            original(body, sequence)
            Feed.atomic(f.out / "participant-run/attempts/0001/objective-review-state.json",
                self.objective_source(body))
        f.write_sources = with_review
        self.assertEqual(f.run([f.body()]), 0)
        reviews = [event for event in f.events() if event["kind"] == "native-objective-review"]
        self.assertEqual(len(reviews), 1)
        source = f.out / reviews[0]["objectiveSourceFile"]
        self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), reviews[0]["objectiveSourceSha256"])
        event_raw = Feed.encoded(reviews[0])
        event_path = f.out / "objective-reviews/events" / (hashlib.sha256(event_raw).hexdigest() + ".json")
        self.assertEqual(event_path.read_bytes(), event_raw)

    def test_objective_detached_event_failure_does_not_duplicate_main_log(self):
        f = self.fixture
        original_sources = f.write_sources
        def with_review(body, sequence=1):
            original_sources(body, sequence)
            Feed.atomic(f.out / "participant-run/attempts/0001/objective-review-state.json",
                self.objective_source(body))
        f.write_sources = with_review
        original_replace = os.replace
        refused = False
        def replace_once(source, destination):
            nonlocal refused
            if not refused and "objective-reviews/events" in Path(destination).as_posix():
                refused = True
                raise PermissionError("controlled detached event sharing denial")
            return original_replace(source, destination)
        with patch.object(Native.os, "replace", side_effect=replace_once):
            self.assertEqual(f.run([f.body(), f.body(step=1)]), 0)
        self.assertTrue(refused)
        reviews = [event for event in f.events() if event["kind"] == "native-objective-review"]
        self.assertEqual(len(reviews), 1)
        event_raw = Feed.encoded(reviews[0])
        detached = f.out / "objective-reviews/events" / (hashlib.sha256(event_raw).hexdigest() + ".json")
        self.assertEqual(detached.read_bytes(), event_raw)

    def test_objective_main_log_failure_reuses_one_detached_event(self):
        f = self.fixture
        original_sources = f.write_sources
        def with_review(body, sequence=1):
            original_sources(body, sequence)
            Feed.atomic(f.out / "participant-run/attempts/0001/objective-review-state.json",
                self.objective_source(body))
        f.write_sources = with_review
        original_open = Path.open
        refused = False
        def open_once(path, mode="r", *args, **kwargs):
            nonlocal refused
            if (not refused and Path(path) == f.out / "events.jsonl" and mode == "ab"
                    and list((f.out / "objective-reviews/events").glob("*.json"))):
                refused = True
                raise PermissionError("controlled main-log sharing denial")
            return original_open(path, mode, *args, **kwargs)
        with patch.object(Path, "open", new=open_once):
            self.assertEqual(f.run([f.body(), f.body(step=1)]), 0)
        self.assertTrue(refused)
        reviews = [event for event in f.events() if event["kind"] == "native-objective-review"]
        self.assertEqual(len(reviews), 1)
        detached_files = list((f.out / "objective-reviews/events").glob("*.json"))
        self.assertEqual(len(detached_files), 1)
        self.assertEqual(detached_files[0].read_bytes(), Feed.encoded(reviews[0]))

    def test_objective_review_epoch_and_basement_attempt_are_retained(self):
        f = self.fixture; f.out.mkdir()
        path = f.out / "participant-run/attempts/0001/objective-review-state.json"
        path.parent.mkdir(parents=True)
        events = []
        archive = Native.ObjectiveReviewArchive(f.out, f.receipt(),
            lambda kind, **fields: events.append({"kind": kind, **fields}))
        source = self.objective_source()
        source["reviews"][0]["review"]["attempts"][0]["z"] = -1
        Feed.atomic(path, source)
        self.assertTrue(archive.collect(path))
        source["captureEpoch"] = 2
        Feed.atomic(path, source)
        self.assertTrue(archive.collect(path))
        self.assertEqual([e["captureEpoch"] for e in events], [1, 2])

    def test_command_preserves_native_menu_sound_cache_and_native_options(self):
        f = self.fixture
        agent = f.root / "fixture-agent.jar"; agent.write_bytes(b"inert adapter")
        command = Native.command(f.game, agent, f.session, f.native.parent, f.encoder, f.sao)
        self.assertEqual(command[-1], "zombie.gameStates.MainScreenState")
        for option in f.definition["vmArgs"]: self.assertIn(option, command)
        for prefix in ["-cachedir=", "-Duser.home=", "-nosound", "-Dstudy.activeMods=", "-Dstudy.launch"]:
            self.assertFalse(any(item.startswith(prefix) for item in command), prefix)
        self.assertEqual(command.count("-XX:+UseZGC"), 1)
        self.assertEqual(command[command.index("-cp") + 1].split(os.pathsep), [".", "projectzomboid.jar", "ZombieBuddy.jar"])
        self.assertLess(command.index(f"-javaagent:{f.sao}=sao"), command.index(f"-javaagent:{agent}=native-play"))

    def test_conflicting_menu_home_mod_agent_and_classpath_inputs_rejected(self):
        f = self.fixture
        agent = f.root / "fixture-agent.jar"; agent.write_bytes(b"inert adapter")
        original = copy.deepcopy(f.definition)
        for option in ["-Duser.home=foreign", "-Dstudy.activeMods=forced", "-javaagent:foreign.jar"]:
            with self.subTest(option=option):
                f.definition = copy.deepcopy(original); f.definition["vmArgs"].append(option); f.write_definition()
                with self.assertRaises(ValueError): Native.command(f.game, agent, f.session, f.native.parent, f.encoder)
        f.definition = copy.deepcopy(original); f.definition["classpath"].append("foreign.jar"); f.write_definition()
        with self.assertRaises(ValueError): Native.command(f.game, agent, f.session, f.native.parent, f.encoder)
        f.definition = copy.deepcopy(original); f.definition["mainClass"] = "zombie.gameStates.GameLoadingState"; f.write_definition()
        with self.assertRaises(ValueError): Native.command(f.game, agent, f.session, f.native.parent, f.encoder)

    def test_prepare_only_creates_adapter_parent_and_pins_independent_sao_jar(self):
        f = self.fixture
        before = {str(p.relative_to(f.game)): pin(p) for p in f.game.rglob("*") if p.is_file()}
        with patch.object(Native, "existing_game", return_value=[]), \
             patch.object(Native.Run, "build_participant_adapter", side_effect=f.builder), \
             patch.object(Native.subprocess, "Popen") as spawn:
            self.assertEqual(Native.main(f.args("--prepare-only", "--sao-jar", str(f.sao))), 0)
            spawn.assert_not_called()
        launch = Feed.read(f.out / "launch.json")[1]
        self.assertEqual(launch["saoAgentSha256"], pin(f.sao))
        self.assertNotEqual(launch["saoAgentSha256"], launch["adapterSha256"])
        self.assertEqual(launch["saveSelection"], "native-LoadGameScreen")
        self.assertEqual(launch["userCache"], "native-default")
        self.assertFalse(launch["nativeModsOverride"]); self.assertFalse(launch["nativeSoundDisabled"])
        self.assertEqual(before, {str(p.relative_to(f.game)): pin(p) for p in f.game.rglob("*") if p.is_file()})
        self.assertFalse((f.out / "participant-run/cache").exists())
        self.assertEqual(Feed.read(f.out / "host.json")[1]["phase"], "prepared")

    def test_existing_native_game_prevents_spawn_at_both_checks(self):
        f = self.fixture
        with patch.object(Native, "existing_game", return_value=[{"ProcessId": 99}]), \
             patch.object(Native.subprocess, "Popen") as spawn:
            with self.assertRaises(ValueError): Native.main(f.args())
            spawn.assert_not_called(); self.assertFalse(f.out.exists())
        with patch.object(Native, "existing_game", side_effect=[[], [{"ProcessId": 99}]]), \
             patch.object(Native.Run, "build_participant_adapter", side_effect=f.builder), \
             patch.object(Native.subprocess, "Popen") as spawn:
            with self.assertRaises(ValueError): Native.main(f.args())
            spawn.assert_not_called()

    def test_post_spawn_run_publication_failure_preserves_pid(self):
        f = self.fixture
        def fault(path, value):
            if path.name == "run.json": raise OSError("controlled run publication failure")
        with self.assertRaisesRegex(OSError, "controlled run publication"):
            f.run(fault=fault)
        host = Feed.read(f.out / "host.json")[1]
        self.assertEqual(host["pid"], ControlledProcess.pid); self.assertEqual(host["phase"], "failed")
        self.assertIsNone(f.process.poll()); self.assertTrue(all(h.closed for h in f.process.handles))
        self.assertEqual(len(f.spawned), 1); self.assertFalse(f.spawned[0]["javaOptionsPresent"])

    def test_feed_full_namespace_changes_and_original_person_retention(self):
        f = self.fixture; feed = self.new_feed()
        original_source = f.body()
        f.write_sources(original_source); feed.publish_play(); original = self.latest()
        original_bytes = (f.destination / original["image"]["file"]).read_bytes()
        ids = [original["people"][0]["id"]]
        for step, changes in enumerate([{"saveMode": "Rising"}, {"save": "another-save"}, {"playerSqlId": 2}], 1):
            body = f.body(step, **changes); f.write_sources(body, step + 1); feed.publish_play()
            ids.append(self.latest()["people"][0]["id"])
        self.assertEqual(len(set(ids)), 4)
        self.assertEqual(original["people"][0]["id"], ids[0])
        self.assertEqual(original["people"][0]["label"], original_source["body"]["label"])
        self.assertEqual((f.destination / original["image"]["file"]).read_bytes(), original_bytes)
        self.assertEqual(original_bytes, f.image)
        self.assertEqual(len(list((f.out / "feeds").iterdir())), 1)
        self.assertIsNone(Feed.read(f.out / "participant-run/run.json")[1]["save"])

    def test_ready_unbound_and_missing_mode_do_not_invent_a_person(self):
        f = self.fixture; feed = self.new_feed()
        for body in [f.body(), f.body(1, ready=False, alive=False, save="", saveMode="", playerSqlId=-1)]:
            bad = copy.deepcopy(body); bad.pop("saveMode")
            with self.assertRaisesRegex(ValueError, "namespace unavailable"): Feed.validate_body(bad, f.receipt())
        unbound = f.body(2, ready=False, alive=False, save="", saveMode="", playerSqlId=-1)
        unbound.pop("body"); f.write_sources(unbound); feed.publish_play()
        view = self.latest(); self.assertEqual(view["people"], []); self.assertNotIn("inspection", view)
        self.assertEqual(view["image"]["sha256"], hashlib.sha256(f.image).hexdigest())
        f.write_sources(f.body(3), 2); feed.publish_play()
        self.assertEqual(len(self.latest()["people"]), 1)

    def test_native_source_owner_and_full_namespace_mismatches_are_rejected(self):
        f = self.fixture; good = f.body()
        for key, value in [("sessionId", str(uuid.uuid4())), ("pid", 12346), ("attempt", 2),
                           ("playerIndex", 1), ("playerSqlId", 0)]:
            with self.subTest(field=key):
                bad = copy.deepcopy(good); bad[key] = value
                with self.assertRaises(ValueError): Feed.validate_body(bad, f.receipt())
        for receipt in [dict(f.receipt(), saveMode="Rising"), dict(f.receipt(), save="other-save")]:
            with self.assertRaises(ValueError): Feed.validate_body(good, receipt)
        legacy = copy.deepcopy(good); legacy.pop("saveMode")
        legacy_receipt = f.receipt(); legacy_receipt.pop("launchMode")
        self.assertIs(Feed.validate_body(legacy, legacy_receipt), legacy)
        with self.assertRaises(ValueError): Feed.validate_body(good, legacy_receipt)

    def test_feed_world_clock_reset_and_native_clock_guards(self):
        f = self.fixture; feed = self.new_feed()
        f.write_sources(f.body()); feed.publish_play()
        body = f.body(1, worldHours=1); f.write_sources(body, 2); feed.publish_play()
        self.assertEqual(self.latest()["inspection"]["worldHours"], 1)
        self.assertNotEqual(self.latest()["capturedAtUnixMs"], self.latest()["inspection"]["capturedAtUnixMs"])
        self.assertFalse(feed.publish_play())
        reused = copy.deepcopy(body); reused["body"]["x"] += 1
        Feed.atomic(f.native.parent / "participant-state.json", reused)
        with self.assertRaisesRegex(ValueError, "time reused"): feed.body()
        regressed = copy.deepcopy(body); regressed["capturedAtUnixMs"] -= 1
        Feed.atomic(f.native.parent / "participant-state.json", regressed)
        with self.assertRaisesRegex(ValueError, "time regressed"): feed.body()

    def test_frame_body_source_guards_preserve_latest_on_rejected_pixels(self):
        f = self.fixture; feed = self.new_feed()
        f.write_sources(f.body()); feed.publish_play(); before = (f.destination / "latest.json").read_bytes()
        frame = Feed.read(f.native / "native.json")[1]
        frame["sequence"] += 1; frame["image"]["sha256"] = "0" * 64
        Feed.atomic(f.native / "native.json", frame)
        with self.assertRaises(ValueError): feed.publish_play()
        self.assertEqual((f.destination / "latest.json").read_bytes(), before)
        self.assertEqual((f.destination / "study-live-0000000000000001.png").read_bytes(), f.image)

    def test_main_retains_mode_save_sql_unbind_reset_intervals_and_samples(self):
        f = self.fixture
        bodies = [f.body(0), f.body(1, saveMode="Rising"), f.body(2, save="second-save"),
            f.body(3, playerSqlId=2), f.body(4, ready=False, alive=False, save="", saveMode="", playerSqlId=-1),
            f.body(5), f.body(6, worldHours=1)]
        self.assertEqual(f.run(bodies), 0)
        events = f.events()
        starts = [e for e in events if e["kind"] == "native-player-interval-started"]
        ends = [e for e in events if e["kind"] == "native-player-interval-ended"]
        self.assertEqual(len(starts), 6)
        self.assertEqual(len([e for e in ends if e["reason"] != "native-exit"]), 5)
        self.assertEqual(len([e for e in events if e["kind"] == "native-player-unbound"]), 1)
        self.assertEqual(len([e for e in ends if e["reason"] == "world-clock-reset"]), 1)
        for body in bodies:
            raw = Native.Lab.canonical(body)
            self.assertEqual((f.out / "body-samples" / (hashlib.sha256(raw).hexdigest() + ".json")).read_bytes(), raw)
        for event in starts:
            sample = Feed.read(f.out / "body-samples" / (event["sampleSha256"] + ".json"))[1]
            self.assertEqual((event["saveMode"], event["save"], event["playerIndex"], event["playerSqlId"]),
                (sample["saveMode"], sample["save"], sample["playerIndex"], sample["playerSqlId"]))
            self.assertEqual(event["sourceObservedAtUnixMs"], sample["capturedAtUnixMs"])
        samples = [e for e in events if e["kind"] == "native-body-sample"]
        self.assertEqual(len(samples), len([body for body in bodies if body["ready"]]))
        for event in samples:
            sample = Feed.read(f.out / "body-samples" / (event["sampleSha256"] + ".json"))[1]
            self.assertEqual((event["pid"], event["attempt"], event["saveMode"], event["save"],
                event["playerIndex"], event["playerSqlId"], event["sourceObservedAtUnixMs"]),
                (sample["pid"], sample["attempt"], sample["saveMode"], sample["save"],
                 sample["playerIndex"], sample["playerSqlId"], sample["capturedAtUnixMs"]))
        self.assertEqual(len(list((f.out / "feeds").iterdir())), 1)
        self.assertEqual(len([v for v in f.view_publications if v["state"] == "running"]), len(bodies))
        self.assertEqual(self.latest()["sequence"], len(bodies) + 2,
                         "the finality pointer is a distinct ended-view publication")
        self.assertIsNone(Feed.read(f.out / "participant-run/run.json")[1]["save"])
        terminal = [e for e in ends if e["reason"] == "native-exit"]
        self.assertEqual(len(terminal), 1, "the last body interval needs an explicit native-exit boundary")
        self.assertEqual(terminal[0]["interval"], starts[-1]["interval"])
        self.assertEqual(terminal[0]["lastSourceObservedAtUnixMs"], bodies[-1]["capturedAtUnixMs"])
        self.assertEqual(terminal[0]["terminalClock"], "native-process-exit-observed-at-event-time")
        self.assertNotIn("sourceObservedAtUnixMs", terminal[0], "process exit must not invent a fresh body sample")

    def test_terminal_publishes_ended_then_drains_then_qualifies(self):
        f = self.fixture; self.assertEqual(f.run([f.body()]), 0)
        self.assertLess(f.trace.index("feed:ended"), f.trace.index("archive-close:ended"))
        self.assertLess(f.trace.index("archive-close:ended"), f.trace.index("qualify"))
        self.assertTrue(Feed.read(f.out / "recording-completion.json")[1]["complete"])
        view = self.latest()
        finality_raw = (f.destination / view["archiveFinality"]["file"]).read_bytes()
        self.assertEqual(view["archiveFinality"]["sha256"], hashlib.sha256(finality_raw).hexdigest())
        finality = json.loads(finality_raw)
        self.assertTrue(finality["recordingComplete"])
        self.assertEqual(finality["runReceipt"]["status"], "completed")
        self.assertEqual(finality["catalog"], view["archiveCatalog"])
        self.assertEqual(hashlib.sha256((f.destination / finality["runReceipt"]["file"]).read_bytes()).hexdigest(),
                         finality["runReceipt"]["sha256"])
        self.assertEqual(hashlib.sha256((f.destination / finality["completionReceipt"]["file"]).read_bytes()).hexdigest(),
                         finality["completionReceipt"]["sha256"])
        self.assertEqual(Feed.read(f.out / "host.json")[1]["phase"], "ended")
        self.assertTrue(f.events()[-1]["recordingComplete"])

    def test_final_drain_failure_never_claims_recording_completion(self):
        f = self.fixture; self.assertEqual(f.run([f.body()], close_error="controlled final drain failure"), 0)
        completion = Feed.read(f.out / "recording-completion.json")[1]
        self.assertFalse(completion["complete"]); self.assertEqual(completion["archiveError"], "controlled final drain failure")
        self.assertNotIn("qualify", f.trace); self.assertFalse(f.events()[-1]["recordingComplete"])

    def test_incomplete_prior_geometry_epoch_never_claims_recording_completion(self):
        f = self.fixture; self.assertEqual(f.run([f.body()], incomplete_epoch=True), 0)
        self.assertFalse(Feed.read(f.out / "recording-completion.json")[1]["complete"])
        view = self.latest(); finality = Feed.read(f.destination / view["archiveFinality"]["file"])[1]
        catalog = Feed.read(f.destination / view["archiveCatalog"]["file"])[1]
        self.assertFalse(finality["recordingComplete"])
        self.assertFalse(catalog["aggregateCoverage"]["complete"])
        self.assertEqual(catalog["aggregateCoverage"]["unavailableCount"], 1)
        self.assertEqual(finality["runReceipt"]["status"], "incomplete")
        self.assertNotEqual(finality["projectionRunReceiptSha256"], finality["runReceipt"]["sha256"])
        self.assertIn("recording-qualification-failed", [e["kind"] for e in f.events()])
        self.assertFalse(f.events()[-1]["recordingComplete"])

    def test_no_native_save_return_never_claims_saved_or_complete_recording(self):
        f = self.fixture; self.assertEqual(f.run([f.body()], save_returned=False), 0)
        receipt = Feed.read(f.out / "participant-run/run.json")[1]
        self.assertFalse(receipt["nativeSaveReturned"]); self.assertEqual(receipt["status"], "incomplete")
        self.assertFalse(Feed.read(f.out / "recording-completion.json")[1]["complete"])
        self.assertNotIn("qualify", f.trace)

    @unittest.skipUnless(os.environ.get("SAO_NATIVE_PLAY04_RECORDED_SOURCE"), "retained native source explicitly supplied")
    def test_retained_native03_pixels_and_body_read_only(self):
        source = Path(os.environ["SAO_NATIVE_PLAY04_RECORDED_SOURCE"]).resolve()
        receipt = Feed.read(source / "run.json", Feed.MAX_RUN_JSON)[1]
        state = source / "attempts/0001/participant-state.json"
        native = source / "attempts/0001/native-view"
        frame_path = native / "native.json"
        descriptor = Feed.read(frame_path)[1]["image"]
        image = native / descriptor["file"]
        files = [source / "run.json", state, frame_path, image]
        before = {str(p): pin(p) for p in files}
        destination = self.root / "retained-source-read/feeds/0001"
        feed = Feed.ParticipantFeed(source, destination, receipt, receipt["sessionId"])
        frame, body = feed.frame(), feed.body()
        self.assertEqual((destination / descriptor["file"]).read_bytes(), image.read_bytes())
        self.assertEqual(frame["image"]["sha256"], pin(image))
        self.assertEqual(body["sessionId"], receipt["sessionId"]); self.assertEqual(body["pid"], receipt["pid"])
        self.assertEqual({str(p): pin(p) for p in files}, before)
        RECORDED_SOURCE_RECEIPTS.append({"source": str(source), "pins": before,
            "sessionId": receipt["sessionId"], "pid": receipt["pid"], "save": body["save"],
            "playerSqlId": body["playerSqlId"], "bodyCapturedAtUnixMs": body["capturedAtUnixMs"],
            "frameCapturedAtUnixMs": frame["capturedAtUnixMs"], "saveModeObserved": body.get("saveMode"),
            "scope": "Retained legacy source copied unchanged; no current native-play, game mode or rendered acceptance claim."})


if __name__ == "__main__": unittest.main(verbosity=2)
