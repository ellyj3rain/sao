-- Integrated source: KnoxAquarium; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("KnoxAquarium") then return end
require 'KA_Core'
require 'KA_Debug'
require 'KA_FishRecords'
local K = KnoxAquarium
local function reply(player, message)
    if isServer() then sendServerCommand(player, 'KnoxAquarium', 'message', {text=message}) else player:Say(message) end
end
local function findItem(player, id)
    local items = player:getInventory():getItems()
    for i=0,items:size()-1 do local item=items:get(i); if item:getID()==id then return item end end
end
-- The animal itself is kept, not a copy of its numbers: a live animal's state
-- lives in a Java object that cannot be rebuilt from mod data, so the real
-- AnimalInventoryItem goes into a container on the tank and comes back out
-- untouched. Vanilla does the same thing with chicken hutches.
local function habitat(obj)
    local container=obj:getContainer()
    if container then return container end
    local ok,made=pcall(function()
        local c=ItemContainer.new('aquarium',obj:getSquare(),obj,2,1)
        obj:setContainer(c)
        return c
    end)
    if ok then return made end
end

local function animalInHabitat(obj,id)
    local container=obj:getContainer()
    if not container then return nil end
    local items=container:getItems()
    for i=0,items:size()-1 do
        local item=items:get(i)
        if tostring(item:getID())==tostring(id) then return item end
    end
end

-- A tank carries the container its vanilla table sprite declares. The game rolls
-- loot into any container it has not "explored" the first time that container is
-- looked at - which is how crowbars, hooks and tire pumps ended up stored inside
-- players' aquariums (found in a real save, 2026-09-14). Furniture a player puts
-- down should never spawn loot, so the container is marked explored the moment
-- the tank exists (More Builds does the same for everything it builds), and any
-- older tank is settled the first time the server handles a command for it.
-- Whatever was already spawned stays put: Pick up hands it to the player.
function K.settleContainers(obj)
    pcall(function()
        for i = 0, obj:getContainerCount() - 1 do
            local c = obj:getContainerByIndex(i)
            if c and not c:isExplored() then c:setExplored(true) end
        end
    end)
end

-- The water container an item carries changed on the SERVER. syncItemFields is
-- not how vanilla reports a fluid change: its own fluid actions call
-- sendItemStats (ISDumpWaterAction, B42.20), which is what a client's bucket
-- display follows. Both are sent, each only where it exists.
function K.syncFluid(item)
    if not item then return end
    pcall(function() item:syncItemFields() end)
    if isServer() and type(sendItemStats) == 'function' then pcall(sendItemStats, item) end
end

-- Vanilla item moves into or out of a WORLD container on the server must be
-- announced, or every client keeps its old picture of that container: a pet
-- that was taken out still listed in the tank's loot window, or one put in
-- that nobody else can see.
local function announceAdd(container, item)
    if isServer() then pcall(sendAddItemToContainer, container, item) end
end
local function announceRemove(container, item)
    if isServer() then pcall(sendRemoveItemFromContainer, container, item) end
end

local function sync(obj)
    obj:transmitModData()
    if isServer() then sendServerCommand('KnoxAquarium','refresh',{x=obj:getX(),y=obj:getY(),z=obj:getZ()})
    elseif K.refresh then K.refresh(obj:getSquare()) end
end

-- ------------------------------------------------------- two-tile tanks
-- A tank whose tier stands on two tiles (the display tank) keeps a PART object
-- on its second tile. The part holds nothing - fish, water and animals all stay
-- on the tank - it only makes that tile solid and leads back to its tank:
--     modData.KnoxAquariumPart = {x=, y=, z=}   (the tank's own tile)
-- It is made from K.PART_SPRITE, a vanilla sprite that is solidtrans and
-- nothing else, so on the server it blocks the tile exactly as the tank's own
-- table sprite blocks the tank's, and it never gets a container of its own.
local PART_NEIGHBOURS={{1,0},{0,1},{-1,0},{0,-1}}

-- Every part this tank owns, with the square it is on.
function K.partsOf(obj)
    local found={}
    local sq=obj:getSquare()
    if not sq then return found end
    local x,y,z=sq:getX(),sq:getY(),sq:getZ()
    for _,o in ipairs(PART_NEIGHBOURS) do
        local nsq=getCell():getGridSquare(x+o[1],y+o[2],z)
        local part=nsq and K.partOn(nsq,x,y,z)
        if part then table.insert(found,{part=part,sq=nsq}) end
    end
    return found
end

function K.removeParts(obj)
    for _,entry in ipairs(K.partsOf(obj)) do entry.sq:transmitRemoveItemFromSquare(entry.part) end
end

local function sameSquare(a,b)
    return a and b and a:getX()==b:getX() and a:getY()==b:getY() and a:getZ()==b:getZ()
end

-- Put this tank's part where its facing says, removing any it has elsewhere.
-- Never stacks a part onto other furniture and never reaches through a wall:
-- if the tile is not free the tank simply stays one tile solid.
function K.ensurePart(obj)
    local d=obj:getModData().KnoxAquarium
    if not d or not K.partDelta(d) then return end
    local sq=obj:getSquare()
    if not sq then return end
    local want=K.partSquare(d,sq)
    for _,entry in ipairs(K.partsOf(obj)) do
        if not sameSquare(entry.sq,want) then entry.sq:transmitRemoveItemFromSquare(entry.part) end
    end
    if not want or K.partOn(want,sq:getX(),sq:getY(),sq:getZ()) then return end
    if not K.canPlaceOn(want,nil) then return end
    local walled=false
    pcall(function() walled=sq:isBlockedTo(want) end)
    if walled then return end
    local part=IsoObject.new(want,K.PART_SPRITE,'AquariumPart',false)
    part:getModData().KnoxAquariumPart={x=sq:getX(),y=sq:getY(),z=sq:getZ()}
    want:AddTileObject(part)
    part:transmitCompleteItemToClients()
end

-- Anything a player has put in the tank's storage. Every tank has carried a
-- vanilla "desk" container since 0.7.0 - it comes with the placeholder sprite
-- the tank is created from - and picking the tank up used to destroy whatever
-- was in it. Animals are counted by K.animals, not here.
local function storedItems(obj)
    local n=0
    pcall(function()
        local c=obj:getContainer()
        if c then n=c:getItems():size() end
    end)
    return n
end

-- Is this exact item (by ID) in the container now?
local function holds(container,item)
    local found=false
    pcall(function()
        local id=item:getID(); local list=container:getItems()
        for i=0,list:size()-1 do if list:get(i):getID()==id then found=true; return end end
    end)
    return found
end

-- REPORTED (2026-09-11): "won't let me pick it up, says something is in it but
-- it's empty". The hidden desk container above can hold things the player never
-- put there - the game can spawn loot into a desk - and nothing in the mod shows
-- it, so refusing left the tank stuck for good. Everything stored is handed to
-- the player instead: each item is added and CONFIRMED in their inventory before
-- it leaves the tank, and if any item fails to arrive the tank is not packed, so
-- nothing can be lost or duplicated. Returns how many moved, or nil on failure.
local function handOverStored(obj,player)
    local c=nil; pcall(function() c=obj:getContainer() end)
    if not c then return 0 end
    local items={}
    pcall(function() local list=c:getItems(); for i=0,list:size()-1 do items[#items+1]=list:get(i) end end)
    local inv=player:getInventory()
    for n,item in ipairs(items) do
        inv:AddItem(item); sendAddItemToContainer(inv,item)
        if not holds(inv,item) then return nil, n-1 end
        pcall(function() c:Remove(item) end)
        pcall(function() sendRemoveItemFromContainer(c,item) end)
    end
    return #items
end

function K.command(module, command, player, args)
    if module ~= 'KnoxAquarium' or type(command)~='string' or not player or player:isDead() or type(args)~='table' then return end
    K.acceptHostToken(player, args)
    if type(args.x)~='number' or type(args.y)~='number' or type(args.z)~='number' then return end
    if args.x~=math.floor(args.x) or args.y~=math.floor(args.y) or args.z~=math.floor(args.z) then return end
    if math.abs(player:getX()-args.x)>K.placeRange or math.abs(player:getY()-args.y)>K.placeRange
        or player:getZ()~=args.z then
        -- A right-click reaches tanks across the room; the server acts only
        -- within placeRange. Say so instead of doing nothing at all.
        return reply(player,'Stand closer to the aquarium.')
    end
    local sq=getCell():getGridSquare(args.x,args.y,args.z)
    if not sq or sq:isBlockedTo(player:getSquare()) then return end
    local obj
    for i=0,sq:getObjects():size()-1 do
        local candidate=sq:getObjects():get(i)
        if K.tankData(candidate) then obj=candidate; break end
    end
    if obj then K.settleContainers(obj) end
    if string.sub(command,1,6)=='debug_' then
        K.debugCommand(command,player,obj,reply,sync); return
    end
    if command=='cleanupPart' then
        -- A client found a second-tile part whose tank is gone (a tank taken
        -- apart some other way than Pick up). Remove it - but only if it really
        -- is an orphan and its tank's own tile is loaded here too.
        for i=sq:getObjects():size()-1,0,-1 do
            local o=sq:getObjects():get(i)
            local p=K.isPart(o) and o:getModData().KnoxAquariumPart or nil
            if p and getCell():getGridSquare(p.x,p.y,p.z) and not K.masterOf(o) then
                sq:transmitRemoveItemFromSquare(o)
            end
        end
        return
    end
    if command=='place' or command=='placeKit' then
        -- Prototype access: a free empty tank; survival crafting will replace this menu.
        local kit=command=='placeKit' and findItem(player,args.item) or nil
        -- The tier comes from the kit being placed, or from the request for a
        -- free beta placement. Never trusted blindly: it must name a tier that
        -- exists and has art, and a kit always wins over the request.
        local tierId=type(args.fishId)=='string' and args.fishId or 'standard'
        local tier=K.tankTiers[tierId]
        if not tier or not K.tierAvailable(tier) then return end
        if command=='placeKit' then
            if not kit then return end
            local kitTier
            for id,t in pairs(K.tankTiers) do if t.item and kit:getFullType()==t.item then kitTier=id end end
            if not kitTier then return end
            tierId=kitTier; tier=K.tankTiers[kitTier]
        end
        -- A free tank (no kit) obeys the Free tanks sandbox option. Checked here,
        -- not only in the menu, so a modified client cannot place one anyway.
        if command=='place' and not K.freePlacementAllowed(player) then
            return reply(player, K.freeTankPolicy()==K.FREE_TANKS_ADMINS
                and 'Free aquariums are for admins on this server. Place one from an Empty Aquarium item.'
                or 'Free aquariums are turned off on this server. Place one from an Empty Aquarium item.')
        end
        local rotation=tonumber(args.rotation) or 0
        if rotation~=math.floor(rotation) or rotation<0 or rotation>3 then return end
        -- The whole tank must fit: its own tile, and a two-tile tank's second.
        local canPlace, why = K.canPlaceTank(sq, player, tierId, rotation)
        if not canPlace then return reply(player, why or 'Cannot place it there.') end
        obj=IsoObject.new(sq,'carpentry_02_8','Aquarium',false)
        obj:getModData().KnoxAquarium={water=0,fish={},animals={},schema=2,nextFishId=0,tainted=false,
                                       rotation=rotation,mode='water',tier=tierId}
        sq:AddTileObject(obj)
        -- AddTileObject gave it the table sprite's container: never loot it
        K.settleContainers(obj)
        K.ensurePart(obj)
        if kit then player:getInventory():Remove(kit);sendRemoveItemFromContainer(player:getInventory(),kit) end
        obj:transmitCompleteItemToClients(); sync(obj)
        return
    end
    if not obj then return end
    local d=K.migrate(obj:getModData().KnoxAquarium)
    -- A two-tile tank placed before 0.13.0 has no second-tile part yet; it gets
    -- one the first time anybody uses it. Rotate and pack look after their own.
    if command~='rotate' and command~='pack' and K.partDelta(d) then K.ensurePart(obj) end
    if command=='setSpecies' then
        local wanted=type(args.fishId)=='string' and args.fishId~='' and args.fishId or nil
        local ok,why=K.canSetSpecies(d,wanted)
        if not ok then return reply(player,why) end
        d.species=wanted
        sync(obj)
        return reply(player, wanted
            and ('Tank set up for '..K.speciesName(wanted)..'. Only that species goes in, and all of them are drawn properly.')
            or 'Tank is a community tank again. Any species goes in; your biggest fish is the one drawn.')
    elseif command=='setMode' then
        local mode=args.fishId=='dry' and 'dry' or 'water'
        local ok,reason=K.canSetMode(d,mode)
        if not ok then return reply(player,reason) end
        d.mode=mode; sync(obj)
        return reply(player,mode=='dry' and 'Tank set to a dry habitat. It now takes a small live animal instead of fish.'
            or ('Tank set to water. It now takes '..K.cap(d)..' litres and live fish.'))
    elseif command=='addAnimal' then
        local item=findItem(player,args.item)
        if not item then return end
        local ok,reason=K.canAddAnimal(d,item)
        if not ok then return reply(player,reason) end
        local container=habitat(obj)
        if not container then return reply(player,'This tank cannot hold an animal. Pick it up and place it again.') end
        -- Move it in FIRST and confirm it arrived. Never remove the animal from
        -- the player's inventory on the strength of a call that might not have
        -- worked: losing somebody's pet is not a recoverable bug.
        local moved=pcall(function() container:AddItem(item) end)
        if not moved or not animalInHabitat(obj,item:getID()) then
            return reply(player,'Could not move the animal into the tank. Nothing was taken.')
        end
        announceAdd(container,item)
        player:getInventory():Remove(item); sendRemoveItemFromContainer(player:getInventory(),item)
        table.insert(K.animals(d),{id=tostring(item:getID()),name=K.animalName(item),kind=K.animalType(item)})
        sync(obj)
        return reply(player,K.animalName(item)..' moved into the habitat.')
    elseif command=='retrieveAnimal' then
        local record,index
        for i,entry in ipairs(K.animals(d)) do
            if entry.id==tostring(args.fishId) then record,index=entry,i; break end
        end
        if not record then return reply(player,'That animal is no longer in this tank.') end
        local item=animalInHabitat(obj,record.id)
        if not item then
            table.remove(K.animals(d),index); sync(obj)
            return reply(player,'That animal is no longer in this tank.')
        end
        local container=obj:getContainer()
        player:getInventory():AddItem(item); sendAddItemToContainer(player:getInventory(),item)
        pcall(function() container:Remove(item) end)
        announceRemove(container,item)
        table.remove(K.animals(d),index); sync(obj)
        return reply(player,'Took '..record.name..' out of the habitat.')
    end
    if command=='fill' then
        if K.isDry(d) then return reply(player,'This is a dry habitat. Switch it back to water first.') end
        local item=findItem(player,args.item)
        if not item or not K.waterSource(item) then return end
        local amount=math.min(K.cap(d)-d.water,item:getFluidContainer():getAmount())
        if amount<=0 then return end
        if item:getFluidContainer():contains(Fluid.TaintedWater) then d.tainted=true end
        item:getFluidContainer():removeFluid(amount,false); K.syncFluid(item)
        d.water=d.water+amount; sync(obj)
    elseif command=='add' then
        if K.isDry(d) then return reply(player,'This is a dry habitat. It takes a small live animal, not a fish.') end
        local item=findItem(player,args.item)
        if not item then return end
        local ok, reason=K.canAdd(d,item,K.now())
        if not ok then return reply(player,reason) end
        local record=K.captureFish(item,d)
        player:getInventory():Remove(item); sendRemoveItemFromContainer(player:getInventory(),item)
        table.insert(d.fish,record); sync(obj)
    elseif command=='retrieve' or command=='discardOne' then
        local record,index=K.findFish(d,args.fishId)
        if not record then return reply(player,'That fish is no longer in this tank. Open the fish list again.') end
        if command=='retrieve' then
            local item,reason=K.restoreFish(record,player)
            if not item then return reply(player,reason) end
            table.remove(d.fish,index)
            player:getInventory():AddItem(item);sendAddItemToContainer(player:getInventory(),item)
            reply(player,'Retrieved '..record.name..'. Its transport timer has started.')
        else
            table.remove(d.fish,index);reply(player,'Removed '..record.name..'.')
        end
        sync(obj)
    elseif command=='drainTo' then
        if #d.fish>0 then return reply(player,'Retrieve the fish before draining water.') end
        local item=findItem(player,args.item);local fluid=item and item:getFluidContainer()
        if not fluid or (not fluid:isEmpty() and not K.waterSource(item)) then return end
        local amount=math.min(d.water,fluid:getCapacity()-fluid:getAmount())
        if amount<=0 then return end
        fluid:addFluid(d.tainted~=false and Fluid.TaintedWater or Fluid.Water,amount)
        K.syncFluid(item);d.water=math.max(0,d.water-amount);if d.water==0 then d.tainted=false end;sync(obj)
    elseif command=='release' then
        -- Explicitly discard occupants; never reconstruct an edible item with reset nutrition/age.
        d.fish={}; sync(obj); reply(player,'Fish removed from the aquarium.')
    elseif command=='empty' then
        if #d.fish>0 then return reply(player,'Remove the fish before draining the tank.') end
        d.water=0;d.tainted=false; sync(obj)
    elseif command=='rotate' then
        -- Turning a tank on the spot moves nothing inside it, so there is no
        -- reason to make somebody drain and restock a tank to face it the other
        -- way. Picking it up still needs it empty; carrying 400 litres does not.
        local newRotation=(K.rotation(d)+1)%4
        local probe={tier=d.tier,rotation=newRotation}
        if K.partDelta(probe) then
            -- A two-tile tank swings its second tile round with it, so that
            -- tile must be free - apart from this tank's own part, if it is
            -- already standing there.
            local want=K.partSquare(probe,sq)
            if not want then return reply(player,'There is no room to turn it here.') end
            if not K.partOn(want,sq:getX(),sq:getY(),sq:getZ()) then
                local ok,why=K.canPlaceOn(want,nil)
                if not ok then return reply(player,'There is no room to turn it here. '..(why or '')) end
                local walled=false
                pcall(function() walled=sq:isBlockedTo(want) end)
                if walled then return reply(player,'A wall is in the way of turning it here.') end
            end
        end
        d.rotation=newRotation
        K.ensurePart(obj)
        sync(obj)
    elseif command=='pack' then
        -- 2026-09-11: this used to auto-drain water on pickup, to fix a report
        -- of "won't let me pick up empty tank" when only water remained and
        -- Drain was buried in the V wheel. Reverted 2026-09-15 per Jay, after a
        -- live two-player MP test: water must be drained first, same as fish
        -- or animals, for every tier. If "won't let me pick it up" comes back,
        -- the fix is to make Drain easier to find, not to auto-drain again.
        if not K.tankEmpty(d) then
            if K.occupied(d) then return reply(player,'Take any fish or animal out first.') end
            return reply(player,'Drain the tank before picking it up.')
        end
        local handed=handOverStored(obj,player)
        if not handed then
            return reply(player,'Could not move everything stored in the tank into your inventory, so the tank stays. Take the rest out by hand.')
        end
        d.water=0;d.tainted=false
        local kit=instanceItem(K.tierOf(d).item or 'KnoxAquarium.TankKit')
        if not kit then return reply(player,'Aquarium item definition unavailable; restart the game after updating.') end
        kit:getModData().KnoxAquariumRotation=K.rotation(d)
        K.removeParts(obj)
        sq:transmitRemoveItemFromSquare(obj)
        player:getInventory():AddItem(kit);sendAddItemToContainer(player:getInventory(),kit)
        reply(player,'Aquarium packed.'..(handed>0 and (' '..handed..(handed==1 and ' item' or ' items')..' stored in it went to your inventory.') or '')
            ..' Right-click it in your main inventory to place it.')
    end
end
Events.OnClientCommand.Add(K.command)
-- A fresh code for this server session, so the co-op host can prove who it is.
-- 0.14.1: pcall. This is the LAST statement in the server's own file and it
-- touches the filesystem; anything it throws would abort the load of this file,
-- taking K.command and OnClientCommand with it - a server that stops during
-- launch. The token is optional; the mod is fully functional without it.
if isServer() then pcall(K.publishHostToken) end
