#!/usr/bin/env python3
"""P008 selected-character provenance survives a Week One source retirement."""

from pathlib import Path
import hashlib
import json
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
from weekone_continuity_test import GAME, JDK, PRELUDE, ROOT, SOURCE
from weekone_source_spawn_test import EXTRA


LUA = r'''
local W=SAO.WeekOneContinuity
local brain,body=__entrant(951)
brain.saoWeekOneStartEntry=nil
local event='000000000000000000000000000003b7'
brain.saoWeekOneScenarioBirth={kind='source-spawn-event',
 source='VBandit.setup/SpawnGroupArea',eventRef=event,
 variant='Bandits',variantId=1,ordinal=1,count=24,
 brainId=brain.id,born=brain.born}
__source=body
if __which~='saved-sandbox' and __which~='creator-after-source' then
 __player.data.SAOCreationReceipt=__receipt(true)
 __player.data.SAOCreationReceipt.weekOneVariant=1
end
local id=W.observeBrain(brain,body)
assert(id and __records[id].weekOne.sourceEvent
 and __records[id].weekOne.sourceEvent.eventRef==event
 and not __records[id].weekOne.sourceEvent.accountKey
 and not __records[id].weekOne.sourceEvent.playerKey
 and not __records[id].weekOne.sourceSpawn
 and __grants==0,'public event or private identity boundary failed')
local rec=__records[id]
local owner={source='VBandit.setup/SpawnGroupArea',eventRef=event,
 brainId=brain.id,born=brain.born,accountKey='player:account',
 playerKey=(__which=='saved-sandbox' or __which=='creator-after-source')
  and 'player:account'
  or 'player:account/character/sao-player-1',
 nativeDescriptorId=55,forename='Avery',surname='Stone',
 world='trial-world',gameMode='Sandbox'}
local function reply(value)
 W.onServerCommand('SAOWeekOne','OwnerReceipt',value)
end
local function assertPrivate(label)
 local provenance,reason=W.selectedScenarioProvenance(id)
 assert(provenance and provenance.personId==id
  and provenance.eventRef==event and provenance.brainId==brain.id
  and provenance.born==brain.born and provenance.variantId==1
  and provenance.ordinal==1 and provenance.nativeDescriptorId==55
  and provenance.playerKey==(__player.data.SAOCreationReceipt
   and __player.data.SAOCreationReceipt.playerKey or owner.playerKey)
  and not rec.weekOne.sourceEvent.accountKey
  and not rec.weekOne.sourceEvent.playerKey
  and not rec.weekOne.chatCompanion and not rec.playerCompanionIntent
  and not rec.weekOne.sourceSpawn and __grants==0,
  label..':'..tostring(reason))
end
local function retire()
 local accepted,ticket=W.prepareRetire(brain,body,__player)
 assert(accepted==true and ticket and ticket.personId==id,
  'independent scenario person could not prepare retirement')
 W.onServerCommand('SAOWeekOne','Prepared',
  {id=brain.id,born=brain.born,token=ticket.token,personId=id})
 local action,reason=W.confirmPreparedRetire(
  {id=brain.id,born=brain.born,token=ticket.token,personId=id},
  brain,body,__player)
 assert(action=='remove','source retirement refused:'..tostring(reason))
 __source=nil body.alive=false
 W.onServerCommand('SAOWeekOne','Retired',
  {id=brain.id,born=brain.born,token=ticket.token})
 W.poll()
 assert(rec.weekOne.status=='transferred' and __source==nil,
  'scenario person was not retained after source retirement')
end
if __which=='timely' then
 local pending,why=W.selectedScenarioProvenance(id)
 assert(pending==nil and why=='owner-receipt-pending'
  and __query and __query.args.eventRef==event,
  'lost reply query omitted exact event reference')
 reply(owner) assertPrivate('timely selected owner refused')
 retire() assertPrivate('timely owner lost after retirement')
elseif __which=='retired' then
 retire()
 local pending,why=W.selectedScenarioProvenance(id)
 assert(pending==nil and why=='owner-receipt-pending'
  and __query and __query.args.eventRef==event
  and __query.args.brainId==brain.id and __query.args.born==brain.born,
  'retired person could not request the save-local private owner')
 reply(owner) assertPrivate('retired private owner not recovered')
elseif __which=='saved-sandbox' then
 retire() reply(owner)
 assertPrivate('native selected character without SAO creator refused')
elseif __which=='creator-after-source' then
 reply(owner)
 __player.data.SAOCreationReceipt=__receipt(true)
 __player.data.SAOCreationReceipt.weekOneVariant=1
 local provenance,reason=W.selectedScenarioProvenance(id)
 assert(provenance and provenance.playerKey
  ==__player.data.SAOCreationReceipt.playerKey
  and owner.playerKey=='player:account' and __grants==0,
  'pre-creator owner did not join later exact character:'..tostring(reason))
 retire() assertPrivate('pre-creator owner lost after retirement')
elseif __which=='wrong-account' or __which=='wrong-generation'
 or __which=='wrong-event' then
 local wrong={}
 for k,v in pairs(owner) do wrong[k]=v end
 if __which=='wrong-account' then wrong.accountKey='player:other' end
 if __which=='wrong-generation' then wrong.born=brain.born+1 end
 if __which=='wrong-event' then
  wrong.eventRef='000000000000000000000000000003b8' end
 reply(wrong)
 local result=W.selectedScenarioProvenance(id)
 assert(result==nil and __grants==0,
  'wrong private owner admitted selected-character provenance')
 reply(owner) assertPrivate('valid reply after wrong one refused')
elseif __which=='wrong-variant' then
 reply(owner)
 __player.data.SAOCreationReceipt.weekOneVariant=2
 local result,why=W.selectedScenarioProvenance(id)
 assert(result==nil and why=='creator-choice-mismatch',
  'different selected variant inherited scenario provenance')
elseif __which=='wrong-character' then
 reply(owner)
 __descriptor={getID=function() return 56 end,
  getForename=function() return 'Avery' end,
  getSurname=function() return 'Stone' end}
 local result,why=W.selectedScenarioProvenance(id)
 assert(result==nil and why=='selected-character-mismatch',
  'different native descriptor inherited scenario provenance')
elseif __which=='tampered-public-person' then
 reply(owner)
 rec.weekOne.sourceEvent.brainId=brain.id+1
 local result,why=W.selectedScenarioProvenance(id)
 assert(result==nil and why=='scenario-event-unavailable',
  'public person event changed its source brain identity')
else error('unknown case') end
return 'PASS:'..__which
'''

CASES = ("timely", "retired", "saved-sandbox", "creator-after-source",
         "wrong-account",
         "wrong-generation", "wrong-event", "wrong-variant",
         "wrong-character", "tampered-public-person")


def main():
    source_bytes = SOURCE.read_bytes()
    source = source_bytes.decode("utf-8")
    receipt = {"schema": "sao.weekone-scenario-owner-test/1",
               "sourceSha256": hashlib.sha256(source_bytes).hexdigest(),
               "cases": []}
    with tempfile.TemporaryDirectory(prefix="sao-weekone-scenario-owner-") as t:
        work = Path(t)
        (work / "stdlib.lua").write_bytes((GAME / "stdlib.lua").read_bytes())
        built = subprocess.run([str(JDK / "javac.exe"), "-cp",
            str(GAME / "projectzomboid.jar"), "-d", str(work),
            str(ROOT / "tools/luacheck/LuaRun.java")],
            capture_output=True, text=True, timeout=120)
        if built.returncode:
            raise RuntimeError("Kahlua harness compile: " + built.stderr)
        (work / "prelude.lua").write_text(PRELUDE + EXTRA, encoding="utf-8")

        def run(name, candidate):
            (work / "source.lua").write_text(candidate, encoding="utf-8")
            (work / "case.lua").write_text("__which='" + name + "'\n"
                "function __safe() local ok,value=pcall(function()\n" + LUA +
                "\nend) if ok then return value end return 'FAIL:'..tostring(value) end",
                encoding="utf-8")
            p = subprocess.run([str(JDK / "java.exe"), "-cp",
                f"{GAME / 'projectzomboid.jar'};{work}", "LuaRun",
                str(work / "prelude.lua"), str(work / "source.lua"),
                str(work / "case.lua"), "--", "__safe()"], cwd=work,
                capture_output=True, text=True, timeout=60)
            out = p.stdout + p.stderr
            receipt["cases"].append({"name": name, "exitCode": p.returncode,
                                     "output": out[-1600:]})
            return p.returncode, out

        for name in CASES:
            code, out = run(name, source)
            if code or f"VALUE PASS:{name}" not in out:
                raise RuntimeError(name + " failed: " + out)
        mutations = (
            ("missing-query-ref", "retired",
             "brainId = spawn.brainId, born = spawn.born,\n"
             "            eventRef = spawn.eventRef",
             "brainId = spawn.brainId, born = spawn.born,\n"
             "            eventRef = nil",
             "retired person could not request the save-local private owner"),
            ("variant-bypass", "wrong-variant",
             "receipt.weekOneVariant ~= event.variantId", "false",
             "different selected variant inherited scenario provenance"),
            ("person-crosswalk-bypass", "tampered-public-person",
             "event.brainId ~= phase.brainId", "false",
             "public person event changed its source brain identity"),
            ("precreator-fallback-removed", "creator-after-source",
             "and owner.playerKey ~= accountKey then",
             "then", "pre-creator owner did not join later exact character"),
        )
        for label, case, needle, replacement, expected in mutations:
            if source.count(needle) != 1:
                raise RuntimeError(label + " mutation target changed")
            code, out = run(case, source.replace(needle, replacement, 1))
            if code or expected not in out:
                raise RuntimeError(label + " inverse not detected: " + out)
    receipt["status"] = "PASS"
    target = ROOT / "_scratch/d2-leisure-01/weekone21/scenario-owner-continuity.json"
    target.write_text(json.dumps(receipt, indent=2), encoding="utf-8")
    print("PASS", len(CASES), "cases, 4 inverses", target)


if __name__ == "__main__":
    main()
