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
ResourceType={Item='Item'};ItemTag.SAW='Saw'
ActionSoundTime={ACTION_START='ACTION_START'};DebugType.CraftLogic='CraftLogic'
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
    function item:hasTag(tag) return kind=='Saw' and tag==ItemTag.SAW end
    function item:canBeDroppedOnFloor() return true end
    return item
end
local function input(keep,index)
    return {getResourceType=function() return ResourceType.Item end,getIntAmount=function() return 1 end,
        isKeep=function() return keep end,index=index}
end
local logInput,sawInput=input(false,0),input(true,1)
local actionScript={getMetabolics=function() return 'MediumWork' end,hasMuscleStrain=function() return false end,
    isCantSit=function() return false end,getActionAnim=function() return 'SawLog' end,getAnimVarKey=function() return nil end,
    getSound=function() return 'Sawing' end,getSoundTime=function() return ActionSoundTime.ACTION_START end,
    getCompletionSound=function() return nil end}
local recipe={getRequiredSkillCount=function() return 0 end,getInputs=function() return list({logInput,sawInput}) end,
    getIndexForIO=function(_,i) return i.index end,getIOForIndex=function(_,n) return n==0 and logInput or n==1 and sawInput end,
    getName=function() return 'SawLogs' end,getTranslationName=function() return 'Saw logs' end,
    getTime=function() return __nativeCraft('recipeTime') end,getTimedActionScript=function() return actionScript end,
    isCanWalk=function() return false end}
ScriptManager={instance={getCraftRecipe=function(_,name) return name=='Base.SawLogs' and __recipeRegistered~=false and recipe or nil end}}
CraftRecipeManager={hasPlayerLearnedRecipe=function(_,body) return body.recipeKnown~=false and __nativeCraft('recipeLearned') end,
    hasPlayerRequiredSkill=function() return true end,
    getValidInputScriptForItem=function(_,item)
        if item:getFullType()=='Base.Log' then return logInput end
        if item:hasTag(ItemTag.SAW) and item:getCondition()>0 then return sawInput end
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
        if body.nativeRefused or not self.selected or not self.manual[logInput] or not self.manual[sawInput]
            or self.manual[logInput]:get(0)~=body.log or self.manual[sawInput]:get(0)~=body.saw then return false end
        return __nativeCraft('eligible')==true
    end
    function l:getRecipeData()
        local selfLogic=self
        return {getAllInputItems=function() return list({body.log,body.saw}) end,
            getAllCreatedItems=function() return list(selfLogic.outputs) end,
            getAllRecordedConsumedItems=function() return list(__nativeCraft('recordedLog') and {body.log} or {}) end,
            getAllConsumedItems=function() return list(not body.hideNativeConsumed and __nativeCraft('consumedLog') and {body.log} or {}) end,
            luaCallOnCreate=function() body.createCallbacks=(body.createCallbacks or 0)+1 end,
            processDestroyAndUsedItems=function() end}
    end
    function l:getModelHandOne() return 'Saw' end
    function l:getModelHandTwo() return 'Log' end
    function l:performCurrentRecipe()
        body.nativeCalls=(body.nativeCalls or 0)+1
        if not __nativeCraft('perform') then return false end
        body.log.uses=__nativeCraft('logUses');body.saw.condition=__nativeCraft('sawCondition')
        if not __nativeCraft('logHeld') then body.log:getContainer():Remove(body.log) end
        self.outputs={}
        for i=0,__nativeCraft('count')-1 do
            local o=material('Plank',tonumber(__nativeCraft('outputId',i)),nil)
            if o:getFullType()~=__nativeCraft('outputType',i) then error('native type mismatch') end
            self.outputs[#self.outputs+1]=o
        end
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
local function fixture(id,nested)
    __nativeCraft('reset');__permission=true;__recipeRegistered=true;__hours=100
    local f=__boardingFixture(id,false)
    f.body.emitter=f.emitter
    f.inventory.items={};f.rec.bodyOwnerToken=nil;f.body.md.SAOExternalToken=nil
    f.log=material('Log',701,f.inventory);f.saw=material('Saw',702,f.inventory)
    f.inventory.items={f.log,f.saw};f.body.log,f.body.saw=f.log,f.saw
    if nested then
        local bag={items=f.inventory.items};__boardingInventory(bag,f.inventory)
        function bag:contains(i) for _,x in ipairs(self.items) do if i==x then return true end end;return false end
        function bag:Remove(i) for n,x in ipairs(self.items) do if i==x then table.remove(self.items,n);i.container=nil;return end end end
        f.inventory.nested=bag;f.inventory.items={};f.log.container,f.saw.container=bag,bag
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
    local p=SAO.ProceduralPlanning.maintain(id,{key='native-handcraft-test',domain='construction',objective='Board the observed entry'})
    p.materialWork={operation='board',entryKey='barricade:0:0:0:0:true'}
    p.constructionDestination={key=p.materialWork.entryKey,x=0,y=0,z=0}
    p.steps={{id='make-planks',verb='produce',owner='SAO.ResourceProduction',token='resource:crafted',
        target='Base.SawLogs',recipeId='Base.SawLogs',productionKind='saw-logs',category='plank',status='available',
        logItemId='701',logItemType='Base.Log',sawItemId='702',sawItemType='Base.Saw'},
        {id='return-entry',verb='go',owner='Locomotion',token='travel:arrived',target=p.materialWork.entryKey,status='available'}}
    p.cursor=1;f.purpose,f.step=p,p.steps[1]
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
function __runHandcraftCases()
    local R,P,C=SAO.ResourceProduction,SAO.ProceduralPlanning,SAO.Cognition
    C.ensureGameDefaults()
    local f=fixture('native-craft')
    check('installed_recipe_native_eligible',R.craftingAvailable(f.id,f.body)==true and __nativeCraft('recipeInputs')==2)
    check('ordinary_nil_token_admits',begin(f)==true and f.rec.resourceProductionWork.bodyToken==nil)
    local workId=f.rec.resourceProductionWork and f.rec.resourceProductionWork.id
    check('admission_has_no_output_or_lesson',workId~=nil and R.outcome(f.id,workId)==nil
        and f.inventory:contains(f.log) and __nativeCraft('count')==0 and not f.rec.cognition)
    check('generic_result_no_craft_credit',P.recordResult(f.id,f.purpose.id,{owner='SAO.ResourceProduction',
        token='resource:crafted',status='completed',correlationId=workId})==false and f.purpose.admission~=nil)
    check('generic_craft_fact_requires_native_owner',C.experience(f.id,{id='resource-production/'..f.id..'/999',
        actorId=f.id,observerId=f.id,worldHours=__hours,occurredAtHours=__hours,kind='material-crafting',
        category='construction',perspective='performed',status='completed',sourceId='Base.SawLogs',itemId=701,itemType='Base.Plank'})==false
        and not f.rec.cognition)
    check('generic_window_fact_requires_native_owner',C.experience(f.id,{id=f.id..'/window-result/999',
        actorId=f.id,observerId=f.id,worldHours=__hours,occurredAtHours=__hours,kind='window-repair',
        category='construction',perspective='performed',status='completed',sourceId='window:1:2:0:0:true',itemId=701,itemType='RepairableWindows.LargeGlassPane'})==false
        and not f.rec.cognition)
    local a=action(f);a:start();a.action.nativeFinished=true
    check('direct_recipe_callback_refuses',a:performRecipe()==false and f.inventory:contains(f.log) and __nativeCraft('count')==0)
    cancel(f)
    f=fixture('native-effects');begin(f);a=action(f);local purposeId=f.purpose.id;local dest=f.purpose.constructionDestination.key
    local row=finish(f);local canonical=R.outcome(f.id,row and row.id)
    check('native_log_paid_three_planks_held',canonical and canonical.status=='completed' and canonical.nativeCredit==canonical.id
        and canonical.nativeAttempted and canonical.logConsumed and canonical.sawRetained and canonical.held
        and canonical.outputCount==3 and #canonical.outputs==3 and __nativeCraft('createdCount')==3
        and __nativeCraft('logHeld')==false and __nativeCraft('sawHeld')==true and f.body.nativeCalls==1)
    check('same_boarding_purpose_retained',f.purpose.id==purposeId and f.purpose.admission==nil
        and f.purpose.status~='completed' and f.purpose.constructionDestination.key==dest)
    check('private_native_craft_experience_once',f.rec.cognition and #f.rec.cognition.experiences==1
        and f.rec.cognition.experiences[1].actorId==f.id and f.rec.cognition.experiences[1].kind=='material-crafting'
        and f.rec.cognition.experiences[1].perspective=='performed' and canonical.experienceDelivered==true)
    local detached=R.outcome(f.id,row.id);detached.outputs[1].itemType='Base.Log'
    check('outcome_detached_and_forgery_refused',R.outcome(f.id,row.id).outputs[1].itemType=='Base.Plank'
        and C.materialCraftOutcome(f.id,detached)==false)
    check('foreign_fact_refused',C.materialCraftOutcome('foreign',canonical)==false and __records.foreign==nil)
    R.reconcileSaved(f.id,f.body);R.tick(f.id,f.body)
    check('terminal_delivery_not_replayed',#f.rec.cognition.experiences==1 and f.body.nativeCalls==1)
    check('duplicate_native_callback_inert',a:performRecipe()==false and a:complete()==false and __nativeCraft('createdCount')==3)
    saved(f)
    check('native_save_retains_private_fact',#f.rec.cognition.experiences==1 and R.outcome(f.id,row.id).experienceDelivered==true)
    local function outputBoundary(count)
        local boundary=fixture('native-output-boundary-'..count)
        -- Extra carried receivers affect only custody traversal; installed SawLogs still receives the exact log/saw.
        for i=3,count do boundary.inventory.items[#boundary.inventory.items+1]=material('Nails',900000+i,boundary.inventory) end
        local admitted=begin(boundary)
        local result=admitted and finish(boundary)
        return admitted and result and result.status=='completed' and result.nativeCredit==result.id
            and result.logConsumed and result.sawRetained and result.held and result.outputCount==3 and #result.outputs==3
            and #boundary.inventory.items==count+2 and __nativeCraft('createdCount')==3
            and __nativeCraft('logHeld')==false and __nativeCraft('sawHeld')==true and boundary.body.nativeCalls==1
            and boundary.purpose.admission==nil and boundary.purpose.status~='completed'
            and boundary.rec.cognition and #boundary.rec.cognition.experiences==1
    end
    check('native_511_inputs_complete_513_held',outputBoundary(511))
    check('native_512_inputs_complete_514_held',outputBoundary(512))
    f=fixture('nested-inputs',true);check('nested_exact_inputs_admitted',begin(f)==true and action(f).Type=='ISInventoryTransferAction')
    row=finish(f)
    check('installed_transfers_precede_native_craft',row and row.status=='completed' and f.log:getContainer()==nil
        and f.saw:getContainer()==f.inventory and f.inventory.nested:contains(f.saw)==false)
    f=fixture('native-floor-alternative');__nativeCraft('addFloorLog');begin(f);row=finish(f)
    check('native_manual_selection_keeps_floor_alternative',row and row.status=='completed' and __nativeCraft('floorLogHeld')==true
        and __nativeCraft('logHeld')==false and row.logItemId=='701')
    f=fixture('before-materials');f.inventory.items={}
    check('availability_does_not_require_kit',R.craftingAvailable(f.id,f.body)==true and begin(f)==false)
    f=fixture('recipe-refused');f.body.recipeKnown=false
    check('native_knowledge_refusal',R.craftingAvailable(f.id,f.body)==false and begin(f)==false)
    f=fixture('unregistered');__recipeRegistered=false
    check('unregistered_recipe_refuses',R.craftingAvailable(f.id,f.body)==false and begin(f)==false);__recipeRegistered=true
    f=fixture('broken-saw');f.saw.condition=0
    check('broken_saw_refuses',begin(f)==false and __nativeCraft('count')==0)
    f=fixture('manual-refused');f.body.manualRefused=true
    check('native_manual_admission_refuses',begin(f)==false and __nativeCraft('count')==0)
    f=fixture('native-refused');f.body.nativeRefused=true
    check('native_eligibility_refuses',begin(f)==false and __nativeCraft('count')==0)
    f=fixture('forged-finish');begin(f);a=action(f)
    check('complete_without_native_perform_refuses',a:complete()==false and __nativeCraft('count')==0);cancel(f)
    f=fixture('unfinished-perform');begin(f);a=action(f);a:start()
    check('perform_before_native_end_refuses',a:perform()==false and __nativeCraft('count')==0);cancel(f)
    f=fixture('item-replacement');begin(f);a=action(f);a:start()
    f.inventory:Remove(f.log);local replacement=material('Log',701,f.inventory);f.inventory.items[#f.inventory.items+1]=replacement
    a.action.nativeFinished=true
    check('same_id_replacement_and_floor_refuse',a:perform()==false and __nativeCraft('count')==0 and replacement:getCurrentUses()==1);cancel(f)
    f=fixture('changed-token');begin(f);a=action(f);a:start();f.body.md.SAOExternalToken='replacement-token';a.action.nativeFinished=true
    check('changed_body_token_refuses',a:perform()==false and __nativeCraft('count')==0);cancel(f)
    f=fixture('changed-target');begin(f);a=action(f);a:start();f.purpose.materialWork.entryKey='barricade:9:9:0:0:true';a.action.nativeFinished=true
    check('changed_retained_target_refuses',a:perform()==false and __nativeCraft('count')==0);cancel(f)
    f=fixture('changed-work-geometry');begin(f);a=action(f);a:start();f.rec.resourceProductionWork.x=99;a.action.nativeFinished=true
    check('changed_saved_geometry_refuses',a:perform()==false and __nativeCraft('count')==0);f.rec.resourceProductionWork.x=0;cancel(f)
    f=fixture('changed-recipe');begin(f);a=action(f);a:start();a.craftRecipe={};a.action.nativeFinished=true
    check('changed_native_recipe_refuses',a:perform()==false and __nativeCraft('count')==0);cancel(f)
    f=fixture('manual-map-mutated');begin(f);a=action(f);a:start();a.manualInputs[0]=list({f.saw});a.action.nativeFinished=true
    check('changed_manual_input_refuses',a:perform()==false and __nativeCraft('count')==0);cancel(f)
    f=fixture('lost-queue');begin(f);a=action(f);a:start();local q=ISTimedActionQueue.getTimedActionQueue(f.body)
    q.queue={};q.current=nil;f.body.holdCancellation=true
    check('queue_absence_is_not_native_ack',R.interrupt(f.id,f.body,'lost-queue')==false and f.rec.resourceProductionWork~=nil)
    f.body.holdCancellation=false;a:stop();R.retryCraftCancellations()
    check('native_stop_ack_releases_claim',f.rec.resourceProductionWork==nil and f.purpose.admission==nil)
    f=fixture('synchronous-stop-return');begin(f);a=action(f);a:start()
    check('synchronous_native_stop_returns_acknowledged',R.interrupt(f.id,f.body,'sync-stop')==true
        and f.rec.resourceProductionWork==nil and f.purpose.admission==nil and f.inventory:contains(f.log)
        and __nativeCraft('count')==0 and #f.rec.resourceProductionOutcomes==1)
    check('duplicate_stop_acknowledgement_is_inert',R.interrupt(f.id,f.body,'duplicate-stop')==true
        and #f.rec.resourceProductionOutcomes==1 and __nativeCraft('count')==0)
    f=fixture('pending-stop-return');begin(f);a=action(f);a:start();f.body.holdCancellation=true
    check('pending_native_stop_remains_unacknowledged',R.interrupt(f.id,f.body,'pending-stop')==false
        and f.rec.resourceProductionWork~=nil and f.purpose.admission~=nil and action(f)==a
        and f.rec.resourceProductionOutcomes==nil and __nativeCraft('count')==0)
    f.body.holdCancellation=false;a:stop()
    check('pending_native_stop_ack_can_then_release',R.interrupt(f.id,f.body,'after-native-ack')==true
        and f.rec.resourceProductionWork==nil and f.purpose.admission==nil)
    f=fixture('synchronous-stop-successor');begin(f);a=action(f);a:start();q=ISTimedActionQueue.getTimedActionQueue(f.body)
    local nextAction={character=f.body,Type='UnrelatedSuccessor',isValidStart=function() return true end,
        begin=function(self) self.begun=true;f.body.farming=true;f.log.jobDelta=.7;f.saw.jobDelta=.8;
            f.body.emitter.playing.SuccessorLoop=true end}
    q.queue[#q.queue+1]=nextAction
    check('synchronous_stop_preserves_started_successor',R.interrupt(f.id,f.body,'sync-successor')==true
        and q.current==nextAction and q.queue[1]==nextAction and nextAction.begun==true and f.body.farming==true
        and f.log.jobDelta==.7 and f.saw.jobDelta==.8 and f.body.emitter.playing.SuccessorLoop==true
        and f.rec.resourceProductionWork==nil and f.purpose.admission==nil)
    q.current=nil;q.queue={}
    f=fixture('actor-death');begin(f);a=action(f);a:start();f.rec.dead=true;f.body.dead=true;f.body.holdCancellation=true
    check('actor_death_retains_pending_native_ownership',R.tick(f.id,f.body)=='cancelling' and f.rec.resourceProductionWork~=nil
        and f.purpose.admission~=nil and __nativeCraft('count')==0)
    f.body.holdCancellation=false;a:stop();R.retryCraftCancellations()
    check('actor_death_native_ack_retires_without_effect',f.rec.resourceProductionWork==nil and f.purpose.admission==nil
        and f.inventory:contains(f.log) and not f.rec.cognition)
    f=fixture('actor-retirement');begin(f);a=action(f);a:start();SAO.Body.active[f.id]=nil;f.body.holdCancellation=true
    check('body_retirement_waits_native_ack',R.detach(f.id)==false and f.rec.resourceProductionWork~=nil and f.purpose.admission~=nil)
    f.body.holdCancellation=false;a:stop()
    check('body_retirement_ack_no_output_credit',R.detach(f.id)==true and f.rec.resourceProductionWork==nil
        and f.purpose.admission==nil and __nativeCraft('count')==0 and f.inventory:contains(f.log))
    f=fixture('transfer-stop',true);begin(f);a=action(f);a:start();a.loopSound='RummageInInventory';a.loopSoundNoTrigger=true
    f.body.emitter.playing[a.loopSound]=true;a.item.jobDelta=.5;a.action.looped=true
    R.interrupt(f.id,f.body,'prepare-interrupted')
    check('native_transfer_cleanup_before_ack',a.item.jobDelta==0 and a.action.looped==false and a.loopSound==nil
        and f.body.emitter.stopped.RummageInInventory==1 and f.rec.resourceProductionWork==nil)
    f=fixture('craft-stop');begin(f);a=action(f);a:start();a:update()
    R.interrupt(f.id,f.body,'craft-interrupted')
    check('native_craft_stop_cosmetic_cleanup',f.log.jobDelta==0 and f.saw.jobDelta==0 and f.body.emitter.triggered.Sawing==1
        and f.purpose.admission==nil and __nativeCraft('count')==0)
    f=fixture('replacement-owner');begin(f);a=action(f);a:start();q=ISTimedActionQueue.getTimedActionQueue(f.body)
    local successor={character=f.body,isValidStart=function() return true end,begin=function() end,Type='Successor'}
    q.queue={successor};q.current=successor;f.log.jobDelta=.7;f.saw.jobDelta=.8;f.body.farming=true
    R.interrupt(f.id,f.body,'replacement')
    check('replacement_queue_cosmetics_preserved',q.current==successor and q.queue[1]==successor and f.body.farming==true
        and f.log.jobDelta==.7 and f.saw.jobDelta==.8 and f.body.emitter.playing.Sawing==true)
    q.queue={};q.current=nil
    f=fixture('dropped-output');begin(f);f.body.dropOutputs=true;row=finish(f)
    check('created_but_unheld_output_no_credit',row and row.status~='completed' and row.nativeCredit==nil
        and row.held==false and __nativeCraft('createdCount')==3 and f.purpose.admission==nil and not f.rec.cognition)
    f=fixture('native-payment-query-refused');begin(f);f.body.hideNativeConsumed=true;row=finish(f)
    check('missing_exact_native_consumption_no_credit',row and row.status~='completed' and row.nativeCredit==nil
        and __nativeCraft('createdCount')==3 and f.purpose.admission==nil and not f.rec.cognition)
    f=fixture('saved-native-owner');begin(f);saved(f);f.body.holdCancellation=true;__reloadProduction()
    check('saved_native_queue_waits_original_ack',R.reconcileSaved(f.id,f.body)==false and f.rec.resourceProductionWork~=nil)
    f.body.holdCancellation=false;action(f):stop()
    check('saved_native_ack_then_recovery',R.reconcileSaved(f.id,f.body)==true and f.purpose.admission==nil and __nativeCraft('count')==0)
    f=fixture('saved-quiet');begin(f);a=action(f);local quietRecord=__nativeRoundtrip(f.rec);cancel(f)
    __records[f.id]=quietRecord;f.rec=quietRecord;f.agent.rec=quietRecord;f.purpose=quietRecord.proceduralPlanning.purposes[f.purpose.id]
    __reloadProduction();local samePurpose=f.purpose.id
    check('saved_nil_token_work_recovers_without_effect',R.reconcileSaved(f.id,f.body)==true and f.purpose.admission==nil
        and f.purpose.id==samePurpose and f.rec.resourceProductionOutcomes[1].nativeObservability=='runtime-unavailable'
        and f.rec.resourceProductionOutcomes[1].nativeAttempted==false and f.inventory:contains(f.log))
    f.step=f.purpose.steps[f.purpose.cursor];f.step.status='available'
    check('saved_purpose_can_resume_actual_remaining_kit',begin(f)==true and finish(f).status=='completed')
    f=fixture('saved-clock-restored');begin(f);a=action(f);a:start();__hours=99
    check('rewound_clock_native_ack_retains_saved_claim',R.interrupt(f.id,f.body,'clock-rewound')==false
        and action(f)==nil and f.rec.resourceProductionWork.status=='interrupted' and f.purpose.admission~=nil)
    saved(f);__reloadProduction();__hours=101
    check('restored_clock_recovers_interrupted_saved_work',R.reconcileSaved(f.id,f.body)==true and f.purpose.admission==nil
        and f.rec.resourceProductionWork==nil and f.rec.resourceProductionOutcomes[1].nativeObservability=='runtime-unavailable'
        and f.inventory:contains(f.log) and __nativeCraft('count')==0)
    f=fixture('saved-stale');begin(f);quietRecord=__nativeRoundtrip(f.rec);cancel(f)
    __records[f.id]=quietRecord;f.rec=quietRecord;f.agent.rec=quietRecord;f.purpose=quietRecord.proceduralPlanning.purposes[f.purpose.id]
    f.purpose.admission.correlationId='forged-work';__reloadProduction()
    check('stale_saved_admission_refuses',R.reconcileSaved(f.id,f.body)==false and f.rec.resourceProductionWork~=nil)
    f.rec.resourceProductionWork=nil
    f=fixture('saved-missing-agent');begin(f);quietRecord=__nativeRoundtrip(f.rec);cancel(f)
    __records[f.id]=quietRecord;f.rec=quietRecord;f.purpose=quietRecord.proceduralPlanning.purposes[f.purpose.id]
    SAO.Controller.agents[f.id]=nil;__reloadProduction()
    check('saved_missing_agent_retires_without_drive',R.reconcileSaved(f.id,f.body)==true and f.purpose.admission==nil and f.inventory:contains(f.log))
    f=fixture('saved-transfer-pending');begin(f);saved(f);f.rec.zaoTransferPending=true;f.body.holdCancellation=true;__reloadProduction()
    check('saved_pending_transfer_waits_ack',R.interrupt(f.id,f.body,'transfer')==false and f.rec.resourceProductionWork~=nil)
    f.body.holdCancellation=false;action(f):stop()
    check('saved_pending_transfer_ack_is_quiescent',R.interrupt(f.id,f.body,'transfer')==true and f.rec.resourceProductionWork==nil
        and f.purpose.admission==nil and f.inventory:contains(f.log))
    f=fixture('saved-foreign-queue');begin(f);quietRecord=__nativeRoundtrip(f.rec);cancel(f)
    __records[f.id]=quietRecord;f.rec=quietRecord;f.agent.rec=quietRecord;f.purpose=quietRecord.proceduralPlanning.purposes[f.purpose.id]
    q=ISTimedActionQueue.getTimedActionQueue(f.body);q.current={character=f.body,Type='Foreign'};q.queue={q.current};__reloadProduction()
    check('saved_pending_foreign_queue_refuses_retirement',R.reconcileSaved(f.id,f.body)==false and f.rec.resourceProductionWork~=nil
        and f.purpose.admission~=nil and q.current.Type=='Foreign')
    q.current=nil;q.queue={};R.reconcileSaved(f.id,f.body)
    f=fixture('saved-malformed');begin(f);quietRecord=__nativeRoundtrip(f.rec);cancel(f)
    __records[f.id]=quietRecord;f.rec=quietRecord;f.agent.rec=quietRecord;quietRecord.resourceProductionWork.logItemId='wrong';__reloadProduction()
    check('malformed_saved_work_refuses',R.reconcileSaved(f.id,f.body)==false and f.rec.resourceProductionWork~=nil);f.rec.resourceProductionWork=nil
    f=fixture('saved-terminal-retry');begin(f);local consume=P.consumeCraftProductionResult
    P.consumeCraftProductionResult=function() return false end;row=finish(f);saved(f);P.consumeCraftProductionResult=consume;__reloadProduction()
    check('authentic_saved_terminal_delivery_retries',R.reconcileSaved(f.id,f.body)==true and f.purpose.admission==nil
        and R.outcome(f.id,row.id).purposeDelivered==true and #f.rec.cognition.experiences==1)
    __windowResults=table.concat(__checks,'\n')
end
