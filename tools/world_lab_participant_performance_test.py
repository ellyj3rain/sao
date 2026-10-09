#!/usr/bin/env python3
"""Receipt/source-event controls on the actual participant production methods."""
import os
from pathlib import Path
import tempfile
import time
import unittest
import uuid
from types import SimpleNamespace
from unittest.mock import patch

import world_lab_participant_feed as Feed
import world_lab_participant_session as Pipeline
import world_lab_session as Session
from world_lab_participant_pipeline_test import png, protocol_recording


class Performance(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="sao-participant-performance-")
        self.root = Path(self.temporary.name)
        self.run = self.root / "participant-run"
        self.native = self.run / "attempts/0001/native-view"
        self.native.mkdir(parents=True)
        self.receipt = {"schema":"sao-study-run/1", "sessionId":str(uuid.uuid4()), "pid":12345,
            "host":"player", "participantInput":True, "window":"visible", "watch":True,
            "launchNumber":1, "observerDirectory":"attempts/0001", "status":"running"}
        self.study = Session.new_state("Source-event protocol control", 30, False)
        self.study.update(status="running", attempt=1, feedGeneration=1, canCheckpoint=True)
        self.now = int(time.time()*1000)
        self.body = {"schema":"sao-native-participant/1", "sessionId":self.receipt["sessionId"],
            "pid":12345, "attempt":1, "save":"controlled-save", "playerIndex":0, "playerSqlId":27,
            "capturedAtUnixMs":self.now-10, "worldHours":4.5, "ready":True,
            "displayFocused":True, "alive":True, "body":{"x":1,"y":2,"z":0,"label":"Protocol body"}}
        image = png()
        import hashlib
        self.frame = {"schema":"sao-native-viewport/1", "sequence":1, "observerSequence":0,
            "capturedAtUnixMs":self.now-20, "hours":4.4, "image":{"file":"study-live-0000000000000001.png",
            "sha256":hashlib.sha256(image).hexdigest(), "width":2,"height":2}}
        self.image = image
        self.write_sources(self.run)
        self.feed = Feed.ParticipantFeed(self.run, self.root/"feeds/0001", self.receipt, self.study["id"])

    def tearDown(self): self.temporary.cleanup()

    def write_sources(self, run):
        native = run/"attempts/0001/native-view"
        native.mkdir(parents=True, exist_ok=True)
        Feed.atomic(run/"run.json", self.receipt)
        Feed.atomic(native/"native.json", self.frame)
        Feed.atomic(native.parent/"participant-state.json", self.body)
        (native/self.frame["image"]["file"]).write_bytes(self.image)

    def test_unchanged_publications_parse_run_once(self):
        with patch.object(Feed, "read", wraps=Feed.read) as reader:
            for _ in range(5): self.feed.publish(self.study, now=self.now)
        self.assertEqual(sum(Path(c.args[0])==self.run/"run.json" for c in reader.call_args_list),1)

    def test_new_body_keeps_exact_png_and_cached_run(self):
        import world_lab_run as Run
        with patch.object(Feed, "read", wraps=Feed.read) as reader, patch.object(Run,"native_png",wraps=Run.native_png) as decode:
            self.feed.publish(self.study,now=self.now)
            self.body.update(capturedAtUnixMs=self.now, worldHours=4.6)
            Feed.atomic(self.native.parent/"participant-state.json",self.body)
            self.feed.publish(self.study,now=self.now)
        self.assertEqual(decode.call_count,1)
        self.assertEqual(sum(Path(c.args[0])==self.run/"run.json" for c in reader.call_args_list),1)
        self.assertEqual((self.feed.destination/self.frame["image"]["file"]).read_bytes(),self.image)

    def test_changed_receipts_retain_owner_and_schema_refusals(self):
        self.feed.run_receipt()
        accepted = self.feed.receipt_version
        for field,value in (("sessionId",str(uuid.uuid4())),("pid",23456),("schema","foreign"),
                            ("participantInput",False),("status","invented"),("launchNumber",2),
                            ("observerDirectory","attempts/0002"),("host","observer")):
            with self.subTest(field=field):
                Feed.atomic(self.run/"run.json",dict(self.receipt,**{field:value}))
                with self.assertRaises(ValueError): self.feed.run_receipt()
                self.assertEqual(self.feed.receipt_version,accepted)
        Feed.atomic(self.run/"run.json",self.receipt)
        self.assertEqual(self.feed.run_receipt()["sessionId"],self.receipt["sessionId"])

    def test_valid_terminal_and_saved_identity_are_rechecked(self):
        self.feed.publish(self.study,now=self.now)
        Feed.atomic(self.run/"run.json",dict(self.receipt,status="completed",save=self.body["save"]))
        self.assertEqual(self.feed.run_receipt()["status"],"completed")
        Feed.atomic(self.run/"run.json",dict(self.receipt,status="completed",save="foreign-save"))
        with self.assertRaisesRegex(ValueError,"save changed"): self.feed.run_receipt()

    def test_duplicate_json_remains_refused_after_cached_read(self):
        self.feed.run_receipt()
        raw = Feed.encoded(self.receipt).decode().rstrip()
        (self.run/"run.json").write_text(raw[:-1]+',"pid":12345}',encoding="utf-8")
        with self.assertRaisesRegex(ValueError,"duplicate"): self.feed.run_receipt()

    def race(self, foreign=False, forever=False):
        original = Feed.read
        count = 0
        def replaced(path,*args,**kwargs):
            nonlocal count
            result = original(path,*args,**kwargs)
            if Path(path)==self.run/"run.json":
                count += 1
                if count==1 or forever:
                    replacement = dict(self.receipt,status="completed",sample=count)
                    if foreign: replacement["sessionId"]=str(uuid.uuid4())
                    Feed.atomic(path,replacement)
            return result
        with patch.object(Feed,"read",side_effect=replaced):
            if foreign:
                with self.assertRaisesRegex(ValueError,"session changed"): self.feed.run_receipt()
            elif forever:
                with self.assertRaises(PermissionError): self.feed.run_receipt()
            else: self.assertEqual(self.feed.run_receipt()["status"],"completed")
        return count

    def test_atomic_read_turnover_retries_stable_current_source(self):
        self.assertEqual(self.race(),2)

    def test_atomic_read_turnover_refuses_foreign_successor(self):
        self.assertEqual(self.race(foreign=True),2)
        self.assertIsNone(self.feed.receipt_version)

    def test_continuous_turnover_is_bounded_and_never_cached(self):
        self.assertEqual(self.race(forever=True),Feed.MAX_RUN_READ_ATTEMPTS)
        self.assertIsNone(self.feed.receipt_version)

    def test_atomic_replacement_with_equal_size_and_mtime_rechecks_owner(self):
        self.feed.run_receipt()
        before=(self.run/"run.json").stat()
        candidate=self.run/"replacement.json"
        candidate.write_bytes((self.run/"run.json").read_bytes().replace(b'"pid":12345',b'"pid":54321'))
        self.assertEqual(candidate.stat().st_size,before.st_size)
        os.utime(candidate,ns=(before.st_atime_ns,before.st_mtime_ns))
        os.replace(candidate,self.run/"run.json")
        with self.assertRaisesRegex(ValueError,"PID changed"): self.feed.run_receipt()

    def test_oversized_changed_receipt_does_not_acquire_cache(self):
        self.feed.run_receipt()
        accepted=self.feed.receipt_version
        with (self.run/"run.json").open("wb") as out: out.truncate(Feed.MAX_RUN_JSON+1)
        with self.assertRaisesRegex(ValueError,"unsafe"): self.feed.run_receipt()
        self.assertEqual(self.feed.receipt_version,accepted)

    def test_idle_supervisor_preserves_input_command_and_terminal_cadence(self):
        import world_lab_video_archive as Archive
        import world_lab_participant_lease as Lease
        out=self.root/"source-event-session"
        events=[]; stopped=False
        current=self
        class Owner:
            returncode=0; pid=88; count=0
            def poll(owner):
                nonlocal stopped
                owner.count+=1
                if stopped:
                    Feed.atomic(out/"participant-run/run.json",dict(current.receipt,status="completed"))
                    return 0
                if owner.count==3:
                    changed=dict(current.body,capturedAtUnixMs=current.now,worldHours=4.6)
                    Feed.atomic(out/"participant-run/attempts/0001/participant-state.json",changed)
                if owner.count==5:
                    Feed.atomic(out/"feeds/0001/commands/0000000000000001.json",{
                        "schema":"mousecat.native-view-command/1","sessionId":current.receipt["sessionId"],
                        "sequence":1,"action":"checkpoint"})
                return None
            def wait(owner,timeout): return 0
        class Broker:
            def __init__(broker,run): pass
            def poll(broker): events.append("input")
            def release(broker,reason): events.append(reason)
            def close(broker): events.append("broker-close")
        class Retention:
            def close(archive):
                events.append("archive-close")
                protocol_recording(out/"feeds/0001",Feed.read(out/"study-session.json")[1]["id"],current.receipt["sessionId"])
        def prepared(path,owner):
            current.write_sources(path.parent)
            return current.receipt
        def stop(run,reason):
            nonlocal stopped
            events.append(reason); stopped=True
        actual_publish=Feed.ParticipantFeed.publish
        def publish(publisher,study,*args,**kwargs):
            events.append("publish-"+study["status"])
            return actual_publish(publisher,study,*args,**kwargs)
        args=SimpleNamespace(participant_input=True,window="visible",auto_continue=False,
            package=self.root/"package",out=out,game=self.root/"game",jdk=self.root/"jdk",
            watcher=self.root/"unused-watcher",registry=self.root/"registry.json",duration=30,
            label="Source-event protocol",view_id="source-event-control",project_ref="sao",
            video_encoder=self.root/"non-executable-protocol-encoder")
        ticks=iter(i*.002 for i in range(100))
        with patch.object(Pipeline.subprocess,"Popen",return_value=Owner()), \
             patch.object(Session,"participant_command",return_value=["protocol-only"]), \
             patch.object(Session,"wait_for_run",side_effect=prepared), \
             patch.object(Session,"open_mousecat",return_value=None), \
             patch.object(Feed,"load_video_module",return_value=(None,{"fixture":"protocol-only"})), \
             patch.object(Archive,"start",return_value=Retention()), \
             patch.object(Lease,"ParticipantLeaseBroker",Broker), \
             patch.object(Pipeline,"request_stop",side_effect=stop), \
             patch.object(Feed.ParticipantFeed,"publish",publish), \
             patch.object(Pipeline.time,"monotonic",side_effect=lambda:next(ticks)), \
             patch.object(Pipeline.time,"sleep") as waited:
            self.assertEqual(Pipeline.supervise(args),0)
        self.assertEqual(events.count("input"),5)
        self.assertEqual(events.count("publish-running"),3)
        self.assertEqual(events.count("publish-closed"),1)
        self.assertIn("operator-checkpoint",events)
        self.assertIn("archive-close",events)
        self.assertEqual(events[-1],"broker-close")
        self.assertEqual(waited.call_count,5)
        for call in waited.call_args_list: self.assertAlmostEqual(call.args[0],.008)


if __name__=="__main__": unittest.main()
