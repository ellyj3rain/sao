#!/usr/bin/env python3
"""Border 192: exact Speakeasy bundle parity in the shipped Java evaluator.

This compiles the production JDK-only evaluator and bounded async worker, loads
the content-hashed resource, checks all twenty R66 rows plus byte-tokenizer
vectors, executes corruption/mask/queue/reset controls, and reports measured
headless evaluator and worker round-trip latency.  It launches no game or UI.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]
JDK = Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
MODEL = ROOT / "java/src/com/sao/engine/SAOCoordinationModel.java"
WORKER = ROOT / "java/src/com/sao/engine/SAOCoordinationWorker.java"
HARNESS = ROOT / "tools/javacheck/CoordinationModelCheck.java"
RESOURCE = ROOT / "java/resources/com/sao/model/coordination-r67.bundle"
MANIFEST = ROOT / "java/resources/com/sao/model/coordination-r67.manifest.json"
PARITY = ROOT / "tools/fixtures/coordination-r67/parity.tsv"
TOKENS = ROOT / "tools/fixtures/coordination-r67/tokenizer-vectors.tsv"
SHIPPED = ROOT / "mod/42.20/media/java/SAO.jar"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--receipt", type=Path)
    args = parser.parse_args()
    receipt: dict[str, object] = {
        "border": 192,
        "scope": "headless exact Java evaluator and bounded async worker",
        "loadedGameplay": False,
    }
    try:
        required = (MODEL, WORKER, HARNESS, RESOURCE, MANIFEST, PARITY, TOKENS,
                    SHIPPED)
        for path in required:
            if not path.is_file():
                raise RuntimeError("required coordination artifact is absent: " + str(path))
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        components = manifest["components"]
        if digest(RESOURCE) != components["coordination.bundle"]:
            raise RuntimeError("SAO bundle differs from the Speakeasy manifest")
        if digest(PARITY) != components["parity.tsv"]:
            raise RuntimeError("SAO parity vectors differ from the Speakeasy manifest")
        if digest(TOKENS) != components["tokenizer-vectors.tsv"]:
            raise RuntimeError("SAO tokenizer vectors differ from the Speakeasy manifest")
        if not all((JDK / name).is_file() for name in ("javac.exe", "java.exe")):
            print("SKIPPED coordination native parity: JDK absent")
            return 0
        with tempfile.TemporaryDirectory(prefix="sao-coordination-model-") as tmp:
            scratch = Path(tmp)
            classes = scratch / "classes"
            classes.mkdir()
            compile_command = [JDK / "javac.exe", "-encoding", "UTF-8",
                               "-d", classes, MODEL, WORKER, HARNESS]
            compiled = subprocess.run([str(item) for item in compile_command],
                                      capture_output=True, text=True,
                                      encoding="utf-8", errors="replace",
                                      timeout=60)
            if compiled.returncode:
                raise RuntimeError("coordination Java compile failed: " + compiled.stderr)
            resource_target = classes / "com/sao/model/coordination-r67.bundle"
            resource_target.parent.mkdir(parents=True)
            shutil.copy2(RESOURCE, resource_target)
            run_command = [JDK / "java.exe", "-cp", classes,
                           "CoordinationModelCheck", RESOURCE, PARITY, TOKENS]
            result = subprocess.run([str(item) for item in run_command],
                                    capture_output=True, text=True,
                                    encoding="utf-8", errors="replace",
                                    timeout=60)
            if result.returncode or not result.stdout.startswith("PASS rows=20 "):
                raise RuntimeError("coordination Java parity failed: "
                                   + result.stdout + result.stderr)

            # Repeat against the exact jar shipped by the mod. This proves the
            # packaged classes and classpath resource, rather than only the
            # source compilation above, execute the same corruption, parity,
            # queue and reset controls.
            shipped_classes = scratch / "shipped-classes"
            shipped_classes.mkdir()
            shipped_compile_command = [
                JDK / "javac.exe", "-encoding", "UTF-8", "-cp", SHIPPED,
                "-d", shipped_classes, HARNESS,
            ]
            shipped_compiled = subprocess.run(
                [str(item) for item in shipped_compile_command],
                capture_output=True, text=True, encoding="utf-8",
                errors="replace", timeout=60)
            if shipped_compiled.returncode:
                raise RuntimeError("shipped-jar harness compile failed: "
                                   + shipped_compiled.stderr)
            shipped_run_command = [
                JDK / "java.exe", "-cp",
                str(shipped_classes) + os.pathsep + str(SHIPPED),
                "CoordinationModelCheck", RESOURCE, PARITY, TOKENS,
            ]
            shipped_result = subprocess.run(
                [str(item) for item in shipped_run_command],
                capture_output=True, text=True, encoding="utf-8",
                errors="replace", timeout=60)
            if (shipped_result.returncode
                    or not shipped_result.stdout.startswith("PASS rows=20 ")):
                raise RuntimeError("shipped-jar coordination parity failed: "
                                   + shipped_result.stdout
                                   + shipped_result.stderr)
            receipt.update({
                "status": "PASS",
                "measurement": result.stdout.strip(),
                "shippedJarMeasurement": shipped_result.stdout.strip(),
                "hashes": {str(path.relative_to(ROOT)): digest(path)
                           for path in required},
                "commands": [[str(item) for item in compile_command],
                             [str(item) for item in run_command],
                             [str(item) for item in shipped_compile_command],
                             [str(item) for item in shipped_run_command]],
            })
            print(result.stdout.strip())
            print("SHIPPED " + shipped_result.stdout.strip())
            print("  192) exact tokenizer/output parity, malformed-artifact refusal, "
                  "bounded async reset, packaged-resource execution and native "
                  "cost measurement")
    except (OSError, RuntimeError, subprocess.TimeoutExpired,
            json.JSONDecodeError) as error:
        receipt.update({"status": "FAIL", "error": str(error)})
        print("FAULT: " + str(error))
    if args.receipt:
        args.receipt.parent.mkdir(parents=True, exist_ok=True)
        args.receipt.write_text(json.dumps(receipt, indent=2) + "\n",
                                encoding="utf-8")
    return 0 if receipt.get("status") == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
