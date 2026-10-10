-- Person-owned boarding through the installed native action and equipment queue.
SAO = SAO or {}
SAO.Build = SAO.Build or {}
local B = SAO.Build
if B.runtimeCount then pcall(B.reset, "module-reload"); return B end
local TOKEN, offers, runtime, cancellations = {}, {}, {}, {}
local offerCount, installed = 0, false
local MAX_OFFERS, MAX_RESULTS, MAX_RETRIES = 128, 32, 32
-- Native boarding contact remains on the aperture's two adjacent squares.
local BOARDING_REACH_SQ = 4
local FIELDS = {id=true,sequence=true,actorId=true,purposeId=true,stepId=true,workId=true,entryKey=true,
    status=true,endedAt=true,startedAt=true,reason=true,nativeOwner=true,plankConsumed=true,
    nailsConsumed=true,barricadeChanged=true,nativeAttempted=true,planningAcknowledged=true,
    itemId=true,hammerId=true,world=true,bodyToken=true,x=true,y=true,z=true,objectIndex=true,
    north=true,planksBefore=true,planksAfter=true,nativeObservability=true}
local function finite(v) return type(v)=="number" and v==v and v~=math.huge and v~=-math.huge end
local function availableMaterial(item) return not item:getIsCraftingConsumed() end
local function integer(v) return finite(v) and v>=0 and v<1000000000 and v%1==0 end
local function hours() local v=SAO.History and SAO.History.countyHours(); return finite(v) and v or nil end
local function person(id) return SAO.Identity and SAO.Identity.get(id) end
local function copy(row) local out={}; for k,v in pairs(row) do out[k]=v end; return out end
local function tombstone() return false end
local function nativeEnded(action)
    local ok,ended=pcall(function()
        return action.action and action.action:isStarted()
            and (action.action:finished() or action.action:isForceComplete())
    end)
    return ok and ended==true
end
local function ledger(r,create)
    local s=r and r.barricade
    if not s and r and create then s={schema=1,nextWork=0,nextResult=0,outcomes={},order={}}; r.barricade=s end
    if type(s)~="table" or getmetatable(s) or s.schema~=1 or not integer(s.nextWork)
        or not integer(s.nextResult) or type(s.outcomes)~="table" or getmetatable(s.outcomes)
        or type(s.order)~="table" or getmetatable(s.order) or #s.order>MAX_RESULTS then return nil end
    local count,previous,seen=0,0,{}
    for k,v in pairs(s.order) do
        if not integer(k) or k<1 or k>#s.order or not integer(v) or v<1 or v>s.nextResult then return nil end
        count=count+1
    end
    if count~=#s.order then return nil end
    for _,seq in ipairs(s.order) do
        if seq<=previous or seen[tostring(seq)] or type(s.outcomes[tostring(seq)])~="table" then return nil end
        previous,seen[tostring(seq)]=seq,true
    end
    for key in pairs(s.outcomes) do if not seen[key] then return nil end end
    return s
end
local function ordinary(id,body)
    local r,md=person(id),body and body:getModData()
    return r and not r.dead and body and not body:isDead() and body:isExistInTheWorld()
        and not r.zaoTransferPending and not r.crossedTransferPending and r.bodyOwner==nil
        and SAO.Body and SAO.Body.get(id)==body and SAO.Body.active and SAO.Body.active[id]==body
        and not (SAO.Body.foreign and SAO.Body.foreign[id]) and md
        and tostring(md.SAOPersonId or "")==id and md.SAOExternalOwner==nil
        and md.SAOExternalToken==r.bodyOwnerToken and md.ZAOOwned~=true
        and SAOJavaBridge and SAOJavaBridge:isShell(body)==true and r or nil
end
local function boardable(target,body)
    if not target or not instanceof(target,"BarricadeAble") or target:getObjectIndex()<0 then return false end
    if not (instanceof(target,"IsoWindow") or instanceof(target,"IsoDoor")
        or instanceof(target,"IsoThumpable") and (target:isDoor() or target:isWindow())) then return false end
    local barricade=target:getBarricadeForCharacter(body)
    return not barricade or barricade:canAddPlank()
end
local function claimKey(id,body,target)
    local S=SAO.Standing
    if not S or not S.fallHasCome() then return nil end
    local c,sq=S.claimOf(id),target:getSquare()
    if not c or not sq or not S.insideClaim(id,body:getX(),body:getY())
        or sq:getX()<c.minX or sq:getX()>c.maxX or sq:getY()<c.minY or sq:getY()>c.maxY
        or sq:getZ()~=(c.z or 0) then return nil end
    return table.concat({tostring(c.minX),tostring(c.minY),tostring(c.maxX),tostring(c.maxY),
        tostring(c.z or 0),tostring(S.groupOf and S.groupOf(id) or "")},":")
end
local function geometry(b,sight)
    local body,sq,target,world=b.body,b.square,b.target,getWorld()
    local here=body:getCurrentSquare()
    local living=b.cell:getObjectList():contains(body) or b.cell:getAddList():contains(body)
    if not world or world:getWorld()~=b.world or world:getCell()~=b.cell or body:getCell()~=b.cell
        or not living or not here or not body:isExistInTheWorld() or body:isDead()
        or b.cell:getGridSquare(here:getX(),here:getY(),here:getZ())~=here
        or b.cell:getGridSquare(sq:getX(),sq:getY(),sq:getZ())~=sq or math.floor(body:getZ())~=sq:getZ()
        or target:getSquare()~=sq or target:getObjectIndex()~=b.index or target:getNorth()~=b.north
        or not sq:getObjects():contains(target) or not here:canStand() then return false end
    local other
    if b.north then other=sq:getN() else other=sq:getW() end
    if here~=sq and here~=other then return false end
    if b.work and here~=b.interactionSquare then return false end
    local dx,dy=sq:getX()+0.5-body:getX(),sq:getY()+0.5-body:getY()
    if dx*dx+dy*dy>BOARDING_REACH_SQ then return false end
    return not sight or SAOJavaBridge:canSeeBoardable(body,target)==true
end
local function purposeBinding(b)
    local s=b.record.proceduralPlanning
    local p=s and s.purposes and s.purposes[b.purposeId]
    local step=p and p.steps and p.steps[p.cursor]
    local a=p and p.admission
    return p==b.purpose and step==b.step and step.id==b.stepId and step.owner=="SAOBuild"
        and step.token=="construction:boarded" and step.target==b.entryKey
        and a and a.owner=="SAOBuild" and a.correlationId==b.workId and a.stepId==b.stepId
end
local function nativePaymentMatches(b)
    -- Match RemoveAll's raw root-list traversal without container or eligibility
    -- filtering. Captured material custody is checked separately by bound.
    local items=b.inventory:getItems()
    local plank,nails=nil,{}
    for index=0,items:size()-1 do
        local item=items:get(index)
        if not item then return false end
        local rawType,fullType=item:getType(),item:getFullType()
        if not plank and (rawType=="Plank" or fullType=="Plank") then plank=item end
        if #nails<2 and (rawType=="Nails" or fullType=="Nails") then nails[#nails+1]=item end
        if plank and #nails==2 then break end
    end
    return plank==b.plank and nails[1]==b.nails[1] and nails[2]==b.nails[2]
end
local function bound(b,materials)
    if ordinary(b.id,b.body)~=b.record or b.body:getInventory()~=b.inventory
        or b.body:getModData().SAOExternalToken~=b.token or not geometry(b,false)
        or claimKey(b.id,b.body,b.target)~=b.claim or b.cancelled
        or b.record.barricadeWork~=b.work or b.work.status~="boarding"
        or b.work.id~=b.workId or b.work.purposeId~=b.purposeId or b.work.stepId~=b.stepId
        or b.work.entryKey~=b.entryKey or b.work.itemId~=b.itemId or b.work.startedAt~=b.startedAt
        or ledger(b.record)~=b.state or not hours() or hours()<b.startedAt
        or not purposeBinding(b) or ISTimedActionQueue.getTimedActionQueue(b.body)~=b.queue then return false end
    if materials then
        if b.plank:getFullType()~="Base.Plank" or tostring(b.plank:getID())~=b.itemId
            or not b.inventory:containsRecursive(b.plank) or not b.inventory:containsRecursive(b.hammer)
            or tostring(b.hammer:getID())~=b.hammerId or not b.hammer:hasTag(ItemTag.HAMMER)
            or b.hammer:getCondition()<=0 or b.hammer:isBroken() then return false end
        for _,item in ipairs({b.plank,b.hammer,b.nails[1],b.nails[2]}) do
            local container=item:getContainer()
            if not container or item:getIsCraftingConsumed()
                or (container~=b.inventory and container:getOutermostContainer()~=b.inventory)
                or b.prepared and container~=b.inventory then return false end
        end
        if b.prepared then
            if not nativePaymentMatches(b) then return false end
        end
        for i=1,2 do
            if b.nails[i]:getFullType()~="Base.Nails" or not b.inventory:containsRecursive(b.nails[i])
                or tostring(b.nails[i]:getID())~=b.nailIds[i] then return false end
        end
    end
    return true
end
local function retireOffer(id) if offers[id] then offerCount=offerCount-1 end; offers[id]=nil end
function B.expireOffers() offers={}; offerCount=0 end
function B.offerCount() return offerCount end
local function schedule(b)
    if not b.retryQueued then b.retryQueued=true; cancellations[#cancellations+1]=b end
end
local function retire(b)
    if runtime[b.id]~=b then return runtime[b.id]==nil end
    for _,c in ipairs(b.actions) do
        if b.queue:indexOf(c.action)~=-1 or b.queue.current==c.action
            or c.action.action and not c.acknowledged then return false end
    end
    runtime[b.id]=nil
    for _,c in ipairs(b.actions) do
        local a=c.action
        a._SAOBuildBinding=false
        -- Dispose closures holding native handles when the old action retires.
        a.isValidStart,a.isValid,a.perform,a.complete,a.stop,a.forceCancel=
            tombstone,tombstone,tombstone,tombstone,tombstone,tombstone
    end
    for i=#cancellations,1,-1 do if cancellations[i]==b then table.remove(cancellations,i) end end
    b.retryQueued=false
    return true
end
function B.outcome(id,sequence)
    id=tostring(id)
    local s=ledger(person(id)); local row=s and s.outcomes[tostring(sequence)]
    if not row or getmetatable(row) or not integer(sequence) or sequence<1 or row.sequence~=sequence
        or row.actorId~=id or row.id~=id.."/barricade-result/"..sequence or type(row.workId)~="string"
        or type(row.purposeId)~="string" or type(row.stepId)~="string" or type(row.entryKey)~="string"
        or (row.status~="completed" and row.status~="interrupted") or row.nativeOwner~="ISBarricadeAction"
        or not finite(row.startedAt) or not finite(row.endedAt) or row.endedAt<row.startedAt
        or type(row.reason)~="string" or type(row.plankConsumed)~="boolean"
        or not integer(row.nailsConsumed) or row.nailsConsumed>2 or type(row.barricadeChanged)~="boolean"
        or type(row.nativeAttempted)~="boolean" or not integer(row.planksBefore)
        or row.nativeObservability~="runtime-unavailable" and not integer(row.planksAfter)
        or row.planksBefore>4 or row.planksAfter~=nil and (not integer(row.planksAfter) or row.planksAfter>4) or type(row.north)~="boolean"
        or not integer(row.objectIndex) or type(row.itemId)~="string" or type(row.hammerId)~="string"
        or type(row.world)~="string" or not finite(row.x) or not finite(row.y) or not finite(row.z)
        or row.x%1~=0 or row.y%1~=0 or row.z%1~=0
        or row.entryKey~="barricade:"..row.x..":"..row.y..":"..row.z..":"..row.objectIndex..":"..tostring(row.north)
        or (row.planningAcknowledged~=nil and type(row.planningAcknowledged)~="boolean") then return nil end
    local n=tonumber(row.workId:match("/barricade%-work/(%d+)$"))
    if not integer(n) or n<1 or n>s.nextWork or row.workId~=id.."/barricade-work/"..n then return nil end
    if row.status=="completed" and (not row.nativeAttempted or not row.plankConsumed or row.nailsConsumed~=2
        or not row.barricadeChanged or row.planksAfter~=row.planksBefore+1) then return nil end
    if row.nativeObservability~=nil and (row.nativeObservability~="runtime-unavailable" or row.status~="interrupted"
        or row.reason~="barricade-runtime-unavailable" or row.nativeAttempted or row.plankConsumed
        or row.nailsConsumed~=0 or row.barricadeChanged or row.planksAfter~=nil) then return nil end
    if (row.plankConsumed or row.nailsConsumed>0 or row.barricadeChanged) and not row.nativeAttempted then return nil end
    for k,v in pairs(row) do
        if not FIELDS[k] or (type(v)~="string" and type(v)~="number" and type(v)~="boolean")
            or type(v)=="string" and #v>512 or type(v)=="number" and not finite(v) then return nil end
    end
    return copy(row)
end
function B.acknowledge(id,sequence)
    local s=ledger(person(id))
    if not s or not B.outcome(id,sequence) then return false end
    s.outcomes[tostring(sequence)].planningAcknowledged=true; return true
end
function B.flush(id)
    id=tostring(id)
    local s=ledger(person(id)); local P=SAO.ProceduralPlanning
    if not s or not P or not P.consumeBarricadeOutcome then return 0 end
    local delivered=0
    for _,seq in ipairs(s.order) do
        local row=B.outcome(id,seq)
        if row and not row.planningAcknowledged then
            local ok,accepted=pcall(P.consumeBarricadeOutcome,id,seq)
            if ok and accepted==true and B.outcome(id,seq) and B.outcome(id,seq).planningAcknowledged then delivered=delivered+1 end
        end
    end
    return delivered
end
local function close(b,status,reason)
    if b.closed then return false end
    b.closed=true
    local s,at=ledger(b.record),hours()
    b.work.status,b.work.reason=status,reason
    if not s or s~=b.state or not at or at<b.startedAt or s.nextResult>=999999999 then return false end
    s.nextResult=s.nextResult+1
    local row={id=b.id.."/barricade-result/"..s.nextResult,sequence=s.nextResult,actorId=b.id,
        workId=b.workId,purposeId=b.purposeId,stepId=b.stepId,entryKey=b.entryKey,status=status,reason=reason,
        startedAt=b.startedAt,endedAt=at,nativeOwner="ISBarricadeAction",itemId=b.itemId,hammerId=b.hammerId,
        world=b.world,bodyToken=b.token,x=b.square:getX(),y=b.square:getY(),z=b.square:getZ(),
        objectIndex=b.index,north=b.north,plankConsumed=b.plankConsumed==true,nailsConsumed=b.nailsConsumed or 0,
        barricadeChanged=b.barricadeChanged==true,nativeAttempted=b.nativeAttempted==true,
        planksBefore=b.planksBefore,planksAfter=b.planksAfter or b.planksBefore}
    s.outcomes[tostring(s.nextResult)]=row; s.order[#s.order+1]=s.nextResult
    b.work.resultSequence=s.nextResult
    if person(b.id)==b.record then B.flush(b.id) end
    return true
end
local function refuse(b,reason)
    if not b.closed then b.cancelled=true; close(b,"interrupted",reason) end
    schedule(b); return false
end
local function capsule(action)
    local f=action and rawget(action,"_SAOBuildBinding")
    if type(f)~="function" then return nil end
    local c=f(TOKEN)
    return type(c)=="table" and c.seal==TOKEN and c.action==action and c or nil
end
local function exact(c)
    local a,b=c.action,c.binding
    return capsule(a)==c and a.character==b.body and a.item==c.item
        and (c.kind~="board" or a.isMetal==false and a.isMetalBar==false)
        and (c.kind~="equip" or a.primary==c.primary and a.twoHands==false)
        and (c.kind~="transfer" or a.srcContainer==c.source and a.destContainer==b.inventory)
end
local function current(c)
    local b=c.binding
    return exact(c) and ISTimedActionQueue.getTimedActionQueue(b.body)==b.queue
        and b.queue.current==c.action and b.queue:indexOf(c.action)==1
end
local function woodenValid(action)
    -- Installed ISBarricadeAction.isValid uses ItemType.HAMMER. That field is
    -- absent in the installed ItemType class; hasEquippedTag takes ItemTag.
    -- These NPC instances use the same wooden requirements with the real tag.
    local target,body=action.item,action.character
    if not target or not instanceof(target,"BarricadeAble") or target:getObjectIndex()<0 then return false end
    local barricade=target:getBarricadeForCharacter(body)
    if barricade and not barricade:canAddPlank() then return false end
    if not body:hasEquippedTag(ItemTag.HAMMER) or not body:hasEquipped("Plank")
        or body:getInventory():getItemCount("Base.Nails",true)<2 then return false end
    if action.isStarted and (instanceof(target,"IsoDoor")
        or instanceof(target,"IsoThumpable") and target:isDoor()) and target:IsOpen() then return false end
    return true
end
local enqueue
local function guardTransfer(b,item)
    local source=item:getContainer()
    local action=ISInventoryTransferAction:new(b.body,item,source,b.inventory)
    local c={seal=TOKEN,binding=b,action=action,kind="transfer",item=item,source=source}
    action._SAOBuildBinding=function(token) if token==TOKEN then return c end end
    action.canMergeAction=function() return false end
    local nativeValid,nativePerform=action.isValid,action.perform
    local function transferValid()
        return exact(c) and not c.done and not b.closed and bound(b,true)
            and source:getOutermostContainer()==b.inventory and source:contains(item)
            and item:getContainer()==source
    end
    function action:isValidStart() return transferValid() and nativeValid(self)==true or false end
    function action:isValid() return transferValid() and nativeValid(self)==true or false end
    function action:perform()
        local ql=self.queueList
        if c.performed or not current(c) or not nativeEnded(self) or not transferValid() or type(ql)~="table" or #ql~=1
            or type(ql[1].items)~="table" or #ql[1].items~=1 or ql[1].items[1]~=item then
            return refuse(b,"barricade-transfer-owner-changed")
        end
        c.performed=true
        local ok=pcall(nativePerform,self)
        c.done,c.acknowledged=true,true
        if not ok or not exact(c) or not bound(b,true) or item:getContainer()~=b.inventory
            or not b.inventory:contains(item) or source:contains(item)
            or b.queue:indexOf(self)~=-1 or b.queue.current==self then
            refuse(b,"barricade-transfer-unconfirmed"); retire(b); return false
        end
        return enqueue(b,c.position+1)
    end
    function action:complete() return false end
    function action:stop()
        if c.acknowledged or capsule(self)~=c then return false end
        local ownsTransfer=current(c)
        refuse(b,"native-barricade-transfer-stopped")
        if ownsTransfer and current(c) then
            -- Native transfer stop cosmetics precede queue retirement, so a
            -- successor's item progress, sounds and animation remain its own.
            pcall(function() self:playSourceContainerCloseSound() end)
            pcall(function() self:playDestContainerCloseSound() end)
            pcall(function() self:stopLoopingSound() end)
            pcall(function() c.item:setJobDelta(0) end)
            pcall(function() if self.action then self.action:setLoopedAction(false) end end)
            self.started=false
            b.body:setIsFarming(false)
            c.acknowledged=true; b.queue:onCompleted(self)
        else
            c.acknowledged=true; b.queue:removeFromQueue(self)
            if b.queue.current==self then b.queue.current=nil end
        end
        retire(b); return true
    end
    function action:forceCancel()
        if capsule(self)~=c or c.acknowledged then return false end
        refuse(b,"native-barricade-transfer-force-cancel")
        if not self.action then c.acknowledged=true end
        return false
    end
    c.position=#b.actions+1; b.actions[c.position]=c
end
local function guard(b,action,kind,item,primary)
    local c={seal=TOKEN,binding=b,action=action,kind=kind,item=item,primary=primary}
    action._SAOBuildBinding=function(token) if token==TOKEN then return c end end
    local nativeValid,nativeStart,nativeComplete,nativePerform,nativeCancel=kind=="board" and woodenValid or action.isValid,
        action.isValidStart,action.complete,action.perform,action.forceCancel
    function action:isValidStart()
        return exact(c) and not c.performed and not c.done and bound(b,true)
            and nativeStart(self)==true and nativeValid(self)==true or false
    end
    function action:isValid()
        return exact(c) and not c.performed and not c.done and bound(b,true) and nativeValid(self)==true or false
    end
    function action:perform()
        if c.performed or c.done or not current(c) or not nativeEnded(self) or not bound(b,true) or nativeValid(self)~=true then
            return refuse(b,"barricade-perform-owner-changed")
        end
        c.performed=true
        -- The engine calls perform before complete. Retain this private owner
        -- while native perform retires the queue, then complete admits the next action.
        local ok,result=pcall(nativePerform,self)
        if not ok then refuse(b,"barricade-native-perform-failed"); return false end
        return result
    end
    function action:complete()
        if c.done or not c.performed or not exact(c) or not bound(b,true)
            or kind=="board" and nativeValid(self)~=true
            or b.queue:indexOf(self)~=-1 or b.queue.current~=nil or #b.queue.queue~=0 then
            refuse(b,"barricade-complete-owner-changed"); return false
        end
        c.done,c.acknowledged=true,true
        if kind=="board" then
            local before=b.target:getBarricadeForCharacter(b.body)
            if (before and before:getNumPlanks() or 0)~=b.planksBefore
                or b.body:getPrimaryHandItem()~=b.hammer or b.body:getSecondaryHandItem()~=b.plank then
                refuse(b,"barricade-material-or-baseline-changed"); retire(b); return false
            end
            b.nativeAttempted=true
        end
        local ok,result=pcall(nativeComplete,self)
        if kind=="equip" then
            local equipped=primary and b.body:getPrimaryHandItem() or b.body:getSecondaryHandItem()
            if not ok or result~=true or equipped~=item or not bound(b,true) then
                refuse(b,"barricade-equipment-unconfirmed"); retire(b); return false
            end
            return enqueue(b,c.position+1)
        end
        b.plankConsumed=not b.inventory:contains(b.plank)
        b.nailsConsumed=0
        for i=1,2 do if not b.inventory:contains(b.nails[i]) then b.nailsConsumed=b.nailsConsumed+1 end end
        local after=b.target:getBarricadeForCharacter(b.body)
        b.planksAfter=after and after:getNumPlanks() or 0
        b.barricadeChanged=b.planksAfter==b.planksBefore+1
        local measured=ok and result==true and bound(b,false) and b.plankConsumed and b.nailsConsumed==2
            and b.barricadeChanged and b.body:getPrimaryHandItem()==b.hammer
        close(b,measured and "completed" or "interrupted",measured and "native-barricade-and-payment-measured" or "native-barricade-effect-unconfirmed")
        retire(b); return measured
    end
    function action:stop()
        if c.acknowledged or capsule(self)~=c then return false end
        local ownsAction=current(c)
        refuse(b,"native-barricade-stopped")
        -- Stop only this exact owner; native base.stop resets unrelated work.
        if ownsAction and current(c) then
            if self.sound then
                pcall(function() b.body:getEmitter():stopSound(self.sound) end); self.sound=nil
            end
            if kind=="equip" then
                pcall(function() c.item:setJobDelta(0) end)
                pcall(function() self:restoreWeaponType() end)
            end
            b.body:setIsFarming(false)
            c.acknowledged=true; b.queue:onCompleted(self)
        else
            c.acknowledged=true; b.queue:removeFromQueue(self)
            if b.queue.current==self then b.queue.current=nil end
        end
        retire(b); return true
    end
    function action:forceCancel()
        if capsule(self)~=c or c.acknowledged then return false end
        refuse(b,"native-barricade-force-cancel")
        if not self.action then c.acknowledged=true end
        return nativeCancel(self)
    end
    c.position=#b.actions+1; b.actions[c.position]=c; return c
end
local function prepareNativePayment(b)
    -- Native RemoveAll pays the first raw matches. Arrange only the captured
    -- eligible materials within their same root inventory before preparation.
    local items=b.inventory:getItems()
    for index,item in ipairs({b.plank,b.nails[1],b.nails[2]}) do
        local currentIndex=items:indexOf(item)
        if currentIndex<0 or item:getContainer()~=b.inventory or not availableMaterial(item) then return false end
        local paymentIndex=index-1
        if currentIndex~=paymentIndex then
            local displaced=items:get(paymentIndex)
            items:set(currentIndex,displaced); items:set(paymentIndex,item)
        end
    end
    return true
end
enqueue=function(b,position)
    local c=b.actions[position]
    if not c then return false end
    if b.closed or not bound(b,true) or b.queue.current or #b.queue.queue>0 then return refuse(b,"barricade-preparation-queue-changed") end
    if c.kind~="transfer" then
        if not b.prepared and not prepareNativePayment(b) then return refuse(b,"barricade-payment-preparation-refused") end
        b.prepared=true
        if not bound(b,true) then return refuse(b,"barricade-preparation-material-changed") end
    end
    b.current=c
    if not SAO.Needs or not SAO.Needs.queueVerified or not SAO.Needs.queueVerified(c.action) then
        refuse(b,"native-barricade-queue-refused"); B.interrupt(b.id,b.body,"native-barricade-queue-refused"); return false
    end
    return true
end
function B.install()
    if installed then return true end
    if type(require)~="function" then return false end
    local ok=pcall(require,"TimedActions/ISBarricadeAction")
    local equip=pcall(require,"TimedActions/ISEquipWeaponAction")
    local transfer=pcall(require,"TimedActions/ISInventoryTransferAction")
    installed=ok and equip and transfer and type(ISBarricadeAction)=="table" and type(ISBarricadeAction.new)=="function"
        and type(ISBarricadeAction.complete)=="function" and type(ISEquipWeaponAction)=="table"
        and type(ISEquipWeaponAction.complete)=="function"
        and type(ISInventoryTransferAction)=="table" and type(ISInventoryTransferAction.perform)=="function"
    return installed
end
function B.offer(id,body,entryKey)
    id=tostring(id); retireOffer(id)
    local r=ordinary(id,body)
    if not r or runtime[id] or offerCount>=MAX_OFFERS or not hours() or not B.install()
        or SAOJavaBridge:hasPendingActions(body) then return nil end
    local here,world=body:getCurrentSquare(),getWorld()
    if not here or not world then return nil end
    for _,offset in ipairs({{0,0},{0,1},{1,0}}) do
        local sq=body:getCell():getGridSquare(here:getX()+offset[1],here:getY()+offset[2],here:getZ())
        if sq then
            local objects=sq:getObjects()
            for index=0,math.min(objects:size(),128)-1 do
                local target=objects:get(index)
                if boardable(target,body) then
                    local b={id=id,body=body,record=r,target=target,square=sq,index=target:getObjectIndex(),
                        north=target:getNorth(),cell=body:getCell(),world=world:getWorld(),token=body:getModData().SAOExternalToken}
                    b.claim=claimKey(id,body,target)
                    if b.claim and geometry(b,true) then
                        b.entryKey="barricade:"..sq:getX()..":"..sq:getY()..":"..sq:getZ()..":"..b.index..":"..tostring(b.north)
                        if not entryKey or entryKey==b.entryKey then
                            local offer={entryKey=b.entryKey}
                            offers[id]={offer=offer,binding=b}; offerCount=offerCount+1; return offer
                        end
                    end
                end
            end
        end
    end
end
function B.destination(id,body,offer)
    id=tostring(id)
    local slot=offers[id]; local b=slot and slot.offer==offer and slot.binding
    if not b or b.body~=body or ordinary(id,body)~=b.record or offer.entryKey~=b.entryKey
        or not geometry(b,true) or claimKey(id,body,b.target)~=b.claim then return nil end
    return {key=b.entryKey,x=math.floor(body:getX()),y=math.floor(body:getY()),z=math.floor(body:getZ())}
end
function B.begin(id,body,offer,purposeId,stepId)
    id=tostring(id)
    local slot=offers[id]; local b=slot and slot.offer==offer and slot.binding
    retireOffer(id)
    if not b or ordinary(id,body)~=b.record or body~=b.body or offer.entryKey~=b.entryKey
        or not geometry(b,true) or claimKey(id,body,b.target)~=b.claim or not boardable(b.target,body)
        or runtime[id] or SAOJavaBridge:hasPendingActions(body) or isClient() or isServer() then return false end
    local pstate=b.record.proceduralPlanning
    local p=pstate and pstate.purposes and pstate.purposes[purposeId]
    local step=p and p.steps and p.steps[p.cursor]
    if not p or p.admission or not step or step.id~=stepId or step.owner~="SAOBuild"
        or step.status~="available" or step.token~="construction:boarded" or step.target~=b.entryKey then return false end
    b.inventory=body:getInventory()
    b.plank=b.inventory:getFirstTypeEval("Base.Plank",availableMaterial)
        or b.inventory:getFirstTypeEvalRecurse("Base.Plank",availableMaterial)
    local function usableHammer(item)
        return item:getCondition()>0 and not item:isBroken() and not item:getIsCraftingConsumed()
            and not item:isRequiresEquippedBothHands()
    end
    b.hammer=b.inventory:getFirstTagEval(ItemTag.HAMMER,usableHammer)
        or b.inventory:getFirstTagEvalRecurse(ItemTag.HAMMER,usableHammer)
    local nails=b.inventory:getAllTypeEval("Base.Nails",availableMaterial)
    local picked={}
    for index=0,math.min(nails:size(),2)-1 do picked[#picked+1]=nails:get(index) end
    if #picked<2 then
        local recursive=b.inventory:getAllTypeEvalRecurse("Base.Nails",availableMaterial)
        for index=0,recursive:size()-1 do
            local nail=recursive:get(index)
            if nail~=picked[1] and nail~=picked[2] and #picked<2 then picked[#picked+1]=nail end
        end
    end
    if not b.plank or not b.hammer or #picked<2 or b.hammer:isRequiresEquippedBothHands()
        or b.plank:isRequiresEquippedBothHands() then return false end
    b.nails=picked
    b.nailIds={tostring(b.nails[1]:getID()),tostring(b.nails[2]:getID())}
    b.itemId,b.hammerId=tostring(b.plank:getID()),tostring(b.hammer:getID())
    local s,at=ledger(b.record,true),hours()
    if not s or not at or s.nextWork>=999999999 then return false end
    while #s.order>=MAX_RESULTS do
        local first=s.outcomes[tostring(s.order[1])]
        if not first or not B.outcome(id,s.order[1]) or first.planningAcknowledged~=true then return false end
        s.outcomes[tostring(table.remove(s.order,1))]=nil
    end
    s.nextWork=s.nextWork+1
    b.work={id=id.."/barricade-work/"..s.nextWork,purposeId=purposeId,stepId=stepId,entryKey=b.entryKey,
        status="boarding",startedAt=at,itemId=b.itemId,actorId=id,nativeOwner="ISBarricadeAction",
        hammerId=b.hammerId,world=b.world,bodyToken=b.token,x=b.square:getX(),y=b.square:getY(),z=b.square:getZ(),
        objectIndex=b.index,north=b.north}
    b.state,b.startedAt,b.purposeId,b.stepId,b.workId=s,at,purposeId,stepId,b.work.id
    b.purpose,b.step,b.queue,b.actions=p,step,ISTimedActionQueue.getTimedActionQueue(body),{}
    b.interactionSquare=body:getCurrentSquare()
    local barricade=b.target:getBarricadeForCharacter(body)
    b.planksBefore=barricade and barricade:getNumPlanks() or 0
    b.work.planksBefore=b.planksBefore
    for _,item in ipairs({b.plank,b.hammer,b.nails[1],b.nails[2]}) do
        if item:getContainer()~=b.inventory then guardTransfer(b,item) end
    end
    if body:getPrimaryHandItem()~=b.hammer then guard(b,ISEquipWeaponAction:new(body,b.hammer,50,true,false),"equip",b.hammer,true) end
    if body:getSecondaryHandItem()~=b.plank then guard(b,ISEquipWeaponAction:new(body,b.plank,50,false,false),"equip",b.plank,false) end
    guard(b,ISBarricadeAction:new(body,b.target,false,false),"board",b.target)
    b.record.barricadeWork,runtime[id]=b.work,b
    if not SAO.ProceduralPlanning.noteAdmission(id,purposeId,"SAOBuild",b.workId,stepId) then
        refuse(b,"barricade-planning-admission-refused"); B.interrupt(id,body,"barricade-planning-admission-refused"); return false
    end
    return enqueue(b,1)
end
function B.interrupt(id,body,reason)
    id=tostring(id); local b=runtime[id]
    if not b then return true end
    if b.closed and b.work.status=="completed" then return retire(b) end
    refuse(b,reason or "barricade-interrupted")
    -- Remove pending entries before a stop acknowledgement can start another action.
    for _,c in ipairs(b.actions) do
        if not c.action.action then b.queue:removeFromQueue(c.action); c.acknowledged=true end
    end
    for _,c in ipairs(b.actions) do
        if c.action.action and not c.acknowledged then pcall(function() c.action.action:forceStop() end) end
    end
    return retire(b)
end
function B.forget(id) id=tostring(id); retireOffer(id); return B.interrupt(id,nil,"controller-forget") end
function B.reconcileSaved(id,body)
    id=tostring(id)
    -- Existing terminal evidence has priority over reconstruction of lost work.
    B.flush(id)
    if runtime[id] then return B.interrupt(id,body,"barricade-adoption-reconciliation") end
    local r=person(id); local work=r and r.barricadeWork
    if not work then return true end
    if type(work)~="table" or getmetatable(work) then return false end
    local ps=r.proceduralPlanning
    local p=type(ps)=="table" and type(ps.purposes)=="table" and ps.purposes[work.purposeId]
    if p~=nil and (type(p)~="table" or getmetatable(p)) then return false end
    local admission=p and p.admission
    if admission~=nil and (type(admission)~="table" or getmetatable(admission)) then return false end
    local pinned=admission and admission.owner=="SAOBuild" and admission.correlationId==work.id
    -- A refused terminal write can leave interrupted work without an outcome.
    -- Recover that exact pinned admission through the same conservative guards.
    if work.status~="boarding" and (work.status~="interrupted" or work.resultSequence~=nil or not pinned) then
        return not pinned
    end
    local s,at=ledger(r),hours()
    if p and (type(p.steps)~="table" or getmetatable(p.steps) or not integer(p.cursor) or p.cursor<1) then return false end
    local step=p and p.steps[p.cursor]
    local material=p and p.materialWork
    local world=getWorld()
    local n=type(work.id)=="string" and tonumber(work.id:match("/barricade%-work/(%d+)$"))
    if ordinary(id,body)~=r or r.id~=id or not s or not at or s.nextResult>=999999999
        or getmetatable(work) or not integer(n) or n<1 or n~=s.nextWork or work.id~=id.."/barricade-work/"..n
        or work.actorId~=id or work.nativeOwner~="ISBarricadeAction" or work.resultSequence~=nil
        or type(work.purposeId)~="string" or type(work.stepId)~="string" or type(work.entryKey)~="string"
        or type(work.itemId)~="string" or type(work.hammerId)~="string" or type(work.world)~="string"
        or not world or work.world~=world:getWorld() or work.bodyToken~=nil and type(work.bodyToken)~="string"
        or not finite(work.startedAt) or work.startedAt>at or not integer(work.planksBefore) or work.planksBefore>4
        or not finite(work.x) or not finite(work.y) or not finite(work.z) or work.x%1~=0 or work.y%1~=0 or work.z%1~=0
        or not integer(work.objectIndex) or type(work.north)~="boolean"
        or work.entryKey~="barricade:"..work.x..":"..work.y..":"..work.z..":"..work.objectIndex..":"..tostring(work.north)
        or not p or p.id~=work.purposeId or p.status=="completed" or p.status=="abandoned"
        or type(material)~="table" or getmetatable(material) or material.operation~="board" or material.entryKey~=work.entryKey
        or type(step)~="table" or getmetatable(step) or step.id~=work.stepId or step.owner~="SAOBuild" or step.token~="construction:boarded"
        or step.target~=work.entryKey or step.status=="completed"
        or not admission or admission.owner~="SAOBuild" or admission.correlationId~=work.id
        or admission.stepId~=work.stepId or admission.target~=work.entryKey or admission.token~="construction:boarded"
        or not finite(admission.at) or admission.at~=work.startedAt then return false end
    for key,value in pairs(work) do
        local t=type(value)
        if type(key)~="string" or t~="string" and t~="number" and t~="boolean"
            or t=="string" and #value>512 or t=="number" and not finite(value) then return false end
    end
    if SAOJavaBridge:hasPendingActions(body) then return false end
    local q=ISTimedActionQueue.getTimedActionQueue(body)
    if q.current or #q.queue>0 then return false end
    for _,sequence in ipairs(s.order) do
        local row=B.outcome(id,sequence)
        if not row then return false end
        if row.workId==work.id then return false end
    end
    while #s.order>=MAX_RESULTS do
        local first=s.outcomes[tostring(s.order[1])]
        if first.planningAcknowledged~=true then return false end
        s.outcomes[tostring(table.remove(s.order,1))]=nil
    end
    s.nextResult=s.nextResult+1
    local row={id=id.."/barricade-result/"..s.nextResult,sequence=s.nextResult,actorId=id,
        workId=work.id,purposeId=work.purposeId,stepId=work.stepId,entryKey=work.entryKey,
        status="interrupted",reason="barricade-runtime-unavailable",startedAt=work.startedAt,endedAt=at,
        nativeOwner="ISBarricadeAction",itemId=work.itemId,hammerId=work.hammerId,world=work.world,
        bodyToken=work.bodyToken,x=work.x,y=work.y,z=work.z,objectIndex=work.objectIndex,north=work.north,
        planksBefore=work.planksBefore,plankConsumed=false,nailsConsumed=0,barricadeChanged=false,
        nativeAttempted=false,nativeObservability="runtime-unavailable"}
    s.outcomes[tostring(s.nextResult)]=row; s.order[#s.order+1]=s.nextResult
    work.status,work.reason,work.resultSequence="interrupted",row.reason,s.nextResult
    B.flush(id)
    return row.planningAcknowledged==true and p.admission==nil
end
function B.active(id,body)
    id=tostring(id); local b=runtime[id]
    if not b then
        return not B.reconcileSaved(id,body)
    end
    local c=b.current
    if b.closed or b.body~=body or not bound(b,true) or not c
        or (not c.performed and b.queue:indexOf(c.action)==-1 and b.queue.current~=c.action) then
        return not B.interrupt(id,body,"barricade-owner-or-queue-changed")
    end
    return true
end
function B.runtimeCount() local n=0; for _ in pairs(runtime) do n=n+1 end; return n end
function B.retryCancellations()
    local n=math.min(#cancellations,MAX_RETRIES)
    for _=1,n do
        local b=table.remove(cancellations,1)
        if not b then break end
        b.retryQueued=false
        if runtime[b.id]==b then B.interrupt(b.id,b.body,"barricade-cancellation-retry") end
    end
end
function B.reset(reason)
    for id,b in pairs(runtime) do B.interrupt(id,b.body,reason or "barricade-world-reset") end
    B.expireOffers()
end
if Events and Events.OnTick then Events.OnTick.Add(B.retryCancellations); Events.OnTick.Add(B.expireOffers) end
if Events and Events.OnInitGlobalModData then Events.OnInitGlobalModData.Add(B.reset) end
if Events and Events.OnGameStart then Events.OnGameStart.Add(function() B.reset("world-reset"); B.install() end) end
return B
