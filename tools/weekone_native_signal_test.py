#!/usr/bin/env python3
"""Native Week One shout/horn state and sound-only person contact."""
from pathlib import Path
import hashlib
import json
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
GAME = Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
JDK = Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
SOURCE = ROOT / "mod/42.20/media/lua/client/SAO_WeekOneNativeSignal.lua"
CASES = ROOT / "tools/weekone_native_signal_cases.lua"
PROBE = ROOT / "tools/luacheck/WeekOneNativeSignalProbe.java"
RUNNER = ROOT / "tools/luacheck/LuaRun.java"
BRIDGE = ROOT / "java/src/com/sao/bridge/SAOBridge.java"
SHIPPED = ROOT / "mod/42.20/media/java/SAO.jar"
DIST = ROOT / "java/dist/SAOAgent.jar"

CONTROLS = [
    ("held-pulse", "if calloutOccurrence and calloutOccurrence ~= previous.calloutOccurrence then",
     "if calloutOccurrence then", "one held native callout produced a duplicate"),
    ("state-only", "local calloutOccurrence = callout and nativeCalloutOccurrence(player) or nil",
     'local calloutOccurrence = callout and "state-only" or nil',
     "sticky native state without Callout occurrence became contact"),
    ("stale-replay", "    previous.horn = horn\n    return heard",
     "    previous.calloutOccurrence = calloutOccurrence\n    previous.horn = horn\n    return heard",
     "stale Callout occurrence was replayed after a missing read"),
    ("heard-gate", "if ok and heard == true then",
     "if ok then", "unheard native callout became contact"),
    ("owner-gate", 'and SAO.Claims.heldBy(rec) == "BanditsWeekOne" then',
     "and true then", "foreign owner borrowed sound contact"),
    ("native-horn", 'local horn = nativeState(player, "horn")',
     "local horn = false", "rebound native horn did not remain a sound-only contact"),
]


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def command(args: list[str], cwd: Path, timeout: int = 90) -> dict:
    done = subprocess.run([str(arg) for arg in args], cwd=cwd,
                          capture_output=True, text=True, timeout=timeout)
    return {"exit": done.returncode, "output": (done.stdout + done.stderr)[-3000:]}


def main() -> int:
    paths = [GAME / "projectzomboid.jar", GAME / "ZombieBuddy.jar",
             GAME / "stdlib.lua", JDK / "java.exe",
             JDK / "javac.exe", SOURCE, CASES, PROBE, RUNNER, BRIDGE, SHIPPED, DIST]
    missing = [str(path) for path in paths if not path.is_file()]
    if missing:
        raise RuntimeError("missing installed engine or source: " + ", ".join(missing))
    if sha(SHIPPED) != sha(DIST):
        raise RuntimeError("shipped and dist SAO Java jars differ")
    if "weekOneNativeSignalHeard" not in BRIDGE.read_text(encoding="utf-8"):
        raise RuntimeError("native signal source/Java jar join unavailable")
    receipt = {"status": "INCOMPLETE", "sources": {str(p.relative_to(ROOT)): sha(p)
        for p in [SOURCE, CASES, PROBE, RUNNER, BRIDGE, SHIPPED, DIST]},
        "boundary": "Installed Callout executes natively with headless voice and chat sinks. BaseVehicle.onHornStart reaches its state setter, but absent zombie-population JNI requires a controlled native WorldSound payload. Kahlua event sequencing and real game input/rendering remain separate observations.",
        "checks": []}
    with tempfile.TemporaryDirectory(prefix="sao-weekone-native-signal-") as tmp:
        work = Path(tmp)
        (work / "stdlib.lua").write_bytes((GAME / "stdlib.lua").read_bytes())
        cp = f"{GAME / 'projectzomboid.jar'};{GAME / 'ZombieBuddy.jar'};{SHIPPED}"
        built = command([JDK / "javac.exe", "-encoding", "UTF-8", "-cp", cp,
                         "-d", work, RUNNER, PROBE], work, 120)
        receipt["checks"].append({"name": "compile", **built})
        if built["exit"]:
            raise RuntimeError("native probe compile failed: " + built["output"])
        native = command([JDK / "java.exe", f"-Duser.home={work}",
                          "--enable-native-access=ALL-UNNAMED",
                          f"-javaagent:{SHIPPED}=sao", "-cp",
                          f"{work};{cp}", "WeekOneNativeSignalProbe"], work, 120)
        receipt["checks"].append({"name": "installed-native", **native})
        if native["exit"] or "PASS Week One installed native Callout" not in native["output"] \
                or "HORN headless population JNI unavailable" not in native["output"]:
            raise RuntimeError("installed-native: " + native["output"])

        current = SOURCE.read_text(encoding="utf-8")
        cases = [("current", current, "VALUE PASS")]
        cases += [(name, current.replace(before, after, 1), "VALUE FAIL:")
                  for name, before, after, _ in CONTROLS]
        for name, lua, expected in cases:
            (work / "candidate.lua").write_text(lua, encoding="utf-8")
            run = command([JDK / "java.exe", "-cp", f"{GAME / 'projectzomboid.jar'};{work}",
                           "LuaRun", CASES, work / "candidate.lua", "--", "__safe()"],
                          work)
            receipt["checks"].append({"name": name, **run})
            if run["exit"] or expected not in run["output"]:
                raise RuntimeError(name + ": " + run["output"])
            if name != "current":
                wanted = next(row[3] for row in CONTROLS if row[0] == name)
                if wanted not in run["output"]:
                    raise RuntimeError(name + " inverse failed for wrong reason: " + run["output"])
    receipt["status"] = "PASS"
    out = ROOT / "_scratch/d2-leisure-01/weekone21/native-signal.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(f"PASS Week One native Callout, controlled horn sound, contact, and {len(CONTROLS)} inverses")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
