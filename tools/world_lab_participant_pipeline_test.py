#!/usr/bin/env python3
"""Controlled participant bridge checks; these do not launch a native game."""
from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import tempfile
import time
import unittest
import uuid
import zlib

import world_lab_participant_feed as Feed
import world_lab_participant_session as Pipeline
import world_lab_session as Session


def watcher_path():
    import os
    return Path(os.environ.get("SAO_PARTICIPANT_WATCHER", str(Path(__file__).resolve().parents[2]
        / "speakeasy-r88-video-observation/tools/world_watch.py")))


def video_fixture_path():
    import os
    return Path(os.environ.get("SAO_PARTICIPANT_VIDEO_FIXTURE",
        str(watcher_path().with_name("fixtures") / "native_video.json")))


def png(width=2, height=2):
    def chunk(kind, payload):
        data = kind + payload
        return struct.pack(">I", len(payload)) + data + struct.pack(">I", zlib.crc32(data))
    pixels = b"".join(b"\x00" + b"\x13\x67\xb9" * width for _ in range(height))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(pixels)) + chunk(b"IEND", b""))


def protocol_recording(destination, study_id, session_id):
    """Labeled metadata-only protocol fixture; no native/encoded-media claim."""
    destination = Path(destination)
    assert destination.name == "0001" and destination.parent.name == "feeds", "protocol fixture requires safe session/feeds/0001 layout"
    stream = str(uuid.uuid4())
    path = destination / "latest.json"
    view = Feed.read(path)[1] if path.exists() else {"sessionId": session_id}
    view["video"] = {"state": "ended", "streamId": stream, "segments": [{"sequence": 1}]}
    page = {"schema": "mousecat.native-video-archive-page/1", "segments": [{"sequence": 1}]}
    Feed.atomic(Path(destination)/"archive-pages/protocol01.json", page)
    raw = (Path(destination)/"archive-pages/protocol01.json").read_bytes()
    index = {"schema": "mousecat.native-video-archive/1", "sessionId": session_id,
             "studyId": study_id, "attempt": 1, "streamId": stream, "coverage": "complete-published-segments",
             "tailConfirmed": True, "segmentCount": 1, "ptsStartMs": 0, "ptsEndMs": 250,
             "pages": [{"file": "archive-pages/protocol01.json", "sha256": hashlib.sha256(raw).hexdigest()}],
             "generation": hashlib.sha256(b"explicit protocol stub").hexdigest()}
    Feed.atomic(path, view)
    Feed.atomic(Path(destination)/"archive-index.json", index)
    # Exact current metadata completion shape; still no native/media claim.
    session_root = destination.resolve().parents[1]
    archive = {"schema":"sao.native-video-archive/1", "studyId":study_id,
        "source":str(session_root), "status":"stopped", "error":None, "priorFailureCount":0,
        "attempts":[{"attempt":1,"nativeProvenance":{"sessionId":session_id,"status":"completed"}}],
        "streams":[{"attempt":1,"streamId":stream,"coverage":"complete-published-segments",
                    "tailConfirmed":True,"lateAttachment":False,"retainedSegments":1}]}
    Feed.atomic(session_root/"video-archive/archive.json", archive)
    return view, index


class ParticipantPipeline(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="sao-participant-pipeline-controlled-")
        self.root = Path(self.temporary.name)
        self.run = self.root / "participant-run"
        self.native = self.run / "attempts/0001/native-view"
        self.native.mkdir(parents=True)
        self.now = int(time.time() * 1000)
        # Existence is explicit; no fixture is ever executed as an encoder.
        (self.root / "protocol-stub-encoder.exe").write_bytes(b"controlled non-executable protocol fixture")
        self.receipt = {"schema": "sao-study-run/1", "sessionId": str(uuid.uuid4()), "pid": 12345,
                        "host": "player", "participantInput": True, "window": "visible", "watch": True,
                        "launchNumber": 1, "observerDirectory": "attempts/0001", "status": "running"}
        self.study = Session.new_state("Controlled player test", 30, False)
        self.study.update(status="running", attempt=1, feedGeneration=1, canCheckpoint=True)
        self.destination = self.root / "feeds/0001"
        self.feed = Feed.ParticipantFeed(self.run, self.destination, self.receipt, self.study["id"])
        self.image = png()
        self.frame = {"schema": "sao-native-viewport/1", "sequence": 1, "observerSequence": 0,
            "capturedAtUnixMs": self.now - 200, "hours": 4.5,
            "image": {"file": "study-live-0000000000000001.png", "sha256": hashlib.sha256(self.image).hexdigest(),
                      "width": 2, "height": 2}}
        self.body = {"schema": "sao-native-participant/1", "sessionId": self.receipt["sessionId"],
            "pid": self.receipt["pid"], "attempt": 1, "save": "controlled-isolated-save",
            "playerIndex": 0, "playerSqlId": 27, "capturedAtUnixMs": self.now - 100, "worldHours": 4.6,
            "ready": True, "displayFocused": True, "alive": True,
            "body": {"x": 10.25, "y": 22.75, "z": 0, "label": "Actual native label"}}
        self.write_sources()

    def tearDown(self): self.temporary.cleanup()

    def write_sources(self):
        Feed.atomic(self.run / "run.json", self.receipt)
        Feed.atomic(self.native / "native.json", self.frame)
        Feed.atomic(self.run / "attempts/0001/participant-state.json", self.body)
        (self.native / self.frame["image"]["file"]).write_bytes(self.image)

    def publish(self): return self.feed.publish(self.study, now=self.now)

    def latest(self): return Feed.read(self.destination / "latest.json")[1]

    def test_source_bytes_and_independent_clocks(self):
        original = (self.native / self.frame["image"]["file"]).read_bytes()
        self.assertTrue(self.publish())
        view = self.latest()
        self.assertEqual(view["sequence"], 1)
        self.assertEqual(view["capturedAtUnixMs"], self.frame["capturedAtUnixMs"])
        self.assertEqual(view["inspection"]["capturedAtUnixMs"], self.body["capturedAtUnixMs"])
        self.assertNotEqual(view["capturedAtUnixMs"], view["inspection"]["capturedAtUnixMs"])
        self.assertEqual(view["camera"]["personIds"], [])
        self.assertEqual(view["people"][0]["id"], "native-player-0-sql-27")
        self.assertEqual((self.destination / view["image"]["file"]).read_bytes(), original)
        self.assertEqual((self.native / view["image"]["file"]).read_bytes(), original)
        self.assertFalse(self.publish())
        self.assertEqual(self.latest()["sequence"], 1)

    def test_new_body_same_pixels_and_terminal_snapshot(self):
        self.publish()
        self.body["capturedAtUnixMs"] += 10
        self.body["body"]["x"] += 1
        self.write_sources()
        self.publish()
        self.assertEqual(self.latest()["sequence"], 2)
        self.assertEqual(self.latest()["inspection"]["sequence"], 2)
        self.study.update(status="closed", canCheckpoint=False, canContinue=False, lastStopReason="operator-checkpoint")
        self.publish()
        self.assertEqual(self.latest()["state"], "ended")
        self.assertFalse(self.latest()["study"]["canContinue"])

    def test_unready_never_invents_body(self):
        self.body.update(ready=False, alive=False, save="", playerSqlId=-1)
        self.body.pop("body")
        self.write_sources()
        self.publish()
        self.assertEqual(self.latest()["people"], [])
        self.assertNotIn("inspection", self.latest())

    def test_observed_body_before_engine_sql_does_not_hide_pixels(self):
        self.body.update(ready=False, playerSqlId=-1)
        self.write_sources()
        self.publish()
        self.assertEqual(self.latest()["people"], [])
        self.assertEqual(self.latest()["image"]["sha256"], hashlib.sha256(self.image).hexdigest())
        self.assertNotIn("inspection", self.latest())
        self.body.update(ready=True, playerSqlId=27, capturedAtUnixMs=self.body["capturedAtUnixMs"] + 1)
        self.write_sources()
        self.publish()
        self.assertEqual(self.latest()["people"][0]["id"], "native-player-0-sql-27")

    def test_ready_sql_zero_and_receipt_save_mismatch_refused(self):
        bad = copy.deepcopy(self.body); bad["playerSqlId"] = 0
        with self.assertRaises(ValueError): Feed.validate_body(bad, self.receipt, now=self.now)
        receipt = dict(self.receipt, save="foreign-save")
        with self.assertRaisesRegex(ValueError, "save differs"): Feed.validate_body(self.body, receipt, now=self.now)

    def test_large_mod_inventory_run_receipt_is_supported(self):
        self.receipt["controlledInventory"] = "x" * (2 * 1024 * 1024)
        self.write_sources()
        self.publish()
        self.assertEqual(self.latest()["sessionId"], self.receipt["sessionId"])

    def test_accepted_pixels_are_not_redecoded_for_every_body_poll(self):
        from unittest.mock import patch
        import world_lab_run as Run
        original = Run.native_png
        with patch.object(Run, "native_png", wraps=original) as decoder:
            self.publish(); self.publish()
            self.body["capturedAtUnixMs"] += 1
            self.write_sources(); self.publish()
            self.assertEqual(decoder.call_count, 1)

    def test_missing_body_does_not_invent_details(self):
        (self.run / "attempts/0001/participant-state.json").unlink()
        self.publish()
        self.assertEqual(self.latest()["people"], [])

    def test_state_foreign_session_pid_attempt_and_slot(self):
        for key, value in (("sessionId", str(uuid.uuid4())), ("pid", 54321), ("attempt", 2),
                           ("playerIndex", 1), ("pid", True)):
            with self.subTest(key=key, value=value):
                bad = copy.deepcopy(self.body); bad[key] = value
                with self.assertRaises(ValueError): Feed.validate_body(bad, self.receipt, now=self.now)

    def test_unknown_and_malformed_body_refused(self):
        for mutate in (lambda v: v.update(playerSqlId=-1), lambda v: v["body"].update(x=float("inf")),
                       lambda v: v["body"].update(z=32), lambda v: v.update(capturedAtUnixMs=self.now+2001),
                       lambda v: v.update(ready=1), lambda v: v.update(extra="no"),
                       lambda v: v.update(save=""), lambda v: v["body"].update(label="bad\nlabel")):
            bad = copy.deepcopy(self.body); mutate(bad)
            with self.subTest(value=bad):
                with self.assertRaises(ValueError): Feed.validate_body(bad, self.receipt, now=self.now)

    def test_rebinding_native_owner_is_refused(self):
        for key, value in (("pid", 77), ("sessionId", str(uuid.uuid4())), ("launchNumber", 2),
                           ("host", "observer"), ("watch", False), ("participantInput", False)):
            bad = dict(self.receipt); bad[key] = value
            Feed.atomic(self.run / "run.json", bad)
            with self.subTest(key=key):
                with self.assertRaises(ValueError): self.publish()
        Feed.atomic(self.run / "run.json", self.receipt)

    def test_identity_change_is_refused_after_first_binding(self):
        self.publish()
        self.body["capturedAtUnixMs"] += 1
        self.body["playerSqlId"] += 1
        self.write_sources()
        with self.assertRaisesRegex(ValueError, "identity changed"): self.publish()

    def test_reused_source_clocks_are_refused(self):
        self.publish()
        self.body["body"]["x"] += 1
        self.write_sources()
        with self.assertRaisesRegex(ValueError, "clock reused"): self.publish()

    def test_world_clock_regression_refused(self):
        self.publish()
        self.body["capturedAtUnixMs"] += 1
        self.body["worldHours"] -= 1
        self.write_sources()
        with self.assertRaisesRegex(ValueError, "world clock regressed"): self.publish()

    def test_pixel_regression_observer_region_and_hash_refused(self):
        for update in ({"observerSequence": 1}, {"sequence": 0}, {"capturedAtUnixMs": self.now+2001},
                       {"views": []}):
            bad = dict(self.frame); bad.update(update)
            Feed.atomic(self.native / "native.json", bad)
            with self.subTest(update=update):
                with self.assertRaises(ValueError): self.feed.frame(now=self.now)
        Feed.atomic(self.native / "native.json", self.frame)
        (self.native / self.frame["image"]["file"]).write_bytes(self.image + b"changed")
        with self.assertRaisesRegex(ValueError, "pixels differ"): self.feed.frame(now=self.now)

    def test_foreign_optional_frame_stamp_refused(self):
        self.frame["participant"] = copy.deepcopy(self.body)
        self.frame["participant"]["sessionId"] = str(uuid.uuid4())
        self.write_sources()
        with self.assertRaises(ValueError): self.publish()

    def test_duplicate_source_json_refused(self):
        path = self.root / "duplicate.json"
        path.write_text('{"pid":1,"pid":2}', encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "duplicate"): Feed.read(path)

    def test_other_study_or_auto_continue_refused(self):
        for update in ({"id": str(uuid.uuid4())}, {"autoContinue": True}):
            bad = dict(self.study); bad.update(update)
            with self.subTest(update=update):
                with self.assertRaises(ValueError): self.feed.publish(bad, now=self.now)

    def test_registry_preserves_other_producer_and_rebinds_exact_view(self):
        registry = self.root / "registry.json"
        other = {"id": "other", "label": "Other", "directory": "retained", "sessionId": str(uuid.uuid4())}
        Feed.atomic(registry, [other])
        Feed.register_feed(registry, "controlled-player", "Player", "sao", self.destination, self.receipt["sessionId"])
        rows = Feed.read(registry)[1]
        self.assertEqual(rows[1], other)
        self.assertEqual(rows[0]["sessionId"], self.receipt["sessionId"])
        Feed.register_feed(registry, "controlled-player", "Player", "sao", self.destination, self.receipt["sessionId"])
        self.assertEqual(len(Feed.read(registry)[1]), 2)

    def actual_registry_clone(self):
        import os
        checkout = Path(__file__).resolve().parents[1]
        projects = checkout.parent.parent if checkout.parent.name == ".worktrees" else checkout.parent
        default = projects / "survivor-awareness/_scratch/c87-study/desktop-bindings.json"
        actual = Path(os.environ.get("SAO_PARTICIPANT_NATIVE_REGISTRY", str(default)))
        original = actual.read_bytes()
        rows = json.loads(original)
        self.assertGreaterEqual(len(rows),36,"actual existing native registry is required for this integration check")
        self.assertEqual(len({row["id"] for row in rows}),len(rows))
        # A bounded clone of 36 actual rows stays reusable when later attempts
        # register further feeds. Nothing writes the original registry.
        cloned = copy.deepcopy(rows[:36])
        registry=self.root/"actual-registry-clone.json";Feed.atomic(registry,cloned)
        self.addCleanup(lambda:self.assertEqual(actual.read_bytes(),original))
        return registry,cloned

    def test_actual_36_registry_clone_grows_to37_preserving_foreign_rows(self):
        registry,rows=self.actual_registry_clone()
        Feed.register_feed(registry,"controlled-registry-target","Controlled participant","sao",self.destination,self.receipt["sessionId"])
        current=Feed.read(registry)[1]
        self.assertEqual(len(current),37);self.assertEqual(current[1:],rows)

    def test_full128_registry_target_rebind_preserves_capacity(self):
        registry,rows=self.actual_registry_clone()
        while len(rows)<128:
            n=len(rows);rows.append({"id":f"controlled-retained-{n}","label":"Explicit synthetic retained view","directory":"controlled-directory","sessionId":str(uuid.uuid4())})
        Feed.atomic(registry,rows);target=rows[17]["id"]
        Feed.register_feed(registry,target,"Rebound controlled target","sao",self.destination,self.receipt["sessionId"])
        current=Feed.read(registry)[1];self.assertEqual(len(current),128)
        self.assertEqual(current[0]["id"],target);self.assertEqual(current[1:],[row for row in rows if row["id"]!=target])

    def test_new129th_registry_entry_refused_without_byte_change(self):
        registry,rows=self.actual_registry_clone()
        while len(rows)<128:
            n=len(rows);rows.append({"id":f"controlled-retained-{n}","label":"Explicit synthetic retained view","directory":"controlled-directory","sessionId":str(uuid.uuid4())})
        Feed.atomic(registry,rows);before=registry.read_bytes()
        with self.assertRaisesRegex(ValueError,"registry is full"):
            Feed.register_feed(registry,"controlled-129th","Overflow","sao",self.destination,self.receipt["sessionId"])
        self.assertEqual(registry.read_bytes(),before)

    def test_duplicate_registry_ids_refused_without_byte_change(self):
        registry,rows=self.actual_registry_clone();rows.append(copy.deepcopy(rows[0]));Feed.atomic(registry,rows);before=registry.read_bytes()
        with self.assertRaisesRegex(ValueError,"duplicate"):
            Feed.register_feed(registry,"controlled-registry-target","Controlled participant","sao",self.destination,self.receipt["sessionId"])
        self.assertEqual(registry.read_bytes(),before)

    def test_release_precedes_native_stop_and_foreign_command_refused(self):
        calls = []
        command = {"schema": "mousecat.native-view-command/1", "sessionId": str(uuid.uuid4()),
                   "sequence": 1, "action": "checkpoint"}
        Feed.atomic(self.destination / "commands/0000000000000001.json", command)
        acknowledged, result = Pipeline.consume_commands(self.destination, self.study, self.receipt["sessionId"], 0,
            lambda reason: calls.append(("release", reason)), lambda reason: calls.append(("stop", reason)))
        self.assertEqual(acknowledged, 1); self.assertEqual(result["status"], "rejected"); self.assertEqual(calls, [])
        command.update(sessionId=self.receipt["sessionId"], sequence=2)
        Feed.atomic(self.destination / "commands/0000000000000002.json", command)
        acknowledged, result = Pipeline.consume_commands(self.destination, self.study, self.receipt["sessionId"], 1,
            lambda reason: calls.append(("release", reason)), lambda reason: calls.append(("stop", reason)))
        self.assertEqual(acknowledged, 2); self.assertEqual(result["status"], "applied")
        self.assertEqual(calls, [("release", "native-checkpoint"), ("stop", "operator-checkpoint")])
        record = Feed.read(self.destination / "participant-command-receipt.json")[1]
        self.assertEqual(record["studyId"], self.study["id"])

    def test_continuation_and_arbitrary_commands_refused(self):
        for sequence, action in enumerate(("continue", "configure", "resume", "pause", "pan"), 1):
            command = {"schema": "mousecat.native-view-command/1", "sessionId": self.receipt["sessionId"],
                       "sequence": sequence, "action": action}
            Feed.atomic(self.destination / "commands" / f"{sequence:016d}.json", command)
            _, result = Pipeline.consume_commands(self.destination, self.study, self.receipt["sessionId"], sequence-1,
                lambda _: self.fail("unexpected lease release"), lambda _: self.fail("unexpected native stop"))
            self.assertEqual(result["status"], "rejected")

    def test_actual_mousecat_validator_and_source_http_read(self):
        # Explicit integration dependency can be set for any checkout. The
        # sibling default is the actual specified Mousecat worktree.
        import os
        mousecat = Path(os.environ.get("SAO_PARTICIPANT_MOUSECAT_ROOT", str(Path(__file__).resolve().parents[2] / "mousecat-development-continuity")))
        validator = mousecat / "src/core/native-view.mjs"
        self.assertTrue(validator.is_file(), "actual Mousecat validator is required for this scoped check")
        self.publish()
        script = """import {readFile} from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
const {validateNativeView,createNativeViews}=await import(pathToFileURL(process.argv[1]).href);
const view=JSON.parse(await readFile(process.argv[2],'utf8'));validateNativeView(view);
const api=createNativeViews({registryPath:process.argv[3]});const snapshot=await api.snapshot('controlled-player');
const bytes=await api.image('controlled-player',new URLSearchParams(snapshot.imageUrl.split('?')[1]));
if(!bytes.length||snapshot.view.people[0].label!=='Actual native label')throw Error('source join differs');
console.log(JSON.stringify({schema:true,httpImageBytes:bytes.length,bodyClock:snapshot.view.inspection.capturedAtUnixMs,pixelClock:snapshot.view.capturedAtUnixMs}));"""
        registry = self.root / "registry.json"
        Feed.register_feed(registry, "controlled-player", "Player", "sao", self.destination, self.receipt["sessionId"])
        output = subprocess.run(["node", "--input-type=module", "-e", script, str(validator),
                                 str(self.destination / "latest.json"), str(registry)], capture_output=True, text=True)
        self.assertEqual(output.returncode, 0, output.stderr)

        self.assertEqual(json.loads(output.stdout)["httpImageBytes"], len(self.image))
        self.study.update(status="closed", canCheckpoint=False, canContinue=False)
        self.publish()
        output = subprocess.run(["node", "--input-type=module", "-e", script, str(validator),
                                 str(self.destination / "latest.json"), str(registry)], capture_output=True, text=True)
        self.assertEqual(output.returncode, 0, output.stderr)

    def test_existing_encoded_video_bytes_relay_unchanged(self):
        # Existing encoded fixture, with explicitly controlled participant
        # metadata. This checks the protocol and never claims native gameplay.
        import base64
        module, _ = Feed.load_video_module(watcher_path())
        fixture = json.loads(video_fixture_path().read_text())
        value = copy.deepcopy(fixture["manifest"])
        shift = self.now - value["segments"][-1]["endCapturedAtUnixMs"]
        for segment in value["segments"]:
            segment.update(observerSequence=0, sites=[])
            segment.pop("crops", None)
            for key in ("capturedAtUnixMs", "endCapturedAtUnixMs"): segment[key] += shift
        for descriptor in [value["init"], *value["segments"]]:
            (self.native / descriptor["file"]).write_bytes(base64.b64decode(fixture["files"][descriptor["file"]]))
        Feed.atomic(self.native / "latest-video.json", value)
        self.feed.video = module.VideoRelay(self.native, self.destination)
        self.publish()
        observed = self.latest()["video"]
        self.assertEqual(observed["schema"], "mousecat.native-video/1")
        self.assertEqual(observed["segments"], value["segments"])
        for descriptor in [value["init"], *value["segments"]]:
            source = (self.native / descriptor["file"]).read_bytes()
            self.assertEqual((self.destination / descriptor["file"]).read_bytes(), source)
            self.assertEqual(hashlib.sha256(source).hexdigest(), descriptor["sha256"])
        self.assertFalse(self.publish())
        segment = value["segments"][0]
        segment["cameraFrames"] = [{"frameSequence": sequence, "camera": {
            "schema": "sao.native-frame-camera/1", "mode": "viewpoint-third", "ready": True}}
            for sequence in range(segment["firstFrameSequence"], segment["lastFrameSequence"] + 1)]
        Feed.atomic(self.native / "latest-video.json", value)
        self.assertTrue(self.publish())
        self.assertEqual(self.latest()["video"]["segments"][0]["cameraFrames"], segment["cameraFrames"])
        import os
        mousecat = Path(os.environ.get("SAO_PARTICIPANT_MOUSECAT_ROOT", str(Path(__file__).resolve().parents[2]
            / "mousecat-development-continuity")))
        validator = mousecat / "src/core/native-view.mjs"
        script = """import {readFile} from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
const {validateNativeView}=await import(pathToFileURL(process.argv[1]).href);
validateNativeView(JSON.parse(await readFile(process.argv[2],'utf8')));"""
        accepted = subprocess.run(["node", "--input-type=module", "-e", script, str(validator),
            str(self.destination / "latest.json")], capture_output=True, text=True)
        self.assertEqual(accepted.returncode, 0, accepted.stderr)
        accepted_rows = copy.deepcopy(segment["cameraFrames"])
        for rows, reason in (([accepted_rows[0], accepted_rows[-1]], "encoded sample count"),
                             (None, "camera frame count")):
            with self.subTest(camera_rows=reason):
                segment["cameraFrames"] = rows
                Feed.atomic(self.native / "latest-video.json", value)
                with self.assertRaisesRegex(ValueError, reason): self.publish()
                self.assertEqual(self.latest()["video"]["segments"][0]["cameraFrames"], accepted_rows)
        segment["cameraFrames"] = accepted_rows
        segment["cameraFrames"][0]["camera"]["ready"] = False
        Feed.atomic(self.native / "latest-video.json", value)
        with self.assertRaisesRegex(ValueError, "native camera readiness"):
            self.publish()
        self.assertTrue(self.latest()["video"]["segments"][0]["cameraFrames"][0]["camera"]["ready"])
        segment["cameraFrames"][0]["camera"]["ready"] = True
        # A cross-session observer epoch/region must never be repackaged as
        # participant capture, even when the underlying bytes are valid.
        value["segments"][0]["observerSequence"] = 1
        Feed.atomic(self.native / "latest-video.json", value)
        with self.assertRaisesRegex(ValueError, "observer regions"): self.publish()

    def test_whole_native_viewport_crop_relay_and_foreign_region_refusal(self):
        # Existing encoded bytes with controlled full-frame metadata; this
        # verifies the real relay/Mousecat descriptor, not native gameplay.
        import base64
        module, _ = Feed.load_video_module(watcher_path())
        fixture = json.loads(video_fixture_path().read_text())
        value = copy.deepcopy(fixture["manifest"])
        crop = {"id": "participant-viewport", "slot": 0, "left": 0, "top": 0,
                "width": value["width"], "height": value["height"]}
        shift = self.now - value["segments"][-1]["endCapturedAtUnixMs"]
        for segment in value["segments"]:
            segment.update(observerSequence=0, sites=[], crops=[dict(crop)])
            for key in ("capturedAtUnixMs", "endCapturedAtUnixMs"): segment[key] += shift
        for descriptor in [value["init"], *value["segments"]]:
            (self.native / descriptor["file"]).write_bytes(base64.b64decode(fixture["files"][descriptor["file"]]))
        self.feed.video = module.VideoRelay(self.native, self.destination)
        Feed.atomic(self.native / "latest-video.json", value)
        self.publish()
        self.assertEqual(self.latest()["video"]["segments"], value["segments"])
        self.assertEqual(self.latest()["camera"]["personIds"], [])
        for descriptor in [value["init"], *value["segments"]]:
            self.assertEqual((self.destination / descriptor["file"]).read_bytes(),
                             (self.native / descriptor["file"]).read_bytes())
        bad_crops = [None, [dict(crop, id="other")], [dict(crop, slot=True)],
                     [dict(crop, left=1)], [dict(crop, width=crop["width"]-1)],
                     [dict(crop, extra=1)], [crop, crop]]
        for bad in bad_crops:
            with self.subTest(crop=bad):
                invalid = copy.deepcopy(value); invalid["segments"][0]["crops"] = bad
                Feed.atomic(self.native / "latest-video.json", invalid)
                with self.assertRaisesRegex(ValueError, "viewport crop differs"): self.publish()
        for key, bad in [("observerSequence", True), ("sites", [{"id":"invented-body-camera"}])]:
            with self.subTest(field=key):
                invalid = copy.deepcopy(value); invalid["segments"][0][key] = bad
                Feed.atomic(self.native / "latest-video.json", invalid)
                with self.assertRaisesRegex(ValueError, "observer regions"): self.publish()

    def test_supervisor_connected_lifecycle_with_controlled_owner(self):
        from types import SimpleNamespace
        from unittest.mock import patch
        import world_lab_video_archive as Archive
        import world_lab_participant_lease as Lease

        out = self.root / "controlled-session"
        calls = []
        receipt = dict(self.receipt)

        class Owner:
            returncode = 0
            pid = 88
            count = 0
            def poll(owner):
                owner.count += 1
                if owner.count == 1: return None
                final = dict(receipt, status="completed", save=self.body["save"], lastHours=4.6,
                             terminal={"startHours": 4.5, "endHours": 4.6, "stopReason": "operator-checkpoint"})
                Feed.atomic(out / "participant-run/run.json", final)
                return 0

        class Broker:
            def __init__(broker, run): calls.append(("broker", Path(run)))
            def poll(broker): calls.append(("poll", None))
            def release(broker, reason): calls.append(("release", reason))
            def close(broker): calls.append(("broker-close", None))

        class Retention:
            # Explicit protocol stub: these descriptors do not represent an
            # encoder/native recording. Actual require_recording remains called.
            def close(archive):
                calls.append(("archive-close", None))
                study = Feed.read(out / "study-session.json")[1]
                protocol_recording(out / "feeds/0001", study["id"], receipt["sessionId"])


        def prepared(path, process):
            native = path.parent / "attempts/0001/native-view"
            native.mkdir(parents=True)
            Feed.atomic(path, receipt)
            Feed.atomic(native / "native.json", self.frame)
            Feed.atomic(native.parent / "participant-state.json", self.body)
            (native / self.frame["image"]["file"]).write_bytes(self.image)
            return receipt

        args = SimpleNamespace(participant_input=True, window="visible", auto_continue=False,
            package=self.root / "controlled-package", out=out, game=self.root / "controlled-game", jdk=self.root / "controlled-jdk",
            watcher=watcher_path(), registry=self.root / "controlled-registry.json", duration=30, label="Controlled native owner",
            view_id="controlled-owner", project_ref="sao", video_encoder=self.root/"protocol-stub-encoder.exe")
        with patch.object(Pipeline.subprocess, "Popen", return_value=Owner()) as launch, \
             patch.object(Session, "participant_command", return_value=["controlled-no-game"]), \
             patch.object(Session, "wait_for_run", side_effect=prepared), \
             patch.object(Session, "open_mousecat", return_value=None), \
             patch.object(Archive, "start", return_value=Retention()) as retain, \
             patch.object(Lease, "ParticipantLeaseBroker", Broker):
            self.assertEqual(Pipeline.supervise(args), 0)
            launch.assert_called_once_with(["controlled-no-game"])
            self.assertEqual(retain.call_args.kwargs["run_name"], "participant-run")
        self.assertEqual(Feed.read(out / "study-session.json")[1]["status"], "closed")
        view = Feed.read(out / "feeds/0001/latest.json")[1]
        self.assertEqual(view["state"], "ended")
        self.assertFalse(view["study"]["canContinue"])
        self.assertEqual(calls[-1], ("broker-close", None))
        self.assertIn(("release", "native-attempt-ended"), calls)
        self.assertIn(("archive-close", None), calls)

    def _exercise_windows_publisher_turnover(self, stage, invalid=None):
        from types import SimpleNamespace
        from unittest.mock import patch
        import world_lab_video_archive as Archive
        import world_lab_participant_lease as Lease
        out = self.root / ("controlled-turnover-" + stage + "-" + str(invalid))
        calls = []
        receipt = dict(self.receipt)
        faulted = False
        actual_body = Feed.ParticipantFeed.body
        actual_publish = Feed.ParticipantFeed.publish

        def complete_receipt():
            Feed.atomic(out / "participant-run/run.json", dict(receipt, status="completed",
                save=self.body["save"], lastHours=4.7,
                terminal={"startHours":4.5,"endHours":4.7,"stopReason":"controlled-owner-completed"}))

        class Owner:
            returncode = 0
            pid = 88
            count = 0
            def poll(owner):
                owner.count += 1
                if owner.count <= 2 or invalid is not None: return None
                complete_receipt(); return 0
            def wait(owner, timeout):
                calls.append(("native-owner-wait", timeout))
                complete_receipt(); return 0

        class Broker:
            def __init__(broker, run): pass
            def poll(broker): calls.append(("broker-poll", None))
            def release(broker, reason): calls.append(("release", reason))
            def close(broker): calls.append(("broker-close", None))

        class Retention:
            # Only a metadata protocol stub, never native/encoded-media proof.
            def close(archive):
                calls.append(("archive-close", None))
                if invalid is None:
                    study = Feed.read(out / "study-session.json")[1]
                    protocol_recording(out / "feeds/0001", study["id"], receipt["sessionId"])

        def prepared(path, process):
            native = path.parent / "attempts/0001/native-view"
            native.mkdir(parents=True)
            Feed.atomic(path, receipt); Feed.atomic(native / "native.json", self.frame)
            Feed.atomic(native.parent / "participant-state.json", self.body)
            (native / self.frame["image"]["file"]).write_bytes(self.image)
            return receipt

        def turnover(publisher, location):
            nonlocal faulted
            if stage != location or faulted: return
            faulted = True
            # Simulate one Windows atomic-reader denial, then expose a distinct
            # complete producer frame. Product body/publish validation remains real.
            frame = dict(self.frame, sequence=2, capturedAtUnixMs=self.now+1)
            body = copy.deepcopy(self.body)
            body.update(capturedAtUnixMs=self.now+2, worldHours=4.7)
            if invalid == "malformed": body["schema"] = "malformed-protocol-fixture"
            elif invalid == "foreign": body["sessionId"] = str(uuid.uuid4())
            Feed.atomic(publisher.native / "native.json", frame)
            Feed.atomic(publisher.native.parent / "participant-state.json", body)
            calls.append(("transient-permission", location))
            raise PermissionError(13, "Controlled Windows atomic-reader turnover",
                                  str(publisher.native.parent / "participant-state.json"))

        def body_read(publisher, *args, **kwargs):
            turnover(publisher, "body")
            return actual_body(publisher, *args, **kwargs)

        def publish(publisher, *args, **kwargs):
            turnover(publisher, "publish")
            accepted = actual_publish(publisher, *args, **kwargs)
            if accepted: calls.append(("accepted-frame", Feed.read(publisher.destination / "latest.json")[1]["capturedAtUnixMs"]))
            return accepted

        args = SimpleNamespace(participant_input=True, window="visible", auto_continue=False,
            package=self.root/"protocol-package", out=out, game=self.root/"protocol-game", jdk=self.root/"protocol-jdk",
            watcher=watcher_path(), registry=self.root/"turnover-registry.json", duration=30,
            label="Controlled Windows turnover", view_id="controlled-turnover", project_ref="sao",
            video_encoder=self.root/"protocol-stub-encoder.exe")
        with patch.object(Pipeline.subprocess, "Popen", return_value=Owner()), \
             patch.object(Session, "participant_command", return_value=["controlled-no-game"]), \
             patch.object(Session, "wait_for_run", side_effect=prepared), \
             patch.object(Session, "open_mousecat", return_value=None) as selected, \
             patch.object(Archive, "start", return_value=Retention()), \
             patch.object(Lease, "ParticipantLeaseBroker", Broker), \
             patch.object(Feed.ParticipantFeed, "body", body_read), \
             patch.object(Feed.ParticipantFeed, "publish", publish), \
             patch.object(Session, "stop_process", side_effect=AssertionError("native owner must not be killed")):
            if invalid is None:
                self.assertEqual(Pipeline.supervise(args), 0)
                selected.assert_called_once()
            else:
                message = "state fields differ" if invalid == "malformed" else "state owner differs"
                with self.assertRaisesRegex(ValueError, message): Pipeline.supervise(args)
                selected.assert_not_called()
        self.assertEqual(sum(c[0] == "transient-permission" for c in calls), 1)
        self.assertEqual(Feed.read(out/"participant-run/run.json")[1]["status"], "completed")
        self.assertIn(("archive-close", None), calls)
        self.assertEqual(calls[-1], ("broker-close", None))
        if invalid is None:
            self.assertIn(("accepted-frame", self.now+1), calls)
            self.assertEqual(Feed.read(out/"study-session.json")[1]["status"], "closed")
            self.assertTrue((out/"participant-recording-completion.json").is_file())
            self.assertFalse((out/"participant-orchestration-failure.json").exists())
            self.assertIn(("release", "native-attempt-ended"), calls)
        else:
            self.assertEqual(Feed.read(out/"study-session.json")[1]["status"], "failed")
            self.assertFalse((out/"participant-recording-completion.json").exists())
            failure = Feed.read(out/"participant-orchestration-failure.json")[1]
            self.assertEqual(failure["errorType"], "ValueError")
            self.assertIn(("release", "participant-session-exit"), calls)
            self.assertIn(("native-owner-wait", 90), calls)
            self.assertLess(calls.index(("release", "participant-session-exit")), calls.index(("native-owner-wait", 90)))
            self.assertEqual((out/"participant-run/cache/Lua/StudyRunnerStop0001.txt").read_text().strip(), "participant-session-exit")

    def test_windows_atomic_body_and_publish_turnover_retry_complete_frame(self):
        for stage in ("body", "publish"):
            with self.subTest(stage=stage): self._exercise_windows_publisher_turnover(stage)

    def test_turnover_does_not_swallow_malformed_or_foreign_state(self):
        for invalid in ("malformed", "foreign"):
            with self.subTest(invalid=invalid): self._exercise_windows_publisher_turnover("body", invalid)

    def test_release_failure_still_requests_native_exit_and_closes_lock(self):
        from types import SimpleNamespace
        from unittest.mock import patch
        import world_lab_video_archive as Archive
        import world_lab_participant_lease as Lease
        out = self.root / "controlled-failure-session"
        calls = []

        class Owner:
            returncode = None
            pid = 88
            def poll(owner): return None
            def wait(owner, timeout): calls.append(("native-owner-wait", timeout)); owner.returncode = 0; return 0

        class Broker:
            def __init__(broker, run): pass
            def poll(broker): raise ValueError("controlled-input-refusal")
            def release(broker, reason): calls.append(("release", reason)); raise OSError("controlled-release-write-failure")
            def close(broker): calls.append(("broker-close", None))

        class Retention:
            def close(archive): calls.append(("archive-close", None))

        def prepared(path, process):
            path.parent.mkdir(parents=True)
            Feed.atomic(path, self.receipt)
            return self.receipt

        args = SimpleNamespace(participant_input=True, window="visible", auto_continue=False,
            package=self.root / "controlled-package", out=out, game=self.root / "controlled-game", jdk=self.root / "controlled-jdk",
            watcher=watcher_path(), registry=self.root / "controlled-registry.json", duration=30, label="Controlled failure owner",
            view_id="controlled-failure", project_ref="sao", video_encoder=self.root/"protocol-stub-encoder.exe")
        with patch.object(Pipeline.subprocess, "Popen", return_value=Owner()), \
             patch.object(Session, "participant_command", return_value=["controlled-no-game"]), \
             patch.object(Session, "wait_for_run", side_effect=prepared), \
             patch.object(Archive, "start", return_value=Retention()), \
             patch.object(Lease, "ParticipantLeaseBroker", Broker), \
             patch.object(Session, "stop_process", side_effect=AssertionError("native owner must not be killed")):
            with self.assertRaisesRegex(OSError, "release-write-failure"): Pipeline.supervise(args)
        self.assertEqual((out / "participant-run/cache/Lua/StudyRunnerStop0001.txt").read_text().strip(),
                         "participant-session-exit")
        self.assertIn(("native-owner-wait", 90), calls)
        self.assertEqual(calls[-1], ("broker-close", None))
        self.assertIn(("archive-close", None), calls)
        failure = Feed.read(out / "participant-orchestration-failure.json")[1]
        self.assertEqual(failure["reason"], "controlled-input-refusal")


class RecordingBoundaries(unittest.TestCase):
    def test_actual_completion_function_and_rejected_protocols(self):
        with tempfile.TemporaryDirectory(prefix="sao-recording-protocol-") as temporary:
            root=Path(temporary)/"feeds/0001";root.mkdir(parents=True);session=str(uuid.uuid4());study=str(uuid.uuid4())
            view,index=protocol_recording(root,study,session)
            self.assertEqual(Pipeline.require_recording(root,study,session)["segmentCount"],1)
            vectors=[("video-failed","view",lambda v:v["video"].update(state="failed")),
                     ("video-active","view",lambda v:v["video"].update(state="active")),
                     ("video-empty","view",lambda v:v["video"].update(segments=[])),
                     ("view-foreign-session","view",lambda v:v.update(sessionId=str(uuid.uuid4()))),
                     ("partial","index",lambda v:v.update(coverage="partial")),
                     ("no-tail","index",lambda v:v.update(tailConfirmed=False)),
                     ("no-pages","index",lambda v:v.update(pages=[])),
                     ("zero-segments","index",lambda v:v.update(segmentCount=0)),
                     ("boolean-count","index",lambda v:v.update(segmentCount=True)),
                     ("foreign-session","index",lambda v:v.update(sessionId=str(uuid.uuid4()))),
                     ("foreign-study","index",lambda v:v.update(studyId=str(uuid.uuid4()))),
                     ("foreign-attempt","index",lambda v:v.update(attempt=2)),
                     ("boolean-attempt","index",lambda v:v.update(attempt=True)),
                     ("foreign-stream","index",lambda v:v.update(streamId=str(uuid.uuid4())))]
            for label,target,mutate in vectors:
                with self.subTest(label=label):
                    a,b=copy.deepcopy(view),copy.deepcopy(index);mutate(a if target=="view" else b)
                    Feed.atomic(root/"latest.json",a);Feed.atomic(root/"archive-index.json",b)
                    with self.assertRaises(ValueError):Pipeline.require_recording(root,study,session)
            Feed.atomic(root/"latest.json",view);(root/"archive-index.json").unlink()
            with self.assertRaisesRegex(ValueError,"unsafe participant source file"):Pipeline.require_recording(root,study,session)

    def test_completion_requires_all_geometry_epochs_and_exact_archive_owner(self):
        with tempfile.TemporaryDirectory(prefix="sao-recording-epoch-protocol-") as temporary:
            root=Path(temporary)/"feeds/0001";root.mkdir(parents=True)
            session,study=str(uuid.uuid4()),str(uuid.uuid4())
            protocol_recording(root,study,session)
            path=root.resolve().parents[1]/"video-archive/archive.json"
            archive=Feed.read(path)[1]
            earlier=copy.deepcopy(archive["streams"][0]);earlier["streamId"]=str(uuid.uuid4())
            archive["streams"].insert(0,earlier);Feed.atomic(path,archive)
            self.assertEqual(len(Pipeline.require_recording(root,study,session)["geometryEpochs"]),2)
            vectors=[("foreign-study",lambda a:a.update(studyId=str(uuid.uuid4()))),
                ("foreign-session",lambda a:a["attempts"][0]["nativeProvenance"].update(sessionId=str(uuid.uuid4()))),
                ("native-not-completed",lambda a:a["attempts"][0]["nativeProvenance"].update(status="failed")),
                ("boolean-native-attempt",lambda a:a["attempts"][0].update(attempt=True)),
                ("wrong-source",lambda a:a.update(source=str(root))),
                ("still-recording",lambda a:a.update(status="recording")),
                ("collector-error",lambda a:a.update(error="controlled archive failure")),
                ("prior-failure",lambda a:a.update(priorFailureCount=1)),
                ("partial-earlier-epoch",lambda a:a["streams"][0].update(coverage="partial")),
                ("unconfirmed-earlier-tail",lambda a:a["streams"][0].update(tailConfirmed=False)),
                ("late-earlier-attachment",lambda a:a["streams"][0].update(lateAttachment=True)),
                ("empty-earlier-epoch",lambda a:a["streams"][0].update(retainedSegments=0)),
                ("foreign-epoch-attempt",lambda a:a["streams"][0].update(attempt=2)),
                ("boolean-epoch-attempt",lambda a:a["streams"][0].update(attempt=True)),
                ("duplicate-epoch",lambda a:a["streams"][0].update(streamId=a["streams"][1]["streamId"])),
                ("final-epoch-absent",lambda a:a["streams"].pop())]
            for label,mutate in vectors:
                with self.subTest(label=label):
                    bad=copy.deepcopy(archive);mutate(bad);Feed.atomic(path,bad)
                    with self.assertRaises(ValueError):Pipeline.require_recording(root,study,session)
            Feed.atomic(path,archive);path.unlink()
            with self.assertRaisesRegex(ValueError,"unsafe participant source file"):
                Pipeline.require_recording(root,study,session)

    def test_missing_encoder_refused_before_any_launch(self):
        from types import SimpleNamespace
        from unittest.mock import patch
        import world_lab_video_archive as Archive
        with patch.object(Pipeline.subprocess,"Popen") as launch,patch.object(Archive,"start") as archive:
            with self.assertRaisesRegex(ValueError,"continuous native recording"):
                Pipeline.supervise(SimpleNamespace(participant_input=True,window="visible",video_encoder=None))
            launch.assert_not_called();archive.assert_not_called()

    def exercise_supervisor(self,mode):
        from types import SimpleNamespace
        from unittest.mock import patch
        import world_lab_video_archive as Archive
        import world_lab_participant_lease as Lease
        fixture=ParticipantPipeline();fixture.setUp()
        try:
            out=fixture.root/"controlled-supervisor";calls=[];receipt=dict(fixture.receipt)
            class Retention:
                error="controlled-start-error" if mode=="archive-start" else None
                def close(owner):
                    calls.append("archive-close")
                    if mode=="archive-close":owner.error="controlled-close-error";return
                    if not (out/"feeds/0001/latest.json").exists():return
                    study=Feed.read(out/"study-session.json")[1]
                    view,index=protocol_recording(out/"feeds/0001",study["id"],receipt["sessionId"])
                    if mode=="no-index":(out/"feeds/0001/archive-index.json").unlink()
                    elif mode=="partial":index["coverage"]="partial";Feed.atomic(out/"feeds/0001/archive-index.json",index)
                    elif mode=="foreign":index["sessionId"]=str(uuid.uuid4());Feed.atomic(out/"feeds/0001/archive-index.json",index)
                    elif mode=="video-failed":view["video"]["state"]="failed";Feed.atomic(out/"feeds/0001/latest.json",view)
            retention=Retention()
            class Owner:
                pid=88;returncode=0;count=0
                def poll(owner):
                    owner.count+=1
                    if owner.count==1:
                        if mode=="archive-live":retention.error="controlled-live-error"
                        return None
                    final=dict(receipt,status="completed",save=fixture.body["save"],lastHours=4.6,
                               terminal={"startHours":4.5,"endHours":4.6,"stopReason":"operator-checkpoint"})
                    Feed.atomic(out/"participant-run/run.json",final);return 0
                def wait(owner,timeout):self.fail("completed native owner must not be waited/killed")
            class Broker:
                def __init__(owner,run):pass
                def poll(owner):pass
                def release(owner,reason):calls.append("release:"+reason)
                def close(owner):calls.append("broker-close")
            def prepared(path,process):
                native=path.parent/"attempts/0001/native-view";native.mkdir(parents=True)
                Feed.atomic(path,receipt);Feed.atomic(native/"native.json",fixture.frame)
                Feed.atomic(native.parent/"participant-state.json",fixture.body)
                (native/fixture.frame["image"]["file"]).write_bytes(fixture.image);return receipt
            args=SimpleNamespace(participant_input=True,window="visible",auto_continue=False,
                package=fixture.root/"protocol-package",out=out,game=fixture.root/"protocol-game",jdk=fixture.root/"protocol-jdk",
                watcher=watcher_path(),registry=fixture.root/"registry.json",duration=30,label="Protocol failure fixture",
                view_id="protocol-owner",project_ref="sao",video_encoder=fixture.root/"protocol-stub-encoder.exe")
            with patch.object(Pipeline.subprocess,"Popen",return_value=Owner()) as launch,\
                 patch.object(Session,"participant_command",return_value=["controlled-no-game"]),\
                 patch.object(Session,"wait_for_run",side_effect=prepared),\
                 patch.object(Session,"open_mousecat",return_value=None),\
                 patch.object(Archive,"start",return_value=retention),\
                 patch.object(Lease,"ParticipantLeaseBroker",Broker),\
                 patch.object(Session,"stop_process",side_effect=AssertionError("native runner must not be killed")):
                with self.assertRaises((ValueError,FileNotFoundError)):Pipeline.supervise(args)
                if mode=="archive-start":launch.assert_not_called()
            self.assertEqual(Feed.read(out/"study-session.json")[1]["status"],"failed")
            self.assertFalse((out/"participant-recording-completion.json").exists())
            if mode!="archive-start":self.assertEqual(Feed.read(out/"participant-run/run.json")[1]["status"],"completed")
            self.assertIn("archive-close",calls)
        finally:fixture.tearDown()

    def test_archive_start_live_close_errors_remain_failed(self):
        for mode in ("archive-start","archive-live","archive-close"):
            with self.subTest(mode=mode):self.exercise_supervisor(mode)

    def test_native_save_completion_does_not_hide_recording_failure(self):
        for mode in ("video-failed","no-index","partial","foreign"):
            with self.subTest(mode=mode):self.exercise_supervisor(mode)


if __name__ == "__main__": unittest.main(verbosity=2)
