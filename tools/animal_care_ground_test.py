#!/usr/bin/env python3
r"""Border 156 - livestock state is read from the engine and cared for by it.

The C123 adapter may observe a designated ranch's own animal, trough and
hutch lists, then queue vanilla animal actions with real animal/item objects.
It must not manufacture a food source, treat a wild animal as a ranch animal,
or claim a Horse Mod mount when the optional machinery is absent.
"""
import pathlib
import re
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent
ANIMALS = ROOT / "java" / "src" / "com" / "sao" / "engine" / "SAOAnimals.java"
BRIDGE = ROOT / "java" / "src" / "com" / "sao" / "bridge" / "SAOBridge.java"
LUA = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Animals.lua"
CONTROLLER = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Controller.lua"


def source_faults():
    faults = []
    sources = {path: path.read_text(encoding="utf-8", errors="ignore")
               for path in (ANIMALS, BRIDGE, LUA, CONTROLLER) if path.exists()}
    if len(sources) != 4:
        return ["the C123 animal care surfaces are incomplete"]
    java = sources[ANIMALS]
    bridge = sources[BRIDGE]
    lua = sources[LUA]
    controller = sources[CONTROLLER]
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
    for guard in ("not animal.wild", "Mounts.hasMount", "Mounts.getMount",
                  "horse:getAnimalID()"):
        if guard not in lua:
            faults.append("the optional-animal guard omits " + guard)
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
    print("156) ranch lists, animal state, vanilla care, and optional horses hold")
    return 0


def source_faults_for_java(java):
    return ([] if "readyToBeMilked()" in java
            else ["the engine ranch read omits readyToBeMilked()"])


if __name__ == "__main__":
    sys.exit(main())