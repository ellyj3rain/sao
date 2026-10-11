-- Actual ordinary Controller/Needs/Planner over explicitly controlled actor/dispatch
-- ports. Native scene doorway translation/collision, region and sleep are forwarded separately.
local function setup(f)
    local nativeFeedback=SAO.Cognition.shelterOutcome
    SAO.Cognition.shelterOutcome=function(id,receipt)
        local accepted,reason=nativeFeedback(id,receipt)
        print('SHELTER_FEEDBACK kind='..tostring(receipt.kind)..' accepted='..tostring(accepted)..' reason='..tostring(reason)
            ..' attempted='..tostring(receipt.nativeAttempted)..' complete='..tostring(receipt.nativeCompleted)..' credit='..tostring(receipt.nativeCredit))
        return accepted,reason
    end
    SAO.Disposition.eatAt=function()return .8 end;SAO.Disposition.drinkAt=function()return .8 end
    SAO.Perception.believedThreatCount=function()return 0 end
    SAO.Standing.insideClaim=function()return true end;SAO.Study={active=function()return false end}
    SAO.Needs.bleeding=function()return 0 end;SAO.Needs.cold=function()return 0 end
    SAO.Needs.recoveryPreference=function()return 'sleep',{} end
    SAO.Needs.recoveryAlternatives=function()return {{id='sleep'}} end
    function f.body:getCurrentStateName()return self.nativeState or 'IdleState' end
    function f.body:isOnBed()return false end
    function f.body:isResting()return self.resting==true end
    function f.body:isAsleep()return __nativeShelter('sceneAsleep') end
    function f.body:getBed()return nil end;function f.body:getSitOnFurnitureObject()return nil end
    function f.body:faceThisObject()end
    function f.body:getTimedActionToRetrigger()return nil end
    SAOJavaBridge.setShellAsleep=function(_,body,value)body.asleep=__nativeShelter('sceneSleep',value) end
    SAO.Needs.read=function(body)return body==f.body and __nativeShelter('sceneNeeds') or nil end
    SAO.RecoveryPose={pendingExits={}}
    SAO.RecoveryPose.begin=function(body,kind,id,place)
        if not __nativeShelter('sceneGroundClear',place.x..','..place.y..','..place.z) then return nil,'native-ground-clearance-refused' end
        f.nativeEntries=(f.nativeEntries or 0)+1;body.groundPose=true
        return {body=body,kind=kind,id=id,place=place}
    end
    SAO.RecoveryPose.poll=function()return 'admitted' end
    SAO.RecoveryPose.observed=function(body)return body.groundPose==true end
    SAO.RecoveryPose.cancel=function(work)
        if f.holdExit then return false,'pending-safe-exit' end;work.body.groundPose=false;return true
    end
    SAO.RecoveryPose.retire=function()end
    SAOJavaBridge.hasPendingActions=function(_,body)
        local q=ISTimedActionQueue.getTimedActionQueue(body);return q.current~=nil or #q.queue>0
    end
    SAO.Controller.resourceContext=function()return {sources={}} end
    SAOJavaBridge.setForceEntry=function()return true end
end
local function materials(f,id)
    __nativeShelter('reset',id);__nativeShelter('face',f.orientation);f.entityId=id
    f.inventory.items={};f.materials={};f.materialById={}
    for itemId=100,99+__nativeShelter('count') do
        local item=__boardingItem(__nativeShelter('type',itemId):sub(6),itemId,f.inventory)
        item.condition=__nativeShelter('condition',itemId)
        function item:getFluidContainer()return nil end
        function item:getFluidContainerFromSelfOrWorldItem()return nil end
        function item:hasTag(tag)return self:getType()=='Hammer' and tag==ItemTag.HAMMER end
        f.inventory.items[#f.inventory.items+1]=item;f.materials[#f.materials+1]=item;f.materialById[itemId]=item
    end
    f.hammer=f.materials[1];f.tool=f.hammer
end
function __runShelterControllerCases()
    local Ctl,R,P,N=SAO.Controller,SAO.ResourceProduction,SAO.ProceduralPlanning,SAO.Needs
    local f=__shelterFixture('ordinary-shelter','N','Base.WoodDoorFrameLvl1');setup(f)
    __nativeShelter('sceneSetup','N',f.id)
    local admitted=Ctl.offerRecovery(f.id,f.agent,f.body,100,{hunger=.1,thirst=.1,fatigue=.65,endurance=.8},'sleep')
    __shelterCheck('ordinary_shelter_concern_admits_native_stage',admitted and f.agent.state=='RESOURCE' and f.rec.resourceProductionWork~=nil)
    local purposeId=f.rec.resourceProductionWork and f.rec.resourceProductionWork.purposeId
    local row=__shelterFinish(f)
    __shelterCheck('native_frame_keeps_original_shelter_concern',row and row.status=='completed'
        and f.rec.proceduralPlanning.purposes[purposeId].status~='completed' and not f.rec.recoveryExperiences)
    materials(f,'Base.WoodenDoorLvl1');f.agent.state='IDLE'
    admitted=Ctl.offerRecovery(f.id,f.agent,f.body,200,{hunger=.1,thirst=.1,fatigue=.65,endurance=.8},'sleep')
    row=__shelterFinish(f)
    __shelterCheck('native_leaf_continues_same_concern',admitted and row and row.status=='completed' and row.purposeId==purposeId
        and f.nativePayments==2 and f.created:isDoor() and not f.rec.recoveryExperiences)
    local door=f.created
    function door:ToggleDoor(body)
        __nativeShelter('sceneToggle');self.open=__nativeShelter('sceneOpen')
    end
    SAOJavaBridge.worldShelterBeginPassage=function(_,body,target,key,revision,inward)
        return body==f.body and target==door and __nativeShelter('sceneBeginPassage',inward) or nil
    end
    SAOJavaBridge.worldShelterPassage=function(_,body,token)
        return body==f.body and __nativeShelter('scenePassageReceipt',token)
    end
    SAOJavaBridge.worldShelterForgetPassage=function(_,body,token)
        return __nativeShelter('sceneForgetPassage',token)
    end
    SAO.Locomotion.tick=function(id)
        local job=SAO.Locomotion.jobs[id]
        local doorway=math.floor(job.goal.x)==10 and (math.floor(job.goal.y)==20 or math.floor(job.goal.y)==19)
        local already=(f.body:getX()-job.goal.x)^2+(f.body:getY()-job.goal.y)^2<=.35^2
        local arrived=already or doorway and __nativeShelter('scenePass',math.floor(job.goal.y)==20)
            or __nativeShelter('sceneMove',job.goal.x..','..job.goal.y..','..job.goal.z)
        local position=__nativeShelter('scenePosition')
        f.body.x,f.body.y,f.body.z=position.x,position.y,position.z
        local x,y=math.floor(position.x),math.floor(position.y)
        f.body.here=f.cell:getGridSquare(x,y,position.z) or __shelterSquare(f,x,y)
        if arrived then
            job.done,job.result=true,'arrived'
        end
    end
    SAOJavaBridge.worldShelterCover=function(_,body,x,y,z)
        return body==f.body and __nativeShelter('sceneCover',x..','..y..','..z) or nil
    end
    SAOJavaBridge.recoveryPlaces=function(_,body)
        return body==f.body and __nativeShelter('sceneRecoveryPlaces') or nil
    end
    SAOJavaBridge.worldShelterRecoveryValid=function(_,body,key,revision,x,y,z,reached)
        return body==f.body and __nativeShelter('sceneRecoveryValid',x..','..y..','..z,reached) or false
    end
    f.agent.state='IDLE'
    admitted=Ctl.offerRecovery(f.id,f.agent,f.body,300,{hunger=.1,thirst=.1,fatigue=.65,endurance=.8},'sleep')
    __shelterCheck('construction_only_unlocks_separate_use',admitted and f.rec.resourceProductionWork
        and f.rec.resourceProductionWork.kind=='use-shelter' and not f.rec.recoveryExperiences)
    for count=1,8 do
        local q=ISTimedActionQueue.getTimedActionQueue(f.body)
        local drained=0
        while q.current do
            drained=drained+1;if drained>5 then print("door drain stalled");break end
            local a=q.current;print('door before '..tostring(a.Type)..' valid '..tostring(a:isValid())..' stage '..tostring(f.rec.resourceProductionWork and f.rec.resourceProductionWork.stage))
            local started=a:start();a.action.nativeFinished=true;print('door guards current='..tostring(q.current==a)..' first='..tostring(q.queue[1]==a)..' index='..tostring(q:indexOf(a))..' started='..tostring(a.action:isStarted())..' ended='..tostring(a.action:finished())..' valid='..tostring(a:isValid())..' actor='..tostring(a.character==f.body)..' registry='..tostring(ISTimedActionQueue.queues[f.body]==q));local performed=a:perform();print('door callbacks '..tostring(started)..' '..tostring(performed))
            if a.Type=='ISOpenCloseDoor' then print('door complete '..tostring(a:complete())) end
        end
        local status=R.tick(f.id,f.body);print('ordinary native use '..tostring(status))
        if not f.rec.resourceProductionWork then break end
    end
    local results=f.rec.resourceProductionOutcomes;local used=results[#results]
    print('use outcome '..tostring(used.status)..' '..tostring(used.detail)..' opened='..tostring(used.opened)..' nativeopen='..tostring(__nativeShelter('sceneOpen')))
    __shelterCheck('same_body_native_open_cross_close_and_enclosure',used and used.status=='completed' and used.kind=='use-shelter'
        and used.opened and used.crossedOut and used.crossedIn and used.closedDoor and used.enclosureConfirmed
        and __nativeShelter('scenePassages')==2 and not __nativeShelter('sceneOpen') and f.nativePayments==2)
    local purpose=f.rec.proceduralPlanning.purposes[purposeId]
    __shelterCheck('usable_shelter_promotes_ordinary_recovery_without_relief',purpose.shelterConstruction.usedWorkId==used.id
        and purpose.steps[purpose.cursor].status=='available' and not f.rec.recoveryExperiences)
    __shelterCheck('native_doorway_circulation_cannot_supply_ground_place',not __nativeShelter('sceneGroundClear','10.5,20.5,0'))
    __shelterCheck('native_outside_place_cannot_admit_shelter_recovery',not __nativeShelter('sceneRecoveryValid','10.5,19.5,0',false))
    f.agent.state='IDLE';admitted=Ctl.offerRecovery(f.id,f.agent,f.body,400,N.read(f.body),'sleep')
    print('RECOVERY offered='..tostring(admitted)..' state='..tostring(f.agent.state)..' observation='..tostring(f.rec.recoveryPlaceObservation and f.rec.recoveryPlaceObservation.status))
    local route=f.agent.recoveryRoute
    if admitted and route then
        SAO.Locomotion.tick(f.id);__shelterControllerTick(401);Ctl.finishRecoveryPlaceMovement(f.id,f.agent,f.body)
    end
    __shelterCheck('original_concern_admits_ordinary_ground_recovery',admitted and purpose.admission and purpose.admission.owner=='SAONeeds')
    local place=f.rec.recoveryIntent and f.rec.recoveryIntent.place
    __shelterCheck('native_recovery_place_is_safe_interior',place and place.kind=='ground' and place.key~='ground:10:20:0'
        and __nativeShelter('sceneGroundClear',place.x..','..place.y..','..place.z)
        and __nativeShelter('sceneRecoveryValid',place.x..','..place.y..','..place.z,true))
    local preparing=N.pollRecovery(f.id,f.body)
    local before=N.read(f.body).fatigue
    local nativeMeasured=preparing=='running' and __nativeShelter('sceneSleepTicks')
    __hours=__hours+.1
    local actualConsume=P.consumeShelterRecovery
    P.consumeShelterRecovery=function(id,sequence)
        local canonical=f.rec.recoveryExperiences[#f.rec.recoveryExperiences];local key=canonical.sourceId
        canonical.sourceId='ground:wrong:canonical:key'
        local refused=actualConsume(id,sequence)==false and purpose.status~='completed'
        canonical.sourceId=key
        __shelterCheck('canonical_ground_key_mismatch_cannot_finish',refused)
        P.consumeShelterRecovery=actualConsume
        return actualConsume(id,sequence)
    end
    local recovered=N.pollRecovery(f.id,f.body)
    __shelterCheck('native_sleep_finishes_original_shelter_concern',nativeMeasured and recovered=='completed'
        and purpose.status=='completed' and f.nativeEntries==1 and #f.rec.recoveryExperiences==1
        and f.rec.recoveryExperiences[1].sourceId==place.key and f.rec.recoveryExperiences[1].beforeValue==before)
    print('FEEDBACK count='..#f.rec.cognition.experiences..' ordinary='..f.rec.cognition.models.ordinary.revision..' associative='..f.rec.cognition.models.associative.revision)
    for _,experience in ipairs(f.rec.cognition.experiences) do print('FEEDBACK kind='..tostring(experience.kind)) end
    __shelterCheck('construction_use_and_recovery_keep_independent_feedback',#f.rec.cognition.experiences==4
        and f.rec.cognition.experiences[1].kind=='shelter-construction' and f.rec.cognition.experiences[2].kind=='shelter-construction'
        and f.rec.cognition.experiences[3].kind=='shelter-use' and f.rec.cognition.experiences[4].kind=='recovery-outcome'
        and f.rec.cognition.models.ordinary.revision==4 and f.rec.cognition.models.associative.revision==4)
    local count=#f.rec.cognition.experiences
    R.reconcileSaved(f.id,f.body);R.reconcileSaved(f.id,f.body)
    __shelterCheck('canonical_shelter_feedback_replay_is_once',#f.rec.cognition.experiences==count)
end
