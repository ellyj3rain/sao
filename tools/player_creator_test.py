#!/usr/bin/env python3
"""Exact Kahlua checks for SAO's owned creation draft and native apply edge."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
GAME = Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
WORKSHOP = Path(r"C:\Program Files (x86)\Steam\steamapps\workshop\content\108600")
JDK = Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
MODEL = ROOT / "mod/42.20/media/lua/client/SAO_PlayerCreator.lua"
UI = ROOT / "mod/42.20/media/lua/client/SAO_PlayerCreatorUI.lua"
HOOKS = ROOT / "mod/42.20/media/lua/client/SAO_PlayerCreatorHooks.lua"
CASES = ROOT / "tools/player_creator_cases.lua"
RUNNER = ROOT / "tools/luacheck/LuaRun.java"
NATIVE_SOURCES = {
    GAME / "media/lua/client/OptionScreens/CharacterCreationAvatar.lua":
        ("914aa7b2d01bef383b8adf4c98c324e8cc67183dcac90019451dbf9c3395d73e",
         ("function CharacterCreationAvatar:new(x, y, width, height)",
          "function CharacterCreationAvatar:setSurvivorDesc(survivorDesc)",
          "self.avatarPanel:setSurvivorDesc(survivorDesc)")),
    GAME / "media/lua/client/OptionScreens/CharacterCreationMain.lua":
        ("a058e7c6294c70f4969fffd5a7b135c4b8a3a4bb340721aa7c80ac3690d7f489",
         ("function CharacterCreationMain:onOptionMouseDown(button, x, y)",
          "self:initPlayer();",
          "self.forenameEntry:getText() .. \" \" .. self.surnameEntry:getText()")),
    GAME / "media/lua/client/OptionScreens/NewGameScreen.lua":
        ("926a073d6299d92ce7f9de95ada3ef0049d1f92b722460177c9b0dde7600604d",
         ("mainScreenInstance.createWorld = true",)),
    GAME / "media/lua/client/OptionScreens/MainScreen.lua":
        ("f89d351830fcb0050cfc10bc7a7e1a216a260b4731fe0ac34da9bcd4269352e5",
         ("MainScreen.instance.createWorld = false",)),
    GAME / "media/lua/client/OptionScreens/CoopCharacterCreationMain.lua":
        ("6ddae63880be661c9b79f124165bcafd5eb05fd39054fd34b87eb7740b7a7260",
         ("function CoopCharacterCreationMain:onOptionMouseDown(button, x, y)",
          "CoopCharacterCreation.instance:accept()")),
    WORKSHOP / "3403180543/mods/BanditsWeekOne/42.20/media/lua/client/OptionScreens/CharacterCreationMainPatch.lua":
        ("6d51c6a5bfbe8f73b12e3b2464d4ff25a2b1b93cb74ce54bf09cac12771a4316",
         ("function CharacterCreationMain:onOptionMouseDown2(button, x, y)",
          'self.variantButton.internal = "VARIANT"',
          "MainScreen.instance.variantMain:setVisible(true, joypadData)")),
    WORKSHOP / "3403180543/mods/BanditsWeekOne/42.20/media/lua/client/OptionScreens/VariantMain.lua":
        ("beed5054518e297126aa1fdcd5c4618003fa97e326b4bfd5053eb7f5b4edfc04",
         ("function VariantMain:onOptionMouseDown(button, x, y)",
          "SandboxVars.BanditsWeekOne.Variant = self.variantListBox.selected")),
    WORKSHOP / "3773911887/mods/ThisIsYourLife/42/media/lua/client/ThisIsYourLife/TIYLFlow.lua":
        ("eb77285867da153630027400df40b313e4cb46196635790c243536086abd0fe4",
         ("function CharacterCreationMain:setVisible(visible, joypadData)",
          "self:onOptionMouseDown(self.playButton, 0, 0)",
          "Events.OnCreatePlayer.Add(persistLife)")),
    WORKSHOP / "3782021029/mods/scenarios/42/media/lua/shared/WhereIWas/ScenarioConfig.lua":
        ("ac805b8a11ab6b0a6274201a9f274ac2a2433e9b3d500efdda855b943b813c1d",
         ("function ScenarioConfig.getActiveScenario()",
          "local selected = options and options.ActiveScenario")),
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: player_creator_test.py <new-output-dir>")
    out = Path(sys.argv[1]).resolve()
    out.mkdir(parents=True, exist_ok=False)
    paths = [MODEL, UI, HOOKS, CASES, RUNNER,
             GAME / "projectzomboid.jar", GAME / "stdlib.lua",
             *NATIVE_SOURCES]
    before = {str(path): sha(path) for path in paths}
    for path, (expected, patterns) in NATIVE_SOURCES.items():
        assert before[str(path)] == expected, f"selected native source changed: {path}"
        source = path.read_text(encoding="utf-8")
        for pattern in patterns:
            assert pattern in source, f"required native seam changed: {path}: {pattern}"
    shutil.copy2(GAME / "stdlib.lua", out / "stdlib.lua")
    classpath = str(GAME / "projectzomboid.jar") + ";" + str(out)
    compile_result = subprocess.run(
        [str(JDK / "javac.exe"), "-encoding", "UTF-8", "-cp",
         str(GAME / "projectzomboid.jar"), "-d", str(out), str(RUNNER)],
        cwd=out, capture_output=True, text=True, timeout=120,
    )
    (out / "compile.log").write_text(
        compile_result.stdout + compile_result.stderr, encoding="utf-8")
    if compile_result.returncode:
        print(compile_result.stderr)
        return 2

    def run(name: str, model: Path) -> dict:
        result = subprocess.run(
            [str(JDK / "java.exe"), "-cp", classpath, "LuaRun",
             CASES, model, UI, HOOKS, "--", "fixtureCases()"],
            cwd=out, capture_output=True, text=True, timeout=120,
        )
        log = out / (name + ".log")
        log.write_text(result.stdout + result.stderr, encoding="utf-8")
        return {
            "name": name, "exitCode": result.returncode,
            "pass": [x[5:] for x in result.stdout.splitlines()
                     if x.startswith("PASS ")],
            "fail": [x[5:] for x in result.stdout.splitlines()
                     if x.startswith("FAIL ")],
            "value": re.findall(r"(?m)^VALUE (.+)$", result.stdout),
            "logSha256": sha(log),
            "error": [x for x in result.stdout.splitlines()
                      if x.startswith("ERROR ")],
        }

    controls = {
        "ignore-required-history": (
            'if background == "" then return false, "background-required" end',
            'if false then return false, "background-required" end',
            "ui/history-required",
        ),
        "keep-weekone-default": (
            "SandboxVars.BanditsWeekOne.EventFinalSolution = false",
            "SandboxVars.BanditsWeekOne.EventFinalSolution = true",
            "native/new-world-continues",
        ),
        "accept-other-body": (
            "or native.forename ~= pending.context.forename\n"
            "        or native.surname ~= pending.context.surname\n",
            "or false\n"
            "        or false\n",
            "native/mismatch-refused",
        ),
        "forget-player-receipt": (
            "data.SAOCreationReceipt = copy(receipt)",
            "data.SAOCreationReceipt = nil",
            "identity/native-receipt",
        ),
        "forget-world-record": (
            "store.characters[characterId] = copy(receipt)",
            "store.characters[characterId] = nil",
            "identity/world-and-standing",
        ),
        "forget-world-choice-owner": (
            "local called, accepted = pcall(SAO.Nuke.applyCreatorChoice,\n"
            "            pending.draft.nukeChoice, receipt)",
            "local called, accepted = true, true",
            "identity/world-and-standing",
        ),
        "accept-group-owner-failure": (
            'if not joined or accepted ~= true or type(token) ~= "table" then',
            'if false then',
            "identity/group-refusal-no-partial-record",
        ),
        "skip-group-rollback": (
            "if groupToken then\n"
            "                local rolled, undone = pcall(",
            "if false then\n"
            "                local rolled, undone = pcall(",
            "identity/nuke-refusal-no-partial-record",
        ),
        "accept-other-descriptor": (
            "or native.descriptorId ~= pending.context.nativeDescriptorId then",
            "or false then",
            "native/same-name-other-descriptor-refused",
        ),
        "accept-other-slot": (
            "or playerIndex ~= pending.context.playerSlot then",
            "or false then",
            "native/same-name-other-slot-refused",
        ),
        "accept-other-account": (
            "and accountKey ~= pending.context.accountKey then",
            "and false then",
            "native/same-name-other-account-refused",
        ),
        "lose-explicit-off": (
            "return group[key]",
            "return group[key] or nil",
            "draft/optional-nuke-default-off",
        ),
        "overwrite-prior-character": (
            'if store.characters[characterId] ~= nil then',
            'if false then',
            "identity/character-collision-preserves-prior-save",
        ),
        "ignore-native-false-return": (
            "if not advanced or result == false then",
            "if not advanced then",
            "transition/false-result-restores-sandbox",
        ),
    }
    runs = [run("production", MODEL)]
    source = MODEL.read_text(encoding="utf-8")
    for name, (needle, replacement, _) in controls.items():
        assert source.count(needle) == 1, name
        candidate = out / (name + ".lua")
        candidate.write_text(source.replace(needle, replacement),
                             encoding="utf-8")
        runs.append(run(name, candidate))

    assert before == {str(path): sha(path) for path in paths}, (
        "source changed while checking"
    )
    production = runs[0]
    verdict = (
        production["exitCode"] == 0
        and production["value"] == ["49:0:"]
    )
    for item in runs[1:]:
        expected = controls[item["name"]][2]
        verdict = (
            verdict and item["exitCode"] == 0
            and len(item["value"]) == 1
            and expected in item["value"][0]
        )
    receipt = {
        "schema": "sao.player-creator/1",
        "status": "PASS" if verdict else "FAIL",
        "boundary": "installed Kahlua executes production model/UI/hooks with synthetic native menu, body, save and ModData ports; no rendered game acceptance",
        "sourcePins": before,
        "runs": runs,
    }
    (out / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n",
                                      encoding="utf-8")
    for item in runs:
        print(item["name"], item["exitCode"], item["value"], item["fail"],
              item["error"])
    return 0 if verdict else 1


if __name__ == "__main__":
    raise SystemExit(main())
