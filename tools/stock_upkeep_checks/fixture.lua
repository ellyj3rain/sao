-- Actual native recipes/items/data/logic/effects. Explicit Lua body/map ports
-- forward material and skill/knowledge operations to the native receiver.
local NativeLogic,NativeManager=HandcraftLogic,CraftRecipeManager
local function nativeBody(body) return type(body)=="table" and body.nativeBody or body end
CraftRecipeManager={hasPlayerLearnedRecipe=function(recipe,body) return NativeManager.hasPlayerLearnedRecipe(recipe,nativeBody(body)) end,
    hasPlayerRequiredSkill=function(skill,body) return NativeManager.hasPlayerRequiredSkill(skill,nativeBody(body)) end,
    isItemValidForInputScript=function(slot,item,body) return NativeManager.isItemValidForInputScript(slot,item,nativeBody(body)) end,
    getValidInputScriptForItem=function(recipe,item,body) return NativeManager.getValidInputScriptForItem(recipe,item,nativeBody(body)) end}
HandcraftLogic={new=function(body,bench,object)
    local logic=NativeLogic.new(nativeBody(body),bench,object and (object.nativeObject or object))
    local data=logic:getRecipeData()
    local dataPort=setmetatable({luaCallOnCreate=function() data:luaCallOnCreate(nativeBody(body)) end,
        processDestroyAndUsedItems=function() data:processDestroyAndUsedItems(nativeBody(body)) end,
        getAllDestroyInputItems=function() return __omitDestroy and ArrayList.new() or data:getAllDestroyInputItems() end},
        {__index=function(_,key) return function(_,...) return data[key](data,...) end end})
    return setmetatable({getRecipeData=function() return dataPort end},{__index=function(_,key)
        return function(_,...) return logic[key](logic,...) end
    end})
end}
CharacterTrait={ALL_THUMBS="controlled"}
ActionSoundTime={ACTION_START="controlled"};DebugType={Action={warn=function() end},CraftLogic="controlled"}
function log() end
function showDebugInfoInChat() end
function convertToPZNetTable(t) return t end
function getText(t) return t end
function getCore() return {getGameMode=function() return "Sandbox" end} end
function getTimestampMs() return 10000 end
function isClient() return false end
function isServer() return false end
function removeItemTransaction() end
ISInventoryPage={dirtyUI=function() end}
ISTakeWaterAction={}
SAO.Cooking={};SAO.Pharmacology={};SAO.Controller={agents={}}
SAO.Locomotion={jobs={}}
ModData={data={}}
function ModData.get(k) return ModData.data[k] end
function ModData.getOrCreate(k) ModData.data[k]=ModData.data[k] or {};return ModData.data[k] end
SAO.Standing.mayTakeCurrent=function() return __permission~=false end
SAO.Standing.mayAttemptBelieved=function() return __permission~=false end
SAO.Needs.busy=function(body) local q=ISTimedActionQueue.getTimedActionQueue(body);return q.current~=nil or #q.queue>0 end
SAO.Needs.read=function() return {hunger=.1,thirst=.1,fatigue=.1} end
Actions={addOrDropItem=function(body,item) __addOrDrop(item,body.dropOutputs==true) end}
SAOJavaBridge.privateCarriedItems=function(_,body) return body:getInventory():getItems() end
SAO.Perception.knownPlaces=function(id) return __records[id].knownPlaces or {} end
SAO.ProceduralPlanning={}
function SAO.ProceduralPlanning.admitRecipeProduction(id,work)
    local p=__records[id].proceduralPlanning.purposes[work.purposeId]
    if p.admission then return false end
    local step=p.steps[p.cursor]
    if step.id~=work.purposeStepId then return false end
    p.admission={owner=step.owner,correlationId=work.id,stepId=step.id,target=step.target,at=__hours}
    return true
end
function SAO.ProceduralPlanning.consumeRecipeProductionResult(id,row)
    local p=__records[id].proceduralPlanning.purposes[row.purposeId]
    if p.lastResult==row.id then return true end
    if not p.admission or p.admission.correlationId~=row.id then return false end
    p.lastResult=row.id;p.admission=nil
    if row.status=="completed" and row.stockAvailable then p.cursor=p.cursor+1 end
    return true
end
local originalTimed=LuaTimedActionNew.new
LuaTimedActionNew.new=function(action,body)
    local a=originalTimed(action,body)
    a.scriptAction=action
    function a:finished() return self.nativeFinished==true end
    function a:isForceComplete() return false end
    function a:setOverrideHandModels() end
    function a:setOverrideHandModelsObject() end
    function a:overrideHandModels() end
    function a:setActionAnim() end
    function a:setAnimVariable() end
    return a
end
local function list(values)
    return {size=function() return #values end,get=function(_,n) return values[n+1] end,
        contains=function(_,v) for _,item in ipairs(values) do if item==v then return true end end;return false end}
end
function __stockFixture(kind,recipeId,operation,metric)
    local native=__stockReset(kind)
    __omitDestroy=false
    local id="stock-"..kind
    local rec={id=id,bodyOwnerToken="token-"..id,resourceProductionSequence=0}
    local square={getX=function() return 0 end,getY=function() return 0 end,getZ=function() return 0 end,canStand=function() return true end}
    local body={nativeBody=native.body,md={SAOPersonId=id,SAOExternalToken=rec.bodyOwnerToken},square=square}
    local cell={getGridSquare=function() return square end,getObjectList=function() return list({body}) end,getAddList=function() return list({}) end}
    function body:getModData() return self.md end
    function body:getInventory() return self.nativeBody:getInventory() end
    function body:getCurrentSquare() return self.square end
    function body:getCell() return cell end
    function body:getX() return .5 end
    function body:getY() return .5 end
    function body:getZ() return 0 end
    function body:isExistInTheWorld() return true end
    for _,method in ipairs({"isDead","isAsleep","isAttacking","isAiming","isClimbing","isClimbingRope","hasTrait","isWearingAwkwardGloves","isSitOnGround"}) do body[method]=function() return false end end
    function body:getVehicle() return nil end
    function body:isTimedActionInstant() return true end -- controlled duration only
    function body:setIsFarming() end
    function body:setTimedActionToRetrigger() end
    function body:StopAllActionQueue() end
    function body:StartAction(a)
        self.started=a
        if self.consumeSuccessorOutputs and a.scriptAction.Type=="ISBaseTimedAction" then
            local items=self:getInventory():getItems()
            for n=items:size()-1,0,-1 do local item=items:get(n)
                if item:getFullType()=="Base.Plank" then self:getInventory():Remove(item) end
            end
        end
    end
    function body:faceThisObject() end
    function body:shouldBeTurning() return false end
    function body:setSitOnGround() end
    function body:getEmitter() return {isPlaying=function() return false end,playSound=function() return 1 end} end
    function body:playSound() return 1 end
    function body:stopOrTriggerSound() end
    local world={getWorld=function() return "isolated-stock-world" end,getCell=function() return cell end}
    __world=world;__hours=100;__permission=true;__records[id]=rec;SAO.Body.active[id]=body
    SAO.Controller.agents[id]={rec=rec,state="IDLE"}
    local recipe=ScriptManager.instance:getCraftRecipe(recipeId)
    local desiredType=recipeId=="Base.SawLogs" and "Base.Plank" or "Base.CrudeWhetstone"
    local demand={id="demand-1",consumerId="consumer-1",kind=operation,sourceRevision="registered-source-1",
        desiredType=desiredType,desiredAmount=1,consumerRecipeId=recipeId=="Base.SawLogs" and "Base.Wood_Bed" or "Base.SharpenBlade"}
    if operation=="recipe-upkeep" then
        local target=native.items.Saw or native.items.SmallSaw or native.items.BlowTorch or native.items.Hammer or native.items.Scissors
        demand.targetItemId=tostring(target:getID());demand.desiredState={metric=metric or "condition"}
        for n=0,recipe:getInputs():size()-1 do if CraftRecipeManager.isItemValidForInputScript(recipe:getInputs():get(n),target,body) then
            demand.targetSlotIndex=recipe:getIndexForIO(recipe:getInputs():get(n));break
        end end
    end
    local anchor,workplace
    if native.object then
        local object={nativeObject=native.object,getSquare=function() return square end,
            isUsingPlayer=function(_,b) return native.object:isUsingPlayer(nativeBody(b)) end,
            getUsingPlayer=function() local using=native.object:getUsingPlayer();return using==body.nativeBody and body or using end,
            setUsingPlayer=function(_,b) native.object:setUsingPlayer(b and nativeBody(b) or nil) end}
        workplace={object=object,bench=native.bench,key="observed-surface",revision="seen-1",authorized=true}
        anchor={key=workplace.key,revision=workplace.revision,x=0,y=0,z=0}
        SAO.Perception.recipeWorkplace=function(_,b,a) return workplace end
    else SAO.Perception.recipeWorkplace=nil end
    -- Exact selected native input identities; no synthetic stock state.
    local policy=SAO.RecipePolicy.describe(recipe,body,demand,workplace)
    if native.bench then native.object:setUsingPlayer(native.body) end
    local selected,why=SAO.RecipePolicy.selectInputs(policy,body,{ownerId=id,purposeId=demand.id,canUse=function() return true end},native.containers)
    if native.bench then native.object:setUsingPlayer(nil) end
    if not selected then error("native fixture selection refused "..tostring(why and why[1] and why[1].reason)) end
    local inputs={}
    for _,slot in ipairs(selected.slots) do
        local row={index=slot.index,items={}}
        for n=0,slot.items:size()-1 do local item=slot.items:get(n);row.items[#row.items+1]={itemId=tostring(item:getID()),itemType=item:getFullType()} end
        inputs[#inputs+1]=row
    end
    local step={id="produce-1",verb="produce",owner="SAO.ResourceProduction",productionKind=operation,
        token=operation=="recipe-stock" and "resource:recipe-produced" or "resource:recipe-maintained",
        target=recipeId,recipeId=recipeId,sourceRevision=demand.sourceRevision,category="material",status="available",
        recipeInputs=inputs,recipeDemand=demand,recipeWorkplace=anchor}
    local purpose={id="purpose-1",status="maintained",cursor=1,materialWork={entryKey="held-work-1",recipeDemand=demand},
        steps={step,{id="resume-consumer",owner="original-consumer",status="available"}}}
    rec.proceduralPlanning={purposes={[purpose.id]=purpose}}
    return {id=id,rec=rec,body=body,native=native,recipe=recipe,step=step,purpose=purpose,policy=policy}
end
function __stockBegin(f)
    return SAO.ResourceProduction.begin(f.id,f.body,f.step,{purposeId=f.purpose.id,purposeStepId=f.step.id})
end
function __stockFinish(f,successor)
    local q=ISTimedActionQueue.getTimedActionQueue(f.body)
    local action=q.current
    if not action then return nil end
    print("ADMISSION_VALID",action:isValid(),action:isValidStart())
    print("START",action:start(),action.craftStarted);action.action.nativeFinished=true
    if successor then
        local nextAction=ISBaseTimedAction:new(f.body);nextAction.isValid=function() return true end
        ISTimedActionQueue.add(nextAction)
    end
    print("PERFORM",action:perform());print("COMPLETE",action:complete())
    print("REMAINING",f.rec.resourceProductionWork and f.rec.resourceProductionWork.status,q.current and q.current.Type)
    return f.rec.resourceProductionOutcomes and f.rec.resourceProductionOutcomes[#f.rec.resourceProductionOutcomes]
end
