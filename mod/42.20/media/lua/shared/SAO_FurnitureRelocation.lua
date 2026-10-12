-- Original SAO relocation over installed native moveable APIs.
require "Moveables/ISMoveableSpriteProps"
SAO=SAO or {};SAO.FurnitureRelocation=SAO.FurnitureRelocation or {}
local R=SAO.FurnitureRelocation
local MAX_MEMBERS,MAX_ITEMS=64,4096
local bathIso,bathFluid=nil,nil
local function coords(s)return s:getX(),s:getY(),s:getZ()end
local function finite(n)return type(n)=="number" and n==n and n>-math.huge and n<math.huge end
local function contains(square, object)
    local objects = square and square:getObjects()
    if not objects then return false end
    for i = 0, objects:size() - 1 do if objects:get(i) == object then return true end end
    return false
end
local function sprite(object)
    local s = object and object:getSprite()
    return s and s:getName()
end
local function activated(id)
    return getActivatedMods and getActivatedMods():contains(id)
end
local function bathAllowed(object, square)
    if not activated("TakeABathAndShowerNew") then return true end
    if not bathIso or not bathFluid then
        local okIso, iso = pcall(require, "TABAS_Iso")
        local okFluid, fluid = pcall(require, "TubFluidContainer/TABAS_TubFluidContainerSystemUtils")
        if not okIso or not okFluid or type(iso) ~= "table" or type(fluid) ~= "table"
            or type(iso.isBathObject) ~= "function" or type(fluid.hasTfcData) ~= "function" then
            return false, "bath-owner-unavailable"
        end
        bathIso, bathFluid = iso, fluid
    end
    if bathIso.isBathObject(object) and bathFluid.hasTfcData(square) then return false, "bath-in-use" end
    return true
end

-- InventoryItem identity survives native relocation; IsoObject identity does not.
-- Include nested inventories so their contents cannot change unnoticed during delay.
local function inventorySnapshot(container, budget, depth)
    if depth > 16 then return nil end
    local snapshot = { container=container, items={} }
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if budget.seen[item] or budget.count >= MAX_ITEMS then return nil end
        budget.seen[item], budget.count = true, budget.count + 1
        local entry = { item=item }
        if instanceof(item, "InventoryContainer") then
            entry.nested = inventorySnapshot(item:getInventory(), budget, depth + 1)
            if not entry.nested then return nil end
        end
        snapshot.items[#snapshot.items + 1] = entry
    end
    return snapshot
end
local function inventoryMatches(snapshot, container, nested)
    if not container or (nested and snapshot.container ~= container) then return false end
    local items = container:getItems()
    if items:size() ~= #snapshot.items then return false end
    local seen = {}
    for i = 0, items:size() - 1 do seen[items:get(i)] = true end
    for _, entry in ipairs(snapshot.items) do
        if not seen[entry.item] or entry.item:getContainer() ~= container then return false end
        seen[entry.item] = nil
        if entry.nested and not inventoryMatches(entry.nested, entry.item:getInventory(), true) then return false end
    end
    return true
end
local function contentsMatch(member, object)
    if object:getContainerCount() ~= #member.containers then return false end
    for i, snapshot in ipairs(member.containers) do
        local container = object:getContainerByIndex(i - 1)
        if not inventoryMatches(snapshot, container, false) then return false end
    end
    return true
end

local function waterState(object)
    if not object:getFluidContainer() then return nil end
    local amount, capacity = object:getFluidAmount(), object:getFluidCapacity()
    if not finite(amount) or not finite(capacity) or amount ~= 0 or capacity <= 0 then return nil end
    return capacity
end
local function scalarCopy(row)
    if type(row) ~= "table" then return nil end
    local copy = {}
    for k, v in pairs(row) do
        local t = type(v)
        if type(k) ~= "string" or (t ~= "string" and t ~= "boolean" and not finite(v)) then return nil end
        copy[k] = v
    end
    return copy
end
local function sameScalars(left, right)
    if left == nil or right == nil then return left == right end
    for k, v in pairs(left) do if right[k] ~= v then return false end end
    for k, v in pairs(right) do if left[k] ~= v then return false end end
    return true
end
local function waterPreflight(binding)
    local water, sourceKeys = {}, {}
    for _, member in ipairs(binding.members) do
        if WPIso and WPIso.IsBarrel and WPIso.IsBarrel(member.object) then
            -- GetWaterStatus changes and transmits the fixture. Read only the
            -- supported empty native fluid component here; other shapes remain open.
            local capacity = waterState(member.object)
            if not capacity then return nil, "water-fixture-state" end
            if not WPServer or not WPServer.Commands or not WPServer.Commands.BarrelAdd
                or not WPServer.Commands.BarrelRemove or not WPUtils or not WPUtils.Coords2Id
                or not GetWPModData or not WPIso.GetBarrel then return nil, "water-authority-unavailable" end
            local data = GetWPModData()
            if not data or type(data.Barrels) ~= "table" then return nil, "water-authority-unavailable" end
            local x, y, z = coords(member.square)
            local k = WPUtils.Coords2Id(x, y, z)
            local old = data.Barrels[k]
            local saved = old and scalarCopy(old) or nil
            if sourceKeys[k] or WPIso.GetBarrel(member.square) ~= member.object
                or (old and (not saved or old.w ~= 0 or old.wmax ~= capacity * 100
                    or old.x ~= x or old.y ~= y or old.z ~= z)) then return nil, "water-fixture-state" end
            sourceKeys[k] = true
            water[#water + 1] = { member=member, capacity=capacity, registry=data.Barrels, old=saved, sourceKey=k }
        end
    end
    for _, state in ipairs(water) do
        local x, y, z = coords(state.member.target)
        local k = WPUtils.Coords2Id(x, y, z)
        if state.registry[k] and not sourceKeys[k] then return nil, "water-destination-registered" end
        state.destinationKey = k
        state.destinationOld = state.registry[k] and scalarCopy(state.registry[k]) or nil
    end
    return water
end

local function measure(binding)
    local changed, complete, used = false, true, {}
    for _, m in ipairs(binding.members) do
        if contains(m.square, m.object) then complete = false else changed = true end
        local found = nil
        local objects = m.target:getObjects()
        for i = 0, objects:size() - 1 do
            local candidate = objects:get(i)
            if not m.before[candidate] and sprite(candidate) == m.sprite then
                if found then complete = false end
                found = candidate
            end
        end
        if not found or used[found] or not contentsMatch(m, found) then complete = false end
        if found then used[found], changed = true, true end
        m.placed = found
    end
    return complete, changed
end

local function reconcileWater(binding)
    if #binding.water == 0 then return true end
    local data = GetWPModData()
    local destinations = {}
    -- Validate the whole result before changing either registry coordinate.
    for _, water in ipairs(binding.water) do
        local m = water.member
        if data.Barrels ~= water.registry or not m.placed or not WPIso.IsBarrel(m.placed)
            or WPIso.GetBarrel(m.target) ~= m.placed or waterState(m.placed) ~= water.capacity
            or not sameScalars(data.Barrels[water.sourceKey], water.old)
            or not sameScalars(data.Barrels[water.destinationKey], water.destinationOld) then return false end
        local x, y, z = coords(m.target)
        local k = WPUtils.Coords2Id(x, y, z)
        if destinations[k] then return false end
        local row = water.old and scalarCopy(water.old) or {w=0,wmax=water.capacity * 100}
        row.x, row.y, row.z, row.bid = x, y, z, nil
        destinations[k] = row
        local building = m.target:getBuilding()
        if building then destinations[k].bid = building:getDef():getIDString() end
    end
    for _, water in ipairs(binding.water) do
        local m = water.member
        local x, y, z = coords(m.square)
        local k = WPUtils.Coords2Id(x, y, z)
        if not destinations[k] and not WPIso.GetBarrel(m.square) then
            WPServer.Commands.BarrelRemove(binding.character, {x=x,y=y,z=z})
            if data.Barrels[k] ~= nil then return false end
        end
    end
    for k, args in pairs(destinations) do
        WPServer.Commands.BarrelAdd(binding.character, args)
        local registered = data.Barrels[k]
        if not registered or registered.w ~= 0 or registered.wmax ~= args.wmax
            or registered.x ~= args.x or registered.y ~= args.y or registered.z ~= args.z then return false end
    end
    return true
end

-- Original native relocation. Prior-art identifiers are compatibility data.
local LINKS={
 location_business_office_generic_01_40={"location_business_office_generic_01_41",0,-1},
 location_business_office_generic_01_41={"location_business_office_generic_01_40",0,1},
 location_business_office_generic_01_42={"location_business_office_generic_01_43",1,0},
 location_business_office_generic_01_43={"location_business_office_generic_01_42",-1,0},
 location_business_office_generic_01_44={"location_business_office_generic_01_45",1,0},
 location_business_office_generic_01_45={"location_business_office_generic_01_44",-1,0},
 location_business_office_generic_01_46={"location_business_office_generic_01_47",0,-1},
 location_business_office_generic_01_47={"location_business_office_generic_01_46",0,1}}
R.provenance={original="SAO native furniture relocation",revision="1",priorArt="FurniturePushPull1.2.1/B42.21",
 compatibility="Native office desk member identifiers; no third-party modules copied",native="ISMoveableSpriteProps"}
local function actor(character)
 return character and not character:isDead() and character:isExistInTheWorld() and not character:getVehicle()
  and not character:isAsleep() and not character:isOnBed() and not character:isResting() and not character:isClimbing()
  and character:getCell()==getCell() and character:getCurrentSquare()
  and getCell():getGridSquare(character:getCurrentSquare():getX(),character:getCurrentSquare():getY(),character:getCurrentSquare():getZ())==character:getCurrentSquare()
end
function R.props(object)
 if not object or not object:getSquare() or not contains(object:getSquare(),object) then return nil end
 local p=ISMoveableSpriteProps.fromObject(object)
 if not p or not p.isMoveable or p.type~="Object" or p.isTableTop then return nil end
 local name=sprite(object)
 if not name or name:sub(1,21)=="vegetation_drying_01_" or name:match("^lighting_indoor_03_") and p.isHigh then return nil end
 if instanceof(object,"IsoBarbecue") and (object:isLit() or object:hasPropaneTank())
  or instanceof(object,"IsoFireplace") and (object:isLit() or object:isSmouldering()) then return nil end
 if object:getFluidContainer() and object:getFluidAmount()~=0 then return nil end
 return p
end
function R.members(object)
 local p=R.props(object);if not p then return nil end
 local out={}
 if p.isMultiSprite then
  local grid=p:getSpriteGridInfo(object:getSquare(),true);if not grid then return nil end
  for _,m in ipairs(grid)do
   if #out>=MAX_MEMBERS or not m.object or not R.props(m.object) or m.sprInstance then return nil end
   out[#out+1]={object=m.object,square=m.square,sprite=m.sprite:getName()}
  end
 else
  out[1]={object=object,square=object:getSquare(),sprite=sprite(object)}
  local link=LINKS[sprite(object)]
  if link then
   local s=object:getSquare();s=getCell():getGridSquare(s:getX()+link[2],s:getY()+link[3],s:getZ())
   local found
   if s then for i=0,s:getObjects():size()-1 do local o=s:getObjects():get(i)
    if sprite(o)==link[1] then if found then return nil end;found=o end end end
   if not found or not R.props(found) then return nil end
   out[2]={object=found,square=s,sprite=sprite(found)}
  end
 end
 return #out>0 and out or nil
end
local function transition(a,b)
 if not a or not b then return false end
 if a:isDoorTo(b) then return not a:isDoorBlockedTo(b) and not a:isWindowTo(b) and not a:isHoppableTo(b) end
 return not a:isSomethingTo(b)
end
local function geometry(b,contact)
 if not actor(b.character) or b.cell~=getCell() then return false end
 local here=b.character:getCurrentSquare()
 if here:getZ()~=b.z or math.floor(b.character:getZ())~=b.z then return false end
 local touched=false
 for _,m in ipairs(b.members)do
  local x,y=coords(m.square)
  local hx,hy=b.mode=="push" and x-b.moveX or x+b.moveX*2,b.mode=="push" and y-b.moveY or y+b.moveY*2
  if here:getX()==hx and here:getY()==hy and transition(here,b.mode=="push" and m.square or m.target) then touched=true end
  if not m.target or getCell():getGridSquare(m.target:getX(),m.target:getY(),m.target:getZ())~=m.target
   or not m.target:getFloor() or m.target:isVehicleIntersecting() or not transition(m.square,m.target)
   or m.props:isSquareAtTopOfStairs(m.target) then return false end
  for i=0,m.target:getMovingObjects():size()-1 do
   local moving=m.target:getMovingObjects():get(i)
   if moving~=b.character and moving:isCharacter() then return false end
  end
  if not b.sources[m.target] and not m.props:canPlaceMoveableInternal(b.character,m.target,nil,true) then return false end
  for i=0,m.target:getObjects():size()-1 do local o=m.target:getObjects():get(i)
   local own=false;for _,source in ipairs(b.members)do if source.object==o then own=true end end
   local p=o:getProperties()
   if not own and p and (p:has(IsoFlagType.solid) or p:has(IsoFlagType.solidtrans) or p:has("BlocksPlacement"))
    and not p:has("IsHigh") and not p:has(IsoFlagType.canBeRemoved) then return false end
  end
 end
 -- A footprint may not straddle a wall even when each shifted member is clear.
 for i,a in ipairs(b.members)do for j=i+1,#b.members do local d=b.members[j]
  if math.abs(a.target:getX()-d.target:getX())+math.abs(a.target:getY()-d.target:getY())==1
   and not transition(a.target,d.target) then return false end end end
 return contact==false or touched
end
function R.bind(character,object,destination,mode,contact)
 local members=R.members(object)
 if not actor(character) or not members or not destination or mode~="push" and mode~="pull" then return nil end
 local source=object:getSquare();local x,y,z=coords(source)
 local dx,dy=destination:getX()-x,destination:getY()-y
 if destination:getZ()~=z or math.abs(dx)+math.abs(dy)~=1 then return nil end
 local b={character=character,object=object,cell=getCell(),mode=mode,x=x,y=y,z=z,dx=destination:getX(),dy=destination:getY(),dz=z,
  moveX=dx,moveY=dy,members={},sources={},spent=false}
 local budget={count=0,seen={}}
 for _,m in ipairs(members)do
  local sx,sy=coords(m.square);local p=R.props(m.object)
  local allowed=bathAllowed(m.object,m.square);if not allowed or m.object:isFurnitureOccupied(character) then return nil end
  local row={object=m.object,square=m.square,target=getCell():getGridSquare(sx+dx,sy+dy,z),sprite=m.sprite,props=p,containers={},before={}}
  if not row.target then return nil end
  for i=0,row.target:getObjects():size()-1 do row.before[row.target:getObjects():get(i)]=true end
  for i=0,m.object:getContainerCount()-1 do
   local snapshot=inventorySnapshot(m.object:getContainerByIndex(i),budget,0);if not snapshot then return nil end
   row.containers[#row.containers+1]=snapshot
  end
  b.sources[m.square]=true;b.members[#b.members+1]=row
 end
 b.water=waterPreflight(b);if not b.water or not geometry(b,contact) then return nil end
 return b
end
function R.current(b,contact)
 if not b or b.spent or b.cell~=getCell() then return false end
 local members=R.members(b.object);if not members or #members~=#b.members then return false end
 local actual={};for _,m in ipairs(members)do actual[m.object]=m.square end
 for _,m in ipairs(b.members)do
  if actual[m.object]~=m.square or m.object:getSquare()~=m.square or not contains(m.square,m.object)
   or sprite(m.object)~=m.sprite or not contentsMatch(m,m.object) or m.object:isFurnitureOccupied(b.character)
   or not bathAllowed(m.object,m.square) then return false end
 end
 local water=waterPreflight(b);if not water or #water~=#b.water then return false end
 for i,w in ipairs(water)do local old=b.water[i]
  if w.registry~=old.registry or w.sourceKey~=old.sourceKey or w.destinationKey~=old.destinationKey
   or not sameScalars(w.old,old.old) or not sameScalars(w.destinationOld,old.destinationOld) then return false end
 end
 return geometry(b,contact)
end
function R.duration(b)
 local longest=0
 for _,m in ipairs(b.members)do local v=m.props:getActionTime(b.character,"pickup")+m.props:getActionTime(b.character,"place")
  if not finite(v) or v<=0 then return nil end;longest=math.max(longest,v) end
 return longest
end
function R.commit(b)
 if not R.current(b) then return false,"binding-changed" end
 b.spent=true
 -- All native members and contents were frozen before the first removal event.
 local ok,err=pcall(function()
  -- Preflight and capture every temporary native item before any removal.
  -- The native internal factory is rebound only on this private props instance.
  for _,m in ipairs(b.members)do
   m.carried=m.props:instanceItem(m.sprite);if not m.carried then error("native-member-item-unavailable") end
   local carried=m.carried;m.props.instanceItem=function()return carried end
  end
  for _,m in ipairs(b.members)do for _,c in ipairs(m.containers)do for _,e in ipairs(c.items)do c.container:Remove(e.item) end end end
  for _,m in ipairs(b.members)do
   local picked=m.props:pickUpMoveableInternal(b.character,m.square,m.object,nil,m.sprite,false,true)
   if picked~=m.carried or contains(m.square,m.object) then error("native-pickup-incomplete") end
  end
  for _,m in ipairs(b.members)do
   local p=ISMoveableSpriteProps.new(m.sprite);if not p then error("native-placement-props-unavailable") end
   p:placeMoveableInternal(b.character,m.target,m.carried,m.sprite)
  end
  for _,m in ipairs(b.members)do
   local found
   for i=0,m.target:getObjects():size()-1 do local o=m.target:getObjects():get(i)
    if not m.before[o] and sprite(o)==m.sprite then if found then error("native-member-ambiguous") end;found=o end end
   if not found or found:getContainerCount()~=#m.containers then error("native-member-incomplete") end
   m.placed=found
   for i,c in ipairs(m.containers)do local target=found:getContainerByIndex(i-1)
    for _,e in ipairs(c.items)do if e.item:getContainer()~=nil then error("content-owned-elsewhere") end;target:AddItem(e.item) end
   end
  end
 end)
 -- Resolve post-callback reality even if an add/remove callback raised midway.
 -- Preserve unplaced native member items in native inventory for ordinary save.
 b.recovered={}
 for _,m in ipairs(b.members)do
  if not m.placed then
   for i=0,m.target:getObjects():size()-1 do local o=m.target:getObjects():get(i)
    if not m.before[o] and sprite(o)==m.sprite then if m.placed then m.ambiguous=true end;m.placed=o end
   end
  end
  if not ok and m.carried and not m.placed then
   if contains(m.square,m.object) then
    pcall(function()GameEntityFactory.TransferComponents(m.carried,m.object)end)
   elseif m.carried:getContainer()==nil then
    b.character:getInventory():AddItem(m.carried)
    b.recovered[#b.recovered+1]={sprite=m.sprite,itemId=tostring(m.carried:getID()),fullType=m.carried:getFullType()}
   end
  end
 end
 -- Unexpected native failures rescue only detached originals, never substitute items.
 for _,m in ipairs(b.members)do for _,c in ipairs(m.containers)do for _,e in ipairs(c.items)do
  if e.item:getContainer()==nil then
   local target=contains(m.square,m.object) and c.container or b.character:getInventory()
   if m.placed and not m.ambiguous and m.placed:getContainerCount()==#m.containers then
    for i,snapshot in ipairs(m.containers)do if snapshot==c then target=m.placed:getContainerByIndex(i-1) end end
   end
   target:AddItem(e.item)
  end
 end end end
 local complete,changed=measure(b)
 if not ok or not complete then return false,ok and "partial-native-effect" or tostring(err),changed end
 if not reconcileWater(b) then return false,"utility-reconciliation-failed",true end
 return true,"all-native-members-and-original-contents",true
end
function R.plain(b)
 local out={mode=b.mode,x=b.x,y=b.y,z=b.z,dx=b.dx,dy=b.dy,dz=b.dz,members={}}
 for _,m in ipairs(b.members)do out.members[#out.members+1]={x=m.square:getX(),y=m.square:getY(),z=m.square:getZ(),
  dx=m.target:getX(),dy=m.target:getY(),dz=m.target:getZ(),sprite=m.sprite} end
 return out
end
return R
