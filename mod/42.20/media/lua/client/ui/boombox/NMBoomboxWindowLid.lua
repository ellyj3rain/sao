-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
local env = _G.NMBoomboxWindowEnv
setfenv(1, env)

function BoomboxWindow:getLidRect()
    return { x = LID_X, y = LID_Y, w = LID_W, h = LID_H }
end

function BoomboxWindow:getLidStateRect(open)
    if open == true then
        return { x = LID_X, y = LID_OPEN_Y, w = LID_W, h = LID_OPEN_H }
    end
    return self:getLidRect()
end

function BoomboxWindow:getLidArrowRect()
    local lidState = self:getLidRenderState()
    return { x = lidState.x, y = lidState.y, w = LID_ARROW_W, h = LID_ARROW_H }
end

function BoomboxWindow:getLidIngressZoneRect()
    return { x = LID_INGRESS_X, y = LID_INGRESS_Y, w = LID_INGRESS_W, h = LID_INGRESS_H }
end

function BoomboxWindow:isLidTargetOpen()
    return self:hasInsertedCassette() ~= true and self.isLidManuallyOpen == true
end

function BoomboxWindow:startLidAnimation(open)
    local targetRect = self:getLidStateRect(open)
    local currentY = tonumber(self.lidCurrentY) or (self.isLidOpen == true and LID_OPEN_Y or LID_Y)
    local currentH = tonumber(self.lidCurrentH) or (self.isLidOpen == true and LID_OPEN_H or LID_H)
    self.isLidOpen = (open == true)
    if currentY == targetRect.y and currentH == targetRect.h then
        self.isLidAnimating = false
        self.lidCurrentY = targetRect.y
        self.lidCurrentH = targetRect.h
        return
    end
    if open ~= true and self._nmSuppressNextLidCloseSound == true then
        self._nmSuppressNextLidCloseSound = nil
    else
        playBoomboxSoundEvent(self, open == true and "lid_open" or "lid_close")
    end
    self.isLidAnimating = true
    self.lidAnimStartY = currentY
    self.lidAnimStartH = currentH
    self.lidAnimTargetY = targetRect.y
    self.lidAnimTargetH = targetRect.h
    self.lidAnimStartTime = getNowMs()
end

function BoomboxWindow:syncLidFromMedia(snap)
    local timed = self._nmMediaSlotTimedProgress
    local timedAction = timed and timed.active == true and tostring(timed.action or "") or ""
    local insertActive = timedAction == "insert_media"
    local ejectActive = timedAction == "eject_media"
    local hasMedia = self:hasInsertedCassette()
    local hadMedia = self._nmLidHadMedia == true
    local removeInFlight = self._nmSlotRemoveInFlightByType or nil
    local ejectQueued = hasMedia == true and removeInFlight and removeInFlight.media == true
    if hasMedia == true then
        self.isLidManuallyOpen = false
    elseif hadMedia == true then
        self.isLidManuallyOpen = true
    elseif self.isLidManuallyOpen == nil then
        self.isLidManuallyOpen = true
    end
    local shouldBeOpen = insertActive == true or ejectActive == true or ejectQueued == true or (hasMedia ~= true and self.isLidManuallyOpen == true)
    self._nmLidHadMedia = (hasMedia == true)
    if snap == true then
        local rect = self:getLidStateRect(shouldBeOpen)
        self.isLidOpen = shouldBeOpen
        self.isLidAnimating = false
        self.lidCurrentY = rect.y
        self.lidCurrentH = rect.h
        return
    end
    if self.isLidOpen ~= shouldBeOpen then
        self:startLidAnimation(shouldBeOpen)
    elseif self.isLidAnimating ~= true then
        local rect = self:getLidStateRect(shouldBeOpen)
        self.lidCurrentY = rect.y
        self.lidCurrentH = rect.h
    end
end

function BoomboxWindow:getLidRenderState(textures)
    local currentY = tonumber(self.lidCurrentY) or (self.isLidOpen == true and LID_OPEN_Y or LID_Y)
    local currentH = tonumber(self.lidCurrentH) or (self.isLidOpen == true and LID_OPEN_H or LID_H)
    local chrome = textures or self:resolveBoomboxUITextures()
    return { texture = chrome and chrome.lid or nil, x = LID_X, y = currentY, w = LID_W, h = currentH, isOpen = self.isLidOpen == true }
end

function BoomboxWindow:getLidEdgeRenderState(lidState)
    local state = lidState or self:getLidRenderState()
    local openRatio = clamp01((LID_H - (tonumber(state.h) or LID_H)) / math.max(1, LID_H - LID_OPEN_H))
    local edgeH = math.floor((LID_EDGE_H * openRatio) + 0.5)
    return {
        texture = self:resolveBoomboxUITextures().lidEdge,
        x = state.x,
        y = state.y - edgeH,
        w = LID_EDGE_W,
        h = edgeH,
        visible = edgeH > 0
    }
end

function BoomboxWindow:canAcceptDraggedMediaViaLid()
    if self:isLidTargetOpen() ~= true then
        return false
    end
    local dragItems, dragOk = resolveDraggedInventoryItemsSnapshot()
    return dragOk == true and isCompatibleBoomboxMediaDrag(self, dragItems)
end

function BoomboxWindow:shouldShowLidIngressZone()
    if self:canAcceptDraggedMediaViaLid() ~= true then
        return false
    end
    local ax = self.getAbsoluteX and self:getAbsoluteX() or 0
    local ay = self.getAbsoluteY and self:getAbsoluteY() or 0
    local mx = (getMouseX and getMouseX() or 0) - ax
    local my = (getMouseY and getMouseY() or 0) - ay
    return pointInRect(mx, my, self:getLidIngressZoneRect())
end

function BoomboxWindow:insertDraggedMediaViaLid()
    local interaction = rawget(_G, "NMPortableMediaInteraction") or nil
    if interaction and interaction.handleMediaSlotMouseUp then
        return interaction.handleMediaSlotMouseUp(self, "aux") == true
    end
    return false
end

function BoomboxWindow:ejectMediaViaControl()
    self._nmSlotRemoveInFlightByType = self._nmSlotRemoveInFlightByType or {}
    if self._nmSlotRemoveInFlightByType.media then
        return false
    end
    local cassetteMediaState = self:getCassetteDisplayMediaState()
    local fullType = tostring(cassetteMediaState and cassetteMediaState.fullType or "")
    if fullType == "" then
        return false
    end
    self._nmSlotRemoveInFlightByType.media = true
    self._nmPendingMediaSlotFullType = fullType
    self.isLidManuallyOpen = true
    local okDispatch = queueBoomboxMediaAction(self, "eject_media", {})
    if okDispatch ~= true then
        self._nmPendingMediaSlotFullType = nil
        self._nmSlotRemoveInFlightByType.media = nil
        return false
    end
    self:syncLidFromMedia(false)
    return true
end

function BoomboxWindow:ejectMediaViaLid()
    return self:ejectMediaViaControl()
end

function BoomboxWindow:ejectOpenLidMediaViaAux()
    return self:ejectMediaViaControl()
end
