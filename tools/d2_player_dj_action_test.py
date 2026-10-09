"""Owned DJ action lifecycle in native Kahlua with controlled game objects.

The selected installed action, owned source vault, native timed-action base,
track table and live queue implementation are pinned. Physical rendering and
loaded-world audio remain separate game acceptance.
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

ACTION = ROOT / "mod/42.20/media/lua/shared/TimedActions/PlayDJBoothAction.lua"
VAULT = ROOT / "mod/42.20/media/SAOSources/LifestyleHobbies/media/lua/shared/TimedActions/PlayDJBoothAction.lua"
OWNER = ROOT / "mod/42.20/media/lua/client/SAO_LeisureLifestyle.lua"
MENU = ROOT / "mod/42.20/media/lua/client/DJBoothContextMenu.lua"
PRELUDE = ROOT / "tools/d2_player_dj/action-prelude.lua"
CASES = ROOT / "tools/d2_player_dj/action-cases.lua"
PROBE = ROOT / "tools/d2_leisure_music/MusicProbe.java"
BASE_OBJECT = GAME / "media/lua/shared/ISBaseObject.lua"
BASE_ACTION = GAME / "media/lua/shared/TimedActions/ISBaseTimedAction.lua"
QUEUE = GAME / "media/lua/client/TimedActions/ISTimedActionQueue.lua"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    original = LS / "shared/TimedActions/PlayDJBoothAction.lua"
    tracks = LS / "client/TimedActions/PlayDJBoothTracks.lua"
    jars = [GAME / "projectzomboid.jar", *sorted((GAME / "jars").glob("*.jar"))]
    inputs = [Path(__file__), ACTION, VAULT, OWNER, MENU, PRELUDE, CASES,
              PROBE, original, tracks, BASE_OBJECT, BASE_ACTION, QUEUE,
              GAME / "stdlib.lua", *jars]
    before = {str(path): sha(path) for path in inputs}
    receipt = {"schema": "sao-d2-player-dj-action/1", "status": "INCOMPLETE",
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
        assert sha(original) == "6a8d3dd5767260e67ea96353a197ce577a3a023ccc7e2fd56151a2a8f55e7dac"
        assert sha(VAULT) == sha(original)
        assert sha(original) in OWNER.read_text(encoding="utf8")
        assert sha(ACTION) != sha(original), "physical action remains copied source"
        menu = MENU.read_text(encoding="utf8")
        assert "function M.playerQueueOwner(booth,action)" in menu
        assert "pending[booth]=action" in menu
        queue = QUEUE.read_text(encoding="utf8")
        assert "ISTimedActionQueue.hasAction = function(action)" in queue
        assert "return queue:indexOf(action) ~= -1" in queue
        base = BASE_OBJECT.read_text(encoding="utf8")
        assert 'o.Type = type' in base
        receipt["sourceChecks"] = 8

        controls = [
            ("queue", "or not playerOwns(self) or not exactQueueOwner(self)",
             "or not playerOwns(self) or false", "queue_refused"),
            ("track", "or not self.sourceLength\n",
             "or false\n", "source_track_refused"),
            ("track-revision", "or selectedTrack(self.sourceMode,self.sourceSound)~=self.sourceLength",
             "or false", "source_changed_refused"),
            ("actor", "or not playerOwns(self) or not exactQueueOwner(self)",
             "or false or not exactQueueOwner(self)", "player_slot_refused"),
            ("left-part", "or not partStillAt(booth,self.leftPart,true)",
             "or false", "native_left_part_refused"),
            ("front", "or self.character:getSquare()~=self.frontSquare",
             "or false", "not_at_front_refused"),
            ("power", "or not powered(self.stationSquare)",
             "or false", "station_power_refused"),
            ("npc", "or npcOwns(booth)", "or false", "npc_station_lease_refused"),
            ("update", "if not self.saoStarted or not self:isValid() then",
             "if false then", "power_outage_stops_without_credit"),
            ("completion", "local completed=self.saoStarted and self:isValid()",
             "local completed=true", "invalid_completion_no_credit"),
            ("start-failure", "local ok,reason=pcall(sourceStart,self)",
             "local ok,reason=true,nil;sourceStart(self)",
             "source_start_failure_returns"),
            ("volume", "if tonumber(manager:getMusicVolume())==0 then",
             "if true then", "user_volume_change_preserved"),
            ("type", 'o.saoOwner = "SAO.PlayerDJ"',
             'o.saoOwner = "ImportedDJ"', "owned_constructor"),
            ("terminal-replay", "function PlayDJBoothAction:perform()\n    if self.saoEnded then return end",
             "function PlayDJBoothAction:perform()\n    if false then return end",
             "terminal_replay_inert"),
            ("mic", "if LS_DJBooth.isPlayingMic~=true and self.musicOriginalVolume then",
             "if self.musicOriginalVolume then", "mic_takeover_preserves_mic"),
        ]
        source = ACTION.read_text(encoding="utf8")
        with tempfile.TemporaryDirectory(prefix="sao-player-dj-action-") as scratch:
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
                variant = out / (name + "-action.lua")
                current = source
                if old is not None:
                    assert current.count(old) == 1, (name, current.count(old))
                    current = current.replace(old, replacement, 1)
                variant.write_text(current, encoding="utf8")
                code, log = run(name, [JDK / "java.exe",
                                       "--enable-native-access=ALL-UNNAMED",
                                       "-Djava.awt.headless=true", "-cp",
                                       str(work) + os.pathsep + cp,
                                       "MusicProbe", manifest, PRELUDE,
                                       BASE_OBJECT, BASE_ACTION, variant, CASES], work)
                if marker:
                    assert code != 0 and "DJ_ACTION:" + marker in log, (name, log[-6500:])
                else:
                    assert code == 0 and "PASS SAO player DJ action " in log, log[-9000:]
                    receipt["checks"] = int(re.search(r"PASS SAO player DJ action (\d+)", log)[1])
        receipt["inverseControls"] = len(controls)
        receipt["inputsAfter"] = {str(path): sha(path) for path in inputs}
        assert before == receipt["inputsAfter"], "inputs changed during qualification"
        receipt["status"] = "PASS"
        save()
        print("PASS SAO player DJ action", receipt["checks"], len(controls))
        return 0
    except Exception as error:
        receipt["status"] = "FAIL"
        receipt["error"] = str(error)
        save()
        raise


if __name__ == "__main__":
    raise SystemExit(main())
