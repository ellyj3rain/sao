-- Controlled map/body/item and pickup/placement receivers. Installed FPP Lua stays intact.
SAO = {}
__now, __network, __npc, __effects, __active = 1000, false, false, 0, {}
function require(name) return __modules and __modules[name] or {} end
function isClient() return __network end
function isServer() return false end
function getTimestampMs() return __now end
function getText(value) return value end
function instanceof(value, kind) return value and value.kind == kind end
function getActivatedMods() return {contains=function(_,name) return __active[name] == true end} end
function getGameTime() return {getWorldAgeHours=function() return 4 end} end
function getSoundManager() return {PlayWorldSound=function() __effects=__effects+1 end} end
function addSound() end
CharacterStat={ENDURANCE='endurance'}
Events = setmetatable({}, {__index=function(t,k)
 local e={callbacks={}}; function e.Add(f) e.callbacks[#e.callbacks+1]=f end
 rawset(t,k,e); return e
end})
function __event(name) for _,f in ipairs(Events[name].callbacks) do f() end end
ISBaseTimedAction={}
function ISBaseTimedAction:derive(name) local t={}; t.__index=t; setmetatable(t,{__index=self}); return t end
function ISBaseTimedAction:new(character) return setmetatable({character=character},{__index=self}) end
function ISBaseTimedAction:perform() end
function ISBaseTimedAction:stop() end
function __list(values)
 local t={values=values or {}}
 function t:size() return #self.values end
 function t:get(i) return self.values[i+1] end
 function t:contains(v) for _,x in ipairs(self.values) do if x==v then return true end end return false end
 function t:add(v) self.values[#self.values+1]=v end
 function t:remove(v) for i,x in ipairs(self.values) do if x==v then table.remove(self.values,i); return true end end end
 return t
end
function __container()
 local c={items=__list()}
 function c:getItems() return self.items end
 function c:contains(item) return self.items:contains(item) end
 function c:Remove(item) self.items:remove(item); item.container=nil end
 function c:AddItem(item) self.items:add(item); item.container=self; return item end
 c.AddItemBlind=c.AddItem
 function c:getParent() return self.parent end
 return c
end
function __item(id)
 local t={id=id,md={identity=id}}
 function t:getContainer() return self.container end
 function t:getID() return self.id end
 function t:getFullType() return 'Fixture.Item' end
 function t:getModData() return self.md end
 return t
end
__squares={}
function __square(x,y,z)
 local key=x..':'..y..':'..z
 if __squares[key] then return __squares[key] end
 local q={x=x,y=y,z=z,objects=__list()}
 function q:getX() return self.x end; function q:getY() return self.y end; function q:getZ() return self.z end
 function q:getBuilding() return nil end
 function q:getObjects() return self.objects end
 function q:getMovingObjects() return __list() end
 function q:isFree() return true end
 function q:RecalcAllWithNeighbours() end
 __squares[key]=q; return q
end
__cell={getGridSquare=function(_,x,y,z) return __squares[x..':'..y..':'..z] end}
function getCell() return __cell end
function __object(square,name)
 local o={kind='IsoObject',square=square,name=name or 'fixtures_cabinet_01_0',containers={__container()},md={}}
 o.containers[1].parent=o
 function o:getSquare() return self.square end
 function o:getSprite() return {getName=function() return self.name end, getProperties=function() return {Is=function() return false end,Val=function() return nil end} end} end
 function o:getModData() return self.md end
 function o:getContainerCount() return #self.containers end
 function o:getContainerByIndex(i) return self.containers[i+1] end
 function o:getContainer() return self.containers[1] end
 function o:getObjectIndex() if not self.square then return -1 end for i,v in ipairs(self.square.objects.values) do if v==self then return i-1 end end return -1 end
 function o:hasFluid() return self.wet==true end
 function o:getFluidContainer() return self.capacity and self or nil end
 function o:getFluidAmount() return self.amount or 0 end
 function o:getFluidCapacity() return self.capacity or 0 end
 function o:isFloor() return false end
 square.objects:add(o)
 return o
end
function __character()
 local c={inventory=__container(),square=__square(9,10,0),effects=0}
 function c:isNpc() return __npc end
 function c:isDead() return self.dead==true end
 function c:isExistInTheWorld() return self.present~=false end
 function c:getVehicle() return nil end
 function c:getCell() return self.cell or __cell end
 function c:getCurrentSquare() return self.square end
 function c:getSquare() return self.square end
 function c:getX() return self.square.x end; function c:getY() return self.square.y end; function c:getZ() return self.square.z end
 function c:getInventory() return self.inventory end
 function c:getModData() return {} end
 function c:getPlayerNum() return 0 end
 function c:getOnlineID() return 7 end
 function c:faceThisObject() end; function c:faceLocation() end
 function c:setDoShove() end; function c:setDoGrapple() end; function c:setAimAtFloor() end
 function c:AttemptAttack() self.effects=self.effects+1 end
 function c:getStats() return {remove=function() __effects=__effects+1 end} end
 return c
end
ISMoveableSpriteProps={}
local function props(name,object)
 local p={spriteName=name,isMoveable=true,type='Object',weight=10}
 function p:findOnSquare(square,sprite) for _,v in ipairs(square.objects.values) do if v.name==sprite then return v end end end
 function p:pickUpMoveableInternal(character,square,obj)
  __pickups=__pickups+1; square.objects:remove(obj); obj.square=nil
  return {name=obj.name, md=obj.md, capacity=obj.capacity, amount=obj.amount}
 end
 function p:placeMoveableInternal(character,square,item,name)
  __placements=__placements+1
  if __failPlace then return false end
  local o=__object(square,name); o.md=item.md; o.capacity=item.capacity; o.amount=item.amount
  if __omitContainer then o.containers={} end
  if __afterPlacement then __afterPlacement(o) end
  return o
 end
 function p:pickUpMoveable(character,square)
  local o=self:findOnSquare(square,self.spriteName)
  __held=self:pickUpMoveableInternal(character,square,o)
  return {__held}
 end
 function p:placeMoveable(character,square,name) return self:placeMoveableInternal(character,square,__held,name) end
 return p
end
function ISMoveableSpriteProps.fromObject(o) return props(o.name,o) end
function ISMoveableSpriteProps.new(name) return props(name) end
__modules={}
function __reset()
 if SAO.FurnitureMovement then SAO.FurnitureMovement.reset('fixture') end
 __squares={}; __now=1000; __network=false; __npc=false; __active={}; __effects=0
 __pickups=0; __placements=0; __failPlace=false; __omitContainer=false; __afterPlacement=nil
 __cell={getGridSquare=function(_,x,y,z) return __squares[x..':'..y..':'..z] end}
 local src,dst=__square(10,10,0),__square(11,10,0)
 local o=__object(src); local c=__character(); local i=__item(1); local nested=__item(2)
 i.nested=nested; o.containers[1]:AddItem(i)
 return c,o,src,dst,i,nested
end
function check(name,result) print('CHECK '..name..'='..tostring(result==true)); if not result then error('FAILED '..name) end end

__wp={Barrels={}}
function GetWPModData() return __wp end
WPUtils={Coords2Id=function(x,y,z) return x..'_'..y..'_'..z end}
__tfc={Registered={}}
function GetTFCSystemData() return __tfc end
