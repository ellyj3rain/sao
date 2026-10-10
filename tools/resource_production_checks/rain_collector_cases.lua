-- Real registered Java recipe/build payment/factory and installed Lua build
-- actions. Unattached actors, geometry, action dispatch and cosmetics are receivers.
local function list(values)
    local a={values=values or {}}
    function a:size() return #self.values end
    function a:get(i) return self.values[i+1] end
    function a:add(x) self.values[#self.values+1]=x end
    function a:contains(x) for _,v in ipairs(self.values) do if v==x then return true end end;return false end
    function a:isEmpty() return #self.values==0 end
    return a
end
ArrayList={new=function() return list() end};ResourceType={Item='Item'}
ComponentType={FluidContainer='FluidContainer'}
IsoObjectType=setmetatable({},{__index=function(_,k) return k end})
IsoPropertyType=setmetatable({},{__index=function(_,k) return k end})
CharacterTrait.HANDY='Handy';Metabolics.HeavyWork='HeavyWork'
function showDebugInfoInChat() end
function getTimestamp() return 100 end
function createBuildAction() return 17 end
function removeAction(body,id,cancelled) body.transactionCancelled=cancelled end
function getSandboxOptions() return {getOptionByName=function() return {getValue=function() return 3 end} end} end
function getSpecificPlayer() error('native player-slot fallback is not this actor') end
function getSquare(x,y,z) return getCell():getGridSquare(x,y,z) end
ISBuildMenu={cheat=false}
Core={getTileScale=function() return 1 end}
local nativeBuildPerform=ISBuildAction.perform
ISBuildAction.perform=function(self)
    local ok,value=pcall(nativeBuildPerform,self)
    if not ok then print('native build error '..tostring(value));error(value) end
    return value
end
buildUtil.stairIsBlockingPlacement=function() return false end
buildUtil.getMaterialOnGround=function() return {} end
buildUtil.getMaterialOnGroundCounts=function() return {} end
buildUtil.getMaterialOnGroundUses=function() return {} end
buildUtil.checkCorner=function() end
buildUtil.setInfo=function(object,builder) object.builder=builder end
luautils={stringStarts=function(s,prefix) return s:sub(1,#prefix)==prefix end}
local properties={has=function() return false end}
local function sprite(name)
    return {name=name,LoadSingleTexture=function() end,getProperties=function() return properties end,
        getType=function() return 'normal' end}
end
IsoSprite={new=function() return sprite() end}
function getSprite(name) return sprite(name) end
local entities={'Base.RainCollector','Base.RainCollectorRound','Base.RainCollector_Tarp','Base.RainCollectorRound_Tarp'}
local policies={}
for _,id in ipairs(entities) do
    local inputs={}
    for j=0,3 do
        local index=j
        inputs[#inputs+1]={index=index,entityId=id,getResourceType=function() return ResourceType.Item end,
            getIntAmount=function() return __nativeCollector('policyCount',id,index) end,
            isKeep=function() return __nativeCollector('policyKeep',id,index) end}
    end
    local recipe={entityId=id}
    function recipe:getInputs() return list(inputs) end
    function recipe:getScriptObjectFullType() return __nativeCollector('entityRecipeId',id) end
    function recipe:getRequiredSkillCount() return __nativeCollector('policySkillCount',id) end
    function recipe:getRequiredSkill(j) return {entityId=id,index=j} end
    function recipe:getTime() return __nativeCollector('policyTime',id) end
    function recipe:getName() return id:sub(6) end
    function recipe:getHighestRelevantSkill() return Perks.Woodwork end
    function recipe:getHighestRelevantSkillLevel() return 5 end
    function recipe:getToolLeft() return nil end
    function recipe:getToolRight() return {canUseItem=function(_,name) return name=='Base.Hammer' end} end
    function recipe:getTimedActionScript() return nil end
    local parent={getScriptObjectFullType=function() return id end}
    function parent:getComponentScriptFor(kind)
        if kind==ComponentType.FluidContainer then return {getCapacity=function() return __nativeCollector('capacity',id) end} end
    end
    local cfg={getParent=function() return parent end,getPreviousStages=function() return list() end,
        getName=function() return id:sub(6) end,getBonusHealth=function() return __nativeCollector('spriteProp',id,'getBonusHealth') end}
    function cfg:getFace() return {getLightsourceOffsetX=function() return 0 end,getLightsourceOffsetY=function() return 0 end,getLightsourceOffsetZ=function() return 0 end} end
    function cfg:getLightsourceTagItem() return list() end
    setmetatable(cfg,{__index=function(_,key)
        return function() return __nativeCollector('spriteProp',id,key) end
    end})
    local tile={getSpriteName=function() return __nativeCollector('sprite',id) end,isBlocking=function() return false end}
    local face={getWidth=function() return 1 end,getHeight=function() return 1 end,getzLayers=function() return 1 end,
        getTileInfo=function() return tile end,getFaceName=function() return 's' end}
    local info={getScript=function() return cfg end,getRecipe=function() return {getCraftRecipe=function() return recipe end} end,
        getName=function() return id:sub(6) end,getFace=function(_,key) return (key=='S' or key==2) and face or nil end}
    policies[id]={info=info,recipe=recipe,inputs=inputs}
end
SpriteConfigManager={GetObjectInfoList=function()
    local out={};for _,id in ipairs(entities) do out[#out+1]=policies[id].info end;return list(out)
end}
CraftRecipeManager={
    hasPlayerLearnedRecipe=function(recipe,body) return body.recipeUnknown~=true and __nativeCollector('policyLearned',recipe.entityId) end,
    hasPlayerRequiredSkill=function(skill) return __nativeCollector('policySkill',skill.entityId,skill.index) end,
    getValidInputScriptForItem=function(recipe,item)
        for j=0,3 do if item:getID()>=100 and item:getID()<116 and __nativeCollector('inputMatches',recipe.entityId..'|'..j,item:getID()) then return policies[recipe.entityId].inputs[j+1] end end
    end}
local active
local function nativeManual(data,input,out)
    for id in __nativeCollector('manualIds',data,input.index):gmatch('[^,]+') do out:add(active.materialById[tonumber(id)]) end
    return out
end
BuildLogic={new=function(body)
    __nativeCollector('newLogic')
    local logic={body=body,manualMode=false}
    function logic:setContainers(v) self.containers=v;__nativeCollector('containers') end
    function logic:setRecipe(r) self.recipe=r;__nativeCollector('setRecipe',r.entityId) end
    function logic:getRecipe() return self.recipe end
    function logic:setManualSelectInputs(v) self.manualMode=v;__nativeCollector('manualMode',v) end
    function logic:isManualSelectInputs() return self.manualMode end
    function logic:clearManualInputs() __nativeCollector('clearManual') end
    function logic:setManualInputsFor(input,items)
        local ids={};for i=0,items:size()-1 do ids[#ids+1]=tostring(items:get(i):getID()) end
        return __nativeCollector('manual',input.index,table.concat(ids,','))
    end
    function logic:canPerformCurrentRecipe() return __nativeCollector('eligible') end
    function logic:getPossibleCraftCount() return __nativeCollector('possible') end
    function logic:startCraftAction(action) __nativeCollector('start') end
    function logic:stopCraftAction() __nativeCollector('stop') end
    function logic:getModelHandOne() return 'Hammer' end
    function logic:getModelHandTwo() return nil end
    function logic:getAllConsumedItems() return self:getRecipeData():getAllConsumedItems() end
    function logic:performCurrentRecipe()
        active.nativePayments=(active.nativePayments or 0)+1
        return __nativeCollector('perform')
    end
    local function data(kind)
        return {getRecipe=function() return kind~='progress' or __nativeCollector('progressRecipe') and logic.recipe or nil end,
            getManualInputsFor=function(_,input,out) return nativeManual(kind,input,out) end,
            getAllConsumedItems=function()
                local out={};for _,item in ipairs(active.materials) do if __nativeCollector('consumed',item:getID()) then out[#out+1]=item end end;return list(out)
            end,
            getAllKeepInputItems=function()
                local out={};for _,item in ipairs(active.materials) do if __nativeCollector('kept',item:getID()) then out[#out+1]=item end end;return list(out)
            end,
            getAllRecordedConsumedItems=function() return list() end,
            luaCallOnCreate=function() end,
            processDestroyAndUsedItems=function()
                __nativeCollector('process')
                for _,item in ipairs(active.materials) do
                    item.condition=__nativeCollector('condition',item:getID())
                    if not __nativeCollector('held',item:getID()) then item:getContainer():Remove(item) end
                end
            end}
    end
    function logic:getRecipeData() return data('current') end
    function logic:getRecipeDataInProgress() return data('progress') end
    return logic
end}
GameEntityFactory={CreateIsoObjectEntity=function(object,entity)
    __nativeCollector('factory',active.entityId)
    object.nativeFactory=true
    object.fluid={getCapacity=function() return __nativeCollector('createdCapacity') end,
        getAmount=function() return active.collectorAmount or __nativeCollector('createdAmount') end}
end}
IsoThumpable={new=function(cell,square,name,north,builder)
    local object={kind='IsoThumpable',square=square,sprite=name}
    function object:getType() return 'normal' end
    function object:getProperties() return properties end
    function object:getSquare() return self.square end
    function object:getFluidContainer() return self.fluid end
    function object:setMaxHealth(v) self.maxHealth=v end
    function object:getMaxHealth() return self.maxHealth end
    function object:setHealth(v) self.health=v end
    function object:setBreakSound(v) self.breakSound=v end
    function object:setExplored(v) self.explored=v end
    function object:transmitCompleteItemToClients() self.sent=true end
    return object
end}
local function roofSquare(f,x,y)
    local s={x=x,y=y,z=1,objects={}}
    function s:getX() return self.x end
    function s:getY() return self.y end
    function s:getZ() return self.z end
    function s:getObjects() return list(self.objects) end
    function s:getProperties() return properties end
    function s:has() return false end
    function s:isVehicleIntersecting() return false end
    function s:isSolid() return false end
    function s:isSolidTrans() return false end
    function s:isFree() return #self.objects==0 and not self.blocked end
    function s:isFreeOrMidair() return self:isFree() end
    function s:hasFloor() return true end
    function s:isOutside() return true end
    function s:AddSpecialObject(object) self.objects[#self.objects+1]=object;f.created=object;f.placements=(f.placements or 0)+1 end
    function s:RecalcAllWithNeighbours() end
    f.cell.squares[x..':'..y..':1']=s
    return s
end
function __rainFixture(id,entityId,nested)
    entityId=entityId or 'Base.RainCollector'
    __nativeCollector('reset',entityId)
    local f=__plumbingFixture(id,false,false);active=f;f.entityId=entityId;f.vessel=f.item;f.sourceFixture=f.fixture
    f.inventory.items={f.vessel};f.materials={};f.materialById={}
    for itemId=100,99+__nativeCollector('count') do
        local fullType=__nativeCollector('type',itemId)
        local item=__boardingItem(fullType:sub(6),itemId,f.inventory)
        item.condition=__nativeCollector('condition',itemId)
        function item:canStoreWater() return false end
        function item:getFluidContainer() return nil end
        function item:hasTag(tag) return tag==ItemTag.HAMMER and self:getType()=='Hammer' end
        if fullType=='Base.Garbagebag' then
            item.kind='InventoryContainer';item.contents={}
            function item:getInventory() return {getItems=function() return list(self.contents) end} end
        end
        f.inventory.items[#f.inventory.items+1]=item;f.materials[#f.materials+1]=item;f.materialById[itemId]=item
    end
    f.hammer=f.materials[1];f.tool=f.hammer
    if nested then
        local bag={items=f.materials};__boardingInventory(bag,f.inventory)
        function bag:contains(item) for _,v in ipairs(self.items) do if v==item then return true end end;return false end
        function bag:Remove(item) for i,v in ipairs(self.items) do if v==item then table.remove(self.items,i);item.container=nil;return end end end
        f.inventory.items={f.vessel};f.inventory.nested=bag
        for _,item in ipairs(f.materials) do item.container=bag end
    end
    f.siteSquare=roofSquare(f,0,0);f.roofHere=roofSquare(f,-1,0)
    f.body.here=f.roofHere;f.body.x=-.5;f.body.y=.5;f.body.z=1
    function f.body:isBuildCheat() return false end
    function f.body:getPerkLevel() return 5 end
    function f.body:faceLocation() end
    function f.body:faceLocationF() end
    function f.body:damageCheck() return false end
    SAOJavaBridge.worldCollectorSites=function(_,body)
        return body:getZ()==1 and '0,0,1,site-r1|-1,0,1,interaction-r1' or ''
    end
    SAOJavaBridge.worldCollectorPlacementSquare=function(_,body,x,y,z,revision)
        return f.placementRefused~=true and body==f.body and body:getZ()==1 and revision==f.siteRevision
            and x==0 and y==0 and z==1 and #f.siteSquare.objects==0 and f.siteSquare or nil
    end
    SAOJavaBridge.worldCollectorCreated=function(_,body,object,entity,x,y,z)
        return body==f.body and object==f.created and object.nativeFactory and object.square==f.siteSquare
            and entity==f.entityId and x==0 and y==0 and z==1
    end
    SAOJavaBridge.worldCollectorSource=function(_,body,object,entity,x,y,z)
        return SAOJavaBridge:worldCollectorCreated(body,object,entity,x,y,z) and 'F:new-'..id..'|new-fp-'..id or ''
    end
    SAOJavaBridge.worldCollectorFeedsFixture=function(_,body,object,sourceId,fp,x,y,z)
        return object==f.created and sourceId==f.sourceId and fp==f.fingerprint and f.feedRefused~=true
    end
    local observe=SAOJavaBridge.observeWorldChunk
    SAOJavaBridge.observeWorldChunk=function(...)
        local protocol=observe(...)
        if f.created then
            protocol=protocol:gsub('|sources=1\n','|sources=2\n',1)
            protocol=protocol:sub(1,#protocol-1)..'S|id=F:new-'..id..'|fp=new-fp-'..id..'|rev=new-r1|kind=fluid|x=0|y=0|z=1|building=-1|explored=1|state=spent|access=unknown|container=collector|plumbing=|q:water=0\n'
                ..'I|source=F:new-'..id..'|id=0|type=|uses=0|amount=0|fluid=|poison=0|rotten=0|cats=\nE'
        end
        return protocol
    end
    f.siteRevision='site-r1'
    assert(SAO.Perception.observeCollectorSites(id,f.body,__hours))
    f.site=SAO.Perception.collectorSites(id,f.body)[1]
    SAO.Locomotion.order=function(pid,body,x,y,z)
        f.routeCalls=(f.routeCalls or 0)+1
        SAO.Locomotion.jobs[pid]={body=body,x=x,y=y,z=z,done=false}
        return true
    end
    SAO.Locomotion.tick=function(pid)
        local job=SAO.Locomotion.jobs[pid]
        if f.routeArrived then
            f.body.x,f.body.y,f.body.z=job.x+.5,job.y+.5,job.z
            f.body.here=f.cell:getGridSquare(job.x,job.y,job.z)
            job.done,job.result=true,'arrived'
        end
    end
    return f
end
function __rainPlan(f)
    local options={}
    for _,option in ipairs(SAO.ResourceProduction.options(f.id,f.body,'water')) do
        if option.kind=='build-rain-collector' and option.entityId==f.entityId then options[#options+1]=option end
    end
    local p,s=SAO.ProceduralPlanning.planResource(f.id,{category='water',pressure=.7,atHours=__hours,
        carriedWater=0,carriedReady=0,carriedRaw=0,sources={},productionOptions=options,needs={fatigue=.1,health=1}})
    f.purpose,f.step=p,s;return p,s
end
function __rainBegin(f)
    if not f.purpose then __rainPlan(f) end
    return f.purpose and type(f.step)=='table' and SAO.ResourceProduction.begin(f.id,f.body,f.step,{purposeId=f.purpose.id,purposeStepId=f.step.id}) or false
end
function __rainCurrent(f) return ISTimedActionQueue.getTimedActionQueue(f.body).current end
function __rainFinish(f)
    local q=ISTimedActionQueue.getTimedActionQueue(f.body)
    local count=0
    while q.current do
        count=count+1;if count>18 then error('collector preparation loop') end
        local a=q.current
        if a.Type=='ISBuildAction' then
            print('build validity '..tostring(a:isValid()))
            for j=0,3 do print('manual '..j..' '..__nativeCollector('manualIds','current',j)..' / '..__nativeCollector('manualIds','progress',j)) end
        end
        if a.Type=='ISInventoryTransferAction' then a.getNotFullFloorSquare=function() return nil end;a.playTransferCompleteSound=function() end end
        a:start();a.action.nativeFinished=true;a:perform()
        if a.Type=='ISEquipWeaponAction' then a:complete() end
        if q.current==a then error('native collector queue remained '..a.Type) end
    end
    SAO.ResourceProduction.tick(f.id,f.body)
    return f.rec.resourceProductionOutcomes and f.rec.resourceProductionOutcomes[#f.rec.resourceProductionOutcomes]
end
function __rainSaved(f)
    local r=__nativeRoundtrip(f.rec);__records[f.id]=r;f.rec=r;f.agent.rec=r
    f.purpose=r.proceduralPlanning.purposes[f.purpose.id];f.step=f.purpose.steps[f.purpose.cursor]
end
local function check(name,value) print(name..'='..tostring(value==true)) end
function __runRainCollectorCases()
    local R,P,C=SAO.ResourceProduction,SAO.ProceduralPlanning,SAO.Cognition
    C.ensureGameDefaults()
    for index,entityId in ipairs(entities) do
        local f=__rainFixture('variant-'..index,entityId)
        check('registered_variant_'..index,#R.options(f.id,f.body,'water')>=4 and __rainBegin(f))
        check('admission_no_construction_'..index,not f.created and not f.rec.cognition and f.purpose.admission~=nil)
        local row=__rainFinish(f)
        check('native_variant_payment_placement_'..index,row and row.status=='completed' and row.constructed and row.placed
            and row.exactInputs and row.inputsConsumed and row.toolRetained and row.nativeOwner=='ISBuildAction'
            and row.beforeCollectorAmount==0 and row.afterCollectorAmount==0 and row.collectorCapacity==(index%2==1 and 400 or 600)
            and f.created and f.created.sent and f.placements==1 and f.nativePayments==1 and f.amount==0)
        check('native_variant_private_fact_'..index,row and row.sourceObservation.status=='confirmed' and f.rec.cognition
            and #f.rec.cognition.experiences==1 and f.rec.cognition.experiences[1].kind=='collector-construction'
            and f.rec.cognition.experiences[1].entityId==entityId and f.rec.cognition.experiences[1].itemType=='Base.Hammer'
            and f.rec.cognition.models.ordinary.revision==1 and f.rec.cognition.models.associative.revision==1)
        check('empty_collector_retains_hydration_'..index,f.purpose.status~='completed' and f.purpose.collector.constructedWorkId==row.id
            and not f.purpose.admission and f.amount==0 and not __rainBegin(f))
    end
end

-- The following scenarios are appended after the reusable producer prefix.
function __collectorScenario(name)
    local R,C=SAO.ResourceProduction,SAO.Cognition
    local f=__rainFixture('scenario-'..name,'Base.RainCollector')
    if name=='nested_exact_inputs_native_preparation' then
        local carried={};for _,item in ipairs(f.materials) do carried[#carried+1]=item end
        local bag={items=carried};__boardingInventory(bag,f.inventory)
        function bag:contains(item) for _,v in ipairs(self.items) do if v==item then return true end end;return false end
        function bag:Remove(item) for i,v in ipairs(self.items) do if v==item then table.remove(self.items,i);item.container=nil;return end end end
        f.inventory.items={f.vessel};f.inventory.nested=bag;for _,item in ipairs(f.materials) do item.container=bag end
        if not __rainBegin(f) then return false end
        local row=__rainFinish(f)
        return row and row.status=='completed' and row.inputsConsumed and row.toolRetained and f.hammer:getContainer()==f.inventory
            and f.inventory:contains(f.vessel) and #bag.items==0 and f.placements==1
    elseif name=='replacement_queue_custody_preserved' then
        f.body.primary=f.hammer;if not __rainBegin(f) then return false end
        local a=__rainCurrent(f);a:start()
        local q=ISTimedActionQueue.getTimedActionQueue(f.body)
        local successor={character=f.body,Type='Successor',isValidStart=function() return true end,begin=function() end}
        q.queue={successor};q.current=successor;f.body.farming=true;f.hammer.jobDelta=.7
        local closed=R.interrupt(f.id,f.body,'queue-replaced')
        return closed and q.current==successor and q.queue[1]==successor and f.body.farming==true and f.hammer.jobDelta==.7
            and not f.created and not f.nativePayments
    elseif name=='nonempty_bag_refused' then
        f.materials[10].contents={{}}
        return __rainBegin(f)==false and not f.created and not f.nativePayments
    elseif name=='native_manual_preparation' then
        f.body.primary=f.hammer
        return __rainBegin(f) and __rainCurrent(f):isValid()==true and not f.nativePayments
    elseif name=='offfloor_return_refreshes_admitted_site' then
        __rainPlan(f);f.body.here=f.square;f.body.x,f.body.y,f.body.z=.5,.5,0;f.placementRefused=true
        if not __rainBegin(f) then return false end
        local workId=f.rec.resourceProductionWork.id
        __hours=100.01;f.routeArrived=true;R.tick(f.id,f.body)
        local fresh=SAO.Perception.collectorSites(f.id,f.body)[1]
        local pending=f.rec.resourceProductionWork and f.rec.resourceProductionWork.id==workId and fresh.observedAtHours==100.01
        f.placementRefused=false;R.tick(f.id,f.body)
        local ok,row=pcall(__rainFinish,f)
        return pending and ok and row and row.status=='completed' and row.siteObservedAtHours==100 and row.id==workId and f.placements==1
    elseif name=='changed_site_revision_refuses' then
        __rainPlan(f);f.body.primary=f.hammer;if not __rainBegin(f) then return false end
        f.siteRevision='changed'
        local a=__rainCurrent(f);a:start();a.action.nativeFinished=true
        return a:perform()==false and not f.created and not f.nativePayments
    elseif name=='direct_native_create_refuses_payment' then
        f.body.primary=f.hammer;if not __rainBegin(f) then return false end
        local a=__rainCurrent(f)
        a.item:create(a.x,a.y,a.z,a.north,a.spriteName)
        return not f.created and not f.nativePayments and #f.inventory.items==14
    elseif name=='full_envelope_canonical_delivery' or name=='canonical_constructor_both_models'
        or name=='constructor_replay_and_forgery' or name=='nonselected_supplier_keeps_construction_fact' then
        if name=='nonselected_supplier_keeps_construction_fact' then f.feedRefused=true end
        if not __rainBegin(f) then return false end
        local fields=0;for _ in pairs(f.rec.resourceProductionWork) do fields=fields+1 end
        local ok,row=pcall(__rainFinish,f)
        if not ok or not row then return false end
        if name=='full_envelope_canonical_delivery' then
            local count=0;for _ in pairs(row) do count=count+1 end
            return fields>32 and count>32 and row.status=='completed' and row.purposeDelivered and row.experienceDelivered
        elseif name=='canonical_constructor_both_models' then
            return row.status=='completed' and f.rec.cognition and #f.rec.cognition.experiences==1
                and f.rec.cognition.models.ordinary.revision==1 and f.rec.cognition.models.associative.revision==1
        elseif name=='nonselected_supplier_keeps_construction_fact' then
            return row.status=='completed' and row.feedsFixture==false and f.rec.cognition.experiences[1].feedsFixture==false
                and f.purpose.status~='completed' and f.amount==0
        end
        local canonical=R.outcome(f.id,row.id);local fake=__nativeRoundtrip(canonical);fake.collectorFingerprint='forged'
        local denied=C.collectorConstructionOutcome(f.id,fake)==false and C.collectorConstructionOutcome('other',canonical)==false
        __rainSaved(f);R.reconcileSaved(f.id,f.body);canonical=R.outcome(f.id,row.id)
        return denied and C.collectorConstructionOutcome(f.id,canonical) and R.onOutcome(f.id,canonical)
            and #f.rec.resourceProductionOutcomes==1 and #f.rec.cognition.experiences==1 and f.placements==1
    elseif name=='generic_constructor_fact_denied' then
        return C.experience(f.id,{id='resource-production/'..f.id..'/1',actorId=f.id,observerId=f.id,worldHours=100,
            occurredAtHours=100,kind='collector-construction',category='construction',perspective='performed',status='completed',
            sourceId='F:new-'..f.id,itemId=100,itemType='Base.Hammer',entityId=f.entityId,recipeId=f.entityId,
            originalFixtureSourceId=f.sourceId,siteKey='collector-site:0:0:1',siteX=0,siteY=0,siteZ=1,feedsFixture=true})==false
    elseif name=='pending_constructor_ack_retained' then
        f.body.primary=f.hammer;if not __rainBegin(f) then return false end
        local a=__rainCurrent(f);a:start();f.body.holdCancellation=true
        local pending=R.interrupt(f.id,f.body,'transfer')==false and f.rec.resourceProductionWork~=nil
            and f.purpose.admission~=nil and __rainCurrent(f)==a and not f.created
        f.body.holdCancellation=false;a:stop()
        return pending and not f.rec.resourceProductionWork and not f.purpose.admission and not f.created
    elseif name=='death_cancels_native_constructor' then
        if not __rainBegin(f) then return false end
        local a=__rainCurrent(f);a:start();f.rec.dead=true;f.body.dead=true
        return R.detach(f.id,f.body,'death')==true and not f.rec.resourceProductionWork and not f.purpose.admission and not f.created
    elseif name=='changed_body_token_refuses_constructor' then
        f.body.primary=f.hammer;if not __rainBegin(f) then return false end
        local a=__rainCurrent(f);a:start();f.body.md.SAOExternalToken='foreign';a.action.nativeFinished=true
        return a:perform()==false and not f.created and not f.nativePayments
    elseif name=='saved_pending_constructor_retires_without_credit' then
        f.body.primary=f.hammer;if not __rainBegin(f) then return false end
        local a=__rainCurrent(f);a:start();__rainSaved(f);__reloadProduction();f.body.holdCancellation=true;SAO.Controller.agents[f.id]=nil
        local pending=R.reconcileSaved(f.id,f.body)==false and f.rec.resourceProductionWork~=nil and f.purpose.admission~=nil
        f.body.holdCancellation=false
        local ack=R.reconcileSaved(f.id,f.body)
        local row=f.rec.resourceProductionOutcomes and f.rec.resourceProductionOutcomes[1]
        return pending and ack==true and not f.rec.resourceProductionWork and not f.purpose.admission and row
            and row.status=='interrupted' and row.nativeObservability=='runtime-unavailable' and not row.nativeCredit
            and not f.created and not f.nativePayments
    elseif name=='duplicate_native_constructor_callbacks_inert' then
        f.body.primary=f.hammer;if not __rainBegin(f) then return false end
        local a=__rainCurrent(f);local row=__rainFinish(f)
        a:perform();a:complete();a.item:create(a.x,a.y,a.z,a.north,a.spriteName)
        return row.status=='completed' and f.placements==1 and f.nativePayments==1 and #f.rec.resourceProductionOutcomes==1
    end
    error('unknown collector scenario '..name)
end
function __runAdditionalCollectorCases()
    for _,name in ipairs({'nested_exact_inputs_native_preparation','replacement_queue_custody_preserved',
        'nonempty_bag_refused','native_manual_preparation','offfloor_return_refreshes_admitted_site',
        'changed_site_revision_refuses','direct_native_create_refuses_payment','full_envelope_canonical_delivery',
        'canonical_constructor_both_models','constructor_replay_and_forgery','nonselected_supplier_keeps_construction_fact',
        'generic_constructor_fact_denied','pending_constructor_ack_retained','death_cancels_native_constructor',
        'changed_body_token_refuses_constructor','saved_pending_constructor_retires_without_credit','duplicate_native_constructor_callbacks_inert'}) do
        print(name..'='..tostring(__collectorScenario(name)==true))
    end
end
function __runRainCollectorControl(name)
    local ok,result=pcall(__collectorScenario,name)
    print(name..'='..tostring(ok and result==true))
end
