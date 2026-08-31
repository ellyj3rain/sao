#!/usr/bin/env python3
r"""Border 17 - what ships is what was built.

`mod/` is the distributed work: deploy copies it wholesale, and
publishing IS shipping `mod/`. The jar inside it is tracked in git, so
it is a build artifact that a human has to remember to refresh.

[B33] found it two days stale and missing all seventeen engine classes
the bridge calls. deploy.sh overwrote it on the way to the game, so the
LIVE install was always correct and the staleness was invisible from
inside a play session - the only person who would have seen it is
somebody installing from the repository, and what they would have seen
is a mod that loads, appears to run, and does nothing, because every
bridge call raises NoClassDefFoundError inside the pcall that wraps it.

The gating check is exact: every Java source must have a class in the
shipped jar. A missing class is a fact, not a heuristic, so this cannot
manufacture a finding.

Modification times are reported but do NOT gate. A fresh clone sets
every mtime to checkout time, so an mtime comparison would cry wolf on
a tree that is perfectly correct - and a border that cries wolf gets
ignored ([B31], [B31]).
"""
import pathlib
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "java" / "src"
SHIPPED = ROOT / "mod" / "42.20" / "media" / "java" / "SAO.jar"
DIST = ROOT / "java" / "dist" / "SAOAgent.jar"


def classes_in(jar):
    with zipfile.ZipFile(jar) as z:
        return {n for n in z.namelist() if n.endswith(".class")}


def main():
    if not SRC.exists():
        print("17) shipped jar: SKIPPED (no java sources)")
        return 0
    if not SHIPPED.exists():
        print("17) shipped jar: MISSING - mod/ would ship without it")
        return 1

    sources = sorted(SRC.rglob("*.java"))
    shipped = classes_in(SHIPPED)
    names = {n.split("/")[-1] for n in shipped}

    absent = [str(p.relative_to(ROOT)).replace("\\", "/")
              for p in sources if p.stem + ".class" not in names]

    disagree = []
    if DIST.exists():
        d = classes_in(DIST)
        if d != shipped:
            only_dist = sorted(x.split("/")[-1] for x in d - shipped)
            only_ship = sorted(x.split("/")[-1] for x in shipped - d)
            if only_dist:
                disagree.append(f"built but not shipped: {only_dist}")
            if only_ship:
                disagree.append(f"shipped but not built: {only_ship}")

    if absent or disagree:
        print("17) shipped jar:")
        for a in absent:
            print(f"      STALE: {a} has no class in the shipped jar")
        for d in disagree:
            print(f"      DISAGREE: {d}")
        print("      run tools/build-java.sh")
        return 1

    newer = [str(p.relative_to(ROOT)).replace("\\", "/")
             for p in sources
             if p.stat().st_mtime > SHIPPED.stat().st_mtime]
    note = ""
    if newer:
        note = (f"; {len(newer)} source(s) modified after it - "
                "advisory only, mtimes are not reliable after a clone")

    print(f"17) shipped jar: {len(shipped)} classes, all "
          f"{len(sources)} sources present{note}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
