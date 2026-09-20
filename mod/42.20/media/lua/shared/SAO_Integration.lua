-- SAO_Integration.lua - connects the branching graph to the county's surfaces.

SAO = SAO or {}
SAO.Integration = SAO.Integration or {}
local Integration = SAO.Integration

Integration.ready = false
-- Installers are runtime code too. A stable id is the explicit startup
-- contract for sister mods and optional modules: registering the same id
-- replaces its installer, while a rebuild runs each installer once.
Integration.extensions = Integration.extensions or {}
Integration.installedExtensions = {}
-- Kahlua's table.sort uses its leftmost element as the pivot. Keep the
-- extension registry in the low hundreds so stable ordering cannot exhaust
-- the VM stack regardless of the caller-supplied id order.
local EXTENSION_CEILING = 128

local function extensionCount()
    local count = 0
    for _ in pairs(Integration.extensions) do
        count = count + 1
        if count >= EXTENSION_CEILING then return count end
    end
    return count
end

local function clearRuntimeGraph()
    if not SAO.Branching then return end
    SAO.Branching.surfaces = {}
    SAO.Branching.pressures = {}
    SAO.Branching.branches = {}
end

local function installExtension(id, installer)
    local ok, installed = pcall(installer, SAO.Branching)
    if not ok or installed == false then return false end
    Integration.installedExtensions[id] = true
    return true
end

function Integration.registerExtension(id, installer)
    if type(id) ~= "string" or id == "" or type(installer) ~= "function" then
        return false
    end
    if Integration.extensions[id] == nil
        and extensionCount() >= EXTENSION_CEILING then
        return false
    end
    local wasReady = Integration.ready
    Integration.extensions[id] = installer
    if wasReady then return Integration.rebuild() end
    return true
end

function Integration.unregisterExtension(id)
    if type(id) ~= "string" or Integration.extensions[id] == nil then
        return false
    end
    local wasReady = Integration.ready
    Integration.extensions[id] = nil
    Integration.ready = false
    if wasReady then return Integration.ensure() end
    return true
end

function Integration.ensure()
    if Integration.ready then return true end
    if SAO.GraphPersistence then
        SAO.GraphPersistence.bind()
    end
    clearRuntimeGraph()
    Integration.installedExtensions = {}
    if not (SAO.Branching and SAO.Pressure and SAO.Labor
        and SAO.PathogenPressure and SAO.Organization
        and SAO.Settlement and SAO.Material
        and SAO.Communication and SAO.PlayerInteraction) then
        return false
    end

    SAO.Branching.registerSurface("person", function(id)
        return SAO.Identity and SAO.Identity.get(id) or nil
    end)
    SAO.Branching.registerSurface("perception", function(id)
        return SAO.Perception and SAO.Perception.beliefs[id] or nil
    end)
    SAO.Branching.registerSurface("isolation", function(id)
        return SAO.Isolation and SAO.Isolation.of(id) or nil
    end)
    SAO.Branching.registerSurface("placeAttachment", function(id)
        return SAO.PlaceAttachment and SAO.PlaceAttachment.of(id) or nil
    end)
    SAO.Branching.registerSurface("worldDevelopment", function(id)
        return SAO.WorldDevelopment and SAO.WorldDevelopment.of(id) or nil
    end)
    SAO.Branching.registerSurface("place", function(id)
        local rec = SAO.Identity and SAO.Identity.get(id) or nil
        if not rec or not SAO.WorldSources then return nil end
        return SAO.WorldSources.nearestBelieved(id,
            rec.x or rec.homeX or 0, rec.y or rec.homeY or 0,
            "food", SAO.Places.commitHorizon())
    end)
    SAO.Branching.registerSurface("relationship", function(id)
        return SAO.Standing and SAO.Standing.fellowsOf(id) or {}
    end)
    SAO.Branching.registerSurface("organization", function(id)
        return SAO.Organization and SAO.Organization.organizationsOf(id) or {}
    end)
    SAO.Branching.registerSurface("settlement", function(id)
        if not SAO.Settlement then return nil end
        for _, base in pairs(SAO.Settlement.bases) do
            if base.members[id] then return base end
        end
        return nil
    end)
    SAO.Branching.registerSurface("player", function(id)
        return SAO.PlayerInteraction and SAO.PlayerInteraction.actions or {}
    end)
    SAO.Branching.registerSurface("material", function(id)
        return SAO.Material and SAO.Material.storeOf(id) or nil
    end)
    SAO.Branching.registerSurface("communication", function(id)
        return SAO.Communication and SAO.Communication.pendingFor(id) or {}
    end)
    SAO.Branching.registerSurface("adaptation", function(id)
        return SAO.Adaptation and SAO.Adaptation.stateOf(id) or nil
    end)
    SAO.Branching.registerSurface("pathogen", function(id)
        local rec = SAO.Identity and SAO.Identity.get(id) or nil
        if not rec then return nil end
        if rec.pathogenState then return rec.pathogenState end
        if not (ZAO and ZAO.State) then return nil end
        local hour = 0
        pcall(function() hour = SAO.History.countyHours() end)
        return ZAO.State.of(rec, hour)
    end)
    SAO.Branching.registerSurface("action", function(id)
        return SAO.Controller and SAO.Controller.agents[id] or nil
    end)

    SAO.Branching.registerPressure("threat", function(id, tick, x, y)
        return SAO.Pressure.threat(id, tick, x, y)
    end)
    SAO.Branching.registerPressure("needs", function(id)
        return SAO.Pressure.needs(id)
    end)
    SAO.Branching.registerPressure("injury", function(id)
        return SAO.Pressure.injury(id)
    end)
    SAO.Branching.registerPressure("infection", function(id)
        return SAO.Pressure.infection(id)
    end)
    SAO.Branching.registerPressure("weather", function()
        return SAO.Pressure.weather()
    end)
    SAO.Branching.registerPressure("isolation", function(id)
        local state = SAO.Isolation and SAO.Isolation.of(id) or nil
        return state and state.isolation or 0
    end)
    SAO.Branching.registerPressure("attachment", function(id)
        local state = SAO.PlaceAttachment
            and SAO.PlaceAttachment.of(id) or nil
        return state and state.attachment or 0
    end)
    SAO.Branching.registerPressure("development", function(id)
        local state = SAO.WorldDevelopment
            and SAO.WorldDevelopment.of(id) or nil
        return state and state.development or 0
    end)
    SAO.Branching.registerPressure("pathogen", function(id, tick, x, y)
        if not SAO.PathogenPressure then return 0 end
        -- [C116] The nearest believed carrier of a form, living or
        -- dead: the pathogen presses by what a body carries, not by
        -- what kind of body carries it, and a returned neighbor shaped
        -- like the county's worst news is read at full weight.
        local threat = SAO.Perception
            and SAO.Perception.nearestBelievedThreat(id, tick, x, y)
            or nil
        if not threat or not threat.form or threat.form == "none" then
            return 0
        end
        return math.max(0.0, SAO.PathogenPressure.multiplier(threat) - 1.0)
    end)

    SAO.Branching.registerBranch({
        id = "threat",
        weight = function(id, tick, pressure)
            local pressureValue = SAO.Pressure.total(id, tick, 0, 0)
            return pressureValue * 1.5
        end,
    })
    SAO.Branching.registerBranch({
        id = "work",
        weight = function(id, tick, pressure)
            return pressure
        end,
    })
    SAO.Branching.registerBranch({
        id = "organization",
        weight = function(id, tick, pressure)
            if not SAO.Organization then return 0 end
            return pressure * 0.8
        end,
    })
    SAO.Branching.registerBranch({
        id = "settlement",
        weight = function(id, tick, pressure)
            if not SAO.Settlement then return 0 end
            return pressure * 0.9
        end,
    })

    local ids = {}
    for id in pairs(Integration.extensions) do
        if #ids >= EXTENSION_CEILING then
            clearRuntimeGraph()
            Integration.installedExtensions = {}
            return false
        end
        ids[#ids + 1] = id
    end
    table.sort(ids)
    for _, id in ipairs(ids) do
        if not installExtension(id, Integration.extensions[id]) then
            clearRuntimeGraph()
            Integration.installedExtensions = {}
            return false
        end
    end

    Integration.ready = true
    return true
end

function Integration.rebuild()
    Integration.ready = false
    return Integration.ensure()
end

function Integration.apply(id, agent, tick, x, y)
    if not Integration.ensure() then return nil end
    local options = SandboxVars and SandboxVars.SurvivorAwareness or nil
    if options and options.Branching == false then return nil end

    local pressure = (not options or options.Pressure ~= false)
        and SAO.Pressure.total(id, tick, x, y) or 0
    local groupId = SAO.Standing and SAO.Standing.groupOf(id) or nil
    local leader = groupId and SAO.Standing.leaderOf(groupId) or nil
    local claim = groupId and SAO.Standing.groupClaimOf(groupId) or nil
    local branch = SAO.Branching.select(id, tick)
    local work = (not options or options.Labor ~= false)
        and SAO.Labor.choose(id, tick, pressure) or nil
    if work then
        SAO.Branching.record(id, work, tick)
    end
    local organizations = SAO.Organization
        and SAO.Organization.organizationsOf(id) or {}
    local settlement = nil
    if SAO.Settlement then
        for _, base in pairs(SAO.Settlement.bases) do
            if base.members[id] then settlement = base end
        end
    end
    local material = (not options or options.Material ~= false)
        and SAO.Material and SAO.Material.storeOf(id) or nil
    local messages = (not options or options.Communication ~= false)
        and SAO.Communication and SAO.Communication.pendingFor(id) or {}
    local isolation = SAO.Isolation and SAO.Isolation.of(id) or nil
    local placeAttachment = SAO.PlaceAttachment
        and SAO.PlaceAttachment.of(id) or nil
    local worldDevelopment = SAO.WorldDevelopment
        and SAO.WorldDevelopment.of(id) or nil

    local graph = {
        pressure = pressure,
        group = groupId,
        leader = leader,
        claim = claim,
        branch = branch and branch.id or nil,
        work = work,
        organizations = organizations,
        settlement = settlement,
        material = material,
        messages = messages,
        isolation = isolation,
        placeAttachment = placeAttachment,
        worldDevelopment = worldDevelopment,
    }

    agent.graph = graph
    agent.branch = graph.branch
    agent.work = graph.work
    agent.organizations = graph.organizations
    agent.settlement = graph.settlement
    agent.material = graph.material
    agent.messages = graph.messages
    agent.isolation = graph.isolation
    agent.placeAttachment = graph.placeAttachment
    agent.worldDevelopment = graph.worldDevelopment

    return graph
end

if Integration.onGameStart then
    Events.OnGameStart.Remove(Integration.onGameStart)
end
Integration.onGameStart = function()
    Integration.rebuild()
end
Events.OnGameStart.Add(Integration.onGameStart)

return Integration
