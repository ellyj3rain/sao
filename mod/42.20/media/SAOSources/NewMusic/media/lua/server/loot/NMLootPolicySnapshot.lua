NMLootPolicySnapshot = NMLootPolicySnapshot or {}

local snapshotPolicy = NMLootPolicySnapshot

local CATEGORY_ORDER = {
    "cassettes",
    "vinyl",
    "cds",
    "walkman",
    "boombox",
    "cdplayer",
    "recordplayer"
}

local function cloneRates(rates)
    return {
        cassettes = tonumber(rates and rates.cassettes) or 0,
        vinyl = tonumber(rates and rates.vinyl) or 0,
        cds = tonumber(rates and rates.cds) or 0,
        walkman = tonumber(rates and rates.walkman) or 0,
        boombox = tonumber(rates and rates.boombox) or 0,
        cdplayer = tonumber(rates and rates.cdplayer) or 0,
        recordplayer = tonumber(rates and rates.recordplayer) or 0
    }
end

function snapshotPolicy.createFromSandboxSnapshot(snapshot)
    local policy = {
        casesEnabled = snapshot and snapshot.mediaSpawnsWithCases == true or false,
        ostEnabled = snapshot and snapshot.zomboidOST == true or false,
        convertVanilla = snapshot and snapshot.convertVanilla == true or false,
        authority = tostring(snapshot and snapshot.authority or "unknown"),
        stage = tostring(snapshot and snapshot.stage or "unknown"),
        cacheKey = tostring(snapshot and snapshot.cacheKey or ""),
        defaultLike = snapshot and snapshot.defaultLike == true or false,
        rates = cloneRates(snapshot)
    }
    return policy
end

function snapshotPolicy.clone(policy)
    if type(policy) ~= "table" then
        return nil
    end
    return {
        casesEnabled = policy.casesEnabled == true,
        ostEnabled = policy.ostEnabled == true,
        convertVanilla = policy.convertVanilla == true,
        authority = tostring(policy.authority or "unknown"),
        stage = tostring(policy.stage or "unknown"),
        cacheKey = tostring(policy.cacheKey or ""),
        defaultLike = policy.defaultLike == true,
        rates = cloneRates(policy.rates)
    }
end

function snapshotPolicy.toRawSandboxLootSettings(policy)
    return {
        cassettes = tonumber(policy and policy.rates and policy.rates.cassettes) or 0,
        vinyl = tonumber(policy and policy.rates and policy.rates.vinyl) or 0,
        cds = tonumber(policy and policy.rates and policy.rates.cds) or 0,
        walkman = tonumber(policy and policy.rates and policy.rates.walkman) or 0,
        boombox = tonumber(policy and policy.rates and policy.rates.boombox) or 0,
        cdplayer = tonumber(policy and policy.rates and policy.rates.cdplayer) or 0,
        recordplayer = tonumber(policy and policy.rates and policy.rates.recordplayer) or 0,
        _pagePresent = true,
        source = "controller_policy"
    }
end

function snapshotPolicy.toZomboidOSTSetting(policy)
    local enabled = policy and policy.ostEnabled == true or false
    return {
        pagePresent = true,
        keyPresent = true,
        rawValue = enabled,
        enabled = enabled,
        state = enabled and "enabled" or "disabled",
        source = "controller_policy"
    }
end

function snapshotPolicy.resolveCategoryRate(policy, category, fallbackRate)
    local key = tostring(category or "")
    local rates = policy and policy.rates or nil
    if rates and rates[key] ~= nil then
        return tonumber(rates[key]) or 0
    end
    return tonumber(fallbackRate) or 0
end

function snapshotPolicy.formatRates(policy)
    local rates = policy and policy.rates or nil
    local parts = {}
    for i = 1, #CATEGORY_ORDER do
        local category = CATEGORY_ORDER[i]
        parts[#parts + 1] = string.format("%s=%s", category, tostring(tonumber(rates and rates[category]) or 0))
    end
    return table.concat(parts, " ")
end

function snapshotPolicy.formatPolicy(policy)
    return string.format(
        "cases=%s ost=%s convertVanilla=%s authority=%s stage=%s defaultLike=%s cacheKey=%s rates={%s}",
        tostring(policy and policy.casesEnabled == true),
        tostring(policy and policy.ostEnabled == true),
        tostring(policy and policy.convertVanilla == true),
        tostring(policy and policy.authority or "unknown"),
        tostring(policy and policy.stage or "unknown"),
        tostring(policy and policy.defaultLike == true),
        tostring(policy and policy.cacheKey or ""),
        snapshotPolicy.formatRates(policy)
    )
end

return snapshotPolicy
