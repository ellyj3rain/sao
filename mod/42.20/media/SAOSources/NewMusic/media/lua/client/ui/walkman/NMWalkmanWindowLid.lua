local env = _G.NMWalkmanWindowEnv
setfenv(1, env)

function WalkmanWindow:getTimedCassetteAnimationState()
    local timed = self._nmMediaSlotTimedProgress
    local actionName = timed and tostring(timed.action or "") or ""
    local isInsert = actionName == "insert_media"
    local isEject = actionName == "eject_media"
    if not (timed and timed.active == true and (isInsert == true or isEject == true)) then
        return {
            visible = false,
            action = "",
            fullType = "",
            texture = nil,
            texturePath = nil,
            x = CASSETTE_DISPLAY_X,
            y = CASSETTE_DISPLAY_Y,
            w = CASSETTE_DISPLAY_W,
            h = CASSETTE_DISPLAY_H,
            alpha = 0.0,
            progress = 0.0,
        }
    end

    local fullType = tostring(self._nmPendingMediaSlotFullType or "")
    if fullType == "" then
        return {
            visible = false,
            action = actionName,
            fullType = "",
            texture = nil,
            texturePath = nil,
            x = CASSETTE_DISPLAY_X,
            y = CASSETTE_DISPLAY_Y,
            w = CASSETTE_DISPLAY_W,
            h = CASSETTE_DISPLAY_H,
            alpha = 0.0,
            progress = 0.0,
        }
    end

    local texture, texturePath = nil, nil
    if NMMediaWorldTextureResolver and NMMediaWorldTextureResolver.resolveTexture then
        texture, texturePath = NMMediaWorldTextureResolver.resolveTexture(fullType)
    end
    if not texture then
        return {
            visible = false,
            action = actionName,
            fullType = fullType,
            texture = nil,
            texturePath = texturePath,
            x = CASSETTE_DISPLAY_X,
            y = CASSETTE_DISPLAY_Y,
            w = CASSETTE_DISPLAY_W,
            h = CASSETTE_DISPLAY_H,
            alpha = 0.0,
            progress = 0.0,
        }
    end

    local finalRect = self:getCassetteDisplayRect()
    local progress = clamp01(tonumber(timed.delta) or 0.0)
    local startY = finalRect.y
    local endY = finalRect.y
    local alpha = 1.0
    if isInsert == true then
        startY = finalRect.y - 200
        endY = finalRect.y
        alpha = progress
    else
        startY = finalRect.y
        endY = finalRect.y - 200
        alpha = 1.0 - progress
    end
    local currentY = startY + ((endY - startY) * progress)
    return {
        visible = true,
        action = actionName,
        fullType = fullType,
        texture = texture,
        texturePath = texturePath,
        x = finalRect.x,
        y = math.floor(currentY + 0.5),
        w = finalRect.w,
        h = finalRect.h,
        alpha = alpha,
        progress = progress,
    }
end

function WalkmanWindow:getCassetteLabelRect()
    return {
        x = CASSETTE_LABEL_X,
        y = CASSETTE_LABEL_Y,
        w = CASSETTE_LABEL_W,
        h = CASSETTE_LABEL_H
    }
end

function WalkmanWindow:getCassetteLabelRectForVariant(variant)
    local rect = self:getCassetteLabelRect()
    if tostring(variant or "") == "Lore" then
        rect.y = rect.y + (tonumber(CASSETTE_LABEL_LORE_OFFSET_Y) or 0)
    end
    return rect
end

function WalkmanWindow:getCassetteSpoolRect(index)
    local spoolIndex = math.floor(tonumber(index) or 1)
    local x = spoolIndex == 2 and CASSETTE_SPOOL_B_X or CASSETTE_SPOOL_A_X
    local y = spoolIndex == 2 and CASSETTE_SPOOL_B_Y or CASSETTE_SPOOL_A_Y
    return {
        x = x,
        y = y,
        w = CASSETTE_SPOOL_W,
        h = CASSETTE_SPOOL_H
    }
end

function WalkmanWindow:getLidRect()
    return {
        x = LID_X,
        y = LID_Y,
        w = LID_W,
        h = LID_H
    }
end

function WalkmanWindow:getLidStateRect(open)
    if open == true then
        return {
            x = LID_X,
            y = LID_OPEN_Y,
            w = LID_W,
            h = LID_OPEN_H
        }
    end
    return self:getLidRect()
end

function WalkmanWindow:isLidTargetOpen()
    return self:hasInsertedCassette() ~= true and self.isLidManuallyOpen == true
end

function WalkmanWindow:startLidAnimation(open)
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
        playWalkmanLidSound(self, open == true)
    end
    self.isLidAnimating = true
    self.lidAnimStartY = currentY
    self.lidAnimStartH = currentH
    self.lidAnimTargetY = targetRect.y
    self.lidAnimTargetH = targetRect.h
    self.lidAnimStartTime = getNowMs()
end

function WalkmanWindow:syncLidFromMedia(snap)
    local timed = self._nmMediaSlotTimedProgress
    local timedAction = timed and timed.active == true and tostring(timed.action or "") or ""
    local insertActive = timedAction == "insert_media"
    local ejectActive = timedAction == "eject_media"
    local hasMedia = self:hasInsertedCassette()
    local hadMedia = self._nmLidHadMedia == true
    local removeInFlight = self._nmSlotRemoveInFlightByType or nil
    local ejectQueued = hasMedia == true and removeInFlight and removeInFlight.media == true
    local ejectOpenOverride = (ejectActive == true) or (ejectQueued == true)
    local ejectInterrupted = self._nmMediaEjectInterrupted == true
    if hasMedia == true then
        self.isLidManuallyOpen = false
    elseif hadMedia == true then
        self.isLidManuallyOpen = true
    elseif self.isLidManuallyOpen == nil then
        self.isLidManuallyOpen = true
    end
    local shouldBeOpen = (insertActive == true) or (ejectOpenOverride == true) or (hasMedia ~= true and self.isLidManuallyOpen == true)
    local effectiveSnap = snap == true or (ejectInterrupted == true and hasMedia == true)
    self._nmLidHadMedia = (hasMedia == true)
    if effectiveSnap == true then
        self._nmMediaEjectInterrupted = nil
        local rect = self:getLidStateRect(shouldBeOpen)
        self.isLidOpen = shouldBeOpen
        self.isLidAnimating = false
        self.lidAnimStartY = nil
        self.lidAnimStartH = nil
        self.lidAnimTargetY = nil
        self.lidAnimTargetH = nil
        self.lidAnimStartTime = nil
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

function WalkmanWindow:getLidRenderState(textures)
    local currentY = tonumber(self.lidCurrentY) or (self.isLidOpen == true and LID_OPEN_Y or LID_Y)
    local currentH = tonumber(self.lidCurrentH) or (self.isLidOpen == true and LID_OPEN_H or LID_H)
    local walkmanTextures = textures or self:resolveWalkmanUITextures()
    return {
        texture = walkmanTextures and walkmanTextures.lid or nil,
        x = LID_X,
        y = currentY,
        w = LID_W,
        h = currentH,
        isOpen = self.isLidOpen == true
    }
end

function WalkmanWindow:getLidArrowRect()
    local lidState = self:getLidRenderState()
    return {
        x = lidState.x,
        y = lidState.y + LID_ARROW_Y_OFFSET,
        w = LID_ARROW_W,
        h = LID_ARROW_H
    }
end

function WalkmanWindow:getLidIngressZoneRect()
    local lidState = self:getLidRenderState()
    return {
        x = lidState.x + 2,
        y = lidState.y - LID_INGRESS_H,
        w = LID_INGRESS_W,
        h = LID_INGRESS_H
    }
end

function WalkmanWindow:isCompatibleLidMediaDrag()
    local dragItems, dragOk = resolveDraggedInventoryItemsSnapshot()
    return dragOk == true and isCompatibleWalkmanMediaDrag(self, dragItems)
end

function WalkmanWindow:canAcceptDraggedMediaViaLid()
    if self.isAwaitingAuthoritativeMediaEject and self:isAwaitingAuthoritativeMediaEject() == true then
        return false
    end
    if self:isLidTargetOpen() ~= true then
        return false
    end
    local dragItems, dragOk = resolveDraggedInventoryItemsSnapshot()
    if dragOk ~= true or not isCompatibleWalkmanMediaDrag(self, dragItems) then
        return false
    end
    return true
end

function WalkmanWindow:shouldShowLidIngressZone()
    if self:canAcceptDraggedMediaViaLid() ~= true then
        return false
    end
    local ax = self.getAbsoluteX and self:getAbsoluteX() or 0
    local ay = self.getAbsoluteY and self:getAbsoluteY() or 0
    local mx = (getMouseX and getMouseX() or 0) - ax
    local my = (getMouseY and getMouseY() or 0) - ay
    return pointInRect(mx, my, self:getLidIngressZoneRect())
end

function WalkmanWindow:insertDraggedMediaViaLid()
    if self.isAwaitingAuthoritativeMediaEject and self:isAwaitingAuthoritativeMediaEject() == true then
        return false
    end
    local interaction = rawget(_G, "NMPortableMediaInteraction") or nil
    if interaction and interaction.handleMediaSlotMouseUp then
        return interaction.handleMediaSlotMouseUp(self, "aux") == true
    end
    return false
end

function WalkmanWindow:ejectMediaViaLid()
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
    local okDispatch = queueWalkmanMediaAction(self, "eject_media", {})
    if okDispatch ~= true then
        self._nmPendingMediaSlotFullType = nil
        self._nmSlotRemoveInFlightByType.media = nil
        return false
    end
    self:syncLidFromMedia(false)
    return true
end

function WalkmanWindow:getLidEdgeRenderState(lidState)
    local state = lidState or self:getLidRenderState()
    local openRatio = clamp01((LID_H - (tonumber(state.h) or LID_H)) / LID_OPEN_SHRINK_H)
    local edgeH = math.floor((LID_EDGE_H * openRatio) + 0.5)
    if edgeH <= 0 then
        return {
            texture = UI_TEXTURES.lidEdge,
            x = state.x,
            y = state.y,
            w = LID_EDGE_W,
            h = 0,
            visible = false
        }
    end
    return {
        texture = UI_TEXTURES.lidEdge,
        x = state.x,
        y = state.y - edgeH,
        w = LID_EDGE_W,
        h = edgeH,
        visible = true
    }
end
