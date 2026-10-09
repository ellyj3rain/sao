require "ui/shared/host/NMDeviceUiTime"

local NMFancyWindowChrome = {}

local function persistWindow(window, persistFn, immediate)
    if not persistFn or not window or not window.target then
        return
    end
    persistFn(window, immediate == true)
end

function NMFancyWindowChrome.beginHeaderPress(window)
    if not window then
        return false
    end
    if window.isAnimating == true and window.snapToState then
        window:snapToState(window.isCollapsed)
    end
    window.headerPressed = true
    window.headerPressStartedCollapsed = (window.isCollapsed == true)
    window.headerDragMode = nil
    window.draggingHeader = false
    window.headerPressX = getMouseX and getMouseX() or 0
    window.headerPressY = getMouseY and getMouseY() or 0
    window.dragStartWindowX = window.getX and window:getX() or 0
    window.dragStartWindowY = window.getY and window:getY() or 0
    window.interactionSuppressedToggle = false
    return true
end

function NMFancyWindowChrome.finishHeaderInteraction(window)
    if not window then
        return
    end
    window.headerPressed = false
    window.headerPressStartedCollapsed = nil
    window.headerDragMode = nil
    window.draggingHeader = false
    window.headerPressX = nil
    window.headerPressY = nil
    window.dragStartWindowX = nil
    window.dragStartWindowY = nil
    window.interactionSuppressedToggle = false
end

function NMFancyWindowChrome.snapToState(window, collapsed, persistFn)
    if not window then
        return
    end
    window.isCollapsed = (collapsed == true)
    window.isAnimating = false
    window.animStartY = nil
    window.animTargetY = nil
    window.animStartTime = nil
    window:setX(window:clampWindowX(window:getX()))
    window._nmExpandedY = window:getExpandedY()
    window:setY(window:getStateY(window.isCollapsed))
    persistWindow(window, persistFn, true)
end

function NMFancyWindowChrome.startCollapseAnimation(window, collapsed, persistFn)
    if not window then
        return
    end
    local targetY = window:getStateY(collapsed)
    local currentY = tonumber(window:getY()) or targetY
    if collapsed ~= true then
        window._nmExpandedY = window:getExpandedY()
        targetY = window:getExpandedY()
    end
    window.isCollapsed = (collapsed == true)
    persistWindow(window, persistFn, true)
    if currentY == targetY then
        window.isAnimating = false
        window:setY(targetY)
        return
    end
    window.isAnimating = true
    window.animStartY = currentY
    window.animTargetY = targetY
    window.animStartTime = NMDeviceUiTime.nowMs()
end

function NMFancyWindowChrome.toggleCollapsed(window, persistFn)
    if not window then
        return
    end
    NMFancyWindowChrome.startCollapseAnimation(window, not window.isCollapsed, persistFn)
end

function NMFancyWindowChrome.updateHeaderDrag(window, dragThreshold, persistFn)
    if not window or window.headerPressed ~= true then
        return false
    end

    local mouseX = getMouseX and getMouseX() or 0
    local mouseY = getMouseY and getMouseY() or 0
    local deltaX = mouseX - (tonumber(window.headerPressX) or mouseX)
    local deltaY = mouseY - (tonumber(window.headerPressY) or mouseY)
    local threshold = math.max(0, math.floor((tonumber(dragThreshold) or 0) + 0.5))

    if window.draggingHeader ~= true and (math.abs(deltaX) >= threshold or math.abs(deltaY) >= threshold) then
        local startedCollapsed = window.headerPressStartedCollapsed == true
        window.draggingHeader = true
        window.headerDragMode = startedCollapsed and "collapsed" or "expanded"
        window.interactionSuppressedToggle = true
        window.isAnimating = false
        if startedCollapsed then
            window:setY(window:getCollapsedY())
        else
            window.isCollapsed = false
            window._nmExpandedY = window:getExpandedY()
            window:setY(window:getExpandedY())
        end
    end

    if window.draggingHeader ~= true then
        return false
    end

    local dragStartX = tonumber(window.dragStartWindowX) or tonumber(window:getX()) or 0
    window:setX(window:clampWindowX(dragStartX + deltaX))
    if window.headerDragMode == "collapsed" then
        window:setY(window:getCollapsedY())
    else
        local dragStartY = tonumber(window.dragStartWindowY) or tonumber(window:getY()) or window:getExpandedY()
        window._nmExpandedY = window:clampWindowY(dragStartY + deltaY)
        window:setY(window._nmExpandedY)
    end
    persistWindow(window, persistFn, false)
    return true
end

function NMFancyWindowChrome.releaseHeaderInteraction(window, x, y)
    if not window then
        return false
    end
    local shouldToggle = window.headerPressed == true
        and window.draggingHeader ~= true
        and window.interactionSuppressedToggle ~= true
        and window.isHeaderHit
        and window:isHeaderHit(x, y)
    NMFancyWindowChrome.finishHeaderInteraction(window)
    if shouldToggle and window.toggleCollapsed then
        window:toggleCollapsed()
        return true
    end
    return false
end

function NMFancyWindowChrome.cancelHeaderInteraction(window)
    if not window then
        return false
    end
    local hadHeaderInteraction = window.headerPressed == true or window.draggingHeader == true
    NMFancyWindowChrome.finishHeaderInteraction(window)
    return hadHeaderInteraction
end

_G.NMFancyWindowChrome = NMFancyWindowChrome

return NMFancyWindowChrome
