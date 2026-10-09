local S=SAO.LeisureSkill
local checks=0
local function check(name,condition)assert(condition,'LEISURE_SKILL:'..name);checks=checks+1;print('CASE '..name)end
local function fresh()
    __hours=10;__client=false;__server=false;__sourceLost=false;__sourceCalls=0
    __records={person={id='person'},other={id='other'}};__bodies={person=__body,other=__other}
    for _,row in ipairs({{__body,'person'},{__other,'other'}}) do
        row[1]:getModData().SAOPersonId=row[2];row[1]:getModData().SAOExternalToken=nil
        row[1]:setAsleep(false)
    end
    __clearXP()
    __works={person={actorId='person',sequence=1,workId='art/person/1',purposeId='purpose-art',
        family='art',activity='painting',itemKey='easel:fixture',sourceId='LifestyleHobbies',revision='fixture-exact-source',
        status='active',bodyGenerationKnown=false,admittedAtHours=10,nativeOwner='LSCanvasPaintingAction'}}
    __requests={person={}}
    local purpose={id='purpose-art',domain='leisure',status='maintained',affordance='LifestyleHobbies',cursor=1,
        leisure={activity='painting',itemKey='easel:fixture'},steps={{id='perform-activity',owner='SAO.LeisureArt',token='leisure:performed',status='available'}}}
    __records.person.proceduralPlanning={schema=1,purposes={['purpose-art']=purpose},order={'purpose-art'},spatial={},spatialOrder={},practice={}}
    assert(SAO.ProceduralPlanning.admitHobbyWork('person','purpose-art',1,'SAO.LeisureArt'))
end
local function issue()
    __sourceIssueArt(__body,{size='small',level=1},{10,20})
    return __requests.person[#__requests.person]
end
local function consume(sequence)return S.consume('person',__body,'SAO.LeisureArt',1,sequence or 1)end
fresh();local request=issue()
check('actual_source_issued_exact_rate',request.perkName=='Art' and request.amount==1 and __sourceCalls==1)
local accepted,out=consume()
check('native_same_body_XP_applied',accepted and out.status=='applied' and __body:getXp():getXP(Perks.Art)>0)
check('measured_native_delta',out.afterXP>out.beforeXP and out.appliedDelta==out.afterXP-out.beforeXP)
check('foreign_body_unchanged',__other:getXp():getXP(Perks.Art)==0)
check('multiplier_not_fabricated',out.requestedAtHours==10 and out.amount==1 and out.appliedDelta~=out.amount)
local delta=out.appliedDelta;__clearXP();__sourceAddXP(__body,{'Art',request.amount})
check('actual_source_handler_equivalence',math.abs(__body:getXp():getXP(Perks.Art)-delta)<.000001)
local before=__body:getXp():getXP(Perks.Art);check('duplicate_request_refused',not consume());check('duplicate_no_XP',__body:getXp():getXP(Perks.Art)==before)
out.status='spoof';check('detached_receipt',S.receipt('person','SAO.LeisureArt',1,1).status=='applied')
issue();check('next_monotonic_source_request',consume(2))
__works.person.sequence=2;__works.person.workId='art/person/2'
__records.person.proceduralPlanning.purposes['purpose-art'].admission=nil
assert(SAO.ProceduralPlanning.admitHobbyWork('person','purpose-art',2,'SAO.LeisureArt'))
issue();check('global_sequence_survives_second_work',S.consume('person',__body,'SAO.LeisureArt',2,3))
local old=__requests.person[1];old.workSequence=2;old.workId='art/person/2'
check('new_work_cannot_replay_earlier_global_request',not S.consume('person',__body,'SAO.LeisureArt',2,1))
fresh();issue();check('foreign_body_refused',not S.consume('person',__other,'SAO.LeisureArt',1,1))
check('unknown_provider_refused',not S.consume('person',__body,'SAO.Controller',1,1))
check('request_parameter_gap_refused',not consume(2))
fresh();request=issue();request.actorId='other';check('foreign_request_refused',not consume())
fresh();request=issue();request.workId='foreign-work';check('foreign_work_refused',not consume())
fresh();request=issue();request.atHours=11;check('future_request_refused',not consume())
fresh();request=issue();request.amount=-1;check('negative_reward_refused',not consume())
fresh();request=issue();request.revision='spoof';check('source_revision_refused',not consume())
fresh();request=issue();request.nativeProgress.actionStarted=false;check('actual_source_progress_required',not consume())
fresh();issue();__works.person.status='completed';check('retired_native_work_refused',not consume())
fresh();issue();__body:getModData().SAOExternalToken='replacement';__records.person.bodyOwnerToken='replacement'
check('stale_body_generation_refused',not consume())
fresh();issue();__records.person.proceduralPlanning.purposes['purpose-art'].admission=nil
check('typed_planner_admission_required',not consume())
fresh();issue();__records.person.proceduralPlanning.purposes['purpose-art'].hobby.owner='SAO.LeisureMusic'
__records.person.proceduralPlanning.purposes['purpose-art'].steps[1].owner='SAO.LeisureMusic'
__records.person.proceduralPlanning.purposes['purpose-art'].admission.owner='SAO.LeisureMusic'
check('wrong_typed_owner_refused',not consume())
fresh();request=issue();request.perkName='missing-perk'
accepted,out=consume();check('unsupported_perk_retained',not accepted and out.status=='unsupported')
check('unsupported_request_not_replayed',not consume())
fresh();issue();local actualAdd=addXp;addXp=function()end
accepted,out=consume();addXp=actualAdd
check('zero_native_effect_not_claimed',not accepted and out.status=='noeffect' and out.appliedDelta==0)
check('zero_effect_not_replayed',not consume())
fresh();issue();local actualSync=SyncXp;SyncXp=function()error('controlled sync failure after native write')end
accepted,out=consume();SyncXp=actualSync
check('partial_native_effect_retained',not accepted and out.status=='interrupted' and out.appliedDelta>0)
before=__body:getXp():getXP(Perks.Art);check('partial_write_not_replayed',not consume() and __body:getXp():getXP(Perks.Art)==before)
fresh();issue();__client=true;check('client_authority_unverified',not consume());__client=false;__server=true
check('server_NPC_join_unverified',not consume());__server=false
fresh();issue();assert(consume());__records=__roundTrip(__records);__reloadGesture()
check('durable_cursor_survives_native_serialization',not consume())
fresh();issue();__sourceLost=true;check('source_runtime_reload_loss_refused',not consume())
fresh();issue();__records.person.leisureSkill={schema=1,actorId='person',cursors={['SAO.LeisureArt']={workSequence=1,sequence=1}},receipts={},order={}}
check('reserved_unobservable_write_not_replayed',not consume())
check('no_mastery_state_fabricated',__records.person.education==nil and __records.person.cognitiveModels==nil)
print('PASS leisure skill '..checks)
