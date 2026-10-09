Events.OnGameBoot.Add(function()
    local mods = getActivatedMods()
    if not (mods and mods:contains("NeatBuilding")) then return end

    if _G.ProjectArcade_NBCompatPatched then return end
    _G.ProjectArcade_NBCompatPatched = true

    if NB_BuildRecipeCode and NB_BuildRecipeCode.Floors and NB_BuildRecipeCode.Floors.OnCreate then
        local original = NB_BuildRecipeCode.Floors.OnCreate

        NB_BuildRecipeCode.Floors.OnCreate = function(params)
            local ret = original(params)

            return ret
        end
    end
end)
