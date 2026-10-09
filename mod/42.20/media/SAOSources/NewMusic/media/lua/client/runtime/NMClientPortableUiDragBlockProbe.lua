NMClientPortableUiDragBlockProbe = NMClientPortableUiDragBlockProbe or {}

local probe = NMClientPortableUiDragBlockProbe

probe._tick = probe._tick or 0
probe._lastSignature = probe._lastSignature or nil
probe._lastWindowSignature = probe._lastWindowSignature or nil
probe._lastLeftDown = probe._lastLeftDown or false
probe._lastDragActive = probe._lastDragActive or false
probe._lastNmDragActive = probe._lastNmDragActive or false
probe._lastWinner = probe._lastWinner or nil

local DRAG_HEARTBEAT_TICKS = 180

local function enabled()
    return NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("ui_lifecycle") == true
end

local function log(tag, detail)
    if not (enabled() and NMCore and NMCore.logChannel) then
        return
    end
    NMCore.logChannel("ui_lifecycle", tostring(tag or "ui_lifecycle"), tostring(detail or ""))
end

local function toBool(value)
    return value == true
end

local function safeNumber(value)
    local n = tonumber(value)
    if n == nil then
        return "nil"
    end
    return tostring(math.floor(n + 0.5))
end

local function safeString(value)
    local text = tostring(value or "")
    text = text:gsub("%s+", " ")
    return text
end

local function getTopLevelUiList()
    local uiManager = UIManager
    if not (uiManager and uiManager.getUI) then
        return nil
    end
    return uiManager.getUI()
end

local function isVisibleWindow(window)
    if not (window and window.javaObject) then
        return false
    end
    if window.getIsVisible then
        return window:getIsVisible() == true
    end
    if window.isVisible then
        return window:isVisible() == true
    end
    return true
end

local function firstVisibleWindow(windowMap)
    if type(windowMap) ~= "table" then
        return nil
    end
    for _, window in pairs(windowMap) do
        if isVisibleWindow(window) then
            return window
        end
    end
    return nil
end

local function getOpenPortableWindows()
    local genericEnv = rawget(_G, "NMDeviceWindowEnv") or nil
    local walkmanEnv = rawget(_G, "NMWalkmanWindowEnv") or nil
    local cdEnv = rawget(_G, "NMCDPlayerWindowEnv") or nil
    return firstVisibleWindow(walkmanEnv and walkmanEnv.windowsByPlayer or nil),
        firstVisibleWindow(cdEnv and cdEnv.windowsByPlayer or nil),
        firstVisibleWindow(genericEnv and genericEnv.windowsByPlayer or nil)
end

function probe.hasPendingWork()
    if not enabled() then
        return false
    end
    local walkmanWindow, cdWindow, genericWindow = getOpenPortableWindows()
    if walkmanWindow or cdWindow or genericWindow then
        return true
    end
    if ISMouseDrag and type(ISMouseDrag.dragging) == "table" and #ISMouseDrag.dragging > 0 then
        return true
    end
    local nmDragWindow = nil
    local nmDrag = nil
    if NMSlotGhostManager and NMSlotGhostManager.getActiveDrag then
        nmDragWindow, nmDrag = NMSlotGhostManager.getActiveDrag()
    end
    return nmDragWindow ~= nil and nmDrag ~= nil
end

local function describeJavaUi(ui)
    if not ui then
        return "ui=nil"
    end
    local uiTable = ui.getTable and ui:getTable() or nil
    local typeName = safeString(uiTable and uiTable.Type or "")
    local luaName = safeString(uiTable and uiTable.name or "")
    local uiName = safeString(ui.getUIName and ui:getUIName() or "")
    local x = safeNumber(ui.getX and ui:getX() or nil)
    local y = safeNumber(ui.getY and ui:getY() or nil)
    local w = safeNumber(ui.getWidth and ui:getWidth() or nil)
    local h = safeNumber(ui.getHeight and ui:getHeight() or nil)
    local visible = tostring(ui.isVisible and ui:isVisible() == true or false)
    local capture = tostring(ui.isCapture and ui:isCapture() == true or false)
    local consume = tostring(ui.isConsumeMouseEvents and ui:isConsumeMouseEvents() == true or false)
    return string.format(
        "uiName=%s type=%s name=%s x=%s y=%s w=%s h=%s visible=%s capture=%s consume=%s",
        uiName,
        typeName,
        luaName,
        x,
        y,
        w,
        h,
        visible,
        capture,
        consume
    )
end

local function describeWindow(family, window)
    if not window then
        return tostring(family or "window") .. "=closed"
    end
    local javaObject = window.javaObject
    local tooltipObject = window.tooltipUI and window.tooltipUI.javaObject or nil
    local root = describeJavaUi(javaObject)
    local tooltip = tooltipObject and describeJavaUi(tooltipObject) or "tooltip=closed"
    return string.format(
        "%sRoot={%s} %s tooltipVisible=%s",
        tostring(family or "window"),
        root,
        tooltip,
        tostring(window.tooltipUI and window.tooltipUI.getIsVisible and window.tooltipUI:getIsVisible() == true or false)
    )
end

local function buildWindowSignature(walkmanWindow, cdWindow, genericWindow)
    return table.concat({
        tostring(walkmanWindow ~= nil),
        describeWindow("walkman", walkmanWindow),
        tostring(cdWindow ~= nil),
        describeWindow("cdplayer", cdWindow),
        tostring(genericWindow ~= nil),
        describeWindow("generic", genericWindow),
    }, " || ")
end

local function identifyUi(ui, walkmanWindow, cdWindow, genericWindow)
    if walkmanWindow and walkmanWindow.javaObject == ui then
        return "walkman_root"
    end
    if walkmanWindow and walkmanWindow.tooltipUI and walkmanWindow.tooltipUI.javaObject == ui then
        return "walkman_tooltip"
    end
    if cdWindow and cdWindow.javaObject == ui then
        return "cdplayer_root"
    end
    if cdWindow and cdWindow.tooltipUI and cdWindow.tooltipUI.javaObject == ui then
        return "cdplayer_tooltip"
    end
    if genericWindow and genericWindow.javaObject == ui then
        return "generic_root"
    end
    if NMSlotGhostOverlay and NMSlotGhostOverlay.instance and NMSlotGhostOverlay.instance.javaObject == ui then
        return "ghost_overlay"
    end
    local uiTable = ui and ui.getTable and ui:getTable() or nil
    local typeName = safeString(uiTable and uiTable.Type or "")
    local uiName = safeString(ui and ui.getUIName and ui:getUIName() or "")
    local lowerType = string.lower(typeName)
    local lowerName = string.lower(uiName)
    if string.find(lowerType, "inventory", 1, true) or string.find(lowerName, "inventory", 1, true) then
        return "inventory_ui"
    end
    if string.find(lowerType, "contextmenu", 1, true) or string.find(lowerName, "contextmenu", 1, true) then
        return "context_menu"
    end
    if typeName ~= "" then
        return typeName
    end
    if uiName ~= "" then
        return uiName
    end
    return "unknown_ui"
end

local function hasDraggedInventoryPayload()
    if not ISMouseDrag then
        return false
    end
    local dragging = ISMouseDrag.dragging
    return type(dragging) == "table" and #dragging > 0
end

local function resolveActiveNmSlotDrag()
    if not (NMSlotGhostManager and NMSlotGhostManager.getActiveDrag) then
        return nil, nil
    end
    return NMSlotGhostManager.getActiveDrag()
end

local function describeInventoryDrag()
    if not ISMouseDrag then
        return "mouseDrag=missing"
    end
    local dragging = ISMouseDrag.dragging
    if type(dragging) ~= "table" then
        return "mouseDrag=none"
    end
    return "mouseDrag=count:" .. tostring(#dragging)
end

local function describeActiveNmDrag(window, drag)
    if not (window and drag) then
        return "nmDrag=none"
    end
    local family = NMSlotActionCommon and NMSlotActionCommon.resolveSlotHostFamily
        and NMSlotActionCommon.resolveSlotHostFamily(window)
        or "unknown"
    local target = NMSlotActionCommon and NMSlotActionCommon.resolveSlotTargetSummary
        and NMSlotActionCommon.resolveSlotTargetSummary(window)
        or {}
    return string.format(
        "nmDrag=slotType:%s family:%s targetKind:%s itemId:%s uuid:%s vehicleId:%s partId:%s moved:%s zone:%s",
        tostring(drag.slotType or ""),
        tostring(family),
        tostring(target.kind or ""),
        tostring(target.itemId or ""),
        tostring(target.uuid or ""),
        tostring(target.vehicleId or ""),
        tostring(target.partId or ""),
        tostring(drag.moved == true),
        tostring(drag.sourceZoneKind or "slot")
    )
end

local function findDragBlockingUi(walkmanWindow, cdWindow, genericWindow)
    local uis = getTopLevelUiList()
    if not uis then
        return nil, "uis=nil"
    end
    local mx = getMouseX and getMouseX() or 0
    local my = getMouseY and getMouseY() or 0
    local winner = nil
    local parts = {}
    for i = 0, uis:size() - 1 do
        local ui = uis:get(i)
        local over = ui and ui.isPointOver and ui:isPointOver(mx, my) == true or false
        local role = identifyUi(ui, walkmanWindow, cdWindow, genericWindow)
        if i < 8 or over then
            parts[#parts + 1] = string.format(
                "#%d:%s:over=%s:%s",
                i,
                role,
                tostring(over),
                describeJavaUi(ui)
            )
        end
        if winner == nil and over then
            winner = string.format("#%d:%s:%s", i, role, describeJavaUi(ui))
        end
    end
    return winner, table.concat(parts, " | ")
end

function probe.onGameStart()
    if not enabled() then
        return
    end
    log("walkman_drag_probe_ready", "subsystem=ui_lifecycle")
end

function probe.onTick()
    if not enabled() then
        return
    end

    probe._tick = (tonumber(probe._tick) or 0) + 1

    local walkmanWindow, cdWindow, genericWindow = getOpenPortableWindows()
    local dragActive = hasDraggedInventoryPayload()
    local nmDragWindow, nmDrag = resolveActiveNmSlotDrag()
    local nmDragActive = nmDragWindow ~= nil and nmDrag ~= nil
    local walkmanOpen = walkmanWindow ~= nil
    local cdOpen = cdWindow ~= nil
    local genericOpen = genericWindow ~= nil
    local leftDown = isMouseButtonDown and isMouseButtonDown(0) == true or false

    if not walkmanOpen and not cdOpen and not genericOpen and not dragActive and not nmDragActive then
        probe._lastDragActive = false
        probe._lastNmDragActive = false
        probe._lastWinner = nil
        return
    end

    local hadActiveDrag = probe._lastDragActive == true or probe._lastNmDragActive == true
    local dragTransition = dragActive ~= (probe._lastDragActive == true) or nmDragActive ~= (probe._lastNmDragActive == true)
    local mouseTransition = leftDown ~= (probe._lastLeftDown == true)
    local shouldLogWindowState = not hadActiveDrag or dragTransition or mouseTransition

    if shouldLogWindowState then
        local windowSignature = buildWindowSignature(walkmanWindow, cdWindow, genericWindow)
        if windowSignature ~= probe._lastWindowSignature then
            probe._lastWindowSignature = windowSignature
            log("ui_lifecycle_window_state", windowSignature)
        end
    end

    if not dragActive and not nmDragActive then
        probe._lastDragActive = false
        probe._lastNmDragActive = false
        probe._lastWinner = nil
        probe._lastLeftDown = leftDown
        return
    end

    local heartbeatDue = (probe._tick % DRAG_HEARTBEAT_TICKS) == 1
    local shouldScan = dragTransition or mouseTransition or heartbeatDue
    local winner = nil
    local scan = nil

    if shouldScan then
        winner, scan = findDragBlockingUi(walkmanWindow, cdWindow, genericWindow)
    end

    local winnerChanged = shouldScan and safeString(winner or "none") ~= safeString(probe._lastWinner or "none")
    local shouldEmitDetail = dragTransition or mouseTransition or winnerChanged or heartbeatDue
    if not shouldEmitDetail then
        probe._lastDragActive = dragActive == true
        probe._lastNmDragActive = nmDragActive == true
        probe._lastLeftDown = leftDown
        return
    end

    if shouldScan then
        probe._lastWinner = winner
    end

    local signature = string.format(
        "drag=true nmDrag=%s inventoryDrag=%s leftDown=%s mouse=%s,%s winner=%s walkmanOpen=%s cdOpen=%s genericOpen=%s",
        tostring(nmDragActive),
        tostring(dragActive),
        tostring(leftDown),
        safeNumber(getMouseX and getMouseX() or nil),
        safeNumber(getMouseY and getMouseY() or nil),
        safeString((shouldScan and winner) or probe._lastWinner or "none"),
        tostring(walkmanOpen),
        tostring(cdOpen),
        tostring(genericOpen)
    )

    if signature ~= probe._lastSignature or dragTransition or mouseTransition or winnerChanged or heartbeatDue then
        probe._lastSignature = signature
        log("ui_lifecycle_drag_gate", signature)
        log("ui_lifecycle_drag_state", describeInventoryDrag() .. " " .. describeActiveNmDrag(nmDragWindow, nmDrag))
        if shouldScan then
            log("ui_lifecycle_drag_scan", scan)
        end
    end

    if probe._lastLeftDown == true and leftDown ~= true then
        if not shouldScan then
            winner, scan = findDragBlockingUi(walkmanWindow, cdWindow, genericWindow)
            probe._lastWinner = winner
        end
        local vanillaOwnsRelease = dragActive == true
        log(
            "ui_lifecycle_release_snapshot",
            table.concat({
                "winner=" .. safeString(winner or "none"),
                "scan=" .. safeString(scan or "scan_skipped"),
                describeInventoryDrag(),
                describeActiveNmDrag(nmDragWindow, nmDrag),
                "vanillaOwnsRelease=" .. tostring(vanillaOwnsRelease),
                "ghostVisible=" .. tostring(NMSlotGhostOverlay and NMSlotGhostOverlay.instance ~= nil),
                "leftDown=" .. tostring(leftDown)
            }, " | ")
        )
    end

    probe._lastDragActive = dragActive == true
    probe._lastNmDragActive = nmDragActive == true
    probe._lastLeftDown = leftDown
end

return probe
