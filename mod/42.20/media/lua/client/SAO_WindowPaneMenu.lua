-- Normal human entry uses the same guarded producer as private NPC work.
require "SAO_WindowPaneAction"
require "SAO_WindowRepair"
require "TimedActions/WalkToTimedAction"
require "TimedActions/ISInventoryTransferAction"
require "Util/AdjacentFreeTileFinder"
SAO=SAO or {}
SAO.WindowPaneMenu=SAO.WindowPaneMenu or {}
local M=SAO.WindowPaneMenu
local PANE=SAO.WindowPaneAction.MaterialFullType
local function available(item)return item and item:getFullType()==PANE and item:getIsCraftingConsumed()~=true end
function M.queueNew(character,window)
    if not character or not window or not window:isSmashed() or not window:isGlassRemoved()
        or window:isBarricaded() or not SAO.WindowRepair.install() then return false end
    local inventory=character:getInventory()
    local material=inventory:getFirstTypeEvalRecurse(PANE,available)
    local square=AdjacentFreeTileFinder.FindWindowOrDoor(window:getSquare(),window,character)
    if not material or not square then return false end
    ISTimedActionQueue.add(ISWalkToTimedAction:new(character,square))
    if material:getContainer()~=inventory then
        ISTimedActionQueue.add(ISInventoryTransferAction:new(character,material,material:getContainer(),inventory))
    end
    ISTimedActionQueue.add(SAO.WindowPaneAction:new(character,window))
    return true
end
function M.fill(playerIndex,context,objects,test)
    if test or not SAO.WindowRepair.install() then return end
    -- Its existing callback retains optional removal and forwards addition
    -- through the owned guarded action. This callback supplies absence only.
    if SAO.WindowRepair.optionalPaneMenu then return end
    local character=getSpecificPlayer(playerIndex)
    if not character then return end
    for _,object in ipairs(objects) do
        if instanceof(object,"IsoWindow") and not object:hasProperty("IsMoveAble") and object:isSmashed()
            and object:isGlassRemoved() and character:getInventory():getFirstTypeEvalRecurse(PANE,available) then
            local menu=context
            local entry=context:getOptionFromName(getText("ContextMenu_Window"))
            if entry then menu=context:getSubInstance(entry.subOption) or context end
            local option=menu:addOption(getText("ContextMenu_SAO_RepairWindow"),character,M.queueNew,object)
            option.notAvailable=object:isBarricaded()
            return
        end
    end
end
if Events and Events.OnFillWorldObjectContextMenu then
    if M.callback then Events.OnFillWorldObjectContextMenu.Remove(M.callback) end
    M.callback=M.fill;Events.OnFillWorldObjectContextMenu.Add(M.callback)
end
return M
