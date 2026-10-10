-- Installed action/queue/transfer and real Java recipe/material effects.
-- Lua actor/map/sound/dispatch receivers are controlled; no attached game.
local list=function(values)
    local a={values=values or {}}
    function a:size() return #self.values end
    function a:get(i) return self.values[i+1] end
    function a:add(v) self.values[#self.values+1]=v end
    function a:contains(v) for _,x in ipairs(self.values) do if v==x then return true end end;return false end
    return a
end
ArrayList={new=function() return list() end}
ResourceType={Item='Item'};ItemTag.SAW='Saw';ItemTag.FILE='File';ItemTag.WHETSTONE='Whetstone';ItemTag.SHARPENABLE='Sharpenable'
ActionSoundTime={ACTION_START=__nativeCraft('actionSoundTime')};DebugType.CraftLogic='CraftLogic'
function log() end
function showDebugInfoInChat() end
function convertToPZNetTable(v) return v end
function removeItemTransaction() end
ModData={data={}}
function ModData.getOrCreate(key) ModData.data[key]=ModData.data[key] or {};return ModData.data[key] end
function ModData.get(key) return ModData.data[key] end
SAO.Pharmacology={};SAO.Cooking={}
ISInventoryPage={dirtyUI=function() end}
local oldItem=__boardingItem
local function material(kind,id,container)
    local item=oldItem(kind,id,container)
    function item:getCurrentUses() return self.uses==nil and 1 or self.uses end
    item.condition=kind=='Saw' and 2 or kind=='File' and 8 or 10
    item.repairCount=kind=='Saw' and 3 or 0
    item.maximum=id==701 and __nativeCraft('maxCondition') or id==702 and __nativeCraft('toolMaxCondition') or 10
    item.sharpness=0;item.maxSharpness=1
    item.headCondition=kind=='HandAxe' and 10 or nil
    function item:getConditionMax() return self.maximum end
    function item:getHaveBeenRepaired() return self.repairCount end
    function item:isDamaged() return self.condition<self:getConditionMax() end
    function item:hasTag(tag) return (kind=='Saw' or kind=='SmallSaw' or kind=='HacksawBlade') and tag==ItemTag.SAW
        or kind=='File' and tag==ItemTag.FILE or (kind=='Whetstone' or kind=='CrudeWhetstone') and tag==ItemTag.WHETSTONE
        or (kind=='KitchenKnife' or kind=='HandAxe') and tag==ItemTag.SHARPENABLE end
    function item:hasSharpness() return kind=='KitchenKnife' or kind=='HandAxe' end
    function item:getSharpness() return self.sharpness end
    function item:getMaxSharpness() return self.maxSharpness end
    function item:isSharpenable() return self:hasSharpness() and self.sharpness<self.maxSharpness end
    function item:hasHeadCondition() return self.headCondition~=nil end
    function item:getHeadCondition() return self.headCondition end
    function item:getHeadConditionMax() return 10 end
    function item:canBeDroppedOnFloor() return true end
    return item
end
local function input(keep,index,sharpening)
    return {getResourceType=function() return ResourceType.Item end,getIntAmount=function() return 1 end,
        isKeep=function() return keep end,isDamaged=function() return index==0 and not sharpening end,
        isSharpenable=function() return index==0 and sharpening==true end,index=index}
end
local targetInput,toolInput=input(true,0),input(true,1)
local actionScript={getMetabolics=function() return __nativeCraft('actionMetabolics') end,
    hasMuscleStrain=function() return __nativeCraft('actionHasMuscleStrain') end,
    isCantSit=function() return __nativeCraft('actionCantSit') end,getActionAnim=function() return __nativeCraft('actionAnim') end,
    getAnimVarKey=function() return nil end,
    getSound=function() return __nativeCraft('actionSound') end,getSoundTime=function() return __nativeCraft('actionSoundTime') end,
    getCompletionSound=function() return nil end}
local recipe={getRequiredSkillCount=function() return 1 end,getRequiredSkill=function() return {} end,getOutputs=function() return list() end,getInputs=function() return list({targetInput,toolInput}) end,
    getIndexForIO=function(_,i) return i.index end,getIOForIndex=function(_,n) return n==0 and targetInput or n==1 and toolInput end,
    getName=function() return 'FixSaw' end,getTranslationName=function() return 'Repair saw' end,
    getTime=function() return __nativeCraft('recipeTime') end,getTimedActionScript=function() return actionScript end,
    isCanWalk=function() return false end}
recipe.targetInput,recipe.toolInput=targetInput,toolInput
local recipes={['Base.FixSaw']=recipe}
for _,name in ipairs({'Base.SharpenBlade','Base.SharpenBladePoorlyWithFile'}) do
    local target,tool=input(true,0,true),input(true,1,true)
    local r={targetInput=target,toolInput=tool,toolCategory=name=='Base.SharpenBlade' and 'whetstone' or 'file'}
    for k,v in pairs(recipe) do if type(v)=='function' then r[k]=v end end
    r.getRequiredSkillCount=function() return 0 end
    r.getInputs=function() return list({target,tool}) end
    r.getIOForIndex=function(_,n) return n==0 and target or n==1 and tool end
    r.getName=function() return name:sub(6) end
    recipes[name]=r
end
ScriptManager={instance={getCraftRecipe=function(_,name) return __recipeRegistered~=false and recipes[name] or nil end}}
CraftRecipeManager={hasPlayerLearnedRecipe=function(_,body) return body.recipeKnown~=false and __nativeCraft('recipeLearned') end,
    hasPlayerRequiredSkill=function() return __nativeCraft('requiredSkill') end,
    getValidInputScriptForItem=function(r,item)
        if r==recipe and item:hasTag(ItemTag.SAW) or r~=recipe and item:hasTag(ItemTag.SHARPENABLE) then return r.targetInput end
        if item:hasTag(r.toolCategory=='whetstone' and ItemTag.WHETSTONE or ItemTag.FILE) then return r.toolInput end
    end}
HandcraftLogic={new=function(body)
    local l={body=body,manual={},outputs={}}
    function l:setContainers(v) self.containers=v end
    function l:setRecipe(v) self.recipe=v end
    function l:setTargetVariableInputRatio(v) self.ratio=v end
    function l:setManualSelectInputs(v) self.selected=v end
    function l:isManualSelectInputs() return self.selected==true end
    function l:clearManualInputs() self.manual={} end
    function l:setManualInputsFor(i,items)
        if body.manualRefused then return false end
        self.manual[i]=items;return items:size()==1
    end
    function l:canPerformCurrentRecipe()
        if body.nativeRefused or not self.selected or not self.manual[self.recipe.targetInput] or not self.manual[self.recipe.toolInput]
            or self.manual[self.recipe.targetInput]:get(0)~=body.target or self.manual[self.recipe.toolInput]:get(0)~=body.tool then return false end
        return __nativeCraft('eligible')==true
    end
    function l:getRecipeData()
        local selfLogic=self
        return {getAllInputItems=function() return list({body.target,body.tool}) end,
            getAllCreatedItems=function() return list(selfLogic.outputs) end,
            getAllKeepInputItems=function() return list(not body.hideNativeKept and __nativeCraft('keptExact') and {body.target,body.tool} or {}) end,
            getAllConsumedItems=function() return list(__nativeCraft('consumedTarget') and {body.target} or __nativeCraft('consumedTool') and {body.tool} or {}) end,
            luaCallOnCreate=function()
                body.createCallbacks=(body.createCallbacks or 0)+1
                if body.breakFileAtCallback then __nativeCraft('setToolCondition',0) end
                if body.seedNativeCallback~=nil then __nativeCraft('seed',body.seedNativeCallback) end
                __nativeCraft('onCreate');body.target.condition=__nativeCraft('condition');body.tool.condition=__nativeCraft('toolCondition')
                body.target.repairCount=__nativeCraft('repairCount')
                body.target.sharpness=__nativeCraft('sharpness');body.target.maxSharpness=__nativeCraft('maxSharpness')
                if body.target:hasHeadCondition() then body.target.headCondition=__nativeCraft('headCondition') end
            end,
            processDestroyAndUsedItems=function()
                __nativeCraft('process');body.target.condition=__nativeCraft('condition');body.tool.condition=__nativeCraft('toolCondition')
                if body.dropTarget then body.target:getContainer():Remove(body.target) end
            end}
    end
    function l:getModelHandOne() return 'File' end
    function l:getModelHandTwo() return 'Saw' end
    function l:performCurrentRecipe()
        body.nativeCalls=(body.nativeCalls or 0)+1
        if not __nativeCraft('perform') then return false end
        self.outputs={}
        return true
    end
    function l:getCreatedOutputItems(out) for _,i in ipairs(self.outputs) do out:add(i) end end
    return l
end}
Actions={addOrDropItem=function(body,item)
    if body.dropOutputs then return end
    local inventory=body:getInventory();inventory.items[#inventory.items+1]=item;item.container=inventory
end}
ISTakeWaterAction=ISBaseTimedAction:derive('ISTakeWaterAction')
SAO.Locomotion={jobs={}};SAO.Controller={agents={}}
SAO.Needs.busy=function(body) local q=ISTimedActionQueue.getTimedActionQueue(body);return q.current~=nil or #q.queue>0 end
SAO.Standing.mayTakeCurrent=function() return __permission~=false end
SAO.Needs.read=function() return {hunger=.1,thirst=.1,fatigue=.1} end
SAOJavaBridge.privateCarriedItems=function(_,body)
    __carriedScans=(__carriedScans or 0)+1
    local items={};for _,inv in ipairs({body:getInventory(),body:getInventory().nested}) do
        for _,item in ipairs(inv.items) do items[#items+1]=item end
    end
    return list(items)
end
local originalTimed=LuaTimedActionNew.new
LuaTimedActionNew.new=function(action,body)
    local a=originalTimed(action,body)
    function a:setOverrideHandModels() end
    function a:overrideHandModels() end
    function a:setOverrideHandModelsObject() end
    function a:stopTimedActionAnim() end
    function a:setAnimVariable() end
    return a
end
local function fixture(id,nested,recipeId,targetType,toolType)
    __nativeCraft('reset');__permission=true;__recipeRegistered=true;__hours=100
    recipeId=recipeId or 'Base.FixSaw';targetType=targetType or 'Saw';toolType=toolType or 'File'
    __nativeCraft('recipe',recipeId)
    if targetType~='Saw' then __nativeCraft('targetType',targetType) end
    if toolType~='File' then __nativeCraft('toolType',toolType) end
    local f=__boardingFixture(id,false)
    f.body.emitter=f.emitter
    f.inventory.items={};f.rec.bodyOwnerToken=nil;f.body.md.SAOExternalToken=nil
    f.target=material(targetType,701,f.inventory);f.tool=material(toolType,702,f.inventory)
    f.target.condition,f.target.repairCount=__nativeCraft('condition'),__nativeCraft('repairCount')
    f.tool.condition=__nativeCraft('toolCondition')
    f.target.sharpness,f.target.maxSharpness=__nativeCraft('sharpness'),__nativeCraft('maxSharpness')
    if __nativeCraft('hasHeadCondition') then f.target.headCondition=__nativeCraft('headCondition') end
    f.inventory.items={f.target,f.tool};f.body.target,f.body.tool=f.target,f.tool
    if nested then
        local bag={items=f.inventory.items};__boardingInventory(bag,f.inventory)
        function bag:contains(i) for _,x in ipairs(self.items) do if i==x then return true end end;return false end
        function bag:Remove(i) for n,x in ipairs(self.items) do if i==x then table.remove(self.items,n);i.container=nil;return end end end
        f.inventory.nested=bag;f.inventory.items={};f.target.container,f.tool.container=bag,bag
    end
    function f.body:getVehicle() return nil end
    local sq=f.body:getCurrentSquare()
    function sq:TreatAsSolidFloor() return true end
    function sq:isSolid() return false end
    function sq:isSolidTrans() return false end
    function f.body:isAttacking() return false end
    function f.body:isAiming() return false end
    function f.body:isClimbing() return false end
    function f.body:isClimbingRope() return false end
    function f.body:playSound(sound) return self:getEmitter():playSound(sound) end
    function f.body:stopOrTriggerSound(sound) self:getEmitter():stopOrTriggerSound(sound) end
    function f.body:isTimedActionInstant() return false end
    function f.body:isSitOnGround() return false end
    function f.body:getBodyDamage() return {getOverallBodyHealth=function() return 100 end,
        getBodyPart=function() return {getPain=function() return 0 end} end} end
    SAO.Controller.agents[id]=f.agent
    local p=SAO.ProceduralPlanning.maintain(id,{key='native-repair-test',domain='construction',objective='Board the observed entry'})
    p.materialWork={operation='board',entryKey='barricade:0:0:0:0:true'}
    p.constructionDestination={key=p.materialWork.entryKey,x=0,y=0,z=0}
    p.steps={{id='repair-saw:701:2',verb='produce',owner='SAO.ResourceProduction',token='resource:repaired',
        target='Base.FixSaw',recipeId='Base.FixSaw',productionKind='repair-held-item',category='saw',status='available',
        targetItemId='701',targetItemType='Base.Saw',toolItemId='702',toolItemType='Base.File'},
        {id='return-entry',verb='go',owner='Locomotion',token='travel:arrived',target=p.materialWork.entryKey,status='available'}}
    p.cursor=1;f.purpose,f.step=p,p.steps[1]
    if recipeId~='Base.FixSaw' then
        p.materialWork={operation='maintain-tool',entryKey='held-item:701',targetItemId='701',targetItemType='Base.'..targetType}
        p.constructionDestination=nil;p.steps={f.step}
        local policy=SAO.ResourceProduction.repairPolicy(recipeId)
        f.step.target,f.step.recipeId=recipeId,recipeId
        f.step.category,f.step.toolCategory,f.step.effectMetric=policy.category,policy.toolCategory,policy.effectMetric
    end
    f.step.targetItemType,f.step.toolItemType='Base.'..targetType,'Base.'..toolType
    return f
end
local function begin(f)
    return SAO.ResourceProduction.begin(f.id,f.body,f.step,{purposeId=f.purpose.id,purposeStepId=f.step.id})
end
local function action(f) return ISTimedActionQueue.getTimedActionQueue(f.body).current end
local function finish(f)
    local q=ISTimedActionQueue.getTimedActionQueue(f.body)
    local loops=0
    while q.current do
        loops=loops+1;if loops>4 then error('preparation loop') end
        local a=q.current
        if a.Type=='ISInventoryTransferAction' then
            a.getNotFullFloorSquare=function() return nil end
            a.playTransferCompleteSound=function() end
        end
        a:start();a.action.nativeFinished=true;a:perform();a:complete()
        if q.current==a then
            for _,v in ipairs(__checks) do print(v) end
            print('work detail='..tostring(f.rec.resourceProductionWork and f.rec.resourceProductionWork.detail)..' status='..tostring(f.rec.resourceProductionWork and f.rec.resourceProductionWork.status)..' stage='..tostring(f.rec.resourceProductionWork and f.rec.resourceProductionWork.stage)..' started='..tostring(a.craftStarted)..' outputs='..tostring(__nativeCraft('count')))
            error('native action remained current '..tostring(a.Type))
        end
    end
    return f.rec.resourceProductionOutcomes and f.rec.resourceProductionOutcomes[#f.rec.resourceProductionOutcomes]
end
local function cancel(f)
    f.body.holdCancellation=false;SAO.ResourceProduction.interrupt(f.id,f.body,'case-ended')
end
local function saved(f)
    local r=__nativeRoundtrip(f.rec);__records[f.id]=r;f.rec=r;f.agent.rec=r
    f.purpose=r.proceduralPlanning.purposes[f.purpose.id];f.step=f.purpose.steps[f.purpose.cursor]
    return r
end
local function check(name,value) local row=name..'='..tostring(value==true);__checks[#__checks+1]=row;print(row) end
-- Each known-bad run executes the relevant receiver case in isolation, so a
-- detected owner defect cannot turn later independent cases into incidental errors.
function __runRepairControl(name)
    local R,P,C=SAO.ResourceProduction,SAO.ProceduralPlanning,SAO.Cognition
    C.ensureGameDefaults()
    local f=fixture('fault-'..name,name=='transfer-cosmetic-cleanup')
    local a,row,q,value
    if name=='native-end' then
        begin(f);a=action(f);a:start()
        check('perform_before_native_end_refuses',a:perform()==false and __nativeCraft('condition')==2)
    elseif name=='callback-ownership' then
        begin(f);a=action(f);a:start();a.action.nativeFinished=true
        check('direct_recipe_callback_refuses',a:performRecipe()==false and __nativeCraft('condition')==2)
    elseif name=='material-binding' then
        begin(f);a=action(f);a:start();f.inventory:Remove(f.target)
        local replacement=material('Saw',701,f.inventory);f.inventory.items[#f.inventory.items+1]=replacement;a.action.nativeFinished=true
        check('same_id_replacement_refuses',a:perform()==false and __nativeCraft('condition')==2)
    elseif name=='native-ack' then
        begin(f);a=action(f);a:start();q=ISTimedActionQueue.getTimedActionQueue(f.body);q.current=nil;q.queue={};f.body.holdCancellation=true
        check('queue_absence_is_not_native_ack',R.interrupt(f.id,f.body,'lost')==false and f.rec.resourceProductionWork~=nil)
    elseif name=='synchronous-stop-ack' then
        begin(f);a=action(f);a:start()
        check('synchronous_native_stop_returns_acknowledged',R.interrupt(f.id,f.body,'sync-stop')==true
            and f.rec.resourceProductionWork==nil and f.purpose.admission==nil and __nativeCraft('condition')==2)
    elseif name=='premature-stop-ack' then
        begin(f);a=action(f);a:start();f.body.holdCancellation=true
        check('pending_native_stop_remains_unacknowledged',R.interrupt(f.id,f.body,'pending-stop')==false
            and f.rec.resourceProductionWork~=nil and f.purpose.admission~=nil and action(f)==a)
    elseif name=='saved-admission' or name=='raw-saved-record' then
        begin(f);local rec=__nativeRoundtrip(f.rec);cancel(f);__records[f.id]=rec;f.rec=rec;f.agent.rec=rec
        f.purpose=rec.proceduralPlanning.purposes[f.purpose.id]
        if name=='saved-admission' then f.purpose.admission.correlationId='wrong'
        else SAO.Controller.agents[f.id]=nil end
        __reloadProduction();value=R.reconcileSaved(f.id,f.body)
        if name=='saved-admission' then check('stale_saved_admission_refuses',value==false and rec.resourceProductionWork~=nil)
        else check('saved_missing_agent_retires_without_drive',value==true and rec.resourceProductionWork==nil and f.purpose.admission==nil) end
    elseif name=='transfer-cosmetic-cleanup' then
        begin(f);a=action(f);a:start();a.loopSound='RummageInInventory';a.loopSoundNoTrigger=true
        f.body.emitter.playing[a.loopSound]=true;a.item.jobDelta=.5;a.action.looped=true;R.interrupt(f.id,f.body,'stop')
        check('native_transfer_cleanup_before_ack',a.item.jobDelta==0 and not a.action.looped and a.loopSound==nil
            and f.body.emitter.stopped.RummageInInventory==1 and f.rec.resourceProductionWork==nil)
    elseif name=='replacement-cosmetic-ownership' then
        begin(f);a=action(f);a:start();q=ISTimedActionQueue.getTimedActionQueue(f.body)
        local successor={character=f.body,isValidStart=function() return true end,begin=function() end,Type='Successor'}
        q.queue={successor};q.current=successor;f.target.jobDelta=.7;f.tool.jobDelta=.8;f.body.farming=true
        R.interrupt(f.id,f.body,'replacement')
        check('replacement_queue_cosmetics_preserved',q.current==successor and q.queue[1]==successor and f.body.farming==true
            and f.target.jobDelta==.7 and f.tool.jobDelta==.8 and f.body.emitter.playing.SharpenBladeWhetstone==true)
    elseif name=='native-kept-inputs' then
        begin(f);f.body.hideNativeKept=true;row=finish(f)
        check('missing_exact_native_kept_inputs_no_credit',row and row.status~='completed' and row.nativeCredit==nil and not f.rec.cognition)
    elseif name=='saved-material-anchor' then
        begin(f);a=action(f);a:start();f.rec.resourceProductionWork.beforeCondition=1;a.action.nativeFinished=true
        check('changed_saved_material_anchor_refuses',a:perform()==false and __nativeCraft('condition')==2)
    elseif name=='manual-input-capsule' then
        begin(f);a=action(f);a:start();a.manualInputs[0]=list({f.tool});a.action.nativeFinished=true
        check('changed_manual_input_refuses',a:perform()==false and __nativeCraft('condition')==2)
    elseif name=='result-condition-bound' then
        begin(f);row=finish(f);row.afterCondition=999;row.fullRestoration=true
        check('forged_durable_condition_refused',R.outcome(f.id,row.id)==nil)
    elseif name=='native-completion-credit' then
        begin(f);row=finish(f);row.afterCondition=row.beforeCondition;row.fullRestoration=false
        check('forged_no_gain_credit_refused',R.outcome(f.id,row.id)==nil)
    elseif name=='native-producer' then
        begin(f);row=finish(f)
        check('native_saw_restored_exact_kept_file',row and row.status=='completed' and row.afterCondition==10 and __nativeCraft('condition')==10)
    elseif name=='generic-fact-gate' then
        check('generic_private_repair_fact_denied',C.experience(f.id,{id='resource-production/'..f.id..'/1',kind='tool-repair',
            category='construction',actorId=f.id,observerId=f.id,perspective='performed',status='completed',worldHours=100,
            sourceId='Base.FixSaw',itemId=701,itemType='Base.Saw',beforeValue=2,afterValue=10})==false and not f.rec.cognition)
    elseif name=='sharpen-target-gate' then
        f=fixture('sharp-gate',false,'Base.SharpenBlade','KitchenKnife','Whetstone')
        f.target.sharpness=f.target.maxSharpness;__nativeCraft('setSharpness',f.target.sharpness)
        check('sharp_blade_refuses',R.repairAvailable(f.id,f.body,f.target,f.step.recipeId)==false)
    elseif name=='selected-effect-measurement' then
        f=fixture('effect-metric',false,'Base.SharpenBlade','KitchenKnife','Whetstone');__nativeCraft('skill',10);f.body.seedNativeCallback=0
        begin(f);row=finish(f)
        check('whetstone_zero_sharpness_native_gain',row and R.outcome(f.id,row.id) and row.status=='completed'
            and row.beforeSharpness==0 and row.afterSharpness>0 and row.effectMetric=='sharpness')
    elseif name=='result-sharpness-bound' then
        f=fixture('sharpness-bound',false,'Base.SharpenBlade','KitchenKnife','Whetstone');__nativeCraft('skill',10);f.body.seedNativeCallback=0
        begin(f);row=finish(f);row.afterSharpness=999;row.fullRestoration=true
        check('forged_durable_sharpness_refused',R.outcome(f.id,row.id)==nil)
    elseif name=='ordinary-inventory-filter' then
        f=fixture('inventory-filter',false,'Base.SharpenBlade','KitchenKnife','Whetstone');f.inventory.items={f.target}
        for i=1,511 do f.inventory.items[#f.inventory.items+1]=material('Nails',10000+i,f.inventory) end
        __carriedScans=0;local options=R.maintenanceOptions(f.id,f.body)
        check('ordinary_inventory_filters_before_exact_custody_scan',#options==2 and __carriedScans==3)
    else error('unknown control '..name) end
    __windowResults=table.concat(__checks,'\n')
end
function __runToolRepairCases()
    local R,P,C,M=SAO.ResourceProduction,SAO.ProceduralPlanning,SAO.Cognition,SAO.CognitiveModels
    C.ensureGameDefaults()
    local f=fixture('native-repair')
    check('installed_recipe_native_eligible',R.repairAvailable(f.id,f.body,f.target,'Base.FixSaw')==true and __nativeCraft('recipeInputs')==2)
    check('ordinary_nil_token_admits',begin(f)==true and f.rec.resourceProductionWork.bodyToken==nil)
    local workId=f.rec.resourceProductionWork and f.rec.resourceProductionWork.id
    check('admission_has_no_effect_or_lesson',workId~=nil and R.outcome(f.id,workId)==nil
        and f.target:getCondition()==2 and __nativeCraft('condition')==2 and not f.rec.cognition)
    check('generic_result_no_repair_credit',P.recordResult(f.id,f.purpose.id,{owner='SAO.ResourceProduction',
        token='resource:repaired',status='completed',correlationId=workId})==false and f.purpose.admission~=nil)
    check('generic_private_repair_fact_denied',C.experience(f.id,{id=workId,kind='tool-repair',category='construction',
        actorId=f.id,observerId=f.id,perspective='performed',status='completed',worldHours=100,
        sourceId='Base.FixSaw',itemId=701,itemType='Base.Saw',beforeValue=2,afterValue=10})==false and not f.rec.cognition)
    local a=action(f);a:start();a.action.nativeFinished=true
    check('direct_recipe_callback_refuses',a:performRecipe()==false and __nativeCraft('condition')==2)
    cancel(f)
    f=fixture('native-effects');begin(f);a=action(f);local purposeId=f.purpose.id;local dest=f.purpose.constructionDestination.key
    local row=finish(f);local canonical=R.outcome(f.id,row and row.id)
    check('native_saw_restored_exact_kept_file',canonical and canonical.status=='completed' and canonical.nativeCredit==canonical.id
        and canonical.nativeAttempted and canonical.nativeCompleted and canonical.targetRetained and canonical.toolRetained
        and canonical.held and canonical.improved and canonical.afterCondition==10 and canonical.fullRestoration
        and __nativeCraft('targetHeld')==true and __nativeCraft('toolHeld')==true and __nativeCraft('keptExact')==true
        and __nativeCraft('createdCount')==0 and f.body.nativeCalls==1 and __nativeCraft('callbacks')==1)
    check('repair_count_measured_without_invented_increment',canonical and canonical.beforeRepairCount==3 and canonical.afterRepairCount==3)
    check('native_file_wear_measured',canonical and canonical.beforeToolCondition==8 and canonical.afterToolCondition==__nativeCraft('toolCondition')
        and canonical.afterToolCondition<=8)
    check('same_boarding_purpose_retained',f.purpose.id==purposeId and f.purpose.admission==nil
        and f.purpose.status~='completed' and f.purpose.constructionDestination.key==dest)
    check('private_native_repair_experience_once',f.rec.cognition and #f.rec.cognition.experiences==1
        and f.rec.cognition.experiences[1].actorId==f.id and f.rec.cognition.experiences[1].kind=='tool-repair'
        and f.rec.cognition.experiences[1].perspective=='performed' and canonical.experienceDelivered==true)
    local detached=R.outcome(f.id,row.id);detached.afterCondition=999
    check('outcome_detached_and_forgery_refused',R.outcome(f.id,row.id).afterCondition==10 and C.toolRepairOutcome(f.id,detached)==false)
    check('foreign_fact_refused',C.toolRepairOutcome('foreign',canonical)==false and __records.foreign==nil)
    R.reconcileSaved(f.id,f.body);R.tick(f.id,f.body)
    check('terminal_delivery_not_replayed',#f.rec.cognition.experiences==1 and __nativeCraft('callbacks')==1)
    check('duplicate_native_callback_inert',a:performRecipe()==false and a:complete()==false and __nativeCraft('callbacks')==1)
    saved(f)
    check('native_save_retains_private_fact',#f.rec.cognition.experiences==1 and R.outcome(f.id,row.id).experienceDelivered==true)
    local legacy=f.rec.resourceProductionOutcomes[1]
    legacy.effectMetric,legacy.toolCategory=nil,nil
    check('legacy_saved_fixsaw_row_supported',R.outcome(f.id,legacy.id)~=nil)
    row=f.rec.resourceProductionOutcomes[1];row.afterCondition=999;row.fullRestoration=true
    check('forged_durable_condition_refused',R.outcome(f.id,row.id)==nil)
    row.afterCondition=row.beforeCondition
    check('forged_no_gain_credit_refused',R.outcome(f.id,row.id)==nil)
    row.afterCondition=10;row.fullRestoration=true
    local policy=R.repairPolicy('Base.SharpenBlade');policy.toolCategory='file'
    check('portable_policy_detached_and_finite',R.repairPolicy('Base.SharpenBlade').toolCategory=='whetstone'
        and R.repairPolicy('Base.SharpenBladePoorlyWithFile').effectMetric=='sharpness'
        and R.repairPolicy('Base.SharpenBladeWithGrindstone')==nil)
    f=fixture('small-saw-family',false,'Base.FixSaw','SmallSaw','File')
    f.target.condition=2;__nativeCraft('setTargetCondition',2);begin(f);row=finish(f)
    check('native_small_saw_family_restores',row and row.status=='completed' and row.afterCondition==row.maxCondition)
    f=fixture('whetstone-sharpening',false,'Base.SharpenBlade','KitchenKnife','Whetstone');__nativeCraft('skill',10);f.body.seedNativeCallback=0
    check('full_condition_dull_blade_native_eligible',f.target.condition==f.target:getConditionMax()
        and R.repairAvailable(f.id,f.body,f.target,f.step.recipeId)==true)
    f.inventory.items={f.target};local options=R.maintenanceOptions(f.id,f.body)
    check('maintenance_options_private_target_without_tool',#options==2 and options[1].targetItemId=='701'
        and options[1].targetItemType=='Base.KitchenKnife' and options[1].sharpness==0 and begin(f)==false)
    for i=1,511 do f.inventory.items[#f.inventory.items+1]=material('Nails',10000+i,f.inventory) end
    __carriedScans=0;options=R.maintenanceOptions(f.id,f.body)
    check('ordinary_inventory_filters_before_exact_custody_scan',#options==2 and __carriedScans==3)
    f.inventory.items={f.target}
    for i=1,20 do f.inventory.items[#f.inventory.items+1]=material('KitchenKnife',20000+i,f.inventory) end
    options=R.maintenanceOptions(f.id,f.body)
    check('maintenance_options_bounded_to_32',#options==32)
    f.inventory.items={f.target,f.tool};begin(f);row=finish(f)
    check('whetstone_zero_sharpness_native_gain',row and R.outcome(f.id,row.id) and row.status=='completed'
        and row.beforeSharpness==0 and row.afterSharpness>0 and row.effectMetric=='sharpness'
        and row.nativeCompleted and row.targetRetained and row.toolRetained and __nativeCraft('callbacks')==1)
    check('independent_upkeep_closes_and_native_fact_once',f.purpose.admission==nil and f.purpose.status=='completed'
        and f.rec.cognition and #f.rec.cognition.experiences==1 and f.rec.cognition.experiences[1].category=='construction'
        and f.rec.cognition.experiences[1].effectMetric=='sharpness')
    saved(f);check('sharpness_observations_survive_native_save',R.outcome(f.id,row.id).afterSharpness==row.afterSharpness)
    row=f.rec.resourceProductionOutcomes[1];row.afterSharpness=999;row.fullRestoration=true
    check('forged_durable_sharpness_refused',R.outcome(f.id,row.id)==nil)
    f=fixture('sharp-blade',false,'Base.SharpenBlade','KitchenKnife','Whetstone')
    f.target.sharpness=f.target.maxSharpness;__nativeCraft('setSharpness',f.target.sharpness)
    check('sharp_blade_refuses',R.repairAvailable(f.id,f.body,f.target,f.step.recipeId)==false)
    f=fixture('file-condition-damage',false,'Base.SharpenBladePoorlyWithFile','KitchenKnife','File')
    -- A fragile native file ends after one real sharpening iteration.
    -- Native RNG seed19 admits the independently measured damage branch.
    __nativeCraft('skill',0);__nativeCraft('setToolCondition',1);__nativeCraft('setToolWearChance',1)
    f.tool.condition=1;f.body.seedNativeCallback=19;begin(f);row=finish(f)
    check('native_file_sharpness_gain_preserves_condition_damage',row and R.outcome(f.id,row.id) and row.status=='completed'
        and row.afterSharpness>row.beforeSharpness and row.afterCondition<row.beforeCondition
        and not row.fullRestoration and row.afterCondition==__nativeCraft('condition'))
    local fact=f.rec.cognition and f.rec.cognition.experiences[1]
    check('private_fact_retains_native_condition_loss',fact and fact.effectMetric=='sharpness' and fact.conditionLoss==row.beforeCondition-row.afterCondition)
    f=fixture('file-head-damage',false,'Base.SharpenBladePoorlyWithFile','HandAxe','File')
    -- A fragile native file ends after one real sharpening iteration.
    -- Native RNG seed19 admits the independently measured damage branch.
    __nativeCraft('skill',0);__nativeCraft('setToolCondition',1);__nativeCraft('setToolWearChance',1)
    f.tool.condition=1;f.body.seedNativeCallback=19;begin(f);row=finish(f)
    check('native_axe_sharpness_gain_preserves_head_damage',row and R.outcome(f.id,row.id) and row.status=='completed'
        and row.afterSharpness>row.beforeSharpness and row.afterHeadCondition<row.beforeHeadCondition
        and row.afterHeadCondition==__nativeCraft('headCondition'))
    fact=f.rec.cognition and f.rec.cognition.experiences[1]
    check('private_fact_retains_native_head_loss',fact and fact.headConditionLoss==row.beforeHeadCondition-row.afterHeadCondition)
    local separateDamage=true
    local baseKey='plan:tool-repair:construction:'..#row.recipeId..':'..row.recipeId..':'..#row.targetItemType..':'..row.targetItemType
    local damageCandidate={id='maintenance-damage',evidence=1,continuity=1,novelty=0,informationGain=0,blockers=0,
        consequences={{kind='tool-repair',category='construction',sourceId=row.recipeId,itemType=row.targetItemType,condition='damage',value=-.25}}}
    for _,model in ipairs({'ordinary','associative'}) do
        local own=f.rec.cognition and f.rec.cognition.models[model]
        local benefit=own and own.beliefs[baseKey]
        local damage=own and own.beliefs[baseKey..':damage']
        local prediction=own and M.planPrediction(model,damageCandidate,own,{actorId=f.id,atHours=100,pressure=.5})
        local selected=prediction and prediction.predictions[1]
        separateDamage=separateDamage and benefit~=nil and damage~=nil and benefit.condition==nil and damage.condition=='damage'
            and benefit.id~=damage.id and benefit.support==1 and damage.support==1
            and selected~=nil and selected.probability>.5 and #selected.beliefIds==1 and selected.beliefIds[1]==damage.id
            and #selected.evidenceIds==1 and selected.evidenceIds[1]==fact.id
    end
    check('both_models_predict_exact_separate_native_damage',separateDamage)
    f=fixture('native-partial');f.tool.condition=1;__nativeCraft('setToolCondition',1);__nativeCraft('setToolWearChance',1)
    check('low_condition_file_admits',begin(f)==true);row=finish(f)
    check('native_depleted_file_can_yield_full_restoration',row and row.status=='completed' and row.afterCondition==row.maxCondition
        and row.fullRestoration==true and row.afterToolCondition<=0
        and row.toolRetained==true and __nativeCraft('toolHeld')==true)
    f=fixture('native-no-gain');begin(f);f.body.breakFileAtCallback=true;row=finish(f)
    check('native_completed_without_gain_is_failed',row and row.status=='failed' and row.nativeCompleted and row.nativeAttempted
        and row.afterCondition==row.beforeCondition and not row.improved and not row.fullRestoration and row.nativeCredit==nil
        and __nativeCraft('callbacks')==1 and __nativeCraft('condition')==2 and row.afterToolCondition==0)
    local key='plan:tool-repair:construction:11:Base.FixSaw:8:Base.Saw'
    local negative=true
    local candidate={id='repair-again',evidence=1,continuity=1,novelty=0,informationGain=0,blockers=0,
        consequences={{kind='tool-repair',category='construction',sourceId='Base.FixSaw',itemType='Base.Saw',value=1}}}
    for _,model in ipairs({'ordinary','associative'}) do
        local own=f.rec.cognition and f.rec.cognition.models[model]
        local belief=own and own.beliefs[key]
        local prediction=own and M.planPrediction(model,candidate,own,{actorId=f.id,atHours=100,pressure=.5})
        negative=negative and belief~=nil and belief.against==1 and belief.support==0 and prediction~=nil
            and prediction.predictions[1].probability<.5
    end
    check('canonical_no_gain_changes_both_private_predictions',negative and #f.rec.cognition.experiences==1
        and f.rec.cognition.experiences[1].status=='no-effect')
    R.reconcileSaved(f.id,f.body)
    check('no_gain_private_fact_not_replayed',#f.rec.cognition.experiences==1 and f.rec.cognition.models.ordinary.beliefs[key].against==1)
    f=fixture('nested-inputs',true);check('nested_exact_inputs_admitted',begin(f)==true and action(f).Type=='ISInventoryTransferAction')
    row=finish(f)
    check('installed_transfers_precede_native_repair',row and row.status=='completed' and f.target:getContainer()==f.inventory
        and f.tool:getContainer()==f.inventory and not f.inventory.nested:contains(f.target) and not f.inventory.nested:contains(f.tool))
    f=fixture('native-floor-alternative');__nativeCraft('addFloorTarget');begin(f);row=finish(f)
    check('manual_all_slots_keep_floor_alternative',row and row.status=='completed' and __nativeCraft('floorTargetUntouched')==true
        and row.targetItemId=='701' and row.toolItemId=='702')
    f=fixture('before-file');f.inventory.items={f.target}
    check('availability_independent_of_file',R.repairAvailable(f.id,f.body,f.target,'Base.FixSaw')==true and begin(f)==false)
    f=fixture('unheld-target');f.inventory.items={f.tool}
    check('unheld_target_availability_refused',R.repairAvailable(f.id,f.body,f.target,'Base.FixSaw')==false and begin(f)==false)
    f=fixture('standing-refused');__permission=false
    check('current_standing_claim_refuses',R.repairAvailable(f.id,f.body,f.target,'Base.FixSaw')==false and begin(f)==false)
    f=fixture('network-refused');local nativeClient,nativeServer=isClient,isServer
    isClient=function() return true end
    check('network_client_admission_refused',begin(f)==false and __nativeCraft('condition')==2);isClient=nativeClient
    isServer=function() return true end
    check('network_server_admission_refused',begin(f)==false and __nativeCraft('condition')==2);isServer=nativeServer
    f=fixture('wrong-recipe')
    check('wrong_registered_recipe_refused',R.repairAvailable(f.id,f.body,f.target,'Base.SawLogs')==false)
    f=fixture('skill-refused');__nativeCraft('skill',1)
    check('native_skill_refusal',R.repairAvailable(f.id,f.body,f.target,'Base.FixSaw')==false and begin(f)==false)
    f=fixture('knowledge-refused');f.body.recipeKnown=false
    check('native_knowledge_refusal',R.repairAvailable(f.id,f.body,f.target,'Base.FixSaw')==false and begin(f)==false)
    f=fixture('unregistered');__recipeRegistered=false
    check('unregistered_recipe_refuses',R.repairAvailable(f.id,f.body,f.target,'Base.FixSaw')==false and begin(f)==false);__recipeRegistered=true
    f=fixture('broken-target');f.target.condition=0;__nativeCraft('setTargetCondition',0)
    check('broken_target_refuses',R.repairAvailable(f.id,f.body,f.target,'Base.FixSaw')==false and begin(f)==false)
    f=fixture('undamaged-target');f.target.condition=10;__nativeCraft('setTargetCondition',10)
    check('undamaged_target_refuses',R.repairAvailable(f.id,f.body,f.target,'Base.FixSaw')==false and begin(f)==false)
    f=fixture('broken-file');f.tool.condition=0;__nativeCraft('setToolCondition',0)
    check('broken_file_refuses',begin(f)==false and __nativeCraft('condition')==2)
    f=fixture('manual-refused');f.body.manualRefused=true
    check('native_manual_admission_refuses',begin(f)==false and __nativeCraft('condition')==2)
    f=fixture('native-refused');f.body.nativeRefused=true
    check('native_eligibility_refuses',begin(f)==false and __nativeCraft('condition')==2)
    f=fixture('forged-finish');begin(f);a=action(f)
    check('complete_without_native_perform_refuses',a:complete()==false and __nativeCraft('condition')==2);cancel(f)
    f=fixture('unfinished-perform');begin(f);a=action(f);a:start()
    check('perform_before_native_end_refuses',a:perform()==false and __nativeCraft('condition')==2);cancel(f)
    f=fixture('item-replacement');begin(f);a=action(f);a:start()
    f.inventory:Remove(f.target);local replacement=material('Saw',701,f.inventory);f.inventory.items[#f.inventory.items+1]=replacement
    a.action.nativeFinished=true
    check('same_id_replacement_refuses',a:perform()==false and __nativeCraft('condition')==2 and replacement:getCondition()==2);cancel(f)
    f=fixture('file-replacement');begin(f);a=action(f);a:start();f.inventory:Remove(f.tool)
    replacement=material('File',702,f.inventory);f.inventory.items[#f.inventory.items+1]=replacement;a.action.nativeFinished=true
    check('same_id_file_replacement_refuses',a:perform()==false and __nativeCraft('condition')==2);cancel(f)
    f=fixture('changed-token');begin(f);a=action(f);a:start();f.body.md.SAOExternalToken='replacement-token';a.action.nativeFinished=true
    check('changed_body_token_refuses',a:perform()==false and __nativeCraft('condition')==2);cancel(f)
    f=fixture('replacement-body');begin(f);a=action(f);a:start();SAO.Body.active[f.id]={};a.action.nativeFinished=true
    check('replacement_body_refuses_effect',a:perform()==false and __nativeCraft('condition')==2);cancel(f)
    f=fixture('replacement-queue');begin(f);a=action(f);a:start();local originalQueue=ISTimedActionQueue.queues[f.body]
    ISTimedActionQueue.queues[f.body]={current=nil,queue={}};a.action.nativeFinished=true
    check('replacement_native_queue_refuses_effect',a:perform()==false and __nativeCraft('condition')==2)
    ISTimedActionQueue.queues[f.body]=originalQueue;cancel(f)
    f=fixture('changed-target');begin(f);a=action(f);a:start();f.purpose.materialWork.entryKey='barricade:9:9:0:0:true';a.action.nativeFinished=true
    check('changed_retained_entry_refuses',a:perform()==false and __nativeCraft('condition')==2);cancel(f)
    f=fixture('changed-anchor');begin(f);a=action(f);a:start();f.rec.resourceProductionWork.beforeCondition=1;a.action.nativeFinished=true
    check('changed_saved_material_anchor_refuses',a:perform()==false and __nativeCraft('condition')==2)
    f.rec.resourceProductionWork.beforeCondition=2;cancel(f)
    f=fixture('changed-recipe');begin(f);a=action(f);a:start();a.craftRecipe={};a.action.nativeFinished=true
    check('changed_native_recipe_refuses',a:perform()==false and __nativeCraft('condition')==2);cancel(f)
    f=fixture('manual-map-mutated');begin(f);a=action(f);a:start();a.manualInputs[0]=list({f.tool});a.action.nativeFinished=true
    check('changed_manual_input_refuses',a:perform()==false and __nativeCraft('condition')==2);cancel(f)
    f=fixture('lost-queue');begin(f);a=action(f);a:start();local q=ISTimedActionQueue.getTimedActionQueue(f.body)
    q.queue={};q.current=nil;f.body.holdCancellation=true
    check('queue_absence_is_not_native_ack',R.interrupt(f.id,f.body,'lost-queue')==false and f.rec.resourceProductionWork~=nil)
    f.body.holdCancellation=false;a:stop();R.retryCraftCancellations()
    check('native_stop_ack_releases_claim',f.rec.resourceProductionWork==nil and f.purpose.admission==nil)
    f=fixture('synchronous-stop-return');begin(f);a=action(f);a:start()
    check('synchronous_native_stop_returns_acknowledged',R.interrupt(f.id,f.body,'sync-stop')==true
        and f.rec.resourceProductionWork==nil and f.purpose.admission==nil and f.target:getCondition()==2
        and __nativeCraft('callbacks')==0 and #f.rec.resourceProductionOutcomes==1)
    check('duplicate_stop_acknowledgement_is_inert',R.interrupt(f.id,f.body,'duplicate-stop')==true
        and #f.rec.resourceProductionOutcomes==1 and __nativeCraft('callbacks')==0)
    f=fixture('pending-stop-return');begin(f);a=action(f);a:start();f.body.holdCancellation=true
    check('pending_native_stop_remains_unacknowledged',R.interrupt(f.id,f.body,'pending-stop')==false
        and f.rec.resourceProductionWork~=nil and f.purpose.admission~=nil and action(f)==a
        and f.rec.resourceProductionOutcomes==nil and __nativeCraft('callbacks')==0)
    f.body.holdCancellation=false;a:stop()
    check('pending_native_stop_ack_can_then_release',R.interrupt(f.id,f.body,'after-native-ack')==true
        and f.rec.resourceProductionWork==nil and f.purpose.admission==nil)
    f=fixture('synchronous-stop-successor');begin(f);a=action(f);a:start();q=ISTimedActionQueue.getTimedActionQueue(f.body)
    local nextAction={character=f.body,Type='UnrelatedSuccessor',isValidStart=function() return true end,
        begin=function(self) self.begun=true;f.body.farming=true;f.target.jobDelta=.7;f.tool.jobDelta=.8;
            f.body.emitter.playing.SuccessorLoop=true end}
    q.queue[#q.queue+1]=nextAction
    check('synchronous_stop_preserves_started_successor',R.interrupt(f.id,f.body,'sync-successor')==true
        and q.current==nextAction and q.queue[1]==nextAction and nextAction.begun==true and f.body.farming==true
        and f.target.jobDelta==.7 and f.tool.jobDelta==.8 and f.body.emitter.playing.SuccessorLoop==true
        and f.rec.resourceProductionWork==nil and f.purpose.admission==nil)
    q.current=nil;q.queue={}
    f=fixture('actor-death');begin(f);a=action(f);a:start();f.rec.dead=true;f.body.dead=true;f.body.holdCancellation=true
    check('actor_death_retains_pending_native_ownership',R.tick(f.id,f.body)=='cancelling' and f.rec.resourceProductionWork~=nil
        and f.purpose.admission~=nil and __nativeCraft('condition')==2)
    f.body.holdCancellation=false;a:stop();R.retryCraftCancellations()
    check('actor_death_native_ack_retires_without_effect',f.rec.resourceProductionWork==nil and f.purpose.admission==nil
        and f.target:getCondition()==2 and not f.rec.cognition)
    f=fixture('body-retirement');begin(f);a=action(f);a:start();SAO.Body.active[f.id]=nil;f.body.holdCancellation=true
    check('body_retirement_waits_native_ack',R.detach(f.id)==false and f.rec.resourceProductionWork~=nil and f.purpose.admission~=nil)
    f.body.holdCancellation=false;a:stop()
    check('body_retirement_ack_has_no_credit',R.detach(f.id)==true and f.purpose.admission==nil and __nativeCraft('condition')==2)
    f=fixture('transfer-stop',true);begin(f);a=action(f);a:start();a.loopSound='RummageInInventory';a.loopSoundNoTrigger=true
    f.body.emitter.playing[a.loopSound]=true;a.item.jobDelta=.5;a.action.looped=true
    R.interrupt(f.id,f.body,'prepare-interrupted')
    check('native_transfer_cleanup_before_ack',a.item.jobDelta==0 and a.action.looped==false and a.loopSound==nil
        and f.body.emitter.stopped.RummageInInventory==1 and f.rec.resourceProductionWork==nil)
    f=fixture('repair-stop');begin(f);a=action(f);a:start();a:update();R.interrupt(f.id,f.body,'repair-interrupted')
    check('native_repair_stop_cosmetic_cleanup',f.target.jobDelta==0 and f.tool.jobDelta==0 and f.body.emitter.triggered.SharpenBladeWhetstone==1
        and f.purpose.admission==nil and __nativeCraft('condition')==2)
    f=fixture('replacement-owner');begin(f);a=action(f);a:start();q=ISTimedActionQueue.getTimedActionQueue(f.body)
    local successor={character=f.body,isValidStart=function() return true end,begin=function() end,Type='Successor'}
    q.queue={successor};q.current=successor;f.target.jobDelta=.7;f.tool.jobDelta=.8;f.body.farming=true
    R.interrupt(f.id,f.body,'replacement')
    check('replacement_queue_cosmetics_preserved',q.current==successor and q.queue[1]==successor and f.body.farming==true
        and f.target.jobDelta==.7 and f.tool.jobDelta==.8 and f.body.emitter.playing.SharpenBladeWhetstone==true)
    q.queue={};q.current=nil
    f=fixture('dropped-target');begin(f);f.body.dropTarget=true;row=finish(f)
    check('native_improvement_unheld_has_no_credit',row and row.status~='completed' and row.nativeCredit==nil
        and row.held==false and __nativeCraft('condition')==10 and f.purpose.admission==nil and not f.rec.cognition)
    f=fixture('native-kept-query-refused');begin(f);f.body.hideNativeKept=true;row=finish(f)
    check('missing_exact_native_kept_inputs_no_credit',row and row.status~='completed' and row.nativeCredit==nil
        and f.purpose.admission==nil and not f.rec.cognition)
    f=fixture('saved-native-owner');begin(f);saved(f);f.body.holdCancellation=true;__reloadProduction()
    check('saved_native_queue_waits_original_ack',R.reconcileSaved(f.id,f.body)==false and f.rec.resourceProductionWork~=nil)
    f.body.holdCancellation=false;action(f):stop()
    check('saved_native_ack_then_recovery',R.reconcileSaved(f.id,f.body)==true and f.purpose.admission==nil and __nativeCraft('condition')==2)
    f=fixture('saved-quiet');begin(f);local quietRecord=__nativeRoundtrip(f.rec);cancel(f)
    __records[f.id]=quietRecord;f.rec=quietRecord;f.agent.rec=quietRecord;f.purpose=quietRecord.proceduralPlanning.purposes[f.purpose.id]
    __reloadProduction();local samePurpose=f.purpose.id
    check('saved_nil_token_work_recovers_without_effect',R.reconcileSaved(f.id,f.body)==true and f.purpose.admission==nil
        and f.purpose.id==samePurpose and f.rec.resourceProductionOutcomes[1].nativeObservability=='runtime-unavailable'
        and f.rec.resourceProductionOutcomes[1].nativeAttempted==false and f.rec.resourceProductionOutcomes[1].afterCondition==nil
        and f.target:getCondition()==2)
    f.step=f.purpose.steps[f.purpose.cursor];f.step.status='available'
    check('saved_purpose_resumes_actual_remaining_kit',begin(f)==true and finish(f).status=='completed')
    f=fixture('saved-clock-restored');begin(f);a=action(f);a:start();__hours=99
    check('rewound_clock_native_ack_retains_saved_claim',R.interrupt(f.id,f.body,'clock-rewound')==false
        and action(f)==nil and f.rec.resourceProductionWork.status=='interrupted' and f.purpose.admission~=nil)
    saved(f);__reloadProduction();__hours=101
    check('restored_clock_recovers_interrupted_saved_work',R.reconcileSaved(f.id,f.body)==true and f.purpose.admission==nil
        and f.rec.resourceProductionWork==nil and f.rec.resourceProductionOutcomes[1].nativeObservability=='runtime-unavailable'
        and __nativeCraft('condition')==2)
    f=fixture('saved-stale');begin(f);quietRecord=__nativeRoundtrip(f.rec);cancel(f)
    __records[f.id]=quietRecord;f.rec=quietRecord;f.agent.rec=quietRecord;f.purpose=quietRecord.proceduralPlanning.purposes[f.purpose.id]
    f.purpose.admission.correlationId='forged-work';__reloadProduction()
    check('stale_saved_admission_refuses',R.reconcileSaved(f.id,f.body)==false and f.rec.resourceProductionWork~=nil)
    f.rec.resourceProductionWork=nil
    f=fixture('saved-missing-agent');begin(f);quietRecord=__nativeRoundtrip(f.rec);cancel(f)
    __records[f.id]=quietRecord;f.rec=quietRecord;f.purpose=quietRecord.proceduralPlanning.purposes[f.purpose.id]
    SAO.Controller.agents[f.id]=nil;__reloadProduction()
    check('saved_missing_agent_retires_without_drive',R.reconcileSaved(f.id,f.body)==true and f.purpose.admission==nil and __nativeCraft('condition')==2)
    f=fixture('saved-transfer-pending');begin(f);saved(f);f.rec.zaoTransferPending=true;f.body.holdCancellation=true;__reloadProduction()
    check('saved_pending_transfer_waits_ack',R.interrupt(f.id,f.body,'transfer')==false and f.rec.resourceProductionWork~=nil)
    f.body.holdCancellation=false;action(f):stop()
    check('saved_pending_transfer_ack_is_quiescent',R.interrupt(f.id,f.body,'transfer')==true and f.rec.resourceProductionWork==nil
        and f.purpose.admission==nil and __nativeCraft('condition')==2)
    f=fixture('saved-foreign-queue');begin(f);quietRecord=__nativeRoundtrip(f.rec);cancel(f)
    __records[f.id]=quietRecord;f.rec=quietRecord;f.agent.rec=quietRecord;f.purpose=quietRecord.proceduralPlanning.purposes[f.purpose.id]
    q=ISTimedActionQueue.getTimedActionQueue(f.body);q.current={character=f.body,Type='Foreign'};q.queue={q.current};__reloadProduction()
    check('saved_pending_foreign_queue_refuses_retirement',R.reconcileSaved(f.id,f.body)==false and f.rec.resourceProductionWork~=nil
        and f.purpose.admission~=nil and q.current.Type=='Foreign')
    q.current=nil;q.queue={};R.reconcileSaved(f.id,f.body)
    f=fixture('saved-malformed');begin(f);quietRecord=__nativeRoundtrip(f.rec);cancel(f)
    __records[f.id]=quietRecord;f.rec=quietRecord;f.agent.rec=quietRecord;quietRecord.resourceProductionWork.toolItemId='wrong';__reloadProduction()
    check('malformed_saved_work_refuses',R.reconcileSaved(f.id,f.body)==false and f.rec.resourceProductionWork~=nil);f.rec.resourceProductionWork=nil
    f=fixture('saved-terminal-retry');begin(f);local consume=P.consumeRepairProductionResult
    P.consumeRepairProductionResult=function() return false end;row=finish(f);saved(f);P.consumeRepairProductionResult=consume;__reloadProduction()
    check('authentic_saved_terminal_delivery_retries',R.reconcileSaved(f.id,f.body)==true and f.purpose.admission==nil
        and R.outcome(f.id,row.id).purposeDelivered==true and #f.rec.cognition.experiences==1)
    __windowResults=table.concat(__checks,'\n')
end
