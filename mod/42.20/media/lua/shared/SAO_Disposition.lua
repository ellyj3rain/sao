-- SAO_Disposition — the Disposition pillar (ARCHITECTURE §Disposition).
-- ---------------------------------------------------------------------------
-- Converts a belief set into a preference ordering under risk. Owns nerve,
-- discipline, aggression, initiative, self-preservation. Does not manufacture
-- facts (only Perception queries enter) and does not grant permission (that
-- is Standing). Bounded by the human envelope: low traits mean hesitant,
-- early-withdrawing, imprecise — never behavior no person would produce.
--
-- Traits are deterministic per survivor id (stable across sessions without
-- storing anything) in [0.15, 0.85]: nobody is a statue and nobody is a
-- machine — the envelope's floor and ceiling, not balance numbers.

SAO = SAO or {}
SAO.Disposition = SAO.Disposition or {}
local D = SAO.Disposition

local function hash(id, salt)
    -- [B48] Kahlua's numbers are doubles and the FNV step
    -- overflowed the mantissa, collapsing this to a handful of
    -- values. One implementation now, computed exactly.
    return SAO.Hash.unit(id, salt)
end

local function trait(id, name)
    local value = 0.15 + hash(id, name) * 0.70
    -- The lived past echoes into who a person is now ([A14] S1): formative
    -- events shift traits, bounded inside the human envelope - history
    -- bends a person, never breaks the species. Applied at the primitive
    -- so EVERY consumer feels it.
    local rec = SAO.Identity and SAO.Identity.get and SAO.Identity.get(id) or nil
    local echo = rec and rec.traitEchoes and rec.traitEchoes[name] or 0
    local learned = rec and rec.lessonEchoes and rec.lessonEchoes[name] or 0
    -- [C32] A condition bends an axis the way the past does, inside
    -- the same envelope (SAO_Conditions.bend: a low spell, a scattered
    -- day, the anxious). Zero for everyone without one.
    local carried = 0
    pcall(function() carried = SAO.Conditions.bend(id, name) end)
    if type(carried) ~= "number" then carried = 0 end
    if echo ~= 0 or learned ~= 0 or carried ~= 0 then
        value = math.max(0.15, math.min(0.85, value + echo + learned + carried))
    end
    return value
end

function D.traits(id)
    return {
        nerve = trait(id, "nerve"),                       -- composure under threat
        discipline = trait(id, "discipline"),             -- sticks to current action
        aggression = trait(id, "aggression"),             -- willingness to engage
        initiative = trait(id, "initiative"),             -- self-starts vs waits
        selfPreservation = trait(id, "selfPreservation"), -- flee earliness
        compassion = trait(id, "compassion"),             -- gives to the suffering
        appetite = trait(id, "appetite"),                 -- eats early vs waits
        talkativeness = trait(id, "talkativeness"),       -- voices the day
    }
end

-- [C31] The child's fear (Growing Up's model, CREDITS.md; the numbers
-- live in SAO_History): a floor by age, eased for good by every kill
-- of their own and for now by a comfort object carried, and raised at
-- night under fifteen. Nothing for anyone grown, so every decision
-- below reads exactly as it did for an adult. Reads the body and the
-- engine's clock where there are any; in a bare VM it is the floor
-- alone, which is what Border 63 samples.
function D.fear(id)
    local age = nil
    pcall(function() age = SAO.History.ageOf(id) end)
    -- [C32] The anxious and the haunted carry fear at any age
    -- (SAO_Conditions.fear); a child's floor sits under it.
    local carried = 0
    pcall(function()
        local tick = SAO.Controller and SAO.Controller.tick and SAO.Controller.tick() or nil
        carried = SAO.Conditions.fear(id, tick)
    end)
    if type(carried) ~= "number" then carried = 0 end
    if type(age) ~= "number" or age >= 18 then
        return math.min(1, carried)
    end
    local floor = 0
    pcall(function() floor = SAO.History.fearFloorOf(age) end)
    local body = nil
    pcall(function() body = SAO.Body.get(id) end)
    if body then
        pcall(function()
            floor = floor - body:getZombieKills() * SAO.History.KILL_EASE
        end)
        pcall(function()
            local inv = body:getInventory()
            for _, item in ipairs(SAO.History.COMFORT_OBJECTS) do
                if inv:containsTypeRecurse(item) then
                    floor = floor - SAO.History.COMFORT_EASE
                    break
                end
            end
        end)
    end
    if floor < 0 then floor = 0 end
    local night = 0
    pcall(function()
        night = SAO.History.nightFearOf(age, getGameTime():getTimeOfDay())
    end)
    local fear = floor + night + carried
    if fear > 1 then fear = 1 end
    return fear
end

-- ---------------------------------------------------------------------------
-- [B48] The ranges below are what this code can actually PRODUCE,
-- and every one of them used to be wrong in the same way.
--
-- They were written as if a trait ran 0..1. It does not: `trait()`
-- returns 0.15..0.85 - the human envelope [A14] imposes so history
-- bends a person and never breaks the species - and the echoes that
-- shift it are clamped to the same band. So `3.0 .. 11.0 tiles` was
-- describing a survivor who cannot exist, and `2 .. 7` promised a
-- seventh that is structurally unreachable.
--
-- Every figure here is now the reachable extreme, and the engine
-- agrees with all eight to four decimal places (Border 63 asks it
-- every run rather than trusting this comment).
--
-- It mattered beyond tidiness once already: [B46] reasoned from
-- "talkativeness runs 0.20 to 0.85" that a reserved survivor ignored
-- four questions in five. The floor is 0.2975, so it was nearer three
-- in five. The conclusion held and the number did not.

-- Decisions (each consumes beliefs, returns a preference — never an order)

-- At what believed distance does this survivor break and move away?
-- High nerve holds longer; high self-preservation breaks earlier.
function D.fleeDistance(id)
    local t = D.traits(id)
    return 3.0 + (1.0 - t.nerve) * 5.0 + t.selfPreservation * 3.0
        + D.fear(id) * 4.0   -- 4.2 .. 11.8 tiles over the county sampled (a grown adult 4.2 .. 9.8; the rest is a child's fear, [C31], whose arithmetic tops at 12.0)
end

-- How many believed nearby threats before this survivor refuses to hold
-- ground regardless of armament? Envelope: everyone flees a crowd.
function D.overwhelmThreshold(id)
    local t = D.traits(id)
    -- A frightened child holds against a smaller crowd ([C31]); the
    -- envelope's floor of two stands for everyone.
    return math.max(2, math.floor(2 + t.nerve * 3 + t.aggression * 2
        - D.fear(id) * 2))  -- 2 .. 6
end

-- Would this survivor choose to engage one believed threat, given whether it
-- is armed? Unarmed engagement is outside the envelope entirely.
function D.wouldEngage(id, armed, believedCount)
    if not armed then return false end
    -- Past half fear a child does not choose to engage at all ([C31]).
    if D.fear(id) >= 0.5 then return false end
    local t = D.traits(id)
    if believedCount >= D.overwhelmThreshold(id) then return false end
    return t.aggression > 0.35 or believedCount == 1 and t.nerve > 0.5
end

-- Latency: ticks between decision updates. Low initiative thinks slower.
-- This is where "skill changes latency" lives.
function D.decisionInterval(id)
    local t = D.traits(id)
    return math.floor(8 + (1.0 - t.initiative) * 22)   -- 11 .. 26 ticks
end

-- Movement pace preference under believed threat.
function D.paceUnderThreat(id)
    local t = D.traits(id)
    if D.fear(id) > 0.3 then return "run" end   -- a frightened child runs ([C31])
    if t.selfPreservation > 0.6 then return "run" end
    return t.discipline > 0.5 and "walk" or "run"
end

-- Idle roaming: high initiative wanders sooner and farther. An empty mind is
-- not a random walk - the interval is long and the range short, a person
-- stretching their legs, not a screensaver.
function D.roamInterval(id)
    local t = D.traits(id)
    -- [B49] Frames, not seconds - a tick is one rendered frame.
    return math.floor(1800 + (1.0 - t.initiative) * 3600)
        -- 2340 .. 4860 frames, which is 39s .. 81s at 60fps
end

function D.roamRange(id)
    local t = D.traits(id)
    return 4 + math.floor(t.initiative * 8)                 -- 5 .. 10 tiles
end

-- The hunger level (engine stat, ~0 fed .. 1 starving) at which this person
-- goes looking for food. The disciplined wait; the indulgent eat early.
function D.eatAt(id)
    -- [C32] The diabetic looks for food sooner (SAO_Conditions.eatEarlier).
    local earlier = 0
    pcall(function() earlier = SAO.Conditions.eatEarlier(id) end)
    if type(earlier) ~= "number" then earlier = 0 end
    return 0.30 + trait(id, "appetite") * 0.25 - earlier   -- 0.2875 .. 0.5125
end

-- Overwhelmed with a loaded gun: stand and shoot, or run anyway? Nerve
-- decides; discipline tempers the reckless yes.
function D.wouldShootWhenOverwhelmed(id)
    local t = D.traits(id)
    local bar = 0.55
    if SAO.Lessons then bar = bar + SAO.Lessons.shootBarBump(id) end
    bar = bar + D.fear(id) * 0.3   -- a frightened child needs more nerve to stand ([C31])
    return t.nerve > bar
end

-- The short fuse ([A27]): how far trust must fall before THIS person
-- turns hostile. Aggressive people declare around -0.4; the meek
-- endure to about -0.62. Centered on the old flat -0.5 - the county's
-- total heat is similar, but WHO starts things is now a person.
function D.hostilityBar(id)
    local t = D.traits(id)
    return -0.65 + t.aggression * 0.3
end

-- The wanted circle ([A27]): some keep their own company, some keep
-- a small band, some want the whole house. A durable fact of the
-- person, same hash idiom as every trait - never forced, never cured.
function D.circle(id)
    local h = hash(id, "circle")
    if h < 0.15 then return "loner" end
    if h < 0.50 then return "band" end
    return "house"
end

function D.circleCap(id)
    local c = D.circle(id)
    if c == "loner" then return 1 end
    if c == "band" then return 3 end
    return 999
end

-- Habits are hash facts. About a third of the county smoked before the
-- end; the end did not help anyone quit. The third is Kentucky's own:
-- 30.1 percent of adults, BRFSS 1993 (MMWR Surveillance Summaries,
-- state- and sex-specific prevalence of selected characteristics,
-- 1992 and 1993; the national figure that year was 25.0 percent,
-- MMWR, Cigarette Smoking Among Adults - United States, 1993).
function D.isSmoker(id)
    return hash(id, "smoker") < 0.30
end

-- The tidy judge appearances: high discipline warms to the visibly
-- unkempt at half speed. Judgment, never hostility.
function D.judgesAppearance(id)
    return trait(id, "discipline") > 0.60
end

-- Whether this person gives to a suffering STRANGER. Company shares by
-- bond; charity is temperament.
function D.wouldGiveToStranger(id)
    local bar = 0.6
    if SAO.Lessons then bar = bar - SAO.Lessons.charityEase(id) end
    return trait(id, "compassion") > bar
end

-- How readily this person voices what they are doing (0..1 chance scale
-- for non-urgent lines; urgency always speaks).
function D.talkativeness(id)
    return 0.20 + trait(id, "talkativeness") * 0.65   -- 0.2975 .. 0.7525
end

-- The thirst level at which this person seeks water. Thirst bites faster
-- than hunger and is cheaper to fix; the band sits lower than eatAt.
function D.drinkAt(id)
    return 0.25 + trait(id, "appetite") * 0.20   -- 0.28 .. 0.42
end

-- How far this person lets company drift before closing the gap. The
-- independent-minded range wider; the cautious keep close.
function D.followGap(id)
    return 4.0 + trait(id, "initiative") * 4.0   -- 4.6 .. 7.4 tiles
end

-- Facing a locked door while not under threat: does this person force it?
-- Within the envelope, breaking into things is a decision, not a reflex -
-- and without urgency or standing hostility the answer is no.
function D.wouldForceEntry(id, fleeing)
    if fleeing then return true end
    return false
end

function D.describe(id)
    local t = D.traits(id)
    return string.format(
        "nerve=%.2f disc=%.2f aggr=%.2f init=%.2f selfp=%.2f fear=%.2f | flee@%.1f overwhelm@%d interval=%d",
        t.nerve, t.discipline, t.aggression, t.initiative, t.selfPreservation, D.fear(id),
        D.fleeDistance(id), D.overwhelmThreshold(id), D.decisionInterval(id))
end

return D
