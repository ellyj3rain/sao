#!/usr/bin/env python3
"""Installed-engine staged-return lifecycle probe, compiled in private scratch."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
JDK = Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ = Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid\projectzomboid.jar")
MUTATIONS = [
    ("constructor-publication", "new SAOIsoPlayerShell(null, descriptor, 0, 0, 0)",
     "new SAOIsoPlayerShell(null, descriptor, (int) x, (int) y, (int) z)",
     "successful creation requires cleanup"),
    ("missing-stage-pause", "shell.removalPending = true;", "shell.removalPending = false;",
     "staged body is not paused"),
    ("population-debit", "shell.populationAccounted = true;", "shell.populationAccounted = false;",
     "return would debit population again"),
    ("premature-activation", "if (stage.phase != Phase.PUBLISHED) return false;", "",
     "detached body activated before publication"),
    ("lost-cleanup-failure", "SAONativeSnapshot.unregister(shell);\n            ModelManager.instance.Remove(shell);",
     "ModelManager.instance.Remove(shell);",
     "invalid inventory cleanup falsely succeeded"),
    ("missing-world-removal", "shell.removeFromWorld();", "",
     "native cleanup retry failed"),
    ("duplicate-selection", "if (found != null) throw new IllegalStateException(\"Duplicate staged return identity/token\");",
     "", "duplicate transaction silently selected a body"),
    ("lost-reload-handle", "return found;", "return null;",
     "reload GC lost the pending shell"),
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", nargs="?", type=Path, default=ROOT)
    parser.add_argument("--receipt", type=Path)
    args = parser.parse_args()
    root = args.root.resolve()
    source = root / "java/src/com/sao/engine/SAOReturnBody.java"
    companions = [root / path for path in (
        "java/src/com/sao/engine/SAOIsoPlayerShell.java",
        "java/src/com/sao/engine/SAONativeSnapshot.java",
        "tools/luacheck/ReturnBodyProbe.java",
    )]
    sao = root / "mod/42.20/media/java/SAO.jar"
    receipt = {"results": [], "commands": []}
    try:
        for path in [source, *companions, sao]:
            if not path.is_file():
                raise RuntimeError(f"Required staged return source missing: {path}")
        if not all(p.is_file() for p in (PZ, JDK / "javac.exe", JDK / "java.exe")):
            print("SKIPPED staged return body VM: installed engine/JDK absent")
            return 0
        original = source.read_text(encoding="utf-8-sig")
        with tempfile.TemporaryDirectory(prefix="sao-return-body-") as tmp:
            scratch = Path(tmp)

            def run(argv, cwd):
                result = subprocess.run([str(v) for v in argv], cwd=cwd, capture_output=True,
                    text=True, encoding="utf-8", errors="replace", timeout=60)
                receipt["commands"].append({"argv": [str(v) for v in argv], "cwd": str(cwd),
                    "returncode": result.returncode, "stdout": result.stdout, "stderr": result.stderr})
                return result

            def case(name, content):
                work = scratch / name
                work.mkdir()
                changed = work / "SAOReturnBody.java"
                changed.write_text(content, encoding="utf-8")
                classes = work / "classes"
                classes.mkdir()
                cp = os.pathsep.join((str(PZ), str(sao)))
                compiled = run([JDK / "javac.exe", "-encoding", "UTF-8", "-cp", cp,
                    "-d", classes, changed, *companions], work)
                if compiled.returncode:
                    raise RuntimeError(f"{name} did not compile: {compiled.stderr}")
                executed = run([JDK / "java.exe", f"-Duser.home={work}", "-cp",
                    os.pathsep.join((str(classes), cp)), "ReturnBodyProbe"], work)
                agent_log = work / "Zomboid/SAOAgent.log"
                if agent_log.is_file():
                    logged = agent_log.read_text(encoding="utf-8", errors="replace")
                    receipt["commands"][-1]["agent_log"] = logged
                    executed.stderr += "\n" + logged
                return executed

            result = case("production", original)
            if result.returncode or "PASS staged return body:" not in result.stdout:
                raise RuntimeError("Staged return probe failed: " + result.stdout + result.stderr)
            print(result.stdout[result.stdout.index("PASS staged return body:"):].strip())
            receipt["results"].append({"case": "production", "passed": True})
            for name, before, after, reason in MUTATIONS:
                if before not in original:
                    raise RuntimeError(f"Control {name} source target missing")
                changed = original.replace(before, after, 1)
                if changed == original:
                    raise RuntimeError(f"Control {name} did not change source")
                result = case(name, changed)
                if result.returncode == 0 or reason not in result.stdout + result.stderr:
                    raise RuntimeError(f"Control {name} did not fail for {reason}: "
                        + result.stdout + result.stderr)
                receipt["results"].append({"case": name, "passed": True, "reason": reason})
                print(f"CONTROL {name}: {reason}")
        receipt["status"] = "PASS"
        print("  165) PASS -- native staged return body")
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
        receipt["status"] = "FAIL"
        receipt["error"] = str(error)
        print("FAULT " + str(error))
    if args.receipt:
        args.receipt.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    return 0 if receipt.get("status") == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
