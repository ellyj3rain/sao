-- Integrated source: ProjectArcade; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("ProjectArcade") then return end
local function applyNBCompat()
    local mods = getActivatedMods()
    if not (mods and mods:contains("Neat_Building")) then return end

    if _G.ProjectArcade_NBCompatPatched then return end
    if NB_BuildRecipeCode and NB_BuildRecipeCode.Floors and NB_BuildRecipeCode.Floors.OnCreate then
        _G.ProjectArcade_NBCompatPatched = true
        local original = NB_BuildRecipeCode.Floors.OnCreate

        NB_BuildRecipeCode.Floors.OnCreate = function(params)
            local ret = original(params)

            return ret
        end
    end
end
Events.OnGameBoot.Add(applyNBCompat)
Events.OnGameStart.Add(applyNBCompat)
