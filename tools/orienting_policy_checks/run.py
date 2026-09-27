#!/usr/bin/env python3
"""Execute private orienting candidates in installed Kahlua with defect controls.

Native bodies and admission are controlled fixtures here. This instrument proves
Lua ownership/cue semantics, not pose, animation, occlusion or loaded gameplay.
"""
from __future__ import annotations

import argparse
import sys
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

HERE=Path(__file__).resolve().parent
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('root',nargs='?',type=Path,default=HERE.parents[1])
parser.add_argument('--zao-root',type=Path)
parser.add_argument('--output',type=Path)
args=parser.parse_args()
ROOT=args.root.resolve()
ZAO=(args.zao_root or ROOT.parent/'zombie-awareness').resolve()
GAME=Path(os.environ.get('PZ_DIR',r'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'))
JDK=Path(os.environ.get('JDK_BIN',r'C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin'))
PZ=GAME/'projectzomboid.jar'
_output_directory=tempfile.TemporaryDirectory(prefix='sao-orienting-proof-')
OUTPUT=args.output or Path(_output_directory.name)/'verification.json'
FILES={
    'perception':ROOT/'mod/42.20/media/lua/shared/SAO_Perception.lua',
    'orienting':ROOT/'mod/42.20/media/lua/shared/SAO_Orienting.lua',
    'driver':ZAO/'mod/42.20/media/lua/client/ZAO_Driver.lua',
    'neuro':ROOT/'mod/42.20/media/lua/shared/SAO_Neuro.lua',
}
CONTROLS = [
    ("refresh_is_new_pulse", "perception", "then cue.lastHeardAt = tick end",
     "then cue.lastHeardAt = tick cue.heardAt = tick end", "native_refusal_expires_despite_refresh"),
    ("malformed_token_admitted", "perception", "or not validSoundToken(fields[6]) or not body",
     "or fields[6] == nil or not body", "malformed_occurrences_refused"),
    ("restored_runtime_authority", "perception", "    soundPulses = {}\n    if SAO.Orienting",
     "    -- restored defect: soundPulses retained\n    if SAO.Orienting", "bind_clears_runtime_authority"),
    ("repeat_admission", "orienting", "and row.consumed[cue.cueId] == nil then",
     "and true then", "timestamp_refresh_never_restarts"),
    ("refusal_reported_success", "orienting",
     'if not admittedOk or admitted ~= true then return false, "native-refused" end',
     'if not admittedOk then return false, "native-refused" end', "native_refusal_remains_retryable"),
    ("sleeping_body_admitted", "orienting", "and body:isDead() == false and body:isAsleep() == false",
     "and body:isDead() == false", "native_sleeping_refused"),
    ("owner_token_ignored", "orienting", "or context.bodyOwnerToken ~= rec.bodyOwnerToken then return nil end",
     "then return nil end", "owner_token_mismatch_refused"),
    ("source_reservation_ignored", "orienting", "if rec.worldSourceReservation ~= nil then return false end",
     "if false then return false end", "source_owner_read_is_nonmutating"),
    ("route_pivots_body", "orienting", "and (not job or job.done == true)",
     "and true", "route_only_admits_head_without_mutation"),
    ("neuro_projection_bypassed", "orienting",
     "return SAO.Neuro.clarityOf(rec), SAO.Neuro.motorSteadiness(rec)",
     "return 1, 1", "neuro_state_shapes_response"),
    ("zao_admission_unwired", "driver", "if SAO and SAO.Orienting then",
     "if false then", "crossed_driver_admits_after_own_policy"),
    ("queue_ownership_ignored", "orienting",
     "if queue and type(queue.queue) == \"table\" and #queue.queue > 0 then return false end",
     "if false then return false end", "driver_new_timed_action_prevents_glance"),
]


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    if not PZ.is_file() or not (JDK/'javac.exe').is_file() or not (JDK/'java.exe').is_file():
        print('SKIPPED: installed game and JDK required for orienting policy proof'); return 0
    if not FILES['driver'].is_file():
        print('SKIPPED: sibling ZAO source required for orienting policy proof'); return 0
    OUTPUT.parent.mkdir(parents=True,exist_ok=True)
    receipt = {"boundary": "Installed Kahlua; controlled body/native admission fixtures; no native pose claim",
               "sources": {key: {"path": str(path), "sha256": sha(path)} for key, path in FILES.items()},
               "engine_sha256": sha(PZ), "runs": []}
    expected = set(re.findall(r'check\("([a-z0-9_]+)",', (HERE / "cases.lua").read_text(encoding="utf-8")))
    expected |= {f"native_{field}_refused" for field in ("sleeping", "dead", "attack", "aim", "climb", "rope")}
    expected |= {f"{terminal}_driver_admits_after_own_policy" for terminal in ("afflicted", "crossed")}

    def command(args, work, label):
        result = subprocess.run(list(map(str, args)), cwd=work, capture_output=True,
                                text=True, encoding="utf-8", errors="replace", timeout=60)
        receipt["runs"].append({"label": label, "exit": result.returncode,
                                "stdout": result.stdout, "stderr": result.stderr})
        return result

    try:
        with tempfile.TemporaryDirectory(prefix="kahlua-") as temporary:
            work = Path(temporary)
            classes = work / "classes"
            classes.mkdir()
            done = command([JDK / "javac.exe", "-encoding", "UTF-8", "-cp", PZ,
                            "-d", classes, ROOT / "tools/luacheck/LuaRun.java"], work, "compile-runner")
            if done.returncode:
                raise RuntimeError("Kahlua runner compile failed: " + done.stderr)
            shutil.copy2(GAME / "stdlib.lua", work / "stdlib.lua")

            def execute(label, changed=None, text=None):
                paths = dict(FILES)
                if changed:
                    mutation = work / (label + ".lua")
                    mutation.write_text(text, encoding="utf-8")
                    paths[changed] = mutation
                done = command([JDK / "java.exe", "-Djava.awt.headless=true", "-cp",
                                os.pathsep.join(map(str, (classes, PZ))), "LuaRun", HERE / "prelude.lua",
                                ROOT / "mod/42.20/media/lua/shared/SAO_Hash.lua", paths["neuro"],
                                paths["perception"], paths["orienting"], paths["driver"],
                                HERE / "cases.lua", "--", "__orientingResults"], work, label)
                checks = dict(re.findall(r"^([a-z0-9_]+)=(true|false)$", done.stdout.replace("VALUE ", ""), re.M))
                if done.returncode or set(checks) != expected:
                    raise RuntimeError(f"{label}: exit={done.returncode}; missing={sorted(expected-set(checks))}; "
                                       f"unexpected={sorted(set(checks)-expected)}; {done.stdout[-2500:]}")
                return checks

            checks = execute("candidate")
            bad = [name for name, verdict in checks.items() if verdict != "true"]
            if bad:
                raise RuntimeError("candidate failures: " + ", ".join(bad))
            receipt["cases"] = len(checks)
            receipt["controls"] = []
            for label, source, before, after, target in CONTROLS:
                baseline = FILES[source].read_text(encoding="utf-8-sig")
                if baseline.count(before) != 1:
                    raise RuntimeError(label + ": mutation anchor did not match exactly once")
                changed = baseline.replace(before, after, 1)
                if changed == baseline or after not in changed:
                    raise RuntimeError(label + ": mutation did not land")
                checks = execute(label, source, changed)
                if checks[target] != "false":
                    raise RuntimeError(label + ": named defect did not flip " + target)
                receipt["controls"].append({"name": label, "target": target, "verdict": checks[target],
                                             "source_sha256": hashlib.sha256(changed.encode()).hexdigest()})
            receipt["status"] = "passed"
    except Exception as error:
        receipt["status"], receipt["error"] = "failed", str(error)
    OUTPUT.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: receipt.get(key) for key in ("status", "cases", "error")}))
    if receipt.get("status") == "passed":
        print(f"CONTROLS {len(receipt['controls'])} named defects reproduced")
    return 0 if receipt.get("status") == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
