#!/usr/bin/env python3
"""Exact private Week One hearing into the SAO cognition models on Kahlua."""
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
MODELS = ROOT / "mod/42.20/media/lua/shared/SAO_CognitiveModels.lua"
PERCEPTION = ROOT / "mod/42.20/media/lua/shared/SAO_Perception.lua"
COGNITION = ROOT / "mod/42.20/media/lua/shared/SAO_Cognition.lua"
PRELUDE = ROOT / "tools/cognition_checks/prelude.lua"
CASES = ROOT / "tools/weekone_listener_cognition_cases.lua"
RUNNER = ROOT / "tools/luacheck/LuaRun.java"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def replace_exact(source, before, after, label):
    if source.count(before) != 1:
        raise AssertionError(f"{label} source anchor count {source.count(before)}")
    return source.replace(before, after, 1)


def mutate(sources, name):
    changed = dict(sources)
    if name == "plan_receiver":
        changed["cognition"] = replace_exact(changed["cognition"],
            "pcall(C.weekOnePerformanceHearings, id)",
            "pcall(function() return true end)", name)
    elif name == "source_identity":
        changed["cognition"] = replace_exact(changed["cognition"],
            'sourceId = "BanditsWeekOne:SAOPerform",',
            'sourceId = "invented",', name)
    elif name == "generic_authority":
        changed["cognition"] = replace_exact(changed["cognition"],
            ' or supplied.kind=="weekone-performance-hearing"', "", name)
    elif name == "hobby_promotion":
        changed["models"] = replace_exact(changed["models"],
            'elseif e.kind == "weekone-instrument-performance" then\n'
            '        retain("hobby", "leisure", true, e.actionKind)',
            'elseif e.kind == "weekone-instrument-performance" or '
            'e.kind == "weekone-performance-hearing" then\n'
            '        retain("hobby", "leisure", true, e.actionKind)', name)
    elif name == "pulse_binding":
        changed["models"] = replace_exact(changed["models"],
            'and e.pulseId==e.sourceEpoch.."-"..tostring(e.sourceSequence)',
            'and true', name)
    elif name == "pleasure_boundary":
        changed["models"] = replace_exact(changed["models"],
            'and e.succeeded==nil and e.stats==nil and e.detail==nil',
            'and e.stats==nil and e.detail==nil', name)
        changed["models"] = replace_exact(changed["models"],
            'and not HOBBY_KINDS[e.kind] and (e.actionKind~=nil or e.succeeded~=nil)',
            'and not HOBBY_KINDS[e.kind] and e.kind~="weekone-performance-hearing" '
            'and (e.actionKind~=nil or e.succeeded~=nil)', name)
    elif name == "retired_cursor":
        changed["cognition"] = replace_exact(changed["cognition"],
            "if position > prior then", "if true then", name)
        changed["cognition"] = replace_exact(changed["cognition"],
            "if prior and position <= prior then", "if false then", name)
        changed["models"] = replace_exact(changed["models"],
            "if previousPosition and position<=previousPosition then",
            "if false then", name)
    elif name == "single_hearing_promotion":
        changed["cognition"] = replace_exact(changed["cognition"],
            'out.status = "single-hearing"',
            'out.status = "supported-exploration"; out.informationGain = 0.2', name)
    elif name == "passive_repetition_promotion":
        changed["cognition"] = replace_exact(changed["cognition"],
            'out.status = "familiarity-only"',
            'out.status = "supported-exploration"; out.informationGain = 0.2', name)
    elif name == "own_action_ignored":
        changed["cognition"] = replace_exact(changed["cognition"],
            "if latestOwn.succeeded == true then", "if false then", name)
    elif name == "failed_action_ignored":
        changed["cognition"] = replace_exact(changed["cognition"],
            "if latestOwn.succeeded == true then", "if true then", name)
    elif name == "time_separation_omitted":
        changed["cognition"] = replace_exact(changed["cognition"],
            "and later.nativeEmittedAtHours - earlier.nativeEmittedAtHours >= 0.05 then",
            "and true then", name)
    elif name == "own_action_chronology":
        changed["cognition"] = replace_exact(changed["cognition"],
            "latestOwn.occurredAtHours > first.occurredAtHours",
            "true", name)
    elif name == "source_county_clock_ignored":
        changed["cognition"] = replace_exact(changed["cognition"],
            "now, r.countyAtHours or r.atHours)",
            "now, r.atHours)", name)
    elif name == "legacy_source_clock_fabricated":
        changed["cognition"] = replace_exact(changed["cognition"],
            "x.nativeCompletedAtHours = r.countyAtHours and r.atHours or nil",
            "x.nativeCompletedAtHours = r.atHours", name)
    elif name == "source_native_completion_erased":
        changed["cognition"] = replace_exact(changed["cognition"],
            "x.nativeCompletedAtHours = r.countyAtHours and r.atHours or nil",
            "x.nativeCompletedAtHours = nil", name)
    elif name == "source_own_action_ignored":
        changed["cognition"] = replace_exact(changed["cognition"],
            'or x.kind == "weekone-instrument-performance"\n'
            '                        and x.nativeCompletedAtHours ~= nil)',
            'or false)', name)
    elif name == "native_completion_order_relaxed":
        changed["models"] = replace_exact(changed["models"],
            "and e.nativeCompletedAtHours>=e.startedAtHours)",
            "and e.nativeCompletedAtHours>=0)", name)
    elif name == "source_native_future_allowed":
        changed["cognition"] = replace_exact(changed["cognition"],
            "not finite(r.atHours, r.startedAtHours, nativeNow)",
            "not finite(r.atHours, r.startedAtHours, now)", name)
    elif name == "domain_bleed":
        changed["cognition"] = replace_exact(changed["cognition"],
            'if enabled and frame.domain == "leisure-action" then',
            'if enabled then', name)
    elif name == "all_options":
        changed["cognition"] = replace_exact(changed["cognition"],
            'if candidate.kind == "instrument"\n'
            '                    and finite(candidate.informationGain, 0, 1)',
            'if (candidate.kind == "instrument" or candidate.kind == "reading")\n'
            '                    and finite(candidate.informationGain, 0, 1)', name)
    else:
        raise ValueError(name)
    return changed


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
    inputs = [MODELS, PERCEPTION, COGNITION, PRELUDE, CASES, RUNNER,
              game / "projectzomboid.jar", game / "stdlib.lua",
              Path(__file__), ROOT / "tools/native_proof_preflight.py"]
    preflight = installed_presence(inputs, game, jdk,
                                   "Week One listener cognition")
    if preflight is not None:
        raise SystemExit(preflight)
    receipt = {"schema": "sao-weekone-listener-cognition-proof/1",
               "status": "INCOMPLETE",
               "inputSha256": {str(p): sha(p) for p in inputs},
               "commands": [], "controls": [],
               "boundary": "Actual SAO Perception, Cognition and both CognitiveModels on "
                           "installed Kahlua with controlled native hearing source. "
                           "No game launch, audio hardware or rendered acceptance."}

    def save():
        (output / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n",
                                             encoding="utf-8")

    def command(label, argv, cwd):
        result = subprocess.run([str(a) for a in argv], cwd=cwd,
                                capture_output=True, timeout=120)
        log_file = output / (label + ".log")
        log_file.write_bytes(result.stdout + result.stderr)
        receipt["commands"].append({"label": label, "exitCode": result.returncode,
            "log": str(log_file), "logSha256": sha(log_file)})
        save()
        return result.returncode, log_file.read_text(encoding="utf-8", errors="replace")

    try:
        with tempfile.TemporaryDirectory(prefix="sao-weekone-listener-") as tmp:
            work = Path(tmp)
            shutil.copyfile(game / "stdlib.lua", work / "stdlib.lua")
            code, log = command("compile-lua-runner",
                [jdk / "javac.exe", "-encoding", "UTF-8", "-cp",
                 game / "projectzomboid.jar", "-d", work, RUNNER], work)
            if code:
                raise AssertionError("Kahlua runner compile: " + log[-4000:])
            sources = {"models": MODELS.read_text(encoding="utf-8"),
                       "cognition": COGNITION.read_text(encoding="utf-8")}

            def run(label, variant=None):
                code = mutate(sources, variant) if variant else sources
                home = output / label
                home.mkdir()
                models = home / "SAO_CognitiveModels.lua"
                cognition = home / "SAO_Cognition.lua"
                models.write_text(code["models"], encoding="utf-8")
                cognition.write_text(code["cognition"], encoding="utf-8")
                return command(label, [jdk / "java.exe", "-cp",
                    os.pathsep.join([str(work), str(game / "projectzomboid.jar")]),
                    "LuaRun", PRELUDE, models, PERCEPTION, cognition, CASES,
                    "--", "__weekOneListenerResult"], work)

            code, log = run("baseline")
            match = re.search(r"VALUE PASS Week One listener cognition (\d+)", log)
            if code or not match or int(match.group(1)) < 49:
                raise AssertionError("Kahlua listener baseline: " + log[-4000:])
            receipt["checks"] = int(match.group(1))
            save()
            if not args.baseline_only:
                controls = [
                    ("plan_receiver", "actual_plan_path_ingests_historical_hearing"),
                    ("source_identity", "actual_plan_path_ingests_historical_hearing"),
                    ("generic_authority", "generic_caller_cannot_mint_hearing"),
                    ("hobby_promotion", "hearing_is_not_hobby_success"),
                    ("pulse_binding", "model_refuses_wrong_pulse"),
                    ("pleasure_boundary", "model_refuses_fake_pleasure"),
                    ("retired_cursor", "repeated_passive_hearing_is_familiarity"),
                    ("single_hearing_promotion", "single_hearing_stays_neutral"),
                    ("passive_repetition_promotion", "repeated_passive_hearing_is_familiarity"),
                    ("own_action_ignored", "repeated_hearing_plus_own_action_supports_exploration"),
                    ("failed_action_ignored", "latest_failed_attempt_counters_exploration"),
                    ("time_separation_omitted", "near_occurrences_do_not_make_interest"),
                    ("own_action_chronology", "prior_action_does_not_claim_response"),
                    ("source_county_clock_ignored", "source_performance_clocks_preserved"),
                    ("legacy_source_clock_fabricated", "legacy_native_time_does_not_invent_county_order"),
                    ("source_native_completion_erased", "source_performance_clocks_preserved"),
                    ("source_own_action_ignored", "source_own_performance_supports_private_exploration"),
                    ("native_completion_order_relaxed", "model_refuses_native_completion_before_start"),
                    ("source_native_future_allowed", "future_native_completion_refused"),
                    ("domain_bleed", "unrelated_plan_domain_untouched"),
                    ("all_options", "bounded_private_music_option_effect"),
                ]
                for variant, expected in controls:
                    code, log = run("control-" + variant, variant)
                    if code == 0 or "WEEKONE_LISTENER:" + expected not in log:
                        raise AssertionError(variant + " failed for wrong reason: " + log[-4000:])
                    receipt["controls"].append({"variant": variant,
                                                 "failedCheck": expected})
                    save()
            after = {str(p): sha(p) for p in inputs}
            if after != receipt["inputSha256"]:
                raise AssertionError("source inputs changed during cognition proof")
            receipt["status"] = "PASS"
            save()
    except BaseException as error:
        receipt["error"] = f"{type(error).__name__}: {error}"
        save()
        raise
    print(f"PASS Week One listener cognition: {receipt['checks']} Kahlua checks, "
          f"{len(receipt['controls'])} causal controls")
    print(output / "receipt.json")


if __name__ == "__main__":
    main()
