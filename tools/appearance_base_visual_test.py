#!/usr/bin/env python3
"""Verify native visual ownership and production age updates on installed Kahlua."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "mod/42.20/media/lua/client/SAO_Appearance.lua"
CASES = ROOT / "tools/appearance_base_visual_cases.lua"
NATIVE = ROOT / "tools/appearance_base_visual/AppearanceBaseVisualProbe.java"
RUNNER = ROOT / "tools/luacheck/LuaRun.java"
IDENTITY = ROOT / "mod/42.20/media/lua/shared/SAO_Identity.lua"
SNAPSHOT = ROOT / "java/src/com/sao/engine/SAONativeSnapshot.java"
GAME = Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
JDK = Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def command(cmd: list[str], cwd: Path, log: Path) -> dict:
    result = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True,
                            timeout=120)
    log.write_text(result.stdout + result.stderr, encoding="utf-8")
    return {
        "exitCode": result.returncode,
        "pass": re.findall(r"(?m)^PASS (.+)$", result.stdout),
        "fail": re.findall(r"(?m)^FAIL (.+)$", result.stdout),
        "values": re.findall(r"(?m)^VALUE (.*)$", result.stdout),
        "logSha256": sha(log),
    }


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: appearance_base_visual_test.py <new-output-dir>")
    out = Path(sys.argv[1]).resolve()
    out.mkdir(parents=True, exist_ok=False)
    jar = GAME / "projectzomboid.jar"
    stdlib = GAME / "stdlib.lua"
    pins = [SOURCE, CASES, NATIVE, RUNNER, IDENTITY, SNAPSHOT, jar, stdlib]
    before = {str(path): sha(path) for path in pins}
    shutil.copy2(stdlib, out / "stdlib.lua")
    cp = str(jar) + ";" + str(out)
    compiled = command([str(JDK / "javac.exe"), "-encoding", "UTF-8", "-cp",
                        str(jar), "-d", str(out), str(RUNNER), str(NATIVE)],
                       out, out / "compile.log")
    if compiled["exitCode"]:
        print("compile failed", (out / "compile.log").read_text(encoding="utf-8"))
        return 2

    native = command([str(JDK / "java.exe"), "-cp", cp,
                      "AppearanceBaseVisualProbe"], out, out / "native.log")
    source = SOURCE.read_text(encoding="utf-8")
    controls = {
        "descriptor-only": (
            "pcall(function() visual = body:getHumanVisual() end)",
            "pcall(function() visual = body:getDescriptor():getHumanVisual() end)",
            "legacy/body-baseVisual"),
        "legacy-marker-gate": (
            "    local frac = A.greyness(rec.id, age)",
            "    if rec.greyApplied then return false end\n"
            "    local frac = A.greyness(rec.id, age)",
            "legacy/body-baseVisual"),
        "overwrite-dye": (
            "    if current and not sameColour(current, base)\n"
            "        and not sameColour(current, previous)\n"
            "        and not sameColour(current, target) then return false, nil, false end",
            "    if false then return false, nil, false end",
            "choice/dye-preserved"),
        "omit-descriptor-alignment": (
            "    syncDisplay(body, visual)",
            "    -- omitted descriptor alignment",
            "legacy/descriptor-aligned"),
    }

    def lua(name: str, path: Path) -> dict:
        return command([str(JDK / "java.exe"), "-cp", cp, "LuaRun", CASES,
                        str(path), "--", "appearanceBaseVisualCases()"],
                       out, out / f"{name}.log")

    production = lua("production", SOURCE)
    mutants = {}
    for name, (needle, replacement, _) in controls.items():
        assert source.count(needle) == 1, f"{name}: mutation anchor changed"
        mutant = out / f"{name}.lua"
        mutant.write_text(source.replace(needle, replacement), encoding="utf-8")
        mutants[name] = lua(name, mutant)

    assert before == {str(path): sha(path) for path in pins}, "source drift during probe"
    expected_cases = {
        "legacy/body-baseVisual", "legacy/descriptor-aligned",
        "legacy/natural-identity-preserved", "legacy/age-owned-record",
        "reload/same-age-idempotent", "reload/age-progresses",
        "reload/second-pass-idempotent", "choice/dye-preserved",
        "choice/natural-restored-ages", "child/body-style",
        "child/second-pass-idempotent", "missing-body-visual/fail-closed",
    }
    expected_native = {
        "native/constructor-distinct-baseVisual",
        "native/constructor-copied-style",
        "native/constructor-copied-colour",
        "native/descriptor-mutation-does-not-change-body",
        "native/descriptor-colour-does-not-change-body",
        "native/body-visual-is-display-authority",
        "native/body-colour-is-display-authority",
    }
    verdict = (native["exitCode"] == 0
               and set(native["pass"]) == expected_native
               and production["exitCode"] == 0
               and production["pass"] == []
               and production["fail"] == []
               and production["values"] == [f"{len(expected_cases)}:"])
    for name, result in mutants.items():
        expected = controls[name][2]
        verdict = verdict and result["exitCode"] == 0 \
            and len(result["values"]) == 1 \
            and result["values"][0].startswith(f"{len(expected_cases)}:") \
            and expected in result["values"][0]

    receipt = {
        "schema": "sao.appearance-base-visual/1",
        "status": "PASS" if verdict else "FAIL",
        "boundary": "installed native IsoPlayer constructor and installed Kahlua execute source with synthetic person/body visuals; no rendered game, save, peer F03, or deployment observation",
        "sourcePins": before,
        "native": native,
        "production": production,
        "inverses": mutants,
        "recordPersistenceBasis": "SAO_Identity stores plain person records in GlobalModData; appearanceGrey contains plain Lua tables/numbers",
    }
    (out / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n",
                                      encoding="utf-8")
    print("appearance baseVisual", receipt["status"])
    for name, result in [("native", native), ("production", production),
                         *mutants.items()]:
        print(name, "exit", result["exitCode"], "passes", len(result["pass"]),
              "failures", result["fail"], "values", result["values"])
    return 0 if verdict else 1


if __name__ == "__main__":
    raise SystemExit(main())
