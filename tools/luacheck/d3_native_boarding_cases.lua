-- Actual installed action/equipment/transfer/queue; controlled body, map and dispatch.
ISInventoryPage={}
ItemTag={HAMMER='Hammer',WEARABLE='Wearable',REPLACE_PRIMARY='ReplacePrimary',LIGHTER='Lighter'}
ItemType={RADIO='Radio'}
CharacterTrait={HANDY='Handy',DEXTROUS='Dextrous',ALL_THUMBS='AllThumbs'}
Perks={Woodwork='Woodwork',MetalWelding='MetalWelding'}
IsoObjectChange={STATE='STATE'}
Metabolics={LightWork='LightWork'}
DebugType={Action={warn=function() end}}
buildUtil={setHaveConstruction=function(sq) sq.construction=true end}
function isClient() return false end
function isServer() return false end
function getTimestampMs() return 10000 end
function getCore() return {getGameMode=function() return 'Sandbox' end} end
function getText(v) return v end
function getPlayerHotbar() return nil end
function getPlayerInventory() return {refreshBackpacks=function() end} end
function sendRemoveItemsFromContainer(inv,items) inv.paid=(inv.paid or 0)+items:size() end
function addXpNoMultiplier(body,perk,amount) body.xp=(body.xp or 0)+amount end
function addSound(body,x,y,z,radius,volume) body.nativeWorldSounds=(body.nativeWorldSounds or 0)+1 end
local originalInstance=instanceof
local originalTimed=LuaTimedActionNew.new
LuaTimedActionNew.new=function(action,body)
    local a=originalTimed(action,body)
    a.finished=function() return a.nativeFinished==true end
    a.isForceComplete=function() return false end
    a.looped=true
    function a:setLoopedAction(v) self.looped=v;self.loopWrites=(self.loopWrites or 0)+1 end
    function a:getJobDelta() return self.jobDelta or 0 end
    function a:setActionAnim(v) self.animation=v end
    function a:overrideWeaponType() body.weaponAnimation='equipment-override' end
    function a:restoreWeaponType()
        self.weaponRestores=(self.weaponRestores or 0)+1;body.weaponAnimation='original'
    end
    return a
end
function instanceof(o,kind)
    return originalInstance(o,kind) or type(o)=='table' and
        (kind=='InventoryItem' and o.fullType~=nil or kind=='BarricadeAble'
            and (o.kind=='IsoWindow' or o.kind=='IsoDoor' or o.kind=='IsoThumpable'))
end
SAOJavaBridge.canSeeBoardable=function(_,body,target)
    local sq=target:getSquare()
    local side=body:getCurrentSquare()==sq and -1 or 1
    local dx,dy=target:getNorth() and 0 or side,target:getNorth() and side or 0
    return body.visible and dx*body:getForwardDirectionX()+dy*body:getForwardDirectionY()>=0
end
local function list(items)
    return {size=function() return #items end,get=function(_,i) return items[i+1] end}
end
local function item(kind,id,inventory)
    local i={kind='InventoryItem',fullType='Base.'..kind,id=id,container=inventory,condition=10}
    function i:getID() return self.id end
    function i:getFullType() return self.fullType end
    function i:getType() return self.fullType:match("%.(.+)$") end
    function i:getName() return self:getType() end
    function i:getContainer() return self.container end
    function i:hasTag(tag) return self.fullType=='Base.Hammer' and tag==ItemTag.HAMMER end
    function i:getCondition() return self.condition end
    function i:setCondition(v) self.condition=v end
    function i:isBroken() return self.condition<=0 end
    function i:getIsCraftingConsumed() return self.consumed==true end
    function i:isRequiresEquippedBothHands() return false end
    function i:isForceDropHeavyItem() return false end
    function i:IsInventoryContainer() return false end
    function i:canBeActivated() return false end
    function i:getCurrentUsesFloat() return 1 end
    function i:setJobDelta(v) self.jobDelta=v;self.jobWrites=(self.jobWrites or 0)+1 end
    function i:setJobType(v) self.jobType=v end
    function i:getJobType() return self.jobType or 'controlled' end
    function i:getEquipSound() return self.equipSound end
    function i:isFavorite() return false end
    function i:getActualWeight() return 1 end
    return i
end
local function inventory(inv,root)
    local function matchesType(item,t)
        return t:find('.',1,true) and item:getFullType()==t or not t:find('.',1,true) and item:getType()==t
    end
    function inv:getItems()
        local items=self.items
        return {size=function() return #items end,get=function(_,index) return items[index+1] end,
            indexOf=function(_,item) for index,value in ipairs(items) do if value==item then return index-1 end end;return -1 end,
            set=function(_,index,item) local previous=items[index+1];items[index+1]=item;return previous end}
    end
    function inv:getFirstType(t)
        for _,i in ipairs(self.items) do if matchesType(i,t) then return i end end
    end
    function inv:getFirstTypeRecurse(t) return self:getFirstType(t) or self.nested and self.nested:getFirstType(t) end
    function inv:getFirstTypeEval(t,predicate)
        for _,i in ipairs(self.items) do if matchesType(i,t) and predicate(i) then return i end end
        return self.nested and self.nested:getFirstTypeEval(t,predicate)
    end
    function inv:getFirstTypeEvalRecurse(t,predicate) return self:getFirstTypeEval(t,predicate) end
    function inv:getFirstTag(t)
        for _,i in ipairs(self.items) do if i:hasTag(t) then return i end end
    end
    function inv:getFirstTagRecurse(t) return self:getFirstTag(t) or self.nested and self.nested:getFirstTag(t) end
    function inv:getFirstTagEval(t,predicate)
        for _,i in ipairs(self.items) do if i:hasTag(t) and predicate(i) then return i end end
    end
    function inv:getFirstTagEvalRecurse(t,predicate)
        return self:getFirstTagEval(t,predicate) or self.nested and self.nested:getFirstTagEval(t,predicate)
    end
    function inv:getAllType(t)
        local out={};for _,i in ipairs(self.items) do if matchesType(i,t) then out[#out+1]=i end end
        return list(out)
    end
    function inv:getAllTypeRecurse(t)
        local out={};for _,c in ipairs({self,self.nested}) do
            for _,i in ipairs(c.items) do if matchesType(i,t) then out[#out+1]=i end end
        end
        return list(out)
    end
    function inv:getAllTypeEval(t,predicate)
        local out={};for _,i in ipairs(self.items) do if matchesType(i,t) and predicate(i) then out[#out+1]=i end end
        return list(out)
    end
    function inv:getAllTypeEvalRecurse(t,predicate)
        local out={};for _,c in ipairs({self,self.nested}) do
            for _,i in ipairs(c.items) do if matchesType(i,t) and predicate(i) then out[#out+1]=i end end
        end
        return list(out)
    end
    function inv:containsRecursive(i) return self:contains(i) or self.nested and self.nested:contains(i) or false end
    function inv:getItemWithID(id)
        for _,i in ipairs(self.items) do if i:getID()==id then return i end end
    end
    function inv:getItemCount(t,recurse)
        return (recurse and self:getAllTypeRecurse(t) or self:getAllType(t)):size()
    end
    function inv:RemoveAll(t,n)
        local out={}
        for index=#self.items,1,-1 do
            local i=self.items[index]
            if i:getType()==t then table.insert(out,1,i) end
        end
        while #out>n do table.remove(out) end
        for _,i in ipairs(out) do self:Remove(i) end
        return list(out)
    end
    function inv:AddItems(items)
        for index=0,items:size()-1 do local i=items:get(index);self.items[#self.items+1]=i;i.container=self end
    end
    function inv:getOutermostContainer() return root or self end
    function inv:setDrawDirty(v) end
    function inv:setHasBeenLooted(v) end
    function inv:getType() return 'inventory' end
    function inv:getParent() return nil end
    function inv:getTakeSound() return nil end
    function inv:isExistYet() return true end
    function inv:hasRoomFor() return true end
    function inv:isRemoveItemAllowed() return true end
    function inv:isItemAllowed() return true end
    function inv:isInside() return false end
    function inv:isInCharacterInventory() return true end
    function inv:isVehicleSeat() return false end
    function inv:getCapacityWeight() return 1 end
    function inv:getMaxWeight() return 50 end
    return inv
end
IsoBarricade={AddBarricadeToObject=function(target,body)
    target.barricade=target.barricade or {planks=0,canAddPlank=function(self) return self.planks<4 end,
        getNumPlanks=function(self) return self.planks end,
        addPlank=function(self,actor,plank) self.planks=self.planks+1; self.exactPlank=plank end,
        transmitCompleteItemToClients=function(self) self.synced=true end}
    return target.barricade
end}
ISTransferAction={transferItem=function(_,body,i,source,dest,square)
    source:Remove(i);dest.items[#dest.items+1]=i;i.container=dest;return i
end}
local function fixture(id,nested)
    local f=__windowFixture(id)
    f.inventory.items={}
    inventory(f.inventory)
    f.hammer=item('Hammer',1,f.inventory)
    f.plank=item('Plank',2,f.inventory)
    f.nails={item('Nails',3,f.inventory),item('Nails',4,f.inventory)}
    f.inventory.items={f.hammer,f.plank,f.nails[1],f.nails[2]}
    function f.window:getBarricadeForCharacter(body) return self.barricade end
    function f.body:getPrimaryHandItem() return self.primary end
    function f.body:getSecondaryHandItem() return self.secondary end
    function f.body:setPrimaryHandItem(i) self.primary=i end
    function f.body:setSecondaryHandItem(i) self.secondary=i end
    function f.body:hasEquipped(t)
        return self.primary and self.primary:getType()==t or self.secondary and self.secondary:getType()==t or false
    end
    function f.body:hasEquippedTag(t)
        return self.primary and self.primary:hasTag(t) or self.secondary and self.secondary:hasTag(t) or false
    end
    function f.body:getPerkLevel() return 0 end
    function f.body:getHammerSoundMod() return 1 end
    function f.body:hasTrait() return false end
    function f.body:getPlayerNum() return 0 end
    function f.body:getClothingItem_Back() return nil end
    function f.body:isEquippedClothing() return false end
    function f.body:isWearingAwkwardGloves() return false end
    function f.body:isPlayerMoving() return false end
    function f.body:reportEvent(v) self.lastEvent=v end
    function f.body:setMetabolicTarget(v) self.metabolic=v end
    f.emitter={stopped={},triggered={},playing={}}
    function f.emitter:playSound(v) self.playing[v]=true;return v end
    function f.emitter:isPlaying(v) return self.playing[v]==true end
    function f.emitter:stopSound(v)
        self.stopped[v]=(self.stopped[v] or 0)+1;self.playing[v]=false
    end
    function f.emitter:stopOrTriggerSound(v)
        self.triggered[v]=(self.triggered[v] or 0)+1;self.playing[v]=false
    end
    function f.body:getEmitter() return f.emitter end
    if nested then
        local bag={items=f.inventory.items}
        function bag:contains(i) for _,x in ipairs(self.items) do if x==i then return true end end;return false end
        function bag:Remove(i) for n,x in ipairs(self.items) do if x==i then table.remove(self.items,n);i.container=nil;return end end end
        inventory(bag,f.inventory)
        f.inventory.nested=bag;f.inventory.items={}
        for _,i in ipairs(bag.items) do i.container=bag end
    end
    return f
end
local function aperture(id,kind,door,window,open)
    local f=fixture(id)
    f.window.kind,f.window.open,f.window.door,f.window.window=kind,open,door,window
    function f.window:IsOpen() return self.open end
    function f.window:isDoor() return self.door end
    function f.window:isWindow() return self.window end
    function f.window:ToggleDoor(body) self.open=not self.open;self.toggles=(self.toggles or 0)+1 end
    return f
end
local function plan(f,offer)
    local P=SAO.ProceduralPlanning
    local p=P.planFortification(f.id,{operation='board',entryKey=offer.entryKey,insideOwnedGround=true,
        knownGround=true,materials={hammer=1,plank=1,nails=2},destination=SAO.Build.destination(f.id,f.body,offer)})
    if not p then error('plan refused '..f.id) end
    f.purpose=p;return p
end
local function admit(f)
    local offer=SAO.Build.offer(f.id,f.body)
    if not offer then error('offer refused '..f.id) end
    local p=plan(f,offer)
    if not SAO.Build.begin(f.id,f.body,offer,p.id,p.steps[p.cursor].id) then error('begin refused '..f.id) end
    return ISTimedActionQueue.getTimedActionQueue(f.body).current
end
local function tryAdmit(f)
    local offer=SAO.Build.offer(f.id,f.body)
    if not offer then return false end
    local p=plan(f,offer)
    return SAO.Build.begin(f.id,f.body,offer,p.id,p.steps[p.cursor].id)
end
local function sameInventory(inv,before)
    if #inv.items~=#before then return false end
    for _,item in ipairs(before) do if not inv:contains(item) or item:getContainer()~=inv then return false end end
    return true
end
local function finish(f,prepareOnly)
    local q=ISTimedActionQueue.getTimedActionQueue(f.body)
    while q.current do
        local a=q.current
        if prepareOnly and a.Type=='ISBarricadeAction' then return a end
        a.action.nativeFinished=true
        a.action.restoreWeaponType=function() end
        a.action.stopTimedActionAnim=function() end
        a.action.setLoopedAction=function() end
        a.getNotFullFloorSquare=function() return nil end
        a.playTransferCompleteSound=function() end
        a.playSourceContainerCloseSound=function() end
        a.playDestContainerCloseSound=function() end
        a.stopLoopingSound=function() end
        local result=a:perform()
        if a.Type~='ISInventoryTransferAction' then a:complete() end
        if q.current==a then error('action did not retire '..a.Type) end
    end
    return SAO.Build.outcome(f.id,1)
end
local function foreignPaymentRefused(id,kind,consumed,afterPerform,custody)
    local f=fixture(id);admit(f)
    local action=finish(f,true);action.action.nativeFinished=true
    if afterPerform then action:perform() end
    local shadow=item(kind,81,f.inventory);shadow.fullType='OtherMod.'..kind;shadow.consumed=consumed
    if custody=='nil' then shadow.container=nil
    elseif custody=='other' then shadow.container=inventory({items={shadow}}) end
    local originalContainer=shadow:getContainer()
    table.insert(f.inventory.items,1,shadow)
    local result
    if afterPerform then result=action:complete() else result=action:perform() end
    local refused=result==false and not f.window.barricade and f.inventory.paid==nil
        and f.inventory:contains(shadow) and shadow:getContainer()==originalContainer and shadow.consumed==consumed
        and f.inventory:contains(f.plank) and f.inventory:contains(f.nails[1]) and f.inventory:contains(f.nails[2])
        and not SAO.Build.outcome(f.id,1).nativeAttempted
    SAO.Build.forget(f.id)
    return refused
end
local function reopenedDoorRefused(id,kind,afterPerform)
    local f=aperture(id,kind,true,false,true);admit(f)
    local action=finish(f,true);action:start();action.action.nativeFinished=true
    if afterPerform then action:perform() end
    f.window.open=true
    local result
    if afterPerform then result=action:complete() else result=action:perform() end
    local row=SAO.Build.outcome(f.id,1)
    local refused=result==false and not f.window.barricade and f.window.open==true and f.window.toggles==1
        and f.inventory:contains(f.plank) and f.inventory:contains(f.nails[1]) and f.inventory:contains(f.nails[2])
        and row and row.status=='interrupted' and row.nativeAttempted==false and row.plankConsumed==false
    SAO.Build.forget(f.id)
    return refused
end
local function startPreparation(f,a)
    if a.Type=='ISEquipWeaponAction' then a.item.equipSound='controlled-equip' end
    a:start()
    a.action.jobDelta=.625;a:update()
    if a.Type=='ISEquipWeaponAction' then a:overrideWeaponType()
    else
        -- Captured native handles exercise the installed close-sound methods.
        a.sourceContainerOpenSound=f.emitter:playSound('controlled-source-open')
        a.destContainerOpenSound=f.emitter:playSound('controlled-dest-open')
    end
    f.body.farming=true
    return a.action
end
local function successor(f,sharedItem)
    local a=ISBaseTimedAction:new(f.body)
    a.Type='ControlledSuccessor'
    function a:isValidStart() return true end
    function a:isValid() return true end
    function a:begin()
        ISBaseTimedAction.begin(self)
        self.character.farming=true;self.character.weaponAnimation='successor'
        if sharedItem then sharedItem:setJobDelta(.875) end
        self.sound=f.emitter:playSound('controlled-successor')
    end
    ISTimedActionQueue.add(a)
    return a
end
function __runBoardingCases()
    local B,P=SAO.Build,SAO.ProceduralPlanning
    local check=__windowCheck
    local empty=fixture('empty');empty.inventory.items={}
    local offer=B.offer(empty.id,empty.body)
    check('offer_without_materials',offer~=nil)
    local destination=B.destination(empty.id,empty.body,offer)
    check('sealed_destination',destination and destination.key==offer.entryKey and destination.x==0)
    offer.entryKey='forged'
    check('forged_destination_refuses',B.destination(empty.id,empty.body,offer)==nil)
    local unseen=fixture('unseen');unseen.body.visible=false
    check('unseen_not_offered',B.offer(unseen.id,unseen.body)==nil)
    local far=fixture('far');far.body.here=far.cell:getGridSquare(1,1,0);far.body.x=1.5;far.body.y=1.5
    check('wrong_interaction_side_refuses',B.offer(far.id,far.body)==nil)
    local before=fixture('prefall');__fall=false
    check('prefall_refuses',B.offer(before.id,before.body)==nil);__fall=true
    local openDoor=aperture('native-open-door','IsoDoor',true,false,true)
    check('open_door_offered_without_mutation',B.offer(openDoor.id,openDoor.body)~=nil
        and openDoor.window.open==true and not openDoor.window.toggles and not openDoor.rec.barricadeWork)
    admit(openDoor);local doorAction=finish(openDoor,true);doorAction:start()
    check('open_door_native_start_closes',doorAction.isStarted==true and doorAction:isValid()==true
        and openDoor.window.open==false and openDoor.window.toggles==1 and openDoor.body.nativeWorldSounds==1
        and openDoor.inventory:contains(openDoor.plank) and not openDoor.window.barricade)
    local doorResult=doorAction:isValid()==true and finish(openDoor)
    check('open_door_native_completion_paid',doorResult and doorResult.status=='completed'
        and openDoor.window.barricade.exactPlank==openDoor.plank and openDoor.inventory.paid==3
        and openDoor.window.open==false and openDoor.window.toggles==1)
    B.forget(openDoor.id)
    local openThump=aperture('native-open-thump-door','IsoThumpable',true,false,true)
    check('open_thumpable_door_offered_without_mutation',B.offer(openThump.id,openThump.body)~=nil
        and openThump.window.open==true and not openThump.window.toggles and not openThump.rec.barricadeWork)
    admit(openThump);local thumpAction=finish(openThump,true);thumpAction:start()
    check('open_thumpable_door_native_start_closes',thumpAction.isStarted==true and thumpAction:isValid()==true
        and openThump.window.open==false and openThump.window.toggles==1 and openThump.body.nativeWorldSounds==1
        and openThump.inventory:contains(openThump.plank) and not openThump.window.barricade)
    local thumpResult=thumpAction:isValid()==true and finish(openThump)
    check('open_thumpable_door_native_completion_paid',thumpResult and thumpResult.status=='completed'
        and openThump.window.barricade.exactPlank==openThump.plank and openThump.inventory.paid==3
        and openThump.window.open==false and openThump.window.toggles==1)
    B.forget(openThump.id)
    local closedDoor=aperture('native-closed-door','IsoDoor',true,false,false);admit(closedDoor)
    local closedDoorAction=finish(closedDoor,true);closedDoorAction:start();local closedDoorResult=finish(closedDoor)
    check('closed_door_native_path_preserved',closedDoorResult and closedDoorResult.status=='completed'
        and closedDoor.window.open==false and not closedDoor.window.toggles and closedDoor.inventory.paid==3)
    local closedThump=aperture('native-closed-thump-door','IsoThumpable',true,false,false);admit(closedThump)
    local closedThumpAction=finish(closedThump,true);closedThumpAction:start();local closedThumpResult=finish(closedThump)
    check('closed_thumpable_door_native_path_preserved',closedThumpResult and closedThumpResult.status=='completed'
        and closedThump.window.open==false and not closedThump.window.toggles and closedThump.inventory.paid==3)
    check('reopened_door_after_start_refuses',reopenedDoorRefused('reopened-door-perform','IsoDoor',false))
    check('reopened_thumpable_door_after_start_refuses',reopenedDoorRefused('reopened-thump-perform','IsoThumpable',false))
    check('reopened_door_before_complete_refuses',reopenedDoorRefused('reopened-door-complete','IsoDoor',true))
    check('reopened_thumpable_door_before_complete_refuses',reopenedDoorRefused('reopened-thump-complete','IsoThumpable',true))
    local consumedFirst=fixture('consumed-plank-first')
    local consumedPlank=item('Plank',51,consumedFirst.inventory);consumedPlank.consumed=true
    table.insert(consumedFirst.inventory.items,1,consumedPlank)
    local preserved={};for _,material in ipairs(consumedFirst.inventory.items) do preserved[#preserved+1]=material end
    local plankAdmitted=tryAdmit(consumedFirst)
    check('eligible_plank_after_consumed_selected',plankAdmitted==true
        and consumedFirst.rec.barricadeWork.itemId==tostring(consumedFirst.plank:getID())
        and sameInventory(consumedFirst.inventory,preserved) and consumedPlank.consumed==true
        and not consumedFirst.window.barricade)
    local plankResult=plankAdmitted and finish(consumedFirst)
    check('eligible_plank_native_exact_payment',plankResult and plankResult.status=='completed'
        and consumedFirst.window.barricade.exactPlank==consumedFirst.plank
        and consumedFirst.inventory:contains(consumedPlank) and not consumedFirst.inventory:contains(consumedFirst.plank)
        and consumedFirst.inventory.paid==3)
    B.forget(consumedFirst.id)
    local allPlanks=fixture('all-planks-consumed');allPlanks.plank.consumed=true
    check('all_consumed_planks_refuse',tryAdmit(allPlanks)==false and allPlanks.rec.barricadeWork==nil
        and allPlanks.purpose.admission==nil and not allPlanks.window.barricade
        and allPlanks.inventory:contains(allPlanks.plank) and not ISTimedActionQueue.getTimedActionQueue(allPlanks.body).current)
    local nestedPlank=fixture('nested-eligible-plank',true)
    local rootConsumed=item('Plank',52,nestedPlank.inventory);rootConsumed.consumed=true
    nestedPlank.inventory.items={rootConsumed}
    local nestedAdmitted=tryAdmit(nestedPlank)
    local nestedResult=nestedAdmitted and finish(nestedPlank)
    check('nested_eligible_plank_preserves_consumed_root',nestedResult and nestedResult.status=='completed'
        and nestedPlank.window.barricade.exactPlank==nestedPlank.plank and nestedPlank.inventory:contains(rootConsumed)
        and rootConsumed:getContainer()==nestedPlank.inventory and not nestedPlank.inventory.nested:contains(nestedPlank.plank))
    B.forget(nestedPlank.id)
    local consumedNails=fixture('consumed-nails-first')
    local reservedNails={item('Nails',53,consumedNails.inventory),item('Nails',54,consumedNails.inventory)}
    for _,nail in ipairs(reservedNails) do nail.consumed=true;table.insert(consumedNails.inventory.items,1,nail) end
    local nailsBefore={};for _,material in ipairs(consumedNails.inventory.items) do nailsBefore[#nailsBefore+1]=material end
    local nailsAdmitted=tryAdmit(consumedNails)
    check('eligible_nails_preparation_preserves_inventory',nailsAdmitted==true and sameInventory(consumedNails.inventory,nailsBefore)
        and reservedNails[1].consumed==true and reservedNails[2].consumed==true and not consumedNails.window.barricade)
    local nailsResult=nailsAdmitted and finish(consumedNails)
    check('eligible_nails_after_consumed_native_payment',nailsResult and nailsResult.status=='completed'
        and nailsResult.nailsConsumed==2 and consumedNails.inventory:contains(reservedNails[1])
        and consumedNails.inventory:contains(reservedNails[2]) and reservedNails[1]:getContainer()==consumedNails.inventory
        and reservedNails[2]:getContainer()==consumedNails.inventory
        and not consumedNails.inventory:contains(consumedNails.nails[1]) and not consumedNails.inventory:contains(consumedNails.nails[2])
        and consumedNails.inventory.paid==3)
    B.forget(consumedNails.id)
    local allNails=fixture('all-nails-consumed');allNails.nails[1].consumed=true;allNails.nails[2].consumed=true
    check('all_consumed_nails_refuse',tryAdmit(allNails)==false and allNails.rec.barricadeWork==nil
        and allNails.purpose.admission==nil and not allNails.window.barricade
        and allNails.inventory:contains(allNails.nails[1]) and not ISTimedActionQueue.getTimedActionQueue(allNails.body).current)
    local nestedNails=fixture('nested-eligible-nails',true)
    local rootReserved=item('Nails',55,nestedNails.inventory);rootReserved.consumed=true
    nestedNails.inventory.items={rootReserved}
    local nestedNailsAdmitted=tryAdmit(nestedNails)
    local nestedNailsResult=nestedNailsAdmitted and finish(nestedNails)
    check('nested_eligible_nails_preserve_consumed_root',nestedNailsResult and nestedNailsResult.status=='completed'
        and nestedNailsResult.nailsConsumed==2 and nestedNails.inventory:contains(rootReserved)
        and rootReserved:getContainer()==nestedNails.inventory
        and not nestedNails.inventory.nested:contains(nestedNails.nails[1]) and not nestedNails.inventory.nested:contains(nestedNails.nails[2]))
    B.forget(nestedNails.id)
    local paymentOrder=fixture('changed-payment-order');admit(paymentOrder)
    local paymentOrderAction=finish(paymentOrder,true)
    local unboundPlank=item('Plank',56,paymentOrder.inventory)
    table.insert(paymentOrder.inventory.items,1,unboundPlank)
    paymentOrderAction.action.nativeFinished=true
    check('changed_native_payment_order_refuses',paymentOrderAction:perform()==false and not paymentOrder.window.barricade
        and paymentOrder.inventory:contains(paymentOrder.plank) and paymentOrder.inventory:contains(unboundPlank)
        and paymentOrder.inventory.paid==nil)
    B.forget(paymentOrder.id)
    check('foreign_plank_before_perform_refuses',foreignPaymentRefused('foreign-plank-perform','Plank',false,false))
    check('foreign_plank_before_complete_refuses',foreignPaymentRefused('foreign-plank-complete','Plank',false,true))
    check('consumed_foreign_plank_before_perform_refuses',foreignPaymentRefused('consumed-foreign-plank-perform','Plank',true,false))
    check('consumed_foreign_plank_before_complete_refuses',foreignPaymentRefused('consumed-foreign-plank-complete','Plank',true,true))
    check('foreign_nails_before_perform_refuses',foreignPaymentRefused('foreign-nails-perform','Nails',false,false))
    check('foreign_nails_before_complete_refuses',foreignPaymentRefused('foreign-nails-complete','Nails',false,true))
    check('consumed_foreign_nails_before_perform_refuses',foreignPaymentRefused('consumed-foreign-nails-perform','Nails',true,false))
    check('consumed_foreign_nails_before_complete_refuses',foreignPaymentRefused('consumed-foreign-nails-complete','Nails',true,true))
    check('nil_container_plank_before_perform_refuses',foreignPaymentRefused('nil-plank-perform','Plank',false,false,'nil'))
    check('nil_container_plank_before_complete_refuses',foreignPaymentRefused('nil-plank-complete','Plank',true,true,'nil'))
    check('foreign_owned_plank_before_perform_refuses',foreignPaymentRefused('owned-plank-perform','Plank',true,false,'other'))
    check('foreign_owned_plank_before_complete_refuses',foreignPaymentRefused('owned-plank-complete','Plank',false,true,'other'))
    check('nil_container_nails_before_perform_refuses',foreignPaymentRefused('nil-nails-perform','Nails',false,false,'nil'))
    check('nil_container_nails_before_complete_refuses',foreignPaymentRefused('nil-nails-complete','Nails',true,true,'nil'))
    check('foreign_owned_nails_before_perform_refuses',foreignPaymentRefused('owned-nails-perform','Nails',true,false,'other'))
    check('foreign_owned_nails_before_complete_refuses',foreignPaymentRefused('owned-nails-complete','Nails',false,true,'other'))
    local foreignInitial=fixture('foreign-initial-payment')
    local initialShadows={item('Plank',82,foreignInitial.inventory),item('Nails',83,foreignInitial.inventory),item('Nails',84,foreignInitial.inventory)}
    local initialBefore={};for _,material in ipairs(foreignInitial.inventory.items) do initialBefore[#initialBefore+1]=material end
    for index,shadow in ipairs(initialShadows) do
        shadow.fullType='OtherMod.'..shadow:getType();shadow.consumed=index~=2
        table.insert(foreignInitial.inventory.items,1,shadow);initialBefore[#initialBefore+1]=shadow
    end
    local foreignInitialAdmitted=tryAdmit(foreignInitial)
    check('foreign_module_admission_preserves_inventory',foreignInitialAdmitted==true
        and sameInventory(foreignInitial.inventory,initialBefore) and not foreignInitial.window.barricade)
    local foreignInitialResult=foreignInitialAdmitted and finish(foreignInitial)
    check('foreign_module_native_payment_preserves_shadows',foreignInitialResult and foreignInitialResult.status=='completed'
        and foreignInitial.window.barricade.exactPlank==foreignInitial.plank and foreignInitial.inventory.paid==3
        and foreignInitial.inventory:contains(initialShadows[1]) and foreignInitial.inventory:contains(initialShadows[2])
        and foreignInitial.inventory:contains(initialShadows[3]) and sameInventory(foreignInitial.inventory,{foreignInitial.hammer,
            initialShadows[1],initialShadows[2],initialShadows[3]}))
    B.forget(foreignInitial.id)
    local f=fixture('completed');local first=admit(f)
    check('admission_has_no_effect',not f.window.barricade and f.inventory:contains(f.plank)
        and f.purpose.status~='completed' and B.outcome(f.id,1)==nil)
    check('native_hammer_preparation_queued',first.Type=='ISEquipWeaponAction' and first.primary==true and first.item==f.hammer)
    __hours=101
    local row=finish(f)
    check('native_barricade_payment',row and row.status=='completed' and row.plankConsumed and row.nailsConsumed==2
        and f.window.barricade.planks==1 and f.window.barricade.exactPlank==f.plank and f.inventory.paid==3)
    check('native_equipment_convention',f.body.primary==f.hammer and f.body.secondary==nil)
    check('authenticated_planner_once',f.purpose.status=='completed' and row.planningAcknowledged==true
        and P.consumeBarricadeOutcome(f.id,1)==true and B.runtimeCount()==0)
    row.status='forged'
    check('detached_outcome',B.outcome(f.id,1).status=='completed')
    __records[f.id]=__nativeRoundtrip(f.rec)
    check('durable_native_reload',B.outcome(f.id,1).status=='completed' and P.consumeBarricadeOutcome(f.id,1)==true)
    check('retired_duplicate_callbacks_inert',first:perform()==false and first:complete()==false and first:stop()==false
        and __records[f.id].barricade.nextResult==1)
    local targetRace=fixture('target-race');admit(targetRace)
    local ta=finish(targetRace,true);ta.action.nativeFinished=true;ta:perform()
    ta.item=fixture('target-other').window
    check('changed_board_target_before_effect_refuses',ta:complete()==false and not targetRace.window.barricade
        and targetRace.inventory:contains(targetRace.plank))
    B.forget(targetRace.id)
    local baseline=fixture('baseline');admit(baseline)
    local baselineAction=finish(baseline,true);baselineAction.action.nativeFinished=true;baselineAction:perform()
    IsoBarricade.AddBarricadeToObject(baseline.window,baseline.body):addPlank(baseline.body,baseline.plank)
    check('changed_barricade_baseline_refuses',baselineAction:complete()==false and baseline.inventory:contains(baseline.plank))
    B.forget(baseline.id)
    local payment=fixture('payment');admit(payment)
    local paymentAction=finish(payment,true);paymentAction.action.nativeFinished=true;paymentAction:perform()
    payment.inventory:Remove(payment.nails[1])
    check('missing_nails_before_effect_refuses',paymentAction:complete()==false and not payment.window.barricade
        and payment.inventory:contains(payment.plank))
    B.forget(payment.id)
    local owner=fixture('transfer');admit(owner)
    local ownerAction=finish(owner,true);ownerAction.action.nativeFinished=true;ownerAction:perform()
    owner.rec.crossedTransferPending={token='controlled'}
    check('transfer_pending_before_effect_refuses',ownerAction:complete()==false and not owner.window.barricade)
    B.forget(owner.id)
    local side=fixture('side');admit(side)
    local sideAction=finish(side,true);sideAction.action.nativeFinished=true;sideAction:perform()
    side.body.here=side.cell:getGridSquare(0,-1,0);side.body.y=-.5
    check('changed_barricade_side_refuses',sideAction:complete()==false and not side.window.barricade)
    B.forget(side.id)
    local player=fixture('player')
    player.body.primary,player.body.secondary=player.hammer,player.plank
    local playerAction=ISBarricadeAction:new(player.body,player.window,false,false)
    check('installed_native_hammer_type_defect',ItemType.HAMMER==nil and playerAction:isValid()==false)
    ISTimedActionQueue.add(playerAction);playerAction:perform()
    check('player_native_path_preserved',playerAction:complete()==true and player.window.barricade.planks==1
        and not player.inventory:contains(player.plank) and player.inventory.paid==3 and player.rec.barricade==nil)
    local early=fixture('early');local a=admit(early)
    check('complete_before_perform_refuses',a:complete()==false and early.inventory:contains(early.plank)
        and not early.window.barricade and B.outcome(early.id,1).status=='interrupted')
    B.forget(early.id)
    local premature=fixture('premature')
    premature.body.primary,premature.body.secondary=premature.hammer,premature.plank
    local prematureAction=admit(premature)
    check('perform_before_native_end_refuses',prematureAction:perform()==false and not premature.window.barricade)
    B.forget(premature.id)
    local forged=fixture('forged');local fa=admit(forged);fa.item=forged.plank
    fa.action.nativeFinished=true
    check('changed_equipment_target_refuses',fa:perform()==false and not forged.window.barricade)
    B.forget(forged.id)
    local replacement=fixture('replace');local ra=admit(replacement)
    ra.action.nativeFinished=true
    replacement.inventory:Remove(replacement.plank)
    local substitute=item('Plank',2,replacement.inventory)
    replacement.inventory.items[#replacement.inventory.items+1]=substitute
    check('same_id_material_substitution_refuses',ra:perform()==false and not replacement.window.barricade)
    B.forget(replacement.id)
    local replacedBoard=fixture('replace-board')
    replacedBoard.body.primary,replacedBoard.body.secondary=replacedBoard.hammer,replacedBoard.plank
    local ba=admit(replacedBoard)
    ba.action.nativeFinished=true
    replacedBoard.inventory:Remove(replacedBoard.plank)
    local substituteBoard=item('Plank',2,replacedBoard.inventory)
    replacedBoard.inventory.items[#replacedBoard.inventory.items+1]=substituteBoard
    check('board_same_id_material_refuses',ba:perform()==false and not replacedBoard.window.barricade)
    B.forget(replacedBoard.id)
    local nested=fixture('nested',true);admit(nested)
    local nr=finish(nested)
    check('nested_native_transfer_and_board',nr and nr.status=='completed' and not nested.inventory.nested:contains(nested.plank)
        and nested.inventory:contains(nested.hammer) and nested.window.barricade.planks==1)
    local nestedRace=fixture('nested-race',true);local nestedAction=admit(nestedRace)
    nestedAction.action.nativeFinished=true
    nestedAction.srcContainer=nestedRace.inventory
    check('changed_transfer_source_refuses',nestedAction:perform()==false and nestedRace.inventory.nested:contains(nestedRace.plank))
    B.forget(nestedRace.id)
    local broken=fixture('broken')
    local brokenHammer=item('Hammer',99,broken.inventory);brokenHammer.condition=0
    table.insert(broken.inventory.items,1,brokenHammer)
    local brokenFirst=admit(broken)
    check('usable_hammer_selected_after_broken',brokenFirst.item==broken.hammer)
    B.forget(broken.id)
    local transferStop=fixture('transfer-stop',true);local ts=admit(transferStop)
    local tsNative=startPreparation(transferStop,ts)
    local tsItem=ts.item
    check('boarding_transfer_interrupt_native_cleanup',B.interrupt(transferStop.id,transferStop.body,'controlled-stop')==true
        and tsItem.jobDelta==0 and tsNative.looped==false and ts.started==false
        and transferStop.emitter.stopped.RummageInInventory==1
        and transferStop.emitter.triggered['controlled-source-open']==1
        and transferStop.emitter.triggered['controlled-dest-open']==1
        and transferStop.body.farming==false and transferStop.inventory.nested:contains(tsItem)
        and not transferStop.inventory:contains(tsItem) and not transferStop.window.barricade
        and B.runtimeCount()==0)
    local equipStop=fixture('equip-stop');local es=admit(equipStop)
    local esNative=startPreparation(equipStop,es)
    check('boarding_equip_interrupt_native_cleanup',B.interrupt(equipStop.id,equipStop.body,'controlled-stop')==true
        and equipStop.hammer.jobDelta==0 and esNative.weaponRestores==1
        and equipStop.body.weaponAnimation=='original' and equipStop.emitter.stopped['controlled-equip']==1
        and equipStop.body.farming==false and equipStop.body.primary==nil
        and equipStop.inventory:contains(equipStop.hammer) and not equipStop.window.barricade
        and B.runtimeCount()==0)
    local transferNext=fixture('transfer-successor',true);local tn=admit(transferNext)
    local tnNative=startPreparation(transferNext,tn);local tnItem=tn.item
    local tnSuccessor=successor(transferNext,tnItem)
    check('boarding_transfer_successor_preserved',B.interrupt(transferNext.id,transferNext.body,'controlled-stop')==true
        and ISTimedActionQueue.getTimedActionQueue(transferNext.body).current==tnSuccessor
        and transferNext.body.farming==true and transferNext.body.weaponAnimation=='successor'
        and tnItem.jobDelta==.875 and tnNative.looped==false and tnSuccessor.action.looped==true
        and transferNext.emitter.playing['controlled-successor']==true
        and transferNext.inventory.nested:contains(tnItem) and B.runtimeCount()==0)
    local equipNext=fixture('equip-successor');local en=admit(equipNext)
    local enNative=startPreparation(equipNext,en);local enSuccessor=successor(equipNext,en.item)
    check('boarding_equip_successor_preserved',B.interrupt(equipNext.id,equipNext.body,'controlled-stop')==true
        and ISTimedActionQueue.getTimedActionQueue(equipNext.body).current==enSuccessor
        and equipNext.body.farming==true and equipNext.body.weaponAnimation=='successor'
        and equipNext.hammer.jobDelta==.875 and enNative.weaponRestores==1
        and equipNext.emitter.playing['controlled-successor']==true
        and equipNext.inventory:contains(equipNext.hammer) and B.runtimeCount()==0)
    local transferReplace=fixture('transfer-replacement',true);local tr=admit(transferReplace)
    local trNative=startPreparation(transferReplace,tr);local trItem=tr.item
    local trQueue=ISTimedActionQueue.getTimedActionQueue(transferReplace.body)
    trQueue:removeFromQueue(tr);trQueue.current=nil
    local trSuccessor=successor(transferReplace,nil)
    check('boarding_transfer_replacement_preserved',B.interrupt(transferReplace.id,transferReplace.body,'controlled-stop')==true
        and trQueue.current==trSuccessor and transferReplace.body.farming==true
        and transferReplace.body.weaponAnimation=='successor' and trItem.jobDelta==.625
        and trNative.looped==true and tr.started==true
        and transferReplace.emitter.stopped.RummageInInventory==nil
        and transferReplace.emitter.triggered['controlled-source-open']==nil
        and transferReplace.emitter.triggered['controlled-dest-open']==nil
        and transferReplace.inventory.nested:contains(trItem) and B.runtimeCount()==0)
    local equipReplace=fixture('equip-replacement');local er=admit(equipReplace)
    local erNative=startPreparation(equipReplace,er)
    local erQueue=ISTimedActionQueue.getTimedActionQueue(equipReplace.body)
    erQueue:removeFromQueue(er);erQueue.current=nil
    local erSuccessor=successor(equipReplace,nil)
    check('boarding_equip_replacement_preserved',B.interrupt(equipReplace.id,equipReplace.body,'controlled-stop')==true
        and erQueue.current==erSuccessor and equipReplace.body.farming==true
        and equipReplace.body.weaponAnimation=='successor' and equipReplace.hammer.jobDelta==.625
        and erNative.weaponRestores==nil and equipReplace.emitter.stopped['controlled-equip']==nil
        and equipReplace.inventory:contains(equipReplace.hammer) and B.runtimeCount()==0)
    local transferItem=fixture('transfer-item-replacement',true);local ti=admit(transferItem)
    local tiNative=startPreparation(transferItem,ti);local tiOriginal=ti.item
    ti.item=transferItem.hammer;ti.item:setJobDelta(.875)
    check('boarding_transfer_replaced_item_preserved',B.interrupt(transferItem.id,transferItem.body,'controlled-stop')==true
        and tiOriginal.jobDelta==.625 and transferItem.hammer.jobDelta==.875 and tiNative.looped==true
        and transferItem.body.farming==true and transferItem.emitter.stopped.RummageInInventory==nil
        and transferItem.inventory.nested:contains(tiOriginal) and B.runtimeCount()==0)
    local equipItem=fixture('equip-item-replacement');local ei=admit(equipItem)
    local eiNative=startPreparation(equipItem,ei)
    ei.item=equipItem.plank;ei.item:setJobDelta(.875)
    check('boarding_equip_replaced_item_preserved',B.interrupt(equipItem.id,equipItem.body,'controlled-stop')==true
        and equipItem.hammer.jobDelta==.625 and equipItem.plank.jobDelta==.875 and eiNative.weaponRestores==nil
        and equipItem.body.farming==true and equipItem.body.weaponAnimation=='equipment-override'
        and equipItem.emitter.stopped['controlled-equip']==nil and equipItem.inventory:contains(equipItem.hammer)
        and B.runtimeCount()==0)
    local held=fixture('held');local ha=admit(held);held.body.holdCancellation=true
    check('native_ack_blocks_retirement',B.interrupt(held.id,held.body,'controlled')==false and B.active(held.id,held.body)==true)
    local newbody=fixture('other').body
    SAO.Body.active[held.id]=newbody
    check('body_change_keeps_native_owner',B.active(held.id,newbody)==true and B.runtimeCount()==1)
    held.body.holdCancellation=false
    B.retryCancellations()
    check('independent_native_ack_retires',B.runtimeCount()==0)
    local pending=fixture('pending');local pa=admit(pending)
    pending.body.holdCancellation=true;B.reset('controlled-world-reset')
    check('world_reset_retains_until_ack',B.runtimeCount()==1 and pa:perform()==false and not pending.window.barricade)
    pending.body.holdCancellation=false;B.retryCancellations()
    check('world_reset_ack_releases',B.runtimeCount()==0)
    local stale=fixture('stale');admit(stale);stale.body.holdCancellation=true
    ISTimedActionQueue.getTimedActionQueue(stale.body):removeFromQueue(ISTimedActionQueue.getTimedActionQueue(stale.body).current)
    ISTimedActionQueue.getTimedActionQueue(stale.body).current=nil
    check('queue_absence_is_not_ack',B.interrupt(stale.id,stale.body,'removed')==false and B.runtimeCount()==1)
    stale.body.holdCancellation=false;B.retryCancellations()
    check('late_stop_retires_absent_entry',B.runtimeCount()==0)
    local forgedResult=fixture('generic');admit(forgedResult)
    check('generic_result_cannot_credit',P.recordResult(forgedResult.id,forgedResult.purpose.id,
        {owner='SAOBuild',token='construction:boarded',correlationId=forgedResult.rec.barricadeWork.id,status='completed'})==false)
    B.forget(forgedResult.id)
    local malformed=__records[f.id].barricade
    malformed.order[2]=malformed.order[1]
    check('malformed_ledger_refuses',B.outcome(f.id,1)==nil)
    local staleRecord=fixture('saved-no-runtime')
    staleRecord.rec.barricadeWork={status='boarding',purposeId='saved-purpose'}
    check('malformed_saved_work_refuses',B.active(staleRecord.id,staleRecord.body)==true
        and staleRecord.rec.barricadeWork.status=='boarding' and not staleRecord.window.barricade)
    local function reloadPending(id)
        local restored=fixture(id)
        admit(restored)
        local saved=__nativeRoundtrip(restored.rec)
        local purposeId=restored.purpose.id
        B.forget(id)
        __records[id],restored.rec=saved,saved
        restored.purpose=saved.proceduralPlanning.purposes[purposeId]
        return restored
    end
    local saved=reloadPending('saved-pending')
    local retainedPurpose=saved.purpose.id
    local retainedDestination=saved.purpose.constructionDestination.key
    __hours=102
    check('saved_pending_owner_reconciles',B.reconcileSaved(saved.id,saved.body)==true
        and saved.purpose.admission==nil and saved.purpose.id==retainedPurpose
        and saved.purpose.constructionDestination.key==retainedDestination
        and saved.inventory:contains(saved.plank) and not saved.window.barricade)
    local lost=B.outcome(saved.id,1)
    check('saved_pending_interruption_has_no_effect_claim',lost and lost.status=='interrupted'
        and lost.planningAcknowledged==true and lost.nativeObservability=='runtime-unavailable'
        and lost.plankConsumed==false and lost.nailsConsumed==0 and lost.barricadeChanged==false
        and lost.planksAfter==nil and lost.nativeAttempted==false)
    local resumeOffer=B.offer(saved.id,saved.body,retainedDestination)
    local resumed=plan(saved,resumeOffer)
    check('saved_same_purpose_resumes',resumed.id==retainedPurpose
        and B.begin(saved.id,saved.body,resumeOffer,resumed.id,resumed.steps[resumed.cursor].id)==true)
    finish(saved)
    check('saved_resume_native_completion',B.outcome(saved.id,2).status=='completed'
        and saved.purpose.status=='completed' and saved.window.barricade.planks==1)
    local staleAdmission=reloadPending('saved-stale-admission')
    staleAdmission.purpose.admission.correlationId='different-native-work'
    check('stale_admission_recovery_refuses',B.reconcileSaved(staleAdmission.id,staleAdmission.body)==false
        and staleAdmission.rec.barricadeWork.status=='boarding' and staleAdmission.rec.barricade.nextResult==0)
    local malformedSaved=reloadPending('saved-malformed-ledger')
    malformedSaved.rec.barricade.order[1]=9
    check('malformed_saved_ledger_recovery_refuses',B.reconcileSaved(malformedSaved.id,malformedSaved.body)==false
        and malformedSaved.rec.barricadeWork.status=='boarding')
    local malformedStep=reloadPending('saved-malformed-step')
    malformedStep.purpose.steps=23
    local stepOk,stepResult=pcall(B.reconcileSaved,malformedStep.id,malformedStep.body)
    check('malformed_saved_step_recovery_refuses',stepOk and stepResult==false
        and malformedStep.rec.barricadeWork.status=='boarding' and malformedStep.rec.barricade.nextResult==0)
    local staleActor=reloadPending('saved-stale-actor')
    staleActor.rec.barricadeWork.actorId='different-person'
    check('stale_actor_recovery_refuses',B.reconcileSaved(staleActor.id,staleActor.body)==false
        and staleActor.rec.barricadeWork.status=='boarding' and staleActor.rec.barricade.nextResult==0)
    local nativeQueue=reloadPending('saved-native-queue')
    local nq=ISTimedActionQueue.getTimedActionQueue(nativeQueue.body)
    nq.current={controlledUnclaimedNativeAction=true}
    check('saved_native_queue_recovery_refuses',B.reconcileSaved(nativeQueue.id,nativeQueue.body)==false
        and nativeQueue.rec.barricadeWork.status=='boarding' and nativeQueue.rec.barricade.nextResult==0)
    nq.current=nil
    local clock=reloadPending('saved-clock')
    __hours=clock.rec.barricadeWork.startedAt-1
    check('saved_clock_rewind_refuses',B.reconcileSaved(clock.id,clock.body)==false
        and clock.rec.barricadeWork.status=='boarding' and clock.rec.barricade.nextResult==0)
    __hours=103
    local rewind=fixture('interrupted-clock-recovery');admit(rewind)
    local rewindPurpose,rewindTarget=rewind.purpose.id,rewind.purpose.constructionDestination.key
    rewind.body.holdCancellation=true
    __hours=rewind.rec.barricadeWork.startedAt-1
    check('rewound_interrupt_waits_native_ack',B.interrupt(rewind.id,rewind.body,'controlled-clock-rewind')==false
        and B.runtimeCount()==1 and rewind.rec.barricadeWork.status=='interrupted'
        and rewind.rec.barricadeWork.resultSequence==nil and rewind.rec.barricade.nextResult==0
        and rewind.purpose.admission~=nil)
    rewind.body.holdCancellation=false;B.retryCancellations()
    check('rewound_interrupt_native_ack_retires',B.runtimeCount()==0
        and rewind.rec.barricadeWork.resultSequence==nil and rewind.rec.barricade.nextResult==0
        and rewind.purpose.admission~=nil)
    local rewindSaved=__nativeRoundtrip(rewind.rec)
    __records[rewind.id],rewind.rec=rewindSaved,rewindSaved
    rewind.purpose=rewindSaved.proceduralPlanning.purposes[rewindPurpose]
    check('interrupted_recovery_rewound_clock_refuses',B.reconcileSaved(rewind.id,rewind.body)==false
        and rewind.rec.barricade.nextResult==0 and rewind.purpose.admission~=nil)
    __hours=rewind.rec.barricadeWork.startedAt+1
    local recovered=B.reconcileSaved(rewind.id,rewind.body)
    local rewindRow=B.outcome(rewind.id,1)
    check('interrupted_clock_restoration_recovers',recovered==true and rewindRow~=nil
        and rewindRow.status=='interrupted' and rewindRow.planningAcknowledged==true
        and rewindRow.nativeObservability=='runtime-unavailable' and rewindRow.nativeAttempted==false
        and rewindRow.plankConsumed==false and rewindRow.nailsConsumed==0
        and rewindRow.barricadeChanged==false and rewindRow.planksAfter==nil
        and rewind.purpose.admission==nil and rewind.purpose.id==rewindPurpose
        and rewind.purpose.status~='completed' and rewind.purpose.constructionDestination.key==rewindTarget
        and rewind.inventory:contains(rewind.plank) and rewind.inventory:contains(rewind.nails[1])
        and rewind.inventory:contains(rewind.nails[2]) and not rewind.window.barricade)
    local live=fixture('saved-live-owner');admit(live);live.body.holdCancellation=true
    check('saved_reconcile_waits_native_ack',B.reconcileSaved(live.id,live.body)==false and B.runtimeCount()==1)
    live.body.holdCancellation=false;B.retryCancellations()
    check('saved_reconcile_native_ack_releases',B.reconcileSaved(live.id,live.body)==true and B.runtimeCount()==0)
    local terminal=fixture('saved-terminal');admit(terminal)
    local consumer=P.consumeBarricadeOutcome
    P.consumeBarricadeOutcome=function() return false end
    local terminalRow=finish(terminal)
    local terminalSaved=__nativeRoundtrip(terminal.rec)
    P.consumeBarricadeOutcome=consumer
    __records[terminal.id],terminal.rec=terminalSaved,terminalSaved
    terminal.purpose=terminalSaved.proceduralPlanning.purposes[terminalRow.purposeId]
    check('saved_terminal_delivery_retries',B.reconcileSaved(terminal.id,terminal.body)==true
        and terminal.purpose.status=='completed' and terminal.purpose.admission==nil
        and B.outcome(terminal.id,1).planningAcknowledged==true and terminal.rec.barricade.nextResult==1)
    __windowResults=table.concat(__checks,'\n')
end
