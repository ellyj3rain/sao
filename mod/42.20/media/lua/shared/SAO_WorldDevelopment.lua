-- SAO_WorldDevelopment - the live world-development state.
--
-- This is a state surface, not a behaviour. It reads the facts the county
-- already holds - home, ground, larder, water, hearth, motor pool and
-- fortification - and reports them together. Nothing here builds, stocks,
-- claims or boards anything.

SAO = SAO or {}
SAO.WorldDevelopment = SAO.WorldDevelopment or {}
local W = SAO.WorldDevelopment

function W.of(id)
    local rec = SAO.Identity and SAO.Identity.get
        and SAO.Identity.get(id) or nil
    if not rec or rec.dead then return nil end

    local attachment = SAO.PlaceAttachment and SAO.PlaceAttachment.of
        and SAO.PlaceAttachment.of(id) or nil
    local home = attachment and attachment.home or false
    local ground = attachment and attachment.claimKind ~= "none"

    local group = nil
    pcall(function() group = SAO.Standing.groupOf(id) end)

    local larder, water, hearth, motor = nil, nil, nil, nil
    if group then
        pcall(function() larder = SAO.Standing.larderOf(group) end)
        pcall(function() water = SAO.Standing.waterStoreOf(group) end)
        pcall(function() hearth = SAO.Standing.hearthOf(group) end)
        pcall(function() motor = SAO.Standing.motorPoolOf(group) end)
    end

    local boarded = tonumber(rec.boardedAtHome) or 0
    local waysIn = tonumber(rec.waysIntoHome) or 0
    local fortified = boarded > 0

    local larderStocked = larder ~= nil
    local waterStocked = water ~= nil
    local hearthPresent = hearth ~= nil
    local transport = motor ~= nil

    local development = (
        (home and 1 or 0)
        + (ground and 1 or 0)
        + (larderStocked and 1 or 0)
        + (waterStocked and 1 or 0)
        + (hearthPresent and 1 or 0)
        + (transport and 1 or 0)
        + (fortified and 1 or 0)) / 7

    return {
        group = group,
        home = home,
        ground = ground,
        homePlaceId = attachment and attachment.homePlaceId or nil,
        homeDistance = attachment and attachment.homeDistance or nil,
        homeKnown = attachment and attachment.homeKnown or false,
        homeVisits = attachment and attachment.homeVisits or 0,
        homeOffers = attachment and attachment.homeOffers or 0,
        knownPlaces = attachment and attachment.knownPlaces or 0,
        visitedPlaces = attachment and attachment.visitedPlaces or 0,
        larder = larderStocked,
        larderWord = larder and larder.word or nil,
        larderCount = larder and larder.count or 0,
        water = waterStocked,
        waterWord = water and water.word or nil,
        waterUnits = water and water.units or 0,
        hearth = hearthPresent,
        hearthBurning = hearth and hearth.burning or false,
        motorPool = transport,
        motorCars = motor and #(motor.cars or {}) or 0,
        waysIntoHome = waysIn,
        boardedAtHome = boarded,
        fortified = fortified,
        development = development,
    }
end

SAO.Log.line("WORLD", "world-development module loaded")
return W
