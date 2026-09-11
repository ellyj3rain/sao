-- SAO_PlaceAttachment - the live place-attachment state.
--
-- This is a state surface, not a behaviour. It reads the place facts the
-- county already holds - home, current building, known places, visits,
-- personal and group claims - and reports them together. Nothing here
-- writes a place, a claim, a belief or a record.

SAO = SAO or {}
SAO.PlaceAttachment = SAO.PlaceAttachment or {}
local A = SAO.PlaceAttachment

local function numberOr(value, fallback)
    if type(value) ~= "number" then return fallback end
    return value
end

function A.of(id)
    local rec = SAO.Identity and SAO.Identity.get
        and SAO.Identity.get(id) or nil
    if not rec or rec.dead then return nil end

    local known = {}
    pcall(function() known = SAO.Perception.knownPlaces(id) end)

    local knownCount, visitedCount = 0, 0
    local mostVisitedId, mostVisitedVisits, mostVisitedAt = nil, 0, nil
    for placeId, row in pairs(known or {}) do
        knownCount = knownCount + 1
        local visits = numberOr(row.visits, 0)
        if visits > 0 then visitedCount = visitedCount + 1 end
        if visits > 0
            and (visits > mostVisitedVisits
            or (visits == mostVisitedVisits
                and mostVisitedId ~= nil
                and tostring(placeId) < tostring(mostVisitedId))) then
            mostVisitedId = placeId
            mostVisitedVisits = visits
            mostVisitedAt = row.at
        end
    end

    local home = false
    local homePlaceId, homeDistance = nil, nil
    local homeKnown, homeVisits, homeOffers = false, 0, 0
    if rec.homeX and rec.homeY then
        home = true
        pcall(function()
            local place = SAO.Places.at(rec.homeX, rec.homeY)
            if place and place.id then homePlaceId = place.id end
        end)
        if rec.x and rec.y then
            homeDistance = math.sqrt(
                (rec.x - rec.homeX) ^ 2 + (rec.y - rec.homeY) ^ 2)
        end
        if homePlaceId and known[homePlaceId] then
            homeKnown = true
            homeVisits = numberOr(known[homePlaceId].visits, 0)
            for _ in pairs(known[homePlaceId].offers or {}) do
                homeOffers = homeOffers + 1
            end
        end
    end

    local currentPlaceId = nil
    pcall(function()
        local x, y = rec.x or rec.homeX, rec.y or rec.homeY
        if x and y then
            local place = SAO.Places.at(x, y)
            if place and place.id then currentPlaceId = place.id end
        end
    end)

    local personalClaim, groupClaim = false, false
    pcall(function()
        personalClaim = SAO.Standing.claimOf(id) ~= nil
    end)
    pcall(function()
        local group = SAO.Standing.groupOf(id)
        groupClaim = group ~= nil and SAO.Standing.groupClaimOf(group) ~= nil
    end)
    local claimKind = "none"
    if personalClaim then
        claimKind = "personal"
    elseif groupClaim then
        claimKind = "group"
    end

    local insideClaim = false
    pcall(function()
        local x, y = rec.x or rec.homeX, rec.y or rec.homeY
        if x and y then
            insideClaim = SAO.Standing.insideClaim(id, x, y)
        end
    end)

    local nowTick = nil
    pcall(function() nowTick = SAO.Controller.tick() end)
    local mostVisitedAge = nil
    if nowTick and mostVisitedAt then
        mostVisitedAge = nowTick - mostVisitedAt
    end

    local ground = claimKind ~= "none"
    local visited = visitedCount > 0
    local knownState = knownCount > 0
    local attachment = (
        (home and 1 or 0)
        + (ground and 1 or 0)
        + (visited and 1 or 0)
        + (knownState and 1 or 0)) / 4

    return {
        home = home,
        homePlaceId = homePlaceId,
        homeDistance = homeDistance,
        homeKnown = homeKnown,
        homeVisits = homeVisits,
        homeOffers = homeOffers,
        currentPlaceId = currentPlaceId,
        personalClaim = personalClaim,
        groupClaim = groupClaim,
        claimKind = claimKind,
        insideClaim = insideClaim,
        knownPlaces = knownCount,
        visitedPlaces = visitedCount,
        mostVisitedPlaceId = mostVisitedId,
        mostVisitedPlaceVisits = mostVisitedVisits,
        mostVisitedPlaceAge = mostVisitedAge,
        attachment = attachment,
    }
end

SAO.Log.line("PLACE", "place-attachment module loaded")
return A
