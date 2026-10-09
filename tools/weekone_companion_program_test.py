#!/usr/bin/env python3
"""Installed Bandits Companion callbacks under Week One person authority."""
from pathlib import Path
import hashlib
import json
import subprocess
import tempfile

from weekone_active_program_test import PORTS
from weekone_continuity_test import GAME, JDK, PRELUDE, ROOT, SOURCE

WORKSHOP = Path(r"C:\Program Files (x86)\Steam\steamapps\workshop\content\108600")
PROGRAMS = {
    "ZPCompanion.lua": (WORKSHOP / "3268487204/mods/Bandits/42.20/media/lua/"
        "shared/ZombiePrograms/ZPCompanion.lua",
        "67e69aa75ceba6642c7484c50fe93ecc3186914a52382cb4cda34533bcc4cc57"),
    "ZPCompanionGuard.lua": (WORKSHOP / "3268487204/mods/Bandits/42.20/media/lua/"
        "shared/ZombiePrograms/ZPCompanionGuard.lua",
        "6a92d03b4c68cbc615231e7a9336a4adc175bc40f55e86cce971bd05e442fddf"),
    "ZPWalker.lua": (WORKSHOP / "3403180543/mods/BanditsWeekOne/42.20/"
        "media/lua/shared/ZombiePrograms/WeekOne/ZPWalker.lua",
        "ad6ff8a9d0d6b022d03324f7378d5f611b92af6d511fee5d06e1ff6ea7053bcd"),
}
MOVE_SOURCE = (WORKSHOP / "3268487204/mods/Bandits/42.20/media/lua/"
    "shared/BanditUtils.lua")
MOVE_SHA = "ab65995505dd93e1cd6be0d4f8cf0eda973736fbd30f68f62a0af9203038cf69"

FIXTURE = r'''
Events.OnGameBoot={callbacks={},Add=function(fn)
 local callbacks=Events.OnGameBoot.callbacks
 callbacks[#callbacks+1]=fn end,
 Remove=function(fn) local callbacks=Events.OnGameBoot.callbacks
  for i=#callbacks,1,-1 do
   if callbacks[i]==fn then table.remove(callbacks,i) end end end}
__sourceMasterCalls=0 __sourcePostCalls=0 __sourceGlobalCalls=0
__sourcePoseCalls=0 __speech={} __answers={} __standing=.2
__friendVisible=true __featureVisible=true
BanditPost={At=function() __sourcePostCalls=__sourcePostCalls+1 return nil end,
 GetClosestFree=function() error('source chose global guardpost') end}
BanditPlayer={GetMasterPlayer=function()
 __sourceMasterCalls=__sourceMasterCalls+1 return nil end}
Bandit.ForceStationary=function(body,value)
 __sourcePoseCalls=__sourcePoseCalls+1 end
BanditUtils.GetClosestZombieLocation=function()
 __sourceGlobalCalls=__sourceGlobalCalls+1 error('source global enemy') end
BanditUtils.GetClosestEnemyBanditLocation=function()
 __sourceGlobalCalls=__sourceGlobalCalls+1 error('source global enemy') end
BanditUtils.GetMoveTaskTarget=function()
 error('source master target selected') end
-- Mirrors the installed single-player GetMoveTask table fields. An owned
-- source motion can be replaced by accepted speech only for this exact shape.
BanditUtils.GetMoveTask=function(endurance,x,y,z,walkType,dist,closeSlow)
 return {action='Move',time=115,endurance=endurance,x=x,y=y,z=z,
  walkType=walkType,closeSlow=closeSlow} end
__road={getX=function() return 86 end,getY=function() return 80 end,
 getZ=function() return 0 end}
getCell=function() return {getGridSquare=function(self,x,y,z)
 if x==86 and y==80 and z==0 then return __road end end} end
SAOJavaBridge.weekOneObservedFeature=function(self,body,square,kind)
 return __featureVisible and square==__road and kind=='road' end
local originalTarget=SAOJavaBridge.weekOneObservedTarget
SAOJavaBridge.weekOneObservedTarget=function(self,body,kind,key)
 if kind=='person' and key=='Morgan Hill' then
  return __friendVisible and 'TARGET\t86\t80\t0\t6' or 'REFUSED\tsight' end
 return originalTarget(self,body,kind,key)
end
SAOJavaBridge.weekOneObservedAttacker=function(self,body,player,kind,name)
 return body and player==__player and kind=='person'
  and name=='Morgan Hill' end
SAOJavaBridge.weekOneCanHearPlayer=function(self,player,body,id,brainId,born)
 return player==__player and body.md.SAOWeekOneOrigin=='BanditsWeekOne'
  and body.md.SAOWeekOnePersonId==id
  and body.md.SAOWeekOneBrainId==brainId
  and body.md.SAOWeekOneBorn==born end
SAO.Standing.keyForObserved=function(name)
 return name=='Morgan Hill' and 'player:active' or 'known:'..name end
SAO.Standing.playerKey=function(player)
 return player==__player and 'player:active' or nil end
SAO.Standing.groupOf=function() return nil end
SAO.Standing.trust=function() return .8 end
SAO.Standing.companyStanding=function() return __standing end
SAO.Standing.isHostileTo=function() return false end
SAO.Disposition.conflictValues=function(id) return {actorId=id,
 selfPreservation=.2,aggression=.8,nerve=.7,discipline=.7} end
__player.Say=function(self,words) __speech[#__speech+1]=words end
__player.isDead=function() return false end
BanditBrain.Get=function(body) return __brains[body.id] end
function __actor(id,origin,program,stage)
 local brain=__brain(id,origin or 'BanditsWeekOne')
 brain.program={name=program or 'Companion',stage=stage or 'Prepare'}
 brain.tasks={}
 local body=__body(id)
 body.getCell=function() return getCell() end
 body.getForwardDirection=function() return {getX=function() return 1 end,
  getY=function() return 0 end} end
 body.addLineChatElement=function(self,text)
  __answers[#__answers+1]=text end
 __brains[id]=brain __bodies[id]=body
 return brain,body
end
'''

HOLD = r'''
__companionSource=ZombiePrograms.Companion
__guardSource=ZombiePrograms.CompanionGuard
__walkerSource=ZombiePrograms.Walker
ZombiePrograms.Companion=nil
ZombiePrograms.CompanionGuard=nil
ZombiePrograms.Walker=nil
'''

CASES = r'''
local W=SAO.WeekOneContinuity
__step='boot'
assert(ZombiePrograms.Companion==nil and W.onProgramsBoot,
 'source callback was not held until the boot retry')
ZombiePrograms.Companion=__companionSource
ZombiePrograms.CompanionGuard=__guardSource
ZombiePrograms.Walker=__walkerSource
W.onProgramsBoot()
local ready,count=W.installProgramAdapters()
assert(ready and count==7
 and W.programWrapped['Companion.Prepare']==ZombiePrograms.Companion.Prepare
 and W.programWrapped['Companion.Main']==ZombiePrograms.Companion.Main
 and W.programWrapped['Companion.Guard']==ZombiePrograms.Companion.Guard
 and W.programWrapped['CompanionGuard.Prepare']==ZombiePrograms.CompanionGuard.Prepare
 and W.programWrapped['CompanionGuard.Main']==ZombiePrograms.CompanionGuard.Main,
 'installed Companion callbacks did not attach on native boot retry')

__step='foreign'
local foreign,foreignBody=__actor(690,'Bandits2','Companion')
local sourcePrepare=ZombiePrograms.Companion.Prepare(foreignBody)
foreign.program.stage='Main'
local sourceMain=ZombiePrograms.Companion.Main(foreignBody)
assert(sourcePrepare.next=='Main' and sourceMain.tasks[1].anim=='Shrug'
 and __sourceMasterCalls==1 and __sourcePostCalls==1
 and foreignBody.md.SAOWeekOnePersonId==nil,
 'foreign Companion actor lost the original installed source path')
local foreignGuard,foreignGuardBody=__actor(691,'Bandits2','CompanionGuard')
local guardPrepare=ZombiePrograms.CompanionGuard.Prepare(foreignGuardBody)
foreignGuard.program.stage='Main'
local guardMain=ZombiePrograms.CompanionGuard.Main(foreignGuardBody)
assert(guardPrepare.next=='Main' and guardMain.next=='Prepare'
 and foreignGuard.program.name=='Companion',
 'foreign CompanionGuard actor lost the original installed source path')

__step='threat' __target='zombie' __threat=2 __tick=100
local brain,body=__actor(701,'BanditsWeekOne','Companion')
local prepared=ZombiePrograms.Companion.Prepare(body)
local person=body.md.SAOWeekOnePersonId
assert(prepared.next=='Main' and #prepared.tasks==0
 and person and __records[person].heldBy=='BanditsWeekOne'
 and __records[person].weekOne.chatCompanion==nil,
 'source Companion preparation created a relationship or bypassed person admission:'
 ..tostring(prepared.next)..':'..tostring(person)..':'
 ..tostring(person and __records[person].heldBy))
brain.program.stage='Main'
local moved=ZombiePrograms.Companion.Main(body)
if not moved.tasks[1] then
 local directly,why=W.ordinaryProgramStage(brain,body,'Companion','Main')
 error('threat adapter deferred: '..tostring(why)..' direct='..tostring(directly))
end
assert(moved.next=='Main' and moved.tasks[1].action=='Move'
 and moved.tasks[1].x==82
 and __records[person].weekOne.decision.adapter=='Companion.Main'
 and __sourceMasterCalls==2 and __sourcePostCalls==2
 and __sourceGlobalCalls==0,
 'stamped Companion selected a source master, post or global enemy:'
 ..tostring(moved.tasks[1].x)..':'
 ..tostring(__records[person].weekOne.decision.adapter)..':'
 ..tostring(__sourceMasterCalls)..':'..tostring(__sourcePostCalls)..':'
 ..tostring(__sourceGlobalCalls))

__step='ordinary' __target='none' __threat=0 __tick=121
local ordinary=ZombiePrograms.Companion.Main(body)
local phase=__records[person].weekOne
assert(ordinary.tasks[1].action=='Move' and ordinary.tasks[1].x==86
 and phase.ordinary.sourceProgram=='Companion'
 and phase.ordinary.role==nil and phase.chatCompanion==nil
 and brain.program.name=='Companion',
 'source Companion label became an SAO relationship or occupation')
__step='guard' __tick=142
local guard,guardBody=__actor(702,'BanditsWeekOne','CompanionGuard')
local preparedGuard=ZombiePrograms.CompanionGuard.Prepare(guardBody)
guard.program.stage='Main'
local guarded=ZombiePrograms.CompanionGuard.Main(guardBody)
local guardPerson=guardBody.md.SAOWeekOnePersonId
assert(preparedGuard.next=='Main' and guarded.tasks[1].action=='Move'
 and guarded.tasks[1].x==86 and __records[guardPerson].weekOne.ordinary.role==nil
 and __records[guardPerson].weekOne.ordinary.sourceProgram=='CompanionGuard'
 and __sourceMasterCalls==2 and __sourceGlobalCalls==0,
 'source guard callback retained automatic master or global target behavior')
__step='guard-stage' __tick=163
local guardStage,guardStageBody=__actor(703,'BanditsWeekOne','Companion','Guard')
local held=ZombiePrograms.Companion.Guard(guardStageBody)
assert(held.next=='Guard' and held.tasks[1].action=='Move'
 and __sourceGlobalCalls==0,
 'source Companion.Guard selected global targets')

__step='unseen-route' __featureVisible=false __tick=184
local unseen=ZombiePrograms.Companion.Main(body)
assert(unseen.tasks[1].action=='Time' and unseen.tasks[1].anim
 and __sourceMasterCalls==2 and __sourceGlobalCalls==0,
 'unseen route yielded a source master follow or invented destination')
__featureVisible=true
__tick=205
local disposable=ZombiePrograms.Companion.Main(body).tasks[1]
assert(disposable and disposable.action=='Move'
 and disposable.saoWeekOnePersonId==person
 and disposable.saoWeekOneBrainId==brain.id,
 'ordinary source motion was not attributed to the exact SAO person')
brain.tasks={disposable}
local priorQueue=brain.tasks
__step='low-standing'
local refused,reason=W.onSourceChat(brain,body,__player,'Follow me')
assert(refused and reason=='refused' and brain.program.name=='Companion'
 and brain.tasks==priorQueue and brain.tasks[1]==disposable
 and phase.chatCompanion==nil and brain.permanent~=true
 and brain.loyal~=true,
 'low Standing created an automatic source companion')
__step='accepted' __standing=.8
local accepted,answer=W.onSourceChat(brain,body,__player,'Follow me')
assert(accepted and answer=='accepted'
 and phase.chatCompanion.playerKey=='player:active'
 and phase.chatCompanion.source=='heard-player-request'
 and brain.program.name=='Walker' and brain.program.stage=='Prepare'
 and #brain.tasks==0 and brain.tasks~=priorQueue
 and brain.permanent~=true and brain.loyal~=true,
 'heard and Standing-accepted request did not become a person choice')
__step='follow' __tick=205
local walkerPrepare=ZombiePrograms.Walker.Prepare(body)
brain.program.stage='Main' __tick=226
local following=ZombiePrograms.Walker.Main(body)
assert(walkerPrepare.next=='Main'
 and following.tasks[1].action=='Move' and following.tasks[1].x==86
 and phase.decision.purpose=='follow-trusted-companion'
 and phase.companion.key=='player:active'
 and phase.companion.source=='private-sight-and-standing'
 and __sourceMasterCalls==2 and __sourceGlobalCalls==0,
 'accepted source actor did not act on private player sight and Standing')
__step='lost-sight' __friendVisible=false __tick=247
local unseenPlayer=ZombiePrograms.Walker.Main(body)
assert(unseenPlayer.tasks[1].action=='Time'
 and phase.decision.purpose=='no-observed-trusted-companion',
 'lost native player sight still yielded a follow move')
__friendVisible=true

__step='retire'
local retired,retiredBody=__actor(704,'BanditsWeekOne','CompanionGuard','Main')
local retireId=W.observeBrain(retired,retiredBody)
retired.permanent=true
local protected,why=W.prepareRetire(retired,retiredBody,__player)
assert(protected==false and why=='source-body-busy'
 and __records[retireId].weekOne.pending==nil,
 'protected source body retired without exact safe custody')
retired.permanent=nil
local pending,ticket=W.prepareRetire(retired,retiredBody,__player)
assert(pending==true and ticket.personId==retireId
 and __records[retireId].weekOne.status=='retirement-pending'
 and __records[retireId].heldBy=='BanditsWeekOne',
 'ordinary source actor failed exact off-camera handoff or released early')

__step='hook-conflict'
local wrapped=ZombiePrograms.Companion.Main
ZombiePrograms.Companion.Main=function() return nil end
local safe,conflict=W.installProgramAdapters()
assert(safe==false and conflict=='program-hook-changed:Companion.Main',
 'a foreign callback replacement silently displaced stamped SAO ownership')
ZombiePrograms.Companion.Main=wrapped
return 'PASS'
'''

CONTROLS = [
    ("companion-catalog", '"Companion",\n    "CompanionGuard"',
     '"CompanionGuard"', "installed Companion callbacks did not attach"),
    ("guard-catalog", '"CompanionGuard", "Entertainer"',
     '"Entertainer"', "installed Companion callbacks did not attach"),
    ("source-label", 'phase.ordinary = { sourceProgram = family, stage = stage,',
     'phase.ordinary = { role = family, sourceProgram = family, stage = stage,',
     "source Companion label became an SAO relationship or occupation"),
    ("private-stage", 'local plan, phase = acceptedStagePlan(brain, body)\n',
     'local plan, phase = nil, "forced-private-refusal"\n',
     "threat adapter deferred"),
    ("source-pass-through", 'return stageResult(stage)\n                            end\n                            return previous(body)\n',
     'return stageResult(stage)\n                            end\n                            return stageResult(stage)\n',
     "foreign Companion actor lost the original installed source path"),
    ("standing-refusal", 'or standing <= bar)',
     'or standing > bar)', "low Standing created an automatic source companion"),
    ("visible-companion", 'and seen.source == "observed" and seen.at == tick then',
     'and false then',
     "accepted source actor did not act on private player sight and Standing"),
]


def main() -> int:
    required = [SOURCE, GAME / "projectzomboid.jar", GAME / "stdlib.lua",
        JDK / "java.exe", JDK / "javac.exe", MOVE_SOURCE,
        *(row[0] for row in PROGRAMS.values())]
    if not all(path.is_file() for path in required):
        raise SystemExit("missing installed Kahlua, game or exact source program")
    pins = {name: hashlib.sha256(path.read_bytes()).hexdigest()
        for name, (path, _) in PROGRAMS.items()}
    for name, (_, expected) in PROGRAMS.items():
        if pins[name] != expected:
            raise RuntimeError(f"installed {name} drifted: {pins[name]}")
    move_pin = hashlib.sha256(MOVE_SOURCE.read_bytes()).hexdigest()
    if move_pin != MOVE_SHA:
        raise RuntimeError(f"installed BanditUtils.GetMoveTask source drifted: {move_pin}")
    source = SOURCE.read_text(encoding="utf-8")
    receipt = {"saoSourceSha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        "installedSourceSha256": pins, "moveSourceSha256": move_pin,
        "cases": []}
    with tempfile.TemporaryDirectory(prefix="sao-weekone-companion-") as temp:
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
        (work / "hold.lua").write_text(HOLD, encoding="utf-8")
        (work / "cases.lua").write_text("function __cases()\n" + CASES
            + "\nend\nfunction __safe() local ok,value=pcall(__cases)"
            + " if ok then return value end return 'FAIL:'..tostring(__step)..':'..tostring(value) end",
            encoding="utf-8")
        for name, (path, _) in PROGRAMS.items():
            (work / name).write_bytes(path.read_bytes())

        def run(name: str, current: str):
            (work / "sao.lua").write_text(current, encoding="utf-8")
            done = subprocess.run([str(JDK / "java.exe"), "-cp",
                f"{GAME / 'projectzomboid.jar'};{work}", "LuaRun",
                str(work / "prelude.lua"),
                *(str(work / item) for item in PROGRAMS),
                str(work / "hold.lua"), str(work / "sao.lua"),
                str(work / "cases.lua"), "--", "__safe()"], cwd=work,
                capture_output=True, text=True, timeout=60)
            output = done.stdout + done.stderr
            receipt["cases"].append({"name": name, "exit": done.returncode,
                "output": output[-1400:]})
            return done.returncode, output

        code, output = run("installed-source-and-private-adapter", source)
        if code or "VALUE PASS" not in output:
            chunks = [str(work / "prelude.lua"),
                *(str(work / item) for item in PROGRAMS),
                str(work / "hold.lua"), str(work / "sao.lua"),
                str(work / "cases.lua")]
            stages = []
            for index in range(1, len(chunks) + 1):
                loaded = subprocess.run([str(JDK / "java.exe"), "-cp",
                    f"{GAME / 'projectzomboid.jar'};{work}", "LuaRun",
                    *chunks[:index], "--", "true"], cwd=work,
                    capture_output=True, text=True, timeout=60)
                stages.append(f"{Path(chunks[index-1]).name}:"
                    f"{(loaded.stdout + loaded.stderr).strip()}")
                if loaded.returncode:
                    break
            raise RuntimeError("production companion adapter failed: "
                + output + " stages=" + " | ".join(stages))
        for name, before, after, expected in CONTROLS:
            if before not in source:
                raise RuntimeError("missing inverse target " + name)
            code, output = run(name, source.replace(before, after, 1))
            if "VALUE FAIL:" not in output or expected not in output:
                raise RuntimeError(name + " did not trip its contract: " + output)
        receipt["status"] = "PASS"
    out = ROOT / "_scratch/d2-leisure-01/weekone21/companion-program.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(f"PASS installed Week One Companion callbacks and {len(CONTROLS)} inverses")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
