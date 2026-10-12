require "TimedActions/ISBaseTimedAction"
require "SAO_FurnitureRelocation"
SAO=SAO or {};SAO.FurnitureRelocationAction=SAO.FurnitureRelocationAction or ISBaseTimedAction:derive("SAOFurnitureRelocationAction")
local A,R=SAO.FurnitureRelocationAction,SAO.FurnitureRelocation
local SEAL={}
local function live(s)
 return s and s.seal==SEAL and not s.cancelled and not s.finished and s.binding
  and R.current(s.binding,false) and (not s.validate or s.validate(s)==true)
end
local function contact(s,phase)
 local b,here=s.binding,s.character:getCurrentSquare()
 if not here then return false end
 for _,m in ipairs(b.members)do
  local n=b.mode=="pull" and (phase=="commit" and 2 or 1) or -1
  if here:getX()==m.square:getX()+n*b.moveX and here:getY()==m.square:getY()+n*b.moveY and here:getZ()==b.z then return true end
 end
 return false
end
function A.session(character,object,destination,mode,validate,onResult,onRetreat)
 if isClient() or isServer() then return nil end
 local b=R.bind(character,object,destination,mode,false);if not b then return nil end
 local duration=R.duration(b);if not duration then return nil end
 return {seal=SEAL,character=character,binding=b,duration=duration,validate=validate,onResult=onResult,onRetreat=onRetreat,
  phase="effort",actions={},finished=false,cancelled=false}
end
function A.validSession(s) return live(s) end
function A.cancel(s,reason)
 if not s or s.seal~=SEAL or s.finished or s.cancelled then return false end
 s.cancelled=true
 if not s.reported then s.reported=true;if s.onResult then s.onResult(s,false,reason or "cancelled",false) end end
 for _,action in ipairs(s.actions)do
  local q=action._queue
  if q then
   if q.current==action and action.action then action.action:forceStop()
   elseif q.current==action then q:onCompleted(action)
   elseif q:indexOf(action)~=-1 then q:removeFromQueue(action) end
  end
 end
 return true
end
function A:isValidStart()
 local s=self._session
 return live(s) and s.phase==self.phase and contact(s,self.phase) and not self._ended
end
function A:isValid()return self:isValidStart()end
function A:waitToStart()self.character:faceThisObject(self._session.binding.object);return self.character:shouldBeTurning()end
function A:start()
 if not self:isValidStart() then return end
 self._queue=ISTimedActionQueue.getTimedActionQueue(self.character)
 self:setActionAnim("Loot");self:setAnimVariable("LootPosition","Low");self:setOverrideHandModels(nil,nil)
 self.character:reportEvent("EventLootItem")
end
function A:update()
 self.character:faceThisObject(self._session.binding.object)
 if self.phase=="effort" then self.character:setMetabolicTarget(Metabolics.UsingTools) end
end
function A:stop()
 if self._ended then return end
 local q=self._queue
 if q and q==ISTimedActionQueue.getTimedActionQueue(self.character) and q.current==self then
  self.character:setIsFarming(false);q:onCompleted(self)
 end
 A.cancel(self._session,"native-stop")
end
function A:forceCancel()return A.cancel(self._session,"cancelled")end
local function ended(action)
 local ok,result=pcall(function()return action.action and action.action:isStarted() and (action.action:finished() or action.action:forceComplete())end)
 return ok and result==true
end
function A:perform()
 local q=self._queue
 if self._performed or not self:isValid() or not ended(self) or not q or q~=ISTimedActionQueue.getTimedActionQueue(self.character)
  or q.current~=self or q:indexOf(self)~=1 then return false end
 self._performed=true
 self.character:setIsFarming(false)
 q:onCompleted(self);ISLogSystem.logAction(self)
 self._retiredCurrent,self._retiredFirst,self._retiredLength=q.current,q.queue[1],#q.queue
 return true
end
function A:complete()
 local s,q=self._session,self._queue
 if self._ended or not self._performed or not live(s) or s.phase~=self.phase or not contact(s,self.phase)
  or q~=ISTimedActionQueue.getTimedActionQueue(self.character) or q:indexOf(self)~=-1
  or q.current~=self._retiredCurrent or q.queue[1]~=self._retiredFirst or #q.queue~=self._retiredLength then return false end
 self._ended=true
 if self.phase=="effort" and s.binding.mode=="pull" then
  s.phase="retreat";s.effortCompleted=true
  if s.onRetreat then s.onRetreat(s) end
  return true
 end
 s.finished=true
 local ok,reason,changed=R.commit(s.binding)
 s.succeeded,s.reason=ok,reason
 if not s.reported then s.reported=true;if s.onResult then s.onResult(s,ok,reason,changed) end end
 return ok
end
function A.commitRetreat(s)
 if not live(s) or s.phase~="retreat" or not s.effortCompleted or not contact(s,"commit") then return false end
 s.phase="commit";return true
end
function A:getDuration()return self.phase=="commit" and 1 or self._session.duration end
function A:new(session,phase)
 if not session or session.seal~=SEAL or session.cancelled or session.finished then return nil end
 local o=ISBaseTimedAction.new(self,session.character)
 o._queue=ISTimedActionQueue.getTimedActionQueue(session.character)
 o._session=session;o.phase=phase or "effort";o.maxTime=o:getDuration()
 o.stopOnWalk,o.stopOnRun,o.stopOnAim=true,true,true
 session.actions[#session.actions+1]=o
 return o
end
_G[A.Type]=A
return A
