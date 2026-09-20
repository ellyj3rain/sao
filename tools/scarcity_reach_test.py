#!/usr/bin/env python3
r"""Border 45 - every material action is bounded by native source truth.

The historical border required both simulation halves to decrement a room-sized
counter. R10a removes that abstraction. Dormant arrival now demands native
ground and learns the exact observation, but it cannot credit food or water
until an actor-specific access/action executor exists. Loaded survivors mutate
PZ directly and then reconcile the same exact source ledger. Room vocabulary
remains exploration possibility only.
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
DORMANT = LUA / "client" / "SAO_DormantPopulation.lua"
LIVE = LUA / "client" / "SAO_Controller.lua"
AGE = LUA / "client" / "SAO_Age.lua"
WORLD = LUA / "shared" / "SAO_WorldSources.lua"
PLACES = LUA / "shared" / "SAO_Places.lua"


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") \
        if path.exists() else ""


def main():
    dormant = read(DORMANT)
    live = read(LIVE)
    age = read(AGE)
    world = read(WORLD)
    places = read(PLACES)

    demand = dormant.find("SAO.WorldSources.demandPlace(place)")
    learn = dormant.find("SAO.Perception.learnBuilding(id, place", demand)
    refuse = dormant.find('return false, "access-unproven"', learn)
    checks = {
        "dormant arrival orders native demand, private learning, refusal":
            -1 not in (demand, learn, refuse) and demand < learn < refuse,
        "dormant observation cannot reserve, consume, or credit need":
            "SAO.WorldSources.reserve(" not in dormant
            and "SAO.WorldSources.commit(" not in dormant
            and "rec.lastWaterDay = day" not in dormant
            and "rec.lastFoodDay = day" not in dormant,
        "reservation substrate requires proven accessibility":
            'source.access ~= "accessible"' in world,
        "a reservation hides its source without mutating observation":
            "if pendingFor(value, source.id, nil) then return 0 end"
            in world,
        "interruption releases reserved stock":
            "function WS.release" in world
            and '"night-interrupted"' in dormant
            and '"arrival-error"' in dormant,
        "loaded food and water reconcile after native mutation":
            "if SAO.Needs.eatCarried(id, body) then" in live
            and live.count("SAO.WorldSources.observeAt(") >= 2,
        "the player reconciles the same ledger":
            "SAO.WorldSources.observeAt(x, y, LOOT_REACH)" in age,
        "room vocabulary cannot create or spend stock":
            "function Pl.take(" not in places
            and "function Pl.offersNow" not in places
            and "function Pl.isSpent" not in places,
    }

    print("=" * 74)
    print("EVERY MATERIAL ACTION IS BOUNDED BY NATIVE SOURCE TRUTH")
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
    print("  45) dormant arrival learns exact native stock but awards no need;")
    print("      loaded and player mutations reconcile source identities/revisions")
    return 0


if __name__ == "__main__":
    sys.exit(main())
