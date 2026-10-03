"""Actual installed-engine proof; no native game process or rendered-world claim."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

from .controls import controls
from .late_loading import run_checks as late_loading_checks

HERE = Path(__file__).resolve().parent
DEFAULT_GAME = r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"
DEFAULT_JDK = r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin"
ASSETS = Path("mod/42.20/media/SAOOrienting")
NATIVE_NAMES = ("projectzomboid.jar", "ZombieBuddy.jar")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def jdk_tool(directory, name):
    return directory / (name + (".exe" if os.name == "nt" else ""))


def save_receipt(output, receipt):
    (output / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")


def verify_checks(text, label):
    checks = [line for line in text.splitlines() if line.startswith("CHECK ")]
    assert len(checks) == 93, (label, "native check count changed", len(checks))
    assert all(line.endswith("=true") for line in checks), (label, "native check failed")
    assert len({line.partition("=")[0] for line in checks}) == 93, (label, "duplicate native check")
    return len(checks)


def main(argv=None, *, default_root=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, default=default_root or HERE.parents[1])
    parser.add_argument("--output", type=Path, help="Optional evidence directory outside the source tree")
    args = parser.parse_args(argv)
    root = args.source_root.resolve()
    game = Path(os.environ.get("PZ_DIR", DEFAULT_GAME)).resolve()
    jdk = Path(os.environ.get("JDK_BIN", DEFAULT_JDK)).resolve()
    # The private output is intentionally retained to make a failed gate inspectable.
    output = args.output.resolve() if args.output else Path(tempfile.mkdtemp(prefix="sao-orienting-evidence-"))
    if output == root or root in output.parents:
        raise ValueError("Evidence output must be outside --source-root")
    output.mkdir(parents=True, exist_ok=True)
    receipt = {"schema": "sao-orienting-native-proof/1", "status": "RUNNING", "runs": [],
        "sourceRoot": str(root), "timestamp": datetime.now(timezone.utc).isoformat(),
        "controls": [], "limits": ["Installed method and actual animation-pose fixture; no rendered gameplay or live-world timing acceptance."]}
    input_paths = []
    try:
        required = [root / "java/src/com/sao/engine/SAOOrientation.java",
                    root / "java/src/com/sao/engine/SAOOrientationAnimation.java",
                    root / "java/src/com/sao/engine/SAOSenses.java",
                    root / "java/src/com/sao/engine/SAOWorldSoundPulses.java",
                    root / "java/src/com/sao/agent/SAOOrientationWeave.java",
                    root / "tools/luacheck/MovementCrossingProbe.java",
                    root / "mod/42.20/media/java/SAO.jar"]
        required += [root / ASSETS / (name + ".xml") for name in ("tags", "look", "enter", "exit", "children")]
        required += [HERE / "OrientationProbe.java", HERE / "OrientationProbeAgent.java",
                     HERE / "WeaveDiagnosticsAgent.java", HERE / "WeaveDiagnosticsProbe.java", HERE / "controls.py",
                     HERE / "RegistrationRaceAgent.java",
                     HERE / "LateNativeLoadAgent.java", HERE / "LateNativeLoadProbe.java", HERE / "late_loading.py",
                     Path(__file__).resolve(), HERE.parent / "orienting_native_test.py"]
        required += [root / "tools/world_lab" / name for name in
                     ("StudyLoadingAgent.java", "StudyObserver.java", "StudyViewCapture.java", "StudyVideoCapture.java", "StudyExport.java")]
        assert all(path.is_file() for path in required), "missing owned orientation input: " + ", ".join(str(p) for p in required if not p.is_file())
        java_sources = sorted((root / "java/src").rglob("*.java"))
        input_paths = list(dict.fromkeys(required + java_sources))
        receipt["inputs"] = {str(p): sha(p) for p in input_paths}
        native = [game / name for name in NATIVE_NAMES]
        native_agent = game / ("zbNative.dll" if os.name == "nt" else "libzbNative.so")
        executables = {name: jdk_tool(jdk, name) for name in ("java", "javac", "jar")}
        missing = [str(path) for path in native + [native_agent] + list(executables.values()) if not path.is_file()]
        if missing:
            receipt.update(status="SKIPPED", reason="installed Project Zomboid, ZombieBuddy or JDK unavailable", missing=missing)
            print("SKIPPED -- native orientation: " + receipt["reason"], flush=True)
            return 0
        # The stamped jar supplies generated SAOVersion. Every production Java source is
        # compiled into the first classpath entry, ahead of the packaged runtime.
        native.append(root / "mod/42.20/media/java/SAO.jar")
        receipt["engineInputs"] = {str(p): sha(p) for p in native + [native_agent]}
        cp = os.pathsep.join(map(str, native))
        with tempfile.TemporaryDirectory(prefix="sao-orienting-build-") as temporary:
            work = Path(temporary)
            classes = work / "classes"
            classes.mkdir()

            def execute(command, name, *, cwd=root, expected=None):
                started = time.monotonic()
                result = subprocess.run(list(map(str, command)), cwd=cwd, capture_output=True,
                    text=True, encoding="utf-8", errors="replace", timeout=120)
                text = result.stdout + result.stderr
                (output / (name + ".log")).write_text(text, encoding="utf-8")
                passed = (result.returncode != 0 and expected in text) if expected else result.returncode == 0
                receipt["runs"].append({"name": name, "exit": result.returncode, "passed": passed,
                    "seconds": round(time.monotonic() - started, 3), "expectedFailure": expected,
                    "logSha256": hashlib.sha256(text.encode()).hexdigest()})
                save_receipt(output, receipt)
                assert passed, name + "\n" + text[-6500:]
                return text

            sources = java_sources + [HERE / "OrientationProbe.java", HERE / "OrientationProbeAgent.java",
                                      HERE / "WeaveDiagnosticsAgent.java", HERE / "WeaveDiagnosticsProbe.java",
                                      HERE / "RegistrationRaceAgent.java",
                                      HERE / "LateNativeLoadAgent.java", HERE / "LateNativeLoadProbe.java",
                                      root / "tools/luacheck/MovementCrossingProbe.java"]
            execute([executables["javac"], "-encoding", "UTF-8", "-cp", cp, "-d", classes, *sources], "compile")
            manifest = work / "MANIFEST.MF"
            manifest.write_text("Manifest-Version: 1.0\nPremain-Class: OrientationProbeAgent\nCan-Retransform-Classes: true\n\n", encoding="utf-8")
            agent = work / "probe-agent.jar"
            execute([executables["jar"], "cfm", agent, manifest, "-C", classes, "."], "jar")
            home = work / "home"
            home.mkdir()

            def run(name, *, first=None, assets=root, preload=False, expected=None, probe_agent=agent):
                return execute([executables["java"], f"-Duser.home={home}", f"-Djava.library.path={game}",
                    "--enable-native-access=ALL-UNNAMED", f"-javaagent:{probe_agent}" + ("=preload" if preload else ""),
                    "-cp", os.pathsep.join(map(str, ([first] if first else []) + [classes, *native])),
                    "OrientationProbe", assets, game], name, cwd=game, expected=expected)

            receipt["checks"] = verify_checks(run("baseline"), "baseline")
            verify_checks(run("preloaded-worldsound", preload=True), "preloaded-worldsound")
            race_manifest = work / "registration-race.MF"
            race_manifest.write_text("Manifest-Version: 1.0\nPremain-Class: RegistrationRaceAgent\nCan-Retransform-Classes: true\n\n", encoding="utf-8")
            race_agent = work / "registration-race-agent.jar"
            execute([executables["jar"], "cfm", race_agent, race_manifest, "-C", classes, "."], "registration-race-jar")
            race_text = run("loaded-during-installation", probe_agent=race_agent)
            assert "NATIVE_SOUND_LOADED_AFTER_INSTALL_SNAPSHOT=true" in race_text, "installation race was not exercised"
            verify_checks(race_text, "loaded-during-installation")
            receipt["nativeLoadingOrders"] = ["cold", "preloaded", "loaded-after-installer-snapshot"]
            print("PASS 93 native checks under cold, preloaded and during-installation native loading", flush=True)

            diagnostics_manifest = work / "diagnostics.MF"
            diagnostics_manifest.write_text("Manifest-Version: 1.0\nPremain-Class: WeaveDiagnosticsAgent\nCan-Retransform-Classes: true\n\n", encoding="utf-8")
            diagnostics_agent = work / "diagnostics-agent.jar"
            execute([executables["jar"], "cfm", diagnostics_agent, diagnostics_manifest, "-C", classes, "."], "diagnostics-jar")

            def diagnostics(name, mode, *, first=None, failure=False, expected=None):
                diagnostic_home = work / ("home-" + name)
                diagnostic_home.mkdir()
                return execute([executables["java"], f"-Duser.home={diagnostic_home}", f"-Djava.library.path={game}",
                    "--enable-native-access=ALL-UNNAMED", f"-javaagent:{diagnostics_agent}={mode}",
                    "-cp", os.pathsep.join(map(str, ([first] if first else []) + [classes, *native])),
                    "WeaveDiagnosticsProbe", "failure" if failure else "healthy", str("preload" in mode).lower()],
                    name, cwd=game, expected=expected)

            for mode in ("cold", "preload", "full", "full-preload"):
                diagnostics("weave-" + mode, mode)

            weave_source = root / "java/src/com/sao/agent/SAOOrientationWeave.java"
            original_weave = weave_source.read_text(encoding="utf-8")
            assert original_weave.count("@Advice.This Object sound") == 1
            invalid_advice = original_weave.replace("@Advice.This Object sound", "@Advice.This String sound", 1)

            def compile_diagnostic_mutant(name, source, changed):
                directory = work / "diagnostic-controls" / name
                directory.mkdir(parents=True)
                mutant = directory / source.name
                mutant.write_text(changed, encoding="utf-8")
                execute([executables["javac"], "-encoding", "UTF-8", "-cp", os.pathsep.join(map(str, [classes, *native])),
                    "-d", directory, mutant], "compile-" + name)
                return directory

            invalid = compile_diagnostic_mutant("invalid-advice", weave_source, invalid_advice)
            diagnostics("invalid-advice-cold", "cold", first=invalid, failure=True)
            diagnostics("invalid-advice-preloaded", "preload", first=invalid, failure=True)
            receipt["weaveDiagnosticChecks"] = 36
            receipt["nativeTransformFaultInjections"] = 2
            silent_call = 'if (TARGET.equals(name)) failed("transform", loader, loaded, error);'
            assert invalid_advice.count(silent_call) == 1
            silent = invalid_advice.replace(silent_call, 'if (TARGET.equals(name)) failure = error.toString();', 1)
            silent_classes = compile_diagnostic_mutant("silent-transform-failure", weave_source, silent)
            diagnostics("silent-transform-failure", "cold", first=silent_classes, failure=True,
                expected="CHECK actual_transform_failure_logged=false")
            agent_source = root / "java/src/com/sao/agent/SAOAgent.java"
            original_agent = agent_source.read_text(encoding="utf-8")
            install_call = "        SAOOrientationWeave.install(instrumentation);"
            assert original_agent.count(install_call) == 1
            omitted = original_agent.replace(install_call, "        // Deliberate missing installed-agent binding.", 1)
            omitted_classes = compile_diagnostic_mutant("missing-agent-pulse-binding", agent_source, omitted)
            diagnostics("missing-agent-pulse-binding", "full", first=omitted_classes,
                expected="CHECK entry_point_registered_weave=false")
            reconcile_start = "            // installOn holds Byte Buddy's circularity lock"
            reconcile_end = '            SAOAgent.log("orientation sound weave registered'
            assert original_weave.count(reconcile_start) == 1 and original_weave.count(reconcile_end) == 1
            start = original_weave.index(reconcile_start)
            end = original_weave.index(reconcile_end, start)
            unreconciled = original_weave[:start] + original_weave[end:]
            unreconciled_classes = compile_diagnostic_mutant("missing-install-reconciliation", weave_source, unreconciled)
            run("missing-install-reconciliation", first=unreconciled_classes, probe_agent=race_agent,
                expected="CHECK native_pulse_weave=false")
            for name, changed, verdict in (
                    ("silent-transform-failure", silent, "actual_transform_failure_logged"),
                    ("missing-agent-pulse-binding", omitted, "entry_point_registered_weave"),
                    ("missing-install-reconciliation", unreconciled, "native_pulse_weave")):
                receipt["controls"].append({"name": name, "assertion": verdict,
                    "mutantSha256": hashlib.sha256(changed.encode()).hexdigest()})
            print("PASS 36 native weave diagnostics, including full agent entry, and 3 installation controls", flush=True)
            late_loading_checks(root=root, game=game, work=work, classes=classes, native=native,
                executables=executables, execute=execute, receipt=receipt,
                compile_mutant=compile_diagnostic_mutant)
            mutations = list(controls())
            assert len(mutations) == 22, "orientation control coverage changed"
            for name, relative, mutate, verdict in mutations:
                mutation = work / "controls" / name
                mutation.mkdir(parents=True)
                source = root / relative
                changed = mutate(source.read_text(encoding="utf-8"))
                mutant = mutation / source.name
                mutant.write_text(changed, encoding="utf-8")
                expected = f"CHECK {verdict}=false"
                if source.suffix == ".java":
                    mutant_classes = mutation / "classes"
                    mutant_classes.mkdir()
                    execute([executables["javac"], "-encoding", "UTF-8", "-cp",
                        os.pathsep.join(map(str, [classes, *native])), "-d", mutant_classes, mutant], "compile-" + name)
                    run(name, first=mutant_classes, expected=expected)
                else:
                    asset_dir = mutation / ASSETS
                    asset_dir.mkdir(parents=True)
                    for path in (root / ASSETS).glob("*.xml"):
                        shutil.copyfile(path, asset_dir / path.name)
                    (asset_dir / source.name).write_text(changed, encoding="utf-8")
                    run(name, assets=mutation, expected=expected)
                receipt["controls"].append({"name": name, "assertion": verdict,
                    "mutantSha256": hashlib.sha256(changed.encode()).hexdigest()})
                print("PASS control " + name + " -> " + verdict, flush=True)
        receipt["inputsUnchanged"] = all(sha(Path(p)) == h for p, h in receipt["inputs"].items())
        assert receipt["inputsUnchanged"], "orientation inputs changed during checks"
        receipt["status"] = "PASS"
        print("PASS native orientation: 93 pose/sense/posture checks in 3 loading orders, 36 weave checks, 16 late-bootstrap checks, 28 controls; receipt " + str(output / "receipt.json"), flush=True)
        return 0
    except Exception as error:
        receipt.update(status="FAIL", error=str(error))
        print("FAIL native orientation: " + str(error), flush=True)
        return 1
    finally:
        save_receipt(output, receipt)
