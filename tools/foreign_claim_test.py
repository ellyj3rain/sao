#!/usr/bin/env python3
r"""Border 145 - another mod's name is not a condition in this one.

The county held one fact as `rec.knox`, a boolean named after a single
mod, and read it in twenty-four places to decide four different things:
never conjure a body for them, never walk them on the dormant day,
never let attrition take them, and presume their occupation rather than
asserting it.

None of those is a question about Knox Survivors. Every one is the same
question - is somebody else driving this body - and writing it as a
mod's name put that mod into the logic of a project whose rule is that
a mod is never named in logic (DR-035). The next population framework
would have wanted a second boolean and twenty-four more branches.

WHAT THIS HOLDS.

**The property answers, and the flag is gone.** `SAO.Claims.heldBy`
returns a holder for a record claimed after `[C81]` and for a legacy
record carrying only the old boolean, and neither `rec.knox` nor
`Body.knox` survives anywhere outside the module that reads the old
form.

**A holder's name appears only where it is integrated.** Each foreign
identifier below is allowed in the files that exist to talk to that
mod, and nowhere else. A name that spreads past its integration is the
defect this batch removed, coming back.

A legacy save is not rewritten. The old boolean still answers the new
question, which is checked here, because tidying a field name in
somebody's save is a judgement about their save.

ITS CONTROL is any tree before this batch, where `rec.knox` is read in
two dozen branches across seven files and the name is the condition.
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
SRC = HERE / "luacheck" / "LuaRun.java"
OUT = ROOT / "java" / "out" / "luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"

MODULES = ["shared/SAO_Log.lua", "shared/SAO_Claims.lua"]

# A foreign mod's identifiers, and the files that exist to talk to it.
# A name outside its own integration is the finding.
INTEGRATIONS = {
    "KnoxSurvivors": {
        "client/SAO_Absorb.lua":
            "the absorption itself - his people become the county's "
            "through his own teardown functions",
        "client/SAO_Neighbours.lua":
            "his menu, superimposed (DR-015), which means reaching his "
            "own globals by name",
        "client/SAO_Harness.lua":
            "his world ModData table, read for the county's own panel",
        "client/SAO_Population.lua":
            "the passive adoption pass, which reads his live actors",
        "client/SAO_Sandbox.lua":
            "two of HIS sandbox rows removed from the settings screen, "
            "because absorbing his people makes those dials mean "
            "nothing. The name here is a settings key, which is data",
        "shared/SAO_Claims.lua":
            "the holder constant, named once so nothing else has to",
    },
}

# The flag itself, which must not survive outside the module that reads
# the legacy form of it.
RETIRED = {
    r"\brec\.knox\b": "shared/SAO_Claims.lua",
    r"\bBody\.knox\b": None,
    r"\bknoxCount\b": None,
}

PRELUDE = "SAO = SAO or {}\n"


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
        args = [str(JDK / "java.exe"), "-cp", "%s;." % PZ, "LuaRun",
                str(prelude)]
        args += [str(LUA / m) for m in MODULES if (LUA / m).exists()]
        args += ["--", expr]
        done = subprocess.run(args, cwd=str(work), capture_output=True,
                              text=True, timeout=900)
    out = done.stdout or ""
    at = out.find("VALUE ")
    if at < 0:
        return "ERROR " + (out + (done.stderr or "")).strip()[-400:]
    return out[at + 6:].strip().split("\n")[0]


def strip_prose(text):
    """Lua with its comments removed.

    Every file below explains in prose why the name left its logic, so
    a bare search finds the very thing it is checking has gone. That is
    GOVERNANCE's prose-is-not-code clause, and it has caught borders in
    this tree twice.
    """
    out = []
    for line in text.splitlines():
        cut = line.find("--")
        out.append(line if cut < 0 else line[:cut])
    return "\n".join(out)


def lua_files():
    for p in sorted(LUA.rglob("*.lua")):
        yield p.relative_to(LUA).as_posix(), \
            strip_prose(p.read_text(encoding="utf-8", errors="ignore"))


def main():
    faults = []
    print("=" * 74)
    print("ANOTHER MOD'S NAME IS NOT A CONDITION IN THIS ONE")
    print("=" * 74)

    if not (LUA / "shared" / "SAO_Claims.lua").exists():
        print("  145) the claim is a property: CONTROL")
        print("  CONTROL: SAO_Claims.lua is absent. On this tree the fact")
        print("  is `rec.knox`, a boolean named after one mod, read in two")
        print("  dozen branches across seven files - and the name IS the")
        print("  condition.")
        return 1

    # 1. The retired spellings are gone.
    for pattern, allowed in RETIRED.items():
        hits = []
        for rel, body in lua_files():
            if allowed and rel == allowed:
                continue
            if re.search(pattern, body):
                hits.append(rel)
        label = pattern.replace(r"\b", "").replace("\\", "")
        if hits:
            print("  FAULT: %s survives in %s" % (label, ", ".join(hits)))
            faults.append("retired")
        else:
            print("  %-16s retired everywhere it was a condition : yes"
                  % label)

    # 2. A holder's name stays inside its own integration.
    for name, allowed in INTEGRATIONS.items():
        # A declaration that no longer describes anything is a claim
        # about a world that does not exist, so it fails here the way
        # save_compat's accepted drops do.
        for rel in sorted(allowed):
            if not (LUA / rel).exists():
                print("  FAULT: %s is declared to integrate with %s and "
                      "does not exist" % (rel, name))
                faults.append("stale")
        stray = []
        for rel, body in lua_files():
            if rel in allowed:
                continue
            if re.search(r"\b%s\b" % re.escape(name), body):
                stray.append(rel)
        if stray:
            print("  FAULT: %s is named in %s, which does not integrate "
                  "with it" % (name, ", ".join(stray)))
            faults.append("spread")
        else:
            print("  %-16s named only where it is integrated     : yes"
                  % name)

    # 3. And the property actually answers, for both shapes of record.
    if not (JDK.exists() and PZ.exists() and STDLIB.exists()
            and SRC.exists()):
        print("  SKIPPED the VM - no JDK, engine jar, stdlib or runner")
        print("  145) the claim is a property: TEXT ONLY, the engine "
              "install is absent")
        return 1 if faults else 0

    if not build():
        print("  FAULT: LuaRun does not compile against the installed jar")
        return 1

    line = probe(
        '(function()'
        ' local legacy = { knox = true }'
        ' local fresh = {}'
        ' SAO.Claims.claim(fresh, SAO.Claims.KNOX_SURVIVORS)'
        ' local ours = {}'
        ' local released = { knox = true }'
        ' SAO.Claims.release(released)'
        ' return "legacy=" .. (SAO.Claims.isHeld(legacy) and 1 or 0)'
        ' .. " fresh=" .. (SAO.Claims.isHeld(fresh) and 1 or 0)'
        ' .. " ours=" .. (SAO.Claims.isHeld(ours) and 1 or 0)'
        ' .. " released=" .. (SAO.Claims.isHeld(released) and 1 or 0)'
        ' .. " untouched=" .. (legacy.heldBy == nil and 1 or 0)'
        ' end)()')
    n = {k: int(v) for k, v in re.findall(r"(\w+)=(\d)", line or "")}
    if len(n) == 5:
        print("  a record carrying only the old flag reads as held : %s"
              % ("yes" if n["legacy"] else "NO"))
        print("  one claimed through the property does too         : %s"
              % ("yes" if n["fresh"] else "NO"))
        print("  one nobody holds does not                         : %s"
              % ("yes" if not n["ours"] else "NO"))
        print("  a released body comes back to the county          : %s"
              % ("yes" if not n["released"] else "NO"))
        print("  and reading a legacy record does not rewrite it   : %s"
              % ("yes" if n["untouched"] else "NO"))
        if not (n["legacy"] and n["fresh"]) or n["ours"] or n["released"] \
                or not n["untouched"]:
            print("  FAULT: the property does not answer for every shape of")
            print("  record, so a live save loses people or gains them.")
            faults.append("property")
    else:
        print("    " + str(line)[:200])
        faults.append("property")

    print("-" * 74)
    if faults:
        print("  145) another mod's name is not a condition: FAIL")
        print("REFUSED: " + ", ".join(sorted(set(faults))))
        return 1
    print("  145) the claim is a property, the holder is data, and a "
          "legacy save still answers")
    print("MATCH: no mod is named in this one's logic.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
