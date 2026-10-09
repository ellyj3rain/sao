#!/usr/bin/env python3
"""Installed-engine Week One scanner hearing with source inverses."""
from pathlib import Path
import hashlib
import json
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
GAME = Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
JDK = Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
SCANNER = ROOT / "java/src/com/sao/engine/SAOPerceptionScanner.java"
PROBE = ROOT / "tools/luacheck/WeekOnePrivateHearingProbe.java"
SHIPPED = ROOT / "mod/42.20/media/java/SAO.jar"
DIST = ROOT / "java/dist/SAOAgent.jar"

CONTROLS = (
    ("old-zombie-hearing", "float hearing = hearingForScan(shell);",
     "float hearing = SAOSenses.hearing(shell, true);",
     "exact Week One body did not acquire native world sound"),
    ("unmarked-proxy-hearing",
     "shell instanceof IsoZombie zombie && weekOnePersonName(zombie) != null",
     "shell instanceof IsoZombie zombie",
     "mismatched brain borrowed human hearing"),
)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def command(args: list[object], cwd: Path) -> subprocess.CompletedProcess:
    return subprocess.run([str(item) for item in args], cwd=cwd,
                          capture_output=True, text=True, timeout=120)


def main() -> int:
    for path in (SCANNER, PROBE, SHIPPED, DIST, GAME / "projectzomboid.jar",
                 GAME / "ZombieBuddy.jar", JDK / "java.exe", JDK / "javac.exe"):
        if not path.is_file():
            raise RuntimeError("missing installed engine or source: " + str(path))
    if sha(SHIPPED) != sha(DIST):
        raise RuntimeError("paired SAO jars differ")
    cp = f"{GAME / 'projectzomboid.jar'};{GAME / 'ZombieBuddy.jar'};{SHIPPED}"
    source = SCANNER.read_text(encoding="utf-8")
    receipt = {"status": "OPEN", "sourcePins": {str(path.relative_to(ROOT)): sha(path)
        for path in (SCANNER, PROBE, SHIPPED, DIST)}, "runs": []}
    with tempfile.TemporaryDirectory(prefix="sao-weekone-private-hearing-") as tmp:
        work = Path(tmp)
        classes = work / "classes"
        classes.mkdir()
        built = command([JDK / "javac.exe", "-encoding", "UTF-8", "-cp", cp,
                         "-d", classes, PROBE], work)
        if built.returncode:
            raise RuntimeError("installed-engine probe compile: " + built.stderr)

        def run(extra: Path | None) -> str:
            classpath = f"{extra};{classes};{cp}" if extra else f"{classes};{cp}"
            result = command([JDK / "java.exe", "--enable-native-access=ALL-UNNAMED",
                f"-Duser.home={work}", "-cp", classpath,
                "com.sao.engine.WeekOnePrivateHearingProbe"], work)
            output = result.stdout + result.stderr
            return output if result.returncode == 0 else "EXIT " + str(result.returncode) + "\n" + output

        output = run(None)
        receipt["runs"].append({"name": "current", "output": output[-1600:]})
        if "PASS Week One exact scanner hearing and three inverses" not in output:
            raise RuntimeError("installed-engine scanner: " + output)
        for name, before, after, expected in CONTROLS:
            if source.count(before) != 1:
                raise RuntimeError("inverse anchor drift: " + name)
            altered = work / name
            target = altered / "com/sao/engine/SAOPerceptionScanner.java"
            target.parent.mkdir(parents=True)
            target.write_text(source.replace(before, after, 1), encoding="utf-8")
            compile_inverse = command([JDK / "javac.exe", "-encoding", "UTF-8",
                "-cp", cp, "-d", altered, target], work)
            if compile_inverse.returncode:
                raise RuntimeError(name + " failed to compile: " + compile_inverse.stderr)
            output = run(altered)
            receipt["runs"].append({"name": name, "output": output[-1600:]})
            if "AssertionError: " + expected not in output:
                raise RuntimeError(name + " failed for wrong reason: " + output)
    receipt["status"] = "PASS"
    out = ROOT / "_scratch/d2-leisure-01/weekone21/private-hearing.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(f"PASS Week One installed scanner hearing, {len(CONTROLS)} source inverses")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
