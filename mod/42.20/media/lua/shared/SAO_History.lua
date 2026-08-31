-- SAO_History - the apocalypse clock and the settled past (DR-006 S1,
-- corrected at [A14]).
-- ---------------------------------------------------------------------------
-- A survivor's past is a SMALL set of settled claims with provenance -
-- paid-for (lived), seen, or told - plus an epistemic age: how many months
-- of apocalypse they have had to learn anything at all. Claims echo into
-- traits (bounded at the disposition primitive) and feed the lesson
-- economy (S2). TEXT IS ONLY A RENDERING of the claims, produced at read
-- time and never stored; the record holds knowledge, not narrative.
--
-- Sparsity is the discipline: most claims carry no name and no story. At
-- most ONE claim - the costliest lived one - may carry the name of who it
-- cost, and only sometimes. The dead are an attribution, not a cast.

SAO = SAO or {}
SAO.History = SAO.History or {}
local H = SAO.History

-- [B47] One door out. `log` is what happened once; `tally` is
-- what happens once per person, counted rather than printed.
local function log(msg) SAO.Log.line("HISTORY", msg) end
local function tally(kind) SAO.Log.tally("HISTORY", kind) end

-- Months since the outbreak began, as of NOW (fractional).
function H.clockMonths()
    local sv = SandboxVars or nil
    local startMonths = (sv and tonumber(sv.TimeSinceApo)) or 1
    local elapsed = 0
    pcall(function()
        elapsed = GameTime.getInstance():getWorldAgeHours() / (24.0 * 30.0)
    end)
    return (startMonths - 1) + elapsed
end

local function hashOf(id, salt)
    -- [B48] Kahlua's numbers are doubles and the FNV step
    -- overflowed the mantissa, collapsing this to a handful of
    -- values. One implementation now, computed exactly.
    return SAO.Hash.of(id, salt)
end

-- [B38] A coin, and NOT `hashOf(...) % 2`.
--
-- FNV's low bit is a parity checksum of its input, not a random bit.
-- The step is `v = v * 16777619 + byte` and 16777619 is odd, so the
-- bottom bit of v is the running parity of every byte fed in, plus
-- the basis. Across ids that differ by a digit - which is every id
-- this mod makes - that parity barely moves.
--
-- Measured over a thousand pairs: `% 2` came up heads 9% of the time.
-- It was deciding partner-versus-sibling for every family in the
-- county, and - older than this batch - how many contacts a survivor
-- starts life with, two lines apart. A bit from the middle of the
-- word gives 51%.
local function coinOf(id, salt)
    return math.floor(hashOf(id, salt) / 65536) % 2
end

-- [B37] How old this person is, and therefore what they lived
-- through before any of this.
--
-- The clock below counts months of APOCALYPSE. Nothing counted the
-- years before it, so every survivor's knowable past began the day
-- the world ended and none of them remembered a decade of it. Age is
-- the one number that fixes that: birth year falls out of the world's
-- own start year, and which decades a person actually lived through
-- is then arithmetic rather than a table per person.
--
-- The shape is the county the apocalypse leaves behind rather than a
-- census of 1993: the old die first and die fastest, so the body of
-- it sits in the twenties to forties, thins through the fifties, and
-- keeps a narrow tail into the sixties. No children - the mod does
-- not model them, and inventing one would be worse than the gap.
--
-- Deterministic from the same hash the traits use, so age is a fact
-- about WHO SOMEBODY IS rather than a roll at read time, and two
-- sessions agree about the same person.
local AGE_BANDS = {
    { from = 19, to = 29, weight = 26 },
    { from = 30, to = 39, weight = 30 },
    { from = 40, to = 49, weight = 23 },
    { from = 50, to = 59, weight = 14 },
    { from = 60, to = 68, weight = 7 },
}

function H.ageOf(id)
    local roll = hashOf(id, "age") % 100
    local seen = 0
    for _, band in ipairs(AGE_BANDS) do
        seen = seen + band.weight
        if roll < seen then
            local span = band.to - band.from
            return band.from
                + (hashOf(id, "ageIn") % (span + 1))
        end
    end
    return 34
end

-- The year they were born, against the world's OWN start year - so a
-- sandbox that begins in 1997 moves everybody four years without a
-- second table.
function H.birthYearOf(id)
    local start = 1993
    pcall(function()
        local y = GameTime.getInstance():getStartYear()
        if y and y > 1900 then start = y end
    end)
    return start - H.ageOf(id)
end

-- How old they were in a given year - negative before they existed.
-- The whole point of carrying age: what a person can remember of a
-- decade depends entirely on how old they were during it.
function H.ageInYear(id, year)
    return (tonumber(year) or 0) - H.birthYearOf(id)
end

-- [B39] The war they were old enough for.
--
-- [B37] built `ageInYear` and closed saying nothing read it. This
-- reads it, and it is the cleanest thing age can be asked: a person's
-- war is not a fact about them that needs storing, it is arithmetic
-- over the year they were born.
--
-- The windows are real and are not mine. US ground involvement ran
-- 1950-1953 in Korea, 1965-1973 in Vietnam, and the Gulf ground war
-- was 1990-1991. The operator's frame for exactly this: Nirvana was
-- popular, Clinton was president, the Soviet Union collapsed two
-- years ago - it is not that deep. Modelling
-- a world that actually happened is fidelity, not invention.
--
-- Against the county's own age bands - nineteen to sixty-eight in
-- 1993, so born 1925 to 1974 - all three windows are reachable and
-- the youngest are too young for any of them, which is correct.
local WARS = {
    { key = "Korea", from = 1950, to = 1953 },
    { key = "Vietnam", from = 1965, to = 1973 },
    { key = "the Gulf", from = 1990, to = 1991 },
}

-- Old enough to be sent, young enough to be sent. Nobody is drafted
-- at sixteen and few at thirty.
local SERVICE_MIN, SERVICE_MAX = 18, 26

-- Nil for somebody no war reached, which is most of the county.
function H.warOf(id)
    local found = nil
    for _, war in ipairs(WARS) do
        local atStart = H.ageInYear(id, war.from)
        local atEnd = H.ageInYear(id, war.to)
        -- They turned service age before it ended and had not aged out
        -- before it began.
        if atEnd >= SERVICE_MIN and atStart <= SERVICE_MAX then
            found = war.key
        end
    end
    return found
end

-- Did this person's life actually put them in one? Only the lives the
-- census already calls military - a schoolteacher born in 1948 was
-- the right age for Vietnam and did not go.
local SERVED = { veteran = true, soldier = true }

function H.servedIn(id, occupation)
    if not SERVED[tostring(occupation or "")] then return nil end
    return H.warOf(id)
end

local LOST_NAMES = {
    "Maria", "Devon", "Ruth", "Caleb", "Ana", "Marcus", "June", "Elias",
    "Priya", "Tom", "Rosa", "Walt", "Nadia", "Hank", "Simone", "Ray",
}

-- The claim grammar: which lessons a life like THIS could have settled,
-- and what each settles into. fits() reads base traits (the claim
-- explains the trait bend it echoes; it never contradicts the person).
local GRAMMAR = {
    { key = "measure-the-danger",  fits = function(t) return t.nerve < 0.45 end,
      echoes = { nerve = -0.08, selfPreservation = 0.10 }, mortal = true },
    { key = "doors-decide-lives",  fits = function(t) return t.aggression > 0.55 end,
      echoes = { aggression = 0.05, compassion = -0.06 }, mortal = false },
    { key = "people-are-worth-it", fits = function(t) return t.compassion > 0.55 end,
      echoes = { compassion = 0.08 }, mortal = true },
    { key = "claimed-places-bite", fits = function(t) return true end,
      echoes = { discipline = 0.05 }, mortal = false },
    { key = "routine-is-armor",    fits = function(t) return t.discipline > 0.5 end,
      echoes = { discipline = 0.05, initiative = -0.04 }, mortal = false },
    { key = "noise-is-a-debt",     fits = function(t) return t.initiative > 0.5 end,
      echoes = { nerve = 0.04 }, mortal = true },
    { key = "running-has-a-price", fits = function(t) return t.selfPreservation > 0.55 end,
      echoes = { selfPreservation = 0.06, compassion = 0.04 }, mortal = true },
}

-- The split clock ([A17]): world-time is the sandbox's (clockMonths);
-- each BODY carries contactMonths - months alive scaled by an isolation
-- factor - and everything settled rides CONTACT. A six-month hermit
-- (factor near the floor) has settled almost nothing; two people in the
-- same month hold different sets because their contact and their rolls
-- differ.
function H.contactFactor(id)
    -- 0.10 (hermit) .. 1.00 (gregarious); hash-stable per identity.
    return 0.10 + (hashOf(id, 77) % 900) / 1000.0
end

-- Settle the past once per record: contact months, a SPARSE claim set
-- with ROLLED provenance (a settled past includes hearsay a person
-- organized their life around), settled trait echoes scaled by how the
-- claim was acquired, and at most one named cost on a lived claim.
function H.generate(id, rec, monthsAliveOverride)
    if rec.epistemicMonths ~= nil then return end
    -- The census seam ([A18], DR-010): every generated past begins with
    -- who this person WAS. One seam covers every caller - genesis,
    -- harness spawn, Knox adoption, and whatever comes later.
    --
    -- [B42] This used to say that Knox adoptees "arrive with
    -- occupation ALREADY SET ([A20] - the seed runs before this); only
    -- the unreadable fall to a presumed draw". DR-012 reversed that, so
    -- ALL of them fall to the draw now and all of them are flagged
    -- honest. The sentence is replaced rather than left standing,
    -- because a comment describing a path that no longer exists is the
    -- same defect one layer up from the code.
    if not rec.occupation and SAO.Census then
        local row = SAO.Census.assign(id)
        if row then
            rec.occupation = row.key
            if rec.knox then rec.occupationPresumed = true end
        end
    end
    local worldMonths = H.clockMonths()
    local monthsAlive = monthsAliveOverride or worldMonths
    local contact = monthsAlive * H.contactFactor(id)
    rec.monthsAlive = math.floor(monthsAlive * 10 + 0.5) / 10
    rec.contactMonths = math.floor(contact * 10 + 0.5) / 10
    rec.epistemicMonths = rec.contactMonths   -- readers keep working
    -- [B41] `rec.seasonedMonths = rec.contactMonths` used to follow.
    -- Three names for one number, and the third was read by nothing
    -- anywhere in the tree - `epistemicMonths` is the back-compat
    -- alias that IS read and says so on its own line. A duplicate
    -- nobody reads is not redundancy, it is a value that can drift
    -- from its source with nothing to notice.
    local traits = SAO.Disposition.traits(id)

    -- The past has a trade ([A18], census C3): occupation class biases
    -- WHICH claims settle (affinity = pick-pool multiplicity; the
    -- deputy's measure-the-danger crowds the draw) and HOW they were
    -- paid for (provenance tilt: hardened trades lived it; settled
    -- trades were mostly told). The CLOCK is deliberately untouched -
    -- contact and count stay occupation-blind so the hermit invariant
    -- holds; only the texture of the settled past bends.
    local occClass = (SAO.Census and SAO.Census.classOf)
        and SAO.Census.classOf(rec.occupation) or nil
    local AFFINITY = {
        hardened = { ["measure-the-danger"] = 3, ["doors-decide-lives"] = 2,
                     ["routine-is-armor"] = 2 },
        carer    = { ["people-are-worth-it"] = 3, ["running-has-a-price"] = 2 },
        outdoors = { ["noise-is-a-debt"] = 2, ["routine-is-armor"] = 2,
                     ["claimed-places-bite"] = 2 },
        settled  = { ["claimed-places-bite"] = 2, ["people-are-worth-it"] = 2 },
        trades   = { ["routine-is-armor"] = 2, ["doors-decide-lives"] = 2 },
    }
    local TILT = { hardened = 15, carer = 10, outdoors = 5,
                   settled = -15, trades = 0 }
    local affinity = occClass and AFFINITY[occClass] or nil
    local livedBar = 45 + (occClass and TILT[occClass] or 0)
    -- [B39] Somebody who was actually in one paid for more of what
    -- they know. This uses the bar that already exists rather than
    -- inventing a second mechanism, and it applies only to the lives
    -- the census calls military whose AGE put them in a real war.
    local theirWar = nil
    pcall(function() theirWar = H.servedIn(id, rec.occupation) end)
    if theirWar then livedBar = livedBar + 15 end

    -- Count rides CONTACT, not the slider: the hermit's half-year can
    -- settle less than a trader's fortnight.
    local count
    if contact < 0.5 then count = coinOf(id, 21)              -- 0..1
    elseif contact < 2 then count = 1 + coinOf(id, 21)        -- 1..2
    else count = 1 + hashOf(id, 21) % 3 end                   -- 1..3

    local fitting = {}
    for _, entry in ipairs(GRAMMAR) do
        if entry.fits(traits) then
            local times = (affinity and affinity[entry.key]) or 1
            for _ = 1, times do fitting[#fitting + 1] = entry end
        end
    end
    local echoes = {}
    local named = false
    local settled = 0
    local used = {}
    for k = 1, count do
        if #fitting == 0 then break end
        local pick = fitting[(hashOf(id, 30 + k) % #fitting) + 1]
        if not used[pick.key] then
            used[pick.key] = true
            settled = settled + 1
            -- Provenance is ROLLED per claim: lived 45 / witnessed 25 /
            -- told 30. Echoes scale with the weight - hearsay bends a
            -- person less than what they paid for.
            local roll = hashOf(id, 90 + k) % 100
            local src, weight
            if roll < livedBar then src, weight = "lived", 1.0
            elseif roll < livedBar + 25 then src, weight = "witnessed", 0.6
            else src, weight = "told", 0.4 end
            for trait, delta in pairs(pick.echoes) do
                echoes[trait] = (echoes[trait] or 0) + delta * weight
            end
            local of = nil
            if src == "lived" and pick.mortal and not named
                and (hashOf(id, 50 + k) % 100) < 40 then
                named = true
                of = LOST_NAMES[(hashOf(id, 60 + k) % #LOST_NAMES) + 1]
            end
            -- Day zero ([A29]): a county that starts BEFORE the
            -- fall has no apocalypse lessons to seed - these pasts
            -- are pre-outbreak lives. The grammar still shaped their
            -- trait echoes (who they are); what the world TEACHES
            -- begins when the world starts teaching. Era is per
            -- person: the first witnessed horror writes the first
            -- lesson through the machinery that already exists.
            local dz = SandboxVars and SandboxVars.SurvivorAwareness
                and SandboxVars.SurvivorAwareness.DayZero == true
            if SAO.Lessons and not dz then
                SAO.Lessons.learn(id, pick.key, weight, src, of)
            end
            -- [B48] What the draw actually drew.
            --
            -- The operator's session settled forty-nine pasts and every
            -- single one of them was `doors-decide-lives`. Seven
            -- entries in the grammar, one of which (`claimed-places-bite`)
            -- fits EVERYBODY and so is in every pool ever built - and it
            -- came up not once.
            --
            -- Simulating this loop over the same id range gives a
            -- healthy spread across all seven, so the source as written
            -- does not explain it, and four batches of reading that log
            -- did not either. The draw is the county's most
            -- characterful decision and there has never been an
            -- instrument on it: the only way anyone found out was by
            -- noticing the same string forty-nine times by eye.
            --
            -- One counted line per key per flush, which [B47] made
            -- affordable. The next session says what the draw does.
            tally("settled '" .. tostring(pick.key) .. "'")
        end
    end
    rec.traitEchoes = echoes
    -- [B47] Once per person. The numbers differ per person and that
    -- is exactly why printing them 234 times told nobody anything;
    -- the count is the readable part.
    tally("history read")
end

-- Rendering, at read time only: terse claim lines, never chapters.
function H.describe(id)
    local rec = SAO.Identity.get(id)
    if not rec then return "no record" end
    local alive = tostring(rec.monthsAlive or rec.epistemicMonths or "?")
    local contact = tostring(rec.contactMonths or rec.epistemicMonths or "?")
    local head = alive .. " months out there, " .. contact .. " in company."
    -- [B39] Rendered at read time, never stored - the claims-not-
    -- chapters law. A war is one clause, not a biography.
    local war = nil
    pcall(function() war = H.servedIn(id, rec.occupation) end)
    if war then
        head = head .. " " .. war .. ", a long time ago."
    end
    -- [B41] What they kept.
    --
    -- `rec.keepsake` has always held the item's full type - the bridge
    -- writes `item.getFullType()` for anything in the Memento category
    -- or carrying IS_MEMENTO - and the one consumer tested truthiness,
    -- so the county knew somebody was carrying SOMETHING and never
    -- what.
    --
    -- The engine supplies the readable name and nothing else. There is
    -- no field saying who a memento was of, so nothing here says: the
    -- object is named and the meaning is left where it belongs, with
    -- whoever is looking at them.
    local kept = nil
    pcall(function()
        if rec.keepsake then
            local it = getScriptManager():getItem(tostring(rec.keepsake))
            local nm = it and it:getDisplayName() or nil
            if nm and nm ~= "" then kept = nm end
        end
    end)
    if kept then
        head = head .. " Still carrying " .. kept .. "."
    end
    if not SAO.Lessons then
        return head
    end
    local rendered = SAO.Lessons.renderClaims(id)
    if rendered == "" then
        return head .. " Nothing settled yet."
    end
    return head .. " " .. rendered
end

-- [B38] Who two people in a unit are to each other.
--
-- [B37] gave everybody an age and left it reading nowhere. This is
-- what reads it. A unit records only what KIND it is - family,
-- friends, mixed - and the specific relation falls out of the ages
-- the two already have, because choosing the relation and then
-- choosing ages to match would be authoring the same fact twice.
--
-- Sixteen years is the gap that separates a generation from a
-- household: below it two family members are of an age with each
-- other, above it one of them raised the other. Partner or sibling is
-- settled by the hash of the PAIR - a fact about the two of them,
-- stable across sessions, the same way every other fact here is
-- settled.
local GENERATION_GAP = 16

function H.relationIn(aId, bId, kind)
    if not aId or not bId or aId == bId then return nil end
    kind = tostring(kind or "mixed")
    if kind == "friends" then return "friend" end
    if kind ~= "family" then return "companion" end

    local ageA, ageB = H.ageOf(aId), H.ageOf(bId)
    if math.abs(ageA - ageB) >= GENERATION_GAP then
        return (ageA > ageB) and "parent" or "child"
    end
    -- Ordered so both sides ask the same question of the same pair.
    local first = (tostring(aId) < tostring(bId)) and aId or bId
    local second = (first == aId) and bId or aId
    local pair = tostring(first) .. "+" .. tostring(second)
    if coinOf(pair, "kin") == 0 then return "partner" end
    return "sibling"
end

-- The pair's relation as the OTHER one would put it. A parent's child
-- is a child; a partner's partner is a partner.
function H.relationBack(relation)
    if relation == "parent" then return "child" end
    if relation == "child" then return "parent" end
    return relation
end

log("history module loaded (clock at "
    .. string.format("%.1f", H.clockMonths()) .. " months)")

return H
