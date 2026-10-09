"""Source-qualified speech boundary checks. All bodies, inputs and pixels are synthetic.

Runs actual Python validators/queue, actual installed Kahlua Lua module and actual
Java eligibility/epoch/parser methods. Does not launch a game, drive a desktop,
change a save/mod/service, run an encoder or claim native/runner/voice acceptance.
Only the explicitly supplied evidence directory receives generated fixtures.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import unittest
from unittest.mock import patch

import world_lab_native_communication as Comm
import world_lab_participant_feed as Feed
import world_lab_session as Session

ROOT = Path(__file__).resolve().parents[1]
GAME = Path("C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid")
JDK = Path("C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin")
EVIDENCE = None
SESSION = "69f9025d-1204-4120-930d-700000000001"
NOW = 1791357000000
RECEIPT = dict(sessionId=SESSION, pid=27003, launchNumber=1)
CASE_COUNTER = 0


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def person(hearing="available", events=None):
    return dict(id="person-buddy", label="Synthetic nearby person",
        summary="Explicitly synthetic physical speech sample.",
        sections=[dict(id="native-communication", label="Speech", source="Synthetic source control",
            perspective="Physical observation", status=hearing, message="Synthetic hearing predicate",
            rows=[dict(label="Execution owner", value="SAO.Controller")])], events=events or [])


def body(**updates):
    value = dict(schema="sao-native-participant/1", sessionId=SESSION, pid=27003, attempt=1,
        save="synthetic-save", saveMode="Sandbox", playerIndex=0, playerSqlId=23,
        capturedAtUnixMs=NOW-100, worldHours=10., ready=True, alive=True, displayFocused=True,
        body=dict(label="Synthetic selected player", x=10., y=20., z=0.))
    value.update(updates)
    return value


def state(**updates):
    value = dict(schema=Comm.STATE_SCHEMA, sessionId=SESSION, pid=27003, attempt=1,
        save="synthetic-save", saveMode="Sandbox", playerIndex=0, playerSqlId=23,
        capturedAtUnixMs=NOW-50, worldHours=10., bindingEpoch=1, gameThreadDurationNs=90,
        status="available", nearby=dict(people=[person()], omittedPeople=0, omittedEvents=0),
        lastCommandSequence=0)
    value.update(updates)
    return value


def command(sequence=1, **updates):
    value = dict(schema="mousecat.native-view-command/1", sessionId=SESSION, sequence=sequence,
        action="speak", personId="person-buddy", text="wait here", inputMode="typed", bindingEpoch=1)
    value.update(updates)
    return value


def event(sequence=1, **updates):
    value = dict(id=f"utterance-{sequence}", capturedAtUnixMs=NOW-60, worldHours=10.,
        source="Explicitly synthetic source event", stage="utterance-heard-uninterpreted",
        summary="wait here", actorId="synthetic-player", recipientId="person-buddy",
        correlationId="native-speech-1")
    value.update(updates)
    return value


class SpeechBoundaryTests(unittest.TestCase):
    def setUp(self):
        global CASE_COUNTER
        CASE_COUNTER += 1
        self.root = EVIDENCE / ("python-" + str(CASE_COUNTER).zfill(3) + "-" + self._testMethodName)
        self.attempt, self.destination = self.root / "attempt", self.root / "view"
        self.retained = self.root / "retained"
        for path in (self.attempt/"interaction/commands", self.destination/"commands", self.retained):
            path.mkdir(parents=True)
        self.bridge = Comm.NativeCommunication(self.attempt, self.destination, RECEIPT, self.retained)

    def sample_file(self, value):
        Session.atomic(self.attempt/"interaction/state.json", value)

    def queue(self, value=None):
        value = value or command()
        Session.atomic(self.destination/"commands"/f"{value['sequence']:016d}.json", value)

    def wire(self, sequence=1):
        return json.loads((self.attempt/"interaction/commands"/f"{sequence:016d}.json").read_bytes())

    def assert_refusal(self, command_value=None, body_value=None, state_value=None):
        self.sample_file(state_value or state())
        self.queue(command_value)
        self.bridge.process(body_value or body(), NOW)
        self.assertEqual(self.wire()["schema"], "sao.native-interaction-rejection/1")

    def test_original_epoch_identity_and_expiry_forwarded(self):
        self.sample_file(state()); self.queue()
        self.bridge.process(body(), NOW)
        wire = self.wire()
        self.assertEqual(wire["schema"], Comm.WIRE_SCHEMA)
        for key in ("sessionId", "pid", "attempt", "save", "saveMode", "playerIndex", "playerSqlId"):
            self.assertEqual(wire[key], body()[key])
        self.assertEqual(wire["bindingEpoch"], command()["bindingEpoch"])
        self.assertEqual(wire["issuedAtUnixMs"], NOW)
        self.assertEqual(wire["expiresAtUnixMs"], NOW+5000)

    def test_foreign_command_binding_and_fields_refused(self):
        changes = [
            dict(sessionId="69f9025d-1204-4120-930d-700000000002"),
            dict(action="focus"), dict(sequence=True), dict(inputMode="generated"),
            dict(personId="unknown-person"), dict(privateBelief="must not enter native wire")]
        for change in changes:
            with self.subTest(change=change):
                self.setUp()
                # File identity remains sequence 1 even for malformed sequence controls.
                Session.atomic(self.destination/"commands/0000000000000001.json", command(**change))
                self.sample_file(state()); self.bridge.process(body(), NOW)
                self.assertEqual(self.wire()["schema"], "sao.native-interaction-rejection/1")

    def test_foreign_or_unbound_selected_body_refused(self):
        for change in (dict(save="another-save"), dict(saveMode="Survivor"), dict(playerSqlId=24),
                       dict(pid=27004), dict(attempt=2), dict(ready=False), dict(alive=False)):
            with self.subTest(change=change):
                self.setUp(); self.assert_refusal(body_value=body(**change))

    def test_queued_request_cannot_rebind_after_body_switch(self):
        self.sample_file(state()); self.bridge.sample(NOW); self.queue()
        # The request was made while body/epoch 1 was exposed. Epoch 2 contains
        # the same recipient ID: only immutable issuance identity can prevent rebinding.
        self.sample_file(state(bindingEpoch=2, save="second-save", playerSqlId=24,
            capturedAtUnixMs=NOW-25))
        self.bridge.process(body(save="second-save", playerSqlId=24, capturedAtUnixMs=NOW-30), NOW)
        self.assertEqual(self.wire()["schema"], "sao.native-interaction-rejection/1",
            "queued speech was rebound to the newly selected character")

    def test_foreign_or_missing_command_epoch_refused(self):
        for epoch in (0, 2, True, 1.0, "1", None):
            with self.subTest(epoch=epoch):
                self.setUp(); self.assert_refusal(command_value=command(bindingEpoch=epoch))
        self.setUp(); value=command(); del value["bindingEpoch"]
        self.assert_refusal(command_value=value)

    def test_malformed_unicode_controls_and_utf16_bounds_refused(self):
        for text in ("\ud800", "\udc00", "hello\x00", "hello\x7f", "a\nb", "   ", "\U0001f31f"*193):
            with self.subTest(text=repr(text)):
                self.setUp()
                # Escaped Unicode permits deliberate invalid UTF-16 to reach the actual reader.
                (self.destination/"commands/0000000000000001.json").write_text(
                    json.dumps(command(text=text), ensure_ascii=True), encoding="utf-8")
                self.sample_file(state()); self.bridge.process(body(), NOW)
                self.assertEqual(self.wire()["schema"], "sao.native-interaction-rejection/1")

    def test_valid_unicode_preserved_without_generated_voice(self):
        self.sample_file(state()); self.queue(command(text="Hello \U0001f31f", inputMode="dictated"))
        self.bridge.process(body(), NOW)
        self.assertEqual(self.wire()["text"], "Hello \U0001f31f")
        self.assertEqual(self.wire()["inputMode"], "dictated")

    def test_lost_hearing_and_removed_person_refused(self):
        for people in ([person("unavailable")], []):
            with self.subTest(people=people):
                self.setUp(); self.assert_refusal(state_value=state(
                    nearby=dict(people=people, omittedPeople=0, omittedEvents=0)))

    def test_stale_and_future_sample_refused(self):
        for captured in (NOW-3001, NOW+1):
            with self.subTest(captured=captured):
                self.setUp(); self.sample_file(state(capturedAtUnixMs=captured))
                with self.assertRaises(ValueError): self.bridge.sample(NOW)

    def test_cache_revalidates_age_without_reopening_payload(self):
        self.sample_file(state()); self.bridge.sample(NOW)
        with patch.object(Feed, "read", side_effect=AssertionError("unchanged state reopened")):
            self.assertEqual(self.bridge.sample(NOW)["bindingEpoch"], 1)
            with self.assertRaises(ValueError): self.bridge.sample(NOW+3001)

    def test_source_process_identity_requires_integer_not_numeric_alias(self):
        for changes in (dict(pid=27003.0), dict(attempt=True), dict(attempt=1.0)):
            with self.subTest(changes=changes):
                with self.assertRaises(ValueError): Comm.validate_state(state(**changes), RECEIPT, NOW)

    def test_future_participant_clock_cannot_issue_speech(self):
        self.assert_refusal(body_value=body(capturedAtUnixMs=NOW+100, worldHours=10.))

    def test_body_and_speech_world_clock_order_must_agree(self):
        self.assertFalse(Comm.same_body(state(worldHours=2., bindingEpoch=2),
            body(capturedAtUnixMs=NOW-100, worldHours=10.)))
        self.assertFalse(Comm.same_body(state(capturedAtUnixMs=NOW-150, worldHours=10.),
            body(worldHours=2.)))
        self.assertTrue(Comm.same_body(state(), body()))

    def test_epoch_regression_or_reuse_for_new_namespace_refused(self):
        for change in (dict(bindingEpoch=0), dict(save="new-save"), dict(saveMode="Survivor"),
                       dict(playerSqlId=24), dict(worldHours=9.9)):
            with self.subTest(change=change):
                self.setUp(); self.sample_file(state()); self.bridge.sample(NOW)
                self.sample_file(state(capturedAtUnixMs=NOW-25, **change))
                with self.assertRaises(ValueError): self.bridge.sample(NOW)

    def test_larger_epoch_admits_world_restart_without_old_history(self):
        self.sample_file(state()); self.bridge.sample(NOW)
        self.sample_file(state(bindingEpoch=2, capturedAtUnixMs=NOW-25, worldHours=2.,
            nearby=dict(people=[person()], omittedPeople=0, omittedEvents=0)))
        self.assertEqual(self.bridge.sample(NOW)["worldHours"], 2.)

    def test_event_capture_and_world_clock_bound_enclosing_sample(self):
        for changes in (dict(capturedAtUnixMs=NOW), dict(worldHours=11.),
                        dict(recipientId="another-person"), dict(stage="fabricated-completion")):
            with self.subTest(changes=changes):
                with self.assertRaises(ValueError):
                    Comm.validate_state(state(nearby=dict(people=[person(events=[event(**changes)])],
                        omittedPeople=0, omittedEvents=0)), RECEIPT, NOW)

    def test_old_event_after_world_restart_refused(self):
        with self.assertRaises(ValueError):
            Comm.validate_state(state(bindingEpoch=2, worldHours=2., nearby=dict(
                people=[person(events=[event(worldHours=10.)])], omittedPeople=0, omittedEvents=0)), RECEIPT, NOW)

    def test_cursor_jump_without_forwarded_source_cannot_claim_outcome(self):
        self.sample_file(state(lastCommandSequence=1,
            commandResult=dict(sequence=1, status="applied", message="Synthetic native acknowledgment")))
        with self.assertRaises(ValueError): self.bridge.sample(NOW)

    def test_acknowledgment_and_unchanged_repeat_are_idempotent(self):
        self.sample_file(state()); self.queue(); self.bridge.process(body(), NOW)
        result=dict(sequence=1, status="applied", message="Received; action remains unobserved.")
        self.sample_file(state(capturedAtUnixMs=NOW-25, lastCommandSequence=1, commandResult=result))
        self.bridge.sample(NOW); self.bridge.sample(NOW)
        self.assertEqual(self.bridge.cursor, 1); self.assertIsNone(self.bridge.forwarded)
        self.assertEqual(self.bridge.result, result)
        self.assertEqual(len(list((self.attempt/"interaction/commands").glob("*.json"))), 1)

    def test_reused_sequence_cannot_replace_recorded_outcome(self):
        self.test_acknowledgment_and_unchanged_repeat_are_idempotent()
        self.sample_file(state(capturedAtUnixMs=NOW-10, lastCommandSequence=1,
            commandResult=dict(sequence=1, status="rejected", message="Changed receipt")))
        with self.assertRaises(ValueError): self.bridge.sample(NOW)

    def test_unknown_effect_acknowledgment_is_retained_without_resend(self):
        self.sample_file(state()); self.queue(); self.bridge.process(body(), NOW)
        result=dict(sequence=1, status="unknown", message="May have emitted; effect not established.")
        self.sample_file(state(capturedAtUnixMs=NOW-25, lastCommandSequence=1, commandResult=result))
        self.bridge.sample(NOW)
        self.assertEqual(self.bridge.result, result); self.assertEqual(self.bridge.cursor, 1)
        self.bridge.process(body(), NOW)
        self.assertEqual(len(list((self.attempt/"interaction/commands").glob("*.json"))), 1)

    def test_pending_unknown_does_not_retry_or_consume_next_request(self):
        self.sample_file(state()); self.queue(); self.queue(command(sequence=2))
        self.bridge.process(body(), NOW)
        original=(self.attempt/"interaction/commands/0000000000000001.json").read_bytes()
        for _ in range(3): self.bridge.process(body(), NOW)
        self.assertEqual(self.bridge.forwarded, 1); self.assertEqual(self.bridge.cursor, 0)
        self.assertEqual((self.attempt/"interaction/commands/0000000000000001.json").read_bytes(), original)
        self.assertFalse((self.attempt/"interaction/commands/0000000000000002.json").exists())

    def test_cursor_regression_refused_after_ack(self):
        self.test_acknowledgment_and_unchanged_repeat_are_idempotent()
        self.sample_file(state(capturedAtUnixMs=NOW-10))
        with self.assertRaises(ValueError): self.bridge.sample(NOW)

    def test_state_stat_read_stat_race_refused(self):
        self.sample_file(state())
        original=Feed.read
        def race(path, maximum=Feed.MAX_JSON):
            raw, value=original(path, maximum)
            self.sample_file(state(capturedAtUnixMs=NOW-25, bindingEpoch=2))
            return raw, value
        with patch.object(Feed, "read", side_effect=race):
            with self.assertRaises(ValueError): self.bridge.sample(NOW)
        self.assertIsNone(self.bridge.state)

    def test_command_stat_read_stat_race_never_forwards_original_text(self):
        self.sample_file(state()); self.bridge.sample(NOW); self.queue()
        original=Feed.read
        def race(path, maximum=Feed.MAX_JSON):
            raw, value=original(path, maximum)
            if Path(path).name == "0000000000000001.json": self.queue(command(text="follow me"))
            return raw, value
        with patch.object(Feed, "read", side_effect=race): self.bridge.process(body(), NOW)
        self.assertEqual(self.wire()["schema"], "sao.native-interaction-rejection/1")

    def test_clock_reuse_with_different_payload_refused(self):
        self.sample_file(state()); self.bridge.sample(NOW)
        self.sample_file(state(gameThreadDurationNs=100))
        with self.assertRaises(ValueError): self.bridge.sample(NOW)

    def test_clock_only_samples_do_not_grow_archive_but_events_are_retained(self):
        self.sample_file(state()); self.bridge.sample(NOW)
        self.sample_file(state(capturedAtUnixMs=NOW-25, gameThreadDurationNs=120))
        self.bridge.sample(NOW)
        self.assertEqual(len(list((self.retained/"interaction-samples").glob("*.json"))), 1)
        value=state(capturedAtUnixMs=NOW-10, nearby=dict(
            people=[person(events=[event()])], omittedPeople=0, omittedEvents=0))
        self.sample_file(value); self.bridge.sample(NOW)
        samples=list((self.retained/"interaction-samples").glob("*.json"))
        self.assertEqual(len(samples), 2)
        for sample in samples: self.assertEqual(sample.stem, digest(sample))
        self.assertTrue(any(json.loads(p.read_bytes())["nearby"]["people"][0]["events"] for p in samples))

    def test_schema_private_extra_fields_and_oversize_refused(self):
        with self.assertRaises(ValueError): Comm.validate_state(state(privateBelief="secret"), RECEIPT, NOW)
        value=state(); value["nearby"]["people"][0]["sections"][0]["rows"][0]["private"]="secret"
        with self.assertRaises(ValueError): Comm.validate_state(value, RECEIPT, NOW)
        (self.attempt/"interaction/state.json").write_bytes(b" "* (Comm.MAX_STATE+1))
        with self.assertRaises(ValueError): self.bridge.sample(NOW)

    def test_duplicate_json_and_nonfinite_clock_refused(self):
        for raw in (b'{"schema":"a","schema":"b"}', b'{"worldHours":NaN}'):
            with self.subTest(raw=raw):
                self.setUp(); (self.attempt/"interaction/state.json").write_bytes(raw)
                with self.assertRaises(ValueError): self.bridge.sample(NOW)


JAVA_PROBE = r'''
import java.nio.file.*;
import java.util.*;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.vm.*;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import zombie.core.Core;
public class NativeCommunication12Probe {
 static int checks;
 static void check(boolean value,String message) { checks++; if(!value) throw new AssertionError(message); }
 static Object get(String name)throws Exception {var f=StudyNativeInteraction.class.getDeclaredField(name);f.setAccessible(true);return f.get(null);}
 static void set(String name,Object value)throws Exception {var f=StudyNativeInteraction.class.getDeclaredField(name);f.setAccessible(true);f.set(null,value);}
 static StudyParticipant.Binding body(Object owner,String save,int sql,double hours,boolean alive,boolean ready) {
  return new StudyParticipant.Binding(owner,0,sql,save,1,hours,alive,1,2,0,"synthetic",ready);
 }
 static void eligibility(Path input)throws Exception {
  var fields=StudyNativeInteraction.parseFlat(Files.readString(input),StudyNativeInteraction.FIELDS);
  Object owner=new Object(); var body=body(owner,"synthetic-save",23,10,true,true);
  long now=(Long)fields.get("issuedAtUnixMs");
  check(StudyNativeInteraction.eligibility(fields,body,"Sandbox",now,"69f9025d-1204-4120-930d-700000000001",1,27003,1)==null,"valid source-bound request refused");
  for(String key:List.of("pid","attempt","bindingEpoch","playerIndex","playerSqlId","sessionId","save","saveMode")) {
   var altered=new LinkedHashMap<String,Object>(fields); Object prior=fields.get(key);
   altered.put(key,prior instanceof Long?(Long)prior+1:prior+"-foreign");
   check(StudyNativeInteraction.eligibility(altered,body,"Sandbox",now,"69f9025d-1204-4120-930d-700000000001",1,27003,1)!=null,"foreign "+key+" admitted");
  }
  check(StudyNativeInteraction.eligibility(fields,null,"Sandbox",now,"69f9025d-1204-4120-930d-700000000001",1,27003,1)!=null,"unbound player admitted");
  check(StudyNativeInteraction.eligibility(fields,body(owner,"synthetic-save",23,10,false,true),"Sandbox",now,"69f9025d-1204-4120-930d-700000000001",1,27003,1)!=null,"dead player admitted");
  check(StudyNativeInteraction.eligibility(fields,body,"Sandbox",now+5000,"69f9025d-1204-4120-930d-700000000001",1,27003,1)!=null,"expiry equality admitted");
  check(StudyNativeInteraction.eligibility(fields,body,"Sandbox",now-1,"69f9025d-1204-4120-930d-700000000001",1,27003,1)!=null,"future request admitted");
  for(String text:List.of("\uD800","\uDC00","a\nb","a\u007f"," ","\uD83C\uDF1F".repeat(193))) {
   var altered=new LinkedHashMap<String,Object>(fields);altered.put("text",text);
   check(StudyNativeInteraction.eligibility(altered,body,"Sandbox",now,"69f9025d-1204-4120-930d-700000000001",1,27003,1)!=null,"invalid Unicode boundary admitted");
  }
  var unicode=new LinkedHashMap<String,Object>(fields);unicode.put("text","Hello \uD83C\uDF1F");
  check(StudyNativeInteraction.eligibility(unicode,body,"Sandbox",now,"69f9025d-1204-4120-930d-700000000001",1,27003,1)==null,"valid Unicode refused");
  String raw=Files.readString(input);
  for(String invalid:List.of(raw+"[]",raw.replace("\"schema\":","\"schema\":\"duplicate\",\"schema\":"),
     raw.replace("\"bindingEpoch\":1","\"bindingEpoch\":{}"),raw.replace("\"bindingEpoch\":1","\"bindingEpoch\":1.0"))) {
   boolean refused=false;try{StudyNativeInteraction.parseFlat(invalid,StudyNativeInteraction.FIELDS);}catch(RuntimeException expected){refused=true;}
   check(refused,"ambiguous/nested/noninteger JSON admitted");
  }
 }
 static void epoch()throws Exception {
  Object one=new Object(),two=new Object();
  set("bindingEpoch",0L);set("epochBody",null);set("epochMode",null);
  StudyNativeInteraction.observeEpoch(null,"");check((long)get("bindingEpoch")==0,"menu invented a bound epoch");
  StudyNativeInteraction.observeEpoch(body(one,"synthetic-save",23,10,true,true),"Sandbox");long first=(long)get("bindingEpoch");
  check(first>0,"first body has no lifetime");
  StudyNativeInteraction.observeEpoch(body(one,"synthetic-save",23,10.1,true,true),"Sandbox");check((long)get("bindingEpoch")==first,"same body created a new lifetime");
  StudyNativeInteraction.observeEpoch(body(one,"synthetic-save",23,2,true,true),"Sandbox");check((long)get("bindingEpoch")==first+1,"world rollback retained speech lifetime");
  StudyNativeInteraction.observeEpoch(body(two,"synthetic-save",23,2,true,true),"Sandbox");check((long)get("bindingEpoch")==first+2,"replacement body retained speech lifetime");
  StudyNativeInteraction.observeEpoch(body(two,"synthetic-save",24,2,true,true),"Sandbox");check((long)get("bindingEpoch")==first+3,"SQL switch retained speech lifetime");
  StudyNativeInteraction.observeEpoch(body(two,"synthetic-save",24,2,true,true),"Survivor");check((long)get("bindingEpoch")==first+4,"save-mode switch retained speech lifetime");
  StudyNativeInteraction.observeEpoch(null,"");check((long)get("bindingEpoch")==first+5,"unbinding retained speech lifetime");
 }
 static void runLua(Path module,Path controls)throws Exception {
  Core.debug=false; var platform=new J2SEPlatform(); var env=platform.newEnvironment();
  var thread=new KahluaThread(platform,env);thread.debugOwnerThread=Thread.currentThread();
  check(env.rawget("next")==null,"installed standard library control changed; inspect primary");
  Object[] init=thread.pcall(LuaCompiler.loadstring(Files.readString(controls),"explicitly-synthetic-controls",env),new Object[0]);
  check(Boolean.TRUE.equals(init[0]),"synthetic Lua setup failed: "+Arrays.toString(init));
  Object[] loaded=thread.pcall(LuaCompiler.loadstring(Files.readString(module),module.toString(),env),new Object[0]);
  check(Boolean.TRUE.equals(loaded[0]),"actual Lua module refused: "+Arrays.toString(loaded));
  Object[] result=thread.pcall(env.rawget("runCommunicationChecks"),new Object[0]);
  check(Boolean.TRUE.equals(result[0]),"actual Lua behavioral boundary failed: "+Arrays.toString(result));
  System.out.println("LUA_RESULT="+result[1]);
 }
 public static void main(String[] args)throws Exception {
  switch(args[0]) {case "eligibility":eligibility(Path.of(args[1]));break;case "epoch":epoch();break;case "lua":runLua(Path.of(args[1]),Path.of(args[2]));break;default:throw new AssertionError("unknown mode");}
  System.out.println("PASS "+args[0]+" checks="+checks);
 }
}
'''

LUA_CONTROLS = r'''
-- This fixture supplies synthetic native objects/predicates only. The production
-- speech module and installed Kahlua stdlib execute unchanged.
local stamp, hours, emitted, judged, responseCount = 1791357000000, 10, 0, 0, 0
local hearing, verdict, external, failTimestamp = true, "complies", false, false
local player = {dead=false}
function player:isDead() return self.dead end
function player:getCurrentSquare() return {} end
function player:getX() return 0 end
function player:getY() return 0 end
function player:getZ() return 0 end
function player:Say(text) emitted=emitted+1 end
local buddy = {dead=false}
function buddy:isDead() return self.dead end
function buddy:getCurrentSquare() return {} end
function buddy:getX() return 1 end
function buddy:getY() return 1 end
function buddy:getZ() return 0 end
local record = {id="person-buddy",privateOwnMemory="not projected"}
local agent = {companioning=true}
SAO = {Participants={player=function(n) return player end}, Standing={playerKey=function(p) return "synthetic-player" end},
 Body={active={["person-buddy"]=true},foreign={}}, Perception={EARSHOT=10},
 Identity={get=function(id) if id=="person-buddy" then return record end end,displayName=function(r) return "Synthetic buddy" end},
 Controller={agents={["person-buddy"]=agent}},
 Communication={executionOwners={},bodyFor=function(id) if id=="person-buddy" then return buddy end end,
 canConverse=function(fromId,toId) return hearing end},
 Command={order=function(fromId,toId,kind,arg) judged=judged+1; return verdict,"synthetic source judgment" end},
 Voice={answer=function(id,kind) responseCount=responseCount+1 end}}
function getSpecificPlayer(n) return player end
function getTimestampMs() if failTimestamp then error("Synthetic failure after physical emission") end stamp=stamp+1;return stamp end
function getGameTime() return {getWorldAgeHours=function() return hours end} end
local function contains(value,needle) return string.find(value,needle,1,true) ~= nil end
function runCommunicationChecks()
 local M=SAO.MousecatInteraction
 local empty=M.nearby(nil,"1");assert(contains(empty,'"people":[]'),"unbound nearby did not return empty envelope")
 local near=M.nearby(player,"1")
 assert(contains(near,'"native-communication"'),"represented physical person missing")
 assert(not contains(near,"privateOwnMemory") and not contains(near,"not projected"),"own private record leaked to projection")
 hearing=false
 local refused=M.speak(player,"person-buddy","wait here","typed","1","1")
 assert(contains(refused,'"status":"rejected"') and emitted==0 and judged==0,"lost hearing still emitted or ordered")
 hearing=true;agent.companioning=false
 local noCompanion=M.speak(player,"person-buddy","follow me","typed","2","1")
 assert(contains(noCompanion,'"status":"applied"') and emitted==1 and judged==0 and agent.followTight==nil,"noncompanion was assigned follow state")
 agent.companioning=true;verdict="refuses"
 local no=M.speak(player,"person-buddy","wait here","typed","3","1")
 assert(contains(no,"refused") and judged==1 and agent.holdPosition==nil,"source refusal forced hold")
 verdict="complies"
 local yes=M.speak(player,"person-buddy","wait here","typed","4","1")
 assert(agent.holdPosition==true and contains(yes,"Action completion has not been inferred"),"accepted hold claim or state differs")
 M.speak(player,"person-buddy","follow me","typed","5","1")
 assert(agent.holdPosition==nil and agent.followTight==true,"accepted close differs from companion menu")
 M.speak(player,"person-buddy","walk with me","typed","6","1")
 assert(agent.holdPosition==nil and agent.followTight==nil,"accepted walk differs from companion menu")
 local before=judged
 local uninterpreted=M.speak(player,"person-buddy","Tell me about the sky","dictated","7","1")
 assert(judged==before and contains(uninterpreted,"No supported instruction"),"freeform utterance fabricated an instruction")
 local seen
 record.bodyOwner="real-synthetic-runner"
 SAO.Communication.executionOwners[record.bodyOwner]={receiveUtterance=function(id,own,observation)
  seen=observation;assert(id=="person-buddy" and own==record,"owner received foreign identity");return {received=true}
 end}
 local received=M.speak(player,"person-buddy","An explicit objective","typed","8","1")
 assert(contains(received,"registered controller received") and seen.text=="An explicit objective" and seen.inputMode=="typed","registered owner did not receive actual utterance")
 local fields=0;for key in pairs(seen) do fields=fields+1;assert(key~="privateOwnMemory" and key~="privateBelief","private state added to observed utterance") end
 assert(fields==8,"external observed utterance envelope expanded")
 local history=M.nearby(player,"1")
 assert(contains(history,"utterance-heard-uninterpreted") and contains(history,"native-speech-8"),"actual reception history lost")
 local changed=M.nearby(player,"2")
 assert(contains(changed,'"events":[]') and not contains(changed,"native-speech-8"),"history crossed body epoch")
 record.bodyOwner=nil
 M.speak(player,"person-buddy","hello","typed","9","2")
 hours=2
 local reset=M.nearby(player,"2")
 assert(contains(reset,'"events":[]'),"history crossed world rollback")
 player.dead=true
 local old=emitted;M.speak(player,"person-buddy","hello","typed","10","3")
 assert(emitted==old,"dead speaker emitted")
 player.dead=false
 -- Unknown-effect control proves that errors after native Say do not establish
 -- nonexecution. Java adapter must report unknown, not a false rejection.
 failTimestamp=true
 local okay=pcall(M.speak,player,"person-buddy","hello","typed","11","3")
 assert(okay==false and emitted==old+1,"post-emission failure control did not reach actual effect boundary")
 return "PASS synthetic hearing/companion/owner/private/epoch/history/unknown-effect boundaries"
end
'''

NODE_PROBE = r'''
import assert from "node:assert/strict";
import {createHash,randomUUID} from "node:crypto";
import {mkdir,readFile,readdir,writeFile} from "node:fs/promises";
import {join} from "node:path";
import {pathToFileURL} from "node:url";
const [module,root]=process.argv.slice(2);
const {createNativeViews}=await import(pathToFileURL(module));
await mkdir(join(root,"producer","commands"),{recursive:true});
const directory=join(root,"producer"),registryPath=join(root,"registry.json"),sessionId="69f9025d-1204-4120-930d-700000000001";
const png=Buffer.from("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/a9sAAAAASUVORK5CYII=","base64");
await writeFile(join(directory,"synthetic.png"),png);
const section={id:"native-communication",label:"Speech",source:"Explicitly synthetic control",perspective:"Physical sample",status:"available",message:"Synthetic",rows:[]};
let view={schema:"mousecat.native-view/1",sessionId,sequence:1,capturedAtUnixMs:Date.now(),image:{file:"synthetic.png",sha256:createHash("sha256").update(png).digest("hex"),width:1,height:1},
 state:"running",title:"Synthetic source control",summary:"No actual game frame.",people:[{id:"person-buddy",label:"Synthetic buddy",summary:"Fixture only",sections:[section],events:[]}],
 lastCommandSequence:0,commandActions:["speak"],communicationBindingEpoch:1,inspection:{sequence:1,capturedAtUnixMs:Date.now(),worldHours:10,status:"available",message:"Synthetic",omittedPeople:0,omittedEvents:0}};
await writeFile(registryPath,JSON.stringify([{id:"synthetic",label:"Synthetic control",projectRef:"synthetic",directory,sessionId}]));
const save=()=>writeFile(join(directory,"latest.json"),JSON.stringify(view));
await save();
const adapter=createNativeViews({registryPath}),snapshot=await adapter.snapshot("synthetic");
const payload=(changes={})=>({bindingId:snapshot.binding.bindingId,sessionId,requestId:randomUUID(),action:"speak",personId:"person-buddy",text:"hello",inputMode:"typed",bindingEpoch:1,...changes});
let checks=0;const check=(value,message)=>{checks++;assert.ok(value,message)};
for(const changes of [{bindingEpoch:2},{bindingEpoch:0},{bindingEpoch:true},{text:"\ud800"},{text:"\udc00"},{text:"a\nb"},{text:" "},{inputMode:"generated"}]){
 await assert.rejects(adapter.command("synthetic",payload(changes)));checks++;
}
const absent=payload();delete absent.bindingEpoch;await assert.rejects(adapter.command("synthetic",absent));checks++;
const request=payload({text:"hello \u{1f31f}"}), [first,duplicate]=await Promise.all([adapter.command("synthetic",request),adapter.command("synthetic",request)]);
check(first.sequence===1&&duplicate.sequence===1,"same request duplicated the immutable command");
await assert.rejects(adapter.command("synthetic",{...request,text:"altered intent"}));checks++;
const file=JSON.parse(await readFile(join(directory,"commands","0000000000000001.json"),"utf8"));
check(file.bindingEpoch===1&&file.text===request.text&&file.sessionId===sessionId,"immutable issuance identity or text differs");
check((await readdir(join(directory,"commands"))).filter(x=>x.endsWith(".json")).length===1,"duplicate request produced extra commands");
view={...view,sequence:2,capturedAtUnixMs:Date.now()+1,lastCommandSequence:1,commandResult:{sequence:1,status:"unknown",message:"May have emitted; no completed effect established."},commandActions:[]};
await save();await adapter.snapshot("synthetic");
const retry=await adapter.command("synthetic",request);check(retry.sequence===1,"unknown acknowledgment retry issued a new command");
check((await readdir(join(directory,"commands"))).filter(x=>x.endsWith(".json")).length===1,"unknown acknowledgment caused resend");
view={...view,sequence:3,capturedAtUnixMs:Date.now()+2,commandResult:{sequence:1,status:"applied",message:"Replaced outcome"}};
await save();await assert.rejects(adapter.snapshot("synthetic"));checks++;
console.log(JSON.stringify({status:"PASS",checks,evidence:"explicitly-synthetic-no-native-frames"}));
'''

POLL_PROBE = r'''
import java.nio.file.*;import java.util.*;import java.util.concurrent.atomic.*;
import se.krka.kahlua.j2se.J2SEPlatform;import se.krka.kahlua.vm.*;
import se.krka.kahlua.integration.LuaCaller;import se.krka.kahlua.converter.KahluaConverterManager;
import se.krka.kahlua.luaj.compiler.LuaCompiler;import zombie.Lua.LuaManager;import zombie.core.Core;
public class NativeCommunication12PollProbe {
 static StudyParticipant.Binding selected;
 static final AtomicLong emittedAt=new AtomicLong();static int emitted;
 static void set(String n,Object v)throws Exception{var f=StudyNativeInteraction.class.getDeclaredField(n);f.setAccessible(true);f.set(null,v);}
 static Object get(String n)throws Exception{var f=StudyNativeInteraction.class.getDeclaredField(n);f.setAccessible(true);return f.get(null);}
 static void check(boolean v,String m){if(!v)throw new AssertionError(m);}
 public static void main(String[] a)throws Exception {
  Core.debug=false;var p=new J2SEPlatform();var env=p.newEnvironment();var t=new KahluaThread(p,env);t.debugOwnerThread=Thread.currentThread();
  LuaManager.env=env;LuaManager.thread=t;LuaManager.caller=new LuaCaller(new KahluaConverterManager());
  env.rawset("noteEmission",(JavaFunction)(frame,count)->{emitted++;emittedAt.set(System.currentTimeMillis());return 0;});
  env.rawset("fixtureTimestamp",(JavaFunction)(frame,count)->{try{Thread.sleep(25);}catch(InterruptedException e){throw new RuntimeException(e);}return frame.push((double)System.currentTimeMillis());});
  String setup="local player={} function player:isDead() return false end function player:getCurrentSquare() return {} end function player:getX() return 0 end function player:getY() return 0 end function player:getZ() return 0 end function player:Say(text) noteEmission() end "
   +"fixturePlayer=player;function getGameTime() return {getWorldAgeHours=function() return 10 end} end function getTimestampMs() if failTimestamp then error('Synthetic fault after emitted utterance') end return fixtureTimestamp() end "
   +"SAO={Participants={player=function(n)return player end},Standing={playerKey=function(p)return 'synthetic-player' end},Body={active={buddy=true},foreign={}},Identity={get=function(id)return {id=id} end,displayName=function(r)return 'Synthetic buddy' end},Communication={bodyFor=function(id)return player end,canConverse=function(f,to)return true end,executionOwners={}}}";
  check(Boolean.TRUE.equals(t.pcall(LuaCompiler.loadstring(setup,"synthetic-poll-objects",env),new Object[0])[0]),"poll fixture setup failed");
  check(Boolean.TRUE.equals(t.pcall(LuaCompiler.loadstring(Files.readString(Path.of(a[0])),a[0],env),new Object[0])[0]),"actual module load failed");
  selected=new StudyParticipant.Binding(env.rawget("fixturePlayer"),0,23,"synthetic-save",1,10,true,0,0,0,"Synthetic",true);
  set("configured",true);set("session","69f9025d-1204-4120-930d-700000000001");set("attempt",1);
  set("epochBody",selected);set("epochMode","Sandbox");set("bindingEpoch",1L);
  var samples=new ArrayList<String>();var writer=new StudyParticipant.StatePublisher(Path.of(a[1]),(path,value)->{synchronized(samples){samples.add(value);}});set("writer",writer);
  env.rawset("failTimestamp",a[2].equals("unknown"));
  long now=System.currentTimeMillis();var f=new LinkedHashMap<String,Object>();
  f.put("schema",StudyNativeInteraction.SCHEMA);f.put("sessionId","69f9025d-1204-4120-930d-700000000001");f.put("pid",ProcessHandle.current().pid());f.put("attempt",1L);f.put("sequence",1L);
  f.put("save","synthetic-save");f.put("saveMode","Sandbox");f.put("playerIndex",0L);f.put("playerSqlId",23L);f.put("issuedAtUnixMs",now);f.put("expiresAtUnixMs",now+5000);f.put("personId","buddy");f.put("text","hello");f.put("inputMode","typed");f.put("bindingEpoch",1L);
  set("pending",new StudyNativeInteraction.Request(1,f,null));StudyNativeInteraction.poll();
  String expected=a[2].equals("unknown")?"unknown":"applied";
  check(((String)get("result")).contains("\"status\":\""+expected+"\""),"post-callback effect certainty differs: "+get("result"));
  check(emitted==1,"physical utterance was not emitted exactly once");
  set("sampled",false);StudyNativeInteraction.poll();check(emitted==1,"acknowledged/unknown request was replayed");
  check(writer.close(2000),"actual asynchronous state publisher did not drain");
  synchronized(samples){check(!samples.isEmpty(),"no poll sample reached actual publisher");for(String value:samples)System.out.println("SAMPLE="+value.strip());}
  System.out.println("CONTROL="+a[2]+" emitted="+emitted+" emittedAtUnixMs="+emittedAt.get()+" status="+expected);
 }
}
'''


def execute(arguments, log, *, cwd=ROOT):
    result = subprocess.run(list(map(str, arguments)), cwd=cwd, text=True, encoding="utf-8",
        errors="replace", capture_output=True, timeout=50,
        creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    log.write_text(result.stdout+result.stderr, encoding="utf-8")
    return result


def main():
    global EVIDENCE, Comm
    parser=argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--mousecat", type=Path, required=True)
    parser.add_argument("--cohort-classes", type=Path, required=True)
    parser.add_argument("--python-only", action="store_true")
    parser.add_argument("--python-module", type=Path)
    args=parser.parse_args()
    EVIDENCE=args.output.resolve(); EVIDENCE.mkdir(parents=True, exist_ok=False)
    if args.python_module:
        spec=importlib.util.spec_from_file_location("speech_review_copy", args.python_module.resolve())
        Comm=importlib.util.module_from_spec(spec); spec.loader.exec_module(Comm)
    sources=[ROOT/"tools/world_lab_native_communication.py",ROOT/"tools/world_lab/StudyNativeInteraction.java",
        ROOT/"mod/42.20/media/lua/client/SAO_MousecatInteraction.lua",ROOT/"tools/world_lab_native_play.py",
        ROOT/"tools/world_lab_run.py",ROOT/"tools/world_lab/StudyLoadingAgent.java",
        ROOT/"tools/world_lab/StudyParticipant.java",ROOT/"tools/world_lab/StudyParticipantInput.java",
        ROOT/"tools/world_lab_participant_feed.py",ROOT/"tools/world_lab_session.py",
        args.mousecat.resolve()/"src/core/native-view.mjs",Path(__file__).resolve()]
    snapshots=EVIDENCE/"source"; snapshots.mkdir()
    pins=[]
    for index, source in enumerate(sources):
        raw=source.read_bytes(); pin=hashlib.sha256(raw).hexdigest()
        dest=snapshots/(str(index).zfill(2)+"-"+source.name); dest.write_bytes(raw)
        if digest(source)!=pin: raise ValueError("source changed while pinning: "+str(source))
        pins.append(dict(path=str(source),sha256=pin,bytes=len(raw),snapshot=str(dest)))
    (EVIDENCE/"source-pins-before.json").write_text(json.dumps(pins,indent=2)+"\n",encoding="utf-8")
    stream=io.StringIO()
    result=unittest.TextTestRunner(stream=stream,verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(SpeechBoundaryTests))
    (EVIDENCE/"python-tests.log").write_text(stream.getvalue(),encoding="utf-8")
    print(stream.getvalue())
    phases=[dict(label="python-boundaries",tests=result.testsRun,failures=len(result.failures),errors=len(result.errors),skips=len(result.skipped))]
    if not args.python_only:
        classes=EVIDENCE/"probe-classes"; classes.mkdir()
        probe=EVIDENCE/"NativeCommunication12Probe.java"; probe.write_text(JAVA_PROBE,encoding="utf-8")
        lua=EVIDENCE/"synthetic-native-controls.lua"; lua.write_text(LUA_CONTROLS,encoding="utf-8")
        jars=[GAME/"projectzomboid.jar",GAME/"ZombieBuddy.jar"]
        cp=os.pathsep.join(map(str,[classes,args.cohort_classes.resolve(),*jars]))
        java_source=snapshots/"01-StudyNativeInteraction.java"
        # javac needs the production class filename. Only the evidence copy changes.
        qualified=EVIDENCE/"qualified-source";qualified.mkdir()
        (qualified/"StudyNativeInteraction.java").write_bytes(java_source.read_bytes())
        compiled=execute([JDK/"javac.exe","-cp",cp,"-d",classes,qualified/"StudyNativeInteraction.java",probe],EVIDENCE/"compile.log")
        phases.append(dict(label="installed-java-source-probe-compile",exitCode=compiled.returncode))
        if compiled.returncode==0:
            wire=EVIDENCE/"synthetic-wire.json"
            value=dict(schema=Comm.WIRE_SCHEMA,sessionId=SESSION,pid=27003,attempt=1,sequence=1,
                save="synthetic-save",saveMode="Sandbox",playerIndex=0,playerSqlId=23,
                issuedAtUnixMs=NOW,expiresAtUnixMs=NOW+5000,personId="person-buddy",text="wait here",inputMode="typed",bindingEpoch=1)
            wire.write_text(json.dumps(value,separators=(",",":")),encoding="utf-8")
            for mode,arguments in (("eligibility",[wire]),("epoch",[]),("lua",[snapshots/"02-SAO_MousecatInteraction.lua",lua])):
                process=execute([GAME/"jre64/bin/java.exe","-Djava.awt.headless=true","-Duser.home="+str(EVIDENCE/"isolated-home"),
                    "-cp",cp,"NativeCommunication12Probe",mode,*arguments],EVIDENCE/(mode+".log"),cwd=GAME if mode=="lua" else ROOT)
                phases.append(dict(label="installed-java-"+mode,exitCode=process.returncode))
                print(mode+": "+(process.stdout+process.stderr).strip())
            poll_source=EVIDENCE/"synthetic-sampling-source";poll_source.mkdir()
            current=java_source.read_text(encoding="utf-8")
            replacements={"StudyParticipant.Binding body = StudyParticipant.binding();":
                "StudyParticipant.Binding body = NativeCommunication12PollProbe.selected;",
                'String mode = body == null ? "" : Core.getInstance().getGameMode();':
                'String mode = body == null ? "" : "Sandbox";'}
            for old,new in replacements.items():
                if current.count(old)!=1: raise ValueError("synthetic sampling seam changed: "+old)
                current=current.replace(old,new)
            (poll_source/"StudyNativeInteraction.java").write_text(current,encoding="utf-8")
            poll=EVIDENCE/"NativeCommunication12PollProbe.java";poll.write_text(POLL_PROBE,encoding="utf-8")
            poll_classes=EVIDENCE/"poll-classes";poll_classes.mkdir()
            poll_cp=os.pathsep.join(map(str,[poll_classes,args.cohort_classes.resolve(),*jars]))
            process=execute([JDK/"javac.exe","-cp",poll_cp,"-d",poll_classes,poll_source/"StudyNativeInteraction.java",poll],EVIDENCE/"poll-compile.log")
            phases.append(dict(label="actual-poll-with-synthetic-native-sampling-compile",exitCode=process.returncode))
            if process.returncode==0:
                for mode in ("emitted","unknown"):
                    proc=execute([GAME/"jre64/bin/java.exe","-Djava.awt.headless=true","-Duser.home="+str(EVIDENCE/"isolated-home"),
                        "-cp",poll_cp,"NativeCommunication12PollProbe",snapshots/"02-SAO_MousecatInteraction.lua",
                        EVIDENCE/("poll-"+mode+".json"),mode],EVIDENCE/("poll-"+mode+".log"),cwd=GAME)
                    phases.append(dict(label="actual-poll-synthetic-sampling-"+mode,exitCode=proc.returncode))
                    print("poll-"+mode+": "+(proc.stdout+proc.stderr).strip())
                    if proc.returncode==0:
                        samples=[json.loads(line[7:]) for line in proc.stdout.splitlines() if line.startswith("SAMPLE=")]
                        for sample in samples:
                            Comm.validate_state(sample,dict(sessionId=SESSION,pid=sample["pid"],launchNumber=1),sample["capturedAtUnixMs"])
                            if sample["gameThreadDurationNs"]<0:raise AssertionError("native callback cost is negative")
                        (EVIDENCE/("poll-"+mode+"-samples.json")).write_text(json.dumps(samples,indent=2)+"\n",encoding="utf-8")
        node=EVIDENCE/"native-sink-controls.mjs";node.write_text(NODE_PROBE,encoding="utf-8")
        node_run=execute(["node",node,args.mousecat.resolve()/"src/core/native-view.mjs",EVIDENCE/"node-synthetic"],EVIDENCE/"node-sink.log")
        phases.append(dict(label="actual-mousecat-command-sink",exitCode=node_run.returncode))
        print("node: "+(node_run.stdout+node_run.stderr).strip())
    drift=[dict(path=pin["path"],before=pin["sha256"],after=digest(pin["path"])) for pin in pins if digest(pin["path"])!=pin["sha256"]]
    passed=result.wasSuccessful() and not drift and all(row.get("exitCode",0)==0 for row in phases)
    receipt=dict(schema="sao.native-communication-source-qualification/12",status="PASS_SOURCE_SYNTHETIC" if passed else "FAIL_SOURCE_SYNTHETIC",
        evidenceOrigin="explicitly-synthetic-actual-source-and-installed-dependencies",phases=phases,sourcePins=pins,sourceDrift=drift,
        nativeGameActions=False,nativeFrames=False,runnerOrVoiceAcceptance=False,
        reusedObjectiveChecks="frozen unchanged; not rerun")
    (EVIDENCE/"receipt.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({key:receipt[key] for key in ("status","phases","sourceDrift")}))
    return 0 if passed else 1


if __name__ == "__main__":
    sys.dont_write_bytecode=True
    raise SystemExit(main())
