#!/usr/bin/env python3
r"""Border 65 - time softens, and enmity ends.

[B8] made the county's feelings age: a relation nobody has touched
for a fortnight loses 8% of its trust a day, and a grudge that has
faded past a fifth is over - *"nobody shook hands; they simply stopped
mattering to each other"*.

Nobody has ever watched it happen. It runs once per world-day inside a
`runSub`, it moves numbers in ModData, and every possible way for it to
be wrong looks the same from inside a game:

  * too slow, or never - every grudge is permanent and the county
    hardens into whoever wronged whom first
  * too fast - nobody holds anything against anybody and the whole
    standing layer is decoration
  * grace ignored - a feeling a week old is already fading, and
    nothing is ever current
  * bonds not exempt - the one relation the design says is permanent
    quietly is not

A player would read any of those as "the county is like that".

So this drives the real `driftStandings` in a real Kahlua VM with a
stubbed clock and store, one world-day at a time, and asks what
actually happens. Measured at [B49]:

    grace held through day 13
    hostility cleared day 31
    trust spent day 67
    a bond untouched after 200 days

The bars below are wide on purpose. They are not there to pin the
tuning - the operator may want a county that forgives faster or
slower, and that is a design choice. They are there to catch the decay
being switched off, inverted, or made instant, which is not.
"""
import pathlib
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
CHECK = ROOT / "tools" / "luacheck"
PROBE = CHECK / "probe_standing.lua"
SRC = CHECK / "LuaRun.java"
OUT = ROOT / "java" / "out" / "luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"

MODULES = ("shared/SAO_Log.lua", "shared/SAO_Hash.lua",
           "shared/SAO_Disposition.lua", "shared/SAO_Standing.lua")

GRACE_DAYS = 13        # inside the fortnight nothing may move
CLEAR_BY = 60          # a grudge must be over within this
CLEAR_NOT_BEFORE = 15  # and must survive the grace at least
BOND_DAYS = 200


def build():
    cls = OUT / "LuaRun.class"
    if cls.exists() and cls.stat().st_mtime >= SRC.stat().st_mtime:
        return True
    OUT.mkdir(parents=True, exist_ok=True)
    return subprocess.run(
        [str(JDK / "javac.exe"), "-cp", str(PZ), "-d", str(OUT), str(SRC)],
        capture_output=True, text=True, timeout=300).returncode == 0


def ask(expr):
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(STDLIB, work / "stdlib.lua")
        for c in OUT.glob("*.class"):
            shutil.copy2(c, work / c.name)
        args = [str(JDK / "java.exe"), "-cp", f"{PZ};.", "LuaRun"]
        args += [str(LUA / m) for m in MODULES]
        args += [str(PROBE), "--", expr]
        done = subprocess.run(args, cwd=str(work), capture_output=True,
                              text=True, timeout=600)
    tail = (done.stdout or "").strip().split("\n")[-1] if done.stdout else ""
    if not tail.startswith("VALUE "):
        return None, (tail or (done.stderr or "").strip())[:200]
    return tail[6:].strip(), None


def main():
    faults = []
    print("=" * 74)
    print("TIME SOFTENS, AND ENMITY ENDS")
    print("=" * 74)

    if not (JDK.exists() and PZ.exists() and STDLIB.exists()
            and SRC.exists()):
        print("  SKIPPED - no JDK, engine jar, stdlib.lua or runner")
        print("  65) time softens: SKIPPED, engine absent")
        return 0
    missing = [m for m in MODULES if not (LUA / m).exists()]
    if missing or not PROBE.exists():
        print()
        print("VERDICT:")
        print("  FAULT: " + ", ".join(missing + ([PROBE.name] if not
              PROBE.exists() else [])) + " missing, so the county's feelings "
              "were never aged. An absent module is the finding")
        return 1
    if not build():
        print()
        print("VERDICT:")
        print("  FAULT: the VM runner will not compile, so nothing ran on "
              "the engine. A border that cannot run is not one that passed")
        return 1

    grace, err = ask(f"PROBE_GRACE({GRACE_DAYS})")
    feud, err2 = ask(f"PROBE_FEUD(-0.8, {CLEAR_BY + 20})")
    bond, err3 = ask(f"PROBE_BOND({BOND_DAYS})")
    for e in (err, err2, err3):
        if e:
            print()
            print("VERDICT:")
            print(f"  FAULT: the engine would not age the county: {e}")
            return 1

    cleared, spent = (int(x) for x in feud.split(","))
    print(f"  trust after {GRACE_DAYS} days inside the grace : {grace}")
    print(f"  hostility cleared on day                : {cleared}")
    print(f"  trust spent on day                      : {spent}")
    print(f"  a bond after {BOND_DAYS} days                  : {bond}")

    if abs(float(grace) - 0.5) > 1e-6:
        faults.append(
            f"a feeling set at 0.5 reads {grace} after {GRACE_DAYS} days, "
            "and nothing should have touched it. The fortnight's grace is "
            "what makes a feeling CURRENT - without it a survivor starts "
            "forgetting you the day after you meet")

    if cleared < 0:
        faults.append(
            f"a grudge at -0.8 was still live after {CLEAR_BY + 20} days. "
            "Enmity that never ends means the county hardens permanently "
            "into whoever wronged whom first, and [B8] exists to say it "
            "does not")
    elif cleared < CLEAR_NOT_BEFORE:
        faults.append(
            f"a grudge at -0.8 ended on day {cleared}, inside the grace "
            "period. Somebody being forgiven before the county has even "
            "stopped counting the fortnight means the decay is running "
            "when it should not, and no feeling is ever current")
    elif cleared > CLEAR_BY:
        faults.append(
            f"a grudge at -0.8 took {cleared} days to end, past the {CLEAR_BY} "
            "this border allows. The bar is wide on purpose - it is here to "
            "catch the decay being slowed to nothing, not to pin the tuning")

    if spent < 0:
        faults.append(
            "trust never ran out at all. A feeling that decays but never "
            "arrives anywhere is a number going quietly to a place nobody "
            "checks")

    if abs(float(bond) - 0.9) > 1e-6:
        faults.append(
            f"a BONDED relation set at 0.9 reads {bond} after {BOND_DAYS} "
            "days. A bond is the one thing the design says time does not "
            "touch - `bonded ~= true` is the guard, and if it has stopped "
            "holding then the closest relationships in the county are the "
            "ones quietly eroding")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  65) time softens: the grace holds {GRACE_DAYS} days, a grudge "
          f"at -0.8 ends on day {cleared}, and a bond is untouched after "
          f"{BOND_DAYS}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
