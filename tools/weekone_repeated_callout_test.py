#!/usr/bin/env python3
"""Installed Callout occurrence proof with two compiled native inverses."""
from pathlib import Path
import hashlib
import json
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parent.parent
GAME = Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
JDK = Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
JAR = ROOT / "mod/42.20/media/java/SAO.jar"
DIST = ROOT / "java/dist/SAOAgent.jar"
WEAVE = ROOT / "java/src/com/sao/agent/SAOCalloutWeave.java"
BRIDGE = ROOT / "java/src/com/sao/bridge/SAOBridge.java"
PULSES = ROOT / "java/src/com/sao/engine/SAOWorldSoundPulses.java"
PROBE = ROOT / "tools/luacheck/WeekOneNativeSignalProbe.java"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(args: list[object], cwd: Path) -> subprocess.CompletedProcess:
    return subprocess.run([str(item) for item in args], cwd=cwd,
                          capture_output=True, text=True, timeout=120)


def modified_source(source: Path, before: str, after: str, target: Path) -> None:
    body = source.read_text(encoding="utf-8")
    if body.count(before) != 1:
        raise RuntimeError("native inverse anchor drift: " + source.name)
    target.write_text(body.replace(before, after, 1), encoding="utf-8")


def repack(original: Path, overlay: Path, target: Path) -> None:
    changes = {str(path.relative_to(overlay)).replace("\\", "/"): path
               for path in overlay.rglob("*.class")}
    if not changes:
        raise RuntimeError("native inverse compiled no class files")
    with zipfile.ZipFile(original) as old, zipfile.ZipFile(target, "w") as new:
        originals = {item.filename for item in old.infolist()}
        if not changes.keys() <= originals:
            raise RuntimeError("native inverse added unrecognized class files")
        for item in old.infolist():
            new.writestr(item, changes[item.filename].read_bytes()
                         if item.filename in changes else old.read(item.filename))


def main() -> int:
    inputs = [JAR, DIST, WEAVE, BRIDGE, PULSES, PROBE,
              GAME / "projectzomboid.jar", GAME / "ZombieBuddy.jar",
              JDK / "javac.exe", JDK / "java.exe"]
    missing = [str(path) for path in inputs if not path.is_file()]
    if missing:
        raise RuntimeError("missing installed native input: " + ", ".join(missing))
    if sha(JAR) != sha(DIST):
        raise RuntimeError("shipping/dist Java jars differ")
    receipt = {"status": "OPEN", "inputs": {str(path.relative_to(ROOT)) if path.is_relative_to(ROOT)
               else str(path): sha(path) for path in inputs}, "runs": [],
               "boundary": "Installed engine Callout and woven WorldSound were exercised headlessly. This does not establish live input, audio, multiplayer delivery, or rendered play."}
    with tempfile.TemporaryDirectory(prefix="sao-repeat-callout-") as tmp:
        work = Path(tmp)
        probe_classes = work / "probe"
        probe_classes.mkdir()
        engine_cp = f"{GAME / 'projectzomboid.jar'};{GAME / 'ZombieBuddy.jar'};{JAR}"
        built = run([JDK / "javac.exe", "-encoding", "UTF-8", "-cp", engine_cp,
                     "-d", probe_classes, PROBE], work)
        if built.returncode:
            raise RuntimeError("native probe compile failed: " + built.stderr)

        def check(name: str, agent: Path, expected: str, success: bool) -> None:
            home = work / ("home-" + name)
            home.mkdir()
            result = run([JDK / "java.exe", f"-Duser.home={home}",
                          "--enable-native-access=ALL-UNNAMED",
                          f"-javaagent:{agent}=sao", "-cp",
                          f"{probe_classes};{GAME / 'projectzomboid.jar'};"
                          f"{GAME / 'ZombieBuddy.jar'};{agent}",
                          "WeekOneNativeSignalProbe"], work)
            output = result.stdout + result.stderr
            receipt["runs"].append({"name": name, "exit": result.returncode,
                                    "expected": expected, "output": output[-1500:]})
            if (result.returncode == 0) != success or expected not in output:
                raise RuntimeError(name + " failed for wrong reason: " + output[-2500:])

        check("current", JAR, "PASS Week One installed native Callout", True)

        weave_src = work / "SAOCalloutWeave.java"
        modified_source(WEAVE,
            "if (thrown == null) SAOWorldSoundPulses.completedNativeCallout(body, before);",
            "if (false && thrown == null) SAOWorldSoundPulses.completedNativeCallout(body, before);",
            weave_src)
        weave_classes = work / "weave-classes"
        weave_classes.mkdir()
        compiled = run([JDK / "javac.exe", "-encoding", "UTF-8", "-cp", engine_cp,
                        "-d", weave_classes, weave_src], work)
        if compiled.returncode:
            raise RuntimeError("omitted-marker inverse compile failed: " + compiled.stderr)
        omitted_jar = work / "omitted-marker.jar"
        repack(JAR, weave_classes, omitted_jar)
        check("omitted-native-marker", omitted_jar,
              "native Callout has no woven occurrence", False)

        bridge_src = work / "SAOBridge.java"
        original = BRIDGE.read_text(encoding="utf-8")
        old_null = 'if ("callout".equals(kind) && calloutSound == null) return false;'
        old_exact = 'if (sound != calloutSound || sound.source != player || sound.radius != 6'
        if original.count(old_null) != 1 or original.count(old_exact) != 1:
            raise RuntimeError("exact-hearing inverse anchors drifted")
        bridge_src.write_text(original.replace(old_null, "if (false) return false;", 1)
                              .replace(old_exact, 'if (sound.source != player || sound.radius != 6', 1),
                              encoding="utf-8")
        bridge_classes = work / "bridge-classes"
        bridge_classes.mkdir()
        compiled = run([JDK / "javac.exe", "-encoding", "UTF-8", "-cp", engine_cp,
                        "-d", bridge_classes, bridge_src], work)
        if compiled.returncode:
            raise RuntimeError("generic-sound inverse compile failed: " + compiled.stderr)
        generic_jar = work / "generic-sound.jar"
        repack(JAR, bridge_classes, generic_jar)
        check("generic-sound-admission", generic_jar,
              "unrelated same-source sound borrowed the sticky Callout flag", False)

    receipt["status"] = "PASS"
    out = ROOT / "_scratch/d2-leisure-01/weekone21/repeated-native-callout.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print("PASS installed repeated Callout, stale/pooled exclusion, two compiled native inverses")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
