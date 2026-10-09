#!/usr/bin/env python3
"""Exact Week One body and native speech through the common person surface."""
from pathlib import Path
import hashlib
import json
import subprocess
import tempfile

from weekone_continuity_test import GAME, JDK, ROOT
from weekone_chat_continuity_test import PRELUDE, FIXTURE

WEEK = ROOT / "mod/42.20/media/lua/client/SAO_WeekOneContinuity.lua"
COMM = ROOT / "mod/42.20/media/lua/shared/SAO_Communication.lua"
MOUSE = ROOT / "mod/42.20/media/lua/client/SAO_MousecatInteraction.lua"
CASES = ROOT / "tools/weekone_common_speech_cases.lua"

CONTROLS = (
    ("missing-source-controller-fail-closed", MOUSE,
     'if not (weekOne and type(weekOne.sourceBodyFor) == "function"',
     'if false and not (weekOne and type(weekOne.sourceBodyFor) == "function"',
     "missing source controller fell through"),
    ("one-native-utterance", MOUSE,
     'local ok, received, reason = pcall(weekOne.onSourceChat,',
     'player:Say(text)\n        local ok, received, reason = pcall(weekOne.onSourceChat,',
     "common speech did not reach one heard person"),
    ("nearest-global-cap", MOUSE,
     'return a.distance < b.distance',
     'return a.distance > b.distance',
     "final global cap kept far source"),
    ("physical-source-resolution", COMM,
     'return weekOneBodyFor(id, rec)',
     'return nil',
     "exact source body absent from common physical resolver"),
    ("native-weekone-hearing", COMM,
     'return ok and heard == true\n    end\n    local a, b = bodyFor(fromId)',
     'return true\n    end\n    local a, b = bodyFor(fromId)',
     "unheard source person received or emitted common speech"),
    ("ordinary-owner-actor", MOUSE,
     '"Registered controller received the utterance; subsequent action remains its own evidence.", fromId, correlation)',
     '"Registered controller received the utterance; subsequent action remains its own evidence.", id, correlation)',
     "ordinary owner receipt attributed player speech to recipient"),
    ("ordinary-inactive-actor", MOUSE,
     '"This person is not an active companion; no follow or hold state was assigned.", fromId, correlation)',
     '"This person is not an active companion; no follow or hold state was assigned.", id, correlation)',
     "ordinary inactive-companion refusal attributed player speech to recipient"),
    ("ordinary-refusal-actor", MOUSE,
     'record(id, "utterance-refused", message, fromId, correlation)',
     'record(id, "utterance-refused", message, id, correlation)',
     "ordinary judged refusal attributed player speech to recipient"),
    ("ordinary-accepted-actor", MOUSE,
     '"Accepted " .. kind .. " through SAO.Command; movement is still observed independently.", fromId, correlation)',
     '"Accepted " .. kind .. " through SAO.Command; movement is still observed independently.", id, correlation)',
     "ordinary accepted order attributed player speech to recipient"),
)


def run_probe(work: Path, sources: dict[Path, str]) -> tuple[int, str]:
    for source, code in sources.items():
        (work / source.name).write_text(code, encoding="utf-8")
    run = subprocess.run(
        [str(JDK / "java.exe"), "-cp", f"{GAME / 'projectzomboid.jar'};{work}",
         "LuaRun", str(work / "prelude.lua"), str(work / WEEK.name),
         str(work / COMM.name), str(work / MOUSE.name), str(CASES),
         "--", "__safeCommon()"], cwd=work, capture_output=True,
        text=True, timeout=90)
    return run.returncode, run.stdout + run.stderr


def main() -> int:
    for path in (WEEK, COMM, MOUSE, CASES, GAME / "projectzomboid.jar",
                 GAME / "stdlib.lua", JDK / "javac.exe", JDK / "java.exe"):
        if not path.is_file():
            raise RuntimeError(f"missing exact source or installed engine: {path}")
    source = {path: path.read_text(encoding="utf-8")
              for path in (WEEK, COMM, MOUSE)}
    receipt = {"status": "OPEN", "sourcePins": [
        {"path": str(path), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
        for path in (WEEK, COMM, MOUSE, CASES)], "runs": []}
    with tempfile.TemporaryDirectory(prefix="sao-weekone-common-") as temp:
        work = Path(temp)
        (work / "stdlib.lua").write_bytes((GAME / "stdlib.lua").read_bytes())
        (work / "prelude.lua").write_text(PRELUDE + FIXTURE, encoding="utf-8")
        build = subprocess.run([str(JDK / "javac.exe"), "-cp",
            str(GAME / "projectzomboid.jar"), "-d", str(work),
            str(ROOT / "tools/luacheck/LuaRun.java")], capture_output=True,
            text=True, timeout=120)
        if build.returncode:
            raise RuntimeError("installed Kahlua probe compile failed: " + build.stderr)
        code, output = run_probe(work, source)
        receipt["runs"].append({"name": "current", "exit": code,
                                 "output": output[-1800:]})
        if code or "VALUE PASS" not in output:
            raise RuntimeError("common speech current failed: " + output)
        for name, path, before, after, expected in CONTROLS:
            if source[path].count(before) != 1:
                raise RuntimeError(f"mutation anchor drift: {name}")
            mutated = dict(source)
            mutated[path] = source[path].replace(before, after, 1)
            code, output = run_probe(work, mutated)
            receipt["runs"].append({"name": name, "exit": code,
                                     "output": output[-1800:]})
            if "VALUE FAIL:" not in output or expected not in output:
                raise RuntimeError(f"inverse {name} failed incorrectly: {output}")
    receipt["status"] = "PASS"
    out = ROOT / "_scratch/d2-leisure-01/weekone21/common-speech.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(f"PASS Week One common native speech and {len(CONTROLS)} inverses")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
