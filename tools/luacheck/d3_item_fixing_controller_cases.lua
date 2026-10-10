function __runFixingControllerCases(fixture,finish,check,control)
    local Ctl,P,R=SAO.Controller,SAO.ProceduralPlanning,SAO.ResourceProduction
    local f=fixture('controller-'..tostring(control or 'ordinary'))
    Ctl.reconcileConstruction=function() return true end
    Ctl.resourceContext=function() return {sources={}} end
    if control~='private-donor' then
        local context=Ctl.toolMaintenanceContext(f.id,f.agent,f.body)
        check('controller_projects_registered_fixing_and_exact_donor',#context.options>0 and context.options[1].productionKind=='fix-held-item'
            and context.options[1].toolItemId=='702' and context.options[1].requiredItemType=='Base.Pistol')
        SAO.Disposition.traits=function() return {discipline=.8} end
        local dispatched=__ordinaryNativeItemFixingChoice(f.id,f.agent,f.body,100)
        check('controller_ordinary_maintenance_dispatches_native_fixing',dispatched==true and f.agent.state=='RESOURCE' and f.rec.resourceProductionWork~=nil)
        if control then return end
        local purpose=f.rec.resourceProductionWork and f.rec.resourceProductionWork.purposeId
        local interpretations=f.rec.proceduralPlanning.purposes[purpose].interpretations
        check('controller_private_choice_uses_both_interpreters',interpretations and interpretations.models and #interpretations.models==2)
        local row=finish(f)
        check('controller_same_gun_reuse_closes_exact_maintenance_purpose',row and row.status=='completed'
            and row.purposeId==purpose and f.rec.proceduralPlanning.purposes[purpose].status=='completed' and f.body:getPrimaryHandItem()==f.target)
    end
    f=fixture('controller-private-'..tostring(control or 'normal'))
    f.inventory.items={f.target}
    local source={sourceId='C:private-donor',revision='revision-1',category='weapons',known=true,itemId='702',itemType='Base.Pistol',
        distance=1,place={key='private-stock',x=1,y=1,z=0,knownGround=true}}
    local wrong={sourceId='C:wrong',revision='revision-1',category='weapons',known=true,itemId='wrong',itemType='Base.Pistol2',
        distance=0,place={key='wrong-stock',x=1,y=1,z=0,knownGround=true}}
    Ctl.resourceContext=function() return {sources={wrong,source}} end
    SAO.WorldSources={}
    SAO.SourceUse={beginAcquisition=function(id,body,place,category,context)
        f.acquisition=context;f.acquisition.category=category
        return P.noteAdmission(id,context.purposeId,'SAO.SourceUse','exact-private-reservation',context.purposeStepId)
    end}
    local context=Ctl.toolMaintenanceContext(f.id,f.agent,f.body)
    local dispatched=Ctl.tryToolMaintenance(f.id,f.agent,f.body,101,context)
    if not f.acquisition then local p,step,reason=P.planToolMaintenance(f.id,context);print('private route status '..tostring(dispatched)..' reason='..tostring(reason)..' option='..tostring(#context.options)..' type='..tostring(context.options[1] and context.options[1].requiredItemType)..' source='..tostring(context.sources.weapons and #context.sources.weapons)..' step='..tostring(step and step.verb)..' status='..tostring(step and step.status)) end
    check('controller_only_exact_privately_known_donor_acquired',dispatched==true and f.acquisition~=nil
        and f.acquisition.sourceId==source.sourceId and f.acquisition.itemId=='702' and f.acquisition.itemType=='Base.Pistol')
    if control then return end
    local purpose=f.rec.proceduralPlanning.purposes[f.acquisition.purposeId]
    check('private_acquisition_keeps_same_target_and_unfinished_purpose',purpose and purpose.materialWork.targetItemId=='701'
        and purpose.admission and not f.rec.resourceProductionWork and purpose.status~='completed')
    local pending=P.planToolMaintenance(f.id,context)
    check('pending_source_admission_keeps_exact_purpose',pending==purpose and pending.admission.correlationId=='exact-private-reservation')
    local event={actorId=f.id,reservationId='exact-private-reservation',operation='acquire',status='completed',
        purposeId=purpose.id,purposeStepId=f.acquisition.purposeStepId,sourceId=source.sourceId,preRevision=source.revision,
        itemId=source.itemId,itemType=source.itemType,category='weapons',measurement='native-item-transfer',observedQuantity=1,at=100}
    SAO.WorldSources={actionOutcome=function() return event end}
    event.sourceId=wrong.sourceId
    check('wrong_private_donor_source_cannot_advance',P.consumeSourceResult(event)==false and purpose.admission~=nil)
    event.sourceId=source.sourceId
    f.inventory.items[#f.inventory.items+1]=f.tool;f.tool.container=f.inventory
    check('authenticated_private_donor_receipt_advances',P.consumeSourceResult(event)==true and purpose.admission==nil)
    local restored=__nativeRoundtrip(f.rec);__records[f.id]=restored;f.rec=restored;f.agent.rec=restored;f.agent.state='IDLE'
    context=Ctl.toolMaintenanceContext(f.id,f.agent,f.body)
    check('saved_same_purpose_resumes_native_fixing',Ctl.tryToolMaintenance(f.id,f.agent,f.body,102,context)==true
        and f.rec.resourceProductionWork and f.rec.resourceProductionWork.purposeId==purpose.id)
    local row=finish(f)
    check('private_acquire_native_fix_and_reuse_complete_same_purpose',row and row.status=='completed' and row.purposeId==purpose.id
        and f.rec.proceduralPlanning.purposes[purpose.id].status=='completed' and row.reequipped)
    f=fixture('controller-unknown');f.inventory.items={f.target};Ctl.resourceContext=function() return {sources={}} end
    context=Ctl.toolMaintenanceContext(f.id,f.agent,f.body)
    check('unknown_donor_has_no_synthetic_work',Ctl.tryToolMaintenance(f.id,f.agent,f.body,103,context)==false and not f.rec.resourceProductionWork)
end
