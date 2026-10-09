require "ISUI/ISPanel"
require "ui/shared/NMReadoutLabelState"
require "ui/shared/NMReadoutTextResolver"
require "ui/shared/render/NMUIRenderCache"
-- Canonical generic ui_render widget: builds readout render state and draws the widget.
NMReadoutPane = NMReadoutPane or {}

local PANE_W = 300
local PANE_H = 24
local BORDER = 1
local RING = 1

local OUTER = { a = 1.0, r = 0.39, g = 0.39, b = 0.39 } -- #646364
local BLACK = { a = 1.0, r = 0.0, g = 0.0, b = 0.0 }
local ACTIVE = { a = 1.0, r = 0.69, g = 0.77, b = 0.17 } -- #afc42b
local TEXT = { a = 1.0, r = 0.31, g = 0.35, b = 0.03 } -- #4e5908
local TEXT_PAD = 4

function NMReadoutPane.buildRenderState(window, frame)
    local resolved = frame and frame.resolved or (window and window.resolveContextCached and window:resolveContextCached()) or nil
    local state = resolved and resolved.state or nil
    local contentW = math.max(1, (PANE_W - ((BORDER + RING) * 2)) - (TEXT_PAD * 2))
    local fullText = NMReadoutTextResolver and NMReadoutTextResolver.resolveReadoutText
        and NMReadoutTextResolver.resolveReadoutText(state)
        or NMTranslations.ui("NoMediaNoSong", "No Media | No Song")
    return {
        fullText = fullText,
        contentW = contentW,
        nowMs = frame and frame.nowMs or 0,
    }
end

function NMReadoutPane.attach(window, x, y)
    local panel = ISPanel:new(x, y, PANE_W, PANE_H)
    panel:initialise()
    panel:instantiate()
    panel.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    panel.borderColor = { r = 0, g = 0, b = 0, a = 0 }

    panel.render = function(self)
        local perfStart = NMUIRenderProbe and NMUIRenderProbe.beginWindow and NMUIRenderProbe.beginWindow(window) or nil
        local w = tonumber(self.width) or 0
        local h = tonumber(self.height) or 0
        if w <= 0 or h <= 0 then
            if NMUIRenderProbe and NMUIRenderProbe.endWindow then
                NMUIRenderProbe.endWindow(window, "widget.readout.render", perfStart)
            end
            return
        end
        self:drawRect(0, 0, w, h, OUTER.a, OUTER.r, OUTER.g, OUTER.b)
        self:drawRect(BORDER, BORDER, w - (BORDER * 2), h - (BORDER * 2), BLACK.a, BLACK.r, BLACK.g, BLACK.b)
        local innerX = BORDER + RING
        local innerY = BORDER + RING
        local innerW = w - ((BORDER + RING) * 2)
        local innerH = h - ((BORDER + RING) * 2)
        self:drawRect(innerX, innerY, innerW, innerH, ACTIVE.a, ACTIVE.r, ACTIVE.g, ACTIVE.b)

        local renderState = window and window.getRenderState and window:getRenderState("readout") or nil
        local fullText = renderState and renderState.fullText or NMTranslations.ui("NoMediaNoSong", "No Media | No Song")
        local nowMs = renderState and renderState.nowMs or 0
        local textState = NMReadoutLabelState.build(window, {
            fullText = fullText,
            contentW = renderState and renderState.contentW or math.max(1, innerW - (TEXT_PAD * 2)),
            nowMs = nowMs,
            pagerHost = self,
            x = innerX + TEXT_PAD,
            color = TEXT,
        })
        local tm = getTextManager and getTextManager() or nil
        local textH = tm and tm.MeasureStringY and tm:MeasureStringY(UIFont.Small, "Ag") or 10
        local textY = innerY + math.floor(((innerH - textH) * 0.5) + 0.5)
        if textY < (innerY + TEXT_PAD) then
            textY = innerY + TEXT_PAD
        end
        local drawnText = tostring(textState and textState.text or "")
        self:drawText(drawnText, innerX + TEXT_PAD, textY, TEXT.r, TEXT.g, TEXT.b, TEXT.a, UIFont.Small)
        if NMUIRenderProbe and NMUIRenderProbe.endWindow then
            NMUIRenderProbe.endWindow(window, "widget.readout.render", perfStart)
        end
    end

    window:addChild(panel)
    return panel
end

function NMReadoutPane.getSize()
    return PANE_W, PANE_H
end
