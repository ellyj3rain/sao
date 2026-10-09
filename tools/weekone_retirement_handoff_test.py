#!/usr/bin/env python3
"""Exact Week One chat handoff into the ordinary SAO person and controller."""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess
import tempfile

from weekone_continuity_test import GAME, JDK, PRELUDE, ROOT, SOURCE
from weekone_chat_continuity_test import FIXTURE as CHAT_FIXTURE

CONTROLLER = ROOT / "mod/42.20/media/lua/client/SAO_Controller.lua"
HARNESS = ROOT / "mod/42.20/media/lua/client/SAO_Harness.lua"

EXTRA = r'''
__player.getZ=function() return 0 end
SAO.Log={line=function() end}
SAO.Needs={}
SAO.Disposition.describe=function() return 'ordinary person' end
SAO.History.countyHours=function() return __clock end
SAO.Perception.beliefs={}
SAO.Command={order=function() return 'complies' end}
SAO.Voice={answer=function() end}
playerKeyOf=function(player) return SAO.Standing.playerKey(player) end
log=function() end
'''

CASES = r'''
local W=SAO.WeekOneContinuity
local Ctl=SAO.Controller
local function retire(id, mode, legacyBabe)
 local prior=ModData.getOrCreate('SurvivorAwareness_WeekOneContinuity')
  .weekOneTransitionClock
 -- Later cases keep the same saved world's native hour at the boundary.
 -- The source scheduler may be one update behind while a new receipt lands.
 if prior and prior.legacyAgeHours>=170 then
  __calendar={day=7,hour=2,month=0,year=1993}
 end
 BWOScheduler.WorldAge=169
 local brain,body=__actor(id)
 local personId=W.observeBrain(brain,body)
 -- This fixture exercises an existing save's recorded source timing. New
 -- native-default people are covered by the continuity transfer proof.
 __records[personId].weekOne.bodyMode='legacy-source'
 local joined,answer=W.onSourceChat(brain,body,__player,'Follow me')
 assert(joined and answer=='accepted','source company was not accepted')
 if mode=='hold' then
  local held,verdict=W.onSourceChat(brain,body,__player,'Stay here')
  assert(held and verdict=='accepted','source hold was not accepted')
 elseif mode=='home' then
  local home,verdict=W.onSourceChat(brain,body,__player,'Go home')
  assert(home and verdict=='accepted','source home was not accepted')
 elseif mode=='leave' then
  local left,verdict=W.onSourceChat(brain,body,__player,'Go away')
  assert(left and verdict=='accepted','source leave was not accepted')
 end
 if legacyBabe then
  brain.occupation='Babe' brain.permanent=true brain.loyal=true
  brain.program={name='Babe',stage='Main'}
 end
 local accepted,ticket=W.prepareRetire(brain,body,__player)
 assert(accepted and ticket.personId==personId,
  'off-camera source body did not prepare exact retirement')
 local rec=__records[personId]
 assert(rec.heldBy=='BanditsWeekOne' and rec.playerCompanionIntent==nil
  and rec.weekOne.retirementOffCamera==true,
  'source chat became ordinary intent before retirement')
 __removeWithProof(W,ticket,brain,body)
 __bodies[id]=nil
 W.onServerCommand('SAOWeekOne','Retired',
  {id=id,born=brain.born,token=ticket.token,personId=personId})
 W.poll()
 assert(rec.weekOne.status=='dormant' and rec.heldBy=='BanditsWeekOne'
  and rec.playerCompanionIntent==nil,
  'server removal prematurely released source ownership or chat')
 return rec,brain,body
end

__step='nearby-distance-order'
local near={}
for i,x in ipairs({9,2,5}) do
 local brain,body=__actor(700+i)
 body.x=x body.y=0
 local personId=W.observeBrain(brain,body)
 near[i]={id=personId,brain=brain,body=body}
 BanditZombie.CacheLightB[brain.id]={brain=brain}
end
local ids,omitted=W.loadedPersonIdsNear(__player,10,2)
assert(#ids==2 and ids[1]==near[2].id and ids[2]==near[3].id
 and omitted==1,'nearby cache cap hid a nearer exact person')
local none,allOmitted=W.loadedPersonIdsNear(__player,10,0)
assert(#none==0 and allOmitted==3,'zero output cap hid omitted person count')
near[2].body.md.SAOWeekOneBorn=-1
ids,omitted=W.loadedPersonIdsNear(__player,10,2)
assert(#ids==2 and ids[1]==near[3].id and ids[2]==near[1].id
 and omitted==0,'wrong marker entered nearby common projection')
near[2].body.md.SAOWeekOneBorn=near[2].brain.born
near[1].body.z=1
ids,omitted=W.loadedPersonIdsNear(__player,10,2)
assert(#ids==2 and ids[1]==near[2].id and ids[2]==near[3].id
 and omitted==0,'different floor entered nearby common projection')
BanditZombie.CacheLightB={}

__step='source-envelope'
local originBody=near[2].body local originBrain=near[2].brain
local before=#__spoken
local received,reply=W.onSourceChat(originBrain,originBody,__player,
 'Hello',false,{source='Mousecat-native-speech',inputMode='typed',
  correlationId='native-speech-retirement-1'})
local speech=__records[near[2].id].weekOne.lastSpeech
assert(received and reply=='answered' and #__spoken==before+1
 and speech.source=='Mousecat-native-speech' and speech.inputMode=='typed'
 and speech.correlationId=='native-speech-retirement-1',
 'Mousecat source envelope failed to preserve one true speech origin')
before=#__spoken
local rejected,why=W.onSourceChat(originBrain,originBody,__player,
 'Hello',false,{source='Mousecat-native-speech',inputMode='typed',
  correlationId='forged'})
assert(rejected==false and why=='invalid-source-envelope'
 and #__spoken==before,'malformed source envelope emitted speech')

__step='follow-pending-reload'
local unproven=retire(800,'follow')
SAO.WeekOneContinuity=nil __reloadWeekOne() W=SAO.WeekOneContinuity
assert(unproven.playerCompanionIntent==nil and unproven.heldBy=='BanditsWeekOne',
 'reload invented an early ordinary companion')
BWOScheduler.WorldAge=170 W.poll()
assert(unproven.weekOne.status=='dormant'
 and unproven.heldBy=='BanditsWeekOne'
 and unproven.playerCompanionIntent==nil,
 'reload without native physical witness carried a source relationship')
local follow=retire(801,'follow')
BWOScheduler.WorldAge=170 W.poll()
local intent=follow.playerCompanionIntent
assert(follow.weekOne.status=='transferred' and follow.heldBy==nil
 and intent and intent.playerKey=='player:active' and intent.mode=='follow'
 and intent.origin=='week-one-heard-player-request'
 and follow.weekOne.chatHandoff.status=='carried'
 and not follow.permanent and not follow.loyal and not __groups[follow.id],
 'actual release failed to carry accepted person relationship cleanly')
assert(W.validTransferredCompanion(follow,__player)==intent,
 'current player and Standing did not validate carried relationship')

__step='controller-adopt'
local agent={rec=follow,state='IDLE'}
local valid,mode=Ctl.reconcileWeekOneCompanion(follow,agent,__player)
assert(valid and mode=='follow' and agent.weekOneHandoff.intent==intent
 and not agent.companioning and not agent.holdPosition,
 'controller forced follower loyalty without current observation')
Ctl.agents[follow.id]=nil
assert(Ctl.adopt(follow) and Ctl.agents[follow.id].weekOneHandoff.intent==intent
 and not Ctl.agents[follow.id].companioning,
 'controller adoption lost durable Week One person intent')

__step='current-identity-inverse'
local originalKey=SAO.Standing.playerKey
SAO.Standing.playerKey=function() return 'player:another-character' end
assert(W.validTransferredCompanion(follow,__player)==nil,
 'old character chat bound a different current character')
local active=Ctl.agents[follow.id]
assert(Ctl.reconcileWeekOneCompanion(follow,active,__player)==false
 and active.weekOneHandoff==nil and not active.companioning,
 'old character companion remained active after identity change')
SAO.Standing.playerKey=originalKey

__step='standing-inverses'
__standing=.1
assert(W.validTransferredCompanion(follow,__player)==nil,
 'fallen company standing retained transferred authority')
__standing=.8 __hostile=true
assert(W.validTransferredCompanion(follow,__player)==nil,
 'hostile person retained transferred company')
__hostile=false __groups[follow.id]='other-group'
assert(W.validTransferredCompanion(follow,__player)==nil,
 'grouped person retained automatic player company')
__groups[follow.id]=nil

__step='hold-handoff'
local held=retire(802,'hold')
BWOScheduler.WorldAge=170 W.poll()
local holdAgent={rec=held,state='IDLE'}
local holdValid,holdMode=Ctl.reconcileWeekOneCompanion(held,holdAgent,__player)
assert(holdValid and holdMode=='hold' and holdAgent.holdPosition==true
 and holdAgent.weekOneHold==true and not holdAgent.companioning,
 'accepted hold failed to reach ordinary controller without forced loyalty')
__standing=.1
assert(Ctl.reconcileWeekOneCompanion(held,holdAgent,__player)==false
 and holdAgent.holdPosition==nil and holdAgent.weekOneHandoff==nil,
 'invalid Standing retained transferred hold')
__standing=.8
Ctl.agents[held.id]=holdAgent
assert(Ctl.noteWeekOneCompanionOrder(held.id,'player:active','close')
 and held.playerCompanionIntent.mode=='follow' and not holdAgent.holdPosition,
 'accepted ordinary follow could not supersede Week One hold')
Ctl.agents[held.id]=nil Ctl.adopt(held)
assert(not Ctl.agents[held.id].holdPosition
 and Ctl.agents[held.id].weekOneHandoff.mode=='follow',
 'reload resurrected a superseded Week One hold')

__step='native-menu-judgment'
local menuCalls=0
SAO.Command.order=function() error('judgment unavailable') end
local thrown=__onYourWord(__player,held.id,'hold',nil,function()
 menuCalls=menuCalls+1 end,true)
assert(thrown==false and menuCalls==0
 and held.playerCompanionIntent.mode=='follow',
 'thrown Command.order actuated an unearned companion instruction')
SAO.Command.order=function() return 'deferred' end
local unknown=__onYourWord(__player,held.id,'hold',nil,function()
 menuCalls=menuCalls+1 end,true)
assert(unknown==false and menuCalls==0
 and held.playerCompanionIntent.mode=='follow',
 'unknown Command.order verdict actuated companion instruction')
SAO.Command.order=function() return 'complies' end
local acceptedMenu=__onYourWord(__player,held.id,'hold',nil,function(orderKey)
 menuCalls=menuCalls+1
 Ctl.noteWeekOneCompanionOrder(held.id,orderKey,'hold')
end,true)
assert(acceptedMenu==true and menuCalls==1
 and held.playerCompanionIntent.mode=='hold',
 'accepted native menu judgment did not persist one exact instruction')

__step='home-handoff'
local unrouteable=retire(803,'home')
BWOScheduler.WorldAge=170 W.poll()
assert(unrouteable.playerCompanionIntent==nil
 and unrouteable.weekOne.chatHandoff.status=='refused'
 and unrouteable.weekOne.chatHandoff.reason=='ordinary-home-unavailable',
 'unknown home became a permanent ordinary instruction')
Ctl.agents[unrouteable.id]=nil Ctl.adopt(unrouteable)
assert(Ctl.agents[unrouteable.id].weekOneHandoff==nil,
 'reload resurrected an unrouteable home instruction')
local home=retire(808,'home')
home.homeX=30 home.homeY=40 home.homeZ=0
BWOScheduler.WorldAge=170 W.poll()
local homeAgent={rec=home,state='IDLE'}
local homeValid,homeMode=Ctl.reconcileWeekOneCompanion(home,homeAgent,__player)
assert(homeValid and homeMode=='home' and homeAgent.weekOneHomeIntent==true
 and homeAgent.companioning==nil and home.homeX==30,
 'known home intent failed to carry without forcing follower')
home.playerCompanionIntent.homeArrivedAtHours=__clock
assert(W.validTransferredCompanion(home,__player)==nil,
 'completed home trip kept an active source instruction')
assert(Ctl.reconcileWeekOneCompanion(home,homeAgent,__player)==false
 and homeAgent.weekOneHandoff==nil and homeAgent.weekOneHomeIntent==nil
 and home.playerCompanionIntent.mode=='home',
 'completed home trip blocked later ordinary standing choice')
Ctl.agents[home.id]=nil Ctl.adopt(home)
assert(Ctl.agents[home.id].weekOneHandoff==nil
 and Ctl.agents[home.id].weekOneHomeIntent==nil,
 'reload resurrected completed home instruction')

__step='legacy-babe-retirement'
local legacy=retire(809,'follow',true)
BWOScheduler.WorldAge=170 W.poll()
assert(legacy.weekOne.status=='transferred'
 and legacy.playerCompanionIntent
 and legacy.playerCompanionIntent.mode=='follow'
 and not legacy.permanent and not legacy.loyal,
 'exact older Babe flags prevented witnessed off-camera handoff')
BWOScheduler.WorldAge=169
local oldBrain,oldBody=__actor(811)
oldBrain.occupation='Babe' oldBrain.program={name='Babe',stage='Main'}
oldBrain.permanent=true oldBrain.loyal=true
local oldId=W.observeBrain(oldBrain,oldBody)
local oldAllowed,oldTicket=W.prepareRetire(oldBrain,oldBody,__player)
assert(oldAllowed and oldTicket.personId==oldId,
 'older source companion without new chat could not retire')
__removeWithProof(W,oldTicket,oldBrain,oldBody)
__bodies[oldBrain.id]=nil
W.onServerCommand('SAOWeekOne','Retired',
 {id=oldBrain.id,born=oldBrain.born,token=oldTicket.token,
  personId=oldId})
W.poll() BWOScheduler.WorldAge=170 W.poll()
assert(__records[oldId].weekOne.status=='transferred'
 and __records[oldId].playerCompanionIntent==nil,
 'legacy source flags fabricated accepted ordinary loyalty')
local wrongBrain,wrongBody=__actor(810)
wrongBrain.occupation='Babe' wrongBrain.permanent=true
wrongBrain.loyal=true
assert(W.prepareRetire(wrongBrain,wrongBody,__player)==false,
 'unrelated permanent source program bypassed retirement guard')

__step='leave-and-current-player-at-release'
local left=retire(804,'leave')
BWOScheduler.WorldAge=170 W.poll()
assert(left.playerCompanionIntent==nil and left.weekOne.chatHandoff==nil,
 'source leave resurrected a companion at retirement')
local different=retire(805,'follow')
SAO.Standing.playerKey=function() return 'player:another-character' end
BWOScheduler.WorldAge=170 W.poll()
assert(different.weekOne.status=='transferred' and different.heldBy==nil
 and different.playerCompanionIntent==nil
 and different.weekOne.chatHandoff.reason=='current-player-mismatch',
 'different current player inherited source chat')
SAO.Standing.playerKey=originalKey

__step='off-camera-proof-and-standing-at-release'
local old=retire(806,'follow')
old.weekOne.retirementOffCamera=nil
BWOScheduler.WorldAge=170 W.poll()
assert(old.weekOne.status=='dormant' and old.heldBy=='BanditsWeekOne'
 and old.playerCompanionIntent==nil and old.weekOne.chatHandoff==nil
 and ModData.getOrCreate('SurvivorAwareness_WeekOneContinuity')
  .lastHandoffRefusal=='retirement-evidence-missing',
 'old save without off-camera proof released the source body or gained intent')
local drifted=retire(807,'follow')
__hostile=true
BWOScheduler.WorldAge=170 W.poll()
assert(drifted.playerCompanionIntent==nil
 and drifted.weekOne.chatHandoff.reason=='current-standing-refused',
 'hostility drift between chat and retirement created ordinary companion')
__hostile=false
return 'PASS'
'''

CONTROLS = [
    ("week-boundary", "weekone", "transitionFact.legacyAgeHours >= 170",
     "transitionFact.legacyAgeHours >= 169",
     "server removal prematurely released source ownership or chat"),
    ("current-character", "weekone", "or not playerKey or playerKey ~= accepted.playerKey then",
     "or false then", "different current player inherited source chat"),
    ("standing-at-release", "weekone", "if not currentChatStanding(rec, playerKey) then",
     "if false then", "hostility drift between chat and retirement created ordinary companion"),
    ("off-camera-proof", "weekone",
     "or phase.pending or phase.stageToken\n        or phase.retirementOffCamera ~= true",
     "or phase.pending or phase.stageToken\n        or false",
     "old save without off-camera proof released the source body or gained intent"),
    ("unknown-home", "weekone",
     'if phase.chatMode == "home"\n        and (not finite(rec.homeX) or not finite(rec.homeY)) then',
     'if false then', "unknown home became a permanent ordinary instruction"),
    ("nearest-first", "weekone", "if a.dist2 ~= b.dist2 then return a.dist2 < b.dist2 end",
     "if a.dist2 ~= b.dist2 then return a.dist2 > b.dist2 end",
     "nearby cache cap hid a nearer exact person"),
    ("controller-hold", "controller", 'if intent.mode == "hold" then',
     'if false then',
     "accepted hold failed to reach ordinary controller without forced loyalty"),
    ("completed-home", "weekone",
     'or intent.mode == "home" and finite(intent.homeArrivedAtHours)',
     'or false', "completed home trip kept an active source instruction"),
    ("legacy-babe-shape", "weekone",
     'and brain.loyal == true and brain.occupation == "Babe"',
     'and brain.loyal == false and brain.occupation == "Babe"',
     "off-camera source body did not prepare exact retirement"),
    ("native-menu-judgment", "harness",
     'if requireAccepted and (not judged or not key',
     'if false and (not judged or not key',
     "thrown Command.order actuated an unearned companion instruction"),
]


def menu_hooks_exact(harness: str) -> bool:
    start = harness.find("-- Companion orders ([A24])")
    end = harness.find("-- [C20] Verb parity", start)
    if start < 0 or end < 0:
        return False
    block = harness[start:end]
    if block.count("end, true)") != 4:
        return False
    if block.count("SAO.Controller.noteWeekOneCompanionOrder(") != 4:
        return False
    for kind in ("hold", "close", "walk", "home"):
        if f'orderKey, "{kind}")' not in block:
            return False
    home = block[block.find('sub:addOption("go back to your own place"'):]
    return ("if SAO.Controller.orderTravel(nearId," in home
            and home.find("if SAO.Controller.orderTravel(nearId,")
                < home.find('orderKey, "home")'))


def menu_helper(harness: str) -> str:
    start = harness.find("local function onYourWord(")
    end = harness.find("\nend\n\n-- [C7]", start)
    if start < 0 or end < 0:
        raise RuntimeError("native menu judgment helper moved")
    return harness[start:end + 4].replace(
        "local function onYourWord(", "function __onYourWord(", 1)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path,
        default=ROOT / "_scratch/d2-leisure-01/weekone21/retirement-handoff.json")
    out = parser.parse_args().out.resolve()
    paths = [SOURCE, CONTROLLER, HARNESS, GAME / "projectzomboid.jar",
             GAME / "stdlib.lua", JDK / "java.exe", JDK / "javac.exe"]
    if not all(path.is_file() for path in paths):
        raise SystemExit("missing source or installed engine for Week One handoff")
    source = SOURCE.read_text(encoding="utf-8")
    controller = CONTROLLER.read_text(encoding="utf-8")
    harness = HARNESS.read_text(encoding="utf-8")
    if not menu_hooks_exact(harness):
        raise RuntimeError("native companion menu hooks lost exact accepted scope")
    if menu_hooks_exact(harness.replace('orderKey, "hold")',
                                        'orderKey, "unearned")', 1)):
        raise RuntimeError("native menu hook inverse escaped exact scope")
    receipt = {"saoWeekOneSha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
               "testSha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
               "saoControllerSha256": hashlib.sha256(CONTROLLER.read_bytes()).hexdigest(),
               "saoHarnessSha256": hashlib.sha256(HARNESS.read_bytes()).hexdigest(),
               "cases": []}
    with tempfile.TemporaryDirectory(prefix="sao-weekone-retirement-") as temp:
        work = Path(temp)
        (work / "stdlib.lua").write_bytes((GAME / "stdlib.lua").read_bytes())
        built = subprocess.run([str(JDK / "javac.exe"), "-cp",
            str(GAME / "projectzomboid.jar"), "-d", str(work),
            str(ROOT / "tools/luacheck/LuaRun.java")],
            capture_output=True, text=True, timeout=120)
        if built.returncode:
            raise RuntimeError("LuaRun compile failed: " + built.stderr)
        (work / "prelude.lua").write_text(PRELUDE + CHAT_FIXTURE + EXTRA,
                                           encoding="utf-8")
        (work / "cases.lua").write_text(
            "function __cases()\n" + CASES + "\nend\n"
            "function __safe() local ok,value=pcall(__cases) "
            "if ok then return value end return 'FAIL:'..tostring(__step)..':'..tostring(value) end",
            encoding="utf-8")
        def run(name: str, weekone: str, ordinary: str,
                menu: str) -> tuple[int, str]:
            (work / "sao.lua").write_text(weekone, encoding="utf-8")
            (work / "controller.lua").write_text(ordinary, encoding="utf-8")
            (work / "harness.lua").write_text(menu, encoding="utf-8")
            (work / "menu-helper.lua").write_text(menu_helper(menu), encoding="utf-8")
            (work / "reload.lua").write_text(
                "function __reloadWeekOne()\n" + weekone + "\nend\n",
                encoding="utf-8")
            done = subprocess.run([str(JDK / "java.exe"), "-cp",
                f"{GAME / 'projectzomboid.jar'};{work}", "LuaRun",
                str(work / "prelude.lua"), str(work / "sao.lua"),
                str(work / "controller.lua"), str(work / "harness.lua"),
                str(work / "menu-helper.lua"), str(work / "reload.lua"),
                str(work / "cases.lua"), "--", "__safe()"],
                cwd=work, capture_output=True, text=True, timeout=90)
            output = done.stdout + done.stderr
            receipt["cases"].append({"name": name, "exit": done.returncode,
                                     "output": output[-1500:]})
            return done.returncode, output

        code, output = run("current", source, controller, harness)
        if code or "VALUE PASS" not in output:
            raise RuntimeError("Week One handoff failed: " + output)
        for name, target, before, after, expected in CONTROLS:
            original = {"weekone": source, "controller": controller,
                        "harness": harness}[target]
            if before not in original:
                raise RuntimeError("missing inverse target " + name)
            altered = original.replace(before, after, 1)
            code, output = run(name, altered if target == "weekone" else source,
                               altered if target == "controller" else controller,
                               altered if target == "harness" else harness)
            if "VALUE FAIL:" not in output or expected not in output:
                raise RuntimeError(name + " inverse failed incorrectly: " + output)
        receipt["status"] = "PASS"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(f"PASS Week One retirement handoff and {len(CONTROLS)} inverses")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
