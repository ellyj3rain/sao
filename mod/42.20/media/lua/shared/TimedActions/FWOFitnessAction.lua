-- Integrated source: FWOFitnessWorkoutOverhaul; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("FWOFitnessWorkoutOverhaul") then return end
--
-- FWO Fitness Workout Overhaul - ISFitnessAction Override
-- Version: 42.15.3
-- 
-- FIXED: Proper multiplayer support with per-player state
-- 
-- Architecture:
-- - This file loads on BOTH client and server (shared folder)
-- - Server handles authoritative XP calculations
-- - Client handles presentation and local UI
-- - Each player has independent state (no global shared state)
--

require "TimedActions/ISFitnessAction"

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

local perk_boost_map = {
    [1] = 1.75,
    [2] = 2,
    [3] = 2.25,
}

-- ============================================================================
-- PER-PLAYER STATE (NOT GLOBAL - indexed by player number)
-- ============================================================================
-- CRITICAL FIX: These tables store per-player data, not shared global state
-- ============================================================================

local playerCurrentExercise = {}       -- Current exercise per player
local playerLastProcessedTime = {}     -- Timestamp-based cooldown to prevent double-processing

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

--- Get the correct player object based on environment
-- @param playerIndex number - Player index
-- @return IsoGameCharacter or nil
local function getPlayerObject(playerIndex)
    if isServer() then
        local players = getOnlinePlayers()
        if playerIndex < players:size() then
            return players:get(playerIndex)
        end
    else
        return getSpecificPlayer(playerIndex)
    end
    return nil
end

-- getPlayerNum() is the LOCAL split-screen slot (0-3), not a network-unique ID:
-- over plain network MP every remote client's own character also reports
-- playerNum 0. Keying playerCurrentExercise/playerLastProcessedTime by playerNum
-- therefore let two different network players collide on the same table slot,
-- so one player's currentExercise/regularity calc could stomp the other's mid-
-- calculation - producing exactly the erratic, cross-contaminated multipliers
-- reported between a MP host and their guest. getOnlineID() is unique per
-- connected network player; fall back to playerNum for single-player/splitscreen
-- where getOnlineID() isn't meaningful.
local function getPlayerStateKey(player)
    if not player then return nil end
    if player.getOnlineID then
        local onlineID = player:getOnlineID()
        if onlineID and onlineID >= 0 then return onlineID end
    end
    return player:getPlayerNum()
end

--- Get total player count based on environment
-- @return number
local function getPlayerCount()
    if isServer() then
        return getOnlinePlayers():size()
    else
        return getNumActivePlayers()
    end
end

--- Calculate XP multiplier for a specific player
-- @param player IsoGameCharacter - The player character
-- @param perkType Perk - The perk type (Fitness or Strength)
-- @param perkLvl number - Current perk level
-- @param avgRegularity number - Average regularity across all exercises
-- @param currentExercise string|nil - Current exercise type (per-player)
local function calcMulExe(player, perkType, perkLvl, avgRegularity, currentExercise)
    if not player or not perkType then return end
    
    local mulXP = 1
    local playerFitness = player:getFitness()
    
    -- 1. Initial Perk Bonus
    if SandboxVars.FWOFitness.InitialPerkBonus then
        local perkBoost = player:getXp():getPerkBoost(perkType)
        if perk_boost_map[perkBoost] then
            mulXP = mulXP * perk_boost_map[perkBoost]
        end
    end
    
    -- 2. Current Exercise Regularity Bonus
    -- CRITICAL: Uses passed currentExercise parameter, not global
    if SandboxVars.FWOFitness.currentExerciseRegularityBonus and currentExercise ~= nil then
        local regularity = playerFitness:getRegularity(currentExercise)
        local offset = SandboxVars.FWOFitness.currentExerciseOffset or 25
        local rate = SandboxVars.FWOFitness.currentExerciseRate or 5.0
        mulXP = mulXP + ((regularity - offset) * rate) / 100
    end
    
    -- 3. Average Exercise Regularity Bonus
    if SandboxVars.FWOFitness.AverageExerciseRegularityBonus then
        mulXP = mulXP + ((avgRegularity / 100) * SandboxVars.FWOFitness.AverageExerciseRegularityBonus)
    end
    
    -- 4. Level Bonus
    if SandboxVars.FWOFitness.LevelBonus then
        mulXP = mulXP + (perkLvl * SandboxVars.FWOFitness.LevelBonus)
    end
    
    -- 5. Space Out Exercise Bonus/Nerf
    if SandboxVars.FWOFitness.SpaceOutExercise then
        if perkType == Perks.Strength then
            local stiffnessTimer = playerFitness:getCurrentExeStiffnessTimer("arms")
            if stiffnessTimer < 60 and stiffnessTimer > 0 then
                mulXP = mulXP * (SandboxVars.FWOFitness.SpaceOutExerciseNegative or 0.90)
            end
        elseif perkType == Perks.Fitness then
            local legsTimer = playerFitness:getCurrentExeStiffnessTimer("legs")
            local absTimer = playerFitness:getCurrentExeStiffnessTimer("abs")
            if (legsTimer < 60 and legsTimer > 0) or (absTimer < 60 and absTimer > 0) then
                mulXP = mulXP * (SandboxVars.FWOFitness.SpaceOutExerciseNegative or 0.90)
            end
        end
    end
    
    -- 6. Rested Bonus (muscle soreness check)
    if SandboxVars.FWOFitness.RestedBonus then
        if playerFitness:onGoingStiffness() then
            mulXP = mulXP * (SandboxVars.FWOFitness.RestedBonusNegative or 0.90)
        end
    end
    
    -- 7. Global XP Multiplier
    if SandboxVars.FWOFitness.XPMultiplier then
        mulXP = mulXP * SandboxVars.FWOFitness.XPMultiplier
    end
    
    -- 8. Passive Multiplier (when not exercising)
    if currentExercise == nil then
        mulXP = mulXP * (SandboxVars.FWOFitness.PassiveMultiplier or 1.0)
    end
    
    -- Apply the multiplier. addXpMultiplier(perk, multiplier, minLevel, maxLevel) is a
    -- LEVEL-BRACKET gate, not a timer (confirmed against vanilla ISReadABook.lua's skill
    -- book logic, which uses the same call to bound a book's effect between its intrinsic
    -- min/max trainable level and the character's current perk level). There is no
    -- time-based decay here: the multiplier stays in the XP multiplier map, valid while
    -- perkLvl (current level) <= 10, until something overwrites or removes it.
    -- We keep it accurate by re-issuing this call on every exercise start/stop AND on the
    -- EveryTenMinutes tick (see CheckRegularity below), so it's continuously refreshed
    -- rather than left to expire on its own.
    player:getXp():addXpMultiplier(perkType, mulXP, perkLvl, 10)
end

--- Calculate average regularity and apply multipliers for a player
-- @param player IsoGameCharacter - The player character
-- @param currentExercise string|nil - Current exercise for this player
local function processPlayerRegularity(player, currentExercise)
    if not player or player:isDead() then return end
    
    local sumAverage = 0
    local count = 0
    
    for k, v in pairs(FitnessExercises.exercisesType) do
        count = count + 1
        sumAverage = sumAverage + player:getFitness():getRegularity(k)
    end
    
    if count == 0 then return end
    
    sumAverage = math.ceil(sumAverage * 100) / 100
    local totAverage = math.ceil((sumAverage / count) * 100) / 100
    
    -- Apply multipliers for both Strength and Fitness
    calcMulExe(player, Perks.Strength, player:getPerkLevel(Perks.Strength), totAverage, currentExercise)
    calcMulExe(player, Perks.Fitness, player:getPerkLevel(Perks.Fitness), totAverage, currentExercise)
end

--- Timestamp-based cooldown check
-- @param stateKey number - Per-player state key (see getPlayerStateKey)
-- @return boolean - true if should process, false if on cooldown
local function shouldProcessPlayer(stateKey)
    local currentTime = getGameTime():getCalender():getTimeInMillis()
    local lastTime = playerLastProcessedTime[stateKey] or 0
    local cooldownMS = 60000  -- 1 minute cooldown between calculations

    if lastTime > 0 and (currentTime - lastTime) < cooldownMS then
        return false
    end

    playerLastProcessedTime[stateKey] = currentTime
    return true
end

-- ============================================================================
-- ISFitnessAction OVERRIDES
-- ============================================================================

-- Store vanilla methods
local vanilla_serverStart = ISFitnessAction.serverStart
local vanilla_exeLooped = ISFitnessAction.exeLooped
local vanilla_start = ISFitnessAction.start
local vanilla_stop = ISFitnessAction.stop

--- Override: serverStart - Called on SERVER when exercise begins
-- CRITICAL FIX: Sets per-player current exercise state on SERVER (for dedicated servers)
function ISFitnessAction:serverStart()
    local stateKey = getPlayerStateKey(self.character)

    -- CRITICAL: Store exercise per-player on SERVER (dedicated servers call serverStart, not start)
    playerCurrentExercise[stateKey] = self.exercise

    -- Process regularity and apply multipliers for this player on server
    local currentExe = playerCurrentExercise[stateKey]
    if self.character and not self.character:isDead() then
        processPlayerRegularity(self.character, currentExe)
    end

    -- Call vanilla serverStart for animation period setup
    vanilla_serverStart(self)
end

--- Override: exeLooped - Called on each animation loop
-- Handles stat bonuses (boredom, unhappiness, stress reduction)
function ISFitnessAction:exeLooped()
    -- Apply mental/physical stat bonuses
    if not getActivatedMods():contains("DynamicTraits") then
        local player = self.character

        if SandboxVars.FWOFitness then
            local boredomMul = SandboxVars.FWOFitness.BoredomMultiplier or 1
            local unhappyMul = SandboxVars.FWOFitness.UnhappynessMultiplier or 1

            player:getStats():remove(CharacterStat.BOREDOM, 0.33 * boredomMul)
            player:getStats():remove(CharacterStat.UNHAPPINESS, 0.33 * unhappyMul)
            player:getStats():remove(CharacterStat.STRESS, 0.004)
            player:getStats():remove(CharacterStat.NICOTINE_WITHDRAWAL, 0.0004)
            player:getStats():remove(CharacterStat.ANGER, 0.004)
        end
    end

    -- Call vanilla for core fitness logic (XP, regularity, stamina)
    vanilla_exeLooped(self)
end

--- Override: start - Called when exercise action begins
-- CRITICAL: Sets per-player current exercise state
function ISFitnessAction:start()
    local stateKey = getPlayerStateKey(self.character)

    -- CRITICAL FIX: Store exercise per-player, not globally
    playerCurrentExercise[stateKey] = self.exercise

    -- Process regularity and apply multipliers for this player
    local currentExe = playerCurrentExercise[stateKey]
    if self.character and not self.character:isDead() then
        processPlayerRegularity(self.character, currentExe)
    end

    -- Call vanilla
    vanilla_start(self)
end

--- Override: stop - Called when exercise action ends
-- CRITICAL: Clears per-player current exercise state
function ISFitnessAction:stop()
    local stateKey = getPlayerStateKey(self.character)

    -- CRITICAL FIX: Clear only this player's exercise state
    playerCurrentExercise[stateKey] = nil

    -- Recalculate without current exercise bonus
    if self.character and not self.character:isDead() then
        processPlayerRegularity(self.character, nil)
    end

    -- Call vanilla
    vanilla_stop(self)
end

-- ============================================================================
-- GLOBAL EVENT HANDLERS
-- ============================================================================

--- Process all players - called by EveryTenMinutes
-- CRITICAL FIX: Proper server vs client player iteration
local function CheckRegularity()
    local playerCount = getPlayerCount()

    for playerIndex = 0, playerCount - 1 do
        local player = getPlayerObject(playerIndex)
        if player and not player:isDead() then
            local stateKey = getPlayerStateKey(player)
            -- Timestamp-based cooldown to prevent double-processing
            if shouldProcessPlayer(stateKey) then
                -- CRITICAL FIX: Get per-player current exercise
                local currentExe = playerCurrentExercise[stateKey]
                processPlayerRegularity(player, currentExe)
            end
        end
    end
end

--- Clean up multipliers when player disconnects
-- CRITICAL FIX: Only called on disconnect, not on save
local function disableMultiplier(player)
    if not player or player:isDead() then return end

    player:getXp():getMultiplierMap():remove(Perks.Fitness)
    player:getXp():getMultiplierMap():remove(Perks.Strength)

    -- Clean up per-player state
    local stateKey = getPlayerStateKey(player)
    playerCurrentExercise[stateKey] = nil
    playerLastProcessedTime[stateKey] = nil
end

--- Initialize on game start
local function onGameStart()
    -- Only process player 0 in single-player/hosted
    if not isServer() then
        local player = getSpecificPlayer(0)
        if player and not player:isDead() then
            processPlayerRegularity(player, playerCurrentExercise[getPlayerStateKey(player)])
        end
    end
end

--- Initialize when player connects (multiplayer)
local function onConnected(player)
    if not player or player:isDead() then return end

    local stateKey = getPlayerStateKey(player)
    processPlayerRegularity(player, playerCurrentExercise[stateKey])
end

--- Clean up when player disconnects
local function onDisconnect(player)
    if not player then return end

    local stateKey = getPlayerStateKey(player)
    disableMultiplier(player)

    -- Clean up state tables
    playerCurrentExercise[stateKey] = nil
    playerLastProcessedTime[stateKey] = nil
end

-- ============================================================================
-- EVENT REGISTRATION
-- ============================================================================

-- Only register events once (on first load)
if not FWO_EventsRegistered then
    Events.OnGameStart.Add(onGameStart)
    Events.OnConnected.Add(onConnected)
    Events.OnDisconnect.Add(onDisconnect)
    Events.EveryTenMinutes.Add(CheckRegularity)
    
    FWO_EventsRegistered = true
end
