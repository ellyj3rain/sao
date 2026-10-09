-- Server-side listener eligibility policy for no-listener freeze/resume behavior.
NMServerListenerEligibility = NMServerListenerEligibility or {}

local function getPlayers()
    return getOnlinePlayers and getOnlinePlayers() or nil
end

local function normalizeRange(profile)
    local v = NMDeviceProfiles and NMDeviceProfiles.getWorldTrackingRange and NMDeviceProfiles.getWorldTrackingRange(profile) or 0
    v = tonumber(v) or 0
    return math.max(0, v)
end

local function normalizeFloors(profile)
    local v = NMDeviceProfiles and NMDeviceProfiles.getWorldTrackingFloors and NMDeviceProfiles.getWorldTrackingFloors(profile) or 0
    v = tonumber(v) or 0
    return math.max(0, v)
end

local function hasWorldListenerAt(entry, profile)
    local players = getPlayers()
    if not players then
        return false
    end
    local ex = tonumber(entry and entry.x) or 0
    local ey = tonumber(entry and entry.y) or 0
    local ez = tonumber(entry and entry.z) or 0
    local range = normalizeRange(profile)
    local rangeSq = range * range
    local floors = normalizeFloors(profile)
    for i = 0, players:size() - 1 do
        local p = players:get(i)
        local sq = p and p.getSquare and p:getSquare() or nil
        if sq then
            local pz = tonumber(sq:getZ()) or 0
            local dz = math.abs(pz - ez)
            if dz <= floors then
                if range <= 0 then
                    return true
                end
                local dx = (tonumber(sq:getX()) or 0) - ex
                local dy = (tonumber(sq:getY()) or 0) - ey
                local d2 = (dx * dx) + (dy * dy)
                if d2 <= rangeSq then
                    return true
                end
            end
        end
    end
    return false
end

function NMServerListenerEligibility.hasEligibleListener(entry, state, profile)
    if type(entry) ~= "table" then
        return false
    end
    local mode = tostring(state and state.authoritativeMode or entry.sourceMode or "")
    if mode == "inventory" then
        -- Personal inventory playback has no world listener requirement.
        return getPlayers() ~= nil and getPlayers():size() > 0
    end
    return hasWorldListenerAt(entry, profile)
end

function NMServerListenerEligibility.evaluate(entry, state, profile)
    local hasListener = NMServerListenerEligibility.hasEligibleListener(entry, state, profile)
    return {
        hasEligibleListener = hasListener == true,
        shouldFreezeForNoListener = hasListener ~= true,
        shouldRestartOnResume = hasListener == true
    }
end


