#!/usr/bin/env python3
"""Exercise selected Week One source entry without inventing birth or Standing."""
from pathlib import Path
import hashlib
import json
import subprocess
import tempfile

from weekone_continuity_test import GAME, JDK, PRELUDE, ROOT, SOURCE


EXTRA = r'''
__relations={} __grants=0
__world={getWorld=function() return 'trial-world' end,
 getGameMode=function() return 'Sandbox' end}
getWorld=function() return __world end
__descriptor={getID=function() return 55 end,
 getForename=function() return 'Avery' end,
 getSurname=function() return 'Stone' end}
__player.data={}
__player.getModData=function(self) return self.data end
__player.getDescriptor=function() return __descriptor end
__player.isDead=function() return false end
SAO.Standing.playerAccountKey=function() return 'player:account' end
SAO.Identity.all=function() return __records end
SAO.Standing.playerKey=function(player)
 local receipt=player.data.SAOCreationReceipt
 return receipt and receipt.playerKey or 'player:account'
end
SAO.Standing.adjustTrust=function(id,key,delta)
 __grants=__grants+1
 local name=id..'|'..key
 __relations[name]=(__relations[name] or 0)+delta
 return __relations[name]
end
function __receipt(choice, newWorld)
 return {schema='sao-created-player/1',newWorld=newWorld~=false,
  weekOneStartBabe=choice,accountKey='player:account',
  playerKey='player:account/character/sao-player-1',
  nativeDescriptorId=55,world='trial-world',gameMode='Sandbox',
  forename='Avery',surname='Stone'}
end
function __entry(id)
 return {source='BWOEvents.Start/StartBabe',sourceProgram='Babe',
  program='Walker',accountKey='player:account',brainId=id,born=12.5,
  eventRef=string.format('%032x',id),
  nativeDescriptorId=55,forename='Avery',surname='Stone',
  world='trial-world',gameMode='Sandbox',selected=true,
  selectionSource='creator-receipt'}
end
function __entrant(id)
 local brain=__brain(id,'BanditsWeekOne')
 brain.program.name='Walker'
 brain.saoWeekOneStartEntry=__entry(id)
 return brain,__body(id)
end
function __owner(brain)
 local spawn=brain.saoWeekOneStartEntry
 return {source=spawn.source,eventRef=spawn.eventRef,
  brainId=spawn.brainId,born=spawn.born,
  accountKey='player:account',
  playerKey='player:account/character/sao-player-1',
  nativeDescriptorId=55,forename='Avery',surname='Stone',
  world='trial-world',gameMode='Sandbox'}
end
'''

CASES = r'''
local W=SAO.WeekOneContinuity
__step='before-creator-receipt'
local brain,body=__entrant(61)
local id=W.observeBrain(brain,body)
assert(id and __records[id].weekOne.sourceSpawn==nil and __grants==0,
 'source entry attached to an uncreated character')
__step='selected-entry-after-receipt'
__player.data.SAOCreationReceipt=__receipt(true)
W.onServerCommand('SAOWeekOne','OwnerReceipt',__owner(brain))
W.observeBrain(brain,body)
local entry=__records[id].weekOne.sourceSpawn
 assert(entry and entry.eventRef==brain.saoWeekOneStartEntry.eventRef
 and entry.playerKey==nil and entry.accountKey==nil
 and entry.nativeDescriptorId==nil and entry.world==nil
 and W.selectedStartProvenance(id).playerKey
  ==__player.data.SAOCreationReceipt.playerKey
 and entry.sourceProgram=='Babe' and entry.program=='Walker'
 and entry.brainId==61 and entry.born==12.5
 and entry.relationship==nil and entry.age==nil and entry.birth==nil
 and __grants==0 and brain.program.name=='Walker'
 and not __records[id].weekOne.chatCompanion
 and not __records[id].playerCompanionIntent
 and not __records[id].loyal and not __records[id].permanent,
 'source entry became an invented birth, role, or relationship')
__step='reload-idempotence'
W.observeBrain(brain,body)
assert(__records[id].weekOne.sourceSpawn==entry and __grants==0,
 'source entry was rewritten on repeated observation')
__step='source-flagged-retirement'
brain.permanent=true
local allowed,ticket=W.prepareRetire(brain,body,__player)
assert(allowed==true and ticket.personId==id
 and __records[id].weekOne.status=='retirement-pending',
 'selected source entry with old permanent flag was stranded')

__step='disabled-choice'
__player.data.SAOCreationReceipt=__receipt(false)
local disabled,disabledBody=__entrant(62)
W.onServerCommand('SAOWeekOne','OwnerReceipt',__owner(disabled))
local disabledId=W.observeBrain(disabled,disabledBody)
assert(disabledId and not __records[disabledId].weekOne.sourceSpawn
 and __grants==0,'disabled source encounter was adopted')
disabled.permanent=true
local refused,reason=W.prepareRetire(disabled,disabledBody,__player)
assert(refused==false and reason=='selected-owner-receipt-pending'
 and __records[disabledId].weekOne.pending==nil,
 'contradictory source selection retired without a selected owner')
disabled.saoWeekOneStartEntry.selected=false
local unselectedRetire,unselectedReason=W.prepareRetire(disabled,disabledBody,__player)
assert(unselectedRetire==false and unselectedReason=='source-body-busy',
 'unadmitted permanent Walker entered source-start retirement')
__step='unselected-source-marker'
__player.data.SAOCreationReceipt=__receipt(true)
local unselected,unselectedBody=__entrant(69)
unselected.saoWeekOneStartEntry.selected=false
W.onServerCommand('SAOWeekOne','OwnerReceipt',__owner(unselected))
local unselectedId=W.observeBrain(unselected,unselectedBody)
assert(unselectedId and not __records[unselectedId].weekOne.sourceSpawn
 and __grants==0,'unselected source marker became a selected encounter')
__step='existing-world'
__player.data.SAOCreationReceipt=__receipt(true,false)
local oldWorld,oldBody=__entrant(63)
W.onServerCommand('SAOWeekOne','OwnerReceipt',__owner(oldWorld))
local oldId=W.observeBrain(oldWorld,oldBody)
assert(oldId and not __records[oldId].weekOne.sourceSpawn
 and __grants==0,'existing world acquired a new-world encounter')
__player.data.SAOCreationReceipt=__receipt(true)

__step='wrong-native-character'
local other,otherBody=__entrant(64)
W.onServerCommand('SAOWeekOne','OwnerReceipt',__owner(other))
local savedDescriptor=__descriptor
__descriptor={getID=function() return 56 end,
 getForename=function() return 'Avery' end,
 getSurname=function() return 'Stone' end}
local otherId=W.observeBrain(other,otherBody)
__descriptor=savedDescriptor
assert(otherId and not __records[otherId].weekOne.sourceSpawn
 and __grants==0,'different native character inherited source entry')
__step='wrong-account'
local account,accountBody=__entrant(65)
W.onServerCommand('SAOWeekOne','OwnerReceipt',__owner(account))
local savedAccountKey=SAO.Standing.playerAccountKey
SAO.Standing.playerAccountKey=function() return 'player:other' end
local accountId=W.observeBrain(account,accountBody)
SAO.Standing.playerAccountKey=savedAccountKey
assert(accountId and not __records[accountId].weekOne.sourceSpawn
 and __grants==0,'different account inherited source entry')
__step='wrong-brain-generation'
local generation,generationBody=__entrant(66)
generation.saoWeekOneStartEntry.born=99
W.onServerCommand('SAOWeekOne','OwnerReceipt',__owner(generation))
local generationId=W.observeBrain(generation,generationBody)
assert(generationId and not __records[generationId].weekOne.sourceSpawn
 and __grants==0,'different source generation inherited entry')
__step='wrong-explicit-character'
local explicit,explicitBody=__entrant(67)
W.onServerCommand('SAOWeekOne','OwnerReceipt',__owner(explicit))
__player.data.SAOCreationReceipt.playerKey='player:account/character/sao-player-2'
local explicitId=W.observeBrain(explicit,explicitBody)
__player.data.SAOCreationReceipt=__receipt(true)
assert(explicitId and not __records[explicitId].weekOne.sourceSpawn
 and __grants==0,'different explicit character inherited source entry')
__step='preexisting-opinion'
__player.data.SAOCreationReceipt=nil
local late,lateBody=__entrant(68)
local lateId=W.observeBrain(late,lateBody)
__relations[lateId..'|player:account/character/sao-player-1']=-0.3
__player.data.SAOCreationReceipt=__receipt(true)
W.onServerCommand('SAOWeekOne','OwnerReceipt',__owner(late))
W.observeBrain(late,lateBody)
assert(__records[lateId].weekOne.sourceSpawn
 and __relations[lateId..'|player:account/character/sao-player-1']==-0.3
 and __grants==0,'source proximity overwrote a person\'s opinion')
__records['saved-old-owner']={weekOne={sourceSpawn={
 source='BWOEvents.Start/StartBabe',eventRef='00000000000000000000000000000068',
 accountKey='player:account',playerKey='private:old',nativeDescriptorId=55,
 forename='Avery',surname='Stone',world='trial-world',gameMode='Sandbox'}}}
for n=1,300 do
 __records['saved-batch-'..n]={weekOne={sourceSpawn={
  source='BWOEvents.Start/StartBabe',eventRef=string.format('%032x',n),
  accountKey='player:account',playerKey='private:old'}}}
end
W.rebindWorld()
local first=W.scrubLegacySourceOwners()
local second=W.scrubLegacySourceOwners()
local third=W.scrubLegacySourceOwners()
assert(first<=128 and second<=128 and third<=128
 and first+second+third==301
 and __records['saved-old-owner'].weekOne.sourceSpawn.eventRef
  =='00000000000000000000000000000068'
 and __records['saved-old-owner'].weekOne.sourceSpawn.accountKey==nil
 and __records['saved-old-owner'].weekOne.sourceSpawn.playerKey==nil
 and __records['saved-old-owner'].weekOne.sourceSpawn.nativeDescriptorId==nil
 and __records['saved-old-owner'].weekOne.sourceSpawn.world==nil
 and __records['saved-batch-300'].weekOne.sourceSpawn.accountKey==nil,
 'older saved person retained public selected-character keys')
return 'PASS'
'''

CONTROLS = [
    ("selected-source-marker", 'or brain.saoWeekOneStartEntry and spawn.selected ~= true',
     '', 'unselected source marker became a selected encounter'),
    ("choice", 'if not selected or selected.receipt.weekOneStartBabe ~= true then return end',
     'if not selected or false then return end',
     'disabled source encounter was adopted'),
    ("new-world", 'receipt.newWorld ~= true', 'false',
     'existing world acquired a new-world encounter'),
    ("native-character", 'owner.nativeDescriptorId ~= descriptorId', 'false',
     'different native character inherited source entry'),
    ("account", 'owner.accountKey ~= accountKey', 'false',
     'different account inherited source entry'),
    ("generation", 'or spawn.born ~= nil and spawn.born ~= brain.born', '',
     'different source generation inherited entry'),
    ("explicit-character", 'owner.playerKey ~= accountKey and owner.playerKey ~= playerKey',
     'false', 'different explicit character inherited source entry'),
    ("once", 'or rec.weekOne.sourceSpawn or rec.weekOne.babeBirth', '',
     'source entry was rewritten on repeated observation'),
    ("retirement", 'or selectedStampedSourceStart(brain, rec)', '',
     'selected source entry with old permanent flag was stranded'),
    ("no-trust-grant", '    rec.weekOne.sourceSpawn = {',
     '    SAO.Standing.adjustTrust(rec.id, selected.playerKey, 0.6)\n'
     '    rec.weekOne.sourceSpawn = {',
     'source entry became an invented birth, role, or relationship'),
    ("legacy-key-scrub", 'if scrubPublicSourceOwner(rec) then changed = changed + 1 end',
     'if false then changed = changed + 1 end',
     'older saved person retained public selected-character keys'),
]


def main() -> int:
    if not SOURCE.is_file() or not (GAME / "projectzomboid.jar").is_file():
        raise SystemExit("Week One source or installed engine unavailable")
    original = SOURCE.read_text(encoding="utf-8")
    receipt = {"sourceSha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
               "cases": []}
    with tempfile.TemporaryDirectory(prefix="sao-source-spawn-") as temp:
        work = Path(temp)
        (work / "stdlib.lua").write_bytes((GAME / "stdlib.lua").read_bytes())
        built = subprocess.run([str(JDK / "javac.exe"), "-cp",
            str(GAME / "projectzomboid.jar"), "-d", str(work),
            str(ROOT / "tools/luacheck/LuaRun.java")],
            capture_output=True, text=True, timeout=120)
        if built.returncode:
            raise RuntimeError(built.stderr)
        (work / "prelude.lua").write_text(PRELUDE + EXTRA, encoding="utf-8")
        (work / "cases.lua").write_text(
            "function __cases()\n" + CASES + "\nend\n"
            "function __safe() local ok,value=pcall(__cases) "
            "if ok then return value end "
            "return 'FAIL:'..tostring(__step)..':'..tostring(value) end",
            encoding="utf-8")

        def run(name: str, source: str):
            code = work / "SAO_WeekOneContinuity.lua"
            code.write_text(source, encoding="utf-8")
            done = subprocess.run([str(JDK / "java.exe"), "-cp",
                f"{GAME / 'projectzomboid.jar'};{work}", "LuaRun",
                str(work / "prelude.lua"), str(code), str(work / "cases.lua"),
                "--", "__safe()"], cwd=work, capture_output=True,
                text=True, timeout=60)
            output = done.stdout + done.stderr
            receipt["cases"].append({"name": name, "exit": done.returncode,
                                     "output": output[-1600:]})
            return done.returncode, output

        code, output = run("production", original)
        if code or "VALUE PASS" not in output:
            raise RuntimeError("production failed: " + output)
        for name, before, after, expected in CONTROLS:
            if before not in original:
                raise RuntimeError(f"missing control target {name}")
            code, output = run(name, original.replace(before, after, 1))
            if "VALUE FAIL:" not in output or expected not in output:
                raise RuntimeError(f"control {name} failed incorrectly: {output}")
        receipt["status"] = "PASS"
    out = ROOT / "_scratch/d2-leisure-01/weekone21/source-spawn-kahlua.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(f"PASS selected source spawn Kahlua and {len(CONTROLS)} defect inverses")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
