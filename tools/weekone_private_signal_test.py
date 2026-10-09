#!/usr/bin/env python3
"""Installed Kahlua proof for native Week One sound into private Perception."""
from pathlib import Path
import hashlib
import json
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
GAME = Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
JDK = Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
P = ROOT / "mod/42.20/media/lua/shared/SAO_Perception.lua"
N = ROOT / "mod/42.20/media/lua/client/SAO_WeekOneNativeSignal.lua"
CASES = ROOT / "tools/weekone_private_signal_cases.lua"
RUNNER = ROOT / "tools/luacheck/LuaRun.java"

CONTROLS = (
    ("held-pulse", N, "if calloutOccurrence and calloutOccurrence ~= previous.calloutOccurrence then",
     "if calloutOccurrence then", "one held native callout duplicated a private cue"),
    ("state-only", N,
     "local calloutOccurrence = callout and nativeCalloutOccurrence(player) or nil",
     'local calloutOccurrence = callout and "state-only" or nil',
     "sticky native state without Callout occurrence entered private Perception"),
    ("stale-replay", N, "    previous.horn = horn\n    return heard",
     "    previous.calloutOccurrence = calloutOccurrence\n    previous.horn = horn\n    return heard",
     "stale Callout occurrence replayed into private Perception"),
    ("canonical-intake", N,
     'if perception and type(perception.acquireWeekOneNativeSignal) == "function" then',
     'if false and perception and type(perception.acquireWeekOneNativeSignal) == "function" then',
     "callout cue lost real body origin or invented social meaning"),
    ("vehicle-origin", P,
     'kind == "horn" and player:getVehicle() or player',
     "player", "horn cue did not use actual driven vehicle location"),
    ("body-bound-query", P,
     "local out, row = {}, weekOneNativeSignals[id]\n    if not row or row.body ~= body or not finiteSoundNumber(tick)",
     "local out, row = {}, weekOneNativeSignals[id]\n    if not row or not finiteSoundNumber(tick)",
     "another body read this person's private sound"),
    ("heard-gate", P, "if not okHeard or heard ~= true then return nil end",
     "if false then return nil end", "unheard native action entered private Perception"),
)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def invoke(args: list[object], cwd: Path, timeout: int = 90) -> subprocess.CompletedProcess:
    return subprocess.run([str(item) for item in args], cwd=cwd,
                          capture_output=True, text=True, timeout=timeout)


def main() -> int:
    for path in (P, N, CASES, RUNNER, GAME / "projectzomboid.jar",
                 GAME / "stdlib.lua", JDK / "java.exe", JDK / "javac.exe"):
        if not path.is_file():
            raise RuntimeError(f"missing installed engine or source: {path}")
    source = {path: path.read_text(encoding="utf-8") for path in (P, N)}
    receipt = {"status": "OPEN", "sourcePins": {str(path.relative_to(ROOT)): sha(path)
        for path in (P, N, CASES, RUNNER)}, "runs": []}
    with tempfile.TemporaryDirectory(prefix="sao-weekone-private-signal-") as tmp:
        work = Path(tmp)
        (work / "stdlib.lua").write_bytes((GAME / "stdlib.lua").read_bytes())
        built = invoke([JDK / "javac.exe", "-cp", GAME / "projectzomboid.jar",
                        "-d", work, RUNNER], work, 120)
        if built.returncode:
            raise RuntimeError("installed Kahlua runner failed: " + built.stderr)

        def run(changed: dict[Path, str]) -> str:
            (work / "Perception.lua").write_text(changed[P], encoding="utf-8")
            (work / "NativeSignal.lua").write_text(changed[N], encoding="utf-8")
            result = invoke([JDK / "java.exe", "-cp",
                f"{GAME / 'projectzomboid.jar'};{work}", "LuaRun", CASES,
                work / "Perception.lua", work / "NativeSignal.lua",
                "--", "__safePrivate()"], work)
            if result.returncode:
                raise RuntimeError("Kahlua run failed: " + result.stdout + result.stderr)
            return result.stdout + result.stderr

        output = run(source)
        receipt["runs"].append({"name": "current", "output": output[-1400:]})
        if "VALUE PASS" not in output:
            raise RuntimeError("private signal current failed: " + output)
        for name, path, before, after, expected in CONTROLS:
            if source[path].count(before) != 1:
                raise RuntimeError("inverse anchor drift: " + name)
            altered = dict(source)
            altered[path] = source[path].replace(before, after, 1)
            output = run(altered)
            receipt["runs"].append({"name": name, "output": output[-1400:]})
            if "VALUE FAIL:" not in output or expected not in output:
                raise RuntimeError(f"inverse {name} failed for wrong reason: {output}")
    receipt["status"] = "PASS"
    out = ROOT / "_scratch/d2-leisure-01/weekone21/private-signal.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(f"PASS Week One private native sound, {len(CONTROLS)} inverses")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
