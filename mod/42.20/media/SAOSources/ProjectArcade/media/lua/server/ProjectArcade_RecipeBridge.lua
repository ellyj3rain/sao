ProjectArcade = ProjectArcade or {}
ProjectArcade.RecipeBridge = ProjectArcade.RecipeBridge or {}
ProjectArcade.RecipeBridge.Floors = ProjectArcade.RecipeBridge.Floors or {}

local function isNBActive()
    local mods = getActivatedMods()
    return mods and mods:contains("NeatBuilding")
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
