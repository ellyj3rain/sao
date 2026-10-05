"""Real installed study/gameplay startup order and native callback bytecode.

Short-lived JVMs only: no world, graphics context, live cache or game simulation.
"""
from datetime import datetime, timezone
from pathlib import Path
import ast
import hashlib
import json
import os
import subprocess
import sys

import world_lab_run as Runner
from native_proof_preflight import installed_presence

ROOT = Path(__file__).resolve().parents[1]
GAME = Path(os.environ.get("PZ_DIR", r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"))
JDK = Path(os.environ.get("JDK_BIN", r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin"))


def main():
    work = ROOT / "_scratch/d1-shared-reasoning/conflict/callback-integration" / datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S-%f")
    work.mkdir(parents=True)
    source = ROOT / "tools/world_lab"
    observer_sources = [source / name for name in Runner.OBSERVER_SOURCES]
    probe = source / "NativeCombatStartupProbe.java"
    sao = ROOT / "mod/42.20/media/java/SAO.jar"
    native = [GAME / "projectzomboid.jar", GAME / "ZombieBuddy.jar"]
    inputs = [Path(__file__), ROOT / "tools/world_lab_run.py", probe, *observer_sources, sao, *native,
              GAME / "zbNative.dll", GAME / "jre64/bin/java.exe"]
    inputs.append(Path(__file__).with_name('native_proof_preflight.py'))
    preflight = installed_presence(inputs, GAME, JDK, "world lab combat startup")
    if preflight is not None:
        raise SystemExit(preflight)
    def pins():
        return {str(p.relative_to(ROOT)) if p.is_relative_to(ROOT) else str(p):
                hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
    receipt = {"schema": "sao.native-combat-startup/1", "status": "INCOMPLETE",
               "boundary": __doc__, "inputs": pins(), "variants": []}
    def save():
        (work / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    def execute(command, name, *, expected=None):
        result = subprocess.run(list(map(str, command)), cwd=GAME, capture_output=True,
                                text=True, encoding="utf-8", errors="replace", timeout=90)
        output = result.stdout + result.stderr
        (work / (name + ".log")).write_text(output, encoding="utf-8")
        receipt["variants"].append({"name": name, "command": list(map(str, command)),
            "exit": result.returncode, "expectedFailure": expected,
            "logSha256": hashlib.sha256(output.encode()).hexdigest()})
        save()
        if expected:
            assert result.returncode != 0 and expected in output, output
        else:
            assert result.returncode == 0, output
        return output
    save()
    tree = ast.parse((ROOT / "tools/world_lab_run.py").read_text(encoding="utf-8"))
    calls = [n for n in ast.walk(tree) if isinstance(n, ast.Call)
             and isinstance(n.func, ast.Name) and n.func.id == "native_agent_arguments"]
    assert len(calls) == 1 and ast.unparse(calls[0]) == "native_agent_arguments(sao_jars[0], agent)", "actual launcher must use the proven agent sequence"
    classes = work / "classes"
    classes.mkdir()
    cp = os.pathsep.join(map(str, [classes, sao, *native]))
    execute([JDK / "javac.exe", "-encoding", "UTF-8", "-cp", cp, "-d", classes,
             *observer_sources, probe], "compile")
    for name, entry in (("observer", "StudyLoadingAgent"), ("capture", "NativeCombatStartupProbe")):
        manifest = work / (name + ".MF")
        manifest.write_text("Manifest-Version: 1.0\nPremain-Class: " + entry + "\nCan-Retransform-Classes: true\n\n", encoding="utf-8")
        execute([JDK / "jar.exe", "cfm", work / (name + ".jar"), manifest, "-C", classes, "."], name + "-jar")
    actual = Runner.native_agent_arguments(sao, work / "observer.jar")
    for name, agents, expected in (
        ("production", actual, None),
        ("reversed-agent-order", list(reversed(actual)), "COMBAT_STARTUP:combat_callbacks_ready"),
        ("omitted-gameplay-agent", [a for a in actual if not a.endswith("=sao")], "COMBAT_STARTUP:combat_callbacks_ready"),
    ):
        home = work / name
        home.mkdir()
        captured = home / "SwipeStatePlayer.class"
        command = [GAME / "jre64/bin/java.exe", f"-Duser.home={home}", "-Dstudy.observer=true",
            "-Dstudy.showWindow=false", f"-Dstudy.viewDirectory={home / 'view'}",
            f"-Dstudy.observerState={home / 'observer.json'}", f"-Dstudy.observerControl={home / 'control.properties'}",
            *agents, f"-javaagent:{work / 'capture.jar'}", f"-agentpath:{GAME / 'zbNative.dll'}",
            "-Djava.awt.headless=true", "--enable-native-access=ALL-UNNAMED",
            "--add-exports=java.base/jdk.internal.misc=ALL-UNNAMED", "-Dzomboid.steam=0",
            f"-Djava.library.path={GAME / 'win64'}{os.pathsep}{GAME}",
            "-XX:-CreateCoredumpOnCrash", "-cp", cp, "NativeCombatStartupProbe", captured]
        output = execute(command, name, expected=expected)
        if not expected:
            assert "PASS native combat startup checks=5" in output
        code = execute([JDK / "javap.exe", "-p", "-c", captured], name + "-bytecode")
        helper_calls = code.count("com/sao/agent/SAOCombatGate.allowLocalCombatHook:")
        assert helper_calls == (0 if expected else 3), "actual transformed callback bodies disagree with readiness"
        if not expected:
            for method in ("OnAnimEvent_AttackCollisionCheck", "OnAnimEvent_PlaySwingSound", "OnAnimEvent_PlaySwingSoundAlways"):
                body = code.split(" " + method + "(", 1)[1].split("\n  private ", 1)[0].split("\n  public ", 1)[0]
                assert body.count("com/sao/agent/SAOCombatGate.allowLocalCombatHook:") == 1, method
                assert "IsoPlayer.isLocalPlayer:(Lzombie/characters/IsoGameCharacter;)Z" not in body, method
        receipt.setdefault("nativeCallbackBytes", {})[name] = {
            "sha256": hashlib.sha256(captured.read_bytes()).hexdigest(), "helperCalls": helper_calls}
        print("PASS " + name + ": callbacks=" + str(helper_calls), flush=True)
    receipt["inputsAfter"] = pins()
    assert receipt["inputsAfter"] == receipt["inputs"], "startup proof inputs changed"
    receipt.update(status="PASS", productionChecks=5, callbackBodiesVerified=3, controls=2,
                   gameplayJarChanged=False, worldStarted=False)
    save()
    print("receipt=" + str(work / "receipt.json"))


if __name__ == "__main__":
    try:
        main()
    except Exception as failure:
        print("FAIL native combat startup: " + str(failure), file=sys.stderr)
        raise SystemExit(1)
