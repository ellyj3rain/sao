#!/usr/bin/env python3
r"""Border 150 - the place-attachment state is live, read-only, and visible.

The second category from the dependency substrate is place attachment. This
border holds the state surface rather than a spelling:

  * it reports home, current building, known places, visited places, claims,
    and the most-returned-to place;
  * it separates the four underlying facts from the coarse attachment
    summary;
  * it reads only existing identity, perception, place and standing facts;
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
MODULE = LUA / "shared" / "SAO_PlaceAttachment.lua"
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
    homed = { id = "homed", dead = false, x = 100, y = 100,
             homeX = 100, homeY = 100 },
    grounded = { id = "grounded", dead = false, x = 100, y = 100,
                 homeX = 100, homeY = 100 },
    settled = { id = "settled", dead = false, x = 100, y = 100,
                homeX = 100, homeY = 100 },
    dead = { id = "dead", dead = true },
}

SAO.Identity = {
    get = function(id) return records[tostring(id)] end,
}

local known = {
    rootless = {},
    homed = {},
    grounded = {
        ["1"] = { visits = 0, at = 20, offers = { food = true } },
    },
    settled = {
        ["1"] = { visits = 4, at = 20, offers = { food = true, water = true } },
        ["2"] = { visits = 2, at = 40, offers = {} },
    },
}

SAO.Perception = {
    knownPlaces = function(id) return known[tostring(id)] or {} end,
}

SAO.Places = {
    at = function(x, y)
        if x == 100 and y == 100 then return { id = 1 } end
        return nil
    end,
}

local personalClaims = { grounded = true }
local groups = { grounded = "g", settled = "g" }
local groupClaims = { g = true }

SAO.Standing = {
    claimOf = function(id) return personalClaims[tostring(id)] end,
    groupOf = function(id) return groups[tostring(id)] end,
    groupClaimOf = function(group) return groupClaims[tostring(group)] end,
    insideClaim = function(id, x, y)
        return personalClaims[tostring(id)]
            or groupClaims[groups[tostring(id)] or ""]
    end,
}

SAO.Controller = {
    tick = function() return 100 end,
}

function PA(id)
    local s = SAO.PlaceAttachment.of(id)
    if not s then return "none" end
    return "home=" .. (s.home and 1 or 0)
        .. " known=" .. s.knownPlaces
        .. " visited=" .. s.visitedPlaces
        .. " claim=" .. s.claimKind
        .. " inside=" .. (s.insideClaim and 1 or 0)
        .. " homeId=" .. tostring(s.homePlaceId)
        .. " currentId=" .. tostring(s.currentPlaceId)
        .. " most=" .. tostring(s.mostVisitedPlaceId)
        .. "x" .. tostring(s.mostVisitedPlaceVisits)
        .. " age=" .. tostring(s.mostVisitedPlaceAge)
        .. " attachment=" .. string.format("%.2f", s.attachment)
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
    print("THE PLACE-ATTACHMENT STATE IS LIVE, READ-ONLY, AND VISIBLE")
    print("=" * 74)

    if not MODULE.exists():
        print()
        print("VERDICT:")
        print("  FAULT: SAO_PlaceAttachment.lua does not exist - place")
        print("  attachment is still scattered facts rather than one state")
        return 1

    text = MODULE.read_text(encoding="utf-8", errors="ignore")
    code = "\n".join(
        line[:line.find("--")] if line.find("--") >= 0 else line
        for line in text.split("\n"))
    for banned, why in (
            ("ModData", "opens a save store"),
            ("learnBuilding", "writes a place belief"),
            ("setClaim", "writes a claim"),
            ("setGroupClaim", "writes a group claim"),
            ("take(", "spends a place"),
            ("Identity.create", "creates a person"),
            ("Identity.ensure", "creates a person")):
        if banned in code:
            faults.append(f"the place-attachment module touches {banned} - {why}")
    if re.search(r"\b(SAO\.[A-Za-z]+)\.[A-Za-z0-9_]+\s*=", code):
        faults.append("the place-attachment module assigns another module's state")

    inspect = INSPECT.read_text(encoding="utf-8", errors="ignore") \
        if INSPECT.exists() else ""
    if "SAO.PlaceAttachment.of" not in inspect:
        faults.append("the inspect panel does not read place attachment")
    for field in ("jsonl.placeAttachmentHome",
                  "jsonl.placeAttachmentHomeKnown",
                  "jsonl.placeAttachmentHomeVisits",
                  "jsonl.placeAttachmentHomeOffers",
                  "jsonl.placeAttachmentHomeDistance",
                  "jsonl.placeAttachmentClaimKind",
                  "jsonl.placeAttachmentInsideClaim",
                  "jsonl.placeAttachmentKnownPlaces",
                  "jsonl.placeAttachmentVisitedPlaces",
                  "jsonl.placeAttachmentMostVisitedId",
                  "jsonl.placeAttachmentMostVisitedVisits",
                  "jsonl.placeAttachmentMostVisitedAge",
                  "jsonl.placeAttachment"):
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
             'PA("rootless")',
             "home=0 known=0 visited=0 claim=none inside=0 homeId=nil"
             " currentId=nil most=nilx0 age=nil attachment=0.00"),
            ("a homed person",
             'PA("homed")',
             "home=1 known=0 visited=0 claim=none inside=0 homeId=1"
             " currentId=1 most=nilx0 age=nil attachment=0.25"),
            ("a grounded person",
             'PA("grounded")',
             "home=1 known=1 visited=0 claim=personal inside=1 homeId=1"
             " currentId=1 most=nilx0 age=nil attachment=0.75"),
            ("a settled person",
             'PA("settled")',
             "home=1 known=2 visited=2 claim=group inside=1 homeId=1"
             " currentId=1 most=1x4 age=80 attachment=1.00"),
            ("a dead person answers nothing",
             'PA("dead")',
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
        print("  150) the place-attachment state: FAIL")
        return 1
    print("  150) the place-attachment state: live, read-only, and visible")
    return 0


if __name__ == "__main__":
    sys.exit(main())
