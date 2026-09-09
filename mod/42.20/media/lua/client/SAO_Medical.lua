-- SAO_Medical - what one person can tell by looking at another.
-- ---------------------------------------------------------------------------
-- `[C78]` gave a body a course to run and `[C79]` let the county catch
-- it, and neither is visible to anybody. A survivor sickens and dies
-- out there and the only trace is a line in the log.
--
-- This is the reading, and the whole design is in one rule: it reports
-- what THIS examiner could actually tell, not what the record knows.
-- DR-007 draws Knox on two ledgers - what the pathogen does, and what
-- anyone is permitted to know about it - and says never a percentage
-- on the forehead. `SAO_Inspect` is the panel that sees everything and
-- it says of itself that a window is not a pathway; this is the
-- opposite instrument, and the difference between them is the point.
--
-- WHAT GATES IT is the examiner's own First Aid, `Perks.Doctor`, which
-- is the skill vanilla already uses to decide how well somebody
-- dresses a wound and which `[B20]` already reads for exactly that.
-- Untrained, a person sees that something is wrong. Trained, they can
-- name it. Practised, they can say how far along it is. Only a real
-- medic can tell whether the body is winning, because that is a
-- judgement rather than a symptom.
--
-- Nothing here observes, tells, or moves standing. Reading a person
-- does not inform them and does not inform the county.
--
-- OFFLINE BY CONSTRUCTION: `readingOf` is a pure function of a record,
-- a skill number and the hour. The window is a renderer for it, and
-- the border runs the function without the window.

SAO = SAO or {}
SAO.Medical = SAO.Medical or {}
local Med = SAO.Medical

-- The tiers, named rather than numbered at the call sites, because a
-- bare `>= 5` in a branch is a decision nobody can argue with.
Med.CAN_NAME_IT = 2      -- a fever is a fever
Med.CAN_PLACE_IT = 5     -- early, or well along, or nearly through
Med.CAN_JUDGE_IT = 8     -- whether the body is actually winning

-- How far through the course they are, in words. A fraction would be a
-- percentage on the forehead with extra steps (DR-007).
local function howFarAlong(pos)
    if pos < 0.34 then return "It set in recently." end
    if pos < 0.72 then return "It is well along." end
    return "It is nearly through with them."
end

-- Whether the body is ahead of the course or behind it. `[C78]`'s
-- progress runs to 1 and the position runs to 1, so the two are
-- directly comparable and the comparison is the whole judgement.
local function whoIsWinning(progress, pos)
    if progress >= pos then
        return "Their body is holding it off."
    end
    if progress >= pos * 0.6 then
        return "Their body is fighting, and not keeping up."
    end
    return "They are losing."
end

---Lines an examiner of this skill could honestly give about this
---person, in the order a person would notice them.
---
---@param rec table the patient's record
---@param skill number the EXAMINER's First Aid level
---@param nowHours number the county's clock
---@return table lines, plain sentences
function Med.readingOf(rec, skill, nowHours)
    local out = {}
    if not rec then return out end
    skill = tonumber(skill) or 0

    if rec.dead then
        out[#out + 1] = "They are dead."
        return out
    end

    -- The obvious, which needs no training at all.
    if rec.woundInfected then
        out[#out + 1] = (skill >= Med.CAN_NAME_IT)
            and "A wound has gone septic."
            or "One of their wounds looks bad."
    end

    -- Derived from the day they last reached water, which is the fact
    -- the county actually produces ([B37]); there is no "days dry"
    -- field and inventing one here would put a second accounting of
    -- thirst beside the attrition pass's.
    local lastWater = tonumber(rec.lastWaterDay)
    if lastWater and nowHours then
        local dry = math.floor(nowHours / 24.0) - lastWater
        if dry >= 2 then
            out[#out + 1] = "They have not had anything to drink in days."
        end
    end

    if not rec.knoxInfected then
        if #out == 0 then
            out[#out + 1] = (skill >= Med.CAN_NAME_IT)
                and "Nothing obviously wrong with them."
                or "They look well enough to you."
        end
        return out
    end

    -- Infected. What can be said about it depends entirely on who is
    -- doing the looking.
    if skill < Med.CAN_NAME_IT then
        out[#out + 1] = "Something is wrong with them."
        out[#out + 1] = "You could not say what."
        return out
    end

    out[#out + 1] = "They are running a fever, and it is the bad kind."

    -- Only where the course has already been stamped. `positionOf`
    -- REPAIRS a missing span by writing one, and looking at somebody
    -- must not change them - this module's whole claim is that reading
    -- a person informs nothing, and a repair is a write like any other.
    if skill >= Med.CAN_PLACE_IT and SAO.Course
        and tonumber(rec.infectionSpanHours) then
        local pos = nil
        pcall(function()
            pos = SAO.Course.positionOf(rec, nowHours)
        end)
        if pos then
            out[#out + 1] = howFarAlong(pos)
            if skill >= Med.CAN_JUDGE_IT then
                out[#out + 1] = whoIsWinning(
                    tonumber(rec.immuneProgress) or 0, pos)
            end
        end
    end

    if (tonumber(rec.infectionsSurvived) or 0) > 0
        and skill >= Med.CAN_JUDGE_IT then
        out[#out + 1] = "They have come through this before."
    end

    return out
end

---The examiner's own First Aid, read off the player. Behind pcall
---because every engine read in this tree is.
function Med.skillOf(playerObj)
    local n = 0
    pcall(function()
        n = playerObj:getPerkLevel(Perks.Doctor) or 0
    end)
    return tonumber(n) or 0
end

return Med
