#!/usr/bin/env python3
r"""Border 154 - vehicles hold keys and containers.

The driving port had one old reading wrong. `tryStartEngine(boolean)`
does not take a cheat flag: after the cheat, easy-use and ignition
paths it reads the argument as a held-key answer. Passing false made a
survivor walk past the key in their own bag. The engine's
`haveThisKeyId` is the player path and searches a key ring's container
too.

The ground pass found the other half. Campers and trailers are real
vehicles even where they have no engine to start. Their vehicle parts
hold real item containers, so food, cooking and stores must read them
inside the same radius as an ordinary shelf. A vehicle outside that radius,
a non-container part, and a compartment the engine says this person cannot
access are not ground. A remembered vehicle source refreshes its moving
position and access again before use.

This runs the keyed preference through the engine's Kahlua VM, checks
the Java/Lua transfer and every material reader, then mutates the key
start and part-container guards. The controls must fault.
"""
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else \
    pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
JAVA = ROOT / "java" / "src" / "com" / "sao" / "engine"
DRIVER = JAVA / "SAODriver.java"
NEEDS = JAVA / "SAONeeds.java"
CONTROLLER = LUA / "client" / "SAO_Controller.lua"
STANDING = LUA / "shared" / "SAO_Standing.lua"
RUNNER = ROOT / "tools" / "luacheck" / "LuaRun.java"
OUT = ROOT / "java" / "out" / "luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"

PRELUDE = '''
SAO = SAO or {}
SAO.Log = { line = function() end, tally = function() end }
SAO.Identity = { get = function() return nil end, all = function() return {} end }
SAO.Hash = { of = function() return 0 end, unit = function() return 0.5 end }
SAO.Disposition = { traits = function() return {} end }
SAO.Lessons = { has = function() return false end, weight = function() return 0 end }
ModData = { getOrCreate = function(k) _G.__md = _G.__md or {} ; _G.__md[k] = _G.__md[k] or {} ; return _G.__md[k] end }
GameTime = { getInstance = function() return { getWorldAgeHours = function() return 100 end } end }
getGameTime = function() return GameTime.getInstance() end
ZombRand = function(n) return 0 end
'''

def method_body(src, name):
    """Return one Java method body by brace balance."""
    match = re.search(r"^\s{4}(?:public|private|protected)\s+.*?\b"
                      + re.escape(name) + r"\s*\([^)]*\)\s*\{", src,
                      re.M)
    if match is None:
        return ""
    start = match.end() - 1
    depth, at = 0, start
    while at < len(src):
        if src[at] == "{":
            depth += 1
        elif src[at] == "}":
            depth -= 1
            if depth == 0:
                return src[start:at]
        at += 1
    return ""


def source_faults(driver_src, needs_src, controller_src, standing_src):
    """Check the source seams that the VM cannot construct by itself."""
    faults = []
    board = method_body(driver_src, "boardAsDriver")
    appraisal = method_body(needs_src, "appraiseVehiclesNear")
    containers = method_body(needs_src, "vehicleContainersNear")
    larder = method_body(needs_src, "countEdibleNearby")
    cook = method_body(needs_src, "cookNearbyFood")
    nearest = method_body(needs_src, "nearestContainer")
    nearest_vehicle = method_body(needs_src, "nearestVehicleSource")
    refresh_vehicle = method_body(needs_src, "refreshVehicleSource")
    valid_source = method_body(needs_src, "validSource")
    source_reach = method_body(needs_src, "sourceWithinReach")
    drink_source = method_body(needs_src, "findDrinkSourceNear")
    drug_source = method_body(needs_src, "findDrugSourceNear")
    food_source = method_body(needs_src, "findFoodSourceNear")

    if not re.search(r"haveThisKeyId\(vehicle\.getKeyId\(\)\)"
                     r"[\s\S]{0,400}?haveKey\s*=\s*key\s*!=\s*null"
                     r"[\s\S]{0,400}?vehicle\.tryStartEngine\(haveKey\)",
                     board):
        faults.append("the driver does not pass the held-key answer to the "
                      "engine start")
    if "haveThisKeyId(vehicle.getKeyId())" not in appraisal:
        faults.append("the appraisal does not read the body's key")
    if "hasKey = 1" not in appraisal:
        faults.append("the appraisal does not mark a held key")
    if not re.search(r"\.append\(\"@\"\)\s*\.append\(hot\)\s*"
                     r"\.append\(\"@\"\)\s*\.append\(hasKey\)",
                     appraisal):
        faults.append("the appraisal does not carry the body's key after "
                      "the hotwire field")
    if not re.search(r"local\s+vn,\s+vs,\s+vf,\s+vfu,\s+ve,\s+vl,"
                     r"\s+vst,\s+vig,\s+vh,\s+vhk,\s+vd", controller_src):
        faults.append("the vehicle parser does not receive the held-key "
                      "field")
    if "key = tonumber(vhk)" not in controller_src:
        faults.append("the vehicle parser drops the held-key field")
    if "or (c.key or 0) == 1" not in standing_src:
        faults.append("the motor pool does not prefer the held-key vehicle")

    container_seams = (
        "if (cell == null) return found;", "cell.getVehicles()", "r2",
        "dx * dx + dy * dy > r2", "part.isContainer()",
        "part.getItemContainer()", "found.add(c)",
    )
    if not all(seam in containers for seam in container_seams):
        faults.append("vehicle containers are not limited to real parts "
                      "inside the requested radius")
    if "vehicle.canAccessContainer(i, shell)" not in containers:
        faults.append("larder/cooking inspection admits locked compartments")
    if "vehicle.canAccessContainer(i, shell)" not in nearest:
        faults.append("the store target admits a locked vehicle compartment")
    if "vehicle.canAccessContainer(i, shell)" not in nearest_vehicle:
        faults.append("a food/drink/drug search admits a locked compartment")
    remembered = ("source.vehicle = vehicle", "source.vehiclePartIndex = i")
    if not all(seam in nearest_vehicle for seam in remembered):
        faults.append("a vehicle source forgets the moving vehicle or part")
    refreshed = (
        "source.vehicle.getSquare()",
        "source.vehicle.isRemovedFromWorld()",
        "cell.getVehicles().contains(source.vehicle)",
        "part.getItemContainer() != source.container",
        "source.vehicle.canAccessContainer(index, shell)",
        "source.x = (int) source.vehicle.getX()",
        "source.y = (int) source.vehicle.getY()",
        "source.z = square.getZ()",
    )
    if not all(seam in refresh_vehicle for seam in refreshed):
        faults.append("vehicle source use does not prove loaded identity, access and position")
    if "refreshVehicleSource(shell, source)" not in valid_source:
        faults.append("cached source readers bypass vehicle revalidation")
    if "FoodSource source = validSource(shell);" not in source_reach:
        faults.append("the reach decision uses stale cached vehicle coordinates")
    if "(int) shell.getZ() != source.z" not in needs_src:
        faults.append("remembered material sources can transfer across floors")
    if "vehicleContainersNear(shell, radius)" not in larder:
        faults.append("the larder does not read vehicle containers")
    if "vehicleContainersNear(shell, radius)" not in cook:
        faults.append("the cook does not read vehicle containers")
    if "nearestVehicleSource(shell, radius" not in drink_source:
        faults.append("the drink source does not read vehicle containers")
    if "nearestVehicleSource(shell, radius" not in drug_source:
        faults.append("the dose source does not read vehicle containers")
    if "nearestVehicleSource(shell, radius" not in food_source:
        faults.append("the food source does not read vehicle containers")
    if not re.search(r"cell\.getVehicles\(\)[\s\S]{0,900}?"
                     r"part\.isContainer\(\)[\s\S]{0,300}?"
                     r"part\.getItemContainer\(\)", nearest):
        faults.append("the store reader does not read vehicle containers")
    return faults


def build_runner():
    """Build the engine's Lua runner when the engine is available."""
    cls = OUT / "LuaRun.class"
    if cls.exists() and cls.stat().st_mtime >= RUNNER.stat().st_mtime:
        return True
    OUT.mkdir(parents=True, exist_ok=True)
    done = subprocess.run(
        [str(JDK / "javac.exe"), "-cp", str(PZ), "-d", str(OUT),
         str(RUNNER)], capture_output=True, text=True, timeout=300)
    return done.returncode == 0


def probe(expr):
    """Run the real Standing module with the smallest truthful prelude."""
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(STDLIB, work / "stdlib.lua")
        for cls in OUT.glob("*.class"):
            shutil.copy2(cls, work / cls.name)
        prelude = work / "prelude.lua"
        prelude.write_text(PRELUDE, encoding="utf-8")
        done = subprocess.run(
            [str(JDK / "java.exe"), "-cp", f"{PZ};.", "LuaRun",
             str(prelude), str(LUA / "shared" / "SAO_History.lua"),
             str(STANDING), "--", expr], cwd=str(work),
            capture_output=True, text=True, timeout=900)
    if done.returncode != 0:
        return "ERROR " + (done.stderr or done.stdout or "runner failed").strip()
    values = re.findall(r"^VALUE\s+(.+)$", done.stdout or "", re.M)
    return "VALUE " + values[-1] if values else "ERROR runner gave no VALUE"


def keyed_pool():
    return '''(function()
local s = ModData.getOrCreate("SurvivorAwareness_Standing")
s.groupMeta = { h = { motorPool = { atHours = 100, cars = {
    { name = "LockedSix", seats = 6, free = 5, loud = 10, fuel = 60,
      engine = 90, ignition = 0, hotwired = 0, key = 0 },
    { name = "KeyTwo", seats = 2, free = 1, loud = 10, fuel = 60,
      engine = 90, ignition = 0, hotwired = 0, key = 1 }
} } } }
local c = SAO.Standing.roadworthy("h")
return tostring(c and c.name or "none") .. ":" .. tostring(c and c.open or false)
end)()'''


def main():
    print("=" * 74)
    print("VEHICLES HOLD KEYS AND CONTAINERS")
    print("=" * 74)
    paths = (DRIVER, NEEDS, CONTROLLER, STANDING)
    if not all(path.exists() for path in paths):
        print("  FAULT: a vehicle source surface is missing")
        return 1

    driver_src, needs_src, controller_src, standing_src = (
        path.read_text(encoding="utf-8", errors="ignore") for path in paths)
    faults = source_faults(driver_src, needs_src, controller_src, standing_src)

    bad_driver = driver_src.replace("vehicle.tryStartEngine(haveKey);",
                                    "vehicle.tryStartEngine(false);", 1)
    if bad_driver == driver_src:
        faults.append("CONTROL did not remove the held-key start")
    elif not source_faults(bad_driver, needs_src, controller_src, standing_src):
        faults.append("CONTROL held-key start removed but the border passed")

    bad_needs = needs_src.replace(
        "if (part == null || !part.isContainer()) continue;",
        "if (part == null) continue;", 3)
    if bad_needs == needs_src:
        faults.append("CONTROL did not remove the vehicle container guard")
    elif not source_faults(driver_src, bad_needs, controller_src, standing_src):
        faults.append("CONTROL vehicle container guard removed but the "
                      "border passed")

    bad_source = needs_src.replace(
        "FoodSource vehicle = nearestVehicleSource(shell, radius,\n"
        "                item -> edible(item));",
        "FoodSource vehicle = null;", 1)
    if bad_source == needs_src:
        faults.append("CONTROL did not remove the food vehicle source")
    elif not source_faults(driver_src, bad_source, controller_src, standing_src):
        faults.append("CONTROL food vehicle source removed but the border "
                      "passed")

    bad_access = needs_src.replace(
        "                    if (!vehicle.canAccessContainer(i, shell)) continue;\n",
        "", 3)
    if bad_access == needs_src:
        faults.append("CONTROL did not remove vehicle access checks")
    elif not source_faults(driver_src, bad_access, controller_src, standing_src):
        faults.append("CONTROL removed vehicle access checks but the border passed")

    bad_refresh = needs_src.replace(
        "            FoodSource source = validSource(shell);\n"
        "            if (source == null) {",
        "            FoodSource source = SOURCES.get(shell);\n"
        "            if (source == null) {", 1)
    if bad_refresh == needs_src:
        faults.append("CONTROL did not bypass source reach revalidation")
    elif not source_faults(driver_src, bad_refresh, controller_src, standing_src):
        faults.append("CONTROL bypassed source reach revalidation but the border passed")

    bad_loaded = needs_src.replace(
        "                || source.vehicle.isRemovedFromWorld()\n"
        "                || !cell.getVehicles().contains(source.vehicle)",
        "", 1)
    if bad_loaded == needs_src:
        faults.append("CONTROL did not remove loaded vehicle membership")
    elif not source_faults(driver_src, bad_loaded, controller_src, standing_src):
        faults.append("CONTROL removed loaded vehicle membership but the border passed")

    bad_floor = needs_src.replace(
        " || (int) shell.getZ() != source.z", "", 1)
    if bad_floor == needs_src:
        faults.append("CONTROL did not remove source floor grounding")
    elif not source_faults(driver_src, bad_floor, controller_src, standing_src):
        faults.append("CONTROL removed source floor grounding but the border passed")

    print("  source seams: " + ("ok" if not faults else "FAULT"))
    required = (JDK.exists() and PZ.exists() and STDLIB.exists()
                and RUNNER.exists())
    if not required:
        print("  SKIPPED - no JDK, engine jar, stdlib or Lua runner")
    elif not build_runner():
        faults.append("the engine Lua runner does not compile")
    else:
        answer = probe(keyed_pool())
        print("  keyed smaller runner: " + answer)
        if answer != "VALUE KeyTwo:true":
            faults.append("a held-key runner did not outrank a larger "
                          "locked vehicle (got %s)" % answer)

    print()
    print("VERDICT:")
    if faults:
        for fault in faults:
            print("  FAULT: " + fault)
        return 1
    print("  154) vehicles: held keys reach the lawful start and pool; "
          "accessible, current vehicle parts are food, cooking and store ground")
    return 0


if __name__ == "__main__":
    sys.exit(main())
