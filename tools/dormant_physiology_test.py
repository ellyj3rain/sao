#!/usr/bin/env python3
"""Border 174: dormant partial food/drink and nutrition in the real engine."""
from __future__ import annotations

from pathlib import Path
import os
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parent.parent
GAME = Path(os.environ.get("PZ_DIR", r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"))
JDK = Path(os.environ.get("JDK_BIN", r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin"))
JAR = GAME / "projectzomboid.jar"
NATIVE = ROOT / "java/src/com/sao/engine/SAONativeSnapshot.java"
HIBERNATION = ROOT / "java/src/com/sao/engine/SAOHibernation.java"
PROBE = ROOT / "tools/luacheck/PersonSnapshotProbe.java"


def run(source: str) -> subprocess.CompletedProcess[str]:
    with tempfile.TemporaryDirectory(prefix="sao-dormant-physiology-") as tmp:
        work = Path(tmp)
        changed = work / "SAOHibernation.java"
        changed.write_text(source, encoding="utf-8")
        classes = work / "classes"
        classes.mkdir()
        compiled = subprocess.run(
            [str(JDK / "javac.exe"), "-encoding", "UTF-8", "-cp", str(JAR),
             "-d", str(classes), str(NATIVE), str(changed), str(PROBE)],
            cwd=work, capture_output=True, text=True, timeout=60)
        if compiled.returncode:
            return compiled
        return subprocess.run(
            [str(JDK / "java.exe"), f"-Duser.home={work}", "-cp",
             f"{classes}{os.pathsep}{JAR}", "PersonSnapshotProbe"],
            cwd=work, capture_output=True, text=True, timeout=60)


def main() -> int:
    required = [JAR, JDK / "java.exe", JDK / "javac.exe", NATIVE,
                HIBERNATION, PROBE]
    if not all(path.is_file() for path in required):
        print("Border 174 SKIPPED: installed engine, JDK, or probe absent")
        return 0
    source = HIBERNATION.read_text(encoding="utf-8-sig")
    fixed = run(source)
    if fixed.returncode or "dormant partial food/drink and partition stability" not in fixed.stdout:
        print("REFUSED: dormant physiology production path failed\n"
              + fixed.stdout + fixed.stderr)
        return 1
    controls = [
        ("native partial eating",
         "if (!shell.Eat(meal, engineFraction, false)) break;",
         "if (true) break;", "partial nested food quantity was not retained"),
        ("nested resource traversal",
         "collect(nested.getInventory(), found, seen);",
         "/* nested resources omitted */", "partial nested food quantity was not retained"),
        ("spoilage exclusion",
         "if (food.isRotten() || food.getPoisonPower() > 0",
         "if (false || food.getPoisonPower() > 0", "rotten food was consumed"),
        ("native partial drinking",
         "if (!shell.DrinkFluid(drink, engineFraction, false)) break;",
         "fluids.Empty();", "partial nested drink quantity was not retained"),
        ("fluid quantity accounting",
         "return -properties.getThirstChange();",
         "return -properties.getThirstChange() * fluids.getAmount();",
         "equal dormant event history changed across interval partitions"),
    ]
    for name, old, new, expected in controls:
        if source.count(old) != 1:
            print(f"REFUSED: {name} mutation seam changed")
            return 1
        result = run(source.replace(old, new, 1))
        combined = result.stdout + result.stderr
        if result.returncode == 0 or expected not in combined:
            print(f"REFUSED: {name} mutation did not fail for {expected}\n" + combined)
            return 1
    print("Border 174 PASS: real partial Eat/DrinkFluid, nested inventory, spoilage, nutrition, quantity journals, zero elapsed and partition/reload stability; five controls fail")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
