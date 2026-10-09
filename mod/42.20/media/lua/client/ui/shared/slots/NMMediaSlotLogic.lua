-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
local env = _G.NMMediaSlotEnv
setfenv(1, env)

require "ui/shared/slots/NMDeviceUiSlotContract"
require "ui/shared/slots/NMSlotPlaceholderRender"

local AUTHORITATIVE_INSERT_TIMEOUT_MS = 750
local AUTHORITATIVE_EJECT_TIMEOUT_MS = 1000

local function logPortableUiProbe(tag, detail)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("portable_ui")) then
        return
    end
    NMCore.logChannel("portable_ui", tostring(tag or "portable_ui"), tostring(detail or ""))
end

local function resolveWindowContext(window)
    if not window then
        return nil
    end
    if window.resolveContextCached then
        return window:resolveContextCached()
    end
    return window.resolveContext and window:resolveContext() or nil
end

local function resolveDraggedItems(window, frame)
    if frame and frame.dragOk == true and type(frame.dragItems) == "table" then
        return frame.dragItems, true
    end
    if NMSlotHostLifecycle and NMSlotHostLifecycle.resolveDraggedItemsSnapshot then
        return NMSlotHostLifecycle.resolveDraggedItemsSnapshot(window)
    end
    return getDraggedInventoryItems()
end

local function resolveWindowFamily(window)
    if window and window.target and tostring(window.target.kind or "") == "vehicle" then
        return "vehicle"
    end
    if window and window.getFrontVariant then
        return "cdplayer"
    end
    if window and window.getBoomboxVariant then
        return "boombox"
    end
    if window and window.getLidRect and window.syncLidFromMedia then
        return "walkman"
    end
    return "generic"
end

local function resolveNowMs(window)
    local nowMs = window and tonumber(window._nmFrameNowMs) or nil
    if nowMs ~= nil and nowMs > 0 then
        return nowMs
    end
    if getTimestampMs then
        nowMs = tonumber(getTimestampMs())
        if nowMs ~= nil then
            return nowMs
        end
    end
    if getTimeInMillis then
        nowMs = tonumber(getTimeInMillis())
        if nowMs ~= nil then
            return nowMs
        end
    end
    return 0
end

function resolveDeviceCarrier(window, resolved)
    local ctx = resolved or resolveWindowContext(window)
    local profile = ctx and ctx.profile or nil
    return tostring(profile and profile.supportedCarrier or "")
end
function queueMediaSlotAction(window, actionName, args)
    if not window then return false end
    if window._nmSlotRangeGateEnabled ~= false and not canQueueSlotAction(window) then
        return false
    end
    if actionName == "insert_media"
        and window.isAwaitingAuthoritativeMediaEject
        and window:isAwaitingAuthoritativeMediaEject() == true then
        return false
    end
    if actionName == "eject_media"
        and window.clearAwaitingAuthoritativeMediaInsert then
        window:clearAwaitingAuthoritativeMediaInsert()
    end
    local payload = args or {}
    if payload.slotTraceId == nil then
        payload.slotTraceId = nextSlotTraceId()
    end
    local resolved = resolveWindowContext(window)
    local playerObj = resolved and resolved.player or nil
    if not (playerObj and ISTimedActionQueue and NMMediaSlotTimedAction) then
        return window:dispatchSlotAction(actionName, payload)
    end
    ISTimedActionQueue.add(NMMediaSlotTimedAction:new(playerObj, window, actionName, payload))
    return true
end

function getContextMenuPoint(button, x, y)
    local bx = button and button.getAbsoluteX and button:getAbsoluteX() or (getMouseX and getMouseX() or 0)
    local by = button and button.getAbsoluteY and button:getAbsoluteY() or (getMouseY and getMouseY() or 0)
    return bx + (tonumber(x) or 0), by + (tonumber(y) or 0)
end

function isMouseOverButton(button)
    if not button then return false end
    local mx = getMouseX and getMouseX() or 0
    local my = getMouseY and getMouseY() or 0
    local ax = button.getAbsoluteX and button:getAbsoluteX() or 0
    local ay = button.getAbsoluteY and button:getAbsoluteY() or 0
    local bw = tonumber(button.width) or 0
    local bh = tonumber(button.height) or 0
    if bw <= 0 or bh <= 0 then return false end
    return mx >= ax and mx < (ax + bw) and my >= ay and my < (ay + bh)
end

function resolveTextureByFullType(fullType)
    local ft = tostring(fullType or "")
    if ft == "" or not getTexture then
        return nil
    end
    local scriptItem = ScriptManager and ScriptManager.instance and ScriptManager.instance.FindItem
        and ScriptManager.instance:FindItem(ft) or nil
    if scriptItem and scriptItem.getIcon then
        local iconName = tostring(scriptItem:getIcon() or "")
        if iconName ~= "" then
            local tex = getTexture("Item_" .. iconName) or getTexture("media/textures/Item_" .. iconName .. ".png")
            if tex then return tex end
        end
    end
    local mediaType = ft
    local dotPos = string.find(mediaType, "%.")
    if dotPos then
        mediaType = string.sub(mediaType, dotPos + 1)
    end
    return getTexture("Item_" .. mediaType)
        or getTexture("media/textures/Item_" .. mediaType .. ".png")
end

function resolveItemTextureForMedia(item)
    if not item then return nil end
    local fullType = item.getFullType and item:getFullType() or nil
    if not fullType then return nil end
    local key = tostring(fullType)
    if MEDIA_TEXTURE_CACHE[key] == nil then
        MEDIA_TEXTURE_CACHE[key] = resolveTextureByFullType(fullType) or false
    end
    local tex = MEDIA_TEXTURE_CACHE[key]
    return tex ~= false and tex or nil
end

function resolveMediaSlotFullType(window, state)
    local authoritative = tostring((state and (state.mediaEjectFullType or state.mediaFullType)) or "")
    local awaitingAuthoritativeInsert = window and window.isAwaitingAuthoritativeMediaInsert
        and window:isAwaitingAuthoritativeMediaInsert() == true
        or false
    if awaitingAuthoritativeInsert == true then
        local awaitingInsertFullType = tostring(window._nmAwaitingAuthoritativeMediaInsert and window._nmAwaitingAuthoritativeMediaInsert.fullType or "")
        local awaitingStartedAtMs = tonumber(window._nmAwaitingAuthoritativeMediaInsert and window._nmAwaitingAuthoritativeMediaInsert.startedAtMs) or 0
        local nowMs = resolveNowMs(window)
        if authoritative == awaitingInsertFullType and awaitingInsertFullType ~= "" then
            if window.clearAwaitingAuthoritativeMediaInsert then
                window:clearAwaitingAuthoritativeMediaInsert()
            else
                window._nmAwaitingAuthoritativeMediaInsert = nil
            end
            authoritative = awaitingInsertFullType
            awaitingAuthoritativeInsert = false
        elseif awaitingInsertFullType ~= "" and authoritative == "" and awaitingStartedAtMs > 0 and nowMs > 0 and (nowMs - awaitingStartedAtMs) >= AUTHORITATIVE_INSERT_TIMEOUT_MS then
            logPortableUiProbe(
                "slot_insert_authority_timeout",
                string.format(
                    "ui=%s targetItemId=%s targetUuid=%s awaiting=%s elapsedMs=%s",
                    tostring(resolveWindowFamily(window)),
                    tostring(window and window.target and window.target.itemId or ""),
                    tostring(window and window.target and window.target.uuid or ""),
                    tostring(awaitingInsertFullType),
                    tostring(nowMs - awaitingStartedAtMs)
                )
            )
            if window.clearAwaitingAuthoritativeMediaInsert then
                window:clearAwaitingAuthoritativeMediaInsert()
            else
                window._nmAwaitingAuthoritativeMediaInsert = nil
            end
            if tostring(window and window._nmPendingMediaSlotFullType or "") == awaitingInsertFullType then
                window._nmPendingMediaSlotFullType = nil
            end
            awaitingAuthoritativeInsert = false
        elseif awaitingInsertFullType ~= "" and authoritative == "" then
            return awaitingInsertFullType
        else
            if window.clearAwaitingAuthoritativeMediaInsert then
                window:clearAwaitingAuthoritativeMediaInsert()
            else
                window._nmAwaitingAuthoritativeMediaInsert = nil
            end
            awaitingAuthoritativeInsert = false
        end
    end
    local awaitingAuthoritativeEject = window and window.isAwaitingAuthoritativeMediaEject
        and window:isAwaitingAuthoritativeMediaEject() == true
        or false
    if awaitingAuthoritativeEject == true then
        local awaitingFullType = tostring(window._nmAwaitingAuthoritativeMediaEject and window._nmAwaitingAuthoritativeMediaEject.fullType or "")
        local awaitingStartedAtMs = tonumber(window._nmAwaitingAuthoritativeMediaEject and window._nmAwaitingAuthoritativeMediaEject.startedAtMs) or 0
        local nowMs = resolveNowMs(window)
        if authoritative == "" or (awaitingFullType ~= "" and authoritative ~= awaitingFullType) then
            logPortableUiProbe(
                "slot_eject_authority_settle",
                string.format(
                    "ui=%s targetItemId=%s targetUuid=%s awaiting=%s reason=state_apply authoritative=%s",
                    tostring(resolveWindowFamily(window)),
                    tostring(window and window.target and window.target.itemId or ""),
                    tostring(window and window.target and window.target.uuid or ""),
                    tostring(awaitingFullType),
                    tostring(authoritative)
                )
            )
            if window.clearAwaitingAuthoritativeMediaEject then
                window:clearAwaitingAuthoritativeMediaEject()
            else
                window._nmAwaitingAuthoritativeMediaEject = nil
            end
            awaitingAuthoritativeEject = false
        elseif awaitingFullType ~= "" and authoritative == awaitingFullType then
            if awaitingStartedAtMs > 0 and nowMs > 0 and (nowMs - awaitingStartedAtMs) >= AUTHORITATIVE_EJECT_TIMEOUT_MS then
                logPortableUiProbe(
                    "slot_eject_authority_timeout",
                    string.format(
                        "ui=%s targetItemId=%s targetUuid=%s awaiting=%s elapsedMs=%s",
                        tostring(resolveWindowFamily(window)),
                        tostring(window and window.target and window.target.itemId or ""),
                        tostring(window and window.target and window.target.uuid or ""),
                        tostring(awaitingFullType),
                        tostring(nowMs - awaitingStartedAtMs)
                    )
                )
                logPortableUiProbe(
                    "slot_eject_authority_settle",
                    string.format(
                        "ui=%s targetItemId=%s targetUuid=%s awaiting=%s reason=timeout authoritative=%s elapsedMs=%s",
                        tostring(resolveWindowFamily(window)),
                        tostring(window and window.target and window.target.itemId or ""),
                        tostring(window and window.target and window.target.uuid or ""),
                        tostring(awaitingFullType),
                        tostring(authoritative),
                        tostring(nowMs - awaitingStartedAtMs)
                    )
                )
                if window.clearAwaitingAuthoritativeMediaEject then
                    window:clearAwaitingAuthoritativeMediaEject()
                else
                    window._nmAwaitingAuthoritativeMediaEject = nil
                end
                if window._nmSlotRemoveInFlightByType then
                    window._nmSlotRemoveInFlightByType.media = nil
                end
                if tostring(window and window._nmPendingMediaSlotFullType or "") == awaitingFullType then
                    window._nmPendingMediaSlotFullType = nil
                end
                awaitingAuthoritativeEject = false
            else
            return ""
            end
        end
    end
    local pending = window and window._nmPendingMediaSlotFullType or nil
    local timed = window and window._nmMediaSlotTimedProgress or nil
    local timedAction = timed and tostring(timed.action or "") or ""
    local timedActive = timed and timed.active == true and (timedAction == "insert_media" or timedAction == "eject_media")
    if timedActive and timedAction == "eject_media" and tostring(pending or "") ~= "" then
        return tostring(pending or "")
    end
    if timedActive ~= true and pending ~= nil and tostring(pending or "") == authoritative then
        window._nmPendingMediaSlotFullType = nil
        if window._nmSlotRemoveInFlightByType then
            window._nmSlotRemoveInFlightByType.media = nil
        end
    end
    return authoritative
end

function isCompatibleMediaItem(window, item)
    if not (window and item and item.getFullType) then return false end
    if not (NMMediaHelpers and NMMediaHelpers.isInsertableMediaItem and NMMediaHelpers.isInsertableMediaItem(item) == true) then
        return false
    end
    local requiredCarrier = resolveDeviceCarrier(window)
    if requiredCarrier == "" then return false end
    local fullType = item:getFullType()
    if requiredCarrier == ((NMMediaContract and NMMediaContract.CD_CARRIER) or "nm_carrier_cd")
        and tostring(fullType or "") == "Base.Disc_Retail" then
        return false
    end
    local typeName = item.getType and item:getType() or nil
    local resolvedCarrier = NMMediaContract and NMMediaContract.resolveMediaCarrier and NMMediaContract.resolveMediaCarrier(fullType or typeName) or nil
    return tostring(resolvedCarrier or "") == requiredCarrier
end

function isCompatibleMediaDrag(window, items)
    if type(items) ~= "table" or #items <= 0 then return false end
    for i = 1, #items do
        if isCompatibleMediaItem(window, items[i]) then
            return true
        end
    end
    return false
end

function pickFirstCompatibleMedia(window, items)
    if type(items) ~= "table" then return nil end
    for i = 1, #items do
        if isCompatibleMediaItem(window, items[i]) then
            return items[i]
        end
    end
    return nil
end

function normalizeMediaIngressItem(window, item)
    local resolved = resolveWindowContext(window)
    local player = resolved and resolved.player or nil
    local itemId = item and NMCore and NMCore.itemId and NMCore.itemId(item) or nil
    local uuid = item and NMInventoryHelpers and NMInventoryHelpers.getItemStateUuid and NMInventoryHelpers.getItemStateUuid(item) or nil
    if not (player and itemId and NMInventoryHelpers) then
        return nil, "normalize_helper_missing"
    end
    if NMCore and NMCore.isMPClientRuntime and NMCore.isMPClientRuntime() and NMInventoryHelpers.findAccessibleItemByIdOrUuid then
        return NMInventoryHelpers.findAccessibleItemByIdOrUuid(player, itemId, uuid, item)
    end
    if not NMInventoryHelpers.normalizeItemToMainInventory then
        return nil, "normalize_helper_missing"
    end
    return NMInventoryHelpers.normalizeItemToMainInventory(player, itemId, uuid, item)
end

function collectEligibleMediaItems(window)
    local resolved = resolveWindowContext(window)
    local player = resolved and resolved.player or nil
    if not (player and NMInventoryHelpers and NMInventoryHelpers.collectVisibleUiSourceInventories) then
        return {}
    end
    local inventories = NMInventoryHelpers.collectVisibleUiSourceInventories(player)
    local out, seen = {}, {}
    for inventoryIndex = 1, #inventories do
        local inventory = inventories[inventoryIndex]
        local all = {}
        NMInventoryHelpers.collectItemsRecursive(inventory, all)
        for i = 1, #all do
            local item = all[i]
            local key = nil
            if item and item.getID then
                key = "id:" .. tostring(item:getID() or "")
            end
            if not key or key == "id:" then
                local ft = item and item.getFullType and tostring(item:getFullType() or "") or "?"
                local dn = item and item.getDisplayName and tostring(item:getDisplayName() or "") or "?"
                key = "fallback:" .. ft .. "|" .. dn
            end
            if isCompatibleMediaItem(window, item) and not seen[key] then
                seen[key] = true
                out[#out + 1] = item
            end
        end
    end
    return out
end

function resolveEmptyMediaTexture(iconKey)
    local key = tostring(iconKey or "")
    if key == "" then return nil end
    local scaleKey = NMFancyDeviceUiScale and NMFancyDeviceUiScale.getTextureScaleKey and NMFancyDeviceUiScale.getTextureScaleKey() or "1x"
    local cacheKey = key .. "|" .. scaleKey
    if EMPTY_MEDIA_PLACEHOLDER_TEXTURES[cacheKey] == nil then
        local tex = nil
        local getFancyTexture = NMFancyDeviceUiScale and NMFancyDeviceUiScale.getTexture or nil
        if key == "cd_placeholder" then
            tex = getFancyTexture and getFancyTexture("media/textures/UI/UI_NM_SlotEmpty_CD.png") or getTexture and (
                getTexture("media/textures/UI/UI_NM_SlotEmpty_CD.png")
                or getTexture("UI/UI_NM_SlotEmpty_CD")
                or getTexture("UI_NM_SlotEmpty_CD")
            ) or nil
        elseif key == "vinyl_placeholder" then
            tex = getFancyTexture and getFancyTexture("media/textures/UI/UI_NM_SlotEmpty_Vinyl.png") or getTexture and (
                getTexture("media/textures/UI/UI_NM_SlotEmpty_Vinyl.png")
                or getTexture("UI/UI_NM_SlotEmpty_Vinyl")
                or getTexture("UI_NM_SlotEmpty_Vinyl")
            ) or nil
        else
            tex = getFancyTexture and getFancyTexture("media/textures/UI/UI_NM_SlotEmpty_Cassette.png") or getTexture and (
                getTexture("media/textures/UI/UI_NM_SlotEmpty_Cassette.png")
                or getTexture("UI/UI_NM_SlotEmpty_Cassette")
                or getTexture("UI_NM_SlotEmpty_Cassette")
            ) or nil
        end
        EMPTY_MEDIA_PLACEHOLDER_TEXTURES[cacheKey] = tex or false
    end
    local cached = EMPTY_MEDIA_PLACEHOLDER_TEXTURES[cacheKey]
    return cached ~= false and cached or nil
end

function drawEmptyMediaTexture(button, iconKey)
    local tex = resolveEmptyMediaTexture(iconKey)
    return NMSlotPlaceholderRender and NMSlotPlaceholderRender.drawTexture and NMSlotPlaceholderRender.drawTexture(button, tex) or false
end

function drawMediaTexture(button, fullType)
    local key = tostring(fullType or "")
    if key == "" then
        return
    end
    if MEDIA_TEXTURE_CACHE[key] == nil then
        MEDIA_TEXTURE_CACHE[key] = resolveTextureByFullType(key) or false
    end
    local tex = MEDIA_TEXTURE_CACHE[key]
    if tex == false then
        tex = nil
    end
    if not tex then return end
    local w = tonumber(button.width) or 0
    local h = tonumber(button.height) or 0
    local size = math.max(10, math.min(w, h) - 6)
    local left = math.floor((w - size) * 0.5 + 0.5)
    local top = math.floor((h - size) * 0.5 + 0.5)
    button:drawTextureScaledAspect(tex, left, top, size, size, 1.0, 1.0, 1.0, 1.0)
end

function resolvePlaceholderKey(window)
    local carrier = resolveDeviceCarrier(window)
    if carrier == tostring(CARRIER_KEYS.cd) then
        return "cd_placeholder"
    end
    if carrier == tostring(CARRIER_KEYS.vinyl) then
        return "vinyl_placeholder"
    end
    return "cassette_placeholder"
end

function resolveEmptyInsertTooltip(window)
    local carrier = resolveDeviceCarrier(window)
    if carrier == tostring(CARRIER_KEYS.cd) then
        return NMTranslations.ui("InsertCD", "Insert CD")
    end
    if carrier == tostring(CARRIER_KEYS.vinyl) then
        return NMTranslations.ui("InsertVinyl", "Insert Vinyl")
    end
    return NMTranslations.ui("InsertCassette", "Insert Cassette")
end

function resolveMediaTooltipLabel(state, fullType)
    local display = tostring(state and state.mediaDisplayName or "")
    if display ~= "" then
        return display
    end
    local ft = tostring(fullType or "")
    if ft ~= "" and NMMediaContract and NMMediaContract.getDisplayNameForFullType then
        local resolved = tostring(NMMediaContract.getDisplayNameForFullType(ft) or "")
        if resolved ~= "" then
            return resolved
        end
    end
    return ft
end

function resolveSlotStyle(window, button, resolved)
    local mouseOver = isMouseOverButton(button)
    if mouseOver then
        if NMUIRenderProbe and NMUIRenderProbe.count then
            NMUIRenderProbe.count(window, "slot.drag_check", 1)
        end
        local items, ok = resolveDraggedItems(window)
        if ok and type(items) == "table" and #items > 0 and isCompatibleMediaDrag(window, items) then
            return "slot_drag"
        end
    end
    local state = resolved and resolved.state or nil
    local fullType = resolveMediaSlotFullType(window, state)
    if fullType ~= "" then
        return "slot_filled"
    end
    if mouseOver then
        return "slot_hover"
    end
    return "slot"
end

function NMMediaSlot.buildContentState(window, frame)
    local resolved = frame and frame.resolved or resolveWindowContext(window)
    local state = resolved and resolved.state or nil
    local fullType = resolveMediaSlotFullType(window, state)
    local timed = window and window._nmMediaSlotTimedProgress or nil
    local fillPct = nil
    if timed and timed.active == true and timed.delta then
        fillPct = NMCore.clamp(tonumber(timed.delta) or 0.0, 0.0, 1.0)
    end
    local placeholderKey = nil
    local tooltip = nil
    if fullType ~= "" then
        tooltip = resolveMediaTooltipLabel(state, fullType)
    else
        placeholderKey = resolvePlaceholderKey(window)
        tooltip = resolveEmptyInsertTooltip(window)
    end
    local acceptedCarriers = {}
    local requiredCarrier = resolveDeviceCarrier(window, resolved)
    if requiredCarrier ~= "" then
        acceptedCarriers[1] = requiredCarrier
    end
    return NMDeviceUiSlotContract.buildContentState("media", {
        fullType = fullType,
        fillPct = fillPct,
        placeholderKey = placeholderKey,
        tooltip = tooltip,
        acceptedCarriers = acceptedCarriers,
        insertAction = "insert_media",
        ejectAction = "eject_media",
    })
end

function NMMediaSlot.buildInteractionState(window, frame, contentState)
    local button = window and window.mediaSlot and window.mediaSlot.button or nil
    local mouseOver = isMouseOverButton(button)
    local styleKey = tostring(contentState and contentState.styleKey or "slot")
    local canAcceptDrag = mouseOver and frame and frame.dragOk and type(frame.dragItems) == "table" and #frame.dragItems > 0
        and isCompatibleMediaDrag(window, frame.dragItems) or false
    if canAcceptDrag then
        styleKey = "slot_drag"
    elseif mouseOver and tostring(contentState and contentState.fullType or "") == "" then
        styleKey = "slot_hover"
    end
    return NMDeviceUiSlotContract.buildInteractionState("media", {
        styleKey = styleKey,
        mouseOver = mouseOver == true,
        dragActive = canAcceptDrag,
        canAcceptDrag = canAcceptDrag,
    })
end

function NMMediaSlot.buildRenderState(window, frame)
    local contentState = NMMediaSlot.buildContentState(window, frame)
    local interactionState = NMMediaSlot.buildInteractionState(window, frame, contentState)
    local out = {}
    for key, value in pairs(contentState or {}) do
        out[key] = value
    end
    for key, value in pairs(interactionState or {}) do
        out[key] = value
    end
    return out
end

