-- Integrated source: FWOBenchPressTreadmill; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("FWOBenchPressTreadmill") then return end
require "ISUI/ISFitnessUI"

function ISFitnessUI:updateExercises()
	self.exercises:clear();
	
	for i,v in pairs(FitnessExercises.exercisesType) do
		if i ~= "treadmill" and i ~= "benchpress" then
			self:addExerciseToList(i, v);
		end
	end

end	