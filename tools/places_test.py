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
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

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
            re.search(r"(?:local\s+)?startedIn = SAO\.Places\.at\(origin\.x, origin\.y\)", admissions) is not None
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


ENTRY_PROBE = r'''
import java.nio.ByteBuffer;
import java.nio.file.Files;
import java.nio.file.Path;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.JavaFunction;
import se.krka.kahlua.vm.KahluaTable;
import se.krka.kahlua.vm.KahluaThread;
import zombie.Lua.LuaManager;
import zombie.characters.IsoPlayer;
import zombie.characters.SurvivorDesc;
import zombie.iso.BuildingDef;
import zombie.iso.IsoCell;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoWorld;
import zombie.iso.areas.IsoBuilding;
import zombie.iso.areas.IsoRoom;

/** Actual occupied native squares exposed to the production Perception owner. */
public final class PlaceEntryProbe {
    private static IsoGridSquare square(IsoCell cell, int x, int y, int z, long id) {
        var square = new IsoGridSquare(cell, null, x, y, z);
        if (id != 0) {
            var definition = new BuildingDef(); definition.id = id;
            var building = new IsoBuilding(); building.def = definition;
            var room = new IsoRoom(); room.building = building;
            square.setRoom(room); square.roomId = id;
            if (square.getBuildingDef() != definition) throw new AssertionError("native occupied fixture");
        } else {
            square.getProperties().set(zombie.iso.SpriteDetails.IsoFlagType.exterior);
            if (square.getBuildingDef() != null || !square.isOutside()) throw new AssertionError("native outdoor fixture");
        }
        return square;
    }
    public static void main(String[] args) throws Exception {
        var platform = new J2SEPlatform();
        var env = platform.newEnvironment(); var thread = new KahluaThread(platform, env);
        thread.debugOwnerThread = Thread.currentThread();
        LuaManager.platform = platform; LuaManager.env = env; LuaManager.thread = thread;
        LuaManager.converterManager = new se.krka.kahlua.converter.KahluaConverterManager();
        zombie.Lua.KahluaNumberConverter.install(LuaManager.converterManager);
        LuaManager.caller = new se.krka.kahlua.integration.LuaCaller(LuaManager.converterManager);
        var exposer = new LuaManager.Exposer(LuaManager.converterManager, platform, env);
        for (Class<?> type : new Class<?>[] {IsoPlayer.class, IsoGridSquare.class, BuildingDef.class}) {
            exposer.setExposed(type); exposer.exposeLikeJava(type, env);
        }
        zombie.Lua.LuaEventManager.register(platform, env);
        zombie.core.random.RandStandard.INSTANCE.init();
        zombie.ZomboidFileSystem.instance.init();
        zombie.SoundManager.instance = new zombie.DummySoundManager();
        SurvivorDesc.HairCommonColors.add(new zombie.core.ImmutableColor(.2f,.3f,.4f));
        var styles = new zombie.core.skinnedmodel.population.HairStyles();
        zombie.core.skinnedmodel.population.HairStyles.instance = styles;
        zombie.core.skinnedmodel.population.BeardStyles.instance = new zombie.core.skinnedmodel.population.BeardStyles();
        var hair = new zombie.core.skinnedmodel.population.HairStyle(); hair.name="fixture";
        styles.maleStyles.add(hair); styles.femaleStyles.add(hair);
        var beard = new zombie.core.skinnedmodel.population.BeardStyle(); beard.name="fixture";
        zombie.core.skinnedmodel.population.BeardStyles.instance.styles.add(beard);
        var cell = new IsoCell(1,1); zombie.iso.WorldReuserThread.instance.stop();
        IsoWorld.instance.currentCell = cell;
        var descriptor = new SurvivorDesc(false); descriptor.getHumanVisual().setSkinTextureName("fixture");
        env.rawset("__body", new IsoPlayer(cell,descriptor,10,20,0,false));
        env.rawset("__inside", square(cell,10,20,0,42));
        env.rawset("__sameBuilding", square(cell,11,20,0,42));
        env.rawset("__other", square(cell,30,40,0,43));
        env.rawset("__outside", square(cell,9,20,0,0));
        var unresolved = square(cell,10,20,0,0);
        unresolved.getProperties().unset(zombie.iso.SpriteDetails.IsoFlagType.exterior);
        unresolved.roomId = 42;
        if (unresolved.getBuildingDef() != null || unresolved.isOutside()) throw new AssertionError("native unresolved interior fixture");
        env.rawset("__unresolvedInterior", unresolved);
        env.rawset("__wrongFloorBuilding", square(cell,10,20,1,44));
        env.rawset("__roundtrip", (JavaFunction) (frame, count) -> {
            try {
                ByteBuffer bytes = ByteBuffer.allocate(1024*1024);
                ((KahluaTable) frame.get(0)).save(bytes); bytes.flip();
                KahluaTable restored = platform.newTable(); restored.load(bytes,249);
                frame.push(restored); return 1;
            } catch (Exception error) { throw new RuntimeException(error); }
        });
        for (String file : args) {
            try (var reader = Files.newBufferedReader(Path.of(file))) {
                thread.call(LuaCompiler.loadis(reader,file,env),null,null,null);
            }
        }
        if (env.rawget("__entryErrors") != null) System.out.println("DETAIL " + env.rawget("__entryErrors"));
        System.out.println("RESULT " + env.rawget("__entryResult"));
    }
}
'''

ENTRY_HOST = r'''
__tick=100 __persisted={} __snapshotCalls=0 __mapUnavailable=false
__placeA={id=42,cx=12,cy=22,minX=10,minY=20,maxX=15,maxY=25}
__placeB={id=43,cx=32,cy=42,minX=30,minY=40,maxX=35,maxY=45}
__hidden={medicine={state='available',observedAt=3,quantities={medicine=99}}}
SAO={Log={line=function() end},History={ticks=function() return __tick end},
    Conditions={memoryFactor=function() return 1 end},
    Standing={claimOf=function() return nil end,groupOf=function() return nil end},
    Places={at=function(x,y)
        if __mapUnavailable then return nil end
        if x>=10 and x<15 and y>=20 and y<25 then return __placeA end
        if x>=30 and x<35 and y>=40 and y<45 then return __placeB end
        return nil
    end},
    WorldSources={beliefSnapshot=function(place)
        __snapshotCalls=__snapshotCalls+1
        return {medicine=true},'global-secret',{medicine=true},__hidden
    end}}
Events={OnGameStart={Add=function() end}}
ModData={getOrCreate=function(key) assert(key=='SurvivorAwareness_Beliefs') return __persisted end}
SAOJavaBridge={perceive=function() return '' end}
'''

ENTRY_CASES = r'''
local P=SAO.Perception
local results={}
local function empty(value) for _ in pairs(value) do return false end return true end
local function at(square)
    __body:setCurrent(square)
    if square then
        __body:setX(square:getX()+0.5) __body:setY(square:getY()+0.5) __body:setZ(square:getZ())
    end
end
local function observe(square,tick,asleep)
    __tick=tick or (__tick+20) at(square)
    P.observe('a',__body,__tick,asleep==true)
    return P.beliefs.a
end
local function row(id) return P.knownPlaces('a')[id or 42] end
local function check(name,fn)
    P.beliefs={} P.beliefVersion=0 __persisted={} __snapshotCalls=0 __mapUnavailable=false __tick=100
    SAOJavaBridge={perceive=function() return '' end}
    local ok,value=pcall(fn)
    if not ok then __entryErrors=(__entryErrors or '')..name..': '..tostring(value)..'\n' end
    results[#results+1]=name..'='..tostring(ok and value==true)
end
check('native_occupied_building_admits_personal_visit',function()
    observe(__inside,100)
    local value=row()
    return __body:getCurrentSquare():getBuildingDef():getID()==42
        and value and value.visits==1 and value.at==100 and value.source=='observed'
        and value.minX==10 and value.maxY==25 and P.placeAge('a',42,160)==60
        and P.beliefs.a.occupiedBuilding=='42'
end)
check('entry_never_reads_global_stock',function()
    observe(__inside,100)
    local value=row()
    return value and __snapshotCalls==0 and empty(value.sources)
        and empty(value.sourceFacts) and value.sourceRevision==''
end)
check('stationary_scans_and_same_building_rooms_are_one_visit',function()
    observe(__inside,100)
    for tick=120,500,20 do observe(tick%40==0 and __inside or __sameBuilding,tick) end
    return row().visits==1 and row().at==100 and P.beliefs.a.occupiedBuilding=='42'
end)
check('positive_outdoor_exit_allows_one_reentry',function()
    observe(__inside,100) local b=observe(__outside,120)
    if b.occupiedBuilding~=false or row().visits~=1 then return false end
    observe(__inside,140) observe(__inside,160)
    return row().visits==2 and row().at==140
end)
check('different_native_buildings_count_separate_entries',function()
    observe(__inside,100) observe(__other,120) observe(__inside,140)
    return row().visits==2 and row(43).visits==1 and row(43).at==120
end)
check('unloaded_square_does_not_invent_exit',function()
    observe(__inside,100) observe(nil,120) observe(__inside,140)
    return row().visits==1 and row().at==100
end)
check('unresolved_native_interior_room_does_not_invent_exit',function()
    observe(__inside,100) observe(__unresolvedInterior,120) observe(__inside,140)
    return __unresolvedInterior:getBuildingDef()==nil and not __unresolvedInterior:isOutside()
        and __unresolvedInterior:getRoomID()==42 and row().visits==1 and row().at==100
end)
check('unresolved_map_record_does_not_invent_exit',function()
    observe(__inside,100) __mapUnavailable=true observe(__sameBuilding,120)
    __mapUnavailable=false observe(__inside,140)
    return row().visits==1 and row().at==100
end)
check('native_building_id_must_match_map_record',function()
    observe(__wrongFloorBuilding,100)
    if row() then return false end
    observe(__inside,120) observe(__wrongFloorBuilding,140) observe(__inside,160)
    return row().visits==1 and row().at==120
end)
check('asleep_does_not_admit_unseen_building',function()
    observe(__inside,100,true)
    if row() then return false end
    observe(__inside,120,false)
    return row().visits==1 and row().at==120
end)
check('occupied_entry_is_independent_of_threat_bridge',function()
    SAOJavaBridge=nil observe(__inside,100)
    return row() and row().visits==1
end)
check('admission_lived_visit_is_not_recounted_on_body_load',function()
    P.learnBuilding('a',__placeA,0,'lived') observe(__inside,100)
    return row().visits==1 and row().at==0 and row().source=='lived' and __snapshotCalls==1
end)
check('dormant_arrival_is_not_recounted_on_body_load',function()
    P.learnBuilding('a',__placeB,40,'observed') observe(__other,100)
    return row(43).visits==1 and row(43).at==40 and __snapshotCalls==1
end)
check('dormant_arrival_updates_previous_loaded_entry_receipt',function()
    P.learnBuilding('a',__placeA,0,'lived') observe(__inside,100)
    P.learnBuilding('a',__placeB,140,'observed') observe(__other,160)
    return row(43).visits==1 and row(43).at==140 and P.beliefs.a.occupiedBuilding=='43'
end)
check('return_preserves_private_sources_and_revisions',function()
    observe(__inside,100)
    local value=row()
    local private={pantry={state='available',revision='pantry-old',quantities={food=1}}}
    value.sourceFacts=private value.sources={food=true} value.sourceAccess={food=true} value.sourceRevision='private-old'
    observe(__outside,120) observe(__inside,140)
    return row().visits==2 and row().at==140 and row().sourceFacts==private
        and private.pantry.revision=='pantry-old' and row().sources.food==true
        and row().sources.medicine==nil and row().sourceRevision=='private-old' and __snapshotCalls==0
end)
check('serialized_entry_receipt_survives_bind_without_extra_visit',function()
    observe(__inside,100) __persisted=__roundtrip(P.beliefs) P.beliefs={}
    __tick=120 if not P.bindPersistentStore() then return false end
    observe(__inside,140)
    return row().visits==1 and row().at==100 and P.beliefs.a.occupiedBuilding=='42'
end)
check('serialized_outdoor_receipt_preserves_next_reentry',function()
    observe(__inside,100) observe(__outside,120)
    __persisted=__roundtrip(P.beliefs) P.beliefs={} __tick=140
    if not P.bindPersistentStore() then return false end
    observe(__inside,160)
    return row().visits==2 and row().at==160
end)
check('legacy_current_place_establishes_continuity_without_visit',function()
    P.learnBuilding('a',__placeA,40,'lived')
    local b=P.beliefs.a b.occupiedBuilding=nil b.known[42].visits=4
    __persisted=__roundtrip(P.beliefs) P.beliefs={} __tick=100 P.bindPersistentStore()
    observe(__inside,120)
    if row().visits~=4 or row().at~=40 or row().source~='lived' then return false end
    observe(__outside,140) observe(__inside,160)
    return row().visits==5 and row().at==160
end)
check('known_source_without_prior_visit_gains_exactly_one',function()
    observe(__outside,100)
    P.beliefs.a.known={[42]={sourceFacts={},sources={},sourceAccess={},sourceRevision='',at=10,source='inspected-source'}}
    observe(__inside,120) observe(__inside,140)
    return row().visits==1 and row().at==120
end)
check('source_inspection_string_key_becomes_one_native_building',function()
    observe(__outside,100)
    local old={sourceFacts={},sources={},sourceAccess={},sourceRevision='kept',at=10,source='inspected-source'}
    P.beliefs.a.known={['42']=old}
    observe(__inside,120)
    return row() and row().visits==1 and row().sourceFacts==old.sourceFacts
        and row().sourceRevision=='kept' and P.knownPlaces('a')['42']==nil and P.placeAge('a',42,140)==20
end)
check('legacy_string_visit_keeps_familiarity_under_native_key',function()
    P.learnBuilding('a',__placeA,40,'lived')
    local b=P.beliefs.a local old=b.known[42]
    b.known[42]=nil b.known['42']=old old.visits=4 b.occupiedBuilding=nil
    __persisted=__roundtrip(P.beliefs) P.beliefs={} __tick=100 P.bindPersistentStore()
    observe(__inside,120)
    return row() and row().visits==4 and row().at==40 and row().source=='lived'
        and P.knownPlaces('a')['42']==nil and P.placeAge('a',42,140)==100
end)
check('dual_aliases_keep_private_facts_without_duplicate_visits',function()
    observe(nil,100)
    local pantry={state='available',revision='canonical',access='accessible',quantities={food=1}}
    local well={state='available',revision='alias-water',access='accessible',quantities={water=1}}
    P.beliefs.a.known={
        [42]={visits=2,at=40,source='observed',sourceFacts={pantry=pantry}},
        ['42']={visits=5,at=50,source='inspected-source',sourceFacts={well=well,
            pantry={state='available',revision='conflicting-alias',quantities={food=99}}}}
    }
    observe(__inside,120)
    local value=row()
    return value and value.visits==5 and value.at==50 and value.source=='inspected-source'
        and value.sourceFacts.pantry==pantry and value.sourceFacts.well==well
        and value.sources.food and value.sources.water and value.sourceAccess.water
        and P.knownPlaces('a')['42']==nil and P.placeAge('a',42,140)==90 and __snapshotCalls==0
end)
check('one_person_entry_never_teaches_another',function()
    observe(__inside,100)
    return row().visits==1 and empty(P.knownPlaces('b'))
end)
__entryResult=table.concat(results,';')
'''


def entry_checks(receipt_path=None):
    """Drive production acquisition with real native body/square/building methods."""
    game = GAME.parent
    jar = game / 'projectzomboid.jar'
    jdk = pathlib.Path(os.environ.get('JDK_BIN', r'C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin'))
    source_path = PLACES.with_name('SAO_Perception.lua')
    if not jar.is_file():
        print('  SKIPPED native building entries: installed engine unavailable')
        return 0
    receipt = {'schema': 'sao-native-place-entries/1', 'status': 'failed', 'runs': [],
        'boundary': 'Actual native IsoPlayer, IsoGridSquare and BuildingDef in installed Kahlua; controlled room placement, no rendered gameplay.',
        'engineSha256': hashlib.sha256(jar.read_bytes()).hexdigest(),
        'sourceSha256': hashlib.sha256(source_path.read_bytes()).hexdigest(),
        'testSha256': hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest()}
    source = source_path.read_text(encoding='utf-8')
    expected = set(re.findall(r"check\('([a-z0-9_]+)'", ENTRY_CASES))
    def mutate(old,new):
        if source.count(old)!=1: raise AssertionError('entry control anchor drifted: '+old)
        return source.replace(old,new,1)
    try:
        controls = [
            ('entry-hook-removed', mutate('pcall(function() observeOccupiedBuilding(id, body, tick) end)',
                'pcall(function() end)'), 'native_occupied_building_admits_personal_visit'),
            ('every-scan-is-visit', mutate('if b.occupiedBuilding == occupied then return end',
                'if false then return end'), 'stationary_scans_and_same_building_rooms_are_one_visit'),
            ('outdoor-exit-ignored', mutate('b.occupiedBuilding = false',
                'b.occupiedBuilding = b.occupiedBuilding'), 'positive_outdoor_exit_allows_one_reentry'),
            ('unloaded-is-exit', mutate('if not square then return end -- unavailable is not an observed exit',
                'if not square then store(id).occupiedBuilding = false return end'), 'unloaded_square_does_not_invent_exit'),
            ('unresolved-interior-is-exit', mutate('if square:isOutside() and b.occupiedBuilding ~= false then',
                'if b.occupiedBuilding ~= false then'), 'unresolved_native_interior_room_does_not_invent_exit'),
            ('occupied-id-ignored', mutate('if not place or tostring(place.id) ~= tostring(def:getID()) then return end',
                'if not place then return end'), 'native_building_id_must_match_map_record'),
            ('whole-building-stock-revealed', mutate('rememberBuildingVisit(id, place, tick, "observed", false)',
                'rememberBuildingVisit(id, place, tick, "observed", true)'), 'entry_never_reads_global_stock'),
            ('legacy-presence-recounted', mutate('if b.occupiedBuilding == nil and was and (was.visits or 0) > 0 then',
                'if false then'), 'legacy_current_place_establishes_continuity_without_visit'),
            ('asleep-acquires-place', mutate('    if not asleep then\n        pcall(function() observeOccupiedBuilding',
                '    if true then\n        pcall(function() observeOccupiedBuilding'), 'asleep_does_not_admit_unseen_building'),
            ('dormant-receipt-not-updated', mutate('if source == "observed" or source == "lived" then',
                'if source == "lived" then'), 'dormant_arrival_updates_previous_loaded_entry_receipt'),
            ('legacy-native-key-not-normalized', mutate('known[place.id], known[occupied] = was, nil',
                'known[occupied] = was'), 'legacy_string_visit_keeps_familiarity_under_native_key'),
            ('discard-alias-private-facts', mutate('if was.sourceFacts[sourceId] == nil then',
                'if false then'), 'dual_aliases_keep_private_facts_without_duplicate_visits'),
            ('sum-alias-visits', mutate('was.visits = math.max(was.visits or 0, alias.visits or 0)',
                'was.visits = (was.visits or 0) + (alias.visits or 0)'), 'dual_aliases_keep_private_facts_without_duplicate_visits'),
            ('alias-revision-overwrites-native', mutate('if was.sourceFacts[sourceId] == nil then',
                'if true then'), 'dual_aliases_keep_private_facts_without_duplicate_visits'),
        ]
        with tempfile.TemporaryDirectory(prefix='sao-place-entry-') as directory:
            work=pathlib.Path(directory)
            def run(command,label):
                result=subprocess.run(list(map(str,command)),cwd=work,capture_output=True,
                    text=True,encoding='utf-8',errors='replace',timeout=120)
                receipt['runs'].append({'label':label,'exit':result.returncode,'stdout':result.stdout,'stderr':result.stderr})
                if result.returncode: raise AssertionError(label+'\n'+result.stdout+result.stderr)
                return result.stdout
            java=work/'PlaceEntryProbe.java'; java.write_text(ENTRY_PROBE,encoding='utf-8')
            host=work/'host.lua'; host.write_text(ENTRY_HOST,encoding='utf-8')
            cases=work/'cases.lua'; cases.write_text(ENTRY_CASES,encoding='utf-8')
            shutil.copy2(game/'stdlib.lua',work/'stdlib.lua')
            run([jdk/'javac.exe','-encoding','UTF-8','-cp',jar,'-d',work,java],'compile-native-entry-probe')
            receipt['controls']=[]
            for label,text,marker in [('production',source,None),*controls]:
                module=work/(label+'.lua'); module.write_text(text,encoding='utf-8')
                output=run([jdk/'java.exe',f'-Duser.home={work}','-Djava.awt.headless=true',
                    '-Dstdout.encoding=UTF-8','--enable-native-access=ALL-UNNAMED','-cp',
                    os.pathsep.join(map(str,(work,jar))),'PlaceEntryProbe',host,module,cases],label)
                result=next((line[7:] for line in output.splitlines() if line.startswith('RESULT ')), '')
                checks=dict(re.findall(r'([a-z0-9_]+)=(true|false)',result))
                if set(checks)!=expected: raise AssertionError('missing actual entry verdicts: '+label+'\n'+output)
                if marker is None:
                    failed=[name for name,value in checks.items() if value!='true']
                    if failed: raise AssertionError('actual entry cases failed: '+', '.join(failed)+'\n'+output)
                    receipt['checks']=checks
                    print(f'  PASS {len(checks)} actual native/Kahlua building-entry cases')
                else:
                    if checks[marker]!='false': raise AssertionError('entry control did not reverse verdict: '+label+'\n'+output)
                    receipt['controls'].append({'name':label,'marker':marker,'rejected':True})
                    print('  PASS entry control refused: '+label)
        receipt['status']='passed'
    except (AssertionError,OSError,subprocess.TimeoutExpired) as error:
        receipt['error']=str(error)
        print('  FAULT: '+str(error))
    if receipt_path:
        receipt_path.parent.mkdir(parents=True,exist_ok=True)
        receipt_path.write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    return 0 if receipt['status']=='passed' else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--receipt', type=pathlib.Path)
    parser.add_argument('--entries-only', action='store_true')
    args = parser.parse_args()
    if args.entries_only:
        return entry_checks(args.receipt)
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
    entries = entry_checks(args.receipt)
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
    if entries:
        return entries
    print(f"  every stem matches the shipped map; none exceeds "
          f"{BREADTH_CEILING:.0%} breadth")
    print("  the day goes to a place, learns it, and refuses enemy ground")
    print("  room vocabulary guides exploration; exact native sources decide stock")
    return 0


if __name__ == "__main__":
    sys.exit(main())
