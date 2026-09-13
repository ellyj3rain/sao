-- SAO_Settlement.lua - group territory, occupancy, and material use.

SAO = SAO or {}
SAO.Settlement = SAO.Settlement or {}
local Settlement = SAO.Settlement

Settlement.bases = Settlement.bases or {}

function Settlement.scoreBuilding(building)
    if type(building) ~= "table" then return 0 end
    local rooms = tonumber(building.rooms) or 0
    local area = tonumber(building.area) or 0
    local water = building.water and 1 or 0
    local food = building.food and 1 or 0
    local tools = building.tools and 1 or 0
    return rooms * 2 + area * 0.1 + water * 3 + food * 2 + tools
end

function Settlement.claim(organizationId, building)
    if type(organizationId) ~= "string" or type(building) ~= "table" then
        return nil
    end
    local base = {
        organization = organizationId,
        building = building,
        score = Settlement.scoreBuilding(building),
        members = {},
        storage = {},
        claimedAt = 0,
    }
    Settlement.bases[organizationId] = base
    if SAO.Organization then
        SAO.Organization.createOrganization(
            organizationId, building, "localist")
    end
    return base
end

function Settlement.occupy(organizationId, personId)
    local base = Settlement.bases[organizationId]
    if not base then return false end
    base.members[personId] = true
    if SAO.Organization then
        SAO.Organization.join(organizationId, personId)
    end
    return true
end

function Settlement.leave(organizationId, personId)
    local base = Settlement.bases[organizationId]
    if not base then return false end
    base.members[personId] = nil
    if SAO.Organization then
        SAO.Organization.leave(organizationId, personId)
    end
    local count = 0
    for _ in pairs(base.members) do count = count + 1 end
    if count == 0 then
        Settlement.bases[organizationId] = nil
    end
    return true
end

function Settlement.store(organizationId, item, amount)
    local base = Settlement.bases[organizationId]
    if not base then return false end
    base.storage[item] = (base.storage[item] or 0) + amount
    return true
end

function Settlement.take(organizationId, item, amount)
    local base = Settlement.bases[organizationId]
    if not base then return 0 end
    local available = base.storage[item] or 0
    if available < amount then return 0 end
    base.storage[item] = available - amount
    if base.storage[item] <= 0 then base.storage[item] = nil end
    return amount
end

function Settlement.bestBase()
    local best, bestScore
    for _, base in pairs(Settlement.bases) do
        if not bestScore or base.score > bestScore then
            best, bestScore = base, base.score
        end
    end
    return best
end

return Settlement
