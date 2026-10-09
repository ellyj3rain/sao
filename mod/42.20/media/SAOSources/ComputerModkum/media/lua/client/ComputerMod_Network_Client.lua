require "ComputerMod_Network"
require "ComputerMod_Debug"

if isServer() then return end

ComputerModNetworkClient = ComputerModNetworkClient or {}

local function applyDebugMode(enabled)
    local player = getPlayer and getPlayer() or nil
    local data = player and player.getModData and player:getModData() or nil
    if data then
        data.ComputerModDebugEnabled = enabled == true
    end
end

function ComputerModNetworkClient.requestSync(playerObj)
    if isClient and isClient() and sendClientCommand then
        local player = playerObj or getPlayer and getPlayer() or nil
        if player then
            sendClientCommand(player, "ComputerModNetwork", "RequestSync", {})
        end
    end
end

function ComputerModNetworkClient.init()
    ComputerModNetwork.clientInternetEnabled = nil
    ComputerModNetworkClient.requestSync()
end

function ComputerModNetworkClient.onCreatePlayer(_, playerObj)
    ComputerModNetworkClient.requestSync(playerObj)
end

function ComputerModNetworkClient.onServerCommand(module, command, args)
    if module ~= "ComputerModNetwork" then return end
    if command == "Sync" then
        local store = ComputerModNetwork.getStore()
        if args then
            if args.enabled ~= nil then
                store.internetDisabled = args.enabled ~= true
                ComputerModNetwork.clientInternetEnabled = args.enabled == true
            end
            if args.activeTerminalId ~= nil then
                store.activeTerminalId = args.activeTerminalId ~= false and args.activeTerminalId or nil
            end
            if args.terminals ~= nil then
                store.terminals = args.terminals
            end
            if args.debugEnabled ~= nil then
                applyDebugMode(args.debugEnabled == true)
            end
        end
        if ComputerScreenUI and ComputerScreenUI.instance and ComputerScreenUI.instance.updateStartMenuButtons then
            ComputerScreenUI.instance:updateStartMenuButtons()
        end
    elseif command == "RepairProgress" then
        if ComputerModRelayRepairUI and ComputerModRelayRepairUI.instance and ComputerModRelayRepairUI.instance.handleServerProgress then
            ComputerModRelayRepairUI.instance:handleServerProgress(args or {})
        end
    elseif command == "RepairResult" then
        if ComputerScreenUI and ComputerScreenUI.instance and ComputerScreenUI.instance.handleNetworkRepairResult then
            ComputerScreenUI.instance:handleNetworkRepairResult(args or {})
        end
    elseif command == "DebugModeResult" then
        applyDebugMode(args and args.success == true and args.enabled == true)
        if ComputerScreenUI and ComputerScreenUI.instance and ComputerScreenUI.instance.handleDebugModeResult then
            ComputerScreenUI.instance:handleDebugModeResult(args or {})
        end
    end
end

Events.OnInitGlobalModData.Add(ComputerModNetworkClient.init)
if Events.OnCreatePlayer then
    Events.OnCreatePlayer.Add(ComputerModNetworkClient.onCreatePlayer)
end
Events.OnServerCommand.Add(ComputerModNetworkClient.onServerCommand)
