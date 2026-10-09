-- Integrated source: FWOFitnessWorkoutOverhaul; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("FWOFitnessWorkoutOverhaul") then return end
--
-- FWO Fitness Workout Overhaul - Client-Side Script
-- Version: 42.15.3
--
-- Client-only logic (UI, input, presentation)
-- 
-- Note: The main fitness override is in shared/TimedActions/FWOFitnessAction.lua
-- which loads on both client and server
--

-- Client-specific initialization
local function onClientInit()
    -- Any client-specific setup can go here
end

-- Player-specific client initialization
local function onPlayerLoad(player)
    if not player or player:isDead() then return end
    
    -- Initialize fitness UI data for this player
    local fitness = player:getFitness()
    if fitness then
        fitness:init()
    end
end

-- Register client events
if not FWO_ClientEventsRegistered then
    Events.OnGameStart.Add(onClientInit)
    Events.OnLoad.Add(onPlayerLoad)
    
    FWO_ClientEventsRegistered = true
end
