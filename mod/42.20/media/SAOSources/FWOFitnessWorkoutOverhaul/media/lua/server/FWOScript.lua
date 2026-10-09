--
-- FWO Fitness Workout Overhaul - Server-Side Script
-- Version: 42.15.3
--
-- Server-authoritative logic for fitness XP calculations
-- 
-- Note: The main override is in shared/TimedActions/FWOFitnessAction.lua
-- This file handles additional server-specific functionality if needed
--

-- Server-specific initialization
local function onServerInit()
    -- Any server-specific setup can go here
    -- The main fitness logic is in the shared file which loads on server too
end

-- Player connect handler (server-side)
local function onPlayerConnect(player)
    if not player or player:isDead() then return end
    
    -- Ensure player's fitness data is initialized
    local fitness = player:getFitness()
    if fitness then
        fitness:init()
    end
end

-- Register server events
if not FWO_ServerEventsRegistered then
    Events.OnGameStart.Add(onServerInit)
    Events.OnConnected.Add(onPlayerConnect)
    
    FWO_ServerEventsRegistered = true
end
