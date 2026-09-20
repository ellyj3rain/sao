-- SAO_GraphPersistence.lua - the branching graph's durable store.

SAO = SAO or {}
SAO.GraphPersistence = SAO.GraphPersistence or {}
local GraphPersistence = SAO.GraphPersistence

local STORE_KEY = "SurvivorAwareness_Graph"
local GRAPH_SCHEMA = 2
local C63_UPGRADE_PROVENANCE =
    "initialized at C63 upgrade from represented C62 state; no earlier history inferred"

local function groundedSettlement(base)
    local grounding = type(base) == "table" and base.grounding or nil
    return type(grounding) == "table"
        and grounding.producer == "place-development"
        and type(grounding.resultId) == "string"
        and grounding.resultId ~= ""
end

local function electionGroundedOrganization(store, organizationId)
    organizationId = tostring(organizationId or "")
    local organization = store.organization.organizations[organizationId]
    local office = store.organization.offices[organizationId .. ":chair"]
    if type(office) ~= "table" and type(organization) == "table"
        and type(organization.offices) == "table" then
        office = organization.offices.chair
    end
    return type(office) == "table"
        and tostring(office.organization or "") == organizationId
        and office.legitimacy == "election"
end

local function detachDurableOwners()
    if SAO.Branching then
        SAO.Branching.surfaces = {}
        SAO.Branching.pressures = {}
        SAO.Branching.branches = {}
        SAO.Branching.patterns = {}
        SAO.Branching.offices = {}
    end
    if SAO.Organization then
        SAO.Organization.organizations = {}
        SAO.Organization.offices = {}
        SAO.Organization.claims = {}
        SAO.Organization.decisions = {}
    end
    if SAO.Settlement then SAO.Settlement.bases = {} end
    if SAO.Material then
        SAO.Material.stores = {}
        SAO.Material.reconciliations = {}
        SAO.Material.sourceOwners = {}
    end
    if SAO.Communication then SAO.Communication.messages = {} end
    if SAO.PlayerInteraction then SAO.PlayerInteraction.claims = {} end
    if SAO.Integration then SAO.Integration.ready = false end
end

local function migrateLegacyFalseOutputs(store, priorSchema)
    local retiredHouseStores = 0
    for owner, materialStore in pairs(store.material.stores) do
        if type(owner) == "string" and string.sub(owner, 1, 6) == "house:"
            and (type(materialStore) ~= "table"
                or materialStore.projection ~= "native-sources") then
            store.material.stores[owner] = nil
            retiredHouseStores = retiredHouseStores + 1
        end
    end

    local retiredSettlementBases = 0
    local retiredBaseOrganizations = {}
    for organizationId, base in pairs(store.settlement.bases) do
        if not groundedSettlement(base) then
            store.settlement.bases[organizationId] = nil
            retiredSettlementBases = retiredSettlementBases + 1
            local linkedId = type(base) == "table" and base.organization
                or organizationId
            linkedId = tostring(linkedId or "")
            if linkedId ~= "" then retiredBaseOrganizations[linkedId] = true end
        end
    end

    local retiredProvisioningOrganizations = 0
    local sanitizedElectionOrganizations = 0
    for organizationId in pairs(retiredBaseOrganizations) do
        local organization = store.organization.organizations[organizationId]
        if organization then
            if electionGroundedOrganization(store, organizationId) then
                local chair = store.organization.offices[
                    organizationId .. ":chair"]
                store.organization.organizations[organizationId] = {
                    id = organizationId,
                    boundary = {},
                    governance = "unsettled",
                    members = {},
                    offices = { chair = chair },
                    customs = {},
                    createdAt = 0,
                }
                sanitizedElectionOrganizations =
                    sanitizedElectionOrganizations + 1
            else
                store.organization.organizations[organizationId] = nil
                retiredProvisioningOrganizations =
                    retiredProvisioningOrganizations + 1
            end
        end
    end

    store.migrations.c63FalseOutputRetirement = {
        fromSchema = priorSchema,
        toSchema = GRAPH_SCHEMA,
        provenance = C63_UPGRADE_PROVENANCE,
        retiredHouseStores = retiredHouseStores,
        retiredSettlementBases = retiredSettlementBases,
        retiredProvisioningOrganizations = retiredProvisioningOrganizations,
        sanitizedElectionOrganizations = sanitizedElectionOrganizations,
    }
end

function GraphPersistence.store()
    local ok, store = pcall(function()
        return ModData.getOrCreate(STORE_KEY)
    end)
    if not ok or type(store) ~= "table" then return nil end

    local priorSchema = tonumber(store.schema) or 0
    if priorSchema > GRAPH_SCHEMA then return nil, "future-schema" end

    store.branching = type(store.branching) == "table" and store.branching or {}
    store.organization = type(store.organization) == "table"
        and store.organization or {}
    store.settlement = type(store.settlement) == "table"
        and store.settlement or {}
    store.material = type(store.material) == "table" and store.material or {}
    store.communication = type(store.communication) == "table"
        and store.communication or {}
    store.player = type(store.player) == "table" and store.player or {}
    store.migrations = type(store.migrations) == "table" and store.migrations or {}

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

    store.organization.organizations = type(store.organization.organizations)
        == "table" and store.organization.organizations or {}
    store.organization.offices = type(store.organization.offices) == "table"
        and store.organization.offices or {}
    store.organization.claims = type(store.organization.claims) == "table"
        and store.organization.claims or {}
    store.organization.decisions = type(store.organization.decisions) == "table"
        and store.organization.decisions or {}

    store.settlement.bases = type(store.settlement.bases) == "table"
        and store.settlement.bases or {}
    store.material.stores = type(store.material.stores) == "table"
        and store.material.stores or {}
    store.material.reconciliations = type(store.material.reconciliations)
        == "table" and store.material.reconciliations or {}
    store.material.sourceOwners = type(store.material.sourceOwners) == "table"
        and store.material.sourceOwners or {}
    store.communication.messages = store.communication.messages or {}
    store.player.claims = store.player.claims or {}

    if priorSchema < GRAPH_SCHEMA then
        migrateLegacyFalseOutputs(store, priorSchema)
        store.schema = GRAPH_SCHEMA
    end

    return store
end

function GraphPersistence.bind()
    local store, why = GraphPersistence.store()
    if not store then
        detachDurableOwners()
        return false, why
    end

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
        SAO.Material.reconciliations = store.material.reconciliations
        SAO.Material.sourceOwners = store.material.sourceOwners
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
