-- Original SAO timed repair over native window and inventory APIs.
require "TimedActions/ISBaseTimedAction"
require "SAO_WindowPaneSources"
require "Util/AdjacentFreeTileFinder"
SAO=SAO or {}
SAO.WindowPaneAction=SAO.WindowPaneAction or ISBaseTimedAction:derive("SAOWindowPaneAction")
local A=SAO.WindowPaneAction
local PANE=SAO.WindowPaneSources.material.fullType
A.MaterialFullType=PANE
-- Same owned interaction reach as WindowRepair, with the installed helper's
-- primary sides and admissible fallback. No private planning authority here.
local INTERACTION_REACH_SQ=2*2
local function pane(item)
    return item and item:getFullType()==PANE and item:getIsCraftingConsumed()~=true
end
local function physicalAvailable(self)
    local character,window=self.character,self.window
    if not character or not window or character:isDead() or not character:isExistInTheWorld() then return false end
    local cell,here,square=character:getCell(),character:getCurrentSquare(),window:getSquare()
    if not cell or not here or not square or cell~=getCell()
        or cell:getGridSquare(here:getX(),here:getY(),here:getZ())~=here
        or cell:getGridSquare(square:getX(),square:getY(),square:getZ())~=square
        or math.floor(character:getZ())~=square:getZ() or not here:canStand()
        or window:getObjectIndex()<0 or not square:getObjects():contains(window) then return false end
    local other=window:getNorth() and square:getN() or square:getW()
    if here~=square and here~=other and (not AdjacentFreeTileFinder
        or AdjacentFreeTileFinder.FindWindowOrDoor(square,window,character)~=here) then return false end
    local dx,dy=square:getX()+.5-character:getX(),square:getY()+.5-character:getY()
    if dx*dx+dy*dy>INTERACTION_REACH_SQ then return false end
    local inventory=character:getInventory()
    return window:isSmashed() and window:isGlassRemoved() and not window:isBarricaded()
        and inventory and inventory:getFirstTypeEval(PANE,pane)~=nil or false
end
function A:isValidStart() return physicalAvailable(self) end
function A:isValid() return physicalAvailable(self) end
function A:waitToStart()
    self.character:faceThisObject(self.window)
    return self.character:shouldBeTurning()
end
function A:perform()
    -- Same native retirement APIs as ISBaseTimedAction.perform. Retire this
    -- action's old flag before the queue may start a legitimate successor.
    self.character:setIsFarming(false)
    ISTimedActionQueue.getTimedActionQueue(self.character):onCompleted(self)
    ISLogSystem.logAction(self)
end
function A:complete(exactPane)
    if self._SAOPaneCommitted or not physicalAvailable(self) then return false end
    local inventory=self.character:getInventory()
    local material=exactPane or inventory:getFirstTypeEval(PANE,pane)
    if not pane(material) or material:getContainer()~=inventory or not inventory:contains(material) then return false end
    self._SAOPaneCommitted=true
    -- Native glass removal changes navigation while the window is destroyed.
    -- Native unsmashing then restores maxHealth and its open/closed sprite.
    self.window:setGlassRemoved(false)
    self.window:setSmashed(false)
    self.window:sync()
    inventory:Remove(material)
    sendRemoveItemFromContainer(inventory,material)
    return not inventory:contains(material)
end
function A:getDuration() return self.character:isTimedActionInstant() and 1 or 192 end
function A:new(character,window)
    local o=ISBaseTimedAction.new(self,character)
    o.window=window;o.maxTime=o:getDuration()
    o.stopOnAim,o.stopOnRun,o.stopOnWalk=true,true,true
    return o
end
_G[A.Type]=A
return A
