#!/usr/bin/env python3
"""Border 186: operating radio endpoints produce private reception evidence."""
from __future__ import annotations

import hashlib
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import time


ROOT = pathlib.Path(__file__).resolve().parents[1]
GAME = pathlib.Path(os.environ.get(
    "PZ_DIR", r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"))
PZ = GAME / "projectzomboid.jar"
ZB = GAME / "ZombieBuddy.jar"
JDK = pathlib.Path(os.environ.get(
    "JDK_BIN", r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin"))
LUA = ROOT / "mod/42.20/media/lua"
STANDING = LUA / "shared/SAO_Standing.lua"
ORGANIZATION = LUA / "shared/SAO_Organization.lua"
PERCEPTION = LUA / "shared/SAO_Perception.lua"
COMMUNICATION = LUA / "shared/SAO_Communication.lua"
RADIO = LUA / "server/SAO_Radio.lua"
HARNESS = LUA / "client/SAO_Harness.lua"
RADIO_EAR = LUA / "client/SAO_RadioEar.lua"
KNOWLEDGE = LUA / "shared/SAO_Knowledge.lua"
PHYSICAL = LUA / "shared/SAO_PhysicalFacts.lua"
BODY = LUA / "client/SAO_Body.lua"
PRIVATE = ROOT / "java/src/com/sao/engine/SAOPrivateInventory.java"
BRIDGE = ROOT / "java/src/com/sao/bridge/SAOBridge.java"
PROBE = ROOT / "tools/luacheck/RadioReceptionProbe.java"
CASES = ROOT / "tools/sweep/radio_reception_cases.lua"

EXPECTED = {
    "request_producer_names_speaker", "wire_reaches_exact_endpoints",
    "private_reception_evidence", "request_radio_provenance",
    "legacy_possession_refused", "dormant_battery_advanced",
    "replay_is_idempotent", "source_less_request_stays_global",
    "player_transmission_exact_listeners", "player_receipt_precedes_effect",
    "muted_transmitter_refused", "beacon_creates_receipt",
    "receipt_requires_matching_channel", "receipt_requires_bounded_power",
    "retroactive_reception_refused", "loaded_controller_sleep_refused",
    "failed_clock_refuses_broadcast", "borrowed_body_refused",
    "unrecorded_claim_field_refused",
}

PRELUDE = r'''
Events=setmetatable({}, {__index=function()
  return {Add=function() end,Remove=function() end} end})
DynamicRadio={channels={},scripts={},cache={}}
RadioLine={new=function(text) return text end}
RadioBroadCast={new=function(id)
  return {id=id,lines={},AddRadioLine=function(self,line)
    self.lines[#self.lines+1]=line end}
end}
__now,__stores,__records,__bodies,__represented=100,{},{},{},{}
__player=nil __clockFail=false
ModData={getOrCreate=function(key)
  __stores[key]=__stores[key] or {} return __stores[key]
end}
SandboxVars={SurvivorAwareness={Material=true}}
getSpecificPlayer=function(index) return index==0 and __player or nil end
getGameTime=function() return nil end
SAO={
 Log={line=function() end},
 Rand={int=function(a,b) return a or 0 end},
 History={countyHours=function()
   if __clockFail then error('clock unavailable') end return __now end,
   ticks=function() return __now*9000 end,TICKS_PER_HOUR=9000,
   recordDay=function() return 0 end},
 Conditions={memoryFactor=function() return 1 end},
 Identity={get=function(id) return __records[tostring(id)] end,
   all=function() return __records end,
   knownName=function(rec) return rec and rec.id or nil end,
   beliefKey=function(rec) return rec and rec.id or nil end,
   displayName=function(rec) return rec and rec.id or 'unknown' end},
 Body={get=function(id) return __bodies[tostring(id)] end,
   hasRepresentation=function(id)
     return __bodies[tostring(id)]~=nil or __represented[tostring(id)]==true
   end},
 Controller={agents={}},
 GraphPersistence={bind=function() return true end},
 Disposition={},
}
local function parts(state)
  if type(state)~='string' then return nil end
  local on,channel,volume,power,use=string.match(state,
    '^RAD:(%d):(%d+):([%d%.eE%+%-]+):([%d%.eE%+%-]+):([%d%.eE%+%-]+)$')
  if not on then return nil end
  return tonumber(on)==1,tonumber(channel),tonumber(volume),tonumber(power),tonumber(use)
end
local function endpoint(receiver,frequency,transmit)
  if type(receiver)~='table' or receiver.direct~=true then
    return 'REFUSED:no-direct-receiver' end
  if not receiver.on then return 'REFUSED:off' end
  if receiver.channel~=frequency then return 'REFUSED:mistuned' end
  if receiver.battery and (not receiver.hasBattery or receiver.power<=0) then
    return 'REFUSED:unpowered' end
  if transmit then
    if not receiver.twoWay then return 'REFUSED:receive-only' end
    if receiver.muted then return 'REFUSED:muted' end
    if receiver.noTransmit then return 'REFUSED:transmit-disabled' end
  elseif receiver.volume<=0 then return 'REFUSED:silent' end
  return 'AVAILABLE:'..tostring(receiver.itemId)..':'
    ..tostring(receiver.fullType)..':'..tostring(receiver.channel)..':'
    ..tostring(receiver.power)
end
SAOJavaBridge={
 canReceiveRadioNow=function(self,body)
   return body and not body.dead and not body.asleep and not body.deaf end,
 canTransmitRadioNow=function(self,body)
   return body and not body.dead and not body.asleep end,
 loadedRadioReceiverAccess=function(self,body,frequency)
   return endpoint(body and body.receiver,frequency,false) end,
 loadedRadioTransmitterAccess=function(self,body,frequency)
   return endpoint(body and body.receiver,frequency,true) end,
 validateRadioState=function(self,state) return parts(state)~=nil end,
 advanceDormantRadioState=function(self,state,elapsed)
   local on,channel,volume,power,use=parts(state)
   if on==nil or type(elapsed)~='number' or elapsed<0 then return '' end
   if on then power=math.max(0,power-use*elapsed*60) end
   if power<=0 then on=false end
   return 'RAD:'..(on and '1' or '0')..':'..tostring(channel)..':'
     ..tostring(volume)..':'..tostring(power)..':'..tostring(use)
 end,
 dormantRadioReceiverAccess=function(self,state,frequency)
   local on,channel,volume,power=parts(state)
   if on==nil then return 'REFUSED:state-unavailable' end
   return endpoint({direct=true,on=on,channel=channel,volume=volume,
     power=power,battery=true,hasBattery=true,twoWay=true,muted=false,
     noTransmit=false,itemId=7310,fullType='Base.WalkieTalkie5'},frequency,false)
 end,
 hibernationHearingAccess=function() return 'AVAILABLE:1.0' end,
 canConverseNow=function() return true end,
 speechWeatherHearing=function() return 1 end,
}
'''

LUA_MUTATIONS = (
    ("request-source", STANDING,
     "speakerId = speakerId, processId", "speakerId = nil, processId",
     "request_producer_names_speaker"),
    ("receipt-before-effect", RADIO,
     "        if received then\n            delivered[rec.id] = true",
     "        if true then\n            delivered[rec.id] = true",
     "wire_reaches_exact_endpoints"),
    ("private-receipt-write", PERCEPTION,
     "    b.radioReceptions[broadcastId] = receipt",
     "    -- mutation omits the recipient-private receipt",
     "private_reception_evidence"),
    ("per-person-listener", STANDING,
     "    return s.onAir and s.onAir.heardSolo\n"
     "        and s.onAir.heardSolo[id] ~= nil or false",
     "    local g = s.groups and s.groups[id]\n"
     "    return (s.onAir and s.onAir.heardSolo and s.onAir.heardSolo[id])\n"
     "        or (g ~= nil and s.onAir and s.onAir.heardSolo ~= nil)",
     "player_transmission_exact_listeners"),
    ("current-event-time", COMMUNICATION,
     "if not finite(at) or at < 0 or math.abs(at - now) > 0.000001 then",
     "if not finite(at) or at < 0 or false then",
     "retroactive_reception_refused"),
    ("listener-body-binding", COMMUNICATION,
     "local resolved = bodyFor(id)\n"
     "    if body and resolved ~= body then return nil, \"body-mismatch\" end\n"
     "    body = resolved\n"
     "    if body then",
     "local resolved = bodyFor(id)\n"
     "    if false then return nil, \"body-mismatch\" end\n"
     "    body = body or resolved\n"
     "    if body then",
     "borrowed_body_refused"),
    ("complete-claim-receipt", PERCEPTION,
     "if type(key) ~= \"string\" or not RADIO_CLAIM_FIELD_SET[key] then",
     "if type(key) ~= \"string\" then",
     "unrecorded_claim_field_refused"),
)


def sha(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def static_contract() -> list[str]:
    private = PRIVATE.read_text(encoding="utf-8-sig")
    bridge = BRIDGE.read_text(encoding="utf-8-sig")
    standing = STANDING.read_text(encoding="utf-8-sig")
    perception = PERCEPTION.read_text(encoding="utf-8-sig")
    communication = COMMUNICATION.read_text(encoding="utf-8-sig")
    radio = RADIO.read_text(encoding="utf-8-sig")
    harness = HARNESS.read_text(encoding="utf-8-sig")
    ear = RADIO_EAR.read_text(encoding="utf-8-sig")
    knowledge = KNOWLEDGE.read_text(encoding="utf-8-sig")
    physical = PHYSICAL.read_text(encoding="utf-8-sig")
    body = BODY.read_text(encoding="utf-8-sig")
    petition_start = harness.find('wire:addOption("Urge peace on the air"')
    petition_end = harness.find('wire:addOption("Ask for the news"',
                                 petition_start)
    petition = (harness[petition_start:petition_end]
                if petition_start >= 0 and petition_end > petition_start else "")
    plan = (ROOT / "artifacts/audits/20260921-2351Z-1651PST-radio-reception/PLAN.md").read_text(
        encoding="utf-8-sig")
    checks = {
        "matrix and boundary": all(term in plan for term in (
            "Loaded receiver state", "Dormant receiver state",
            "Reception", "Household shortage", "transmission, access, receipt")),
        "direct-root protocol": 'RADIO_PROTOCOL = "SAORAD1;"' in private
            and "person.getInventory().getItems()" in private
            and "loadedRadioFacts" in private,
        "device predicates": all(term in private for term in (
            "getIsTurnedOn", "getChannel", "getDeviceVolume",
            "getIsBatteryPowered", "getHasBattery", "getPower",
            "getUseDelta", "getIsTwoWay", "getMicIsMuted", "isNoTransmit")),
        "dormant power": "elapsedHours * 60.0" in private
            and "setTurnedOnRaw" in private and "applyRadioState" in private,
        "bridge endpoints": all(term in bridge for term in (
            "captureRadioState", "advanceDormantRadioState",
            "loadedRadioReceiverAccess", "loadedRadioTransmitterAccess",
            "dormantRadioReceiverAccess", "applyDormantRadioState")),
        "checkpoint and wake": "rec.radioState = radioKnown and facts.radioState or nil" in physical
            and "rec.radioStateAtHours = radioKnown and now or nil" in physical
            and "applyDormantRadioState" in body,
        "private receipt": "function P.recordRadioReception" in perception
            and "radioReceptions" in perception and "RADIO_LIMIT = 64" in perception,
        "transport before content": "Communication.radioReception" in radio
            and radio.find("Communication.radioReception") < radio.find("hearTheWire(rec.id"),
        "request source": "speakerId = speakerId" in standing
            and '"told", item.speakerId, "food"' in radio,
        "player exact endpoints": "radioTransmitterAccess" in ear
            and "Communication.radioReception" in harness
            and "heardBy" not in harness and "local receivedBy = {}" in harness
            and "target = atWar" not in harness,
        "radio petition is addressed not inferred":
            "SAO.Organization.recordReception" in petition
            and "answerPeacePetition" in petition
            and "radioTransmitterAccess" in petition
            and "adjustTrust" not in petition,
        "ownership removed from claims": "ownsRadio" not in radio
            and "ownsRadio" not in harness and "ownsRadio" not in knowledge,
        "knowledge from receipt": "SAO.Perception.radioReceptions" in knowledge,
        "older state refused": '"receiver-unobserved"' in communication,
    }
    missing = [name for name, passed in checks.items() if not passed]
    if missing:
        raise RuntimeError("Radio reception contract missing: " + ", ".join(missing))
    return list(checks)


def run(command, cwd, phase, case, receipt, timeout=180):
    started = time.perf_counter()
    done = subprocess.run([str(value) for value in command], cwd=cwd,
        capture_output=True, text=True, encoding="utf-8", errors="replace",
        timeout=timeout)
    receipt["commands"].append({"phase": phase, "case": case,
        "returncode": done.returncode, "seconds": time.perf_counter() - started,
        "stdout": done.stdout, "stderr": done.stderr})
    return done


def compile_lua_runner(work: pathlib.Path):
    import provisioning_result_test as border
    shutil.copy2(border.STDLIB, work / "stdlib.lua")
    done = subprocess.run([str(JDK / "javac.exe"), "-cp", str(PZ), "-d",
        str(work), str(border.RUNNER)], capture_output=True, text=True,
        encoding="utf-8", errors="replace", timeout=120)
    if done.returncode:
        raise RuntimeError("Lua runner compile failed: " + done.stdout + done.stderr)


def run_lua(work: pathlib.Path, overrides=None):
    overrides = overrides or {}
    prelude = work / "prelude.lua"
    prelude.write_text(PRELUDE, encoding="utf-8")
    chunks = [prelude]
    for path in (ORGANIZATION, STANDING, PERCEPTION, COMMUNICATION, RADIO):
        if path.name in overrides:
            altered = work / ("altered-" + path.name)
            altered.write_text(overrides[path.name], encoding="utf-8")
            chunks.append(altered)
        else:
            chunks.append(path)
    probe = work / "cases.lua"
    probe.write_text("local ok, result = pcall(function() return "
        + CASES.read_text(encoding="utf-8") + "\nend)\n"
        + "__radioReceptionResult = ok and result or ('ERROR after ' .. "
        + "tostring(__radioReceptionLast) .. ': ' .. tostring(result))\n",
        encoding="utf-8")
    chunks.append(probe)
    done = subprocess.run([str(JDK / "java.exe"), "-cp", f"{PZ};.",
        "LuaRun", *map(str, chunks), "--", "__radioReceptionResult"],
        cwd=work, capture_output=True, text=True, encoding="utf-8",
        errors="replace", timeout=120)
    detail = done.stdout + done.stderr
    lines = done.stdout.strip().splitlines()
    value = lines[-1][6:] if lines and lines[-1].startswith("VALUE ") else ""
    return dict(re.findall(r"([a-z0-9_]+)=(true|false)", value)), detail


def compile_native(work: pathlib.Path, receipt: dict):
    classes = work / "production"
    classes.mkdir()
    generated = work / "SAOVersion.java"
    version = (ROOT / "VERSION").read_text(encoding="utf-8-sig").strip()
    generated.write_text("package com.sao; public final class SAOVersion { "
        f'public static final String VALUE = "{version}"; '
        "private SAOVersion() {} }\n", encoding="utf-8")
    sources = sorted((ROOT / "java/src").rglob("*.java"))
    sources.extend((generated, PROBE))
    classpath = os.pathsep.join(map(str, (PZ, ZB)))
    compiled = run([JDK / "javac.exe", "-encoding", "UTF-8", "-cp",
        classpath, "-d", classes, *sources], work, "native-compile",
        "production", receipt)
    if compiled.returncode:
        raise RuntimeError("Radio native compile failed: "
            + compiled.stdout + compiled.stderr)
    return classes


def run_native(work: pathlib.Path, classes: pathlib.Path, receipt: dict,
        case="production", override=None):
    leading = []
    if override is not None:
        mutation = work / case
        mutation.mkdir()
        changed = mutation / "SAOPrivateInventory.java"
        changed.write_text(override, encoding="utf-8")
        mutated = mutation / "classes"
        mutated.mkdir()
        compiled = run([JDK / "javac.exe", "-encoding", "UTF-8", "-cp",
            os.pathsep.join(map(str, (classes, PZ, ZB))), "-d", mutated,
            changed], work, "native-compile", case, receipt)
        if compiled.returncode:
            raise RuntimeError(f"Radio native mutation {case} failed to compile: "
                + compiled.stdout + compiled.stderr)
        leading.append(mutated)
    classpath = os.pathsep.join(map(str, (*leading, classes, PZ, ZB)))
    return run([JDK / "java.exe", f"-Duser.home={work / case}", "-cp",
        classpath, "RadioReceptionProbe"], work, "native-probe", case,
        receipt)


def execute(receipt: dict) -> None:
    with tempfile.TemporaryDirectory(prefix="sao-radio-reception-") as raw:
        work = pathlib.Path(raw)
        compile_lua_runner(work)
        checks, detail = run_lua(work)
        failed = sorted(name for name, value in checks.items() if value != "true")
        if set(checks) != EXPECTED or failed:
            raise RuntimeError("Radio Kahlua cases failed: missing="
                f"{sorted(EXPECTED-set(checks))} extra={sorted(set(checks)-EXPECTED)} "
                f"failed={failed}\n{detail[-5000:]}")
        print(f"PASS {len(checks)} production radio reception cases")
        for name, path, before, after, expected in LUA_MUTATIONS:
            original = path.read_text(encoding="utf-8-sig")
            if original.count(before) != 1:
                raise RuntimeError(f"Radio Lua mutation anchor drifted: {name}")
            altered, detail = run_lua(work,
                {path.name: original.replace(before, after, 1)})
            if set(altered) != EXPECTED or altered.get(expected) != "false":
                raise RuntimeError(f"Radio Lua mutation {name} did not flip "
                    f"{expected}\n{detail[-5000:]}")
            print(f"CONTROL {name}: {expected}")

        classes = compile_native(work, receipt)
        production = run_native(work, classes, receipt)
        if production.returncode or "PASS radio state:" not in production.stdout:
            raise RuntimeError("Radio native probe failed: "
                + production.stdout + production.stderr)
        print(production.stdout.strip())
        source = PRIVATE.read_text(encoding="utf-8-sig")
        mutations = (
            ("recursive-radio", "for (InventoryItem item : new ArrayList<>(\n"
             "                person.getInventory().getItems())) {\n"
             "            if (!(item instanceof Radio radio)",
             "for (InventoryItem item : carriedItems(person)) {\n"
             "            if (!(item instanceof Radio radio)", "nested_refused"),
            ("no-battery-use", "* elapsedHours * 60.0;",
             "* 0.0 * 60.0;", "elapsed_power"),
            ("power-bypass", "if (fact.batteryPowered()\n"
             "                    && (!fact.hasBattery() || fact.power() <= 0.0f)) {",
              "if (false) {", "unpowered_refused"),
            ("partial-wake-overlay", "                overlays.put(fact, data);",
             "                data.setPower(fact.power());\n"
             "                overlays.put(fact, data);", "transactional_restore"),
        )
        for name, before, after, marker in mutations:
            if source.count(before) != 1:
                raise RuntimeError(f"Radio native mutation anchor drifted: {name}")
            controlled = run_native(work, classes, receipt, name,
                source.replace(before, after, 1))
            output = controlled.stdout + controlled.stderr
            if controlled.returncode == 0 or marker not in output:
                raise RuntimeError(f"Radio native control {name} did not fail "
                    f"at {marker}: {output[-3000:]}")
            print(f"CONTROL {name}: {marker}")
        print("Border 186 PASS: actual radio reception")


def main(argv=None) -> int:
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--receipt", type=pathlib.Path)
    args = parser.parse_args(argv)
    receipt = {"border": 186, "checks": [], "commands": [], "status": "FAIL"}
    try:
        receipt["checks"] = static_contract()
        required = (PZ, ZB, JDK / "java.exe", JDK / "javac.exe", PROBE, CASES)
        if not all(path.is_file() for path in required):
            receipt["status"] = "SKIPPED"
            print("Border 186 SKIPPED: installed game VM or JDK absent; "
                "static radio contract checked")
        else:
            receipt["engine_sha256"] = sha(PZ)
            execute(receipt)
            receipt["status"] = "PASS"
    except Exception as error:
        receipt["error"] = str(error)
        print("FAULT radio reception: " + str(error), file=sys.stderr)
        code = 1
    else:
        code = 0
    if args.receipt:
        args.receipt.parent.mkdir(parents=True, exist_ok=True)
        args.receipt.write_text(json.dumps(receipt, indent=2) + "\n",
            encoding="utf-8")
    return code


if __name__ == "__main__":
    raise SystemExit(main())
