-- SAO_WorldGenesis - the dormant county's graph pass.
--
-- This module does not author a world. It observes the same branching graph
-- over the dormant records that the live controller runs over bodies, so
-- a county that has already lived carries standing group, leader, claim,
-- material state, communication, and
-- per-person graph summaries when the player arrives.

SAO = SAO or {}
SAO.WorldGenesis = SAO.WorldGenesis or {}
local WorldGenesis = SAO.WorldGenesis

function WorldGenesis.ensure()
    if SAO.GraphPersistence and SAO.GraphPersistence.bind then
        local bound = SAO.GraphPersistence.bind()
        if bound ~= true then return false end
    end
    if SAO.Integration and SAO.Integration.ensure then
        return SAO.Integration.ensure()
    end
    return false
end

local function copyMap(value)
    local out = {}
    for key, scalar in pairs(type(value) == "table" and value or {}) do
        if type(scalar) ~= "table" then out[key] = scalar end
    end
    return out
end

local function summarizeMaterialStore(value)
    if type(value) ~= "table" then return nil end
    return {
        owner = value.owner,
        projection = value.projection,
        items = copyMap(value.items),
        claims = copyMap(value.claims),
        categories = copyMap(value.categories),
    }
end

local function summarize(graph)
    if type(graph) ~= "table" then return nil end
    local organizations = {}
    for index, organizationId in ipairs(graph.organizations or {}) do
        organizations[index] = tostring(organizationId)
    end

    local material = nil
    if type(graph.material) == "table" then
        material = {
            owner = graph.material.owner,
            accessibleBy = graph.material.accessibleBy,
            projection = graph.material.projection,
            items = copyMap(graph.material.items),
            claims = copyMap(graph.material.claims),
            categories = copyMap(graph.material.categories),
            personal = summarizeMaterialStore(graph.material.personal),
            house = summarizeMaterialStore(graph.material.house),
        }
    end

    return {
        group = graph.group,
        leader = graph.leader,
        claim = graph.claim,
        branch = graph.branch,
        work = graph.work,
        organizations = organizations,
        settlement = graph.settlement
            and graph.settlement.organization or nil,
        material = material,
        messages = graph.messages and #graph.messages or 0,
        pressure = graph.pressure,
        isolation = graph.isolation,
        placeAttachment = graph.placeAttachment,
        worldDevelopment = graph.worldDevelopment,
    }
end

local function sourceOwnsActor(id)
    if SAO.WorldSources and SAO.WorldSources.ownsActor then
        return SAO.WorldSources.ownsActor(id) == true
    end
    return false
end

function WorldGenesis.applyDay(day)
    if not WorldGenesis.ensure() then return 0 end
    if not (SAO.Identity and SAO.Integration and SAO.History) then return 0 end

    day = tonumber(day) or 0
    -- [C53] dailyCounty owns an elapsed county day; Integration owns a
    -- county tick. Convert once, here at the producer/consumer boundary.
    local tick = SAO.History.tickAtDayStart(day)
    if type(tick) ~= "number" then return 0 end
    local changed = 0
    for id, record in pairs(SAO.Identity.all()) do
        if not record.dead
            and not (SAO.Body and SAO.Body.hasRepresentation(id))
            and not sourceOwnsActor(id) then
            local agent = {
                id = id,
                x = record.x,
                y = record.y,
            }
            local graph = SAO.Integration.apply(
                id, agent, tick, record.x, record.y)
            local summary = summarize(graph)
            if summary then
                record.worldGraph = summary
                record.worldGraphDay = day
                changed = changed + 1
            end
        end
    end
    return changed
end

return WorldGenesis
