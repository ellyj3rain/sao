-- SAO_Appearance - age you can see.
--
-- [B38]. The operator ruled a visible age gradient important - age
-- that can be seen, not just stored.
--
-- [B37] gave everybody an age. [B38] made it read - a unit's
-- relations fall out of it. Both are invisible from inside the game:
-- a sixty-two year old and a twenty-two year old stand in the road
-- looking identical, so the gradient exists and the player cannot
-- perceive any of it.
--
-- Hair is the honest place to put it. Every accessor here is a public
-- method on a shipped class, javap-verified:
--
--     body:getHumanVisual()                 -> displayed HumanVisual
--     body:getDescriptor():getHumanVisual() -> constructor source
--     visual:getNaturalHairColor()          -> ImmutableColor
--     visual:setHairColor(ImmutableColor)
--     visual:getNaturalBeardColor() / setBeardColor
--     ImmutableColor.new(r, g, b)
--
-- The NATURAL colour is never written. Only the displayed one moves,
-- so what a person's hair actually was is still there underneath.

SAO = SAO or {}
SAO.Appearance = SAO.Appearance or {}
local A = SAO.Appearance

-- Not white. Grey hair reads as a desaturated version of no colour at
-- all, and pure white on a model in a wheat field looks like a bug.
local GREY = { r = 0.78, g = 0.77, b = 0.74 }

-- When it starts and how long it takes, per person.
--
-- Greying is not a birthday. It begins somewhere in the late twenties
-- to late forties depending entirely on who you are, and takes a
-- couple of decades to finish - which is why a room of fifty year
-- olds contains one head of grey and one still dark. The onset is
-- drawn from the same hash everything else about a person is drawn
-- from, so it is a fact about them rather than a roll at render time.
local ONSET_MIN = 28
local ONSET_SPAN = 21          -- 28..48
local TAKES_YEARS = 30
-- Nobody goes fully grey. There is always some left.
local GREYEST = 0.90

local function hashOf(id, salt)
    -- [B48] Kahlua's numbers are doubles and the FNV step
    -- overflowed the mantissa, collapsing this to a handful of
    -- values. One implementation now, computed exactly.
    return SAO.Hash.of(id, salt)
end

function A.onsetFor(id)
    return ONSET_MIN + (hashOf(id, "grey") % ONSET_SPAN)
end

-- How grey this person is, 0 to GREYEST.
function A.greyness(id, age)
    if not age then return 0 end
    local onset = A.onsetFor(id)
    if age <= onset then return 0 end
    local frac = (age - onset) / TAKES_YEARS
    if frac > GREYEST then frac = GREYEST end
    return frac
end

local function blend(colour, frac, channel)
    local base = colour and colour[channel] or nil
    if base == nil then return nil end
    return base + (GREY[channel] - base) * frac
end

local function channels(colour)
    if not colour then return nil end
    local r, g, b
    local ok = pcall(function()
        r = colour:getRedFloat()
        g = colour:getGreenFloat()
        b = colour:getBlueFloat()
    end)
    if not ok or type(r) ~= "number" or type(g) ~= "number"
        or type(b) ~= "number" then return nil end
    return { r = r, g = g, b = b }
end

local function sameColour(a, b)
    return a and b and math.abs(a.r - b.r) <= 0.01
        and math.abs(a.g - b.g) <= 0.01
        and math.abs(a.b - b.b) <= 0.01
end

-- Recompute only when the displayed colour is natural or the last age-owned
-- colour. A later dye or restored custom colour remains the person's choice.
local function greyOne(visual, getNatural, getDisplayed, setDisplayed, frac, previous)
    local natural, displayed
    local read = pcall(function()
        natural = visual[getNatural](visual)
        displayed = visual[getDisplayed](visual)
    end)
    if not read then return false, nil, false end
    local base = channels(natural)
    if not base then return false, nil, false end
    local current = channels(displayed)
    if displayed and not current then return false, nil, false end
    local nr = blend(base, frac, "r")
    local ng = blend(base, frac, "g")
    local nb = blend(base, frac, "b")
    local target = { r = nr, g = ng, b = nb }
    if current and not sameColour(current, base)
        and not sameColour(current, previous)
        and not sameColour(current, target) then return false, nil, false end
    if current and sameColour(current, target) then return false, target, true end
    if not current and frac == 0 then return false, target, true end
    local applied = false
    pcall(function()
        visual[setDisplayed](visual, ImmutableColor.new(nr, ng, nb))
        applied = true
    end)
    return applied, applied and target or nil, applied
end

local function syncDisplay(body, visual)
    local descriptorVisual
    pcall(function() descriptorVisual = body:getDescriptor():getHumanVisual() end)
    if not descriptorVisual or descriptorVisual == visual then return end
    for _, names in ipairs({
        { "getHairModel", "setHairModel" },
        { "getBeardModel", "setBeardModel" },
        { "getHairColor", "setHairColor" },
        { "getBeardColor", "setBeardColor" },
    }) do
        pcall(function()
            local value = visual[names[1]](visual)
            if value ~= nil then descriptorVisual[names[2]](descriptorVisual, value) end
        end)
    end
end

-- [C31] A child's head (Growing Up's rule, CREDITS.md): no beard, and
-- none of the styles no child wears - the bald, the balding and
-- receding, the mohawks and spikes, the mullet - replaced by one from
-- a pool of ordinary cuts, chosen by the person's own hash so it is
-- the same head every time. Every name below is a style the game's
-- own HairOutfitDefinitions.lua declares; the accessors are javap-
-- verified on HumanVisual (getHairModel/setHairModel, getBeardModel/
-- setBeardModel) and IsoGameCharacter (resetBeardGrowingTime).
local BANNED_FOR_CHILDREN = {
    Bald = true, Baldspot = true, Picard = true, Recede = true,
    LibertySpikes = true, MohawkFan = true, MohawkShort = true,
    MohawkSpike = true, MohawkFlat = true, Mullet = true,
}
local CHILD_HAIR = { "Short", "Messy", "MessyCurly", "CentreParting",
                     "LeftParting", "RightParting", "CrewCut", "Fresh",
                     "Cornrows", "ShortAfroCurly", "FlatTop" }

-- Returns true when something on the head changed.
function A.applyChildhood(rec, body, visual)
    local changed = false
    pcall(function()
        local beard = visual:getBeardModel()
        if beard and beard ~= "" then
            visual:setBeardModel("")
            pcall(function() body:resetBeardGrowingTime() end)
            changed = true
        end
    end)
    pcall(function()
        local hair = visual:getHairModel()
        if hair and BANNED_FOR_CHILDREN[hair] then
            visual:setHairModel(
                CHILD_HAIR[(hashOf(rec.id, "child-hair") % #CHILD_HAIR) + 1])
            changed = true
        end
    end)
    return changed
end

-- Put a survivor's age on the actual native body. A restored snapshot can
-- carry a later dye or changed cut, so only age-owned colour is recomputed.
function A.applyAge(rec, body)
    if not rec or not body then return false end
    local age = nil
    pcall(function() age = SAO.History.ageOf(rec.id) end)
    if not age then return false end
    local visual = nil
    pcall(function() visual = body:getHumanVisual() end)
    if not visual then return false end

    local childChanged = false
    if visual and age < 18 then
        childChanged = A.applyChildhood(rec, body, visual)
    end

    local frac = A.greyness(rec.id, age)
    local prior = type(rec.appearanceGrey) == "table"
        and rec.appearanceGrey or nil
    local hairChanged, hairTarget, hairOwned = greyOne(visual,
        "getNaturalHairColor", "getHairColor", "setHairColor", frac,
        prior and prior.hair)
    -- A beard greys with the hair. Its natural colour is never changed.
    local beardChanged, beardTarget, beardOwned = greyOne(visual,
        "getNaturalBeardColor", "getBeardColor", "setBeardColor", frac,
        prior and prior.beard)
    if hairOwned or beardOwned then
        rec.appearanceGrey = prior or { version = 1 }
        if hairOwned then rec.appearanceGrey.hair = hairTarget end
        if beardOwned then rec.appearanceGrey.beard = beardTarget end
        rec.appearanceGrey.fraction = frac
        rec.greyApplied = true -- Retained historical marker; no longer a render gate.
    end
    local did = hairChanged or beardChanged
    syncDisplay(body, visual)
    if did or childChanged then
        pcall(function() body:resetModelNextFrame() end)
    end
    return did or childChanged
end

SAO.Log.line("LOOK", "appearance module loaded (age reaches the head)")

return A
