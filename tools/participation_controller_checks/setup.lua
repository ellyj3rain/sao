-- Additional inert surrounding services needed to load the complete Controller.
-- Social and native owners loaded before this file remain production modules.
Events.OnTick.Remove = function() end
Events.OnPlayerDeath = { Add = function() end, Remove = function() end }
SAO.History.ticks = function() return math.floor(SAO.History.countyHours() * 9000) end
SAO.Locomotion = { jobs = {}, cancel = function() end }
SAO.Study = { active = function() return false end }
SAO.Standing.relationsOf = function(id) return __relations[id] or {} end
