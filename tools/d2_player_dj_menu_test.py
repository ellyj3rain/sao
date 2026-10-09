"""SAO-owned DJ player menu against a controlled native Kahlua context.

The selected installed menu and packaged original establish provenance, visible
labels and action signature. Booth, player and context are controlled here.
Loaded-game rendering, audio and save reopening have separate acceptance.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile

from d2_leisure_lifestyle_test import GAME, JDK, LS, ROOT

SOURCE = ROOT / "mod/42.20/media/lua/client/DJBoothContextMenu.lua"
VAULT = ROOT / "mod/42.20/media/SAOSources/LifestyleHobbies/media/lua/client/DJBoothContextMenu.lua"
OWNER = ROOT / "mod/42.20/media/lua/client/SAO_LeisureLifestyle.lua"
PRELUDE = ROOT / "tools/d2_player_dj/prelude.lua"
CASES = ROOT / "tools/d2_player_dj/cases.lua"
PROBE = ROOT / "tools/d2_leisure_music/MusicProbe.java"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    original = LS / "client/DJBoothContextMenu.lua"
    tracks = LS / "client/TimedActions/PlayDJBoothTracks.lua"
    action = LS / "shared/TimedActions/PlayDJBoothAction.lua"
    jars = [GAME / "projectzomboid.jar", *sorted((GAME / "jars").glob("*.jar"))]
    inputs = [Path(__file__), SOURCE, VAULT, OWNER, PRELUDE, CASES, PROBE,
              original, tracks, action, GAME / "stdlib.lua", *jars]
    before = {str(path): sha(path) for path in inputs}
    receipt = {"schema": "sao-d2-player-dj-menu/1", "status": "INCOMPLETE",
               "boundary": __doc__, "inputsBefore": before, "runs": []}

    def save():
        (out / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf8")

    def run(name, command, cwd):
        result = subprocess.run([str(item) for item in command], cwd=cwd,
                                capture_output=True, timeout=90)
        log = out / (name + ".log")
        log.write_bytes(result.stdout + result.stderr)
        receipt["runs"].append({"name": name, "exitCode": result.returncode,
                                "logSha256": sha(log)})
        save()
        return result.returncode, log.read_text(encoding="utf8", errors="replace")

    try:
        assert sha(original) == "8894fd69dcf5326dfd740d36b26c4fc95f2b1f7c01fdd6dd3e2b54e45256fa93"
        assert sha(VAULT) == sha(original)
        assert sha(original) in OWNER.read_text(encoding="utf8")
        selected = original.read_text(encoding="utf8")
        owned = SOURCE.read_text(encoding="utf8")
        for key in ("ContextMenu_Play_DJBooth", "ContextMenu_Play_DJBooth_Slow",
                    "ContextMenu_Play_DJBooth_Medium", "ContextMenu_Play_DJBooth_Fast",
                    "ContextMenu_Play_DJBooth_HouseMix",
                    "ContextMenu_DancingPartner_Enable_Option",
                    "ContextMenu_DancingPartner_Disable_Option"):
            assert key in selected and key in owned, key
        assert "function PlayDJBoothAction:new(character, DJBooth, soundFile, mode, length, xp, boredomReduction, stressReduction, actionType, isFail)" in action.read_text(encoding="utf8")
        for mode, sound, length in (("slow", "slow1", 215),
                                    ("medium", "medium1", 211),
                                    ("fast", "fast1", 230)):
            assert f'{{mode="{mode}",sound="{sound}",length={length}}}' in tracks.read_text(encoding="utf8")
        assert sha(SOURCE) != sha(VAULT), "player menu remains copied source"
        receipt["sourceChecks"] = 11

        controls = [
            ("save", "local wants=player:getModData().WantsToDance",
             "local wants=player:getModData().WantsToDance;player:getModData().WantsToDance=true",
             "menu_no_save_mutation"),
            ("lease", "return stationOwned(booth) or M.playerQueueOwner(booth)",
             "return false or M.playerQueueOwner(booth)", "npc_exact_station_lease"),
            ("player-queue", "return stationOwned(booth) or M.playerQueueOwner(booth) or (type(LS_DJBooth)",
             "return stationOwned(booth) or false or (type(LS_DJBooth)",
             "player_queue_claim_prevents_duplicate"),
            ("equipment", "and equippedHeadphones(player) and not embarrassed(player)",
             "and true and not embarrassed(player)", "equipment_requeried_at_click"),
            ("player-binding", 'getSpecificPlayer(playerIndex)==player',
             'true', "saved_character_binding_requeried"),
            ("power", "and assembled(booth) and powered(booth)",
             "and assembled(booth) and true", "power_requeried_at_click"),
            ("skill", "and player:getPerkLevel(Perks.Music)>=(config.level or 0)",
             "and true", "skill_requeried_at_click"),
            ("catalog", "local chosen\n    for _,track in ipairs(tracksFor(mode)) do",
             "local chosen={sound=sound,length=999}\n    for _,track in ipairs(tracksFor(mode)) do",
             "forged_track_refused"),
            ("stats", "local xp,boredom,stress=reductions(player)",
             "local xp,boredom,stress=0,0,0", "native_action_parameters"),
            ("preference", "if data and data.WantsToDance==nil then data.WantsToDance=true end",
             "if false then data.WantsToDance=true end", "explicit_action_initializes_preference"),
            ("refusal", "if not ok or not queued then pending[booth]=nil;return false end",
             "if false then pending[booth]=nil;return false end",
             "queue_refusal_has_no_choice_or_claim"),
        ]
        with tempfile.TemporaryDirectory(prefix="sao-player-dj-") as scratch:
            work = Path(scratch)
            shutil.copyfile(GAME / "stdlib.lua", work / "stdlib.lua")
            cp = os.pathsep.join(map(str, jars))
            code, log = run("compile", [JDK / "javac.exe", "-encoding", "UTF-8",
                                        "-cp", cp, "-d", work, PROBE], work)
            assert code == 0, log[-4000:]
            manifest = out / "empty-sources.tsv"
            manifest.write_text("", encoding="utf8")
            for name, old, replacement, marker in [
                    ("baseline", None, None, None), *controls]:
                variant = out / (name + "-menu.lua")
                source = owned
                if old is not None:
                    assert source.count(old) == 1, (name, source.count(old))
                    source = source.replace(old, replacement, 1)
                variant.write_text(source, encoding="utf8")
                code, log = run(name, [JDK / "java.exe",
                                       "--enable-native-access=ALL-UNNAMED",
                                       "-Djava.awt.headless=true", "-cp",
                                       str(work) + os.pathsep + cp,
                                       "MusicProbe", manifest, PRELUDE, variant, CASES], work)
                if marker:
                    assert code != 0 and "DJ_PLAYER:" + marker in log, (name, log[-6000:])
                else:
                    assert code == 0 and "PASS SAO player DJ menu " in log, log[-8000:]
                    receipt["checks"] = int(re.search(r"PASS SAO player DJ menu (\d+)", log)[1])
            inactive = out / "inactive.lua"
            inactive.write_text("__active=false\n", encoding="utf8")
            inactive_cases = out / "inactive-cases.lua"
            inactive_cases.write_text(
                'assert(__registered==nil,"external menu was overwritten")\n'
                'print("PASS external source coexistence")\n', encoding="utf8")
            code, log = run("external-active", [JDK / "java.exe",
                                                  "--enable-native-access=ALL-UNNAMED",
                                                  "-Djava.awt.headless=true", "-cp",
                                                  str(work) + os.pathsep + cp,
                                                  "MusicProbe", manifest, PRELUDE,
                                                  inactive, SOURCE, inactive_cases], work)
            assert code == 0 and "PASS external source coexistence" in log, log[-6000:]
        receipt["inverseControls"] = len(controls)
        receipt["inputsAfter"] = {str(path): sha(path) for path in inputs}
        assert before == receipt["inputsAfter"], "inputs changed during qualification"
        receipt["status"] = "PASS"
        save()
        print("PASS SAO player DJ menu", receipt["checks"], len(controls))
        return 0
    except Exception as error:
        receipt["status"] = "FAIL"
        receipt["error"] = str(error)
        save()
        raise


if __name__ == "__main__":
    raise SystemExit(main())
