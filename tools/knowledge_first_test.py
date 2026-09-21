#!/usr/bin/env python3
r"""Border 99 - how far a person goes is knowledge and desire (DR-027).

The operator, on the errand dial: people operate off social
structures and social incentives and personal desires and
understanding and awareness - never a permitted radius of twelve.
The same objection stands against the neighbour framework.

The ruling splits one number into two honest things. The PROBE - how
far a body notices what is around it - is perception, a constant of
seeing, and nobody's option. How far a person will GO is knowledge:
the county's own places, searched nearest first from where they
stand, committed to by their own need against horizons DERIVED from
the engine's own neighborhood quantum (the cell). A sandbox dial for
either is the leash the operator refused.

WHAT THIS HOLDS
---------------
  1. The ErrandRadius dial does not exist - not as an option, not as
     a translation, not as a read - anywhere under mod/.
  2. The probe span is named for what it is (PERCEPTION_TILES, in
     the needs module) and every finder defaults to it.
  3. The controller carries the knowledge step: on a blind probe,
     all four need branches reach for the nearest KNOWN offering
     (knownSource), and the step is position-anchored - knowledge
     moves with the walker.
  4. Knowledge earns no exemptions: the four claim vetoes
     (mayEnterBelieved) still stand at the need branches, so a known
     place walks the same property law a noticed source walks.
  5. The knowledge surface is private and grounded: horizons derive
     from the engine's own cell size, selection reads only that person's
     observed native-source beliefs, and arrival refreshes stale belief
     from native ground before any acquisition can complete.
  6. The dormant half walks the same law: need cuts ahead of
     curiosity through the same knowledge search, and one barring
     function serves both choosers - two copies of a law is how
     they drift.

An optional argv[1] points the checker at another tree root, which is
how the control runs against the pre-[C25] tree.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
MOD = ROOT / "mod"
LUA = MOD / "42.20" / "media" / "lua"


def read(p):
    return p.read_text(encoding="utf-8", errors="ignore") \
        if p.exists() else ""


def strip_lua_comments(text):
    """Prose is not code (the GOVERNANCE clause, hit by this border's
    own first run: the modules that KILLED the dial name it in their
    comments, as the batch records do). The carrier scan reads code."""
    return "\n".join(
        line[:line.find("--")] if line.find("--") >= 0 else line
        for line in text.split("\n"))


def finder_bodies(needs):
    return [match for match in re.finditer(
        r"^function N\.(find\w+)\(([^)]*)\)(.*?)(?=^function |\Z)",
        strip_lua_comments(needs), re.M | re.S)
        if re.search(r"\bradius\b", match.group(2))]


def finder_defaults(needs):
    # Every radius-bearing discovery function has its own native-call default.
    # An absent default is a finding even when the other finders are correct.
    return {match.group(1): [value for call in re.findall(
                r"SAOJavaBridge:\w+\([^)]*\)", match.group(3))
            for value in re.findall(r"radius\s+or\s+([A-Za-z_.0-9]+)(?=\s*[,\)])", call)]
            for match in finder_bodies(needs)}


def private_belief_source(world):
    for name in ("nearestBelieved", "nearestObserved"):
        function = re.search(r"^function WS\." + name
            + r"\([^)]*\)(.*?)(?=^function |^local function |\Z)",
            strip_lua_comments(world), re.M | re.S)
        if not function or not re.search(
                r"SAO\.Perception\.knownPlaces\(id(?:,\s*true)?\)",
                function.group(1)):
            return False
    return True


def main():
    faults = []
    print("=" * 74)
    print("HOW FAR A PERSON GOES IS KNOWLEDGE AND DESIRE")
    print("=" * 74)

    needs = read(LUA / "client" / "SAO_Needs.lua")
    ctl = read(LUA / "client" / "SAO_Controller.lua")
    pop = read(LUA / "client" / "SAO_DormantPopulation.lua")
    places = read(LUA / "shared" / "SAO_Places.lua")
    world = read(LUA / "shared" / "SAO_WorldSources.lua")

    # 1. The dial is dead everywhere under mod/. Lua is scanned with
    # its comments stripped - the modules that killed the dial name
    # it in their prose, and prose is not code; options and
    # translations are scanned raw, because there a mention IS a row
    # on the player's screen.
    carriers = []
    for p in sorted(MOD.rglob("*")):
        if p.is_file() and p.suffix in (".lua", ".txt", ".json"):
            body = read(p)
            if p.suffix == ".lua":
                body = strip_lua_comments(body)
            if "ErrandRadius" in body:
                carriers.append(str(p.relative_to(ROOT)).replace("\\", "/"))
    if carriers:
        faults.append("the ErrandRadius dial still exists in: "
                      + ", ".join(carriers)
                      + " - the leash the operator refused (DR-027)")

    # 2. The probe span, named and used.
    if "N.PERCEPTION_TILES = 12" not in needs:
        faults.append("the probe span is not named PERCEPTION_TILES in "
                      "the needs module - a bare number is a leash with "
                      "the label torn off")
    finders = finder_defaults(needs)
    if len(finders) < 4 or any(values != ["N.PERCEPTION_TILES"] for values in finders.values()):
        faults.append("not every finder defaults its probe to "
                      f"PERCEPTION_TILES (saw {finders}) - one finder on "
                      "a different span is a second, secret dial")

    # 3. The knowledge step, in all four need branches.
    if "local function knownSource" not in ctl:
        faults.append("the controller has no knowledge step - a blind "
                      "probe still means giving up, which is the exact "
                      "sentence DR-027 struck: 'knows of no food nearby' "
                      "while the county's own index knows the grocery")
    calls = len(re.findall(r"= knownSource\(", ctl))
    if calls < 4:
        faults.append(f"the knowledge step reaches only {calls} of the "
                      "four need branches (food, water, gear, ammo) - a "
                      "need without knowledge gives up at the probe line")
    if "body:getX()" not in ctl.split("local function knownSource", 1)[-1] \
            .split("local function decide", 1)[0]:
        faults.append("the knowledge step is not anchored on the body's "
                      "own position - knowledge must move with the walker")

    # 4. Knowledge earns no exemptions.
    if len(re.findall(r"mayEnterBelieved\(", ctl)) < 4:
        faults.append("fewer than four claim vetoes stand in the "
                      "controller - a known place must walk the same "
                      "property law a noticed source walks")

    # 5. The knowledge surface itself.
    if "getCellSizeInSquares" not in places:
        faults.append("the horizons do not derive from the engine's own "
                      "cell size - a horizon from nowhere is a dial "
                      "wearing a derivation's clothes")
    if "cellSpan() / 2" not in places.replace("Pl.cellSpan", "cellSpan") \
            or "* 1.5" not in places:
        faults.append("the comfort/commit horizon pair is not derived "
                      "from the cell span")
    if not private_belief_source(world):
        faults.append("known-source selection does not start from the "
                      "asker's private place beliefs")
    if "belief.sources and belief.sources[category]" not in world:
        faults.append("known-source selection accepts a room hint as "
                      "stock instead of requiring a personally observed "
                      "native source")
    live_step = ctl.split("local function knownSource", 1)[-1] \
        .split("local function decide", 1)[0]
    if "SAO.WorldSources.nearestBelieved" not in live_step \
            or "id, bx, by, offer, horizon" not in live_step:
        faults.append("the loaded knowledge step does not carry the "
                      "asker's identity into private source selection")
    if "SAO.WorldSources.demandPlace(place)" not in pop \
            or 'tickCounter, "observed"' not in pop:
        faults.append("arrival does not refresh possibly stale belief "
                      "from native ground before acquisition")

    # 6. The dormant half walks the same law.
    if "local function placeBarred" not in pop \
            or len(re.findall(r"placeBarred\(", pop)) < 3:
        faults.append("the dormant choosers do not share one barring "
                      "law - two copies of feud-and-claim is how they "
                      "drift apart")
    if "SAO.WorldSources.nearestBelieved" not in pop:
        faults.append("dormant need never cuts ahead of curiosity - a "
                      "dying walker roams for novelty while the county "
                      "knows where the water is")

    for finder in finder_bodies(needs):
        for replacement in ("radius or 4", "4"):
            changed = finder.group(3).replace("radius or N.PERCEPTION_TILES",
                                              replacement, 1)
            case = "function N." + finder.group(1) + "(" + finder.group(2) + ")" + changed
            if finder_defaults(case).get(finder.group(1)) == ["N.PERCEPTION_TILES"]:
                faults.append("CONTROL: wrong or removed native default survived for "
                              + finder.group(1))
    wrong_actor = world.replace("SAO.Perception.knownPlaces(id",
                                'SAO.Perception.knownPlaces("someone-else"', 1)
    if private_belief_source(wrong_actor):
        faults.append("CONTROL: another person's belief lookup was not detected")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print("  99) knowledge-first: the dial is dead, the probe is named for")
    print("      what it is, all four needs reach for what the county knows")
    print("      under the same property law, horizons derive from the")
    print("      engine's own quantum, and private source belief is refreshed")
    print("      from native ground before acquisition")
    return 0


if __name__ == "__main__":
    sys.exit(main())
