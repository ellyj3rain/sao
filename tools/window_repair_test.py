#!/usr/bin/env python3
"""Exact installed window action, production fortification caller and outcome controls.

Bodies, map squares, clock, sync/network and LuaTimedAction dispatch are controlled.
The last treatment forwards installed complete() effects to isolated real native
IsoWindow/ItemContainer/InventoryItem receivers. No world, game or save is created.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod/42.20/media/lua"
W = LUA / "client/SAO_WindowRepair.lua"
P = LUA / "shared/SAO_ProceduralPlanning.lua"
C = LUA / "client/SAO_Controller.lua"
I = LUA / "shared/SAO_Identity.lua"
COGNITION = LUA / "shared/SAO_Cognition.lua"
MODELS = LUA / "shared/SAO_CognitiveModels.lua"
FIXTURE = ROOT / "tools/luacheck/window_repair_cases.lua"
LEARNING = ROOT / "tools/luacheck/window_repair_learning_cases.lua"
DISPOSAL = ROOT / "tools/luacheck/window_repair_disposal_cases.lua"
STOP = ROOT / "tools/luacheck/window_repair_stop_cases.lua"
PROBE = ROOT / "tools/luacheck/WindowRepairNativeProbe.java"
JDK = pathlib.Path(os.environ.get("JDK_BIN", r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin"))
GAME = pathlib.Path(os.environ.get("PZ_DIR", r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"))
WORKSHOP = pathlib.Path(os.environ.get("SAO_WINDOW_REPAIR_DIR", r"C:\Program Files (x86)\Steam\steamapps\workshop\content\108600\3378304610\mods\RepairableWindows\42.13"))
ACTION = WORKSHOP / "media/lua/shared/RepairableWindows/AddWindowAction.lua"
NATIVE = [GAME / "media/lua/shared/ISBaseObject.lua",
          GAME / "media/lua/shared/TimedActions/ISBaseTimedAction.lua",
          GAME / "media/lua/client/TimedActions/ISTimedActionQueue.lua",
          GAME / "media/lua/shared/Util/AdjacentFreeTileFinder.lua", ACTION]
BASE_CASES = {
    "native_edge_facing_north_same_offered", "native_edge_facing_west_same_offered",
    "native_edge_facing_north_opposite_offered", "native_edge_facing_west_opposite_offered",
    "installed_missing_pane_completes_before_material", "guard_installs_optional_native_api",
    "production_fortification_caller_admits", "admission_not_completion_or_practice",
    "planner_rejects_forged_completion", "installed_action_start_valid",
    "native_complete_measured", "durable_exact_native_outcome", "native_completion_advances_once",
    "outcome_detached_and_retained", "duplicate_requery_exact_once", "duplicate_native_complete_refuses",
    "removed_pane_prevents_native_effect", "same_id_material_substitution_refuses",
    "action_target_shadow_refuses", "unseen_window_not_offered", "behind_window_not_offered",
    "noninteraction_side_not_offered", "foreign_owner_not_admitted", "standing_before_fall_refuses",
    "modified_public_offer_refuses", "player_native_start_preserved", "player_native_complete_preserved",
    "player_transfer_before_start_preserved", "player_missing_pane_race_closed",
    "controller_owner_change_cancels_exact_work", "pending_native_cancellation_blocks_owner_change",
    "queue_refusal_no_native_effect", "clock_rewind_refuses_without_fabricated_time",
    "saved_active_work_does_not_replay_effect", "production_native_boarding_still_available",
    "actual_native_material_present", "installed_complete_real_native_poststate",
    "native_save_reload_preserves_outcome", "malformed_sparse_ledger_refuses",
    "malformed_duplicate_ledger_refuses", "malformed_future_ledger_refuses",
    "bounded_ledger_and_planner_retirement",
    "ordinary_body_without_external_token_admits", "production_completed_hold_releases",
    "production_threat_hold_interrupts", "production_deadline_hold_interrupts",
    "unacknowledged_full_ledger_refuses_new_work", "different_inventory_action_shadow_refuses",
    "partial_native_effect_recorded_without_completion", "nonplain_saved_outcome_refuses_requery",
    "installed_player_diagonal_fallback_preserved",
    "native_pending_add_membership_admits", "retained_removed_player_body_refuses",
    "native_first_validity_query_pins_player_pane",
    "ordinary_death_acknowledged_runtime_retires", "ordinary_death_retains_pending_native_owner",
    "late_native_stop_retires_without_agent", "new_body_after_native_ack_is_not_blocked",
    "independent_tick_retry_retires_after_agent_removal", "queue_absence_without_native_ack_retains",
    "world_reset_retains_until_native_ack", "world_reset_late_ack_releases_new_world_offer",
    "transfer_pending_cancels_before_resume", "transfer_pending_complete_cannot_consume_or_credit",
    "transfer_pending_retries_before_resume", "bodyless_transfer_waits_for_native_ack",
    "transfer_pending_without_controller_tick_refuses_effect", "transfer_pending_not_offered",
    "bounded_cancellation_retry_is_fair",
    "window_admission_has_no_private_experience", "window_disabled_learning_preserves_physical_completion",
    "window_disabled_learning_retains_unacknowledged_result", "window_replay_delivers_private_experience",
    "window_native_private_projection", "window_native_independent_memories",
    "window_private_experience_has_no_execution_credit", "window_learning_duplicate_is_inert",
    "window_native_restore_replay_is_inert", "window_completion_private_join",
    "window_interrupted_work_has_no_private_experience", "window_learning_fault_retains_result",
    "window_learning_fault_retries_exact_completion", "window_learning_retry_is_independent_of_planner",
    "window_learning_retirement_records_omission", "window_malformed_learning_ledger_refuses_requery",
    "window_learning_scan_budget", "window_learning_owner_budget", "window_learning_replay_is_fair",
    "window_learning_reset_rebuilds_scan",
}
EXPECTED = BASE_CASES | {f"changed_{name}_cannot_mutate" for name in
    ("body", "token", "record", "world", "floor", "distance", "window", "standing", "death", "ledger", "saved_work", "cell_membership")}
EXPECTED |= {f"disposal_player_{mode}_{case}" for mode in ("completed", "stopped", "failed", "force_cancelled")
             for case in ("first_pin", "terminal_tombstone", "cannot_recapture", "binding_collected")}
EXPECTED |= {
    "disposal_native_network_argument_names", "disposal_private_binding_token_refuses_public_access",
    "disposal_forged_binding_accessor_refuses", "disposal_npc_completed_terminal_tombstone",
    "disposal_pending_native_ack_retains_binding", "disposal_only_latest_offer_admits",
    "disposal_death_retires_unconsumed_offer", "disposal_ctor_action_collected",
    "disposal_ctor_binding_and_body_collected", "disposal_npc_completed_binding_collected",
    "disposal_original_queue_waits_for_native_ack", "disposal_abandoned_offer_retained_until_expiry",
    "disposal_replaced_offer_collected", "disposal_dead_offer_collected",
    "disposal_death_preserves_separate_corpse_owner",
    "disposal_player_duplicate_terminal_callbacks_inert", "disposal_npc_duplicate_terminal_callbacks_inert",
    "disposal_perform_refuses_replaced_queue",
    "stop_player_original_native_cleanup", "stop_npc_original_ack_and_cleanup",
    "stop_npc_original_ack_preserves_next_flags",
    "stop_player_replaced_queue_preserves_successor", "stop_player_advanced_queue_preserves_successor",
    "stop_npc_replaced_queue_ack_preserves_successor", "stop_npc_advanced_queue_ack_preserves_successor",
    "stop_player_character_shadow_refuses", "stop_player_window_shadow_refuses",
    "cancel_player_replaced_queue_preserves_successor", "cancel_player_character_shadow_refuses",
    "cancel_player_window_shadow_refuses", "perform_player_noncurrent_same_queue_refuses",
    "perform_npc_noncurrent_same_queue_refuses",
    "disposal_acknowledged_native_binding_tombstone", "disposal_tick_expires_abandoned_offers",
    "disposal_acknowledged_native_binding_collected", "disposal_expired_offer_and_body_collected",
    "disposal_offer_capacity_is_bounded", "disposal_offer_forget_releases_capacity",
    "disposal_world_reset_clears_all_offers",
}


def digest(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def section(source: str, start: str, end: str) -> str:
    if source.count(start) != 1 or source.count(end) != 1:
        raise ValueError(f"production extraction boundary changed: {start}")
    return source[source.index(start):source.index(end)]


def controller(source: str) -> str:
    """Execute complete actual functions; unrelated controller services stay controlled."""
    state = section(source, "local function setState(agent, id, state, why, answer, repairingSourceProjection)",
                    "setStateRef = setState")
    travel = section(source, "local function orderTravelState(agent, id, body, x, y, z, state, why, answer)",
                     "local function startNearbyCollection")
    home_number = section(source, "local function homeRouteNumber(value)", "local function homeRouteClock()")
    decision = section(source, "local function decideHomeAndEquipment(id, agent, body, tick, rec)",
                       "local function decideNightAndDrift(id, agent, body, tick, rec)")
    hold = section(source, '    if agent.state == "WINDOWREPAIR" then',
                   '    if agent.state == "BOARDING" then')
    construction_ticks = re.search(r"local CONSTRUCTION_WORK_TICKS = (\d+)", source).group(1)
    forget = section(source, "function Ctl.forget(id)", "function Ctl.coordinationRuntimeCount()")
    deadwork = section(source, "local function retireDeadBodyWork(id, body, rec)", "-- A body may leave SAO")
    update = section(source, "local function updateAgent(id, agent)", "-- Hearing of a death")
    markdead = section(I.read_text(encoding="utf-8-sig"), "function Identity.markDead(rec, tick, cause)",
                       "function Identity.livingCount()")
    return ("local Ctl={}\nlocal tickCount=50\nlocal CONSTRUCTION_WORK_TICKS=" + construction_ticks
            + "\nlocal PRESSURE_ANSWER,CONTACT_STATES,MOVEMENT_STATES={},{},{}\n"
              "local function log() end\nlocal function knownSource() return nil end\n"
            + "local function mayEnterBelieved() return true end\n"
            + state + "\n" + travel + "\n" + home_number + "\n" + decision
            + "\n__decideHome=decideHomeAndEquipment\n__setState=setState\n"
            + "__windowHold=function(id,agent,body,tick) tickCount=tick\n" + hold + "end\n"
            + "SAO.Controller=Ctl\nCtl.agents={}\nCtl.pendingCorpses={}\nCtl.coordinationRuntime={}\n"
              "local agentFaults={}\nlocal hostTickCount=100\nlocal Identity=SAO.Identity\n"
              "local function witnessDeath() return 'controlled' end\nlocal function tellPlayerOfDeath() end\n"
              "SAO.Locomotion={cancel=function() return true end}\nSAO.Needs.retireRecovery=function() end\n"
              "ModData={getOrCreate=function() return {} end}\n"
              "SAOJavaBridge.captureReturnLiving=function() return nil end\n"
              "SAOJavaBridge.validateHibernation=function() return false end\n"
              "SAO.CrossedTransfer={resumePending=function() __transferRetries=(__transferRetries or 0)+1 end}\n"
            + forget + "\n" + deadwork + "\n" + markdead + "\n" + update + "\n__updateAgent=updateAgent\n")


def execute(out: pathlib.Path, sources: dict[str, str], classes: pathlib.Path) -> dict:
    out.mkdir()
    shutil.copy2(GAME / "stdlib.lua", out / "stdlib.lua")
    names = []
    for name, text in sources.items():
        path = out / name
        path.write_text(text, encoding="utf-8")
        names.append(path)
    command = [str(JDK / "java.exe"), "-cp", f"{GAME / 'projectzomboid.jar'};{classes}",
               "WindowRepairNativeProbe", *(str(name) for name in names)]
    started = time.monotonic()
    done = subprocess.run(command, cwd=out, capture_output=True, encoding="utf-8", timeout=90)
    log = done.stdout + done.stderr
    (out / "output.log").write_text(log, encoding="utf-8")
    found = dict(re.findall(r"([a-z0-9_]+)=(true|false)", log))
    return {"command": command, "cwd": str(out), "exitCode": done.returncode,
            "elapsedSeconds": round(time.monotonic() - started, 3), "checks": found,
            "failed": sorted(key for key, value in found.items() if value != "true"),
            "missing": sorted(EXPECTED - found.keys()), "extra": sorted(found.keys() - EXPECTED),
            "outputSha256": digest(out / "output.log")}


def main() -> int:
    print("Border 232: Native window repair and fortification results")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=pathlib.Path)
    parser.add_argument("--required", action="store_true", help="fail when installed native dependencies are absent")
    args = parser.parse_args()
    sys.dont_write_bytecode = True
    helper = ROOT / "tools/native_proof_preflight.py"
    if not helper.is_file():
        print("FAILED window repair: owned proof inputs absent: " + str(helper))
        return 1
    from native_proof_preflight import presence, causal_controls
    owned = [pathlib.Path(__file__).resolve(), W, P, C, I, COGNITION, MODELS, FIXTURE, LEARNING, DISPOSAL, STOP, PROBE, helper]
    installed = [*NATIVE, WORKSHOP / "mod.info", GAME / "projectzomboid.jar", GAME / "stdlib.lua",
                 JDK / "java.exe", JDK / "javac.exe"]
    inputs = owned + installed
    unavailable = presence(owned, installed, args.required, "window repair")
    if unavailable is not None:
        return unavailable
    temporary = tempfile.TemporaryDirectory(prefix="sao-window-repair-") if args.out is None else None
    out = pathlib.Path(temporary.name) / "proof" if temporary else args.out.resolve()
    if out.exists():
        raise ValueError("refuse replacing prior proof")
    out.mkdir(parents=True)
    before = {str(path): digest(path) for path in inputs}
    classification = causal_controls(ROOT, pathlib.Path(__file__), owned,
        env_updates={"SAO_WINDOW_REPAIR_DIR": "{absent-extension}"}, missing_owned=W)
    classes = out / "classes"
    classes.mkdir()
    command = [str(JDK / "javac.exe"), "-cp", str(GAME / "projectzomboid.jar"), "-d", str(classes), str(PROBE)]
    done = subprocess.run(command, cwd=out, capture_output=True, encoding="utf-8", timeout=90)
    (out / "compile.log").write_text(done.stdout + done.stderr, encoding="utf-8")
    if done.returncode:
        print((done.stdout + done.stderr)[-4000:])
        return 1
    sources = {"fixture.lua": FIXTURE.read_text(encoding="utf-8-sig")}
    sources.update({f"native-{i}.lua": path.read_text(encoding="utf-8-sig") for i, path in enumerate(NATIVE)})
    sources.update({"models.lua": MODELS.read_text(encoding="utf-8-sig"),
                    "cognition.lua": COGNITION.read_text(encoding="utf-8-sig"),
                    "planner.lua": P.read_text(encoding="utf-8-sig"),
                    "repair.lua": W.read_text(encoding="utf-8-sig"),
                    "controller.lua": controller(C.read_text(encoding="utf-8-sig")),
                    "learning.lua": LEARNING.read_text(encoding="utf-8-sig"),
                    "disposal.lua": DISPOSAL.read_text(encoding="utf-8-sig"),
                    "stop.lua": STOP.read_text(encoding="utf-8-sig"),
                    "run.lua": "__runWindowCases()\n__runWindowLifecycle()\n__runWindowLearning()\n"
                               "__setupWindowDisposal()\n__observeWindowDisposal()\n__finishWindowDisposal()\n"
                               "__runWindowStopCustody()\n"})
    normal = execute(out / "normal", sources, classes)
    mutations = [
        ("squared-native-interaction-reach", "repair.lua",
         "dx * dx + dy * dy > NATIVE_WINDOW_INTERACTION_REACH * NATIVE_WINDOW_INTERACTION_REACH",
         "dx * dx + dy * dy > NATIVE_WINDOW_INTERACTION_REACH", "installed_player_diagonal_fallback_preserved"),
        ("precompletion-material-owner", "repair.lua",
         'if not b or b.preparing or self.character ~= b.body or self.window ~= b.window or b.spent or b.cancelled or not bound(b, true, false) or not self.window:isSmashed() then',
         'if not b then', "removed_pane_prevents_native_effect"),
        ("planner-private-authority", "planner.lua",
         'if purpose and purpose.windowRepair and authority ~= WINDOW_REPAIR_RESULT then return false end',
         '-- restored untrusted generic completion', "planner_rejects_forged_completion"),
        ("per-body-visible-acquisition", "repair.lua", 'body:CanSee(window) ~= true', 'false', "unseen_window_not_offered"),
        ("per-body-facing-acquisition", "repair.lua", 'facingX * body:getForwardDirectionX() + facingY * body:getForwardDirectionY() < 0',
         'false', "behind_window_not_offered"),
        ("native-edge-facing-acquisition", "repair.lua", 'local facingX, facingY = b.north and 0 or side, b.north and side or 0',
         'local facingX, facingY = dx, dy', "native_edge_facing_north_same_offered"),
        ("foreign-native-owner", "repair.lua", 'and not (SAO.Body.foreign and SAO.Body.foreign[id])',
         'and true', "foreign_owner_not_admitted"),
        ("exact-cancellation", "repair.lua", 'q:onCompleted(self)',
         'q:resetQueue()', "controller_owner_change_cancels_exact_work"),
        ("north-side-neighbor", "repair.lua", 'if b.north then other = sq:getN() else other = sq:getW() end',
         'other = b.north and sq:getN() or sq:getW()', "noninteraction_side_not_offered"),
        ("production-caller", "controller.lua", 'if Ctl.tryWindowRepair(id, agent, body, tick) then return true end\n                -- A blocked repair',
         'if false then return true end\n                -- A blocked repair', "production_fortification_caller_admits"),
        ("living-native-cell-membership", "repair.lua", 'or body:getCell() ~= b.cell or not living or not here',
         'or body:getCell() ~= b.cell or not here', "changed_cell_membership_cannot_mutate"),
        ("native-first-valid-query", "repair.lua", 'and freezePane(b) and bound(b, true, false) and nativeValid(self)',
         'and bound(b, true, false) and nativeValid(self)', "native_first_validity_query_pins_player_pane"),
        ("late-native-stop-retirement", "repair.lua", 'if active and active.binding == b then retireAcknowledged(b.personId, active) end',
         'do end', "late_native_stop_retires_without_agent"),
        ("independent-cancellation-retry", "repair.lua", 'Events.OnTick.Add(W.retryCancellations)',
         'do end', "independent_tick_retry_retires_after_agent_removal"),
        ("native-ack-before-retirement", "repair.lua", 'b.cancelled and action.action and not b.stopAcknowledged',
         'false', "queue_absence_without_native_ack_retains"),
        ("transfer-handoff-cancellation", "controller.lua",
         'if SAO.WindowRepair and SAO.WindowRepair.interrupt(id, body, "zao-person-ownership-transfer") ~= true then return end',
         'do end', "transfer_pending_cancels_before_resume"),
        ("bodyless-transfer-cancellation", "controller.lua",
         'if SAO.WindowRepair and SAO.WindowRepair.interrupt(id, nil, "zao-person-ownership-transfer") ~= true then return end',
         'do end', "bodyless_transfer_waits_for_native_ack"),
        ("pre-effect-transfer-custody", "repair.lua",
         ['and not r.zaoTransferPending and not r.crossedTransferPending',
          'or b.record.zaoTransferPending or b.record.crossedTransferPending'],
         ['and true', 'or false'], "transfer_pending_without_controller_tick_refuses_effect"),
        ("actual-completion-private-delivery", "repair.lua",
         'if person(b.personId) == r then W.deliverLearning(b.personId) end',
         'do end', "window_completion_private_join"),
        ("private-acknowledgement-after-acceptance", "repair.lua",
         'if ok and accepted == true and person(id) == r and ledger(r) == s',
         'if person(id) == r and ledger(r) == s', "window_disabled_learning_retains_unacknowledged_result"),
        ("pending-learning-omission-accounting", "repair.lua",
         'if not first or first.planningAcknowledged ~= true then return false end\n        if first.status == "completed" and first.learningAcknowledged ~= true then\n            s.learningOmitted = math.min(999999999, (s.learningOmitted or 0) + 1)',
         'if not first or first.planningAcknowledged ~= true then return false end\n        if first.status == "completed" and first.learningAcknowledged ~= true then\n            s.learningOmitted = s.learningOmitted or 0', "window_learning_retirement_records_omission"),
        ("independent-minute-learning-replay", "repair.lua",
         'Events.EveryOneMinute.Add(W.retryLearning)', 'do end', "window_replay_delivers_private_experience"),
        ("learning-scan-budget", "repair.lua", 'visited < MAX_LEARNING_SCANS', 'true', "window_learning_scan_budget"),
        ("learning-owner-budget", "repair.lua", 'owners < MAX_LEARNING_OWNERS', 'true', "window_learning_owner_budget"),
        ("learning-replay-cursor", "repair.lua", 'if learningRecords ~= records or not learningIterator then',
         'if true then', "window_learning_replay_is_fair"),
        ("learning-reset-rebuild", "repair.lua",
         'W.expireOffers()\n    learningRecords, learningIterator = nil, nil',
         'W.expireOffers()', "window_learning_reset_rebuilds_scan"),
        ("learning-registry-replacement", "repair.lua", 'if learningRecords ~= records or not learningIterator then',
         'if not learningIterator then', "window_learning_owner_budget"),
        ("restored-module-action-root", "repair.lua",
         ['local BINDING_TOKEN = {}',
          'action._SAOWindowRepairBinding = function(token) if token == BINDING_TOKEN then return b end end'],
         ['local BINDING_TOKEN = {}\nlocal retainedBindings = setmetatable({}, {__mode="k"})',
          'action._SAOWindowRepairBinding = function(token) if token == BINDING_TOKEN then return b end end\n            retainedBindings[action] = b'],
         "disposal_ctor_action_collected"),
        ("terminal-binding-disposal", "repair.lua",
         '    action._SAOWindowRepairBinding = false\n    return true',
         '    do end\n    return true', "disposal_player_completed_binding_collected"),
        ("abandoned-offer-tick-expiry", "repair.lua", 'Events.OnTick.Add(W.expireOffers)',
         'do end', "disposal_tick_expires_abandoned_offers"),
        ("unconsumed-offer-death-retirement", "repair.lua", 'function W.forget(id)\n    id = tostring(id)\n    retireOffer(id)',
         'function W.forget(id)\n    id = tostring(id)\n    do end', "disposal_death_retires_unconsumed_offer"),
        ("per-person-offer-replacement", "repair.lua", 'function W.offer(id, body, entryKey)\n    id = tostring(id)\n    retireOffer(id)',
         'function W.offer(id, body, entryKey)\n    id = tostring(id)\n    do end', "disposal_only_latest_offer_admits"),
        ("offer-finite-capacity", "repair.lua", 'offerCount >= MAX_OFFERS',
         'false', "disposal_offer_capacity_is_bounded"),
        ("native-constructor-argument-names", "repair.lua",
         ['function base:new(character, window)', 'nativeNew(self, character, window)'],
         ['function base:new(body, window)', 'nativeNew(self, body, window)'],
         "disposal_native_network_argument_names"),
        ("private-binding-token", "repair.lua", 'if token == BINDING_TOKEN then return b end',
         'return b', "disposal_private_binding_token_refuses_public_access"),
        ("released-action-perform-fallback", "repair.lua",
         'if not b or self.character ~= b.body or self.window ~= b.window then return false end\n        if not queued(self) then',
         'if not b then return nativePerform(self) end\n        if not queued(self) then', "disposal_npc_duplicate_terminal_callbacks_inert"),
        ("native-perform-original-queue", "repair.lua",
         'ISTimedActionQueue.getTimedActionQueue(b.body) ~= b.queue',
         'false', "disposal_perform_refuses_replaced_queue"),
        ("player-stop-original-queue-custody", "repair.lua", 'if not ownsCurrent then',
         'if false then', "stop_player_replaced_queue_preserves_successor"),
        ("stop-current-action-custody", "repair.lua", 'q.current == self and q:indexOf(self) == 1',
         'true', "stop_player_advanced_queue_preserves_successor"),
        ("npc-stop-shared-successor-flags", "repair.lua", 'if ownsCurrent then\n            b.body:setIsFarming(false)',
         'if true then\n            b.body:setIsFarming(false)', "stop_npc_replaced_queue_ack_preserves_successor"),
        ("npc-stop-next-owner-flag-order", "repair.lua",
         'b.body:setIsFarming(false)\n            q:onCompleted(self)',
         'q:onCompleted(self)\n            b.body:setIsFarming(false)', "stop_npc_original_ack_preserves_next_flags"),
        ("player-stop-frozen-public-receiver", "repair.lua",
         'if not b.work and (self.character ~= b.body or self.window ~= b.window) then return false end',
         'do end', "stop_player_character_shadow_refuses"),
        ("force-cancel-frozen-public-receiver", "repair.lua",
         'function base:forceCancel()\n        local b = binding(self)\n        if not b or self.character ~= b.body or self.window ~= b.window then return false end',
         'function base:forceCancel()\n        local b = binding(self)\n        if not b then return false end',
         "cancel_player_character_shadow_refuses"),
        ("perform-current-action-custody", "repair.lua",
         'or b.queue.current ~= self or b.queue:indexOf(self) ~= 1',
         'or false', "perform_npc_noncurrent_same_queue_refuses"),
    ]
    controls = []
    for name, filename, old, new, detector in mutations:
        mutant = dict(sources)
        replacements = zip(old, new) if isinstance(old, list) else [(old, new)]
        for before_text, after_text in replacements:
            if mutant[filename].count(before_text) != 1:
                raise ValueError(f"source mutation anchor changed: {name}")
            mutant[filename] = mutant[filename].replace(before_text, after_text, 1)
        result = execute(out / name, mutant, classes)
        result.update(name=name, detector=detector,
                      detected=result["exitCode"] == 0 and result["checks"].get(detector) == "false")
        controls.append(result)
    after = {str(path): digest(path) for path in inputs}
    passed = (normal["exitCode"] == 0 and not normal["failed"] and not normal["missing"]
              and not normal["extra"] and all(row["detected"] for row in controls) and before == after)
    receipt = {"schema": "sao-window-repair-focused-proof/1", "status": "PASS" if passed else "FAIL",
               "sourcePins": before, "sourcePreserved": before == after, "normal": normal,
               "controls": controls, "compile": {"command": command, "exitCode": done.returncode},
               "preflight": classification,
               "boundary": "Installed Kahlua/action/queue and isolated native receivers; controlled map/body/dispatch/network; no loaded game or save.",
               "open": ["loaded-game geometry/action acceptance", "dormant work", "publication parent reanchor",
                        "nested carried bag approach/transfer", "optional API license grant unestablished; no copied source"]}
    raw = json.dumps(receipt, indent=2, sort_keys=True).encode("utf-8") + b"\n"
    (out / "receipt.json").write_bytes(raw)
    print(f"Window repair {'PASS' if passed else 'FAIL'}: {len(normal['checks'])}/{len(EXPECTED)} cases; "
          f"{sum(row['detected'] for row in controls)}/{len(controls)} executing controls")
    if not passed:
        print("normal", normal)
        print("controls", [(row['name'], row['exitCode'], row['failed']) for row in controls])
        print((out / "normal/output.log").read_text(encoding="utf-8")[-4000:])
    print(f"receipt {out / 'receipt.json'} sha256={hashlib.sha256(raw).hexdigest()}")
    if temporary:
        temporary.cleanup()
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
