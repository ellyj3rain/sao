#!/usr/bin/env python3
"""Installed Week One performance sound custody and private SAO hearing proof.

The native probe uses loaded Project Zomboid geometry, WorldSoundManager,
scanner, emitter handle and the SAO source classes. The Lua probe runs the
actual Perception receiver on the installed Kahlua VM. Neither starts play.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

from native_proof_preflight import installed_presence

ROOT = Path(__file__).resolve().parents[1]
CHECKS = ROOT / "tools/weekone_performance_hearing_checks"
PULSE = ROOT / "java/src/com/sao/engine/SAOWorldSoundPulses.java"
PERCEPTION = ROOT / "mod/42.20/media/lua/shared/SAO_Perception.lua"
SOURCES = [
    PULSE,
    ROOT / "java/src/com/sao/bridge/SAOBridge.java",
    ROOT / "java/src/com/sao/agent/SAOOrientationWeave.java",
    ROOT / "tools/luacheck/MovementCrossingProbe.java",
    ROOT / "tools/luacheck/ResourceApproachProbe.java",
    ROOT / "tools/cognition_checks/CognitionUseProbe.java",
    ROOT / "tools/instrument_checks/InstrumentProbe.java",
    ROOT / "tools/orienting_checks/OrientationProbeAgent.java",
    CHECKS / "WeekOnePerformanceHearingProbe.java",
]
LUA_INPUTS = [ROOT / "tools/luacheck/LuaRun.java",
              ROOT / "tools/cognition_checks/prelude.lua", PERCEPTION,
              CHECKS / "perception_cases.lua"]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def replace_exact(source, before, after, label):
    if source.count(before) != 1:
        raise AssertionError(f"{label} source anchor count {source.count(before)}")
    return source.replace(before, after, 1)


def replace_method(source, method, changes, label):
    begin = source.index(method)
    end = source.find("\n    /**", begin + len(method))
    if end < 0:
        end = len(source)
    section = source[begin:end]
    for before, after in changes:
        section = replace_exact(section, before, after, label)
    return source[:begin] + section + source[end:]


def native_mutant(source, name):
    claim = "public static synchronized KahluaTable claimWeekOnePerformance("
    bind = "public static synchronized KahluaTable bindWeekOnePerformance("
    reset = "public static synchronized void resetRuntimeForWorld()"
    if name == "birth":
        return replace_exact(source, "&& Double.compare(time.doubleValue(), born) == 0;",
                             "&& true;", name)
    if name == "handle":
        return replace_method(source, bind, [("|| !playing(body, handle)",
                                               "|| false")], name)
    if name == "ended_audio":
        return replace_method(source, claim, [
            ("|| !playing(body, emission.soundHandle())", "|| false")], name)
    if name == "unseen_attribution":
        changed = replace_exact(source,
            "SAOPerceptionScanner.canSeePersonNow(observer, emitter, 16)",
            "true", name)
        return replace_method(changed, claim, [
            ("|| !SAOPerceptionScanner.canSeePersonNow(observer, body, 16)",
             "|| false")], name)
    if name == "replay":
        return replace_method(source, claim, [
            ("heard.claimed.contains(pulseId)", "false"),
            ("emission.claims().containsKey(observer)", "false")], name)
    if name == "reload":
        return replace_method(source, reset, [
            ("PULSES.clear(); EMISSIONS.clear(); WEEK_ONE_EMISSIONS.clear();",
             "EMISSIONS.clear();"),
            ("HEARD.clear(); NATIVE_CALLOUTS.clear();",
             "NATIVE_CALLOUTS.clear();")], name)
    if name == "emitter_age_window":
        return replace_method(source, claim, [
            ("|| emission.atHours() > heardAt) continue;",
             "|| emission.atHours() > heardAt\n"
             "                    || at - emission.atHours() > CLAIM_HORIZON_HOURS) continue;")], name)
    if name == "stale_acquisition_window":
        return replace_method(source, claim, [
            ("|| heardAt > at || at - heardAt > CLAIM_HORIZON_HOURS",
             "|| heardAt > at || false")], name)
    if name == "pooled_reinit":
        changed = replace_method(source, "public static synchronized void initialized(", [
            ("WEEK_ONE_EMISSIONS.remove(sound);", "/* retained stale emission */")], name)
        return replace_method(changed, claim, [
            ("|| PULSES.get(sound) != acquired || sound.source != body",
             "|| false || sound.source != body")], name)
    if name == "removed_world_sound":
        return replace_method(source, claim, [
            ("|| !zombie.WorldSoundManager.instance.soundList.contains(sound)",
             "|| false")], name)
    if name == "expired_world_sound":
        return replace_method(source, claim, [
            ("|| PULSES.get(sound) != acquired || sound.source != body || sound.life <= 0",
             "|| PULSES.get(sound) != acquired || sound.source != body || false")], name)
    if name == "proxy_identity_path":
        return replace_method(source, claim, [
            ("String observerId = proxy == null ? actor(observer) : proxy.id();",
             "String observerId = actor(observer);")], name)
    if name == "proxy_generation":
        return replace_exact(source,
            '&& Objects.equals(weekOneBorn, body.getModData().rawget("SAOWeekOneBorn"))',
            '&& true', name)
    raise ValueError(name)


def lua_mutant(source, name):
    if name == "observer_owner":
        return replace_exact(source,
            'if needs and needs.ownsRecoveryBody\n'
            '        and needs.ownsRecoveryBody(id, body) then return "recovery" end',
            'if true then return "recovery" end', name)
    if name == "between_scan":
        return replace_exact(source,
            'if not asleep then observeWeekOnePerformances(id, body) end',
            'if not asleep and tick - b.lastScanAt >= SCAN_INTERVAL then '
            'observeWeekOnePerformances(id, body) end', name)
    if name == "claim_before_scan":
        begin = source.index("function P.observe(id, body, tick, asleep)")
        end = source.index("\nfunction ", begin + 1)
        section = source[begin:end]
        claim = '    if not asleep then observeWeekOnePerformances(id, body) end\n'
        scan = '    if not asleep and SAOJavaBridge and SAOJavaBridge.perceiveAudibleSounds then\n'
        section = replace_exact(section, claim, '', name)
        section = replace_exact(section, scan, claim + scan, name)
        return source[:begin] + section + source[end:]
    begin = source.index("function P.acquireWeekOnePerformanceHearing(")
    end = source.index("function P.weekOnePerformanceHearings(", begin)
    section = source[begin:end]
    if name == "exact_handle":
        section = replace_exact(section,
            "or row.soundHandle ~= occurrence.soundHandle",
            "or false", name)
    else:
        raise ValueError(name)
    return source[:begin] + section + source[end:]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--baseline-only", action="store_true")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    game = Path(os.environ.get("PZ_DIR",
        r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"))
    jdk = Path(os.environ.get("JDK_BIN",
        r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin"))
    jars = [game / "projectzomboid.jar", game / "ZombieBuddy.jar",
            ROOT / "mod/42.20/media/java/SAO.jar"]
    inputs = list(dict.fromkeys(SOURCES + LUA_INPUTS + jars +
        [ROOT / "mod/42.20/media/lua/client/SAO_WeekOneContinuity.lua",
         game / "stdlib.lua", Path(__file__),
         ROOT / "tools/native_proof_preflight.py"]))
    preflight = installed_presence(inputs, game, jdk,
                                   "Week One performance hearing")
    if preflight is not None:
        raise SystemExit(preflight)
    receipt = {"schema": "sao-weekone-performance-hearing-proof/1",
               "status": "INCOMPLETE", "inputSha256": {str(p): sha(p) for p in inputs},
               "commands": [], "controls": [],
               "boundary": "Installed native headless sound/scanner/visibility and Kahlua receiver. "
                           "No rendered or audible acceptance, wall occlusion proof, "
                           "assent, pleasure, or save intervention."}

    def save():
        (output / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n",
                                             encoding="utf-8")

    def command(label, argv, cwd):
        done = subprocess.run([str(a) for a in argv], cwd=cwd,
                              capture_output=True, timeout=120)
        log = output / (label + ".log")
        log.write_bytes(done.stdout + done.stderr)
        receipt["commands"].append({"label": label, "exitCode": done.returncode,
            "log": str(log), "logSha256": sha(log)})
        save()
        return done.returncode, log.read_text(encoding="utf-8", errors="replace")

    try:
        with tempfile.TemporaryDirectory(prefix="sao-weekone-performance-") as tmp:
            work = Path(tmp)
            classes = work / "classes"
            classes.mkdir()
            shutil.copyfile(game / "stdlib.lua", work / "stdlib.lua")
            cp = os.pathsep.join(map(str, jars))
            code, log = command("compile-native",
                [jdk / "javac.exe", "-encoding", "UTF-8", "-cp", cp,
                 "-d", classes, *SOURCES, LUA_INPUTS[0]], work)
            if code:
                raise AssertionError("native compile: " + log[-4000:])
            manifest = work / "MANIFEST.MF"
            manifest.write_text("Manifest-Version: 1.0\n"
                "Premain-Class: OrientationProbeAgent\n"
                "Can-Retransform-Classes: true\n\n", encoding="ascii")
            agent = work / "probe-agent.jar"
            code, log = command("package-agent",
                [jdk / "jar.exe", "cfm", agent, manifest, "-C", classes, "."], work)
            if code:
                raise AssertionError("native agent package: " + log[-2000:])

            native_source = PULSE.read_text(encoding="utf-8")
            lua_source = PERCEPTION.read_text(encoding="utf-8")

            def run_native(label, variant=None):
                leading = []
                if variant:
                    mutant = work / variant
                    mutant.mkdir()
                    changed = native_mutant(native_source, variant)
                    source_file = mutant / "com/sao/engine/SAOWorldSoundPulses.java"
                    source_file.parent.mkdir(parents=True)
                    source_file.write_text(changed, encoding="utf-8")
                    code, log = command("compile-" + label,
                        [jdk / "javac.exe", "-encoding", "UTF-8", "-cp",
                         str(classes) + os.pathsep + cp, "-d", mutant,
                         source_file], work)
                    if code:
                        raise AssertionError("mutant compile " + variant + ": " + log[-3000:])
                    leading = [mutant]
                run_cp = os.pathsep.join(map(str, [*leading, classes, *jars]))
                return command(label, [jdk / "java.exe",
                    "--enable-native-access=ALL-UNNAMED",
                    "-Duser.home=" + str(work), "-Djava.library.path=" + str(game),
                    "-Djava.awt.headless=true", "-javaagent:" + str(agent),
                    "-cp", run_cp, "WeekOnePerformanceHearingProbe"], work)

            code, log = run_native("native-baseline")
            rows = re.findall(r"^CHECK ([a-z0-9_]+)=(true|false)$", log, re.M)
            if code or len(rows) != 42 or any(value != "true" for _, value in rows) \
                    or "PASS Week One physical performance hearing" not in log:
                raise AssertionError("native baseline: " + log[-5000:])
            receipt["nativeChecks"] = [name for name, _ in rows]
            save()

            def run_lua(label, variant=None):
                lua = PERCEPTION
                if variant:
                    lua = output / (label + "-Perception.lua")
                    lua.write_text(lua_mutant(lua_source, variant), encoding="utf-8")
                return command(label, [jdk / "java.exe", "-cp",
                    str(classes) + os.pathsep + str(game / "projectzomboid.jar"),
                    "LuaRun", LUA_INPUTS[1], lua, LUA_INPUTS[3], "--", "true"], work)

            code, log = run_lua("lua-baseline")
            if code or "VALUE true" not in log:
                raise AssertionError("Kahlua receiver baseline: " + log[-4000:])

            if not args.baseline_only:
                native_controls = [
                    ("birth", "wrong_birth_refused"),
                    ("handle", "wrong_handle_refused"),
                    ("ended_audio", "ended_audio_refuses_claim"),
                    ("unseen_attribution", "unseen_emitter_not_identified"),
                    ("replay", "one_claim_per_listener"),
                    ("reload", "reload_discards_runtime_authority"),
                    ("emitter_age_window", "fresh_late_acquisition_claims_live_renewed_sound_once"),
                    ("stale_acquisition_window", "stale_acquisition_still_refused"),
                    ("pooled_reinit", "pooled_reinit_refuses_old_occurrence"),
                    ("removed_world_sound", "removed_world_sound_refuses_claim"),
                    ("expired_world_sound", "expired_world_sound_refuses_claim"),
                    ("proxy_identity_path", "stamped_proxy_owns_private_hearing_once"),
                    ("proxy_generation", "proxy_generation_swap_refused"),
                ]
                for variant, expected in native_controls:
                    code, log = run_native("native-control-" + variant, variant)
                    if code == 0 or f"CHECK {expected}=false" not in log:
                        raise AssertionError(variant + " failed for wrong reason: " + log[-4000:])
                    receipt["controls"].append({"layer": "native", "variant": variant,
                                                 "failedCheck": expected})
                    save()
                lua_controls = [
                    ("observer_owner", "foreign observer body entered private hearing"),
                    ("exact_handle", "source receipt handle mismatch entered private hearing"),
                    ("between_scan", "first live callback claimed performance before personal sound acquisition"),
                    ("claim_before_scan", "first live callback claimed performance before personal sound acquisition"),
                ]
                for variant, expected in lua_controls:
                    code, log = run_lua("lua-control-" + variant, variant)
                    if code == 0 or expected not in log:
                        raise AssertionError(variant + " failed for wrong reason: " + log[-4000:])
                    receipt["controls"].append({"layer": "Kahlua", "variant": variant,
                                                 "failedCheck": expected})
                    save()
            changed = {str(p): sha(p) for p in inputs}
            if changed != receipt["inputSha256"]:
                raise AssertionError("source inputs changed during proof")
            receipt["status"] = "PASS"
            save()
    except BaseException as error:
        receipt["error"] = f"{type(error).__name__}: {error}"
        save()
        raise
    print(f"PASS Week One performance hearing: {len(rows)} native checks, "
          f"1 Kahlua receiver fixture, {len(receipt['controls'])} causal controls")
    print(output / "receipt.json")


if __name__ == "__main__":
    main()
