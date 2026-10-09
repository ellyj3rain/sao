#!/usr/bin/env python3
"""Installed-engine Week One visual transfer and proxy perception proof."""
from pathlib import Path
import hashlib
import json
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
GAME = Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
JDK = Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
SOURCES = [
    "java/src/com/sao/engine/SAONativeSnapshot.java",
    "java/src/com/sao/engine/SAOPerceptionScanner.java",
    "java/src/com/sao/engine/SAOSenses.java",
    "java/src/com/sao/bridge/SAOBridge.java",
    "tools/luacheck/PersonSnapshotProbe.java",
    "tools/luacheck/WeekOneSnapshotProbe.java",
    "tools/luacheck/WeekOnePerceptionProbe.java",
    "tools/luacheck/WeekOneRoleProbe.java",
]


def run(command, timeout=120):
    done = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=timeout)
    return {"exit": done.returncode, "output": (done.stdout + done.stderr)[-6000:]}


def main():
    engine = GAME / "projectzomboid.jar"
    sao = ROOT / "mod/42.20/media/java/SAO.jar"
    if not (engine.is_file() and sao.is_file() and (JDK / "javac.exe").is_file()):
        print("SKIPPED installed engine/JDK/SAO jar unavailable")
        return 0
    receipt = {"sources": {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
        for name in SOURCES}, "engineJarSize": engine.stat().st_size, "checks": {}}
    with tempfile.TemporaryDirectory(prefix="sao-weekone-native-") as temp:
        out = Path(temp)
        cp = f"{engine};{sao}"
        build = run([str(JDK / "javac.exe"), "-cp", cp, "-d", str(out),
            *(str(ROOT / name) for name in SOURCES)])
        receipt["checks"]["compile"] = build
        if build["exit"]:
            raise RuntimeError("Week One native compile failed: " + build["output"])
        for name, marker in [
            ("WeekOneSnapshotProbe", "PASS Week One native visual-to-physical snapshot and duplicate refusal"),
            ("WeekOnePerceptionProbe", "PASS Week One scanner exact living-proxy classification and inverses"),
            ("WeekOneRoleProbe", "PASS Week One exact feature sight, hearing, real bandage, and inverses"),
        ]:
            result = run([str(JDK / "java.exe"), f"-Duser.home={out}",
                "-cp", f"{out};{cp}", name])
            receipt["checks"][name] = result
            if result["exit"] or marker not in result["output"]:
                raise RuntimeError(name + " failed: " + result["output"])
    receipt["status"] = "PASS"
    target = ROOT / "_scratch/d2-leisure-01/weekone21/continuity-native.json"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print("PASS Week One installed-engine native snapshot, scanner, and bridge compile")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
