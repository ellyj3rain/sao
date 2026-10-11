-- Installed native stair recipes, construction callbacks, measured footprint and landing.
-- Actor-private observations forward the independent native scene. Dispatch/material-source ports are controlled.
DesignationZoneAnimal={addNewRoof=function()end};FBORenderChunk={DIRTY_OBJECT_ADD=1}
function sendServerCommand()end;function invalidateLighting()end
IsoFlagType=setmetatable({},{__index=function(_,key)return key end})
function getMaximumWorldLevel()return 31 end
function string.contains(s,part)return s:find(part,1,true)~=nil end
local function square(f,x,y,z)
    local key=x..':'..y..':'..z;local prior=f.cell.squares[x..':'..y..':0']
    local sq=f.cell.squares[key]
    if not sq then sq=__shelterSquare(f,x,y);sq.z=z;f.cell.squares[x..':'..y..':0']=prior;f.cell.squares[key]=sq end
    local coordinates=x..','..y..','..z
    function sq:getCell()return f.cell end
    function sq:getFloor()
        if not __nativeShelter('nativeFloor',coordinates) then return nil end
        return {getSprite=function()return {getProperties=function()return {has=function(_,key)return __nativeShelter('nativeFloorHas',coordinates,key) end} end} end}
    end
    function sq:has(key)return __nativeShelter('nativeSquareHas',coordinates,key) end
    function sq:getProperties()return {has=function(_,key)return __nativeShelter('nativeSquareHas',coordinates,key) end} end
    function sq:getWall(north)return __nativeShelter('nativeWall',coordinates,north) end
    function sq:getModData()return __nativeShelter('nativeModData',coordinates) end
    function sq:isSolid()return __nativeShelter('nativeSolid',coordinates) end
    function sq:isSolidTrans()return false end
    function sq:addFloor(sprite)return __nativeShelter('nativeAddFloor',coordinates,sprite) end
    function sq:RecalcAllWithNeighbours()return __nativeShelter('surfaceRecalcNeighbours',coordinates) end
    return sq
end
local function measuredPosition(f)
    local p=__nativeShelter('scenePosition');f.body.x,f.body.y,f.body.z=p.x,p.y,p.z
    f.body.here=square(f,math.floor(p.x),math.floor(p.y),math.floor(p.z));return p
end
local function fixture(id,face)
    local f=__shelterFixture(id,face,'Base.Wood_Stairs');__shelterControllerSetup(f)
    assert(__nativeShelter('stairsSceneSetup',face,id));assert(__nativeShelter('stairsLook',face));measuredPosition(f)
    function __world:isValidSquare(x,y,z)return __nativeShelter('nativeWorldValid',x..','..y..','..z) end
    f.mode='stairs';f.rootX,f.rootY=face=='S' and 10 or 11,face=='S' and 21 or 20
    f.siteSquare=square(f,f.rootX,f.rootY,0)
    -- The callback owns upper validity and landing creation; these proxy squares assert no private upper fact.
    for x=5,17 do for y=14,25 do for z=0,2 do square(f,x,y,z) end end end
    SAOJavaBridge.worldShelterSurfaces=function(_,body)return body==f.body and __nativeShelter('surfaceSites') or {} end
    SAOJavaBridge.worldShelterStairSites=function(_,body)
        local out={}
        if body~=f.body or f.hideFootprint then return out end
        for _,row in ipairs(__nativeShelter('stairsSites')) do
            if row.x==f.rootX and row.y==f.rootY and row.z==0 and row.face==face then out[#out+1]=row end
        end;return out
    end
    SAOJavaBridge.worldShelterCoverNeeds=function(_,body)return body==f.body and __nativeShelter('surfaceCoverNeeds') or {} end
    SAOJavaBridge.worldShelterAccess=function(_,body)return body==f.body and __nativeShelter('surfaceAccess') or {} end
    SAOJavaBridge.worldShelterSites=function(_,body,x,y,z)return body==f.body and __nativeShelter('sceneSites',x..','..y..','..z) or {} end
    SAOJavaBridge.worldShelterStairPlacementSquare=function(_,body,key,revision)
        return body==f.body and __nativeShelter('stairsPlacement',key,revision) and f.siteSquare or nil
    end
    SAOJavaBridge.worldShelterStairsCreated=function(_,body,parts,x,y,z,orientation)
        return body==f.body and #parts==3 and x==f.rootX and y==f.rootY and z==0 and orientation==face
            and __nativeShelter('stairsCreated') and not f.createdRefused
    end
    SAOJavaBridge.worldShelterCover=function(_,body,x,y,z)return body==f.body and __nativeShelter('sceneCover',x..','..y..','..z) or nil end
    SAO.Locomotion.tick=function(pid)
        local job=SAO.Locomotion.jobs[pid];local arrived=__nativeShelter('sceneMove',job.goal.x..','..job.goal.y..','..job.goal.z)
        measuredPosition(f);job.done,job.result=true,arrived and 'arrived' or 'failed'
    end
    SAO.Cognition.ensureGameDefaults();return f
end
local function plan(f)
    local context=SAO.Controller.shelterConstructionContext(f.id,f.agent,f.body,SAO.Needs.read(f.body),'sleep')
    local p,step=SAO.ProceduralPlanning.planShelterConstruction(f.id,context);f.purpose,f.step=p,step
    print('STAIR_PLAN face='..f.orientation..' offers='..#context.options..' needs='..#context.coverNeeds..' kind='..tostring(step and step.productionKind)..' blockers='..tostring(p and p.blockers[1]))
    return p,step,context
end
local function begin(f)
    local p,step=plan(f)
    return step and step.productionKind=='build-shelter-stairs' and SAO.ResourceProduction.begin(f.id,f.body,step,{purposeId=p.id,purposeStepId=step.id})
end
local function moveToApproach(f)
    local rows=SAOJavaBridge:worldShelterStairSites(f.body);local site=rows[1];assert(site,'native observed stair footprint absent')
    assert(__nativeShelter('sceneMove',(site.approachX+.5)..','..(site.approachY+.5)..',0'));measuredPosition(f)
end
function __runShelterStairsFirst(face)
    local f=fixture('stairs-first-'..face,face);moveToApproach(f)
    local function check(name,pass)__shelterCheck(name..'_'..face,pass) end
    check('scene_begins_without_native_stairs',__nativeShelter('stairsNone') and #__nativeShelter('surfaceAccess')==0)
    local nativeSites=SAOJavaBridge:worldShelterStairSites(f.body)
    local admitted=begin(f);local w=f.rec.resourceProductionWork
    check('native_exact_twenty_two_inputs_and_full_private_footprint',admitted and w and #w.inputs==22
        and #nativeSites==1 and w.site.width*w.site.height==3 and w.site.landingObserved==false
        and w.site.landingBasis=='native-recipe-effect' and w.requirements[2].count==13 and w.requirements[3].count==8)
    local saved=__nativeRoundtrip(f.rec)
    check('actual_saved_stair_claim_retains_all_inputs_and_original_purpose',saved.resourceProductionWork and #saved.resourceProductionWork.inputs==22
        and saved.resourceProductionWork.inputs[22].itemId==w.inputs[22].itemId and saved.resourceProductionWork.face==face
        and saved.proceduralPlanning.purposes[w.purposeId].shelterConstruction.origin.z==0
        and #saved.proceduralPlanning.purposes[w.purposeId].steps[1].inputs==22)
    local row=admitted and __shelterFinish(f)
    print('STAIR_RESULT face='..face..' status='..tostring(row and row.status)..' parts='..tostring(row and #row.parts)..' paid='..tostring(f.nativePayments))
    check('all_native_stair_parts_landing_payment_and_hammer_measured',row and row.status=='completed' and #row.parts==3
        and row.inputsConsumed and row.toolRetained and #row.inputs==22 and f.nativePayments==1 and __nativeShelter('stairsCreated'))
    check('native_partial_or_foreign_parts_refuse_completion',row and not __nativeShelter('stairsPartial') and not __nativeShelter('stairsForeign'))
    check('stair_build_feedback_has_no_travel_or_recovery_credit',row and row.status=='completed' and #f.rec.cognition.experiences==1
        and f.rec.cognition.experiences[1].entityId=='Base.Wood_Stairs' and f.rec.cognition.models.ordinary.revision==1
        and f.rec.cognition.models.associative.revision==1 and not f.rec.recoveryExperiences and f.purpose.status~='completed')
    local site=nativeSites[1]
    local travelled=site and __nativeShelter('sceneMove',(site.landingX+.5)..','..(site.landingY+.5)..',1');measuredPosition(f)
    check('same_body_genuine_native_travel_uses_new_flight',travelled and f.body:getCurrentSquare():getZ()==1 and f.body.z>=1)
end
function __runShelterStairsChain()
    local f=fixture('stairs-to-shelter','W')
    assert(__nativeShelter('sceneMove','10.5,20.5,0'));assert(__nativeShelter('stairsLook','survey'));measuredPosition(f)
    f.inventory.items={f.hammer};local known={}
    for _,item in ipairs(f.materials) do if item~=f.hammer then known[#known+1]=item end end
    SAO.Controller.resourceContext=function(id,agent,body,needs,category)
        local out={}
        for _,item in ipairs(known) do local kind=item:getType()=='Plank' and 'plank' or 'nails'
            if kind==category then out[#out+1]={sourceId='C:personally-known-stair-kit',revision='private-stair-kit-revision',category=category,
                itemId=item:getID(),itemType=item:getFullType(),known=true,distance=1,place={id='private-stock',cx=1,cy=0,z=0}} end
        end;return {sources=out}
    end
    local P=SAO.ProceduralPlanning;local sourceRow;local purposeId;local acquired=true
    local originalSourceOutcome=SAO.WorldSources.actionOutcome
    SAO.WorldSources.actionOutcome=function()return sourceRow end
    SAO.SourceUse={beginAcquisition=function(id,body,place,category,context)
        f.acquisition=context;context.category=category
        return P.noteAdmission(id,context.purposeId,'SAO.SourceUse','stair-input-'..context.itemId,context.purposeStepId)
    end}
    for index=1,21 do
        f.agent.state='IDLE'
        local accepted=SAO.Controller.offerRecovery(f.id,f.agent,f.body,10+index,SAO.Needs.read(f.body),'sleep')
        local context=f.acquisition
        if not accepted or not context then acquired=false;break end
        purposeId=purposeId or context.purposeId
        sourceRow={actorId=f.id,operation='acquire',reservationId='stair-input-'..context.itemId,purposeId=context.purposeId,
            purposeStepId=context.purposeStepId,status='completed',measurement='native-item-transfer',observedQuantity=1,
            sourceId=context.sourceId,preRevision=context.sourceRevision,itemId=context.itemId,itemType=context.itemType,category=context.category,at=__hours}
        if index==1 then
            sourceRow.preRevision='stale-source-revision'
            __shelterCheck('stale_private_stair_source_cannot_advance',not P.consumeSourceResult(sourceRow) and not f.nativePayments)
            sourceRow.preRevision=context.sourceRevision;sourceRow.actorId='foreign-person'
            __shelterCheck('foreign_private_stair_actor_cannot_advance',not P.consumeSourceResult(sourceRow) and not f.nativePayments)
            sourceRow.actorId=f.id;sourceRow.itemId=99999
            __shelterCheck('foreign_exact_stair_item_cannot_advance',not P.consumeSourceResult(sourceRow) and not f.nativePayments)
            sourceRow.itemId=context.itemId
        end
        local item=f.materialById[tonumber(context.itemId)];f.inventory.items[#f.inventory.items+1]=item;item.container=f.inventory
        for n,candidate in ipairs(known) do if candidate==item then table.remove(known,n);break end end
        acquired=acquired and context.purposeId==purposeId and P.consumeSourceResult(sourceRow)==true and not f.nativePayments
        f.acquisition=nil
    end
    f.purpose=P.shelterPurpose(f.id)
    __shelterCheck('twenty_one_exact_private_acquisitions_keep_original_shelter_purpose',acquired and #known==0 and #f.inventory.items==22
        and f.purpose.id==purposeId and f.purpose.status~='completed' and f.purpose.shelterConstruction.origin.originX==10
        and f.purpose.shelterConstruction.origin.originY==20 and not f.rec.recoveryExperiences)
    SAO.WorldSources.actionOutcome=originalSourceOutcome
    local actualObserve=SAO.CognitiveModels.observe;local held=true;local refused=0
    SAO.CognitiveModels.observe=function(model,state,event,depth)
        if held and model=='associative' and event.kind=='shelter-movement' and event.sourceId:sub(1,10)=='reobserve:' then refused=refused+1;return 'held-native-movement-feedback' end
        return actualObserve(model,state,event,depth)
    end
    f.agent.state='IDLE';assert(__nativeShelter('stairsLook','W'));moveToApproach(f)
    __shelterCheck('chain_has_no_stairs_or_upper_access_at_start',__nativeShelter('stairsNone') and #__nativeShelter('surfaceAccess')==0)
    local admitted=begin(f);local row=admitted and __shelterFinish(f)
    __shelterCheck('ordinary_original_shelter_concern_builds_native_access',row and row.status=='completed' and row.kind=='build-shelter-stairs'
        and f.purpose.shelterConstruction.origin.z==0 and f.purpose.status~='completed' and not f.rec.recoveryExperiences)
    assert(row and row.status=='completed','native stairs chain construction failed')
    purposeId=f.purpose.id
    f.orientation='W';__shelterControllerMaterials(f,'Base.WoodFloorLvl1');__nativeShelter('surfaceBuildAt','12,21,1');f.agent.state='IDLE'
    __runShelterSurfaceUpper(f)
    local p=f.rec.proceduralPlanning.purposes[purposeId]
    local before=#f.rec.cognition.experiences
    local pending=0 for _,movement in ipairs(f.rec.proceduralPlanning.shelterMovementResults or {}) do if not movement.experienceDelivered then pending=pending+1 end end
    __shelterCheck('transient_model_refusal_retains_native_movement_receipts',refused>0 and pending>0
        and f.rec.cognition.models.ordinary.revision==before and f.rec.cognition.models.associative.revision==before)
    local reload=__nativeRoundtrip(f.rec);__records[f.id]=reload;f.rec=reload;f.agent.rec=reload;p=reload.proceduralPlanning.purposes[purposeId]
    held=false;SAO.CognitiveModels.observe=actualObserve
    SAO.ResourceProduction.reconcileSaved(f.id,f.body)
    __shelterCheck('ordinary_saved_reconciliation_retries_movement_feedback_once',#reload.cognition.experiences==before+pending
        and reload.cognition.models.ordinary.revision==before+pending and reload.cognition.models.associative.revision==before+pending
        and reload.proceduralPlanning.shelterMovementResults[1].experienceDelivered==true)

    __shelterCheck('new_stairs_cover_return_and_recovery_finish_same_retained_purpose',p.status=='completed'
        and p.shelterConstruction.origin.z==0 and #p.shelterConstruction.constructionResults==4
        and #f.rec.cognition.experiences>=8 and f.rec.cognition.experiences[1].entityId=='Base.Wood_Stairs'
        and f.rec.cognition.experiences[2].kind=='shelter-movement' and f.rec.cognition.experiences[4].kind=='shelter-movement'
        and f.rec.cognition.experiences[7].kind=='shelter-use' and f.rec.cognition.experiences[8].kind=='recovery-outcome')
    local saved=__nativeRoundtrip(f.rec);__records[f.id]=saved;f.rec=saved;f.agent.rec=saved
    local count=#saved.cognition.experiences
    SAO.ResourceProduction.reconcileSaved(f.id,f.body)
    SAO.ProceduralPlanning.reconcileShelterMovement(f.id,f.body)
    __shelterCheck('actual_saved_finished_chain_replays_each_private_owner_once',#saved.cognition.experiences==count
        and saved.cognition.models.ordinary.revision==count and saved.cognition.models.associative.revision==count
        and #saved.resourceProductionOutcomes[1].inputs==22 and saved.proceduralPlanning.purposes[purposeId].status=='completed')
end
function __runShelterStairsGuards()
    local R,P,C=SAO.ResourceProduction,SAO.ProceduralPlanning,SAO.Cognition
    local f=fixture('stairs-hidden','W');f.hideFootprint=true
    local p,step=plan(f)
    __shelterCheck('unacquired_full_footprint_cannot_be_selected',p and not step and not f.rec.resourceProductionWork and not f.nativePayments)
    f=fixture('stairs-skill','W');__nativeShelter('skill',5);p,step=plan(f)
    __shelterCheck('installed_woodwork_six_requirement_owns_admission',p and not step and not f.rec.resourceProductionWork)
    f=fixture('stairs-permission','W');moveToApproach(f)
    local current=SAO.Standing.mayTakeCurrent;SAO.Standing.mayTakeCurrent=function(id,x,y,kind)
        if id==f.id and x==11 and y==21 then return false end;return current(id,x,y,kind)
    end
    local admitted=begin(f)
    if f.rec.resourceProductionWork then R.interrupt(f.id,f.body,'permission') end
    __shelterCheck('denied_middle_footprint_cannot_start_native_payment',not admitted and not f.nativePayments and f.purpose.status~='completed')
    SAO.Standing.mayTakeCurrent=current
    f=fixture('stairs-permission-revoked','W');moveToApproach(f);f.body.primary=f.hammer;assert(begin(f))
    local q=ISTimedActionQueue.getTimedActionQueue(f.body);local action=q.current;action:start()
    SAO.Standing.mayTakeCurrent=function(id,x,y,kind)
        if id==f.id and x==11 and y==21 then return false end;return current(id,x,y,kind)
    end
    action.action.nativeFinished=true;local result=action:perform();R.interrupt(f.id,f.body,'permission-revoked')
    __shelterCheck('revoked_middle_footprint_refuses_before_native_effect',result==false and not f.nativePayments
        and not f.rec.recoveryExperiences and __nativeShelter('stairsNone') and f.purpose.status~='completed')
    SAO.Standing.mayTakeCurrent=current
    f=fixture('stairs-above','W');moveToApproach(f);__nativeShelter('nativeBlockAbove',true)
    admitted=begin(f)
    if f.rec.resourceProductionWork then R.tick(f.id,f.body);R.interrupt(f.id,f.body,'native-upper-obstruction') end
    __shelterCheck('native_unseen_upper_floor_rejects_without_acquired_upper_fact',not f.nativePayments and not f.rec.recoveryExperiences
        and #SAO.Perception.shelterSurfaces(f.id,f.body)==0 and f.purpose.status~='completed')
    f=fixture('stairs-material','W');moveToApproach(f);local missing=f.materials[14];f.inventory:Remove(missing)
    p,step=plan(f)
    __shelterCheck('exact_missing_plank_keeps_unfinished_original_concern',p and step and step.status=='blocked'
        and step.productionKind=='build-shelter-stairs' and #step.inputs==21 and not f.rec.resourceProductionWork and not f.nativePayments)
    f=fixture('stairs-ack','W');moveToApproach(f);f.body.primary=f.hammer;assert(begin(f))
    local q=ISTimedActionQueue.getTimedActionQueue(f.body);local a=q.current;a:start();f.body.holdCancellation=true
    __shelterCheck('stair_pending_native_ack_keeps_exact_claim',R.interrupt(f.id,f.body,'pending')==false
        and f.rec.resourceProductionWork and #f.rec.resourceProductionWork.inputs==22 and f.purpose.admission and not f.nativePayments)
    f.body.holdCancellation=false
    __shelterCheck('stair_ack_retires_no_parts_or_lesson',R.interrupt(f.id,f.body,'ack') and not f.rec.resourceProductionWork
        and not f.purpose.admission and not f.nativePayments and not f.rec.recoveryExperiences
        and #(f.rec.cognition and f.rec.cognition.experiences or {})==0)
    f=fixture('stairs-foreign-queue','W');moveToApproach(f);f.body.primary=f.hammer;assert(begin(f));q=ISTimedActionQueue.getTimedActionQueue(f.body);a=q.current;a:start()
    local successor={character=f.body,Type='successor',isValidStart=function()return true end,begin=function()end}
    q.queue={successor};q.current=successor;f.body.farming=true;R.interrupt(f.id,f.body,'foreign-queue')
    __shelterCheck('stale_stair_callback_preserves_foreign_queue',q.current==successor and q.queue[1]==successor and f.body.farming==true and not f.nativePayments)
    q.current=nil;q.queue={}
    f=fixture('stairs-saved','W');moveToApproach(f);f.body.primary=f.hammer;assert(begin(f));local saved=__nativeRoundtrip(f.rec)
    R.interrupt(f.id,f.body,'quiet');__records[f.id]=saved;f.rec=saved;f.agent.rec=saved;f.purpose=saved.proceduralPlanning.purposes[f.purpose.id];__reloadProduction()
    __shelterCheck('actual_saved_stair_work_reconciles_without_fabricated_effects',R.reconcileSaved(f.id,f.body)
        and not saved.resourceProductionWork and not f.purpose.admission and f.purpose.status~='completed'
        and not f.created and not saved.recoveryExperiences and __nativeShelter('stairsNone'))
end
function __runShelterStairsCapacity()
    local f=fixture('stairs-capacity','W');moveToApproach(f)
    local p,step,context=plan(f);local option
    for _,candidate in ipairs(context.options) do if candidate.kind=='build-shelter-stairs' then option=candidate;break end end
    __shelterCheck('native_stair_capacity_preserves_all_twenty_two_inputs',option and #option.inputs==22
        and SAO.ProceduralPlanning.collectorReady(option) and p and step and step.productionKind=='build-shelter-stairs'
        and #step.inputs==22 and step.status=='available')
end
function __runShelterStairsSaturation()
    local f=fixture('stairs-saturated-feedback','S');moveToApproach(f);assert(begin(f));assert(__shelterFinish(f).status=='completed')
    assert(__nativeShelter('sceneMove','9.5,21.5,1'));measuredPosition(f)
    local s=f.rec.proceduralPlanning;s.shelterMovementResults={};s.shelterMovementSequence=32
    -- Controlled pending scalar state applies pressure to the real arrival/reconciliation owner.
    for index=1,32 do s.shelterMovementResults[index]={id='shelter-movement/'..f.id..'/'..index,actorId=f.id,sequence=index,
        purposeId=f.purpose.id,routeId='older-owned-route-'..index,sourceId='older-access-'..index,actionKind='inspect',succeeded=true,atHours=__hours} end
    local actualObserve=SAO.CognitiveModels.observe;local held=true
    SAO.CognitiveModels.observe=function(model,state,event,depth)
        if held and event.kind=='shelter-movement' then return 'held-movement-model' end
        return actualObserve(model,state,event,depth)
    end
    local P,Ctl=SAO.ProceduralPlanning,SAO.Controller
    local p,step=P.planShelterConstruction(f.id,{recoveryKind='sleep',fatigue=.65,atHours=__hours,options={},materialSources={},
        sites={},coverNeeds={},access={},position={x=f.body.x,y=f.body.y,z=f.body.z}})
    assert(step and step.verb=='return' and Ctl.beginShelterMovement(f.id,f.agent,f.body,100,p,step))
    SAO.Locomotion.tick(f.id);__shelterControllerTick(101);local retired=Ctl.finishShelterMovement(f.id,f.agent,f.body)
    __shelterCheck('saturated_pending_feedback_never_gates_actual_native_arrival',retired and f.agent.state=='IDLE' and not f.agent.shelterRoute
        and not p.admission and step.status=='completed' and f.body:getCurrentSquare():getZ()==0
        and #s.shelterMovementResults==33 and s.shelterMovementResults[1].sequence==1 and s.shelterMovementResults[33].sequence==33
        and #(f.rec.cognition.experiences or {})==1 and not f.rec.recoveryExperiences)
    local saved=__nativeRoundtrip(f.rec);__records[f.id]=saved;f.rec=saved;f.agent.rec=saved;held=false;SAO.CognitiveModels.observe=actualObserve
    SAO.ResourceProduction.reconcileSaved(f.id,f.body)
    __shelterCheck('pending_feedback_replays_then_bounds_only_acknowledged_history',#saved.proceduralPlanning.shelterMovementResults==32
        and saved.proceduralPlanning.shelterMovementResults[1].sequence==2
        and saved.proceduralPlanning.shelterMovementResults[32].sequence==33
        and saved.cognition.nativeExperienceCursors['shelter-movement']==33
        and saved.cognition.models.ordinary.revision==34 and saved.cognition.models.associative.revision==34)
end
