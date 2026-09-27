#!/usr/bin/env python3
"""Border 206: exact failed home attempts reconsider without an immediate loop."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True


def module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--controller", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--baseline-only", action="store_true")
    args = parser.parse_args(argv)
    root = args.root.resolve()
    source_path = (args.controller or root / "mod/42.20/media/lua/client/SAO_Controller.lua").resolve()
    game = Path(os.environ.get("PZ_DIR", r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"))
    jdk = Path(os.environ.get("JDK_BIN", r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin"))
    if not all(p.is_file() for p in (game / "projectzomboid.jar", game / "stdlib.lua", jdk / "java.exe", jdk / "javac.exe")):
        print("Border 206 SKIPPED: installed engine/JDK unavailable")
        return 0
    fixture = module(root / "tools/flee_continuity_test.py", "home_route_prelude")
    support = Path(__file__).resolve().parent / "home_route_checks"
    controls = module(support / "controls.py", "home_route_controls")
    source = source_path.read_text(encoding="utf-8-sig")
    expose = "Ctl.__homeRouteDecide=decideHomeAndEquipment\nCtl.__homeRouteMovement=updateMovement\nCtl.__homeRouteNeeds=decideNeedsAndCompanion\nCtl.__homeRouteThreat=decideThreat\nCtl.__homeRouteTick=function(t) tickCount=t end\nreturn Ctl\n"
    if source.count("return Ctl\n") != 1:
        raise AssertionError("Controller probe export seam drifted")
    receipt = {"schema": "sao-home-route-check/1", "border": 206, "status": "running", "cases": 0, "controls": []}
    sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
    inputs = [source_path, root / "mod/42.20/media/lua/client/SAO_Locomotion.lua",
              root / "mod/42.20/media/lua/shared/SAO_Identity.lua",
              root / "tools/flee_continuity_test.py", root / "tools/luacheck/LuaRun.java",
              support / "probe.lua", support / "controls.py", Path(__file__).resolve()]
    receipt["sources"] = {p.name: sha(p) for p in inputs}
    receipt["engineSha256"] = sha(game / "projectzomboid.jar")
    output = args.output.resolve() if args.output else None
    if output:
        output.mkdir(parents=True, exist_ok=True)
    try:
        with tempfile.TemporaryDirectory(prefix="sao-home-route-", dir=output) as tmp:
            work = Path(tmp)
            cp = os.pathsep.join([str(game / "projectzomboid.jar"), str(work)])
            def run(command, label):
                result = subprocess.run([str(v) for v in command], cwd=work, text=True,
                                        encoding="utf-8", errors="replace", capture_output=True, timeout=60)
                text = result.stdout + result.stderr
                if output:
                    (output / (label + ".log")).write_text(text, encoding="utf-8")
                return result.returncode, text
            code, text = run([jdk / "javac.exe", "-encoding", "UTF-8", "-cp", cp, "-d", work,
                              root / "tools/luacheck/LuaRun.java"], "compile")
            if code:
                raise AssertionError(text)
            shutil.copy2(game / "stdlib.lua", work / "stdlib.lua")
            (work / "prelude.lua").write_text(fixture.PRELUDE, encoding="utf-8")
            shutil.copy2(root / "mod/42.20/media/lua/shared/SAO_Identity.lua", work / "identity.lua")
            shutil.copy2(root / "mod/42.20/media/lua/client/SAO_Locomotion.lua", work / "locomotion.lua")
            shutil.copy2(support / "probe.lua", work / "probe.lua")
            def probe(candidate, label):
                (work / "controller.lua").write_text(candidate.replace("return Ctl\n", expose, 1), encoding="utf-8")
                return run([jdk / "java.exe", "-cp", cp, "LuaRun", "prelude.lua", "identity.lua", "locomotion.lua",
                            "controller.lua", "probe.lua", "--", "RESULT"], label)
            code, text = probe(source, "production")
            found = re.search(r"VALUE PASS home route (\d+)", text)
            if code or not found:
                raise AssertionError("production: " + text)
            receipt["cases"] = int(found.group(1))
            if not args.baseline_only:
                for label, candidate, marker in controls.variants(source):
                    code, text = probe(candidate, label)
                    if not code or "HOME_ROUTE:" + marker not in text:
                        raise AssertionError(label + " did not fail its required assertion: " + text)
                    receipt["controls"].append({"name": label, "assertion": marker, "rejected": True})
        receipt["status"] = "baseline-only" if args.baseline_only else "passed"
        print(f"Border 206 PASS: {receipt['cases']} assertions; {len(receipt['controls'])} rejected source controls")
        return 0
    except (AssertionError, OSError, subprocess.SubprocessError) as error:
        receipt["status"], receipt["error"] = "failed", str(error)
        print("Border 206 FAIL: " + str(error))
        return 1
    finally:
        if output:
            (output / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
