#!/usr/bin/env python3
"""Production D3 Controller connectors, planner and installed native window repair.

Private source offers/transfers, locomotion, bodies/map/network, and the Build
owner's cancellation acknowledgement are controlled boundaries. Actual repair
complete() effects reach isolated native IsoWindow/ItemContainer receivers.
No live game, renderer, map or save is opened.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import time

sys.dont_write_bytecode = True
import window_repair_test as native
from native_proof_preflight import presence

ROOT = pathlib.Path(__file__).resolve().parent.parent
CASES = ROOT / "tools/luacheck/d3_construction_controller_cases.lua"
CANDIDATE = ROOT / "mod/42.20/media/java/SAO.jar"
BUILD = ROOT / "mod/42.20/media/lua/client/SAO_Build.lua"
INSPECT = ROOT / "mod/42.20/media/lua/client/SAO_Inspect.lua"
EXPECTED = {
    "d3_controller_boarding_admission_does_not_increment_inspection",
    "d3_controller_canonical_board_completion_updates_inspection",
    "d3_controller_repeated_board_terminal_does_not_double_inspection",
    "d3_controller_unacknowledged_board_result_has_no_inspection_count",
    "d3_controller_adoption_flushes_board_count_without_prior_agent",
    "d3_controller_saved_board_counter_replay_is_once_only",
    "d3_controller_interrupted_board_result_has_no_inspection_count",
    "d3_controller_invalid_failed_board_result_has_no_inspection_count",
    "d3_controller_existing_session_board_count_is_preserved",
    "d3_controller_same_aperture_accepts_next_completed_plank",
    "d3_controller_next_plank_pending_admission_survives_replan",
    "d3_controller_sequential_planks_complete_once_each_after_saved_replay",
    "d3_controller_returned_repair_waits_for_native_turn",
    "d3_controller_returned_repair_reacquires_after_native_turn",
    "d3_controller_returned_board_waits_without_refusal",
    "d3_controller_returned_board_reacquires_after_native_turn",
    "d3_controller_changed_entry_does_not_orient",
    "d3_controller_exact_craft_inputs_after_240_items",
    "d3_controller_exact_craft_inputs_at_512_bound",
    "d3_controller_craft_over_native_inventory_bound_unavailable",
    "d3_controller_exact_repair_inputs_after_240_items",
    "d3_controller_repair_uses_actual_held_target_eligibility",
    "d3_controller_repair_dispatches_private_file_acquisition",
    "d3_controller_repair_dispatches_exact_native_inputs",
    "d3_controller_repair_admission_preserves_construction_destination",
    "d3_controller_saved_repair_result_flushes_without_work",
    "d3_controller_repair_resumes_planks_under_original_purpose",
    "d3_controller_native_repair_guard_installs",
    "d3_controller_missing_pane_retains_observed_purpose",
    "d3_controller_unknown_private_material_stays_blocked",
    "d3_controller_dispatches_exact_material_identity",
    "d3_controller_material_admission_has_no_construction_credit",
    "d3_controller_pending_material_admission_is_preserved",
    "d3_controller_authenticated_transfer_preserves_construction_purpose",
    "d3_controller_returns_through_production_travel",
    "d3_controller_reacquires_exact_native_repair_target",
    "d3_controller_native_repair_consumes_pane_and_closes_same_purpose",
    "d3_controller_changed_aperture_blocks_repair",
    "d3_controller_changed_standing_blocks_repair",
    "d3_controller_blocked_repair_allows_observed_boarding",
    "d3_controller_blocked_board_allows_ready_window_repair",
    "d3_controller_ready_repair_keeps_unfinished_board_purpose",
    "d3_controller_ready_repair_completion_keeps_unfinished_board_purpose",
    "d3_controller_pending_board_material_admission_blocks_ready_repair",
    "d3_controller_boarding_uses_native_owner_without_eager_bridge",
    "d3_controller_board_cancellation_preflight_holds_for_ack",
    "d3_controller_zao_transfer_waits_for_board_ack",
    "d3_controller_zao_transfer_resumes_after_board_ack",
    "d3_controller_death_requests_board_cancellation_and_retains_ack",
    "d3_controller_late_board_ack_retires_without_live_agent",
    "d3_controller_adoption_reconciles_actual_saved_window_owner",
    "d3_controller_saved_recovery_preserves_goal_without_completion_credit",
    "d3_controller_idle_holds_for_window_cancellation_ack",
    "d3_controller_reconciliation_accepts_exact_late_window_ack",
    "d3_controller_unavailable_board_target_retains_bounded_deferral",
    "d3_controller_new_visible_boarding_preserves_deferred_purpose",
    "d3_controller_craft_acquires_private_log",
    "d3_controller_craft_acquires_private_saw",
    "d3_controller_dispatches_craft_before_return_travel",
    "d3_controller_restored_craft_result_flushes_without_work",
    "d3_controller_crafted_planks_return_to_original_entry",
    "d3_controller_crafted_planks_resume_same_boarding_purpose",
}


def production_controller(source: str) -> str:
    # Reuse the existing verified complete-function extraction. Add the actual
    # resourceContext producer, travel entrypoint and BOARDING hold consumer.
    resource = native.section(source, "function Ctl.resourceContext(id, agent, body, needs, category, pressure, hydrationIntent)",
                              "-- This read-only preflight uses the same private means")
    board_hold = native.section(source, '    if agent.state == "BOARDING" then',
                                '    if agent.state == "WARMING" then')
    home_number = native.section(source, "local function homeRouteNumber(value)", "local function sameHomeRoute(")
    adoption = native.section(source, "function Ctl.adopt(rec)", "-- Passive adoption ([A17])")
    return (home_number + "\n" + native.controller(source) + "\n" + resource
            + "\nlocal function closeUnownedCognitionOnAdoption() end\n"
              "Ctl.reconcileWeekOneCompanion=function() return false end\n" + adoption
            + "\n__d3OrderTravel=orderTravelState\n"
              "__d3BoardHold=function(id,agent,body,tick) tickCount=tick\n" + board_hold + "end\n")


def execute(out: pathlib.Path, sources: dict[str, str], classes: pathlib.Path) -> dict:
    out.mkdir()
    shutil.copy2(native.GAME / "stdlib.lua", out / "stdlib.lua")
    files = []
    for name, source in sources.items():
        target = out / name
        target.write_text(source, encoding="utf-8")
        files.append(str(target))
    command = [str(native.JDK / "java.exe"), "-cp",
               f"{native.GAME / 'projectzomboid.jar'};{CANDIDATE};{classes}",
               "WindowRepairNativeProbe", *files]
    started = time.monotonic()
    done = subprocess.run(command, cwd=out, capture_output=True, encoding="utf-8", timeout=90)
    log = done.stdout + done.stderr
    log_path = out / "output.log"
    log_path.write_text(log, encoding="utf-8")
    found = dict(re.findall(r"(d3_controller_[a-z0-9_]+)=(true|false)", log))
    return {"command": command, "exitCode": done.returncode, "elapsedSeconds": round(time.monotonic() - started, 3),
            "checks": found, "failed": sorted(key for key, value in found.items() if value != "true"),
            "missing": sorted(EXPECTED - found.keys()), "extra": sorted(found.keys() - EXPECTED),
            "runtimeError": "D3_ERROR=" in log,
            "outputSha256": native.digest(log_path), "outputLog": str(log_path)}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=pathlib.Path)
    parser.add_argument("--required", action="store_true")
    args = parser.parse_args()
    owned = [pathlib.Path(__file__).resolve(), CASES, CANDIDATE, BUILD, INSPECT,
             native.P, native.W, native.C, native.I, native.MODELS, native.COGNITION,
             native.FIXTURE, native.PROBE, ROOT / "tools/window_repair_test.py", ROOT / "tools/native_proof_preflight.py"]
    installed = [*native.NATIVE, native.GAME / "projectzomboid.jar", native.GAME / "stdlib.lua",
                 native.JDK / "java.exe", native.JDK / "javac.exe"]
    unavailable = presence(owned, installed, args.required, "D3 construction Controller")
    if unavailable is not None:
        return unavailable
    temporary = tempfile.TemporaryDirectory(prefix="sao-d3-controller-") if args.out is None else None
    out = pathlib.Path(temporary.name) / "proof" if temporary else args.out.resolve()
    if out.exists():
        raise ValueError("refuse replacing prior proof")
    out.mkdir(parents=True)
    before = {str(path): native.digest(path) for path in owned + installed}
    classes = out / "classes"
    classes.mkdir()
    command = [str(native.JDK / "javac.exe"), "-cp", str(native.GAME / "projectzomboid.jar"),
               "-d", str(classes), str(native.PROBE)]
    compiled = subprocess.run(command, cwd=out, capture_output=True, encoding="utf-8", timeout=90)
    (out / "compile.log").write_text(compiled.stdout + compiled.stderr, encoding="utf-8")
    if compiled.returncode:
        print("D3 Controller compile FAILED\n" + (compiled.stdout + compiled.stderr)[-3000:])
        return 1
    controller_source = native.C.read_text(encoding="utf-8-sig")
    sources = {"fixture.lua": native.FIXTURE.read_text(encoding="utf-8-sig")}
    sources.update({f"native-{index}.lua": path.read_text(encoding="utf-8-sig") for index, path in enumerate(native.NATIVE)})
    sources.update({"models.lua": native.MODELS.read_text(encoding="utf-8-sig"),
                    "cognition.lua": native.COGNITION.read_text(encoding="utf-8-sig"),
                    "planner.lua": native.P.read_text(encoding="utf-8-sig"),
                    "boarding.lua": BUILD.read_text(encoding="utf-8-sig"),
                    "repair.lua": native.W.read_text(encoding="utf-8-sig"),
                    "controller.lua": production_controller(controller_source),
                    "inspection.lua": "__d3InspectBoarded=function(id)\nlocal jsonl,rows={},{}\n"
                        "local function row(value) rows[#rows+1]=value end\n"
                        + native.section(INSPECT.read_text(encoding="utf-8-sig"),
                            "    -- [C44] What they have actually built,", "    -- [C37] On your word:")
                        + "\nreturn jsonl.boarded,rows\nend\n",
                    "cases.lua": CASES.read_text(encoding="utf-8-sig"),
                    "run.lua": "local ok,reason=pcall(__runD3ConstructionControllerCases)\n"
                               "if not ok then __windowResults=table.concat(__checks,'\\n')..'\\nD3_ERROR='..tostring(reason) end"})
    normal = execute(out / "normal", sources, classes)
    mutations = [
        ("completed-construction-purpose-reuse", "planner.lua",
         'purpose.key == key and purpose.status ~= "completed"', 'purpose.key == key',
         "d3_controller_same_aperture_accepts_next_completed_plank"),
        ("boarding-inspection-completion-projection", "controller.lua",
         "if outcome.status == \"completed\" then count = count + 1 end", "do end",
         "d3_controller_canonical_board_completion_updates_inspection"),
        ("boarding-inspection-result-cursor", "controller.lua",
         'type(sequence) == "number" and sequence > cursor',
         'type(sequence) == "number" and sequence > 0',
         "d3_controller_repeated_board_terminal_does_not_double_inspection"),
        ("boarding-inspection-planning-acknowledgement", "controller.lua",
         "if not outcome or outcome.planningAcknowledged ~= true then break end",
         "if not outcome then break end",
         "d3_controller_unacknowledged_board_result_has_no_inspection_count"),
        ("boarding-inspection-adoption-projection", "controller.lua",
         "agent.boarded = tonumber(rec.boarded) or 0", "do end",
         "d3_controller_adoption_flushes_board_count_without_prior_agent"),
        ("boarding-inspection-interrupted-rejection", "controller.lua",
         'if outcome.status == "completed" then count = count + 1 end',
         'if outcome.status == "completed" or outcome.status == "interrupted" then count = count + 1 end',
         "d3_controller_interrupted_board_result_has_no_inspection_count"),
        ("blocked-board-ready-window-fallback", "controller.lua",
         'if not retained.pendingAdmission and retained.operation == "board"\n'
         '                and Ctl.tryWindowRepair(id, agent, body, tick) then return true end',
         "do end", "d3_controller_blocked_board_allows_ready_window_repair"),
        ("ready-window-fallback-pending-admission", "controller.lua",
         'if not retained.pendingAdmission and retained.operation == "board"',
         'if retained.operation == "board"',
         "d3_controller_pending_board_material_admission_blocks_ready_repair"),
        ("construction-native-turn-before-offer", "controller.lua",
         "if Ctl.orientConstructionEntry(body, retained) then return true end", "do end",
         "d3_controller_returned_repair_waits_for_native_turn"),
        ("construction-orientation-target-anchor", "controller.lua",
         'or target:getNorth() ~= (north == "true") then return false end', "then return false end",
         "d3_controller_changed_entry_does_not_orient"),
        ("construction-exact-carried-range", "controller.lua",
         "math.min(items:size(), 512)", "math.min(items:size(), 240)",
         "d3_controller_exact_craft_inputs_after_240_items"),
        ("construction-native-inventory-bound", "controller.lua",
         "and read and items and items:size() <= 512", "and read and items and true",
         "d3_controller_craft_over_native_inventory_bound_unavailable"),
        ("repair-target-identity", "controller.lua",
         'targetItemId = context.craftInputs.sawItemId, targetItemType = context.craftInputs.sawItemType',
         'targetItemId = "wrong-held-target", targetItemType = context.craftInputs.sawItemType',
         "d3_controller_repair_dispatches_private_file_acquisition"),
        ("repair-file-revision", "controller.lua",
         'sourceRevision = step.sourceRevision, itemId = step.itemId, itemType = step.itemType',
         'sourceRevision = step.category == "file" and 0 or step.sourceRevision, itemId = step.itemId, itemType = step.itemType',
         "d3_controller_repair_dispatches_private_file_acquisition"),
        ("missing-pane-observation", "repair.lua", "local pane = inv and inv:getFirstTypeEval(PANE, availablePane)",
         "local pane = inv and inv:getFirstTypeEval(PANE, availablePane); if not pane then return nil end",
         "d3_controller_missing_pane_retains_observed_purpose"),
        ("exact-acquisition-revision", "controller.lua",
         "sourceRevision = step.sourceRevision, itemId = step.itemId, itemType = step.itemType",
         "sourceRevision = nil, itemId = step.itemId, itemType = step.itemType",
         "d3_controller_dispatches_exact_material_identity"),
        ("construction-return-route", "controller.lua",
         '"TRAVEL", "returns to an observed construction task"',
         '"ROAM", "returns to an observed construction task"',
         "d3_controller_returns_through_production_travel"),
        ("exact-aperture-reacquisition", "controller.lua",
         "owner.offer(id, body, entryKey)", "owner.offer(id, body)",
         "d3_controller_changed_aperture_blocks_repair"),
        ("eager-boarding-regression", "controller.lua",
         "if owner.begin(id, body, offer, purpose.id, step.id) then",
         "SAOJavaBridge:boardWindow(body,0,0,0)\n    if owner.begin(id, body, offer, purpose.id, step.id) then",
         "d3_controller_boarding_uses_native_owner_without_eager_bridge"),
        ("private-material-knowledge", "controller.lua",
         "if p and SAO.WorldSources.privatelyKnowsItem(id, p.sourceId, p.itemId)", "if p",
         "d3_controller_unknown_private_material_stays_blocked"),
        ("boarding-state-cancellation-preflight", "controller.lua", 'if state ~= "BOARDING" and SAO.Build',
         "if false and SAO.Build", "d3_controller_board_cancellation_preflight_holds_for_ack"),
        ("zao-boarding-cancellation-preflight", "controller.lua",
         'if SAO.Build and SAO.Build.interrupt(id, body, "zao-person-ownership-transfer") ~= true then return end',
         "if false then return end", "d3_controller_zao_transfer_waits_for_board_ack"),
        ("death-boarding-cancellation", "controller.lua",
         'if SAO.Build then SAO.Build.interrupt(id, body, "death") end', "do end",
         "d3_controller_death_requests_board_cancellation_and_retains_ack"),
        ("construction-adoption-reconciliation", "controller.lua",
         "Ctl.reconcileConstruction(rec.id, SAO.Body.get(rec.id))", "do end",
         "d3_controller_adoption_reconciles_actual_saved_window_owner"),
        ("construction-idle-reconciliation", "controller.lua",
         "if not Ctl.reconcileConstruction(id, body) then return false end", "do end",
         "d3_controller_idle_holds_for_window_cancellation_ack"),
        ("unavailable-target-deferral", "controller.lua",
         "if SAO.ProceduralPlanning.deferConstructionTarget(id, purpose.id, retained.entryKey,\n"
         '        "the observed boarding entry is not currently offered by its native owner") then',
         "if false then", "d3_controller_unavailable_board_target_retains_bounded_deferral"),
        ("new-visible-boarding-fallback", "controller.lua",
         "return Ctl.tryBoarding(id, agent, body, tick)\n    end", "return false\n    end",
         "d3_controller_new_visible_boarding_preserves_deferred_purpose"),
        ("craft-dispatch-before-return", "controller.lua",
         'if step.verb == "produce" then return Ctl.beginConstructionProduction(id, agent, body, tick, purpose, step) end\n    if math.floor(body:getX())',
         'if step.verb == "produce" then return false end\n    if math.floor(body:getX())',
         "d3_controller_dispatches_craft_before_return_travel"),
        ("saved-craft-outcome-flush", "controller.lua", 'SAO.Build or {}, SAO.ResourceProduction or {}',
         'SAO.Build or {}', "d3_controller_restored_craft_result_flushes_without_work"),
    ]
    # The installed action/native material guard has its independent controls;
    # only the new Controller joins are mutated in this bounded instrument.
    controls = []
    for name, filename, old, new, expected in mutations:
        text = sources[filename]
        if old not in text or old == new:
            controls.append({"name": name, "landed": False, "killed": False, "expectedFailure": expected})
            continue
        mutant = dict(sources)
        mutant[filename] = text.replace(old, new, 1)
        result = execute(out / name, mutant, classes)
        result.update({"name": name, "landed": mutant[filename] != text, "expectedFailure": expected,
                       "killed": result["checks"].get(expected) == "false"})
        controls.append(result)
    after = {str(path): native.digest(path) for path in owned + installed}
    passed = normal["exitCode"] == 0 and not normal["runtimeError"] and not normal["failed"] and not normal["missing"] and not normal["extra"]
    passed = passed and all(control["landed"] and control["killed"] for control in controls) and before == after
    receipt = {"schema": 1, "passed": passed, "inputSha256Before": before, "inputSha256After": after,
               "unchangedInputs": before == after, "compileCommand": command, "compileExitCode": compiled.returncode,
               "candidateJarSha256": before[str(CANDIDATE)], "normal": normal, "controls": controls,
               "production": ["Controller resource/construction context, exact acquisition connector, travel/state/death/transfer/adoption/reconciliation",
                              "Build canonical outcome validation, planner flush and acknowledgement; existing Inspect boarded projection",
                              "ProceduralPlanning maintained purpose/admission/canonical result consumption",
                              "WindowRepair native actor/target/material/queue admission, installed AddWindowAction completion, serialized saved-work recovery"],
               "controlled": ["private source offers and SourceUse native transfer terminal", "Locomotion route admission/arrival",
                              "actor, surrounding map, Standing inputs, native queue dispatch and network sync",
                              "bridge carried inventory and construction-material count projection",
                              "unrelated Week One and cognition adoption ports",
                              "Build physical terminal effects and cancellation request/acknowledgement boundary"],
               "unverified": ["loaded gameplay", "physical SourceUse transfer and physical barricade execution in this instrument"]}
    receipt_path = out / "receipt.json"
    receipt_path.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(f"D3 construction Controller {'PASS' if passed else 'FAIL'}: {len(normal['checks'])}/{len(EXPECTED)} cases, "
          f"{sum(control['killed'] for control in controls)}/{len(controls)} motivating controls")
    print(f"Receipt: {receipt_path}")
    if not passed:
        print("Failed=" + repr(normal["failed"]) + " missing=" + repr(normal["missing"]))
        for control in controls:
            if not control["killed"]:
                print("Control failed: " + control["name"] + " expected=" + control["expectedFailure"])
        if normal["exitCode"] or normal["runtimeError"]:
            print(pathlib.Path(normal["outputLog"]).read_text(encoding="utf-8")[-2500:])
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
