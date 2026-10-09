require "ProjectArcade_PrizeRegistry"
require "ProjectArcade_PrizeNet"

local MODULE = ProjectArcade_PrizeNet.MODULE

local function rollAndGivePrize(playerObj)
    if not playerObj then return nil, nil end
    local inv = playerObj:getInventory()
    if not inv then return nil, nil end

    local prizeType = ProjectArcade_PrizeRegistry.rollMerged()
    if not prizeType then
        return nil, nil
    end

    local item = inv:AddItem(prizeType)
    if item then
        sendAddItemToContainer(inv, item) -- replica al cliente
        local displayName = item.getDisplayName and item:getDisplayName() or nil
        return prizeType, displayName
    end

    return prizeType, nil
end

local function onClientCommand(module, command, playerObj, args)
    if module ~= MODULE then return end
    if command ~= ProjectArcade_PrizeNet.CMD_ROLL then return end

    local nonce = args and args.nonce
    if not nonce then return end

    local prizeType, displayName = rollAndGivePrize(playerObj)

    sendServerCommand(playerObj, MODULE, ProjectArcade_PrizeNet.CMD_RESULT, {
        nonce = nonce,
        ok = prizeType ~= nil,
        prizeType = prizeType,
        displayName = displayName,
    })
end

Events.OnClientCommand.Add(onClientCommand)
