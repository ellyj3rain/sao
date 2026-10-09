#!/usr/bin/env python3
"""Exercise the source companion lease in installed Kahlua with inverses."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
GAME = Path(os.environ.get("PZ_DIR", r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"))
JDK = Path(os.environ.get("JDK_BIN", r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin"))
LUA = ROOT / "mod/42.20/media/lua"
SOURCES = {
    "communication": LUA / "shared/SAO_Communication.lua",
    "locomotion": LUA / "client/SAO_Locomotion.lua",
    "body": LUA / "client/SAO_Body.lua",
    "crossed": LUA / "client/SAO_CrossedTransfer.lua",
    "companion": LUA / "client/SAO_CompanionExecution.lua",
}
CASES = ROOT / "tools/companion_execution_cases.lua"
RUNNER = ROOT / "tools/luacheck/LuaRun.java"
CONTROLS = [
    ("live-auth-open", "companion",
     'function C.requestGrant() return false, "peer-auth-unavailable" end',
     'function C.requestGrant() return true, "admitted" end',
     "live_grant_peer_auth_closed"),
    ("horse-admitted", "companion",
     'goal.x, goal.y, goal.z, goal.running == true, { footOnly = true })',
     'goal.x, goal.y, goal.z, goal.running == true, { footOnly = false })',
     "foot_route_excludes_horse"),
    ("companion-adapter-overwrite", "communication",
     'and Communication.executionOwners[ownerId] ~= adapter then return false end',
     'and false then return false end',
     "companion_adapter_replacement_refused"),
    ("terminal-journal-omitted", "crossed",
     'rec.zaoTransferPending = pending or { token = token,\n            atHours = tonumber(atHours), terminalState = terminal }',
     'rec.zaoTransferPending = pending or { token = "wrong-token",\n            atHours = tonumber(atHours), terminalState = terminal }',
     "terminal_transition_held_under_companion"),
    ("terminal-before-cancel-omitted", "companion",
     'recordResult(grant, requestId, "interrupted", reason)',
     '-- omitted exact interrupted terminal',
     "terminal_written_before_exact_route_cancel"),
    ("foreign-checkpoint-omitted", "body",
     'and rec.bodyOwner:sub(1, 10) == "companion:")\n            and body and not rec.dead',
     'and rec.bodyOwner:sub(1, 10) == "not-our-one")\n            and body and not rec.dead',
     "companion_foreign_body_save_checkpoint"),
    ("claim-interrupts-study", "companion",
     'if rec.cookingWork or rec.studyWork and rec.studyWork.status == "reading" then\n        return false, "work-pending"\n    end',
     'if false then return false, "work-pending" end',
     "study_claim_refuses_without_interrupt"),
    ("reload-returns-immediately", "companion",
     'queueReturn(rec, rec.zaoTransferPending and "zao-terminal"\n                or "grant-expired")',
     'queueReturn(rec, rec.zaoTransferPending and "zao-terminal"\n                or "grant-expired")\n            retryReturn(rec)',
     "reload_only_queues_readiness"),
    ("death-owner-cleanup-omitted", "companion",
     'if observed then settleDeadOwner(grant.owner, rec) end',
     'if observed then return end',
     "companion_death_uses_external_death"),
]


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    out = (args.output or ROOT / "_scratch/d2-leisure-01/companion-execution24" /
           datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S-%f")).resolve()
    out.mkdir(parents=True, exist_ok=False)
    inputs = [*SOURCES.values(), CASES, RUNNER, Path(__file__),
              GAME / "projectzomboid.jar", GAME / "stdlib.lua"]
    before = {str(path): sha(path) for path in inputs}
    shutil.copy2(GAME / "stdlib.lua", out / "stdlib.lua")
    compiled = subprocess.run([str(JDK / "javac.exe"), "-encoding", "UTF-8",
        "-cp", str(GAME / "projectzomboid.jar"), "-d", str(out), str(RUNNER)],
        cwd=out, capture_output=True, text=True, timeout=120)
    (out / "compile.log").write_text(compiled.stdout + compiled.stderr,
                                      encoding="utf-8")
    if compiled.returncode:
        print(compiled.stderr)
        return 2
    classpath = os.pathsep.join((str(GAME / "projectzomboid.jar"), str(out)))
    source_text = {name: path.read_text(encoding="utf-8-sig")
                   for name, path in SOURCES.items()}
    assert "C._fixture" not in source_text["companion"], "test hook shipped"
    # Production never exports the grant path; only the temporary test copy
    # makes private functions callable by this controlled Kahlua fixture.
    hook = ('C._fixture = { claim = function(p, r) '
            'r.requestId = r.requestId or ("test-" .. tostring(r.grantId)); '
            'return claimVerified(p, r) end, rawClaim = claimVerified, '
            'attempt = attemptVerified, '
            'revoke = revokeVerified, result = function(grantId, requestId) '
            'return finalResults[grantId] and finalResults[grantId][requestId] end }\n'
            'return C\n')

    def run(label: str, changed: dict[str, str]) -> dict:
        files = []
        for name in SOURCES:
            body = changed.get(name, source_text[name])
            if name == "companion":
                assert body.count("return C\n") == 1
                body = body.replace("return C\n", hook)
            target = out / f"{label}-{name}.lua"
            target.write_text(body, encoding="utf-8")
            files.append(target)
        command = [str(JDK / "java.exe"), "-cp", classpath,
                   "LuaRun", str(CASES), *map(str, files), "--",
                   "companionExecutionCases()"]
        done = subprocess.run(command, cwd=out, capture_output=True,
                              text=True, timeout=120)
        log = out / f"{label}.log"
        log.write_text(done.stdout + done.stderr, encoding="utf-8")
        value = re.findall(r"(?m)^VALUE (.+)$", done.stdout)
        failed = value[0].split(":", 1)[1].split(",") if value and ":" in value[0] else []
        return {"label": label, "exitCode": done.returncode, "value": value,
                "failed": [name for name in failed if name], "logSha256": sha(log)}

    results = [run("production", {})]
    valid = results[0]["exitCode"] == 0 and len(results[0]["value"]) == 1 \
        and results[0]["failed"] == []
    for label, module, old, new, expected in CONTROLS:
        assert source_text[module].count(old) == 1, f"control anchor {label}"
        changed = {module: source_text[module].replace(old, new, 1)}
        result = run(label, changed)
        results.append(result)
        valid = valid and result["exitCode"] == 0 and expected in result["failed"]
    after = {str(path): sha(path) for path in inputs}
    valid = valid and before == after
    receipt = {"schema": "sao.companion-execution-source/1",
        "status": "PASS" if valid else "FAIL",
        "boundary": "Installed Kahlua executes real SAO source against controlled native body, queue, route, save and ZAO callbacks. Private verified principal is injected into a temporary test copy only. Production live grant, real named-peer authentication, native game and save remain unobserved and unavailable. The custody token remains on the existing internal record/native modData seam and is never peer authorization or emitted in a command receipt.",
        "inputsBefore": before, "inputsAfter": after,
        "productionChecks": results[0]["value"], "runs": results}
    (out / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n",
                                      encoding="utf-8")
    for result in results:
        print(result["label"], result["exitCode"], result["value"],
              result["failed"])
    print("receipt=" + str(out / "receipt.json"))
    return 0 if valid else 1


if __name__ == "__main__":
    raise SystemExit(main())
