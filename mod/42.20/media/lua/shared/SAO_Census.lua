-- SAO_Census.lua - who the county actually was (DR-010, census C2).
--
-- The distribution is REAL-WORLD-SHAPED, not engine-shaped: rows exist
-- for lives the engine holds no profession for (clerks, teachers,
-- truckers, homemakers, retirees - most of any county), and engine
-- professions attach where they exist. Weights are per-10k adults of a
-- defensible circa-1993 Meade/Hardin County, Kentucky - rural, riverine,
-- manufacturing-heavy, and sitting in Fort Knox's lap (soldier weight is
-- locally real; the armor school is next door). Figures are documented
-- approximations of 1990s Kentucky labor structure; the operator
-- ratified approximation ("beyond 1993, it doesn't really matter").
--
-- First-principles mod compatibility: the catalog ingests the engine's
-- own profession registry (bridge listProfessions -> namespace:path for
-- every registration, vanilla or modded). Known paths anchor to base
-- rows; unknown registrations become NEW rows weighted by
-- classification - so any profession mod that registers through
-- `CharacterProfession.register` enters the population automatically,
-- at an honest rarity. Spec-ops exist ONLY this way (baseline zero: no
-- SOF at Fort Knox in 1993) and carry the in-fiction justification that
-- operators were deployed INTO the exclusion zone after the outbreak.

SAO = SAO or {}
local Census = {}
SAO.Census = Census

local function log(text)
    SAO.Log.line("census", text)
end

-- FNV-family hash, same math as Disposition's - deterministic per id.
local function hashOf(id, salt)
    -- [B48] Kahlua's numbers are doubles and the FNV step
    -- overflowed the mantissa, collapsing this to a handful of
    -- values. One implementation now, computed exactly.
    return SAO.Hash.of(id, salt)
end

-- Per-10k rows; sum of per10k over the base table is exactly 10000.
-- enginePath, where present, is the VERIFIED vanilla registry path
-- (extracted from the jar's constant pool at [A18]).
Census.BASE = {
    -- The residue: no trade, but designation differs - a retiree's day
    -- is not a student's (DR-011 reaches here).
    { key = "homemaker",   label = "homemaker",            per10k = 1000 },
    { key = "retiree",     label = "retiree",              per10k = 1400 },
    { key = "student",     label = "student",              per10k = 500 },
    { key = "unemployed",  label = "out-of-work",          per10k = 470,
      enginePath = "unemployed" },
    -- Civil lives the engine has no profession for.
    { key = "clerk",       label = "office clerk",         per10k = 900 },
    { key = "salesperson", label = "salesperson",          per10k = 550 },
    { key = "teacher",     label = "schoolteacher",        per10k = 200 },
    { key = "trucker",     label = "truck driver",         per10k = 340 },
    { key = "waitress",    label = "waitress",             per10k = 300 },
    { key = "minister",    label = "minister",             per10k = 50 },
    { key = "postal",      label = "mail carrier",         per10k = 60 },
    { key = "bartender",   label = "bartender",            per10k = 60 },
    { key = "factoryhand", label = "factory hand",         per10k = 520 },
    { key = "farmhand",    label = "farmhand",             per10k = 240 },
    { key = "nursesaide",  label = "nurse's aide",         per10k = 220 },
    -- [B38] The two kinds of person the county could not produce.
    -- Border 24 measured both at zero against a 1990 workforce where
    -- they were 10.2% and 3.4% - and a mod about companies and who
    -- leads them had nobody who had ever run a shift. Weighted for a
    -- rural county rather than the nation: about a third of the
    -- national managerial share, and under two thirds of the
    -- technical one.
    { key = "manager",     label = "store manager",        per10k = 120 },
    { key = "foreman",     label = "shift foreman",        per10k = 110 },
    { key = "owner",       label = "shop owner",           per10k = 90 },
    { key = "labtech",     label = "lab technician",       per10k = 40 },
    { key = "emt",         label = "paramedic",            per10k = 40 },
    { key = "electech",    label = "electronics tech",     per10k = 40 },
    -- Vanilla-anchored trades and services.
    { key = "burgerflipper", label = "line cook",          per10k = 300,
      enginePath = "burgerflipper" },
    { key = "chef",        label = "chef",                 per10k = 110,
      enginePath = "chef" },
    { key = "carpenter",   label = "carpenter",            per10k = 170,
      enginePath = "carpenter" },
    { key = "construction", label = "construction worker", per10k = 270,
      enginePath = "constructionworker" },
    { key = "electrician", label = "electrician",          per10k = 85,
      enginePath = "electrician" },
    { key = "engineer",    label = "engineer",             per10k = 65,
      enginePath = "engineer" },
    { key = "farmer",      label = "farmer",               per10k = 220,
      enginePath = "farmer" },
    { key = "rancher",     label = "rancher",              per10k = 65,
      enginePath = "rancher" },
    { key = "fisherman",   label = "fisherman",            per10k = 20,
      enginePath = "fisherman" },
    { key = "fitness",     label = "fitness instructor",   per10k = 12,
      enginePath = "fitnessInstructor" },
    { key = "lumberjack",  label = "lumberjack",           per10k = 40,
      enginePath = "lumberjack" },
    { key = "mechanic",    label = "mechanic",             per10k = 210,
      enginePath = "mechanics" },
    { key = "metalworker", label = "metalworker",          per10k = 150,
      enginePath = "metalworker" },
    { key = "nurse",       label = "nurse",                per10k = 125,
      enginePath = "nurse" },
    { key = "parkranger",  label = "park ranger",          per10k = 4,
      enginePath = "parkranger" },
    { key = "police",      label = "police officer",       per10k = 28,
      enginePath = "policeofficer" },
    { key = "fireofficer", label = "firefighter",          per10k = 12,
      enginePath = "fireofficer" },
    { key = "repairman",   label = "repairman",            per10k = 130,
      enginePath = "repairman" },
    { key = "security",    label = "security guard",       per10k = 65,
      enginePath = "securityguard" },
    { key = "smither",     label = "smith",                per10k = 4,
      enginePath = "smither" },
    { key = "tailor",      label = "tailor",               per10k = 25,
      enginePath = "tailor" },
    { key = "veteran",     label = "veteran",              per10k = 210,
      enginePath = "veteran" },
    { key = "doctor",      label = "doctor",               per10k = 20,
      enginePath = "doctor" },
    { key = "burglar",     label = "burglar",              per10k = 30,
      enginePath = "burglar" },
    -- Fort Knox next door: active-duty among the county's people.
    { key = "soldier",     label = "soldier",              per10k = 380,
      bucket = "military" },
}

-- Verified vanilla outfits by census key ([A20]) - names enumerated
-- from media/clothing/clothing.xml; a key absent here keeps random
-- dress. Buckets fall back for classified (modded) rows.
local OUTFIT_BY_KEY = {
    police = "Police", fireofficer = "Fireman", nurse = "Nurse",
    doctor = "Doctor", farmer = "Farmer", farmhand = "Farmer",
    chef = "Chef", burgerflipper = "Cook_Generic",
    construction = "ConstructionWorker", mechanic = "Mechanic",
    security = "Security", postal = "Postal", trucker = "Trucker",
    teacher = "Teacher", clerk = "OfficeWorker", minister = "Priest",
    parkranger = "Ranger", fitness = "FitnessInstructor",
    student = "Student", soldier = "ArmyCamoGreen",
}
local OUTFIT_BY_BUCKET = {
    specops = "ArmyCamoDesert", military = "ArmyCamoGreen",
    law = "Police", medical = "Nurse",
}

function Census.outfitOf(key)
    if not key then return nil end
    local direct = OUTFIT_BY_KEY[key]
    if direct then return direct end
    local row = Census.rowOf(key)
    if row and row.bucket then return OUTFIT_BY_BUCKET[row.bucket] end
    return nil
end

-- Rarity buckets for professions we have never heard of - the honest
-- weights a registration earns by what its name says it is.
-- Relative weight among lives the base table does not know. These are
-- RATIOS between buckets, not shares of the county - [B38] holds the
-- whole block to MOD_SHARE, up to a point named below.
local BUCKETS = {
    specops      = 7,
    military     = 45,
    law          = 12,
    medical      = 30,
    professional = 40,
    trades       = 60,
}

-- The most of the county, per 10k of base, that may be lives no base
-- row describes. Against a base summing to 10000 this is about a
-- tenth of everyone - enough that an installed profession mod is
-- really present, bounded so that installing thirty of them does not
-- make the county mostly theirs.
--
-- [B50] Where the cap stops holding, said out loud because it used to
-- say "however many mods are installed" and that is not true.
--
-- Scaling floors each life's weight and then lifts it to at least 1,
-- deliberately: a life the county can never produce is worse than a
-- rare one, and rounding must not delete somebody's mod. So once there
-- are MORE mod-added lives than MOD_SHARE, every one of them is
-- already at the floor and the block is exactly their count.
--
-- Measured in the engine: 200 lives -> 1200, 1200 lives -> 1200,
-- 2000 lives -> 2000, at which point they are a sixth of the county
-- rather than a ninth. That is the floor winning, and it should - the
-- alternative is silently deleting professions somebody installed.
-- Twelve hundred profession mods is not a load order anyone has, and
-- if it ever is, the honest answer is a bigger base table rather than
-- a stricter cap.
local MOD_SHARE = 1200

-- What this engine's `table.sort` will actually do. Measured, not
-- guessed: a thousand entries sort, fifteen hundred throw. Held well
-- under the boundary because the failure is a stack overflow during
-- genesis, and the cost of stopping short is only that a list reads in
-- registration order.
local SORT_CEILING = 900

function Census.classify(path)
    local p = string.lower(tostring(path or ""))
    if p:find("park", 1, true) then return "trades" end
    if p:find("seal", 1, true) or p:find("delta", 1, true)
        or p:find("commando", 1, true) or p:find("specop", 1, true)
        or p:find("sof", 1, true) or p:find("ranger", 1, true) then
        return "specops"
    end
    if p:find("soldier", 1, true) or p:find("marine", 1, true)
        or p:find("army", 1, true) or p:find("infantry", 1, true)
        or p:find("military", 1, true) then
        return "military"
    end
    if p:find("police", 1, true) or p:find("sheriff", 1, true)
        or p:find("swat", 1, true) or p:find("detective", 1, true)
        or p:find("trooper", 1, true) or p:find("marshal", 1, true) then
        return "law"
    end
    if p:find("doctor", 1, true) or p:find("surgeon", 1, true)
        or p:find("medic", 1, true) or p:find("nurse", 1, true)
        or p:find("emt", 1, true) then
        return "medical"
    end
    if p:find("pilot", 1, true) or p:find("teacher", 1, true)
        or p:find("lawyer", 1, true) or p:find("scientist", 1, true)
        or p:find("priest", 1, true) then
        return "professional"
    end
    return "trades"
end

local catalogCache = nil

-- The living catalog: base rows plus every engine registration. Known
-- paths anchor engine keys onto base rows; unknown registrations become
-- classified rows, SORTED BY KEY so the weighted walk is stable across
-- boots regardless of registry iteration order.
function Census.catalog()
    -- F-036: never let an early bridge-less call freeze a base-only
    -- catalog for the session - cache only what was built WITH the
    -- bridge, or rebuild once it appears. Records keep their stored
    -- occupations either way; only future draws see the fuller world.
    if catalogCache
        and (catalogCache.sawBridge or not SAOJavaBridge) then
        return catalogCache
    end
    local rows = {}
    local byPath = {}
    for i = 1, #Census.BASE do
        local base = Census.BASE[i]
        local row = {}
        for k, v in pairs(base) do row[k] = v end
        rows[#rows + 1] = row
        if row.enginePath then byPath[row.enginePath] = row end
    end
    local listed = nil
    if SAOJavaBridge then
        local ok, result = pcall(function()
            return SAOJavaBridge:listProfessions()
        end)
        if ok and type(result) == "string" then listed = result end
    end
    if listed and listed ~= "" then
        local classified = {}
        for entry in string.gmatch(listed, "[^|]+") do
            local ns, path = string.match(entry, "^([^:]+):(.+)$")
            if ns and path then
                local known = byPath[path]
                if known then
                    known.engineKey = ns .. ":" .. path
                    known.source = ns
                else
                    local bucket = Census.classify(path)
                    classified[#classified + 1] = {
                        key = ns .. ":" .. path,
                        label = string.lower(path),
                        per10k = BUCKETS[bucket] or BUCKETS.trades,
                        engineKey = ns .. ":" .. path,
                        source = ns,
                        bucket = bucket,
                        classified = true,
                    }
                end
            end
        end
        -- [B38] The county's composition is ours, not the mod list's.
        --
        -- Every life a mod adds arrived here at its bucket's flat
        -- rate and was simply appended, so the share of the county
        -- made of lives the base table does not know grew with the
        -- number of profession mods installed. Measured on the
        -- operator's own session: 31 registered lives, 24 of them at
        -- exactly 60/10k because they classify as trades, together
        -- about a seventh of everyone. Install ten more such mods and
        -- the county is mostly them - which is a fact about a mod
        -- list, not about who lived in Knox County.
        --
        -- So the bucket rates stay as RELATIVE weight among mod-added
        -- lives, and the block as a whole is held to a fixed share.
        -- Adding more profession mods now diversifies the county
        -- without enlarging its claim on it.
        local modTotal = 0
        for i = 1, #classified do
            modTotal = modTotal + (classified[i].per10k or 0)
        end
        if modTotal > MOD_SHARE then
            local scale = MOD_SHARE / modTotal
            for i = 1, #classified do
                local scaled = math.floor((classified[i].per10k or 0) * scale)
                -- Never to zero: a life the county can never produce
                -- is worse than a rare one, and rounding must not
                -- delete somebody's mod.
                classified[i].per10k = math.max(1, scaled)
            end
            log("mod-added lives held to " .. MOD_SHARE .. "/10k of the "
                .. "county (" .. #classified .. " lives, " .. modTotal
                .. " asked)")
        end
        -- [B50] Kahlua's `table.sort` cannot do this many.
        --
        -- Measured in the engine: it sorts a thousand entries and dies
        -- on fifteen hundred - not a JVM stack limit (`-Xss16m` does
        -- not move it) but the VM's own frame ceiling, so the game
        -- would hit it too. `catalog()` runs during genesis and inside
        -- a pcall, so the failure would be a county that quietly has
        -- no occupations at all.
        --
        -- The sort exists to make the appended rows read in a stable
        -- order. That is worth having and it is not worth a crash, so
        -- past the ceiling the bridge's own order stands - still
        -- deterministic within a session, just not alphabetical. Nobody
        -- has a thousand profession mods; this is here so that if
        -- somebody ever does, the county is merely untidy.
        if #classified <= SORT_CEILING then
            table.sort(classified, function(a, b) return a.key < b.key end)
        else
            log("not sorting " .. #classified .. " mod-added lives: past "
                .. "what this engine's table.sort survives")
        end
        for i = 1, #classified do
            rows[#rows + 1] = classified[i]
            log("registered life: " .. classified[i].key .. " ("
                .. classified[i].bucket .. ", "
                .. classified[i].per10k .. "/10k)")
        end
    end
    local total = 0
    for i = 1, #rows do total = total + (rows[i].per10k or 0) end
    catalogCache = { rows = rows, total = total,
        sawBridge = SAOJavaBridge ~= nil }
    log("catalog: " .. #rows .. " lives, " .. total .. " weight")
    return catalogCache
end

-- Deterministic draw: the same id is the same life on every boot.
function Census.assign(id)
    local cat = Census.catalog()
    if cat.total <= 0 then return nil end
    local roll = hashOf(id, "census") % cat.total
    local cum = 0
    for i = 1, #cat.rows do
        cum = cum + (cat.rows[i].per10k or 0)
        if roll < cum then return cat.rows[i] end
    end
    return cat.rows[#cat.rows]
end

-- The class of a life ([A18], census C3): five coarse shapes a trade
-- gives a past. Classified (modded) rows map through their rarity
-- bucket; base rows are named here. Everything unlisted is "trades".
local CLASS_BY_KEY = {
    police = "hardened", security = "hardened", veteran = "hardened",
    soldier = "hardened", burglar = "hardened",
    nurse = "carer", doctor = "carer", nursesaide = "carer",
    fireofficer = "carer", minister = "carer",
    farmer = "outdoors", rancher = "outdoors", fisherman = "outdoors",
    lumberjack = "outdoors", farmhand = "outdoors", parkranger = "outdoors",
    clerk = "settled", homemaker = "settled", retiree = "settled",
    student = "settled", salesperson = "settled", teacher = "settled",
    waitress = "settled", bartender = "settled", postal = "settled",
    unemployed = "settled",
    -- [B38] A manager and a shop owner keep a settled life; a
    -- paramedic is a carer. A foreman and an electronics tech fall to
    -- the trades default, which is what they are.
    manager = "settled", owner = "settled", labtech = "settled",
    emt = "carer",
}
local CLASS_BY_BUCKET = {
    specops = "hardened", military = "hardened", law = "hardened",
    medical = "carer", professional = "settled", trades = "trades",
}

-- Skills read back ([B2]): the live body's real perk level when
-- loaded; the engine profession definition's own boost as the
-- unloaded baseline - one truth, two read paths. -1 means unknown.
-- [B20] The jobs a house deals, and the real perk each one rides.
-- ONE table: it was copied into three files (the dealer in Standing,
-- the player teaching in the Controller, the housemate teaching in
-- Exchange), so adding a job meant editing three places and a mod
-- adding one could not reach any of them. Lives in the census
-- because the census is what already knows the relationship between
-- who someone was and what they can do.
--
-- Quartermaster is deliberately absent: organised is a trait, not a
-- skill, and there is no honest perk to read.
-- [B40] The same skill, in two vocabularies.
--
-- `JOB_PERK` values are PERK IDS - what `PerkFactory.PerkList` calls
-- them, which is what `getPerkLevel` matches against. Item scripts use
-- a different keyword for the same skill: the perk is `Doctor` and the
-- book says `SkillTrained = FirstAid`.
--
-- `SAONeeds.teachesPerk` compares `book.getSkillTrained()` to the
-- string it is handed with `equalsIgnoreCase`, so handing it a perk id
-- means the medic's book is never found. Measured against the shipped
-- scripts: zero books train `Doctor`, five train `FirstAid`.
--
-- That silently emptied [B22]'s whole point for one designation in
-- five - "A struggling medic can read, the dressings start holding,
-- and the evidence against them stops accumulating" - because
-- `readSkillBook` returned "" every time and the branch below it reads
-- as "the place does not hold one", which is what real scarcity looks
-- like. No error, no log, and a medic who could never recover.
--
-- Only the differing names live here; anything absent is already the
-- same word in both vocabularies.
Census.BOOK_SKILL = {
    Doctor = "FirstAid",
}

-- The keyword a BOOK would use for this perk.
function Census.bookSkillFor(perk)
    if not perk then return nil end
    return Census.BOOK_SKILL[perk] or perk
end

Census.JOB_PERK = {
    forager = "Foraging",
    medic   = "Doctor",
    watch   = "Aiming",
    scout   = "Lightfooted",
    cook    = "Cooking",
}

-- [B19] Who can get a car going. This is vanilla's own gate
-- (ISVehicleMenu.lua: Electricity >= 2 and Mechanics >= 3, or the
-- Burglar trait) read through the census - and skillOf already
-- falls back to the profession, so an electrician or a mechanic
-- genuinely has the levels and can take a car nobody else can.
--
-- The BURGLAR half is deliberately absent: our shells carry no
-- traits, so hasTrait(CharacterTrait.BURGLAR) would be a branch
-- that can never fire. A gate that cannot fire is worse than a
-- missing one, because it reads as coverage.
function Census.canHotwire(id)
    local elec = Census.skillOf(id, "Electricity") or -1
    local mech = Census.skillOf(id, "Mechanics") or -1
    return elec >= 2 and mech >= 3
end

function Census.skillOf(id, perkName)
    local body = SAO.Body and SAO.Body.get and SAO.Body.get(id) or nil
    if body and SAOJavaBridge then
        local okL, lvl = pcall(function()
            return SAOJavaBridge:getPerkLevel(body, perkName)
        end)
        if okL and type(lvl) == "number" and lvl >= 0 then return lvl end
    end
    local rec = SAO.Identity and SAO.Identity.get
        and SAO.Identity.get(id) or nil
    local row = rec and rec.occupation and Census.rowOf
        and Census.rowOf(rec.occupation) or nil
    if row and row.enginePath and SAOJavaBridge then
        local okB, boost = pcall(function()
            return SAOJavaBridge:professionBoost(row.enginePath, perkName)
        end)
        if okB and type(boost) == "number" and boost >= 0 then
            return boost
        end
    end
    return -1
end

function Census.classOf(key)
    if not key then return nil end
    local direct = CLASS_BY_KEY[key]
    if direct then return direct end
    local row = Census.rowOf(key)
    if row and row.bucket then
        return CLASS_BY_BUCKET[row.bucket] or "trades"
    end
    return "trades"
end

function Census.rowOf(key)
    local cat = Census.catalog()
    for i = 1, #cat.rows do
        if cat.rows[i].key == key then return cat.rows[i] end
    end
    return nil
end

-- How it started ([A20]): a one-line origin situation in the
-- vocabulary of the county's own start-scenarios (the active "Where I
-- Was When It Happened" catalog), picked deterministically from the
-- life's class - RENDERED, never stored. The burglar's story starts in
-- a cell block; the minister's on a farm with the wrong kind of
-- praying.
local ORIGIN_NOTES = {
    hardened = {
        "a police response that fell apart",
        "a checkpoint that stopped answering the radio",
    },
    carer = {
        "a hospital bed I got up from when nobody came",
        "a ward with the doors left open",
    },
    outdoors = {
        "a trail I never walked back out of",
        "a storm shelter that held",
    },
    settled = {
        "a safehouse somebody had already emptied",
        "a vacation that never ended",
        "a meeting point nobody else reached",
    },
    trades = {
        "a shift that never clocked out",
        "a job site the sirens emptied",
    },
}
local ORIGIN_SPECIAL = {
    burglar = "a cell block nobody came back to",
    minister = "a farm with the wrong kind of praying",
}

function Census.originNote(rec)
    if not rec or not rec.occupation then return nil end
    -- A presumed trade earns no invented origin story ([A22]): we
    -- do not put a beginning in the mouth of someone whose past we
    -- only guessed at.
    if rec.occupationPresumed then return nil end
    local special = ORIGIN_SPECIAL[rec.occupation]
    if special then return special end
    local cls = Census.classOf(rec.occupation) or "trades"
    local list = ORIGIN_NOTES[cls] or ORIGIN_NOTES.trades
    return list[(hashOf(rec.id or "?", "origin") % #list) + 1]
end

-- Render at read time, claims-first: the record stores only the key.
function Census.describe(rec)
    if not rec or not rec.occupation then return nil end
    local row = Census.rowOf(rec.occupation)
    local label = row and row.label or tostring(rec.occupation)
    if rec.occupationPresumed then
        return "carries themselves like a " .. label
    end
    local where = rec.originRegion
        and (" in " .. tostring(rec.originRegion) .. " when it started") or ""
    return "was a " .. label .. where
end
