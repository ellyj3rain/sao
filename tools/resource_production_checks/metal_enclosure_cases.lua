-- Current production over installed recipes, exact native payment and actual world parts.
-- Actor dispatch/animation are ports shared with D3.9; native scene shell owns motion/regions/recovery.
local R,P,Ctl,N=SAO.ResourceProduction,SAO.ProceduralPlanning,SAO.Controller,SAO.Needs
local resourceContext=Ctl.resourceContext
SAO.Locomotion.cancel=function(id)local job=SAO.Locomotion.jobs[id];if job then __nativeShelter('sceneCancelMove');SAO.Locomotion.jobs[id]=nil end;return true end
local nativeValid=ISBuildIsoEntity.isValid
function ISBuildIsoEntity:isValid(square)local result=nativeValid(self,square);print('METAL_VALID '..tostring(result)..' prior='..tostring(self.previousStageObject));return result end
local families={'Base.MetalWindowFrameLvl1','Base.MetalWindowFrameLvl2'}
local function check(name,value)print('METAL '..name..'='..tostring(value==true)) end
local function adaptMaterials(f)
    for _,item in ipairs(f.materials) do function item:getCurrentUses()return __nativeShelter('uses',self:getID()) end end
    function f.body:getPerkLevel()return __nativeShelter('skillValue') end
    function f.body:isRecipeActuallyKnown(name)return __nativeShelter('actualKnown',name) end
    function f.body:isRecipeKnown(name)return true end -- installed visibility-permissive convenience query
end
local function fixture(id,entity,face,prior)
    __nativeShelter('known',true);__nativeShelter('skill',entity:find('Lvl1',1,true) and 3 or 5)
    local f=__shelterFixture(id,face,entity);assert(__nativeShelter('scene',id,face));adaptMaterials(f)
    f.siteSquare.objects={};f.previous=nil;f.initialStage=nil
    if entity:find('Wall',1,true) or entity:find('WindowFrame',1,true) then assert(__nativeShelter('wallScene')) end
    prior=prior or ((entity:find('WallLvl',1,true) or entity:find('WindowFrame',1,true)) and 'Base.MetalWallFrame' or entity:find('DoorLvl',1,true) and 'Base.MetalDoorFrameLvl1')
    if prior then
        assert(__nativeShelter('seed',prior))
        local object=IsoThumpable.new(f.cell,f.siteSquare,__nativeShelter('otherSprite',prior..'|'..face),face=='N',{})
        object.entityId,object.nativeFactory,object.health=prior,true,500
        f.siteSquare.objects[1]=object;f.previous,f.initialStage=object,object
    end
    SAOJavaBridge.worldShelterSites=function(_,body)return body==f.body and __nativeShelter('sceneSites','10,20,0') or {} end
    SAOJavaBridge.worldShelterPlacementSquare=function(_,body,key,revision)
        return body==f.body and not f.placementRefused and __nativeShelter('scenePlacement',key,revision) and f.siteSquare or nil
    end
    SAOJavaBridge.worldShelterPreviousStage=function(_,body,key,revision)
        return body==f.body and __nativeShelter('scenePrevious',key,revision)==(f.previous and f.previous.entityId) and f.previous or nil
    end
    SAOJavaBridge.worldShelterCreated=function(_,body,object,old,target,x,y,z,orientation)
        return body==f.body and object==f.created and object.entityId==target and __nativeShelter('createdMeasured') and not f.createdRefused
    end
    SAOJavaBridge.worldShelterDoor=function(_,body,key,revision)
        return body==f.body and __nativeShelter('sceneDoorLookup',key,revision) and f.created and f.created:isDoor() and f.created or nil
    end
    SAOJavaBridge.worldShelterCover=function(_,body,x,y,z)return body==f.body and __nativeShelter('sceneCover',x..','..y..','..z) or nil end
    for _,site in ipairs(__nativeShelter('sceneSites','10,20,0')) do print('NATIVE_METAL_SITE '..site.key..' '..site.mode..' '..site.previousEntity) end
    assert(SAO.Perception.observeShelterSites(id,f.body))
    return f
end
local function option(f)
    local options=R.shelterOptions(f.id,f.body,f.purpose and f.purpose.shelterConstruction)
    print('METAL_OPTIONS '..f.entityId..' '..f.orientation..' '..#options)
    for _,site in ipairs(SAO.Perception.shelterSites(f.id,f.body)) do print('METAL_SITE '..site.key..' '..site.mode..' '..site.previousEntity..' '..site.face) end
    for _,row in ipairs(options) do print('METAL_OPTION '..row.entityId..' '..row.site.key..' inputs='..#row.inputs);if row.entityId==f.entityId and row.site.x==10 and row.site.y==20 and row.site.face==f.orientation then return row end end
end
local function plan(f,context)
    local offered=option(f);assert(offered,'native metal option missing '..f.entityId..' '..f.orientation)
    context=context or {};context.options={offered};context.recoveryKind='sleep';context.fatigue=.65;context.atHours=__hours
    context.position={x=f.body:getX(),y=f.body:getY(),z=f.body:getZ()};context.sites=SAO.Perception.shelterSites(f.id,f.body);context.materialSources=context.materialSources or {}
    local p,s=P.planShelterConstruction(f.id,context);f.purpose,f.step=p,s;return p,s
end
function __runEnclosureFrames()
    for index,entity in ipairs(families) do for _,face in ipairs({'N','W'}) do
        local f=fixture('metal-family-'..index..face,entity,face);local p,s=plan(f);local prefix='family'..index..'_'..face..'_'
        local begun=s and R.begin(f.id,f.body,s,{purposeId=p.id,purposeStepId=s.id})
        print('METAL_BEGIN_STAGE '..tostring(f.rec.resourceProductionWork and f.rec.resourceProductionWork.stage))
        check(prefix..'native_admission',begun and f.rec.resourceProductionWork and f.rec.resourceProductionWork.entityId==entity)
        if begun then
            local work=__nativeRoundtrip(f.rec.resourceProductionWork)
            check(prefix..'saved_exact_use_inputs',#work.inputs==#f.materials and work.entityId==entity and work.toolCategory=='welding-torch')
            local row=__shelterFinish(f)
            check(prefix..'native_payment_and_grade',row and row.status=='completed' and row.entityId==entity and row.inputsConsumed
                and row.nativeCompleted and __nativeShelter('createdMeasured') and __nativeShelter('createdNorth')==(face=='N')
                and row.usesBefore and row.usesAfter and f.nativePayments==1)
            check(prefix..'native_stage_index',not f.initialStage or __nativeShelter('stageReplaced') or entity:find('DoorLvl',1,true)~=nil)
            check(prefix..'independent_private_build_feedback',row and row.experienceDelivered and row.purposeDelivered and f.rec.cognition
                and #f.rec.cognition.experiences==1 and f.rec.cognition.experiences[1].kind=='shelter-construction'
                and p.status~='completed' and not f.rec.recoveryExperiences)
        end
    end end
end

__enclosureFixture=fixture;__enclosureCheck=check;__enclosurePlan=plan

local boundaries={'Base.MetalFenceLvl1','Base.MetalFenceLvl2','Base.MetalBigMetalFence','Base.MetalBigWireFence','Base.MetalSmallPoleFence','Base.MetalSmallWireFence','Base.MetalPoleFenceGate','Base.MetalPoleFenceGateSmall','Base.MetalWireFenceGate','Base.MetalWireFenceGateSmall'}
local function boundaryFixture(id,entity,face)
    __nativeShelter('known',true);__nativeShelter('skill',entity=='Base.MetalFenceLvl2' and 5 or 3)
    local f=__shelterFixture(id,face,entity);assert(__nativeShelter('boundaryScene',id,face));adaptMaterials(f)
    f.siteSquare.objects={};f.previous=nil;f.initialStage=nil
    SAOJavaBridge.worldBoundarySites=function(_,body)return body==f.body and __nativeShelter('boundarySites') or {} end
    SAOJavaBridge.worldBoundaryPlacement=function(_,body,key,revision)return body==f.body and __nativeShelter('boundaryPlacement',key,revision) and f.siteSquare or nil end
    SAOJavaBridge.worldBoundaryCreated=function(_,body,object,target,x,y,z,orientation)
        if body~=f.body or object~=f.created or target~=f.entityId or x~=10 or y~=20 or z~=0 or orientation~=face then return nil end
        return __nativeShelter('boundaryCreated')
    end
    SAOJavaBridge.worldBoundaryState=function(_,body,gid,target,x,y,z,orientation)
        return body==f.body and target==f.entityId and x==10 and y==20 and z==0 and orientation==face and __nativeShelter('boundaryState',gid) or nil
    end
    SAOJavaBridge.worldBoundaryLeaf=function(_,body,gid)return body==f.body and __nativeShelter('boundaryLeaf',gid) and f.created or nil end
    SAO.Cognition.ensureGameDefaults();local observed=SAO.Perception.observeBoundarySites(id,f.body);print("BOUNDARY_OBSERVED "..tostring(observed).." native="..#__nativeShelter("boundarySites").." private="..#SAO.Perception.boundarySites(id,f.body))
    for _,row in ipairs(SAO.Perception.boundarySites(id,f.body))do print("BOUNDARY_SITE "..row.key.." "..row.mode) end
    return f
end
function __runEnclosureBoundaries()
    for index,entity in ipairs(boundaries)do for _,face in ipairs({'N','W'})do
        local f=boundaryFixture('enclosure-boundary-'..index..face,entity,face);local offered
        for _,candidate in ipairs(R.boundaryOptions(f.id,f.body))do if candidate.entityId==entity and candidate.site.x==10 and candidate.site.y==20 and candidate.site.face==face then offered=candidate;break end end
        assert(offered,'acquired boundary option absent '..entity..' '..face)
        local p,s=P.planDoubleGate(f.id,{boundaryConcern=true,options={offered},materialSources={},recipeBooks={},pressure=.5,atHours=__hours})
        f.purpose,f.step=p,s;print("BOUNDARY_PLAN "..tostring(p and p.id).." step="..tostring(s and s.productionKind).." status="..tostring(s and s.status).." token="..tostring(s and s.token).." category="..tostring(s and s.category).." ready="..tostring(P.collectorReady(offered)).." inputs="..#offered.inputs);local prefix='boundary'..index..'_'..face..'_'
        local begun=s and R.begin(f.id,f.body,s,{purposeId=p.id,purposeStepId=s.id})
        check(prefix..'native_admission',begun==true)
        if begun then local row=__shelterFinish(f)
            check(prefix..'native_payment_and_creation',row and row.status=='completed' and row.inputsConsumed and row.nativeCompleted and __nativeShelter('createdMeasured'))
            check(prefix..'actual_native_collision',__nativeShelter('boundaryCollision'))
            check(prefix..'no_shelter_or_recovery_credit',__nativeShelter('boundaryUnroofed') and not f.rec.recoveryExperiences and not p.shelterConstruction)
            check(prefix..'independent_private_feedback',row and row.purposeDelivered and row.experienceDelivered and #f.rec.cognition.experiences==1)
        end
    end end
end
__enclosureBoundaryFixture=boundaryFixture

local function measuredPosition(f)
    local p=__nativeShelter('scenePosition');f.body.x,f.body.y,f.body.z=p.x,p.y,p.z
    f.body.here=f.cell:getGridSquare(math.floor(p.x),math.floor(p.y),p.z);return p
end
local function gatePorts(f)
    f.groupId=f.purpose.gateAccess.groupId
    function f.created:IsOpen()local group=__nativeShelter('boundaryState',f.groupId);return group and group.open end
    function f.created:ToggleDoor()return __nativeShelter('sceneToggle') end
    function f.body:faceThisObject()end;function f.body:getTimedActionToRetrigger()return nil end;function f.body:getCurrentStateName()return 'IdleState' end
    SAOJavaBridge.worldBoundaryBeginPassage=function(_,body,gid,entity,x,y,z,face,tx,ty)
        return body==f.body and gid==f.groupId and __nativeShelter('boundaryBeginPassage',gid,tx..','..ty) or nil
    end
    SAOJavaBridge.worldBoundaryPassage=function(_,body,token)return body==f.body and __nativeShelter('boundaryPassage',token) end
    SAOJavaBridge.worldBoundaryForgetPassage=function()end -- Terminal query, never a physical effect.
    SAO.Locomotion.order=function(id,body,x,y,z)SAO.Locomotion.jobs[id]={body=body,goal={x=x,y=y,z=z},done=false};return true end
    SAO.Locomotion.tick=function(id)
        local route=SAO.Locomotion.jobs[id];local arrived=__nativeShelter('sceneMove',route.goal.x..','..route.goal.y..','..route.goal.z)
        measuredPosition(f);route.done,route.result=true,arrived and 'arrived' or 'failed'
    end
end
function __runEnclosureGateUses()
    for index=7,10 do local entity=boundaries[index] for _,face in ipairs({'N','W'})do
        local f=boundaryFixture('enclosure-single-use-'..index..face,entity,face);local offered
        for _,candidate in ipairs(R.boundaryOptions(f.id,f.body))do if candidate.entityId==entity and candidate.site.x==10 and candidate.site.y==20 and candidate.site.face==face then offered=candidate;break end end
        local p,s=P.planDoubleGate(f.id,{boundaryConcern=true,options={offered},materialSources={},pressure=.5});f.purpose,f.step=p,s
        assert(s and R.begin(f.id,f.body,s,{purposeId=p.id,purposeStepId=s.id}));local built=__shelterFinish(f);assert(built and built.status=='completed');gatePorts(f)
        local prefix='single'..index..'_'..face..'_'
        for _,operation in ipairs({'open','pass','close'})do
            local own,step=P.planDoubleGate(f.id,{boundaryConcern=true,options={},materialSources={},pressure=.5})
            check(prefix..operation..'_original_purpose',own==p and step and step.productionKind=='operate-single-gate' and step.operation==operation)
            local begun=step and R.begin(f.id,f.body,step,{purposeId=p.id,purposeStepId=step.id});local row=begun and __shelterFinish(f)
            if f.rec.resourceProductionWork then R.tick(f.id,f.body);row=f.rec.resourceProductionOutcomes[#f.rec.resourceProductionOutcomes] end
            check(prefix..operation..'_actual_native_effect',begun and row and row.status=='completed' and row.operation==operation and row.nativeCompleted and row.nativeCredit==row.id
                and #row.afterGroup.parts==1 and (operation=='pass' or row.afterGroup.open==(operation=='open')) and (operation~='close' or __nativeShelter('boundaryCollision')))
            if operation=='pass' then check(prefix..'same_body_physical_passage',math.floor(f.body.x)==offered.site.destinationX and math.floor(f.body.y)==offered.site.destinationY and row and row.status=='completed') end
        end
        check(prefix..'closure_replay_independent_feedback',p.status=='completed' and #f.rec.cognition.experiences==4 and not f.rec.recoveryExperiences and not f.rec.resourceProductionWork)
    end end
end

local function beginBoundaryBuild(f)
    local offered
    for _,candidate in ipairs(R.boundaryOptions(f.id,f.body))do if candidate.entityId==f.entityId and candidate.site.x==10 and candidate.site.y==20 and candidate.site.face==f.orientation then offered=candidate;break end end
    assert(offered);local p,s=P.planDoubleGate(f.id,{boundaryConcern=true,options={offered},materialSources={},pressure=.5});assert(p and s)
    f.purpose,f.step=p,s;assert(R.begin(f.id,f.body,s,{purposeId=p.id,purposeStepId=s.id}))
    local queue=ISTimedActionQueue.getTimedActionQueue(f.body);local action=queue.current
    if action and action.Type=='ISEquipWeaponAction' then action:start();action.action.nativeFinished=true;action:perform();action:complete();action=queue.current end
    assert(action and action.Type=='ISBuildAction');return action,queue
end
local function attemptBoundary(action)
    action:start();action.action.nativeFinished=true;action:perform()
end
function __runEnclosureGuards()
    local f=boundaryFixture('boundary-standing-effect','Base.MetalBigWireFence','N');local a,q=beginBoundaryBuild(f);f.rec.permissionDenied=true;attemptBoundary(a)
    check('boundary_current_standing_revocation_prevents_native_payment',not f.nativePayments and not f.created)
    f=boundaryFixture('boundary-known-effect','Base.MetalBigWireFence','W');a,q=beginBoundaryBuild(f);__nativeShelter('known',false);attemptBoundary(a)
    check('boundary_actual_knowledge_revocation_prevents_native_payment',not f.nativePayments and not f.created)
    f=boundaryFixture('boundary-input-effect','Base.MetalBigWireFence','N');a,q=beginBoundaryBuild(f);local wireId;for _,item in ipairs(f.materials)do if item:getFullType()=='Base.Wire' then wireId=item:getID() end end;assert(wireId);__nativeShelter('setUses',wireId,2);attemptBoundary(a)
    check('boundary_exact_wire_charge_change_prevents_native_payment',not f.nativePayments and not f.created)
    f=boundaryFixture('boundary-save-ack','Base.MetalSmallWireFence','W');a,q=beginBoundaryBuild(f);a:start();f.body.holdCancellation=true
    local saved=__nativeRoundtrip(f.rec);__records[f.id]=saved;f.rec=saved;f.agent.rec=saved;f.purpose=saved.proceduralPlanning.purposes[f.purpose.id];__reloadProduction();R=SAO.ResourceProduction
    local settled=R.reconcileSaved(f.id,f.body)
    check('saved_boundary_construction_holds_exact_old_action_ack',not settled and saved.resourceProductionWork and f.purpose.admission and q.current==a and not f.nativePayments)
    f.body.holdCancellation=false;settled=R.reconcileSaved(f.id,f.body);local row=saved.resourceProductionOutcomes and saved.resourceProductionOutcomes[#saved.resourceProductionOutcomes]
    check('saved_boundary_construction_retires_without_fabricated_effect',settled and row and row.status=='interrupted' and not row.nativeCompleted and #row.parts==0 and not saved.resourceProductionWork and not f.purpose.admission)
    f=boundaryFixture('boundary-effect-ack','Base.MetalFenceLvl2','N');a,q=beginBoundaryBuild(f)
    local completed=q.onCompleted;function q:onCompleted(action)if action==a then return end;return completed(self,action) end;attemptBoundary(a)
    check('paid_boundary_effect_waits_exact_native_queue_ack',f.nativePayments==1 and f.created and f.rec.resourceProductionWork and f.purpose.admission and q.current==a)
    q.onCompleted=completed;completed(q,a);R.tick(f.id,f.body);row=f.rec.resourceProductionOutcomes and f.rec.resourceProductionOutcomes[#f.rec.resourceProductionOutcomes]
    check('paid_boundary_ack_retains_native_fence_completion',row and row.status=='completed' and row.nativeCompleted and f.nativePayments==1 and f.purpose.status=='completed' and not f.rec.resourceProductionWork)
    local before=#f.rec.cognition.experiences;R.reconcileSaved(f.id,f.body);R.reconcileSaved(f.id,f.body)
    check('ordinary_boundary_feedback_replay_credits_each_model_once',#f.rec.cognition.experiences==before and row.experienceDelivered and row.purposeDelivered)
    f=fixture('healthy-window-frame-retention','Base.MetalWindowFrameLvl2','N','Base.MetalWindowFrameLvl1')
    local offered=false;for _,option in ipairs(R.shelterOptions(f.id,f.body))do if option.entityId=='Base.MetalWindowFrameLvl2' and option.site.previousEntity=='Base.MetalWindowFrameLvl1' then offered=true end end
    check('healthy_native_window_grade_does_not_force_upgrade',not offered and not f.nativePayments)
end

-- Correction scope: older candidate streams are controlled private inputs;
-- the selected one-edge site, production, collision and gate access remain native.
local function correctionContext(f)
    f.rec.claim={minX=0,maxX=100,minY=0,maxY=100}
    return Ctl.doubleGateContext(f.id,f.agent,f.body)
end
local function precedingDoubleOffers(f)
    local out={}
    for index=1,15 do local x=30+index
        out[index]={kind='build-double-gate',known=true,recipeKnown=true,recipeName='DoubleFenceGate',entityId='Base.DoubleFenceGate',recipeId='Base.DoubleFenceGate',distance=50,
            site={key='double-gate-site:'..x..':20:0:N',revision='controlled-older-'..index,actorId=f.id,observed=true,boundaryObserved=true,observedAtHours=__hours,mode='double-gate',face='N',x=x,y=20,z=0,width=4,height=1,approachX=x+1,approachY=21,approachZ=0,destinationX=x+1,destinationY=19,destinationZ=0},
            requirements={{inputIndex=0,category='welding-torch',count=1,quantity=10,nativeCount=10,mode='use'},{inputIndex=1,category='metal-pipe',count=10,mode='consume'},{inputIndex=2,category='hinge',count=4,mode='consume'},{inputIndex=3,category='scrap-metal',count=4,mode='consume'},{inputIndex=4,category='welding-rods',count=1,quantity=10,nativeCount=10,mode='use'}},inputs={}}
    end;return out
end
function __runEnclosureCorrections()
    local f=boundaryFixture('correct-mixed-stream','Base.MetalFenceLvl2','N');local oldDouble=R.doubleGateOptions
    R.doubleGateOptions=function()return precedingDoubleOffers(f)end
    local context=correctionContext(f);local p,step=P.planDoubleGate(f.id,context);f.purpose,f.step=p,step
    check('ordinary_controller_mixed_stream_preserves_new_native_family',#context.options>15 and p and step and step.entityId=='Base.MetalFenceLvl2' and step.site.key=='boundary-edge:10:20:0:N')
    local retained,again=P.planDoubleGate(f.id,correctionContext(f))
    check('ordinary_retained_boundary_filters_before_candidate_capacity',retained==p and again and again.site.key==step.site.key and again.entityId==step.entityId)
    local originalSites=SAO.Perception.boundarySites;local actual=originalSites(f.id,f.body)
    SAO.Perception.boundarySites=function(id,body)
        if id~=f.id then return originalSites(id,body) end;local rows={}
        for index=1,4 do local row=__nativeRoundtrip(actual[1]);row.x,row.approachX,row.destinationX=40+index,40+index,40+index;row.key='boundary-edge:'..row.x..':20:0:N';row.revision='controlled-acquired-other-'..index;rows[#rows+1]=row end
        rows[#rows+1]=actual[1];return rows
    end
    local selected=R.boundaryOptions(f.id,f.body,p.gateAccess);local has=false for _,option in ipairs(selected)do if option.site.key==step.site.key then has=true end end
    check('retained_native_boundary_filters_before_provider_capacity',has and #selected<32)
    SAO.Perception.boundarySites=originalSites;R.doubleGateOptions=oldDouble
    for _,entity in ipairs({'Base.MetalFenceLvl2','Base.MetalPoleFenceGateSmall'})do
        f=boundaryFixture('correct-retirement-'..entity,entity,'N');assert(__nativeShelter('boundaryExtraGap'));assert(__nativeShelter('sceneMove','10.5,22.5,0'));__shelterSquare(f,10,22);measuredPosition(f);SAO.Perception.observeBoundarySites(f.id,f.body);assert(__nativeShelter('sceneMove','10.5,20.5,0'));measuredPosition(f)
        local original=SAO.Perception.boundarySites(f.id,f.body);local otherKey
        for _,site in ipairs(original)do if site.key~='boundary-edge:10:20:0:N' then otherKey=site.key end end
        assert(otherKey,'native other gap unavailable');local offered
        for _,option in ipairs(R.boundaryOptions(f.id,f.body))do if option.entityId==entity and option.site.key=='boundary-edge:10:20:0:N' then offered=option end end
        assert(offered);p,step=P.planDoubleGate(f.id,{boundaryConcern=true,options={offered},materialSources={},pressure=.5});f.purpose,f.step=p,step
        assert(R.begin(f.id,f.body,step,{purposeId=p.id,purposeStepId=step.id}));local built=__shelterFinish(f);assert(built and built.status=='completed')
        local key=entity=='Base.MetalFenceLvl2' and 'fence' or 'single_gate';local absent,other=false,false
        for _,site in ipairs(SAO.Perception.boundarySites(f.id,f.body))do if site.key==built.siteKey then absent=true end;if site.key==otherKey then other=true end end
        check(key..'_canonical_build_retires_exact_acquired_gap',not absent and other)
        if entity~='Base.MetalFenceLvl2' then
            gatePorts(f)
            for _,operation in ipairs({'open','pass','close'})do local own,use=P.planDoubleGate(f.id,{boundaryConcern=true,options={},materialSources={},pressure=.5});assert(own==p and use.operation==operation);assert(R.begin(f.id,f.body,use,{purposeId=p.id,purposeStepId=use.id}));local row=__shelterFinish(f);if f.rec.resourceProductionWork then R.tick(f.id,f.body);row=f.rec.resourceProductionOutcomes[#f.rec.resourceProductionOutcomes] end;print('RETIREMENT_USE '..operation..' '..tostring(row and row.status)..' '..tostring(row and row.detail));assert(row.status=='completed' and row.operation==operation) end
            check('single_gate_fact_retirement_preserves_native_access_history',p.status=='completed' and p.gateAccess.opened and p.gateAccess.crossed and p.gateAccess.closed and #f.rec.cognition.experiences==4)
        end
        local nextPurpose,nextStep=P.planDoubleGate(f.id,correctionContext(f))
        check(key..'_ordinary_controller_replans_other_native_gap',nextPurpose and nextPurpose~=p and nextPurpose.gateAccess.site.key==otherKey)
        local saved=__nativeRoundtrip(f.rec);__records[f.id]=saved;f.rec=saved;f.agent.rec=saved;SAO.Perception.beliefs[f.id]=__nativeRoundtrip(SAO.Perception.beliefs[f.id]);R.reconcileSaved(f.id,f.body)
        local survived=true for _,site in ipairs(SAO.Perception.boundarySites(f.id,f.body))do if site.key==built.siteKey then survived=false end end
        check(key..'_saved_replay_preserves_consumed_gap_and_other_fact',survived and #SAO.Perception.boundarySites(f.id,f.body)>=1)
        __hours=__hours+1;assert(__nativeShelter('removeSurface'));assert(__nativeShelter('sceneMove','10.5,20.5,0'));measuredPosition(f);assert(__nativeShelter('boundaryRefreshEnd'));assert(__nativeShelter('boundaryLook'));local observed=SAO.Perception.observeBoundarySites(f.id,f.body);print('NEWER_OBSERVATION '..tostring(observed)..' '..__nativeShelter('boundaryDebug'));for _,row in ipairs(__nativeShelter('boundarySites'))do print('NEWER_NATIVE '..row.key..' '..row.revision) end;local b=SAO.Perception.beliefs[f.id];local newer=b.boundarySites[built.siteKey];assert(newer and newer.revision~=built.siteRevision)
        check(key..'_old_completion_preserves_newer_boundary_revision',not SAO.Perception.consumeBoundarySite(f.id,built) and b.boundarySites[built.siteKey].revision==newer.revision)
    end
end
