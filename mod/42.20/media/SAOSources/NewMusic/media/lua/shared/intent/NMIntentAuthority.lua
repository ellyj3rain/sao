NMIntentAuthority = NMIntentAuthority or {}

local function getAuthority()
    return NMAuthorityV4 or NMAuthorityV3
end

function NMIntentAuthority.resolveSourceOwnerIdentity(player)
    if not player then
        return nil
    end
    local onlineId = player.getOnlineID and tostring(player:getOnlineID() or "") or ""
    if onlineId ~= "" then
        return onlineId
    end
    local username = player.getUsername and tostring(player:getUsername() or "") or ""
    if username ~= "" then
        return username
    end
    return nil
end

function NMIntentAuthority.mapModeToIntent(mode)
    local name = tostring(mode or "")
    if name == "attached" then
        return "request_attached"
    end
    if name == "placed" then
        return "request_placed"
    end
    if name == "stowed" then
        return "request_stowed"
    end
    return "request_off"
end

function NMIntentAuthority.applyIntent(state, intent, context)
    local authority = getAuthority()
    if not (authority and authority.applyIntent and state) then
        return false
    end

    local beforeMode = tostring(state.authoritativeMode or "off")
    local beforeGen = tonumber(state.sourceGeneration) or 0

    authority.applyIntent(state, tostring(intent or "request_off"), context or {})

    local afterMode = tostring(state.authoritativeMode or "off")
    local afterGen = tonumber(state.sourceGeneration) or 0
    return beforeMode ~= afterMode or beforeGen ~= afterGen
end

function NMIntentAuthority.applyMode(state, mode, context)
    return NMIntentAuthority.applyIntent(state, NMIntentAuthority.mapModeToIntent(mode), context)
end

return NMIntentAuthority
