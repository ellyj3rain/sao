-- Integrated source: ProjectArcade; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("ProjectArcade") then return end
require "ProjectArcade_PaymentServer"
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
    if not item then return nil, nil end
    sendAddItemToContainer(inv, item)
    local displayName = item.getDisplayName and item:getDisplayName() or nil
    return prizeType, displayName
end

local function onClientCommand(module, command, playerObj, args)
    if module ~= MODULE then return end
    if command ~= ProjectArcade_PrizeNet.CMD_ROLL then return end

    local nonce = args and args.nonce
    if type(nonce) ~= "string" or nonce == "" or #nonce > 128 then return end

    local prizeType, displayName
    local checked, paid = pcall(ProjectArcade_ClawPayments.consume,
        playerObj, args and args.attemptId)
    if checked and paid then
        local success, rolledType, rolledName = pcall(rollAndGivePrize, playerObj)
        if success then
            prizeType, displayName = rolledType, rolledName
        end
    end

    sendServerCommand(playerObj, MODULE, ProjectArcade_PrizeNet.CMD_RESULT, {
        nonce = nonce,
        ok = prizeType ~= nil,
        prizeType = prizeType,
        displayName = displayName,
    })
end

Events.OnClientCommand.Add(onClientCommand)
