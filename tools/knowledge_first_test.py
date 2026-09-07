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
  5. The knowledge surface is honest: horizons derive from the
     engine's own cell size, the search is nearest-first in rings,
     held knowledge is revalidated at use (offersNow), and "there is
     none around here" expires - belief about absence is belief too.
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


def main():
    faults = []
    print("=" * 74)
    print("HOW FAR A PERSON GOES IS KNOWLEDGE AND DESIRE")
    print("=" * 74)

    needs = read(LUA / "client" / "SAO_Needs.lua")
    ctl = read(LUA / "client" / "SAO_Controller.lua")
    pop = read(LUA / "client" / "SAO_Population.lua")
    places = read(LUA / "shared" / "SAO_Places.lua")

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
    finders = re.findall(r"radius or ([A-Za-z_.0-9]+)\)", needs)
    if len(finders) < 4 or any(f != "N.PERCEPTION_TILES" for f in finders):
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
    if "function Pl.nearestOffering" not in places \
            or "RING_STEP" not in places:
        faults.append("no nearest-first ring search - knowledge that "
                      "scans the whole horizon for the closest shelf "
                      "pays the map when the answer is next door")
    if "offersNow(held.place)" not in places:
        faults.append("held knowledge is not revalidated at use - a "
                      "place eaten bare stays 'known good' forever")
    if not re.search(r"held\.at.*<\s*24|<\s*24.*held\.at", places):
        faults.append("'there is none around here' never expires - "
                      "belief about absence is belief too, and the "
                      "world refills ([B39])")

    # 6. The dormant half walks the same law.
    if "local function placeBarred" not in pop \
            or len(re.findall(r"placeBarred\(", pop)) < 3:
        faults.append("the dormant choosers do not share one barring "
                      "law - two copies of feud-and-claim is how they "
                      "drift apart")
    if "nearestOffering" not in pop:
        faults.append("dormant need never cuts ahead of curiosity - a "
                      "dying walker roams for novelty while the county "
                      "knows where the water is")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print("  99) knowledge-first: the dial is dead, the probe is named for")
    print("      what it is, all four needs reach for what the county knows")
    print("      under the same property law, horizons derive from the")
    print("      engine's own quantum, and held knowledge stays honest")
    return 0


if __name__ == "__main__":
    sys.exit(main())
