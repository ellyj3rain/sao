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
BaseCraftingLogic={callLuaBool=function(name,params)
    if name=='BuildRecipeCode.stairs.OnIsValid' then return BuildRecipeCode.stairs.OnIsValid(params) end
    if name=='BuildRecipeCode.floor.OnIsValid' then return BuildRecipeCode.floor.OnIsValid(params) end
    return BuildRecipeCode.doorFrame.OnIsValid(params)
end,callLuaObject=function(name,params)
    if name=='BuildRecipeCode.stairs.OnCreate' then return BuildRecipeCode.stairs.OnCreate(params) end
    if name=='BuildRecipeCode.floor.OnCreate' then return BuildRecipeCode.floor.OnCreate(params) end
end}
luautils={stringStarts=function(s,prefix) return s:sub(1,#prefix)==prefix end}
local properties={has=function() return false end}
local function sprite(name)
    return {name=name,LoadSingleTexture=function() end,getProperties=function() return properties end,
        getType=function() return 'normal' end}
end
IsoSprite={new=function() return sprite() end}
function getSprite(name)
    local result=sprite(name);function result:getType() return __nativeShelter('spriteType',name) end
    function result:getProperties() return {has=function(_,key)
        if key=='DOOR_WALL_N' or key=='DOOR_WALL_W' then return __nativeShelter('spriteHasProp',name,key) end
        return false
    end} end
    return result
end
local baseInstanceOf=instanceof
function instanceof(object,kind)
    return kind=='IsoObject' and type(object)=='table' and object.kind=='IsoThumpable' or baseInstanceOf(object,kind)
end
local entities={'Base.WoodenWallFrame','Base.WoodenWallLvl1','Base.WoodenWallLvl2','Base.WoodenWallLvl3',
 'Base.WoodDoorFrameLvl1','Base.WoodDoorFrameLvl2','Base.WoodDoorFrameLvl3','Base.WoodenDoorLvl1','Base.WoodenDoorLvl2','Base.WoodenDoorLvl3'}
if __surfaceCases then for _,id in ipairs({'Base.WoodFloorLvl1','Base.WoodFloorLvl2','Base.WoodFloorLvl3'}) do entities[#entities+1]=id end end
if __stairCases then entities[#entities+1]='Base.Wood_Stairs' end
local policies={}
local nativeBridge=__nativeShelter
function __nativeShelter(op,a,b) if op=='spriteProp' then print('native property '..tostring(a)..' '..tostring(b)) end;return nativeBridge(op,a,b) end
for _,id in ipairs(entities) do
    local inputs={}
    for j=0,(id:find("WoodenDoorLvl",1,true) and 4 or 2) do
        local index=j
        inputs[#inputs+1]={index=index,entityId=id,getResourceType=function() return ResourceType.Item end,
            getIntAmount=function() return __nativeShelter('policyCount',id,index) end,
            isKeep=function() return __nativeShelter('policyKeep',id,index) end}
    end
    local recipe={entityId=id}
    function recipe:getInputs() return list(inputs) end
    function recipe:getScriptObjectFullType() return __nativeShelter('entityRecipeId',id) end
    function recipe:getRequiredSkillCount() return __nativeShelter('policySkillCount',id) end
    function recipe:getRequiredSkill(j) return {entityId=id,index=j} end
    function recipe:getTime() return __nativeShelter('policyTime',id) end
    function recipe:getName() return id:sub(6) end
    function recipe:getHighestRelevantSkill() return Perks.Woodwork end
    function recipe:getHighestRelevantSkillLevel() return 8 end
    function recipe:getToolLeft() return nil end
    function recipe:getToolRight() return {canUseItem=function(_,name) return name=='Base.Hammer' end} end
    function recipe:getTimedActionScript() return nil end
    local parent={getScriptObjectFullType=function() return id end}
    function parent:getComponentScriptFor(kind)
        return nil
    end
    local cfg={getParent=function() return parent end,getPreviousStages=function() return list(id:find("WoodenWallLvl",1,true) and {"WoodenWallFrame","MetalWallFrame"} or {}) end,
        getName=function() return id:sub(6) end,getBonusHealth=function() return __nativeShelter('spriteProp',id,'getBonusHealth') end}
    function cfg:getFace() return {getLightsourceOffsetX=function() return 0 end,getLightsourceOffsetY=function() return 0 end,getLightsourceOffsetZ=function() return 0 end} end
    function cfg:getLightsourceTagItem() return list() end
    setmetatable(cfg,{__index=function(_,key)
        return function() return __nativeShelter('spriteProp',id,key) end
    end})
    local faces={}
    for _,orientation in ipairs(id=='Base.Wood_Stairs' and {'S','W'} or {'N','W','N_OPEN','W_OPEN'}) do
        local key=orientation
        faces[key]={getWidth=function() return __nativeShelter('nativeFaceWidth',id,key) end,getHeight=function() return __nativeShelter('nativeFaceHeight',id,key) end,
            getzLayers=function() return 1 end,getFaceName=function() return key end,
            getTileInfo=function(_,x,y,z) return {getSpriteName=function() return __nativeShelter('partSprite',key,id=='Base.Wood_Stairs' and (key=='S' and x or y) or 0) end,isBlocking=function() return false end} end}
    end
    local info={getScript=function() return cfg end,getRecipe=function() return {getCraftRecipe=function() return recipe end} end,
        getName=function() return id:sub(6) end,getFace=function(_,key) return (key=='S' or key==2) and faces.S or (key=='N' or key==0) and faces.N or (key=='W' or key==1) and faces.W or key=='N_OPEN' and faces.N_OPEN or key=='W_OPEN' and faces.W_OPEN or nil end}
    policies[id]={info=info,recipe=recipe,inputs=inputs}
end
SpriteConfigManager={GetObjectInfoList=function()
    local out={};for _,id in ipairs(entities) do out[#out+1]=policies[id].info end;return list(out)
end}
CraftRecipeManager={
    hasPlayerLearnedRecipe=function(recipe,body) return body.recipeUnknown~=true and __nativeShelter('policyLearned',recipe.entityId) end,
    hasPlayerRequiredSkill=function(skill) return __nativeShelter('policySkill',skill.entityId,skill.index) end,
    getValidInputScriptForItem=function(recipe,item)
        for j=0,(recipe.entityId:find("WoodenDoorLvl",1,true) and 4 or 2) do if item:getID()>=100 and item:getID()<132 and __nativeShelter('inputMatches',recipe.entityId..'|'..j,item:getID()) then return policies[recipe.entityId].inputs[j+1] end end
    end}
local active
local function nativeManual(data,input,out)
    for id in __nativeShelter('manualIds',data,input.index):gmatch('[^,]+') do out:add(active.materialById[tonumber(id)]) end
    return out
end
BuildLogic={new=function(body)
    __nativeShelter('newLogic')
    local logic={body=body,manualMode=false}
    function logic:setContainers(v) self.containers=v;__nativeShelter('containers') end
    function logic:setRecipe(r) self.recipe=r;__nativeShelter('setRecipe',r.entityId) end
    function logic:getRecipe() return self.recipe end
    function logic:setManualSelectInputs(v) self.manualMode=v;__nativeShelter('manualMode',v) end
    function logic:isManualSelectInputs() return self.manualMode end
    function logic:clearManualInputs() __nativeShelter('clearManual') end
    function logic:setManualInputsFor(input,items)
        local ids={};for i=0,items:size()-1 do ids[#ids+1]=tostring(items:get(i):getID()) end
        return __nativeShelter('manual',input.index,table.concat(ids,','))
    end
    function logic:canPerformCurrentRecipe() return __nativeShelter('eligible') end
    function logic:getPossibleCraftCount() return __nativeShelter('possible') end
    function logic:startCraftAction(action) __nativeShelter('start') end
    function logic:stopCraftAction() __nativeShelter('stop') end
    function logic:getModelHandOne() return 'Hammer' end
    function logic:getModelHandTwo() return nil end
    function logic:getAllConsumedItems() return self:getRecipeData():getAllConsumedItems() end
    function logic:performCurrentRecipe()
        active.nativePayments=(active.nativePayments or 0)+1
        return __nativeShelter('perform')
    end
    local function data(kind)
        return {getRecipe=function() return kind~='progress' or __nativeShelter('progressRecipe') and logic.recipe or nil end,
            getManualInputsFor=function(_,input,out) return nativeManual(kind,input,out) end,
            getAllConsumedItems=function()
                local out={};for _,item in ipairs(active.materials) do if __nativeShelter('consumed',item:getID()) then out[#out+1]=item end end;return list(out)
            end,
            getAllKeepInputItems=function()
                local out={};for _,item in ipairs(active.materials) do if __nativeShelter('kept',item:getID()) then out[#out+1]=item end end;return list(out)
            end,
            getAllRecordedConsumedItems=function() return list() end,
            luaCallOnCreate=function() end,
            processDestroyAndUsedItems=function()
                __nativeShelter('process')
                for _,item in ipairs(active.materials) do
                    item.condition=__nativeShelter('condition',item:getID())
                    if not __nativeShelter('held',item:getID()) then item:getContainer():Remove(item) end
                end
            end}
    end
    function logic:getRecipeData() return data('current') end
    function logic:getRecipeDataInProgress() return data('progress') end
    return logic
end}
GameEntityFactory={CreateIsoObjectEntity=function(object,entity)
    if __stairCases then __nativeShelter('factoryAt',object.sprite,object:getX()..','..object:getY()..','..object:getZ()) else __nativeShelter('factory',object.sprite) end
    object.nativeFactory=true;object.entityId=active.entityId
    __nativeShelter('creationFlags',object.builder)
end}
IsoThumpable={new=function(cell,square,name,fourth,fifth,sixth)
    local north;if type(fourth)=='string' then north=fifth else north=fourth end
    local object={kind='IsoThumpable',square=square,sprite=name,north=north,open=false}
    function object:getX() return self.square:getX() end
    function object:getY() return self.square:getY() end
    function object:getZ() return self.square:getZ() end
    function object:getSpriteName() return self.sprite end
    function object:getTextureName() return self.sprite end
    function object:getSprite() return getSprite(self.sprite) end
    function object:getObjectIndex() for n,o in ipairs(self.square.objects) do if o==self then return n-1 end end;return -1 end
    function object:getType() return __nativeShelter('spriteType',self.sprite) end
    function object:getNorth() return self.north end
    function object:getName() return self.entityId and self.entityId:sub(6) end
    function object:isDoorFrame() return self:getType()=='doorFrN' or self:getType()=='doorFrW' end
    function object:isDoor() return self:getType()=='doorN' or self:getType()=='doorW' end
    function object:isDestroyed() return (self.health or 500)<=0 end
    function object:IsOpen() return self.open end
    function object:ToggleDoor(body)
        if not active.toggleRefused then self.open=not self.open end
    end
    function object:getCell() return active.cell end
    function object:getEntityScript() return {getFullName=function() return object.entityId end} end
    function object:getProperties() return {has=function(_,key)
        if key=='DOOR_WALL_N' or key=='DOOR_WALL_W' then return __nativeShelter('spriteHasProp',object.sprite,key) end
        if ({solid=true,solidtrans=true,doorN=true,doorW=true,WallN=true,WallNTrans=true,WallW=true,WallWTrans=true,WallNW=true,
            HoppableN=true,HoppableW=true,TallHoppableN=true,TallHoppableW=true,solidfloor=true})[key] then
            return __nativeShelter('spriteHasFlag',object.sprite,key)
        end
        return false
    end} end
    function object:getSquare() return self.square end
    function object:getFluidContainer() return self.fluid end
    function object:setMaxHealth(v) self.maxHealth=v end
    function object:getMaxHealth() return self.maxHealth end
    function object:setHealth(v) self.health=v end
    function object:getHealth() return self.health or 500 end
    function object:setBreakSound(v) self.breakSound=v end
    function object:setExplored(v) self.explored=v end
    function object:transmitCompleteItemToClients() self.sent=true end
    function object:invalidateRenderChunkLevel() end
    return object
end}
local function roofSquare(f,x,y)
    local s={x=x,y=y,z=0,objects={}}
    function s:getX() return self.x end
    function s:getY() return self.y end
    function s:getZ() return self.z end
    function s:getObjects() return list(self.objects) end
    function s:getSpecialObjects() return list(self.objects) end
    function s:transmitRemoveItemFromSquare(object) for i,v in ipairs(self.objects) do if v==object then table.remove(self.objects,i);return i-1 end end;return -1 end
    function s:getProperties() return properties end
    function s:getN() return f.cell:getGridSquare(self.x,self.y-1,self.z) end
    function s:getW() return f.cell:getGridSquare(self.x-1,self.y,self.z) end
    function s:getModData() self.md=self.md or {};return self.md end
    function s:canStand() return true end
    function s:has() return false end
    function s:isVehicleIntersecting() return false end
    function s:isSolid() return false end
    function s:isSolidTrans() return false end
    function s:isFree() return not self.blocked end
    function s:isFreeOrMidair() return self:isFree() end
    function s:hasFloor() return true end
    function s:isOutside() return true end
    function s:AddSpecialObject(object)
        self.objects[#self.objects+1]=object;f.created=object;f.placements=(f.placements or 0)+1
        if f.entityId=='Base.WoodenWallFrame' then f.mode='wall';f.previous=object
        elseif f.entityId:find('WoodDoorFrame',1,true) then f.mode='door-leaf';f.previous=object
        elseif f.entityId:find('WoodenDoorLvl',1,true) then f.mode='door';f.previous=object
        elseif f.entityId:find('WoodFloorLvl',1,true) then f.mode='floor';f.previous=nil
        else f.mode='wall';f.previous=object end
        f.siteRevision=f.siteRevision..'-new'
    end
    function s:RecalcAllWithNeighbours() end
    f.cell.squares[x..':'..y..':0']=s
    return s
end

local function fixture(id,orientation,nested)
    orientation=orientation or 'N';local entityId=nested or 'Base.WoodenWallFrame';nested=false;__nativeShelter('reset',entityId);__nativeShelter('face',orientation)
    local f=__plumbingFixture(id,false,false);active=f;f.entityId=entityId;f.orientation=orientation
    f.inventory.items={};f.materials={};f.materialById={}
    for itemId=100,99+__nativeShelter('count') do
        local item=__boardingItem(__nativeShelter('type',itemId):sub(6),itemId,f.inventory)
        item.condition=__nativeShelter('condition',itemId)
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
    f.siteSquare=roofSquare(f,10,20);f.secondSquare=roofSquare(f,10-(orientation=='W' and 1 or 0),20-(orientation=='N' and 1 or 0))
    local ax,ay=10,20
    f.approach=(ax==10 and ay==20) and f.siteSquare or roofSquare(f,ax,ay);f.body.here=f.approach;f.body.x,f.body.y,f.body.z=ax+.5,ay+.5,0
    function f.body:isBuildCheat() return false end
    function f.body:faceLocation() end
    function f.body:faceLocationF() end
    function f.body:getPerkLevel() return 8 end
    f.rec.permissionDenied=false
    f.siteRevision='12345678-1234-1234-1234-123456789abc'
    local modes={};for _,kind in ipairs({'wall-frame','wall','door-frame','door-leaf'}) do modes[kind]=true end
    f.mode=entityId=='Base.Wood_Stairs' and 'stairs' or entityId=='Base.WoodenWallFrame' and 'wall-frame' or entityId:find('WoodenWallLvl',1,true) and 'wall'
        or entityId:find('WoodFloorLvl',1,true) and 'floor'
        or entityId:find('WoodDoorFrame',1,true) and 'door-frame' or 'door-leaf'
    if f.mode=='wall' or f.mode=='door-leaf' then
        local previousId=f.mode=='wall' and 'Base.WoodenWallFrame' or 'Base.WoodDoorFrameLvl1'
        local prior=IsoThumpable.new(f.cell,f.siteSquare,__nativeShelter('otherSprite',previousId..'|'..orientation),orientation=='N',{})
        prior.entityId=previousId;prior.nativeFactory=true;prior.health=500
        f.siteSquare.objects[#f.siteSquare.objects+1]=prior;f.previous=prior;f.initialStage=prior
    end
    local function observed()
        return {key='shelter-edge:10:20:0:10:20:'..orientation,revision=f.siteRevision,face=orientation,mode=f.mode,
            previousEntity=f.previous and f.previous.entityId or '',x=10,y=20,z=0,approachX=ax,approachY=ay,approachZ=0,
            insideX=10,insideY=20,originX=10,originY=20,roof=true}
    end
    SAOJavaBridge.worldShelterSites=function(_,body) return body==f.body and {observed()} or {} end
    SAOJavaBridge.worldShelterPlacementSquare=function(_,body,key,revision)
        return body==f.body and not f.placementRefused and key==observed().key and revision==f.siteRevision
            and body:getCurrentSquare()==f.approach and f.siteSquare or nil
    end
    SAOJavaBridge.worldShelterPreviousStage=function(_,body,key,revision)
        return body==f.body and revision==f.siteRevision and f.previous or nil
    end
    SAOJavaBridge.worldShelterCreated=function(_,body,object,previous,entity,x,y,z,face)
        return body==f.body and object==f.created and object.nativeFactory and object.entityId==entity
            and __nativeShelter('createdCount')==1 and __nativeShelter('createdEntity')==entity
            and face==orientation and not f.createdRefused
    end
    SAOJavaBridge.worldShelterDoor=function(_,body,key,revision)
        return body==f.body and revision==f.siteRevision and f.created and f.created:isDoor() and f.created or nil
    end
    SAOJavaBridge.worldShelterCover=function(_,body,x,y,z)
        return {reached=body==f.body and math.floor(body:getX())==x and math.floor(body:getY())==y,
            roof=true,room=f.enclosed==true,outside=f.enclosed~=true,regionKnown=f.regionKnown~=false,
            enclosed=f.enclosed==true,fullyRoofed=true,roomId=f.enclosed and 'actual-region' or ''}
    end
    SAOJavaBridge.recoveryPlaces=function(_,body)
        return {actorId=id,status='available',places={{key='ground:10:20:'..id,kind='ground',available=true,x=10.5,y=20.5,z=0}}}
    end
    SAO.Locomotion.order=function(pid,body,x,y,z)
        SAO.Locomotion.jobs[pid]={body=body,goal={x=x,y=y,z=z},done=false};return true
    end
    SAO.Locomotion.tick=function(pid) local job=SAO.Locomotion.jobs[pid]
        if f.arrived then f.body.x,f.body.y,f.body.z=job.goal.x,job.goal.y,job.goal.z;f.body.here=f.cell:getGridSquare(math.floor(job.goal.x),math.floor(job.goal.y),job.goal.z);job.done,job.result=true,'arrived' end
    end
    assert(SAO.Perception.observeShelterSites(id,f.body));return f
end
local function plan(f)
    local option
    for _,offered in ipairs(SAO.ResourceProduction.shelterOptions(f.id,f.body)) do if offered.entityId==f.entityId then option=offered;break end end
    if not option then print('site count '..#SAO.Perception.shelterSites(f.id,f.body)..' mode '..tostring(f.mode)) end
    assert(option,'native shelter option absent')
    local p,step=SAO.ProceduralPlanning.planShelterConstruction(f.id,{recoveryKind='sleep',fatigue=.65,atHours=__hours,options={option},materialSources={}})
    f.purpose,f.step=p,step;if not p then print("planner refused "..tostring(option.entityId)) end;return p,step
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
        a:start();a.action.nativeFinished=true;local performed=a:perform();print('action '..tostring(a.Type)..' performed '..tostring(performed)..' claim '..tostring(f.rec.resourceProductionWork and f.rec.resourceProductionWork.stage))
        if a.Type=='ISEquipWeaponAction' or a.Type=='ISOpenCloseDoor' then print('complete '..tostring(a:complete())) end
        assert(q.current~=a,'native bed action retained '..a.Type)
    end
    SAO.ResourceProduction.tick(f.id,f.body)
    local rows=f.rec.resourceProductionOutcomes or {};return rows[#rows]
end
local function check(name,value) print(name..'='..tostring(value==true)) end
__shelterFixture,__shelterPlan,__shelterBegin,__shelterFinish,__shelterCheck=fixture,plan,begin,finish,check
__shelterSquare=roofSquare

function __runShelterFocusedCases()
    local R,P,C,M=SAO.ResourceProduction,SAO.ProceduralPlanning,SAO.Cognition,SAO.CognitiveModels
    C.ensureGameDefaults()
    local f=fixture('shelter-alternatives','N','Base.WoodDoorFrameLvl1')
    local actual=M.interpretPlans;local seen={}
    M.interpretPlans=function(model,state,candidates,context)
        local view,reason=actual(model,state,candidates,context)
        seen[model]={count=#candidates,first=candidates[1].id,view=view};return view,reason
    end
    local option=R.shelterOptions(f.id,f.body)[1];local choices={}
    for index=1,32 do local copy={} for k,v in pairs(option) do copy[k]=v end;copy.distance=index;choices[index]=copy end
    local p,step=P.planShelterConstruction(f.id,{recoveryKind='sleep',fatigue=.65,atHours=__hours,options=choices,materialSources={}})
    M.interpretPlans=actual
    check('thirty_two_offers_use_actual_continue_plus_fifteen_models',p and step and p.omittedAlternatives==17
        and seen.ordinary and seen.associative and seen.ordinary.count==16 and seen.associative.count==16
        and seen.ordinary.first=='continue' and seen.associative.first=='continue'
        and seen.ordinary.view~=nil and seen.associative.view~=nil)
    if __selectedShelterControl=='candidate-bound' then return end
    f=fixture('shelter-ack','N','Base.WoodDoorFrameLvl1');f.body.primary=f.hammer;begin(f)
    local a=ISTimedActionQueue.getTimedActionQueue(f.body).current;a:start();f.body.holdCancellation=true
    check('shelter_pending_ack_keeps_exact_work_and_admission',R.interrupt(f.id,f.body,'pending')==false
        and f.rec.resourceProductionWork~=nil and f.purpose.admission~=nil and not f.nativePayments)
    f.body.holdCancellation=false
    check('shelter_quiet_ack_retires_without_construction_credit',R.interrupt(f.id,f.body,'ack')
        and not f.rec.resourceProductionWork and not f.purpose.admission and f.purpose.status~='completed' and not f.nativePayments)
    f=fixture('shelter-successor','N','Base.WoodDoorFrameLvl1');f.body.primary=f.hammer;begin(f)
    local q=ISTimedActionQueue.getTimedActionQueue(f.body);a=q.current;a:start()
    local successor={character=f.body,Type='successor',isValidStart=function()return true end,begin=function()end}
    q.queue={successor};q.current=successor;f.body.farming=true;R.interrupt(f.id,f.body,'replacement')
    check('shelter_cancel_preserves_successor_queue_and_cosmetics',q.current==successor and q.queue[1]==successor
        and f.body.farming==true and not f.nativePayments)
    q.current=nil;q.queue={}
    f=fixture('shelter-saved-work','N','Base.WoodDoorFrameLvl1');f.body.primary=f.hammer;begin(f)
    local saved=__nativeRoundtrip(f.rec);R.interrupt(f.id,f.body,'quiet')
    __records[f.id]=saved;f.rec=saved;f.agent.rec=saved;f.purpose=saved.proceduralPlanning.purposes[f.purpose.id]
    __reloadProduction()
    check('saved_shelter_work_reconciles_without_fabricated_parts_or_passage',R.reconcileSaved(f.id,f.body)
        and not saved.resourceProductionWork and not f.purpose.admission and f.purpose.status~='completed'
        and not f.created and not saved.recoveryExperiences)
end

function __runShelterConstructionCases()
    local R,P,C=SAO.ResourceProduction,SAO.ProceduralPlanning,SAO.Cognition
    C.ensureGameDefaults();SAO.Log={line=function(_,message) print(message) end}
    for i,entity in ipairs(entities) do for _,face in ipairs({'N','W'}) do
        local f=fixture('family-'..i..'-'..face,face,entity)
        local admitted=begin(f)
        print('begin stage '..tostring(f.rec.resourceProductionWork and f.rec.resourceProductionWork.stage)..' q '..tostring(ISTimedActionQueue.getTimedActionQueue(f.body).current and ISTimedActionQueue.getTimedActionQueue(f.body).current.Type))
        check('native_family_'..i..'_'..face..'_admission',admitted and f.purpose and f.purpose.admission and not f.nativePayments)
        local row=finish(f)
        print('family result '..entity..' '..face..' '..tostring(row and row.status)..' '..tostring(row and row.detail)..' complete='..tostring(row and row.nativeCompleted)..' consumed='..tostring(row and row.inputsConsumed)..' kept='..tostring(row and row.toolRetained))
        check('native_family_'..i..'_'..face..'_payment_stage',row and row.status=='completed' and row.inputsConsumed
            and row.toolRetained and #row.parts==1 and f.nativePayments==1 and row.entityId==entity and row.face==face
            and (not f.initialStage or f.mode=='door' or not f.siteSquare:getObjects():contains(f.initialStage)))
        check('native_family_'..i..'_'..face..'_private_feedback',row and f.rec.cognition and #f.rec.cognition.experiences==1
            and f.rec.cognition.experiences[1].kind=='shelter-construction' and f.rec.cognition.models.ordinary.revision==1
            and f.rec.cognition.models.associative.revision==1 and f.purpose.status~='completed' and not f.rec.recoveryExperiences)
    end end
end
