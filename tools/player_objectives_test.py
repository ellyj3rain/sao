#!/usr/bin/env python3
"""Exercise the native player request against real social-process Lua owners."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parent.parent
LUA = ROOT / "mod/42.20/media/lua"
TOOLS = ROOT / "tools"
GAME = Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
JDK = Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    files = {
        "organization": LUA / "shared/SAO_Organization.lua",
        "communication": LUA / "shared/SAO_Communication.lua",
        "coordination": LUA / "shared/SAO_Coordination.lua",
        "objectives": LUA / "client/SAO_PlayerObjectives.lua",
        "controller": LUA / "client/SAO_Controller.lua",
        "harness": LUA / "client/SAO_Harness.lua",
        "neighbours": LUA / "client/SAO_Neighbours.lua",
        "prelude": TOOLS / "player_objectives_prelude.lua",
        "cases": TOOLS / "player_objectives_cases.lua",
        "runner": TOOLS / "luacheck/LuaRun.java",
        "game": GAME / "projectzomboid.jar",
        "stdlib": GAME / "stdlib.lua",
        "script": Path(__file__),
    }
    receipt: dict = {"schema": "sao-player-objective/1", "status": "INCOMPLETE",
                     "inputsBefore": {}, "runs": [], "controls": [],
                     "boundary": "Installed Kahlua executes real Organization, Communication, Coordination and player objective source under controlled bodies/native hearing and route/posture receipts. Explicit menu Review requires the helper's current conversation and canonical three-step completion, then records one player inspection in the durable Organization process; the helper's private completion experience remains separate. The retained record is evidence for later replay-backed research evaluation, not a sao.objective-candidate/1 export or training admission. Controller production seam is audited by source and prior coordination execution evidence; no loaded game or rendered menu claim."}

    def save() -> None:
        (out / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n",
                                           encoding="utf-8")

    def fail(reason: str) -> int:
        receipt["status"] = "FAIL"
        receipt["failure"] = reason
        save()
        print("FAIL", reason)
        return 1

    if any(not p.is_file() for p in files.values()) or not (JDK / "java.exe").is_file() \
            or not (JDK / "javac.exe").is_file():
        return fail("required source, installed game VM or JDK absent")
    receipt["inputsBefore"] = {name: sha(path) for name, path in files.items()}
    source = files["objectives"].read_text(encoding="utf-8")
    controller = files["controller"].read_text(encoding="utf-8")
    harness = files["harness"].read_text(encoding="utf-8")
    neighbours = files["neighbours"].read_text(encoding="utf-8")
    required = [
        ('["cooperative-action"] = true' in controller, "existing supported native matter"),
        ('SAO.Posture.begin(id, body' in controller, "existing posture owner"),
        ('"route:travelling"' in files["organization"].read_text(encoding="utf-8")
         or '"route:" .. route.phase' in files["organization"].read_text(encoding="utf-8"),
         "existing movement receipt"),
        ('H.addObjectiveOptions(person, playerObj, nearId)' in harness,
         "ordinary person menu"),
        ('SAO.Harness.addObjectiveOptions(sub, playerObj, recId)' in neighbours,
         "superimposed person menu"),
        ('nearId, worldobjects, context)' in harness,
         "superimposed root prediction checks actual menu"),
        ('SAO.PlayerObjectives.mark(playerObj,' in harness, "square marker menu"),
    ]
    if not all(ok for ok, _ in required):
        return fail("native integration seam missing: " + ", ".join(
            name for ok, name in required if not ok))
    receipt["integrationSeams"] = [name for _, name in required]

    with tempfile.TemporaryDirectory(prefix="sao-player-objective-") as temp:
        work = Path(temp)
        shutil.copy2(files["stdlib"], work / "stdlib.lua")
        classpath = os.pathsep.join([str(files["game"]), str(work)])
        compile_run = subprocess.run([
            str(JDK / "javac.exe"), "-encoding", "UTF-8", "-cp",
            str(files["game"]), "-d", str(work), str(files["runner"]),
        ], cwd=work, capture_output=True, text=True, timeout=120)
        (out / "compile.log").write_text(compile_run.stdout + compile_run.stderr,
                                          encoding="utf-8")
        if compile_run.returncode:
            return fail("Kahlua runner compile failed")

        def run(name: str, objective_path: Path,
                communication_path: Path = files["communication"],
                neighbours_path: Path = files["neighbours"],
                organization_path: Path = files["organization"]) -> tuple[int, str]:
            command = [str(JDK / "java.exe"), "-cp", classpath, "LuaRun",
                       str(files["prelude"]), str(organization_path),
                       str(communication_path), str(files["coordination"]),
                       str(objective_path), str(files["harness"]),
                       str(neighbours_path), str(files["cases"]),
                       "--", "__result"]
            done = subprocess.run(command, cwd=work, capture_output=True,
                                  text=True, timeout=120)
            output = done.stdout + done.stderr
            log = out / (name + ".log")
            log.write_text(output, encoding="utf-8")
            receipt["runs"].append({"name": name, "exitCode": done.returncode,
                                    "logSha256": sha(log)})
            save()
            return done.returncode, output

        code, output = run("production", files["objectives"])
        match = re.search(r"VALUE (\d+)", output)
        if code != 0 or not match or int(match[1]) < 44:
            return fail("production owner exercise failed: " + output[-1300:])
        receipt["checks"] = int(match[1])
        controls = [
            ("player-body-binding", "or SAO.Communication.bodyFor(key) ~= playerObj",
             "or false", "foreign_player_refused"),
            ("external-owner-binding", "or rec.bodyOwner ~= nil",
             "or false", "foreign_owner_refused"),
            ("native-hearing", "and SAO.Communication.canConverse(key, id) == true",
             "and true", "unheard_request_refused"),
            ("withdrawal-conversation", 'local key = nearby(playerObj, tostring(id or ""))',
             "local key = playerBody(playerObj)", "remote_withdrawal_refused"),
            ("return-dependency", 'sameActorAs = "watch", dependsOn = { "watch" },',
             'sameActorAs = "watch", dependsOn = { "outbound" },',
             "outbound_arrival_distinct"),
            ("return-coordinate-proof", "and route.x == scope.returnX",
             "and true", "review_requires_exact_return_route"),
            ("return-arrival-proof", 'if route.id == receiptId and route.status == "arrived"',
             "if route.id == receiptId and true",
             "review_requires_arrived_return"),
            ("unreturned-answer-private",
             "local response = view.responses and view.responses[id]",
             "local response = process.participants[id].responses[tostring(view.revision)]",
             "unreturned_answer_stays_private"),
            ("work-report-not-invented", "workReportDelivered = report ~= nil",
             "workReportDelivered = true", "accepted_without_work_report"),
        ]
        for name, original, replacement, marker in controls:
            if source.count(original) != 1:
                return fail(name + " mutation seam changed")
            mutant = work / (name + ".lua")
            mutant.write_text(source.replace(original, replacement, 1),
                              encoding="utf-8")
            code, output = run(name, mutant)
            if code == 0 or "PLAYER_OBJECTIVE:" + marker not in output:
                return fail(name + " did not fail named verdict: " + output[-900:])
            receipt["controls"].append({"name": name, "failedVerdict": marker})
            save()
        for name, file_key, original, replacement, marker in [
            ("all-player-slots", "communication", "for slot = 0, 3 do",
             "for slot = 0, 0 do", "player_slot_1_resolves_supplied_body"),
            ("missing-original-root", "neighbours",
             "return originalPersonRoot(context, ns, actor) ~= nil",
             "return true", "missing_neighbour_root_fallback"),
            ("work-report-transport", "communication",
             "objectiveReportCapability = { processId = processId,\n        fromId = fromId, toId = toId }",
             "objectiveReportCapability = nil",
             "returned_helper_delivers_exact_work_report"),
            ("work-report-forgery", "organization",
             "if not (SAO.Communication and SAO.Communication.objectiveReportTransport",
             "if false and not (SAO.Communication and SAO.Communication.objectiveReportTransport",
             "direct_work_receipt_cannot_forge_report"),
            ("return-route-place", "organization",
             "or back.x ~= scope.returnX or back.y ~= scope.returnY",
             "or false or back.y ~= scope.returnY",
             "changed_return_route_cannot_be_reported"),
            ("return-route-status", "organization",
             "or back.status ~= \"arrived\" or out.x ~= dest.minX",
             "or false or out.x ~= dest.minX",
             "interrupted_return_cannot_be_reported"),
            ("review-player-body", "organization",
             "or not bodyOk or body ~= playerObj",
             "or not bodyOk or false",
             "same_key_foreign_body_cannot_claim_player_review"),
            ("review-return-receipt", "organization",
             "identity(returnReceiptId) ~= report.returnReceiptId",
             "false", "wrong_return_receipt_cannot_claim_player_review"),
            ("review-duplicate", "organization",
             "if process.objectivePlayerReviews[reviewKey] then",
             "if false then", "duplicate_player_review_is_idempotent"),
            ("review-report-source", "organization",
             "or report.outboundReceiptId ~= receipts.outbound",
             "or false", "tampered_report_source_receipt_refused"),
            ("review-native-receipt-id", "organization",
             "or receipt.receiptId ~= receiptId",
             "or false", "tampered_watch_receipt_id_refuses_review"),
            ("review-attempt-receipt", "organization",
             "and receipt.status == status and finite(route.startedAt)",
             "and finite(route.startedAt)",
             "mismatched_attempt_receipt_is_excluded"),
        ]:
            current = files[file_key].read_text(encoding="utf-8")
            if current.count(original) != 1:
                return fail(name + " mutation seam changed")
            mutant = work / (name + ".lua")
            mutant.write_text(current.replace(original, replacement, 1),
                              encoding="utf-8")
            kwargs = {file_key + "_path": mutant}
            code, output = run(name, files["objectives"], **kwargs)
            if code == 0 or "PLAYER_OBJECTIVE:" + marker not in output:
                return fail(name + " did not fail named verdict: " + output[-900:])
            receipt["controls"].append({"name": name, "failedVerdict": marker})
            save()
    receipt["inputsAfter"] = {name: sha(path) for name, path in files.items()}
    if receipt["inputsBefore"] != receipt["inputsAfter"]:
        return fail("source changed while qualification was running")
    receipt["status"] = "PASS"
    save()
    print(f"PASS player objectives {receipt['checks']} checks, "
          f"{len(receipt['controls'])} inverse controls")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
