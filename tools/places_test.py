#!/usr/bin/env python3
r"""Border 22 - the county's places, against the county's own map.

[B37] gave the dormant day an object. Before that its destination was
`rec.homeX + ZombRand(-24, 25)` - a random coordinate, not a place -
so survivors walked a 48-tile box forever while a daily roll killed
them.

The places come from `IsoMetaGrid`, which is built for the whole map
at world start, and their MEANING comes from `RoomDef:getName()`. The
map names its own rooms, and the shipped `Distributions.lua` is keyed
by exactly those names under a header that reads "Room List (A-Z)".

That corpus is the authority this border checks against. The stems in
`SAO_Places.OFFERS` are an interpretation - authored, and meant to be -
but an interpretation of a REAL vocabulary. So:

  1. Every stem must match at least one room name the shipped map
     actually uses. A stem matching nothing is a category we invented
     and the county cannot supply.

  2. No stem may be so broad it matches nearly everything, which
     would make "somewhere with food in it" mean "anywhere".

  3. The corpus is read from the game, so if a build changes the room
     vocabulary this fails rather than silently drifting.

It also PRINTS what each stem matches, because [B36]'s first clause
is to enumerate the idioms before trusting the pattern - and a stem
list is only as good as the matches somebody actually looked at.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PLACES = (ROOT / "mod" / "42.20" / "media" / "lua" / "shared"
          / "SAO_Places.lua")
GAME = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid\media")
DIST = GAME / "lua" / "server" / "Items" / "Distributions.lua"

# A stem this common stops discriminating between places.
BREADTH_CEILING = 0.25


def corpus():
    """Room names the shipped map actually uses.

    Top-level keys sit at ONE level of indentation inside
    `distributionTable` - and the shipped file mixes its indentation,
    some entries with a single tab and others with four spaces. Reading
    only the tabs finds 313 of them and silently loses the rest,
    including `agriworkerdorm` and `carpentryworkshop`, which is how
    two live stems first looked like invented ones.

    The capitalised keys in that table are CONTAINER distributions
    (`Bag_ToolBag`, `Cooler_Beer`, `GroceryBag1`) rather than rooms,
    and a RoomDef never carries one, so they are excluded by case.
    """
    if not DIST.exists():
        return None
    text = DIST.read_text(encoding="utf-8", errors="ignore")
    names = re.findall(r"^(?:\t|    )([A-Za-z][A-Za-z0-9_]*) = \{",
                       text, re.M)
    return sorted({n for n in names if n[0].islower()})


def offers():
    """Mirror OFFERS and NOT_REALLY out of the shipped Lua."""
    src = PLACES.read_text(encoding="utf-8")
    m = re.search(r"Pl\.OFFERS = \{(.*?)\n\}", src, re.S)
    if not m:
        raise SystemExit("places_test: Pl.OFFERS moved; this mirror is blind")
    out = {}
    for name, body in re.findall(r"(\w+) = \{(.*?)\}", m.group(1), re.S):
        out[name] = re.findall(r'"([^"]+)"', body)
    if not out:
        raise SystemExit("places_test: parsed no stems; this mirror is blind")

    n = re.search(r"Pl\.NOT_REALLY = \{(.*?)\n\}", src, re.S)
    excluded = set(re.findall(r"(\w+) = true", n.group(1))) if n else set()

    return out, excluded


UNVISITED = 1000000
DESPERATE = 10000000
THIRST_PATIENCE = 2
HUNGER_PATIENCE = 7
THIRST_LETHAL = 3
HUNGER_LETHAL = 21


DESPERATION = 0.7


def choose(places, believed, feuds=None, dry=0, hungry=0, held=None,
           line=DESPERATION):
    """Mirror of the shipped chooser's PLACE ordering, without the dice.

    The shipped one randomises among places never seen so that two
    survivors sharing a home do not walk in step; the ordering it is
    randomising WITHIN is what matters and is what this models.

    [B37] adds the half that makes the offers load-bearing: need
    outranks novelty by construction, and thirst outranks hunger
    because it arrives first.

    [C72] What this does NOT model, said rather than left to be
    discovered: the day's goal may also be a PERSON, chosen before the
    place loop is reached. That branch is held by Border 138, which
    runs the real module in the engine's VM, because a Python mirror of
    it would be a second answer to a question about trust, hostility
    and a temperament draw. Everything below is the ordering that
    decides where somebody goes when there is nobody to go to.
    """
    best, best_score = None, None
    for p in places:
        if not p["offers"]:
            continue
        if feuds and any(
                f[0] - 20 <= p["cx"] <= f[2] + 20
                and f[1] - 20 <= p["cy"] <= f[3] + 20 for f in feuds):
            continue
        # [B39] Somebody else's ground, respected below the line the
        # county already draws and taken above it. Belief-gated: only
        # places this survivor KNOWS are held.
        urgency = max(dry / THIRST_LETHAL, hungry / HUNGER_LETHAL)
        if held and p["id"] in held and urgency < line:
            continue
        age = believed.get(p["id"])
        score = min(age, UNVISITED - 1) if age is not None else UNVISITED
        want = 0
        if dry > THIRST_PATIENCE and "water" in p["offers"]:
            want += 100 * dry // THIRST_LETHAL
        if hungry > HUNGER_PATIENCE and "food" in p["offers"]:
            want += 100 * hungry // HUNGER_LETHAL
        score += DESPERATE * want
        if best_score is None or score > best_score:
            best, best_score = p, score
    return best


def drive():
    """The day, driven over a modelled neighbourhood.

    The vocabulary section says the county HAS places. This says the
    day actually goes to one, goes somewhere else next time, and still
    refuses ground the survivor knows belongs to an enemy - which is
    the difference between living somewhere and pacing a box.
    """
    P = [
        {"id": 1, "cx": 100, "cy": 100, "offers": {"food"}},
        {"id": 2, "cx": 140, "cy": 100, "offers": {"water"}},
        {"id": 3, "cx": 100, "cy": 140, "offers": set()},
        {"id": 4, "cx": 400, "cy": 400, "offers": {"tools"}},
    ]
    ok = {}
    print()
    print("=" * 70)
    print("THE DAY, driven")
    print("=" * 70)

    ok["nothing to walk to -> drift"] = choose([], {}) is None
    print(f"  1. wilderness, no places at all -> falls back to the old "
          f"drift: {ok['nothing to walk to -> drift']}")

    ok["a place with nothing is never chosen"] = choose([P[2]], {}) is None
    print(f"  2. a building whose rooms offer nothing is not somewhere "
          f"to GO: {ok['a place with nothing is never chosen']}")

    first = choose(P, {})
    ok["unvisited is chosen"] = first is not None and first["id"] in (1, 2, 4)
    print(f"  3. never having been anywhere, they go somewhere: "
          f"{ok['unvisited is chosen']}")

    ok["unvisited beats visited"] = choose(P, {1: 10, 2: 20})["id"] == 4
    print(f"  4. somewhere never seen beats somewhere just left: "
          f"{ok['unvisited beats visited']}")

    ok["longest unseen wins"] = choose(
        P[:2], {1: 5000, 2: 90})["id"] == 1
    print(f"  5. among places they know, the one longest unseen wins: "
          f"{ok['longest unseen wins']}")

    ok["enemy ground is barred"] = choose(
        P[:2], {}, feuds=[(390, 390, 410, 410)])["id"] in (1, 2)
    ok["enemy ground really bars"] = choose(
        [P[3]], {}, feuds=[(390, 390, 410, 410)]) is None
    print(f"  6. ground they KNOW is an enemy's is refused: "
          f"{ok['enemy ground really bars']}")

    ok["all barred -> drift"] = choose(
        [P[0]], {}, feuds=[(80, 80, 120, 120)]) is None
    print(f"  7. a neighbourhood entirely enemy ground -> drift again: "
          f"{ok['all barred -> drift']}")

    # [B37] Desperation. A well person explores; a dry one does not.
    print()
    ok["thirst overrides curiosity"] = choose(
        P, {2: 50}, dry=4)["id"] == 2
    print(f"  8. four days dry, they go BACK to the water they know "
          f"rather than somewhere new: {ok['thirst overrides curiosity']}")

    ok["fed and watered, they explore"] = choose(
        P, {1: 50, 2: 50}, dry=0, hungry=0)["id"] == 4
    print(f"  9. watered and fed, novelty returns: "
          f"{ok['fed and watered, they explore']}")

    ok["thirst outranks hunger"] = choose(
        P, {1: 50, 2: 50}, dry=4, hungry=20)["id"] == 2
    print(f" 10. dry AND starving, water first - it arrives first: "
          f"{ok['thirst outranks hunger']}")

    ok["patience before panic"] = choose(
        P, {2: 50}, dry=THIRST_PATIENCE)["id"] != 2
    print(f" 11. inside the patience window it is not yet a need: "
          f"{ok['patience before panic']}")

    # [B39] Property, and the line past which it stops mattering.
    print()
    ok["a known claim is respected"] = choose(
        P[:2], {}, held={1, 2}) is None
    print(f" 12. every place near them is somebody else's and they are "
          f"not desperate -> drift: {ok['a known claim is respected']}")

    ok["desperation takes it anyway"] = choose(
        P[:2], {}, held={1, 2}, dry=4) is not None
    print(f" 13. four days dry, the same ground is taken: "
          f"{ok['desperation takes it anyway']}")

    ok["what they do not know does not stop them"] = choose(
        P[:2], {}, held=set()) is not None
    print(f" 14. a claim they have never heard of stops nobody: "
          f"{ok['what they do not know does not stop them']}")

    print()
    print("  THE SHIPPED LINKS - modelled above, required below")
    lua = (ROOT / "mod" / "42.20" / "media" / "lua")
    pop = (lua / "client" / "SAO_DormantPopulation.lua").read_text(
        encoding="utf-8", errors="ignore")
    admissions = (lua / "client" / "SAO_PopulationAdmissions.lua").read_text(
        encoding="utf-8", errors="ignore")
    per = (lua / "shared" / "SAO_Perception.lua").read_text(
        encoding="utf-8", errors="ignore")
    plc = PLACES.read_text(encoding="utf-8")
    links = {
        # [C72] The shape, not one spelling. These named
        # `chooseDayPlace(id, rec, reach)` and
        # `rec.dayGoalX, rec.dayGoalY = chosen.cx` as literals, and both
        # went red on a correct rename - the seam-names-a-declaration
        # defect this repository has paid for three times. What must
        # hold is that the dormant day asks ONE chooser, with the
        # person and the reach, and writes the goal out of the answer
        # it gets back, whatever either is called. [C113] added a
        # fourth payment: the call gained a guard (pre-fall, the open
        # street's authored curve decides whether this person goes out
        # at all before any place is asked about), so the literal went
        # red on a correct gate. The optional guard is one `name and`
        # ahead of the call and nothing more - a second chooser, a
        # different asking shape, or the chooser asked without the
        # person still reads red.
        "the day asks one chooser where it goes":
            re.search(r"and\s+chooseDayGoal\(id, rec, reach, tickCounter\)",
                      pop) is not None,
        "the goal is written from that answer":
            re.search(r"rec\.dayGoalX, rec\.dayGoalY = chosen\.\w+, "
                      r"chosen\.\w+", pop) is not None,
        "arriving teaches it": "SAO.Perception.learnBuilding(id," in pop,
        # [C66] moved every draw to the county's own generator. The
        # property is that the old drift is still the fallback where no
        # place can be chosen, which it is; only its spelling moved.
        "the drift survives as the fallback":
            re.search(r"rec\.dayGoalX\s*=\s*rec\.homeX\s*\n\s*"
                      r"\+\s*SAO\.Rand\.int", pop) is not None,
        "belief can hold a place as a place": "function P.learnBuilding" in per,
        "and can age it": "function P.placeAge" in per,
        "places come from the map": "getBuildingAt" in plc
            and "getMetaGrid" in plc,
        "and from its room names": "room:getName()" in plc,
        # [B38/R10a] Distribution definitions say what a room can
        # generate. They guide exploration; exact current stock belongs
        # to WorldSources. The
        # shipped expressions are required because this mirror cannot
        # run Lua (GOVERNANCE: a mirror that re-derives the rule
        # cannot fail on the rule).
        # The READ, not the name. Both identifiers appear in the
        # comment block explaining them, so a bare name check passes
        # after the code is gone - GOVERNANCE's prose-is-not-code
        # clause, hit twice on the day it was written.
        "reads the game's distribution possibilities":
            "local rooms = SuburbsDistributions" in plc
            and "lists = ProceduralDistributions" in plc,
        "resolves items through the script manager":
            'sm:getItem(name) or sm:getItem("Base." .. name)' in plc,
        "an item's possibility is what it does to a BODY":
            "item:getHungerChange() or 0) < 0" in plc
            and "item:getThirstChange() or 0) < 0" in plc,
        "distribution possibility wins where the game has an answer":
            "local content = Pl.contentOffers(roomName)" in plc
            and "if not content then return stems end" in plc,
        "but shelter still comes from the name":
            "if not MATERIAL[k] then out[k] = true end" in plc,
        "and the content read is cached per room":
            "Pl.contentCache[name] = any and out or false" in plc,
        "room vocabulary never owns stock":
            "function Pl.take(" not in plc
            and "function Pl.isSpent" not in plc
            and "function Pl.offersNow" not in plc,
        "arrival demands native ground":
            "SAO.WorldSources.demandPlace(place)" in pop,
        "arrival preserves the missing access/action boundary":
            'return false, "access-unproven"' in pop,
        "the dormant read the county's own desperation line":
            "local function desperationLine()" in pop
            and "tonumber(sv.Desperation)" in pop,
        "and lessons move it for them too":
            "SAO.Lessons.desperationBump(id)" in pop,
        "somebody else's ground is belief-gated":
            "held = SAO.Perception.believesClaimed(" in pop,
        # [C25] moved the claim gate into placeBarred, the ONE
        # barring law both choosers (need and curiosity) share.
        "and respected only below the line":
            "local function placeBarred" in pop
            and "if not desperate then" in pop,
        # [B40] Everybody wakes up somewhere, and until now nobody
        # knew the one place they had certainly been. `originAnchored`
        # was written at genesis and read nowhere in the tree - one
        # mention in the whole mod.
        "genesis teaches the place they started in":
            "local startedIn = SAO.Places.at(origin.x, origin.y)" in admissions
            and 'learnBuilding(rec.id, startedIn, 0, "lived")' in admissions,
        "and the anchored origin is finally read":
            "rec.originAnchored then" in admissions,
        "arrival does not award food or water from observation":
            "SAO.WorldSources.commit(" not in pop
            and "rec.lastWaterDay = day" not in pop
            and "rec.lastFoodDay = day" not in pop,
        # [B37] Need still reaches the risk model. C61 no longer turns
        # reaching a building into a successful native Eat/Drink action.
        "thirst reaches the death roll":
            "dryDays = daysWithout(rec" in pop
            and "risk = risk * math.min(4.0," in pop,
        "hunger reaches it too":
            "hungryDays = daysWithout(rec" in pop
            and "risk = risk * math.min(2.0," in pop,
        "an old world does not start starving":
            "if rec.lastWaterDay == nil then rec.lastWaterDay = today end"
            in pop,
        "native truth updates the person's private belief":
            "SAO.Perception.learnBuilding(id, place" in pop
            and 'tickCounter, "observed"' in pop,
    }
    for k, v in links.items():
        print(f"    {'yes' if v else 'NO '}  {k}")

    return all(ok.values()) and all(links.values())


def main():
    rooms = corpus()
    if rooms is None:
        print("22) places: SKIPPED - no game install to read the map "
              "vocabulary from")
        return 0

    table, excluded = offers()
    print("=" * 70)
    print(f"THE MAP'S OWN VOCABULARY - {len(rooms)} room names")
    print("=" * 70)

    faults = []
    matched_by = {}
    for offer in sorted(table):
        hits_for_offer = set()
        rows = []
        for stem in table[offer]:
            hits = [r for r in rooms if stem in r and r not in excluded]
            if not hits:
                faults.append(
                    f"{offer}: stem {stem!r} matches no room name the "
                    "shipped map uses - an invented category")
            share = len(hits) / max(len(rooms), 1)
            if share > BREADTH_CEILING:
                faults.append(
                    f"{offer}: stem {stem!r} matches {len(hits)} of "
                    f"{len(rooms)} rooms ({share:.0%}) - too broad to "
                    "discriminate")
            hits_for_offer.update(hits)
            rows.append((stem, hits))
        for r in hits_for_offer:
            matched_by.setdefault(r, set()).add(offer)
        print(f"\n  {offer}  ({len(hits_for_offer)} rooms)")
        for stem, hits in rows:
            sample = ", ".join(sorted(hits)[:5])
            more = f" +{len(hits) - 5}" if len(hits) > 5 else ""
            print(f"    {len(hits):>3}  {stem:<18} {sample}{more}")

    covered = len(matched_by)
    print()
    print("=" * 70)
    print("COVERAGE")
    print("=" * 70)
    print(f"  rooms that offer something : {covered} of {len(rooms)} "
          f"({covered / len(rooms):.0%})")
    multi = [r for r, o in matched_by.items() if len(o) > 1]
    print(f"  rooms offering more than one: {len(multi)}"
          f"   e.g. {', '.join(sorted(multi)[:4])}")
    print(f"  deliberately excluded       : "
          f"{', '.join(sorted(excluded)) or 'none'}")
    unmatched = [r for r in rooms if r not in matched_by]
    print(f"  rooms that offer nothing    : {len(unmatched)}")
    print(f"    {', '.join(unmatched[:14])}"
          f"{' ...' if len(unmatched) > 14 else ''}")

    driven = drive()
    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    if not driven:
        print("  FAULT: the day does not behave as modelled, or a "
              "shipped link is missing")
        return 1
    print(f"  every stem matches the shipped map; none exceeds "
          f"{BREADTH_CEILING:.0%} breadth")
    print("  the day goes to a place, learns it, and refuses enemy ground")
    print("  room vocabulary guides exploration; exact native sources decide stock")
    return 0


if __name__ == "__main__":
    sys.exit(main())
