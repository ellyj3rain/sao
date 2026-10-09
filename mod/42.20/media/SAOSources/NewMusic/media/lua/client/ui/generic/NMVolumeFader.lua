require "ISUI/ISPanel"
NMVolumeFader = NMVolumeFader or {}

local SCALE = 2.0
local function S(v)
    return v * SCALE
end

local DETENT_COUNT = 21
local DETENT_TOP_PX = S(11)
local DETENT_STEP_PX = S(11)
local PANEL_W = S(54)
local PANEL_H = S(242)
local STRIP_X = S(10)
local STRIP_Y = 0
local STRIP_W = S(6)
local STRIP_H = PANEL_H
local FADER_W = S(14)
local FADER_H = S(22)
local TICK_GAP_X = S(5)
local TICK_COLUMN_X_OFFSET = 4
local TICK_COLUMN_Y_OFFSET = -1
local TICK_X = STRIP_X + STRIP_W + TICK_GAP_X + TICK_COLUMN_X_OFFSET
local LONG_TICK_W = S(9)
local SHORT_TICK_W = S(5)
local TICK_H = S(1)
local LABEL_TOP_Y = S(9) + TICK_COLUMN_Y_OFFSET + S(1)
local LABEL_MID_Y = S(119) + TICK_COLUMN_Y_OFFSET + S(1)
local LABEL_BOT_Y = S(228) + TICK_COLUMN_Y_OFFSET + S(1)
local LABEL_X = TICK_X
local LABEL_BLOCK_W = S(14)
local DRAG_DISPATCH_MIN_MS = 80
local STATIC_GEOMETRY = nil

local function nowMs()
    return (getTimestampMs and tonumber(getTimestampMs()))
        or (getTimeInMillis and tonumber(getTimeInMillis()))
        or 0
end

local function clamp01(v)
    return NMCore.clamp(tonumber(v) or 0.0, 0.0, 1.0)
end

local function pctToDetentIndex(pct)
    local clamped = clamp01(pct)
    local idx = math.floor(((1.0 - clamped) * (DETENT_COUNT - 1)) + 0.5)
    if idx < 0 then idx = 0 end
    if idx > (DETENT_COUNT - 1) then idx = DETENT_COUNT - 1 end
    return idx
end

local function detentIndexToPct(idx)
    local i = math.max(0, math.min(DETENT_COUNT - 1, math.floor(tonumber(idx) or 0)))
    return clamp01(1.0 - (i / (DETENT_COUNT - 1)))
end

local function detentIndexToCenterY(idx)
    return DETENT_TOP_PX + (DETENT_STEP_PX * idx)
end

local function mouseYToDetentIndex(panel, localY)
    local y = tonumber(localY) or 0
    local bestIdx = 0
    local bestDist = 999999
    for i = 0, (DETENT_COUNT - 1) do
        local cy = detentIndexToCenterY(i)
        local d = math.abs(y - cy)
        if d < bestDist then
            bestDist = d
            bestIdx = i
        end
    end
    return bestIdx
end

local function activeLeftX()
    local thumbX = STRIP_X + math.floor((STRIP_W - FADER_W) / 2)
    return math.min(thumbX, TICK_X)
end

local function activeRightX()
    local thumbX = STRIP_X + math.floor((STRIP_W - FADER_W) / 2)
    local thumbRight = thumbX + FADER_W
    local labelRight = LABEL_X + LABEL_BLOCK_W
    return math.max(thumbRight, labelRight)
end

local function isInsideActiveArea(xArg, yArg)
    local x = tonumber(xArg) or -9999
    local y = tonumber(yArg) or -9999
    if y < 0 or y > PANEL_H then
        return false
    end
    return x >= activeLeftX() and x <= activeRightX()
end

local SYMBOL_UNIT = 3.33

local function appendSymbolRects(out, x, y, rects)
    local u = S(1)
    local k = u / SYMBOL_UNIT
    for i = 1, #rects do
        local r = rects[i]
        out[#out + 1] = {
            x = x + (r[1] * k),
            y = y + (r[2] * k),
            w = r[3] * k,
            h = r[4] * k,
        }
    end
end

local function dedupeRects(rects)
    local out = {}
    local seen = {}
    for i = 1, #rects do
        local r = rects[i]
        local key = string.format("%.2f,%.2f,%.2f,%.2f", r[1], r[2], r[3], r[4])
        if not seen[key] then
            seen[key] = true
            out[#out + 1] = r
        end
    end
    return out
end

local SYMBOL_100_RECTS = dedupeRects({
    { 3.33, 0.00, 3.34, 13.33 },
    { 0.00, 3.33, 3.33, 3.34 },
    { 0.00, 6.67, 3.33, 3.33 },
    { 10.00, 0.00, 10.00, 3.33 },
    { 10.00, 10.00, 10.00, 3.33 },
    { 16.66, 3.33, 3.34, 6.67 },
    { 10.00, 3.33, 3.33, 6.67 },
    { 23.33, 0.00, 10.00, 3.33 },
    { 23.33, 10.00, 10.00, 3.33 },
    { 29.99, 3.33, 3.34, 6.67 },
    { 23.33, 3.33, 3.33, 6.67 },
    { 36.67, 0.00, 3.33, 3.33 },
    { 40.00, 3.33, 3.33, 3.34 },
    { 43.33, 6.67, 3.34, 3.33 },
    { 46.67, 10.00, 3.33, 3.33 },
    { 36.67, 10.00, 3.33, 3.33 },
    { 46.67, 0.00, 3.33, 3.33 }
})

local SYMBOL_50_RECTS = dedupeRects({
    { 0.00, 0.00, 10.00, 3.33 },
    { 0.00, 3.33, 6.67, 3.33 },
    { 6.67, 6.66, 3.33, 3.34 },
    { 0.00, 10.00, 10.00, 3.33 },
    { 13.33, 0.00, 10.00, 3.33 },
    { 13.33, 10.00, 10.00, 3.33 },
    { 20.00, 3.33, 3.33, 6.67 },
    { 13.33, 3.33, 3.33, 6.67 },
    { 26.67, 0.00, 3.33, 3.33 },
    { 30.00, 3.33, 3.33, 3.34 },
    { 33.33, 6.66, 3.34, 3.34 },
    { 36.67, 10.00, 3.33, 3.33 },
    { 26.67, 10.00, 3.33, 3.33 },
    { 36.67, 0.00, 3.33, 3.33 }
})

local SYMBOL_INFINITY_RECTS = dedupeRects({
    { 0, 3.33, 3.33, 10.0 },
    { 3.33, 0, 10, 3.33 }, { 3.33, 13.33, 10, 3.34 },
    { 13.33, 3.33, 3.33, 3.33 }, { 16.67, 6.67, 3.33, 3.33 }, { 13.33, 10, 3.33, 3.33 },
    { 20, 10, 3.33, 3.33 }, { 20, 3.33, 3.33, 3.33 },
    { 23.33, 0, 10, 3.33 }, { 33.33, 3.33, 3.33, 10.0 }, { 23.33, 13.33, 10, 3.34 }
})

local function buildStaticGeometry()
    local rects = {}
    rects[#rects + 1] = { x = STRIP_X, y = STRIP_Y, w = STRIP_W, h = STRIP_H, a = 1.0, r = 0.27, g = 0.27, b = 0.29 }
    for i = 1, DETENT_COUNT do
        local detent = i - 1
        if detent ~= 0 and detent ~= 10 and detent ~= 20 then
            local y = detentIndexToCenterY(detent) + TICK_COLUMN_Y_OFFSET
            local w = ((detent % 2) == 0) and LONG_TICK_W or SHORT_TICK_W
            rects[#rects + 1] = { x = TICK_X, y = y, w = w, h = TICK_H, a = 1.0, r = 1.0, g = 1.0, b = 1.0 }
        end
    end
    appendSymbolRects(rects, LABEL_X, LABEL_TOP_Y, SYMBOL_100_RECTS)
    appendSymbolRects(rects, LABEL_X, LABEL_MID_Y, SYMBOL_50_RECTS)
    appendSymbolRects(rects, LABEL_X, LABEL_BOT_Y, SYMBOL_INFINITY_RECTS)
    for i = 1, #rects do
        local r = rects[i]
        if r.a == nil then
            r.a, r.r, r.g, r.b = 1.0, 1.0, 1.0, 1.0
        end
    end
    return rects
end

local function getStaticGeometry()
    if STATIC_GEOMETRY == nil then
        STATIC_GEOMETRY = buildStaticGeometry()
    end
    return STATIC_GEOMETRY
end

local function drawStaticGeometry(panel)
    local rects = getStaticGeometry()
    for i = 1, #rects do
        local r = rects[i]
        panel:drawRect(r.x, r.y, r.w, r.h, r.a, r.r, r.g, r.b)
    end
end

local function drawFaderThumb(panel, centerY)
    local x = STRIP_X + math.floor((STRIP_W - FADER_W) / 2)
    local y = math.floor(centerY - math.floor(FADER_H / 2))
    panel:drawRect(x, y, FADER_W, S(11), 1.0, 0.38, 0.38, 0.38)
    panel:drawRect(x, y + S(11), FADER_W, S(11), 1.0, 0.30, 0.30, 0.30)
    local innerX = x + S(2)
    panel:drawRect(innerX, y + S(2), S(10), S(8), 1.0, 0.56, 0.56, 0.56)
    panel:drawRect(innerX, y + S(10), S(10), S(1), 1.0, 1.0, 1.0, 1.0)
    panel:drawRect(innerX, y + S(11), S(10), S(8), 1.0, 0.45, 0.44, 0.45)
end

function NMVolumeFader.buildRenderState(window, frame)
    local resolved = frame and frame.resolved or (window and window.resolveContextCached and window:resolveContextCached()) or nil
    local state = resolved and resolved.state or nil
    local liveVolume = tonumber(state and state.volume)
    return {
        liveVolume = liveVolume and clamp01(liveVolume) or nil,
    }
end

function NMVolumeFader.prewarm(panel)
    getStaticGeometry()
end

local function applyDetent(panel, idx)
    idx = math.max(0, math.min(DETENT_COUNT - 1, math.floor(tonumber(idx) or 0)))
    if panel._nmLastDetentIdx == idx then
        return
    end
    panel._nmLastDetentIdx = idx
    panel._nmPreviewVolume = detentIndexToPct(idx)
    panel._nmStableVolume = panel._nmPreviewVolume
    panel._nmPendingDispatchVolume = panel._nmPreviewVolume
end

local function flushVolumeDispatch(panel, force)
    if not (panel and panel.window and panel.window.executeUiControl) then
        return
    end
    local pending = tonumber(panel._nmPendingDispatchVolume)
    if pending == nil then
        return
    end
    local now = nowMs()
    local last = tonumber(panel._nmLastVolumeDispatchMs) or 0
    if force ~= true and (now - last) < DRAG_DISPATCH_MIN_MS then
        return
    end
    panel.window:executeUiControl("set_volume", { volume = pending })
    panel._nmLastVolumeDispatchMs = now
    panel._nmLastDispatchedVolume = pending
    panel._nmPendingDispatchVolume = nil
end

function NMVolumeFader.attach(window, x, y)
    local panel = ISPanel:new(x, y, PANEL_W, PANEL_H)
    panel:initialise()
    panel:instantiate()
    panel.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    panel.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    panel.window = window
    panel._nmDragging = false
    panel._nmLastDetentIdx = nil
    panel._nmPreviewVolume = nil
    panel._nmStableVolume = nil
    panel._nmPendingDispatchVolume = nil
    panel._nmLastVolumeDispatchMs = 0
    panel._nmLastDispatchedVolume = nil

    panel.onMouseDown = function(self, xArg, yArg)
        if not isInsideActiveArea(xArg, yArg) then
            return false
        end
        self._nmDragging = true
        local idx = mouseYToDetentIndex(self, yArg)
        applyDetent(self, idx)
        flushVolumeDispatch(self, false)
        return true
    end

    panel.onMouseMove = function(self, dx, dy)
        if self._nmDragging then
            local ay = getMouseY and getMouseY() or 0
            local py = self.getAbsoluteY and self:getAbsoluteY() or 0
            local idx = mouseYToDetentIndex(self, ay - py)
            applyDetent(self, idx)
            flushVolumeDispatch(self, false)
        end
        return true
    end

    panel.onMouseMoveOutside = function(self, dx, dy)
        if self._nmDragging then
            local ay = getMouseY and getMouseY() or 0
            local py = self.getAbsoluteY and self:getAbsoluteY() or 0
            local idx = mouseYToDetentIndex(self, ay - py)
            applyDetent(self, idx)
            flushVolumeDispatch(self, false)
        end
        return true
    end

    panel.onMouseUp = function(self, xArg, yArg)
        if self._nmDragging and isInsideActiveArea(xArg, yArg) then
            local idx = mouseYToDetentIndex(self, yArg)
            applyDetent(self, idx)
        end
        flushVolumeDispatch(self, true)
        self._nmDragging = false
        return true
    end

    panel.onMouseUpOutside = function(self, xArg, yArg)
        if not self._nmDragging then
            return false
        end
        local ay = getMouseY and getMouseY() or 0
        local py = self.getAbsoluteY and self:getAbsoluteY() or 0
        local idx = mouseYToDetentIndex(self, ay - py)
        applyDetent(self, idx)
        flushVolumeDispatch(self, true)
        self._nmDragging = false
        return true
    end

    panel.render = function(self)
        local perfStart = NMUIRenderProbe and NMUIRenderProbe.beginWindow and NMUIRenderProbe.beginWindow(window) or nil
        local renderState = self.window and self.window.getRenderState and self.window:getRenderState("fader") or nil
        local liveVolume = renderState and renderState.liveVolume or nil
        if liveVolume ~= nil then
            self._nmStableVolume = clamp01(liveVolume)
        elseif self._nmStableVolume == nil then
            self._nmStableVolume = clamp01(self._nmPreviewVolume or 1.0)
        end

        local authoritative = self._nmStableVolume
        local effectiveVolume = self._nmDragging and (self._nmPreviewVolume or authoritative) or authoritative
        local detentIdx = pctToDetentIndex(effectiveVolume)
        local centerY = detentIndexToCenterY(detentIdx)

        drawStaticGeometry(self)
        drawFaderThumb(self, centerY)

        if NMUIRenderProbe and NMUIRenderProbe.endWindow then
            NMUIRenderProbe.endWindow(window, "widget.fader.render", perfStart)
        end
    end

    window:addChild(panel)
    return panel
end

function NMVolumeFader.getPanelSize()
    return PANEL_W, PANEL_H
end
