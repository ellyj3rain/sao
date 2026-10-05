local checks=0
local function check(name,value)
    if not value then error("CONFLICT_RESPONSE:"..name) end
    checks=checks+1
end
local records={}
local now=2
SAO.Identity.get=function(id)return records[id]end
SAO.History.countyHours=function()return now end
SAO.Disposition.conflictValues=function(id)
    return {actorId=id,selfPreservation=.8,aggression=.2,nerve=.3,discipline=.7,compassion=.3}
end
SAO.Disposition.fear=function()return .1 end
SAO.Disposition.decisionInterval=function()return 20 end
SAO.Disposition.fleeDistance=function()return 9 end
SAO.Disposition.overwhelmThreshold=function()return 4 end
SAO.Disposition.paceUnderThreat=function()return 'run' end
SAO.Disposition.wouldDemand=function()return false end
SAO.Disposition.wouldYieldTo=function()return false end
SAO.Standing.mayEngageZombie=function()return true end
SAO.Standing.mayEngagePerson=function()return false end
local starts,attacks,cancels,advances,combatTicks=0,0,0,0,0
local moves,native,verdict,cancelResult
SAOJavaBridge.isShell=function()return true end
SAOJavaBridge.getShellHealth=function(_,body)return body.health end
SAOJavaBridge.localCombatMoves=function()return moves end
SAOJavaBridge.combatOpportunity=function()return native end
SAOJavaBridge.beginCombatObserved=function(_,body,kind,key,mode)
    attacks=attacks+1;__attack={body=body,kind=kind,key=key,mode=mode}
    return 'COMBAT_STARTED observed'
end
SAOJavaBridge.tickCombat=function()combatTicks=combatTicks+1;return verdict end
SAOJavaBridge.cancelCombatObserved=function()cancels=cancels+1;return cancelResult end
SAO.Locomotion={jobs={}}
SAO.Locomotion.order=function(id,body,x,y,z)
    starts=starts+1
    if __refuse then return false end
    SAO.Locomotion.jobs[id]={body=body,goal={x=x,y=y,z=z},nativeRouteGeneration=starts,done=false}
    return true
end
SAO.Locomotion.cancel=function(id)cancels=cancels+1;SAO.Locomotion.jobs[id]=nil end
SAO.Locomotion.tick=function()__moveTicks=(__moveTicks or 0)+1 end
SAO.Locomotion.status=function(id)
    local job=SAO.Locomotion.jobs[id]
    return job and (job.done and 'done:'..job.result or 'moving') or 'none'
end
local function setState(a,id,state,reason)
    if __stateRefused then return false end
    if a.state=='FLEE' and state~='FLEE' then SAO.Locomotion.cancel(id) end
    a.state=state;a.pressure={detail=reason};return true
end
local hooks={setState=setState,mayEnter=function()return not __forbid end,
    advance=function()advances=advances+1 end,coordinate=function()return false,'not-admitted' end}
local function fresh()
    records={};now=2;starts=0;attacks=0;cancels=0;advances=0;combatTicks=0
    __refuse=false;__forbid=false;__stateRefused=false
    __busy=false;__moveTicks=0;__injury=0;__shouts=0;__tells=0;__trust={};__player=nil
    __group=nil;__fellows={};__forbidden={};__blockAll=false;__companyStanding=1
    SAO.Needs.busy=function()return __busy end
    moves='MOVE\t1\t0\t0\nMOVE\t0\t1\t0'
    native='REFUSED\tout-of-reach';verdict='COMBAT_ATTACKING';cancelResult='COMBAT_CANCELLED'
    SAO.Locomotion.jobs={};SAO.Body.active={};SAO.Body.foreign={}
    SAO.Coordination=nil;SAO.Organization=nil;SAO.Communication=nil;SAO.Handover=nil
    SAO.Posture=nil
    SAO.Study=nil;SAO.PathogenPressure=nil
    SAO.Disposition.describe=function()return 'fixture person' end
    local rec={id='runner',bodyOwnerToken='body:1'};records.runner=rec
    local b={x=.5,y=.5,z=0,health=100,data={SAOPersonId='runner',SAOExternalToken='body:1'}}
    function b:getX()return self.x end;function b:getY()return self.y end;function b:getZ()return self.z end
    function b:getHealth()return .01 end;function b:getModData()return self.data end
    function b:faceLocationF(x,y)self.facing={x=x,y=y}end
    function b:isClimbing()return self.climbing==true end
    function b:getCurrentStateName()return self.nativeState or 'IdleState' end
    function b:Callout()__shouts=__shouts+1 end
    local a={rec=rec,state='IDLE'}
    SAO.Body.active.runner=b;SAO.Body.get=function(id)return SAO.Body.active[id]end
    SAO.Controller.agents={runner=a}
    __bodies={runner=b};SAO.Perception.beliefs={runner={people={}}}
    local t={x=-5,y=.5,dist=5.5,source='observed',track='observed-track-1',at=1}
    return a,b,t
end
local function decide(a,b,t,tick)
    return SAO.ConflictResponse.decide('runner',a,b,tick or 1,t,1,nil,nil,hooks)
end

local a,b,t=fresh();decide(a,b,t)
check('native_retreat_admitted',a.state=='FLEE' and starts==1 and a.conflictRoute~=nil)
local job=SAO.Locomotion.jobs.runner
local offer=a.conflictRoute.routeKey
b.x=1.05;now=2.001;t.at=10;decide(a,b,t,10)
check('progress_retains_exact_native_route',SAO.Locomotion.jobs.runner==job and starts==1
    and a.conflictRoute.routeKey==offer and advances==2)
job.done=true;job.result='FailedObstacle:FAILED_LOCKED_DOOR'
SAO.ConflictResponse.finishMovement('runner',a,b,setState)
check('native_failure_retained',SAO.ProceduralPlanning.conflictSnapshot('runner').lastOutcome.status=='failed')
b.x=.5;now=2.002;decide(a,b,t,20)
check('failed_exit_changes_actual_route',starts==2 and a.conflictRoute and a.conflictRoute.routeKey~=offer)

a,b,t=fresh();moves='';native='AVAILABLE\tshove\t1\t1.5';t.dist=1;t.x=-.5
decide(a,b,t)
check('unarmed_defense_actual_dispatch',a.state=='ENGAGE' and attacks==1 and __attack.mode=='shove'
    and __attack.key==t.track)
local work=a.conflictCombat
verdict='COMBAT_COMPLETED attack-requests=1 attribution=unknown'
SAO.ConflictResponse.pump('runner',a,b,2,t,1,nil,setState)
local view=SAO.ProceduralPlanning.conflictSnapshot('runner')
check('attempt_completion_reopens_ooda',a.state=='ALERT' and not a.conflictCombat and view.lastOutcome.status=='completed'
    and view.lastOutcome.reason:find('attribution=unknown',1,true))
check('completion_is_exact_once',not SAO.ProceduralPlanning.conflictResult('runner',work.purposeId,work.token,
    {status='completed',reason='duplicate'}))

a,b,t=fresh();moves='';native='AVAILABLE\tshove\t1\t1.5';t.dist=1;decide(a,b,t)
b.health=99;cancelResult='COMBAT_HELD'
SAO.ConflictResponse.pump('runner',a,b,30,t,2,nil,setState)
check('native_animation_keeps_custody',a.state=='ENGAGE' and a.conflictCombat and combatTicks==1)
cancelResult='COMBAT_CANCELLED'
SAO.ConflictResponse.pump('runner',a,b,31,t,2,nil,setState)
check('changed_danger_reappraised_after_handback',a.state=='ALERT' and not a.conflictCombat)

a,b,t=fresh();b.data.SAOExternalToken='successor';decide(a,b,t)
check('foreign_body_token_cannot_dispatch',starts==0 and attacks==0 and not records.runner.proceduralPlanning)
a,b,t=fresh();__stateRefused=true;decide(a,b,t)
check('pending_owner_prevents_new_native_action',starts==0 and attacks==0)
a,b,t=fresh();__refuse=true;decide(a,b,t)
view=SAO.ProceduralPlanning.conflictSnapshot('runner')
check('native_refusal_is_not_admission',view.lastOutcome.status=='refused' and view.lastOutcome.admitted==false and not view.admission)

a,b,t=fresh();__forbid=true;native='REFUSED\tno-observed-target';t.source='told';t.track=nil
decide(a,b,t)
check('heard_contact_cannot_be_replaced_with_nearest',attacks==0 and starts==0 and b.facing~=nil)
a,b,t=fresh();moves='';native='AVAILABLE\tshove\t1\t1.5';t.source='observed';t.fromPerson=true;t.name='A Neighbor';t.dist=1
SAO.ConflictResponse.decide('runner',a,b,1,t,1,nil,nil,hooks)
check('formed_appearance_does_not_grant_attack_permission',attacks==0)

a,b,t=fresh();__busy=true;decide(a,b,t)
check('unrelated_timed_action_keeps_body',starts==0 and attacks==0 and a.state=='IDLE')

a,b,t=fresh();SAO.Controller.__fleeProbeTick(1)
SAO.Controller.__threatProbeDecide('runner',a,b,1,t,1,nil,nil)
check('actual_controller_dispatches_conflict',a.state=='FLEE' and starts==1 and a.conflictRoute~=nil)
__injury=4;SAO.Controller.__fleeProbeTick(2)
SAO.Controller.__threatProbeDecide('runner',a,b,2,t,1,nil,nil)
check('held_conflict_route_keeps_cry_consequences',a.conflictRoute~=nil and __shouts==1 and a.criedAt==2)
local exact=SAO.Locomotion.jobs.runner
a.coordinationRoute={commitmentId='old'};a.coordinationCommitment='old'
SAO.Organization={commitment=function()return {status='completed'}end}
SAO.Controller.__followProbeMovement('runner',a,b)
check('old_commitment_cannot_cancel_new_escape',a.state=='FLEE' and SAO.Locomotion.jobs.runner==exact)

a,b,t=fresh();a.state='TRAVEL';a.residenceRoute={}
job={body=b,goal={x=1,y=0,z=0},lastVerdict='Transition:STARTED_WINDOW_CLIMB',done=false}
SAO.Locomotion.jobs.runner=job
SAO.Controller.__threatProbeDecide('runner',a,b,1,t,1,nil,nil,true)
check('accepted_crossing_before_native_state_keeps_owner',a.state=='TRAVEL' and SAO.Locomotion.jobs.runner==job and starts==0)
check('strategic_crossing_owner_keeps_ticking',__moveTicks==1)
job.lastVerdict='ManualRoute';b.nativeState='ClimbThroughWindowState'
SAO.Controller.__threatProbeDecide('runner',a,b,2,t,1,nil,nil,true)
check('native_crossing_state_keeps_owner',a.state=='TRAVEL' and starts==0 and __moveTicks==2)

a,b,t=fresh();moves='';native='AVAILABLE\tshove\t1\t1.5';t.dist=1;decide(a,b,t)
work=a.conflictCombat;b.health=99
SAO.ConflictResponse.pump('runner',a,b,30,t,1,nil,setState)
check('native_physiology_reopens_combat',not a.conflictCombat and a.state=='ALERT')

a,b,t=fresh();decide(a,b,t);local first=a.conflictRoute.token.id
check('drop_settles_admitted_conflict',SAO.Controller.drop('runner') and SAO.Controller.agents.runner==nil
    and not SAO.ProceduralPlanning.conflictSnapshot('runner').admission)
SAO.Controller.adopt(records.runner);a=SAO.Controller.agents.runner
decide(a,b,t,3)
check('readoption_keeps_unique_attempt_identity',a.conflictRoute~=nil and a.conflictRoute.token.id~=first)

a,b,t=fresh();moves='';native='AVAILABLE\tshove\t1\t1.5';t.dist=1;decide(a,b,t)
cancelResult='COMBAT_HELD'
check('drop_waits_for_native_attack_handback',not SAO.Controller.drop('runner')
    and SAO.Controller.agents.runner==a and a.conflictCombat~=nil)

-- The actual Controller posture owner keeps a segment selected for this same
-- threat, then returns its native result to the conflict record.
a,b,t=fresh();moves='';native='REFUSED\tno-physical-action';t.dist=5
local commitment={id='accepted:1',actorId='runner',acceptedAt=1,status='accepted'}
SAO.Organization={activeCommitments=function()return {commitment}end,
    workPlan=function()return {proposal={scope={action='tactical-withdrawal'}}}end}
SAO.Posture={jobs={}}
local postureTicks=0
SAO.Posture.tick=function(id)postureTicks=postureTicks+1;return 'working'end
SAO.Posture.interrupt=function(id)SAO.Posture.jobs[id]=nil;return true end
local oldCoordinate=hooks.coordinate
hooks.coordinate=function(id,body,runtime)
    SAO.Posture.jobs[id]={body=body,id='native-watch:1'};runtime.state='POSTURE';return true,'posture'
end
decide(a,b,t)
check('accepted_cooperation_gets_exact_native_binding',a.conflictCoordination~=nil and a.state=='POSTURE')
__threat=t;SAO.Controller.advancePosture('runner',a,b,2)
check('same_known_threat_preserves_selected_cooperative_watch',postureTicks==1 and a.state=='POSTURE')
SAO.Posture.tick=function(id)SAO.Posture.jobs[id]=nil;return 'completed'end
SAO.Controller.advancePosture('runner',a,b,3)
check('native_cooperative_segment_result_reaches_conflict',SAO.ProceduralPlanning.conflictSnapshot('runner').lastOutcome.status=='completed'
    and not a.conflictCoordination)
hooks.coordinate=oldCoordinate

a,b,t=fresh();decide(a,b,t);now=5
job=SAO.Locomotion.jobs.runner;job.done=true;job.result='arrived'
SAO.ConflictResponse.finishMovement('runner',a,b,setState)
view=SAO.ProceduralPlanning.conflictSnapshot('runner')
check('late_terminal_releases_exact_admission_without_credit',not a.conflictRoute and not view.admission
    and view.lastOutcome.status=='cancelled' and view.lastOutcome.reason:find('uncredited',1,true))
decide(a,b,t,10)
check('late_terminal_allows_next_attempt',a.conflictRoute~=nil)
a,b,t=fresh();a.rec={id='someone-else',bodyOwnerToken='body:1'};decide(a,b,t)
check('wrong_person_record_cannot_dispatch',starts==0 and attacks==0)
a,b,t=fresh();SAO.Controller.agents.runner={rec=a.rec,state='IDLE'};decide(a,b,t)
check('stale_controller_cannot_dispatch',starts==0 and attacks==0)
a,b,t=fresh();records.runner={id='runner',bodyOwnerToken='body:1'};decide(a,b,t)
check('replaced_identity_record_cannot_dispatch',starts==0 and attacks==0)
a,b,t=fresh();decide(a,b,t);SAO.Controller.agents.runner=nil
SAO.Locomotion.jobs.runner=nil;SAO.Controller.adopt(records.runner)
view=SAO.ProceduralPlanning.conflictSnapshot('runner')
check('actual_adoption_reconciles_orphan',not view.admission and view.lastOutcome.status=='cancelled'
    and view.lastOutcome.observability=='runtime-owner-lost')
local function transfer()
    local runtime,body,threat=fresh()
    local frame={actorId='runner',atHours=now,threat={kind='person',key='neighbor',distance=3,count=1,source='observed'},
        values=SAO.Disposition.conflictValues('runner'),fear=.1,overwhelmed=false,escapeBlocked=true}
    local decision=SAO.ProceduralPlanning.planConflict('runner',frame,{{id='concede',kind='concede',available=true,
        effects={'possible-agreement'},objections={'loss-of-supplies'},reason='Offer spare food.'}})
    local token={owner='Handover',id='handover:1'}
    assert(decision and SAO.ProceduralPlanning.conflictAdmission('runner',decision.purposeId,token,decision.selected))
    local receipt={id=token.id,actorId='runner',status='pending'}
    local state={release=false,requests=0,completed=false}
    SAO.Handover={reconcile=function()if state.completed then receipt.status='completed' end end,
        result=function()return receipt end,
        cancelAttempt=function(receiptId,id,owner)
            assert(receiptId==receipt.id and id=='runner' and owner==body)
            state.requests=state.requests+1
            if not state.release then return false,'pending' end
            if receipt.status=='pending' then receipt.status='interrupted' end
            return true,receipt.status
        end}
    runtime.conflictHandover={body=body,receiptId=receipt.id,token=token,purposeId=decision.purposeId,
        actorId='runner',targetKey=threat.track,threatCount=1,distance=threat.dist,health=body.health,startedAt=now}
    return runtime,body,threat,state
end
a,b,t,work=transfer()
check('stable_transfer_keeps_exact_owner',SAO.ConflictResponse.pendingTransfer('runner',a,b,t,1,nil) and work.requests==0)
b.health=90
check('injury_requests_exact_transfer_cancellation',SAO.ConflictResponse.pendingTransfer('runner',a,b,t,1,nil)
    and work.requests==1 and a.conflictHandover~=nil)
work.release=true
check('transfer_handback_reopens_response',not SAO.ConflictResponse.pendingTransfer('runner',a,b,t,1,nil)
    and not a.conflictHandover and SAO.ProceduralPlanning.conflictSnapshot('runner').lastOutcome.status=='failed')
a,b,t,work=transfer();work.completed=true;b.health=90
check('completed_transfer_still_waits_for_native_handback',SAO.ConflictResponse.pendingTransfer('runner',a,b,t,1,nil)
    and work.requests==1)
work.release=true;SAO.ConflictResponse.pendingTransfer('runner',a,b,t,1,nil)
view=SAO.ProceduralPlanning.conflictSnapshot('runner')
check('completed_transfer_survives_interruption',view.lastOutcome.status=='completed'
    and view.lastOutcome.reason:find('response remains unconfirmed',1,true))

-- Awareness starts with a private believed contact, independently of whether
-- a physical response is selected or currently executable.
a,b,t=fresh();t.dist=14;t.x=-13.5;moves=''
local handled=decide(a,b,t)
view=SAO.ProceduralPlanning.conflictSnapshot('runner')
check('distant_contact_retains_appraisal',view and view.kind=='watch')
check('distant_watch_has_no_fabricated_action',not handled and starts==0 and attacks==0 and not view.admission)

a,b,t=fresh();t.dist=14;t.x=-13.5;a.state='HOMEWARD'
job={body=b,goal={x=10,y=0,z=0},done=false};SAO.Locomotion.jobs.runner=job
handled=decide(a,b,t)
view=SAO.ProceduralPlanning.conflictSnapshot('runner')
check('ordinary_away_route_remains_owned',not handled and SAO.Locomotion.jobs.runner==job
    and a.state=='HOMEWARD' and starts==0 and cancels==0)
check('ordinary_work_keeps_threat_reasoning',view and view.kind=='watch'
    and #view.alternatives>1 and not view.admission)

a,b,t=fresh();t.dist=14;t.x=-13.5;a.state='HOMEWARD'
job={body=b,goal={x=-10,y=0,z=0},done=false};SAO.Locomotion.jobs.runner=job
handled=decide(a,b,t)
check('approaching_route_changes_response',handled and a.state=='FLEE'
    and SAO.Locomotion.jobs.runner~=job and starts==1)

a,b,t=fresh();t.dist=14;t.x=-13.5;moves='';__busy=true
local interrupted=0
SAO.Study={active=function(id,body)return id=='runner' and body==b end,
    interrupt=function()interrupted=interrupted+1;return false end}
handled=decide(a,b,t)
check('watch_retains_real_reading_owner',not handled and interrupted==0 and __busy
    and SAO.ProceduralPlanning.conflictSnapshot('runner').kind=='watch')

a,b,t=fresh();a.state='TRAVEL';t.dist=14;t.x=-13.5
job={body=b,goal={x=10,y=0,z=0},lastVerdict='Transition:STARTED_WINDOW_CLIMB',done=false}
SAO.Locomotion.jobs.runner=job
SAO.Controller.__threatProbeDecide('runner',a,b,1,t,1,nil,nil,true)
view=SAO.ProceduralPlanning.conflictSnapshot('runner')
check('crossing_keeps_awareness',view and #view.alternatives>0)
check('crossing_appraisal_preserves_native_custody',a.state=='TRAVEL'
    and SAO.Locomotion.jobs.runner==job and starts==0 and __moveTicks==1)

a,b,t=fresh();t.dist=14;t.x=-13.5;native='AVAILABLE\tranged\t14\t20'
local originalValues=SAO.Disposition.conflictValues
SAO.Disposition.conflictValues=function(id)
    return {actorId=id,selfPreservation=.5,aggression=.75,nerve=.7,discipline=.5,compassion=.5}
end
handled=decide(a,b,t)
check('distant_native_ranged_offer_can_dispatch',handled and a.state=='ENGAGE' and attacks==1
    and __attack.mode=='ranged' and __attack.key==t.track and a.conflictCombat~=nil)
SAO.Disposition.conflictValues=originalValues
__result='PASS conflict response '..checks..' checks'
