--[[
    FWO Working Bench Press & Treadmill - Exercise Logic (SHARED)
    Version: 42.15.3
    
    Features:
    - Proper multiplayer support (server-authoritative XP)
    - Heat and thirst system with sandbox customization
    - Weight-based strength training bonuses
    - Sound broadcasting to nearby players
    - Custom animation periods for treadmill/benchpress
    
    Heat/Thirst System:
    - Uses manual temperature/thirst additions per rep
    - Base values: 0.07 heat, 0.0025 thirst per rep
    - Configurable via sandbox multipliers (0.0 = disabled, 2.0 = double)
    - Works alongside vanilla metabolic system
]]

require "TimedActions/ISFitnessAction"

-- Store vanilla methods
local vanilla_waitToStart = ISFitnessAction.waitToStart
local vanilla_serverStart = ISFitnessAction.serverStart
local vanilla_exeLooped = ISFitnessAction.exeLooped

-- Custom animation periods for treadmill and benchpress
local customPeriods = {
    treadmill = 2000,
    benchpress = 2200,
}

-- ============================================================================
-- XP AWARD FUNCTION (Uses vanilla addXp for proper MP sync)
-- ============================================================================

--- Add XP for treadmill exercise
-- Uses vanilla addXp() helper for proper MP sync
-- @param player IsoGameCharacter - The player
-- @param weightMultiplier number - Strength XP multiplier based on weight carried (1.0-2.0x)
local function addTreadmillXP(player, weightMultiplier)
    if not player then return end

    -- Default multiplier if not provided
    weightMultiplier = weightMultiplier or 1.0

    local strengthXPMultiply = SandboxVars.FWOWorkingTreadmill.StrengthXPMultiply or 1
    local sprintingXPMultiply = SandboxVars.FWOWorkingTreadmill.SprintingXPMultiply or 1

    -- Sprinting XP: 0.139 per rep (increased by 25% from 0.111)
    local sprintingXp = 0.139 * sprintingXPMultiply
    -- Strength XP: 0.075 per rep, scaled by weight carried (1.0-2.0x)
    local strengthXp = 0.075 * strengthXPMultiply * weightMultiplier

    -- Always award Sprinting XP (treadmill is cardio)
    addXp(player, Perks.Sprinting, sprintingXp)
    
    -- Award Strength XP only when carrying 50%+ weight
    if player:getInventoryWeight() > player:getMaxWeight() * 0.5 then
        addXp(player, Perks.Strength, strengthXp)
    end
end

-- ============================================================================
-- ISFitnessAction OVERRIDES - SHARED (SERVER + CLIENT)
-- ============================================================================

--- Override: waitToStart - Face the equipment
function ISFitnessAction:waitToStart()
    if self.exercise == "benchpress" or self.exercise == "treadmill" then
        -- Set direction from stored value
        if self.FWOObjectFacing then
            self.character:setDir(self.FWOObjectFacing)
        end
        return self.character:shouldBeTurning()
    end
    return vanilla_waitToStart(self)
end

--- Override: serverStart - Set custom animation periods and facing (SERVER only)
function ISFitnessAction:serverStart()
    -- Only handle treadmill and benchpress exercises
    if self.exeDataType ~= "treadmill" and self.exeDataType ~= "benchpress" then
        return vanilla_serverStart(self)
    end

    -- Set facing direction using stored value
    if self.FWOObjectFacing then
        self.character:setDir(self.FWOObjectFacing)
    end

    local period = customPeriods[self.exeDataType]

    -- Fitness:init() copies exercisesType[x].xpMod into the character's own fitness
    -- state the first time it runs for that exercise; after that, the definition
    -- table is never re-read for an existing character. Refresh the treadmill's
    -- xpMod from the live sandbox setting right before init() so a mid-save
    -- FitnessXPMultiply change actually takes effect instead of staying pinned to
    -- whatever the multiplier was when this character first used the treadmill.
    if self.exeDataType == "treadmill" then
        local fitnessXPMultiply = SandboxVars.FWOWorkingTreadmill.FitnessXPMultiply or 1.0
        local treadmillFitnessXPMod = 1.5 * fitnessXPMultiply
        if treadmillFitnessXPMod <= 0 then treadmillFitnessXPMod = 0.000001 end
        FitnessExercises.exercisesType.treadmill.xpMod = treadmillFitnessXPMod
    end

    self.fitness = self.character:getFitness()
    self.fitness:init()
    self.fitness:setCurrentExercise(self.exeDataType)

    emulateAnimEvent(self.netAction, period, "ActiveAnimLooped", nil)
end

--- Override: exeLooped - Called on each animation loop (SERVER side only for XP/stats)
function ISFitnessAction:exeLooped()
    local player = self.character

    -- Set metabolic target for heat/sweat system (matches vanilla fitness)
    if self.exeData and self.exeData.metabolics then
        self.character:setMetabolicTarget(self.exeData.metabolics)
    end

    -- Only process treadmill/benchpress exercises
    if self.exercise == "treadmill" or self.exercise == "benchpress" then
        -- Ensure fitness state is active
        if self.character:getCurrentState() ~= FitnessState.instance() then
            self.character:setVariable("ExerciseType", self.exercise)
            self.character:reportEvent("EventFitness")
            self.character:clearVariable("ExerciseStarted")
            self.character:clearVariable("ExerciseEnded")
            self.character:reportEvent("EventUpdateFitness")
        end

        -- ====================================================================
        -- SERVER-AUTHORITATIVE LOGIC (XP + Stats only on server/dedicated)
        -- ====================================================================
        if isServer() or (not isClient() and not isServer()) then
            -- ====================================================================
            -- TREADMILL EXERCISE (Cardio - Higher intensity)
            -- ====================================================================
            if self.exercise == "treadmill" then
                local inventoryWeight = player:getInventoryWeight() or 0
                local maxWeight = player:getMaxWeight() or 1
                local weightRatio = inventoryWeight / maxWeight

                -- Calculate weight multiplier: 50% weight = 1.0x, 100% weight = 2.0x strength XP
                local weightMultiplier = 1.0
                if weightRatio > 0.5 then
                    weightMultiplier = 1.0 + ((weightRatio - 0.5) * 2.0)

                    -- Bonus stamina drain for weighted training. exeLooped already fires at a
                    -- fixed rate per unit of IN-GAME time (customPeriods above are simulated
                    -- ms), so a fixed number of reps always occurs over a given stretch of
                    -- game time no matter the selected speed. Multiplying by the current speed
                    -- multiplier here would make that same fixed number of reps drain
                    -- proportionally more stamina purely because the player fast-forwarded,
                    -- with no extra exertion actually happening - so we don't.
                    local extraDrain = 0.001 * weightMultiplier
                    player:getStats():remove(CharacterStat.ENDURANCE, extraDrain)
                end

                -- Award XP (Sprinting always, Strength if weighted) - SERVER ONLY
                addTreadmillXP(player, weightMultiplier)

                -- Heat & Thirst: Get sandbox multipliers (default 1.0)
                local heatMultiplier = SandboxVars.FWOWorkingTreadmill.HeatMultiplier or 1.0
                local thirstMultiplier = SandboxVars.FWOWorkingTreadmill.ThirstMultiplier or 1.0

                -- Manual temperature/thirst per rep (base: heat = 0.07, thirst = 0.0025).
                -- Not scaled by game speed - see the stamina-drain comment above.
                local tempIncrease = 0.07 * heatMultiplier
                player:getStats():add(CharacterStat.TEMPERATURE, tempIncrease)

                -- Thirst from dehydration (cardio)
                local thirstIncrease = 0.0025 * thirstMultiplier
                player:getStats():add(CharacterStat.THIRST, thirstIncrease)
            end

            -- ====================================================================
            -- BENCHPRESS EXERCISE (Strength - Moderate intensity)
            -- ====================================================================
            if self.exercise == "benchpress" then
                -- Get sandbox multipliers (default 1.0)
                local strengthXPMultiply = SandboxVars.FWOWorkingTreadmill.StrengthXPMultiply or 1.0
                local heatMultiplier = SandboxVars.FWOWorkingTreadmill.HeatMultiplier or 1.0
                local thirstMultiplier = SandboxVars.FWOWorkingTreadmill.ThirstMultiplier or 1.0

                -- Strength XP: 0.12 per rep (higher than treadmill since it's pure strength).
                -- Not scaled by game speed - see the stamina-drain comment in the treadmill
                -- branch above (exeLooped's rep rate is already fixed per unit of game time).
                local strengthXp = 0.12 * strengthXPMultiply
                addXp(player, Perks.Strength, strengthXp)

                -- Manual temperature/thirst per rep (base: heat = 0.07, thirst = 0.0025)
                local tempIncrease = 0.07 * heatMultiplier
                player:getStats():add(CharacterStat.TEMPERATURE, tempIncrease)

                -- Thirst from exertion (strength)
                local thirstIncrease = 0.0025 * thirstMultiplier
                player:getStats():add(CharacterStat.THIRST, thirstIncrease)
            end
        end

        -- Prevent sitting exploit (runs on all clients for visual feedback)
        if self.character:isSitOnGround() then
            self.character:PlayAnim("Idle")
            self.character:setVariable("ExerciseEnded", true)
            -- forceComplete() requires a full client-side ISBaseTimedAction; the dedicated
            -- server drives exeLooped through a lightweight NetTimedAction stand-in that
            -- doesn't support it, so calling it there throws "forceComplete of non-table: null".
            if not isServer() then
                self:forceComplete()  -- Use forceComplete to trigger exit animation
            end
            self.character:setFallOnFront(true)
        end

        -- Stop from exhaustion (endurance below 20%) - runs on all clients
        if self.character:getStats():get(CharacterStat.ENDURANCE) < 0.2 then
            self.character:setVariable("ExerciseEnded", "true")
            self.character:setVariable("ExerciseStarted", "false")
            self.character:reportEvent("EventUpdateFitness")
        end
    end

    -- Call vanilla for core fitness logic (stamina drain, regularity, Fitness XP)
    vanilla_exeLooped(self)
end
