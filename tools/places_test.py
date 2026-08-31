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

    w = re.search(r"Pl\.MAINS_WATER = \{(.*?)\}", src, re.S)
    mains = set(re.findall(r"(\w+) = true", w.group(1))) if w else set()
    if not mains:
        raise SystemExit("places_test: Pl.MAINS_WATER moved; blind")
    return out, excluded, mains


UNVISITED = 1000000
DESPERATE = 10000000
THIRST_PATIENCE = 2
HUNGER_PATIENCE = 7
THIRST_LETHAL = 3
HUNGER_LETHAL = 21


DESPERATION = 0.7


def choose(places, believed, feuds=None, dry=0, hungry=0, held=None,
           line=DESPERATION):
    """Mirror of `chooseDayPlace`'s ordering, without the dice.

    The shipped one randomises among places never seen so that two
    survivors sharing a home do not walk in step; the ordering it is
    randomising WITHIN is what matters and is what this models.

    [B37] adds the half that makes the offers load-bearing: need
    outranks novelty by construction, and thirst outranks hunger
    because it arrives first.
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


def stem_offers_of(name, table, excluded, mains):
    """Mirror of `Pl.stemOffersOf`, with [B37]'s stored-water mark.

    [B38] made contents outrank names in the shipped `Pl.offersOf`,
    so this models the STEM half only - which is what the shutoff
    section below is about, and the name now says so.
    """
    if name in excluded:
        return set()
    out = set()
    for offer, stems in table.items():
        if any(s in name for s in stems):
            out.add(offer)
    if "water" in out and not any(s in name for s in mains):
        out.add("storedWater")
    return out


def offers_now(offers, water_on):
    """Mirror of `Pl.offersNow`."""
    out = set(offers)
    out.discard("storedWater")
    if not water_on:
        if "storedWater" in offers or "drink" in offers:
            out.add("water")
        else:
            out.discard("water")
    return out


# Buildings as the map actually composes them, from real room names.
BUILDINGS = {
    "a house": ["kitchen", "bathroom", "bedroom", "livingroom"],
    "a farmhouse": ["kitchen", "bathroom", "bedroom", "barn"],
    "a motel": ["motelroom", "bathroom"],
    "a grocery": ["grocery", "grocerystorage", "bathroom"],
    "a bar": ["bar", "barkitchen", "bathroom"],
    "a gas station": ["gas2go", "gasstore", "bathroom"],
    "a warehouse": ["warehouse", "office"],
    "a school pool": ["pool", "bathroom"],
}


def shutoff(table, excluded, mains):
    """[B37] What the county's water looks like before and after.

    Counting ROOM NAMES would mislead: `bathroom` is one name and sits
    in nearly every building on the map, so the change looks tiny in a
    name count and is enormous on the ground. Buildings are the honest
    unit.
    """
    print()
    print("=" * 70)
    print("THE DAY THE WATER GOES OFF")
    print("=" * 70)
    rows = []
    for label, rooms in BUILDINGS.items():
        base = set()
        for r in rooms:
            base |= stem_offers_of(r, table, excluded, mains)
        on = offers_now(base, True)
        off = offers_now(base, False)
        rows.append((label, "water" in on, "water" in off))
        print(f"  {label:<16} mains on: "
              f"{'water' if 'water' in on else '  -  '}"
              f"   mains off: "
              f"{'water' if 'water' in off else '  -  '}"
              f"   ({', '.join(sorted(off - {'water'})) or 'nothing else'})")

    lost = [r[0] for r in rows if r[1] and not r[2]]
    kept = [r[0] for r in rows if r[2]]
    print()
    print(f"  loses its water : {len(lost)}/{len(rows)}  "
          f"{', '.join(lost)}")
    print(f"  keeps it        : {len(kept)}/{len(rows)}  "
          f"{', '.join(kept)}")
    ok = {
        "a house loses its water": "a house" in lost,
        "a motel loses its water": "a motel" in lost,
        "somewhere still has water": len(kept) > 0,
        "a grocery keeps it": "a grocery" in kept,
        "a pool keeps it": "a school pool" in kept,
        "the county is not left dry": 0 < len(kept) < len(rows),
    }
    print()
    for k, v in ok.items():
        print(f"    {'yes' if v else 'NO '}  {k}")
    return all(ok.values())


def scarcity(plc):
    """[B39] The shelves, driven.

    Mirrors capacityOf and takesAt out of the shipped constants. What
    this checks is that a county EMPTIES - that a place with a fixed
    capacity, visited by survivors who each take one thing, stops
    offering before everybody has been. A model where two hundred
    people feed off one grocery forever is the defect this closes.
    """
    import re as _re

    def const(name):
        m = _re.search(rf"^local {name} = (\d+)$", plc, _re.M)
        if not m:
            raise SystemExit(f"places_test: {name} moved; blind")
        return int(m.group(1))

    per_room = const("TAKES_PER_ROOM")
    lo, hi = const("MIN_CAPACITY"), const("MAX_CAPACITY")

    def capacity(rooms):
        return max(lo, min(hi, rooms * per_room))

    print()
    print("=" * 70)
    print("THE SHELVES, driven")
    print("=" * 70)
    print(f"  {per_room} takes a room, held between {lo} and {hi}")
    print()
    print("  building        rooms   holds   feeds")
    ok = {}
    for label, rooms in (("a one-room shed", 1), ("a house", 4),
                         ("a grocery", 8), ("a gigamart", 30)):
        cap = capacity(rooms)
        print(f"  {label:<16} {rooms:>4}    {cap:>4}    {cap} visits")
        ok[f"{label} is finite"] = cap < 200

    # The county empties. 216 people, each taking once from the same
    # grocery, against a grocery that holds what a grocery holds.
    grocery = capacity(8)
    ok["a grocery cannot feed the county"] = grocery < 216
    # And neither can the largest building the map could ever hold.
    # Checking one grocery leaves the CEILING unbound - raising
    # MAX_CAPACITY to a hundred thousand passed every other assertion
    # here while making every place effectively infinite again.
    ok["nor can the biggest place on the map"] = hi < 216
    print()
    print(f"  216 people against one grocery holding {grocery}: "
          f"{216 - grocery} of them find it empty")

    # Refill: with the shipped default (no respawn) it never comes
    # back, which is the game's own answer and not ours.
    ok["no-respawn means permanent"] = (
        "if not on or on == 1 then return nil end" in plc)
    # And a spent place is still shelter.
    ok["spent is not gone"] = (
        "for k in pairs(MATERIAL) do out[k] = nil end" in plc)

    print()
    for k, v in ok.items():
        print(f"  {'yes' if v else 'NO '}  {k}")
    return all(ok.values())


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
    pop = (lua / "client" / "SAO_Population.lua").read_text(
        encoding="utf-8", errors="ignore")
    per = (lua / "shared" / "SAO_Perception.lua").read_text(
        encoding="utf-8", errors="ignore")
    plc = PLACES.read_text(encoding="utf-8")
    links = {
        "the day asks for a place": "chooseDayPlace(id, rec, reach)" in pop,
        "the goal IS the place": "rec.dayGoalX, rec.dayGoalY = chosen.cx" in pop,
        "arriving teaches it": "SAO.Perception.learnBuilding(id," in pop,
        "the drift survives as the fallback":
            "rec.homeX\n                                + ZombRand" in pop,
        "belief can hold a place as a place": "function P.learnBuilding" in per,
        "and can age it": "function P.placeAge" in per,
        "places come from the map": "getBuildingAt" in plc
            and "getMetaGrid" in plc,
        "and from its room names": "room:getName()" in plc,
        # [B38] The county reads what a room CONTAINS, not only what
        # it is called - which is how seventy-five mods' additions
        # reach it without this mod knowing one of their names. The
        # shipped expressions are required because this mirror cannot
        # run Lua (GOVERNANCE: a mirror that re-derives the rule
        # cannot fail on the rule).
        # The READ, not the name. Both identifiers appear in the
        # comment block explaining them, so a bare name check passes
        # after the code is gone - GOVERNANCE's prose-is-not-code
        # clause, hit twice on the day it was written.
        "reads the game's own distribution tables":
            "local rooms = SuburbsDistributions" in plc
            and "lists = ProceduralDistributions" in plc,
        "resolves items through the script manager":
            'sm:getItem(name) or sm:getItem("Base." .. name)' in plc,
        "an item's offer is what it does to a BODY":
            "item:getHungerChange() or 0) < 0" in plc
            and "item:getThirstChange() or 0) < 0" in plc,
        "contents win over the name where the game has an answer":
            "local content = Pl.contentOffers(roomName)" in plc
            and "if not content then return stems end" in plc,
        "but shelter still comes from the name":
            "if not MATERIAL[k] then out[k] = true end" in plc,
        "and the content read is cached per room":
            "Pl.contentCache[name] = any and out or false" in plc,
        # [B39] The shelves are not infinite. [B37] closed on "they
        # cannot fail to find food"; [B37] answered it for water via
        # the mains. This is the other half: a place is spent by being
        # VISITED, holds as much as it has rooms, and refills only on
        # the game's OWN loot clock - which is off by default, so the
        # county empties permanently unless the player says otherwise.
        "a place can be emptied": "function Pl.take(place)" in plc
            and "function Pl.isSpent(place)" in plc,
        "how much it holds comes from how big it is":
            "local rooms = (place and place.roomCount) or 1" in plc,
        "it refills on the game's own loot clock":
            "SandboxVars.LootRespawn" in plc
            and "tonumber(SandboxVars.HoursForLootRespawn)" in plc,
        "and no respawn setting means it never refills":
            "if not on or on == 1 then return nil end" in plc,
        "a spent place keeps its shelter":
            "for k in pairs(MATERIAL) do out[k] = nil end" in plc,
        "the dormant read the county's own desperation line":
            "local function desperationLine()" in pop
            and "tonumber(sv.Desperation)" in pop,
        "and lessons move it for them too":
            "SAO.Lessons.desperationBump(id)" in pop,
        "somebody else's ground is belief-gated":
            "held = SAO.Perception.believesClaimed(" in pop,
        "and respected only below the line":
            "if not barred and not desperate then" in pop,
        # [B40] Everybody wakes up somewhere, and until now nobody
        # knew the one place they had certainly been. `originAnchored`
        # was written at genesis and read nowhere in the tree - one
        # mention in the whole mod.
        "genesis teaches the place they started in":
            "local startedIn = SAO.Places.at(origin.x, origin.y)" in pop
            and 'learnBuilding(rec.id, startedIn, 0, "lived")' in pop,
        "and the anchored origin is finally read":
            "rec.originAnchored then" in pop,
        "taking is recorded only when something was taken":
            "if got.water or got.food then" in pop
            and "SAO.Places.take(arrived)" in pop,
        # [B37] The offers have to be load-bearing or they are
        # decoration. Reaching water must record it, need must reach
        # the risk, and an existing world must not begin starving.
        "reaching water records the day": "rec.lastWaterDay = day" in pop,
        "reaching food records the day": "rec.lastFoodDay = day" in pop,
        "thirst reaches the death roll":
            "dryDays = daysWithout(rec" in pop
            and "risk = risk * math.min(4.0," in pop,
        "hunger reaches it too":
            "hungryDays = daysWithout(rec" in pop
            and "risk = risk * math.min(2.0," in pop,
        "an old world does not start starving":
            "if rec.lastWaterDay == nil then rec.lastWaterDay = today end"
            in pop,
        # [B37] The shutoff section below models `offersNow` in
        # PYTHON, so mutating the shipped rule cannot fail the model -
        # two of its controls came back green until these were added.
        # A mirror that only re-derives its own arithmetic is a
        # control that cannot fail ([B36] clause 2, third time). The
        # rule itself has to be required present.
        # The CALL, not the name. The name also appears in the comment
        # four lines above it, so a bare `getWaterShutModifier()`
        # check passes on the prose that describes the code after the
        # code itself is gone.
        "the county's water can go off":
            "function Pl.waterIsOn" in plc
            and "getSandboxOptions():getWaterShutModifier()" in plc,
        "only stored water and drink survive it":
            "if place.offers.storedWater or place.offers.drink then" in plc,
        "a bathroom depends on the mains":
            "Pl.MAINS_WATER = { bathroom = true" in plc,
        "the day asks what is offered TODAY, twice":
            pop.count("SAO.Places.offersNow(") >= 2,
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

    table, excluded, mains = offers()
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
    watered = shutoff(table, excluded, mains)
    shelves = scarcity(PLACES.read_text(encoding='utf-8'))

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
    if not watered:
        print("  FAULT: the water shutoff leaves the county dry, or "
              "changes nothing")
        return 1
    if not shelves:
        print("  FAULT: the county's places never run out")
        return 1
    print(f"  every stem matches the shipped map; none exceeds "
          f"{BREADTH_CEILING:.0%} breadth")
    print("  the day goes to a place, learns it, and refuses enemy ground")
    print("  when the mains go, houses lose their water and the shops "
          "keep it")
    return 0


if __name__ == "__main__":
    sys.exit(main())
