#!/usr/bin/env python3
"""Private residence deliberation and native movement ownership in installed Kahlua.

The full production decision, Standing, planning and movement modules execute.
Bodies, current squares, perception inputs and movement receiver outcomes are
controlled. This does not establish navigation or behavior in a rendered save.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile

import flee_continuity_test as fixture

ROOT = Path(__file__).resolve().parents[1]
LUA = ROOT / 'mod/42.20/media/lua'
FILES = {
    'perception': LUA / 'shared/SAO_Perception.lua',
    'world': LUA / 'shared/SAO_WorldSources.lua',
    'standing': LUA / 'shared/SAO_Standing.lua',
    'labor': LUA / 'shared/SAO_Labor.lua',
    'planner': LUA / 'shared/SAO_ProceduralPlanning.lua',
    'locomotion': LUA / 'client/SAO_Locomotion.lua',
    'dormant': LUA / 'client/SAO_DormantPopulation.lua',
    'controller': LUA / 'client/SAO_Controller.lua',
    'harness': LUA / 'client/SAO_Harness.lua',
}

SETUP = r'''
require=function() end
local stores={}
ModData={getOrCreate=function(key) stores[key]=stores[key] or {} return stores[key] end,
    get=function(key) return stores[key] end}
__records={}
SAO.Identity={get=function(id) return __records[tostring(id)] end,
    all=function() return __records end,beliefKey=function(r) return r.id end,
    idByName=function(name) return __records[name] and name or nil end,
    updatePosition=function(r,x,y,z) r.x=x r.y=y r.z=z end}
SAO.Census={skillOf=function() return 0 end}
SAO.Places={at=function() return {id=1} end}
SAO.History.countyHours=function() return __hours end
SAO.History.countyTimeOfDay=function() return __hour end
SAO.History.recordDay=function() return 1 end
SAO.History.ticks=function() return __tick end
SAO.Disposition.traits=function() return {nerve=.6,initiative=.5} end
SAO.Disposition.drinkAt=function() return .4 end
SAO.Needs.read=function() return __needs end
SAO.Needs.busy=function() return __busy==true end
SAO.Needs.findGear=function() return nil end
SAO.Needs.needsAmmo=function() return false end
SAO.Needs.bleeding=function() return __bleeding or 0 end
SAO.Needs.bandageSelf=function() return __bandage==true end
SAO.Disposition.wouldCry=function() return false end
SAOJavaBridge.findCarriedFood=function() return __food end
SAOJavaBridge.findCarriedDrink=function() return __drink end
SAOJavaBridge.setShellAsleep=function() return true end
SAOJavaBridge.canSeePersonNow=function() return __personVisible==true end
SAOJavaBridge.perceive=function() return __seen or '' end
SAOJavaBridge.isShell=function() return true end
SAOJavaBridge.worldInspectionMemory=function(_,body)
    __inspectionMemory[body]=__inspectionMemory[body] or {} return __inspectionMemory[body]
end
SAOJavaBridge.worldInspectionCandidates=function() return __holders or 'H|protocol=SAOWI1\nE\n' end
SAO.Body.isTransitioning=function() return false end
Events.OnFillWorldObjectContextMenu.Add=function(fn) __fillMenu=fn end
SAOJavaBridge.setForceEntry=function(_,body,allowed)
    if __forceThrow then error("permission receiver unavailable") end
    if __forceRefuse then return false end
    body.forceEntry=allowed;return true
end
SAOJavaBridge.moveTo=function(_,body,x,y,z)
    __orderedForce=body.forceEntry
    __starts=__starts+1
    if __refuseNativeMove then return 'MOVE_REFUSED_LOCKED' end
    __ordered={x=x,y=y,z=z} return 'MOVE_STARTED'
end
SAOJavaBridge.tickMove=function() return __verdict end
SAOJavaBridge.moveBarrier=function() return __barrier or 'MOVE_BARRIER_UNAVAILABLE' end
SAO.Organization={offices={},activeCommitments=function(id) return __commitments[id] or {} end,
    leave=function() return true end,
    raiseMatter=function(id,kind) __withdrawals=__withdrawals+1 return {id='withdrawal',revision=1} end,
    closeMatter=function() return true end}
SAO.Communication={canConverse=function() return false end}
GameTime={getInstance=function() return {getTimeOfDay=function() return __hour end} end}
getGameTime=function() return GameTime.getInstance() end
function __resetStores() stores={} end
'''

CASES = r'''
local checks={}
local function empty(value) for _ in pairs(value) do return false end return true end
local function size(value) local n=0 for _ in pairs(value) do n=n+1 end return n end
local function check(name,ok)
    __residencePhase=name
    checks[#checks+1]=name..'='..tostring(ok==true)
    __residencePartial=table.concat(checks,'\n')
    if not ok then error('RESIDENCE:'..name) end
end
local C,P,S,L,D=SAO.Controller,SAO.ProceduralPlanning,SAO.Standing,SAO.Labor,SAO.DormantPopulation
local home={cx=10,cy=10,z=0,minX=5,minY=5,maxX=15,maxY=15,at=0,visits=3,source='lived-home'}
local lead={cx=100,cy=10,z=0,minX=95,minY=5,maxX=105,maxY=15,at=0,visits=1,source='observed-building'}
local function body(id,x,y)
    local b={id=id,x=x,y=y,z=0,building=1,md={SAOPersonId=id}}
    function b:getX() return self.x end
    function b:getY() return self.y end
    function b:getZ() return self.z end
    function b:getModData() return self.md end
    function b:isDead() return self.dead==true end
    function b:isAsleep() return self.asleep==true end
    function b:isExistInTheWorld() return self.attached~=false end
    function b:getVehicle() return nil end
    function b:setSitOnGround() end
    function b:getPrimaryHandItem() return nil end
    function b:getUsername() return 'test' end
    function b:getBodyDamage() return {getOverallBodyHealth=function() return 100 end} end
    function b:getCurrentSquare()
        return {isOutside=function() return self.building==nil end,getBuildingDef=function()
            if not self.building then return nil end
            return {getID=function() return self.building end}
        end}
    end
    return b
end
local function reset(hunger)
    __resetStores()
    __hours=2 __hour=12 __tick=18000 __starts=0 __cancels=0 __verdict='Working' __barrier=nil
    __randCalls=0 __randFixed=0 __forceThrow=false __forceRefuse=false __orderedForce=nil
    __withdrawals=0 __commitments={} __refuseNativeMove=false __busy=false __food=nil __drink=nil
    SAO.Organization.offices={}
    __personVisible=true
    __seen='' __holders=nil __inspectionMemory={}
    __bleeding=0 __bandage=false
    __forbidden={} __blockAll=false __group=nil __fellows={} __player=nil __injury=0
    __needs={hunger=hunger or .8,thirst=.1,fatigue=.25,endurance=.8}
    __records={a={id='a',homeX=10,homeY=10,homeZ=0,x=10,y=10,z=0},
        b={id='b',homeX=300,homeY=300,homeZ=0},c={id='c',homeX=200,homeY=200,homeZ=0}}
    local b=body('a',10,10)
    __bodies={a=b,b=body('b',300,300),c=body('c',200,200)}
    SAO.Body.active=__bodies SAO.Body.foreign={}
    C.agents={a={state='IDLE',rec=__records.a},b={state='IDLE',rec=__records.b}}
    SAO.Perception.beliefs={a={known={[1]=home,[2]=lead},zombies={},people={},places={},factions={},lastScanAt=0,scanCount=0},
        b={known={[1]=home},zombies={},people={},places={},factions={},lastScanAt=0,scanCount=0}}
    SAO.Locomotion.jobs={}
    C.__residenceTick(__tick)
    return C.agents.a,b
end
local function consider(a,b)
    __tick=math.floor(__hours*9000) C.__residenceTick(__tick)
    return C.considerResidence('a',a,b,__tick)
end
local function conflict()
    local store=ModData.getOrCreate('SurvivorAwareness_Standing')
    store.groups={a='house',b='house',c='house'}
    store.groupMeta={house={leaderId='b'}}
    store.relations={a={b={hostile=true,trust=-.8}}}
    SAO.Organization.offices['house:chair']={holders={b={commitmentId='accepted-chair'}}}
end
local function arrive(a,b)
    b.x=100 b.y=10 b.building=2
    local job=SAO.Locomotion.jobs.a
    job.done=true job.result='arrived'
    return C.finishResidenceMovement('a',a,b)
end
local a,b=reset()
local p=consider(a,b)
check('starving_with_energy_selects_unknown_stock_search',p.mode=='search' and p.destination.id=='2'
    and p.destination.stock=='unknown-until-private-inspection')
check('private_lead_is_not_global_supply_knowledge',L.assessResidence('b',{tick=__tick,atHours=2,
    position={x=300,y=300,z=0},needs=__needs}).candidates[1].id=='1')
check('own_appraisal_remains_detached',p.appraisal~=SAO.Perception.beliefs.a.known
    and p.destination~=lead and lead.sources==nil)
local nativeStarted=C.advanceResidencePurpose('a',a,b,__tick)
check('search_enters_existing_native_locomotion',nativeStarted and a.state=='TRAVEL'
    and p.admission and SAO.Locomotion.jobs.a.body==b and __starts==1)
local route=SAO.Locomotion.jobs.a
local retainedStep=p.steps[1]
for index=1,50 do __hours=2+index*.01 consider(a,b) end
check('deliberation_does_not_reset_executing_route',SAO.Locomotion.jobs.a==route and __starts==1
    and p.admission~=nil and a.state=='TRAVEL' and p.steps[1]==retainedStep)
check('departure_is_not_required_for_search',__records.a.homeX==10 and __records.b.homeX==300)
local target,journey=D.residenceDestination('a',__records.a)
check('unload_preserves_search_and_no_forced_return',journey and target.cx==100)
arrive(a,b)
check('search_arrival_does_not_grant_stock_or_new_home',lead.sources==nil and __records.a.homeX==10
    and p.lastResidenceResult.stock=='unknown-until-private-inspection' and not p.admission)
__hour=23
C.__residenceHome('a',a,b,__tick,__records.a)
check('dusk_does_not_override_selected_search',a.state=='IDLE' and __starts==1)

a,b=reset(.05)
__hour=23 b.x=30 b.building=nil
p=consider(a,b)
check('ordinary_low_needs_allow_voluntary_return',p.mode=='return' and p.destination.cx==10)
check('return_routes_to_own_remembered_address',C.advanceResidencePurpose('a',a,b,__tick)
    and SAO.Locomotion.jobs.a.goal.x==10)

a,b=reset(.05) conflict()
local x,y,z=C.__residenceAddress('a',__records.a)
check('leader_address_is_not_inherited_knowledge',x==10 and y==10 and z==0)
p=consider(a,b)
check('personally_experienced_conflict_can_choose_departure',p.mode=='depart' and p.destination.id=='2')
check('departure_deliberation_does_not_rehome_anyone',__records.a.homeX==10 and __records.b.homeX==300)
check('departure_admits_native_route_and_owned_withdrawal',C.advanceResidencePurpose('a',a,b,__tick)
    and __withdrawals==1 and S.groupOf('a')==nil and S.groupOf('b')=='house')
check('even_selected_departure_needs_actual_indoor_arrival',not S.completeResidence('a',b,p.destination)
    and __records.a.homeX==10)
arrive(a,b)
check('actual_arrival_changes_only_actor_residence',__records.a.homeX==100 and __records.b.homeX==300
    and __records.c.homeX==200 and #__records.a.residenceHistory==1)
check('new_residence_requires_no_personal_or_group_claim',S.claimOf('a')==nil and S.groupClaimOf('house')==nil
    and __records.a.residenceHistory[1].x==10)
local history=__records.a.residenceHistory
check('repeated_arrival_is_idempotent',S.completeResidence('a',b,{id='2',cx=100,cy=10,z=0})
    and #history==1)
__hours=3 __hour=23 a.nextResidenceAt=0
p=consider(a,b)
check('new_home_is_retained_after_departure',p.mode=='stay' and __records.a.homeX==100)

a,b=reset() a.state='COOK' __records.a.cookingWork={id='native-cook'} conflict()
__busy=true
p=consider(a,b)
check('strategic_deliberation_coexists_with_native_work',p.mode=='depart' and a.state=='COOK'
    and __records.a.cookingWork.id=='native-cook' and __starts==0 and __cancels==0)
check('strategic_choice_does_not_replace_busy_owner',not C.advanceResidencePurpose('a',a,b,__tick)
    and __records.a.cookingWork~=nil)

a,b=reset() p=consider(a,b)
__refuseNativeMove=true
check('actual_native_lock_refusal_cannot_become_arrival',not C.advanceResidencePurpose('a',a,b,__tick)
    and not p.admission and __records.a.homeX==10 and p.status=='blocked')
for index=1,20 do __hours=2+index*.004 C.advanceResidencePurpose('a',a,b,__tick+index) end
check('repeated_decisions_honor_exact_route_retry',__starts==1 and not p.admission)
target,journey=D.residenceDestination('a',__records.a)
check('unloaded_blocked_route_respects_same_retry',journey and target.cx==__records.a.x and target.cx~=100)
__hours=2.1 a.nextResidenceAt=0 consider(a,b)
check('failed_native_route_is_not_immediately_repeated',p.mode=='stay' and __starts==1)

a,b=reset() p=consider(a,b) __refuseNativeMove=true C.advanceResidencePurpose('a',a,b,__tick)
SAO.Perception.beliefs.a.known[3]={cx=60,cy=20,z=0,minX=55,minY=15,maxX=65,maxY=25,at=__tick,visits=1,source='observed'}
__hours=2.11 a.nextResidenceAt=0 __refuseNativeMove=false consider(a,b)
check('failed_target_does_not_block_another_private_lead',p.destination.id=='3'
    and C.advanceResidencePurpose('a',a,b,__tick) and __starts==2)

a,b=reset() p=consider(a,b) C.advanceResidencePurpose('a',a,b,__tick)
local saved=__records.a.proceduralPlanning
SAO.Locomotion.jobs={} a.residenceRoute=nil __hours=2.2 a.nextResidenceAt=0
consider(a,b)
check('reload_retains_purpose_without_false_native_completion',__records.a.proceduralPlanning==saved
    and P.residencePurpose('a')==p and p.admission==nil and p.lastResidenceResult==nil)

a,b=reset() conflict() p=consider(a,b) C.advanceResidencePurpose('a',a,b,__tick)
C.__residenceState(a,'a','FLEE','actual danger')
check('immediate_threat_interrupts_exact_residence_route',p.admission==nil and a.residenceRoute==nil
    and a.state=='FLEE' and p.lastResidenceResult==nil)

a,b=reset(.05)
S.claim('c',95,5,105,15,0)
check('unseen_global_claim_cannot_veto_physical_permission',S.mayTakeCurrent('a',100,10,'standing')==true)
SAO.Perception.beliefs.a.places.c={minX=95,minY=5,maxX=105,maxY=15,at=__tick,source='observed'}
check('acquired_claim_changes_own_normative_choice',S.mayTakeCurrent('a',100,10,'standing')==false
    and S.mayTakeCurrent('a',100,10,'desperate')==true)
SAO.Perception.beliefs.a.places={}
b.x=100 b.y=10 b.building=2
check('unseen_claim_does_not_block_native_residence_arrival',S.completeResidence('a',b,{id='2',cx=100,cy=10,z=0}))

a,b=reset(.05)
local stores=ModData.getOrCreate('SurvivorAwareness_Standing')
stores.groups={a='house',b='house'} stores.groupMeta={house={leaderId='b'}}
D.dormantSettle()
check('visits_do_not_create_collective_claim_or_mass_rehome',S.groupClaimOf('house')==nil
    and __records.a.homeX==10 and __records.b.homeX==300)

a,b=reset(.05)
stores=ModData.getOrCreate('SurvivorAwareness_Standing')
stores.groups={a='house',b='house'} stores.groupMeta={house={leaderId='b'}}
SAO.Organization.offices['house:chair']={holders={b={commitmentId='accepted-chair'}}}
__bodies.b.x=40 __bodies.b.y=10
C.__residenceCompany('a',a,b,__tick)
check('group_membership_gives_no_unseen_leader_position',__starts==0 and a.state=='IDLE')
SAO.Perception.beliefs.a.people.b={id='b',x=40,y=10,at=__tick,source='observed'}
__personVisible=false
C.__residenceCompany('a',a,b,__tick)
check('old_sighting_cannot_replace_current_native_visibility',__starts==0 and a.state=='IDLE')
__personVisible=true
C.__residenceCompany('a',a,b,__tick)
check('actually_seen_company_can_still_be_followed',__starts==1 and a.state=='FOLLOW' and __records.a.homeX==10)

a,b=reset(.05) conflict()
stores.relations={}
stores=ModData.getOrCreate('SurvivorAwareness_Standing')
stores.relations.a.b.hostile=true
stores.relations.a.c={trust=1}
__commitments.a={}
for index=1,8 do __commitments.a[index]={acceptedAt=1} end
p=consider(a,b)
check('conflict_can_preserve_residence_with_own_attachment_and_obligations',p.mode=='stay'
    and p.appraisal.conflict==1 and p.appraisal.responsibilities==8 and __records.a.homeX==10)

a,b=reset(.05)
a.companioning=true __player=body('player:test',100,10) __player.building=nil
local options={}
local menu={addOption=function(_,label,target,fn) options[label]=fn return {} end,
    getNew=function(self) return self end,addSubMenu=function() end}
__fillMenu(0,menu,{}) options['Claim this ground']()
check('player_claim_acquisition_does_not_rehome_companions',__records.a.homeX==10 and __records.b.homeX==300)
__fillMenu(0,menu,{}) options['Release this ground']()
check('player_claim_release_does_not_erase_companion_residence',__records.a.homeX==10)

a,b=reset(.05) __player=body('player:test',19,10)
S.claim('player:test',90,5,110,15,0) S.adjustTrust('a','player:test',.9)
SAO.Perception.beliefs.a.people.test={x=19,y=10,at=__tick,source='observed'}
C.__residenceNeeds('a',a,b,__tick,nil)
check('actual_companion_initiation_does_not_copy_player_claim',a.companioning==true and __records.a.homeX==10)

a,b=reset() p=consider(a,b) C.advanceResidencePurpose('a',a,b,__tick)
route=SAO.Locomotion.jobs.a
__tick=__tick+120 C.__residenceTick(__tick)
C.__residenceUpdate('a',a)
check('actual_live_update_keeps_quiet_residence_route',a.state=='TRAVEL' and SAO.Locomotion.jobs.a==route and p.admission~=nil)
__seen='Z:11:10:1:track:near:floor:0'
__tick=__tick+120 C.__residenceTick(__tick)
C.__residenceUpdate('a',a)
check('actual_live_acquisition_preempts_residence_for_close_threat',a.state=='FLEE'
    and a.residenceRoute==nil and p.admission==nil and p.lastResidenceResult==nil)

a,b=reset() p=consider(a,b) C.advanceResidencePurpose('a',a,b,__tick)
__bleeding=1 __bandage=true __tick=__tick+120 C.__residenceTick(__tick)
C.__residenceUpdate('a',a)
check('actual_live_treatable_bleeding_preempts_residence_route',a.state=='TREAT'
    and a.residenceRoute==nil and p.admission==nil and p.lastResidenceResult==nil)

a,b=reset()
SAO.Perception.beliefs.a.known={[1]=home}
__seen='B:42:100.0:10.5:0:99.5:10.5:door'
SAO.Perception.observe('a',b,__tick,false)
local exteriorKey=SAO.Perception.exteriorLeadKey({buildingId='42',cx=99.5,cy=10.5,z=0,
    surfaceX=100,surfaceY=10.5,kind='door'})
local acquired=SAO.Perception.knownBuildingLeads('a',__tick)
check('native_exterior_acquisition_is_private_unknown_stock',acquired[exteriorKey] and acquired[exteriorKey].cx==99.5
    and acquired[exteriorKey].surfaceX==100 and SAO.Perception.knownPlaces('a')[42]==nil
    and acquired[exteriorKey].sources==nil and empty(SAO.Perception.knownBuildingLeads('b',__tick)))
local privateLead=acquired[exteriorKey];privateLead.cx=999
check('exterior_reader_is_detached',SAO.Perception.knownBuildingLeads('a',__tick)[exteriorKey].cx==99.5)
local savedLead=SAO.Perception.beliefs.a.buildingLeads[exteriorKey]
savedLead.personId='b'
check('foreign_private_lead_record_is_not_admitted',empty(SAO.Perception.knownBuildingLeads('a',__tick)))
savedLead.personId='a' savedLead.at=__tick
p=consider(a,b)
savedLead.at=__tick+600
check('future_exterior_acquisition_is_not_admitted',empty(SAO.Perception.knownBuildingLeads('a',__tick)))
target,journey=D.residenceDestination('a',__records.a)
check('future_exterior_acquisition_cannot_drive_dormant_travel',journey and target.cx==__records.a.x
    and target.cy==__records.a.y)
savedLead.at=__tick
target,journey=D.residenceDestination('a',__records.a)
check('current_exterior_acquisition_retains_dormant_target',journey and target.cx==99.5 and target.cy==10.5)
SAO.Perception.bindPersistentStore() SAO.Perception.beliefs={} SAO.Perception.bindPersistentStore()
check('exterior_private_memory_survives_save_bind',SAO.Perception.knownBuildingLeads('a',__tick)[exteriorKey].at==__tick)
p=consider(a,b)
check('unentered_unknown_stock_lead_selects_observed_outside_approach',p.mode=='search'
    and p.destination.buildingId=='42' and p.steps[1].x==99.5 and p.destination.minX==nil)
C.advanceResidencePurpose('a',a,b,__tick)
b.x=99.5 b.y=10.5 b.building=nil route=SAO.Locomotion.jobs.a route.done=true route.result='arrived'
C.finishResidenceMovement('a',a,b)
check('outside_approach_only_proposes_bounded_native_entry',p.cursor==2 and p.steps[2].x==100.5
    and p.steps[2].basis=='observed-doorway-entry-hypothesis' and __records.a.homeX==10
    and SAO.Perception.knownPlaces('a')[42]==nil)
__hours=2.11 a.nextResidenceAt=0 consider(a,b)
check('reconsideration_preserves_pending_doorway_entry',p.cursor==2 and p.steps[1].status=='completed')
__refuseNativeMove=true C.advanceResidencePurpose('a',a,b,__tick)
check('entry_refusal_grants_no_interior_or_stock',p.status=='blocked' and SAO.Perception.knownPlaces('a')[42]==nil
    and __records.a.homeX==10)

a,b=reset()
SAO.Perception.beliefs.a.known={[1]=home}
__seen='B:42:100.0:10.5:0:99.5:10.5:door'
SAO.Perception.observe('a',b,__tick,false)
p=consider(a,b) C.advanceResidencePurpose('a',a,b,__tick)
local doorA=p.destination.id
route=SAO.Locomotion.jobs.a route.done=true route.result='FailedObstacle:FAILED_LOCKED_DOOR'
C.finishResidenceMovement('a',a,b)
local doorDeadline=p.residenceAttempts[doorA].retryAt
__hours=2.11 __tick=math.floor(__hours*9000)
__seen='B:42:102.0:10.5:0:101.5:10.5:door'
SAO.Perception.observe('a',b,__tick,false)
local doorBKey=SAO.Perception.exteriorLeadKey({buildingId='42',cx=101.5,cy=10.5,z=0,
    surfaceX=102,surfaceY=10.5,kind='door'})
acquired=SAO.Perception.knownBuildingLeads('a',__tick)
check('distinct_observed_entrances_retain_separate_private_memory',acquired[exteriorKey]~=nil and acquired[doorBKey]~=nil)
a.nextResidenceAt=0 p=consider(a,b)
check('locked_door_failure_leaves_other_observed_entrance_available',p.mode=='search' and p.destination
    and p.destination.approachId==doorBKey and p.destination.id~=doorA and __hours<doorDeadline)
check('failed_entrance_keeps_its_own_deadline',p.residenceAttempts[doorA].retryAt==doorDeadline)
__hours=2.12 __tick=math.floor(__hours*9000)
__seen='B:42:100.0:10.5:0:99.5:10.5:door'
SAO.Perception.observe('a',b,__tick,false)
acquired=SAO.Perception.knownBuildingLeads('a',__tick)
check('reobserving_failed_entrance_keeps_other_memory_and_backoff',acquired[exteriorKey] and acquired[doorBKey]
    and p.residenceAttempts[doorA].retryAt==doorDeadline and p.destination.approachId==doorBKey)
local originalSurface=p.destination.surfaceX
p.destination.surfaceX=999
target,journey=D.residenceDestination('a',__records.a)
check('changed_exterior_geometry_cannot_drive_dormant_travel',journey and target.cx==__records.a.x)
p.destination.surfaceX=originalSurface

a,b=reset()
SAO.Perception.beliefs.a.known={[1]=home}
__seen='B:42:100.0:10.5:0:99.5:10.5:door'
SAO.Perception.observe('a',b,__tick,false)
p=consider(a,b) C.advanceResidencePurpose('a',a,b,__tick)
route=SAO.Locomotion.jobs.a local admittedTarget=p.destination
__hours=2.11 __tick=math.floor(__hours*9000)
__seen='B:42:102.0:10.5:0:101.5:10.5:door'
SAO.Perception.observe('a',b,__tick,false)
a.nextResidenceAt=0 consider(a,b)
check('new_entrance_does_not_retarget_admitted_native_route',p.destination==admittedTarget
    and p.destination.approachId==exteriorKey and SAO.Locomotion.jobs.a==route and route.goal.x==99.5)

a,b=reset()
SAO.Perception.beliefs.a.known={[1]=home}
__seen='B:42:100.0:10.5:0:99.5:10.5:door'
SAO.Perception.observe('a',__bodies.b,__tick,false)
check('foreign_body_cannot_teach_exterior_lead',empty(SAO.Perception.knownBuildingLeads('a',__tick)))
SAO.Perception.beliefs.a.lastScanAt=0 b.md.SAO_ObserverAnchor=true
SAO.Perception.observe('a',b,__tick,false)
check('god_camera_cannot_teach_private_lead',empty(SAO.Perception.knownBuildingLeads('a',__tick)))

a,b=reset()
b.x=99.5 b.y=10.5 b.building=nil SAO.Perception.beliefs.a.known={}
local sourceId='C:fixture-holder:0'
local fingerprint=string.rep('a',64)
__holders='H|protocol=SAOWI1\nC|id='..sourceId..'|fp='..fingerprint..'|sx=100|sy=10|sz=0|x=99|y=10|z=0|reachable=1\nE\n'
local offer=SAO.WorldSources.inspectionCandidate('a',b,'standing',12)
local anchor=offer and SAO.Perception.knownPlaces('a',true)['source:'..sourceId]
check('actual_visible_holder_acquires_exact_anchor_without_building_or_stock',offer and anchor
    and anchor.cx==99 and anchor.sourceId==sourceId and anchor.fingerprint==fingerprint
    and anchor.minX==nil and empty(anchor.sources))
local fake={actorId='a',sourceId=sourceId,fingerprint=fingerprint,sourceX=100,sourceY=10,sourceZ=0,x=99,y=10,z=0}
check('fabricated_candidate_cannot_acquire_holder_anchor',not SAO.Perception.learnVisibleHolder('a',b,fake))
check('foreign_candidate_cannot_acquire_holder_anchor',not SAO.Perception.learnVisibleHolder('b',__bodies.b,offer))
offer.x=80
check('changed_candidate_cannot_rewrite_observed_geometry',not SAO.Perception.learnVisibleHolder('a',b,offer) and anchor.cx==99)
offer.x=99 __holders='H|protocol=SAOWI1\nE\n' SAO.WorldSources.inspectionCandidate('a',b,'standing',12)
check('stale_candidate_cannot_acquire_holder_anchor',not SAO.Perception.learnVisibleHolder('a',b,offer))

__holders='H|protocol=SAOWI1\nC|id='..sourceId..'|fp='..fingerprint..'|sx=100|sy=10|sz=0|x=99|y=10|z=0|reachable=1\nE\n'
offer=SAO.WorldSources.inspectionCandidate('a',b,'standing',12)
S.claim('c',100,10,101,11,0)
local inspections=0
SAOJavaBridge.worldInspectContainer=function() inspections=inspections+1 return 'ACCESS_REFUSED' end
SAO.Perception.beliefs.a.places.c={minX=100,minY=10,maxX=101,maxY=11,at=__tick,source='observed'}
local allowed,permission=SAO.WorldSources.inspectContainer('a',b,offer)
check('changed_private_admission_refuses_before_native_inspection',not allowed and permission=='current-claim-refused' and inspections==0)
SAO.Perception.beliefs.a.places={} offer=SAO.WorldSources.inspectionCandidate('a',b,'standing',12)
local inspected=SAO.WorldSources.inspectContainer('a',b,offer)
check('native_inspection_refusal_does_not_grant_private_stock',not inspected and empty(anchor.sources) and inspections==1)
offer=SAO.WorldSources.inspectionCandidate('a',b,'standing',12)
local nativeStock='H|protocol=SAOWS1|status=OBSERVED|detail=|mode=test|cx=12|cy=1|revision=fixture-r1|sources=1\n'
    ..'S|id='..sourceId..'|fp='..fingerprint..'|rev=fixture-s1|kind=container|x=100|y=10|z=0|building=42|explored=1|state=available|access=accessible|container=counter|q:food=1\n'
    ..'I|source='..sourceId..'|id=101|type=Base.Apple|uses=1|amount=0|fluid=|poison=0|rotten=0|cats=food\nE\n'
SAOJavaBridge.worldInspectContainer=function() return 'I|source='..sourceId..'\n'..nativeStock end
local learned,why=SAO.WorldSources.inspectContainer('a',b,offer)
anchor=SAO.Perception.knownPlaces('a',true)['source:'..sourceId]
check('actual_exact_inspection_after_exterior_approach_grants_only_own_source',learned and anchor.sources.food==true
    and anchor.sourceFacts[sourceId]~=nil and SAO.Perception.knownPlaces('b',true)['source:'..sourceId]==nil)

a,b=reset()
for batch=1,5 do
    local rows={}
    for offset=1,16 do
        local index=(batch-1)*16+offset
        rows[#rows+1]='B:'..(500+index)..':'..(100.5+index)..':10.5:0:'..(100+index)..':10.5:door'
    end
    __hours=2+batch*.1 __tick=math.floor(__hours*9000) __seen=table.concat(rows,'|')
    SAO.Perception.observe('a',b,__tick,false)
end
check('native_exterior_producer_retains_64_private_leads',size(SAO.Perception.knownBuildingLeads('a',__tick))==64)
local remembered={}
for index=1,200 do remembered[index]={cx=1000+index,cy=10,z=0,at=__tick,source='observed',visits=1} end
SAO.Perception.beliefs.a.known=remembered
local engineSort,maxSort=table.sort,0
table.sort=function(rows,less) maxSort=math.max(maxSort,#rows) return engineSort(rows,less) end
local appraisal=L.assessResidence('a',{position={x=b.x,y=b.y,z=0},needs=__needs,tick=__tick,atHours=__hours})
table.sort=engineSort
check('valid_private_residence_union_keeps_nearest_order',maxSort==192 and #appraisal.candidates==16
    and appraisal.candidates[1].buildingId=='517' and appraisal.candidates[16].buildingId=='532')
-- A saved private ledger can predate its producer's cap. The reader still
-- bounds the copied candidates, without consulting a current world registry.
for index=1,16 do
    local saved={buildingId=tostring(1000+index),cx=200+index,cy=10.5,z=0,
        surfaceX=200.5+index,surfaceY=10.5,kind='door',at=__tick,
        source='native-visible-exterior',personId='a'}
    SAO.Perception.beliefs.a.buildingLeads[SAO.Perception.exteriorLeadKey(saved)]=saved
end
maxSort=0
table.sort=function(rows,less) maxSort=math.max(maxSort,#rows) return engineSort(rows,less) end
appraisal=L.assessResidence('a',{position={x=b.x,y=b.y,z=0},needs=__needs,tick=__tick,atHours=__hours})
table.sort=engineSort
check('oversized_saved_exterior_input_has_bounded_sort',maxSort==192 and #appraisal.candidates==16
    and appraisal.candidates[1].stock=='unknown-until-private-inspection')

a,b=reset() p=consider(a,b)
local exactTarget=p.destination.id
p.residenceAttempts={}
for index=32,1,-1 do
    local key='tie:'..(index<10 and '0' or '')..index
    p.residenceAttempts[key]={attempts=1,at=10,retryAt=11,reason='native-route:FAILED_LOCKED_DOOR'}
end
P.deferResidenceRoute('a','native-route:FAILED_LOCKED_DOOR')
check('current_route_retained_with_newer_saved_attempts',size(p.residenceAttempts)==16
    and p.residenceAttempts[exactTarget].at==2 and p.residenceAttempts[exactTarget].attempts==1)
local lexical=true
for index=1,32 do
    local key='tie:'..(index<10 and '0' or '')..index
    if (p.residenceAttempts[key]~=nil)~=(index<=15) then lexical=false end
end
check('retry_ties_use_exact_lexical_order',lexical)

a,b=reset()
local completedVisits=true
for index=1,32 do
    __hours=2+index __tick=math.floor(__hours*9000) a.nextResidenceAt=0
    b.x=10 b.y=10 b.building=1
    local building=100+index
    SAO.Perception.beliefs.a.known={[1]=home,[building]={cx=100+index,cy=10,z=0,
        at=__tick,source='observed',visits=1}}
    p=consider(a,b)
    if not C.advanceResidencePurpose('a',a,b,__tick) then completedVisits=false; break end
    local actualJob=SAO.Locomotion.jobs.a
    b.x=p.destination.cx b.y=p.destination.cy b.building=building
    actualJob.done=true actualJob.result='arrived'
    if not C.finishResidenceMovement('a',a,b) or p.lastResidenceResult.target~=tostring(building)
        or p.admission or p.lastResidenceResult.stock~='unknown-until-private-inspection'
        or size(p.residenceAttempts)>16 then completedVisits=false; break end
end
check('successful_visits_keep_retry_ledger_bounded',completedVisits and size(p.residenceAttempts)==16)
local newest=true
for index=1,32 do
    if (p.residenceAttempts[tostring(100+index)]~=nil)~=(index>16) then newest=false end
end
check('success_retention_keeps_newest_exact_targets',newest and __records.a.homeX==10)

a,b=reset()
local failedRoutes=true
for index=1,32 do
    __hours=2+index __tick=math.floor(__hours*9000) a.nextResidenceAt=0
    local building=200+index
    SAO.Perception.beliefs.a.known={[1]=home,[building]={cx=100+index,cy=10,z=0,
        at=__tick,source='observed',visits=1}}
    p=consider(a,b)
    if not C.advanceResidencePurpose('a',a,b,__tick) then failedRoutes=false; break end
    local actualJob=SAO.Locomotion.jobs.a
    actualJob.done=true actualJob.result='FailedObstacle:FAILED_LOCKED_DOOR'
    C.finishResidenceMovement('a',a,b)
    local attempt=p.residenceAttempts[tostring(building)]
    if not attempt or attempt.reason~='native-route:FailedObstacle:FAILED_LOCKED_DOOR'
        or p.admission or p.lastResidenceResult or size(p.residenceAttempts)>16 then failedRoutes=false; break end
end
check('failed_routes_keep_retry_ledger_bounded',failedRoutes and size(p.residenceAttempts)==16)
check('failure_retention_preserves_exact_retry_and_unknown_stock',p.residenceAttempts['232'].retryAt==__hours+.25
    and p.residenceAttempts['231'].retryAt==__hours-1+.25 and p.residenceAttempts['216']==nil
    and p.destination.stock=='unknown-until-private-inspection' and __records.a.homeX==10)

a,b=reset() p=consider(a,b)
for index=1,20 do P.maintain('a',{key='task-'..index,objective='maintained other demand',domain='general'}) end
check('purpose_capacity_keeps_maintained_residence',P.residencePurpose('a')==p)
C.advanceResidencePurpose('a',a,b,__tick)
C.drop('a')
check('controller_drop_detaches_native_admission_and_preserves_private_purpose',P.residencePurpose('a')==p
    and not p.admission and SAO.Locomotion.jobs.a==nil and p.lastResidenceResult==nil)
P.detachResidence('a','death')
check('death_ends_residence_without_fake_arrival',P.residencePurpose('a')==nil and p.status=='abandoned'
    and p.lastResidenceResult==nil)

-- C118: full private acquisition -> comparative choice -> actual Lua route owner
-- -> native receiver verdict -> exact private encountered-edge consequence.
local function observeEntrances(text)
    __seen=text;SAO.Perception.beliefs.a.lastScanAt=0
    SAO.Perception.observe('a',b,__tick,false)
end
local function residenceTime(hours)
    __hours=hours;__tick=math.floor(hours*9000);a.nextResidenceAt=0
    C.__residenceTick(__tick)
end
local function entranceStart()
    a,b=reset();SAO.Perception.beliefs.a.known={[1]=home}
end
local function outsideThenEnter()
    C.advanceResidencePurpose('a',a,b,__tick)
    b.x=p.steps[1].x;b.y=p.steps[1].y;b.building=nil
    local job=SAO.Locomotion.jobs.a;job.done=true;job.result='arrived'
    C.finishResidenceMovement('a',a,b)
    return C.advanceResidencePurpose('a',a,b,__tick)
end
local function failedEdge(text,verdict)
    __barrier=text;__verdict=verdict
    SAO.Locomotion.tick('a')
    local job=SAO.Locomotion.jobs.a
    C.finishResidenceMovement('a',a,b)
    return job
end
local doorRow='B:42:100.0:10.5:0:99.5:10.5:door:closed'
local windowRow='B:42:102.0:10.5:0:101.5:10.5:window:'
local function windowKey()
    return SAO.Perception.exteriorLeadKey({buildingId='42',cx=101.5,cy=10.5,z=0,surfaceX=102,surfaceY=10.5,kind='window'})
end
entranceStart();observeEntrances(doorRow..'|'..windowRow..'open');p=consider(a,b)
check('observed_open_window_competes_with_closed_door',p.destination.kind=='window' and p.destination.apertureState=='open'
    and p.destination.stock=='unknown-until-private-inspection' and empty(SAO.Perception.knownBuildingLeads('b',__tick)))
b.forceEntry=true
check('window_choice_uses_actual_locomotion',outsideThenEnter() and p.steps[2].basis=='observed-window-entry-hypothesis'
    and SAO.Locomotion.jobs.a.goal.x==102.5 and p.admission~=nil)
check('ordinary_window_route_revokes_prior_force_permission',b.forceEntry==false and __orderedForce==false)
__seen='Z:102:10:1:track:window-threat:floor:0';__tick=__tick+120;C.__residenceTick(__tick);C.__residenceUpdate('a',a)
check('window_route_yields_to_current_threat',a.state=='FLEE' and p.admission==nil and p.lastResidenceResult==nil)
for _,failureMode in ipairs({'refuse','throw'}) do
    entranceStart();observeEntrances(windowRow..'open');p=consider(a,b);b.forceEntry=true
    __forceRefuse=failureMode=='refuse';__forceThrow=failureMode=='throw'
    check('entry_permission_'..failureMode..'_cannot_start_native_route',not C.advanceResidencePurpose('a',a,b,__tick)
        and __starts==0 and p.admission==nil and SAO.Locomotion.jobs.a==nil)
end
entranceStart();observeEntrances(doorRow..'|'..windowRow..'open')
S.claim('c',101,9,104,12,0)
SAO.Perception.beliefs.a.places.c={minX=101,minY=9,maxX=104,maxY=12,at=__tick,source='observed'}
p=consider(a,b)
check('standing_excludes_known_foreign_window',p.destination.kind=='door' and p.destination.approachId~=windowKey())
entranceStart();observeEntrances(doorRow..'|'..windowRow..'open')
SAO.Perception.beliefs.a.buildingLeads[windowKey()].personId='b';p=consider(a,b)
check('foreign_window_memory_cannot_win_choice',p.destination.kind=='door')
entranceStart();observeEntrances(doorRow..'|'..windowRow..'locked')
p=consider(a,b)
check('hidden_lock_visual_claim_not_admitted',SAO.Perception.knownBuildingLeads('a',__tick)[windowKey()]==nil and p.destination.kind=='door')
entranceStart();observeEntrances(doorRow);p=consider(a,b)
check('unseen_window_is_not_invented',p.destination.kind=='door' and SAO.Perception.knownBuildingLeads('a',__tick)[windowKey()]==nil)
entranceStart();observeEntrances(doorRow..'|'..windowRow..'closed');p=consider(a,b)
local lockedKey=p.destination.approachId;local lockedId=p.destination.id
check('initial_closed_door_remains_valid_alternative',p.destination.kind=='door' and outsideThenEnter())
local failed=failedEdge('MOVE_BARRIER@99@10@100@10@0@door@closed@FAILED_LOCKED_DOOR','FailedObstacle:FAILED_LOCKED_DOOR')
local learnedFailure=SAO.Perception.knownBuildingLeads('a',__tick)[lockedKey].entryFailure
check('native_failed_edge_is_consumed_into_private_entry_memory',failed.barrier and failed.entryOutcomeRecorded==true
    and learnedFailure and learnedFailure.reason=='FAILED_LOCKED_DOOR' and p.lastResidenceResult==nil)
check('entry_outcome_replay_is_inert',not SAO.Perception.noteEntryOutcome('a',b,failed)
    and SAO.Perception.knownBuildingLeads('a',__tick)[lockedKey].entryFailure.attempts==1)
local deadline=p.residenceAttempts[lockedId].retryAt
local startsBefore=__starts
for index=1,10 do C.advanceResidencePurpose('a',a,b,__tick+index) end
check('known_barrier_has_no_rapid_identical_retry',__starts==startsBefore and not p.admission)
residenceTime(2.3);observeEntrances(doorRow..'|'..windowRow..'closed');p=consider(a,b)
check('unchanged_barrier_changes_choice_after_backoff',__hours>deadline and p.destination.kind=='window'
    and SAO.Perception.knownBuildingLeads('a',__tick)[lockedKey].entryFailure~=nil)
check('alternative_window_attempt_owns_its_route',outsideThenEnter() and SAO.Locomotion.jobs.a.goal.x==102.5)
failed=failedEdge('MOVE_BARRIER@101@10@102@10@0@window@closed@FAILED_WINDOW_DECLINED','FailedObstacle:FAILED_WINDOW_DECLINED')
check('window_refusal_is_actual_private_edge_evidence',failed.barrier and failed.barrier.kind=='window'
    and SAO.Perception.knownBuildingLeads('a',__tick)[windowKey()].entryFailure.reason=='FAILED_WINDOW_DECLINED')
residenceTime(2.41);observeEntrances('B:42:100.0:10.5:0:99.5:10.5:door:open|'..windowRow..'closed');p=consider(a,b)
check('changed_observed_aperture_can_be_reconsidered',p.destination.kind=='door' and p.destination.apertureState=='open'
    and SAO.Perception.knownBuildingLeads('a',__tick)[lockedKey].entryFailure==nil)
entranceStart();observeEntrances(doorRow..'|'..windowRow..'open');p=consider(a,b)
local selectedWindow=p.destination.approachId
C.advanceResidencePurpose('a',a,b,__tick)
failed=failedEdge('MOVE_BARRIER@99@10@100@10@0@door@closed@FAILED_LOCKED_DOOR','FailedObstacle:FAILED_LOCKED_DOOR')
check('different_failed_edge_never_teaches_selected_window_lock',failed.barrier.kind=='door'
    and SAO.Perception.knownBuildingLeads('a',__tick)[selectedWindow].entryFailure==nil
    and SAO.Perception.knownBuildingLeads('a',__tick)[exteriorKey].entryFailure~=nil)
entranceStart();observeEntrances(doorRow);p=consider(a,b);outsideThenEnter()
failed=failedEdge('MOVE_BARRIER@99@10@100@10@0@window@closed@FAILED_WINDOW_DECLINED','FailedObstacle:FAILED_LOCKED_DOOR')
check('mismatched_barrier_verdict_not_admitted',failed.barrier==nil and SAO.Perception.knownBuildingLeads('a',__tick)[exteriorKey].entryFailure==nil)
entranceStart();observeEntrances(doorRow);p=consider(a,b);outsideThenEnter()
failed=failedEdge('MOVE_BARRIER@1@1@2@1@0@door@closed@FAILED_LOCKED_DOOR','FailedObstacle:FAILED_LOCKED_DOOR')
check('unobserved_failed_edge_does_not_invent_entrance',size(SAO.Perception.knownBuildingLeads('a',__tick))==1
    and SAO.Perception.knownBuildingLeads('a',__tick)[exteriorKey].entryFailure==nil)

entranceStart();observeEntrances(doorRow);p=consider(a,b);outsideThenEnter()
failedEdge('MOVE_BARRIER@99@10@100@10@0@door@closed@FAILED_LOCKED_DOOR','FailedObstacle:FAILED_LOCKED_DOOR')
local solitaryDeadline=p.residenceAttempts[p.destination.id].retryAt
residenceTime(2.11);observeEntrances(doorRow);p=consider(a,b)
check('solitary_unchanged_barrier_has_bounded_backoff',__hours<solitaryDeadline
    and not C.advanceResidencePurpose('a',a,b,__tick))
residenceTime(2.22);observeEntrances('B:42:100.0:10.5:0:99.5:10.5:door:open');p=consider(a,b)
check('changed_visual_condition_supersedes_only_own_backoff',__hours<solitaryDeadline
    and p.destination and p.destination.apertureState=='open' and p.status~='blocked' and C.advanceResidencePurpose('a',a,b,__tick))

__residenceResults=table.concat(checks,'\n')
'''

CONTROLS = [
    ('controller', 'return SAOJavaBridge:setForceEntry(body, false)\n    end)', 'return true\n    end)',
     'ordinary_window_route_revokes_prior_force_permission'),
    ('controller', 'if not permissionOk or permissionSet ~= true then', 'if false then',
     'entry_permission_refuse_cannot_start_native_route'),
    ('locomotion', '        captureBarrier(job, verdict)', '        -- barrier capture omitted',
     'native_failed_edge_is_consumed_into_private_entry_memory'),
    ('planner', '            SAO.Perception.noteEntryOutcome(id, body, job)', '            -- encounter not consumed',
     'native_failed_edge_is_consumed_into_private_entry_memory'),
    ('perception', '        lead.entryFailure = prior.entryFailure', '        lead.entryFailure = nil',
     'unchanged_barrier_changes_choice_after_backoff'),
    ('planner', 'if encountered and finite(encountered.atHours) and encountered.atHours <= at then', 'if false then',
     'unchanged_barrier_changes_choice_after_backoff'),
    ('planner', 'if delayed and failure.apertureState and candidate.apertureState ~= "unknown"',
     'if false and failure.apertureState and candidate.apertureState ~= "unknown"',
     'changed_visual_condition_supersedes_only_own_backoff'),
    ('locomotion', 'or verdict ~= "FailedObstacle:" .. tostring(reason) then return end', 'or false then return end',
     'mismatched_barrier_verdict_not_admitted'),
    ('labor', 'if exteriorInspected > 64 then break end', 'if false then break end',
     'oversized_saved_exterior_input_has_bounded_sort'),
    ('planner', 'trimResidenceAttempts(purpose, key)', '-- failed-route trim omitted',
     'current_route_retained_with_newer_saved_attempts'),
    ('planner', 'trimResidenceAttempts(purpose, tostring(step.target))', '-- successful-visit trim omitted',
     'successful_visits_keep_retry_ledger_bounded'),
    ('planner', 'local kept = { [currentKey] = true }', 'local kept = {}',
     'failed_native_route_is_not_immediately_repeated'),
    ('planner', 'tostring(priorKey) < tostring(key)', 'tostring(priorKey) > tostring(key)',
     'retry_ties_use_exact_lexical_order'),
    ('labor', 'id = "exterior:" .. key,', 'id = "exterior:" .. belief.buildingId,',
     'locked_door_failure_leaves_other_observed_entrance_available'),
    ('dormant', 'if not belief or SAO.Perception.exteriorLeadKey(target) ~= target.approachId\n'
     '            or belief.buildingId ~= target.buildingId or belief.surfaceX ~= target.surfaceX\n'
     '            or belief.surfaceY ~= target.surfaceY or belief.kind ~= target.kind or belief.z ~= target.z then',
     'if false then',
     'changed_exterior_geometry_cannot_drive_dormant_travel'),
    ('dormant', 'knownBuildingLeads(id, SAO.History.ticks())', 'knownBuildingLeads(id, nil)',
     'future_exterior_acquisition_cannot_drive_dormant_travel'),
    ('labor', 'and not belief.sourceId and belief.cx == belief.cx and belief.cy == belief.cy then',
     'and not belief.sourceId and belief.sources and belief.sources.food then',
     'starving_with_energy_selects_unknown_stock_search'),
    ('planner', 'local search = travelAvailable and urgent and not appraisal.localRelief and not appraisal.currentResourceOwner',
     'local search = false',
     'starving_with_energy_selects_unknown_stock_search'),
    ('controller', 'and not agent.companioning and not (SAO.ProceduralPlanning\n            and SAO.ProceduralPlanning.residencePurpose and SAO.ProceduralPlanning.residencePurpose(id)) then',
     'and not agent.companioning then',
     'dusk_does_not_override_selected_search'),
    ('controller', 'return rec.homeX, rec.homeY, rec.homeZ',
     'local g=SAO.Standing.groupOf(id) local l=g and SAO.Standing.leaderOf(g) local r=l and SAO.Identity.get(l) or rec return r.homeX,r.homeY,r.homeZ',
     'leader_address_is_not_inherited_knowledge'),
    ('standing', 'and building ~= nil and tostring(building:getID()) == tostring(candidate.id)',
     'and true', 'even_selected_departure_needs_actual_indoor_arrival'),
    ('standing', 'rec.homeX, rec.homeY, rec.homeZ = place.cx, place.cy, z',
     'rec.homeX, rec.homeY, rec.homeZ = place.cx, place.cy, z\n        for _,other in pairs(SAO.Identity.all()) do other.homeX=place.cx other.homeY=place.cy other.homeZ=z end',
     'actual_arrival_changes_only_actor_residence'),
    ('standing', 'return S.mayEnterBelieved(id, x, y)\nend\n\n-- Choosing a residence',
     'return mayPassHolder(id, S.claimedByOther(id, x, y))\nend\n\n-- Choosing a residence',
     'unseen_global_claim_cannot_veto_physical_permission'),
    ('planner', 'if purpose.admission then return purpose end',
     'if false then return purpose end', 'deliberation_does_not_reset_executing_route'),
    ('dormant', 'local function dormantSettle()\n    return 0\nend',
     "local function dormantSettle()\n    SAO.Standing.setGroupClaim('house',95,5,105,15,0)\n    for _,r in pairs(SAO.Identity.all()) do r.homeX=100 r.homeY=10 r.homeZ=0 end\n    return 1\nend",
     'visits_do_not_create_collective_claim_or_mass_rehome'),
    ('dormant', 'return target, true', 'return nil, false', 'unload_preserves_search_and_no_forced_return'),
    ('controller', 'if lbody and activityParticipantAtHand(id, body, leaderId, lbody, tick, math.huge) then',
     'if lbody then', 'group_membership_gives_no_unseen_leader_position'),
    ('controller', 'if purpose.status == "blocked" or (attempt and not attempt.supersededAt and hours < (attempt.retryAt or 0)) then return false end',
     'if false then return false end','repeated_decisions_honor_exact_route_retry'),
    ('dormant', 'if purpose.status == "blocked" or (attempt and not attempt.supersededAt and hoursNow() < (attempt.retryAt or 0)) then',
     'if false then','unloaded_blocked_route_respects_same_retry'),
    ('controller', 'if agent.residenceRoute then\n        local threat, count, person, key = selectedThreat',
     'if false then\n        local threat, count, person, key = selectedThreat',
     'actual_live_acquisition_preempts_residence_for_close_threat'),
    ('standing', 'function S.rehomeCompanions(playerKey, x, y, z)\n    return 0\nend',
     'function S.rehomeCompanions(playerKey, x, y, z) for id,agent in pairs(SAO.Controller.agents) do if agent.companioning then local rec=SAO.Identity.get(id) rec.homeX=x rec.homeY=y rec.homeZ=z end end return 1 end',
     'player_claim_acquisition_does_not_rehome_companions'),
    ('controller', 'agent.companioning = true\n                    -- Accompanying the player',
     'agent.companioning = true\n                    local claim=SAO.Standing.claimOf(myKey) if claim then agent.rec.homeX=(claim.minX+claim.maxX)/2 agent.rec.homeY=(claim.minY+claim.maxY)/2 end\n                    -- Accompanying the player',
     'actual_companion_initiation_does_not_copy_player_claim'),
    ('planner', 'and bestScore > stayScore', 'and true',
     'conflict_can_preserve_residence_with_own_attachment_and_obligations'),
    ('perception', 'if not ok or not admitted then return end\n    local key, sx, sy, z = fields[2]',
     'if not ok then return end\n    local key, sx, sy, z = fields[2]', 'foreign_body_cannot_teach_exterior_lead'),
    ('perception', 'if type(lead) == "table" and lead.personId == tostring(id)\n            and lead.source == "native-visible-exterior" and P.exteriorLeadKey(lead) == key\n            and finiteSoundNumber(lead.cx)', 'if type(lead) == "table"\n            and lead.source == "native-visible-exterior" and P.exteriorLeadKey(lead) == key\n            and finiteSoundNumber(lead.cx)', 'foreign_private_lead_record_is_not_admitted'),
    ('world', 'memory.pending ~= context or context.actorId ~= actorId then return nil end',
     'context.actorId ~= actorId then return nil end', 'fabricated_candidate_cannot_acquire_holder_anchor'),
    ('world', 'if context[key] ~= offered[key] then return nil end',
     'if false then return nil end', 'changed_candidate_cannot_rewrite_observed_geometry'),
    ('planner', 'not prior.admission and (not prior.residence\n                    or prior.status == "completed" or prior.status == "abandoned") and (not prior.resourceOutcome',
     'not prior.admission and (not prior.resourceOutcome', 'purpose_capacity_keeps_maintained_residence'),
    ('controller', 'or agent.state == "FOLLOW" or agent.residenceRoute ~= nil then',
     'or agent.state == "FOLLOW" then', 'actual_live_treatable_bleeding_preempts_residence_route'),
]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--required',action='store_true')
    parser.add_argument('--output',type=Path)
    args=parser.parse_args()
    game, jdk = fixture.GAME, fixture.JDK
    owned=[Path(__file__).resolve(),Path(fixture.__file__).resolve(),ROOT/'tools/luacheck/LuaRun.java',*FILES.values()]
    missing=[str(p) for p in owned if not p.is_file()]
    if missing:
        print('FAULT residence planning: owned inputs absent: '+', '.join(missing)); return 1
    if not all(path.is_file() for path in (game/'projectzomboid.jar',game/'stdlib.lua',jdk/'java.exe',jdk/'javac.exe')):
        print('Residence planning '+('FAILED' if args.required else 'SKIPPED')+': installed game or JDK absent; production execution unverified'); return 1 if args.required else 0
    output=(args.output or ROOT/'_scratch/c118-validation/residence').resolve()
    output.mkdir(parents=True,exist_ok=True)
    inputs=owned+[game/'projectzomboid.jar',game/'stdlib.lua',jdk/'java.exe',jdk/'javac.exe']
    def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
    receipt={'schema':'sao-residence-proof/1','status':'RUNNING','boundary':__doc__,
             'inputs_before':{str(p):digest(p) for p in inputs},'runs':[]}
    def save(): (output/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    def execute(command,cwd,name):
        done=subprocess.run(command,cwd=cwd,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=60)
        log=output/(name+'.log');log.write_text(done.stdout+done.stderr,encoding='utf-8')
        receipt['runs'].append({'name':name,'command':command,'exitCode':done.returncode,'logSha256':digest(log)})
        save();return done
    texts = {name:path.read_text(encoding='utf-8-sig') for name,path in FILES.items()}
    expose = 'Ctl.__residenceAddress=resolvedHomeAddress\nCtl.__residenceHome=decideHomeAndEquipment\nCtl.__residenceCompany=decideCompany\nCtl.__residenceNeeds=decideNeedsAndCompanion\nCtl.__residenceState=setState\nCtl.__residenceUpdate=updateAgent\nCtl.__residenceTick=function(t) tickCount=t end\nreturn Ctl\n'
    expected=set(re.findall(r"check\('([a-z0-9_]+)'\s*,",CASES))
    expected.update({"entry_permission_refuse_cannot_start_native_route","entry_permission_throw_cannot_start_native_route"})
    try:
        with tempfile.TemporaryDirectory(prefix='sao-residence-planning-') as directory:
            work=Path(directory)
            shutil.copy2(game/'stdlib.lua',work/'stdlib.lua')
            runner=(ROOT/'tools/luacheck/LuaRun.java').read_text(encoding='utf-8-sig')
            runner=runner.replace('String m = t.getMessage();','String m = t.getMessage();\n            System.out.println("PHASE " + env.rawget("__residencePhase"));\n            System.out.println("DECISION " + env.rawget("__decisionFacts"));\n            System.out.println("FACTS " + env.rawget("__caseFacts"));\n            System.out.println("PARTIAL " + env.rawget("__residencePartial"));\n            System.out.println("AT " + thread.getCurrentCoroutine().stackTrace);')
            (work/'LuaRun.java').write_text(runner,encoding='utf-8')
            compiled=execute([str(jdk/'javac.exe'),'-cp',str(game/'projectzomboid.jar'),'-d',str(work),str(work/'LuaRun.java')],work,'compile')
            if compiled.returncode: raise RuntimeError('compile failed: '+compiled.stderr)
            run_number=0
            def run(changed=None,target=None):
                nonlocal run_number
                run_number+=1
                code=dict(texts); code.update(changed or {})
                if code['controller'].count('return Ctl\n')!=1: raise RuntimeError('Controller export drift')
                code['controller']=code['controller'].replace('return Ctl\n',expose,1)
                chunks={'prelude':fixture.PRELUDE,'setup':SETUP,**code,'cases':CASES}
                paths=[]
                for name,text in chunks.items():
                    marker=work/(name+'-loading.lua')
                    marker.write_text('__residencePhase='+json.dumps('LOADING '+name),encoding='utf-8');paths.append(marker)
                    path=work/(name+'.lua');path.write_text(text,encoding='utf-8');paths.append(path)
                done=execute([str(jdk/'java.exe'),'-Djava.awt.headless=true','-cp',
                    str(work)+os.pathsep+str(game/'projectzomboid.jar'),'LuaRun',*map(str,paths),'--','__residenceResults'],
                    work,str(run_number)+'-control-'+target if target else 'production')
                checks=dict(re.findall(r'^([a-z0-9_]+)=(true|false)$',done.stdout.replace('VALUE ',''),re.M))
                if target:
                    if done.returncode and 'RESIDENCE:'+target in done.stdout:
                        return {target:'false'}
                    raise RuntimeError(target+': wrong mutation verdict: '+done.stdout[-5000:]+done.stderr[-1000:])
                if done.returncode or set(checks)!=expected:
                    raise RuntimeError(done.stdout[-5000:]+done.stderr[-1000:])
                return checks
            checks=run()
            failed=[name for name,value in checks.items() if value!='true']
            if failed: raise RuntimeError('failed cases: '+', '.join(failed))
            for name,before,after,target in CONTROLS:
                if texts[name].count(before)!=1: raise RuntimeError(target+': mutation anchor differs')
                mutant=run({name:texts[name].replace(before,after,1)},target)
                if mutant[target]!='false': raise RuntimeError(target+': production mutation survived')
            receipt.update(status='PASS',cases=len(checks),controls=len(CONTROLS),inputs_after={str(p):digest(p) for p in inputs})
            if receipt['inputs_before']!=receipt['inputs_after']: raise RuntimeError('relevant inputs changed during proof')
            save()
            print(f'Border 226 PASS: residence planning; {len(checks)} production Kahlua cases; {len(CONTROLS)} named controls')
            return 0
    except Exception as error:
        receipt.update(status='FAIL',error=str(error));save()
        print('FAULT residence planning:',error); return 1

if __name__=='__main__': raise SystemExit(main())
