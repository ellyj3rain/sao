-- Ordinary Controller and actual Needs recovery accounting over controlled
-- native-entry/body ports. Fatigue samples come from real installed sleep ticks.
local function setup(f)
    SAO.Disposition.eatAt=function() return .8 end
    SAO.Disposition.drinkAt=function() return .8 end
    SAO.Perception.believedThreatCount=function() return 0 end
    SAO.Standing.insideClaim=function() return true end
    SAO.Study={active=function() return false end}
    SAO.Needs.bleeding=function() return 0 end
    SAO.Needs.cold=function() return 0 end
    SAO.Needs.recoveryPreference=function() return 'sleep',{} end
    SAO.Needs.recoveryAlternatives=function() return {{id='sleep'}} end
    function f.body:getCurrentStateName() return self.nativeState or 'IdleState' end
    function f.body:isOnBed() return self.onBed==true end
    function f.body:isResting() return self.resting==true end
    function f.body:isAsleep() return self.asleep==true end
    function f.body:getBed() return self.bed end
    function f.body:getSitOnFurnitureObject() return self.bed end
    function f.body:setBed(item) self.bed=item end
    SAOJavaBridge.setShellAsleep=function(_,body,value) body.asleep=value end
    SAO.RecoveryPose={pendingExits={}}
    SAO.RecoveryPose.begin=function(body,kind,id,place)
        f.nativeEntries=(f.nativeEntries or 0)+1
        body.onBed=true;body.bed=f.siteSquare.objects[1]
        return {body=body,kind=kind,id=id,place=place,bed=body.bed}
    end
    SAO.RecoveryPose.poll=function() return 'admitted' end
    SAO.RecoveryPose.observed=function(body) return body.onBed==true end
    SAO.RecoveryPose.cancel=function(work)
        if f.holdExit then return false,'pending-safe-exit' end
        work.body.onBed=false;work.body.bed=nil;return true
    end
    SAO.RecoveryPose.retire=function() end
    SAOJavaBridge.hasPendingActions=function(_,body)
        local q=ISTimedActionQueue.getTimedActionQueue(body);return q.current~=nil or #q.queue>0
    end
    SAO.Controller.resourceContext=function() return {sources={}} end
end
local function recover(f)
    f.agent.state='IDLE'
    local needs=SAO.Needs.read(f.body)
    local admitted=SAO.Controller.offerRecovery(f.id,f.agent,f.body,1000,needs,'sleep')
    if not admitted then return false end
    if SAO.Needs.pollRecovery(f.id,f.body)~='running' then return false end
    f.body.fatigue=__nativeSleepAfter
    __hours=__hours+.1
    return SAO.Needs.pollRecovery(f.id,f.body)=='completed'
end
function __runBedControllerCases()
    local Ctl,P,N=SAO.Controller,SAO.ProceduralPlanning,SAO.Needs
    local f=__bedFixture('ordinary-native-bed','S');setup(f)
    local admitted=Ctl.offerRecovery(f.id,f.agent,f.body,100,{hunger=.1,thirst=.1,fatigue=.65,endurance=.8},'sleep')
    __bedCheck('ordinary_recovery_choice_dispatches_bed_construction',admitted and f.agent.state=='RESOURCE' and f.rec.resourceProductionWork~=nil)
    local purpose=f.rec.resourceProductionWork and f.rec.resourceProductionWork.purposeId
    local row=__bedFinish(f)
    __bedCheck('canonical_bed_creation_unlocks_recovery_without_relief',row and row.status=='completed'
        and f.rec.proceduralPlanning.purposes[purpose].steps[f.rec.proceduralPlanning.purposes[purpose].cursor].status=='available'
        and f.rec.proceduralPlanning.purposes[purpose].status~='completed' and not f.rec.recoveryExperiences)
    f.purpose=f.rec.proceduralPlanning.purposes[purpose]
    __bedCheck('same_ordinary_concern_uses_created_bed_and_native_sleep_sample',recover(f)
        and f.purpose.status=='completed' and f.nativeEntries==1 and #f.rec.recoveryExperiences==1
        and f.rec.recoveryExperiences[1].sourceId==row.bedKey and f.rec.recoveryExperiences[1].beforeValue==__nativeSleepBefore)
    __bedCheck('construction_and_recovery_have_separate_private_credit',#f.rec.cognition.experiences==2
        and f.rec.cognition.experiences[1].kind=='bed-construction' and f.rec.cognition.experiences[2].kind=='recovery-outcome')
    __bedCheck('ordinary_existing_bed_prevents_reconstruction',not f.rec.resourceProductionWork and f.nativePayments==1)
    f=__bedFixture('bed-entry-interrupted','E');setup(f);__bedBegin(f);row=__bedFinish(f)
    f.agent.state='IDLE';Ctl.offerRecovery(f.id,f.agent,f.body,100,{hunger=.1,thirst=.1,fatigue=.65,endurance=.8},'sleep')
    local purpose=f.purpose
    f.holdExit=true;N.stopRecovery(f.id,f.body,'entry-interrupted');f.agent.recovery=false;f.agent.resting=false
    __bedCheck('pending_native_exit_keeps_exact_recovery_admission',purpose.admission and not P.reconcileBedRecovery(f.id,f.body)
        and purpose.bedConstruction.constructedWorkId==row.id)
    f.holdExit=false;f.body.onBed=false;f.body.bed=nil;f.body.asleep=false
    __bedCheck('native_quiet_exit_retires_only_recovery_attempt',P.reconcileBedRecovery(f.id,f.body) and not purpose.admission
        and purpose.bedConstruction.constructedWorkId==row.id and f.nativePayments==1)
    if __selectedBedControl=='interrupted-recovery-retirement' then return end
    __bedCheck('interrupted_entry_retry_completes_without_rebuild',recover(f) and purpose.status=='completed' and f.nativePayments==1)
    f=__bedFixture('bed-saved-entry','S');setup(f);__bedBegin(f);row=__bedFinish(f)
    f.agent.state='IDLE';Ctl.offerRecovery(f.id,f.agent,f.body,100,{hunger=.1,thirst=.1,fatigue=.65,endurance=.8},'sleep')
    local saved=__nativeRoundtrip(f.rec);N.stopRecovery(f.id,f.body,'saved-body-retired')
    __records[f.id]=saved;f.rec=saved;f.agent.rec=saved;f.purpose=saved.proceduralPlanning.purposes[row.purposeId]
    -- Existing saved preparation cancellation establishes the quiet old attempt,
    -- and ordinary visible reobservation gives the actual new runtime bed key.
    local oldBody=f.body;local replacement={}
    for key,value in pairs(oldBody) do replacement[key]=value end
    replacement.md={SAOPersonId=f.id};replacement.onBed=false;replacement.bed=nil;replacement.asleep=false
    f.body=replacement;SAO.Body.active[f.id]=replacement;f.agent.recovery=false;f.agent.resting=false
    assert(N.cancelPreparingRecovery(f.id,saved,saved.recoveryIntent,'saved-old-body-preparation-ended'))
    local originalQuery=SAOJavaBridge.recoveryPlaces
    SAOJavaBridge.recoveryPlaces=function(...)
        local value=originalQuery(...);for _,place in ipairs(value.places) do place.key=place.key..'-reloaded' end;return value
    end
    __bedCheck('saved_recovery_uses_fresh_key_after_quiet_reconciliation',recover(f) and f.purpose.status=='completed'
        and f.purpose.bedConstruction.bedKey:find('reloaded',1,true)~=nil and f.nativePayments==1)
end

function __runBedPrivateAcquisitionCases()
    local Ctl,P=SAO.Controller,SAO.ProceduralPlanning
    local f=__bedFixture('missing-private-bed-inputs','S');setup(f)
    f.inventory.items={f.hammer};local known={}
    for _,item in ipairs(f.materials) do if item~=f.hammer then known[#known+1]=item end end
    Ctl.resourceContext=function(id,agent,body,needs,category)
        local out={}
        for _,item in ipairs(known) do
            local kind=item:getType()=='Plank' and 'plank' or item:getType()=='Nails' and 'nails' or 'mattress'
            if kind==category then out[#out+1]={sourceId='C:known-bed-kit',revision='kit-revision',category=category,
                itemId=item:getID(),itemType=item:getFullType(),known=true,distance=1,
                place={id='known-private-stock',cx=1,cy=0,z=0}} end
        end
        return {sources=out}
    end
    SAO.SourceUse={beginAcquisition=function(id,body,place,category,context)
        f.acquisition=context;context.category=category
        return P.noteAdmission(id,context.purposeId,'SAO.SourceUse','bed-input-'..context.itemId,context.purposeStepId)
    end}
    local sourceRow
    SAO.WorldSources.actionOutcome=function() return sourceRow end
    local purposeId;local acquired=true
    for index=1,11 do
        f.agent.state='IDLE'
        local admitted=Ctl.offerRecovery(f.id,f.agent,f.body,100+index,{hunger=.1,thirst=.1,fatigue=.65,endurance=.8},'sleep')
        if not admitted or not f.acquisition then acquired=false;break end
        local context=f.acquisition
        purposeId=purposeId or context.purposeId
        local p=f.rec.proceduralPlanning.purposes[purposeId]
        if context.purposeId~=purposeId or p.status=='completed' or f.nativePayments then acquired=false end
        sourceRow={actorId=f.id,operation='acquire',reservationId='bed-input-'..context.itemId,
            purposeId=context.purposeId,purposeStepId=context.purposeStepId,status='completed',measurement='native-item-transfer',
            observedQuantity=1,sourceId=context.sourceId,preRevision=context.sourceRevision,itemId=context.itemId,
            itemType=context.itemType,category=context.category,at=__hours}
        local item=f.materialById[tonumber(context.itemId)];f.inventory.items[#f.inventory.items+1]=item;item.container=f.inventory
        for i,v in ipairs(known) do if v==item then table.remove(known,i);break end end
        acquired=acquired and P.consumeSourceResult(sourceRow)==true
        f.acquisition=nil
    end
    __bedCheck('eleven_exact_private_inputs_preserve_original_sleep_concern',acquired and #f.inventory.items==12
        and f.rec.proceduralPlanning.purposes[purposeId].status~='completed')
    f.agent.state='IDLE'
    local admitted=Ctl.offerRecovery(f.id,f.agent,f.body,150,{hunger=.1,thirst=.1,fatigue=.65,endurance=.8},'sleep')
    __bedCheck('acquired_materials_dispatch_native_bed_under_same_purpose',admitted and f.rec.resourceProductionWork
        and f.rec.resourceProductionWork.purposeId==purposeId)
    local row=__bedFinish(f)
    __bedCheck('private_source_materials_build_and_recover_same_concern',row and row.status=='completed' and recover(f)
        and f.rec.proceduralPlanning.purposes[purposeId].status=='completed')
end
