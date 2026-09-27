-- Game mechanism constants and item bindings. Provenance is in the batch
-- catalogue; these are simulation rates, not medical advice or synthesis.
SAO = SAO or {}
local P = {}
-- An existing native sensitivity trait is carried, never inferred from a
-- psychiatric condition or added to population prevalence. No foreign module
-- is loaded; the legacy namespace is an existing-save identifier only.
pcall(function()
    local key=ResourceLocation.of("SurvivorAwareness:drugSensitivity")
    P.sensitivityTrait=CharacterTrait.get(key)
        or CharacterTrait.register("SurvivorAwareness:drugSensitivity")
end)
function P.sensitivityOf(body)
    local ok,value=pcall(function()
        if P.sensitivityTrait and body:hasTrait(P.sensitivityTrait) then return true end
        local old=CharacterTrait.get(ResourceLocation.of("NnC:ParanoidUser"))
        return old~=nil and body:hasTrait(old)
    end)
    return ok and value==true
end
P.order = { "sedatives", "cocaine", "stimulants", "opioids",
    "psychedelics", "cannabis", "steroids" }
P.families = {
    sedatives = { maximum=52, activeMin=2, activeMax=49, clearance=12,
        overload=1420, medium=432, bad=864, mild=1440 },
    cocaine = { maximum=18, activeMin=3, activeMax=18, clearance=24,
        overload=1410, medium=144, bad=720, mild=1440, hangover=true },
    stimulants = { maximum=65, activeMin=3, activeMax=62, clearance=12,
        overload=1420, medium=144, bad=720, mild=1440, hangover=true },
    opioids = { maximum=65, activeMin=3, activeMax=62, clearance=12,
        overload=1410, medium=144, bad=720, mild=1440, hangover=true },
    psychedelics = { maximum=65, activeMin=3, activeMax=62, clearance=12,
        overload=1420, medium=432, bad=864, mild=1440, hangover=true },
    cannabis = { maximum=21, activeMin=1, activeMax=19, clearance=0 },
    steroids = { maximum=145, activeMin=3, activeMax=144, clearance=12,
        overload=1410, medium=144, bad=720, mild=1440 },
}
-- The extra two families acquire dependence through actual use; they are not
-- added to the historically researched population prevalence distribution.
P.items = {
    ["SAO.SedativeTablets"] = { family="sedatives", onset=40, refresh=37,
        use=200, dependentUse=216, amount=144 },
    ["SAO.LongSedativeTablets"] = { family="sedatives", onset=52, refresh=49,
        use=200, dependentUse=216, amount=144 },
    ["SAO.Cocaine"] = { family="cocaine", onset=15, refresh=15,
        use=200, dependentUse=432, amount=144 },
    ["SAO.CocainePure"] = { family="cocaine", onset=18, refresh=18,
        use=400, dependentUse=432, amount=288 },
    ["SAO.Stimulant"] = { family="stimulants", onset=63, refresh=62,
        use=400, dependentUse=432, amount=144 },
    ["SAO.AttentionTablets"] = { family="stimulants", onset=65, refresh=62,
        use=0, dependentUse=0, amount=72 },
    ["SAO.Amphetamine"] = { family="stimulants", onset=64, refresh=62,
        use=300, dependentUse=200, amount=108 },
    ["SAO.Opioid"] = { family="opioids", onset=26, refresh=26,
        use=800, dependentUse=432, amount=288 },
    ["SAO.OpioidTablets"] = { family="opioids", onset=65, refresh=62,
        use=400, dependentUse=432, amount=144 },
    ["SAO.Psychedelic"] = { family="psychedelics", onset=65, refresh=62,
        use=0, dependentUse=0, amount=0 },
    ["SAO.PsychoactiveTablets"] = { family="psychedelics", onset=65, refresh=62,
        use=400, dependentUse=432, amount=144 },
    ["SAO.Cannabis"] = { family="cannabis", onset=19, refresh=18,
        use=72, dependentUse=72, amount=0, smoked=true },
    ["SAO.CannabisEdible"] = { family="cannabis", onset=21, refresh=18,
        use=72, dependentUse=72, amount=0 },
    ["SAO.SteroidTablets"] = { family="steroids", onset=145, refresh=144,
        use=300, dependentUse=200, amount=144 },
    ["SAO.MaintenanceTablets"] = { family="maintenance", onset=144 },
}
P.stats = { "HUNGER", "THIRST", "FATIGUE", "ENDURANCE", "PANIC",
    "STRESS", "NICOTINE_WITHDRAWAL", "BOREDOM", "UNHAPPINESS",
    "DISCOMFORT", "INTOXICATION", "ANGER", "PAIN" }
SAO.PharmacologyProfiles = P
return P
