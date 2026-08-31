#!/usr/bin/env python3
r"""[B33] Does the melee patch still fit the engine it is aimed at?

SAOMeleeTransformer rewrites invokestatic
IsoPlayer.isLocalPlayer(IsoGameCharacter) inside exactly three methods
of SwipeStatePlayer, and demands EXACTLY three rewrites:

    count == 3    PASS, combat arms
    count == 0    "unnecessary", arms anyway (no static gate to move)
    anything else ERROR, markPatchReady(count), isPatchReady() false,
                  and SAOCombat REFUSES TO START

That last line is the whole reason this exists. A game update that
renames one callback, or moves one gate to the virtual form, drops the
count to 2 - and the mod keeps running with combat quietly switched
off. Nothing crashes. Survivors simply never swing.

Every constant is parsed out of SAOMeleeTransformer.java and every
fact is read out of projectzomboid.jar with javap. Neither side is
assumed, because the whole question is whether the two still agree.

SKIPs cleanly where the game or the JDK is absent, so a clone without
Project Zomboid installed does not fail the gate.
"""
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = (ROOT / "java" / "src" / "com" / "sao" / "agent"
       / "SAOMeleeTransformer.java")
JAVAP = pathlib.Path(
    r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin\javap.exe")
PZ = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"
    r"\projectzomboid.jar")

HEADER = re.compile(r"^\s{2}\S.*?\b(\w+)\([^)]*\);\s*$")


def wanted():
    """Target class, patched methods and expected count, from the Java."""
    s = SRC.read_text(encoding="utf-8", errors="ignore")
    cls = re.search(r'TARGET_CLASS\s*=\s*"([^"]+)"', s)
    owner = re.search(r'ORIGINAL_OWNER\s*=\s*"([^"]+)"', s)
    name = re.search(r'ORIGINAL_NAME\s*=\s*"([^"]+)"', s)
    desc = re.search(r'ORIGINAL_DESCRIPTOR\s*=\s*"([^"]+)"', s)
    count = re.search(r"EXPECTED_PATCH_COUNT\s*=\s*(\d+)", s)
    block = re.search(r"PATCHED_METHODS\s*=\s*Set\.of\((.*?)\);", s,
                      re.S)
    if not all((cls, owner, name, desc, count, block)):
        raise SystemExit("combat_patch_test: cannot read the "
                         "transformer's constants - it moved or was "
                         "rewritten, and this mirror is blind")
    methods = set(re.findall(r'"([^"]+)"', block.group(1)))
    return (cls.group(1), owner.group(1), name.group(1),
            desc.group(1), int(count.group(1)), methods)


def engine_sites(cls, owner, name, desc, methods):
    """Static and virtual gate sites per method, from the class file."""
    out = subprocess.run(
        [str(JAVAP), "-c", "-p", "-cp", str(PZ),
         cls.replace("/", ".")],
        capture_output=True, text=True, errors="ignore")
    if out.returncode != 0:
        return None, None, None
    static_ref = f"Method {owner}.{name}:{desc}"
    virtual_ref = f"Method {owner}.{name}:()Z"
    present, static_by, virtual_by = set(), {}, {}
    current = None
    for line in out.stdout.splitlines():
        h = HEADER.match(line)
        if h:
            current = h.group(1)
            present.add(current)
            continue
        if current is None:
            continue
        if "invokestatic" in line and static_ref in line:
            static_by[current] = static_by.get(current, 0) + 1
        elif "invokevirtual" in line and virtual_ref in line:
            virtual_by[current] = virtual_by.get(current, 0) + 1
    return present, static_by, virtual_by


def main():
    if not SRC.exists():
        print("combat patch: SKIPPED (no transformer source)")
        return 0
    if not JAVAP.exists() or not PZ.exists():
        print("combat patch: SKIPPED (no JDK or no game install - the "
              "engine cannot be asked here)")
        return 0

    cls, owner, name, desc, expected, methods = wanted()

    # [B33] "Not in this jar" is NOT the same question as "no jar to
    # ask". The game IS installed here, so a missing target class is a
    # finding and the worst one available: transform() is never called
    # for it, markPatchReady never runs, patchedCalls stays 0, and
    # combat refuses forever. Reporting that as SKIPPED would have been
    # the exact conflation GOVERNANCE forbids - and this tool made it
    # on its own third control.
    import zipfile
    with zipfile.ZipFile(PZ) as z:
        in_jar = (cls.strip("/") + ".class") in z.namelist()
    if not in_jar:
        print("combat patch:")
        print(f"      TARGET GONE: {cls} is not in this engine build.")
        print("      The transformer is never invoked for it, the gate")
        print("      is never marked, and SAOCombat refuses to start.")
        return 1

    present, static_by, virtual_by = engine_sites(
        cls, owner, name, desc, methods)
    if present is None:
        print(f"combat patch: SKIPPED (javap could not read {cls})")
        return 0

    print("=" * 68)
    print(f"TARGET  {cls}")
    print(f"GATE    {owner}.{name}{desc}")
    print("=" * 68)

    missing = sorted(m for m in methods if m not in present)
    would_patch = sum(static_by.get(m, 0) for m in methods)

    for m in sorted(methods):
        s = static_by.get(m, 0)
        v = virtual_by.get(m, 0)
        flag = "  <- METHOD GONE" if m not in present else ""
        print(f"  {m}{flag}")
        print(f"      static gate sites: {s}   virtual: {v}")

    print()
    print(f"  transformer expects exactly: {expected}")
    print(f"  the engine would yield:      {would_patch}")

    print()
    if missing:
        print("  FINDING: a targeted callback no longer exists on this")
        print(f"  build: {missing}")
    if would_patch == expected:
        verdict = "combat ARMS (patch applies cleanly)"
        ok = True
    elif would_patch == 0:
        verdict = ("count 0 -> the 'unnecessary' branch arms combat "
                   "without patching; check the gates really are "
                   "virtual and the shell still overrides them")
        ok = True
    else:
        verdict = (f"count {would_patch} is neither {expected} nor 0 -> "
                   "markPatchReady fails -> SAOCombat REFUSES TO START. "
                   "Survivors will never swing and nothing will crash.")
        ok = False

    print(f"VERDICT: {verdict}")
    if not ok:
        return 1
    if would_patch == expected and not missing:
        print("  the transformer and this engine build still agree")
    return 0


if __name__ == "__main__":
    sys.exit(main())
