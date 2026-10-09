-- Native preparation belongs to the selected person's maintained purpose.
-- Source actions own hand and clothing changes; Locomotion owns movement.
SAO = SAO or {}
SAO.LeisurePreparation = SAO.LeisurePreparation or {}
local Q=SAO.LeisurePreparation
if not SAO.LeisureSeating and type(require)=="function" then pcall(require,"SAO_LeisureSeating") end
if Q.reset then Q.reset("module-reload") end
local runtime={}
local removeOwnedAction
local PINS={ISEquipWeaponAction="5aaf0e6942d83caed3df3acae63aa10c3b77bf9618208067b81d579a6e2bf66f",
    ISWearClothing="146c66743d8593581bae58e7e1d954886f73a1e6b8bc51720fd2271afbb50524",
    ISUnequipAction="e0a3d66680ab19c1704152991de1b8742531d90cdc129fdb3f570479b4a07784"}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function copy(v,depth)
    depth=depth or 0
    if type(v)=="string" or type(v)=="boolean" then return v end
    if type(v)=="number" then return finite(v) and v or nil end
    if type(v)~="table" or depth>=8 then return nil end
    local r={} for k,x in pairs(v) do if type(k)=="string" or type(k)=="number" then r[k]=copy(x,depth+1) end end
    return r
end
local function rec(id) return SAO.Identity and SAO.Identity.get(id) end
local function owner(name)
    if name=="SAO.Leisure" then return SAO.Leisure end
    if name=="SAO.LeisureMusic" then return SAO.LeisureMusic end
    if name=="SAO.LeisureArt" then return SAO.LeisureArt end
    if name=="SAO.LeisureExercise" then return SAO.LeisureExercise end
    if name=="SAO.LeisureGames" then return SAO.LeisureGames end
    if name=="SAO.LeisureRadio" then return SAO.LeisureRadio end
    if name=="SAO.LeisureLifestyle" then return SAO.LeisureLifestyle end
end
local function purposeAlive(a)
    local offer=a.selection
    return SAO.ProceduralPlanning.leisurePreparationPurpose(a.id,a.row.purposeId,a.row.ownerName,
        offer.id,offer.activity,offer.sourceId,offer.itemKey)~=nil
end
local function bodyOwned(a)
    return rec(a.id)==a.record and SAO.Needs.ownsRecoveryBody(a.id,a.body)
        and a.body:getModData().SAOExternalToken==a.bodyToken and a.row.bodyToken==a.bodyToken
        and a.record.bodyOwner==a.bodyOwner and a.record.bodyOwnerToken==a.ownerToken
end
local function live(a)
    return runtime[a.id]==a and a.record.leisurePreparation==a.row
        and a.row.status=="preparing" and bodyOwned(a)
        and not a.body:isAsleep() and not a.body:getVehicle() and purposeAlive(a)
end
local function item(body,key,kind)
    local items=SAOJavaBridge:privateCarriedItems(body)
    for i=0,items:size()-1 do local v=items:get(i);local id=tostring(v:getID())
        if (id==key or "item:"..id..":"..v:getFullType()==key) and (not kind or v:getFullType()==kind) then return v end
    end
end
local function same(x,y)
    for _,k in ipairs({"id","sourceId","revision","activity","itemKey","itemType","objectKey","runtimeInstance"}) do
        if x[k]~=y[k] then return false end
    end return true
end
local function current(a)
    local provider=owner(a.row.ownerName);local query=provider and (provider.intentOffers or provider.offers)
    if not query then return nil end
    for _,v in ipairs(query(a.id,a.body) or {}) do if same(v,a.selection) then return v end end
end
local function finish(a,status,reason)
    a.row.status=status;a.row.reason=reason;a.row.endedAtHours=SAO.History.countyHours()
    runtime[a.id]=nil
end
function Q.interrupt(id,body,reason)
    local a=runtime[id];local r=rec(id);local row=r and r.leisurePreparation
    if a and a.body==body then
        if a.seating and SAO.LeisureSeating then SAO.LeisureSeating.interrupt(id,body,reason) end
        if a.action and ISTimedActionQueue.hasAction(a.action) then
            if a.action.action then
                a.action:stop();a.action:forceStop()
            else a.action:forceCancel() end
            removeOwnedAction(a)
        end
        if a.route and SAO.Locomotion.jobs[id]==a.route then SAO.Locomotion.cancel(id) end
        finish(a,"interrupted",reason or "preparation interrupted")
        return true
    elseif row and row.status=="preparing" and SAO.Needs.ownsRecoveryBody(id,body) then
        if SAO.LeisureSeating then SAO.LeisureSeating.interrupt(id,body,reason) end
        row.status="interrupted";row.reason=reason or "preparation runtime unavailable"
        row.endedAtHours=SAO.History.countyHours();return true
    end return false
end
removeOwnedAction=function(a)
    if not a.action or not ISTimedActionQueue.hasAction(a.action) then return end
    local queue=ISTimedActionQueue.getTimedActionQueue(a.body)
    if queue.current==a.action then queue:onCompleted(a.action)
    else queue:removeFromQueue(a.action) end
end
local function actionClass(name,a)
    if not SAOJavaBridge or not SAOJavaBridge.nativeLeisureActionSource or not loadstring or not setfenv then return nil end
    local env={ISInventoryPage={renderDirty=false},getPlayerHotbar=function()return nil end,
        getPlayerInventory=function()return {refreshBackpacks=function()end} end}
    -- Native stop cleanup normally clears the entire player queue. This actor
    -- adapter retires only its preparation action through the native queue.
    env.ISBaseTimedAction=ISBaseTimedAction:derive("SAOLeisurePreparationBase")
    env.ISBaseTimedAction.stop=function(self)
        if self==a.action and self.character==a.body then
            removeOwnedAction(a);self.character:setIsFarming(false)
        end
    end
    env._G=env;setmetatable(env,{__index=_G})
    env.require=function(path) if path~="TimedActions/ISBaseTimedAction" then error("unaudited preparation dependency") end end
    for _,dependency in ipairs({"ISWearClothing","ISEquipWeaponAction","ISUnequipAction"}) do
        local source=SAOJavaBridge:nativeLeisureActionSource(dependency)
        if not source or source.className~=dependency or source.sha256~=PINS[dependency]
            or type(source.sourceText)~="string" then return nil end
        local fn=loadstring(source.sourceText,"native:"..dependency)
        if not fn then return nil end
        setfenv(fn,env);fn()
    end
    return env[name],PINS[name]
end
local function queue(a,name,selected,primary,twoHands)
    if not selected or not live(a) or not SAO.Needs.workAvailable(a.body) then return false end
    -- These native conversion/drop branches require separate source custody.
    local back=a.body:getClothingItem_Back()
    if back and back:hasTag(ItemTag.REPLACE_PRIMARY) then return false end
    for slot=1,2 do
        local held
        if slot==1 then held=a.body:getPrimaryHandItem()else held=a.body:getSecondaryHandItem()end
        if held and held:isForceDropHeavyItem() then return false end
    end
    local class,sha=actionClass(name,a)
    if not class then return false end
    local act
    if name=="ISWearClothing" then act=class:new(a.body,selected)
    elseif name=="ISUnequipAction" then act=class:new(a.body,selected,50)
    else act=class:new(a.body,selected,50,primary,twoHands==true,false) end
    local native={isValid=act.isValid,start=act.start,update=act.update,complete=act.complete,
        perform=act.perform,stop=act.stop,animEvent=act.animEvent}
    local function custody(self)
        return self==act and a.action==act and live(a)
            and item(a.body,tostring(selected:getID()),selected:getFullType())==selected
    end
    local function valid(self) return custody(self) and native.isValid(act) and self.item==selected end
    local function finishedTime(self)
        local ok,delta=pcall(self.getJobDelta,self)
        return a.started==true and self.action and self.action:isStarted() and ok and finite(delta) and delta>=0.999999
    end
    act.isValid=function(self)return valid(self)end
    act.start=function(self)
        if not valid(self) or a.started or not ISTimedActionQueue.hasAction(self) then return end
        native.start(self);a.started=true;a.sourceSound=self.sound;a.sourceEmitter=a.body:getEmitter()
    end
    act.update=function(self)
        if not valid(self) or not a.started or not ISTimedActionQueue.hasAction(self) then
            if self.action then self:forceStop() end;return
        end
        native.update(self)
    end
    if native.animEvent then act.animEvent=function(self,...)
        if valid(self) and a.started and ISTimedActionQueue.hasAction(self) then return native.animEvent(self,...) end
    end end
    act.complete=function(self)
        if not valid(self) or not finishedTime(self) or a.effectObserved or a.completedCallback
            or not (ISTimedActionQueue.hasAction(self) or a.performed) then return false end
        a.completedCallback=true
        local ok,result=pcall(native.complete,self)
        a.effectObserved=ok and (name=="ISUnequipAction" and not a.body:isEquippedClothing(selected)
                and a.body:getPrimaryHandItem()~=selected and a.body:getSecondaryHandItem()~=selected
            or name=="ISWearClothing" and a.body:isEquippedClothing(selected)
            or name=="ISEquipWeaponAction" and (primary and a.body:getPrimaryHandItem()==selected
                or not primary and a.body:getSecondaryHandItem()==selected))
        if not ok then a.error="native preparation completion unavailable" end
        return ok and result==true
    end
    act.perform=function(self)
        if not custody(self) or a.performed or not finishedTime(self) or not ISTimedActionQueue.hasAction(self) then return end
        native.perform(self);a.performed=true
    end
    act.stop=function(self)
        if self~=act or a.action~=act then return end
        if a.stopped then return end
        if bodyOwned(a) and item(a.body,tostring(selected:getID()),selected:getFullType())==selected then native.stop(self)
        elseif a.sourceEmitter and a.sourceSound then pcall(function()a.sourceEmitter:stopSound(a.sourceSound)end) end
        a.stopped=true
    end
    act.forceCancel=function(self)
        if self==act and a.action==act then a.stopped=true;removeOwnedAction(a) end
    end
    a.action=act;a.row.phase=name;a.row.nativeSourceSha256=sha;a.effectObserved=false;a.performed=false;a.stopped=false
    a.started=false;a.completedCallback=false
    return SAO.Needs.queueVerified(act)
end
local function progress(a)
    if not live(a) then Q.interrupt(a.id,a.body,"maintained purpose or owned body lost");return false end
    if a.seating then
        local held,ready=SAO.LeisureSeating.advance(a.id,a.body)
        if held then return true end
        if not ready then Q.interrupt(a.id,a.body,"native seating preparation unavailable");return false end
        a.seating=nil
    end
    if a.action then
        if a.stopped or a.error then Q.interrupt(a.id,a.body,a.error or "native preparation stopped");return false end
        if ISTimedActionQueue.hasAction(a.action) then return true end
        if not a.effectObserved or not a.performed then Q.interrupt(a.id,a.body,"native preparation lacked completion");return false end
        a.action=nil
    end
    if a.route then
        if SAO.Locomotion.jobs[a.id]~=a.route then Q.interrupt(a.id,a.body,"preparation route replaced");return false end
        SAO.Locomotion.tick(a.id)
        if not a.route.done then return true end
        if a.route.result~="arrived" then Q.interrupt(a.id,a.body,"preparation route failed");return false end
        a.route=nil
    end
    local offer=current(a)
    if not offer then Q.interrupt(a.id,a.body,"selected source affordance unavailable");return false end
    local p=offer.requiresPreparation or {}
    if p.sourceInitialization or p.sourceVoice then
        local provider=owner(a.row.ownerName)
        if not provider.prepareActor or not provider.prepareActor(a.id,a.body) then Q.interrupt(a.id,a.body,"source person initialization unavailable");return false end
        offer=current(a);if not offer then Q.interrupt(a.id,a.body,"initialized source offer unavailable");return false end
        p=offer.requiresPreparation or {}
    end
    if p.sitFurniture or p.faceObject or p.adjacentObject then
        local seating=SAO.LeisureSeating
        if not seating or not seating.begin then Q.interrupt(a.id,a.body,"native seating owner unavailable");return false end
        local held,ready=seating.begin(a.id,a.body,a.row.ownerName,offer,a.row.purposeId)
        if not ready then
            if held then a.seating=true;a.row.phase="native-seating";return true end
            Q.interrupt(a.id,a.body,"native seating preparation refused");return false
        end
        offer=current(a)
        if not offer then Q.interrupt(a.id,a.body,"seated source affordance unavailable");return false end
        p=offer.requiresPreparation or {}
        if p.sitFurniture or p.faceObject or p.adjacentObject then
            Q.interrupt(a.id,a.body,"native seating source conditions unresolved");return false
        end
    end
    if p.frontSquare then
        if not finite(offer.targetX) or not finite(offer.targetY) or not finite(offer.targetZ) then return false end
        local job=SAO.Locomotion.jobs[a.id]
        if job and not job.done then Q.interrupt(a.id,a.body,"another route owns preparation");return false end
        if not SAO.Standing.mayAttemptBelieved(a.id,offer.targetX,offer.targetY,"standing")
            or not SAO.Locomotion.order(a.id,a.body,offer.targetX+0.5,offer.targetY+0.5,offer.targetZ,false) then
            Q.interrupt(a.id,a.body,"source front route unavailable");return false
        end
        a.route=SAO.Locomotion.jobs[a.id];a.row.phase="approaching";return a.route~=nil
    end
    if p.stand then
        a.body:setSitOnGround(false)
        if a.body:isSitOnGround() then Q.interrupt(a.id,a.body,"source standing posture unavailable");return false end
    end
    if p.requiresYogaMat then Q.interrupt(a.id,a.body,"source requires a personally acquired yoga mat");return false end
    local target,primary,name,twoHands
    if p.removeBags and #p.removeBags>0 then
        local bag=p.removeBags[1];target=item(a.body,bag.itemKey,bag.itemType);name="ISUnequipAction"
    elseif p.clearHands then
        target=a.body:getPrimaryHandItem() or a.body:getSecondaryHandItem();name="ISUnequipAction"
    elseif p.equipPrimary then
        local held=type(p.equipPrimary)=="table" and p.equipPrimary or {itemKey=offer.itemKey,itemType=offer.itemType}
        target=item(a.body,held.itemKey,held.itemType);primary=true;name="ISEquipWeaponAction";twoHands=held.twoHands
    elseif p.equipSecondary then
        target=item(a.body,p.equipSecondary.itemKey,p.equipSecondary.itemType);primary=false;name="ISEquipWeaponAction"
    elseif p.weldingMask then
        local mask=offer.materials and offer.materials.item3
        target=mask and item(a.body,tostring(mask.id),mask.itemType);name="ISWearClothing"
    end
    if name then
        if queue(a,name,target,primary,twoHands) then return true end
        Q.interrupt(a.id,a.body,"native preparation action unavailable");return false
    end
    if p.sitOnGround then
        a.body:setSitOnGround(true)
        if not a.body:isSitOnGround() then Q.interrupt(a.id,a.body,"source ground posture unavailable");return false end
    end
    finish(a,"completed","native preparation observed")
    return false,{ownerName=a.row.ownerName,offer=copy(offer),purposeId=a.row.purposeId}
end
function Q.begin(id,body,ownerName,offer,purposeId)
    local r=rec(id)
    if not r or not owner(ownerName) or not SAO.Needs.ownsRecoveryBody(id,body)
        or not SAO.Needs.workAvailable(body) or isClient() or isServer() or runtime[id] then return false end
    local row={actorId=id,ownerName=ownerName,purposeId=purposeId,offer=copy(offer),
        bodyToken=body:getModData().SAOExternalToken,bodyGenerationKnown=body:getModData().SAOExternalToken~=nil,
        status="preparing",phase="selected",admittedAtHours=SAO.History.countyHours()}
    local a={id=id,body=body,record=r,row=row,selection=copy(offer),bodyToken=row.bodyToken,
        bodyOwner=r.bodyOwner,ownerToken=r.bodyOwnerToken}
    r.leisurePreparation=row;runtime[id]=a
    local ok,held,ready=pcall(progress,a)
    if not ok then Q.interrupt(id,body,"native preparation unavailable");return false end
    return held or ready~=nil,ready
end
function Q.advance(id,body)
    local a=runtime[id]
    if not a or a.body~=body then Q.interrupt(id,body,"preparation runtime unavailable");return false end
    local ok,held,ready=pcall(progress,a)
    if not ok then Q.interrupt(id,body,"native preparation unavailable");return false end
    return held,ready
end
function Q.reset(reason)
    local ids={} for id in pairs(runtime)do ids[#ids+1]=id end
    for _,id in ipairs(ids)do Q.interrupt(id,runtime[id] and runtime[id].body,reason)end
end
return Q
