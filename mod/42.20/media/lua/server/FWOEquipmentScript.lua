-- Integrated source: FWOBenchPressTreadmill; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("FWOBenchPressTreadmill") then return end
--
-- FWO Working Bench Press & Treadmill - Server Script
-- Version: 42.15.3
--
-- Server-side initialization for treadmill and benchpress
--

-- Initialize fitness data for players
local function onPlayerConnect(player)
    if not player or player:isDead() then return end
    
    -- Ensure player's fitness data is initialized
    local fitness = player:getFitness()
    if fitness then
        fitness:init()
    end
end

-- Register server events
if not FWO_TreadmillServerEventsRegistered then
    Events.OnGameStart.Add(function()
        -- Server initialization
    end)
    Events.OnConnected.Add(onPlayerConnect)
    
    FWO_TreadmillServerEventsRegistered = true
end
