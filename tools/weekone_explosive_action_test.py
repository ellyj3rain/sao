#!/usr/bin/env python3
"""Check the bounded SAO Week One explosive action on installed Kahlua."""
from pathlib import Path
import hashlib
import json
import subprocess
import tempfile

from weekone_continuity_test import GAME, JDK, PRELUDE, ROOT, SOURCE

FIXTURE = r'''
__step='setup' __blast=0 __removed=0 __traps=0 __occupant=nil
__near=false __stale=false __foreign=false
local ordinaryZombie={zombie=true,getModData=function() return {} end,
 getVariableBoolean=function() return false end,
 isReanimatedPlayer=function() return false end}
local cell={}
function cell:getGridSquare(x,y,z)
 if __missingSquare and x==88 and y==80 then return nil end
 local square={x=x,y=y,z=z}
 square.getX=function(self) return self.x end
 square.getY=function(self) return self.y end
 square.getZ=function(self) return self.z end
 square.getCell=function() return cell end
 square.getMovingObjects=function()
  local occupants={}
  if x==89 and y==80 then occupants[#occupants+1]=ordinaryZombie end
  if not __secondMoved and x==90 and y==80 then
   occupants[#occupants+1]=ordinaryZombie end
  if __occupant and x==89 and y==80 then
   occupants[#occupants+1]=__occupant end
  return {size=function() return #occupants end,
    get=function(_,i) return occupants[i+1] end}
 end
 return square
end
instanceof=function(actor,name)
 return name=='IsoZombie' and actor.zombie==true end
isClient=function() return false end
IsoTrap={new=function(body,item,ownerCell,square)
 assert(item==body.item and ownerCell==cell and square.x==89)
 __traps=__traps+1
 return {getHandWeapon=function() return item end,
  place=function()
   if __failPlace then error('native-place-failed') end
   __blast=__blast+1 end}
end}
local item={kind='Base.PipeBomb',id=905}
item.getFullType=function(self) return self.kind end
item.getID=function(self) return self.id end
item.getExplosionRange=function() return 7 end
item.getMaxRange=function() return 10 end
item.isInstantExplosion=function() return true end
local inventory={item=item}
inventory.contains=function(self,chosen) return self.item==chosen end
inventory.Remove=function(self,chosen)
 if self.item==chosen then self.item=nil __removed=__removed+1 end end
local body=__body(905)
body.item=item body.zombie=true
body.getCell=function() return cell end
body.getInventory=function() return inventory end
body.getPrimaryHandItem=function(self) return self.item end
body.getSecondaryHandItem=function() return nil end
body.removeFromHands=function(self,chosen)
 if self.item==chosen then self.item=nil end end
local brain=__brain(905,'BanditsWeekOne')
brain.program={name='Active',stage='Main'}
__source=body
BanditBrain={Get=function(candidate) return candidate==body and brain end}
BanditZombie={GetInstanceById=function(id)
 return id==905 and body or nil end}
BanditUtils={GetMoveTask=function(_,x,y,z)
 return {action='Move',x=x,y=y,z=z} end}
Bandit={}
ZombieActions={}
SAO.Perception.observe=function(id,observed,tick)
 SAO.Perception.beliefs[id]={lastScanAt=tick,
  zombies={one={source='observed',at=tick,track='zombie-905',x=89,y=80,z=0},
   two={source='observed',at=tick,track='zombie-906',x=90,y=80,z=0}},
  people={}}
end
SAO.Perception.believedThreatCount=function() return 2 end
SAO.Disposition.conflictValues=function(id)
 return {actorId=id,selfPreservation=.2,aggression=.8,
   nerve=.8,discipline=.6}
end
SAOJavaBridge.weekOneObservedTarget=function(_,observed,kind,key)
 if observed~=body or kind~='zombie' or key~='zombie-905' then
  return 'REFUSED\tsight' end
 if __near then return 'TARGET\t84\t80\t0\t4' end
 if __stale then return 'REFUSED\tsight' end
 return 'TARGET\t89\t80\t0\t9'
end
function __fixture()
 local W=SAO.WeekOneContinuity
 assert(W.installRoleActions()==true)
 __step='ordinary-purpose'
 brain.program.name='Walker'
 local ordinary=W.ordinaryProgramStage(brain,body,'Walker','Main')
 local ordinaryPhase=SAO.Identity.get(body.md.SAOWeekOnePersonId).weekOne
 assert(ordinary and ordinary.tasks and ordinary.tasks[1]
  and ordinary.tasks[1].action=='SAOThrowExplosive'
  and ordinaryPhase.ordinary.purpose=='confront-observed-zombie-cluster'
  and ordinaryPhase.decision.purpose=='confront-observed-zombie-cluster',
  'zombie explosive was labeled as a hostile-player attack')
 brain.program.name='Active'
 __step='person-decision'
 local selected=W.activeDecision(brain,body)
 assert(selected and selected.tasks and #selected.tasks==1
  and selected.tasks[1].action=='SAOThrowExplosive',
  'fresh private person did not select the held physical explosive')
 local task=selected.tasks[1]
 local person=body.md.SAOWeekOnePersonId
 local phase=SAO.Identity.get(person).weekOne
 assert(phase.decision.kind=='attack'
  and phase.decision.attackMethod=='native-pipe-bomb'
  and task.saoItemId==905 and task.saoTargetKey=='zombie-905'
  and __blast==0 and __removed==0,
  'decision caused physical effect before action completion')
 local samePlan={kind='move',source='sao-observed',targetKind='zombie',
  actorId=person,brainId=905,born=12.5,atTick=100,observedAtTick=100}
 __step='source-name-neutral'
 brain.program.name='Walker'
 assert(W.explosiveTaskForObserved(brain,body,samePlan,phase),
  'source Shahid label became an explosive decision requirement')
 brain.program.name='Active'
 __step='single-threat-refusal'
 local beliefs=SAO.Perception.beliefs[person]
 local second=beliefs.zombies.two
 beliefs.zombies.two=nil
 assert(W.explosiveTaskForObserved(brain,body,samePlan,phase)==nil,
  'one zombie justified a wide explosive blast')
 beliefs.zombies.two=second
 __step='moved-cluster-refusal'
 __secondMoved=true
 assert(W.explosiveTaskForObserved(brain,body,samePlan,phase)==nil,
  'stale second zombie still justified a wide physical blast')
 __secondMoved=false
 __step='observed-bystander-refusal'
 beliefs.people.Someone={source='observed',at=100,x=89,y=81,z=0}
 assert(W.explosiveTaskForObserved(brain,body,samePlan,phase)==nil,
  'observed person inside blast radius was ignored')
 beliefs.people.Someone=nil
 __step='bystander-refusal'
 __occupant={zombie=false}
 local unsafe=W.explosiveTaskForObserved(brain,body,samePlan,phase)
 assert(unsafe==nil and __blast==0 and __removed==0,
  'human occupant did not stop blast')
 __step='source-human-proxy-refusal'
 __occupant={zombie=true,getModData=function() return {} end,
  getVariableBoolean=function(_,name) return name=='Bandit' end,
  isReanimatedPlayer=function() return false end}
 assert(W.explosiveTaskForObserved(brain,body,samePlan,phase)==nil,
  'human zombie-backed proxy was treated as an ordinary zombie')
 __occupant=nil
 __step='changed-target-refusal'
 __near=true
 local near=W.executeExplosiveTask(body,task)
 assert(near==false and inventory:contains(item) and __blast==0,
  'target moving into blast radius still consumed item')
 __near=false
 __step='item-identity-refusal'
 item.id=906
 local changed=W.executeExplosiveTask(body,task)
 assert(changed==false and inventory:contains(item) and __blast==0,
  'different held item inherited task authority')
 item.id=905
 __step='stale-refusal'
 __tick=120
 local stale=W.executeExplosiveTask(body,task)
 assert(stale==false and __blast==0 and inventory:contains(item),
  'stale private sight consumed item')
 __tick=100
 __step='native-completion'
 assert(W.executeExplosiveTask(body,task)==true
  and __removed==1 and __blast==1 and __traps==1
  and phase.explosiveUse.status=='native-trap-placed'
  and phase.explosiveUse.itemId==905,
  'one real item was not consumed into one native trap blast')
 __step='duplicate-refusal'
 assert(W.executeExplosiveTask(body,task)==false
  and __removed==1 and __blast==1 and __traps==1,
  'repeat task completed a second blast')
 __step='second-item-native-failure'
 local later={kind='Base.PipeBomb',id=907,
  getFullType=item.getFullType,getID=item.getID,
  getExplosionRange=item.getExplosionRange,
  getMaxRange=item.getMaxRange,isInstantExplosion=item.isInstantExplosion}
 body.item=later inventory.item=later
 local laterTask=W.explosiveTaskForObserved(brain,body,samePlan,phase)
 assert(laterTask and laterTask.saoItemId==907,
  'earlier use barred a different physical item')
 __failPlace=true
 local uncertain=W.executeExplosiveTask(body,laterTask)
 __failPlace=false
 assert(uncertain==false and __removed==2 and __blast==1
  and phase.explosiveUse.status=='native-call-uncertain'
  and phase.explosiveUses['905'].status=='native-trap-placed'
  and phase.explosiveUses['907'].status=='native-call-uncertain',
  'failed native call was reported as success or erased prior event')
 assert(W.executeExplosiveTask(body,laterTask)==false
  and __removed==2 and __blast==1,
  'uncertain native call replayed the same item')
 return 'PASS'
end
function __safe() local ok,result=pcall(__fixture)
 if ok then return result end
 return 'FAIL:'..tostring(__step)..':'..tostring(result) end
'''


def main() -> int:
    receipt = {"sourceSha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
               "gameJarSha256": hashlib.sha256((GAME / "projectzomboid.jar").read_bytes()).hexdigest()}
    weapon_script = GAME / "media/scripts/generated/items/weapon.txt"
    script = weapon_script.read_text(encoding="utf-8")
    pipe = script.split("    item PipeBomb\n", 1)[1].split(
        "    item PipeBombRemote\n", 1)[0]
    for property_line in ("ExplosionPower = 90,", "ExplosionRange = 7,",
                          "MaxRange = 10.0,", "PhysicsObject = Base.PipeBomb,"):
        if property_line not in pipe:
            raise RuntimeError("installed pipe bomb script drifted: " + property_line)
    receipt["weaponScriptSha256"] = hashlib.sha256(
        weapon_script.read_bytes()).hexdigest()
    api = subprocess.run([str(JDK / "javap.exe"), "-c", "-p",
        "-classpath", str(GAME / "projectzomboid.jar"),
        "zombie.iso.objects.IsoTrap"], capture_output=True,
        text=True, timeout=60)
    if api.returncode:
        raise RuntimeError(api.stderr)
    place = api.stdout.split("public void place();", 1)[1].split(
        "public void triggerExplosion(boolean);", 1)[0]
    trigger = api.stdout.split("public void triggerExplosion();", 1)[1].split(
        "public void playExplosionSound();", 1)[0]
    required = ("IsoTrap(zombie.characters.IsoGameCharacter, zombie.inventory.types.HandWeapon",
                "Method triggerExplosion:()V", "Method drawCircleExplosion:")
    if required[0] not in api.stdout or required[1] not in place \
            or required[2] not in trigger:
        raise RuntimeError("installed native trap blast contract drifted")
    receipt["nativeApi"] = {
        "constructor": "IsoGameCharacter, held HandWeapon, IsoCell, IsoGridSquare",
        "place": "instant item calls triggerExplosion",
        "trigger": "native drawCircleExplosion"}
    with tempfile.TemporaryDirectory(prefix="sao-weekone-explosive-") as temp:
        work = Path(temp)
        (work / "stdlib.lua").write_bytes((GAME / "stdlib.lua").read_bytes())
        built = subprocess.run([str(JDK / "javac.exe"), "-cp",
            str(GAME / "projectzomboid.jar"), "-d", str(work),
            str(ROOT / "tools/luacheck/LuaRun.java")],
            capture_output=True, text=True, timeout=120)
        if built.returncode:
            raise RuntimeError(built.stderr)
        (work / "prelude.lua").write_text(PRELUDE, encoding="utf-8")
        (work / "fixture.lua").write_text(FIXTURE, encoding="utf-8")
        source = SOURCE.read_text(encoding="utf-8")

        def run_case(name: str, candidate: str) -> tuple[int, str]:
            code = work / "SAO_WeekOneContinuity.lua"
            code.write_text(candidate, encoding="utf-8")
            run = subprocess.run([str(JDK / "java.exe"), "-cp",
                f"{GAME / 'projectzomboid.jar'};{work}", "LuaRun",
                str(work / "prelude.lua"), str(code), str(work / "fixture.lua"),
                "--", "__safe()"], cwd=work, capture_output=True,
                text=True, timeout=60)
            output = run.stdout + run.stderr
            receipt.setdefault("cases", []).append({"name": name,
                "exit": run.returncode, "output": output[-1300:]})
            return run.returncode, output

        code, output = run_case("person-item-native-blast", source)
        good = code == 0 and "VALUE PASS" in output
        inverses = {
            "bystander-blast-guard": (
                'if actor and not instanceof(actor, "IsoZombie") then',
                'if false then'),
            "exact-item-identity": (
                'itemId ~= task.saoItemId or radius ~= task.saoRadius',
                'false or radius ~= task.saoRadius'),
            "real-item-consumption": (
                'body:getInventory():Remove(item)',
                'do end'),
            "fresh-native-target": (
                'local target = nativeTarget(body, "zombie", phase.decision.targetKey)',
                'local target = { x = 89, y = 80, z = 0, dist = 9 }'),
            "physical-cluster": (
                'return ordinaryZombies >= 2',
                'return true'),
        }
        for name, (before, after) in inverses.items():
            if source.count(before) != 1:
                raise RuntimeError(f"{name}: mutation anchor drifted")
            code, result = run_case(name, source.replace(before, after, 1))
            good = good and code == 0 and "VALUE FAIL:" in result
        receipt["status"] = "PASS" if good else "FAIL"
    path = ROOT / "_scratch/d2-leisure-01/weekone21/explosive-action01.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(path)
    print(receipt["status"])
    if receipt["status"] != "PASS":
        print(json.dumps(receipt["cases"], indent=2))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
