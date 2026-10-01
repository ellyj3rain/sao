#!/usr/bin/env python3
r"""Border 121 - native building evidence reaches private planning.

The scout weighed rooms, area and water, and could not see a door. So
a glass-fronted shop with eleven ways in beat a house with three
whenever it had one more room, and the outcomes DR-037 describes - a
neighbourhood that becomes gated, choke points read once the ground is
clear - rest on exactly the fact the scout was blind to.

WHAT THIS HOLDS, AND WHY IT IS SHAPED THIS WAY
----------------------------------------------
  1. IT IS A TIE-BREAK, NOT A WEIGHT. Adding a coefficient for ways-in
     would be inventing a rate at which a door is worth part of a
     room, and nothing in the county gives that number. The check
     therefore refuses to find ways-in inside the score expression at
     all: the moment somebody multiplies it by anything, an invented
     rate has entered the county through the back door.
  2. The margin is the score's OWN unit - one room's worth, named -
     so it moves if the scoring ever does and nobody decides
     separately what a door is worth.
  3. The count is the same predicate the boarding uses, so what the
     scout counts and what somebody would later have to shut are the
     same set of things rather than two ideas of a way in.
  4. It reads the loaded cell and loads nothing: the scout is standing
     in the neighbourhood. Loading ground is [C46]'s, under its own
     border, and must not be duplicated here.
  5. An unreadable count never wins a tie-break.
  6. The old global scout remains a compatibility Java API, with the
     tie-break checks above. It no longer chooses a residence for Lua.
     Current building acquisition runs through native personal vision,
     the B-record parser, retained private exterior leads and Labor's
     uncertain residence appraisal. The checks follow those owners,
     including exact approach identity and withheld interior stock.

An optional argv[1] points the checker at another tree root, which is
how its control runs: the pre-batch scout cannot see a door.
"""
import contextlib
import io
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from lua_read import function_body, strip_lua
from protocol_arity import brace_body

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
SETTLEMENT = ROOT / "java" / "src" / "com" / "sao" / "engine" / "SAOSettlement.java"
BUILD = ROOT / "java" / "src" / "com" / "sao" / "engine" / "SAOBuild.java"
CONTROLLER = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Controller.lua"
CHECK = ROOT / "tools" / "check.sh"
SCANNER = ROOT / "java/src/com/sao/engine/SAOPerceptionScanner.java"
BRIDGE = ROOT / "java/src/com/sao/bridge/SAOBridge.java"
PERCEPTION = ROOT / "mod/42.20/media/lua/shared/SAO_Perception.lua"
LABOR = ROOT / "mod/42.20/media/lua/shared/SAO_Labor.lua"


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""


def strip_block_comments(java):
    out, i, n = [], 0, len(java)
    while i < n:
        if java.startswith("/*", i):
            j = java.find("*/", i)
            i = n if j < 0 else j + 2
        elif java.startswith("//", i):
            j = java.find("\n", i)
            i = n if j < 0 else j
        else:
            out.append(java[i])
            i += 1
    return "".join(out)


def java_method(source, signature):
    match = re.search(signature + r"\s*\{", source)
    return brace_body(source, match.end()) if match else ""


def check_sources(sources):
    faults = []
    print("=" * 74)
    print("NATIVE BUILDING EVIDENCE REACHES PRIVATE PLANNING")
    print("=" * 74)

    settlement = sources[SETTLEMENT]
    if not settlement:
        print("  FAULT: there is no scout to judge anything")
        return 1
    code = strip_block_comments(settlement)

    # 1. The score expression must not contain the count.
    score = re.search(r"double score = (.*?);", code, re.S)
    if not score:
        faults.append("the score expression cannot be read, so this border "
                      "cannot tell whether a door has been given a price")
    else:
        body = score.group(1)
        print("     the score: " + " ".join(body.split()))
        if "ways" in body:
            faults.append(
                "ways-in appears inside the score. That prices a door against "
                "a room, and nothing in the county gives that rate - the "
                "count is a tie-break precisely so nobody has to invent one")

    ways = re.search(r"public static int waysIn\(", code)
    checks = {
        "the count exists": ways is not None,
        "it is the same predicate the boarding uses":
            "BarricadeAble" in code and "BarricadeAble" in sources[BUILD],
        "it reads the loaded cell":
            "cell.getGridSquare(" in code,
        "and loads nothing itself":
            "LoadFromDisk" not in code and "new IsoChunk" not in code,
        "an unreadable count is -1":
            "return -1;" in code,
        "and -1 never wins a tie-break":
            "bestWays >= 0 && ways >= 0" in code,

        # 2. The margin is the score's own unit.
        "a room's worth is named once":
            re.search(r"ROOM_WEIGHT = [\d.]+", code) is not None,
        "the score uses that name rather than the number":
            "rooms * ROOM_WEIGHT" in code and "rooms * 8.0" not in code,
        "and the margin is that same name":
            "Math.abs(score - bestScore) <= ROOM_WEIGHT" in code,

        # The tie-break itself.
        "fewer ways in wins a tie":
            "ways < bestWays" in code,
        "and only within the margin":
            re.search(r"Math\.abs\(score - bestScore\) <= ROOM_WEIGHT\s*\n?\s*&& ways < bestWays",
                      code) is not None,

        # 6. The wire.
        "the report carries the count":
            re.search(r'\+ \(bestWays < 0 \? waysIn\(cell, bestDef\) : bestWays\)', code) is not None,
        "the gate runs this border":
            "tools/ways_in_test.py" in sources[CHECK],
    }

    scanner = strip_block_comments(sources[SCANNER])
    bridge = strip_block_comments(sources[BRIDGE])
    perceive = java_method(bridge, r"public String perceive\(Object object, String knownTiles\)")
    exterior = java_method(scanner, r"private static void appendExteriorBuildings\([^)]*\)")
    scan = java_method(scanner, r"public static synchronized String scan\(IsoGameCharacter shell, String knownTiles\)")
    visibility = java_method(scanner, r"static boolean canSeeWorldSquareNow\([^)]*\)")
    point = java_method(scanner, r"private static boolean visibleTransferPoint\([^)]*\)")
    floor = java_method(scanner, r"private static boolean withinSameFloorRange\([^)]*\)")
    parse = strip_lua(function_body(sources[PERCEPTION], "observeExteriorLead") or "", strings=False)
    observe = strip_lua(function_body(sources[PERCEPTION], "P.observe") or "", strings=False)
    leads = strip_lua(function_body(sources[PERCEPTION], "P.knownBuildingLeads") or "", strings=False)
    appraisal = strip_lua(function_body(sources[LABOR], "Labor.assessResidence") or "", strings=False)
    exterior_appraisal = re.search(
        r"for key, belief in pairs\(perception and perception\.knownBuildingLeads.*?\n    end",
        appraisal, re.S)
    wire = re.search(r'out\.append\("B:"\)(.*?);', exterior, re.S)
    checks.update({
        "current bridge calls personal native scanning":
            "return com.sao.engine.SAOPerceptionScanner.scan(who, knownTiles);" in perceive,
        "current native scan produces exterior records":
            "appendExteriorBuildings(out, shell);" in scan,
        "exterior acquisition excludes the God camera":
            'observer.getModData().rawget("SAO_ObserverAnchor") != null' in exterior,
        "exterior acquisition uses current loaded observer identity":
            "cell.getGridSquare(sx, sy, z) != observer.getCurrentSquare()" in exterior,
        "observed approach requires a loaded standable exterior tile":
            "outside == null || !outside.isOutside() || !outside.isSolidFloor()" in exterior
            and "!outside.isFree(false)" in exterior,
        "a visible native door or wall supplies the boundary":
            "outside.getDoorTo(inside) != null" in exterior and "!outside.isWallTo(inside)" in exterior,
        "different observed doors retain different approach identities":
            "if (!emitted.add(boundaryKey)) continue;" in exterior
            and 'inside.getX() + ":" + inside.getY() + ":" + z + ":" + door' in exterior,
        "native exterior acquisition obeys personal visibility":
            "if (!canSeeWorldSquareNow(observer, outside, RANGE)) continue;" in exterior,
        "personal visibility retains native floor range facing and occlusion":
            "visibleWorldPoint(observer, target, Math.min(RANGE, range))" in visibility
            and "withinSameFloorRange(sx, sy, sz, x, y, z, range)" in point
            and "alignment < CONE_COS" in point
            and "clearPath(observer.getCurrentSquare(), target, true)" in point
            and "Math.abs(az - bz) >= 0.5f" in floor,
        "the native exterior report has the eight parsed fields":
            wire is not None and wire.group(1).count(".append(':')") == 6
            and "#fields ~= 8" in parse,
        "Lua observe dispatches the native building record to its real owner":
            re.search(r'elseif\s+f\[1\]\s*==\s*"B"\s+then\s+observeExteriorLead\(id, body, b, f, tick\)', observe) is not None,
        "Lua observe acquires its records through the actual native bridge":
            'return SAOJavaBridge:perceive(body, asleep and "" or knownZombieTiles(b, body))' in observe,
        "the building parser binds evidence to this person's actual body":
            "own == body" in parse and "tostring(md.SAOPersonId) == tostring(id)" in parse
            and "not md.SAO_ObserverAnchor" in parse,
        "Lua retains the observed approach and exact boundary":
            "cx = x, cy = y, z = z" in parse and "surfaceX = sx, surfaceY = sy, kind = kind" in parse
            and "P.exteriorLeadKey(lead)" in parse and "b.buildingLeads[approachId] = lead" in parse,
        "private leads reject foreign stale or changed evidence identity":
            "lead.personId == tostring(id)" in leads
            and 'lead.source == "native-visible-exterior"' in leads
            and "P.exteriorLeadKey(lead) == key" in leads
            and "lead.at <= tick" in leads,
        "Labor reads this actor's private exterior leads":
            "perception.knownBuildingLeads(id, tick)" in appraisal
            and "approachId = key" in appraisal and "cx = belief.cx, cy = belief.cy, z = belief.z" in appraisal,
        "exterior candidates retain uncertainty about interior stock":
            exterior_appraisal is not None
            and 'stock = "unknown-until-private-inspection"' in exterior_appraisal.group(0)
            and not re.search(r"getRooms\(|getArea\(|getW\(|getH\(|hasWater\(|getContainer\(", exterior),
        "the controller does not restore global scout residence selection":
            re.search(r"SAOJavaBridge\s*:\s*scoutBase\s*\(", strip_lua(sources[CONTROLLER])) is None,
    })

    print()
    for k, v in checks.items():
        print(f"  {'yes' if v else 'NO '}  {k}")
        if not v:
            faults.append(k)

    print()
    print("VERDICT:")
    if faults:
        for f in dict.fromkeys(faults):
            print("  FAULT: " + f)
        return 1
    print("  121) native/private building owners are connected; exterior "
          "approaches preserve uncertainty; legacy scout tie-break remains checked")
    return 0


def main():
    paths = (SETTLEMENT, BUILD, CONTROLLER, CHECK, SCANNER, BRIDGE, PERCEPTION, LABOR)
    sources = {path: read(path) for path in paths}
    status = check_sources(sources)
    if status:
        return status
    controls = [
        (SETTLEMENT, "rooms * ROOM_WEIGHT", "rooms * ROOM_WEIGHT + ways",
         "ways-in appears inside the score"),
        (SCANNER, "appendExteriorBuildings(out, shell);", "/* exterior acquisition removed */",
         "current native scan produces exterior records"),
        (SCANNER, "if (!canSeeWorldSquareNow(observer, outside, RANGE)) continue;", "if (false) continue;",
         "native exterior acquisition obeys personal visibility"),
        (SCANNER, 'observer.getModData().rawget("SAO_ObserverAnchor") != null', "false",
         "exterior acquisition excludes the God camera"),
        (SCANNER, "if (!emitted.add(boundaryKey)) continue;", "if (!emitted.add(Long.toString(def.getID()))) continue;",
         "different observed doors retain different approach identities"),
        (SCANNER, 'out.append("B:")', 'out.append("Q:")',
         "the native exterior report has the eight parsed fields"),
        (BRIDGE, "return com.sao.engine.SAOPerceptionScanner.scan(who, knownTiles);", 'return "";',
         "current bridge calls personal native scanning"),
        (PERCEPTION, 'return SAOJavaBridge:perceive(body, asleep and "" or knownZombieTiles(b, body))', 'return ""',
         "Lua observe acquires its records through the actual native bridge"),
        (PERCEPTION, "observeExteriorLead(id, body, b, f, tick)", "do end",
         "Lua observe dispatches the native building record to its real owner"),
        (PERCEPTION, "b.buildingLeads[approachId] = lead", "do end",
         "Lua retains the observed approach and exact boundary"),
        (PERCEPTION, "lead.personId == tostring(id)", "true",
         "private leads reject foreign stale or changed evidence identity"),
        (LABOR, "perception.knownBuildingLeads(id, tick)", "{}",
         "Labor reads this actor's private exterior leads"),
        (CONTROLLER, "function Ctl.forget(id)",
         "function Ctl.forget(id)\n    SAOJavaBridge:scoutBase(SAO.Body.get(id), '')",
         "the controller does not restore global scout residence selection"),
    ]
    for path, before, after, expected in controls:
        # The handler declaration and call share this spelling; mutate its
        # unique indented dispatch call, preserving the actual parser owner.
        if path == PERCEPTION and before == "observeExteriorLead(id, body, b, f, tick)":
            before = "                " + before
        if sources[path].count(before) != 1:
            print(f"  FAULT: building control anchor drift: {path.name}: {expected}")
            return 1
        mutated = dict(sources)
        mutated[path] = sources[path].replace(before, after, 1)
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            exit_code = check_sources(mutated)
        if exit_code != 1 or "  FAULT: " not in output.getvalue() or expected not in output.getvalue():
            print(f"  FAULT: building control did not reject its defect: {expected}")
            return 1
        print(f"  CONTROL rejected: {expected}")
    print(f"  121) building owner controls: {len(controls)} rejected")
    return 0


if __name__ == "__main__":
    sys.exit(main())
