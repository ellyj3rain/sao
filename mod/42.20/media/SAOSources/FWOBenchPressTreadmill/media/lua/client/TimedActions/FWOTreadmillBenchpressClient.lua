--[[
    FWO Working Bench Press & Treadmill - Client-Side Logic
    Version: 42.15.3
    
    Client-side only: Sound playback, visual effects
    XP and exercise logic is in shared/TimedActions/FWOTreadmillBenchpressExercise.lua
]]

require "TimedActions/ISFitnessAction"

-- ============================================================================
-- PER-PLAYER STATE (NOT GLOBAL)
-- ============================================================================

local playerSoundState = {}  -- Track sound state per player

-- ============================================================================
-- HELPER FUNCTIONS - CLIENT SIDE
-- ============================================================================

--- Play sound for player (broadcasts to other players in MP)
local function playExerciseSound(player, exerciseType, isEnding)
    if not player then return end

    local playerNum = player:getPlayerNum()
    local soundFile = isEnding and "FWOtreadmillend" or (exerciseType == "treadmill" and "FWOtreadmillrun" or "FWObench")
    local soundRadius = isEnding and 15 or 13
    local volume = 6

    -- Stop any existing sound (client-side tracking)
    if playerSoundState[playerNum] and playerSoundState[playerNum].gameSound then
        player:getEmitter():stopSound(playerSoundState[playerNum].gameSound)
    end

    -- Play sound - broadcasts to other players in MP!
    local gameSound = player:playSound(soundFile)
    playerSoundState[playerNum] = { gameSound = gameSound, exerciseType = exerciseType }

    -- Add to world sound system (zombies can hear)
    addSound(player, player:getX(), player:getY(), player:getZ(), soundRadius, volume)
end

--- Stop sound for player
local function stopExerciseSound(player)
    if not player or isServer() then return end

    local playerNum = player:getPlayerNum()
    if playerSoundState[playerNum] and playerSoundState[playerNum].gameSound then
        player:getEmitter():stopSound(playerSoundState[playerNum].gameSound)
        playerSoundState[playerNum] = nil
    end
end

-- ============================================================================
-- ISFitnessAction OVERRIDES - CLIENT SIDE ONLY
-- ============================================================================

-- Store vanilla methods
local vanilla_update = ISFitnessAction.update
local vanilla_stop = ISFitnessAction.stop
local vanilla_perform = ISFitnessAction.perform

-- Sound file constants
local soundFileBenchpress = "FWObench"
local soundFileTreadmill = "FWOtreadmillrun"
local soundEnd = "FWOtreadmillend"

--- Override: update - Handle sound playback (client-side only)
function ISFitnessAction:update()
    -- Handle sound playback (client-side only)
    if not isServer() and (self.exercise == "treadmill" or self.exercise == "benchpress") then
        local player = self.character
        local soundFile = self.exercise == "treadmill" and soundFileTreadmill or soundFileBenchpress

        local isPlaying = playerSoundState[player:getPlayerNum()] and
                         playerSoundState[player:getPlayerNum()].gameSound and
                         player:getEmitter():isPlaying(playerSoundState[player:getPlayerNum()].gameSound)

        if not isPlaying then
            playExerciseSound(player, self.exercise, false)
        end
    end

    -- Call vanilla update - includes setMetabolicTarget() for heat system
    vanilla_update(self)
end

--- Common cleanup function for stop/perform
local function onExerciseEnd(self)
    local player = self.character

    if self.exercise == "treadmill" or self.exercise == "benchpress" then
        -- Stop sounds
        stopExerciseSound(player)

        -- Play end sound for treadmill
        if self.exercise == "treadmill" and not isServer() then
            playExerciseSound(player, self.exercise, true)
        end
    end
end

--- Override: stop - Cleanup on stop
function ISFitnessAction:stop()
    -- Trigger exit animation even when canceling
    if self.exercise == "treadmill" or self.exercise == "benchpress" then
        emulateAnimEventOnce(self.netAction, 100, nil, "FitnessFinished=TRUE")
    end
    
    onExerciseEnd(self)
    vanilla_stop(self)
end

--- Override: perform - Cleanup on completion
function ISFitnessAction:perform()
    onExerciseEnd(self)
    vanilla_perform(self)
end
