-- SAO_GraphPersistence.lua - the branching graph's durable store.

SAO = SAO or {}
SAO.GraphPersistence = SAO.GraphPersistence or {}
local GraphPersistence = SAO.GraphPersistence

local STORE_KEY = "SurvivorAwareness_Graph"
local GRAPH_SCHEMA = 4
local C63_UPGRADE_PROVENANCE =
    "initialized at C63 upgrade from represented C62 state; no earlier history inferred"
local LEGACY_RATION_POLICY = {
    ["watch-first"] = true, ["weak-first"] = true,
    ["house-first"] = true, ["carry-light"] = true,
}

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
    if SAO.CoordinationInference and SAO.CoordinationInference.reset then
        SAO.CoordinationInference.reset()
    end
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
        SAO.Organization.claimHistory = {}
        SAO.Organization.decisionHistory = {}
        SAO.Organization.processes = {}
        SAO.Organization.processOrder = {}
        SAO.Organization.processMeta = { sequence = 0 }
        SAO.Organization.workReceipts = {}
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
        toSchema = 2,
        provenance = C63_UPGRADE_PROVENANCE,
        retiredHouseStores = retiredHouseStores,
        retiredSettlementBases = retiredSettlementBases,
        retiredProvisioningOrganizations = retiredProvisioningOrganizations,
        sanitizedElectionOrganizations = sanitizedElectionOrganizations,
    }
end

local function migratePartialMaterialOutputs(store, priorSchema)
    local markedPartial, clearedStorage = 0, 0
    for owner, materialStore in pairs(store.material.stores) do
        if type(owner) == "string" and string.sub(owner, 1, 6) == "house:"
            and type(materialStore) == "table"
            and materialStore.projection == "native-sources" then
            materialStore.coverage = {
                complete = false,
                basis = "selected-native-sources",
                reason = "c64-partial-projection-migration",
                atHours = 0,
            }
            markedPartial = markedPartial + 1
        end
    end
    for _, base in pairs(store.settlement.bases) do
        if type(base) == "table"
            and base.storageProjection == "native-sources" then
            base.storage = {}
            base.storageProjection = nil
            base.storageEvidence = nil
            clearedStorage = clearedStorage + 1
        end
    end
    store.migrations.c64PartialMaterialCorrection = {
        fromSchema = priorSchema,
        toSchema = 3,
        provenance = "C64 marks selected-source projections partial; no complete house inventory inferred",
        markedPartialHouseStores = markedPartial,
        clearedPartialSettlementStorage = clearedStorage,
    }
end

local function migrateEnactedProcesses(store, priorSchema)
    -- Old claim/decision maps are retained as their latest compatibility
    -- projection.  No legacy roster, office, message, or score is converted
    -- into assent, a participant response, authority, or completed work.
    store.organization.claimHistory = {}
    store.organization.decisionHistory = {}
    store.organization.processes = {}
    store.organization.processOrder = {}
    store.organization.processMeta = { sequence = 0 }
    store.organization.workReceipts = {}
    -- Preserve the last policy an existing save was already living under as
    -- a legacy projection, without inventing a proposal, ballot, participant
    -- response, office mandate, or commitment. New policy authority can only
    -- come from the enacted process owner; this record merely prevents an
    -- upgrade from silently changing established material behaviour.
    local migratedLegacyPolicies, migratedLegacyFormClaims = 0, 0
    local okStanding, standing = pcall(function()
        return ModData.get("SurvivorAwareness_Standing")
    end)
    if okStanding and type(standing) == "table"
        and type(standing.groupMeta) == "table" then
        for organizationId, meta in pairs(standing.groupMeta) do
            local policy = type(meta) == "table" and meta.rationPolicy or nil
            if LEGACY_RATION_POLICY[policy] then
                local key = tostring(organizationId)
                    .. ":assembly:ration-policy"
                if not store.organization.decisions[key] then
                    local atHours = 0
                    for _, history in ipairs(type(meta.govHistory) == "table"
                        and meta.govHistory or {}) do
                        if type(history) == "table" and history.kind == "policy"
                            and history.policy == policy then
                            atHours = tonumber(history.atHours) or atHours
                        end
                    end
                    local record = {
                        id = key .. ":legacy-r1", revision = 1,
                        organization = tostring(organizationId),
                        office = "assembly", holder = nil,
                        matter = "ration-policy", decision = policy,
                        basis = {
                            legacyProjection = true,
                            source = "SurvivorAwareness_Standing.groupMeta.rationPolicy",
                            consent = "unrecorded",
                        },
                        processId = nil, commitmentId = nil,
                        recordedAt = atHours,
                    }
                    store.organization.decisions[key] = record
                    store.organization.decisionHistory[key] = { record }
                    migratedLegacyPolicies = migratedLegacyPolicies + 1
                end
            end
            -- The old player verb stored an urged form directly on groupMeta.
            -- Preserve an attributed ask as an unanswered legacy claim; do not
            -- create a process, reception, response, commitment or authority.
            local urgedForm = type(meta) == "table" and meta.urgedForm or nil
            local urgedBy = type(meta) == "table" and meta.urgedBy or nil
            local urgedAtHours = type(meta) == "table"
                and tonumber(meta.urgedAtHours) or 0
            if (urgedForm == "council" or urgedForm == "ladder")
                and type(urgedBy) == "string" and urgedBy ~= "" then
                local key = urgedBy .. ":governance-form:"
                    .. tostring(organizationId)
                if not store.organization.claims[key] then
                    local claim = {
                        id = key .. ":legacy-r1", key = key, revision = 1,
                        claimant = urgedBy, kind = "governance-form",
                        target = tostring(organizationId),
                        organization = tostring(organizationId),
                        recognizers = {}, dissenters = {},
                        response = "unanswered",
                        evidence = { legacyProjection = true,
                            proposedForm = urgedForm,
                            source = "SurvivorAwareness_Standing.groupMeta",
                            consent = "unrecorded" },
                        recordedAt = urgedAtHours,
                    }
                    store.organization.claims[key] = claim
                    store.organization.claimHistory[key] = { claim }
                    migratedLegacyFormClaims = migratedLegacyFormClaims + 1
                end
            end
        end
    end
    store.migrations.c79EnactedProcesses = {
        fromSchema = priorSchema,
        toSchema = GRAPH_SCHEMA,
        provenance = "C79 initializes empty enacted-process state; no prior consent or work inferred",
        migratedLegacyPolicies = migratedLegacyPolicies,
        migratedLegacyFormClaims = migratedLegacyFormClaims,
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
    store.organization.claimHistory = type(store.organization.claimHistory)
        == "table" and store.organization.claimHistory or {}
    store.organization.decisionHistory = type(store.organization.decisionHistory)
        == "table" and store.organization.decisionHistory or {}
    store.organization.processes = type(store.organization.processes)
        == "table" and store.organization.processes or {}
    store.organization.processOrder = type(store.organization.processOrder)
        == "table" and store.organization.processOrder or {}
    store.organization.processMeta = type(store.organization.processMeta)
        == "table" and store.organization.processMeta or { sequence = 0 }
    store.organization.workReceipts = type(store.organization.workReceipts)
        == "table" and store.organization.workReceipts or {}

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

    if priorSchema < 2 then
        migrateLegacyFalseOutputs(store, priorSchema)
    end
    if priorSchema < 3 then
        migratePartialMaterialOutputs(store, priorSchema)
    end
    if priorSchema < 4 then
        migrateEnactedProcesses(store, priorSchema)
    end
    if priorSchema < GRAPH_SCHEMA then
        store.schema = GRAPH_SCHEMA
    end

    return store
end

function GraphPersistence.bind()
    -- Shadow requests contain one world's process and owner revisions.  They
    -- are deliberately transient and cannot cross a ModData rebind.
    if SAO.CoordinationInference and SAO.CoordinationInference.reset then
        SAO.CoordinationInference.reset()
    end
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
        SAO.Organization.claimHistory = store.organization.claimHistory
        SAO.Organization.decisionHistory = store.organization.decisionHistory
        SAO.Organization.processes = store.organization.processes
        SAO.Organization.processOrder = store.organization.processOrder
        SAO.Organization.processMeta = store.organization.processMeta
        SAO.Organization.workReceipts = store.organization.workReceipts
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
