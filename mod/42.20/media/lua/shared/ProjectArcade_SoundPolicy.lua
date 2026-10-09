-- Derived from ProjectArcade selected duration policy; original source remains in SAOSources.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("ProjectArcade") then return end
local Policy = {}
function Policy.getLoopDurationMs(soundName)
    if soundName == "PAMsfplay" then return 46000 end
    if soundName == "PAMdroidsplay" then return 30000 end
    if soundName == "PAMpinballplay" then return 29000 end
    if soundName == "PAddplay" then return 58000 end
	if soundName == "PAsiplay" then return 38000 end 
    if soundName == "PAafplay" then return 50000 end
    if soundName == "PAtzplay" then return 53000 end
    if soundName == "PAijplay" then return 60500 end
	if soundName == "PAdkplay" then return 55000 end
    if soundName == "PAt2play" then return 60000 end
    if soundName == "PAcenplay" then return 60000 end
    if soundName == "PAdigplay" then return 64000 end
    if soundName == "PAnbaplay" then return 62000 end
    if soundName == "PAtmntplay" then return 62000 end
    if soundName == "PAmkplay" then return 60000 end
    if soundName == "PAfhplay" then return 60000 end
    if soundName == "PAbk2000play" then return 70000 end
    if soundName == "PAetpmplay" then return 60000 end
    if soundName == "PAswplay" then return 60000 end
    if soundName == "PAmbplay" then return 60000 end

    return 25000
end
return Policy
