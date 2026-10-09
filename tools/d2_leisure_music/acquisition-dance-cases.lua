-- Join a personally observed device acquisition to the original dance callback.
-- The source pickup receipt is controlled; Planner, Acquisition and both music
-- owners execute their real source against the pinned native Kahlua runtime.
state=freshPersonal();M.prepareActor('person',__body)
SAO.ProceduralPlanning={}
assert(loadstring(assert(__sources['own:planner']),'own:planner'))()
assert(loadstring(assert(__sources['own:acquisition']),'own:acquisition'))()
local P,A=SAO.ProceduralPlanning,SAO.LeisureAcquisition
local bridgeRequirements=SAOJavaBridge.leisureMaterialRequirements
SAOJavaBridge.leisureMaterialRequirements=function(_,body,itemType)
    assert(body==__body)
    return M.materialRequirementsForType(nil,itemType)
end
local itemType=__device:getFullType()
local function requirement(activity)
    for _,row in ipairs(A.requirements('person',__body,itemType))do
        if row.activity==activity then return row end
    end
end
local listening=assert(requirement('listen-recorded-music'))
local dance=assert(requirement('dance-to-recorded-music'))
check('dance_requirement_distinct_from_listening',dance.role=='playable-item'
    and dance.sourceId=='NewMusic' and dance.itemType==itemType
    and dance.requirementId~=listening.requirementId)

local infer=SAO.ConceptKnowledge.infer
SAO.ConceptKnowledge.infer=function(id,from,effect)
    if from=='dance'then return {actorId=id,paths={}}end
    return infer(id,from,effect)
end
check('dance_without_personal_concept_not_acquirable',requirement('listen-recorded-music')
    and not requirement('dance-to-recorded-music'))
SAO.ConceptKnowledge.infer=infer
local materialFallback=M.materialRequirementAvailable
M.materialRequirementAvailable=function()return true end
SAO.ConceptKnowledge.infer=function(id,from,effect)
    if from=='dance'then return {actorId=id,paths={}}end
    return infer(id,from,effect)
end
check('rejected_playable_cannot_fall_through_material_callback',not requirement('dance-to-recorded-music'))
SAO.ConceptKnowledge.infer=infer;M.materialRequirementAvailable=materialFallback
local sourceAvailable=SAO.SourceIntegration.available
SAO.SourceIntegration.available=function(id)return id=='NewMusic'end
check('missing_dance_source_rejects_acquisition',not requirement('dance-to-recorded-music'))
SAO.SourceIntegration.available=sourceAvailable
local mood=LSUtil.getCharacterMood
LSUtil.getCharacterMood=function(body,name)
    if name=='Endurance'then return .2 end
    return mood(body,name)
end
check('low_endurance_rejects_dance_acquisition',not requirement('dance-to-recorded-music'))
LSUtil.getCharacterMood=mood
local sitting=__body.isSittingOnFurniture
__body.isSittingOnFurniture=function()return true end
check('seated_actor_rejects_dance_acquisition',not requirement('dance-to-recorded-music'))
__body.isSittingOnFurniture=sitting

__items={}
local option={id='observed:device:20',parameters={sourceKind='ground',category='leisure-material',
    sourceId='observed-ground:20',itemId=20,itemType=itemType,revision='ground:rev:1',
    fingerprint='ground:fingerprint:1',sourceX=10,sourceY=10,sourceZ=0}}
local place={sourceId=option.parameters.sourceId,cx=10.5,cy=10.5,z=0,
    minX=10,minY=10,maxX=10,maxY=10}
SAO.Perception.knownPlaces=function(id,private)
    return id=='person'and private and {['known:device']=place}or{}
end
SAO.WorldSources={actionOptions=function(_,category,id,body)
    assert(category=='leisure-material'and id=='person'and body==__body)
    return {options={option}}
end}
local pickup
SAO.SourceUse={beginAcquisition=function(id,body,where,category,binding)
    assert(id=='person'and body==__body and category=='leisure-material')
    pickup={where=where,binding=binding}
    return true
end}
local available=A.offers('person',__body)
local danceRow
for _,row in ipairs(available)do if row.activity=='dance-to-recorded-music'then danceRow=row end end
check('observed_device_has_personal_dance_acquisition',danceRow and danceRow.requirement.requirementId==dance.requirementId
    and danceRow.option.parameters.itemId==20 and danceRow.itemKey=='20')
local started,purposeId=A.begin('person',__body,danceRow)
local purpose=assert(__records.person.proceduralPlanning.purposes[purposeId])
check('dance_acquisition_starts_exact_source_use',started and pickup
    and pickup.binding.purposeId==purposeId and pickup.binding.itemId==20
    and purpose.leisureAcquisition.kind=='dance-to-recorded-music'
    and purpose.leisureAcquisition.owner=='SAO.LeisureMusic')
local forged={};for key,value in pairs(danceRow)do forged[key]=value end
forged.requirement={};for key,value in pairs(danceRow.requirement)do forged.requirement[key]=value end
forged.requirement.activity='listen-recorded-music'
check('wrong_activity_cannot_start_dance_acquisition',not A.begin('person',__body,forged))

-- Exact controlled native transfer receipt is the only transport substitute.
__items={__device}
purpose.leisureAcquisition.resultId='controlled:pickup:20'
purpose.steps[1].status='completed';purpose.cursor=2
local receipt={status='completed',operation='acquire',measurement='native-item-transfer',
    observedQuantity=1,preRevision=option.parameters.revision,at=__hours,
    purposeId=purposeId,itemId=20,itemType=itemType,sourceId=option.parameters.sourceId}
SAO.WorldSources.actionOutcome=function(id,actor)
    return id=='controlled:pickup:20'and actor=='person'and receipt or nil
end
local selected=assert(personalOffer())
local retained=A.acquiredPurpose('person',__body,'SAO.LeisureMusic',selected)
check('exact_acquired_device_retains_dance_purpose',retained and retained.id==purposeId
    and selected.itemKey=='item:20:'..itemType)
local wrong={};for key,value in pairs(selected)do wrong[key]=value end
wrong.activity='listen-recorded-music'
check('wrong_activity_cannot_reuse_dance_purpose',not A.acquiredPurpose('person',__body,'SAO.LeisureMusic',wrong))
local planned=assert(P.planLeisure('person',{activity=selected.activity,activityKey=selected.id,
    itemKey=selected.itemKey,owner='SAO.LeisureMusic',affordance=selected.sourceId,
    acquiredPurposeId=purposeId,atLocation=true,locationKey='actual-personal-device-place'}))
check('dance_plan_reuses_exact_acquisition_purpose',planned==purpose and planned.leisure.activity==selected.activity)
local accepted,work=M.begin('person',__body,selected,purposeId)
check('dance_work_uses_acquired_purpose',accepted and work.purposeId==purposeId and state.isPlaying)
local advanced,reason=M.advance('person',__body)
assert(advanced,tostring(reason))
local action=assert(__queued)
action:start();action:update()
check('acquired_device_dance_requires_original_cycle',M.work('person') and not M.outcome('person',work.sequence)
    and not M.work('person').nativeProgress.sourceDanceCycle)
__seconds=40;action:update()
local outcome=M.outcome('person',work.sequence)
check('acquisition_to_original_dance_callback_completed',outcome and outcome.status=='completed'
    and outcome.purposeId==purposeId and outcome.nativeProgress.sourceDanceCycle
    and outcome.nativeProgress.sourceDanceCycle.sourceCallbackCompleted
    and purpose.status=='completed' and not state.isPlaying)
SAOJavaBridge.leisureMaterialRequirements=bridgeRequirements
