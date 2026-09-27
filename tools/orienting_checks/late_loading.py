"""Actual study/SAO/native-ZombieBuddy bootstrap plus controlled later loading."""
from __future__ import annotations

import hashlib
import os
from pathlib import Path


def verify(text):
    checks = [line for line in text.splitlines() if line.startswith("CHECK ")]
    assert len(checks) == 16 and all(line.endswith("=true") for line in checks), "late native load checks failed"
    assert len({line.partition("=")[0] for line in checks}) == 16, "duplicate late-load check"


def run_checks(*, root, game, work, classes, native, executables, execute, receipt, compile_mutant):
    study_sources = [root / "tools/world_lab" / name for name in
                     ("StudyLoadingAgent.java", "StudyObserver.java", "StudyViewCapture.java")]
    study_classes = work / "study-classes"
    study_classes.mkdir()
    execute([executables["javac"], "-encoding", "UTF-8", "-cp", os.pathsep.join(map(str, native)),
             "-d", study_classes, *study_sources], "late-study-compile")

    def agent(name, entry, directory):
        manifest = work / (name + ".MF")
        manifest.write_text("Manifest-Version: 1.0\nPremain-Class: " + entry
                            + "\nCan-Retransform-Classes: true\n\n", encoding="utf-8")
        jar = work / (name + ".jar")
        execute([executables["jar"], "cfm", jar, manifest, "-C", directory, "."], name + "-jar")
        return jar

    study = agent("late-study", "StudyLoadingAgent", study_classes)
    sao = agent("late-sao", "com.sao.agent.SAOAgent", classes)
    late = agent("late-load", "LateNativeLoadAgent", classes)
    suffix = ".exe" if os.name == "nt" else ""
    bundled_java = game / "jre64/bin" / ("java" + suffix)
    runtime = bundled_java if bundled_java.is_file() else executables["java"]
    native_agent = game / ("zbNative.dll" if os.name == "nt" else "libzbNative.so")

    def invoke(name, first=None, expected=None):
        home = work / ("home-" + name)
        home.mkdir()
        text = execute([runtime, f"-Duser.home={home}", "-Dstudy.observer=true", "-Dstudy.showWindow=false",
            f"-Dstudy.viewDirectory={home / 'view'}", f"-Dstudy.observerState={home / 'observer.json'}",
            f"-Dstudy.observerControl={home / 'control.properties'}", f"-javaagent:{study}=isolated-study",
            f"-javaagent:{sao}=sao", f"-javaagent:{late}", f"-agentpath:{native_agent}",
            "-Djava.awt.headless=true", "--enable-native-access=ALL-UNNAMED",
            "--add-exports=java.base/jdk.internal.misc=ALL-UNNAMED", "-Dzomboid.steam=0",
            f"-Djava.library.path={game / 'win64'}{os.pathsep}{game}", "-XX:-OmitStackTraceInFastThrow",
            "-cp", os.pathsep.join(map(str, ([first] if first else []) + [classes, *native])),
            "LateNativeLoadProbe", root, game], name, cwd=game, expected=expected)
        log = home / "Zomboid/SAOAgent.log"
        if log.is_file():
            receipt.setdefault("lateAgentLogs", {})[name] = log.read_text(encoding="utf-8")
        return text

    verify(invoke("late-native-sensor"))
    receipt["lateNativeLoadChecks"] = 16
    receipt["lateNativeLoadBoundary"] = (
        "Actual installed agents plus a controlled later nested native class load. "
        "Reproduces native05 loaded/unwoven state; does not establish the unobserved live loader call stack.")

    scanner = root / "java/src/com/sao/engine/SAOPerceptionScanner.java"
    original_scanner = scanner.read_text(encoding="utf-8")
    binding = "        com.sao.agent.SAOOrientationWeave.atNativeSensorBoundary();"
    assert original_scanner.count(binding) == 1
    weave = root / "java/src/com/sao/agent/SAOOrientationWeave.java"
    original_weave = weave.read_text(encoding="utf-8")
    native_retransform = "            if (!transformed) instrumentation.retransformClasses(target);"
    assert original_weave.count(native_retransform) == 1
    counterfeited = original_scanner.replace(binding, binding + "\n"
        "        for (zombie.WorldSoundManager.WorldSound old : zombie.WorldSoundManager.instance.soundList)\n"
        "            SAOWorldSoundPulses.initialized(old);", 1)
    cases = [
        ("missing-sensor-binding", scanner, original_scanner.replace(binding, "", 1), "native_sensor_reconciles_late_class"),
        ("missing-late-native-retransform", weave, original_weave.replace(native_retransform, "", 1), "native_sensor_reconciles_late_class"),
        ("invent-missed-pulse", scanner, counterfeited, "sensor_keeps_missed_occurrence_unclassified"),
    ]
    for name, source, changed, verdict in cases:
        mutant = compile_mutant(name, source, changed)
        invoke(name, first=mutant, expected="CHECK " + verdict + "=false")
        receipt["controls"].append({"name": name, "assertion": verdict,
            "mutantSha256": hashlib.sha256(changed.encode()).hexdigest()})
        print("PASS control " + name + " -> " + verdict, flush=True)
    print("PASS 16 late native bootstrap checks and 3 sensor reconciliation controls", flush=True)
