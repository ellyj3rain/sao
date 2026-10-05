SAO.ProceduralPlanning = nil
SAO.History.countyHours = function() return __nativeHours() + 240 end
SAO.History.ageOf = function() return 30 end
SAO.Standing.trust = function() return 0.5 end
SAO.Standing.isHostileTo = function() return false end
SAO.Standing.groupOf = function() return "private-fixture-group" end
SAO.Disposition = { traits = function(id) return { talkativeness = __talk or 0.8, discipline = 0.4 } end }
SAO.Cognition.interpretPlans = function(id, candidates) return { selected = candidates[1].id } end
-- Actual native needs, hearing, queue and ownership remain loaded. These are
-- independently supplied personal values, not a fixture-selected response.
SAO.Perception.nearestBelievedThreat = function() return __threat end
