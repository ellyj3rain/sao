"""Installed Kahlua proof of the production private experience/model contract."""
from __future__ import annotations

import argparse
import ast
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

from .controls import NEW_CONTROLS

HERE = Path(__file__).resolve().parent
REL = Path("mod/42.20/media/lua/shared")
DEFAULT_GAME = r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"
DEFAULT_JDK = r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def jdk_tool(directory, name):
    return directory / (name + (".exe" if os.name == "nt" else ""))


def inherited_controls(path):
    tree = ast.parse(path.read_text(encoding="utf-8"))
    found = [node.value for node in ast.walk(tree) if isinstance(node, ast.Assign)
        and any(isinstance(target, ast.Name) and target.id == "controls" for target in node.targets)]
    assert len(found) == 1, "missing or ambiguous inherited controls: " + str(path)
    return ast.literal_eval(found[0])


def save_receipt(output, receipt):
    (output / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")


def main(argv=None, *, default_root=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, default=default_root or HERE.parents[1])
    parser.add_argument("--output", type=Path, help="Optional evidence directory outside the source tree")
    args = parser.parse_args(argv)
    root = args.source_root.resolve()
    game = Path(os.environ.get("PZ_DIR", DEFAULT_GAME)).resolve()
    jdk = Path(os.environ.get("JDK_BIN", DEFAULT_JDK)).resolve()
    output = args.output.resolve() if args.output else Path(tempfile.mkdtemp(prefix="sao-capability-evidence-"))
    if output == root or root in output.parents:
        raise ValueError("Evidence output must be outside --source-root")
    output.mkdir(parents=True, exist_ok=True)
    receipt = {"schema": "sao-capability-experience-proof/1", "status": "RUNNING", "checks": [],
        "sourceRoot": str(root), "timestamp": datetime.now(timezone.utc).isoformat(),
        "boundary": "Installed Kahlua executes production models and ledger with producer-shaped receipts. "
                    "Native dose, measured Stats and thermal-preparation authenticity remain separately owned producer proofs; "
                    "no rendered world, recipe realization or training admission."}
    try:
        model_path = root / REL / "SAO_CognitiveModels.lua"
        cognition_path = root / REL / "SAO_Cognition.lua"
        inputs = [model_path, cognition_path, HERE / "legacy_archive.lua", HERE / "legacy-archive-receipt.json",
                  HERE / "restore_legacy.lua", HERE / "experience.lua", HERE / "controls.py", Path(__file__).resolve(),
                  HERE.parent / "capability_experience_test.py", root / REL / "SAO_Hash.lua", root / REL / "SAO_Labor.lua",
                  root / "tools/luacheck/CognitiveModelChecks.lua", root / "tools/cognitive_models_test.py",
                  root / "tools/cognition_checks/prelude.lua", root / "tools/cognition_checks/runtime.lua",
                  root / "tools/cognition_checks/run_checks.py", root / "tools/luacheck/LuaRun.java"]
        assert all(p.is_file() for p in inputs), "missing owned capability input: " + ", ".join(str(p) for p in inputs if not p.is_file())
        receipt["inputs"] = {str(p): sha(p) for p in inputs}
        archive = json.loads((HERE / "legacy-archive-receipt.json").read_text(encoding="utf-8"))
        assert archive["schema"] == "sao-cognition-legacy-archive/1" and archive["verdict"] == "PASS"
        # Preserve the original producer receipt bytes, including its original artifact location.
        assert archive["artifact"]["path"].replace("\\", "/") == "tests/legacy_archive.lua"
        assert sha(HERE / "legacy_archive.lua") == archive["artifact"]["sha256"], "legacy data archive changed"
        receipt["legacyArchive"] = {"sha256": archive["artifact"]["sha256"],
            "producerReceiptSha256": sha(HERE / "legacy-archive-receipt.json"), "containsOldRuntime": False}
        engine = game / "projectzomboid.jar"
        executables = {name: jdk_tool(jdk, name) for name in ("java", "javac")}
        missing = [str(p) for p in [engine, game / "stdlib.lua", *executables.values()] if not p.is_file()]
        if missing:
            receipt.update(status="SKIPPED", reason="installed Project Zomboid engine or JDK unavailable", missing=missing)
            print("SKIPPED -- capability experience: " + receipt["reason"], flush=True)
            return 0
        receipt["engineInputs"] = {str(p): sha(p) for p in (engine, game / "stdlib.lua")}
        model = model_path.read_text(encoding="utf-8")
        cognition = cognition_path.read_text(encoding="utf-8")
        original_cases = (root / "tools/luacheck/CognitiveModelChecks.lua").read_text(encoding="utf-8")
        old = 'p.version==(id=="ordinary" and "sao-ordinary/1" or "sao-associative/1")'
        new = 'p.version==(id=="ordinary" and "sao-ordinary/2" or "sao-associative/2")'
        assert original_cases.count(old) + original_cases.count(new) == 1, "model fixture version seam changed"
        model_controls = inherited_controls(root / "tools/cognitive_models_test.py")
        ledger_controls = inherited_controls(root / "tools/cognition_checks/run_checks.py")
        assert len(model_controls) == 36 and len(ledger_controls) == 14 and len(NEW_CONTROLS) == 31, "control coverage changed"
        with tempfile.TemporaryDirectory(prefix="sao-capability-build-") as temporary:
            work = Path(temporary)
            shutil.copyfile(game / "stdlib.lua", work / "stdlib.lua")
            derived_cases = work / "CognitiveModelChecks.lua"
            derived_cases.write_text(original_cases.replace(old, new), encoding="utf-8")
            receipt["derivedFixtureSha256"] = sha(derived_cases)
            compile_result = subprocess.run([str(executables["javac"]), "-cp", str(engine), "-d", str(work),
                str(root / "tools/luacheck/LuaRun.java")], capture_output=True, text=True,
                encoding="utf-8", errors="replace", timeout=120)
            compile_text = compile_result.stdout + compile_result.stderr
            (output / "compile.log").write_text(compile_text, encoding="utf-8")
            receipt["compile"] = {"exit": compile_result.returncode, "logSha256": hashlib.sha256(compile_text.encode()).hexdigest()}
            assert compile_result.returncode == 0, compile_text

            def run(label, mode, *, m=model, c=cognition, marker=None):
                model_file = work / "model.lua"
                model_file.write_text(m, encoding="utf-8")
                cognition_file = work / "cognition.lua"
                cognition_file.write_text(c, encoding="utf-8")
                if mode == "model":
                    chunks, expression, expected = [model_file, derived_cases], "cognitiveModelCases()", "VALUE PASS 29 cases"
                else:
                    chunks = [root / "tools/cognition_checks/prelude.lua", root / REL / "SAO_Hash.lua", root / REL / "SAO_Labor.lua"]
                    if mode == "extended":
                        chunks += [HERE / "legacy_archive.lua", HERE / "restore_legacy.lua"]
                    chunks += [model_file, cognition_file, HERE / "experience.lua" if mode == "extended" else root / "tools/cognition_checks/runtime.lua"]
                    expression = "RESULT"
                    expected = "VALUE PASS extended cognition 985" if mode == "extended" else "VALUE PASS cognition runtime 49"
                started = time.monotonic()
                result = subprocess.run([str(executables["java"]), "-cp", str(engine) + os.pathsep + str(work),
                    "LuaRun", *map(str, chunks), "--", expression], cwd=work, capture_output=True,
                    text=True, encoding="utf-8", errors="replace", timeout=90)
                text = result.stdout + result.stderr
                (output / (label + ".log")).write_text(text, encoding="utf-8")
                good = (result.returncode != 0 and marker in text and "ERROR " in text) if marker else result.returncode == 0 and expected in text
                receipt["checks"].append({"name": label, "exit": result.returncode, "expectedFailure": marker, "passed": good,
                    "seconds": round(time.monotonic() - started, 3), "logSha256": hashlib.sha256(text.encode()).hexdigest(),
                    "result": next((line for line in text.splitlines() if line.startswith(("ERROR ", "VALUE "))), text[-1500:])})
                save_receipt(output, receipt)
                print(label + ": " + ("PASS" if good else "FAIL") + " " + receipt["checks"][-1]["result"], flush=True)
                assert good, label + "\n" + text[-6500:]

            run("existing-model-baseline", "model")
            run("existing-ledger-baseline", "ledger")
            run("extended-baseline", "extended")
            for index, (name, changes, expected) in enumerate(model_controls, 1):
                changed = model
                for before, after in changes:
                    assert changed.count(before) == 1, ("model mutation seam", name, before)
                    changed = changed.replace(before, after, 1)
                run("existing-model-control-" + str(index), "model", m=changed, marker=expected)
            for index, (name, before, after, marker) in enumerate(ledger_controls, 1):
                assert cognition.count(before) == 1, ("ledger mutation seam", name, before)
                run("existing-ledger-control-" + str(index), "ledger", c=cognition.replace(before, after, 1), marker="COGNITION:" + marker)
            for name, changes, marker in NEW_CONTROLS:
                values = {"model": model, "cog": cognition}
                for which, before, after in changes:
                    assert values[which].count(before) == 1, ("extended mutation seam", name, before)
                    values[which] = values[which].replace(before, after, 1)
                run("extended-control-" + name, "extended", m=values["model"], c=values["cog"], marker="EXTENDED:" + marker)
        receipt["inputsUnchanged"] = all(sha(Path(p)) == h for p, h in receipt["inputs"].items())
        assert receipt["inputsUnchanged"], "capability inputs changed during checks"
        receipt.update(status="PASS", invocations=len(receipt["checks"]), controls=81)
        print("PASS capability experience: 84 invocations, 81 controls; receipt " + str(output / "receipt.json"), flush=True)
        return 0
    except Exception as error:
        receipt.update(status="FAIL", error=str(error))
        print("FAIL capability experience: " + str(error), flush=True)
        return 1
    finally:
        save_receipt(output, receipt)
