-- SAO_GraphPersistence.lua - the branching graph's durable store.

SAO = SAO or {}
SAO.GraphPersistence = SAO.GraphPersistence or {}
local GraphPersistence = SAO.GraphPersistence

local STORE_KEY = "SurvivorAwareness_Graph"

function GraphPersistence.store()
    local ok, store = pcall(function()
        return ModData.getOrCreate(STORE_KEY)
    end)
    if not ok or type(store) ~= "table" then return nil end

    store.branching = store.branching or {}
    store.organization = store.organization or {}
    store.settlement = store.settlement or {}
    store.material = store.material or {}
    store.communication = store.communication or {}
    store.player = store.player or {}

    -- [C55] Readers and weights are runtime code. Kahlua omits functions
    -- while serializing, so keeping these registries in ModData left a table
    -- that looked populated before save and came back as broken branch shells.
    -- Old saves are migrated by dropping the three runtime projections; the
    -- durable pattern and office history remains bound below.
    store.branching.surfaces = nil
    store.branching.pressures = nil
    store.branching.branches = nil
    store.branching.patterns = store.branching.patterns or {}
    store.branching.offices = store.branching.offices or {}

    store.organization.organizations = store.organization.organizations or {}
    store.organization.offices = store.organization.offices or {}
    store.organization.claims = store.organization.claims or {}
    store.organization.decisions = store.organization.decisions or {}

    store.settlement.bases = store.settlement.bases or {}
    store.material.stores = store.material.stores or {}
    store.communication.messages = store.communication.messages or {}
    store.player.claims = store.player.claims or {}

    return store
end

function GraphPersistence.bind()
    local store = GraphPersistence.store()
    if not store then return false end

    if SAO.Branching then
        SAO.Branching.patterns = store.branching.patterns
        SAO.Branching.offices = store.branching.offices
    end

    if SAO.Organization then
        SAO.Organization.organizations = store.organization.organizations
        SAO.Organization.offices = store.organization.offices
        SAO.Organization.claims = store.organization.claims
        SAO.Organization.decisions = store.organization.decisions
    end

    if SAO.Settlement then
        SAO.Settlement.bases = store.settlement.bases
    end

    if SAO.Material then
        SAO.Material.stores = store.material.stores
    end

    if SAO.Communication then
        SAO.Communication.messages = store.communication.messages
    end

    if SAO.PlayerInteraction then
        SAO.PlayerInteraction.claims = store.player.claims
    end

    return true
end

-- GlobalModData has just replaced its tables when this fires. Rebind the
-- durable owners immediately; Integration rebuilds executable registries at
-- OnGameStart, after every shared module has registered its extension.
if Events and Events.OnInitGlobalModData then
    if GraphPersistence.onInitGlobalModData then
        Events.OnInitGlobalModData.Remove(GraphPersistence.onInitGlobalModData)
    end
    GraphPersistence.onInitGlobalModData = function()
        GraphPersistence.bind()
    end
    Events.OnInitGlobalModData.Add(GraphPersistence.onInitGlobalModData)
end

return GraphPersistence
