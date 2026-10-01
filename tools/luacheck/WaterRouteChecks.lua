-- Production Controller/Needs/Locomotion and installed water constructor/queue.
-- Body, bridge and animation begin are controlled receivers; no drinking effect
-- or native path completion is manufactured by this queue-admission fixture.
function require() end
Events=setmetatable({}, {__index=function(t,k)
    local e={Add=function() end,Remove=function() end};rawset(t,k,e);return e
end})
ISBaseObject={}
function ISBaseObject:derive(name)
    local child={Type=name};setmetatable(child,{__index=self});child.__index=child;return child
end
ISBaseTimedAction=ISBaseObject:derive('ISBaseTimedAction')
function ISBaseTimedAction:new(character)
    return setmetatable({character=character},self)
end
function ISBaseTimedAction:begin() self.began=true end
ISInventoryTransferAction=ISBaseTimedAction:derive('ISInventoryTransferAction')
CharacterStat={THIRST='thirst'}
HaloTextHelper={addBadText=function() end}
function getText(value) return value end
function instanceof(value,kind)
    return value and value.isBody and (kind=='IsoGameCharacter' or kind=='IsoPlayer')
end
function getSpecificPlayer() return nil end
for _,name in ipairs({'ClimbThroughWindowState','ClimbOverFenceState','ClimbOverWallState',
    'ClimbSheetRopeState','ClimbDownSheetRopeState','CloseWindowState','OpenWindowState'}) do
    local state={};_G[name]={instance=function() return state end}
end
SAO={Log={line=function() end},Controller={agents={}},Body={active={},foreign={},get=function() return __body end},
    Perception={beliefs={person={people={},known={home={source='lived'}}}}},
    History={countyHours=function() return __hours end},
    Standing={mayEnterBelieved=function() return not __forbidden end,groupOf=function() end},
    Disposition={drinkAt=function() return .5 end,eatAt=function() return .5 end,
        isSmoker=function() return false end,wouldForceEntry=function() return false end},
    Lessons={has=function() return false end,desperationBump=function() return 0 end},
    Identity={updatePosition=function() end,get=function(id)
        local agent=SAO.Controller.agents[id];return agent and agent.rec or nil
    end},
    Places={commitHorizon=function() return 100 end,comfortHorizon=function() return 40 end},
    WorldSources={nearestObserved=function() __knowledgeCalls=__knowledgeCalls+1;return __knownPlace end},
    SourceUse={begin=function(id,body,place,category,admission)
        __sourceBegin={id=id,body=body,place=place,category=category,admission=admission};return true
    end,beforeStateChange=function() return not __reconciliationPending end}}
SAOJavaBridge={}
function SAOJavaBridge:findWaterSource(body,radius,hours)
    __queryHours=hours;return __candidate
end
function SAOJavaBridge:findCarriedDrink() return nil end
function SAOJavaBridge:resourceApproach(body,kind,x,y,z) return 'AT:13:20:0' end
function SAOJavaBridge:moveTo(body,x,y,z) __orders=__orders+1;return 'MOVE_STARTED' end
function SAOJavaBridge:tickMove() return __verdict end
function SAOJavaBridge:cancelMove() return 'MOVE_CANCELLED' end
function SAOJavaBridge:failWaterApproach(body,status,hours,x,y,z)
    __trace=__trace..'F';__failCalls=__failCalls+1
    __failure={body=body,status=status,hours=hours,x=x,y=y,z=z};return true
end
function SAOJavaBridge:clearWaterSource() __trace=__trace..'C' end
function SAOJavaBridge:waterSourceWithinReach() return __within end
function SAOJavaBridge:waterSourceObject() return __water end
function SAOJavaBridge:getBleedingCount() return 0 end
function SAOJavaBridge:woundInfection() return 0 end
function SAOJavaBridge:dirtyBandages() return 0 end
function SAOJavaBridge:sickness() return 0 end

function CheckWaterRoutes()
    local names={}
    local function check(name,value)
        assert(value,'WATER_CHECK:'..name);names[#names+1]=name
    end
    local function fresh()
        __hours=100.25;__queryHours=nil;__candidate='14:20:0';__orders=0;__within=false
        __verdict='ManualRoute';__failCalls=0;__failure=nil;__trace='';__forbidden=false
        __knownPlace=nil;__knowledgeCalls=0;__sourceBegin=nil
        __reconciliationPending=false
        __water={getFluidAmount=function() return 2 end}
        __body={isBody=true,x=10.5,y=20.5,z=0}
        function __body:getX() return self.x end
        function __body:getY() return self.y end
        function __body:getZ() return self.z end
        function __body:getVehicle() return nil end
        function __body:getStats() return {get=function() return .8 end} end
        function __body:isTimedActionInstant() return false end
        function __body:isAsleep() return self.asleep==true end
        function __body:isLocalPlayer() return true end
        function __body:isDraggingCorpse() return self.dragging==true end
        function __body:isFarming() return false end
        local a={state='IDLE',rec={id='person'},nextDecisionAt=0}
        SAO.Controller.agents={person=a};SAO.Locomotion.jobs={};ISTimedActionQueue.queues={}
        SAO.Controller.__waterTick(1)
        return a,__body
    end
    local function decide(a,b,tick,thirst)
        SAO.Controller.__waterTick(tick)
        return SAO.Controller.__waterDecide('person',a,b,tick,{thirst=thirst or .9,hunger=0,fatigue=0})
    end
    local a,b=fresh()
    local remembered=SAO.Perception.beliefs.person.known
    check('initial_water_route_uses_native_approach',decide(a,b,1) and a.state=='WATERWARD'
        and SAO.Locomotion.jobs.person.goal.x==13)
    check('selector_receives_county_clock',__queryHours==100.25)
    __verdict='FailedObstacle:FAILED_LOCKED_DOOR'
    SAO.Controller.__waterMovement('person',a,b)
    check('actual_terminal_owner_records_before_clear',a.state=='IDLE' and __failCalls==1 and __trace=='FC')
    check('terminal_receipt_binds_body_goal_and_county_time',__failure.body==b
        and __failure.status=='done:FailedObstacle:FAILED_LOCKED_DOOR' and __failure.hours==100.25
        and __failure.x==13 and __failure.y==20 and __failure.z==0)
    check('failure_keeps_private_place_beliefs',SAO.Perception.beliefs.person.known==remembered
        and remembered.home.source=='lived')
    __candidate='';__knownPlace={cx=40,cy=40,id='remembered-water'}
    check('all_local_candidates_held_reaches_private_source_owner',decide(a,b,602)
        and a.state=='SOURCEWARD' and __knowledgeCalls==1
        and __sourceBegin.place==__knownPlace and __sourceBegin.category=='water')

    a,b=fresh();decide(a,b,1)
    SAO.Controller.__waterState(a,'person','FLEE','actual threat')
    check('flee_interruption_does_not_record_failure',a.state=='FLEE' and __failCalls==0)
    local job=SAO.Locomotion.jobs.person
    check('unfinished_job_cannot_record_failure',not SAO.Needs.noteWaterRouteFailure('person',b,'done:Failed'))
    job.done=true;job.result='Failed'
    check('different_body_cannot_record_failure',not SAO.Needs.noteWaterRouteFailure('person',{},'done:Failed'))
    check('mismatched_status_cannot_record_failure',not SAO.Needs.noteWaterRouteFailure('person',b,'done:stalled:ManualRoute'))

    a,b=fresh();__within=true;b.asleep=true
    check('sleeping_native_queue_drop_is_refusal',not SAO.Needs.queueDrinkFrom('person',b)
        and ISTimedActionQueue.queues[b]==nil)
    b.asleep=false;b.dragging=true
    check('dragging_native_queue_drop_is_refusal',not SAO.Needs.queueDrinkFrom('person',b)
        and ISTimedActionQueue.queues[b]==nil)
    b.dragging=false
    check('native_constructor_and_queue_accept_exact_water',SAO.Needs.queueDrinkFrom('person',b))
    local queued=ISTimedActionQueue.queues[b].queue[1]
    check('native_drink_shape_and_amount_preserved',queued.Type=='ISTakeWaterAction' and queued.waterObject==__water
        and queued.item==nil and queued.waterUnit==1.6 and queued.began==true)

    a,b=fresh();__within=true
    check('usable_fixture_drinks_without_a_route',decide(a,b,1) and a.state=='DRINK'
        and __orders==0 and SAO.Locomotion.jobs.person==nil
        and ISTimedActionQueue.queues[b] and #ISTimedActionQueue.queues[b].queue==1)
    a,b=fresh();__within=false
    check('inaccessible_fixture_keeps_native_approach_route',decide(a,b,1)
        and a.state=='WATERWARD' and __orders==1 and ISTimedActionQueue.queues[b]==nil)
    a,b=fresh();__within=true;b.asleep=true
    check('direct_queue_refusal_never_claims_drink',decide(a,b,1)
        and a.state=='WATERWARD' and __orders==1 and ISTimedActionQueue.queues[b]==nil)
    a,b=fresh();__within=true;a.state='ROAM'
    SAO.Locomotion.order('person',b,22,20,0)
    local previousJob=SAO.Locomotion.jobs.person
    __reconciliationPending=true
    check('pending_source_reconciliation_preserves_route_and_queue',decide(a,b,1)
        and a.state=='ROAM' and SAO.Locomotion.jobs.person==previousJob
        and __orders==1 and ISTimedActionQueue.queues[b]==nil)

    a,b=fresh()
    SAOJavaBridge.foodSourceWithinReach=function() return true end
    SAOJavaBridge.foodSourceItem=function() return {} end
    SAOJavaBridge.foodSourceContainer=function() return {} end
    SAO.SourceUse.beginTransfer=function() return false,'current-claim-refused' end
    local transfer,why=SAO.Needs.queueTake('person',b,{category='food',admission='standing'})
    check('native_transfer_preserves_exact_refusal_reason',transfer==false and why=='current-claim-refused')

    a,b=fresh();decide(a,b,1);__verdict='Succeeded';__within=true;b.asleep=true
    SAO.Controller.__waterMovement('person',a,b)
    check('arrival_with_queue_refusal_does_not_become_drink',a.state=='IDLE')
    a,b=fresh();decide(a,b,1);__verdict='Succeeded';__within=true
    SAO.Controller.__waterMovement('person',a,b)
    check('arrival_with_native_queue_admission_becomes_drink',a.state=='DRINK'
        and #ISTimedActionQueue.queues[b].queue==1)
    a,b=fresh();decide(a,b,1);__verdict='Transition:CLIMBING'
    SAO.Controller.__waterTick(a.taskDeadline)
    SAO.Controller.__waterMovement('person',a,b)
    check('water_deadline_releases_controller_and_records_exact_failure',a.state=='IDLE'
        and a.taskDeadline==nil and SAO.Locomotion.jobs.person==nil
        and __failure and __failure.status=='done:water-approach-expired')
    -- The production Controller admits a rival-selected intent before the
    -- ordinary threshold. This controlled selector proves only the execution
    -- join; independent model behavior is checked with the real model module.
    a,b=fresh();__within=true
    local frames, admissions, interruptions={}, {}, {}
    local due=true
    SAO.Cognition={isDue=function() return due end,
        choose=function(id,frame) frames[#frames+1]=frame;return 'water','episode-rival' end,
        started=function(id,ep,admitted,reason)
            admissions[#admissions+1]={id=id,ep=ep,admitted=admitted,reason=reason}
        end,
        interrupt=function(id,reason) interruptions[#interruptions+1]={id=id,reason=reason} end}
    check('rival_intent_executes_before_ordinary_threshold',decide(a,b,1,.1)
        and a.state=='DRINK' and #frames==1 and #admissions==1
        and admissions[1].ep=='episode-rival' and admissions[1].admitted==true
        and #ISTimedActionQueue.queues[b].queue==1)
    check('cognitive_frame_uses_private_actor_evidence',frames[1].actorId=='person'
        and frames[1].worldHours==100.25 and frames[1].thirst==.1
        and frames[1].knownPlaces==1 and frames[1].knownFood==0
        and frames[1].people==nil and frames[1].camera==nil and frames[1].body==nil)
    SAO.Controller.__waterState(a,'person','IDLE','route ended')
    check('ending_intent_censors_pending_competition',#interruptions==1
        and interruptions[1].id=='person')
    a,b=fresh();due=false
    check('off_cadence_does_not_build_competition_frame',
        SAO.Controller.__cognitionChoice('person',a,b,1,{hunger=0,thirst=.1,fatigue=0})==nil and #frames==1)
    due=true;a.coordinationCommitment={id='already-owned'}
    check('accepted_work_retains_decision_ownership',
        SAO.Controller.__cognitionChoice('person',a,b,1,{hunger=0,thirst=.1,fatigue=0})==nil and #frames==1)
    a.coordinationCommitment=nil;ISTimedActionQueue.queues[b]={queue={{}},current={}}
    check('queued_action_retains_decision_ownership',
        SAO.Controller.__cognitionChoice('person',a,b,1,{hunger=0,thirst=.1,fatigue=0})==nil and #frames==1)
    SAO.Cognition=nil
    return 'PASS water route and native queue checks='..#names
end
