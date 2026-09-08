#!/usr/bin/env python3
r"""Border 117 - they either build or they do not ([C44], DR-036 ruled).

The operator's ruling: nothing is forced. The county is not handed
fortifications and no pass authors them. People are given what they
need and either they manage it or they do not, and a county that never
manages it is telling us something about the systems rather than
telling us to place a barricade by hand.

That makes this border's job unusual. It cannot check that anything
WAS built - that is the outcome, and the outcome is the measurement.
It checks that the capability is real, that it is honest, and that
nothing anywhere fakes it.

WHAT THIS HOLDS
---------------
  1. The act is the engine's own barricade, through the engine's own
     calls, and every requirement the shipped action checks is checked
     here too: a hammer-tagged tool, a plank, two nails.
  2. IT IS PAID FOR. The plank and both nails leave the person's
     inventory. A barricade that costs nothing is a decoration, and a
     county that can fortify for free tells us nothing about whether
     it could gather what it needed.
  3. Every clause of the decision can fail: holding ground, the fall
     having come, standing on their own claim, carrying the makings,
     and a window being left. A decision that cannot fail is a
     placement wearing a decision's clothes.
  4. NOTHING PLACES ONE OTHERWISE. No genesis, no population pass, no
     fast-forward, and no harness debug option may build a barricade -
     the harness may only report. This is the check the ruling exists
     for, and it is the one that would catch a later batch quietly
     seeding what it wanted to see.

An optional argv[1] points the checker at another tree root, which is
how its control runs: the pre-batch tree has no capability at all.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
BUILD = ROOT / "java" / "src" / "com" / "sao" / "engine" / "SAOBuild.java"
BRIDGE = ROOT / "java" / "src" / "com" / "sao" / "bridge" / "SAOBridge.java"
CONTROLLER = LUA / "client" / "SAO_Controller.lua"
INSPECT = LUA / "client" / "SAO_Inspect.lua"
REGISTRY = ROOT / "DECISION_REGISTRY.md"
CHECK = ROOT / "tools" / "check.sh"

PLACERS = ("AddBarricadeToObject", "addPlank", "boardWindow")


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""


def main():
    faults = []
    print("=" * 74)
    print("THEY EITHER BUILD OR THEY DO NOT")
    print("=" * 74)

    if not BUILD.exists():
        print("  FAULT: there is no build capability at all, so the county "
              "cannot fortify anything and the question of whether it would "
              "cannot be asked")
        return 1
    build, bridge = read(BUILD), read(BRIDGE)
    controller, inspect = read(CONTROLLER), read(INSPECT)

    checks = {
        # 1. The engine's own act, with the shipped action's own gate.
        "the act is the engine's own barricade":
            "IsoBarricade.AddBarricadeToObject" in build
            and "barricade.addPlank(person, plank)" in build,
        "a hammer is required, by the engine's own tag":
            "hasEquippedTag(ItemTag.HAMMER)" in build,
        "a plank is required":
            'hasEquipped("Plank")' in build,
        "two nails are required, and the number is the action's":
            "NAILS_PER_PLANK = 2" in build
            and 'getNumberOfItem("Base.Nails", true) >= NAILS_PER_PLANK' in build,
        "a full window is refused":
            "canAddPlank()" in build,

        # 2. Paid for.
        "the plank leaves their inventory":
            re.search(r"bag\.Remove\(plank\)", build) is not None,
        "and both nails do":
            re.search(r"for \(int n = 0; n < NAILS_PER_PLANK; n\+\+\)", build) is not None
            and re.search(r"bag\.Remove\(nail\)", build) is not None,

        # 3. Every clause can fail.
        "they must hold ground":
            "SAO.Standing.claimOf(id)" in controller,
        "the fall must have come":
            'agent.state == "IDLE" and SAO.Standing.fallHasCome()' in controller,
        "they must be standing on their own claim":
            "SAO.Standing.insideClaim(id, body:getX(), body:getY())" in controller,
        "they must be carrying the makings":
            "carriesTheMakings(body)" in controller,
        "and a window must be left to board":
            "findBoardable(body," in controller,
        "the reach is named, not spelled":
            re.search(r"local BOARD_REACH = \d+ -- tiles", controller) is not None,

        # 4. Nothing else places one.
        "the panel reports what was built and builds nothing":
            "boarded" in inspect and not any(p in inspect for p in PLACERS),
    }

    # The population and genesis passes must not touch it at all.
    for name in ("SAO_Population.lua", "SAO_Absorb.lua", "SAO_Harness.lua"):
        text = read(LUA / "client" / name)
        placed = [p for p in PLACERS if p in text]
        checks["%s places no barricade" % name] = not placed
        if placed:
            faults.append(
                "%s calls %s. Nothing may place a fortification that nobody "
                "built: the whole ruling is that they either manage it or "
                "they do not, and a pass that seeds one destroys the only "
                "measurement there is" % (name, ", ".join(placed)))

    checks["the bridge exposes it and decides nothing"] = (
        "public int boardWindow(" in bridge
        and "public boolean carriesTheMakings(" in bridge)
    # The registry is prose wrapped at seventy-odd columns, so a phrase
    # long enough to be worth searching for will span a line break.
    # Reading it raw reported the ruling missing while it sat there.
    registry = " ".join(read(REGISTRY).split())
    checks["the registry carries the ruling"] = (
        "either they manage it or they do not" in registry)
    checks["the gate runs this border"] = (
        "tools/they_build_test.py" in read(CHECK))

    print()
    for k, v in checks.items():
        print(f"  {'yes' if v else 'NO '}  {k}")
        if not v and k not in faults:
            faults.append(k)

    print()
    print("VERDICT:")
    if faults:
        for f in dict.fromkeys(faults):
            print("  FAULT: " + f)
        return 1
    print("  117) they either build or they do not: the engine's own "
          "barricade at its own price, every clause able to fail, and "
          "nothing anywhere placing one that nobody built")
    return 0


if __name__ == "__main__":
    sys.exit(main())
