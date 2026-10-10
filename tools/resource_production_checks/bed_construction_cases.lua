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
local entities={'Base.Wood_Bed'}
local policies={}
for _,id in ipairs(entities) do
    local inputs={}
    for j=0,3 do
        local index=j
        inputs[#inputs+1]={index=index,entityId=id,getResourceType=function() return ResourceType.Item end,
            getIntAmount=function() return __nativeBed('policyCount',id,index) end,
            isKeep=function() return __nativeBed('policyKeep',id,index) end}
    end
    local recipe={entityId=id}
    function recipe:getInputs() return list(inputs) end
    function recipe:getScriptObjectFullType() return __nativeBed('entityRecipeId',id) end
    function recipe:getRequiredSkillCount() return __nativeBed('policySkillCount',id) end
    function recipe:getRequiredSkill(j) return {entityId=id,index=j} end
    function recipe:getTime() return __nativeBed('policyTime',id) end
    function recipe:getName() return id:sub(6) end
    function recipe:getHighestRelevantSkill() return Perks.Woodwork end
    function recipe:getHighestRelevantSkillLevel() return 5 end
    function recipe:getToolLeft() return nil end
    function recipe:getToolRight() return {canUseItem=function(_,name) return name=='Base.Hammer' end} end
    function recipe:getTimedActionScript() return nil end
    local parent={getScriptObjectFullType=function() return id end}
    function parent:getComponentScriptFor(kind)
        return nil
    end
    local cfg={getParent=function() return parent end,getPreviousStages=function() return list() end,
        getName=function() return id:sub(6) end,getBonusHealth=function() return __nativeBed('spriteProp',id,'getBonusHealth') end}
    function cfg:getFace() return {getLightsourceOffsetX=function() return 0 end,getLightsourceOffsetY=function() return 0 end,getLightsourceOffsetZ=function() return 0 end} end
    function cfg:getLightsourceTagItem() return list() end
    setmetatable(cfg,{__index=function(_,key)
        return function() return __nativeBed('spriteProp',id,key) end
    end})
    local faces={}
    for _,orientation in ipairs({'S','E'}) do
        local key=orientation
        faces[key]={getWidth=function() return key=='S' and 2 or 1 end,getHeight=function() return key=='S' and 1 or 2 end,
            getzLayers=function() return 1 end,getFaceName=function() return key end,
            getTileInfo=function(_,x,y,z) return {getSpriteName=function() return __nativeBed('partSprite',key,key=='S' and x or y) end,isBlocking=function() return false end} end}
    end
    local info={getScript=function() return cfg end,getRecipe=function() return {getCraftRecipe=function() return recipe end} end,
        getName=function() return id:sub(6) end,getFace=function(_,key) return (key=='S' or key==2) and faces.S or (key=='E' or key==3) and faces.E or nil end}
    policies[id]={info=info,recipe=recipe,inputs=inputs}
end
SpriteConfigManager={GetObjectInfoList=function()
    local out={};for _,id in ipairs(entities) do out[#out+1]=policies[id].info end;return list(out)
end}
CraftRecipeManager={
    hasPlayerLearnedRecipe=function(recipe,body) return body.recipeUnknown~=true and __nativeBed('policyLearned',recipe.entityId) end,
    hasPlayerRequiredSkill=function(skill) return __nativeBed('policySkill',skill.entityId,skill.index) end,
    getValidInputScriptForItem=function(recipe,item)
        for j=0,3 do if item:getID()>=100 and item:getID()<116 and __nativeBed('inputMatches',recipe.entityId..'|'..j,item:getID()) then return policies[recipe.entityId].inputs[j+1] end end
    end}
local active
local function nativeManual(data,input,out)
    for id in __nativeBed('manualIds',data,input.index):gmatch('[^,]+') do out:add(active.materialById[tonumber(id)]) end
    return out
end
BuildLogic={new=function(body)
    __nativeBed('newLogic')
    local logic={body=body,manualMode=false}
    function logic:setContainers(v) self.containers=v;__nativeBed('containers') end
    function logic:setRecipe(r) self.recipe=r;__nativeBed('setRecipe',r.entityId) end
    function logic:getRecipe() return self.recipe end
    function logic:setManualSelectInputs(v) self.manualMode=v;__nativeBed('manualMode',v) end
    function logic:isManualSelectInputs() return self.manualMode end
    function logic:clearManualInputs() __nativeBed('clearManual') end
    function logic:setManualInputsFor(input,items)
        local ids={};for i=0,items:size()-1 do ids[#ids+1]=tostring(items:get(i):getID()) end
        return __nativeBed('manual',input.index,table.concat(ids,','))
    end
    function logic:canPerformCurrentRecipe() return __nativeBed('eligible') end
    function logic:getPossibleCraftCount() return __nativeBed('possible') end
    function logic:startCraftAction(action) __nativeBed('start') end
    function logic:stopCraftAction() __nativeBed('stop') end
    function logic:getModelHandOne() return 'Hammer' end
    function logic:getModelHandTwo() return nil end
    function logic:getAllConsumedItems() return self:getRecipeData():getAllConsumedItems() end
    function logic:performCurrentRecipe()
        active.nativePayments=(active.nativePayments or 0)+1
        return __nativeBed('perform')
    end
    local function data(kind)
        return {getRecipe=function() return kind~='progress' or __nativeBed('progressRecipe') and logic.recipe or nil end,
            getManualInputsFor=function(_,input,out) return nativeManual(kind,input,out) end,
            getAllConsumedItems=function()
                local out={};for _,item in ipairs(active.materials) do if __nativeBed('consumed',item:getID()) then out[#out+1]=item end end;return list(out)
            end,
            getAllKeepInputItems=function()
                local out={};for _,item in ipairs(active.materials) do if __nativeBed('kept',item:getID()) then out[#out+1]=item end end;return list(out)
            end,
            getAllRecordedConsumedItems=function() return list() end,
            luaCallOnCreate=function() end,
            processDestroyAndUsedItems=function()
                __nativeBed('process')
                for _,item in ipairs(active.materials) do
                    item.condition=__nativeBed('condition',item:getID())
                    if not __nativeBed('held',item:getID()) then item:getContainer():Remove(item) end
                end
            end}
    end
    function logic:getRecipeData() return data('current') end
    function logic:getRecipeDataInProgress() return data('progress') end
    return logic
end}
GameEntityFactory={CreateIsoObjectEntity=function(object,entity)
    __nativeBed('factory',object.sprite)
    object.nativeFactory=true
end}
IsoThumpable={new=function(cell,square,name,north,builder)
    local object={kind='IsoThumpable',square=square,sprite=name}
    function object:getX() return self.square:getX() end
    function object:getY() return self.square:getY() end
    function object:getZ() return self.square:getZ() end
    function object:getSpriteName() return self.sprite end
    function object:getObjectIndex() for n,o in ipairs(self.square.objects) do if o==self then return n-1 end end;return -1 end
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
    local s={x=x,y=y,z=0,objects={}}
    function s:getX() return self.x end
    function s:getY() return self.y end
    function s:getZ() return self.z end
    function s:getObjects() return list(self.objects) end
    function s:getProperties() return properties end
    function s:canStand() return true end
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
    f.cell.squares[x..':'..y..':0']=s
    return s
end

local function fixture(id,orientation,nested)
    orientation=orientation or 'S';__nativeBed('reset','Base.Wood_Bed');__nativeBed('face',orientation)
    local f=__plumbingFixture(id,false,false);active=f;f.entityId='Base.Wood_Bed';f.orientation=orientation
    f.inventory.items={};f.materials={};f.materialById={}
    for itemId=100,99+__nativeBed('count') do
        local item=__boardingItem(__nativeBed('type',itemId):sub(6),itemId,f.inventory)
        item.condition=__nativeBed('condition',itemId)
        function item:getFluidContainer() return nil end
        function item:getFluidContainerFromSelfOrWorldItem() return nil end
        function item:hasTag(tag) return self:getType()=='Hammer' and tag==ItemTag.HAMMER end
        f.inventory.items[#f.inventory.items+1]=item;f.materials[#f.materials+1]=item;f.materialById[itemId]=item
    end
    f.hammer=f.materials[1];f.tool=f.hammer
    if nested then
        local held={};for _,item in ipairs(f.materials) do held[#held+1]=item end
        local bag={items=held};__boardingInventory(bag,f.inventory)
        function bag:contains(i) for _,v in ipairs(self.items) do if i==v then return true end end;return false end
        function bag:Remove(item) for i,v in ipairs(self.items) do if v==item then table.remove(self.items,i);item.container=nil;return end end end
        f.inventory.items={};f.inventory.nested=bag
        for _,item in ipairs(f.materials) do item.container=bag end
    end
    f.siteSquare=roofSquare(f,0,0);f.secondSquare=roofSquare(f,orientation=='S' and 1 or 0,orientation=='E' and 1 or 0)
    local ax,ay=orientation=='S' and 0 or -1,orientation=='S' and -1 or 0
    f.approach=roofSquare(f,ax,ay);f.body.here=f.approach;f.body.x,f.body.y,f.body.z=ax+.5,ay+.5,0
    function f.body:isBuildCheat() return false end
    function f.body:faceLocation() end
    function f.body:faceLocationF() end
    function f.body:getPerkLevel() return 5 end
    f.rec.permissionDenied=false
    f.siteRevision='12345678-1234-1234-1234-123456789abc'
    SAOJavaBridge.worldBedSites=function(_,body)
        return body==f.body and '0,0,0,'..orientation..','..f.siteRevision..','..ax..','..ay..',0' or ''
    end
    SAOJavaBridge.worldBedPlacementSquare=function(_,body,x,y,z,face,revision)
        return body==f.body and not f.placementRefused and face==orientation and revision==f.siteRevision and x==0 and y==0 and z==0
            and body:getCurrentSquare()==f.approach and #f.siteSquare.objects==0 and #f.secondSquare.objects==0 and f.siteSquare or nil
    end
    SAOJavaBridge.worldBedCreated=function(_,body,a,b,x,y,z,face)
        return body==f.body and a~=b and a==f.siteSquare.objects[1] and b==f.secondSquare.objects[1]
            and a.nativeFactory and b.nativeFactory and __nativeBed('createdCount')==2 and __nativeBed('createdGrid')
            and face==orientation and not f.createdRefused
    end
    SAOJavaBridge.recoveryPlaces=function(_,body)
        local places={}
        if f.siteSquare.objects[1] and f.secondSquare.objects[1] and not f.bedOccupied then
            places[1]={key='bed:0:0:0:0:created-'..id,kind='bed',available=true,x=ax+.5,y=ay+.5,z=0,
                objectX=0,objectY=0,objectZ=0,objectIndex=0}
        end
        return {actorId=id,status='available',places=places}
    end
    SAO.Locomotion.order=function(pid,body,x,y,z)
        SAO.Locomotion.jobs[pid]={body=body,goal={x=x,y=y,z=z},done=false};return true
    end
    SAO.Locomotion.tick=function(pid) local job=SAO.Locomotion.jobs[pid]
        if f.arrived then f.body.x,f.body.y,f.body.z=job.goal.x,job.goal.y,job.goal.z;f.body.here=f.approach;job.done,job.result=true,'arrived' end
    end
    assert(SAO.Perception.observeBedSites(id,f.body,__hours));return f
end
local function plan(f)
    local option=SAO.ResourceProduction.bedOptions(f.id,f.body)[1]
    assert(option,'native bed option absent')
    local p,step=SAO.ProceduralPlanning.planBedConstruction(f.id,{recoveryKind='sleep',fatigue=.65,atHours=__hours,options={option},materialSources={}})
    f.purpose,f.step=p,step;return p,step
end
local function begin(f)
    if not f.purpose then plan(f) end
    return f.step and SAO.ResourceProduction.begin(f.id,f.body,f.step,{purposeId=f.purpose.id,purposeStepId=f.step.id})
end
local function finish(f)
    local q=ISTimedActionQueue.getTimedActionQueue(f.body);local count=0
    while q.current do
        count=count+1;assert(count<=15,'bed preparation loop')
        local a=q.current
        if a.Type=='ISInventoryTransferAction' then a.getNotFullFloorSquare=function() return nil end;a.playTransferCompleteSound=function() end end
        a:start();a.action.nativeFinished=true;a:perform()
        if a.Type=='ISEquipWeaponAction' then a:complete() end
        assert(q.current~=a,'native bed action retained '..a.Type)
    end
    SAO.ResourceProduction.tick(f.id,f.body)
    local rows=f.rec.resourceProductionOutcomes or {};return rows[#rows]
end
local function check(name,value) print(name..'='..tostring(value==true)) end
function __runBedConstructionCases()
    local R,P,C=SAO.ResourceProduction,SAO.ProceduralPlanning,SAO.Cognition
    C.ensureGameDefaults()
    for _,face in ipairs({'S','E'}) do
        local f=fixture('orientation-'..face,face,true)
        local admitted=begin(f)
        check('native_bed_'..face..'_admission_no_credit',admitted and not f.created and f.purpose.admission and not f.rec.cognition)
        local row=finish(f)
        print('bed result face='..face..' status='..tostring(row and row.status)..' detail='..tostring(row and row.detail)..' parts='..tostring(row and #row.parts)..' placement='..tostring(f.placements)..' javaParts='..tostring(__nativeBed('createdCount'))..' grid='..tostring(__nativeBed('createdGrid'))..' pending='..tostring(f.rec.resourceProductionWork and f.rec.resourceProductionWork.status))
        check('native_bed_'..face..'_allparts_exactpayment',row and row.status=='completed' and #row.parts==2 and row.inputsConsumed
            and row.toolRetained and f.placements==2 and f.nativePayments==1 and row.face==face and __nativeBed('createdGrid'))
        check('native_bed_'..face..'_private_construction_only',row and f.rec.cognition and #f.rec.cognition.experiences==1
            and f.rec.cognition.experiences[1].kind=='bed-construction' and f.rec.cognition.models.ordinary.revision==1
            and f.rec.cognition.models.associative.revision==1 and f.purpose.status~='completed' and f.purpose.bedConstruction.constructedWorkId==row.id)
        check('native_bed_'..face..'_observed_recovery_source',row and row.bedKey~=nil and row.sourceObservation.status=='confirmed')
    end
end
__bedFixture,__bedPlan,__bedBegin,__bedFinish,__bedCheck=fixture,plan,begin,finish,check

function __runBedCustodyCases()
    local R,P,C=SAO.ResourceProduction,SAO.ProceduralPlanning,SAO.Cognition
    local f=fixture('missing-mattress');plan(f);f.inventory:Remove(f.materials[12])
    check('missing_exact_mattress_cannot_admit_native_payment',begin(f)==false and not f.nativePayments and f.purpose.status~='completed')
    f=fixture('skill-refused');__nativeBed('skill',3)
    check('native_woodwork_four_required',#R.bedOptions(f.id,f.body)==0 and not f.nativePayments)
    f=fixture('blocked-footprint');plan(f);f.secondSquare.blocked=true;f.placementRefused=true
    begin(f)
    check('changed_full_footprint_has_no_native_construction',not f.nativePayments and not f.created)
    R.interrupt(f.id,f.body,'case-ended')
    f=fixture('direct-callback');f.body.primary=f.hammer;begin(f)
    local q=ISTimedActionQueue.getTimedActionQueue(f.body);local a=q.current
    check('direct_native_bed_create_cannot_pay',a.item:create(0,0,0,a.north,a.spriteName)==false and not f.nativePayments)
    R.interrupt(f.id,f.body,'case-ended')
    f=fixture('native-end');f.body.primary=f.hammer;begin(f);a=ISTimedActionQueue.getTimedActionQueue(f.body).current;a:start()
    check('early_native_bed_perform_refuses',a:perform()==false and not f.nativePayments)
    R.interrupt(f.id,f.body,'case-ended')
    f=fixture('ack');f.body.primary=f.hammer;begin(f);a=ISTimedActionQueue.getTimedActionQueue(f.body).current;a:start()
    f.body.holdCancellation=true
    check('pending_native_bed_ack_retains_single_work_claim',R.interrupt(f.id,f.body,'pending')==false and f.rec.resourceProductionWork~=nil and f.purpose.admission~=nil)
    f.body.holdCancellation=false
    check('native_bed_ack_retires_without_payment_credit',R.interrupt(f.id,f.body,'ack') and not f.rec.resourceProductionWork and f.purpose.status~='completed')
    f=fixture('successor');f.body.primary=f.hammer;begin(f);q=ISTimedActionQueue.getTimedActionQueue(f.body);a=q.current;a:start()
    local successor={character=f.body,Type='successor',isValidStart=function() return true end,begin=function() end}
    q.queue={successor};q.current=successor;f.body.farming=true
    R.interrupt(f.id,f.body,'replacement')
    check('bed_cancel_preserves_successor_queue_and_cosmetics',q.current==successor and q.queue[1]==successor and f.body.farming==true and not f.nativePayments)
    q.current=nil;q.queue={}
    f=fixture('saved-native');f.body.primary=f.hammer;begin(f);local saved=__nativeRoundtrip(f.rec);R.interrupt(f.id,f.body,'quiet')
    __records[f.id]=saved;f.rec=saved;f.agent.rec=saved;f.purpose=saved.proceduralPlanning.purposes[f.purpose.id]
    __reloadProduction()
    check('saved_native_bed_work_recovers_without_fabricated_parts',R.reconcileSaved(f.id,f.body) and not saved.resourceProductionWork
        and not f.purpose.admission and f.purpose.status~='completed' and not f.created)
    f=fixture('generic');f.body.primary=f.hammer;begin(f)
    check('generic_bed_result_cannot_complete_sleep_concern',P.recordResult(f.id,f.purpose.id,{owner='SAO.ResourceProduction',
        token='resource:bed-built',correlationId=f.rec.resourceProductionWork.id,status='completed',atHours=__hours})==false)
    R.interrupt(f.id,f.body,'quiet')
    f=fixture('forged-parts');begin(f);local row=finish(f);row.parts[2].sprite='carpentry_02_72'
    check('canonical_wrong_bed_part_refuses',R.outcome(f.id,row.id)==nil)
    f=fixture('replay');begin(f);row=finish(f);local count=#f.rec.cognition.experiences
    R.reconcileSaved(f.id,f.body);R.reconcileSaved(f.id,f.body)
    check('bed_construction_private_model_replay_once',#f.rec.cognition.experiences==count and count==1)
end
