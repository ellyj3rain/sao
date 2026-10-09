require "ISUI/ISPanel"

if isServer() then
    return nil
end

NMSlotGhostOverlay = NMSlotGhostOverlay or ISPanel:derive("NMSlotGhostOverlay")

function NMSlotGhostOverlay:new()
    local sw = getCore() and getCore():getScreenWidth() or 1920
    local sh = getCore() and getCore():getScreenHeight() or 1080
    local o = ISPanel.new(self, 0, 0, sw, sh)
    o:setWantKeyEvents(false)
    o:setCapture(false)
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    o.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    return o
end

function NMSlotGhostOverlay:onMouseDown(x, y) return false end
function NMSlotGhostOverlay:onMouseUp(x, y) return false end
function NMSlotGhostOverlay:onMouseMove(dx, dy) return false end
function NMSlotGhostOverlay:onMouseMoveOutside(dx, dy) return false end
function NMSlotGhostOverlay:onMouseUpOutside(x, y) return false end
function NMSlotGhostOverlay:onMouseWheel(del) return false end

function NMSlotGhostOverlay:prerender()
    local core = getCore and getCore() or nil
    if core then
        local sw = core:getScreenWidth()
        local sh = core:getScreenHeight()
        if self.width ~= sw then self:setWidth(sw) end
        if self.height ~= sh then self:setHeight(sh) end
    end
    if NMSlotHostLifecycle and NMSlotHostLifecycle.finishActiveDragAfterMouseRelease then
        NMSlotHostLifecycle.finishActiveDragAfterMouseRelease()
    end
end

function NMSlotGhostOverlay:render()
    local d = nil
    if NMSlotGhostManager and NMSlotGhostManager.getActiveDrag then
        _, d = NMSlotGhostManager.getActiveDrag()
    end
    if not (d and d.moved and d.iconTex) then return end
    local mx = getMouseX and getMouseX() or 0
    local my = getMouseY and getMouseY() or 0
    local size = 32
    local x = mx - 22
    local y = my - 22
    local tint = d.iconTint or { r = 1.0, g = 1.0, b = 1.0 }
    self:drawTextureScaledAspect(d.iconTex, x, y, size, size, 0.78, tint.r or 1.0, tint.g or 1.0, tint.b or 1.0)
end

return NMSlotGhostOverlay
