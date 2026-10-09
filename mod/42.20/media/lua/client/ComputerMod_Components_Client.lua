-- Integrated source: ComputerModkum; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("ComputerModkum") then return end
require "ComputerMod_Components"
require "ComputerMod_ComputerTypes"

if isServer() then return end

ComputerModComponentsClient = ComputerModComponentsClient or {}

local function commandArgs(computer)
    return ComputerModComputerTypes.getCommandArgs(computer)
end

function ComputerModComponentsClient.requestInstall(player, computer, partId, item)
    local args = commandArgs(computer)
    if not player or not args or not item or not sendClientCommand then return false end
    args.partId = partId
    args.itemType = item:getFullType()
    args.itemId = item.getID and tostring(item:getID()) or ""
    sendClientCommand(player, "ComputerModComponents", "Install", args)
    return true
end

function ComputerModComponentsClient.requestRemove(player, computer, partId)
    local args = commandArgs(computer)
    if not player or not args or not sendClientCommand then return false end
    args.partId = partId
    sendClientCommand(player, "ComputerModComponents", "Remove", args)
    return true
end

function ComputerModComponentsClient.requestRepair(player, computer, partId)
    local args = commandArgs(computer)
    if not player or not args or not sendClientCommand then return false end
    args.partId = partId
    sendClientCommand(player, "ComputerModComponents", "Repair", args)
    return true
end

function ComputerModComponentsClient.requestSetCondition(player, computer, partId, condition)
    local args = commandArgs(computer)
    if not player or not args or not sendClientCommand then return false end
    args.partId = partId
    args.condition = condition
    sendClientCommand(player, "ComputerModComponents", "SetCondition", args)
    return true
end

local function failureText(reason)
    if reason == "screwdriver" then return getText("IGUI_ComputerMod_ComponentNeedScrewdriver") end
    if reason == "powered_on" then return getText("IGUI_ComputerMod_ComponentTurnOff") end
    if reason == "too_far" then return getText("IGUI_ComputerMod_Closer") end
    if reason == "occupied" then return getText("IGUI_ComputerMod_ComponentSlotOccupied") end
    if reason == "missing_part" then return getText("IGUI_ComputerMod_ComponentMissingPart") end
    if reason == "pliers" then return getText("IGUI_ComputerMod_ComponentNeedPliers") end
    if reason == "skill" then return getText("IGUI_ComputerMod_ComponentNeedElectricalSkill") end
    if reason == "materials" then return getText("IGUI_ComputerMod_ComponentNeedRepairMaterials") end
    if reason == "not_repairable" then return getText("IGUI_ComputerMod_ComponentAlreadyServiced") end
    return getText("IGUI_ComputerMod_ComponentActionFailed")
end

function ComputerModComponentsClient.onServerCommand(module, command, args)
    if module ~= "ComputerModComponents" or command ~= "ActionResult" then return end
    args = args or {}
    local ui = ComputerScreenUI and ComputerScreenUI.instance or nil
    local data = ui and ui.getComputerData and ui:getComputerData() or nil
    if data and type(args.components) == "table" then
        data.ComputerModComponents = ComputerModComponents.copyValue(args.components)
        data.ComputerModDriveID = args.driveId
    end
    local player = getPlayer and getPlayer() or nil
    if args.success == true then
        if player and player.Say then player:Say(getText(args.action == "install" and "IGUI_ComputerMod_ComponentInstalled" or args.action == "remove" and "IGUI_ComputerMod_ComponentRemoved" or args.action == "repair" and "IGUI_ComputerMod_ComponentRepaired" or "IGUI_ComputerMod_ComponentConditionUpdated")) end
        if ui and ui.currentView == "SETTINGS" and ui.settingsCategory == "hardware" then ui:updateStartMenuButtons() end
    elseif player and player.Say then
        player:Say(failureText(args.reason))
    end
end

Events.OnServerCommand.Add(ComputerModComponentsClient.onServerCommand)
