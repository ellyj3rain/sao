#!/usr/bin/env python3
"""Installed Kahlua layout and input exercise for the owned creator panel."""
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
UI = ROOT / "mod/42.20/media/lua/client/SAO_PlayerCreatorUI.lua"
BASE = ROOT / "tools/player_creator_cases.lua"
CASES = ROOT / "tools/player_creator_layout_cases.lua"
RUNNER = ROOT / "tools/luacheck/LuaRun.java"
NATIVE = {
    "media/lua/client/OptionScreens/CharacterCreationAvatar.lua":
        ("914aa7b2d01bef383b8adf4c98c324e8cc67183dcac90019451dbf9c3395d73e",
         "function CharacterCreationAvatar:setSurvivorDesc(survivorDesc)"),
    "media/lua/client/OptionScreens/MainScreen.lua":
        ("f89d351830fcb0050cfc10bc7a7e1a216a260b4731fe0ac34da9bcd4269352e5",
         "function MainScreen:onKeyRelease(key)"),
    "media/lua/client/ISUI/ISPanelJoypad.lua":
        ("8e7a2afbe11bb826bd3a2b8e08501790adba772171fd5e747af6cc520a60f060",
         "function ISPanelJoypad:setVisible(visible, joypadData)"),
    "media/lua/client/ISUI/ISUIElement.lua":
        ("2de4720f995ae35e76a1465c6690ad17fe272e33dec3b106e49c475310440f8f",
         "function ISUIElement:addChild(otherElement)"),
    "media/lua/client/ISUI/ISButton.lua":
        ("5a4101bb351f3fc5d20de884b0d15692d9048d72ceff0d8b4e0420800fac3011",
         "function ISButton:setTitle(title)"),
    "media/lua/client/ISUI/ISTextEntryBox.lua":
        ("94d10e1583f68bcba635cd93f7921df85be4d8223ca8a99c67e00c650bf5d3e1",
         "function ISTextEntryBox:setMultipleLine(multiple)"),
}
SOURCE_LABELS = {
    "3403180543/mods/BanditsWeekOne/42.20/media/lua/client/OptionScreens/VariantMain.lua":
        ("beed5054518e297126aa1fdcd5c4618003fa97e326b4bfd5053eb7f5b4edfc04",
         "self.variantListBox:addItem(id, { index = id, name = variant.name"),
    "3773911887/mods/ThisIsYourLife/42/media/lua/shared/ThisIsYourLife/TIYLOrigins.lua":
        ("040caf99a47b3511a19ce29d8a88af231a3f3a7574cc2d5fe8d676bc4ba7e2bf",
         "function TIYL.Origins.getText(origin, field)"),
    "3782021029/mods/scenarios/42/media/lua/shared/Translate/EN/Sandbox.json":
        ("1f13fa6e69958cfebd4c0c5c04c9477883a82ed85f954128f4713b42727ca0bd",
         '"Sandbox_WhereIWas.ActiveScenario_option4": "Police Response"'),
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: player_creator_layout_test.py <new-output-dir>")
    out = Path(sys.argv[1]).resolve()
    out.mkdir(parents=True, exist_ok=False)
    paths = [UI, BASE, CASES, RUNNER, GAME / "projectzomboid.jar",
             GAME / "stdlib.lua", *(GAME / path for path in NATIVE),
             *(WORKSHOP / path for path in SOURCE_LABELS)]
    before = {str(path): sha(path) for path in paths}
    for relative, (expected, seam) in NATIVE.items():
        path = GAME / relative
        assert before[str(path)] == expected, f"installed API source moved: {path}"
        assert seam in path.read_text(encoding="utf-8"), seam
    for relative, (expected, seam) in SOURCE_LABELS.items():
        path = WORKSHOP / relative
        assert before[str(path)] == expected, f"selected source moved: {path}"
        assert seam in path.read_text(encoding="utf-8"), seam

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

    def run(name: str, source: Path) -> dict:
        result = subprocess.run(
            [str(JDK / "java.exe"), "-cp", classpath, "LuaRun",
             BASE, CASES, source, "--", "fixtureCreatorLayout()"],
            cwd=out, capture_output=True, text=True, timeout=120,
        )
        log = out / (name + ".log")
        log.write_text(result.stdout + result.stderr, encoding="utf-8")
        values = re.findall(r"(?m)^VALUE (.*)$", result.stdout)
        tally = values[0].split(":", 2) if len(values) == 1 else []
        return {
            "name": name, "exitCode": result.returncode,
            "value": values,
            "passed": int(tally[0]) if len(tally) == 3 else None,
            "failed": int(tally[1]) if len(tally) == 3 else None,
            "fail": tally[2].split(",") if len(tally) == 3
                and tally[2] else [],
            "error": [line for line in result.stdout.splitlines()
                      if line.startswith("ERROR ")],
            "logSha256": sha(log),
        }

    source = UI.read_text(encoding="utf-8")
    inverses = {
        "footer-overlap": (
            "or footerY - 16", "or footerY + 4",
            "geometry/short-wide-340"),
        "drop-scenario-context": (
            '{"Scenario: " .. labelValue(self.nativeLabels.scenario\n'
            '                or ctx.scenario), rightX, 115}',
            '{"Other: " .. labelValue(self.nativeLabels.scenario\n'
            '                or ctx.scenario), rightX, 115}',
            "context/narrow-404"),
        "drop-native-scenario-label": (
            "labels.scenario = translated",
            "labels.scenario = nil",
            "context/native-display-labels-keep-ids"),
        "preview-wrong-descriptor": (
            "item:setSurvivorDesc(main.desc)",
            "item:setSurvivorDesc({})", "native-preview/desktop-720"),
        "enable-event-unselected": (
            'selectButton(self.saoButton, self.draft.nukeChoice == "SAO")',
            "selectButton(self.saoButton, false)",
            "event/explicit-enable-state"),
        "restore-other-body": (
            "and C.unconfirmed.context.nativeDescriptorId\n"
            "            == draft.context.nativeDescriptorId",
            "and true", "reopen/foreign-descriptor-draft-refused"),
        "split-utf16-pair": (
            "text = text:sub(1, cut - 1)",
            "text = text:sub(1, #text - 1)",
            "context/utf16-truncation"),
        "show-event-on-history-page": (
            "self.noneButton:setVisible(not self.compact or self.page == 2)",
            "self.noneButton:setVisible(true)",
            "page/history-short-wide-340"),
    }
    runs = [run("production", UI)]
    for name, (needle, replacement, _) in inverses.items():
        assert source.count(needle) == 1, name
        mutation = out / (name + ".lua")
        mutation.write_text(source.replace(needle, replacement),
                            encoding="utf-8")
        runs.append(run(name, mutation))
    assert before == {str(path): sha(path) for path in paths}, (
        "creator or installed source changed during checks"
    )
    production = runs[0]
    verdict = (production["exitCode"] == 0
               and production["passed"] == 38
               and production["failed"] == 0)
    for run_result in runs[1:]:
        expected = inverses[run_result["name"]][2]
        verdict = (verdict and run_result["exitCode"] == 0
                   and run_result["failed"] > 0
                   and expected in run_result["fail"])
    receipt = {
        "schema": "sao.player-creator-layout/1",
        "status": "PASS" if verdict else "FAIL",
        "boundary": "production creator UI in installed Kahlua with synthetic ISUI geometry, descriptor and key/joypad ports; native Lua API sources pinned; no pixels, font atlas, game launch, save or rendered acceptance",
        "sourcePins": before,
        "runs": runs,
    }
    (out / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n",
                                      encoding="utf-8")
    for item in runs:
        print(item["name"], item["exitCode"], item["value"],
              item["fail"], item["error"])
    return 0 if verdict else 1


if __name__ == "__main__":
    raise SystemExit(main())
