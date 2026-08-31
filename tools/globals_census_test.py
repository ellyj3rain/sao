#!/usr/bin/env python3
r"""Border 51 - whose namespace we are in, as the engine sees it.

This mod is going public and will share a load order with other
survivor mods. Two questions then matter and neither had an answer:
what do we reach for that is not ours, and what do we write that is
not ours.

Regex cannot answer either. `local ksData = nil` and a reference to
`ksData` fifteen hundred lines later in a different function look
identical in source and are not the same thing at all - one is a
local, the other is a global read that nobody writes. Only the
compiler knows which.

So this asks the compiler. `tools/luacheck/LuaGlobals.java` compiles
each file with Kahlua - the engine's own - and walks the bytecode for
GETGLOBAL and SETGLOBAL. The opcode numbers are verified against that
compiler rather than remembered ([B45] probed `WRITTEN = 1` and
`local x = READ_ONE` and read back op 7 and op 5). A name inside a
comment or a string is not counted; a name reached through a nested
closure is.

WHAT IT FOUND ON ITS FIRST RUN
------------------------------
`uname`, read three times in `onPlayerDeath` and declared nowhere, so
the county mourned a person called "nil" - the lesson's subject, the
log line, and the belief the walk looks up. And `ksData` at
`SAO_Harness.lua`, out of its local's scope, so a block that renders
the neighbouring mod's memorials had never run once.

Both had been in the tree for months, both read as ordinary code, and
neither was findable by grep.

THE RULES
---------
Every global we touch is classified, and the classification is exact:
a name we no longer touch must come off the list, or the list stops
describing our footprint and starts describing our history.

Every global we assign OUTRIGHT must be ours. Say precisely what that
covers, because [B45]'s lesson was about a border overstating its own
reach: `KS = {}` is a SETGLOBAL and is caught here. `KS.Notify = f` is
not - it compiles to GETGLOBAL plus SETTABLE, and the bytecode alone
does not say the table came from a global.

So the neighbour rule does not lean on that distinction. Any name in
NEIGHBOURS is another mod's namespace, and being in it AT ALL - read
or write - requires an argument, the way [B40] required one for two
reaches that shared a number and [B42] for a collision left standing.
An argument for a namespace we no longer touch is a fault in the other
direction: it has outlived what it argued about.
"""
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
SRC = ROOT / "tools" / "luacheck" / "LuaGlobals.java"
OUT = ROOT / "java" / "out" / "luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"
    r"\projectzomboid.jar")

OURS = "ours"        # our namespace; the only outright write allowed
LUA_STD = "lua"      # the standard library, as Border 48 reads it
ENGINE = "engine"    # Project Zomboid's own globals
NEIGHBOUR = "neighbour"   # another mod's; every one needs an argument

# Why we are inside somebody else's namespace. One entry per mod, and
# the sentence has to survive being read by the person who wrote it.
NEIGHBOURS = {
    "KS": "Knox Survivors. [B45] holds two of its functions - "
          "`KS.Notify`, the overhead prompt, and `KS.Say`, words over "
          "an actor - because it narrates people this county does not "
          "have (\"a living voice drops to a whisper nearby\") off a "
          "58-tile scan, and the player cannot tell that from ours. "
          "The originals are kept, every held call is counted, the "
          "count reaches the Ledger, and `SAO.Neighbours.restore()` "
          "hands them back. Held, not replaced, and never its settings "
          "- its own three tickboxes still mean what they say.",
}

KNOWN = {n: OURS for n in (
    "SAO", "SAOCountyWindow", "SAOWire", "SAOJavaBridge",
)}
KNOWN.update({n: NEIGHBOUR for n in NEIGHBOURS})
KNOWN.update({n: LUA_STD for n in (
    "error", "ipairs", "math", "pairs", "pcall", "print", "require",
    "select", "string", "table", "tonumber", "tostring", "type",
)})
KNOWN.update({n: ENGINE for n in (
    "BodyPartType", "DynamicRadio", "Events", "GameTime",
    "HaloTextHelper", "ISApplyBandage", "ISBarricadeAction",
    "ISCollapsableWindow", "ISDrinkFluidAction", "ISEatFoodAction",
    "ISFarmingMenu", "ISGrabItemAction", "ISHarvestPlantAction",
    "ISInventoryTransferAction", "ISPlowAction", "ISReloadWeaponAction",
    "ISSeedActionNew", "ISTakeWaterAction", "ISTimedActionQueue",
    "ISWaterPlantAction", "ImmutableColor", "IsoPlayer", "ItemTag",
    "ModData", "Perks", "ProceduralDistributions", "RadioBroadCast",
    "RadioLine", "SFarmingSystem", "SandboxVars", "SpawnRegionMgr",
    "SuburbsDistributions", "SurvivorFactory", "UIFont", "ZombRand",
    "addSound", "farming_vegetableconf", "getCell", "getClimateManager",
    "getCore", "getFileWriter", "getGameTime", "getSandboxOptions",
    "getScriptManager", "getSpecificPlayer", "getTextManager",
    "getTimestampMs", "getWorld", "instanceof",
)})


def build():
    cls = OUT / "LuaGlobals.class"
    if cls.exists() and cls.stat().st_mtime >= SRC.stat().st_mtime:
        return True
    OUT.mkdir(parents=True, exist_ok=True)
    done = subprocess.run(
        [str(JDK / "javac.exe"), "-cp", str(PZ), "-d", str(OUT), str(SRC)],
        capture_output=True, text=True, timeout=300)
    if done.returncode == 0:
        return True
    for line in (done.stderr or "").strip().split("\n")[:6]:
        print("    " + line)
    return False


def main():
    faults = []
    print("=" * 74)
    print("WHOSE NAMESPACE WE ARE IN")
    print("=" * 74)

    files = sorted(LUA.rglob("*.lua"))
    if not (JDK.exists() and PZ.exists() and SRC.exists()):
        print("  SKIPPED - no JDK, no engine jar, or no instrument source")
        print("  51) globals census: SKIPPED, engine absent")
        return 0
    if not build():
        print()
        print("VERDICT:")
        print("  FAULT: the globals instrument will not compile, so nothing "
              "read the bytecode this run. A border that cannot run is not "
              "a border that passed")
        return 1

    done = subprocess.run(
        [str(JDK / "java.exe"), "-cp", f"{PZ};{OUT}", "LuaGlobals"]
        + [str(p) for p in files],
        capture_output=True, text=True, timeout=600)
    root = str(ROOT) + "\\"

    touched, written, where = set(), set(), {}
    for line in (done.stdout or "").strip().split("\n"):
        if line.startswith("FAIL "):
            faults.append(
                line[5:].replace(root, "").replace("\\", "/")
                + " - the instrument could not compile this file, so its "
                "globals went uncounted; an unread file is not a clean one")
            continue
        parts = line.split(" ", 2)
        if len(parts) != 3:
            continue
        kind, name, path = parts
        touched.add(name)
        where.setdefault(name, path.replace(root, "").replace("\\", "/"))
        if kind == "SET":
            written.add(name)

    if not touched:
        faults.append(
            "not one global came back from the instrument, which cannot be "
            "true of ten thousand lines of Lua - the run failed silently")

    print(f"  globals touched: {len(touched)}   written: "
          f"{len(written)}   classified: {len(KNOWN)}")
    print("  we write outright: " + ", ".join(sorted(written)))
    print("  neighbours we are inside: "
          + (", ".join(sorted(NEIGHBOURS)) or "none"))

    for name in sorted(touched - set(KNOWN)):
        faults.append(
            f"`{name}` is touched at {where[name]} and is not classified. "
            "If it is ours, say so; if it is the engine's or the standard "
            "library's, say which. If it is neither, it is a global nobody "
            "writes and every read of it is nil - which is how [B45] "
            "found `uname` and `ksData`")

    for name in sorted(set(KNOWN) - touched):
        faults.append(
            f"`{name}` is classified here and nothing touches it any more. "
            "Delete the line: this list is what we reach for, and a list "
            "that also holds what we USED to reach for silently permits "
            "its return")

    for name in sorted(NEIGHBOURS):
        if name not in touched:
            faults.append(
                f"NEIGHBOURS argues our presence in `{name}` and nothing "
                "touches it any more. Delete the entry: an argument that "
                "outlived what it argued about describes no code")

    for name in sorted(written):
        if KNOWN.get(name) != OURS:
            faults.append(
                f"we WRITE `{name}`, which is not ours. Writing outside our "
                "own namespace is a change to somebody else's mod made from "
                "inside ours, and the load order decides who wins - that is "
                "not a thing to do by accident")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  51) globals census: all {len(touched)} globals we touch are "
          f"classified, the {len(written)} we assign outright are ours, "
          f"and each of the {len(NEIGHBOURS)} foreign namespace(s) we are "
          "inside is argued")
    return 0


if __name__ == "__main__":
    sys.exit(main())
