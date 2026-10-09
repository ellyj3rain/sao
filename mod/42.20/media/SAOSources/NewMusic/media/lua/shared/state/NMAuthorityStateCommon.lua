-- Shared helper functions for authority state normalization and intent mapping.
NMDeviceAuthorityStateCommon = NMDeviceAuthorityStateCommon or {}

function NMDeviceAuthorityStateCommon.asNumber(value)
    local n = tonumber(value)
    if n == nil then
        return nil
    end
    return n
end

function NMDeviceAuthorityStateCommon.normalizedMode(mode)
    local m = tostring(mode or "")
    if m == "placed" or m == "attached" or m == "stowed" or m == "vehicle" or m == "off" then
        return m
    end
    return "off"
end

function NMDeviceAuthorityStateCommon.sameSourceState(state, mode, sourceKind, sx, sy, sz, sourceOwner)
    local cx = NMDeviceAuthorityStateCommon.asNumber(state and state.sourceX)
    local cy = NMDeviceAuthorityStateCommon.asNumber(state and state.sourceY)
    local cz = NMDeviceAuthorityStateCommon.asNumber(state and state.sourceZ)
    local nx = NMDeviceAuthorityStateCommon.asNumber(sx)
    local ny = NMDeviceAuthorityStateCommon.asNumber(sy)
    local nz = NMDeviceAuthorityStateCommon.asNumber(sz)
    return NMDeviceAuthorityStateCommon.normalizedMode(state and state.authoritativeMode) == NMDeviceAuthorityStateCommon.normalizedMode(mode)
        and tostring(state and state.sourceKind or "none") == tostring(sourceKind or "none")
        and tostring(state and state.sourceOwner or "") == tostring(sourceOwner or "")
        and cx == nx and cy == ny and cz == nz
end

function NMDeviceAuthorityStateCommon.resolveIntent(intent, context)
    local normalizedIntent = tostring(intent or "")
    local out = {
        targetMode = "off",
        sourceKind = "none",
        sx = context and context.sourceX or nil,
        sy = context and context.sourceY or nil,
        sz = context and context.sourceZ or nil,
        sourceOwner = context and context.sourceOwner or nil
    }
    if normalizedIntent == "request_attached" then
        out.targetMode = "attached"
        out.sourceKind = "player"
    elseif normalizedIntent == "request_placed" then
        out.targetMode = "placed"
        out.sourceKind = "world_item"
    elseif normalizedIntent == "request_stowed" then
        out.targetMode = "stowed"
        out.sourceKind = "inventory"
    elseif normalizedIntent == "request_vehicle" then
        out.targetMode = "vehicle"
        out.sourceKind = "vehicle"
    elseif normalizedIntent == "request_off" then
        out.targetMode = "off"
        out.sourceKind = "none"
        out.sx, out.sy, out.sz = nil, nil, nil
        out.sourceOwner = nil
    else
        return nil
    end
    return out
end

