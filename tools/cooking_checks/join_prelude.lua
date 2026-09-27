-- Load-time dependencies only. Actual root Controller, Body, and production
-- CrossedTransfer load whole; only their native/source receivers are fixtures.
setmetatable(Events, { __index = function(self, key)
    local event = { Add = function() end, Remove = function() end }
    self[key] = event return event
end })
Events.OnGameStart.Remove = function() end
SAO.Log = { line = function() end }
SAO.Perception = { beliefs = {}, EARSHOT = 50 }
SAO.Standing = {} SAO.Disposition = {} SAO.Rand = {} SAO.Needs = {}
SAO.History = { countyHours = function() return 10 end }
getSpecificPlayer = function() return nil end
