if isServer() then return end

require "ComputerMod_ComputerTypes"

ComputerModCDClient = ComputerModCDClient or {}

local function textOrFallback(key, fallback)
    if getText then
        local ok, value = pcall(getText, key)
        if ok and value and value ~= key then return value end
    end
    return fallback
end

local function playDiscSound(player)
    if getSoundManager then
        pcall(function() getSoundManager():playUISound("ComputerCDEject") end)
    end
    if player and player.getEmitter then
        pcall(function() player:getEmitter():playSound("ComputerCDEject") end)
    end
end

local function getFailureText(reason)
    if reason == "too_far" then
        return textOrFallback("IGUI_ComputerMod_Closer", "I need to get closer.")
    end
    if reason == "occupied" then
        return textOrFallback("IGUI_ComputerMod_DiscInsertedAlready", "A disc is already inserted.")
    end
    if reason == "missing_disc" then
        return textOrFallback("IGUI_ComputerMod_NeedDisc", "I need the disc first.")
    end
    if reason == "empty" then
        return nil
    end
    return textOrFallback("IGUI_ComputerMod_CDActionFailed", "The CD drive operation failed.")
end

function ComputerModCDClient.requestEject(player, computer, purpose)
    if not player or not computer or not computer.getSquare or not sendClientCommand then return false end
    local args = ComputerModComputerTypes.getCommandArgs(computer)
    if not args then return false end
    args.purpose = purpose == "reset" and "reset" or ""
    sendClientCommand(player, "ComputerModCD", "EjectDisc", args)
    return true
end

function ComputerModCDClient.onServerCommand(module, command, args)
    if module ~= "ComputerModCD" or command ~= "ActionResult" then return end
    args = args or {}
    local player = getPlayer and getPlayer() or nil
    if args.success == true then
        local ui = ComputerScreenUI and ComputerScreenUI.instance or nil
        local data = ui and ui.getComputerData and ui:getComputerData() or nil
        local currentId = data and tostring(data.ComputerModMachineID or "") or ""
        if data and (tostring(args.machineId or "") == "" or tostring(args.machineId or "") == currentId) then
            data.ComputerModMountedCD = args.mountedCD
            data.ComputerModMountedCDItem = args.mountedCDItem
            data.ComputerModMountedCDLabel = args.mountedCDLabel
            data.ComputerModMountedCDContents = type(args.mountedCDContents) == "table" and args.mountedCDContents or {}
            if ui.currentView == "FILES" and ui.startFiles then ui:startFiles() end
        end
        playDiscSound(player)
        if player and player.Say then
            if args.action == "insert" then
                player:Say(textOrFallback("IGUI_ComputerMod_CDInserted", "CD inserted."))
            elseif args.action == "eject" then
                player:Say(textOrFallback("IGUI_ComputerMod_CDRemoved", "CD removed."))
            end
        end
        if args.action == "eject" and args.purpose == "reset" and ComputerScreenUI and ComputerScreenUI.instance then
            local ui = ComputerScreenUI.instance
            ui.resetWaitingForDiscEject = false
            if ui.performComputerReset then
                ui:performComputerReset(true)
            end
        elseif args.action == "eject" and ComputerScreenUI and ComputerScreenUI.instance then
            local ui = ComputerScreenUI.instance
            if ui.cdEjectPending then
                ui.cdEjectPending = false
                local data = ui.getComputerData and ui:getComputerData() or nil
                if data then
                    data.ComputerModMountedCD = nil
                    data.ComputerModMountedCDItem = nil
                    data.ComputerModMountedCDLabel = nil
                    data.ComputerModMountedCDContents = nil
                end
                if ui.currentView == "FILES" and ui.startFiles then
                    ui:startFiles()
                end
            end
        end
        return
    end
    if args.action == "eject" and args.purpose == "reset" and ComputerScreenUI and ComputerScreenUI.instance then
        local ui = ComputerScreenUI.instance
        ui.resetWaitingForDiscEject = false
        ui.resetInProgress = false
        ui.resetTimer = 0
        if ui.showError then
            ui:showError(getFailureText(args.reason) or textOrFallback("IGUI_ComputerMod_CDActionFailed", "The CD drive operation failed."))
        end
    elseif args.action == "eject" and ComputerScreenUI and ComputerScreenUI.instance then
        local ui = ComputerScreenUI.instance
        if ui.cdEjectPending then
            ui.cdEjectPending = false
            if ui.showError then
                ui:showError(getFailureText(args.reason) or textOrFallback("IGUI_ComputerMod_CDActionFailed", "The CD drive operation failed."))
            end
        end
    end
    local message = getFailureText(args.reason)
    if message and player and player.Say then
        player:Say(message)
    end
end

Events.OnServerCommand.Add(ComputerModCDClient.onServerCommand)
