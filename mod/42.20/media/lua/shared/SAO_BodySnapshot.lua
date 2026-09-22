-- SAO_BodySnapshot - durable state carried between body owners.
-- Capture and validation leave the record unchanged. Body owns the transaction
-- and calls commit only after its ownership/teardown requirements succeed.
SAO = SAO or {}
SAO.BodySnapshot = SAO.BodySnapshot or {}
local Snapshot = SAO.BodySnapshot

local function finite(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

function Snapshot.restValues(access)
    if type(access) ~= "string" then return nil end
    local fatigue, endurance, sleepNeed = string.match(access,
        "^AVAILABLE:([%d%.eE%+%-]+):([%d%.eE%+%-]+):([%d%.eE%+%-]+)$")
    fatigue, endurance, sleepNeed = tonumber(fatigue), tonumber(endurance),
        tonumber(sleepNeed)
    if not finite(fatigue) or not finite(endurance) or not finite(sleepNeed)
        or fatigue < 0 or fatigue > 1 or endurance < 0 or endurance > 1
        or sleepNeed <= 0 then return nil end
    return fatigue, endurance, sleepNeed
end

local function restAccess(packed)
    if not (SAOJavaBridge and SAOJavaBridge.hibernationRestState) then return nil end
    local ok, access = pcall(function()
        return SAOJavaBridge:hibernationRestState(packed)
    end)
    if not ok or not Snapshot.restValues(access) then return nil end
    return access
end

function Snapshot.version(packed)
    if SAOJavaBridge and SAOJavaBridge.hibernationVersion then
        local ok, version = pcall(function()
            return SAOJavaBridge:hibernationVersion(packed)
        end)
        if ok and type(version) == "number" then return version end
        return 0
    end
    -- Older bridge doubles represent the supported visual-sidecar format.
    -- The installed bridge always reports the native snapshot version.
    return 3
end

function Snapshot.capture(rec, body)
    local packed = SAOJavaBridge:hibernate(body)
    if SAOJavaBridge:validateHibernation(packed) ~= true then
        return nil, "invalid-snapshot"
    end
    local version = Snapshot.version(packed)
    if version == 0 then return nil, "incomplete-person-snapshot" end
    local rest = restAccess(packed)
    if not rest then return nil, "incomplete-rest-snapshot" end
    local visual = nil
    if version < 4 then
        visual = SAOJavaBridge:captureReturnVisual(body)
        if SAOJavaBridge:validateReturnVisual(visual) ~= true then
            return nil, "invalid-visual"
        end
    end
    local now = SAO.History.countyHours()
    local x, y, z = body:getX(), body:getY(), body:getZ()
    if not finite(now) or not finite(x) or not finite(y) or not finite(z) then
        return nil, "invalid-position-time"
    end
    local facts = SAO.Population.captureBodyFacts(rec, body, now)
    if type(facts) ~= "table" then return nil, "invalid-body-facts" end
    return { packed = packed, visual = visual, rest = rest,
        hours = now, x = x, y = y, z = z, facts = facts,
        radioRequired = true }
end

-- Pending journals can outlive their originating callback or Lua environment.
-- Revalidate their native payloads before removal or publication of a new owner.
-- DurableText payloads are opaque: either a string or a validated chunk table.
function Snapshot.valid(captured)
    if type(captured) ~= "table" then return false end
    local ok, valid = pcall(function()
        local rest = captured.rest or restAccess(captured.packed)
        local facts = captured.facts
        local radioKnown = type(facts) == "table"
            and type(facts.radioState) == "string"
            and SAOJavaBridge:validateRadioState(facts.radioState) == true
        local radioValid = radioKnown
            or (captured.radioRequired == nil and facts.radioState == nil)
        return SAOJavaBridge:validateHibernation(captured.packed) == true
            and Snapshot.restValues(rest) ~= nil
            and finite(captured.hours) and finite(captured.x)
            and finite(captured.y) and finite(captured.z)
            and type(facts) == "table"
            and (captured.radioRequired == nil
                or captured.radioRequired == true)
            and radioValid
            and (captured.visual == nil
                or SAOJavaBridge:validateReturnVisual(captured.visual) == true)
    end)
    return ok and valid == true
end

function Snapshot.commit(rec, captured)
    rec.hibernation = captured.packed
    rec.bodyVisual = captured.visual
    rec.releasedAtHours = captured.hours
    rec.x, rec.y, rec.z = captured.x, captured.y, captured.z
    SAO.Population.commitBodyFacts(rec, captured.facts, captured.hours,
        captured.radioRequired == nil)
    local fatigue, endurance, sleepNeed = Snapshot.restValues(
        captured.rest or restAccess(captured.packed))
    if fatigue then
        rec.dormantPhysiologyOrigin = "native-snapshot"
        rec.dormantFatigue = fatigue
        rec.dormantEndurance = endurance
        rec.dormantSleepNeed = sleepNeed
        rec.dormantPhysiologyAtHours = captured.hours
    else
        rec.dormantPhysiologyOrigin = nil
        rec.dormantFatigue = nil
        rec.dormantEndurance = nil
        rec.dormantSleepNeed = nil
        rec.dormantPhysiologyAtHours = nil
    end
    rec.bodyCheckpointFailure = nil
end

return Snapshot
