NMClientVanillaDiscVisibleProbe = NMClientVanillaDiscVisibleProbe or {}

local TICK_INTERVAL = 300
local LOG_THROTTLE_MS = 15000
local REPAIR_THROTTLE_MS = 5000
local MAX_NAMES = 4

NMClientVanillaDiscVisibleProbe._tick = tonumber(NMClientVanillaDiscVisibleProbe._tick) or 0
NMClientVanillaDiscVisibleProbe._lastLogByKey = NMClientVanillaDiscVisibleProbe._lastLogByKey or {}
NMClientVanillaDiscVisibleProbe._lastRepairByKey = NMClientVanillaDiscVisibleProbe._lastRepairByKey or {}

local function nowRealMs()
    if getTimestampMs then
        local ms = tonumber(getTimestampMs())
        if ms then
            return ms
        end
    end
    if getTimestamp then
        local ts = tonumber(getTimestamp())
        if ts then
            return ts * 1000
        end
    end
    return 0
end

local function isEnabled()
    return NMCore
        and NMCore.isSubsystemDebugEnabled
        and NMCore.isSubsystemDebugEnabled("loot_probe") == true
end

local function logProbe(tag, detail)
    if NMCore and NMCore.logChannel then
        NMCore.logChannel("loot_probe", tostring(tag or "loot_probe.client_visible_vanilla_disc"), tostring(detail or ""))
    end
end

local function shouldSendRepairRequests()
    if NMRuntimeConfig and NMRuntimeConfig.getConvertVanillaCDsAndCDPlayersEnabled then
        return NMRuntimeConfig.getConvertVanillaCDsAndCDPlayersEnabled() == true
    end
    return true
end

local function shouldScanVisibleLoot()
    return isEnabled() == true or shouldSendRepairRequests() == true
end

local function buildServerVisibleArgs(page, pageKind, phase, container, scan, squareText, cType, cName, idsText, namesText)
    local x, y, z = tostring(squareText or ""):match("^(%-?%d+),(%-?%d+),(%-?%d+)$")
    if not x then
        return nil
    end
    return {
        x = tonumber(x) or 0,
        y = tonumber(y) or 0,
        z = tonumber(z) or 0,
        page = tostring(pageKind or "unknown"),
        phase = tostring(phase or "unknown"),
        player = tonumber(page and page.player) or -1,
        selected = page and page.inventoryPane and page.inventoryPane.inventory == container,
        containerType = tostring(cType or ""),
        containerName = tostring(cName or ""),
        clientContainer = tostring(container),
        count = tonumber(scan and scan.count) or 0,
        discCount = tonumber(scan and scan.discCount) or 0,
        deviceCount = tonumber(scan and scan.deviceCount) or 0,
        ids = tostring(idsText or ""),
        names = tostring(namesText or ""),
        discIds = table.concat(scan and scan.discIds or {}, "|"),
        discNames = table.concat(scan and scan.discNames or {}, "|"),
        deviceIds = table.concat(scan and scan.deviceIds or {}, "|"),
        deviceNames = table.concat(scan and scan.deviceNames or {}, "|")
    }
end

local function sendServerVisibleCommand(command, args)
    if not (sendClientCommand and NMCore and NMCore.NetModule) then
        return
    end
    if type(args) ~= "table" then
        return
    end
    sendClientCommand(NMCore.NetModule, tostring(command or ""), args)
end

local function sendServerVisibleCheck(args)
    sendServerVisibleCommand("loot_probe_client_visible_vanilla_disc", args)
end

local function shouldRequestRepair(key, nowMs)
    local last = tonumber(NMClientVanillaDiscVisibleProbe._lastRepairByKey[key]) or 0
    if last > 0 and (nowMs - last) < REPAIR_THROTTLE_MS then
        return false
    end
    NMClientVanillaDiscVisibleProbe._lastRepairByKey[key] = nowMs
    return true
end

local function sendServerVisibleRepair(key, nowMs, args)
    if shouldSendRepairRequests() ~= true or shouldRequestRepair(key, nowMs) ~= true then
        return
    end
    sendServerVisibleCommand("repair_visible_vanilla_media", args)
end

local function itemFullType(item)
    if item and item.getFullType then
        return tostring(item:getFullType() or "")
    end
    return ""
end

local function isVanillaDisc(item)
    local fullType = itemFullType(item)
    if fullType == "Base.Disc_Retail" then
        return true
    end
    if item and item.getType and tostring(item:getType() or "") == "Disc_Retail" then
        return true
    end
    return false
end

local function isVanillaCDPlayer(item)
    local fullType = itemFullType(item)
    if fullType == "Base.CDplayer" or fullType == "Base.CDPlayer" then
        return true
    end
    local itemType = item and item.getType and tostring(item:getType() or "") or ""
    return itemType == "CDplayer" or itemType == "CDPlayer"
end

local function itemName(item)
    if item and item.getDisplayName then
        local displayName = tostring(item:getDisplayName() or "")
        if displayName ~= "" then
            return displayName
        end
    end
    if item and item.getName then
        local name = tostring(item:getName() or "")
        if name ~= "" then
            return name
        end
    end
    return itemFullType(item)
end

local function itemId(item)
    if NMCore and NMCore.itemId then
        local id = NMCore.itemId(item)
        if id then
            return tostring(id)
        end
    end
    if item and item.getID then
        return tostring(item:getID() or "")
    end
    return ""
end

local function containerType(container)
    if container and container.getType then
        local ok, value = pcall(function()
            return container:getType()
        end)
        if ok and value ~= nil then
            return tostring(value or "")
        end
    end
    return ""
end

local function containerName(button, container)
    if button and button.name then
        local buttonName = tostring(button.name or "")
        if buttonName ~= "" then
            return buttonName
        end
    end
    return containerType(container)
end

local function containerSquareText(container)
    local square = nil
    if container and container.getSourceGrid then
        square = container:getSourceGrid()
    end
    if not square and container and container.getParent then
        local parent = container:getParent()
        if parent and parent.getSquare then
            square = parent:getSquare()
        end
    end
    if square and square.getX and square.getY and square.getZ then
        return string.format(
            "%d,%d,%d",
            tonumber(square:getX()) or 0,
            tonumber(square:getY()) or 0,
            tonumber(square:getZ()) or 0
        )
    end
    return ""
end

local function scanContainer(container)
    local result = {
        count = 0,
        discCount = 0,
        deviceCount = 0,
        names = {},
        ids = {},
        discNames = {},
        discIds = {},
        deviceNames = {},
        deviceIds = {}
    }
    if not (container and container.getItems) then
        return result
    end
    local items = container:getItems()
    if not items then
        return result
    end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if isVanillaDisc(item) then
            result.discCount = result.discCount + 1
            result.count = result.count + 1
            if #result.names < MAX_NAMES then
                result.names[#result.names + 1] = itemName(item)
            end
            if #result.ids < MAX_NAMES then
                result.ids[#result.ids + 1] = itemId(item)
            end
            if #result.discNames < MAX_NAMES then
                result.discNames[#result.discNames + 1] = itemName(item)
            end
            if #result.discIds < MAX_NAMES then
                result.discIds[#result.discIds + 1] = itemId(item)
            end
        elseif isVanillaCDPlayer(item) then
            result.deviceCount = result.deviceCount + 1
            result.count = result.count + 1
            if #result.names < MAX_NAMES then
                result.names[#result.names + 1] = itemName(item)
            end
            if #result.ids < MAX_NAMES then
                result.ids[#result.ids + 1] = itemId(item)
            end
            if #result.deviceNames < MAX_NAMES then
                result.deviceNames[#result.deviceNames + 1] = itemName(item)
            end
            if #result.deviceIds < MAX_NAMES then
                result.deviceIds[#result.deviceIds + 1] = itemId(item)
            end
        end
    end
    return result
end

local function shouldLog(key, nowMs)
    local last = tonumber(NMClientVanillaDiscVisibleProbe._lastLogByKey[key]) or 0
    if (nowMs - last) < LOG_THROTTLE_MS then
        return false
    end
    NMClientVanillaDiscVisibleProbe._lastLogByKey[key] = nowMs
    return true
end

local function logContainerHit(page, pageKind, phase, button, container, scan)
    if tonumber(scan and scan.count) == nil or scan.count <= 0 then
        return
    end
    local player = tonumber(page and page.player) or -1
    local selected = page and page.inventoryPane and page.inventoryPane.inventory == container
    local cType = containerType(container)
    local cName = containerName(button, container)
    local squareText = containerSquareText(container)
    local namesText = table.concat(scan.names or {}, "|")
    local idsText = table.concat(scan.ids or {}, "|")
    local key = table.concat({
        tostring(player),
        tostring(pageKind or ""),
        tostring(container),
        tostring(scan.count),
        namesText,
        idsText
    }, "::")
    local nowMs = nowRealMs()
    local args = buildServerVisibleArgs(page, pageKind, phase, container, scan, squareText, cType, cName, idsText, namesText)
    sendServerVisibleRepair(key, nowMs, args)
    if not shouldLog(key, nowMs) then
        return
    end
    sendServerVisibleCheck(args)
    logProbe(
        "loot_probe.client_visible_vanilla_disc",
        string.format(
            "phase=%s page=%s player=%d selected=%s container=%s type=%s name=%s square=%s count=%d discCount=%d deviceCount=%d ids={%s} names={%s} discNames={%s} deviceNames={%s}",
            tostring(phase or "unknown"),
            tostring(pageKind or "unknown"),
            player,
            tostring(selected == true),
            tostring(container),
            tostring(cType),
            tostring(cName),
            tostring(squareText),
            tonumber(scan.count) or 0,
            tonumber(scan.discCount) or 0,
            tonumber(scan.deviceCount) or 0,
            tostring(idsText),
            tostring(namesText),
            table.concat(scan.discNames or {}, "|"),
            table.concat(scan.deviceNames or {}, "|")
        )
    )
end

local function scanPage(page, pageKind, phase)
    if not page then
        return
    end
    if page.backpacks then
        for i, button in ipairs(page.backpacks) do
            local container = button and button.inventory or nil
            logContainerHit(page, pageKind, phase, button, container, scanContainer(container))
        end
    end
    local selectedContainer = page.inventoryPane and page.inventoryPane.inventory or nil
    if selectedContainer then
        logContainerHit(page, pageKind, phase, nil, selectedContainer, scanContainer(selectedContainer))
    end
end

function NMClientVanillaDiscVisibleProbe.scanVisibleLoot(reason)
    if not shouldScanVisibleLoot() then
        return
    end
    for playerNum = 0, 3 do
        local lootPage = getPlayerLoot and getPlayerLoot(playerNum) or nil
        if lootPage and lootPage.getIsVisible and lootPage:getIsVisible() then
            scanPage(lootPage, "loot", reason)
        end
        local inventoryPage = getPlayerInventory and getPlayerInventory(playerNum) or nil
        if inventoryPage and inventoryPage.getIsVisible and inventoryPage:getIsVisible() then
            scanPage(inventoryPage, "inventory", reason)
        end
    end
end

function NMClientVanillaDiscVisibleProbe.onRefreshInventoryWindowContainers(page, phase)
    if phase ~= "end" then
        return
    end
    if not shouldScanVisibleLoot() then
        return
    end
    local pageKind = page and page.onCharacter and "inventory" or "loot"
    scanPage(page, pageKind, "inventory_refresh_end")
end

function NMClientVanillaDiscVisibleProbe.onTick()
    NMClientVanillaDiscVisibleProbe._tick = (tonumber(NMClientVanillaDiscVisibleProbe._tick) or 0) + 1
    if (NMClientVanillaDiscVisibleProbe._tick % TICK_INTERVAL) ~= 0 then
        return
    end
    NMClientVanillaDiscVisibleProbe.scanVisibleLoot("visible_tick")
end

if Events then
    if Events.OnRefreshInventoryWindowContainers and Events.OnRefreshInventoryWindowContainers.Add then
        Events.OnRefreshInventoryWindowContainers.Add(NMClientVanillaDiscVisibleProbe.onRefreshInventoryWindowContainers)
    end
    if Events.OnTick and Events.OnTick.Add then
        Events.OnTick.Add(NMClientVanillaDiscVisibleProbe.onTick)
    end
end

return NMClientVanillaDiscVisibleProbe
