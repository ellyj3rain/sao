-- Installed fixing/equip/transfer/queue procedures with controlled actor/map ports.
-- Definitions/factories, FixingManager effects and scalar saves run in installed Java.
local originalPcall=pcall
function pcall(fn,...) local values={originalPcall(fn,...)};if values[1]==false then print("receiver error "..tostring(values[2])) end;return unpack(values) end
local function list(values)
    local a={values=values or {}}
    function a:size() return #self.values end
    function a:get(i) return self.values[i+1] end
    function a:add(v) self.values[#self.values+1]=v end
    function a:contains(v) for _,x in ipairs(self.values) do if x==v then return true end end;return false end
    function a:set(i,v) local old=self.values[i+1];self.values[i+1]=v;return old end
    return a
end
ArrayList={new=function() return list() end}
Metabolics.UsingTools='UsingTools'
SAO.Pharmacology={};SAO.Cooking={};SAO.Controller={agents={}}
ModData={data={},getOrCreate=function(k) ModData.data[k]=ModData.data[k] or {};return ModData.data[k] end,
    get=function(k) return ModData.data[k] end}
function removeItemTransaction() end
function convertToPZNetTable(v) return v end
ISInventoryPage.dirtyUI=function() end
Perks.FromString=function(s) return s end
local defs={}
for _,raw in ipairs(__nativeFix('definitions')) do
    local d={raw=raw,fixers={}}
    function d:getName() return self.raw.name end
    function d:getModule() return {getName=function() return self.raw.module end} end
    function d:getGlobalItem() return nil end
    function d:getFixers() return list(self.fixers) end
    for _,row in ipairs(raw.fixers) do
        local x={raw=row}
        function x:getFixerName() return self.raw.name end
        function x:getNumberOfUse() return self.raw.uses end
        function x:getFixerSkills()
            local out={}
            for _,sk in ipairs(self.raw.skills) do out[#out+1]={getSkillName=function() return sk.name end,getSkillLevel=function() return sk.level end} end
            return list(out)
        end
        d.fixers[#d.fixers+1]=x
    end
    function d:getRequiredItems(body,fixer,target)
        local items=SAOJavaBridge:privateCarriedItems(body)
        for i=0,items:size()-1 do local item=items:get(i)
            if item~=target and item:getFullType()==fixer:getFixerName() then return list({item}) end
        end
    end
    defs[#defs+1]=d
end
ScriptManager={instance={getAllFixing=function(_,out) for _,d in ipairs(defs) do out:add(d) end;return out end}}
FixingManager={}
function FixingManager.getFixes(target)
    local out={}
    for _,d in ipairs(defs) do for _,type in ipairs(d.raw.required) do if type==target:getFullType() then out[#out+1]=d;break end end end
    return list(out)
end
local oldItem=__boardingItem
local material
material=function(raw,inventory)
    local item=oldItem(raw.fullType:match('%.(.+)$'),raw.id,inventory)
    item.fullType=raw.fullType;item.condition=raw.condition;item.maximum=raw.maximum
    item.repairCount=raw.repairCount;item.ammo=raw.ammo;item.ranged=raw.ranged
    item.swingAnim=raw.swingAnim;item.twoHands=raw.twoHands;item.requiresBoth=raw.requiresBoth;item.magazine=raw.magazine
    item.clip=raw.clip;item.chamber=raw.chamber;item.ammoType=raw.ammoType;item.parts={}
    for _,p in ipairs(raw.parts or {}) do item.parts[#item.parts+1]=material(p,nil) end
    function item:getConditionMax() return self.maximum end
    function item:getHaveBeenRepaired() return self.repairCount end
    function item:isRanged() return self.ranged==true end
    function item:getSwingAnim() return self.swingAnim end
    function item:isTwoHandWeapon() return self.twoHands==true end
    function item:isRequiresEquippedBothHands() return self.requiresBoth==true end
    function item:getCurrentAmmoCount() return self.ammo or 0 end
    function item:getAllWeaponParts() return list(self.parts) end
    function item:getMagazineType() return self.magazine end
    function item:isContainsClip() return self.clip==true end
    function item:haveChamber() return self.ranged==true end
    function item:isRoundChambered() return self.chamber==true end
    function item:getAmmoType() return self.ammoType and {getItemKey=function() return self.ammoType end} end
    function item:hasSharpness() return false end
    function item:hasHeadCondition() return false end
    function item:isActivated() return false end
    function item:getScriptItem() return {isItemType=function() return false end} end
    function item:canBeDroppedOnFloor() return true end
    function item:getFluidContainerFromSelfOrWorldItem() return nil end
    return item
end
local nativeInstance=instanceof
function instanceof(o,kind) return kind=='HandWeapon' and type(o)=='table' and o.ranged~=nil or nativeInstance(o,kind) end
SAOJavaBridge.privateCarriedItems=function(_,body)
    local values={}
    for _,i in ipairs(body:getInventory().items) do values[#values+1]=i end
    if body:getInventory().nested then for _,i in ipairs(body:getInventory().nested.items) do values[#values+1]=i end end
    return list(values)
end
local originalTimed=LuaTimedActionNew.new
LuaTimedActionNew.new=function(action,body)
    local native=originalTimed(action,body)
    function native:forceComplete() self.nativeForceComplete=true end
    function native:isForceComplete() return self.nativeForceComplete==true end
    function native:stopTimedActionAnim() end
    function native:setOverrideHandModels() end
    function native:overrideHandModels() end
    function native:setOverrideHandModelsObject() end
    function native:setAnimVariable() end
    return native
end
SAO.Needs.read=function() return {hunger=.1,thirst=.1,fatigue=.1} end
SAO.Labor={capabilityOf=function() return {} end}
SAO.Needs.workAvailable=function() return true end
SAO.Needs.busy=function() return false end
SAO.Locomotion={jobs={}}
SAO.Standing.mayTakeCurrent=function() return __permission==true end
local function fixture(id,nested,kind,donorType,contents)
    kind=kind or 'Pistol'
    __nativeFix('reset',kind);__hours=100;__permission=true
    if donorType then __nativeFix('donorType',donorType) end
    if contents then __nativeFix('contents') end
    local f=__boardingFixture(id,false)
    f.rec.bodyOwnerToken=nil;f.body.md.SAOExternalToken=nil
    f.target=material(__nativeFix('target'),f.inventory);f.tool=material(__nativeFix('donor'),f.inventory)
    f.inventory.items={f.target,f.tool};f.body.target,f.body.tool=f.target,f.tool
    local oldContains=f.inventory.contains
    function f.inventory:contains(value)
        if type(value)=='string' then return self:getFirstType(value)~=nil end
        return oldContains(self,value)
    end
    if nested then
        local bag={items=f.inventory.items};__boardingInventory(bag,f.inventory)
        function bag:contains(item) for _,i in ipairs(self.items) do if i==item then return true end end;return false end
        function bag:Remove(item) for n,i in ipairs(self.items) do if i==item then table.remove(self.items,n);item.container=nil;return end end end
        f.inventory.nested=bag;f.inventory.items={}
        for _,item in ipairs(bag.items) do item.container=bag end
    end
    function f.body:getVehicle() return nil end
    function f.body:isAttacking() return false end
    function f.body:isAiming() return false end
    function f.body:isClimbing() return false end
    function f.body:isClimbingRope() return false end
    function f.body:isTimedActionInstant() return false end
    function f.body:getPerkLevel() return self.skill or 5 end
    function f.body:getBodyDamage() return {getOverallBodyHealth=function() return 100 end,getBodyPart=function() return {getPain=function() return 0 end} end} end
    function f.body:isSitOnGround() return false end
    local square=f.body:getCurrentSquare()
    function square:TreatAsSolidFloor() return true end
    function square:isSolid() return false end
    function square:isSolidTrans() return false end
    f.agent.state='IDLE';SAO.Controller.agents[id]=f.agent
    local options=SAO.ResourceProduction.maintenanceOptions(id,f.body)
    f.option=options[1];assert(f.option,'registered fixing offer missing '..kind)
    local p=SAO.ProceduralPlanning.maintain(id,{key='maintain-tool:701:Base.'..kind,domain='construction',objective='Maintain carried firearm'})
    p.materialWork={operation='maintain-tool',entryKey='held-item:701',targetItemId='701',targetItemType=f.target:getFullType()}
    p.steps={{id='fix:701:2',verb='produce',owner='SAO.ResourceProduction',token='resource:repaired',status='available',
        productionKind='fix-held-item',recipeId=f.option.recipeId,target=f.option.recipeId,category='weapon',toolCategory='weapons',effectMetric='condition',
        targetItemId='701',targetItemType=f.target:getFullType(),toolItemId='702',toolItemType=f.tool:getFullType()}}
    p.cursor=1;f.purpose,f.step=p,p.steps[1]
    return f
end
__fixingFixture=fixture
function FixingManager.fixItem(target,body,definition,fixer)
    assert(target==body.target and body.tool:getFullType()==fixer:getFixerName())
    assert(__nativeFix('select',SAO.ResourceProduction.repairPolicy('fixing:Base.'..definition:getName()..':'..(function() for i,x in ipairs(definition.fixers) do if x==fixer then return i-1 end end end)()).recipeId))
    assert(__nativeFix('required'),'native exact required donor differs')
    __nativeFix('perform',body.failNative==true)
    local targetData=__nativeFix('target')
    target.condition,target.repairCount=targetData.condition,targetData.repairCount
    local original=body.tool;original:getContainer():Remove(original)
    local existing={}
    for _,item in ipairs(body:getInventory().items) do existing[tostring(item:getID())]=item end
    local parts={}
    for _,part in ipairs(original.parts) do parts[tostring(part:getID())]=part end
    for _,raw in ipairs(__nativeFix('inventory')) do
        if not existing[tostring(raw.id)] then
            local returned=parts[tostring(raw.id)] or material(raw,body:getInventory())
            returned.container=body:getInventory();body:getInventory().items[#body:getInventory().items+1]=returned
        end
    end
    return target
end
local function begin(f)
    f.body.fixRecipe=f.step.recipeId
    return SAO.ResourceProduction.begin(f.id,f.body,f.step,{purposeId=f.purpose.id,purposeStepId=f.step.id})
end
local function finish(f)
    local q=ISTimedActionQueue.getTimedActionQueue(f.body);local count=0
    while q.current do
        count=count+1;assert(count<=6,'native fixing preparation loop')
        local a=q.current
        if a.Type=='ISInventoryTransferAction' then a.getNotFullFloorSquare=function() return nil end;a.playTransferCompleteSound=function() end end
        a:start();a.action.nativeFinished=true;a:perform();a:complete()
        if q.current==a then error('native action retained '..tostring(a.Type)) end
    end
    local rows=f.rec.resourceProductionOutcomes or {};return rows[#rows]
end
local function check(name,condition) print(name..'='..tostring(condition==true)) end
local function cancel(f) f.body.holdCancellation=false;return SAO.ResourceProduction.interrupt(f.id,f.body,'case-retired') end
function __runItemFixingCases()
    local R,P,C,M=SAO.ResourceProduction,SAO.ProceduralPlanning,SAO.Cognition,SAO.CognitiveModels
    C.ensureGameDefaults()
    local f,row,a,q
    local complete=true
    for _,def in ipairs(defs) do for index,fixer in ipairs(def.fixers) do
        local targetType=def.raw.required[1]:match('%.(.+)$')
        local donorType=fixer:getFixerName():match('%.(.+)$')
        f=fixture('registered-'..def:getName()..'-'..index,false,targetType,donorType)
        f.step.recipeId='fixing:Base.'..def:getName()..':'..(index-1);f.step.target=f.step.recipeId
        local admitted=begin(f);complete=admitted==true and complete
        row=finish(f);if not row or row.status~='completed' then print('definition result '..def:getName()..'/'..index..' admit='..tostring(admitted)..' status='..tostring(row and row.status)..' detail='..tostring(row and row.detail)) end;complete=complete and row and row.status=='completed' and row.paymentConsumed and row.reequipped
            and row.targetItemId=='701' and not __nativeFix('donorHeld') and f.body:getPrimaryHandItem()==f.target
    end end
    check('all_registered_firearm_fixers_execute',complete)
    f=fixture('contents',true,nil,nil,true);check('nested_target_and_donor_admitted',begin(f)==true)
    row=finish(f)
    check('native_payment_returns_parts_magazine_and_chamber_ammo',row and row.status=='completed' and #row.returnedItems==3
        and row.paymentConsumed and row.returnsMeasured and not __nativeFix('donorHeld') and __nativeFix('callbacks')==1)
    check('exact_target_native_equipment_reused',row and row.reequipped and f.body:getPrimaryHandItem()==f.target and row.targetItemType=='Base.Pistol')
    check('native_condition_repair_count_measured',row and row.afterCondition>row.beforeCondition and row.afterRepairCount==row.beforeRepairCount+1)
    check('private_both_models_once_only',f.rec.cognition and #f.rec.cognition.experiences==1
        and f.rec.cognition.models.ordinary~=nil and f.rec.cognition.models.associative~=nil)
    local count=f.rec.cognition and #f.rec.cognition.experiences
    R.reconcileSaved(f.id,f.body);R.reconcileSaved(f.id,f.body)
    check('result_learning_replay_once_only',f.rec.cognition and #f.rec.cognition.experiences==count)
    local completed=a
    f=fixture('failure');f.body.failNative=true;f.body.skill=3;__nativeFix('skill',3);__nativeFix('repairCount',5);f.target.repairCount=5;begin(f);row=finish(f)
    print('failure row '..tostring(row and row.status)..' condition='..tostring(row and row.afterCondition)..' detail='..tostring(row and row.detail)..' native='..tostring(row and row.nativeCompleted));check('native_failure_damage_still_pays',row and row.status=='failed' and row.nativeCompleted and row.paymentConsumed
        and row.afterCondition==row.beforeCondition-1 and row.nativeCredit==nil and not __nativeFix('donorHeld'))
    check('failed_target_native_reuse_without_success_credit',row and row.reequipped and f.body:getPrimaryHandItem()==f.target and not row.improved)
    local damage={id='damage',evidence=1,continuity=1,novelty=0,informationGain=0,blockers=0,
        consequences={{kind='tool-repair',category='construction',sourceId=f.step.recipeId,itemType='Base.Pistol',condition='damage',value=-.25}}}
    local learned=true
    for _,kind in ipairs({'ordinary','associative'}) do
        local model=f.rec.cognition and f.rec.cognition.models[kind]
        local prediction=model and M.planPrediction(kind,damage,model,{actorId=f.id,atHours=100,pressure=.5})
        learned=learned and prediction~=nil and prediction.predictions[1].probability>.5
    end
    check('native_damage_changes_both_private_predictions',learned)
    local beneficial={id='benefit',evidence=1,continuity=1,novelty=0,informationGain=0,blockers=0,
        consequences={{kind='tool-repair',category='construction',sourceId=f.step.recipeId,itemType='Base.Pistol',value=1}}}
    local disputed=true
    for _,kind in ipairs({'ordinary','associative'}) do
        local own=f.rec.cognition and f.rec.cognition.models[kind]
        local prediction=own and M.planPrediction(kind,beneficial,own,{actorId=f.id,atHours=100,pressure=.5})
        disputed=disputed and prediction and prediction.predictions[1].probability<.5
    end
    check('native_failure_changes_both_benefit_predictions',disputed==true)
    local private=f.rec.cognition and f.rec.cognition.experiences[1]
    check('fixing_has_no_attack_food_or_physiological_credit',private and private.kind=='tool-repair' and private.category=='construction'
        and private.hungerDelta==nil and private.thirstDelta==nil and private.actionKind==nil)
    f=fixture('skill');f.body.skill=0;__nativeFix('skill',0)
    check('native_skill_gate_refuses',begin(f)==false)
    f=fixture('broken');f.target.condition=0
    check('native_broken_target_refuses',begin(f)==false)
    f=fixture('whole');f.target.condition=f.target:getConditionMax()
    check('native_full_condition_refuses',begin(f)==false)
    f=fixture('permission');__permission=false
    check('current_standing_refuses',begin(f)==false);__permission=true
    f=fixture('no-donor');f.inventory.items={f.target}
    check('missing_donor_keeps_unfinished_purpose',begin(f)==false and f.purpose.status~='completed')
    f=fixture('raw-shadow');local shadow=material(__nativeFix('donor'),nil);shadow.id=999
    f.inventory.items={f.target,shadow,f.tool}
    check('native_raw_payment_prepared_without_deleting_shadow',begin(f)==true and f.inventory.items[2]==f.tool and f.inventory.items[3]==shadow)
    cancel(f)
    for _,phase in ipairs({'perform','complete'}) do
        f=fixture('shadow-'..phase);begin(f);a=ISTimedActionQueue.getTimedActionQueue(f.body).current;a:start();a.action.nativeFinished=true
        if phase=='complete' then a:perform() end
        local foreign=material(__nativeFix('donor'),nil);foreign.id=998;foreign.consumed=true
        table.insert(f.inventory.items,1,foreign)
        local accepted=phase=='perform' and a:perform() or a:complete()
        check('raw_stale_shadow_'..phase..'_refuses',accepted==false and __nativeFix('callbacks')==0 and __nativeFix('donorHeld'))
        cancel(f)
    end
    f=fixture('early');begin(f);a=ISTimedActionQueue.getTimedActionQueue(f.body).current;a:start()
    check('native_early_perform_refuses',a:perform()==false and __nativeFix('callbacks')==0);cancel(f)
    f=fixture('direct');begin(f);a=ISTimedActionQueue.getTimedActionQueue(f.body).current
    check('native_direct_complete_refuses',a:complete()==false and __nativeFix('callbacks')==0);cancel(f)
    f=fixture('anchor');begin(f);a=ISTimedActionQueue.getTimedActionQueue(f.body).current;a:start();f.step.toolItemId='other';a.action.nativeFinished=true
    check('changed_pending_identity_refuses',a:perform()==false and __nativeFix('callbacks')==0);cancel(f)
    f=fixture('stop');begin(f);a=ISTimedActionQueue.getTimedActionQueue(f.body).current;a:start();f.body.holdCancellation=true
    check('pending_native_ack_keeps_claim',R.interrupt(f.id,f.body,'pending')==false and f.rec.resourceProductionWork~=nil)
    check('native_ack_retires_claim_without_payment',cancel(f)==true and f.rec.resourceProductionWork==nil and __nativeFix('callbacks')==0)
    f=fixture('successor');begin(f);a=ISTimedActionQueue.getTimedActionQueue(f.body).current;a:start()
    q=ISTimedActionQueue.getTimedActionQueue(f.body)
    local successor={Type='Successor',character=f.body,isValidStart=function() return true end,begin=function() end}
    q.queue={successor};q.current=successor;f.target.jobDelta=.7
    R.interrupt(f.id,f.body,'replaced')
    check('replacement_queue_and_cosmetics_preserved',q.current==successor and q.queue[1]==successor and f.target.jobDelta==.7 and __nativeFix('callbacks')==0)
    q.current=nil;q.queue={}
    f=fixture('saved');begin(f);local saved=__nativeRoundtrip(f.rec);cancel(f)
    __records[f.id]=saved;f.rec=saved;f.agent.rec=saved;f.purpose=saved.proceduralPlanning.purposes[f.purpose.id]
    __reloadProduction()
    check('saved_native_admission_recovers_without_payment',R.reconcileSaved(f.id,f.body)==true and saved.resourceProductionWork==nil
        and f.purpose.admission==nil and f.purpose.status~='completed' and __nativeFix('callbacks')==0)
    -- A replacement whole queue never grants cleanup ownership over its successor.
    f=fixture('whole-queue');begin(f);a=ISTimedActionQueue.getTimedActionQueue(f.body).current;a:start()
    local old=ISTimedActionQueue.getTimedActionQueue(f.body)
    local nextAction={Type='Successor',character=f.body,isValidStart=function() return true end,begin=function() end}
    local replacement={queue={nextAction},current=nextAction,indexOf=function(_,item) return item==nextAction and 1 or -1 end}
    ISTimedActionQueue.queues[f.body]=replacement;f.target.jobDelta=.7;f.body.farming=true
    R.interrupt(f.id,f.body,'whole-queue-replaced')
    check('whole_replacement_queue_preserves_successor_and_cosmetics',replacement.current==nextAction
        and replacement.queue[1]==nextAction and f.target.jobDelta==.7 and f.body.farming==true and __nativeFix('callbacks')==0)
    replacement.current=nil;replacement.queue={}
    f=fixture('duplicate');begin(f);a=ISTimedActionQueue.getTimedActionQueue(f.body).current;row=finish(f)
    local callbacks=__nativeFix('callbacks')
    check('completed_native_callback_cannot_replay',a:complete()==false and __nativeFix('callbacks')==callbacks and callbacks==1)
    local terminal=__nativeRoundtrip(f.rec);__records[f.id]=terminal;f.rec=terminal;f.agent.rec=terminal;__reloadProduction();R.reconcileSaved(f.id,f.body)
    check('native_saved_terminal_result_and_learning_replay_once',f.rec.cognition and #f.rec.cognition.experiences==1
        and #f.rec.resourceProductionOutcomes==1 and f.rec.resourceProductionWork==nil)
    f=fixture('stale-equip');begin(f);a=ISTimedActionQueue.getTimedActionQueue(f.body).current;a:start();a.action.nativeFinished=true;a:perform();a:complete()
    local equip=ISTimedActionQueue.getTimedActionQueue(f.body).current
    f.target.condition=f.target.condition-1;equip.action.nativeFinished=true
    check('changed_native_target_before_reuse_refuses',equip:perform()==false and f.body:getPrimaryHandItem()~=f.target)
    cancel(f)
    f=fixture('loaded-target');__nativeFix('targetLoaded');f.target.ammo=3;f.target.clip=true;f.target.chamber=true;begin(f);row=finish(f)
    check('repair_preserves_target_loaded_ammunition',row and row.status=='completed' and row.reequipped and f.target.ammo==3
        and __nativeFix('target').ammo==3 and __nativeFix('target').clip and __nativeFix('target').chamber)
    for _,change in ipairs({'death','body','token','transfer'}) do
        f=fixture('owner-'..change);begin(f);a=ISTimedActionQueue.getTimedActionQueue(f.body).current;a:start();a.action.nativeFinished=true
        if change=='death' then f.rec.dead=true elseif change=='body' then SAO.Body.active[f.id]={}
        elseif change=='token' then f.body.md.SAOExternalToken='foreign-token' else f.rec.zaoTransferPending={} end
        check('native_'..change..'_owner_change_refuses',a:perform()==false and __nativeFix('callbacks')==0)
        cancel(f)
    end
    f=fixture('saved-forged');begin(f);local bad=__nativeRoundtrip(f.rec);cancel(f)
    __records[f.id]=bad;f.rec=bad;f.agent.rec=bad
    bad.proceduralPlanning.purposes[f.purpose.id].admission.correlationId='foreign'
    __reloadProduction()
    check('saved_wrong_admission_keeps_unfinished_claim',R.reconcileSaved(f.id,f.body)==false and bad.resourceProductionWork~=nil)
    f=fixture('live-saved-ack');begin(f);a=ISTimedActionQueue.getTimedActionQueue(f.body).current;a:start()
    local live=__nativeRoundtrip(f.rec);__records[f.id]=live;f.rec=live;f.agent.rec=live;f.body.holdCancellation=true
    __reloadProduction()
    check('saved_live_native_ack_blocks_replacement',R.reconcileSaved(f.id,f.body)==false and live.resourceProductionWork~=nil
        and ISTimedActionQueue.getTimedActionQueue(f.body).current==a and __nativeFix('callbacks')==0)
    f.body.holdCancellation=false
    check('saved_live_native_ack_retires_exact_old_capsule',R.reconcileSaved(f.id,f.body)==true and live.resourceProductionWork==nil
        and live.proceduralPlanning.purposes[f.purpose.id].admission==nil and __nativeFix('callbacks')==0)
    f=fixture('generic-plan');begin(f)
    local generic={owner='SAO.ResourceProduction',token='resource:repaired',status='completed',correlationId=f.rec.resourceProductionWork.id,atHours=100}
    check('generic_pending_result_has_no_fixing_completion',P.recordResult(f.id,f.purpose.id,generic)==false and f.purpose.admission~=nil)
    cancel(f)
    f=fixture('foreign-field');begin(f);row=finish(f);row.foreignCredit=true
    check('foreign_canonical_field_refuses',R.outcome(f.id,row.id)==nil)
    f=fixture('generic')
    check('generic_private_fixing_fact_denied' ,C.experience(f.id,{id='resource-production/'..f.id..'/1',kind='tool-repair',category='construction',
        actorId=f.id,observerId=f.id,perspective='performed',status='completed',worldHours=100,occurredAtHours=100,sourceId=f.step.recipeId,itemId=701,itemType='Base.Pistol',beforeValue=2,afterValue=10})==false)
    f=fixture('forged');begin(f);row=finish(f);row.reequipped=false
    check('forged_equipment_completion_denied',R.outcome(f.id,row.id)==nil)
    __runFixingControllerCases(fixture,finish,check)
    __runPrivateFixingSourceCases(fixture,check)
end

function __runItemFixingControl(name)
    local R,P,C=SAO.ResourceProduction,SAO.ProceduralPlanning,SAO.Cognition
    C.ensureGameDefaults()
    local f=fixture('control-'..name)
    local a,row
    if name=='native-end' then
        begin(f);a=ISTimedActionQueue.getTimedActionQueue(f.body).current;a:start()
        check('native_early_perform_refuses',a:perform()==false and __nativeFix('callbacks')==0)
    elseif name=='raw-payment' then
        begin(f);a=ISTimedActionQueue.getTimedActionQueue(f.body).current;a:start();a.action.nativeFinished=true;a:perform()
        local foreign=material(__nativeFix('donor'),nil);foreign.id=998;foreign.consumed=true;table.insert(f.inventory.items,1,foreign)
        check('raw_stale_shadow_complete_refuses',a:complete()==false and __nativeFix('callbacks')==0)
    elseif name=='native-skill' then
        f.body.skill=0;__nativeFix('skill',0)
        check('native_skill_gate_refuses',begin(f)==false)
    elseif name=='equipment-credit' then
        begin(f);row=finish(f);row.reequipped=false
        check('forged_equipment_completion_denied',R.outcome(f.id,row.id)==nil)
    elseif name=='condition-bound' then
        begin(f);row=finish(f);row.afterCondition=999;row.fullRestoration=true
        check('forged_condition_bound_denied',R.outcome(f.id,row.id)==nil)
    elseif name=='generic-fact' then
        check('generic_private_fixing_fact_denied',C.experience(f.id,{id='resource-production/'..f.id..'/1',kind='tool-repair',category='construction',
            actorId=f.id,observerId=f.id,perspective='performed',status='completed',worldHours=100,occurredAtHours=100,sourceId=f.step.recipeId,itemId=701,itemType='Base.Pistol',beforeValue=2,afterValue=10})==false)
    elseif name=='model-damage' then
        f.body.failNative=true;f.body.skill=3;__nativeFix('skill',3);__nativeFix('repairCount',5);f.target.repairCount=5;begin(f);row=finish(f)
        local candidate={id='damage',evidence=1,continuity=1,novelty=0,informationGain=0,blockers=0,
            consequences={{kind='tool-repair',category='construction',sourceId=f.step.recipeId,itemType='Base.Pistol',condition='damage',value=-.25}}}
        local learned=true
        for _,kind in ipairs({'ordinary','associative'}) do
            local model=f.rec.cognition and f.rec.cognition.models[kind]
            local prediction=model and SAO.CognitiveModels.planPrediction(kind,candidate,model,{actorId=f.id,atHours=100,pressure=.5})
            learned=learned and prediction~=nil and prediction.predictions[1].probability>.5
        end
        check('native_damage_changes_both_private_predictions',learned)
    elseif name=='source-cap' or name=='reservation-filter' or name=='sourceuse-filter' then
        __runPrivateFixingSourceCases(fixture,check,name)
    elseif name=='planner-authority' then
        begin(f)
        local generic={owner='SAO.ResourceProduction',token='resource:repaired',status='completed',correlationId=f.rec.resourceProductionWork.id,atHours=100}
        check('generic_pending_result_has_no_fixing_completion',P.recordResult(f.id,f.purpose.id,generic)==false)
    elseif name=='queue-registry' then
        begin(f);a=ISTimedActionQueue.getTimedActionQueue(f.body).current;a:start()
        local successor={Type='Successor',character=f.body,isValidStart=function() return true end,begin=function() end}
        local replacement={queue={successor},current=successor,indexOf=function(_,item) return item==successor and 1 or -1 end}
        ISTimedActionQueue.queues[f.body]=replacement;f.target.jobDelta=.7
        R.interrupt(f.id,f.body,'whole-queue-replaced')
        check('whole_replacement_queue_preserves_successor_and_cosmetics',replacement.current==successor and f.target.jobDelta==.7)
    elseif name=='target-reuse' then
        begin(f);a=ISTimedActionQueue.getTimedActionQueue(f.body).current;a:start();a.action.nativeFinished=true;a:perform();a:complete()
        local equip=ISTimedActionQueue.getTimedActionQueue(f.body).current
        f.target.condition=f.target.condition-1;equip.action.nativeFinished=true
        check('changed_native_target_before_reuse_refuses',equip:perform()==false)
    elseif name=='controller-dispatch' or name=='private-donor' then
        __runFixingControllerCases(fixture,finish,check,name)
    else error('unknown fixing control '..name) end
end

-- Scoped correction: exact native already-held start/false complete path.
function __runItemFixingEquipmentCorrection()
    __runItemFixingDonorSelectionCorrection()
    SAO.Cognition.ensureGameDefaults()
    local R=SAO.ResourceProduction
    for _,kind in ipairs({'Pistol','Shotgun'}) do
        local f=fixture('already-equipped-'..kind,false,kind)
        f.body.primary=f.target
        if f.target:isTwoHandWeapon() then f.body.secondary=f.target end
        local writes=0
        local primary,secondary=f.body.setPrimaryHandItem,f.body.setSecondaryHandItem
        f.body.setPrimaryHandItem=function(self,item) writes=writes+1;return primary(self,item) end
        f.body.setSecondaryHandItem=function(self,item) writes=writes+1;return secondary(self,item) end
        assert(begin(f))
        local q=ISTimedActionQueue.getTimedActionQueue(f.body)
        local fixingAction=q.current;fixingAction:start();fixingAction.action.nativeFinished=true;fixingAction:perform();fixingAction:complete()
        local equip=q.current;assert(equip and equip.Type=='ISEquipWeaponAction')
        equip:start()
        local nativeForced=equip.action:isForceComplete()
        equip:perform();equip:complete()
        local row=f.rec.resourceProductionOutcomes and f.rec.resourceProductionOutcomes[1]
        local good=nativeForced and row and row.status=='completed' and row.nativeCompleted and row.improved and row.reequipped
            and row.paymentConsumed and writes==0 and f.body:getPrimaryHandItem()==f.target
            and (not f.target:isTwoHandWeapon() or f.body:getSecondaryHandItem()==f.target)
            and f.purpose.status=='completed' and f.rec.cognition and #f.rec.cognition.experiences==1 and __nativeFix('callbacks')==1
        if kind=='Pistol' then check('already_held_handgun_native_completion_and_feedback',good)
        else check('already_held_two_hand_gun_native_completion_and_feedback',good) end
        check('already_held_duplicate_callback_is_inert_'..kind:lower(),equip:complete()==false and __nativeFix('callbacks')==1)
    end
    local f=fixture('already-held-hand-drift');f.body.primary=f.target;assert(begin(f))
    local q=ISTimedActionQueue.getTimedActionQueue(f.body);local work=q.current
    work:start();work.action.nativeFinished=true;work:perform();work:complete()
    local equip=q.current;equip:start();f.body.primary=nil;equip:perform()
    -- Native complete now equips the exact target through its ordinary action.
    equip:complete()
    local row=f.rec.resourceProductionOutcomes and f.rec.resourceProductionOutcomes[1]
    check('already_held_lost_hand_uses_native_equipment_effect',row and row.status=='completed' and row.reequipped
        and f.body:getPrimaryHandItem()==f.target and __nativeFix('callbacks')==1)
end

function __runItemFixingDonorSelectionCorrection()
    local f=fixture('reserved-first-donor')
    local reserved=material(__nativeFix('donor'),f.inventory);reserved.id=998;reserved.consumed=true
    f.inventory.items={f.target,reserved,f.tool}
    local options=SAO.ResourceProduction.maintenanceOptions(f.id,f.body)
    check('ordinary_reserved_donor_yields_exact_usable_later_donor',options[1] and options[1].toolItemId=='702'
        and options[1].toolItemType=='Base.Pistol')
    local Ctl=SAO.Controller
    Ctl.resourceContext=function() return {sources={}} end
    SAO.WorldSources={};SAO.SourceUse={}
    local context=Ctl.toolMaintenanceContext(f.id,f.agent,f.body)
    check('controller_reserved_first_donor_projects_carried_usable_means',context.options[1] and context.options[1].toolItemId=='702'
        and context.sources[context.options[1].recipeId]==nil)
    local admitted=begin(f)
    check('selected_usable_later_donor_prepares_native_raw_payment',admitted==true and f.inventory.items[2]==f.tool
        and f.inventory.items[3]==reserved and reserved.consumed==true)
    local row=admitted and finish(f)
    check('native_later_donor_payment_preserves_reserved_item',row and row.status=='completed' and row.toolItemId=='702'
        and row.paymentConsumed and f.inventory:contains(reserved) and reserved:getIsCraftingConsumed()
        and not f.inventory:contains(f.tool) and __nativeFix('callbacks')==1)
end
