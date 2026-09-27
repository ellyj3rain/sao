-- Native loot availability for the owned consumables. The selected ordinary,
-- medical and gym weights come from the admitted source distribution; no
-- person receives a dependence or an item because a scenario needs one.
require "Items/ProceduralDistributions"
require "SAO_PharmacologyProfiles"
SAO = SAO or {}
SAO.PharmacologyLoot = SAO.PharmacologyLoot or {}
local Loot=SAO.PharmacologyLoot
local ordinary={"SedativeTablets","LongSedativeTablets","Cocaine","CocainePure",
    "Stimulant","AttentionTablets","Amphetamine","Opioid","OpioidTablets",
    "Psychedelic","PsychoactiveTablets","Cannabis","CannabisEdible"}
local medical={"SedativeTablets","LongSedativeTablets","AttentionTablets",
    "Amphetamine","OpioidTablets","MaintenanceTablets","SteroidTablets"}
Loot.rules={
    {items=ordinary,weight=.05,pools={"BathroomCabinet","BathroomCounter","BathroomShelf",
        "BedroomDresser","BedroomDresserClassy","BedroomDresserRedneck",
        "BedroomSidetable","BedroomSidetableClassy","BedroomSidetableRedneck"}},
    {items=medical,weight=.5,pools={"MedicalClinicDrugs","MedicalStorageDrugs",
        "MedicalStorageTools","StoreShelfMedical"}},
    {items={"SteroidTablets"},weight=.05,pools={"FitnessTrainer","GymLockers",
        "GymWeights","SportStorageWeights"}},
}
function Loot.install()
    local list=ProceduralDistributions and ProceduralDistributions.list
    if type(list)~="table" then return false end
    for _,rule in ipairs(Loot.rules) do
        for _,name in ipairs(rule.pools) do
            local pool=list[name]
            if type(pool)=="table" and type(pool.items)=="table" then
                for _,item in ipairs(rule.items) do
                    local full="SAO."..item
                    local present=false
                    for index=1,#pool.items,2 do
                        if pool.items[index]==full then present=true;break end
                    end
                    if not present then
                        pool.items[#pool.items+1]=full
                        pool.items[#pool.items+1]=rule.weight
                    end
                end
            end
        end
    end
    return true
end
Loot.install()
return Loot
