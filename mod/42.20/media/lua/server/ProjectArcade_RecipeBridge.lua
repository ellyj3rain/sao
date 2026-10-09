-- Integrated source: ProjectArcade; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("ProjectArcade") then return end
ProjectArcade = ProjectArcade or {}
ProjectArcade.RecipeBridge = ProjectArcade.RecipeBridge or {}
ProjectArcade.RecipeBridge.Floors = ProjectArcade.RecipeBridge.Floors or {}

local function isNBActive()
    local mods = getActivatedMods()
    return mods and mods:contains("Neat_Building")
end

function ProjectArcade.RecipeBridge.Floors.OnIsValid(sourceItems, result)
    return BuildRecipeCode.floor.OnIsValid(sourceItems, result)
end

function ProjectArcade.RecipeBridge.Floors.OnCreate(params)
    if isNBActive()
        and NB_BuildRecipeCode
        and NB_BuildRecipeCode.Floors
        and NB_BuildRecipeCode.Floors.OnCreate
    then
        return NB_BuildRecipeCode.Floors.OnCreate(params)
    end

    if BuildRecipeCode and BuildRecipeCode.floor and BuildRecipeCode.floor.OnCreate then
        return BuildRecipeCode.floor.OnCreate(params)
    end
end
