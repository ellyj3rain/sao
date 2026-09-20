-- SAO_Material.lua - stock, sharing, hoarding, trade, and conservation.

SAO = SAO or {}
SAO.Material = SAO.Material or {}
local Material = SAO.Material

Material.stores = Material.stores or {}
Material.reconciliations = Material.reconciliations or {}
Material.sourceOwners = Material.sourceOwners or {}

local SOURCE_CATEGORY_ORDER = {
    "device", "drink", "food", "fuel", "instrument", "medical",
    "memento", "nails", "plank", "reading", "smokes", "tools",
    "water", "weapons",
}
local MAX_NATIVE_SOURCES = 256

function Material.storeOf(id)
    if type(id) ~= "string" then return nil end
    return Material.stores[id] or nil
end

local function copyScalarMap(value)
    local copy = {}
    if type(value) ~= "table" then return copy end
    for key, item in pairs(value) do
        local kind = type(item)
        if kind == "string" or kind == "number" or kind == "boolean" then
            copy[key] = item
        end
    end
    return copy
end

local function accessStore(store, personId)
    if type(store) ~= "table" then return nil end
    return {
        owner = store.owner,
        accessibleBy = personId,
        projection = store.projection,
        items = copyScalarMap(store.items),
        claims = copyScalarMap(store.claims),
        categories = copyScalarMap(store.categories),
    }
end

-- A group member reads the house projection produced from native sources.
-- Ungrouped people retain their personal store surface for old saves and later
-- person-inventory work. Every returned map is detached: graph readers may
-- inspect this access view but cannot mutate either durable owner around the
-- guarded Material APIs. This resolver never creates either kind of store.
function Material.storeForPerson(id)
    if type(id) ~= "string" then return nil end
    local options = SandboxVars and SandboxVars.SurvivorAwareness or nil
    if options and options.Material == false then return nil end
    local personal = Material.stores[id]
    local group = SAO.Standing and SAO.Standing.groupOf
        and SAO.Standing.groupOf(id) or nil
    if group then
        local house = Material.stores["house:" .. tostring(group)]
        if house and personal then
            -- Keep personal and shared material distinct while presenting the
            -- graph/labor readers with one derived view. Neither owner is
            -- mutated or hidden by this temporary composition.
            local personalView = accessStore(personal, id)
            local houseView = accessStore(house, id)
            local view = {
                accessibleBy = id,
                projection = "person-and-house",
                personal = personalView,
                house = houseView,
                items = {}, claims = {}, categories = {},
            }
            for item, amount in pairs(personalView.items) do
                view.items[item] = (view.items[item] or 0) + amount
            end
            for item, amount in pairs(houseView.items) do
                view.items[item] = (view.items[item] or 0) + amount
            end
            for item, claim in pairs(personalView.claims) do
                view.claims[item] = claim
            end
            for item, claim in pairs(houseView.claims) do
                if view.claims[item] == nil then view.claims[item] = claim end
            end
            for category, amount in pairs(personalView.categories) do
                view.categories[category] = (view.categories[category] or 0)
                    + amount
            end
            for category, amount in pairs(houseView.categories) do
                view.categories[category] = (view.categories[category] or 0)
                    + amount
            end
            return view
        end
        if house then
            local houseView = accessStore(house, id)
            return {
                owner = nil,
                accessibleBy = id,
                projection = "house-access",
                personal = nil,
                house = houseView,
                items = copyScalarMap(houseView.items),
                claims = copyScalarMap(houseView.claims),
                categories = copyScalarMap(houseView.categories),
            }
        end
    end
    return accessStore(personal, id)
end

local function ensureStore(id)
    if type(id) ~= "string" then return nil end
    if not Material.stores[id] then
        Material.stores[id] = {
            owner = id,
            items = {},
            claims = {},
        }
    end
    return Material.stores[id]
end

function Material.add(id, item, amount)
    local store = ensureStore(id)
    if not store then return false end
    -- Native house projections change only when an observed source changes.
    -- Abstract additions would diverge from the engine inventory immediately.
    if store.projection == "native-sources" then return false end
    store.items[item] = (store.items[item] or 0) + amount
    return true
end

function Material.take(id, item, amount)
    -- [C105] Taking from a store that does not exist takes nothing
    -- and creates nothing - no store comes to be by being read.
    if type(id) ~= "string" then return 0 end
    local store = Material.stores[id]
    if not store then return 0 end
    if store.projection == "native-sources" then return 0 end
    local available = store.items[item] or 0
    if available < amount then return 0 end
    store.items[item] = available - amount
    if store.items[item] <= 0 then store.items[item] = nil end
    return amount
end

local function itemQuantity(item)
    local amount = tonumber(item and item.amount) or 0
    if amount > 0 then return amount end
    local uses = tonumber(item and item.uses) or 0
    if uses > 0 then return uses end
    return 1
end

local function sourceCopy(source, receipt)
    local copy = {
        id = tostring(source.id),
        fingerprint = source.fingerprint,
        revision = source.revision,
        kind = source.kind,
        x = source.x, y = source.y, z = source.z,
        buildingId = source.buildingId,
        state = source.state,
        access = source.access,
        observedAt = source.observedAt,
        provenance = source.provenance,
        placeId = receipt.placeId,
        resultId = receipt.reservationId,
        resultAt = receipt.at,
        resultOrder = receipt.order,
        quantities = {}, items = {}, itemOrder = {},
    }
    for _, category in ipairs(SOURCE_CATEGORY_ORDER) do
        local quantity = tonumber(source.quantities
            and source.quantities[category]) or 0
        if quantity > 0 then copy.quantities[category] = quantity end
    end
    for _, itemKey in ipairs(source.itemOrder or {}) do
        local item = source.items and source.items[itemKey] or nil
        if item then
            local categories = {}
            for _, category in ipairs(SOURCE_CATEGORY_ORDER) do
                if item.categories and item.categories[category] then
                    categories[category] = true
                end
            end
            local key = tostring(item.id)
            copy.items[key] = {
                id = item.id,
                type = item.type,
                uses = item.uses,
                amount = item.amount,
                fluid = item.fluid,
                poison = item.poison and true or false,
                rotten = item.rotten and true or false,
                categories = categories,
            }
            copy.itemOrder[#copy.itemOrder + 1] = key
        end
    end
    return copy
end

local function rebuildProjection(store)
    local items, categories = {}, {}
    for _, source in pairs(store.nativeSources or {}) do
        for _, category in ipairs(SOURCE_CATEGORY_ORDER) do
            local quantity = tonumber(source.quantities
                and source.quantities[category]) or 0
            if quantity > 0 then
                categories[category] = (categories[category] or 0) + quantity
            end
        end
        for _, itemKey in ipairs(source.itemOrder or {}) do
            local item = source.items and source.items[itemKey] or nil
            if item and type(item.type) == "string" and item.type ~= "" then
                items[item.type] = (items[item.type] or 0) + itemQuantity(item)
            end
        end
    end
    store.items = items
    store.categories = categories
end

local function rebuildAndAdvance(store)
    rebuildProjection(store)
    store.projectionGeneration = (tonumber(store.projectionGeneration) or 0) + 1
    return store.projectionGeneration
end

local function trimNativeSources(store)
    local count = 0
    for _ in pairs(store.nativeSources or {}) do count = count + 1 end
    local removed = {}
    while count > MAX_NATIVE_SOURCES do
        local oldestId, oldest = nil, nil
        for sourceId, source in pairs(store.nativeSources) do
            local before = not oldest
                or (tonumber(source.resultOrder) or 0)
                    < (tonumber(oldest.resultOrder) or 0)
                or ((tonumber(source.resultOrder) or 0)
                    == (tonumber(oldest.resultOrder) or 0)
                    and tostring(sourceId) < tostring(oldestId))
            if before then oldestId, oldest = sourceId, source end
        end
        if not oldestId then break end
        store.nativeSources[oldestId] = nil
        removed[#removed + 1] = oldestId
        count = count - 1
    end
    return removed
end

local function stampResult(store, receipt)
    store.lastResult = {
        reservationId = receipt.reservationId,
        actorId = receipt.actorId,
        sourceId = receipt.sourceId,
        sourceFingerprint = receipt.sourceFingerprint,
        category = receipt.category,
        quantity = receipt.quantity,
        placeId = receipt.placeId,
        postRevision = receipt.postRevision,
        at = receipt.at,
        order = receipt.order,
    }
end

local function sameProjectedPlace(prior, source)
    return prior and source
        and tostring(prior.fingerprint or "")
            == tostring(source.fingerprint or "")
        and tonumber(prior.x) == tonumber(source.x)
        and tonumber(prior.y) == tonumber(source.y)
        and tonumber(prior.z) == tonumber(source.z)
end

local function affectedStores(transaction)
    local out = {}
    for groupId, generation in pairs(transaction.groups or {}) do
        local projection = {
            groupId = groupId,
            store = Material.stores["house:" .. groupId],
            generation = tonumber(generation),
            evidenceAt = tonumber(transaction.evidenceAt),
        }
        if projection.store then
            projection.generation = projection.generation
                or tonumber(projection.store.projectionGeneration) or 0
            local at = #out + 1
            while at > 1 and out[at - 1].groupId > groupId do
                out[at] = out[at - 1]
                at = at - 1
            end
            out[at] = projection
        end
    end
    return out
end

local function indexedOwner(sourceId)
    local owner = Material.sourceOwners[tostring(sourceId or "")]
    if type(owner) ~= "table" then return nil, nil, nil end
    local groupId = tostring(owner.groupId or "")
    local store = groupId ~= ""
        and Material.stores["house:" .. groupId] or nil
    local prior = store and store.nativeSources
        and store.nativeSources[tostring(sourceId or "")] or nil
    if not prior or tostring(prior.fingerprint or "")
        ~= tostring(owner.fingerprint or "") then
        Material.sourceOwners[tostring(sourceId or "")] = nil
        return nil, nil, nil
    end
    return owner, store, prior
end

function Material.projectedOwner(sourceId, fingerprint)
    local owner = indexedOwner(sourceId)
    if not owner then return nil end
    if fingerprint ~= nil and tostring(owner.fingerprint or "")
        ~= tostring(fingerprint) then
        return nil
    end
    return tostring(owner.groupId)
end

function Material.houseProjectionGeneration(groupId)
    local store = Material.stores["house:" .. tostring(groupId or "")]
    return store and (tonumber(store.projectionGeneration) or 0) or 0
end

local function clearTrimmedOwners(groupId, removed)
    for _, sourceId in ipairs(removed or {}) do
        local owner = Material.sourceOwners[sourceId]
        if owner and tostring(owner.groupId or "") == groupId then
            Material.sourceOwners[sourceId] = nil
        end
    end
end

-- Reconcile one exact physical source across every house projection. A held
-- group receives the current source and prior owners lose it. Personal use
-- grants no new owner, but it refreshes an existing owner at the same physical
-- place so an outsider's consumption cannot leave stale house stock. The
-- durable transaction retains every affected house until their derived
-- Standing/Settlement projections have all succeeded.
function Material.reconcileSource(groupId, receipt, source, context, outcome)
    groupId = groupId and tostring(groupId) or nil
    if groupId == "" then groupId = nil end
    local receiptGroup = receipt and receipt.provisioningGroup
        and tostring(receipt.provisioningGroup) or nil
    if receiptGroup == "" then receiptGroup = nil end
    context = tostring(context or receipt and receipt.provisioningContext or "")
    if type(receipt) ~= "table" or receipt.status ~= "completed"
        or type(receipt.reservationId) ~= "string"
        or type(receipt.sourceId) ~= "string"
        or type(receipt.sourceFingerprint) ~= "string"
        or receipt.sourceFingerprint == "" then
        return false, nil, nil
    end
    if (context == "held-group" and (not groupId or receiptGroup ~= groupId))
        or (context ~= "held-group" and context ~= "personal"
            and context ~= "retired-group")
        or (context ~= "held-group" and groupId ~= nil) then
        return false, nil, nil
    end
    if source and (tostring(source.id) ~= receipt.sourceId
        or source.state == "conflicted"
        or tostring(source.fingerprint or "")
            ~= receipt.sourceFingerprint) then
        return false, nil, nil
    end

    local transaction = Material.reconciliations[receipt.reservationId]
        or { groups = {} }
    transaction.groups = transaction.groups or {}
    transaction.derivations = transaction.derivations or {}
    transaction.sourceId = receipt.sourceId
    transaction.sourceFingerprint = receipt.sourceFingerprint
    transaction.outcome = outcome or transaction.outcome
    transaction.evidenceAt = transaction.evidenceAt
        or tonumber(receipt.materialEvidenceAt)
        or tonumber(source and source.observedAt)
        or tonumber(receipt.at) or 0
    Material.reconciliations[receipt.reservationId] = transaction
    if transaction.applied == true then
        local target = groupId and Material.stores["house:" .. groupId] or nil
        return true, target, affectedStores(transaction)
    end

    local owner, ownerStore, prior = indexedOwner(receipt.sourceId)
    local receiptOrder = tonumber(receipt.order) or 0
    local ownerOrder = owner and (tonumber(owner.resultOrder)
        or tonumber(prior and prior.resultOrder) or 0) or 0
    if owner and ownerOrder > receiptOrder then
        -- Round-robin delivery prevents starvation across sources, so an older
        -- receipt for this source may arrive after a newer one. Its physical
        -- fact is already superseded, so it cannot refresh, move or remove
        -- current ownership or any derived settlement evidence.
        transaction.applied = true
        transaction.context = context
        transaction.superseded = true
        return true, nil, {}
    end

    local keepOwner = context == "personal" and source
        and sameProjectedPlace(prior, source)
    if owner and keepOwner then
        ownerStore.nativeSources[receipt.sourceId] = sourceCopy(source, receipt)
        local generation = rebuildAndAdvance(ownerStore)
        transaction.groups[tostring(owner.groupId)] = generation
        stampResult(ownerStore, receipt)
        Material.sourceOwners[receipt.sourceId] = {
            groupId = tostring(owner.groupId),
            fingerprint = receipt.sourceFingerprint,
            resultOrder = receiptOrder,
        }
    elseif owner and (source ~= nil
        or tostring(owner.fingerprint or "") == receipt.sourceFingerprint) then
        ownerStore.nativeSources[receipt.sourceId] = nil
        local generation = rebuildAndAdvance(ownerStore)
        transaction.groups[tostring(owner.groupId)] = generation
        stampResult(ownerStore, receipt)
        Material.sourceOwners[receipt.sourceId] = nil
    end

    local provedEmpty = (source and source.state == "spent")
        or (not source and receipt.sourceKind == "ground")
    local targetId = groupId and ("house:" .. groupId) or nil
    local target = targetId and ((source or provedEmpty) and ensureStore(targetId)
        or Material.stores[targetId]) or nil
    if target then
        target.projection = "native-sources"
        target.nativeSources = target.nativeSources or {}
        local targetPrior = target.nativeSources[receipt.sourceId]
        local targetChanged = false
        if source and source.state == "available" then
            target.nativeSources[receipt.sourceId] = sourceCopy(source, receipt)
            Material.sourceOwners[receipt.sourceId] = {
                groupId = groupId,
                fingerprint = receipt.sourceFingerprint,
                resultOrder = receiptOrder,
            }
            targetChanged = true
        elseif targetPrior and tostring(targetPrior.fingerprint or "")
            == receipt.sourceFingerprint then
            target.nativeSources[receipt.sourceId] = nil
            local indexed = Material.sourceOwners[receipt.sourceId]
            if indexed and tostring(indexed.groupId or "") == groupId
                and tostring(indexed.fingerprint or "")
                    == receipt.sourceFingerprint then
                Material.sourceOwners[receipt.sourceId] = nil
            end
            targetChanged = true
        elseif provedEmpty then
            -- Exhausting a first observed source is still a material result.
            -- Keep the empty projection so derived claims clear stale stock.
            targetChanged = true
        end
        if targetChanged then
            local removed = trimNativeSources(target)
            clearTrimmedOwners(groupId, removed)
            local generation = rebuildAndAdvance(target)
            transaction.groups[groupId] = generation
            stampResult(target, receipt)
        end
    end
    transaction.applied = true
    transaction.context = context
    return true, target, affectedStores(transaction)
end

function Material.derivationComplete(reservationId, groupId, phase)
    local transaction = Material.reconciliations[tostring(reservationId or "")]
    local derivation = type(transaction) == "table"
        and type(transaction.derivations) == "table"
        and transaction.derivations[tostring(groupId or "")] or nil
    return type(derivation) == "table" and derivation[phase] == true
end

function Material.markDerivationComplete(reservationId, groupId, phase)
    reservationId, groupId = tostring(reservationId or ""),
        tostring(groupId or "")
    local transaction = Material.reconciliations[reservationId]
    if reservationId == "" or groupId == "" or type(transaction) ~= "table"
        or transaction.applied ~= true or not transaction.groups[groupId]
        or (phase ~= "standing" and phase ~= "recognition") then
        return false
    end
    transaction.derivations = transaction.derivations or {}
    local derivation = transaction.derivations[groupId] or {}
    derivation[phase] = true
    transaction.derivations[groupId] = derivation
    return true
end

function Material.resumeReconciliation(reservationId)
    local transaction = Material.reconciliations[tostring(reservationId or "")]
    if type(transaction) ~= "table" or transaction.applied ~= true then
        return false, nil, nil
    end
    return true, affectedStores(transaction), transaction.outcome
end

function Material.finishReconciliation(reservationId)
    reservationId = tostring(reservationId or "")
    if reservationId == "" or not Material.reconciliations[reservationId] then
        return false
    end
    Material.reconciliations[reservationId] = nil
    return true
end

function Material.forgetHouse(groupId)
    groupId = tostring(groupId or "")
    if groupId == "" then return false end
    local store = Material.stores["house:" .. groupId]
    for sourceId in pairs(store and store.nativeSources or {}) do
        local owner = Material.sourceOwners[sourceId]
        if owner and tostring(owner.groupId or "") == groupId then
            Material.sourceOwners[sourceId] = nil
        end
    end
    Material.stores["house:" .. groupId] = nil
    for _, transaction in pairs(Material.reconciliations) do
        if transaction.groups then transaction.groups[groupId] = nil end
        if transaction.derivations then
            transaction.derivations[groupId] = nil
        end
    end
    return true
end

function Material.share(fromId, toId, item, amount)
    if Material.take(fromId, item, amount) < amount then return false end
    if not Material.add(toId, item, amount) then
        Material.add(fromId, item, amount)
        return false
    end
    return true
end

function Material.conserve(id, item)
    local store = ensureStore(id)
    if not store then return false end
    store.claims[item] = "conserve"
    return true
end

function Material.hoard(id, item)
    local store = ensureStore(id)
    if not store then return false end
    store.claims[item] = "hoard"
    return true
end

function Material.trade(fromId, toId, giveItem, giveAmount,
                        wantItem, wantAmount)
    if Material.take(fromId, giveItem, giveAmount) < giveAmount then
        return false
    end
    if Material.take(toId, wantItem, wantAmount) < wantAmount then
        Material.add(fromId, giveItem, giveAmount)
        return false
    end
    Material.add(toId, giveItem, giveAmount)
    Material.add(fromId, wantItem, wantAmount)
    return true
end

-- [C105] The dead keep no stores. The corpse's actual items belong to
-- the engine's body; this table is the county's model of what a
-- LIVING person holds in the provisioning economy, and no trade ever
-- asks a grave. Reached from `Identity.markDead` with the rest of the
-- death funnel's forgets.
function Material.forget(id)
    if type(id) ~= "string" then return false end
    Material.stores[id] = nil
    return true
end

return Material
