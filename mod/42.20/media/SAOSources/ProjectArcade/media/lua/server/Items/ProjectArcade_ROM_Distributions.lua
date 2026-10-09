require 'Items/ProceduralDistributions'

-- Sandbox helpers (ROM distribution)
local function _paSandbox()
    return SandboxVars and SandboxVars.ProjectArcade or nil
end

local function _paPct(name, def)
    local sv = _paSandbox()
    local v = sv and sv[name]
    v = tonumber(v)
    if not v then return def end
    if v < 0 then v = 0 end
    return v
end

local function _scaleAllProjectArcadeROMWeights(mult)
    if not (ProceduralDistributions and ProceduralDistributions.list) then return end
    for _, dist in pairs(ProceduralDistributions.list) do
        local items = dist and dist.items
        if items then
            for i = 1, #items, 2 do
                local ft = items[i]
                if type(ft) == 'string' and ft:find('^ProjectArcade%.ArcadeROM_') and type(items[i + 1]) == 'number' then
                    items[i + 1] = items[i + 1] * mult
                end
            end
        end
    end
end

local _ROM_PCT = _paPct('ROMDistPct', 100)
if _ROM_PCT <= 0 then
    return
end

table.insert(ProceduralDistributions["list"]["ArmyStorageElectronics"].items, "ProjectArcade.ArcadeROM_DoubleDragon");
table.insert(ProceduralDistributions["list"]["ArmyStorageElectronics"].items, 1);
table.insert(ProceduralDistributions["list"]["CabinetFactoryTools"].items, "ProjectArcade.ArcadeROM_DoubleDragon");
table.insert(ProceduralDistributions["list"]["CabinetFactoryTools"].items, 1);
table.insert(ProceduralDistributions["list"]["CrateElectronics"].items, "ProjectArcade.ArcadeROM_DoubleDragon");
table.insert(ProceduralDistributions["list"]["CrateElectronics"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreHAMRadio"].items, "ProjectArcade.ArcadeROM_DoubleDragon");
table.insert(ProceduralDistributions["list"]["ElectronicStoreHAMRadio"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreMagazines"].items, "ProjectArcade.ArcadeROM_DoubleDragon");
table.insert(ProceduralDistributions["list"]["ElectronicStoreMagazines"].items, 1);
table.insert(ProceduralDistributions["list"]["EngineerTools"].items, "ProjectArcade.ArcadeROM_DoubleDragon");
table.insert(ProceduralDistributions["list"]["EngineerTools"].items, 1);
table.insert(ProceduralDistributions["list"]["MechanicShelfElectric"].items, "ProjectArcade.ArcadeROM_DoubleDragon");
table.insert(ProceduralDistributions["list"]["MechanicShelfElectric"].items, 1);
table.insert(ProceduralDistributions["list"]["RadioFactoryComponents"].items, "ProjectArcade.ArcadeROM_DoubleDragon");
table.insert(ProceduralDistributions["list"]["RadioFactoryComponents"].items, 1);
table.insert(ProceduralDistributions["list"]["StoreShelfElectronics"].items, "ProjectArcade.ArcadeROM_DoubleDragon");
table.insert(ProceduralDistributions["list"]["StoreShelfElectronics"].items, 1);
table.insert(ProceduralDistributions["list"]["LivingRoomShelfNoTapes"].items, "ProjectArcade.ArcadeROM_DoubleDragon");
table.insert(ProceduralDistributions["list"]["LivingRoomShelfNoTapes"].items, 1);
table.insert(ProceduralDistributions["list"]["CrateToys"].items, "ProjectArcade.ArcadeROM_DoubleDragon");
table.insert(ProceduralDistributions["list"]["CrateToys"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreAppliances"].items, "ProjectArcade.ArcadeROM_DoubleDragon");
table.insert(ProceduralDistributions["list"]["ElectronicStoreAppliances"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreMisc"].items, "ProjectArcade.ArcadeROM_DoubleDragon");
table.insert(ProceduralDistributions["list"]["ElectronicStoreMisc"].items, 1);
table.insert(ProceduralDistributions["list"]["GigamartSchool"].items, "ProjectArcade.ArcadeROM_DoubleDragon");
table.insert(ProceduralDistributions["list"]["GigamartSchool"].items, 1);
table.insert(ProceduralDistributions["list"]["GigamartToys"].items, "ProjectArcade.ArcadeROM_DoubleDragon");
table.insert(ProceduralDistributions["list"]["GigamartToys"].items, 1);
table.insert(ProceduralDistributions["list"]["Hobbies"].items, "ProjectArcade.ArcadeROM_DoubleDragon");
table.insert(ProceduralDistributions["list"]["Hobbies"].items, 1);

table.insert(ProceduralDistributions["list"]["ArmyStorageElectronics"].items, "ProjectArcade.ArcadeROM_SpaceInvaders");
table.insert(ProceduralDistributions["list"]["ArmyStorageElectronics"].items, 1);
table.insert(ProceduralDistributions["list"]["CabinetFactoryTools"].items, "ProjectArcade.ArcadeROM_SpaceInvaders");
table.insert(ProceduralDistributions["list"]["CabinetFactoryTools"].items, 1);
table.insert(ProceduralDistributions["list"]["CrateElectronics"].items, "ProjectArcade.ArcadeROM_SpaceInvaders");
table.insert(ProceduralDistributions["list"]["CrateElectronics"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreHAMRadio"].items, "ProjectArcade.ArcadeROM_SpaceInvaders");
table.insert(ProceduralDistributions["list"]["ElectronicStoreHAMRadio"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreMagazines"].items, "ProjectArcade.ArcadeROM_SpaceInvaders");
table.insert(ProceduralDistributions["list"]["ElectronicStoreMagazines"].items, 1);
table.insert(ProceduralDistributions["list"]["EngineerTools"].items, "ProjectArcade.ArcadeROM_SpaceInvaders");
table.insert(ProceduralDistributions["list"]["EngineerTools"].items, 1);
table.insert(ProceduralDistributions["list"]["MechanicShelfElectric"].items, "ProjectArcade.ArcadeROM_SpaceInvaders");
table.insert(ProceduralDistributions["list"]["MechanicShelfElectric"].items, 1);
table.insert(ProceduralDistributions["list"]["RadioFactoryComponents"].items, "ProjectArcade.ArcadeROM_SpaceInvaders");
table.insert(ProceduralDistributions["list"]["RadioFactoryComponents"].items, 1);
table.insert(ProceduralDistributions["list"]["StoreShelfElectronics"].items, "ProjectArcade.ArcadeROM_SpaceInvaders");
table.insert(ProceduralDistributions["list"]["StoreShelfElectronics"].items, 1);
table.insert(ProceduralDistributions["list"]["LivingRoomShelfNoTapes"].items, "ProjectArcade.ArcadeROM_SpaceInvaders");
table.insert(ProceduralDistributions["list"]["LivingRoomShelfNoTapes"].items, 1);
table.insert(ProceduralDistributions["list"]["CrateToys"].items, "ProjectArcade.ArcadeROM_SpaceInvaders");
table.insert(ProceduralDistributions["list"]["CrateToys"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreAppliances"].items, "ProjectArcade.ArcadeROM_SpaceInvaders");
table.insert(ProceduralDistributions["list"]["ElectronicStoreAppliances"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreMisc"].items, "ProjectArcade.ArcadeROM_SpaceInvaders");
table.insert(ProceduralDistributions["list"]["ElectronicStoreMisc"].items, 1);
table.insert(ProceduralDistributions["list"]["GigamartSchool"].items, "ProjectArcade.ArcadeROM_SpaceInvaders");
table.insert(ProceduralDistributions["list"]["GigamartSchool"].items, 1);
table.insert(ProceduralDistributions["list"]["GigamartToys"].items, "ProjectArcade.ArcadeROM_SpaceInvaders");
table.insert(ProceduralDistributions["list"]["GigamartToys"].items, 1);
table.insert(ProceduralDistributions["list"]["Hobbies"].items, "ProjectArcade.ArcadeROM_SpaceInvaders");
table.insert(ProceduralDistributions["list"]["Hobbies"].items, 1);

table.insert(ProceduralDistributions["list"]["ArmyStorageElectronics"].items, "ProjectArcade.ArcadeROM_PacMan");
table.insert(ProceduralDistributions["list"]["ArmyStorageElectronics"].items, 1);
table.insert(ProceduralDistributions["list"]["CabinetFactoryTools"].items, "ProjectArcade.ArcadeROM_PacMan");
table.insert(ProceduralDistributions["list"]["CabinetFactoryTools"].items, 1);
table.insert(ProceduralDistributions["list"]["CrateElectronics"].items, "ProjectArcade.ArcadeROM_PacMan");
table.insert(ProceduralDistributions["list"]["CrateElectronics"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreHAMRadio"].items, "ProjectArcade.ArcadeROM_PacMan");
table.insert(ProceduralDistributions["list"]["ElectronicStoreHAMRadio"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreMagazines"].items, "ProjectArcade.ArcadeROM_PacMan");
table.insert(ProceduralDistributions["list"]["ElectronicStoreMagazines"].items, 1);
table.insert(ProceduralDistributions["list"]["EngineerTools"].items, "ProjectArcade.ArcadeROM_PacMan");
table.insert(ProceduralDistributions["list"]["EngineerTools"].items, 1);
table.insert(ProceduralDistributions["list"]["MechanicShelfElectric"].items, "ProjectArcade.ArcadeROM_PacMan");
table.insert(ProceduralDistributions["list"]["MechanicShelfElectric"].items, 1);
table.insert(ProceduralDistributions["list"]["RadioFactoryComponents"].items, "ProjectArcade.ArcadeROM_PacMan");
table.insert(ProceduralDistributions["list"]["RadioFactoryComponents"].items, 1);
table.insert(ProceduralDistributions["list"]["StoreShelfElectronics"].items, "ProjectArcade.ArcadeROM_PacMan");
table.insert(ProceduralDistributions["list"]["StoreShelfElectronics"].items, 1);
table.insert(ProceduralDistributions["list"]["LivingRoomShelfNoTapes"].items, "ProjectArcade.ArcadeROM_PacMan");
table.insert(ProceduralDistributions["list"]["LivingRoomShelfNoTapes"].items, 1);
table.insert(ProceduralDistributions["list"]["CrateToys"].items, "ProjectArcade.ArcadeROM_PacMan");
table.insert(ProceduralDistributions["list"]["CrateToys"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreAppliances"].items, "ProjectArcade.ArcadeROM_PacMan");
table.insert(ProceduralDistributions["list"]["ElectronicStoreAppliances"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreMisc"].items, "ProjectArcade.ArcadeROM_PacMan");
table.insert(ProceduralDistributions["list"]["ElectronicStoreMisc"].items, 1);
table.insert(ProceduralDistributions["list"]["GigamartSchool"].items, "ProjectArcade.ArcadeROM_PacMan");
table.insert(ProceduralDistributions["list"]["GigamartSchool"].items, 1);
table.insert(ProceduralDistributions["list"]["GigamartToys"].items, "ProjectArcade.ArcadeROM_PacMan");
table.insert(ProceduralDistributions["list"]["GigamartToys"].items, 1);
table.insert(ProceduralDistributions["list"]["Hobbies"].items, "ProjectArcade.ArcadeROM_PacMan");
table.insert(ProceduralDistributions["list"]["Hobbies"].items, 1);

table.insert(ProceduralDistributions["list"]["ArmyStorageElectronics"].items, "ProjectArcade.ArcadeROM_StreetFighterII");
table.insert(ProceduralDistributions["list"]["ArmyStorageElectronics"].items, 1);
table.insert(ProceduralDistributions["list"]["CabinetFactoryTools"].items, "ProjectArcade.ArcadeROM_StreetFighterII");
table.insert(ProceduralDistributions["list"]["CabinetFactoryTools"].items, 1);
table.insert(ProceduralDistributions["list"]["CrateElectronics"].items, "ProjectArcade.ArcadeROM_StreetFighterII");
table.insert(ProceduralDistributions["list"]["CrateElectronics"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreHAMRadio"].items, "ProjectArcade.ArcadeROM_StreetFighterII");
table.insert(ProceduralDistributions["list"]["ElectronicStoreHAMRadio"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreMagazines"].items, "ProjectArcade.ArcadeROM_StreetFighterII");
table.insert(ProceduralDistributions["list"]["ElectronicStoreMagazines"].items, 1);
table.insert(ProceduralDistributions["list"]["EngineerTools"].items, "ProjectArcade.ArcadeROM_StreetFighterII");
table.insert(ProceduralDistributions["list"]["EngineerTools"].items, 1);
table.insert(ProceduralDistributions["list"]["MechanicShelfElectric"].items, "ProjectArcade.ArcadeROM_StreetFighterII");
table.insert(ProceduralDistributions["list"]["MechanicShelfElectric"].items, 1);
table.insert(ProceduralDistributions["list"]["RadioFactoryComponents"].items, "ProjectArcade.ArcadeROM_StreetFighterII");
table.insert(ProceduralDistributions["list"]["RadioFactoryComponents"].items, 1);
table.insert(ProceduralDistributions["list"]["StoreShelfElectronics"].items, "ProjectArcade.ArcadeROM_StreetFighterII");
table.insert(ProceduralDistributions["list"]["StoreShelfElectronics"].items, 1);
table.insert(ProceduralDistributions["list"]["LivingRoomShelfNoTapes"].items, "ProjectArcade.ArcadeROM_StreetFighterII");
table.insert(ProceduralDistributions["list"]["LivingRoomShelfNoTapes"].items, 1);
table.insert(ProceduralDistributions["list"]["CrateToys"].items, "ProjectArcade.ArcadeROM_StreetFighterII");
table.insert(ProceduralDistributions["list"]["CrateToys"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreAppliances"].items, "ProjectArcade.ArcadeROM_StreetFighterII");
table.insert(ProceduralDistributions["list"]["ElectronicStoreAppliances"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreMisc"].items, "ProjectArcade.ArcadeROM_StreetFighterII");
table.insert(ProceduralDistributions["list"]["ElectronicStoreMisc"].items, 1);
table.insert(ProceduralDistributions["list"]["GigamartSchool"].items, "ProjectArcade.ArcadeROM_StreetFighterII");
table.insert(ProceduralDistributions["list"]["GigamartSchool"].items, 1);
table.insert(ProceduralDistributions["list"]["GigamartToys"].items, "ProjectArcade.ArcadeROM_StreetFighterII");
table.insert(ProceduralDistributions["list"]["GigamartToys"].items, 1);
table.insert(ProceduralDistributions["list"]["Hobbies"].items, "ProjectArcade.ArcadeROM_StreetFighterII");
table.insert(ProceduralDistributions["list"]["Hobbies"].items, 1);

table.insert(ProceduralDistributions["list"]["ArmyStorageElectronics"].items, "ProjectArcade.ArcadeROM_DonkeyKong");
table.insert(ProceduralDistributions["list"]["ArmyStorageElectronics"].items, 1);
table.insert(ProceduralDistributions["list"]["CabinetFactoryTools"].items, "ProjectArcade.ArcadeROM_DonkeyKong");
table.insert(ProceduralDistributions["list"]["CabinetFactoryTools"].items, 1);
table.insert(ProceduralDistributions["list"]["CrateElectronics"].items, "ProjectArcade.ArcadeROM_DonkeyKong");
table.insert(ProceduralDistributions["list"]["CrateElectronics"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreHAMRadio"].items, "ProjectArcade.ArcadeROM_DonkeyKong");
table.insert(ProceduralDistributions["list"]["ElectronicStoreHAMRadio"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreMagazines"].items, "ProjectArcade.ArcadeROM_DonkeyKong");
table.insert(ProceduralDistributions["list"]["ElectronicStoreMagazines"].items, 1);
table.insert(ProceduralDistributions["list"]["EngineerTools"].items, "ProjectArcade.ArcadeROM_DonkeyKong");
table.insert(ProceduralDistributions["list"]["EngineerTools"].items, 1);
table.insert(ProceduralDistributions["list"]["MechanicShelfElectric"].items, "ProjectArcade.ArcadeROM_DonkeyKong");
table.insert(ProceduralDistributions["list"]["MechanicShelfElectric"].items, 1);
table.insert(ProceduralDistributions["list"]["RadioFactoryComponents"].items, "ProjectArcade.ArcadeROM_DonkeyKong");
table.insert(ProceduralDistributions["list"]["RadioFactoryComponents"].items, 1);
table.insert(ProceduralDistributions["list"]["StoreShelfElectronics"].items, "ProjectArcade.ArcadeROM_DonkeyKong");
table.insert(ProceduralDistributions["list"]["StoreShelfElectronics"].items, 1);
table.insert(ProceduralDistributions["list"]["LivingRoomShelfNoTapes"].items, "ProjectArcade.ArcadeROM_DonkeyKong");
table.insert(ProceduralDistributions["list"]["LivingRoomShelfNoTapes"].items, 1);
table.insert(ProceduralDistributions["list"]["CrateToys"].items, "ProjectArcade.ArcadeROM_DonkeyKong");
table.insert(ProceduralDistributions["list"]["CrateToys"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreAppliances"].items, "ProjectArcade.ArcadeROM_DonkeyKong");
table.insert(ProceduralDistributions["list"]["ElectronicStoreAppliances"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreMisc"].items, "ProjectArcade.ArcadeROM_DonkeyKong");
table.insert(ProceduralDistributions["list"]["ElectronicStoreMisc"].items, 1);
table.insert(ProceduralDistributions["list"]["GigamartSchool"].items, "ProjectArcade.ArcadeROM_DonkeyKong");
table.insert(ProceduralDistributions["list"]["GigamartSchool"].items, 1);
table.insert(ProceduralDistributions["list"]["GigamartToys"].items, "ProjectArcade.ArcadeROM_DonkeyKong");
table.insert(ProceduralDistributions["list"]["GigamartToys"].items, 1);
table.insert(ProceduralDistributions["list"]["Hobbies"].items, "ProjectArcade.ArcadeROM_DonkeyKong");
table.insert(ProceduralDistributions["list"]["Hobbies"].items, 1);

table.insert(ProceduralDistributions["list"]["ArmyStorageElectronics"].items, "ProjectArcade.ArcadeROM_Centipede");
table.insert(ProceduralDistributions["list"]["ArmyStorageElectronics"].items, 1);
table.insert(ProceduralDistributions["list"]["CabinetFactoryTools"].items, "ProjectArcade.ArcadeROM_Centipede");
table.insert(ProceduralDistributions["list"]["CabinetFactoryTools"].items, 1);
table.insert(ProceduralDistributions["list"]["CrateElectronics"].items, "ProjectArcade.ArcadeROM_Centipede");
table.insert(ProceduralDistributions["list"]["CrateElectronics"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreHAMRadio"].items, "ProjectArcade.ArcadeROM_Centipede");
table.insert(ProceduralDistributions["list"]["ElectronicStoreHAMRadio"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreMagazines"].items, "ProjectArcade.ArcadeROM_Centipede");
table.insert(ProceduralDistributions["list"]["ElectronicStoreMagazines"].items, 1);
table.insert(ProceduralDistributions["list"]["EngineerTools"].items, "ProjectArcade.ArcadeROM_Centipede");
table.insert(ProceduralDistributions["list"]["EngineerTools"].items, 1);
table.insert(ProceduralDistributions["list"]["MechanicShelfElectric"].items, "ProjectArcade.ArcadeROM_Centipede");
table.insert(ProceduralDistributions["list"]["MechanicShelfElectric"].items, 1);
table.insert(ProceduralDistributions["list"]["RadioFactoryComponents"].items, "ProjectArcade.ArcadeROM_Centipede");
table.insert(ProceduralDistributions["list"]["RadioFactoryComponents"].items, 1);
table.insert(ProceduralDistributions["list"]["StoreShelfElectronics"].items, "ProjectArcade.ArcadeROM_Centipede");
table.insert(ProceduralDistributions["list"]["StoreShelfElectronics"].items, 1);
table.insert(ProceduralDistributions["list"]["LivingRoomShelfNoTapes"].items, "ProjectArcade.ArcadeROM_Centipede");
table.insert(ProceduralDistributions["list"]["LivingRoomShelfNoTapes"].items, 1);
table.insert(ProceduralDistributions["list"]["CrateToys"].items, "ProjectArcade.ArcadeROM_Centipede");
table.insert(ProceduralDistributions["list"]["CrateToys"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreAppliances"].items, "ProjectArcade.ArcadeROM_Centipede");
table.insert(ProceduralDistributions["list"]["ElectronicStoreAppliances"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreMisc"].items, "ProjectArcade.ArcadeROM_Centipede");
table.insert(ProceduralDistributions["list"]["ElectronicStoreMisc"].items, 1);
table.insert(ProceduralDistributions["list"]["GigamartSchool"].items, "ProjectArcade.ArcadeROM_Centipede");
table.insert(ProceduralDistributions["list"]["GigamartSchool"].items, 1);
table.insert(ProceduralDistributions["list"]["GigamartToys"].items, "ProjectArcade.ArcadeROM_Centipede");
table.insert(ProceduralDistributions["list"]["GigamartToys"].items, 1);
table.insert(ProceduralDistributions["list"]["Hobbies"].items, "ProjectArcade.ArcadeROM_Centipede");
table.insert(ProceduralDistributions["list"]["Hobbies"].items, 1);

table.insert(ProceduralDistributions["list"]["ArmyStorageElectronics"].items, "ProjectArcade.ArcadeROM_DigDug");
table.insert(ProceduralDistributions["list"]["ArmyStorageElectronics"].items, 1);
table.insert(ProceduralDistributions["list"]["CabinetFactoryTools"].items, "ProjectArcade.ArcadeROM_DigDug");
table.insert(ProceduralDistributions["list"]["CabinetFactoryTools"].items, 1);
table.insert(ProceduralDistributions["list"]["CrateElectronics"].items, "ProjectArcade.ArcadeROM_DigDug");
table.insert(ProceduralDistributions["list"]["CrateElectronics"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreHAMRadio"].items, "ProjectArcade.ArcadeROM_DigDug");
table.insert(ProceduralDistributions["list"]["ElectronicStoreHAMRadio"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreMagazines"].items, "ProjectArcade.ArcadeROM_DigDug");
table.insert(ProceduralDistributions["list"]["ElectronicStoreMagazines"].items, 1);
table.insert(ProceduralDistributions["list"]["EngineerTools"].items, "ProjectArcade.ArcadeROM_DigDug");
table.insert(ProceduralDistributions["list"]["EngineerTools"].items, 1);
table.insert(ProceduralDistributions["list"]["MechanicShelfElectric"].items, "ProjectArcade.ArcadeROM_DigDug");
table.insert(ProceduralDistributions["list"]["MechanicShelfElectric"].items, 1);
table.insert(ProceduralDistributions["list"]["RadioFactoryComponents"].items, "ProjectArcade.ArcadeROM_DigDug");
table.insert(ProceduralDistributions["list"]["RadioFactoryComponents"].items, 1);
table.insert(ProceduralDistributions["list"]["StoreShelfElectronics"].items, "ProjectArcade.ArcadeROM_DigDug");
table.insert(ProceduralDistributions["list"]["StoreShelfElectronics"].items, 1);
table.insert(ProceduralDistributions["list"]["LivingRoomShelfNoTapes"].items, "ProjectArcade.ArcadeROM_DigDug");
table.insert(ProceduralDistributions["list"]["LivingRoomShelfNoTapes"].items, 1);
table.insert(ProceduralDistributions["list"]["CrateToys"].items, "ProjectArcade.ArcadeROM_DigDug");
table.insert(ProceduralDistributions["list"]["CrateToys"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreAppliances"].items, "ProjectArcade.ArcadeROM_DigDug");
table.insert(ProceduralDistributions["list"]["ElectronicStoreAppliances"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreMisc"].items, "ProjectArcade.ArcadeROM_DigDug");
table.insert(ProceduralDistributions["list"]["ElectronicStoreMisc"].items, 1);
table.insert(ProceduralDistributions["list"]["GigamartSchool"].items, "ProjectArcade.ArcadeROM_DigDug");
table.insert(ProceduralDistributions["list"]["GigamartSchool"].items, 1);
table.insert(ProceduralDistributions["list"]["GigamartToys"].items, "ProjectArcade.ArcadeROM_DigDug");
table.insert(ProceduralDistributions["list"]["GigamartToys"].items, 1);
table.insert(ProceduralDistributions["list"]["Hobbies"].items, "ProjectArcade.ArcadeROM_DigDug");
table.insert(ProceduralDistributions["list"]["Hobbies"].items, 1);

table.insert(ProceduralDistributions["list"]["ArmyStorageElectronics"].items, "ProjectArcade.ArcadeROM_Terminator2");
table.insert(ProceduralDistributions["list"]["ArmyStorageElectronics"].items, 1);
table.insert(ProceduralDistributions["list"]["CabinetFactoryTools"].items, "ProjectArcade.ArcadeROM_Terminator2");
table.insert(ProceduralDistributions["list"]["CabinetFactoryTools"].items, 1);
table.insert(ProceduralDistributions["list"]["CrateElectronics"].items, "ProjectArcade.ArcadeROM_Terminator2");
table.insert(ProceduralDistributions["list"]["CrateElectronics"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreHAMRadio"].items, "ProjectArcade.ArcadeROM_Terminator2");
table.insert(ProceduralDistributions["list"]["ElectronicStoreHAMRadio"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreMagazines"].items, "ProjectArcade.ArcadeROM_Terminator2");
table.insert(ProceduralDistributions["list"]["ElectronicStoreMagazines"].items, 1);
table.insert(ProceduralDistributions["list"]["EngineerTools"].items, "ProjectArcade.ArcadeROM_Terminator2");
table.insert(ProceduralDistributions["list"]["EngineerTools"].items, 1);
table.insert(ProceduralDistributions["list"]["MechanicShelfElectric"].items, "ProjectArcade.ArcadeROM_Terminator2");
table.insert(ProceduralDistributions["list"]["MechanicShelfElectric"].items, 1);
table.insert(ProceduralDistributions["list"]["RadioFactoryComponents"].items, "ProjectArcade.ArcadeROM_Terminator2");
table.insert(ProceduralDistributions["list"]["RadioFactoryComponents"].items, 1);
table.insert(ProceduralDistributions["list"]["StoreShelfElectronics"].items, "ProjectArcade.ArcadeROM_Terminator2");
table.insert(ProceduralDistributions["list"]["StoreShelfElectronics"].items, 1);
table.insert(ProceduralDistributions["list"]["LivingRoomShelfNoTapes"].items, "ProjectArcade.ArcadeROM_Terminator2");
table.insert(ProceduralDistributions["list"]["LivingRoomShelfNoTapes"].items, 1);
table.insert(ProceduralDistributions["list"]["CrateToys"].items, "ProjectArcade.ArcadeROM_Terminator2");
table.insert(ProceduralDistributions["list"]["CrateToys"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreAppliances"].items, "ProjectArcade.ArcadeROM_Terminator2");
table.insert(ProceduralDistributions["list"]["ElectronicStoreAppliances"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreMisc"].items, "ProjectArcade.ArcadeROM_Terminator2");
table.insert(ProceduralDistributions["list"]["ElectronicStoreMisc"].items, 1);
table.insert(ProceduralDistributions["list"]["GigamartSchool"].items, "ProjectArcade.ArcadeROM_Terminator2");
table.insert(ProceduralDistributions["list"]["GigamartSchool"].items, 1);
table.insert(ProceduralDistributions["list"]["GigamartToys"].items, "ProjectArcade.ArcadeROM_Terminator2");
table.insert(ProceduralDistributions["list"]["GigamartToys"].items, 1);
table.insert(ProceduralDistributions["list"]["Hobbies"].items, "ProjectArcade.ArcadeROM_Terminator2");
table.insert(ProceduralDistributions["list"]["Hobbies"].items, 1);

table.insert(ProceduralDistributions["list"]["ArmyStorageElectronics"].items, "ProjectArcade.ArcadeROM_NBAJam");
table.insert(ProceduralDistributions["list"]["ArmyStorageElectronics"].items, 1);
table.insert(ProceduralDistributions["list"]["CabinetFactoryTools"].items, "ProjectArcade.ArcadeROM_NBAJam");
table.insert(ProceduralDistributions["list"]["CabinetFactoryTools"].items, 1);
table.insert(ProceduralDistributions["list"]["CrateElectronics"].items, "ProjectArcade.ArcadeROM_NBAJam");
table.insert(ProceduralDistributions["list"]["CrateElectronics"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreHAMRadio"].items, "ProjectArcade.ArcadeROM_NBAJam");
table.insert(ProceduralDistributions["list"]["ElectronicStoreHAMRadio"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreMagazines"].items, "ProjectArcade.ArcadeROM_NBAJam");
table.insert(ProceduralDistributions["list"]["ElectronicStoreMagazines"].items, 1);
table.insert(ProceduralDistributions["list"]["EngineerTools"].items, "ProjectArcade.ArcadeROM_NBAJam");
table.insert(ProceduralDistributions["list"]["EngineerTools"].items, 1);
table.insert(ProceduralDistributions["list"]["MechanicShelfElectric"].items, "ProjectArcade.ArcadeROM_NBAJam");
table.insert(ProceduralDistributions["list"]["MechanicShelfElectric"].items, 1);
table.insert(ProceduralDistributions["list"]["RadioFactoryComponents"].items, "ProjectArcade.ArcadeROM_NBAJam");
table.insert(ProceduralDistributions["list"]["RadioFactoryComponents"].items, 1);
table.insert(ProceduralDistributions["list"]["StoreShelfElectronics"].items, "ProjectArcade.ArcadeROM_NBAJam");
table.insert(ProceduralDistributions["list"]["StoreShelfElectronics"].items, 1);
table.insert(ProceduralDistributions["list"]["LivingRoomShelfNoTapes"].items, "ProjectArcade.ArcadeROM_NBAJam");
table.insert(ProceduralDistributions["list"]["LivingRoomShelfNoTapes"].items, 1);
table.insert(ProceduralDistributions["list"]["CrateToys"].items, "ProjectArcade.ArcadeROM_NBAJam");
table.insert(ProceduralDistributions["list"]["CrateToys"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreAppliances"].items, "ProjectArcade.ArcadeROM_NBAJam");
table.insert(ProceduralDistributions["list"]["ElectronicStoreAppliances"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreMisc"].items, "ProjectArcade.ArcadeROM_NBAJam");
table.insert(ProceduralDistributions["list"]["ElectronicStoreMisc"].items, 1);
table.insert(ProceduralDistributions["list"]["GigamartSchool"].items, "ProjectArcade.ArcadeROM_NBAJam");
table.insert(ProceduralDistributions["list"]["GigamartSchool"].items, 1);
table.insert(ProceduralDistributions["list"]["GigamartToys"].items, "ProjectArcade.ArcadeROM_NBAJam");
table.insert(ProceduralDistributions["list"]["GigamartToys"].items, 1);
table.insert(ProceduralDistributions["list"]["Hobbies"].items, "ProjectArcade.ArcadeROM_NBAJam");
table.insert(ProceduralDistributions["list"]["Hobbies"].items, 1);

table.insert(ProceduralDistributions["list"]["ArmyStorageElectronics"].items, "ProjectArcade.ArcadeROM_TMNT");
table.insert(ProceduralDistributions["list"]["ArmyStorageElectronics"].items, 1);
table.insert(ProceduralDistributions["list"]["CabinetFactoryTools"].items, "ProjectArcade.ArcadeROM_TMNT");
table.insert(ProceduralDistributions["list"]["CabinetFactoryTools"].items, 1);
table.insert(ProceduralDistributions["list"]["CrateElectronics"].items, "ProjectArcade.ArcadeROM_TMNT");
table.insert(ProceduralDistributions["list"]["CrateElectronics"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreHAMRadio"].items, "ProjectArcade.ArcadeROM_TMNT");
table.insert(ProceduralDistributions["list"]["ElectronicStoreHAMRadio"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreMagazines"].items, "ProjectArcade.ArcadeROM_TMNT");
table.insert(ProceduralDistributions["list"]["ElectronicStoreMagazines"].items, 1);
table.insert(ProceduralDistributions["list"]["EngineerTools"].items, "ProjectArcade.ArcadeROM_TMNT");
table.insert(ProceduralDistributions["list"]["EngineerTools"].items, 1);
table.insert(ProceduralDistributions["list"]["MechanicShelfElectric"].items, "ProjectArcade.ArcadeROM_TMNT");
table.insert(ProceduralDistributions["list"]["MechanicShelfElectric"].items, 1);
table.insert(ProceduralDistributions["list"]["RadioFactoryComponents"].items, "ProjectArcade.ArcadeROM_TMNT");
table.insert(ProceduralDistributions["list"]["RadioFactoryComponents"].items, 1);
table.insert(ProceduralDistributions["list"]["StoreShelfElectronics"].items, "ProjectArcade.ArcadeROM_TMNT");
table.insert(ProceduralDistributions["list"]["StoreShelfElectronics"].items, 1);
table.insert(ProceduralDistributions["list"]["LivingRoomShelfNoTapes"].items, "ProjectArcade.ArcadeROM_TMNT");
table.insert(ProceduralDistributions["list"]["LivingRoomShelfNoTapes"].items, 1);
table.insert(ProceduralDistributions["list"]["CrateToys"].items, "ProjectArcade.ArcadeROM_TMNT");
table.insert(ProceduralDistributions["list"]["CrateToys"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreAppliances"].items, "ProjectArcade.ArcadeROM_TMNT");
table.insert(ProceduralDistributions["list"]["ElectronicStoreAppliances"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreMisc"].items, "ProjectArcade.ArcadeROM_TMNT");
table.insert(ProceduralDistributions["list"]["ElectronicStoreMisc"].items, 1);
table.insert(ProceduralDistributions["list"]["GigamartSchool"].items, "ProjectArcade.ArcadeROM_TMNT");
table.insert(ProceduralDistributions["list"]["GigamartSchool"].items, 1);
table.insert(ProceduralDistributions["list"]["GigamartToys"].items, "ProjectArcade.ArcadeROM_TMNT");
table.insert(ProceduralDistributions["list"]["GigamartToys"].items, 1);
table.insert(ProceduralDistributions["list"]["Hobbies"].items, "ProjectArcade.ArcadeROM_TMNT");
table.insert(ProceduralDistributions["list"]["Hobbies"].items, 1);

table.insert(ProceduralDistributions["list"]["ArmyStorageElectronics"].items, "ProjectArcade.ArcadeROM_MK");
table.insert(ProceduralDistributions["list"]["ArmyStorageElectronics"].items, 1);
table.insert(ProceduralDistributions["list"]["CabinetFactoryTools"].items, "ProjectArcade.ArcadeROM_MK");
table.insert(ProceduralDistributions["list"]["CabinetFactoryTools"].items, 1);
table.insert(ProceduralDistributions["list"]["CrateElectronics"].items, "ProjectArcade.ArcadeROM_MK");
table.insert(ProceduralDistributions["list"]["CrateElectronics"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreHAMRadio"].items, "ProjectArcade.ArcadeROM_MK");
table.insert(ProceduralDistributions["list"]["ElectronicStoreHAMRadio"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreMagazines"].items, "ProjectArcade.ArcadeROM_MK");
table.insert(ProceduralDistributions["list"]["ElectronicStoreMagazines"].items, 1);
table.insert(ProceduralDistributions["list"]["EngineerTools"].items, "ProjectArcade.ArcadeROM_MK");
table.insert(ProceduralDistributions["list"]["EngineerTools"].items, 1);
table.insert(ProceduralDistributions["list"]["MechanicShelfElectric"].items, "ProjectArcade.ArcadeROM_MK");
table.insert(ProceduralDistributions["list"]["MechanicShelfElectric"].items, 1);
table.insert(ProceduralDistributions["list"]["RadioFactoryComponents"].items, "ProjectArcade.ArcadeROM_MK");
table.insert(ProceduralDistributions["list"]["RadioFactoryComponents"].items, 1);
table.insert(ProceduralDistributions["list"]["StoreShelfElectronics"].items, "ProjectArcade.ArcadeROM_MK");
table.insert(ProceduralDistributions["list"]["StoreShelfElectronics"].items, 1);
table.insert(ProceduralDistributions["list"]["LivingRoomShelfNoTapes"].items, "ProjectArcade.ArcadeROM_MK");
table.insert(ProceduralDistributions["list"]["LivingRoomShelfNoTapes"].items, 1);
table.insert(ProceduralDistributions["list"]["CrateToys"].items, "ProjectArcade.ArcadeROM_MK");
table.insert(ProceduralDistributions["list"]["CrateToys"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreAppliances"].items, "ProjectArcade.ArcadeROM_MK");
table.insert(ProceduralDistributions["list"]["ElectronicStoreAppliances"].items, 1);
table.insert(ProceduralDistributions["list"]["ElectronicStoreMisc"].items, "ProjectArcade.ArcadeROM_MK");
table.insert(ProceduralDistributions["list"]["ElectronicStoreMisc"].items, 1);
table.insert(ProceduralDistributions["list"]["GigamartSchool"].items, "ProjectArcade.ArcadeROM_MK");
table.insert(ProceduralDistributions["list"]["GigamartSchool"].items, 1);
table.insert(ProceduralDistributions["list"]["GigamartToys"].items, "ProjectArcade.ArcadeROM_MK");
table.insert(ProceduralDistributions["list"]["GigamartToys"].items, 1);
table.insert(ProceduralDistributions["list"]["Hobbies"].items, "ProjectArcade.ArcadeROM_MK");
table.insert(ProceduralDistributions["list"]["Hobbies"].items, 1);

-- Apply sandbox multiplier after all insertions.
local _mult = _ROM_PCT / 100
if _mult ~= 1 then
    _scaleAllProjectArcadeROMWeights(_mult)
end