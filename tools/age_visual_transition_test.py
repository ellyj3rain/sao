#!/usr/bin/env python3
"""Run age presentation and inverse controls in the installed Kahlua VM."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
CASES = ROOT / "tools/age_visual_transition_cases.lua"
RESOLVER = ROOT / "mod/42.20/media/lua/client/SAO_AgeVisual.lua"
BODY = ROOT / "mod/42.20/media/lua/client/SAO_Body.lua"
RUNNER = ROOT / "tools/luacheck/LuaRun.java"
PRELUDE = ROOT / "tools/luacheck/probe_age.lua"
HASH = ROOT / "mod/42.20/media/lua/shared/SAO_Hash.lua"
HISTORY = ROOT / "mod/42.20/media/lua/shared/SAO_History.lua"
GAME = Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
JDK = Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
AGE_SOURCE_ROOT = Path(os.environ.get(
    "SAO_AGE_SOURCE_ROOT",
    r"C:\Users\jleyv\Peanut Butter\OpenAI\Codex\2026-10-03\task-2\appearance-scratch",
))
INDEX_REF = "storage-repack-v1/index.json"
INDEX_SHA = "579ac9032e21e37ca3616876d181e443aeb0e74411a39e93d9032d8fd83cbdad"
INPUTS_REF = "advanced-character/generation-inputs.json"
INPUTS_SHA = "3c45e38d653d93ec86a15d329a70b280cf730887f6ecece882a09d22be72a66f"
ARCHIVE_REF = "storage-repack-v1/batches/batch-021688627092.tar.zst"
ARCHIVE_SHA = "b0404887136d1a178646becbc6e8debe155069a735fca0097db8b97ca646464a"
STUDY_REF = "advanced-character/mpfb-study/same_person_proportion_study.blend"
STUDY_SHA = "7de10d43b59f46cef6b3a369b7f9dd1dcd905a914492c3edf844fb2ff46d1b57"
STUDY_MANIFEST_REF = "advanced-character/mpfb-study/manifest.json"
STUDY_MANIFEST_SHA = "b327de27269db6f24b51d428fe3e414cf759f8146ac9f74d7ba2d855f8c04788"
BABY_REF = "advanced-character/baby-anatomy/baby_anatomy_probe.blend"
BABY_SHA = "23c8ed6622fd5b3f768c7d26fb0fa70c35085e8ea19282a5ef8719b5b42433f8"
BABY_MANIFEST_REF = "advanced-character/baby-anatomy/manifest.json"
BABY_MANIFEST_SHA = "896c39dfb953818d2bd6dc0915a1bcafd390ed57cce0c18db6366df484949b21"
CHILD_REF = "advanced-character/child-anatomy/child_anatomy_revised.blend"
CHILD_SHA = "2e0b510f4582c28bc369eae6d8b2c5675dd0ecc0b1553e1313fc770aaf0aaca0"
CHILD_MANIFEST_REF = "advanced-character/child-anatomy/manifest.json"
CHILD_MANIFEST_SHA = "cc8de5a57cad10abc8dd5f69ac4b7d4f1feb120ee8436b62143f6bc4bc7901ed"


def sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def verify_age_sources(resolver_text: str) -> dict:
    """Verify source identities, archive index entries, and illustrative ages."""
    pins = {
        INDEX_REF: INDEX_SHA, INPUTS_REF: INPUTS_SHA,
        ARCHIVE_REF: ARCHIVE_SHA, STUDY_MANIFEST_REF: STUDY_MANIFEST_SHA,
        BABY_MANIFEST_REF: BABY_MANIFEST_SHA,
        CHILD_MANIFEST_REF: CHILD_MANIFEST_SHA,
    }
    checks = {}
    actual = {}
    for ref, expected in pins.items():
        path = AGE_SOURCE_ROOT / ref
        actual[ref] = sha(path) if path.is_file() else None
        checks[f"hash:{ref}"] = actual[ref] == expected

    scene_pins = {
        BABY_REF: BABY_SHA, CHILD_REF: CHILD_SHA, STUDY_REF: STUDY_SHA,
    }
    if checks[f"hash:{INDEX_REF}"]:
        index = json.loads((AGE_SOURCE_ROOT / INDEX_REF).read_text(encoding="utf-8"))
        entries = index.get("files", {})
        for ref, expected in scene_pins.items():
            entry = entries.get(ref, {})
            checks[f"indexed:{ref}"] = (
                entry.get("path") == ref and entry.get("sha256") == expected
                and entry.get("archive") == ARCHIVE_REF
                and entry.get("archiveSHA256") == ARCHIVE_SHA
                and entry.get("rawRemoved") is True
            )
    else:
        for ref in scene_pins:
            checks[f"indexed:{ref}"] = False

    if checks[f"hash:{INPUTS_REF}"]:
        inputs = json.loads((AGE_SOURCE_ROOT / INPUTS_REF).read_text(encoding="utf-8"))
        actual_ages = [row.get("sampleAgeYears") for row in inputs.get("samples", [])]
        checks["illustrative-age-inputs"] = (actual_ages == [0, 8, 15, 31, 72]
            and all(row.get("simulatedCondition") == "living"
                    for row in inputs.get("samples", [])))
    else:
        checks["illustrative-age-inputs"] = False

    if checks[f"hash:{STUDY_MANIFEST_REF}"]:
        study = json.loads((AGE_SOURCE_ROOT / STUDY_MANIFEST_REF).read_text(encoding="utf-8"))
        study_cases = {case.get("name"): case.get("illustrativeAgeYears")
                       for case in study.get("cases", [])}
        checks["study-cases"] = (study.get("blendSha256") == STUDY_SHA
            and study.get("ageControlsAreGameAges") is False
            and study_cases.get("teen_target_probe") == 15
            and study_cases.get("adult_reference") == 31
            and study_cases.get("elder_target_probe") == 72)
    else:
        checks["study-cases"] = False

    if checks[f"hash:{BABY_MANIFEST_REF}"]:
        baby = json.loads((AGE_SOURCE_ROOT / BABY_MANIFEST_REF).read_text(encoding="utf-8"))
        checks["baby-scene"] = (baby.get("blendSha256") == BABY_SHA
            and isinstance(baby.get("revised"), dict))
    else:
        checks["baby-scene"] = False
    if checks[f"hash:{CHILD_MANIFEST_REF}"]:
        child = json.loads((AGE_SOURCE_ROOT / CHILD_MANIFEST_REF).read_text(encoding="utf-8"))
        checks["child-scene"] = (child.get("blendSha256") == CHILD_SHA
            and child.get("illustrativeAgeYears") == 8)
    else:
        checks["child-scene"] = False

    for ref, expected in {**pins, **scene_pins}.items():
        checks[f"resolver:{ref}"] = (f'appearance-scratch/{ref}' in resolver_text
                                      and expected in resolver_text)
    return {
        "status": "PASS" if all(checks.values()) else "FAIL",
        "root": str(AGE_SOURCE_ROOT),
        "expectedSha256": pins | scene_pins,
        "observedSha256": actual,
        "checks": checks,
        "boundary": "archived source scenes are indexed and their archive is hash-verified; scene extraction, native B42 operation, rendered appearance and period clothing are not tested",
    }


def command(args: list[str], work: Path, log: Path) -> dict:
    result = subprocess.run(args, cwd=work, capture_output=True, text=True,
                            timeout=120)
    log.write_text(result.stdout + result.stderr, encoding="utf-8")
    return {
        "exitCode": result.returncode,
        "values": re.findall(r"(?m)^VALUE (.*)$", result.stdout),
        "logSha256": sha(log),
    }


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: age_visual_transition_test.py <new-output-dir>")
    output = Path(sys.argv[1]).resolve()
    output.mkdir(parents=True, exist_ok=False)
    jar, stdlib = GAME / "projectzomboid.jar", GAME / "stdlib.lua"
    sources = [CASES, RESOLVER, BODY, RUNNER, PRELUDE, HASH, HISTORY,
               jar, stdlib]
    before = {str(path): sha(path) for path in sources}
    shutil.copy2(stdlib, output / "stdlib.lua")
    cp = str(jar) + ";" + str(output)
    compiled = command([str(JDK / "javac.exe"), "-encoding", "UTF-8",
                        "-cp", str(jar), "-d", str(output), str(RUNNER)],
                       output, output / "compile.log")
    if compiled["exitCode"]:
        print("Kahlua runner compile failed", output / "compile.log")
        return 2

    resolver_text = RESOLVER.read_text(encoding="utf-8")
    source_evidence = verify_age_sources(resolver_text)
    body_text = BODY.read_text(encoding="utf-8")
    controls = {
        "periodic-refresh-removed": (
            BODY, "Events.EveryTenMinutes.Add(Body.onAgePass)",
            "-- periodic age refresh removed", "growth/adult-reset"),
        "adult-scale-reset-removed": (
            BODY, "(ownedScale and near(currentScale, previous.scale))",
            "(false and near(currentScale, previous.scale))",
            "growth/adult-reset"),
        "rewind-guard-removed": (
            BODY, "if previous and view.asOfCountyHours < previous.asOfCountyHours then",
            "if false then", "clock/backward-refused"),
        "model-boundary-removed": (
            RESOLVER, "modelApplied = false,", "modelApplied = true,",
            "body/native-model-authority"),
        "period-filter-removed": (
            RESOLVER,
            "if year >= model.periodFromYear and year <= model.periodThroughYear then",
            "if true then", "period/model-not-carried-forward"),
        "source-index-pin-changed": (
            RESOLVER, f'local INDEX_SHA = "{INDEX_SHA}"',
            f'local INDEX_SHA = "{"0" * 64}"', "source/pinned-index-and-archive"),
    }

    def run(name: str, resolver: Path, body: Path) -> dict:
        return command([str(JDK / "java.exe"), "-cp", cp, "LuaRun",
                        str(CASES), str(resolver), str(body), "--",
                        "ageVisualTransitionCases()"], output,
                       output / f"{name}.log")

    production = run("production", RESOLVER, BODY)
    real_history_expression = (
        '(function() local id="age-source" '
        'GameTime={getInstance=function() return '
        '{getWorldAgeHours=function() return 0 end,'
        'getStartYear=function() return 1993 end} end} '
        'SAOJavaBridge={daysBehindAtStart=function() return 0 end,'
        'countyInstant=function() return "1993-07-09T00:00:00" end} '
        'SAO.Identity.get=function(key) return key==id and {id=id} or nil end '
        'local v=SAO.AgeVisual.resolve({id=id}) '
        'return tostring(v and v.age==SAO.History.ageOf(id) '
        'and v.calendar.status=="available" '
        'and v.calendar.nominalAge==v.age '
        'and v.calendar.birthYear==1993-v.age '
        'and #v.modelCandidates==5 '
        'and v.modelSelection~=nil '
        'and v.modelApplied==false) end)()'
    )
    real_history = command([str(JDK / "java.exe"), "-cp", cp, "LuaRun",
                            str(PRELUDE), str(HASH), str(HISTORY),
                            str(RESOLVER), "--", real_history_expression],
                           output, output / "real-history.log")
    inverses = {}
    for name, (target, old, new, _) in controls.items():
        source = body_text if target == BODY else resolver_text
        assert source.count(old) == 1, f"{name}: mutation anchor changed"
        mutant = output / f"{name}.lua"
        mutant.write_text(source.replace(old, new), encoding="utf-8")
        inverses[name] = run(name,
                             mutant if target == RESOLVER else RESOLVER,
                             mutant if target == BODY else BODY)

    after = {str(path): sha(path) for path in sources}
    valid = (before == after and source_evidence["status"] == "PASS"
             and production["exitCode"] == 0
             and production["values"] == ["28:"]
             and real_history["exitCode"] == 0
             and real_history["values"] == ["true"])
    for name, result in inverses.items():
        expected = controls[name][3]
        valid = (valid and result["exitCode"] == 0
                 and len(result["values"]) == 1
                 and result["values"][0].startswith("28:")
                 and expected in result["values"][0])
    receipt = {
        "schema": "sao.age-visual-transition/2",
        "status": "PASS" if valid else "FAIL",
        "boundary": "installed Kahlua executes production resolver and Body against synthetic shells; age scenes remain in a verified local archive and native rendered model, game save and live play are not observed",
        "sourcePins": before,
        "ageSourceEvidence": source_evidence,
        "compile": compiled,
        "production": production,
        "realHistory": real_history,
        "inverses": inverses,
    }
    (output / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n",
                                         encoding="utf-8")
    print("age visual transition", receipt["status"])
    print("age source", source_evidence["status"])
    print("production", production["values"], "exit", production["exitCode"])
    print("real history", real_history["values"], "exit", real_history["exitCode"])
    for name, result in inverses.items():
        print(name, result["values"], "exit", result["exitCode"])
    return 0 if valid else 1


if __name__ == "__main__":
    sys.exit(main())
