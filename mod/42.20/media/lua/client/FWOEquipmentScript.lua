-- Integrated source: FWOBenchPressTreadmill; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("FWOBenchPressTreadmill") then return end
--
-- FWO Working Bench Press & Treadmill - Client Script
-- Version: 42.15.3
--
-- Client-side initialization for treadmill and benchpress
--

-- Client initialization
local function onClientInit()
    -- Any client-specific setup
end

-- Player load handler
local function onPlayerLoad(player)
    if not player or player:isDead() then return end
    
    -- Initialize fitness data
    local fitness = player:getFitness()
    if fitness then
        fitness:init()
    end
end

-- Register client events
if not FWO_TreadmillClientEventsRegistered then
    Events.OnGameStart.Add(onClientInit)
    Events.OnLoad.Add(onPlayerLoad)
    
    FWO_TreadmillClientEventsRegistered = true
end
