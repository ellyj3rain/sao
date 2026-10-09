NMSlotDragCommon = NMSlotDragCommon or {}

function NMSlotDragCommon.collapsePinnedInventory(window, resolvedPlayer)
    if not window then return end
    local playerObj = resolvedPlayer or (window.resolveContext and window:resolveContext() or nil)
    playerObj = playerObj and playerObj.player or playerObj
    local playerNum = playerObj and playerObj.getPlayerNum and playerObj:getPlayerNum() or window.playerNum
    if not ISInventoryPage or not ISInventoryPage.getPlayerInventory then
        return
    end
    local invPage = ISInventoryPage.getPlayerInventory(tonumber(playerNum) or 0)
    if invPage and invPage.isPinned and invPage:isPinned() and invPage.setPinned then
        invPage:setPinned(false)
    end
end

return NMSlotDragCommon
