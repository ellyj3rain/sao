-- SAO_Traits - the county's conditions as the engine's own traits.
-- ---------------------------------------------------------------------------
-- [C39] SAO carries its own conditions (DR-032 amended). [C32] made
-- two third-party mods hard requirements so the PLAYER could have the
-- conditions the county's people carry; no code was taken from either
-- and nothing mechanical was gained. A requirement imposed on every
-- user for a surface we can build ourselves is the wrong trade, so
-- this module builds it: the conditions SAO already derives
-- (SAO_Conditions) are registered as engine character traits, the
-- player takes them at creation, and a survivor's drawn conditions
-- are stamped onto their shell as the same traits - the law
-- SAO_Body already keeps for the trade ("the body WEARS it, so
-- anything that reads descriptors sees the truth").
--
-- WHERE VANILLA ALREADY HAS ONE, VANILLA'S IS USED. Asthma and
-- insomnia are shipped traits (`ASTHMATIC`, `INSOMNIAC`); defining a
-- second of either would be two names for one fact.
--
-- Registered in shared Lua rather than through `media/registries.lua`
-- and a `character_trait_definition` script. The engine runs every
-- mod's registries file in load order in one pass, so a mod that
-- throws there takes every mod after it down with it; shared Lua
-- loads after that phase, on the server and every client. The
-- technique is Even More Traits' (CREDITS.md), verified here against
-- the installed jar rather than taken on its word: `CharacterTrait
-- .register(String)`, `CharacterTraitDefinition
-- .addCharacterTraitDefinition(trait, name, cost, desc, free,
-- disabledInMultiplayer)`, `setDescription`, `getCharacterTraits()
-- :set(trait, boolean)`, `hasTrait(trait)` (ENGINE_CONTRACT
-- Addendum F).
--
-- Everything here is idempotent: the file re-runs on every Lua reload
-- and the builder checks before it creates.

SAO = SAO or {}
SAO.Traits = SAO.Traits or {}
local T = SAO.Traits

local NAMESPACE = "SurvivorAwareness:"

-- The trait objects, by condition key.
T.objects = T.objects or {}

-- WHAT EACH CONDITION COSTS AT CREATION, AND WHY THAT NUMBER.
--
-- Not picked. Every condition names the vanilla trait whose shape is
-- closest to what SAO_Conditions actually does to a person, and takes
-- that trait's own cost - so the county's conditions are priced on
-- the game's own scale and follow it if the game moves. Border 113
-- reads vanilla's `character_traits.txt` and refuses any cost that is
-- not its anchor's.
--
-- The two conditions vanilla already ships are not priced here at
-- all: they ARE the vanilla trait.
T.ANCHOR = {
    -- it takes what you know
    dementia = "illiterate",
    -- a daily drag on attention, the scattered day against the sharp
    adhd = "slowreader",
    -- the body's own swing, spell to spell
    bipolar = "needsmoresleep",
    -- it tires you and takes the will to start
    depression = "insomniac",
    -- fear carried into the open
    anxiety = "agoraphobic",
    -- fear at the sight of the thing
    ptsd = "hemophobic",
    -- the page comes slower
    dyslexia = "slowreader",
    -- the senses report what is not there
    psychosis = "hardofhearing",
    -- the body asks for food sooner
    diabetes = "heartyappetite",
}

-- Vanilla's own costs for those anchors, read off the shipped
-- `media/scripts/generated/characters/character_traits.txt` and
-- checked against it by Border 113 every run.
T.ANCHOR_COST = {
    illiterate = -10,
    slowreader = -2,
    needsmoresleep = -4,
    insomniac = -6,
    agoraphobic = -4,
    hemophobic = -5,
    hardofhearing = -4,
    heartyappetite = -4,
    smoker = -3,                                       -- [C51]
}

-- The conditions vanilla already has a trait for: SAO uses the
-- engine's, and registers nothing.
T.VANILLA = {
    asthma = "ASTHMATIC",
    insomnia = "INSOMNIAC",
}

-- [C51] THE HABITS, on the same terms. [C39] gave the player the
-- county's conditions and left the habits behind: nothing on the
-- creation screen offered one, and nothing drove one on the player if
-- it had. SAO_Habits is the same kind of module as SAO_Conditions -
-- drawn from the person's own hash at the record's prevalence, lived
-- on the record, drifting every ten minutes - so it takes the same
-- treatment.
--
-- ONE ANCHOR FOR ALL OF THEM, and that is the honest reading rather
-- than laziness. The conditions differ in KIND, so each named the
-- vanilla trait closest to its own shape. The habits do not: every
-- one of them is a body that demands a substance and pays stress and
-- fatigue without it, differing only in schedule. The engine ships
-- exactly one trait of that shape - `base:smoker` - and prices it at
-- -3. Reaching for a sleep trait's number to make the drinker cost
-- more would be inventing a rate the game does not give, which is
-- what [C48] refused for doors and rooms. Border 113 holds the cost
-- to its anchor's either way.
T.HABIT_ANCHOR = {
    drinker    = "smoker",
    cocaine    = "smoker",
    opioids    = "smoker",
    stimulants = "smoker",
    sedatives  = "smoker",
}

-- Cannabis is NOT registered, and the reason is in SAO_Habits: N and
-- C's page gives it no withdrawal, so `USER_SCHEDULE.cannabis` is nil
-- and `Hb.drift` returns nothing for it. A costed trait on the
-- creation screen that does nothing to the player would be a lie
-- about the game, so the county draws it and the player is not
-- offered it.
T.HABIT_UNPRICED = { cannabis = "no withdrawal, so no cost to price" }

-- Smoking is the habit vanilla already has ([A14] draws it from the
-- hash at a third of the county). SAO uses the engine's trait, and
-- SAO_Disposition answers from it for the player.
T.HABIT_VANILLA = { smoker = "SMOKER" }

function T.costOf(key)
    local anchor = T.ANCHOR[key] or T.HABIT_ANCHOR[key]
    if not anchor then return nil end
    return T.ANCHOR_COST[anchor]
end

-- The engine trait for a condition or a habit ([C51]): vanilla's
-- where there is one, ours otherwise. nil when nothing is registered
-- yet.
function T.objectFor(key)
    local vanillaName = T.VANILLA[key] or T.HABIT_VANILLA[key]
    if vanillaName then
        local found = nil
        pcall(function() found = CharacterTrait[vanillaName] end)
        return found
    end
    return T.objects[key]
end

local function definitionFor(trait)
    local found = nil
    pcall(function()
        found = CharacterTraitDefinition.getCharacterTraitDefinition(trait)
    end)
    return found
end

-- Register one of ours, or recover it when a reload finds it already
-- there (`register` on a name the engine holds does not hand it back).
local function register(key)
    if T.objects[key] then return T.objects[key] end
    local full = NAMESPACE .. key
    local trait = nil
    local ok, made = pcall(function() return CharacterTrait.register(full) end)
    if ok and made ~= nil then
        trait = made
    else
        pcall(function()
            local defs = CharacterTraitDefinition.getTraits()
            for i = 0, defs:size() - 1 do
                local type = defs:get(i):getType()
                if type ~= nil and tostring(type:getName()) == full then
                    trait = type
                    return
                end
            end
        end)
    end
    if trait ~= nil then T.objects[key] = trait end
    return trait
end

-- The words a player reads are the words the county uses for the same
-- condition (DR-017): the translation carries them, and the module's
-- own plain word is the fallback when the translation has not loaded.
local function define(key)
    local trait = register(key)
    if trait == nil then return false end
    local cost = T.costOf(key)
    if cost == nil then return false end
    local nameKey = "UI_trait_SAO_" .. key
    local descKey = nameKey .. "Desc"
    local built = false
    pcall(function()
        local name = getText(nameKey)
        local desc = getText(descKey)
        local existing = definitionFor(trait)
        if existing ~= nil then
            -- A first pass before the translations load bakes the raw
            -- key into a display name that has no setter; when the
            -- text arrives, drop the stale definition and build again.
            if existing:getUIName() == nameKey and name ~= nameKey then
                pcall(function()
                    CharacterTraitDefinition.characterTraitDefinitions:remove(trait)
                    CharacterTraitDefinition.getTraits():remove(existing)
                end)
                existing = nil
            else
                if desc ~= descKey then existing:setDescription(desc) end
                built = true
                return
            end
        end
        local made = CharacterTraitDefinition.addCharacterTraitDefinition(
            trait, name, cost, "", false, false)
        if made ~= nil then
            made:setDescription(desc)
            built = true
        end
    end)
    return built
end

function T.build()
    local made = 0
    for key in pairs(T.ANCHOR) do
        if define(key) then made = made + 1 end
    end
    -- [C51] The habits, on the same builder. `costOf` reads both
    -- anchor tables, so nothing here needed a second definition path.
    for key in pairs(T.HABIT_ANCHOR) do
        if define(key) then made = made + 1 end
    end
    return made
end

-- Does this character carry the condition, as the engine sees it?
function T.has(character, key)
    local trait = T.objectFor(key)
    if trait == nil or character == nil then return false end
    local ok, held = pcall(function() return character:hasTrait(trait) end)
    return ok and held == true
end

-- Every condition the engine says this character carries.
function T.of(character)
    local out = {}
    if character == nil then return out end
    for _, key in ipairs(SAO.Conditions.ORDER) do
        if T.has(character, key) then out[#out + 1] = key end
    end
    return out
end

-- The condition rides the trait: stamp what the record drew onto the
-- body, so anything that reads a trait sees the truth. Vanilla's own
-- traits included - a survivor SAO drew asthma for is asthmatic to
-- the engine.
function T.stamp(id, character)
    if character == nil then return 0 end
    local stamped = 0
    for _, key in ipairs(SAO.Conditions.ORDER) do
        local drawn = false
        pcall(function() drawn = SAO.Conditions.has(id, key) end)
        if drawn then
            local trait = T.objectFor(key)
            if trait ~= nil then
                local ok = pcall(function()
                    character:getCharacterTraits():set(trait, true)
                end)
                if ok then stamped = stamped + 1 end
            end
        end
    end
    return stamped
end

-- [C51] The habit rides the trait too, and cannabis is skipped
-- because nothing was registered for it.
function T.stampHabits(id, character)
    if character == nil then return 0 end
    local stamped = 0
    for _, key in ipairs(SAO.Habits.ORDER) do
        local drawn = false
        pcall(function() drawn = SAO.Habits.has(id, key) end)
        if drawn then
            local trait = T.objectFor(key)
            if trait ~= nil then
                local ok = pcall(function()
                    character:getCharacterTraits():set(trait, true)
                end)
                if ok then stamped = stamped + 1 end
            end
        end
    end
    -- Smoking is vanilla's trait and is not in SAO_Habits' order, so
    -- it is stamped from where the county actually keeps it.
    local smokes = false
    pcall(function() smokes = SAO.Disposition.isSmoker(id) end)
    if smokes then
        local trait = T.objectFor("smoker")
        if trait ~= nil then
            local ok = pcall(function()
                character:getCharacterTraits():set(trait, true)
            end)
            if ok then stamped = stamped + 1 end
        end
    end
    return stamped
end

-- The player's conditions are the ones they chose, not a draw: read
-- the traits off the character and assert them, so every surface that
-- asks SAO_Conditions about this person gets the same answer it gets
-- for anyone else. [C51] The habits are read the same way, and
-- smoking off vanilla's own trait.
function T.readPlayer(player)
    if player == nil then return nil end
    local key = nil
    pcall(function() key = SAO.Standing.playerKey(player) end)
    if not key then return nil end
    local asserted = {}
    for _, condition in ipairs(SAO.Conditions.ORDER) do
        asserted[condition] = T.has(player, condition)
    end
    SAO.Conditions.assert(key, asserted)
    local habits = {}
    for _, habit in ipairs(SAO.Habits.ORDER) do
        habits[habit] = T.has(player, habit)
    end
    SAO.Habits.assert(key, habits)
    SAO.Disposition.assertSmoker(key, T.has(player, "smoker"))
    -- [C51] Somewhere for the habit to live. The player's own modData
    -- is what the save persists, so a drink taken, a habit lapsed and
    -- a habit acquired all survive the reload the way a survivor's do
    -- on their record. The dry clock starts when the character does
    -- rather than at world zero, which is what a fresh drinker's
    -- clock means.
    pcall(function()
        local md = player:getModData()
        if md == nil then return end
        md.SAOHabits = md.SAOHabits or {}
        if md.SAOHabits.lastDrinkHours == nil then
            md.SAOHabits.lastDrinkHours =
                GameTime.getInstance():getWorldAgeHours()
        end
        SAO.Habits.bindRecord(key, md.SAOHabits)
    end)
    return key
end

T.build()

if Events then
    -- Built again after the translations load, so the creation screen
    -- shows words rather than keys; idempotent either way.
    if Events.OnGameBoot then Events.OnGameBoot.Add(function() T.build() end) end
    if Events.OnCreatePlayer then
        Events.OnCreatePlayer.Add(function(_, player)
            T.build()
            T.readPlayer(player)
        end)
    end
end

return T
