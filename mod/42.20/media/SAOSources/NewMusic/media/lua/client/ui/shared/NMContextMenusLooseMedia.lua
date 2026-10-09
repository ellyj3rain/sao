local env = _G.NMContextMenusEnv
setfenv(1, env)

function addCaseMediaActions(menu, player, item, profile, state)
    local function resolveAuthoritativeDisplayState(liveState)
        local stateIn = liveState or state
        if NMClientDisplayStateResolver and NMClientDisplayStateResolver.resolve then
            return NMClientDisplayStateResolver.resolve(stateIn)
        end
        return stateIn
    end

    local function resolveLiveState()
        local liveState = NMDeviceState.ensure(item, profile)
        if liveState and NMClientSessionProjection and NMClientSessionProjection.projectStateIfSessionChanged then
            NMClientSessionProjection.projectStateIfSessionChanged(liveState, {
                kind = "item",
                uuid = tostring(liveState.deviceUUID or ""),
                id = tostring(NMCore.itemId and NMCore.itemId(item) or "unknown")
            })
        end
        return resolveAuthoritativeDisplayState(liveState)
    end
    if NMClientRegistrySync and NMClientRegistrySync.requestNow then
        NMClientRegistrySync.requestNow(player, "context_menu_open")
    end
    state = resolveAuthoritativeDisplayState(resolveLiveState())
    local mediaCandidates = collectMediaCandidates(player, tostring(profile.supportedCarrier or ""))
    if profile and profile.isMediaContainerOnly == true then
        local requiredMedia = NMMediaContract
            and NMMediaContract.resolveContainerMediaBinding
            and NMMediaContract.resolveContainerMediaBinding(item and item.getFullType and item:getFullType() or nil)
            or nil
        if requiredMedia and tostring(requiredMedia) ~= "" then
            local filtered = {}
            for i = 1, #mediaCandidates do
                local candidate = mediaCandidates[i]
                local candidateType = candidate and candidate.getFullType and candidate:getFullType() or nil
                local matches = false
                if NMMediaContract and NMMediaContract.areMediaEquivalent then
                    matches = NMMediaContract.areMediaEquivalent(candidateType, requiredMedia)
                else
                    matches = tostring(candidateType or "") == tostring(requiredMedia)
                end
                if matches then
                    filtered[#filtered + 1] = candidate
                end
            end
            mediaCandidates = filtered
        end
    end

    local function dispatch(action, args)
        if tryQueueOpenWalkmanMediaAction and tryQueueOpenWalkmanMediaAction(player, item, action, args or {}) == true then
            return
        end
        NMClientIntentDispatch.performIntent(player, item, action, args or {})
        state = resolveAuthoritativeDisplayState(resolveLiveState())
    end

    local hasMedia = state.mediaFullType and tostring(state.mediaFullType) ~= ""
    local mediaActionLabel = resolveMediaActionLabel(profile, hasMedia)
    if hasMedia then
        addAction(menu, mediaActionLabel, player, function()
            dispatch("eject_media")
        end)
    else
        addInsertSubmenu(menu, mediaActionLabel, player, mediaCandidates, function(_, mediaItem)
            local args = buildCaseMediaInsertArgs(mediaItem)
            if not args then
                return
            end
            dispatch("insert_media", args)
        end)
    end
end

function addContainerCoverViewAction(menu, player, item, state)
    local fullType = item and item.getFullType and tostring(item:getFullType() or "") or ""
    local texturePath, mode = NMCoverViewResolver.resolvePath(fullType, state)
    local label = tostring(state and state.mediaDisplayName or (item and item.getDisplayName and item:getDisplayName()) or NMTranslations.ui("ViewCover", "View Cover"))
    if texturePath and texturePath ~= "" and getTexture and getTexture(texturePath) then
        menu:addOption(NMTranslations.ui("ViewCover", "View Cover"), player, function(p)
            local playerNum = p and p.getPlayerNum and p:getPlayerNum() or 0
            NMCoverViewUI.open(playerNum, texturePath, label, mode)
        end)
        return
    end
    local unavailable = menu:addOption(NMTranslations.ui("ViewCoverNoCover", "View Cover (No Cover)"), player, function() end)
    unavailable.notAvailable = true
end

function isLooseMediaItem(item)
    if not item then
        return false
    end
    local fullType = item.getFullType and tostring(item:getFullType() or "") or ""
    if fullType == "" then
        return false
    end
    local carrier = NMMediaContract.resolveMediaCarrier(fullType)
    if not carrier or tostring(carrier) == "" then
        return false
    end
    local profile = NMDeviceProfiles.getForItem(item)
    if profile then
        return false
    end
    return true
end

function addLooseMediaActions(subMenu, player, mediaItem)
    local capturedItemId = NMCore.itemId and NMCore.itemId(mediaItem) or nil
    addLooseMediaFlipAction(subMenu, player, mediaItem, capturedItemId)
    addLooseMediaInsertActions(subMenu, player, mediaItem, capturedItemId)
end

