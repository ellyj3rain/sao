#!/usr/bin/env python3
"""Border 199: real Controller + Locomotion retain valid executing routes.

Only the native movement receiver and external belief/needs inputs are
fixtures. The full production modules update movement before follow decisions,
rouse company, order, cancel, and consume terminal movement verdicts.
This is not a rendered-world test.
"""
from __future__ import annotations

import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
CONTROLLER = ROOT / "mod/42.20/media/lua/client/SAO_Controller.lua"
LOCOMOTION = ROOT / "mod/42.20/media/lua/client/SAO_Locomotion.lua"
GAME = Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
JDK = Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
RUNNER = ROOT / "tools/luacheck/LuaRun.java"

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
function SAO.Perception.nearestBelievedZombie() return __threat end
function SAO.Perception.believedThreatCount() return __threat and 1 or 0 end
function SAO.Perception.hasLookedRecently() return true end
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
local function decide(a,b,roused)
 __tick=__tick+1;SAO.Controller.__fleeProbeTick(__tick)
 if roused then
  a.nextDecisionAt=__tick+999
  SAO.Controller.__fleeProbeRouse('fellow',__bodies.fellow)
  check('rousing_reopens_decision',a.nextDecisionAt==0)
 end
 if __tick >= a.nextDecisionAt then
  a.nextDecisionAt=__tick+100
  SAO.Controller.__fleeProbeDecide('runner',a,b)
 end
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
 decide(a,b,false)
 check('initial_escape_owned',__starts==1 and a.state=='FLEE' and SAO.Locomotion.jobs.runner.goal.x==10)
 SAO.Locomotion.tick('runner')
 return a,b,SAO.Locomotion.jobs.runner
end

local a,b,job=fresh()
__fellows={'fellow'}
for _,x in ipairs({1.5,2.5,4.5,6.5}) do
 b.x=x;__bodies.fellow.x=30+x;__bodies.fellow.y=3+x
 decide(a,b,true)
 check('roused_safe_route_not_restarted',__starts==1 and __cancels==0
  and SAO.Locomotion.jobs.runner==job and a.fleeTargetX==job.goal.x)
end
check('repeated_rousing_executed',__tells>=4)
b.x=8.5;decide(a,b,true)
check('near_arrival_route_not_replaced',__starts==1 and SAO.Locomotion.jobs.runner==job)
b.x=10.05;decide(a,b,true)
check('native_center_route_not_replaced',__starts==1 and SAO.Locomotion.jobs.runner==job)

-- Becoming hurt is independent of replacing the current escape. The native
-- cry owner records actual hearers, then the retained route must keep both
-- player-arrival sampling and expiry accounting alive.
a,b,job=fresh();__injury=4;__player=body(20.5,.5,0)
decide(a,b,true)
check('mid_route_injury_still_calls',__shouts==1 and a.criedAt==__tick
 and #a.criedHeard==2 and __starts==1 and SAO.Locomotion.jobs.runner==job)
local criedAt=a.criedAt
__player.x=.5;decide(a,b,true)
check('held_route_records_player_arrival',a.playerCame==true and __shouts==1)
__player.x=30.5;__injury=0;__tick=criedAt+1800;decide(a,b,true)
check('held_route_closes_cry_window',a.criedAt==nil and a.criedHeard==nil
 and __trust.fellow==-.1 and __trust['player:test']==nil
 and __starts==1 and SAO.Locomotion.jobs.runner==job)

for _,verdict in ipairs({'FailedObstacle:FAILED_BLOCKED_DIAGONAL',
 'FailedObstacle:FAILED_UNLOADED_NEXT_SQUARE','Succeeded','IDLE','TICK_FAILED fixture'}) do
 a,b,job=fresh();__verdict=verdict;SAO.Locomotion.tick('runner')
 check('terminal_verdict_consumed',job.done==true)
 decide(a,b,true)
 check('terminal_route_reconsidered',__starts==2 and SAO.Locomotion.jobs.runner~=job)
end

a,b,job=fresh();__threat={x=5,y=.5,dist=4.5,source='observed'}
decide(a,b,true)
check('new_threat_changes_escape',__starts==2
 and SAO.Locomotion.jobs.runner.goal.x<0)

a,b,job=fresh();__forbidden['10,0']=true;__fellows={'fellow'}
__bodies.fellow.x=11.5;decide(a,b,true)
check('forbidden_nearby_route_retired',__starts==2 and __cancels==1
 and SAO.Locomotion.jobs.runner~=job and SAO.Locomotion.jobs.runner.goal.x==11)

a,b,job=fresh();b.z=1;decide(a,b,true)
check('changed_floor_reconsidered',__starts==2 and __cancels==1
 and SAO.Locomotion.jobs.runner.goal.z==1)

a,b,job=fresh();local replacement=body(.5,.5,0)
__bodies.runner=replacement;decide(a,replacement,true)
check('replacement_body_gets_own_route',__starts==2 and SAO.Locomotion.jobs.runner.body==replacement)

a,b,job=fresh();__threat=nil;decide(a,b,true)
check('clear_belief_releases_flee',a.state=='IDLE' and __starts==1
 and __cancels==1 and SAO.Locomotion.jobs.runner==nil)

a,b,job=fresh();__blockAll=true;decide(a,b,true)
check('forbidden_escape_holds',a.state=='ALERT' and __starts==1
 and __cancels==1 and SAO.Locomotion.jobs.runner==nil)

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
 check('follow_anchor_floor_reconsidered',__starts==2 and __cancels==1
  and SAO.Locomotion.jobs.runner.goal.z==1)

 a,b,job,anchor=freshFollow(player);b.z=1
 followDecide(a,b,player,false)
 check('follow_body_floor_reconsidered',__starts==2 and __cancels==1
  and SAO.Locomotion.jobs.runner~=job)

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

 -- Equal x/y on another level is not "beside" the anchor. Keep a real
 -- route to their floor, then stop only after reaching that same floor.
 a,b,job,anchor=freshFollow(player)
 anchor.x=b.x;anchor.y=b.y;anchor.z=1
 followDecide(a,b,player,false)
 local upstairs=SAO.Locomotion.jobs.runner
 check(player and 'player_close_other_floor_keeps_route' or 'companion_close_other_floor_keeps_route',
  __starts==2 and __cancels==1 and upstairs and upstairs~=job
  and upstairs.goal.z==1 and a.state==(player and 'PLAYERFOLLOW' or 'FOLLOW'))
 followDecide(a,b,player,false)
 check('close_other_floor_route_not_restarted',__starts==2 and SAO.Locomotion.jobs.runner==upstairs)
 b.z=1;followDecide(a,b,player,false)
 check('same_floor_close_gap_stops',__starts==2 and __cancels==2
  and SAO.Locomotion.jobs.runner==nil and a.state=='IDLE' and not upstairs.done)
end

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
__result='PASS '..table.concat(checks,',')
'''

CONTROLS = (
    ("missing_hold", "if continueFleeRoute(id, agent, body, bx, by, dx, dy, len) then",
     "if false then", "roused_safe_route_not_restarted"),
    ("held_consequences", "                advanceFleeConsequences(id, agent, body, tick)\n                return true",
     "                return true", "mid_route_injury_still_calls"),
    ("held_player_arrival", "            agent.playerCame = true\n",
     "            agent.playerCame = false\n", "held_route_records_player_arrival"),
    ("held_cry_expiry", "if agent.criedAt and tick > agent.criedAt + 1800 then",
     "if false then", "held_route_closes_cry_window"),
    ("unconditional_hold", "goal.z == math.floor(body:getZ()) and away",
     "goal.z == math.floor(body:getZ())", "new_threat_changes_escape"),
    ("finished_hold", 'or not job or job.done', 'or not job', "terminal_route_reconsidered"),
    ("wrong_floor", "goal.z == math.floor(body:getZ()) and away", "away", "changed_floor_reconsidered"),
    ("wrong_body", "or job.body ~= body or not job.goal", "or not job.goal", "replacement_body_gets_own_route"),
    ("permission", "and mayEnterBelieved(id, goal.x, goal.y)", "", "forbidden_nearby_route_retired"),
    ("invalid_route_reused", "SAO.Locomotion.cancel(id)\n    return false\nend\n\nlocal function advanceFleeConsequences",
     "return false\nend\n\nlocal function advanceFleeConsequences", "forbidden_nearby_route_retired"),
    ("arrival_slack", "local away = remaining ~= 0 and", "local away = remaining >= ARRIVAL_REACH and",
     "near_arrival_route_not_replaced"),
    ("tile_corner", "math.floor(goal.x)) + 0.5", "math.floor(goal.x))", "native_center_route_not_replaced"),
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
     "companion_close_other_floor_keeps_route"),
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


def main() -> int:
    jar = GAME / "projectzomboid.jar"
    required = [jar, GAME / "stdlib.lua", JDK / "java.exe", JDK / "javac.exe"]
    if not all(path.is_file() for path in required):
        print("Flee continuity SKIPPED: installed engine VM or JDK absent")
        return 0
    source = CONTROLLER.read_text(encoding="utf-8-sig")
    locomotion = LOCOMOTION.read_text(encoding="utf-8-sig")
    with tempfile.TemporaryDirectory(prefix="sao-flee-continuity-") as temporary:
        work = Path(temporary)
        code, output = execute([str(JDK / "javac.exe"), "-cp", str(jar), "-d", str(work), str(RUNNER)], work)
        if code:
            print("FAIL compiling Kahlua instrument\n" + output)
            return 1
        shutil.copy2(GAME / "stdlib.lua", work / "stdlib.lua")
        (work / "prelude.lua").write_text(PRELUDE, encoding="utf-8")
        (work / "locomotion.lua").write_text(locomotion, encoding="utf-8")
        (work / "probe.lua").write_text(PROBE, encoding="utf-8")

        def probe(text: str) -> tuple[int, str]:
            if text.count("return Ctl\n") != 1:
                raise AssertionError("controller probe exposure seam differs")
            (work / "controller.lua").write_text(text.replace("return Ctl\n", EXPOSE), encoding="utf-8")
            return execute([str(JDK / "java.exe"), "-cp", os.pathsep.join([str(jar), str(work)]), "LuaRun",
                "prelude.lua", "locomotion.lua", "controller.lua", "probe.lua", "--", "__result"], work)

        code, output = probe(source)
        if code or "VALUE PASS " not in output:
            print("FAIL production flee/follow continuity\n" + output)
            return 1
        print("PASS real Kahlua Controller + Locomotion: movement-update/decision lifecycle, FLEE, companion/player FOLLOW, ROAM entry, rousing, changing owners/targets/floors/permission, terminal verdicts, player crossing, injury, and cry response", flush=True)
        for name, old, new, reason in CONTROLS:
            if source.count(old) != 1:
                print(f"FAIL production control seam differs: {name} ({source.count(old)})")
                return 1
            code, output = probe(source.replace(old, new))
            if not code or "FLEE_CHECK:" + reason not in output:
                print(f"FAIL production control {name} did not fail for {reason}\n{output}")
                return 1
            print(f"PASS rejected {name}: {reason}")
    print(f"Border 199 PASS: flee/follow continuity; {len(CONTROLS)} production-source controls; native world execution remains separate")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
