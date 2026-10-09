-- Integrated source: FWOBenchPressTreadmill; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("FWOBenchPressTreadmill") then return end
--[[
    FWO Working Bench Press & Treadmill - Exercise Definitions
    Version: 42.15.3
    
    Adds treadmill and benchpress exercises to the vanilla fitness system
    Load order safe - checks if FitnessExercises exists before modifying
]]

-- Ensure vanilla FitnessExercises is loaded first
require "Definitions/FitnessExercises"

-- Safety check: Ensure the table exists
if not FitnessExercises or not FitnessExercises.exercisesType then
    print("ERROR: FWO Treadmill & BenchPress - FitnessExercises.exercisesType not found!")
    return
end

local fitnessXPMultiply = (SandboxVars and SandboxVars.FWOWorkingTreadmill and SandboxVars.FWOWorkingTreadmill.FitnessXPMultiply) or 1.0
local treadmillFitnessXPMod = 1.5 * fitnessXPMultiply
-- Vanilla FitnessExercise treats xpMod <= 0 as "use default 1.0", so keep the
-- value barely positive when disabled. Server-side Fitness XP rounds this to 0.
if treadmillFitnessXPMod <= 0 then treadmillFitnessXPMod = 0.000001 end

-- Add benchpress exercise
FitnessExercises.exercisesType.benchpress = {
    type = "benchpress",
    name = getText("IGUI_BenchPress"),
    tooltip = getText("IGUI_BenchPress_Tooltip"),
    stiffness = "arms,chest",
    metabolics = Metabolics.FitnessHeavy,
    xpMod = 2.2,  -- Premium strength: highest combined XP (requires bench + barbell or two dumbbells)
}

-- Add treadmill exercise
FitnessExercises.exercisesType.treadmill = {
    type = "treadmill",
    name = getText("IGUI_Treadmill"),
    tooltip = getText("IGUI_Treadmill_Tooltip"),
    stiffness = "legs",
    metabolics = Metabolics.Fitness,
    xpMod = treadmillFitnessXPMod,  -- Base 1.5, scaled before vanilla Fitness:init() copies the definition
}
