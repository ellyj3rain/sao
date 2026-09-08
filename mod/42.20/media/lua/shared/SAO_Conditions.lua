-- SAO_Conditions - conditions are facts about a person ([C32], DR-032).
-- ---------------------------------------------------------------------------
-- The operator ruled that the county's people carry the conditions the
-- record says people carried - the mind's and the body's - and that
-- knowledge decays per person, not at one rate. The engine ships no
-- memory, no cognition and no chronic illness for a character
-- (ENGINE_CONTRACT Addendum F), so this module holds them, the way
-- age ([C30]) and the child's day ([C31]) are held: a fact drawn from
-- the same hash everything else about a person comes from, at the
-- prevalence the record gives, and read by the modules that already
-- decide things - the disposition (temperament bends and fear), the
-- perception (how long a belief is kept), the age drift (what the
-- body carries every ten minutes), the bridge (what the skills lose),
-- the controller (how long a book takes), the knowledge surface and
-- the inspect panel (in plain words, DR-017/DR-018).
--
-- The mechanisms are the mods' the catalogue settled on (CREDITS.md):
-- Neurodiverse Traits (Mxswat; source public) for the daily skill loss
-- of Alzheimer's, the daily focus of ADHD and the phases of bipolar;
-- Custom Traits (0x00sec; the page's figures) for dyslexia; Scotty's
-- Mental Health Expansion (MIT) for depression, anxiety, PTSD,
-- insomnia and psychosis. Where a mod has no number for the county's
-- form of it, the number is ours and says so. The prevalence figures
-- are the record's, each with its source beside it.
--
-- OFFLINE BY CONSTRUCTION: loads in a bare VM with SAO_Hash and
-- SAO_History; every engine read sits behind pcall.

SAO = SAO or {}
SAO.Conditions = SAO.Conditions or {}
local Cn = SAO.Conditions

local function hashOf(id, salt)
    return SAO.Hash.of(id, salt)
end

local function ageOf(id)
    local age = nil
    pcall(function() age = SAO.History.ageOf(id) end)
    return age or 34
end

-- ---------------------------------------------------------------------------
-- Prevalence, per ten thousand people. Each row names its population
-- and its source; a figure without a source does not go in. The
-- draw is independent per condition (the record gives no joint
-- figures), so a person can carry two.
-- ---------------------------------------------------------------------------
Cn.PREVALENCE = {
    -- Per ten thousand people, with the population and the source of
    -- each figure. Read 2026-09-06 from the primary documents or their
    -- own abstracts (the grade says which); a point-in-time county
    -- takes a current or thirty-day rate where the record has one and
    -- says so where it has only a lifetime one.
    --
    -- Dementia by age, community residents: Evans DA et al., "Prevalence
    -- of Alzheimer's disease in a community population of older
    -- persons", JAMA 1989;262(18):2551-6 - 65-74 3.0%, 75-84 18.7%, 85
    -- and over 47.2% (abstract). The Canadian Study of Health and Aging,
    -- CMAJ 1994;150(6):899-913, puts 85 and over at 34.5% (abstract);
    -- the last band takes the midpoint of the two and says so. None
    -- drawn under sixty-five.
    dementia = { bands = { { from = 65, to = 74, per10k = 300 },
                           { from = 75, to = 84, per10k = 1870 },
                           { from = 85, to = 200, per10k = 4090 } } },
    -- ADHD, school-age children, "3 to 5 percent": NIH Consensus
    -- Statement, Diagnosis and Treatment of Attention Deficit
    -- Hyperactivity Disorder, 1998;16(2):1-37 (text). The record gave
    -- no adult figure of the era, so none is drawn past seventeen.
    adhd       = { per10k = 400, maxAge = 17 },
    -- Major depression, thirty-day, ages 15-54: Blazer DG et al., "The
    -- prevalence and distribution of major depression in a national
    -- community sample: the National Comorbidity Survey", Am J
    -- Psychiatry 1994;151(7):979-86 - 4.9% (abstract; lifetime 17.1%).
    depression = { per10k = 490, minAge = 15 },
    -- Anxiety as the record counts it: generalized anxiety disorder,
    -- current, 1.6% (Wittchen HU et al., Arch Gen Psychiatry
    -- 1994;51(5):355-64, abstract) and panic disorder, one-month,
    -- about 1% (Eaton WW et al., Am J Psychiatry 1994;151(3):413-20,
    -- abstract), ages 15-54, summed. The phobias are counted
    -- separately by the record and are not drawn here.
    anxiety    = { per10k = 260, minAge = 15 },
    -- PTSD, lifetime, ages 15-54: Kessler RC et al., "Posttraumatic
    -- stress disorder in the National Comorbidity Survey", Arch Gen
    -- Psychiatry 1995;52(12):1048-60 - 7.8% (abstract). The record gave
    -- no twelve-month figure, so the county's share is a lifetime one
    -- and runs high; said here so a better figure can replace it.
    ptsd       = { per10k = 780, minAge = 15 },
    -- Bipolar I, lifetime, ages 15-54, with the twelve-month "only
    -- slightly lower": Kessler RC et al., Psychol Med 1997;27(5):
    -- 1079-89 - 0.4% (abstract).
    bipolar    = { per10k = 40, minAge = 15 },
    -- [C52] Nonaffective psychosis, broadly defined (all nonaffective
    -- psychoses), lifetime, BY CLINICIAN DIAGNOSIS: Kendler KS,
    -- Gallagher TJ, Abelson JM, Kessler RC, "Lifetime prevalence,
    -- demographic risk factors, and diagnostic validity of
    -- nonaffective psychosis as assessed in a US community sample.
    -- The National Comorbidity Survey", Arch Gen Psychiatry
    -- 1996;53(11):1022-31 - 0.7% (abstract).
    --
    -- Three choices in that sentence, each the conservative one. The
    -- BROAD definition rather than the narrow (schizophrenia or
    -- schizophreniform, 0.2%), because what this mod's psychosis does
    -- is hallucinate a threat, which is not confined to
    -- schizophrenia. The CLINICIAN diagnosis rather than the computer
    -- algorithm's 2.2%, because the paper's own point is that the two
    -- differ substantially and the clinicians are the check. And
    -- lifetime rather than twelve-month, for the reason the bipolar
    -- row gives: this is a standing fact about a person, not a spell.
    --
    -- The NCS sampled ages 15-54 and no upper bound is applied here.
    -- A lifetime figure measured under 55 is a floor for anyone
    -- older, never a ceiling - they have had more years to reach it -
    -- so drawing it at every adult age understates rather than
    -- overstates.
    psychosis  = { per10k = 70, minAge = 15 },
    -- A reading disability stays with a person: learning disability,
    -- ever, children 3-17, parent-reported, NHIS 1988 - 6.5% (Zill N,
    -- Schoenborn CA, NCHS Advance Data 190, 1990, text); drawn at all
    -- ages for that reason.
    dyslexia   = { per10k = 650 },
    -- [C52] Insomnia, complaint at interview, adults: Ford DE,
    -- Kamerow DB, "Epidemiologic study of sleep disturbances and
    -- psychiatric disorders. An opportunity for prevention?", JAMA
    -- 1989;262(11):1479-84 - 10.2% of a community sample of 7954 in
    -- the NIMH Epidemiologic Catchment Area study noted insomnia at
    -- the first interview (abstract).
    --
    -- WHAT THIS FIGURE IS NOT, said plainly because it is the weakest
    -- row in this table. It is a complaint recorded once, not a
    -- diagnosed chronic disorder, and this mod's insomnia is a
    -- standing trait that costs fatigue every ten minutes. The
    -- paper's own persistent group - insomnia at both interviews, a
    -- year apart - is the right analogue and its abstract gives no
    -- percentage for it, so it could not be read. Until it is, this
    -- draws about one adult in ten and that is more than the county
    -- should carry. Replacing it needs the persistence figure off the
    -- paper's text, not another estimate.
    insomnia   = { per10k = 1020, minAge = 18 },
    -- Asthma, reported, per thousand by age, NHIS 1993 (NCHS, Current
    -- Estimates from the National Health Interview Survey, 1993,
    -- Series 10 No. 190, Table 57, text): under 18 71.6, 18-44 42.5,
    -- 45-64 45.0, 65-74 53.0, 75 and over 41.2.
    asthma     = { bands = { { from = 0, to = 17, per10k = 716 },
                             { from = 18, to = 44, per10k = 425 },
                             { from = 45, to = 64, per10k = 450 },
                             { from = 65, to = 74, per10k = 530 },
                             { from = 75, to = 200, per10k = 412 } } },
    -- Diabetes, reported, per thousand by age, the same table: 18-44
    -- 13.1, 45-64 61.9, 65-74 101.9, 75 and over 106.0; the under-18
    -- figure is marked unreliable there and is not drawn.
    diabetes   = { bands = { { from = 18, to = 44, per10k = 131 },
                             { from = 45, to = 64, per10k = 619 },
                             { from = 65, to = 74, per10k = 1019 },
                             { from = 75, to = 200, per10k = 1060 } } },
}

-- The order every reader lists them in.
Cn.ORDER = { "dementia", "adhd", "bipolar", "depression", "anxiety",
             "ptsd", "insomnia", "dyslexia", "psychosis", "asthma",
             "diabetes" }

local function per10kFor(key, age)
    local row = Cn.PREVALENCE[key]
    if not row then return 0 end
    if row.bands then
        for _, band in ipairs(row.bands) do
            if age >= band.from and age <= band.to then return band.per10k end
        end
        return 0
    end
    if row.minAge and age < row.minAge then return 0 end
    if row.maxAge and age > row.maxAge then return 0 end
    return row.per10k or 0
end

-- Does this person carry this condition? A fact about who they are.
-- [C39] A trait beats the draw.
--
-- The county's people have their conditions drawn from their own
-- hash at the record's prevalence, which is what makes a condition a
-- fact about who somebody is. The PLAYER's are not drawn: they are
-- the ones that person chose at creation, and they arrive as engine
-- traits (SAO_Traits). Anyone whose conditions are asserted answers
-- from the assertion instead of the draw, so every surface in the
-- tree - the fear, the memory, the learning, the drift, the words -
-- reads the player exactly as it reads anyone else.
Cn.asserted = Cn.asserted or {}

function Cn.assert(id, set)
    if not id then return end
    Cn.asserted[tostring(id)] = set
end

-- And who forgets one. The county keeps its dead on purpose, so a
-- table keyed by a survivor id needs a death to reach it or it
-- holds entries nothing will read again ([B51]'s law). The death
-- funnel in SAO_Identity calls this the way it calls the
-- perception's and the voice's. The player's own key is not a
-- survivor id and is re-read at every creation, so it is only
-- cleared when a player's own conditions are read again.
function Cn.forget(id)
    if not id then return end
    Cn.asserted[tostring(id)] = nil
end

function Cn.has(id, key)
    local said = Cn.asserted[tostring(id)]
    if said ~= nil then return said[key] == true end
    local share = per10kFor(key, ageOf(id))
    if share <= 0 then return false end
    return (hashOf(id, "condition:" .. key) % 10000) < share
end

-- Every condition this person carries, in the fixed order.
function Cn.of(id)
    local out = {}
    for _, key in ipairs(Cn.ORDER) do
        if Cn.has(id, key) then out[#out + 1] = key end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- The day's state, for the conditions that have one. Neurodiverse
-- Traits rolls ADHD's focus and flips bipolar's phase once a day; the
-- roll here is a hash of the person and the day, so two sessions
-- agree.
-- ---------------------------------------------------------------------------
local function today()
    local day = 0
    pcall(function()
        day = math.floor(SAO.History.countyHours() / 24)
    end)
    return day
end

-- ADHD's focus: the mod's chance of a focused day is 35 percent plus
-- half a percent per day survived, to 70. The county's days survived
-- are the world's. Returns "focused" or "scattered"; nil without it.
function Cn.focusOf(id, day)
    if not Cn.has(id, "adhd") then return nil end
    day = day or today()
    local chance = math.min(35 + day * 0.5, 70)
    local roll = hashOf(id, "focus:" .. tostring(day)) % 100
    return (roll < chance) and "focused" or "scattered"
end

-- Bipolar's phase: the mod flips it every day. "high" or "low"; nil
-- without it.
function Cn.phaseOf(id, day)
    if not Cn.has(id, "bipolar") then return nil end
    day = day or today()
    return ((hashOf(id, "phase") + day) % 2 == 0) and "high" or "low"
end

-- ---------------------------------------------------------------------------
-- What the conditions do, read by the modules that decide.
-- ---------------------------------------------------------------------------

-- A bend on a temperament axis, applied where every trait is read
-- (SAO_Disposition.trait) inside the human envelope. The mods trade
-- in vanilla traits (fast and slow learner, needs less sleep); the
-- county's people have axes instead, so the bends are ours: a low
-- spell or a low condition takes initiative and appetite, a high
-- spell gives initiative and talk, a scattered day takes discipline
-- and a focused one gives it, the anxious keep to themselves.
local BEND = {
    depression = { initiative = -0.15, appetite = -0.10 },
    anxiety    = { nerve = -0.10 },
    ptsd       = { nerve = -0.05 },
}
local PHASE_BEND = {
    high = { initiative = 0.15, talkativeness = 0.15 },
    low  = { initiative = -0.15, appetite = -0.10, talkativeness = -0.10 },
}
local FOCUS_BEND = {
    focused   = { discipline = 0.15 },
    scattered = { discipline = -0.15 },
}

function Cn.bend(id, axis)
    local total = 0
    for key, bends in pairs(BEND) do
        if bends[axis] and Cn.has(id, key) then total = total + bends[axis] end
    end
    local phase = Cn.phaseOf(id)
    if phase and PHASE_BEND[phase][axis] then
        total = total + PHASE_BEND[phase][axis]
    end
    local focus = Cn.focusOf(id)
    if focus and FOCUS_BEND[focus][axis] then
        total = total + FOCUS_BEND[focus][axis]
    end
    return total
end

-- Fear a condition adds, on the same scale as a child's ([C31]):
-- the anxious carry a quarter (ours; Scotty's raises panic by five a
-- pass past forty), the haunted a constant low fear of 0.15 (Scotty's
-- hypervigilance: "constant low panic") that spikes by 0.40 when
-- something fresh and horrible is held - a death seen just now.
function Cn.fear(id, tick)
    local fear = 0
    if Cn.has(id, "anxiety") then fear = fear + 0.25 end
    if Cn.has(id, "ptsd") then
        fear = fear + 0.15
        local spike = false
        pcall(function()
            local b = SAO.Perception.beliefs[id]
            if not (b and b.people and tick) then return end
            for _, pb in pairs(b.people) do
                if pb.dead and pb.source == "observed"
                    and (tick - (pb.at or 0)) <= 1800 then
                    spike = true
                    break
                end
            end
        end)
        if spike then fear = fear + 0.40 end
    end
    return fear
end

-- How long this person keeps a recent belief, as a factor on the
-- perception's horizon: the demented keep the recent half as long
-- (ours; the mod takes skills, not memories), the old past
-- seventy-five a fifth less (the record's pattern - the old keep the
-- old and lose the recent - as a number of ours), and the haunted
-- keep a threat half again as long (Scotty's hypervigilance).
function Cn.memoryFactor(id, kind)
    local factor = 1.0
    if Cn.has(id, "dementia") then factor = factor * 0.5 end
    if ageOf(id) >= 75 then factor = factor * 0.8 end
    if kind == "zombies" and Cn.has(id, "ptsd") then factor = factor * 1.5 end
    return factor
end

-- The pace of learning a condition sets, multiplied into the shell's
-- learning pace beside the child's ([C31]): dyslexia a tenth slower
-- (Custom Traits' figure), a focused day a third faster and a
-- scattered one a third slower (the fast and slow learner traits the
-- mod swaps, which vanilla makes plus and minus thirty percent).
function Cn.learningScale(id)
    local scale = 1.0
    if Cn.has(id, "dyslexia") then scale = scale * 0.90 end
    local focus = Cn.focusOf(id)
    if focus == "focused" then scale = scale * 1.30
    elseif focus == "scattered" then scale = scale * 0.70 end
    return scale
end

-- How long a book takes: a quarter longer with dyslexia (Custom
-- Traits' figure).
function Cn.readingTime(id)
    if Cn.has(id, "dyslexia") then return 1.25 end
    return 1.0
end

-- What the body carries every ten minutes, in the age drift's own
-- terms (SAO_Age: a reserve down or a load up, at its chance). The
-- low and the sleepless tire (Scotty's: depression and insomnia raise
-- fatigue), the anxious and the haunted carry stress, the short of
-- breath lose stamina, a low spell loses stamina and a high one
-- sheds stress (Neurodiverse Traits' bipolar endurance and stress).
function Cn.drift(id)
    local out = {}
    local function add(stat, delta) out[stat] = (out[stat] or 0) + delta end
    if Cn.has(id, "depression") then add("FATIGUE", 0.010) end
    if Cn.has(id, "insomnia") then add("FATIGUE", 0.010) end
    if Cn.has(id, "anxiety") then add("STRESS", 0.010) end
    if Cn.has(id, "ptsd") then add("STRESS", 0.005) end
    if Cn.has(id, "asthma") then add("ENDURANCE", -0.010) end
    local phase = Cn.phaseOf(id)
    if phase == "low" then add("STRESS", 0.010) add("ENDURANCE", -0.005)
    elseif phase == "high" then add("STRESS", -0.010) end
    return out
end

-- The diabetic eats earlier: the hunger at which they look for food
-- comes down by 0.05 (ours).
function Cn.eatEarlier(id)
    if Cn.has(id, "diabetes") then return 0.05 end
    return 0
end

-- Dementia's day: whether today the skills lose some of what they
-- hold (Neurodiverse Traits: every day, each skill has an even chance
-- of losing 2.5 percent of the next level). The chance and the share
-- go to the bridge, which walks the skills.
Cn.SKILL_LOSS_SHARE = 0.025
Cn.SKILL_LOSS_CHANCE = 50

function Cn.losesSkillsToday(id)
    return Cn.has(id, "dementia")
end

-- Psychosis's hour: Scotty's hallucination is one in a thousand per
-- update past sixty; ours is a three percent chance per ten-minute
-- pass that this person hears a threat nobody else does. The
-- perception holds the phantom like any heard belief.
Cn.PHANTOM_CHANCE = 3

function Cn.hearsThingsNow(id, pass)
    if not Cn.has(id, "psychosis") then return false end
    return (hashOf(id, "phantom:" .. tostring(pass)) % 100) < Cn.PHANTOM_CHANCE
end

-- ---------------------------------------------------------------------------
-- In plain words, for every surface a player reads (DR-017, DR-018).
-- ---------------------------------------------------------------------------
local WORDS = {
    dementia   = "forgets things",
    adhd       = "restless mind",
    bipolar    = "high and low spells",
    depression = "low",
    anxiety    = "anxious",
    ptsd       = "haunted by it",
    insomnia   = "sleeps badly",
    dyslexia   = "reads slowly",
    psychosis  = "hears things",
    asthma     = "short of breath",
    diabetes   = "diabetic",
}

function Cn.words(id)
    local out = {}
    for _, key in ipairs(Cn.of(id)) do
        local word = WORDS[key]
        if key == "adhd" then
            local focus = Cn.focusOf(id)
            if focus == "focused" then word = "sharp today"
            elseif focus == "scattered" then word = "scattered today" end
        elseif key == "bipolar" then
            local phase = Cn.phaseOf(id)
            if phase == "high" then word = "in a high spell"
            elseif phase == "low" then word = "in a low spell" end
        end
        out[#out + 1] = word
    end
    return out
end

function Cn.describe(id)
    local words = Cn.words(id)
    if #words == 0 then return nil end
    return table.concat(words, ", ")
end

return Cn
