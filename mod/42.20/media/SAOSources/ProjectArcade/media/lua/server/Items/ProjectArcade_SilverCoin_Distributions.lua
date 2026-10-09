
require "Items/ProceduralDistributions"
require "Items/SuburbsDistributions"
require "Items/Distributions"
require "Items/Distribution_BinJunk"

-- Sandbox helpers
local function _paSandbox()
    return SandboxVars and SandboxVars.ProjectArcade or nil
end

local function _paCurrencyFullType()
    local sv = _paSandbox()
    local ft = sv and sv.CurrencyFullType
    if ft then
        ft = tostring(ft):gsub("^%s+", ""):gsub("%s+$", "")
        if ft ~= "" then return ft end
    end
    return "Base.SilverCoin"
end

local function _paPct(name, def)
    local sv = _paSandbox()
    local v = sv and sv[name]
    v = tonumber(v)
    if not v then return def end
    if v < 0 then v = 0 end
    return v
end

local function _scaleProceduralItemWeight(fullType, mult)
    if not (ProceduralDistributions and ProceduralDistributions.list) then return end
    for _, dist in pairs(ProceduralDistributions.list) do
        local items = dist and dist.items
        if items then
            for i = 1, #items, 2 do
                if items[i] == fullType and type(items[i + 1]) == "number" then
                    items[i + 1] = items[i + 1] * mult
                end
            end
        end
    end
end

local function ProjectArcadeSilverCoinDistribution()
    -- If the server/admin chose a different currency, do not inject SilverCoin into the world.
    if _paCurrencyFullType() ~= "Base.SilverCoin" then return end

    local pct = _paPct("CoinDistContainersPct", 100)
    if pct <= 0 then return end
    local mult = pct / 100

    local list = ProceduralDistributions.list
    
    if list["GiftStoreToys"] then
        table.insert(list["GiftStoreToys"].items, "Base.SilverCoin");
        table.insert(list["GiftStoreToys"].items, 20);
    end
    if list["GigamartToys"] then
        table.insert(list["GigamartToys"].items, "Base.SilverCoin");
        table.insert(list["GigamartToys"].items, 20);
    end

    
    if list["CrateSpiffoMerch"] then
        table.insert(list["CrateSpiffoMerch"].items, "Base.SilverCoin");
        table.insert(list["CrateSpiffoMerch"].items, 20);
    end
    if list["SpiffosKitchenSpecial"] then
        table.insert(list["SpiffosKitchenSpecial"].items, "Base.SilverCoin");
        table.insert(list["SpiffosKitchenSpecial"].items, 20);
    end
    if list["SpiffosDesk"] then
        table.insert(list["SpiffosDesk"].items, "Base.SilverCoin");
        table.insert(list["SpiffosDesk"].items, 20);
    end
    if list["SpiffosDiningCounter"] then
        table.insert(list["SpiffosDiningCounter"].items, "Base.SilverCoin");
        table.insert(list["SpiffosDiningCounter"].items, 20);
    end
    if list["SpiffosKitchenButcher"] then
        table.insert(list["SpiffosKitchenButcher"].items, "Base.SilverCoin");
        table.insert(list["SpiffosKitchenButcher"].items, 10);
    end
    if list["SpiffosKitchenSauce"] then
        table.insert(list["SpiffosKitchenSauce"].items, "Base.SilverCoin");
        table.insert(list["SpiffosKitchenSauce"].items, 10);
    end
    if list["SpiffosKitchenBags"] then
        table.insert(list["SpiffosKitchenBags"].items, "Base.SilverCoin");
        table.insert(list["SpiffosKitchenBags"].items, 20);
    end
    if list["SpiffosKitchenTrays"] then
        table.insert(list["SpiffosKitchenTrays"].items, "Base.SilverCoin");
        table.insert(list["SpiffosKitchenTrays"].items, 20);
    end
    if list["CratePaperBagSpiffos"] then
        table.insert(list["CratePaperBagSpiffos"].items, "Base.SilverCoin");
        table.insert(list["CratePaperBagSpiffos"].items, 20);
    end

    
    if list["CarnivalPrizes"] then
        table.insert(list["CarnivalPrizes"].items, "Base.SilverCoin");
        table.insert(list["CarnivalPrizes"].items, 0.1);
    end

    
    if list["Gifts"] then
        table.insert(list["Gifts"].items, "Base.SilverCoin");
        table.insert(list["Gifts"].items, 10);
    end
    if list["HolidayStuff"] then
        table.insert(list["HolidayStuff"].items, "Base.SilverCoin");
        table.insert(list["HolidayStuff"].items, 10);
    end
    if list["CrateToys"] then
        table.insert(list["CrateToys"].items, "Base.SilverCoin");
        table.insert(list["CrateToys"].items, 10);
    end
    if list["Hobbies"] then
        table.insert(list["Hobbies"].items, "Base.SilverCoin");
        table.insert(list["Hobbies"].items, 10);
    end

    
    if list["DaycareCounter"] then
        table.insert(list["DaycareCounter"].items, "Base.SilverCoin");
        table.insert(list["DaycareCounter"].items, 1);
    end
    if list["DaycareDesk"] then
        table.insert(list["DaycareDesk"].items, "Base.SilverCoin");
        table.insert(list["DaycareDesk"].items, 1);
    end
    if list["DaycareShelves"] then
        table.insert(list["DaycareShelves"].items, "Base.SilverCoin");
        table.insert(list["DaycareShelves"].items, 1);
    end

    
    if list["BedroomDresserChild"] then
        table.insert(list["BedroomDresserChild"].items, "Base.SilverCoin");
        table.insert(list["BedroomDresserChild"].items, 0.5);
    end
    if list["BedroomSidetableChild"] then
        table.insert(list["BedroomSidetableChild"].items, "Base.SilverCoin");
        table.insert(list["BedroomSidetableChild"].items, 0.5);
    end
    if list["WardrobeChild"] then
        table.insert(list["WardrobeChild"].items, "Base.SilverCoin");
        table.insert(list["WardrobeChild"].items, 0.5);
    end

    
    if list["SchoolLockers"] then
        table.insert(list["SchoolLockers"].items, "Base.SilverCoin");
        table.insert(list["SchoolLockers"].items, 1);
    end
    if list["ClassroomMisc"] then
        table.insert(list["ClassroomMisc"].items, "Base.SilverCoin");
        table.insert(list["ClassroomMisc"].items, 1);
    end
    if list["ClassroomDesk"] then
        table.insert(list["ClassroomDesk"].items, "Base.SilverCoin");
        table.insert(list["ClassroomDesk"].items, 1);
    end
    if list["ClassroomShelves"] then
        table.insert(list["ClassroomShelves"].items, "Base.SilverCoin");
        table.insert(list["ClassroomShelves"].items, 1);
    end
    if list["ScienceMisc"] then
        table.insert(list["ScienceMisc"].items, "Base.SilverCoin");
        table.insert(list["ScienceMisc"].items, 1);
    end
    if list["GigamartSchool"] then
        table.insert(list["GigamartSchool"].items, "Base.SilverCoin");
        table.insert(list["GigamartSchool"].items, 1);
    end

    
    if list["CratePopcorn"] then
        table.insert(list["CratePopcorn"].items, "Base.SilverCoin");
        table.insert(list["CratePopcorn"].items, 5);
    end
    if list["CrateSodaBottles"] then
        table.insert(list["CrateSodaBottles"].items, "Base.SilverCoin");
        table.insert(list["CrateSodaBottles"].items, 5);
    end
    if list["CrateSodaCans"] then
        table.insert(list["CrateSodaCans"].items, "Base.SilverCoin");
        table.insert(list["CrateSodaCans"].items, 5);
    end
    if list["TheatrePopcorn"] then
        table.insert(list["TheatrePopcorn"].items, "Base.SilverCoin");
        table.insert(list["TheatrePopcorn"].items, 5);
    end
    if list["TheatreDrinks"] then
        table.insert(list["TheatreDrinks"].items, "Base.SilverCoin");
        table.insert(list["TheatreDrinks"].items, 5);
    end
    if list["TheatreSnacks"] then
        table.insert(list["TheatreSnacks"].items, "Base.SilverCoin");
        table.insert(list["TheatreSnacks"].items, 5);
    end
    if list["TheatreLiterature"] then
        table.insert(list["TheatreLiterature"].items, "Base.SilverCoin");
        table.insert(list["TheatreLiterature"].items, 5);
    end
    if list["MovieRentalShelves"] then
        table.insert(list["MovieRentalShelves"].items, "Base.SilverCoin");
        table.insert(list["MovieRentalShelves"].items, 1);
    end

    
    if list["ArmyStorageOutfit"] then
        table.insert(list["ArmyStorageOutfit"].items, "Base.SilverCoin");
        table.insert(list["ArmyStorageOutfit"].items, 1);
    end
    if list["ArmyHangarOutfit"] then
        table.insert(list["ArmyHangarOutfit"].items, "Base.SilverCoin");
        table.insert(list["ArmyHangarOutfit"].items, 1);
    end
    if list["ArmySurplusFootwear"] then
        table.insert(list["ArmySurplusFootwear"].items, "Base.SilverCoin");
        table.insert(list["ArmySurplusFootwear"].items, 1);
    end
    if list["ArmySurplusHeadwear"] then
        table.insert(list["ArmySurplusHeadwear"].items, "Base.SilverCoin");
        table.insert(list["ArmySurplusHeadwear"].items, 1);
    end
    if list["ArmySurplusOutfit"] then
        table.insert(list["ArmySurplusOutfit"].items, "Base.SilverCoin");
        table.insert(list["ArmySurplusOutfit"].items, 1);
    end
    if list["ArmySurplusSnacks"] then
        table.insert(list["ArmySurplusSnacks"].items, "Base.SilverCoin");
        table.insert(list["ArmySurplusSnacks"].items, 1);
    end
    if list["ArmySurplusMisc"] then
        table.insert(list["ArmySurplusMisc"].items, "Base.SilverCoin");
        table.insert(list["ArmySurplusMisc"].items, 1);
    end
    if list["LockerArmyBedroom"] then
        table.insert(list["LockerArmyBedroom"].items, "Base.SilverCoin");
        table.insert(list["LockerArmyBedroom"].items, 1);
    end
    if list["ArmyBunkerLockers"] then
        table.insert(list["ArmyBunkerLockers"].items, "Base.SilverCoin");
        table.insert(list["ArmyBunkerLockers"].items, 1);
    end
    if list["ArmyBunkerStorage"] then
        table.insert(list["ArmyBunkerStorage"].items, "Base.SilverCoin");
        table.insert(list["ArmyBunkerStorage"].items, 1);
    end

    
    if list["ArmyStorageMedical"] then
        table.insert(list["ArmyStorageMedical"].items, "Base.SilverCoin");
        table.insert(list["ArmyStorageMedical"].items, 1);
    end
    if list["ArmyBunkerMedical"] then
        table.insert(list["ArmyBunkerMedical"].items, "Base.SilverCoin");
        table.insert(list["ArmyBunkerMedical"].items, 1);
    end
    if list["MedicalOfficeDesk"] then
        table.insert(list["MedicalOfficeDesk"].items, "Base.SilverCoin");
        table.insert(list["MedicalOfficeDesk"].items, 1);
    end
    if list["MedicalOfficeCounter"] then
        table.insert(list["MedicalOfficeCounter"].items, "Base.SilverCoin");
        table.insert(list["MedicalOfficeCounter"].items, 1);
    end
    if list["MedicalStorageDrugs"] then
        table.insert(list["MedicalStorageDrugs"].items, "Base.SilverCoin");
        table.insert(list["MedicalStorageDrugs"].items, 1);
    end
    if list["MedicalStorageTools"] then
        table.insert(list["MedicalStorageTools"].items, "Base.SilverCoin");
        table.insert(list["MedicalStorageTools"].items, 1);
    end
    if list["MedicalStorageOutfit"] then
        table.insert(list["MedicalStorageOutfit"].items, "Base.SilverCoin");
        table.insert(list["MedicalStorageOutfit"].items, 1);
    end
    if list["MedicalClinicTools"] then
        table.insert(list["MedicalClinicTools"].items, "Base.SilverCoin");
        table.insert(list["MedicalClinicTools"].items, 1);
    end
    if list["MedicalClinicDrugs"] then
        table.insert(list["MedicalClinicDrugs"].items, "Base.SilverCoin");
        table.insert(list["MedicalClinicDrugs"].items, 1);
    end
    if list["MedicalClinicOutfit"] then
        table.insert(list["MedicalClinicOutfit"].items, "Base.SilverCoin");
        table.insert(list["MedicalClinicOutfit"].items, 1);
    end
    if list["MedicalCabinet"] then
        table.insert(list["MedicalCabinet"].items, "Base.SilverCoin");
        table.insert(list["MedicalCabinet"].items, 1);
    end
    if list["HospitalLockers"] then
        table.insert(list["HospitalLockers"].items, "Base.SilverCoin");
        table.insert(list["HospitalLockers"].items, 1);
    end
    if list["HospitalRoomShelves"] then
        table.insert(list["HospitalRoomShelves"].items, "Base.SilverCoin");
        table.insert(list["HospitalRoomShelves"].items, 1);
    end
    if list["HospitalMagazineRack"] then
        table.insert(list["HospitalMagazineRack"].items, "Base.SilverCoin");
        table.insert(list["HospitalMagazineRack"].items, 1);
    end
    if list["HospitalRoomCounter"] then
        table.insert(list["HospitalRoomCounter"].items, "Base.SilverCoin");
        table.insert(list["HospitalRoomCounter"].items, 1);
    end
    if list["HospitalRoomWardrobe"] then
        table.insert(list["HospitalRoomWardrobe"].items, "Base.SilverCoin");
        table.insert(list["HospitalRoomWardrobe"].items, 1);
    end
    if list["StoreShelfMedical"] then
        table.insert(list["StoreShelfMedical"].items, "Base.SilverCoin");
        table.insert(list["StoreShelfMedical"].items, 4);
    end

    
    if list["BinSpiffos"] then
        table.insert(list["BinSpiffos"].items, "Base.SilverCoin");
        table.insert(list["BinSpiffos"].items, 1);
    end

    -- Apply sandbox multiplier to every SilverCoin entry (including those added above).
    if mult ~= 1 then
        _scaleProceduralItemWeight("Base.SilverCoin", mult)
    end
end


local function ProjectArcadeSilverCoinBinJunk()
    if _paCurrencyFullType() ~= "Base.SilverCoin" then return end

    local pct = _paPct("CoinDistContainersPct", 100)
    if pct <= 0 then return end
    local mult = pct / 100

    if ClutterTables and ClutterTables.BinItems then
        table.insert(ClutterTables.BinItems, "Base.SilverCoin");
        table.insert(ClutterTables.BinItems, 0.5 * mult);
    end
end


local function ProjectArcadeSilverCoinZombieLoot()
    if _paCurrencyFullType() ~= "Base.SilverCoin" then return end

    local pct = _paPct("CoinDistZombiesPct", 100)
    if pct <= 0 then return end
    local mult = pct / 100

    table.insert(SuburbsDistributions["all"]["inventoryfemale"].items, "Base.SilverCoin");
    table.insert(SuburbsDistributions["all"]["inventoryfemale"].items, 40 * mult);

    table.insert(SuburbsDistributions["all"]["inventorymale"].items, "Base.SilverCoin");
    table.insert(SuburbsDistributions["all"]["inventorymale"].items, 40 * mult);
end

Events.OnPreDistributionMerge.Add(ProjectArcadeSilverCoinDistribution)
Events.OnPreDistributionMerge.Add(ProjectArcadeSilverCoinBinJunk)
Events.OnPreDistributionMerge.Add(ProjectArcadeSilverCoinZombieLoot)
