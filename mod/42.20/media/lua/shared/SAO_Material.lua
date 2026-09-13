-- SAO_Material.lua - stock, sharing, hoarding, trade, and conservation.

SAO = SAO or {}
SAO.Material = SAO.Material or {}
local Material = SAO.Material

Material.stores = Material.stores or {}

function Material.storeOf(id)
    if type(id) ~= "string" then return nil end
    return Material.stores[id] or nil
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
    store.items[item] = (store.items[item] or 0) + amount
    return true
end

function Material.take(id, item, amount)
    -- [C105] Taking from a store that does not exist takes nothing
    -- and creates nothing - no store comes to be by being read.
    if type(id) ~= "string" then return 0 end
    local store = Material.stores[id]
    if not store then return 0 end
    local available = store.items[item] or 0
    if available < amount then return 0 end
    store.items[item] = available - amount
    if store.items[item] <= 0 then store.items[item] = nil end
    return amount
end

function Material.share(fromId, toId, item, amount)
    if Material.take(fromId, item, amount) < amount then return false end
    Material.add(toId, item, amount)
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
