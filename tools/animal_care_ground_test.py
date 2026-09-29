#!/usr/bin/env python3
r"""Border 156 - livestock state is read from the engine and cared for by it.

The ranch reads native state and queues native care. Horse assets and physical
execution are shipped in SAO; survivor cognition, route choice, persistence and
observation connect to that execution without an external runtime dependency.
"""
import pathlib
import re
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent
ANIMALS = ROOT / "java" / "src" / "com" / "sao" / "engine" / "SAOAnimals.java"
BRIDGE = ROOT / "java" / "src" / "com" / "sao" / "bridge" / "SAOBridge.java"
MOVEMENT = ROOT / "java" / "src" / "com" / "sao" / "engine" / "SAOMovement.java"
LUA = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Animals.lua"
CONTROLLER = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Controller.lua"
LOCOMOTION = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Locomotion.lua"
PLANNING = ROOT / "mod" / "42.20" / "media" / "lua" / "shared" / "SAO_ProceduralPlanning.lua"
OBSERVATION = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Observation.lua"
HORSE_ZONES = ROOT / "mod" / "42.20" / "media" / "lua" / "server" / "HorseMod" / "HorseZones.lua"
MOD_INFO = ROOT / "mod" / "42.20" / "mod.info"
HORSE_FILES = (
    ROOT / "mod/42.20/media/texturepacks/HorseMod.pack",
    ROOT / "mod/42.20/media/models_X/HorseMod/HorseSaddle.fbx",
    ROOT / "mod/42.20/media/anims_X/Horse/Horse_Walk.glb",
    ROOT / "mod/42.20/media/scripts/HorseMod/horse_body/stallion.txt",
    ROOT / "mod/42.20/media/lua/shared/HorseMod/Mounts.lua",
    ROOT / "mod/42.20/media/lua/shared/HorseMod/mounting/MountingUtility.lua",
    ROOT / "mod/42.20/media/lua/shared/HorseMod/riding/RidingMovement.lua",
    ROOT / "mod/42.20/media/lua/client/HorseMod/mount/Mount.lua",
)


def source_faults():
    faults = []
    sources = {path: path.read_text(encoding="utf-8", errors="ignore")
               for path in (ANIMALS, BRIDGE, MOVEMENT, LUA, CONTROLLER, LOCOMOTION,
                            PLANNING, OBSERVATION, HORSE_ZONES, MOD_INFO) if path.exists()}
    if len(sources) != 10:
        return ["the C123 animal care surfaces are incomplete"]
    java = sources[ANIMALS]
    bridge = sources[BRIDGE]
    movement = sources[MOVEMENT]
    lua = sources[LUA]
    controller = sources[CONTROLLER]
    locomotion, planning = sources[LOCOMOTION], sources[PLANNING]
    observation, mod_info = sources[OBSERVATION], sources[MOD_INFO]
    horse_zones = sources[HORSE_ZONES]
    for fact in ("DesignationZoneAnimal.getZone", "zone.getAnimals()",
                 "zone.getTroughs()", "zone.getHutchs()", "getHunger()",
                 "getThirst()", "getStress()", "getAcceptanceLevel(shell)",
                 "readyToBeMilked()", "readyToBeSheared()", "canHaveEggs()",
                 "getPossibleLuringItems(shell)"):
        if fact not in java:
            faults.append("the engine ranch read omits " + fact)
    for seam in ("animalCareNear", "animalCareTarget", "animalCareTrough",
                 "animalCareNestBox", "animalCareFeed"):
        if seam not in bridge:
            faults.append("the bridge omits " + seam)
    for action in ("ISMilkAnimal:new", "ISShearAnimal:new",
                   "ISHutchGrabEgg:new", "ISAddWaterToTrough:new",
                   "ISFeedAnimalFromHand:new", "ISPetAnimal:new"):
        if action not in lua:
            faults.append("the care path does not queue " + action)
    for guard in ("not animal.wild", 'require("HorseMod/Mounts")',
                  "Mounting.mountHorse", "HorseRiding.getMount",
                  "horse:getAnimalID()", "rec.horseMount", "A.orderTravel",
                  "A.tickTravel"):
        if guard not in lua:
            faults.append("the owned horse path omits " + guard)
    for path in HORSE_FILES:
        if not path.is_file() or path.stat().st_size == 0:
            faults.append("the integrated horse surface omits " + str(path.relative_to(ROOT)))
    mounting_utility = next(path for path in HORSE_FILES
                            if path.name == "MountingUtility.lua").read_text(
                                encoding="utf-8", errors="ignore")
    if "Mounts.hasMount(player)" not in mounting_utility or "horse_square:isBlockedTo(square)" not in mounting_utility:
        faults.append("mounted dismounting has no safe adjacent-square fallback")
    for token in ("pack=HorseMod", "tiledef=HorseMod 2026"):
        if token not in mod_info:
            faults.append("mod metadata does not load the integrated asset: " + token)
    if ("horseRoutePoint" not in bridge or "String waypoint(" not in movement
            or "MOUNTED_NODE_ADVANCE_DISTANCE" not in movement):
        faults.append("the bridge omits native horse route waypoints")
    if "SAO.Animals.orderTravel" not in locomotion or 'mode = "horse"' not in locomotion:
        faults.append("locomotion never admits the owned horse executor")
    if "function P.planHorseTravel" not in planning:
        faults.append("person-private planning omits horse travel")
    if "Horse and mounted travel" not in observation:
        faults.append("Mousecat observation omits horse state")
    if "isValidSquare" not in horse_zones or "y2 = 561  " in horse_zones:
        faults.append("horse zones do not respect the loaded world extent")
    if "SAO.Animals.care" not in controller:
        faults.append("farm work never invokes animal care")
    if "SAO.Animals.mountedHorse" not in controller:
        faults.append("mounted horses are not kept out of foot decisions")
    return faults


def parse_record(row):
    fields = row.split("@")
    if len(fields) != 19:
        return None
    try:
        numbers = [float(field) for field in fields[1:]]
    except ValueError:
        return None
    return {
        "type": fields[0], "id": int(numbers[0]), "milk": numbers[9] == 1,
        "shear": numbers[10] == 1, "eggs": int(numbers[11]),
        "water": numbers[12], "max_water": numbers[13],
        "hand_feed": numbers[14] == 1, "wild": numbers[15] == 1,
    }


def choose_action(animal, bucket, shears, water, nestbox, feed):
    if animal is None or animal["wild"]:
        return None
    if animal["milk"] and bucket:
        return "milk"
    if animal["shear"] and shears:
        return "shear"
    if animal["eggs"] > 0 and nestbox:
        return "eggs"
    if animal["water"] < animal["max_water"] and water:
        return "water"
    if animal["hand_feed"] and feed:
        return "feed"
    return "pet"


def main():
    faults = source_faults()
    ready = parse_record("cow@7@1@2@0@.2@.4@.1@.3@.5@1@1@2@4@10@1@0@0@1")
    wild = parse_record("deer@8@1@2@0@.2@.4@.1@.3@.5@1@1@2@4@10@1@1@0@0")
    if ready is None or parse_record("cow@not-a-number") is not None:
        faults.append("CONTROL record parser does not reject malformed animal data")
    elif choose_action(ready, True, True, True, True, True) != "milk":
        faults.append("CONTROL readiness does not prefer the engine milk action")
    elif choose_action(wild, True, True, True, True, True) is not None:
        faults.append("CONTROL would care for a wild animal")
    elif choose_action(ready, False, False, False, False, False) != "pet":
        faults.append("CONTROL care has no safe no-resource action")

    if ANIMALS.exists():
        java = ANIMALS.read_text(encoding="utf-8", errors="ignore")
        bad = java.replace("readyToBeMilked()", "notReadyToBeMilked()", 1)
        if bad == java or not any("readyToBeMilked()" in fault
                                  for fault in source_faults_for_java(bad)):
            faults.append("CONTROL removed milk readiness but the border passed")

    if faults:
        for fault in faults:
            print("FAULT: " + fault)
        return 1
    print("156) ranch care and source-owned horse assets, planning, execution, persistence and observation hold")
    return 0


def source_faults_for_java(java):
    return ([] if "readyToBeMilked()" in java
            else ["the engine ranch read omits readyToBeMilked()"])


if __name__ == "__main__":
    sys.exit(main())
