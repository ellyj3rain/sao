#!/usr/bin/env python3
r"""Border 42 - the jar says which jar it is, and says it truthfully.

`SAOBridge.getVersion()` returned a hardcoded
`"0.1.0.0-pre-alpha+java2"` while the repository `VERSION` said
`0.6.0.0-pre-alpha` - five minor versions apart. Nobody noticed,
because `getVersion` was the **one public bridge method no Lua ever
called**. `bridge_arity` had been printing "never called: 1" in every
gate run for months; the number was right and the name was never
looked at.

Both halves of that mattered, and they hid each other. An unread
method cannot be caught lying, and a lying method is worth nothing to
read. Wiring it before fixing it would only have put a false version on
the player's screen.

WHY A VERSION IS WORTH ANYTHING HERE
------------------------------------
[B33]: the tracked `mod/42.20/media/java/SAO.jar` was two days stale
and missing all seventeen engine classes the bridge calls. `deploy.sh`
overwrote it on the way to the game, so the LIVE install was always
correct and the defect was invisible from inside a play session -
anyone installing from the repository got a mod that loads, appears to
run, and does nothing. A version the county can state out loud is how
that becomes visible without a rebuild.

WHAT THIS READS
---------------
The SHIPPED bytecode, not the source. `tools/build-java.sh` generates
`com.sao.SAOVersion` from `VERSION` into the build output, so the
string is a compile-time constant and javap can read it straight out of
the constant pool. Three links:

  1. the shipped jar's stamped constant equals `VERSION`;
  2. `getVersion` actually returns that constant rather than a literal
     of its own;
  3. some Lua reads `getVersion` - an unread version is the state this
     border exists to end.

SKIPs when javap or the jar is absent.
"""
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
SHIPPED = ROOT / "mod" / "42.20" / "media" / "java" / "SAO.jar"
VERSION_FILE = ROOT / "VERSION"
JAVAP = pathlib.Path(
    r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin\javap.exe")

STAMP_CLASS = "com.sao.SAOVersion"

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from menu_reach import strip_lua                       # noqa: E402


def javap(*args):
    try:
        done = subprocess.run([str(JAVAP), *args], capture_output=True,
                              text=True, timeout=180)
    except (OSError, subprocess.SubprocessError):
        return ""
    return done.stdout or ""


def main():
    faults = []
    print("=" * 74)
    print("WHICH JAR IS RUNNING")
    print("=" * 74)

    declared = VERSION_FILE.read_text(encoding="utf-8").strip()
    print(f"  VERSION declares:     {declared}")

    if not (JAVAP.exists() and SHIPPED.exists()):
        print("  SKIPPED - no javap or no shipped jar to read")
        print("  42) version stamp: SKIPPED, artifact absent")
        return 0

    # 1. The stamp in the shipped artifact.
    out = javap("-v", "-p", "-cp", str(SHIPPED), STAMP_CLASS)
    m = re.search(r"ConstantValue:\s*String\s+(\S+)", out)
    stamped = m.group(1) if m else None
    print(f"  shipped jar stamped:  {stamped or 'NOTHING'}")
    if stamped is None:
        faults.append(
            f"{STAMP_CLASS} carries no string constant in the shipped jar "
            "- the build did not stamp it, so whatever getVersion says is "
            "typed rather than derived")
    elif stamped != declared:
        faults.append(
            f"the shipped jar says {stamped} and VERSION says {declared} - "
            "the county would report a build that is not the one running, "
            "which is worse than reporting nothing")

    # 2. What getVersion actually answers, out of the shipped bytecode.
    #
    #    NOT "does it reference SAOVersion". `static final String` is a
    #    compile-time constant, so javac INLINES it: getVersion compiles
    #    to a bare `ldc "0.6.0.0-pre-alpha"` with no reference to the
    #    stamp class left in the bytecode at all. A first draft looked
    #    for that reference, found none, and reported a correct build as
    #    broken. What can be checked in the artifact is the VALUE, and
    #    that is the invariant that matters anyway.
    body = javap("-c", "-cp", str(SHIPPED), "com.sao.bridge.SAOBridge")
    gv = re.search(r"public java\.lang\.String getVersion\(\);\n(.*?)"
                   r"(?=\n  \S|\Z)", body, re.S)
    if not gv:
        faults.append("getVersion is not in the shipped jar at all")
    else:
        # `ldc_w`, not just `ldc`: a constant pool index past 255 needs
        # the wide form, and this one is #843. Matching only the narrow
        # instruction read a correct method as returning nothing.
        answers = re.findall(r"ldc(?:_w)?\s+#\d+\s+//\s*String\s+(\S+)",
                             gv.group(1))
        print(f"  getVersion answers:   {answers[0] if answers else 'NOTHING'}")
        if not answers:
            faults.append(
                "getVersion returns no string constant in the shipped jar "
                "- whatever it answers cannot be read out of the artifact, "
                "which is the only place worth reading it")
        elif answers[0] != declared:
            faults.append(
                f"getVersion answers {answers[0]} and VERSION says "
                f"{declared} - the county would tell the player it is "
                "running a build it is not")

    # 3. And it is DERIVED, which only the source can show, because the
    #    inlining above erases the difference in the artifact.
    src = (ROOT / "java" / "src" / "com" / "sao" / "bridge"
           / "SAOBridge.java").read_text(encoding="utf-8", errors="ignore")
    gvs = re.search(r"public String getVersion\(\)\s*\{(.*?)\}", src, re.S)
    derived = bool(gvs and "SAOVersion.VALUE" in gvs.group(1))
    print(f"  getVersion is:        "
          f"{'stamped from VERSION' if derived else 'TYPED BY HAND'}")
    if not derived:
        faults.append(
            "getVersion does not return SAOVersion.VALUE in the source - a "
            "hand-typed literal is right until VERSION moves, and it was "
            "five minor versions behind when this was written")

    # 3. Somebody asks. An unread version is the state that hid the lie.
    tree = "".join(strip_lua(p.read_text(encoding="utf-8", errors="ignore"),
                             strings=False)
                   for p in sorted(LUA.rglob("*.lua")))
    reads = len(re.findall(r"getVersion\s*\(", tree))
    print(f"  Lua call sites:       {reads}")
    if reads == 0:
        faults.append(
            "no Lua reads getVersion - it was unread for the whole life of "
            "the project and that is how it went five versions stale "
            "without anyone noticing. A version nothing states is not a "
            "version")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print("  42) version stamp: the shipped jar carries VERSION's own "
          "number, getVersion")
    print("      returns it, and the county says it out loud")
    return 0


if __name__ == "__main__":
    sys.exit(main())
