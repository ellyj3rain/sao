#!/usr/bin/env python3
"""Installed Kahlua proof of SAO-authored chronology for external adults.

Runs production History and Age with the installed game VM and native table
serialization. Does not run or modify the game or a save.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys

from native_proof_preflight import installed_presence

ROOT = Path(__file__).resolve().parents[1]
GAME = Path(os.environ.get("PZ_DIR", r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"))
JDK = Path(os.environ.get("JDK_BIN", r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin"))
SHARED = ROOT / "mod/42.20/media/lua/shared"
CLIENT = ROOT / "mod/42.20/media/lua/client"
SOURCES = {
    "hash": SHARED / "SAO_Hash.lua",
    "history": SHARED / "SAO_History.lua",
    "age": CLIENT / "SAO_Age.lua",
    "cases": ROOT / "tools/external_adult_chronology_cases.lua",
}
RUNNER = ROOT / "tools/luacheck/PhysicalMeansLuaProbe.java"
PRELUDE = """SAO={Log={line=function()end}}
require=function()end
Events={EveryTenMinutes={Add=function()end}}
"""
CONTROLS = [
    ("no-admitted-age", "return chronology.ageAtAdmission + years",
     "if chronology then return 6 end", "EXTERNAL_ADULT_CHRONOLOGY:adult_age_birth_year"),
    ("no-admitted-birth-year", "if chronology then return chronology.birthYear end",
     "if chronology then return 1993 end", "EXTERNAL_ADULT_CHRONOLOGY:adult_age_birth_year"),
    ("age-without-source", 'schema = EXTERNAL_ADULT_SCHEMA,\n        ageAuthorship = "SAO",',
     'schema = EXTERNAL_ADULT_SCHEMA,\n        ageAuthorship = "BanditsWeekOne",',
     "invalid-external-adult-chronology"),
    ("hash-derived-adult-age", "local okRoll, roll = pcall(ZombRand, ADULT_AGE_TOTAL)",
     'local okRoll, roll = true, hashOf(rec.id, "external-adult-age") % ADULT_AGE_TOTAL',
     "forbidden-external-age-hash"),
    ("saved-weekone-migration-disabled", "savedWeekOnePerson = true,",
     "savedWeekOnePerson = false,", "external-adult-chronology-unavailable:bwo-saved"),
    ("generated-never-ages", "return baseline + years",
     "return baseline", "EXTERNAL_ADULT_CHRONOLOGY:generated_residents_age_during_midgame"),
    ("january-first-exact-birthday", "if years > 0 and (month < admittedMonth",
     "if false and (month < admittedMonth",
     "EXTERNAL_ADULT_CHRONOLOGY:unknown_birthday_does_not_age_on_january_first"),
    ("allocation-unchecked", "or value.schema == EXTERNAL_ADULT_SCHEMA\n"
     "                and validAdultAllocation(value.allocation, value.ageAtAdmission)",
     "or value.schema == EXTERNAL_ADULT_SCHEMA\n                and true",
     "EXTERNAL_ADULT_CHRONOLOGY:corrupt_chronology_refused"),
    ("existing-past-overwritten", "or rec.epistemicMonths ~= nil or rec.birthYear ~= nil) then",
     "or false) then", "EXTERNAL_ADULT_CHRONOLOGY:existing_history_refused"),
    ("saved-education-birth-ignored", "priorBirth = profile.birthYear",
     "priorBirth = nil", "EXTERNAL_ADULT_CHRONOLOGY:saved_weekone_retains_education_birth_prior"),
    ("unverified-body-admitted", "evidence.nativeDefaultScaleBody ~= true",
     "false", "EXTERNAL_ADULT_CHRONOLOGY:adult_body_evidence_required"),
]


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path,
                        default=ROOT / "_scratch/d2-leisure-01/external-adult-chronology01")
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    required = [*SOURCES.values(), Path(__file__), RUNNER, GAME / "projectzomboid.jar",
                GAME / "stdlib.lua", JDK / "javac.exe", JDK / "java.exe"]
    preflight = installed_presence(required, GAME, JDK, "external adult chronology")
    if preflight is not None:
        raise SystemExit(preflight)
    pins = {str(path): digest(path) for path in required}
    receipt = {"schema": "sao.external-adult-chronology-proof/3", "status": "INCOMPLETE",
               "inputs": pins, "runs": [],
               "boundary": "Installed Kahlua and native table roundtrip; no native game or rendered body"}

    def save() -> None:
        (out / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")

    def command(*argv: object) -> subprocess.CompletedProcess[str]:
        return subprocess.run([str(arg) for arg in argv], cwd=out, text=True,
                              capture_output=True, timeout=120)

    save()
    built = command(JDK / "javac.exe", "-cp", GAME / "projectzomboid.jar",
                    "-d", out, RUNNER)
    (out / "compile.log").write_text(built.stdout + built.stderr, encoding="utf-8")
    receipt["compile"] = {"exitCode": built.returncode, "logSha256": digest(out / "compile.log")}
    save()
    if built.returncode != 0:
        raise RuntimeError("probe compile failed: " + built.stderr[:600])
    shutil.copyfile(GAME / "stdlib.lua", out / "stdlib.lua")
    (out / "prelude.lua").write_text(PRELUDE, encoding="utf-8")
    originals = {key: path.read_text(encoding="utf-8") for key, path in SOURCES.items()}
    variants = [("production", None, None, None), *CONTROLS]
    for name, old, new, expected in variants:
        history = originals["history"]
        if old is not None:
            if history.count(old) != 1:
                raise RuntimeError(f"{name}: control target drifted: {history.count(old)}")
            history = history.replace(old, new)
        for key, text in originals.items():
            candidate = history if key == "history" else text
            if key == "cases":
                candidate = ("__step='start'; local ok, why = pcall(function()\n"
                             + candidate + "\nend); if not ok then "
                             "error('after ' .. tostring(__step) .. ': ' .. tostring(why)) end")
            (out / f"{key}.lua").write_text(candidate, encoding="utf-8")
        ran = command(JDK / "java.exe", "-cp",
                      os.pathsep.join((str(GAME / "projectzomboid.jar"), str(out))),
                      "PhysicalMeansLuaProbe", "prelude.lua", "hash.lua", "history.lua",
                      "age.lua", "cases.lua", "--", "__result")
        log = out / f"{name}.log"
        log.write_text(ran.stdout + ran.stderr, encoding="utf-8")
        receipt["runs"].append({"name": name, "exitCode": ran.returncode,
                                "log": log.name, "logSha256": digest(log),
                                "expectedFailure": expected})
        save()
        if expected:
            if ran.returncode == 0 or expected not in ran.stdout:
                raise RuntimeError(f"{name}: inverse did not fail for {expected}: {ran.stdout[-600:]}")
        elif ran.returncode != 0 or "PASS external adult chronology:" not in ran.stdout:
            raise RuntimeError(f"production failed: {ran.stdout[-1200:]} {ran.stderr[-600:]}")
        print(name + ": " + (ran.stdout.strip().splitlines()[-1] if ran.stdout else ran.stderr[-300:]),
              flush=True)
    if pins != {str(path): digest(path) for path in required}:
        raise RuntimeError("relevant inputs changed during proof")
    receipt["status"] = "PASS"
    save()


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("FAIL external adult chronology: " + str(exc), file=sys.stderr)
        raise SystemExit(1)
