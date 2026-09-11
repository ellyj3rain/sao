#!/usr/bin/env python3
r"""Border 151 - the world-development state is live, read-only, and visible.

The third category from the dependency substrate is world development. This
border holds the state surface rather than a spelling:

  * it reports home, ground, larder, water, hearth, motor pool and
    fortification together;
  * it separates the seven underlying facts from the coarse development
    summary;
  * it reads only existing identity, place-attachment and standing facts;
  * it writes nothing;
  * the inspect panel exposes it to the operator and the JSONL stream.

An optional argv[1] points the checker at another tree root, which is how the
control runs against the pre-batch tree.
"""
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
HERE = pathlib.Path(__file__).resolve().parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
MODULE = LUA / "shared" / "SAO_WorldDevelopment.lua"
INSPECT = LUA / "client" / "SAO_Inspect.lua"
SRC = HERE / "luacheck" / "LuaRun.java"
OUT = ROOT / "java" / "out" / "luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"

PRELUDE = r'''
SAO = SAO or {}

local records = {
    rootless = { id = "rootless", dead = false },
    homed = { id = "homed", dead = false },
    stocked = { id = "stocked", dead = false },
    developed = { id = "developed", dead = false,
                  waysIntoHome = 4, boardedAtHome = 3 },
    dead = { id = "dead", dead = true },
}

SAO.Identity = {
    get = function(id) return records[tostring(id)] end,
}

local attachments = {
    rootless = {
        home = false, claimKind = "none", homePlaceId = nil,
        homeDistance = nil, homeKnown = false, homeVisits = 0,
        homeOffers = 0, knownPlaces = 0, visitedPlaces = 0,
    },
    homed = {
        home = true, claimKind = "none", homePlaceId = 1,
        homeDistance = 0, homeKnown = true, homeVisits = 1,
        homeOffers = 2, knownPlaces = 1, visitedPlaces = 1,
    },
    stocked = {
        home = true, claimKind = "group", homePlaceId = 1,
        homeDistance = 0, homeKnown = true, homeVisits = 4,
        homeOffers = 3, knownPlaces = 3, visitedPlaces = 2,
    },
    developed = {
        home = true, claimKind = "group", homePlaceId = 1,
        homeDistance = 0, homeKnown = true, homeVisits = 9,
        homeOffers = 4, knownPlaces = 5, visitedPlaces = 4,
    },
}

SAO.PlaceAttachment = {
    of = function(id) return attachments[tostring(id)] end,
}

local groups = { stocked = "g", developed = "g" }
local groupMeta = {
    g = {
        larder = { word = "full", count = 12 },
        water = { word = "wet", units = 8 },
        hearth = { burning = true },
        motorPool = { cars = { {}, {} } },
    },
}

SAO.Standing = {
    groupOf = function(id) return groups[tostring(id)] end,
    larderOf = function(g)
        return groupMeta[g] and groupMeta[g].larder or nil
    end,
    waterStoreOf = function(g)
        return groupMeta[g] and groupMeta[g].water or nil
    end,
    hearthOf = function(g)
        return groupMeta[g] and groupMeta[g].hearth or nil
    end,
    motorPoolOf = function(g)
        return groupMeta[g] and groupMeta[g].motorPool or nil
    end,
}

function WD(id)
    local s = SAO.WorldDevelopment.of(id)
    if not s then return "none" end
    return "group=" .. tostring(s.group)
        .. " home=" .. (s.home and 1 or 0)
        .. " ground=" .. (s.ground and 1 or 0)
        .. " larder=" .. (s.larder and 1 or 0)
        .. " water=" .. (s.water and 1 or 0)
        .. " hearth=" .. (s.hearth and 1 or 0)
        .. " cars=" .. s.motorCars
        .. " shut=" .. s.boardedAtHome .. "/" .. s.waysIntoHome
        .. " development=" .. string.format("%.2f", s.development)
end
'''


def build():
    cls = OUT / "LuaRun.class"
    if cls.exists() and cls.stat().st_mtime >= SRC.stat().st_mtime:
        return True
    OUT.mkdir(parents=True, exist_ok=True)
    done = subprocess.run(
        [str(JDK / "javac.exe"), "-cp", str(PZ), "-d", str(OUT), str(SRC)],
        capture_output=True, text=True, timeout=300)
    return done.returncode == 0


def probe(expr):
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(STDLIB, work / "stdlib.lua")
        for c in OUT.glob("*.class"):
            shutil.copy2(c, work / c.name)
        prelude = work / "prelude.lua"
        prelude.write_text(PRELUDE, encoding="utf-8")
        args = [str(JDK / "java.exe"), "-cp", f"{PZ};.", "LuaRun",
                str(prelude), str(LUA / "shared" / "SAO_Log.lua"),
                str(MODULE), "--", expr]
        done = subprocess.run(args, cwd=str(work), capture_output=True,
                              text=True, timeout=120)
    out = done.stdout or ""
    at = out.find("VALUE ")
    if at < 0:
        return "ERROR " + (out + (done.stderr or "")).strip()[-500:]
    return out[at + 6:].strip().split("\n")[0]


def main():
    faults = []
    print("=" * 74)
    print("THE WORLD-DEVELOPMENT STATE IS LIVE, READ-ONLY, AND VISIBLE")
    print("=" * 74)

    if not MODULE.exists():
        print()
        print("VERDICT:")
        print("  FAULT: SAO_WorldDevelopment.lua does not exist - world")
        print("  development is still scattered facts rather than one state")
        return 1

    text = MODULE.read_text(encoding="utf-8", errors="ignore")
    code = "\n".join(
        line[:line.find("--")] if line.find("--") >= 0 else line
        for line in text.split("\n"))
    for banned, why in (
            ("ModData", "opens a save store"),
            ("setLarder", "stocks a larder"),
            ("setWaterStore", "stocks water"),
            ("setHearth", "lights a hearth"),
            ("setMotorPool", "writes a motor pool"),
            ("setGroupClaim", "writes a claim"),
            ("boardWindow", "boards a window"),
            ("Identity.create", "creates a person"),
            ("Identity.ensure", "creates a person")):
        if banned in code:
            faults.append(f"the world-development module touches {banned} - {why}")
    if re.search(r"\b(SAO\.[A-Za-z]+)\.[A-Za-z0-9_]+\s*=", code):
        faults.append("the world-development module assigns another module's state")

    inspect = INSPECT.read_text(encoding="utf-8", errors="ignore") \
        if INSPECT.exists() else ""
    if "SAO.WorldDevelopment.of" not in inspect:
        faults.append("the inspect panel does not read world development")
    for field in ("jsonl.worldDevelopment",
                  "jsonl.worldDevelopmentGroup",
                  "jsonl.worldDevelopmentHome",
                  "jsonl.worldDevelopmentGround",
                  "jsonl.worldDevelopmentLarder",
                  "jsonl.worldDevelopmentLarderWord",
                  "jsonl.worldDevelopmentLarderCount",
                  "jsonl.worldDevelopmentWater",
                  "jsonl.worldDevelopmentWaterWord",
                  "jsonl.worldDevelopmentWaterUnits",
                  "jsonl.worldDevelopmentHearth",
                  "jsonl.worldDevelopmentHearthBurning",
                  "jsonl.worldDevelopmentMotorPool",
                  "jsonl.worldDevelopmentMotorCars",
                  "jsonl.worldDevelopmentWaysIntoHome",
                  "jsonl.worldDevelopmentBoardedAtHome",
                  "jsonl.worldDevelopmentFortified"):
        if field not in inspect:
            faults.append(f"the inspect JSONL omits {field}")

    if not (JDK.exists() and PZ.exists() and STDLIB.exists()
            and SRC.exists()):
        print("  probes: SKIPPED - no JDK, engine jar, stdlib or runner")
    elif not build():
        faults.append("LuaRun does not compile against the installed jar")
    else:
        cases = [
            ("a rootless person",
             'WD("rootless")',
             "group=nil home=0 ground=0 larder=0 water=0 hearth=0 cars=0"
             " shut=0/0 development=0.00"),
            ("a homed person",
             'WD("homed")',
             "group=nil home=1 ground=0 larder=0 water=0 hearth=0 cars=0"
             " shut=0/0 development=0.14"),
            ("a stocked person",
             'WD("stocked")',
             "group=g home=1 ground=1 larder=1 water=1 hearth=1 cars=2"
             " shut=0/0 development=0.86"),
            ("a developed person",
             'WD("developed")',
             "group=g home=1 ground=1 larder=1 water=1 hearth=1 cars=2"
             " shut=3/4 development=1.00"),
            ("a dead person answers nothing",
             'WD("dead")',
             "none"),
        ]
        for name, expr, want in cases:
            got = probe(expr)
            ok = got == want
            print(f"  {'yes' if ok else 'NO '}  {name}")
            if not ok:
                faults.append(f"{name}: got `{got}` (wanted `{want}`)")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print("  FAULT: " + f)
        print("  151) the world-development state: FAIL")
        return 1
    print("  151) the world-development state: live, read-only, and visible")
    return 0


if __name__ == "__main__":
    sys.exit(main())
