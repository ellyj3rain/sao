#!/usr/bin/env python3
r"""Border 129 - loaded mutations reconcile exact native sources (R10a).

The former border certified a room-sized visit counter from
`ItemContainer.isHasBeenLooted`. That proxy could not identify the item or
fluid that changed, represented partially looted containers as full, and made
one stripped container spend unrelated sources in the same building.

This border now holds the actual contract: the player's periodic pass and
loaded survivors' completed food/water actions rescan the bounded native
chunks; reconciliation consumes exact source/item identities; and the retired
container-count bridge and place counter cannot return unnoticed.
"""
import pathlib
import sys

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
AGE = LUA / "client" / "SAO_Age.lua"
CONTROLLER = LUA / "client" / "SAO_Controller.lua"
PLACES = LUA / "shared" / "SAO_Places.lua"
WORLD = LUA / "shared" / "SAO_WorldSources.lua"
NEEDS = ROOT / "java" / "src" / "com" / "sao" / "engine" / "SAONeeds.java"
BRIDGE = ROOT / "java" / "src" / "com" / "sao" / "bridge" / "SAOBridge.java"
ENGINE = ROOT / "java" / "src" / "com" / "sao" / "engine" / "SAOWorldSources.java"
CHECK = ROOT / "tools" / "check.sh"


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") \
        if path.exists() else ""


def main():
    age = read(AGE)
    controller = read(CONTROLLER)
    places = read(PLACES)
    world = read(WORLD)
    needs = read(NEEDS)
    bridge = read(BRIDGE)
    engine = read(ENGINE)

    checks = {
        "the player periodically reconciles bounded native ground":
            "function Age.playerLoots(player)" in age
            and "SAO.WorldSources.observeAt(x, y, LOOT_REACH)" in age
            and "Age.playerLoots(me)" in age,
        "completed loaded food reconciles its exact source":
            "if SAO.Needs.eatCarried(id, body) then" in controller
            and "SAO.WorldSources.observeAt(" in controller,
        "completed loaded water reconciles its exact source":
            'agent.state == "DRINK"' in controller
            and controller.count("SAO.WorldSources.observeAt(") >= 2,
        "native observations carry exact item identities and revisions":
            "source.items[key] = item" in world
            and "revision = raw.rev" in world
            and "id = tonumber(raw.id) or 0" in world
            and "itemId = item.id" in world
            and "local parameters = option.parameters" in world
            and "itemId = parameters.itemId" in world
            and "revision = parameters.revision" in world,
        "the engine reads native item and fluid state":
            "item.getID()" in engine
            and "getFluidContainerFromSelfOrWorldItem()" in engine
            and "source.revision" in engine,
        "the old looted-container bridge is gone":
            "lootedNearby" not in needs and "lootedNearby" not in bridge,
        "room visits cannot spend stock":
            "function Pl.observeLooted" not in places
            and "function Pl.take(" not in places
            and "function Pl.isSpent" not in places,
        "the gate runs this border":
            "tools/player_looting_test.py" in read(CHECK),
    }

    print("=" * 74)
    print("LOADED MUTATIONS RECONCILE EXACT NATIVE SOURCES")
    print("=" * 74)
    faults = []
    for name, ok in checks.items():
        print(f"  {'yes' if ok else 'NO '}  {name}")
        if not ok:
            faults.append(name)

    print()
    print("VERDICT:")
    if faults:
        for fault in faults:
            print("  FAULT: " + fault)
        return 1
    print("  129) player and loaded-survivor mutations rescan exact native")
    print("       sources; item/fluid revisions replace room-sized visit counts")
    return 0


if __name__ == "__main__":
    sys.exit(main())
