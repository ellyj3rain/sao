require "SAO_FurnitureRelocationAction"
require "TimedActions/WalkToTimedAction"
SAO=SAO or {};SAO.FurnitureMenu=SAO.FurnitureMenu or {}
local M,A,R=SAO.FurnitureMenu,SAO.FurnitureRelocationAction,SAO.FurnitureRelocation
local function square(at)return getCell():getGridSquare(at.x,at.y,at.z)end
local function walk(s,at,continuation)
 local destination=square(at);if not destination then return false end
 local a=ISWalkToTimedAction:new(s.character,destination)
 local q=ISTimedActionQueue.getTimedActionQueue(s.character)
 a._queue=q;s.actions[#s.actions+1]=a
 local function current(self)
  return not self._saoWalkRetired and self._queue==ISTimedActionQueue.getTimedActionQueue(s.character)
   and self._queue.current==self and self._queue:indexOf(self)==1
 end
 a:setOnComplete(function()
  if not a._saoWalkPerforming or a._saoWalkContinued then return end
  a._saoWalkContinued=true;a._saoWalkRetired=true
  if q~=ISTimedActionQueue.getTimedActionQueue(s.character) or q:indexOf(a)~=-1 or q.current or #q.queue~=0
   or not A.validSession(s) or s.character:getCurrentSquare()~=destination then A.cancel(s,"walk-not-reached");return end
  continuation(s)
 end)
 local perform=a.perform
 a.perform=function(self)
  if not current(self) or self._saoWalkPerforming then return false end
  self._saoWalkPerforming=true
  perform(self)
  self._saoWalkRetired=true
  return true
 end
 a.stop=function(self)
  if not current(self) then return false end
  self._saoWalkRetired=true
  self.character:getPathFindBehavior2():cancel();self.character:setPath2(nil)
  self.character:setIsFarming(false);q:onCompleted(self)
  A.cancel(s,"walk-interrupted");return true
 end
 ISTimedActionQueue.add(a);return q:indexOf(a)~=-1 or q.current==a
end
function M.queue(character,object,destination,mode)
 local q=character and ISTimedActionQueue.getTimedActionQueue(character)
 if not q or q.current or #q.queue~=0 then return false end
 local session=A.session(character,object,destination,mode);if not session then return false end
 session.onRetreat=function(s)
  local b=s.binding;local m=b.members[1]
  local at={x=m.square:getX()+b.moveX*2,y=m.square:getY()+b.moveY*2,z=b.z}
  if not walk(s,at,function(v)
   if not A.commitRetreat(v) then A.cancel(v,"retreat-not-reached");return end
   ISTimedActionQueue.add(A:new(v,"commit"))
  end)then A.cancel(s,"retreat-route-refused")end
 end
 local b,m=session.binding,session.binding.members[1]
 local at={x=m.square:getX()+(mode=="push" and -1 or 1)*b.moveX,
  y=m.square:getY()+(mode=="push" and -1 or 1)*b.moveY,z=b.z}
 if character:getCurrentSquare()==square(at) then ISTimedActionQueue.add(A:new(session));return true end
 return walk(session,at,function(s)ISTimedActionQueue.add(A:new(s))end)
end
function M.fill(playerIndex,context,objects,test)
 if test or isClient() or isServer() then return end
 -- Optional source menus retain their current entry while forwarding effects.
 if SAO.FurnitureMovement and SAO.FurnitureMovement.install and SAO.FurnitureMovement.install() then return end
 local body=getSpecificPlayer(playerIndex);if not body then return end
 for _,object in ipairs(objects)do
  if R.props(object) then
   local parent=context:addOption(getText("ContextMenu_SAO_MoveFurniture"))
   local menu=ISContextMenu:getNew(context);context:addSubMenu(parent,menu)
   local source=object:getSquare()
   for _,delta in ipairs({{-1,0,"West"},{1,0,"East"},{0,-1,"North"},{0,1,"South"}})do
    local target=getCell():getGridSquare(source:getX()+delta[1],source:getY()+delta[2],source:getZ())
    for _,mode in ipairs({"push","pull"})do
     if R.bind(body,object,target,mode,false) then
      menu:addOption(getText(mode=="push" and "ContextMenu_SAO_PushFurniture" or "ContextMenu_SAO_PullFurniture").." "..getText("ContextMenu_SAO_Furniture"..delta[3]),body,M.queue,object,target,mode)
     end
    end
   end
   return
  end
 end
end
if Events and Events.OnFillWorldObjectContextMenu then
 if M.callback then Events.OnFillWorldObjectContextMenu.Remove(M.callback) end
 M.callback=M.fill;Events.OnFillWorldObjectContextMenu.Add(M.callback)
end
return M
