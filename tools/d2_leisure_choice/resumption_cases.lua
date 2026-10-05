-- Exact Controller ordinary chooser plus installed body/serialization. The
-- fixture supplies private observations and an authored stock obligation, not
-- a native world or a claim that the requested stock has been acquired.
local C,P,Ctl=SAO.Cognition,SAO.ProceduralPlanning,SAO.Controller
local count=0
local function check(name,condition)
    assert(condition,'D2_RESUMPTION:'..name);count=count+1;print('CASE '..name)
end
SAO.Disposition.drinkAt=function()return .3 end
SAO.Disposition.eatAt=function()return .3 end
SAO.Disposition.conflictValues=function(id)return {actorId=id,selfPreservation=.5,
    aggression=.5,nerve=.5,discipline=.5,compassion=.5}end
SAO.Perception.believedThreatCount=function()return __threatCount end
SAO.ConflictResponse={gesturePriority=function()return __conflictPriority end}
SAO.Locomotion={jobs={}}
SAO.Study.offer=function()return nil end
SAO.Study.active=function()return __studying end
SAO.Standing.insideClaim=function()return false end
local nativeBusy=SAO.Needs.busy
local needs={hunger=.6,thirst=0,fatigue=.1,endurance=1}
local function conflict()
    return P.planConflict('person',{actorId='person',atHours=__hours,
        threat={kind='zombie',key='seen:z1',distance=2,count=1,source='observed',at=100},
        values=SAO.Disposition.conflictValues('person'),fear=.5,overwhelmed=false,escapeBlocked=true},
        {{id='defend',kind='defend',available=true,reason='controlled exact shove offer',
          effects={'create-space'},objections={},nativeMode='shove',targetKey='seen:z1'}})
end
local function fresh(deadline)
    __hours=10;__records={person={id='person'},foreign={id='foreign'}};__stores={};__receipts={}
    __threatCount=0;__conflictPriority=false;__studying=nil
    SAO.Needs.busy=nativeBusy;SAO.Locomotion.jobs={}
    __body:getInventory():clear();__other:getInventory():clear()
    __body:setAsleep(false);__body:getCharacterActions():clear()
    local data=__body:getModData();data.SAOPersonId='person';data.SAOExternalOwner=nil
    data.SAOExternalToken=nil;data.ZAOOwned=nil
    SAO.Body.active.person=__body;SAO.Body.foreign.person=nil
    local rec=__records.person;local agent={rec=rec,state='IDLE'};Ctl.agents.person=agent
    assert(C.configure(0,12,3))
    local first
    for i=1,12 do
        local p=P.admitResourceOutcome('person',{id='retained-stock-'..i,revision=2,
            category=i==1 and 'food' or 'water',target=2,
            unit=i==1 and 'usable-food-item' or 'native-clean-fluid-amount',sourceDefinition=string.rep('a',64),
            issuer='controlled-authored-obligation',deadlineAfterHours=i==1 and deadline or nil})
        assert(p,'authored outcome admission '..i);first=first or p
    end
    -- The actual resource planner records this bounded private stock input.
    -- It is deliberately short of the target and supplies no new completion.
    SAO.Labor.assess=function()return {category='food',demand={ownedReady=1,pressure=.6},
        contacts={},dimensions={},capacity={},options={},blocker='no-known-source'}end
    assert(P.planResource('person',{purposeId=first.id,atHours=__hours,
        carriedReadyItems={{itemId=77,itemType='Base.Apple'}},stockCoverage='controlled-private-native-input'}))
    local decision=assert(conflict(),'canonical conflict appraisal')
    assert(P.conflictAdmission('person',decision.purposeId,{owner='SAO.Combat',id='native-handback'},'defend'))
    assert(P.conflictResult('person',decision.purposeId,{owner='SAO.Combat',id='native-handback'},
        {status='cancelled',reason='controlled physical owner handed back'}))
    assert(P.queuedPurpose('person').id==first.id,'canonical capacity queued first obligation')
    return rec,agent,first.id,decision.purposeId
end
local function choose(agent,body,tick)
    return Ctl.chooseOrdinaryPurpose('person',agent,body or __body,tick or 1000,needs)
end
local function stillQueued(id)return P.queuedPurpose('person') and P.queuedPurpose('person').id==id end
do
    local rec,agent,id,conflictId=fresh()
    local queued=rec.proceduralPlanning.queuedPurposes.purposes[id]
    local revision,held,stepRevision=queued.resourceOutcome.revision,queued.outcomeProgress.held,queued.revision
    rec=__roundTrip(rec);__records.person=rec;agent.rec=rec
    local kind=choose(agent)
    local restored=rec.proceduralPlanning.purposes[id]
    check('ordinary_choice_revives_exact_obligation',restored and restored.id==id
        and rec.proceduralPlanning.queuedPurposes.purposes[id]==nil and kind=='food')
    check('reload_retains_request_revision_and_partial_progress',restored.resourceOutcome.revision==revision
        and restored.outcomeProgress.held==held and held==1 and restored.outcomeProgress.target==2
        and restored.revision==stepRevision and restored.status=='blocked'
        and restored.resourceOutcome.issuer=='controlled-authored-obligation')
    local food
    for _,row in ipairs(rec.ordinaryPurposeDecision.alternatives)do if row.id=='food' then food=row end end
    check('private_comparison_carries_restored_exact_purpose',food and food.reasons.purposeId==id
        and food.continuity==.1 and rec.ordinaryPurposeDecision.interpretations.selected=='food')
    local savedConflict=rec.proceduralPlanning.queuedPurposes.purposes[conflictId]
    check('ordinary_resume_preserves_owned_conflict_history',savedConflict
        and savedConflict.conflict.lastOutcome.id=='native-handback'
        and savedConflict.conflict.lastOutcome.status=='cancelled' and P.queuedPurpose('person')==nil)
    check('resumption_does_not_admit_or_complete_material',restored.admission==nil
        and restored.status~='completed' and restored.resolution==nil and restored.outcomeProgress.held==1)
    local renewed=assert(conflict());local next=P.queuedPurpose('person');assert(next)
    choose(agent)
    check('same_tick_retry_cannot_rotate_queue',stillQueued(next.id)
        and rec.proceduralPlanning.purposes[renewed.purposeId]~=nil)
    choose(agent,nil,1001)
    check('later_clear_choice_can_restore_next_obligation',not stillQueued(next.id)
        and rec.proceduralPlanning.purposes[next.id]~=nil)
end
do local _,a,id=fresh();a.state='FLEE';choose(a)
    check('active_defense_state_preserves_queue',stillQueued(id)) end
do local _,a,id=fresh();__threatCount=1;choose(a)
    check('private_current_threat_preserves_queue',stillQueued(id)) end
do local _,a,id=fresh();__conflictPriority=true;choose(a)
    check('owned_conflict_hold_preserves_queue',stillQueued(id)) end
do local _,a,id=fresh();a.conflictCombat={};choose(a)
    check('native_defense_binding_preserves_queue',stillQueued(id)) end
do local _,a,id=fresh();SAO.Needs.busy=function()return true end;choose(a)
    check('current_native_busy_preserves_queue',stillQueued(id)) end
do local _,a,id=fresh();__body:setAsleep(true);choose(a)
    check('sleeping_body_cannot_resume',stillQueued(id));__body:setAsleep(false) end
do local _,a,id=fresh();__studying=true;choose(a)
    check('current_study_preserves_queue',stillQueued(id)) end
do local _,a,id=fresh();SAO.Locomotion.jobs.person={body=__body,done=false};choose(a)
    check('current_route_preserves_queue',stillQueued(id)) end
do local _,a,id=fresh();a.rec.worldSourceReservation={};choose(a)
    check('source_reservation_preserves_queue',stillQueued(id)) end
do local _,a,id=fresh();a.rec.cookingWork={status='cooking'};choose(a)
    check('native_cooking_preserves_queue',stillQueued(id)) end
do local _,a,id=fresh();a.rec.resourceProductionWork={};choose(a)
    check('source_production_preserves_queue',stillQueued(id)) end
do local _,a,id=fresh();a.resting=true;choose(a)
    check('resting_body_preserves_queue',stillQueued(id)) end
do local _,a,id=fresh();a.passive=true;choose(a)
    check('passive_owner_preserves_queue',stillQueued(id)) end
do local _,a,id=fresh();choose(a,__other)
    check('foreign_body_cannot_resume',stillQueued(id)) end
do local rec,_,id=fresh();local forged={rec=rec,state='IDLE'};choose(forged)
    check('detached_agent_cannot_restore_canonical_queue',stillQueued(id)) end
do local _,a,id=fresh();local forged={rec=__records.foreign,state='IDLE'};choose(forged)
    check('foreign_record_cannot_restore_canonical_queue',stillQueued(id)) end
do local rec,a,id=fresh(1);__hours=12;choose(a)
    local expired=rec.proceduralPlanning.purposes[id]
    check('elapsed_deadline_is_resolved_by_canonical_resume',expired and expired.status=='abandoned'
        and expired.resolution=='deadline-expired' and expired.outcomeProgress.held==1)
    local refused=true
    for _,row in ipairs(rec.ordinaryPurposeDecision.alternatives)do
        if row.reasons.purposeId==id then refused=false end
    end
    check('expired_request_cannot_supply_choice_continuity',refused)
end
do local rec,a,id=fresh()
    for _,key in ipairs(rec.proceduralPlanning.order)do
        rec.proceduralPlanning.purposes[key].admission={owner='WorldSources',correlationId='controlled-owned:'..key}
    end
    choose(a)
    check('all_owned_work_requires_handback_before_restoration',stillQueued(id) and a.queuedPurposeResumeTick==nil)
end
print('PASS D2 resumption '..count)
