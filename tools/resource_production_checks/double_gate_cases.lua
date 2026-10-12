-- Actual installed recipes/payment/factory and native double-door operation over controlled actor/dispatch ports.
local function list(values)
    local out={values=values or {}};function out:size()return #self.values end;function out:get(i)return self.values[i+1] end
    function out:add(value)self.values[#self.values+1]=value end
    function out:contains(value)for _,old in ipairs(self.values) do if old==value then return true end end;return false end
    return out
end

local families={'Base.DoubleDoor','Base.DoubleFenceGate','Base.DoubleWireGate'}
local policies={};local active
for _,id in ipairs(families) do
    local inputs={};for index=0,id=='Base.DoubleWireGate' and 5 or 4 do local n=index
        inputs[#inputs+1]={index=n,entityId=id,getResourceType=function()return ResourceType.Item end,
            getIntAmount=function()return __nativeGate('inputCount',id,n) end,isKeep=function()return __nativeGate('inputKeep',id,n) end,isRecordInput=function()return __nativeGate('recordInput',id,n) end}
    end
    local recipe={entityId=id};function recipe:getInputs()return list(inputs) end
    function recipe:getScriptObjectFullType()return id end;function recipe:getName()return id:sub(6) end
    function recipe:needToBeLearn()return __nativeGate('needsLearn',id) end
    function recipe:getRequiredSkillCount()return __nativeGate('skillCount',id) end
    function recipe:getRequiredSkill(index)return {entityId=id,index=index} end
    function recipe:getTime()return 200 end;function recipe:getHighestRelevantSkill()return Perks.Woodwork end
    function recipe:getHighestRelevantSkillLevel()return 8 end;function recipe:getToolLeft()return nil end
    function recipe:getToolRight()return id=='Base.DoubleDoor' and {canUseItem=function(_,type)return type=='Base.Hammer' end} or nil end;function recipe:getTimedActionScript()return nil end
    local script={getParent=function()return {getScriptObjectFullType=function()return id end} end,
        getName=function()return id:sub(6) end,getPreviousStages=function()return list() end,getLightsourceTagItem=function()return list() end,
        getBonusHealth=function()return __nativeGate('spriteProperty',id,'getBonusHealth') end}
    function script:getFace()return {getLightsourceOffsetX=function()return 0 end,getLightsourceOffsetY=function()return 0 end,getLightsourceOffsetZ=function()return 0 end} end
    setmetatable(script,{__index=function(_,key)return function()return __nativeGate('spriteProperty',id,key) end end})
    local faces={}
    for _,name in ipairs({'N','W'}) do local face=name
        faces[face]={getWidth=function()return __nativeGate('faceWidth',id,face) end,getHeight=function()return __nativeGate('faceHeight',id,face) end,
            getzLayers=function()return 1 end,getFaceName=function()return face end,getTileInfo=function(_,x,y)
                return {getSpriteName=function()return __nativeGate('sprite',id,x..','..y) end,isBlocking=function()return false end}
            end}
    end
    local info={getScript=function()return script end,getRecipe=function()return {getCraftRecipe=function()return recipe end} end,
        getName=function()return id:sub(6) end,getFace=function(_,key)return (key=='N' or key==0) and faces.N or (key=='W' or key==1) and faces.W or nil end}
    policies[id]={recipe=recipe,info=info,inputs=inputs}
end
SpriteConfigManager.GetObjectInfoList=function()local out={} for _,id in ipairs(families) do out[#out+1]=policies[id].info end;return list(out) end
CraftRecipeManager.hasPlayerLearnedRecipe=function(recipe)return __nativeGate('learnedPass',recipe.entityId) end
CraftRecipeManager.hasPlayerRequiredSkill=function(required)return __nativeGate('skillPass',required.entityId,required.index) end
CraftRecipeManager.getValidInputScriptForItem=function(recipe,item)
    for index=0,#policies[recipe.entityId].inputs-1 do if __nativeGate('inputMatch',recipe.entityId..'|'..index,item:getID()) then return policies[recipe.entityId].inputs[index+1] end end
end
local function nativeManual(kind,input,out)
    for id in __nativeGate('manualIds',kind,input.index):gmatch('[^,]+') do out:add(active.materialById[tonumber(id)]) end;return out
end
BuildLogic.new=function(body)
    __nativeGate('newLogic');local logic={body=body}
    function logic:setContainers(v)self.containers=v end;function logic:setRecipe(recipe)self.recipe=recipe end;function logic:getRecipe()return self.recipe end
    function logic:setManualSelectInputs(v)self.manual=v end;function logic:isManualSelectInputs()return self.manual end
    function logic:clearManualInputs()end
    function logic:setManualInputsFor(input,items)local ids={} for index=0,items:size()-1 do ids[#ids+1]=tostring(items:get(index):getID()) end;return __nativeGate('manual',input.index,table.concat(ids,',')) end
    function logic:canPerformCurrentRecipe()return __nativeGate('eligible') end;function logic:getPossibleCraftCount()return __nativeGate('possible') end
    function logic:startCraftAction()return __nativeGate('start') end;function logic:stopCraftAction()return __nativeGate('stop') end
    function logic:getModelHandOne()return active.entityId=='Base.DoubleDoor' and 'Hammer' or 'BlowTorch' end;function logic:getModelHandTwo()return nil end
    function logic:performCurrentRecipe()active.nativePayments=(active.nativePayments or 0)+1;return __nativeGate('perform') end
    local function data(kind)
        return {getRecipe=function()return logic.recipe end,getManualInputsFor=function(_,input,out)return nativeManual(kind,input,out) end,
            getAllConsumedItems=function()local out={} for _,item in ipairs(active.materials) do if __nativeGate('consumed',item:getID()) then out[#out+1]=item end end;return list(out) end,
            getAllKeepInputItems=function()local out={} for _,item in ipairs(active.materials) do if __nativeGate('kept',item:getID()) then out[#out+1]=item end end;return list(out) end,
            getAllRecordedConsumedItems=function()return list() end,luaCallOnCreate=function()end,
            processDestroyAndUsedItems=function()
                __nativeGate('process');print('GATE_NATIVE_PAY_AT_EFFECT consumed='..__nativeGate('consumedCount')..' kept='..__nativeGate('keptCount'));for _,item in ipairs(active.materials) do item.condition=__nativeGate('condition',item:getID());if not __nativeGate('held',item:getID()) then item:getContainer():Remove(item) end;print('GATE_NATIVE_EFFECT_ITEM '..item:getID()..' uses='..__nativeGate('uses',item:getID())..' held='..tostring(__nativeGate('held',item:getID()))..' consumed='..tostring(__nativeGate('consumed',item:getID()))) end
            end}
    end
    function logic:getRecipeData()return data('current') end;function logic:getRecipeDataInProgress()return data('progress') end
    function logic:getAllConsumedItems()return self:getRecipeData():getAllConsumedItems() end;return logic
end
GameEntityFactory.CreateIsoObjectEntity=function(object,entity)
    __nativeGate('factory',object.sprite,object:getX()..','..object:getY());object.entityId=active.entityId;object.nativeFactory=true
end
local function measuredPosition(f)
    local p=__nativeGate('position');f.body.x,f.body.y,f.body.z=p.x,p.y,p.z
    local key=math.floor(p.x)..':'..math.floor(p.y)..':0';f.body.here=f.cell.squares[key] or __shelterSquare(f,math.floor(p.x),math.floor(p.y));return p
end
local function fixture(id,entity,face,pooled)
    assert(__nativeGate('reset',entity));if pooled then assert(__nativeGate('split')) end;assert(__nativeGate('scene',id,face))
    local f=__plumbingFixture(id,false,false);active=f;f.entityId,f.face=entity,face;f.siteRevision="controlled-native-gate-revision";f.inventory.items={};f.materials={};f.materialById={};f.createdParts={}
    for itemId=100,99+__nativeGate('count') do
        local item=__boardingItem(__nativeGate('type',itemId):sub(6),itemId,f.inventory);item.condition=__nativeGate('condition',itemId)
        function item:hasTag(tag)return self:getType()=='Hammer' and tag==ItemTag.HAMMER end
        function item:getCurrentUses()return __nativeGate('uses',self:getID()) end
        function item:getFluidContainer()return nil end;function item:getFluidContainerFromSelfOrWorldItem()return nil end
        f.inventory.items[#f.inventory.items+1]=item;f.materials[#f.materials+1]=item;f.materialById[itemId]=item
    end
    f.hammer=f.materials[1];f.tool=f.hammer
    for x=5,17 do for y=14,25 do local square=__shelterSquare(f,x,y)
        local add=square.AddSpecialObject;function square:AddSpecialObject(object)add(self,object);f.createdParts[#f.createdParts+1]=object end
    end end
    f.siteSquare=f.cell:getGridSquare(10,20,0)
    function f.body:isRecipeActuallyKnown(name)return __nativeGate('actualKnown',name) end
    function f.body:isBuildCheat()return false end;function f.body:faceLocation()end;function f.body:faceLocationF()end;function f.body:getPerkLevel()return 8 end
    function f.body:faceThisObject()end;function f.body:getTimedActionToRetrigger()return nil end;function f.body:getCurrentStateName()return 'IdleState' end
    function __world:isValidSquare()return true end
    SAOJavaBridge.worldDoubleGateSites=function(_,body)return body==f.body and not f.hidden and __nativeGate('sites') or {} end
    SAOJavaBridge.worldDoubleGatePlacement=function(_,body,key,revision)return body==f.body and __nativeGate('placement',key,revision) and f.siteSquare or nil end
    SAOJavaBridge.worldDoubleGateCreated=function(_,body,parts,entity,x,y,z,orientation)
        return body==f.body and #parts==4 and entity==f.entityId and x==10 and y==20 and z==0 and orientation==face and __nativeGate('created') or nil
    end
    SAOJavaBridge.worldDoubleGateGroup=function(_,body,gid)
        local row=body==f.body and __nativeGate('group',gid) or nil
        if row and f.hideGateGroup then row.observed=false end
        if row and f.foreignGateObservation then row.id='foreign-group-observation' end
        return row
    end
    local leaf={kind='IsoThumpable'};function leaf:getSquare()return f.siteSquare end;function leaf:isDoor()return true end
    function leaf:ToggleDoor()return __nativeGate('toggle',f.groupId) end
    SAOJavaBridge.worldDoubleGateLeaf=function(_,body,gid)return body==f.body and __nativeGate('leaf',gid) and leaf or nil end
    SAOJavaBridge.worldDoubleGateBeginPassage=function(_,body,gid)return body==f.body and __nativeGate('passBegin',gid) or nil end
    SAOJavaBridge.worldDoubleGatePassage=function(_,body,token)return body==f.body and __nativeGate('passage',token) end
    SAOJavaBridge.worldDoubleGateForgetPassage=function(_,body,token)return __nativeGate('passForget',token) end
    SAO.Locomotion.order=function(pid,body,x,y,z)SAO.Locomotion.jobs[pid]={body=body,goal={x=x,y=y,z=z},done=false};return true end
    SAO.Locomotion.tick=function(pid)local job=SAO.Locomotion.jobs[pid];f.nativeMoves=(f.nativeMoves or 0)+1;local arrived=__nativeGate('move',job.goal.x..','..job.goal.y);measuredPosition(f);job.done,job.result=true,arrived and 'arrived' or 'failed' end
    SAO.Needs.read=function()return {hunger=.1,thirst=.1,fatigue=.1,endurance=.8} end
    measuredPosition(f);SAO.Cognition.ensureGameDefaults();return f
end
local function check(name,result)print(name..'='..tostring(result==true)) end
local function context(f)
    assert(SAO.Perception.observeDoubleGateSites(f.id,f.body));local options={}
    for _,option in ipairs(SAO.ResourceProduction.doubleGateOptions(f.id,f.body)) do if option.entityId==f.entityId then options[#options+1]=option end end
    return {boundaryConcern=true,options=options,materialSources={},pressure=.5}
end
local function plan(f)
    local p,step=SAO.ProceduralPlanning.planDoubleGate(f.id,context(f));f.purpose,f.step=p,step
    print('GATE_PLAN '..f.entityId..' '..f.face..' '..tostring(step and step.productionKind)..' '..tostring(p and p.blockers[1]));return p,step
end
local function finish(f)
    local queue=ISTimedActionQueue.getTimedActionQueue(f.body);local count=0
    while queue.current do
        count=count+1;assert(count<=8);local action=queue.current;action:start();action.action.nativeFinished=true;local result=action:perform();print('GATE_ACTION '..tostring(action.Type)..' result='..tostring(result)..' stage='..tostring(f.rec.resourceProductionWork and f.rec.resourceProductionWork.stage))
        if action.Type=='ISEquipWeaponAction' or action.Type=='ISOpenCloseDoor' then print('GATE_ACTION_COMPLETE '..tostring(action:complete())) end
        assert(queue.current~=action,'native gate queue did not retire')
    end
    for attempt=1,4 do if not f.rec.resourceProductionWork then break end;SAO.ResourceProduction.tick(f.id,f.body) end
    local rows=f.rec.resourceProductionOutcomes or {};return rows[#rows]
end
function __runDoubleGateFamily(entity,face)
    local f=fixture('native-gate-'..entity:sub(6)..'-'..face,entity,face)
    local function gateCheck(name,value)check(name..'_'..entity:sub(6)..'_'..face,value) end
    gateCheck('native_freestanding_scene_has_no_gate_or_roof',__nativeGate('absent') and __nativeGate('unroofed'))
    local p,step=plan(f)
    gateCheck('actual_private_boundary_admits_full_native_family',p and step and step.productionKind=='build-double-gate' and step.site.width*step.site.height==4)
    assert(step and step.productionKind=='build-double-gate','native gate recipe or private footprint absent')
    assert(__nativeGate('move',(step.site.approachX+.5)..','..(step.site.approachY+.5)));measuredPosition(f)
    local admitted=SAO.ResourceProduction.begin(f.id,f.body,step,{purposeId=p.id,purposeStepId=step.id})
    gateCheck('exact_native_materials_and_preparation_admitted',admitted and f.rec.resourceProductionWork~=nil)
    print('GATE_PREFLIGHT stage='..tostring(f.rec.resourceProductionWork and f.rec.resourceProductionWork.stage)..' queue='..tostring(ISTimedActionQueue.getTimedActionQueue(f.body).current and ISTimedActionQueue.getTimedActionQueue(f.body).current.Type)..' eligible='..tostring(__nativeGate('eligible'))..' possible='..tostring(__nativeGate('possible')))
    for _,req in ipairs(step.requirements) do print('GATE_INPUT '..req.inputIndex..' count='..req.count..' quantity='..tostring(req.quantity)..' now='..__nativeGate('manualIds','current',req.inputIndex)..' progress='..__nativeGate('manualIds','progress',req.inputIndex)) end
    local saved=__nativeRoundtrip(f.rec)
    gateCheck('actual_saved_claim_preserves_exact_full_inputs',saved.resourceProductionWork and #saved.resourceProductionWork.inputs==#step.inputs)
    local row=admitted and finish(f)
    print('GATE_NATIVE_PAYMENT consumed='..__nativeGate('consumedCount')..' kept='..__nativeGate('keptCount'))
    for _,item in ipairs(f.materials) do print('GATE_NATIVE_ITEM '..item:getID()..' '..item:getFullType()..' uses='..__nativeGate('uses',item:getID())..' held='..tostring(__nativeGate('held',item:getID()))..' consumed='..tostring(__nativeGate('consumed',item:getID()))) end
    print('GATE_BUILD_RESULT '..entity..' '..face..' '..tostring(row and row.status)..' detail='..tostring(row and row.detail)..' parts='..tostring(row and #row.parts))
    gateCheck('all_four_native_parts_and_exact_payment_measured',row and row.status=='completed' and #row.parts==4 and row.inputsConsumed and row.toolRetained and f.nativePayments==1)
    assert(row and row.status=='completed','native four-part gate creation/payment failed')
    f.groupId=row.groupId
    print('GATE_DELIVERY status='..p.status..' delivered='..tostring(row.purposeDelivered)..' group='..tostring(p.gateAccess.groupId)..' rowgroup='..tostring(row.groupId)..' ad='..tostring(p.admission and p.admission.correlationId)..' token='..tostring(row.token))
    gateCheck('construction_has_separate_once_only_private_feedback',#f.rec.cognition.experiences==1 and f.rec.cognition.models.ordinary.revision==1
        and f.rec.cognition.models.associative.revision==1 and p.status~='completed')
    for _,operation in ipairs({'open','pass','close'}) do
        p,step=plan(f);assert(step and step.operation==operation,'original native access purpose changed')
        local started=SAO.ResourceProduction.begin(f.id,f.body,step,{purposeId=p.id,purposeStepId=step.id})
        row=started and finish(f);print('GATE_USE_RESULT '..entity..' '..face..' '..operation..' '..tostring(row and row.status)..' '..tostring(row and row.detail))
        gateCheck('native_'..operation..'_under_same_retained_purpose',row and row.status=='completed' and row.operation==operation and row.purposeId==f.purpose.id)
        assert(row and row.status=='completed','native gate '..operation..' failed')
        if operation=='open' then gateCheck('native_open_relocates_and_reacquires_exact_leaves',row.afterGroup.open==true and row.afterGroup.relocated==true and #row.afterGroup.parts==4) end
        if operation=='pass' then gateCheck('genuine_same_body_native_passage_measured',math.floor(f.body.x)==step.site.destinationX and math.floor(f.body.y)==step.site.destinationY) end
    end
    gateCheck('native_final_group_closed_and_original_access_complete',p.status=='completed' and row.afterGroup.open==false and not row.afterGroup.relocated)
    gateCheck('build_open_pass_close_feedback_remain_independent',#f.rec.cognition.experiences==4 and f.rec.cognition.models.ordinary.revision==4
        and f.rec.cognition.models.associative.revision==4 and f.rec.cognition.experiences[2].actionKind=='open'
        and f.rec.cognition.experiences[3].actionKind=='pass' and f.rec.cognition.experiences[4].actionKind=='close')
    local loaded=__nativeRoundtrip(f.rec);__records[f.id]=loaded;f.rec=loaded;f.agent.rec=loaded;SAO.ResourceProduction.reconcileSaved(f.id,f.body)
    gateCheck('actual_saved_native_group_replay_is_once',#loaded.cognition.experiences==4 and loaded.proceduralPlanning.purposes[p.id].status=='completed'
        and SAOJavaBridge:worldDoubleGateGroup(f.body,f.groupId,entity,10,20,0,face).open==false)
end

function __runDoubleGatePool()
    local f=fixture('native-pooled-gate','Base.DoubleFenceGate','N',true);local p,step=plan(f)
    check('native_pooled_use_budget_keeps_all_thirty_eight_objects',p and step and #step.inputs==38 and SAO.ProceduralPlanning.collectorReady(step))
    assert(step and #step.inputs==38)
    assert(__nativeGate('move','11.5,21.5'));measuredPosition(f)
    local started=SAO.ResourceProduction.begin(f.id,f.body,step,{purposeId=p.id,purposeStepId=step.id})
    local saved=__nativeRoundtrip(f.rec)
    check('actual_saved_pooled_inputs_do_not_truncate_at_thirty_two',saved.resourceProductionWork and #saved.resourceProductionWork.inputs==38
        and #saved.proceduralPlanning.purposes[p.id].steps[1].inputs==38)
    local row=started and finish(f)
    check('all_exact_partial_drainables_pay_native_recipe_once',row and row.status=='completed' and #row.inputs==38 and #row.parts==4 and row.inputsConsumed and f.nativePayments==1)
end

function __runDoubleGateKnowledge()
    local f=fixture('native-integrated-gate-knowledge','Base.DoubleFenceGate','N')
    __nativeGate('known',false);f.rec.literacy='full';__attachGateRecipeBook(f);f.inventory.items={} for _,item in ipairs(f.materials) do f.inventory.items[#f.inventory.items+1]=item end;f.inventory.items[#f.inventory.items+1]=f.book
    local ctx=context(f);ctx.recipeBooks={DoubleFenceGate={itemId=f.book:getID(),itemType=f.book:getFullType()}}
    local p,step=SAO.ProceduralPlanning.planDoubleGate(f.id,ctx)
    check('unknown_native_metal_recipe_keeps_real_gate_reading_prerequisite',p and step and step.operation=='learn-recipe'
        and step.recipeName=='DoubleFenceGate' and not __recipeNative('known','DoubleFenceGate') and not f.nativePayments)
    assert(step and SAO.Study.beginRecipe(f.id,f.body,f.book,p.id,step.id,'DoubleFenceGate'))
    local queue=ISTimedActionQueue.getTimedActionQueue(f.body);local action=queue.current;action:start();action.action.jobDelta=1;action:update();action.action.nativeFinished=true
    action:complete();action:perform()
    local row=SAO.Study.recipeOutcome(f.id,f.rec.studyWork.id)
    check('actual_magazine_completion_teaches_native_gate_recipe_under_same_purpose',row and row.status=='completed'
        and row.recipeKnown and __recipeNative('known','DoubleFenceGate') and __recipeNative('known','DoubleWireGate') and row.purposeId==p.id
        and p.status~='completed' and not p.admission and not f.nativePayments)
    f.purpose,f.step=p,step;local original=p.id;p,step=plan(f)
    assert(__nativeGate('move','11.5,21.5'));measuredPosition(f)
    local started=step and step.productionKind=='build-double-gate' and SAO.ResourceProduction.begin(f.id,f.body,step,{purposeId=p.id,purposeStepId=step.id})
    row=started and finish(f)
    check('native_reading_feedback_unlocks_same_person_exact_metal_construction',row and row.status=='completed' and row.purposeId==original and #row.parts==4 and f.nativePayments==1)
end

local function buildGuard(id)
    local f=fixture(id,'Base.DoubleDoor','N');local p,step=plan(f);assert(__nativeGate('move','11.5,21.5'));measuredPosition(f)
    assert(SAO.ResourceProduction.begin(f.id,f.body,step,{purposeId=p.id,purposeStepId=step.id}));local row=finish(f);assert(row and row.status=='completed')
    f.groupId=row.groupId;return f
end
local function beginOperation(f)
    local p,step=plan(f);return SAO.ResourceProduction.begin(f.id,f.body,step,{purposeId=p.id,purposeStepId=step.id})
end
function __runDoubleGateGuards()
    local R,P=SAO.ResourceProduction,SAO.ProceduralPlanning
    local f=fixture('gate-no-intent','Base.DoubleDoor','N');local ctx=context(f);ctx.boundaryConcern=false
    check('no_gate_work_without_person_boundary_concern',P.planDoubleGate(f.id,ctx)==nil and not f.rec.resourceProductionWork)
    f=fixture('gate-empty-ground','Base.DoubleDoor','N');__nativeGate('noBoundary');local p,step=plan(f)
    check('arbitrary_empty_ground_cannot_supply_boundary_gate',not p and not step and #SAO.Perception.doubleGateSites(f.id,f.body)==0)
    f=fixture('gate-hidden-space','Base.DoubleDoor','N');f.hidden=true;p,step=plan(f)
    check('unacquired_operating_footprint_cannot_supply_gate',not p and not step and not f.nativePayments)
    f=fixture('gate-native-skill','Base.DoubleFenceGate','N');__nativeGate('skill',4);p,step=plan(f)
    check('native_metal_skill_five_owns_placement_admission',not step and not f.rec.resourceProductionWork and not f.nativePayments)
    f=fixture('gate-permission','Base.DoubleDoor','N');p,step=plan(f);assert(__nativeGate('move','11.5,21.5'));measuredPosition(f)
    local permission=SAO.Standing.mayTakeCurrent;SAO.Standing.mayTakeCurrent=function(id,x,y,kind)if id==f.id and x==12 and y==19 then return false end;return permission(id,x,y,kind) end
    local admitted=R.begin(f.id,f.body,step,{purposeId=p.id,purposeStepId=step.id})
    check('current_permission_covers_every_operating_and_passage_square',not admitted and not f.nativePayments)
    SAO.Standing.mayTakeCurrent=permission
    f=buildGuard('gate-native-lock');__nativeGate('lock',true);local started=beginOperation(f);local row=started and finish(f)
    check('native_lock_refusal_never_earns_opening_credit',row and row.status=='failed' and not row.afterGroup.open and #f.rec.cognition.experiences==1 and not f.purpose.gateAccess.opened)
    f=buildGuard('gate-native-obstruction');local blocked=__nativeGate('obstruct');started=beginOperation(f);row=started and finish(f)
    check('native_opening_obstruction_retains_original_access',blocked and row and row.status=='failed' and not row.afterGroup.open and f.purpose.status~='completed')
    f=buildGuard('gate-native-barricade');local barricaded=__nativeGate('barricade');started=beginOperation(f);row=started and finish(f)
    check('native_barricade_refusal_never_earns_opening_credit',barricaded and row and row.status=='failed' and not row.afterGroup.open and #f.rec.cognition.experiences==1)
    f=buildGuard('gate-partial-group');__nativeGate('removeMember');started=beginOperation(f)
    check('partial_native_group_refuses_operation',not started and not f.rec.resourceProductionWork and #f.rec.cognition.experiences==1)
    f=buildGuard('gate-foreign-group');__nativeGate('foreignMember');started=beginOperation(f)
    check('foreign_native_member_refuses_original_group_operation',not started and not f.rec.resourceProductionWork and #f.rec.cognition.experiences==1)
    f=buildGuard('gate-duplicate-group');local duplicate=__nativeGate('duplicateMember');started=beginOperation(f)
    check('competing_copy_at_native_operating_position_refuses_group',duplicate and not started and not f.rec.resourceProductionWork and #f.rec.cognition.experiences==1)
    f=buildGuard('gate-pending-ack');assert(beginOperation(f));local queue=ISTimedActionQueue.getTimedActionQueue(f.body);local action=queue.current;action:start();f.body.holdCancellation=true
    check('pending_native_gate_ack_keeps_exact_claim',R.interrupt(f.id,f.body,'pending')==false and f.rec.resourceProductionWork and f.purpose.admission and #f.rec.cognition.experiences==1)
    f.body.holdCancellation=false;R.interrupt(f.id,f.body,'ack')
    check('native_gate_ack_retires_without_operation_credit',not f.rec.resourceProductionWork and not f.purpose.admission and #f.rec.cognition.experiences==1)
    f=buildGuard('gate-successor-queue');assert(beginOperation(f));queue=ISTimedActionQueue.getTimedActionQueue(f.body);action=queue.current;action:start()
    local successor={character=f.body,Type='successor',isValidStart=function()return true end,begin=function()end};queue.queue={successor};queue.current=successor;f.body.farming=true
    R.interrupt(f.id,f.body,'foreign-queue')
    check('stale_gate_callback_preserves_foreign_queue_and_flags',queue.current==successor and queue.queue[1]==successor and f.body.farming==true and #f.rec.cognition.experiences==1)
    queue.queue={};queue.current=nil
    f=buildGuard('gate-saved-operation');assert(beginOperation(f));queue=ISTimedActionQueue.getTimedActionQueue(f.body);action=queue.current;action:start()
    local saved=__nativeRoundtrip(f.rec);__records[f.id]=saved;f.rec=saved;f.agent.rec=saved;f.purpose=saved.proceduralPlanning.purposes[f.purpose.id]
    local settled=R.reconcileSaved(f.id,f.body)
    if not settled then settled=R.reconcileSaved(f.id,f.body) end
    check('actual_saved_gate_queue_retires_exact_old_owner_without_effect',settled and not saved.resourceProductionWork and not f.purpose.admission
        and #saved.cognition.experiences==1 and SAOJavaBridge:worldDoubleGateGroup(f.body,f.groupId,'Base.DoubleDoor',10,20,0,'N').open==false)
    f=buildGuard('gate-revoked-native-effect');assert(beginOperation(f));queue=ISTimedActionQueue.getTimedActionQueue(f.body);action=queue.current;action:start();action.action.nativeFinished=true;action:perform()
    permission=SAO.Standing.mayTakeCurrent;SAO.Standing.mayTakeCurrent=function(pid,x,y,kind)if pid==f.id and x==12 and y==19 then return false end;return permission(pid,x,y,kind) end
    action:complete()
    check('revoked_current_operating_permission_refuses_native_toggle_callback',__nativeGate('toggleCount')==0 and not __nativeGate('group',f.groupId).open and #f.rec.cognition.experiences==1)
    SAO.Standing.mayTakeCurrent=permission;R.interrupt(f.id,f.body,'revocation-ended')
    f=buildGuard('gate-changed-frozen-start');assert(beginOperation(f));queue=ISTimedActionQueue.getTimedActionQueue(f.body);action=queue.current;action:start()
    local start=f.rec.resourceProductionWork.startedAt;f.rec.resourceProductionWork.startedAt=start-.1;action.action.nativeFinished=true;action:perform();action:complete()
    check('changed_current_saved_scalar_anchor_refuses_native_effect',__nativeGate('toggleCount')==0 and not __nativeGate('group',f.groupId).open and #f.rec.cognition.experiences==1)
    if f.rec.resourceProductionWork then f.rec.resourceProductionWork.startedAt=start end;R.interrupt(f.id,f.body,'scalar-ended')
end

local function savedGate(f)
    local saved=__nativeRoundtrip(f.rec);__records[f.id]=saved;f.rec=saved;f.agent.rec=saved;f.purpose=saved.proceduralPlanning.purposes[f.purpose.id]
    __reloadProduction();return saved
end
local function pressureLedger(f,pending)
    local rows={};for sequence=1,32 do rows[#rows+1]={id='resource-production/'..f.id..'/'..sequence,sequence=sequence,actorId=f.id,
        kind='controlled-ledger-pressure',purposeId=sequence==1 and 'controlled-pending-purpose' or nil,purposeDelivered=not pending or sequence~=1,experienceDelivered=true} end
    f.rec.resourceProductionSequence=32;f.rec.resourceProductionOutcomes=rows;return rows
end
function __runDoubleGateLifecycle()
    local R,P=SAO.ResourceProduction,SAO.ProceduralPlanning
    local f=buildGuard('gate-pass-effect-before-ack');assert(beginOperation(f));assert(finish(f).status=='completed');assert(beginOperation(f))
    SAO.Locomotion.tick(f.id);assert(math.floor(f.body.y)==19);local moves=f.nativeMoves;local saved=savedGate(f)
    local settled=R.reconcileSaved(f.id,f.body);if not settled then settled=R.reconcileSaved(f.id,f.body) end
    check('saved_actual_pass_without_ack_keeps_truthful_interruption',settled and not f.purpose.gateAccess.crossed and #saved.cognition.experiences==2)
    local started=beginOperation(f);local row=started and finish(f)
    check('saved_pass_at_destination_returns_and_retries_real_crossing',row and row.status=='completed' and row.operation=='pass' and f.nativeMoves>=moves+2
        and f.purpose.gateAccess.crossed==row.id and #saved.cognition.experiences==3)
    assert(beginOperation(f));assert(__nativeGate('toggle',f.groupId));assert(not __nativeGate('group',f.groupId).open)
    saved=savedGate(f);settled=R.reconcileSaved(f.id,f.body);if not settled then settled=R.reconcileSaved(f.id,f.body) end
    check('saved_native_closed_group_without_ack_has_no_closure_credit',settled and not f.purpose.gateAccess.closed and #saved.cognition.experiences==3)
    local toggles=__nativeGate('toggleCount');started=beginOperation(f);row=started and finish(f)
    check('saved_closed_group_retry_reopens_then_really_closes',row and row.status=='completed' and row.operation=='close'
        and __nativeGate('toggleCount')==toggles+2 and not row.afterGroup.open and f.purpose.status=='completed' and #saved.cognition.experiences==4)
    f=buildGuard('gate-retired-effect-full-ledger');local rows=pressureLedger(f,true);assert(beginOperation(f));local work=f.rec.resourceProductionWork
    local queue=ISTimedActionQueue.getTimedActionQueue(f.body);local action=queue.current;action:start();action.action.nativeFinished=true;action:perform();action:complete()
    toggles=__nativeGate('toggleCount')
    check('retired_native_effect_waits_for_pending_ledger_without_repeating',f.rec.resourceProductionWork==work and #rows==32 and __nativeGate('group',f.groupId).open
        and queue.current==nil and #f.rec.cognition.experiences==1 and not f.purpose.gateAccess.opened)
    rows[1].purposeDelivered=true;R.tick(f.id,f.body);row=f.rec.resourceProductionOutcomes[32]
    check('ordinary_tick_publishes_retired_native_effect_after_capacity_clears',not f.rec.resourceProductionWork and #rows==32 and row.status=='completed'
        and row.operation=='open' and row.sequence==33 and __nativeGate('toggleCount')==toggles and #f.rec.cognition.experiences==2)
    local old=row.operation;row.operation='pass';local forged=R.outcome(f.id,row.id);local consumed=P.consumeDoubleGateResult(f.id,row)
    check('changed_saved_operation_cannot_substitute_passage_for_opening',not forged and not consumed and not f.purpose.gateAccess.crossed and #f.rec.cognition.experiences==2)
    row.operation=old
    f=buildGuard('gate-saved-full-ledger');rows=pressureLedger(f,true);assert(beginOperation(f));saved=savedGate(f)
    settled=R.reconcileSaved(f.id,f.body);if not settled then settled=R.reconcileSaved(f.id,f.body) end
    check('saved_gate_recovery_preserves_pending_oldest_at_capacity',not settled and saved.resourceProductionWork and #saved.resourceProductionOutcomes==32
        and not __nativeGate('group',f.groupId).open and #saved.cognition.experiences==1)
    saved.resourceProductionOutcomes[1].purposeDelivered=true;settled=R.reconcileSaved(f.id,f.body);row=saved.resourceProductionOutcomes[32]
    check('saved_gate_recovery_prunes_only_acknowledged_history',settled and not saved.resourceProductionWork and #saved.resourceProductionOutcomes==32
        and row.sequence==33 and row.status=='interrupted' and #saved.cognition.experiences==1)
    local refused,retained=true,true
    for _,field in ipairs({'world','generation','sequence','clock'}) do
        f=buildGuard('gate-saved-custody-'..field);assert(beginOperation(f));queue=ISTimedActionQueue.getTimedActionQueue(f.body);action=queue.current;action:start();saved=savedGate(f)
        local originalWorld=__world.getWorld;local sequence=saved.resourceProductionSequence
        if field=='world' then __world.getWorld=function()return 'changed-world' end
        elseif field=='generation' then f.body.md.SAOExternalToken='new-generation';saved.bodyOwnerToken='new-generation'
        elseif field=='sequence' then saved.resourceProductionSequence=sequence-1
        else __hours=99 end
        settled=R.reconcileSaved(f.id,f.body);refused=refused and not settled
        retained=retained and queue.current==action and queue.queue[1]==action and saved.resourceProductionWork~=nil and #saved.cognition.experiences==1
        __world.getWorld=originalWorld;f.body.md.SAOExternalToken=nil;saved.bodyOwnerToken=nil;saved.resourceProductionSequence=sequence;__hours=100
        R.reconcileSaved(f.id,f.body);R.reconcileSaved(f.id,f.body)
    end
    check('saved_changed_world_generation_sequence_clock_refuse_before_queue_retirement',refused and retained)
    f=buildGuard('gate-feedback-refusal');local feedback=SAO.Cognition.doubleGateOutcome;SAO.Cognition.doubleGateOutcome=function()return false,'controlled-transient-model-refusal' end
    assert(beginOperation(f));row=finish(f);saved=savedGate(f)
    check('physical_gate_effect_and_purpose_survive_private_feedback_refusal',row and row.status=='completed' and f.purpose.gateAccess.opened==row.id
        and row.purposeDelivered and not row.experienceDelivered and #saved.cognition.experiences==1)
    SAO.Cognition.doubleGateOutcome=feedback;R.reconcileSaved(f.id,f.body);R.reconcileSaved(f.id,f.body)
    check('saved_pending_gate_feedback_replays_once_under_exact_original_phase',#saved.cognition.experiences==2 and saved.cognition.experiences[2].actionKind=='open'
        and saved.resourceProductionOutcomes[2].experienceDelivered and saved.proceduralPlanning.purposes[f.purpose.id].gateAccess.opened==row.id)
end

local function acquisitionFixture(id)
    local f=fixture(id,'Base.DoubleFenceGate','N');__nativeGate('woodSkill',0);f.agent.state='IDLE';f.material=f.materialById[101]
    assert(__nativeGate('withdraw',101));f.inventory:Remove(f.material);f.source=__boardingInventory({items={f.material},contains=function(self,item)return self.items[1]==item end,
        Remove=function(self,item)if self.items[1]==item then self.items={};item.container=nil end end},nil);f.material.container=f.source
    f.sourceId='C:gate-material-'..id..':0';f.materialRevision='material-before';f.place={id='source:'..f.sourceId,sourceId=f.sourceId,cx=12,cy=23,z=0,minX=12,minY=23,maxX=13,maxY=24}
    function f.snapshot()
        local present=not f.inventory:contains(f.material);local revision=present and 'material-before' or 'material-after'
        return 'H|protocol=SAOWS1|status=OBSERVED|mode=loaded|cx=1|cy=2|sources=1\nS|id='..f.sourceId..'|fp=exact-gate-container|rev='..revision
            ..'|kind=container|x=12|y=23|z=0|building=-1|explored=1|state='..(present and 'available' or 'spent')..'|access=unknown|container=counter'
            ..(present and '|q:metal-pipe=1\nI|source='..f.sourceId..'|id=101|type=Base.MetalPipe|uses=1|amount=0|fluid=|poison=0|rotten=0|cats=metal-pipe' or '')..'\nE'
    end
    local bridge=SAOJavaBridge
    bridge.observeWorldChunk=function()return f.snapshot() end
    bridge.worldSourceActionTarget=function(_,body,sourceId,fp,revision,itemId,itemType)
        return body==f.body and sourceId==f.sourceId and fp=='exact-gate-container' and revision=='material-before' and tostring(itemId)=='101' and itemType=='Base.MetalPipe' and 'READY:12:23:0:12:23:0' or 'ITEM_MISSING' end
    bridge.bindWorldSourceAction=function()return 'BOUND:12:23:0' end
    bridge.worldSourceActionItem=function()return f.material end;bridge.worldSourceActionContainer=function()return f.source end;bridge.worldSourceActionPermissionContainer=function()return f.source end
    bridge.containerAccessibleNow=function()return true end;bridge.worldTransferPosition=function()return 'AT:12:23:0' end
    bridge.carriedWorldSourceItem=function(_,body,itemId,itemType)return body==f.body and tostring(itemId)=='101' and itemType=='Base.MetalPipe' and f.inventory:contains(f.material) and f.material or nil end
    bridge.carriedWorldTransferItem=function()return f.inventory:contains(f.material) and 'T|id=101|type=Base.MetalPipe|uses=1|amount=0|fluid=|poison=0|rotten=0|cats=metal-pipe' or nil end
    bridge.clearWorldSourceAction=function()end;SAO.Standing.provisioningContextAt=function()return 'unheld',nil end
    local nativeTransfer=ISTransferAction.transferItem
    ISTransferAction.transferItem=function(self,body,item,source,destination,square)
        if body==f.body and item==f.material then assert(__nativeGate('reclaim',101)) end
        return nativeTransfer(self,body,item,source,destination,square)
    end
    SAO.Controller.resourceContext=function(pid,agent,body,needs,category)
        return {sources=category=='metal-pipe' and {{known=true,category=category,sourceId=f.sourceId,revision='material-before',itemId=101,itemType='Base.MetalPipe',place=f.place}} or {}} end
    SAO.Standing.insideClaim=function()return true end
    assert(SAO.WorldSources.applySnapshot(SAO.WorldSources.parse(f.snapshot())));return f
end
function __runDoubleGateAcquisition()
    local Ctl,P,WS,SU=SAO.Controller,SAO.ProceduralPlanning,SAO.WorldSources,SAO.SourceUse
    local f=acquisitionFixture('ordinary-gate-material')
    local started=Ctl.tryDoubleGate(f.id,f.agent,f.body,100);local p,step=P.doubleGatePurpose(f.id);f.purpose,f.step=p,step
    print('GATE_ACQUISITION_INITIAL started='..tostring(started)..' p='..tostring(p and p.id)..' kind='..tostring(step and step.verb)..' status='..tostring(step and step.status)..' blocker='..tostring(p and p.blockers[1])..' entity='..tostring(p and p.gateAccess.entityId)..' state='..tostring(f.agent.state))
    check('unacquired_material_refuses_actual_source_owner_and_records_retry',not started and p and step.verb=='acquire' and step.status=='blocked'
        and p.routeFailures and #p.routeFailures==1 and not f.rec.worldSourceReservation and not __nativeGate('held',101))
    local saved=__nativeRoundtrip(f.rec);__records[f.id]=saved;f.rec=saved;f.agent.rec=saved;f.purpose=saved.proceduralPlanning.purposes[p.id]
    assert(SAO.Perception.learnInspectedSource(f.id,f.place,f.sourceId,100,'native-container-inspection'))
    local before=f.purpose.routeFailures[1].retryAt
    started=Ctl.tryDoubleGate(f.id,f.agent,f.body,101)
    check('saved_acquisition_refusal_waits_existing_exact_retry_clock',not started and not saved.worldSourceReservation and f.purpose.selectedStrategy==step.id and before>__hours)
    __hours=before+.001;started=Ctl.tryDoubleGate(f.id,f.agent,f.body,102);local reservation=WS.pendingActionFor(f.id)
    check('ordinary_controller_admits_exact_private_gate_material_to_sourceuse',started and f.agent.state=='SOURCEWARD' and reservation
        and reservation.operation=='acquire' and reservation.sourceId==f.sourceId and reservation.itemId==101 and reservation.itemType=='Base.MetalPipe'
        and reservation.quantity==1 and reservation.quantityUnit=='item' and reservation.purposeId==p.id and not f.nativePayments)
    assert(reservation);SAO.Locomotion.tick(f.id);assert(SU.onMovementDone(f.id,f.body,'arrived')=='using')
    local queue=ISTimedActionQueue.getTimedActionQueue(f.body);local action=queue.current;action.getNotFullFloorSquare=function()return nil end;action.playTransferCompleteSound=function()end
    action:start();action.action.nativeFinished=true;action:perform();local status=SU.tick(f.id,f.body);local receipt=WS.actionOutcome(reservation.id,f.id)
    check('actual_verified_transfer_retains_exact_native_material_and_item_unit',status=='completed' and receipt and receipt.measurement=='native-item-transfer'
        and receipt.observedQuantity==1 and receipt.quantityUnit=='item' and __nativeGate('held',101) and f.inventory:contains(f.material) and not f.source:contains(f.material))
    assert(receipt);local raw=ModData.get('SurvivorAwareness_WorldSources').results[reservation.id];local fields={'sourceId','preRevision','itemId','itemType','category','actorId','quantityUnit','requestedQuantity','observedQuantity'};local refused=true
    for _,key in ipairs(fields) do local original=raw[key];raw[key]=type(original)=='number' and original+1 or 'foreign-'..tostring(original)
        refused=refused and P.consumeSourceResult(receipt)==false and f.purpose.admission~=nil;raw[key]=original end
    check('changed_authoritative_source_item_actor_quantity_cannot_advance_gate',refused)
    check('exact_canonical_acquisition_continues_original_gate_purpose',P.consumeSourceResult(receipt) and not f.purpose.admission and f.purpose.status~='completed')
    f.agent.state='IDLE';assert(__nativeGate('move','11.5,21.5'));measuredPosition(f);started=Ctl.tryDoubleGate(f.id,f.agent,f.body,103)
    local row=started and finish(f)
    check('ordinary_private_acquisition_unlocks_exact_native_gate_payment',row and row.status=='completed' and row.purposeId==p.id and #row.parts==4 and f.nativePayments==1)
    __hours=100
    f=fixture('gate-native-category-contract','Base.DoubleWireGate','N');__attachGateRecipeBook(f);local all=true;local seen={};local examples={} for _,item in ipairs(f.materials) do examples[#examples+1]=item end;examples[#examples+1]=f.book
    for _,item in ipairs(examples) do for _,category in ipairs({'metal-pipe','wire','scrap-metal','welding-torch','welding-rods','gate-manual'}) do
        if ({['Base.MetalPipe']='metal-pipe',['Base.Wire']='wire',['Base.ScrapMetal']='scrap-metal',['Base.BlowTorch']='welding-torch',['Base.WeldingRods']='welding-rods',['Base.MetalworkMag3']='gate-manual'})[item:getFullType()]==category and not seen[category] then
            seen[category]=true
            all=all and __nativeGate('materialCategory',item:getID(),category) and __nativeGate('sourceCategories',item:getID()):find(category,1,true)~=nil
            local sourceId='C:native-gate-category-'..category..':0';local place={id='source:'..sourceId,sourceId=sourceId,cx=12,cy=23,z=0,minX=12,minY=23,maxX=13,maxY=24}
            local text='H|protocol=SAOWS1|status=OBSERVED|mode=loaded|cx=1|cy=2|sources=1\nS|id='..sourceId..'|fp=category-container|rev=category-1|kind=container|x=12|y=23|z=0|building=-1|explored=1|state=available|access=unknown|container=counter|q:'..category..'=1\nI|source='..sourceId..'|id='..item:getID()..'|type='..item:getFullType()..'|uses=1|amount=0|fluid=|poison=0|rotten=0|cats='..category..'\nE'
            local applied=WS.applySnapshot(WS.parse(text));local learned=applied and SAO.Perception.learnInspectedSource(f.id,place,sourceId,100,'native-container-inspection')
            local offered=learned and WS.actionOptions(place,category,f.id,f.body,1,'standing','acquire',item:getFullType())
            all=all and offered and #offered.options==1 and offered.options[1].parameters.itemId==item:getID()
        end
    end end
    check('native_material_predicates_and_source_projection_share_gate_categories',all==true and seen['gate-manual']==true)
end

function __runDoubleGateCapacity()
    local f=fixture('gate-capacity-control','Base.DoubleFenceGate','N',true);local p,step=plan(f);local copy=__nativeRoundtrip(f.rec)
    local view=SAO.ProceduralPlanning.snapshot(f.id)
    check('all_pooled_gate_objects_reach_ready_saved_and_observed_plan',p and step and #step.inputs==38 and SAO.ProceduralPlanning.collectorReady(step)
        and #copy.proceduralPlanning.purposes[p.id].steps[1].inputs==38 and view.purposes[1] and view.purposes[1].gateAccess and #view.purposes[1].sequence[1].inputs==38)
end
function __runDoubleGatePayment()
    local f=fixture('gate-payment-control','Base.DoubleFenceGate','N');local p,step=plan(f);assert(step)
    assert(__nativeGate('move','11.5,21.5'));measuredPosition(f)
    local started=SAO.ResourceProduction.begin(f.id,f.body,step,{purposeId=p.id,purposeStepId=step.id});local row=started and finish(f)
    check('native_charge_payment_measurement_accepts_exact_installed_use_deltas',row and row.status=='completed' and row.inputsConsumed and row.usesBefore and row.usesAfter and f.nativePayments==1)
end
function __runDoubleGatePassageEdge()
    local f=buildGuard('gate-route-around-edge');assert(beginOperation(f));assert(finish(f).status=='completed');assert(beginOperation(f))
    for _,point in ipairs({'15.5,21.5','15.5,19.5','11.5,19.5'}) do assert(__nativeGate('move',point)) end;measuredPosition(f)
    local route=SAO.Locomotion.jobs[f.id];route.done,route.result=true,'arrived';SAO.ResourceProduction.tick(f.id,f.body)
    local row=f.rec.resourceProductionOutcomes[#f.rec.resourceProductionOutcomes]
    check('same_body_route_around_boundary_cannot_credit_selected_gate_passage',math.floor(f.body.y)==19 and row.status=='failed' and row.operation=='pass'
        and not f.purpose.gateAccess.crossed and #f.rec.cognition.experiences==2)
end

local function reviewBuilt(id,entity,face)
    local f=fixture(id,entity,face);local p,step=plan(f);assert(__nativeGate('move','11.5,21.5'));measuredPosition(f)
    assert(SAO.ResourceProduction.begin(f.id,f.body,step,{purposeId=p.id,purposeStepId=step.id}));local row=finish(f);assert(row and row.status=='completed')
    f.groupId=row.groupId;f.buildRow=row;return f
end
function __runDoubleGateReviewPhases()
    for _,entity in ipairs(families) do for _,face in ipairs({'N','W'}) do
        local function phaseCheck(name,value)check(name..'_'..entity:sub(6)..'_'..face,value) end
        local f=reviewBuilt('gate-external-open-'..entity:sub(6)..face,entity,face);assert(__nativeGate('externalToggle',f.groupId));__nativeGate('look')
        local p,step=plan(f)
        phaseCheck('personally_observed_external_open_selects_pass_without_own_open_credit',step and step.operation=='pass' and not p.gateAccess.opened
            and #f.rec.cognition.experiences==1 and SAO.Perception.currentDoubleGateGroup(f.id,f.body,f.groupId,entity,p.gateAccess.site).open)
        local started=step and SAO.ResourceProduction.begin(f.id,f.body,step,{purposeId=p.id,purposeStepId=step.id});local row=started and finish(f)
        if row and row.status=='completed' then p,step=plan(f);started=SAO.ResourceProduction.begin(f.id,f.body,step,{purposeId=p.id,purposeStepId=step.id});row=started and finish(f) end
        phaseCheck('external_open_continues_original_same_body_pass_and_native_closure',row and row.status=='completed' and row.operation=='close' and p.status=='completed'
            and p.id==f.buildRow.purposeId and not row.afterGroup.open and #f.rec.cognition.experiences==3 and not p.gateAccess.opened)
        f=reviewBuilt('gate-external-reclose-'..entity:sub(6)..face,entity,face);assert(beginOperation(f));assert(finish(f).status=='completed')
        local firstOpen=f.purpose.gateAccess.opened;assert(__nativeGate('externalToggle',f.groupId));__nativeGate('look');p,step=plan(f)
        local actual=__nativeGate('group',f.groupId);print('GATE_EXTERNAL_RECLOSE '..entity..' '..face..' open='..tostring(actual and actual.open)..' observed='..tostring(actual and actual.observed)..' selected='..tostring(step and step.operation)..' experiences='..#f.rec.cognition.experiences)
        phaseCheck('current_external_reclosure_selects_real_reopen_before_original_pass',step and step.operation=='open' and p.gateAccess.opened==firstOpen
            and #f.rec.cognition.experiences==2 and not SAO.Perception.currentDoubleGateGroup(f.id,f.body,f.groupId,entity,p.gateAccess.site).open)
        started=step and SAO.ResourceProduction.begin(f.id,f.body,step,{purposeId=p.id,purposeStepId=step.id});row=started and finish(f)
        print('GATE_REOPEN_RESULT '..entity..' '..face..' status='..tostring(row and row.status)..' native='..tostring(row and row.nativeCompleted)..' open='..tostring(row and row.afterGroup and row.afterGroup.open)..' detail='..tostring(row and row.detail))
        if row and row.status=='completed' then for _,operation in ipairs({'pass','close'}) do
            p,step=plan(f);started=step and step.operation==operation and SAO.ResourceProduction.begin(f.id,f.body,step,{purposeId=p.id,purposeStepId=step.id});row=started and finish(f)
            if not row or row.status~='completed' then break end
        end end
        phaseCheck('external_reclosure_reopens_then_original_body_passes_and_closes',row and row.status=='completed' and row.operation=='close' and p.status=='completed'
            and p.id==f.buildRow.purposeId and p.gateAccess.opened~=firstOpen and not row.afterGroup.open and #f.rec.cognition.experiences==5)
    end end
end
function __runDoubleGateReviewSites()
    local P,V,R,Ctl=SAO.ProceduralPlanning,SAO.Perception,SAO.ResourceProduction,SAO.Controller
    local f=fixture('gate-consumed-site','Base.DoubleDoor','N');local p,step=plan(f);local key,revision=step.site.key,step.site.revision
    f.hidden=true;V.observeDoubleGateSites(f.id,f.body)
    check('hidden_gate_site_observation_preserves_acquired_unresolved_fact',#V.doubleGateSites(f.id,f.body)==1 and V.doubleGateSites(f.id,f.body)[1].revision==revision)
    local observer=SAOJavaBridge.worldDoubleGateSites;SAOJavaBridge.worldDoubleGateSites=function()return nil end
    local observed=V.observeDoubleGateSites(f.id,f.body);SAOJavaBridge.worldDoubleGateSites=observer;f.hidden=false
    check('unavailable_gate_site_observer_cannot_erase_acquired_fact',not observed and #V.doubleGateSites(f.id,f.body)==1)
    check('unauthenticated_build_claim_cannot_consume_private_free_site',not V.consumeDoubleGateSite(f.id,{id='foreign-construction',actorId=f.id,site=step.site}) and #V.doubleGateSites(f.id,f.body)==1)
    assert(__nativeGate('move','11.5,21.5'));measuredPosition(f);assert(R.begin(f.id,f.body,step,{purposeId=p.id,purposeStepId=step.id}));local build=finish(f);assert(build.status=='completed');f.groupId=build.groupId
    check('authenticated_four_part_build_retires_exact_acquired_site_and_order',#V.doubleGateSites(f.id,f.body)==0 and #(V.beliefs[f.id].doubleGateOrder or {})==0)
    for _,operation in ipairs({'open','pass','close'}) do assert(beginOperation(f));assert(finish(f).status=='completed') end
    local before=f.rec.proceduralPlanning.nextPurpose;local acquisitions=0;local acquisition=SAO.SourceUse.beginAcquisition
    SAO.SourceUse.beginAcquisition=function(...)acquisitions=acquisitions+1;return acquisition(...) end
    Ctl.resourceContext=function(_,_,_,_,category)return {sources={{known=true,category=category,sourceId='C:redundant-gate-material:0',revision='redundant-1',itemId=301,itemType='Base.Plank',place={id='redundant',cx=12,cy=23,minX=12,minY=23,maxX=13,maxY=24}}}} end
    SAO.Standing.insideClaim=function()return true end;f.agent.state='IDLE';V.observeDoubleGateSites(f.id,f.body);local started=Ctl.tryDoubleGate(f.id,f.agent,f.body,200)
    check('completed_occupied_gap_cannot_start_second_purpose_or_material_collection',not started and #R.doubleGateOptions(f.id,f.body)==0 and acquisitions==0
        and f.rec.proceduralPlanning.nextPurpose==before and not f.rec.worldSourceReservation and f.nativePayments==1)
    SAO.SourceUse.beginAcquisition=acquisition
    assert(__nativeGate('removeGroup'));assert(__nativeGate('move','11.5,23.5'));measuredPosition(f);__nativeGate('look');__hours=100.1
    local refreshed=V.observeDoubleGateSites(f.id,f.body);local sites=V.doubleGateSites(f.id,f.body)
    check('genuine_native_free_reobservation_readmits_site_after_gate_destruction',refreshed and #sites==1 and sites[1].key==key and sites[1].revision==revision
        and sites[1].observedAtHours>build.atHours and #R.doubleGateOptions(f.id,f.body)>0)
    local consumed=V.consumeDoubleGateSite(f.id,build)
    check('late_old_build_receipt_cannot_erase_newer_free_site_observation',not consumed and #V.doubleGateSites(f.id,f.body)==1)
    __hours=100
    f=reviewBuilt('gate-private-group-observation','Base.DoubleDoor','N');assert(__nativeGate('externalToggle',f.groupId));f.hideGateGroup=true;p,step=plan(f)
    check('hidden_external_group_change_cannot_manufacture_current_open_fact',step.operation=='open' and not V.currentDoubleGateGroup(f.id,f.body,f.groupId,'Base.DoubleDoor',p.gateAccess.site)
        and not p.gateAccess.opened and #f.rec.cognition.experiences==1)
    f.hideGateGroup=false;f.foreignGateObservation=true
    check('foreign_group_observation_cannot_supply_original_phase_state',V.currentDoubleGateGroup(f.id,f.body,f.groupId,'Base.DoubleDoor',p.gateAccess.site)==nil)
end
function __runDoubleGateReviewRace()
    for _,entity in ipairs(families) do for _,face in ipairs({'N','W'}) do
        local function raceCheck(name,value)check(name..'_'..entity:sub(6)..'_'..face,value) end
        local f=reviewBuilt('gate-cross-then-external-close-'..entity:sub(6)..face,entity,face);assert(beginOperation(f));assert(finish(f).status=='completed');assert(beginOperation(f))
        local workId=f.rec.resourceProductionWork.id;SAO.Locomotion.tick(f.id);assert(__nativeGate('externalToggle',f.groupId));assert(not __nativeGate('group',f.groupId).open)
        SAO.ResourceProduction.tick(f.id,f.body);local rows=f.rec.resourceProductionOutcomes;local row=rows[#rows]
        raceCheck('recorded_native_crossing_retires_after_external_closure',row and row.id==workId and row.operation=='pass' and row.status=='completed'
            and row.nativeCompleted and row.afterGroup.open==false and f.rec.resourceProductionWork==nil and f.purpose.admission==nil
            and f.purpose.gateAccess.crossed==workId and #f.rec.cognition.experiences==3)
        local started=false
        if not f.rec.resourceProductionWork then started=beginOperation(f);row=started and finish(f) end
        raceCheck('post_cross_external_closure_keeps_original_native_close_completion',started and row and row.operation=='close' and row.status=='completed'
            and row.purposeId==f.buildRow.purposeId and not row.afterGroup.open and f.purpose.status=='completed' and #f.rec.cognition.experiences==4)
    end end
end
