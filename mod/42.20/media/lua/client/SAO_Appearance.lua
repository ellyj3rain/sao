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
--     body:getDescriptor()                  -> SurvivorDesc
--     desc:getHumanVisual()                 -> HumanVisual
--     visual:getNaturalHairColor()          -> ImmutableColor
--     visual:setHairColor(ImmutableColor)
--     visual:getNaturalBeardColor() / setBeardColor
--     ImmutableColor.new(r, g, b)
--
-- The NATURAL colour is never written. Only the displayed one moves,
-- so what a person's hair actually was is still there underneath and
-- this is reversible by doing nothing.

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

-- Move ONE colour toward grey. Returns true when it was applied.
local function greyOne(visual, getNatural, setDisplayed, frac)
    local natural = nil
    pcall(function() natural = visual[getNatural](visual) end)
    if not natural then return false end
    local r, g, b
    local ok = pcall(function()
        r = natural:getRedFloat()
        g = natural:getGreenFloat()
        b = natural:getBlueFloat()
    end)
    if not ok or r == nil then return false end
    local mixed = { r = r, g = g, b = b }
    local nr = blend(mixed, frac, "r")
    local ng = blend(mixed, frac, "g")
    local nb = blend(mixed, frac, "b")
    if nr == nil then return false end
    local applied = false
    pcall(function()
        visual[setDisplayed](visual, ImmutableColor.new(nr, ng, nb))
        applied = true
    end)
    return applied
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

-- Put a survivor's age on their head. Called when a body exists to
-- carry it: the grey once per person, the child's head every time
-- (a restored snapshot can bring a style back).
function A.applyAge(rec, body)
    if not rec or not body then return false end
    local age = nil
    pcall(function() age = SAO.History.ageOf(rec.id) end)
    if not age then return false end
    local visual = nil
    pcall(function() visual = body:getDescriptor():getHumanVisual() end)

    local childChanged = false
    if visual and age < 18 then
        childChanged = A.applyChildhood(rec, body, visual)
    end

    local did = false
    if not rec.greyApplied then
        local frac = A.greyness(rec.id, age)
        -- Somebody too young for it is not a failure, and marking them
        -- done stops this being asked again every time they materialise.
        if frac <= 0 then
            rec.greyApplied = true
        elseif visual then
            did = greyOne(visual, "getNaturalHairColor", "setHairColor", frac)
            -- A beard greys with the hair and often before it. Not
            -- everyone has one; a missing beard colour is not a failure.
            greyOne(visual, "getNaturalBeardColor", "setBeardColor", frac)
            if did then rec.greyApplied = true end
        end
    end

    if did or childChanged then
        pcall(function() body:resetModelNextFrame() end)
    end
    return did or childChanged
end

SAO.Log.line("LOOK", "appearance module loaded (age reaches the head)")

return A
