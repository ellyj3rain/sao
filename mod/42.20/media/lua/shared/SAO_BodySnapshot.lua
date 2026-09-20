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
    return { packed = packed, visual = visual, hours = now, x = x, y = y, z = z, facts = facts }
end

-- Pending journals can outlive their originating callback or Lua environment.
-- Revalidate their native payloads before removal or publication of a new owner.
-- DurableText payloads are opaque: either a string or a validated chunk table.
function Snapshot.valid(captured)
    if type(captured) ~= "table" then return false end
    local ok, valid = pcall(function()
        return SAOJavaBridge:validateHibernation(captured.packed) == true
            and finite(captured.hours) and finite(captured.x)
            and finite(captured.y) and finite(captured.z)
            and type(captured.facts) == "table"
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
    SAO.Population.commitBodyFacts(rec, captured.facts, captured.hours)
    rec.bodyCheckpointFailure = nil
end

return Snapshot
