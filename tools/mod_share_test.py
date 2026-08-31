#!/usr/bin/env python3
r"""Border 66 - the county's composition is ours, not the mod list's.

[B38] found that every life a profession mod adds arrived at its
bucket's flat rate and was simply appended, so the share of the county
made of lives the base table does not know grew with the number of mods
installed. Its fix holds the whole block to `MOD_SHARE`.

Nobody had ever measured whether it does.

Driven in a real Kahlua VM, with the bridge stubbed to report N
registered professions and everything downstream real:

     31 lives -> 1178      (the operator's own load order)
    200 lives -> 1200
   1200 lives -> 1200
   2000 lives -> 2000

The last line is the interesting one, and it is why this border exists
rather than a comment. The scale floors each weight and then lifts it
to at least 1 - **deliberately**, because a life the county can never
produce is worse than a rare one and rounding must not delete
somebody's mod. So once there are more mod-added lives than
`MOD_SHARE`, every one of them is already at the floor and the block is
exactly their count.

The code is right. The comment beside it said the block was held
"however many mods are installed", and that is the [B40] shape once
more: a claim the code only happens to satisfy, up to a boundary
nobody had gone looking for.

WHAT IS CHECKED
---------------
1. **The base table is untouched.** Whatever mods do, the 46 base rows
   still sum to exactly 10000 - the composition of Knox County is not
   a function of somebody's subscriptions.
2. **The cap holds where it can.** Between a handful of mods and
   `MOD_SHARE` of them, the block never exceeds `MOD_SHARE`.
3. **The floor wins where it must.** Past `MOD_SHARE` lives, the block
   equals their count and no profession has been deleted.
4. **The catalog survives past this engine's sort.** Kahlua's
   `table.sort` handles a thousand entries and throws on fifteen
   hundred - not a JVM stack limit, `-Xss16m` does not move it, so the
   game would hit it too. `catalog()` runs during genesis inside a
   pcall, and the failure would be a county that quietly has no
   occupations. Past `SORT_CEILING` the sort is skipped and the
   bridge's own order stands.

Four counts, one run each. SKIPs without the engine; FAULTs without
the modules, which is Border 54's lesson.
"""
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
CENSUS = LUA / "shared" / "SAO_Census.lua"
CHECK = ROOT / "tools" / "luacheck"
PROBE = CHECK / "probe_census.lua"
SRC = CHECK / "LuaRun.java"
OUT = ROOT / "java" / "out" / "luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"

MODULES = ("shared/SAO_Log.lua", "shared/SAO_Hash.lua",
           "shared/SAO_Census.lua")
BASE_TOTAL = 10000


def declared_share():
    m = re.search(r"^local MOD_SHARE = (\d+)",
                  CENSUS.read_text(encoding="utf-8", errors="ignore"), re.M)
    return int(m.group(1)) if m else None


def build():
    cls = OUT / "LuaRun.class"
    if cls.exists() and cls.stat().st_mtime >= SRC.stat().st_mtime:
        return True
    OUT.mkdir(parents=True, exist_ok=True)
    return subprocess.run(
        [str(JDK / "javac.exe"), "-cp", str(PZ), "-d", str(OUT), str(SRC)],
        capture_output=True, text=True, timeout=300).returncode == 0


def ask(n):
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(STDLIB, work / "stdlib.lua")
        for c in OUT.glob("*.class"):
            shutil.copy2(c, work / c.name)
        args = [str(JDK / "java.exe"), "-cp", f"{PZ};.", "LuaRun"]
        args += [str(LUA / m) for m in MODULES]
        args += [str(PROBE), "--", f"PROBE_MODSHARE({n})"]
        done = subprocess.run(args, cwd=str(work), capture_output=True,
                              text=True, timeout=600)
    for line in reversed((done.stdout or "").strip().split("\n")):
        if line.startswith("VALUE "):
            bits = line[6:].split()
            if len(bits) == 3:
                return tuple(int(b) for b in bits), None
    return None, ((done.stdout or "") + (done.stderr or "")).strip()[:200]


def main():
    faults = []
    print("=" * 74)
    print("THE COUNTY'S COMPOSITION IS OURS")
    print("=" * 74)

    if not (JDK.exists() and PZ.exists() and STDLIB.exists()
            and SRC.exists()):
        print("  SKIPPED - no JDK, engine jar, stdlib.lua or runner")
        print("  66) mod share: SKIPPED, engine absent")
        return 0
    missing = [m for m in MODULES if not (LUA / m).exists()]
    if missing or not PROBE.exists():
        print()
        print("VERDICT:")
        print("  FAULT: " + ", ".join(missing + ([PROBE.name] if not
              PROBE.exists() else [])) + " missing, so no county was built")
        return 1
    if not build():
        print()
        print("VERDICT:")
        print("  FAULT: the VM runner will not compile, so nothing ran on "
              "the engine")
        return 1

    share = declared_share()
    if not share:
        print()
        print("VERDICT:")
        print("  FAULT: MOD_SHARE is gone from SAO_Census.lua, so the block "
              "of mod-added lives is bounded by nothing and the county's "
              "composition is once again a fact about a load order")
        return 1
    print(f"  MOD_SHARE declared: {share}")

    # 1500 is past what this engine's table.sort survives unguarded -
    # it is in the list so the guard is exercised every run rather than
    # trusted.
    for n, rule in ((200, "capped"), (share, "capped"),
                    (1500, "floor"), (share * 2, "floor")):
        got, err = ask(n)
        if got is None:
            faults.append(
                f"the engine would not build a catalog for {n} mod lives: "
                f"{err}. Past about a thousand entries this engine's "
                "table.sort throws, and `catalog()` runs during genesis "
                "inside a pcall - so this failure in a real game is a "
                "county with no occupations and nothing saying why")
            continue
        mod, base, total = got
        print(f"  {n:>5} mod lives -> mod={mod:<6} base={base:<6} "
              f"total={total}")

        if base != BASE_TOTAL:
            faults.append(
                f"with {n} profession mods the BASE table sums to {base}, "
                f"not {BASE_TOTAL}. Knox County's own composition has been "
                "altered by somebody's subscriptions, which is the whole "
                "thing [B38] exists to prevent")

        if rule == "capped" and mod > share:
            faults.append(
                f"{n} mod-added lives claim {mod}/10k, past the {share} the "
                "cap allows. Every life a mod adds arrives at its bucket's "
                "flat rate, so without the scale the county becomes mostly "
                "whatever is installed - a fact about a mod list rather "
                "than about who lived here")
        if rule == "floor" and mod != n:
            faults.append(
                f"{n} mod-added lives claim {mod}/10k, and past MOD_SHARE "
                f"each is meant to sit at the floor of 1 for a total of {n}. "
                "The floor exists so rounding cannot delete somebody's mod; "
                "a life the county can never produce is worse than a rare "
                "one")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  66) mod share: the base table holds at {BASE_TOTAL} whatever "
          f"is installed, the block is capped at {share} while it can be, "
          "and past that no profession is deleted")
    return 0


if __name__ == "__main__":
    sys.exit(main())
