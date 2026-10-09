-- The Organization source owns completed pairs and process retention here.
-- Production Cognition and CognitiveModels receive the exact controlled rows.
local C=SAO.Cognition
local count=0
local function check(name,condition)
    assert(condition,'D2_PAIRED_ORDER:'..name);count=count+1;print('CASE '..name)
end
__hours=10
__records={person={id='person'},foreign={id='foreign'}}
__stores={}
SAO.Identity.all=function()return __records end
assert(C.configure(0,12,3))

local source={duet={},dance={}}
local liveProcesses={}
SAO.Organization={processes=liveProcesses,
    duetParticipationFor=function(id,processId)
        local row=source.duet[processId]
        return row and row.actorId==id and row or nil
    end,
    danceParticipationFor=function(id,processId)
        local row=source.dance[processId]
        return row and row.actorId==id and row or nil
    end}
local function receipt(kind,processId,sequence,partnerId)
    local ownWork=kind..'-native-work:'..processId
    local row={actorId='person',processId=processId,partnerId=partnerId,
        revision=1,sourceId='LifestyleHobbies',sequence=sequence,atHours=10,
        workId=ownWork,before={},after={},
        measurementAuthority='actual-source-interval; concurrent-effects-not-isolated',
        coPerformance={status='completed',ownResultId=ownWork,
            partnerResultId=kind..'-partner-result:'..processId,
            basis='two-committed-native-source-'..kind..'-results'}}
    if kind=='dance' then row.musicKey='native-radio-1';row.role='source' end
    source[kind][processId]=row
    liveProcesses[processId]={id=processId,status='completed'}
    return row
end
local function deliver(kind,row)
    return C[kind..'Outcome']('person',row.processId)
end
local frame={domain='ordinary-purpose',atHours=10,pressure=.1,
    needs={hunger=0,thirst=0,fatigue=.1,endurance=1}}
local function offer(kind,partnerId)
    return {id='paired-choice:'..kind..':'..partnerId,kind='leisure',utility=.2,
        evidence=1,continuity=0,novelty=0,informationGain=0,blockers=0,
        maxAdjustment=.25,consequences={{kind='hobby',category='leisure',
            sourceId='LifestyleHobbies',condition=kind..':'..partnerId,value=.4}}}
end

local pairs={}
for _,kind in ipairs({'duet','dance'}) do
    local earlier=receipt(kind,kind..'-pair:1',1,kind..'-partner-a')
    local later=receipt(kind,kind..'-pair:2',2,kind..'-partner-b')
    pairs[kind]={earlier=earlier,later=later}
    local firstOffer,secondOffer,otherOffer=offer(kind,earlier.partnerId),
        offer(kind,later.partnerId),offer(kind,kind..'-unrelated')
    local coldFirst=C.scorePlan('person',firstOffer,frame)
    local coldSecond=C.scorePlan('person',secondOffer,frame)
    local coldOther=C.scorePlan('person',otherOffer,frame)
    local laterAccepted=deliver(kind,later)
    local onlyLater=C.scorePlan('person',secondOffer,frame)
    local firstStillCold=C.scorePlan('person',firstOffer,frame)
    check(kind..'_later_result_teaches_only_its_exact_partner',laterAccepted
        and onlyLater>coldSecond and math.abs(firstStillCold-coldFirst)<.00001)
    local earlierAccepted=deliver(kind,earlier)
    local warmFirst=C.scorePlan('person',firstOffer,frame)
    local otherAfter=C.scorePlan('person',otherOffer,frame)
    check(kind..'_out_of_order_both_exact_partners_learn',earlierAccepted
        and warmFirst>coldFirst and math.abs(otherAfter-coldOther)<.00001)
    local rec=__records.person
    local events={}
    for _,event in ipairs(rec.cognition.experiences) do
        if event.kind=='leisure-'..kind then events[#events+1]=event end
    end
    check(kind..'_out_of_order_keeps_source_and_delivery_positions',#events==2
        and events[1].id=='leisure-'..kind..'/person/1'
        and events[1].sourceWorkSequence==2
        and events[2].id=='leisure-'..kind..'/person/2'
        and events[2].sourceWorkSequence==1
        and rec.cognition.nativeExperienceCursors[kind]==2)
end

-- Move both private experience logs past their 256-event limit. The source
-- process still exists, so its exact durable claim must survive event eviction.
for sequence=3,260 do
    local row=receipt('duet','duet-many:'..sequence,sequence,'duet-many-partner')
    local ok,reason=deliver('duet',row)
    check('many_duet_'..sequence..'_accepted',ok and reason=='observed')
end
local rec=__records.person
check('old_duet_event_evicted_from_both_logs',#rec.cognition.experiences==256
    and #rec.cognition.models.ordinary.eventOrder==256
    and rec.cognition.seen['leisure-duet/person/1']==nil
    and rec.cognition.models.ordinary.seen['leisure-duet/person/1']==nil)
local loaded=__roundTrip(rec)
__records.person=loaded
C.rebindWorld()
check('paired_claims_and_work_order_survive_save_rebind',loaded.cognition.nativeExperienceCursors.duet==260
    and loaded.cognition.nativeExperienceCursors.dance==2
    and #loaded.cognition.pairedSourceClaimOrder==262
    and loaded.cognition.pairedSourceClaims['duet:11:duet-pair:1:1'].sourceSequence==1)
local revision=loaded.cognition.models.ordinary.revision
local duetReplay,duetReason=deliver('duet',pairs.duet.later)
check('evicted_duet_replay_does_not_relearn_after_reload',duetReplay and duetReason=='duplicate'
    and loaded.cognition.models.ordinary.revision==revision
    and loaded.cognition.nativeExperienceCursors.duet==260)
local danceReplay,danceReason=deliver('dance',pairs.dance.earlier)
check('evicted_dance_replay_does_not_relearn_after_reload',danceReplay and danceReason=='duplicate'
    and loaded.cognition.models.ordinary.revision==revision
    and loaded.cognition.nativeExperienceCursors.dance==2)

local first=pairs.duet.earlier
first.workId='different-source-work'
first.coPerformance.ownResultId=first.workId
local conflict,conflictReason=deliver('duet',first)
check('same_process_revision_conflict_does_not_relearn',not conflict
    and conflictReason=='conflicting-paired-receipt'
    and loaded.cognition.models.ordinary.revision==revision)
first.workId='duet-native-work:duet-pair:1'
first.coPerformance.ownResultId=first.workId

-- Fill the retained-source ledger to its bound with controlled saved process
-- rows. A full live set cannot silently retire a still-replayable claim.
local claims=loaded.cognition.pairedSourceClaims
local order=loaded.cognition.pairedSourceClaimOrder
for index=#order+1,1024 do
    local key='controlled-held:'..index
    local processId='controlled-process:'..index
    claims[key]={processId=processId}
    order[index]=key
    liveProcesses[processId]={id=processId,status='completed'}
end
local nextReceipt=receipt('duet','duet-cap-new',261,'duet-new-partner')
SAO.Organization.processes=nil
local unavailable,unavailableReason=deliver('duet',nextReceipt)
check('missing_source_process_map_cannot_prune_claims',not unavailable
    and unavailableReason=='process-map-unavailable'
    and loaded.cognition.models.ordinary.revision==revision)
SAO.Organization.processes=liveProcesses
local held,heldReason=deliver('duet',nextReceipt)
check('live_source_process_claims_hold_capacity',not held and heldReason=='paired-claim-capacity'
    and #order==1024 and claims['duet:11:duet-pair:1:1']~=nil
    and loaded.cognition.models.ordinary.revision==revision)
liveProcesses['duet-pair:1']=nil
local reclaimed,reclaimedReason=deliver('duet',nextReceipt)
check('retired_source_process_reclaims_one_claim_slot',reclaimed and reclaimedReason=='observed'
    and #loaded.cognition.pairedSourceClaimOrder==1024
    and claims['duet:11:duet-pair:1:1']==nil
    and claims['duet:12:duet-cap-new:1']~=nil
    and loaded.cognition.models.ordinary.revision==revision+1)

print('PASS D2 paired order '..count)
