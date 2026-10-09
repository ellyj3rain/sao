#!/usr/bin/env python3
"""Installed-Kahlua Week One hit evidence without source-directed explosion."""
from pathlib import Path
import hashlib
import json
import subprocess
import tempfile

from weekone_continuity_test import GAME, JDK, PRELUDE, ROOT, SOURCE
from weekone_active_program_test import PORTS

WORKSHOP = Path(r"C:\Program Files (x86)\Steam\steamapps\workshop\content\108600")
SHAHID = WORKSHOP / (
    "3403180543/mods/BanditsWeekOne/42.20/media/lua/shared/"
    "ZombiePrograms/WeekOne/ZPShahid.lua")
HIT_SOURCE = WORKSHOP / (
    "3403180543/mods/BanditsWeekOne/42.20/media/lua/client/BWOPlayer.lua")
PINS = {
    "ZPShahid.lua": "ac3bc3220afc0547c885f3171eee19eacfa3920e73b3e0529ff3b4d9eb6d868c",
    "BWOPlayer.lua": "f49dbd14d50617301f3c1d923e18441e3afad4cb29c1cfa73cadf852907fcbf5",
}

FIXTURE = r'''
__target='none' __threat=0 __tick=100 __explosions=0 __kills=0
__grants=0 __removes=0 __lastExplosion=nil
SAO.Disposition.conflictValues=function(id)
 return {actorId=id,selfPreservation=.1,aggression=1.0,
  nerve=.9,discipline=.2}
end
BWOEvents={Explode=function(params)
 __explosions=__explosions+1 __lastExplosion=params end}
function __inventory()
 local inventory={items={}}
 inventory.getItemFromType=function(self,kind)
  for _,item in ipairs(self.items) do
   if item:getFullType()==kind then return item end end
  return nil
 end
 inventory.AddItem=function(self,kind)
  local item={getFullType=function() return kind end}
  self.items[#self.items+1]=item __grants=__grants+1
  return item
 end
 inventory.contains=function(self,item)
  for _,held in ipairs(self.items) do if held==item then return true end end
  return false
 end
 inventory.Remove=function(self,item)
  for index,held in ipairs(self.items) do
   if held==item then table.remove(self.items,index)
    __removes=__removes+1 return end end
 end
 return inventory
end
function __shahid(id,origin,program)
 local brain=__brain(id,origin or 'BanditsWeekOne')
 brain.program={name=program or 'Shahid',stage='Main'}
 local body=__body(id)
 body.inventory=__inventory()
 body.getInventory=function(self) return self.inventory end
 body.Kill=function(self) __kills=__kills+1 self.alive=false end
 __brains[id]=brain __bodies[id]=body
 return brain,body
end
function __attacker(x,y,z,label)
 return {getX=function() return x end,getY=function() return y end,
  getZ=function() return z end,name=label or 'Morgan Hill'}
end
__observedAttacker=__attacker(83,80,0,'Morgan Hill')
SAOJavaBridge.weekOneObservedAttacker=function(self,observer,candidate,kind,key)
 return candidate==__observedAttacker and kind=='person' and key=='Morgan Hill'
end
'''

CASES = r'''
local W=SAO.WeekOneContinuity
local attacker=__observedAttacker
local function hasBomb(body)
 return body.inventory:getItemFromType('Base.PipeBomb')~=nil end
local function noForcedEffect()
 return __explosions==0 and __kills==0 and __removes==0 end

__step='admission' __tick=100
local legacyBrain,legacyBody=__shahid(800)
local legacyPerson=W.observeBrain(legacyBrain,legacyBody)
local legacy=__records[legacyPerson].weekOne
assert(legacyPerson and not hasBomb(legacyBody) and __grants==0
 and legacy.shahidKit==nil and noForcedEffect(),
 'source Shahid name granted a bomb at person admission')
legacy.shahidKit={itemType='Base.PipeBomb',source='historical-save'}
legacy.shahidDetonation={status='historical-save'}
assert(W.observeBrain(legacyBrain,legacyBody)==legacyPerson
 and __grants==0 and not hasBomb(legacyBody),
 'source Shahid name recreated a bomb on reobservation')
SAO.WeekOneContinuity=nil __reloadWeekOne() W=SAO.WeekOneContinuity
assert(W.observeBrain(legacyBrain,legacyBody)==legacyPerson
 and legacy.shahidKit.source=='historical-save'
 and legacy.shahidDetonation.status=='historical-save'
 and __grants==0 and not hasBomb(legacyBody),
 'historical save evidence changed or a source bomb appeared on reload')

__step='physical-hit' __tick=125
local brain,body=__shahid(801)
body.inventory:AddItem('Base.PipeBomb')
local grants=__grants
local weapon={getFullType=function() return 'Base.Bat' end}
local ok,reason=W.onShahidHit(brain,body,attacker,weapon)
local person=body.md.SAOWeekOnePersonId
local phase=__records[person].weekOne
local hit=phase.lastPhysicalHit
assert(ok and reason=='hit-recorded-no-action'
 and hit and hit.source=='native-OnHitZombie'
 and hit.transport=='BWOPlayer.onHitZombie'
 and hit.brainId==brain.id and hit.born==brain.born
 and hit.attacker and hit.attacker.kind=='person'
 and hit.attacker.key=='Morgan Hill'
 and hit.attacker.source=='private-scan-and-current-native-identity'
 and hit.privateScanAtTick==125 and hit.privateStatus=='identified'
 and hit.attackerPosition.x==83 and hit.body.x==80
 and hit.weaponType=='Base.Bat'
 and hit.carriedExplosive=='Base.PipeBomb'
 and hit.action=='none' and hit.actionReason=='no-sao-explosive-decision'
 and phase.decision==nil
 and hasBomb(body) and __grants==grants and noForcedEffect(),
 'physical hit created source-directed material, action, death or blast')

__step='same-person-evidence-other-source-label' __tick=150
local walker,walkerBody=__shahid(802,nil,'Walker')
walkerBody.inventory:AddItem('Base.PipeBomb')
local walkerGrants=__grants
local walkerOK=W.onShahidHit(walker,walkerBody,attacker,weapon)
local walkerRec=walkerBody.md.SAOWeekOnePersonId and __records[walkerBody.md.SAOWeekOnePersonId]
local walkerHit=walkerRec and walkerRec.weekOne.lastPhysicalHit
assert(walkerOK and walkerHit and walkerHit.attacker
 and walkerHit.attacker.key==hit.attacker.key
 and walkerHit.carriedExplosive==hit.carriedExplosive
 and walkerHit.action==hit.action
 and walkerHit.actionReason==hit.actionReason
 and hasBomb(walkerBody) and __grants==walkerGrants
 and noForcedEffect(),
 'source family changed equal person and material hit evidence')

__step='no-material' __tick=175
local empty,emptyBody=__shahid(803)
local emptyOK=W.onShahidHit(empty,emptyBody,attacker,nil)
local emptyHit=__records[emptyBody.md.SAOWeekOnePersonId].weekOne.lastPhysicalHit
assert(emptyOK and emptyHit and emptyHit.carriedExplosive==nil
 and emptyHit.action=='none' and __grants==walkerGrants
 and noForcedEffect(),
 'hit minted an explosive or action without physical material')

__step='unseen-attacker' __tick=200
local unseen,unseenBody=__shahid(804)
local strange=__attacker(83,80,0,'Unseen stranger')
local unseenOK=W.onShahidHit(unseen,unseenBody,strange,nil)
local unseenHit=__records[unseenBody.md.SAOWeekOnePersonId].weekOne.lastPhysicalHit
assert(unseenOK and unseenHit and unseenHit.attacker==nil
 and unseenHit.privateStatus=='attacker-unidentified'
 and unseenHit.attackerPosition.x==83 and noForcedEffect(),
 'unseen attacker inherited another person identity')

__step='personal-disposition' __tick=225
local values=SAO.Disposition.conflictValues
SAO.Disposition.conflictValues=function(id)
 return {actorId=id,selfPreservation=.01,aggression=1,
  nerve=1,discipline=.01} end
local eager,eagerBody=__shahid(805)
eagerBody.inventory:AddItem('Base.PipeBomb')
local eagerOK=W.onShahidHit(eager,eagerBody,attacker,nil)
SAO.Disposition.conflictValues=values
local eagerHit=__records[eagerBody.md.SAOWeekOnePersonId].weekOne.lastPhysicalHit
assert(eagerOK and eagerHit.action=='none'
 and hasBomb(eagerBody) and noForcedEffect(),
 'disposition and source hit fabricated an explosive intent')

__step='foreign' __tick=250
local foreign,foreignBody=__shahid(806,'Bandits2')
foreignBody.inventory:AddItem('Base.PipeBomb')
local foreignOK=W.onShahidHit(foreign,foreignBody,attacker,nil)
assert(foreignOK==false and foreignBody.md.SAOWeekOnePersonId==nil
 and hasBomb(foreignBody) and noForcedEffect(),
 'foreign source was admitted into SAO hit evidence or acted')

__step='wrong-body' __tick=275
local mismatch,mismatchBody=__shahid(807)
local wrong=__body(808)
wrong.inventory=mismatchBody.inventory
wrong.getInventory=function(self) return self.inventory end
local wrongOK=W.onShahidHit(mismatch,wrong,attacker,nil)
assert(wrongOK==false and wrong.md.SAOWeekOnePersonId==nil
 and noForcedEffect(),
 'mismatched physical body received another person hit')

__step='unverified-attacker' __tick=300
local nativeCheck=SAOJavaBridge.weekOneObservedAttacker
SAOJavaBridge.weekOneObservedAttacker=nil
local unverified,unverifiedBody=__shahid(809)
local unverifiedOK=W.onShahidHit(unverified,unverifiedBody,attacker,nil)
SAOJavaBridge.weekOneObservedAttacker=nativeCheck
local unverifiedHit=__records[unverifiedBody.md.SAOWeekOnePersonId].weekOne.lastPhysicalHit
assert(unverifiedOK and unverifiedHit.attacker==nil
 and unverifiedHit.privateStatus=='attacker-unidentified'
 and noForcedEffect(),
 'missing native identity was reported as a known attacker')

__step='private-scan-deferred' __tick=325
local assess=W.assessForBandit
W.assessForBandit=function() return nil,'private-scan-deferred' end
local deferred,deferredBody=__shahid(810)
local deferredOK=W.onShahidHit(deferred,deferredBody,attacker,nil)
W.assessForBandit=assess
local deferredHit=__records[deferredBody.md.SAOWeekOnePersonId].weekOne.lastPhysicalHit
assert(deferredOK and deferredHit.attacker==nil
 and deferredHit.privateStatus=='private-scan-deferred'
 and noForcedEffect(),
 'physical hit vanished when private scan was deferred')

__step='private-scan-exception' __tick=340
W.assessForBandit=function() error('synthetic-scan-error') end
local thrown,thrownBody=__shahid(812)
local thrownOK=W.onShahidHit(thrown,thrownBody,attacker,nil)
W.assessForBandit=assess
local thrownHit=__records[thrownBody.md.SAOWeekOnePersonId].weekOne.lastPhysicalHit
assert(thrownOK and thrownHit.attacker==nil
 and thrownHit.privateStatus=='private-scan-error'
 and noForcedEffect(),
 'private scan exception erased physical hit evidence')

__step='clock-refusal' __tick=350
local clock=__clock __clock=nil
local untimed,untimedBody=__shahid(811)
local untimedOK=W.onShahidHit(untimed,untimedBody,attacker,nil)
__clock=clock
assert(untimedOK==false and noForcedEffect(),
 'hit without a durable clock invented a timestamp')

__step='repeated-hit' __tick=375
local prior=phase.lastPhysicalHit
local repeatedOK=W.onShahidHit(brain,body,attacker,nil)
assert(repeatedOK and phase.lastPhysicalHit~=prior
 and phase.lastPhysicalHit.atTick==375
 and hasBomb(body) and noForcedEffect(),
 'repeated hit replayed an explosive action or lost event evidence')
'''

SPOOF = r'''
__step='same-coordinate-unseen' __tick=400
local stranger=__attacker(83,80,0,'different object')
local ok=W.onShahidHit(brain,body,stranger,nil)
local receipt=phase.lastPhysicalHit
assert(ok and receipt.attacker==nil
 and receipt.attackerPosition.x==83
 and receipt.action=='none' and noForcedEffect(),
 'same-coordinate stranger inherited observed attacker identity')
'''

CONTROLS = [
    ("source-name-gate",
     'if type(brain) ~= "table" or not currentBody(brain, body) then',
     'if type(brain) ~= "table" or not (brain.program and brain.program.name == "Shahid") or not currentBody(brain, body) then',
     "source family changed equal person and material hit evidence"),
    ("source-bomb-grant",
     '    phase.lastPhysicalHit = {',
     '    body:getInventory():AddItem("Base.PipeBomb")\n    phase.lastPhysicalHit = {',
     "physical hit created source-directed material, action, death or blast"),
    ("source-forced-effect",
     '    return true, "hit-recorded-no-action"',
     '    body:Kill(nil)\n    BWOEvents.Explode({ x = bx, y = by, z = bz })\n    return true, "hit-recorded-no-action"',
     "physical hit created source-directed material, action, death or blast"),
    ("native-attacker-identity",
     'return ok and same == true',
     'return true',
     "unseen attacker inherited another person identity"),
    ("physical-bomb-truth",
     'carriedExplosive = carriedItem(body, "Base.PipeBomb")',
     'carriedExplosive = true',
     "hit minted an explosive or action without physical material"),
    ("scan-exception-isolated",
     'local okScan, frame, appraisalReason = pcall(W.assessForBandit, brain, body)',
     'local okScan, frame, appraisalReason = true, W.assessForBandit(brain, body)',
     "private-scan-exception"),
    ("person-hit-receipt",
     '    phase.lastPhysicalHit = {',
     '    phase.discardedHit = {',
     "physical hit created source-directed material, action, death or blast"),
]


def main() -> int:
    paths = [SOURCE, SHAHID, HIT_SOURCE, GAME / "projectzomboid.jar",
             GAME / "stdlib.lua", JDK / "java.exe", JDK / "javac.exe"]
    if not all(path.is_file() for path in paths):
        raise SystemExit("missing installed Kahlua, source, or Week One Shahid file")
    observed = {path.name: hashlib.sha256(path.read_bytes()).hexdigest()
                for path in (SHAHID, HIT_SOURCE)}
    if observed != PINS:
        raise RuntimeError("installed Shahid source drifted: " + repr(observed))
    source = SOURCE.read_text(encoding="utf-8")
    receipt = {"saoSourceSha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
               "installedSources": observed, "cases": []}
    with tempfile.TemporaryDirectory(prefix="sao-weekone-shahid-") as temp:
        work = Path(temp)
        (work / "stdlib.lua").write_bytes((GAME / "stdlib.lua").read_bytes())
        built = subprocess.run([str(JDK / "javac.exe"), "-cp",
            str(GAME / "projectzomboid.jar"), "-d", str(work),
            str(ROOT / "tools/luacheck/LuaRun.java")],
            capture_output=True, text=True, timeout=120)
        if built.returncode:
            raise RuntimeError("LuaRun compile failed: " + built.stderr)
        (work / "prelude.lua").write_text(PRELUDE + PORTS + FIXTURE,
                                          encoding="utf-8")
        (work / "ZPShahid.lua").write_bytes(SHAHID.read_bytes())

        def run(name: str, current: str, extra: str = "") -> tuple[int, str]:
            (work / "sao.lua").write_text(current, encoding="utf-8")
            (work / "reload.lua").write_text(
                "function __reloadWeekOne()\n" + current + "\nend\n",
                encoding="utf-8")
            (work / "cases.lua").write_text(
                "function __cases()\n" + CASES + "\n" + extra
                + "\nreturn 'PASS'\nend\nfunction __safe() local ok,value=pcall(__cases)"
                + " if ok then return value end return 'FAIL:'..tostring(__step)..':'..tostring(value) end",
                encoding="utf-8")
            done = subprocess.run([str(JDK / "java.exe"), "-cp",
                f"{GAME / 'projectzomboid.jar'};{work}", "LuaRun",
                str(work / "prelude.lua"), str(work / "ZPShahid.lua"),
                str(work / "sao.lua"), str(work / "reload.lua"),
                str(work / "cases.lua"), "--", "__safe()"],
                cwd=work, capture_output=True, text=True, timeout=60)
            output = done.stdout + done.stderr
            receipt["cases"].append({"name": name, "exit": done.returncode,
                                      "output": output[-1600:]})
            return done.returncode, output

        code, output = run("material-private-hit", source)
        if code or "VALUE PASS" not in output:
            raise RuntimeError("hit-evidence production failed: " + output)
        code, output = run("same-coordinate-unseen-attacker", source, SPOOF)
        if code or "VALUE PASS" not in output:
            receipt["status"] = "FAIL"
            target = ROOT / "_scratch/d2-leisure-01/weekone21/shahid-event.json"
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
            raise RuntimeError("observed attacker identity failed: " + output)
        for name, before, after, expected in CONTROLS:
            if before not in source:
                raise RuntimeError("missing inverse target " + name)
            code, output = run(name, source.replace(before, after, 1))
            if "VALUE FAIL:" not in output or expected not in output:
                raise RuntimeError(name + " did not trip its contract: " + output)
        receipt["status"] = "PASS"
    target = ROOT / "_scratch/d2-leisure-01/weekone21/shahid-event.json"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(f"PASS installed Week One hit evidence and {len(CONTROLS)} inverses")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
