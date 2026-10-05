#!/usr/bin/env python3
"""Border 199: shared conflict appraisal and native route continuity.

Only the native movement receiver and external belief/needs inputs are
fixtures. The full production modules update movement before follow decisions,
rouse company, order, cancel, and consume terminal movement verdicts.
This is not a rendered-world test.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent
CONTROLLER = ROOT / "mod/42.20/media/lua/client/SAO_Controller.lua"
LOCOMOTION = ROOT / "mod/42.20/media/lua/client/SAO_Locomotion.lua"
GAME = Path(os.environ.get("PZ_DIR", r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"))
JDK = Path(os.environ.get("JDK_BIN", r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin"))
RUNNER = ROOT / "tools/luacheck/LuaRun.java"
CONFLICT_FILES = {name: ROOT / ("mod/42.20/media/lua/" + scope + "/SAO_" + module + ".lua")
    for name, scope, module in [("perception", "shared", "Perception"), ("models", "shared", "CognitiveModels"),
        ("cognition", "shared", "Cognition"), ("concepts", "shared", "ConceptKnowledge"),
        ("planning", "shared", "ProceduralPlanning"), ("pathogen", "shared", "PathogenPressure"),
        ("response", "client", "ConflictResponse")]}
FLIGHT_CASES = ROOT / "tools/flee_conflict_cases.lua"

PRELUDE = r'''
SAO={Log={line=function() end},Controller={agents={}},
 Body={active={},foreign={}},Perception={beliefs={},EARSHOT=50},
 Standing={},Disposition={},Rand={},Needs={},History={countyHours=function() return 2 end},
 Lessons={weight=function() return 0 end,learn=function() end,has=function() return false end}}
getSpecificPlayer=function() return __player end
Events=setmetatable({}, {__index=function(t,k)
 local e={Add=function() end,Remove=function() end};rawset(t,k,e);return e
end})
function SAO.Body.get(id) return __bodies[id] end
SAO.Identity={get=function(id) return {id=id} end,beliefKey=function(rec) return rec.id end}
function SAO.Perception.nearestBelievedZombie() return __threat end
function SAO.Perception.believedThreatCount() return __threat and 1 or 0 end
function SAO.Perception.hasLookedRecently() return true end
function SAO.Perception.freshObservedPerson() return true end
function SAO.Perception.tell() __tells=__tells+1;return 1 end
function SAO.Perception.cryForHelp() return {'fellow'},50 end
function SAO.Standing.sameGroup() return true end
function SAO.Standing.fellowsOf(id) return id=='runner' and __fellows or {} end
function SAO.Standing.groupOf() return __group end
function SAO.Standing.bondedWith() return nil end
function SAO.Standing.playerKey(player) return player and 'player:test' or nil end
function SAO.Standing.isPlayerKey(id) return id=='player:test' end
function SAO.Standing.keyForObserved(id) return id end
function SAO.Standing.companyStanding() return __companyStanding or 1 end
function SAO.Standing.isBondedTo() return false end
function SAO.Standing.knowsOf() return true end
function SAO.Standing.isHostileTo() return false end
function SAO.Standing.adjustTrust(id,other,delta) __trust[other]=(__trust[other] or 0)+delta end
function SAO.Standing.mayEnterBelieved(id,x,y)
 return not __blockAll and not __forbidden[tostring(x)..','..tostring(y)]
end
function SAO.Disposition.fleeDistance() return 50 end
function SAO.Disposition.overwhelmThreshold() return 99 end
function SAO.Disposition.paceUnderThreat() return 'run' end
function SAO.Disposition.traits() return {nerve=0} end
function SAO.Disposition.followGap() return 3 end
function SAO.Disposition.eatAt() return .5 end
function SAO.Disposition.isSmoker() return false end
function SAO.Disposition.wouldForceEntry() return false end
function SAO.Needs.woundInfection() return 0 end
function SAO.Needs.dirtyBandages() return 0 end
function SAO.Needs.bleeding() return 0 end
function SAO.Needs.findOffered() return nil end
function SAO.Rand.int()
 __randCalls=__randCalls+1
 if __randFixed~=nil then return __randFixed end
 -- Consecutive decision pairs alternate opposite corners. The original
 -- stationary-follow destinations differ by sqrt(8), beyond Loco's 2 tiles.
 return math.floor((__randCalls-1)/2)%2==0 and -1 or 1
end
SAOJavaBridge={}
function SAOJavaBridge:moveTo(body,x,y,z)
 __starts=__starts+1;__ordered={body=body,x=x,y=y,z=z};return 'MOVE_STARTED'
end
function SAOJavaBridge:moveToPaced(body,x,y,z) return self:moveTo(body,x,y,z) end
function SAOJavaBridge:tickMove() return __verdict end
function SAOJavaBridge:cancelMove() __cancels=__cancels+1;return 'MOVE_CANCELLED' end
function SAOJavaBridge:setForceEntry() end
function SAOJavaBridge:canSeePersonNow() return true end
function SAOJavaBridge:getBleedingCount() return __injury end
function SAOJavaBridge:woundInfection() return 0 end
function SAOJavaBridge:followTraverse(body,x,y)
 __traversals=__traversals+1;__lastTraverse={body=body,x=x,y=y};return __traverseResult
end
'''

# Expose existing locals only in the temporary probe copy. No decision body is
# copied/reimplemented and the production API gains no test entry points.
EXPOSE = r'''
Ctl.__fleeProbeDecide=decide
Ctl.__fleeProbeRouse=rouseCompany
Ctl.__fleeProbeTick=function(t) tickCount=t end
Ctl.__companyProbeDecide=decideCompany
Ctl.__playerProbeDecide=decideNeedsAndCompanion
Ctl.__followProbeMovement=updateMovement
Ctl.__threatProbeDecide=decideThreat
Ctl.__inspectionProbeBegin=beginContainerInspection
Ctl.__inspectionProbeState=setState
return Ctl
'''

PROBE = r'''
local checks={}
local function check(name,ok)
 if not ok then error('FLEE_CHECK:'..name) end
 checks[#checks+1]=name
end
local function body(x,y,z)
 local b={x=x,y=y,z=z}
 function b:getX() return self.x end
 function b:getY() return self.y end
 function b:getZ() return self.z end
 function b:getVehicle() return nil end
 function b:isDead() return self.dead==true end
 function b:isClimbing() return self.climbing==true end
 function b:getCurrentStateName() return self.nativeState or 'IdleState' end
 function b:getCurrentSquare()
  return {getX=function() return math.floor(self.x) end,
   getY=function() return math.floor(self.y) end,
   getZ=function() return math.floor(self.z) end}
 end
 function b:Callout() __shouts=__shouts+1 end
 return b
end
local function fresh()
 __starts=0;__cancels=0;__tells=0;__tick=0
 __injury=0;__player=nil;__shouts=0;__trust={};__group=nil
 __fellows={};__forbidden={};__blockAll=false;__verdict='ManualRoute'
 __threat={x=-4.5,y=.5,dist=5,source='observed'}
 local b=body(.5,.5,0)
 __bodies={runner=b,fellow=body(20.5,.5,0)}
 SAO.Perception.beliefs={runner={people={}},fellow={people={}}}
 SAO.Locomotion.jobs={}
 local a={state='IDLE',nextDecisionAt=0,rec={id='runner'}}
 SAO.Controller.agents={runner=a,fellow={state='IDLE',nextDecisionAt=999,rec={id='fellow'}}}
 -- Follow, equipment and inspection cases need an unrelated executing route.
 -- Flight choice itself is exercised through shared production modules in
 -- flee_conflict_cases.lua; do not seed it through the retired flee policy.
 a.state='FLEE'
 SAO.Locomotion.order('runner',b,10,0,0,true)
 check('fixture_route_owned',__starts==1 and SAO.Locomotion.jobs.runner.goal.x==10)
 SAO.Locomotion.tick('runner')
 return a,b,SAO.Locomotion.jobs.runner
end

local a,b,job

local function followDecide(a,b,player,roused)
 __tick=__tick+1;SAO.Controller.__fleeProbeTick(__tick)
 -- updateAgent runs this before its decision. In particular, a failed
 -- PLAYERFOLLOW must survive this phase for followTraverse to read it.
 if SAO.Controller.__followProbeMovement('runner',a,b) then return end
 if roused then
  a.nextDecisionAt=__tick+999
  SAO.Controller.__fleeProbeRouse('fellow',__bodies.fellow)
  check('follow_rousing_reopens_decision',a.nextDecisionAt==0)
 end
 if player then
  SAO.Controller.__playerProbeDecide('runner',a,b,__tick,nil)
 else
  SAO.Controller.__companyProbeDecide('runner',a,b,__tick)
 end
end
local function freshFollow(player)
 __starts=0;__cancels=0;__tells=0;__tick=0
 __injury=0;__shouts=0;__trust={};__threat=nil;__group=nil
 __fellows={'fellow'};__forbidden={};__blockAll=false;__verdict='ManualRoute'
 __randCalls=0;__randFixed=nil;__traversals=0;__traverseResult=nil;__companyStanding=1
 local b=body(.5,.5,0)
 local anchor=body(player and 9.5 or 10.5,.5,0)
 __bodies={runner=b,fellow=anchor};__player=player and anchor or nil
 SAO.Perception.beliefs={runner={people={['player:test']={source='observed',at=0}}},
  fellow={people={}}}
 SAO.Locomotion.jobs={}
 local a={state=player and 'PLAYERFOLLOW' or 'IDLE',nextDecisionAt=0,
  rec={id='runner'},companioning=player or nil}
 SAO.Controller.agents={runner=a,fellow={state='IDLE',nextDecisionAt=999,rec={id='fellow'}}}
 followDecide(a,b,player,false)
 local job=SAO.Locomotion.jobs.runner
 check('initial_follow_owned',__starts==1 and job and job.body==b
  and a.state==(player and 'PLAYERFOLLOW' or 'FOLLOW')
  and job.goal.x==(player and 8 or 9) and job.goal.y==-1)
 SAO.Locomotion.tick('runner')
 return a,b,job,anchor
end

-- Run both actual decision branches. Frequent rousing forces re-decisions;
-- alternating RNG must not replace a still-executing stationary route.
for _,player in ipairs({false,true}) do
 local anchor
 a,b,job,anchor=freshFollow(player)
 for i=1,12 do
  b.x=b.x+.1
  followDecide(a,b,player,true)
  check(player and 'stationary_player_not_restarted' or 'stationary_companion_not_restarted',
   __starts==1 and __cancels==0 and SAO.Locomotion.jobs.runner==job)
 end
 anchor.x=anchor.x+5;followDecide(a,b,player,false)
 local moving=SAO.Locomotion.jobs.runner
 check('moving_anchor_updates_route',__starts==2 and moving~=job
  and moving.goal.x==math.floor(anchor.x-1) and moving.goal.y==-1)
 anchor.x=anchor.x+1;followDecide(a,b,player,false)
 check('small_anchor_motion_keeps_route',__starts==2 and SAO.Locomotion.jobs.runner==moving)
end

for _,player in ipairs({false,true}) do
 for _,verdict in ipairs({'FailedObstacle:FAILED_BLOCKED_DIAGONAL',
  'FailedObstacle:FAILED_UNLOADED_NEXT_SQUARE','Succeeded','IDLE','TICK_FAILED fixture'}) do
  local anchor
  a,b,job,anchor=freshFollow(player)
  __verdict=verdict;SAO.Locomotion.tick('runner')
  check('follow_terminal_verdict_consumed',job.done==true)
  followDecide(a,b,player,false)
  local newJob=SAO.Locomotion.jobs.runner
  check('follow_terminal_route_reconsidered',__starts==2 and newJob~=job
   and newJob.goal.x==math.floor(anchor.x+1) and newJob.goal.y==1)
 end
end

for _,player in ipairs({false,true}) do
 local anchor
 a,b,job,anchor=freshFollow(player)
 local newBody=body(.5,.5,0);__bodies.runner=newBody
 followDecide(a,newBody,player,false)
 check('follow_replacement_body_retires_owner',__starts==2 and __cancels==1
  and SAO.Locomotion.jobs.runner.body==newBody)

 a,b,job,anchor=freshFollow(player)
 local newAnchor=body(anchor.x,anchor.y,anchor.z)
 __bodies.fellow=newAnchor;if player then __player=newAnchor end
 followDecide(a,b,player,false)
 check('follow_replacement_anchor_reconsidered',__starts==2 and __cancels==1
  and SAO.Locomotion.jobs.runner~=job)

 a,b,job,anchor=freshFollow(player);anchor.z=1
 followDecide(a,b,player,false)
 if player then
  check('follow_anchor_floor_reconsidered',__starts==2 and __cancels==1
   and SAO.Locomotion.jobs.runner.goal.z==1)
 else
  check('companion_other_floor_anchor_releases_route',__starts==1 and __cancels==1
   and SAO.Locomotion.jobs.runner==nil and a.state=='IDLE' and a.followOffset==nil)
  anchor.z=0;followDecide(a,b,false,false)
  check('companion_same_floor_anchor_reacquired',__starts==2 and __cancels==1
   and SAO.Locomotion.jobs.runner~=job and a.state=='FOLLOW')
 end

 a,b,job,anchor=freshFollow(player);b.z=1
 followDecide(a,b,player,false)
 if player then
  check('follow_body_floor_reconsidered',__starts==2 and __cancels==1
   and SAO.Locomotion.jobs.runner~=job)
 else
  check('companion_other_floor_body_releases_route',__starts==1 and __cancels==1
   and SAO.Locomotion.jobs.runner==nil and a.state=='IDLE')
  b.z=0;followDecide(a,b,false,false)
  check('companion_same_floor_body_reacquired',__starts==2 and __cancels==1
   and SAO.Locomotion.jobs.runner.goal.z==0 and a.state=='FOLLOW')
 end

 a,b,job,anchor=freshFollow(player)
 __forbidden[tostring(job.goal.x)..','..tostring(job.goal.y)]=true
 __randFixed=-1;anchor.x=anchor.x+1
 followDecide(a,b,player,false)
 local permitted=SAO.Locomotion.jobs.runner
 check('follow_forbidden_old_goal_retired',__starts==2 and __cancels==1
  and permitted~=job and permitted.goal.x==job.goal.x+1)

 a,b,job,anchor=freshFollow(player);__blockAll=true
 followDecide(a,b,player,false)
 check('follow_forbidden_new_goal_refused',__starts==1 and __cancels==1
  and SAO.Locomotion.jobs.runner==nil and a.state=='IDLE')

 a,b,job,anchor=freshFollow(player)
 SAO.Locomotion.order('runner',b,20,0,0)
 followDecide(a,b,player,false)
 check('follow_replaced_job_reconsidered',__starts==3 and __cancels==1
  and SAO.Locomotion.jobs.runner.goal.x==math.floor(anchor.x+1))

 a,b,job,anchor=freshFollow(player);b.x=anchor.x;b.y=anchor.y
 followDecide(a,b,player,false)
 check('follow_close_gap_stops',__starts==1 and __cancels==1
  and SAO.Locomotion.jobs.runner==nil and a.state=='IDLE' and not job.done)

 -- An old ROAM destination is within Loco's reuse radius but forbidden.
 -- The new beside-anchor destination is allowed and must replace it.
 a,b,job,anchor=freshFollow(player)
 SAO.Locomotion.cancel('runner');a.state='ROAM';a.followOffset=nil
 __starts=0;__cancels=0;__randFixed=-1
 SAO.Locomotion.order('runner',b,10,0,0)
 local oldRoam=SAO.Locomotion.jobs.runner
 __forbidden['10,0']=true;anchor.x=12.5;anchor.y=1.5
 followDecide(a,b,player,false)
 local entry=SAO.Locomotion.jobs.runner
 check(player and 'player_follow_entry_retires_forbidden_roam' or 'follow_entry_retires_forbidden_roam',
  __starts==2 and __cancels==1 and entry~=oldRoam
  and entry.goal.x==11 and entry.goal.y==0
  and a.state==(player and 'PLAYERFOLLOW' or 'FOLLOW'))

 a,b,job,anchor=freshFollow(player)
 a.state='ROAM';a.followOffset=nil;__blockAll=true
 followDecide(a,b,player,false)
 check('denied_roam_follow_has_honest_state',__starts==1 and __cancels==1
  and a.state=='IDLE' and SAO.Locomotion.jobs.runner==nil)

 -- PLAYERFOLLOW owns explicit player traversal. Physical companion anchors
 -- require compatible current native heights; visual knowledge may cross floors.
 a,b,job,anchor=freshFollow(player)
 anchor.x=b.x;anchor.y=b.y;anchor.z=1
 followDecide(a,b,player,false)
 if player then
  local upstairs=SAO.Locomotion.jobs.runner
  check('player_close_other_floor_keeps_route',__starts==2 and __cancels==1
   and upstairs and upstairs~=job and upstairs.goal.z==1 and a.state=='PLAYERFOLLOW')
  followDecide(a,b,true,false)
  check('close_other_floor_route_not_restarted',__starts==2 and SAO.Locomotion.jobs.runner==upstairs)
  b.z=1;followDecide(a,b,true,false)
  check('same_floor_close_gap_stops',__starts==2 and __cancels==2
   and SAO.Locomotion.jobs.runner==nil and a.state=='IDLE' and not upstairs.done)
 else
  check('companion_close_other_floor_releases_route',__starts==1 and __cancels==1
   and SAO.Locomotion.jobs.runner==nil and a.state=='IDLE')
  followDecide(a,b,false,false)
  check('companion_absent_floor_does_not_restart',__starts==1 and __cancels==1
   and SAO.Locomotion.jobs.runner==nil)
  b.z=1;followDecide(a,b,false,false)
  check('companion_reacquired_close_gap_stays_idle',__starts==1 and __cancels==1
   and SAO.Locomotion.jobs.runner==nil and a.state=='IDLE')
 end
end

-- Physical admission uses <0.5; quantized floors separately own route goals.
local anchor
a,b,job,anchor=freshFollow(false);anchor.z=0.49
followDecide(a,b,false,false)
check('companion_below_floor_threshold_keeps_route',__starts==1 and __cancels==0
 and SAO.Locomotion.jobs.runner==job and a.state=='FOLLOW')
anchor.z=0.5;followDecide(a,b,false,false)
check('companion_exact_floor_threshold_releases_route',__starts==1 and __cancels==1
 and SAO.Locomotion.jobs.runner==nil and a.state=='IDLE')

-- A fractional-height contact near a step can satisfy physical admission
-- while its destination crosses a quantized floor boundary. The route uses z.
a,b,job,anchor=freshFollow(false);b.z=0.8;anchor.z=1.0
anchor.x=b.x;anchor.y=b.y
followDecide(a,b,false,false)
check('companion_quantized_other_floor_keeps_route',__starts==2 and __cancels==1
 and SAO.Locomotion.jobs.runner and SAO.Locomotion.jobs.runner.goal.z==1
 and a.state=='FOLLOW')

a,b,job=freshFollow(false);__bodies.fellow=nil
followDecide(a,b,false,false)
check('missing_companion_releases_route',__starts==1 and __cancels==1
 and a.state=='IDLE' and SAO.Locomotion.jobs.runner==nil)

local anchor
a,b,job,anchor=freshFollow(false)
__fellows={'different'};__bodies.different=anchor
followDecide(a,b,false,false)
check('changed_companion_identity_reconsidered',__starts==2 and __cancels==1
 and a.followOffset.anchor=='different')

for _,crossing in ipairs({'STARTED_FENCE_CLIMB','TURNING_TO_FENCE','OPENING_DOOR','CLIMBING'}) do
 a,b,job=freshFollow(true);__verdict='FailedObstacle:FAILED_BLOCKED_DIAGONAL'
 SAO.Locomotion.tick('runner');__traverseResult=crossing
 followDecide(a,b,true,false)
 check('player_crossing_keeps_native_action',__traversals==1 and __starts==1 and __cancels==0
  and SAO.Locomotion.jobs.runner==job and a.state=='PLAYERFOLLOW')
end

-- A failed route must not become permission to initiate a different physical
-- action. The native receiver would start it if called; production preflight
-- must reject it before the call, through updateMovement -> decision.
for _,blocked in ipairs({'goal','target','edge'}) do
 a,b,job,anchor=freshFollow(true);__verdict='FailedObstacle:FAILED_BLOCKED_DIAGONAL'
 __traverseResult='STARTED_FENCE_CLIMB'
 local key=blocked=='goal' and '8,-1' or (blocked=='target' and '9,0' or '1,0')
 __forbidden[key]=true
 followDecide(a,b,true,false)
 check('revoked_'..blocked..'_traversal_refused',__traversals==0
  and __cancels==1 and SAO.Locomotion.jobs.runner~=job)
end
for _,crossing in ipairs({'STARTED_FENCE_CLIMB','OPENING_WINDOW','CLIMBING'}) do
 a,b,job=freshFollow(true);__verdict='FailedObstacle:FAILED_BLOCKED_DIAGONAL'
 __traverseResult=crossing;__blockAll=true
 followDecide(a,b,true,false)
 check('revoked_entry_never_calls_native_crossing',__traversals==0 and __starts==1
  and __cancels==1 and a.state=='IDLE' and SAO.Locomotion.jobs.runner==nil)
end
for _,changed in ipairs({'player','body','target'}) do
 a,b,job,anchor=freshFollow(true);__verdict='FailedObstacle:FAILED_BLOCKED_DIAGONAL'
 __traverseResult='STARTED_FENCE_CLIMB'
 if changed=='player' then
  __player=body(anchor.x,anchor.y,anchor.z)
 elseif changed=='body' then
  b=body(b.x,b.y,b.z);__bodies.runner=b
 else
  anchor.x=anchor.x-1
 end
 followDecide(a,b,true,false)
 check('changed_'..changed..'_traversal_owner_refused',__traversals==0
  and __starts==2 and __cancels==1 and SAO.Locomotion.jobs.runner~=job)
end

-- Permission can change after an action was admitted. Keep the exact native
-- climb, and finish an owned OpenWindowState at its pinned edge, before asking
-- permission to begin another action. A mere TURNING receipt owns no climb.
a,b,job=freshFollow(true);__verdict='FailedObstacle:FAILED_BLOCKED_DIAGONAL'
__traverseResult='STARTED_FENCE_CLIMB';followDecide(a,b,true,false)
b.climbing=true;__blockAll=true;followDecide(a,b,true,false)
check('owned_climb_finishes_without_new_action',__traversals==1 and __starts==1
 and __cancels==0 and a.state=='PLAYERFOLLOW' and SAO.Locomotion.jobs.runner==job)
b.climbing=false;followDecide(a,b,true,false)
check('completed_climb_rechecks_permission',__traversals==1 and __cancels==1
 and a.state=='IDLE' and SAO.Locomotion.jobs.runner==nil)

-- Installed fence/window state owners leave isClimbing() false. The exact
-- admitted body/job must finish even when the target moves or permission is
-- revoked during root motion; IdleState then restores ordinary reappraisal.
for _,nativeState in ipairs({'ClimbOverFenceState','ClimbThroughWindowState'}) do
 a,b,job,anchor=freshFollow(true);__verdict='FailedObstacle:FAILED_BLOCKED_DIAGONAL'
 __traverseResult='STARTED_FENCE_CLIMB';followDecide(a,b,true,false)
 b.nativeState=nativeState;b.climbing=false;__blockAll=true;anchor.x=30.5
 b.x=b.x+0.75
 for i=1,3 do followDecide(a,b,true,false) end
 check('owned_'..nativeState..'_finishes_without_new_action',__traversals==1
  and __starts==1 and __cancels==0 and a.state=='PLAYERFOLLOW'
  and SAO.Locomotion.jobs.runner==job)
 b.nativeState='IdleState';anchor.x=9.5;followDecide(a,b,true,false)
 check('completed_'..nativeState..'_rechecks_permission',__traversals==1
  and __cancels==1 and a.state=='IDLE' and SAO.Locomotion.jobs.runner==nil)
end
for _,nativeState in ipairs({'OtherClimbOverFenceState','ClimbThroughWindowStateOther'}) do
 a,b,job=freshFollow(true);__verdict='FailedObstacle:FAILED_BLOCKED_DIAGONAL'
 __traverseResult='STARTED_FENCE_CLIMB';followDecide(a,b,true,false)
 b.nativeState=nativeState;__blockAll=true;followDecide(a,b,true,false)
 check('unrelated_native_state_does_not_own_crossing',__traversals==1
  and __cancels==1 and a.state=='IDLE' and SAO.Locomotion.jobs.runner==nil)
end

a,b,job,anchor=freshFollow(true);__verdict='FailedObstacle:FAILED_BLOCKED_DIAGONAL'
__traverseResult='STARTED_WINDOW_OPEN';followDecide(a,b,true,false)
b.nativeState='OpenWindowState';__blockAll=true;anchor.x=30.5
__traverseResult='COMPLETED_WINDOW_OPEN';followDecide(a,b,true,false)
check('owned_window_finishes_at_original_edge',__traversals==2 and __lastTraverse.x==9
 and __lastTraverse.y==0 and __lastTraverse.body==b and __cancels==0
 and SAO.Locomotion.jobs.runner==job)
b.nativeState='IdleState';anchor.x=9.5;followDecide(a,b,true,false)
check('completed_window_rechecks_permission',__traversals==2 and __cancels==1
 and a.state=='IDLE' and SAO.Locomotion.jobs.runner==nil)

a,b,job=freshFollow(true);__verdict='FailedObstacle:FAILED_BLOCKED_DIAGONAL'
__traverseResult='TURNING_TO_FENCE';followDecide(a,b,true,false)
__blockAll=true;followDecide(a,b,true,false)
check('turning_does_not_bypass_new_permission',__traversals==1 and __cancels==1
 and a.state=='IDLE' and SAO.Locomotion.jobs.runner==nil)

a,b,job=freshFollow(true);__verdict='FailedObstacle:FAILED_BLOCKED_DIAGONAL'
__traverseResult='STARTED_FENCE_CLIMB';followDecide(a,b,true,false)
local foreignBody=body(b.x,b.y,b.z);foreignBody.climbing=true;__bodies.runner=foreignBody
followDecide(a,foreignBody,true,false)
check('crossing_receipt_cannot_own_replacement_body',__traversals==1 and __starts==2
 and __cancels==1 and SAO.Locomotion.jobs.runner.body==foreignBody)

for _,lost in ipairs({'missing','dead','group','distance'}) do
 a,b,job,anchor=freshFollow(true);__verdict='FailedObstacle:FAILED_BLOCKED_DIAGONAL'
 __traverseResult='STARTED_FENCE_CLIMB'
 if lost=='missing' then __player=nil
 elseif lost=='dead' then __player.dead=true
 elseif lost=='group' then __group='new-company'
 else anchor.x=40.5 end
 followDecide(a,b,true,false)
 check(lost..'_player_context_retires_failure',__traversals==0 and __starts==1
  and __cancels==1 and a.state=='IDLE' and SAO.Locomotion.jobs.runner==nil)
end
a,b,job=freshFollow(true);__verdict='Succeeded'
SAO.Controller.__followProbeMovement('runner',a,b)
check('player_arrival_leaves_movement_state',job.done==true and job.result=='arrived'
 and a.state=='IDLE' and __cancels==1 and SAO.Locomotion.jobs.runner==nil)
a,b,job=freshFollow(true);a.holdPosition=true
followDecide(a,b,true,false)
check('player_hold_stops_route',__starts==1 and __cancels==1
 and SAO.Locomotion.jobs.runner==nil and a.state=='IDLE')
a,b,job=freshFollow(true);__companyStanding=0
followDecide(a,b,true,false)
check('player_trust_loss_releases_route',__starts==1 and __cancels==1
 and SAO.Locomotion.jobs.runner==nil and a.state=='IDLE' and not a.companioning)

-- Distant-threat and retained-flight checks now exercise ConflictResponse in
-- flee_conflict_cases.lua, including player-arrival and cry-expiry accounting.
-- Additional native owner lifecycle coverage belongs to conflict_response_test.py;
-- see COVERAGE_TRANSFER below.
-- Native03 retained equipment routes beyond their already assigned deadline.
-- Exercise real movement/state cancellation, leaving native crossings and
-- terminal arrival results under their existing owners.
local gearClears,ammoClears=0,0
SAO.Needs.clearGear=function(native) check('gear_clear_has_exact_body',native==b);gearClears=gearClears+1 end
SAO.Needs.clearAmmo=function(native) check('ammo_clear_has_exact_body',native==b);ammoClears=ammoClears+1 end
for _,state in ipairs({'GEARWARD','AMMOWARD'}) do
 a,b,job=fresh();a.state=state;a.taskDeadline=100;a.nextDecisionAt=500
 SAO.Controller.__fleeProbeTick(99)
 SAO.Controller.__followProbeMovement('runner',a,b)
 check('equipment_before_deadline_keeps_route',a.state==state and __cancels==0 and SAO.Locomotion.jobs.runner==job)
 SAO.Controller.__fleeProbeTick(100)
 local held=SAO.Controller.__followProbeMovement('runner',a,b)
 check('equipment_deadline_reopens_decision',held==false and a.state=='IDLE'
  and a.nextDecisionAt==0 and a.taskDeadline==nil and __cancels==1 and SAO.Locomotion.jobs.runner==nil)
end
check('equipment_cache_owner_cleared',gearClears==1 and ammoClears==1)
for _,verdict in ipairs({'CLIMBING','STARTED_FENCE_CLIMB','STARTED_WINDOW_CLIMB'}) do
 a,b,job=fresh();a.state='GEARWARD';a.taskDeadline=100
 SAO.Controller.__fleeProbeTick(100);__verdict=verdict
 SAO.Controller.__followProbeMovement('runner',a,b)
 check('equipment_owned_crossing_finishes',a.state=='GEARWARD' and __cancels==0 and SAO.Locomotion.jobs.runner==job)
 __verdict='ManualRoute'
 SAO.Controller.__followProbeMovement('runner',a,b)
 check('equipment_completed_crossing_reconsiders',a.state=='IDLE' and __cancels==1)
end
a,b,job=fresh();a.state='GEARWARD';a.taskDeadline=100
SAO.Controller.__fleeProbeTick(100)
SAO.SourceUse={beforeStateChange=function() return false end}
local priorClears=gearClears
check('equipment_reconciliation_keeps_owner',SAO.Controller.__followProbeMovement('runner',a,b)==true
 and a.state=='GEARWARD' and SAO.Locomotion.jobs.runner==job and __cancels==0 and gearClears==priorClears)
SAO.SourceUse=nil
SAO.Identity={updatePosition=function() end}
SAO.Needs.queueTakeGear=function() return true end
a,b,job=fresh();a.state='GEARWARD';a.taskDeadline=100
SAO.Controller.__fleeProbeTick(100);__verdict='Succeeded'
SAO.Controller.__followProbeMovement('runner',a,b)
check('equipment_arrival_keeps_native_acquisition',a.state=='TAKE' and a.takePurpose=='gear' and a.taskDeadline==1900)
a,b,job=fresh();a.taskDeadline=1;SAO.Controller.__fleeProbeTick(100)
SAO.Controller.__followProbeMovement('runner',a,b)
check('equipment_deadline_does_not_end_escape',a.state=='FLEE' and SAO.Locomotion.jobs.runner==job and __cancels==0)

-- Inspection owns a route and changes knowledge, never an acquisition. The
-- WorldSources boundary is a controlled receiver; its real native/private
-- knowledge behavior is independently exercised by Border 184.
local inspectionContext, inspected, inspectionFailures, inspectionOffers, takes
local inspectAllowed, offerAvailable, inspectionPending
SAO.Lessons.desperationBump=function() return 0 end
SAO.Needs.queueTake=function() takes=takes+1;return true end
SAO.WorldSources={
 inspectionCandidate=function(id,body,admission)
  inspectionOffers=inspectionOffers+1
  if not offerAvailable then return nil end
  inspectionContext={actorId=id,admission=admission,sourceId='container:a',fingerprint='fp:a',
   sourceX=11,sourceY=0,sourceZ=0,x=11,y=0,z=0}
  inspectionPending=inspectionContext
  return inspectionContext
 end,
 inspectContainer=function(id,body,context)
  check('inspection_exact_context',context==inspectionContext and inspectionPending==context)
  inspected=inspected+1;inspectionPending=nil
  return inspectAllowed,inspectAllowed and 'inspected' or 'current-claim-refused'
 end,
 inspectionFailed=function(id,body,context,reason)
  inspectionFailures[#inspectionFailures+1]={context=context,reason=reason}
  inspectionPending=nil
 end,
}
local function inspectionFresh()
 SAO.SourceUse=nil
 local a,b,job=fresh();a.state='ROAM'
 inspected=0;inspectionFailures={};inspectionOffers=0;takes=0
 inspectAllowed=true;offerAvailable=true;inspectionPending=nil
 return a,b,job
end
local function startInspection(a,b)
 return SAO.Controller.__inspectionProbeBegin('runner',a,b,.6,'food',100)
end
a,b,job=inspectionFresh()
check('inspection_route_admitted',startInspection(a,b)==true and a.state=='FORAGE'
 and a.forageInspection==inspectionContext and a.taskDeadline==3700)
check('inspection_replaces_close_old_purpose',SAO.Locomotion.jobs.runner~=job
 and SAO.Locomotion.jobs.runner.goal.x==11 and __starts==2 and __cancels==1)
__verdict='Succeeded';SAO.Controller.__fleeProbeTick(101)
local handled=SAO.Controller.__followProbeMovement('runner',a,b)
check('inspection_arrival_teaches_then_redecides',inspected==1 and takes==0 and handled==false
 and a.state=='IDLE' and a.forageInspection==nil and a.nextDecisionAt==0
 and a.taskDeadline==nil and #inspectionFailures==0)

a,b,job=inspectionFresh();startInspection(a,b)
__verdict='FailedObstacle:FAILED_BLOCKED_DIAGONAL'
SAO.Controller.__followProbeMovement('runner',a,b)
check('inspection_route_failure_no_take',inspected==0 and takes==0 and a.state=='IDLE'
 and #inspectionFailures==1 and inspectionFailures[1].context==inspectionContext
 and inspectionFailures[1].reason=='done:FailedObstacle:FAILED_BLOCKED_DIAGONAL')

a,b,job=inspectionFresh();startInspection(a,b)
SAO.Controller.__inspectionProbeState(a,'runner','FLEE','danger')
check('inspection_interrupt_releases_without_access_failure',a.forageInspection==nil
 and #inspectionFailures==1 and inspectionFailures[1].reason=='interrupted:FLEE'
 and inspected==0 and takes==0)

a,b,job=inspectionFresh();SAO.SourceUse={beforeStateChange=function() return false end}
check('inspection_start_reconciliation_preserves_route',startInspection(a,b)==true
 and a.state=='ROAM' and a.forageInspection==nil and SAO.Locomotion.jobs.runner==job
 and __starts==1 and __cancels==0 and inspectionPending==nil)

a,b,job=inspectionFresh();startInspection(a,b);job=SAO.Locomotion.jobs.runner
SAO.SourceUse={beforeStateChange=function() return false end};__verdict='Succeeded'
check('inspection_terminal_reconciliation_preserves_intent',
 SAO.Controller.__followProbeMovement('runner',a,b)==true and a.state=='FORAGE'
 and a.forageInspection==inspectionContext and inspectionPending==inspectionContext
 and SAO.Locomotion.jobs.runner==job and inspected==0 and takes==0)

a,b,job=inspectionFresh();startInspection(a,b);inspectAllowed=false;__verdict='Succeeded'
SAO.Controller.__followProbeMovement('runner',a,b)
check('inspection_permission_change_no_take',inspected==1 and takes==0 and a.state=='IDLE'
 and a.pressure.detail=='container inspection ended: current-claim-refused')

a,b,job=inspectionFresh();offerAvailable=false
check('inspection_no_offer_preserves_route',startInspection(a,b)==false
 and a.state=='ROAM' and SAO.Locomotion.jobs.runner==job and __cancels==0)

a,b,job=inspectionFresh();startInspection(a,b);SAO.Controller.__fleeProbeTick(3700)
check('inspection_deadline_reopens_decision',SAO.Controller.__followProbeMovement('runner',a,b)==false
 and a.state=='IDLE' and a.forageInspection==nil and inspectionPending==nil
 and inspected==0 and takes==0 and a.nextDecisionAt==0)
for _,verdict in ipairs({'CLIMBING','STARTED_FENCE_CLIMB','STARTED_WINDOW_CLIMB'}) do
 a,b,job=inspectionFresh();startInspection(a,b);job=SAO.Locomotion.jobs.runner
 SAO.Controller.__fleeProbeTick(3700);__verdict=verdict
 SAO.Controller.__followProbeMovement('runner',a,b)
 check('inspection_owned_crossing_finishes',a.state=='FORAGE'
  and a.forageInspection==inspectionContext and SAO.Locomotion.jobs.runner==job)
end

SAO.Disposition.drinkAt=function() return .4 end
SAO.Needs.eatCarried=function() return false end
SAO.Needs.findSource=function() return 2,0,0,'known food' end
SAO.Needs.approach=function(body,kind,x,y,z) return x,y,z end
a,b,job=inspectionFresh();a.state='IDLE'
SAO.Controller.__playerProbeDecide('runner',a,b,100,{hunger=.6,thirst=0})
check('inspection_known_food_first',a.state=='FORAGE' and not a.forageInspection
 and inspectionOffers==0 and a.forageContext~=nil)
SAO.Needs.findSource=function() return nil end
a,b,job=inspectionFresh();a.state='IDLE'
SAO.Controller.__playerProbeDecide('runner',a,b,100,{hunger=.6,thirst=0})
check('inspection_unknown_holder_after_food_absent',a.state=='FORAGE'
 and a.forageInspection==inspectionContext and inspectionOffers==1)
a,b,job=inspectionFresh();a.state='FORAGE'
SAO.Needs.clearSource=function() end
SAO.Needs.queueTake=function() return false,'current-claim-refused' end
__verdict='Succeeded'
SAO.Controller.__followProbeMovement('runner',a,b)
check('forage_arrival_reports_transfer_refusal',a.state=='IDLE'
 and a.pressure.detail=='forage attempt ended: current-claim-refused')
__result='PASS '..table.concat(checks,',')
'''

CONTROLS = (
    ("forage_refusal_discarded", 'takeReason = reason or "native-transfer-refused"', 'takeReason = s', 'forage_arrival_reports_transfer_refusal'),
    ("equipment_deadline_missing", '(agent.state == "GEARWARD" or agent.state == "AMMOWARD")\n            and agent.taskDeadline and tickCount >= agent.taskDeadline', '(agent.state == "GEARWARD" or agent.state == "AMMOWARD")\n            and false', 'equipment_deadline_reopens_decision'),
    ("equipment_deadline_early", '(agent.state == "GEARWARD" or agent.state == "AMMOWARD")\n            and agent.taskDeadline and tickCount >= agent.taskDeadline', '(agent.state == "GEARWARD" or agent.state == "AMMOWARD")\n            and agent.taskDeadline and tickCount + 1 >= agent.taskDeadline', 'equipment_before_deadline_keeps_route'),
    ("equipment_crossing_cut", 'if not crossing then\n                local wasGear', 'if true then\n                local wasGear', 'equipment_owned_crossing_finishes'),
    ("equipment_cache_not_cleared", 'if wasGear then SAO.Needs.clearGear(body)', 'if wasGear then', 'equipment_cache_owner_cleared'),
    ("equipment_reconciliation_ignored", 'if not setState(agent, id, "IDLE", "equipment route deadline reached") then', 'if setState(agent, id, "IDLE", "equipment route deadline reached") and false then', 'equipment_reconciliation_keeps_owner'),
    ("equipment_arrival_expired", '(agent.state == "GEARWARD" or agent.state == "AMMOWARD")\n            and agent.taskDeadline and tickCount >= agent.taskDeadline\n            and s:sub(1, 5) ~= "done:" then', '(agent.state == "GEARWARD" or agent.state == "AMMOWARD")\n            and agent.taskDeadline and tickCount >= agent.taskDeadline then', 'equipment_arrival_keeps_native_acquisition'),
    ("inspection_old_purpose_reused", 'SAO.Locomotion.cancel(id)\n    agent.forageContext = nil', 'agent.forageContext = nil', 'inspection_replaces_close_old_purpose'),
    ("inspection_arrival_skipped", 'inspected, reason = SAO.WorldSources.inspectContainer(id, body, context)', 'inspected, reason = true, "invented inspection"', 'inspection_arrival_teaches_then_redecides'),
    ("inspection_failure_unrecorded", 'SAO.WorldSources.inspectionFailed(id, body, context, s)', '', 'inspection_route_failure_no_take'),
    ("inspection_interruption_retained", 'if state ~= "FORAGE" and agent.forageInspection then', 'if false then', 'inspection_interrupt_releases_without_access_failure'),
    ("inspection_start_reconciliation_ignored", 'if not setState(agent, id, "FORAGE", "looks in a container for " .. category) then', 'if setState(agent, id, "FORAGE", "looks in a container for " .. category) and false then', 'inspection_start_reconciliation_preserves_route'),
    ("inspection_terminal_reconciliation_ignored", '"IDLE", "container inspection route ended") == false then return true end', '"IDLE", "container inspection route ended") == false then end', 'inspection_terminal_reconciliation_preserves_intent'),
    ("inspection_deadline_missing", 'if agent.state == "FORAGE" and agent.forageInspection\n            and agent.taskDeadline', 'if false\n            and agent.taskDeadline', 'inspection_deadline_reopens_decision'),
    ("inspection_crossing_cut", 'if not crossing then\n                if not setState(agent, id, "IDLE", "container inspection route expired")', 'if true then\n                if not setState(agent, id, "IDLE", "container inspection route expired")', 'inspection_owned_crossing_finishes'),
    ("physical_companion_floor_omitted", "return math.abs(bz - oz) < 0.5", "return true",
     "companion_other_floor_anchor_releases_route"),
    ("physical_companion_floor_inclusive", "return math.abs(bz - oz) < 0.5", "return math.abs(bz - oz) <= 0.5",
     "companion_exact_floor_threshold_releases_route"),
    ("physical_companion_floor_too_strict", "return math.abs(bz - oz) < 0.5", "return math.abs(bz - oz) < 0.5 and math.floor(bz) == math.floor(oz)",
     "companion_quantized_other_floor_keeps_route"),
    ("follow_redraw", "if not sameFollow then", "if true then", "stationary_companion_not_restarted"),
    ("player_follow_redraw", 'if orderBesideFollow(id, agent, body, myKey, me, "PLAYERFOLLOW",',
     'agent.followOffset = nil\n                    if orderBesideFollow(id, agent, body, myKey, me, "PLAYERFOLLOW",',
     "stationary_player_not_restarted"),
    ("follow_frozen", "local gx = math.floor(anchorBody:getX() + follow.dx)",
     "local gx = follow.job and follow.job.goal.x or math.floor(anchorBody:getX() + follow.dx)",
     "moving_anchor_updates_route"),
    ("follow_finished_hold", "and follow.bodyZ == bz and job and not job.done", "and follow.bodyZ == bz and job",
     "follow_terminal_route_reconsidered"),
    ("follow_wrong_body", "and follow.job == job and job.body == body and job.goal", "and follow.job == job and job.goal",
     "follow_replacement_body_retires_owner"),
    ("follow_wrong_anchor", "and follow.anchor == anchor and follow.anchorBody == anchorBody", "and follow.anchor == anchor",
     "follow_replacement_anchor_reconsidered"),
    ("follow_wrong_floor", "local az = math.floor(anchorBody:getZ())", "local az = 0",
     "follow_anchor_floor_reconsidered"),
    ("follow_wrong_body_floor", "and follow.bodyZ == bz and job and not job.done", "and job and not job.done",
     "follow_body_floor_reconsidered"),
    ("follow_old_permission", "and mayEnterBelieved(id, job.goal.x, job.goal.y)", "",
     "follow_forbidden_old_goal_retired"),
    ("follow_new_permission", "if not mayEnterBelieved(id, gx, gy) then\n        agent.followOffset = nil",
     "if false then\n        agent.followOffset = nil", "follow_forbidden_new_goal_refused"),
    ("follow_replaced_job", "and follow.job == job and job.body == body and job.goal", "and job.body == body and job.goal",
     "follow_replaced_job_reconsidered"),
    ("player_failure_erased", 'if agent.state == "PLAYERFOLLOW" and not s:find("arrived", 1, true) then',
     'if false then', "player_crossing_keeps_native_action"),
    ("follow_stale_entry", "if job then SAO.Locomotion.cancel(id) end",
     "if agent.state == state and job then SAO.Locomotion.cancel(id) end", "follow_entry_retires_forbidden_roam"),
    ("follow_planar_gap", "if anchorDist > gap or not onAnchorFloor then", "if anchorDist > gap then",
     "companion_quantized_other_floor_keeps_route"),
    ("player_follow_planar_gap", "if (pdist > companionGap or not onPlayerFloor) and pdist <= 30.0 then",
     "if pdist > companionGap and pdist <= 30.0 then", "player_close_other_floor_keeps_route"),
    ("crossing_goal_permission", "and mayEnterBelieved(id, followJob.goal.x, followJob.goal.y)", "",
     "revoked_goal_traversal_refused"),
    ("crossing_target_permission", "and mayEnterBelieved(id, math.floor(px2), math.floor(py2))", "",
     "revoked_target_traversal_refused"),
    ("crossing_edge_permission", "if mayEnterBelieved(id, nx, ny) then", "if true then",
     "revoked_edge_traversal_refused"),
    ("crossing_stale_context", "and onPlayerFloor and currentFollow", "and onPlayerFloor",
     "changed_player_traversal_owner_refused"),
    ("crossing_interrupted", "if continueOwnedFollowCrossing(id, agent, body) then return true end", "",
     "owned_climb_finishes_without_new_action"),
    ("crossing_wrong_body", 'or crossing.body ~= body\n', '\n',
     "crossing_receipt_cannot_own_replacement_body"),
    ("crossing_legacy_flag_only", 'body:isClimbing() or nativeState == "ClimbOverFenceState"\n            or nativeState == "ClimbThroughWindowState"',
     'body:isClimbing()', "owned_ClimbOverFenceState_finishes_without_new_action"),
    ("crossing_window_state_missing", '\n            or nativeState == "ClimbThroughWindowState"', '',
     "owned_ClimbThroughWindowState_finishes_without_new_action"),
    ("crossing_state_substring", 'nativeState == "ClimbOverFenceState"',
     'tostring(nativeState):find("ClimbOverFenceState", 1, true) ~= nil',
     "unrelated_native_state_does_not_own_crossing"),
    ("denied_roam_state", 'setState(agent, id, "IDLE", "company route is not permitted")',
     'if agent.state == state then setState(agent, id, "IDLE", "company route is not permitted") end',
     "denied_roam_follow_has_honest_state"),
    ("missing_player_retained", "if not myKey then\n            agent.companioning, agent.followOffset = nil, nil",
     "if false then\n            agent.companioning, agent.followOffset = nil, nil", "missing_player_context_retires_failure"),
    ("dead_player_followed", "local myKey = me and not me:isDead() and SAO.Standing.playerKey(me) or nil",
     "local myKey = me and SAO.Standing.playerKey(me) or nil", "dead_player_context_retires_failure"),
    ("distant_failure_retained", "if distantJob and distantJob.done then", "if false then",
     "distance_player_context_retires_failure"),
    ("grouped_failure_retained", 'elseif myKey and agent.state == "PLAYERFOLLOW" then\n            agent.companioning, agent.followOffset',
     'elseif false then\n            agent.companioning, agent.followOffset', "group_player_context_retires_failure"),
)


def execute(command: list[str], cwd: Path) -> tuple[int, str]:
    result = subprocess.run(command, cwd=cwd, capture_output=True, text=True, timeout=180)
    return result.returncode, (result.stdout or "") + (result.stderr or "")


# Every retired control below targeted the removed ordered flee branch.
# Follow/inspection/equipment controls retain their owners; physical floor
# controls distinguish current admission from independent player traversal.
COVERAGE_TRANSFER = {
    "retiredPolicy": "Controller.continueFleeRoute and ordered decideThreat were replaced by shared ConflictResponse appraisal",
    "changedAssumptions": {
        "physicalCompanionFloor": "Current companion anchors require finite current bodies within the native <0.5 height boundary; loss releases FOLLOW and compatible reacquisition can restart it. PLAYERFOLLOW retains its separate traversal owner. Visual knowledge may cross floors.",
        "fellowDestination": "A fellow's private flee target or current body location does not grant the actor a route; private_fellow_destination_is_not_an_offer checks native offers instead.",
        "failedExit": "Native failure informs the next feasible response; unconditional retry of the same failed exit is superseded.",
        "distantRevokedRoute": "An owned conflict purpose reappraises lawful responses instead of silently becoming an ordinary-needs turn.",
        "crowd": "Crowd pressure triggers appraisal; its selected action remains person-specific.",
        "distantAwareness": "A distant believed threat now receives shared appraisal. Selecting watch preserves genuine ordinary native work and permits the ordinary needs caller; absence of appraisal is no longer sufficient evidence of continuity.",
        "crossingAwareness": "An in-flight native crossing retains physical custody while the person updates conflict appraisal. A selected response does not establish another executor admission.",
        "recognizedRisk": "The previous threshold-only pathogen fixture now loads the actual private risk producer. At fixed distance, route and values, personally recognized danger changes the argument and native response; appraisal grants no encounter experience.",
    },
    "controls": {
        "missing_hold": "shared_hold / roused_shared_route_not_restarted",
        "held_consequences": "conflict_response_test.py: held_conflict_route_keeps_cry_consequences; flee_conflict_cases.lua: retained_route_injury_records_hearers",
        "held_player_arrival": "held_player_arrival / held_route_records_player_arrival",
        "held_cry_expiry": "held_cry_expiry / held_route_closes_cry_window",
        "distant_starvation": "distant_HOMEWARD_reaches_needs and other ordinary-route states",
        "distant_route_cancellation": "distant_HOMEWARD_preserves_unrelated_route and other ordinary-route states",
        "distant_false_clear": "distant_false_clear / distant_belief_is_not_clear",
        "distant_delayed_needs": "distant_delayed_needs / old_alert_reaches_needs_same_turn",
        "distant_reconciliation_bypass": "distant_reconciliation_bypass / reconciliation_keeps_ownership",
        "distant_retreat_discarded": "beyond_trigger_keeps_current_shared_route and beyond_trigger_reappraises_revoked_route",
        "unconditional_hold": "new_threat_rejects_route_through_contact",
        "finished_hold": "native_finish_lost / native_terminal_attempt_consumed",
        "wrong_floor": "changed_floor_reappraises_shared_route",
        "wrong_body": "conflict_response_test.py: foreign_body_token_cannot_dispatch, drop_settles_admitted_conflict, readoption_keeps_unique_attempt_identity",
        "permission": "shared_route_permission / revoked_route_retires_exact_owner",
        "invalid_route_reused": "revoked_route_retires_exact_owner and private_fellow_destination_is_not_an_offer",
        "arrival_slack": "near_native_center_keeps_shared_route",
        "tile_corner": "near_native_center_keeps_shared_route",
    },
    "preservedCases": "Companion/player follow, anchor/body ownership, crossing, equipment deadline, source reconciliation, inspection and forage-refusal coverage remains in PROBE. Companion cross-floor expectations now assert physical release/reacquisition; player floor routing remains distinct. Quantized route-floor and exact physical-threshold controls execute independently.",
    "nativeBoundary": "Native admission, local observation and verdict receivers are controlled; no rendered-world acceptance.",
}

FLIGHT_CONTROLS = (
    ("older_same_track_retained", "perception", "if not newer and (belief.z == nil or belief.z == fromZ) then",
     "if (belief.z == nil or belief.z == fromZ) then", "latest_continuous_track_supersedes_older_location"),
    ("same_track_filtered_before_precedence", "perception",
     'if belief.source == "observed" and type(belief.track) == "string" and belief.track ~= "" then',
     'if belief.source == "observed" and type(belief.track) == "string" and belief.track ~= "" and (belief.z == nil or belief.z == fromZ) then',
     "same_track_precedence_precedes_floor_filter"),
    ("other_believed_threat_omitted", "response", "for _,contact in ipairs(contacts) do",
     "for _,contact in ipairs({}) do", "new_private_contact_revises_actual_route"),
    ("other_threat_consequence_omitted", "response",
     'or approachesBelievedThreat and {"exposure","bodily-harm","approaches-another-believed-threat"}',
     'or approachesBelievedThreat and {"exposure"}', "new_private_contact_revises_actual_route"),
    ("contact_freshness_omitted", "perception", "and tick >= belief.at and tick - belief.at <= horizon",
     "and true", "expired_contact_does_not_change_escape"),
    ("contact_floor_omitted", "perception", "if not newer and (belief.z == nil or belief.z == fromZ) then",
     "if not newer then", "other_floor_contact_does_not_change_escape"),
    ("contact_sound_promoted", "perception", 'or belief.source == "heard" and belief.phantom == true) then',
     'or belief.source == "heard") then', "unidentified_sound_contact_does_not_change_escape"),
    ("contact_person_replaced", "response", "SAO.Perception.believedZombieContacts(id,tick,bx,by,bz)",
     'SAO.Perception.believedZombieContacts("fellow",tick,bx,by,bz)', "new_private_contact_revises_actual_route"),
    ("shared_hold", "response", "if action.job then", "if false then", "roused_shared_route_not_restarted"),
    ("native_finish_lost", "response", "if not job.done then return false end", "if true then return false end", "native_terminal_attempt_consumed"),
    ("shared_route_permission", "response", "available=not blocked and allowed", "available=not blocked", "revoked_route_retires_exact_owner"),
    ("distant_false_clear", "controller", 'and string.format("continues with believed threat at %.1f tiles", threat.dist)', 'and "believes clear"', "distant_belief_is_not_clear"),
    ("distant_delayed_needs", "controller", 'if not threat then return end', 'return', "old_alert_reaches_needs_same_turn"),
    ("distant_reconciliation_bypass", "controller", 'if not setState(agent, id, "IDLE", reason) then return end', 'setState(agent, id, "IDLE", reason)', "reconciliation_keeps_ownership"),
    ("held_player_arrival", "controller", "            agent.playerCame = true\n", "            agent.playerCame = false\n", "held_route_records_player_arrival"),
    ("held_cry_expiry", "controller", "if agent.criedAt and tick > agent.criedAt + 1800 then", "if false then", "held_route_closes_cry_window"),
    ("distant_appraisal_gate", "response",
     '    if SAO.Controller.appraiseCoordination then SAO.Controller.appraiseCoordination(id,body,agent.state) end',
     '    if threat.dist>fleeAt and count<SAO.Disposition.overwhelmThreshold(id) and not agent.conflictRoute then return false end\n'
     '    if SAO.Controller.appraiseCoordination then SAO.Controller.appraiseCoordination(id,body,agent.state) end',
     "distant_HOMEWARD_retains_private_appraisal"),
    ("watch_destroys_ordinary_work", "response",
     'if decision.kind=="watch" and not agent.conflictRoute and not agent.conflictCoordination',
     'if false and decision.kind=="watch" and not agent.conflictRoute and not agent.conflictCoordination',
     "distant_HOMEWARD_reaches_needs"),
    ("crossing_appraisal_gate", "response",
     '    local decision=SAO.ProceduralPlanning.planConflict(id,frame,offers)',
     '    if nativeCrossing(SAO.Locomotion.jobs[id],body) then return true end\n'
     '    local decision=SAO.ProceduralPlanning.planConflict(id,frame,offers)',
     "crossing_retains_private_appraisal"),
    ("recognized_risk_intake_lost", "response",
     'form=threat.form,formPerformance=threat.formPerformance,attributeMutations=threat.attributeMutations',
     'form=nil,formPerformance=nil,attributeMutations=nil',
     "recognized_risk_changes_actual_response"),
)

# Recovery now uses the same native state names. These controls still mutate
# only their original follow owner, not an unrelated recovery boundary.
CONTROL_SCOPES = {name: ("local function continueOwnedFollowCrossing(", "local function orderBesideFollow(")
                  for name in ("crossing_legacy_flag_only", "crossing_window_state_missing", "crossing_state_substring")}


def main(argv=None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--production-only", action="store_true")
    parser.add_argument("--suite", choices=("all", "preserved", "conflict"), default="all")
    parser.add_argument("--control", action="append", default=[],
                        help="Run only the named control(s), retaining the selected production baseline(s).")
    parser.add_argument("--output-dir", type=Path)
    args = parser.parse_args(argv)
    known_controls = {row[0] for row in CONTROLS} | {row[0] for row in FLIGHT_CONTROLS}
    if set(args.control) - known_controls:
        parser.error("unknown control: " + ", ".join(sorted(set(args.control) - known_controls)))
    if args.control and args.production_only:
        parser.error("--control requires defect controls")
    jar = GAME / "projectzomboid.jar"
    required = [jar, GAME / "stdlib.lua", JDK / "java.exe", JDK / "javac.exe"]
    if not all(path.is_file() for path in required):
        print("Flee continuity SKIPPED: installed engine VM or JDK absent")
        return 0
    stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S-%fZ")
    out = args.output_dir or ROOT / "_scratch/d1-shared-reasoning/conflict/flee-migration" / stamp
    out.mkdir(parents=True, exist_ok=True)
    files = {"controller": CONTROLLER, "locomotion": LOCOMOTION, **CONFLICT_FILES, "flight": FLIGHT_CASES}
    paths = [*files.values(), Path(__file__), RUNNER, jar, GAME / "stdlib.lua"]
    pins = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    source = {key: path.read_text(encoding="utf-8-sig") for key, path in files.items()}
    receipt = {"schema": "sao-flee-conflict-migration-proof/1", "at": stamp, "status": "INCOMPLETE",
               "suite": args.suite, "productionOnly": args.production_only, "inputs": pins,
               "coverageTransfer": COVERAGE_TRANSFER, "selectedControls": args.control, "variants": []}
    def save():
        (out / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    def invoke(command, name):
        code, output = execute(list(map(str, command)), out)
        (out / (name + ".log")).write_bytes(output.encode("utf-8"))
        return code, output, {"command": list(map(str, command)), "exit": code,
            "logSha256": hashlib.sha256(output.encode()).hexdigest()}
    save()
    try:
        code, output, row = invoke([JDK / "javac.exe", "-cp", jar, "-d", out, RUNNER], "compile")
        receipt["compile"] = row
        if code: raise RuntimeError("compiling Kahlua instrument\n" + output)
        shutil.copy2(GAME / "stdlib.lua", out / "stdlib.lua")
        # Imports retain PRELUDE and EXPOSE; require is local to this isolated VM.
        (out / "prelude.lua").write_text(PRELUDE + "\nrequire=function() end\n"
            "__fixturePerception={}\nfor key,value in pairs(SAO.Perception) do __fixturePerception[key]=value end\n",
            encoding="utf-8")
        (out / "probe.lua").write_text(PROBE, encoding="utf-8")
        variants = []
        if args.suite in ("all", "preserved"):
            variants.append(("preserved-production", "preserved", None, None, None, None))
            if not args.production_only:
                variants += [(name, "preserved", "controller", old, new, reason) for name, old, new, reason in CONTROLS]
        if args.suite in ("all", "conflict"):
            variants.append(("conflict-production", "conflict", None, None, None, None))
            if not args.production_only:
                variants += [(name, "conflict", key, old, new, reason) for name, key, old, new, reason in FLIGHT_CONTROLS]
        if args.control:
            available = {variant[0] for variant in variants if variant[2]}
            if set(args.control) - available:
                raise RuntimeError("requested control is outside the selected suite")
            variants = [variant for variant in variants if not variant[2] or variant[0] in args.control]
        for name, suite, key, before, after, target in variants:
            texts = dict(source)
            if key:
                begin, end = 0, len(texts[key])
                if name in CONTROL_SCOPES:
                    first, last = CONTROL_SCOPES[name]
                    begin = texts[key].index(first)
                    end = texts[key].index(last, begin)
                owned = texts[key][begin:end]
                if owned.count(before) != 1:
                    raise RuntimeError(f"production control seam differs: {name} ({owned.count(before)})")
                texts[key] = texts[key][:begin] + owned.replace(before, after, 1) + texts[key][end:]
            if texts["controller"].count("return Ctl\n") != 1:
                raise RuntimeError("controller probe exposure seam differs")
            texts["controller"] = texts["controller"].replace("return Ctl\n", EXPOSE)
            for filename, text in texts.items():
                (out / (filename + ".lua")).write_text(text, encoding="utf-8")
            modules = (["locomotion", "controller", "probe"] if suite == "preserved" else
                       [*CONFLICT_FILES, "locomotion", "controller", "flight"])
            command = [JDK / "java.exe", "-cp", os.pathsep.join([str(jar), str(out)]), "LuaRun",
                       "prelude.lua", *[module + ".lua" for module in modules], "--", "__result"]
            code, output, row = invoke(command, name)
            row.update(name=name, suite=suite, target=target)
            receipt["variants"].append(row);save()
            if key:
                if code == 0 or "FLEE_CHECK:" + target not in output:
                    raise RuntimeError(f"control {name} did not fail for {target}\n{output[-5000:]}")
            elif code or "VALUE PASS " not in output:
                raise RuntimeError(f"production {suite}\n{output[-6000:]}")
            else:
                cases = output.split("VALUE PASS ", 1)[1].strip().split(",")
                row["checks"] = len(cases);row["checkNames"] = sorted(set(cases));save()
            print(f"PASS {name}" + (f": {row['checks']} checks" if "checks" in row else f": rejected {target}"), flush=True)
        receipt["inputsAfter"] = {p: hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in pins}
        receipt["changedInputs"] = [p for p in pins if pins[p] != receipt["inputsAfter"][p]]
        if receipt["changedInputs"]: raise RuntimeError("inputs changed during proof")
        receipt["status"] = "PASS";save()
        print(f"Border 199 PASS: {len(variants)} selected variants; receipt {out / 'receipt.json'}")
        return 0
    except Exception as error:
        receipt["status"] = "FAIL";receipt["error"] = str(error);save()
        print("FAIL flee continuity:", error, flush=True)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
