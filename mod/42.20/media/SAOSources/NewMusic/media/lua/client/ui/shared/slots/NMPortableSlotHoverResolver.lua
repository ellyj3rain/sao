NMPortableSlotHoverResolver = NMPortableSlotHoverResolver or {}

local resolver = NMPortableSlotHoverResolver

local function probeEnabled()
    return NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("portable_ui") == true
end

local function logProbe(tag, detail)
    if not (probeEnabled() and NMCore and NMCore.logChannel) then
        return
    end
    NMCore.logChannel("portable_ui", tostring(tag or "portable_ui"), tostring(detail or ""))
end

local function clampPlayerNum(playerNum)
    return tonumber(playerNum) or 0
end

local function getMousePoint()
    return getMouseX and getMouseX() or 0, getMouseY and getMouseY() or 0
end

local function pointInScreenRect(mx, my, rect)
    if type(rect) ~= "table" then
        return false
    end
    local x = tonumber(rect.x) or 0
    local y = tonumber(rect.y) or 0
    local w = tonumber(rect.w) or 0
    local h = tonumber(rect.h) or 0
    if w <= 0 or h <= 0 then
        return false
    end
    return mx >= x and mx < (x + w) and my >= y and my < (y + h)
end

local function zoneContainsPoint(zone, mx, my)
    if type(zone) ~= "table" then
        return false
    end
    local custom = zone.containsPoint
    if type(custom) == "function" then
        local ok, accepted = pcall(custom, mx, my)
        if ok then
            return accepted == true
        end
        return false
    end
    return pointInScreenRect(mx, my, zone.rect)
end

local function zoneSummary(zone)
    if not zone then
        return "none"
    end
    return string.format(
        "%s:%s:item=%s:uuid=%s:z=%s:p=%s",
        tostring(zone.uiFamily or "unknown"),
        tostring(zone.zoneKind or "slot"),
        tostring(zone.itemId or ""),
        tostring(zone.uuid or ""),
        tostring(zone.zOrder or 0),
        tostring(zone.priority or 0)
    )
end

local function zonesToLine(zones)
    if type(zones) ~= "table" or #zones <= 0 then
        return "none"
    end
    local parts = {}
    for i = 1, #zones do
        parts[#parts + 1] = zoneSummary(zones[i])
    end
    return table.concat(parts, " | ")
end

local function sortZones(zones)
    table.sort(zones, function(a, b)
        local az = tonumber(a and a.zOrder) or 0
        local bz = tonumber(b and b.zOrder) or 0
        if az ~= bz then
            return az > bz
        end
        local ap = tonumber(a and a.priority) or 0
        local bp = tonumber(b and b.priority) or 0
        if ap ~= bp then
            return ap > bp
        end
        local af = tostring(a and a.uiFamily or "")
        local bf = tostring(b and b.uiFamily or "")
        if af ~= bf then
            return af < bf
        end
        local ai = tostring(a and a.itemId or "")
        local bi = tostring(b and b.itemId or "")
        if ai ~= bi then
            return ai < bi
        end
        return tostring(a and a.zoneKind or "") < tostring(b and b.zoneKind or "")
    end)
    return zones
end

local function collectImplementationZones(api, fnName, playerNum, dragItems)
    if not (api and api[fnName]) then
        return {}
    end
    local ok, zones = pcall(api[fnName], playerNum, dragItems)
    if not ok or type(zones) ~= "table" then
        return {}
    end
    return zones
end

local function slotFnName(slotType)
    local kind = tostring(slotType or "")
    if kind == "media" then
        return "collectOpenMediaIngressZones"
    end
    if kind == "battery" then
        return "collectOpenBatteryIngressZones"
    end
    if kind == "headphones" then
        return "collectOpenHeadphoneIngressZones"
    end
    return nil
end

function resolver.collectZones(slotType, playerNum, dragItems)
    local fnName = slotFnName(slotType)
    if not fnName then
        return {}
    end
    local resolvedPlayerNum = clampPlayerNum(playerNum)
    local zones = {}
    local implementations = { NMWalkmanWindow, NMCDPlayerWindow, NMBoomboxWindow, NMDeviceWindow }
    for i = 1, #implementations do
        local api = implementations[i]
        local collected = collectImplementationZones(api, fnName, resolvedPlayerNum, dragItems)
        for j = 1, #collected do
            zones[#zones + 1] = collected[j]
        end
    end
    return zones
end

function resolver.resolveHoveredZone(slotType, playerNum, dragItems, mx, my)
    local mouseX = tonumber(mx)
    local mouseY = tonumber(my)
    if mouseX == nil or mouseY == nil then
        mouseX, mouseY = getMousePoint()
    end
    local zones = resolver.collectZones(slotType, playerNum, dragItems)
    local eligible = {}
    local rejected = {}
    for i = 1, #zones do
        local zone = zones[i]
        local accepted = zone
            and zone.window
            and zone.enabled == true
            and zone.visible == true
            and zoneContainsPoint(zone, mouseX, mouseY)
        if dragItems ~= nil then
            accepted = accepted and (
                (zone.canAcceptDraggedMedia and zone.canAcceptDraggedMedia(dragItems) == true)
                or zone.canAccept == true
            )
        else
            accepted = accepted and zone.interactive == true
        end
        if accepted then
            eligible[#eligible + 1] = zone
        else
            rejected[#rejected + 1] = zone
        end
    end
    sortZones(eligible)
    local winner = eligible[1]
    logProbe(
        "slot_hover_resolve",
        string.format(
            "slot=%s player=%s mouse=%s,%s winner=%s eligible=%s rejected=%s",
            tostring(slotType or ""),
            tostring(clampPlayerNum(playerNum)),
            tostring(mouseX),
            tostring(mouseY),
            zoneSummary(winner),
            zonesToLine(eligible),
            zonesToLine(rejected)
        )
    )
    return winner, eligible, rejected
end

function resolver.resolveHoveredMediaSlotWindow(playerNum, dragItems, mx, my)
    return resolver.resolveHoveredZone("media", playerNum, dragItems, mx, my)
end

function resolver.resolveHoveredBatterySlotWindow(playerNum, dragItems, mx, my)
    return resolver.resolveHoveredZone("battery", playerNum, dragItems, mx, my)
end

function resolver.resolveHoveredHeadphoneSlotWindow(playerNum, dragItems, mx, my)
    return resolver.resolveHoveredZone("headphones", playerNum, dragItems, mx, my)
end

return resolver
