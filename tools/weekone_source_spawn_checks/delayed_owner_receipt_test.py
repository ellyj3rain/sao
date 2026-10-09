#!/usr/bin/env python3
"""Probe selected Week One ownership when its server reply crosses retirement."""

from pathlib import Path
import hashlib
import json
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from weekone_continuity_test import GAME, JDK, PRELUDE, ROOT, SOURCE
from weekone_source_spawn_test import EXTRA


LUA = r'''
local W = SAO.WeekOneContinuity
local event = '00000000000000000000000000000385'
local brain, body = __entrant(901)
brain.saoWeekOneStartEntry.eventRef = event
if __which == 'saved-sandbox' then
 brain.saoWeekOneStartEntry.selectionSource = 'saved-sandbox'
elseif __which == 'legacy-stamp' then
 brain.saoWeekOneStartEntry.selectionSource = nil
end
if __which ~= 'saved-sandbox' and __which ~= 'legacy-stamp' then
 __player.data.SAOCreationReceipt = __receipt(true)
end
__source = body
__query = nil
local id = W.observeBrain(brain, body)
assert(id and __records[id] and not __records[id].weekOne.sourceSpawn,
 'selected proxy acquired player origin without the owner receipt')
if __which ~= 'saved-sandbox' and __which ~= 'legacy-stamp' then
 assert(__query and __query.module == 'SAOWeekOne'
  and __query.command == 'QueryOwnerReceipt'
  and __query.args.brainId == brain.id
  and __query.args.born == brain.born,
  'the exact missing owner receipt was not requested')
end
local rec = __records[id]
local owner = { source = 'BWOEvents.Start/StartBabe', eventRef = event,
 brainId = brain.id, born = brain.born, accountKey = 'player:account',
 playerKey = 'player:account', nativeDescriptorId = 55,
 forename = 'Avery', surname = 'Stone', world = 'trial-world',
 gameMode = 'Sandbox' }
local function copy(value)
 local next = {}
 for key, entry in pairs(value) do next[key] = entry end
 return next
end
local function reply(value)
 W.onServerCommand('SAOWeekOne', 'OwnerReceipt', value)
end
local function assertAdmitted(label)
 local stamp = rec.weekOne.sourceSpawn
 assert(stamp and stamp.eventRef == event and stamp.source == owner.source
  and stamp.brainId == brain.id and stamp.born == brain.born
  and stamp.accountKey == nil and stamp.playerKey == nil
  and stamp.nativeDescriptorId == nil and stamp.world == nil
  and W.selectedStartProvenance(id).playerKey
    == __player.data.SAOCreationReceipt.playerKey
  and stamp.program == 'Walker' and stamp.sourceProgram == 'Babe'
  and stamp.relationship == nil and stamp.age == nil and stamp.birth == nil
  and not rec.weekOne.chatCompanion and not rec.playerCompanionIntent
  and __grants == 0, label)
end
local function assertHeld(label)
 local accepted, reason = W.prepareRetire(brain, body, __player)
 assert(accepted == false and reason == 'selected-owner-receipt-pending'
  and rec.weekOne.status == 'external'
  and rec.weekOne.pending == nil and rec.weekOne.stageToken == nil
  and rec.heldBy == 'BanditsWeekOne' and __source == body
  and body.alive == true and body.md.SAOWeekOnePersonId == id
  and __grants == 0, label..':'..tostring(reason))
end
local function prepareTicket(ticket)
 local prepared = { id = brain.id, born = brain.born,
  token = ticket.token, personId = id }
 W.onServerCommand('SAOWeekOne', 'Prepared', prepared)
 assert(rec.weekOne.pending and rec.weekOne.pending.serverPrepared == true,
  'exact retirement was not prepared')
 return prepared
end
local function finishRetire(prepared, ticket)
 local action, reason = W.confirmPreparedRetire(prepared, brain, body, __player)
 assert(action == 'remove', 'prepared source removal refused: '..tostring(reason))
 __source = nil
 body.alive = false
 W.onServerCommand('SAOWeekOne', 'Retired',
  {id = brain.id, born = brain.born, token = ticket.token})
 assert(rec.weekOne.status == 'dormant' and rec.hibernation == 'PACK:weekone',
  'exact source retirement was not durably completed')
 W.poll()
 assert(rec.weekOne.status == 'transferred',
  'native default did not release the retired source person')
end
local function retire()
 local accepted, ticket = W.prepareRetire(brain, body, __player)
 assert(accepted == true and ticket and ticket.personId == id,
  'selected proxy could not prepare its exact source retirement')
 finishRetire(prepareTicket(ticket), ticket)
end

if __which == 'timely' then
 reply(owner)
 assert(W.observeBrain(brain, body) == id,
  'source actor was unavailable before retirement')
 assertAdmitted('timely private owner receipt was not retained')
 retire()
 assertAdmitted('timely provenance was lost during source retirement')
elseif __which == 'delayed' then
 assertHeld('selected proxy retired before its private owner reply')
 assert(rec.weekOne.sourceSpawn == nil,
  'pending selected player provenance was invented')
 reply(owner)
 assert(W.observeBrain(brain, body) == id,
  'held source actor was unavailable after the exact owner reply')
 assertAdmitted('delayed private owner receipt was not retained')
 retire()
 assertAdmitted('delayed provenance was lost during source retirement')
elseif __which == 'retired-requery' then
 reply(owner)
 assert(W.observeBrain(brain, body) == id,
  'source actor was unavailable before retirement')
 retire()
 W.rebindWorld()
 __query = nil
 local missing, reason = W.selectedStartProvenance(id)
 assert(missing == nil and reason == 'owner-receipt-pending'
  and __query and __query.command == 'QueryOwnerReceipt'
  and __query.args.eventRef == event
  and __query.args.brainId == brain.id,
  'retired source person did not query private owner after reload')
 reply(owner)
 assertAdmitted('retired selected owner did not recover after reload')
elseif __which == 'inflight-upgrade' then
 -- A saved Prepared ticket from the previous source existed before this
 -- creator selection could be held. Mint its exact native ticket with the
 -- earlier unclassified marker, then restore the stamped selection source.
 brain.saoWeekOneStartEntry.selectionSource = nil
 local accepted, ticket = W.prepareRetire(brain, body, __player)
 brain.saoWeekOneStartEntry.selectionSource = 'creator-receipt'
 assert(accepted == true and ticket and ticket.personId == id,
  'earlier source could not mint an exact in-flight retirement ticket')
 local prepared = prepareTicket(ticket)
 local action, reason = W.confirmPreparedRetire(prepared, brain, body, __player)
 assert(action == nil and reason == 'selected-owner-receipt-pending'
  and rec.weekOne.pending.localRemovalIntent ~= true
  and rec.weekOne.status == 'retirement-pending'
  and rec.heldBy == 'BanditsWeekOne' and __source == body
  and body.alive == true and __grants == 0,
  'in-flight selected proxy removed before its owner receipt:'..tostring(reason))
 local wrong = copy(owner)
 wrong.accountKey = 'player:other'
 reply(wrong)
 action, reason = W.confirmPreparedRetire(prepared, brain, body, __player)
 assert(action == nil and reason == 'selected-owner-receipt-pending'
  and rec.weekOne.pending.localRemovalIntent ~= true,
  'wrong owner receipt released in-flight selected proxy:'..tostring(reason))
 reply(owner)
 assert(W.observeBrain(brain, body) == id,
  'in-flight source actor was unavailable after exact owner reply')
 assertAdmitted('in-flight owner receipt did not bind provenance')
 finishRetire(prepared, ticket)
 assertAdmitted('in-flight provenance was lost during retirement')
elseif __which == 'wrong-account' or __which == 'wrong-generation'
 or __which == 'wrong-event' then
 local wrong = copy(owner)
 if __which == 'wrong-account' then wrong.accountKey = 'player:other' end
 if __which == 'wrong-generation' then wrong.born = owner.born + 1 end
 if __which == 'wrong-event' then
  wrong.eventRef = '00000000000000000000000000000386' end
 reply(wrong)
 W.observeBrain(brain, body)
 assert(rec.weekOne.sourceSpawn == nil and __grants == 0,
  'invalid owner reply conferred selected-player provenance')
 assertHeld('invalid reply released the selected proxy')
 reply(owner)
 W.observeBrain(brain, body)
 assertAdmitted('valid inverse failed after invalid owner reply')
elseif __which == 'saved-sandbox' or __which == 'legacy-stamp' then
 assert(rec.weekOne.sourceSpawn == nil and __grants == 0,
  'source-only selection inferred a current player')
 retire()
 assert(rec.weekOne.sourceSpawn == nil and rec.playerCompanionIntent == nil
  and rec.weekOne.chatCompanion == nil and __grants == 0,
  'source-only selection gained a player tie during retirement')
else
 error('unknown case '..tostring(__which))
end
return 'PASS:'..__which
'''

CASES = ("saved-sandbox", "legacy-stamp", "timely", "wrong-account",
         "wrong-generation", "wrong-event", "delayed", "retired-requery",
         "inflight-upgrade")


def main() -> int:
    if not SOURCE.is_file() or not (GAME / "projectzomboid.jar").is_file():
        raise SystemExit("Week One source or installed engine unavailable")
    source_bytes = SOURCE.read_bytes()
    source = source_bytes.decode("utf-8")
    receipt = {"sourceSha256": hashlib.sha256(source_bytes).hexdigest(),
               "cases": []}
    with tempfile.TemporaryDirectory(prefix="sao-weekone-owner-delay-") as temp:
        work = Path(temp)
        (work / "stdlib.lua").write_bytes((GAME / "stdlib.lua").read_bytes())
        built = subprocess.run([str(JDK / "javac.exe"), "-cp",
            str(GAME / "projectzomboid.jar"), "-d", str(work),
            str(ROOT / "tools/luacheck/LuaRun.java")],
            capture_output=True, text=True, timeout=120)
        if built.returncode:
            raise RuntimeError("Kahlua harness compilation failed: " + built.stderr)
        (work / "prelude.lua").write_text(PRELUDE + EXTRA, encoding="utf-8")

        def run(name: str, candidate: str) -> tuple[int, str]:
            (work / "SAO_WeekOneContinuity.lua").write_text(candidate,
                encoding="utf-8")
            (work / "cases.lua").write_text(
                "__which='" + name + "'\nfunction __cases()\n" + LUA +
                "\nend\nfunction __safe() local ok,value=pcall(__cases) "
                "if ok then return value end "
                "return 'FAIL:'..tostring(value) end",
                encoding="utf-8")
            done = subprocess.run([str(JDK / "java.exe"), "-cp",
                f"{GAME / 'projectzomboid.jar'};{work}", "LuaRun",
                str(work / "prelude.lua"),
                str(work / "SAO_WeekOneContinuity.lua"),
                str(work / "cases.lua"), "--", "__safe()"],
                cwd=work, capture_output=True, text=True, timeout=60)
            output = done.stdout + done.stderr
            receipt["cases"].append({"name": name, "exit": done.returncode,
                                     "output": output[-1600:]})
            return done.returncode, output

        for name in CASES:
            code, output = run(name, source)
            if code or f"VALUE PASS:{name}" not in output:
                current_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
                raise RuntimeError(f"{name} failed under source "
                    f"{receipt['sourceSha256']} (current {current_hash}): {output}")
        needle = ("    admitSelectedSourceSpawn(brain, rec)\n"
                  "    if rec.weekOne.sourceFallbackSeen ~= true then")
        if source.count(needle) != 1:
            raise RuntimeError("timely check mutation target changed")
        code, output = run("timely", source.replace(needle,
            "    -- admitSelectedSourceSpawn(brain, rec)\n"
            "    if rec.weekOne.sourceFallbackSeen ~= true then", 1))
        if code or "VALUE FAIL:the exact missing owner receipt was not requested" not in output:
            raise RuntimeError("timely check failed its source mutation: " + output)
        prepare_guard = ("    if selectedOwnerReceiptPending(brain, rec) then\n"
                         "        return false, \"selected-owner-receipt-pending\" end")
        if source.count(prepare_guard) != 1:
            raise RuntimeError("prepare guard mutation target changed")
        code, output = run("delayed", source.replace(prepare_guard,
            "    if false then\n"
            "        return false, \"selected-owner-receipt-pending\" end", 1))
        if code or "VALUE FAIL:selected proxy retired before its private owner reply" not in output:
            raise RuntimeError("prepare guard failed its source mutation: " + output)
        confirm_guard = ("    if selectedOwnerReceiptPending(brain, rec) then\n"
                         "        admitSelectedSourceSpawn(brain, rec)\n"
                         "        if selectedOwnerReceiptPending(brain, rec) then\n"
                         "            return nil, \"selected-owner-receipt-pending\" end\n"
                         "    end")
        if source.count(confirm_guard) != 1:
            raise RuntimeError("confirmation guard mutation target changed")
        code, output = run("inflight-upgrade", source.replace(confirm_guard,
            "    if false then\n"
            "        admitSelectedSourceSpawn(brain, rec)\n"
            "        if selectedOwnerReceiptPending(brain, rec) then\n"
            "            return nil, \"selected-owner-receipt-pending\" end\n"
            "    end", 1))
        if code or "VALUE FAIL:in-flight selected proxy removed before its owner receipt" not in output:
            raise RuntimeError("confirmation guard failed its source mutation: " + output)
        receipt["status"] = "PASS"
    current_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    receipt["sourceSha256After"] = current_hash
    if current_hash != receipt["sourceSha256"]:
        receipt["status"] = "SOURCE_MOVED"
    print(json.dumps(receipt, indent=2))
    return 0 if receipt["status"] == "PASS" else 2


if __name__ == "__main__":
    raise SystemExit(main())
