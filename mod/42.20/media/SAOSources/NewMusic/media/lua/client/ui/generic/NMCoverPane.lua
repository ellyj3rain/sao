require "ISUI/ISPanel"
NMCoverPane = NMCoverPane or {}

local PANE_W = 300
local PANE_H = 300
local BORDER = 1
local RING = 1
local NO_COVER_TOKEN = "World_NM_NoCover"
local NO_COVER_ALPHA = 0.20
local DRAW_COVER_TEXTURE = true

local OUTER = { a = 1.0, r = 0.39, g = 0.39, b = 0.39 } -- #646364
local BLACK = { a = 1.0, r = 0.0, g = 0.0, b = 0.0 }

local function resolveCoverTexture(window)
    local resolved = nil
    if window and window.resolveContextCached then
        resolved = window:resolveContextCached()
    elseif window and window.resolveContext then
        resolved = window:resolveContext()
    end
    local state = resolved and resolved.state or nil
    local item = resolved and resolved.item or nil
    if not state then
        return nil, nil
    end

    local mediaFullType = tostring(state.mediaFullType or "")
    local texturePath, _ = nil, nil
    if mediaFullType ~= "" and NMCoverViewResolver and NMCoverViewResolver.resolvePath then
        texturePath = NMCoverViewResolver.resolvePath(mediaFullType, state)
    end
    if (not texturePath or tostring(texturePath) == "") and item and item.getFullType and NMCoverViewResolver and NMCoverViewResolver.resolvePath then
        texturePath = NMCoverViewResolver.resolvePath(item:getFullType(), state)
    end
    local path = tostring(texturePath or "")
    if path == "" then
        return nil, nil
    end
    return getTexture and getTexture(path) or nil, path
end

function NMCoverPane.buildRenderState(window, frame)
    local resolved = frame and frame.resolved or (window and window.resolveContextCached and window:resolveContextCached()) or nil
    local state = resolved and resolved.state or nil
    local item = resolved and resolved.item or nil
    local coverKey = table.concat({
        tostring(state and state.revision or ""),
        tostring(state and state.playbackEpoch or ""),
        tostring(state and state.mediaFullType or ""),
        tostring(item and item.getFullType and item:getFullType() or "")
    }, "|")
    local result = NMUIRenderCache.getFrameValue(window, "nm_cover_resolve", coverKey, function()
        local tex, path = resolveCoverTexture(window)
        return { tex = tex, path = path }
    end) or {}
    return {
        texture = result.tex,
        texturePath = result.path,
    }
end

function NMCoverPane.attach(window, x, y)
    local panel = ISPanel:new(x, y, PANE_W, PANE_H)
    panel:initialise()
    panel:instantiate()
    panel.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    panel.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    panel._nmTexturePath = nil
    panel._nmTexture = nil
    panel._nmWindow = window

    panel.render = function(self)
        local perfStart = NMUIRenderProbe and NMUIRenderProbe.beginWindow and NMUIRenderProbe.beginWindow(window) or nil
        local w = tonumber(self.width) or 0
        local h = tonumber(self.height) or 0
        if w <= 0 or h <= 0 then
            if NMUIRenderProbe and NMUIRenderProbe.endWindow then
                NMUIRenderProbe.endWindow(window, "widget.cover.render", perfStart)
            end
            return
        end
        self:drawRect(0, 0, w, h, OUTER.a, OUTER.r, OUTER.g, OUTER.b)
        self:drawRect(BORDER, BORDER, w - (BORDER * 2), h - (BORDER * 2), BLACK.a, BLACK.r, BLACK.g, BLACK.b)
        local innerX = BORDER + RING
        local innerY = BORDER + RING
        local innerW = w - ((BORDER + RING) * 2)
        local innerH = h - ((BORDER + RING) * 2)
        self:drawRect(innerX, innerY, innerW, innerH, BLACK.a, BLACK.r, BLACK.g, BLACK.b)

        local renderState = self._nmWindow and self._nmWindow.getRenderState and self._nmWindow:getRenderState("cover") or nil
        local tex = renderState and renderState.texture or nil
        local path = renderState and renderState.texturePath or nil
        if path ~= self._nmTexturePath then
            self._nmTexturePath = path
            self._nmTexture = tex
        elseif self._nmTexture == nil and tex ~= nil then
            self._nmTexture = tex
        end

        if DRAW_COVER_TEXTURE and self._nmTexture then
            local alpha = 1.0
            local activePath = tostring(self._nmTexturePath or "")
            if activePath ~= "" and string.find(activePath, NO_COVER_TOKEN, 1, true) then
                alpha = NO_COVER_ALPHA
            end
            self:drawTextureScaledAspect(self._nmTexture, innerX, innerY, innerW, innerH, alpha, 1.0, 1.0, 1.0)
        end
        if NMUIRenderProbe and NMUIRenderProbe.endWindow then
            NMUIRenderProbe.endWindow(window, "widget.cover.render", perfStart)
        end
    end

    window:addChild(panel)
    return panel
end

function NMCoverPane.getSize()
    return PANE_W, PANE_H
end
