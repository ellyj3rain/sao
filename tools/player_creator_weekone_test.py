#!/usr/bin/env python3
"""Cross-repository Kahlua exercise of P005 and SAO's applied creator."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
P = Path(r"C:\Users\jleyv\Peanut Butter\AI Assisted Software Engineering Mass Repository\Projects\mod-patches")
GAME = Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
WORKSHOP = Path(r"C:\Program Files (x86)\Steam\steamapps\workshop\content\108600")
JDK = Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
UPSTREAM = WORKSHOP / "3403180543/mods/BanditsWeekOne/42.20/media/lua/client/OptionScreens/VariantMain.lua"
PATCH = P / "patches/005-weekone-choice-continuity/patch.lua"
FIXTURE_P = P / "tools/weekone_choice_continuity05_test.lua"
FIXTURE = ROOT / "tools/player_creator_weekone_cases.lua"
MODEL = ROOT / "mod/42.20/media/lua/client/SAO_PlayerCreator.lua"
UI = ROOT / "mod/42.20/media/lua/client/SAO_PlayerCreatorUI.lua"
STANDING = ROOT / "mod/42.20/media/lua/shared/SAO_Standing.lua"
COMMUNICATION = ROOT / "mod/42.20/media/lua/shared/SAO_Communication.lua"
OBJECTIVES = ROOT / "mod/42.20/media/lua/client/SAO_PlayerObjectives.lua"
NUKE = ROOT / "mod/42.20/media/lua/client/SAO_Nuke.lua"
RUNNER = ROOT / "tools/luacheck/LuaRun.java"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def method(source: str, signature: str) -> str:
    pattern = r"(?ms)^" + re.escape(signature) + r"\r?\n.*?^end(?:\r?\n|$)"
    result = re.search(pattern, source)
    assert result and len(re.findall(
        r"(?m)^" + re.escape(signature), source)) == 1
    return result.group(0)


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: player_creator_weekone_test.py <new-output-dir>")
    out = Path(sys.argv[1]).resolve()
    out.mkdir(parents=True, exist_ok=False)
    paths = [UPSTREAM, PATCH, FIXTURE_P, FIXTURE, STANDING,
             COMMUNICATION, OBJECTIVES, NUKE, MODEL, UI, RUNNER,
             GAME / "projectzomboid.jar", GAME / "stdlib.lua"]
    before = {str(path): sha(path) for path in paths}
    assert before[str(UPSTREAM)] == (
        "beed5054518e297126aa1fdcd5c4618003fa97e326b4bfd5053eb7f5b4edfc04"
    )
    selected = method(UPSTREAM.read_text(encoding="utf-8"),
                      "function VariantMain:onOptionMouseDown(button, x, y)")
    selected_path = out / "selected-bwo-variant.lua"
    selected_path.write_text(selected + "\n", encoding="utf-8")
    shutil.copy2(GAME / "stdlib.lua", out / "stdlib.lua")
    classpath = str(GAME / "projectzomboid.jar") + ";" + str(out)
    compiled = subprocess.run(
        [str(JDK / "javac.exe"), "-encoding", "UTF-8", "-cp",
         str(GAME / "projectzomboid.jar"), "-d", str(out), str(RUNNER)],
        cwd=out, capture_output=True, text=True, timeout=120,
    )
    (out / "compile.log").write_text(
        compiled.stdout + compiled.stderr, encoding="utf-8")
    if compiled.returncode:
        print(compiled.stderr)
        return 2

    def run(name: str, patch: Path, model: Path = MODEL) -> dict:
        done = subprocess.run(
            [str(JDK / "java.exe"), "-cp", classpath, "LuaRun",
             FIXTURE_P, selected_path, FIXTURE, STANDING,
             COMMUNICATION, OBJECTIVES, NUKE, model, UI, patch,
             "--", "fixtureCrossRepo()"],
            cwd=out, capture_output=True, text=True, timeout=120,
        )
        log = out / (name + ".log")
        log.write_text(done.stdout + done.stderr, encoding="utf-8")
        return {
            "name": name, "exitCode": done.returncode,
            "value": re.findall(r"(?m)^VALUE (.*)$", done.stdout),
            "error": [line for line in done.stdout.splitlines()
                      if line.startswith("ERROR ")],
            "logSha256": sha(log),
        }

    source = PATCH.read_text(encoding="utf-8")
    inverses = {
        "skip-owned-creator": (
            "and creator.beforeWorldTransition(self, continueNative) then",
            "and false then", "creator-before-transition"),
        "lose-selected-variant": (
            "SandboxVars.BanditsWeekOne.Variant = self.variantListBox.selected",
            "SandboxVars.BanditsWeekOne.Variant = 1",
            "native-selected-variant"),
    }
    runs = [run("production", PATCH)]
    for name, (needle, replacement, _) in inverses.items():
        assert source.count(needle) == 1, name
        changed = out / (name + ".lua")
        changed.write_text(source.replace(needle, replacement),
                           encoding="utf-8")
        runs.append(run(name, changed))
    model_source = MODEL.read_text(encoding="utf-8")
    model_inverses = {
        "skip-group-refusal": (
            'if not joined or accepted ~= true or type(token) ~= "table" then',
            'if false then', "production-group-refusal-has-no-world-choice"),
        "skip-group-rollback": (
            "if groupToken then\n"
            "                local rolled, undone = pcall(",
            "if false then\n"
            "                local rolled, undone = pcall(",
            "production-nuke-refusal-rolls-back-group"),
        "lose-start-babe-choice": (
            "weekOneStartBabe = startBabeChoice,",
            "weekOneStartBabe = nil,",
            "native-application-receipt"),
    }
    for name, (needle, replacement, _) in model_inverses.items():
        assert model_source.count(needle) == 1, name
        changed = out / (name + ".lua")
        changed.write_text(model_source.replace(needle, replacement),
                           encoding="utf-8")
        runs.append(run(name, PATCH, changed))
    assert before == {str(path): sha(path) for path in paths}, (
        "source changed during cross-repository exercise"
    )
    verdict = runs[0]["exitCode"] == 0 and runs[0]["value"] == [""]
    for item in runs[1:]:
        controls = inverses | model_inverses
        verdict = (
            verdict and item["exitCode"] == 0
            and len(item["value"]) == 1
            and controls[item["name"]][2] in item["value"][0]
        )
    receipt = {
        "schema": "sao.player-creator-weekone/1",
        "status": "PASS" if verdict else "FAIL",
        "boundary": "exact P005 and selected installed Week One NEXT execute with production SAO Standing, Communication, PlayerObjectives, Nuke and creator model/UI under synthetic native menu and body ports; no game/rendered/save observation",
        "sourcePins": before | {str(selected_path): sha(selected_path)},
        "runs": runs,
    }
    (out / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n",
                                      encoding="utf-8")
    for item in runs:
        print(item["name"], item["exitCode"], item["value"], item["error"])
    return 0 if verdict else 1


if __name__ == "__main__":
    raise SystemExit(main())
