#!/usr/bin/env python3
r"""Border 149 - the isolation state is live, read-only, and visible.

The first category from the dependency substrate is isolation. This border
holds the state surface rather than a spelling:

  * it reports the live social-contact spectrum, not a fixed label;
  * it separates appetite for company from actual isolation;
  * it reads only existing identity, perception, standing, disposition and
    history facts;
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
MODULE = LUA / "shared" / "SAO_Isolation.lua"
STANDING = LUA / "shared" / "SAO_Standing.lua"
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
    alone = { id = "alone", dead = false },
    loner = { id = "loner", dead = false },
    house = { id = "house", dead = false },
    grouped = { id = "grouped", dead = false },
    social = { id = "social", dead = false },
    other = { id = "other", dead = false },
    dead = { id = "dead", dead = true },
}

SAO.Identity = {
    get = function(id) return records[tostring(id)] end,
}

SAO.History = {
    contactFactor = function(id)
        if id == "loner" then return 0.10 end
        if id == "house" then return 0.90 end
        if id == "social" then return 0.80 end
        return 0.50
    end,
    countyHours = function() return 100 end,
}

SAO.Disposition = {
    circle = function(id)
        if id == "loner" then return "loner" end
        return "house"
    end,
    circleCap = function(id)
        if id == "loner" then return 1 end
        return 999
    end,
}

local groups = { grouped = "g", social = "g" }
local fellows = {
    grouped = { "other" },
    social = { "other" },
}
local relations = {
    social = {
        other = { trust = 0.80, atHours = 90 },
    },
}

SAO.Standing = {
    groupOf = function(id) return groups[tostring(id)] end,
    fellowsOf = function(id) return fellows[tostring(id)] or {} end,
    relationsOf = function(id) return relations[tostring(id)] or {} end,
}

SAO.Perception = {
    beliefs = {
        social = {
            people = {
                other = {
                    id = "other", x = 1, y = 1,
                    at = 100, atHours = 90,
                    source = "observed",
                },
            },
        },
    },
}

SandboxVars = {
    SurvivorAwareness = { TrustToCompany = 0.50 },
}

function ISO(id)
    local s = SAO.Isolation.of(id)
    if not s then return "none" end
    return "group=" .. tostring(s.groupSize)
        .. " known=" .. tostring(s.knownPeople)
        .. " trusted=" .. tostring(s.trustedPeople)
        .. " recent=" .. tostring(s.recentPeople)
        .. " contact=" .. string.format("%.3f", s.contact)
        .. " isolation=" .. string.format("%.3f", s.isolation)
        .. " appetite=" .. string.format("%.3f", s.appetite)
        .. " since=" .. tostring(s.hoursSinceContact)
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


def values(line):
    return {k: v for k, v in re.findall(
        r"(group|known|trusted|recent|contact|isolation|appetite|since)"
        r"=([^ ]+)", line)}


def main():
    faults = []
    print("=" * 74)
    print("THE ISOLATION STATE IS LIVE, READ-ONLY, AND VISIBLE")
    print("=" * 74)

    if not MODULE.exists():
        print()
        print("VERDICT:")
        print("  FAULT: SAO_Isolation.lua does not exist - isolation is")
        print("  still a static contact factor rather than a live state")
        return 1

    text = MODULE.read_text(encoding="utf-8", errors="ignore")
    code = "\n".join(
        line[:line.find("--")] if line.find("--") >= 0 else line
        for line in text.split("\n"))
    for banned, why in (
            ("ModData", "opens a save store"),
            ("adjustTrust", "writes standing"),
            ("setHostile", "writes standing"),
            ("formCompany", "writes a group"),
            ("joinGroup", "writes a group"),
            ("sawPerson", "writes a belief"),
            ("markDead", "writes a record"),
            ("Identity.create", "creates a person"),
            ("Identity.ensure", "creates a person")):
        if banned in code:
            faults.append(f"the isolation module touches {banned} - {why}")
    if re.search(r"\b(SAO\.[A-Za-z]+)\.[A-Za-z0-9_]+\s*=", code):
        faults.append("the isolation module assigns another module's state")

    standing = STANDING.read_text(encoding="utf-8", errors="ignore") \
        if STANDING.exists() else ""
    if "function S.relationsOf" not in standing:
        faults.append("Standing does not expose relation rows, so isolation")
        faults.append("cannot count trusted people without walking the")
        faults.append("whole county")

    inspect = INSPECT.read_text(encoding="utf-8", errors="ignore") \
        if INSPECT.exists() else ""
    if "SAO.Isolation.of" not in inspect:
        faults.append("the inspect panel does not read the isolation state")
    for field in ("jsonl.isolationContact", "jsonl.isolationAppetite",
                  "jsonl.isolationGroupSize", "jsonl.isolationKnownPeople",
                  "jsonl.isolationRecentPeople",
                  "jsonl.isolationTrustedPeople",
                  "jsonl.isolationHoursSinceContact"):
        if field not in inspect:
            faults.append(f"the inspect JSONL omits {field}")

    if not (JDK.exists() and PZ.exists() and STDLIB.exists()
            and SRC.exists()):
        print("  probes: SKIPPED - no JDK, engine jar, stdlib or runner")
    elif not build():
        faults.append("LuaRun does not compile against the installed jar")
    else:
        cases = [
            ("a solitary person",
             'ISO("alone")',
             "group=0 known=0 trusted=0 recent=0 contact=0.000"
             " isolation=1.000 appetite=0.500 since=nil"),
            ("a grouped person",
             'ISO("grouped")',
             "group=2 known=0 trusted=0 recent=0 contact=0.667"
             " isolation=0.333 appetite=0.500 since=0"),
            ("a saturated social person",
             'ISO("social")',
             "group=2 known=1 trusted=1 recent=1 contact=1.000"
             " isolation=0.000 appetite=0.800 since=0"),
            ("a dead person answers nothing",
             'ISO("dead")',
             "none"),
            ("appetite is separate from isolation",
             'ISO("loner") .. "|" .. ISO("house")',
             "group=0 known=0 trusted=0 recent=0 contact=0.000"
             " isolation=1.000 appetite=0.100 since=nil|"
             "group=0 known=0 trusted=0 recent=0 contact=0.000"
             " isolation=1.000 appetite=0.900 since=nil"),
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
        print("  149) the isolation state: FAIL")
        return 1
    print("  149) the isolation state: live, read-only, and visible")
    return 0


if __name__ == "__main__":
    sys.exit(main())
