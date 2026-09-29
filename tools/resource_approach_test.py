#!/usr/bin/env python3
"""Border 198 helper: native approach targets retain the original resource receipt."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent
GAME = Path(os.environ.get("PZ_DIR", r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"))
JDK = Path(os.environ.get("JDK_BIN", r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin"))
NEEDS = Path("java/src/com/sao/engine/SAONeeds.java")
SOURCES = Path("java/src/com/sao/engine/SAOWorldSources.java")
PROBE = Path("tools/luacheck/ResourceApproachProbe.java")
WATER_PROBE = Path("tools/luacheck/WaterApproachProbe.java")
WATER_LUA = Path("tools/luacheck/WaterRouteChecks.lua")
LUA_NEEDS = Path("mod/42.20/media/lua/client/SAO_Needs.lua")
CONTROLLER = Path("mod/42.20/media/lua/client/SAO_Controller.lua")
LOCOMOTION = Path("mod/42.20/media/lua/client/SAO_Locomotion.lua")


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(command, cwd, phase, case, receipt):
    start = time.perf_counter()
    completed = subprocess.run([str(part) for part in command], cwd=cwd,
        capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120)
    receipt["commands"].append(dict(phase=phase, case=case,
        exit=completed.returncode, seconds=time.perf_counter() - start,
        stdout=completed.stdout, stderr=completed.stderr))
    return completed


def change(source: str, old: str, new: str, count=1) -> str:
    if source.count(old) != count:
        raise AssertionError("resource approach mutation target drifted: " + old)
    return source.replace(old, new)


def controls(needs: str, sources: str):
    yield "occupied-source-target", NEEDS, change(needs,
        "target = SAOWorldSources.interactionSquare(shell, square);",
        "target = square;", 2), "adjacent_native_target_food"
    yield "ignore-item-removal", NEEDS, change(needs,
        "                        || source.item.getContainer() != source.container\n"
        "                        || !source.container.contains(source.item)\n", ""), "removed_item_refused"
    yield "ignore-root-holder", NEEDS, change(needs,
        "                        || SAOPrivateInventory.rootContainer(source.container)\n"
        "                            != source.permissionContainer\n", ""), "moved_nested_holder_refused"
    yield "admit-unknown-contents", NEEDS, change(needs,
        "                        || !source.permissionContainer.isExplored()) return \"UNAVAILABLE\";",
        ") return \"UNAVAILABLE\";"), "unknown_contents_not_admitted"
    yield "ignore-world-holder-removal", NEEDS, change(needs,
        "                            || !square.getObjects().contains(parent)) return \"UNAVAILABLE\";",
        ") return \"UNAVAILABLE\";"), "removed_world_holder_refused"
    yield "ignore-native-free-square", SOURCES, change(sources,
        "if (candidate == null || !candidate.isFree(false)) continue;",
        "if (candidate == null) continue;"), "no_free_target_refused"
    yield "ignore-native-interaction-barrier", SOURCES, change(sources,
        "if (candidate != source && candidate.isSomethingTo(source)) continue;", ""), "wall_between_free_target_and_source_refused"
    yield "admit-tainted-water", NEEDS, change(needs,
        "                        || !cleanWaterSource(source)) return \"UNAVAILABLE\";",
        "                        || source.getFluidAmount() <= 0) return \"UNAVAILABLE\";"), "tainted_water_refused"
    yield "ignore-water-object-removal", NEEDS, change(needs,
        "                        || !square.getObjects().contains(source)\n", ""), "removed_water_object_refused"
    yield "ignore-unloaded-source", NEEDS, change(needs,
        "            && cell.getGridSquare(x, y, z) == square;", ";"), "unloaded_source_square_refused"
    yield "vehicle-origin-instead-of-part", NEEDS, change(needs,
        "target = SAOWorldSources.vehicleInteractionSquare(vehicle, part);",
        "target = vehicle.getSquare();"), "vehicle_native_part_target"
    yield "ignore-vehicle-permission", NEEDS, change(needs,
        "                            || !vehicle.canAccessContainer(index, shell)\n", ""), "revoked_vehicle_permission_refused"
    moved = change(needs,
        "                            || (int) Math.floor(vehicle.getX()) != sourceX\n"
        "                            || (int) Math.floor(vehicle.getY()) != sourceY\n", "")
    moved = change(moved,
        "                            || !loadedSourceSquare(cell, vehicle.getSquare(),\n"
        "                                sourceX, sourceY, sourceZ)\n", "")
    yield "ignore-vehicle-movement", NEEDS, moved, "moved_vehicle_refused"
    yield "ignore-vehicle-membership", NEEDS, change(needs,
        "                            || !cell.getVehicles().contains(vehicle)\n", ""), "removed_vehicle_refused"
    yield "ignore-free-vehicle-area", SOURCES, change(sources,
        "return square != null && square.isFree(false) ? square : null;",
        "return square;"), "blocked_vehicle_area_refused"


def water_controls(needs: str):
    yield "ignore-water-attempt-feedback", change(needs,
        "&& (!avoidFailedApproaches || !waterApproachHeld(shell, object, atHours))", "&& true"), "failed_fixture_does_not_monopolize_query"
    yield "legacy-query-holds-without-clock", change(needs,
        "return findWaterSourceNear(shell, radius, 0, false);",
        "return findWaterSourceNear(shell, radius, Double.NaN, true);"), "legacy_query_retains_unfiltered_contract"
    yield "erase-failure-with-source-cache", change(needs,
        "public static void clearWaterSource(IsoPlayer shell) {\n        WATER_SOURCES.remove(shell);",
        "public static void clearWaterSource(IsoPlayer shell) {\n        WATER_FAILURES.remove(shell);\n        WATER_SOURCES.remove(shell);"), "failed_fixture_does_not_monopolize_query"
    yield "small-motion-forgets-failure", change(needs,
        "if (waterWithinReach(shell, source)) {", "if (shell.getX() > 11 || waterWithinReach(shell, source)) {"), "small_motion_does_not_reset_failed_approach"
    yield "never-expire-water-failure", change(needs,
        "return !Double.isFinite(atHours) || atHours < failure.retryAtHours;", "return true;"), "county_time_expiry_allows_reconsideration"
    yield "never-release-demonstrated-reach", change(needs,
        "if (waterWithinReach(shell, source)) {", "if (false) {"), "actual_native_reach_releases_failure"
    yield "unbound-failure-target", change(needs,
        "|| approach.x != approachX || approach.y != approachY || approach.z != approachZ", ""), "unrelated_target_cannot_penalize_source"
    yield "cancel-counted-as-water-failure", change(needs,
        "if (!accessFailure || !Double.isFinite(atHours)", "if (!Double.isFinite(atHours)"), "flee_or_cancel_is_not_an_access_failure"
    yield "unbounded-water-failures", change(needs,
        "if (failures.size() >= WATER_FAILURE_LIMIT) failures.remove(0);", ""), "failure_receipts_are_bounded"
    yield "world-keeps-water-attempts", change(needs,
        "        WATER_FAILURES.clear();", ""), "world_reset_discards_attempt_handles"
    yield "water-former-door-edge-reach", change(needs,
        "dx <= 1.6f && dy <= 1.6f && here.canReachTo(square)",
        "dx * dx + dy * dy <= 4.0f && !here.isSomethingTo(square)"), "water_open_door_matches_installed_interaction"
    yield "water-radial-instead-of-native-axis", change(needs,
        "dx <= 1.6f && dy <= 1.6f && here.canReachTo(square)",
        "dx * dx + dy * dy <= 4.0f && here.canReachTo(square)"), "water_diagonal_axis_reach_matches_vanilla"
    yield "water-ignore-closed-native-edge", change(needs,
        "&& here.canReachTo(square);", ";"), "water_closed_door_refused_by_native_reach"
    yield "water-nearest-before-usable", change(needs,
        "if (best != null && ((!reachable && bestReachable)\n"
        "                                        || (reachable == bestReachable && dist >= bestDist))) continue;",
        "if (best != null && dist >= bestDist) continue;"), "usable_water_precedes_nearer_blocked_fixture"
    yield "water-any-untainted-fluid", change(needs,
        " || !object.hasWater()", ""), "nonwater_fluid_is_not_a_thirst_source"
    yield "water-ignore-positive-last-sip", change(needs,
        "object.getFluidAmount() <= 0 || !object.hasWater()",
        "object.getFluidAmount() <= 0.1f || !object.hasWater()"), "positive_last_sip_is_selected"
    yield "water-null-primary-rejects-native-reserve", change(needs,
        "return primary == null || !primary.isPoisonous();",
        "return primary != null && !primary.isPoisonous();"), "empty_component_pipe_reserve_is_selected"
    yield "water-skip-selected-fluid-revalidation", change(needs,
        "if (!cleanWaterSource(object) || square == null || shell == null",
        "if (square == null || shell == null"), "contaminated_selected_fluid_is_revalidated"


def water_lua_checks(root, work, classes, classpath, receipt, baseline_only):
    needs = (root / LUA_NEEDS).read_text(encoding="utf-8-sig")
    controller = (root / CONTROLLER).read_text(encoding="utf-8-sig")
    locomotion = (root / LOCOMOTION).read_text(encoding="utf-8-sig")
    fixture = (root / WATER_LUA).read_text(encoding="utf-8-sig")
    native_paths = [GAME / "media/lua/client/TimedActions/ISTimedActionQueue.lua",
                    GAME / "media/lua/shared/TimedActions/ISTakeWaterAction.lua"]
    native = "\n".join(p.read_text(encoding="utf-8-sig") for p in native_paths)
    receipt["waterNativeLuaSha256"] = {str(p):sha(p) for p in native_paths}
    expose = """Ctl.__waterDecide=decideNeedsAndCompanion
Ctl.__cognitionChoice=competeForResources
Ctl.__waterMovement=updateMovement
Ctl.__waterState=setState
Ctl.__waterTick=function(t) tickCount=t end
return Ctl"""
    variants = [("water-lua-production", needs, controller, None)]
    if not baseline_only:
        variants += [
            ("cognition-ordinary-veto", needs, change(controller,
                '((selection == "water") or (selection == nil',
                '((selection == "water" and needs.thirst >= SAO.Disposition.drinkAt(id)) or (selection == nil'),
                "rival_intent_executes_before_ordinary_threshold"),
            ("cognition-admission-omitted", needs, change(controller,
                'if episodeId then SAO.Cognition.started(id, episodeId, admitted, reason); episodeId = nil end',
                'if episodeId then episodeId = nil end'),
                "rival_intent_executes_before_ordinary_threshold"),
            ("cognition-budget-bypass", needs, change(controller,
                'if cognition.isDue and not cognition.isDue(id) then return nil end', ''),
                "off_cadence_does_not_build_competition_frame"),
            ("cognition-owned-work-bypass", needs, change(controller,
                'or agent.coordinationCommitment or agent.forageInspection', 'or agent.forageInspection'),
                "accepted_work_retains_decision_ownership"),
            ("cognition-terminal-uncensored", needs, change(controller,
                'SAO.Cognition.interrupt(id, "intent ended: " .. tostring(why or "state changed"))', ''),
                "ending_intent_censors_pending_competition"),
            ("water-queue-pcall-only", change(needs,
                "return N.queueVerified(ISTakeWaterAction:new(body, nil, waterObject, nil))",
                "ISTimedActionQueue.add(ISTakeWaterAction:new(body, nil, waterObject, nil)); return true"), controller,
                "sleeping_native_queue_drop_is_refusal"),
            ("water-terminal-no-feedback", needs, change(controller,
                "                SAO.Needs.noteWaterRouteFailure(id, body, s)\n", ""),
                "actual_terminal_owner_records_before_clear"),
            ("water-selector-loses-county-clock", change(needs,
                "SAO.History.countyHours())\n    end)\n    if not ok or type(s)",
                "0)\n    end)\n    if not ok or type(s)"), controller,
                "selector_receives_county_clock"),
            ("water-feedback-unbound-body", change(needs,
                "job.body ~= body or ", ""), controller,
                "different_body_cannot_record_failure"),
            ("water-ignore-already-usable-fixture", needs, change(controller,
                "                    if atHand then\n", "                    if false then\n"),
                "usable_fixture_drinks_without_a_route"),
            ("water-direct-admission-ignored", needs, change(controller,
                'if SAO.Needs.queueDrinkFrom(id, body) then\n                            agent.taskDeadline = tick + 1800',
                'if true then\n                            agent.taskDeadline = tick + 1800'),
                "usable_fixture_drinks_without_a_route"),
            ("water-direct-reconciliation-ignored", needs, change(controller,
                '                        if SAO.SourceUse and SAO.SourceUse.beforeStateChange\n'
                '                            and SAO.SourceUse.beforeStateChange(id, body, agent.state,\n'
                '                                "DRINK", "uses water within reach") == false then\n'
                '                                cognitionStarted(false, "source reconciliation still owns the body"); return true end\n', ''),
                "pending_source_reconciliation_preserves_route_and_queue"),
            ("food-transfer-refusal-loses-reason", change(needs,
                '    return SAO.SourceUse.beginTransfer(id, body, "food",',
                '    return true and SAO.SourceUse.beginTransfer(id, body, "food",'), controller,
                "native_transfer_preserves_exact_refusal_reason"),
        ]
    for name, candidate_needs, candidate_controller, marker in variants:
        script = work / (name + ".lua")
        candidate_controller = change(candidate_controller, "\nreturn Ctl\n", "\n" + expose + "\n")
        script.write_text(fixture + "\n" + native + "\nlocal __needs=(function()\n" + candidate_needs
            + "\nend)()\nlocal __loco=(function()\n" + locomotion + "\nend)()\nlocal __controller=(function()\n" + candidate_controller
            + "\nend)()\nRESULT=CheckWaterRoutes()\n", encoding="utf-8")
        result = run([JDK / "java.exe", f"-Duser.home={work}", "-cp", classpath,
            "LuaRun", script, "--", "RESULT"], GAME, "probe", name, receipt)
        output = result.stdout + result.stderr
        if marker is None:
            if result.returncode or "PASS water route and native queue checks=" not in output:
                raise AssertionError(name + " failed:\n" + output)
            receipt["waterLuaVerdict"] = next(line for line in output.splitlines() if "PASS water route" in line)
        elif result.returncode == 0 or "WATER_CHECK:" + marker not in output:
            raise AssertionError(name + " did not fail its named verdict:\n" + output)
        else:
            receipt["controls"].append(dict(name=name, rejectedBy=marker))
        print("PASS " + name)


def execute(root: Path, receipt: dict, baseline_only=False):
    pz, zb = GAME / "projectzomboid.jar", GAME / "ZombieBuddy.jar"
    classpath = os.pathsep.join(map(str, (pz, zb)))
    needs = (root / NEEDS).read_text(encoding="utf-8-sig")
    sources = (root / SOURCES).read_text(encoding="utf-8-sig")
    receipt["installedWaterInputsSha256"] = {str(path):sha(path) for path in [
        GAME / "media/lua/shared/luautils.lua",
        *(GAME / "media/scripts/generated" / name for name in
          ("fluids.txt", "fluids_Beverages.txt", "fluids_Alcoholic.txt"))]}
    with tempfile.TemporaryDirectory(prefix="sao-resource-approach-") as temporary:
        work = Path(temporary)
        classes = work / "classes"
        classes.mkdir()
        version = (root / "VERSION").read_text(encoding="utf-8-sig").strip()
        generated = work / "SAOVersion.java"
        generated.write_text("package com.sao; public final class SAOVersion {"
            f'public static final String VALUE = "{version}"; }}\n', encoding="utf-8")
        inputs = sorted((root / "java/src").rglob("*.java")) + [generated, root / PROBE, root / WATER_PROBE,
            root / "tools/luacheck/LuaRun.java"]
        compiled = run([JDK / "javac.exe", "-encoding", "UTF-8", "-cp", classpath,
            "-d", classes, *inputs], work, "compile", "production", receipt)
        if compiled.returncode:
            raise AssertionError("production compile failed:\n" + compiled.stdout + compiled.stderr)
        live_cp = os.pathsep.join((str(classes), classpath))
        result = run([JDK / "java.exe", f"-Duser.home={work}", f"-Dwater.probe.game={GAME}", "-cp", live_cp,
            "ResourceApproachProbe"], work, "probe", "production", receipt)
        if result.returncode or "PASS resource approach checks=" not in result.stdout:
            raise AssertionError("production probe failed:\n" + result.stdout + result.stderr)
        receipt["checks"] = [line.removeprefix("CHECK ").removesuffix("=true")
            for line in result.stdout.splitlines() if line.startswith("CHECK ") and line.endswith("=true")]
        print(next(line for line in result.stdout.splitlines() if line.startswith("PASS resource")))
        water = run([JDK / "java.exe", f"-Duser.home={work}", f"-Dwater.probe.game={GAME}", "-cp", live_cp,
            "WaterApproachProbe"], GAME, "probe", "water-production", receipt)
        if water.returncode or "PASS water approach checks=" not in water.stdout:
            raise AssertionError("water approach probe failed:\n" + water.stdout + water.stderr)
        receipt["waterChecks"] = [line.removeprefix("CHECK ").removesuffix("=true")
            for line in water.stdout.splitlines() if line.startswith("CHECK ") and line.endswith("=true")]
        native_log = work / "Zomboid/SAOAgent.log"
        receipt["waterDiagnosticReceipts"] = [line for line in native_log.read_text(encoding="utf-8").splitlines()
            if "[SAO] water " in line]
        print(next(line for line in water.stdout.splitlines() if line.startswith("PASS water")))
        water_lua_checks(root, work, classes, live_cp, receipt, baseline_only)
        if baseline_only:
            return
        for name, relative, mutated, marker in controls(needs, sources):
            mutation = work / name
            mutation.mkdir()
            source = mutation / relative.name
            source.write_text(mutated, encoding="utf-8")
            output = mutation / "classes"
            output.mkdir()
            compiled = run([JDK / "javac.exe", "-encoding", "UTF-8", "-cp", live_cp,
                "-d", output, source], mutation, "compile", name, receipt)
            if compiled.returncode:
                raise AssertionError(name + " did not compile:\n" + compiled.stdout + compiled.stderr)
            result = run([JDK / "java.exe", f"-Duser.home={mutation}", f"-Dwater.probe.game={GAME}", "-cp",
                os.pathsep.join((str(output), live_cp)), "ResourceApproachProbe"],
                mutation, "probe", name, receipt)
            if result.returncode == 0 or "CHECK " + marker + "=false" not in result.stdout:
                raise AssertionError(name + " did not fail its actual verdict:\n" + result.stdout + result.stderr)
            receipt["controls"].append(dict(name=name, rejectedBy=marker))
            print("CONTROL " + name + ": " + marker)
        for name, mutated, marker in water_controls(needs):
            mutation = work / name
            mutation.mkdir()
            source = mutation / NEEDS.name
            source.write_text(mutated, encoding="utf-8")
            output = mutation / "classes"
            output.mkdir()
            compiled = run([JDK / "javac.exe", "-encoding", "UTF-8", "-cp", live_cp,
                "-d", output, source], mutation, "compile", name, receipt)
            if compiled.returncode:
                raise AssertionError(name + " did not compile:\n" + compiled.stdout + compiled.stderr)
            # Baseline runs every group. A mutant runs its complete owning
            # group, avoiding unrelated Kahlua exposure for attempt/fluids.
            phase = "reach" if name.startswith("water-") else "attempt"
            if name in {"water-any-untainted-fluid", "water-ignore-positive-last-sip",
                        "water-null-primary-rejects-native-reserve", "water-skip-selected-fluid-revalidation"}:
                phase = "fluid"
            result = run([JDK / "java.exe", f"-Duser.home={mutation}", f"-Dwater.probe.game={GAME}", "-cp",
                os.pathsep.join((str(output), live_cp)), "WaterApproachProbe", phase], GAME, "probe", name, receipt)
            if result.returncode == 0 or "CHECK " + marker + "=false" not in result.stdout:
                raise AssertionError(name + " did not fail its actual verdict:\n" + result.stdout + result.stderr)
            receipt["controls"].append(dict(name=name, rejectedBy=marker))
            print("CONTROL " + name + ": " + marker)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", nargs="?", type=Path, default=ROOT)
    parser.add_argument("--receipt", type=Path)
    parser.add_argument("--baseline-only", action="store_true")
    args = parser.parse_args(argv)
    root = args.root.resolve()
    receipt = {"helper": "resource-approach", "commands": [], "checks": [], "controls": []}
    code = 0
    try:
        receipt["sourceSha256"] = {str(path).replace("\\", "/"): sha(root / path)
            for path in (NEEDS, SOURCES, PROBE, WATER_PROBE, WATER_LUA, LUA_NEEDS, CONTROLLER, LOCOMOTION,
                Path("java/src/com/sao/bridge/SAOBridge.java"), Path("tools/resource_approach_test.py"))}
        receipt["sourceSha256"].update({str(path.relative_to(root)).replace("\\", "/"):sha(path)
            for path in sorted((root / "java/src").rglob("*.java"))})
        if not all(path.is_file() for path in (GAME / "projectzomboid.jar",
                GAME / "ZombieBuddy.jar", JDK / "javac.exe", JDK / "java.exe")):
            receipt["status"] = "SKIPPED"
            print("Resource approach SKIPPED: installed PZ or JDK unavailable")
        else:
            receipt["engineSha256"] = sha(GAME / "projectzomboid.jar")
            execute(root, receipt, args.baseline_only)
            for relative, wanted in receipt["sourceSha256"].items():
                if sha(root / relative) != wanted:
                    raise AssertionError("source changed during probe: " + relative)
            receipt["status"] = "PASS"
            print(f"Resource approach PASS: {len(receipt['checks'])} approach checks, "
                f"{len(receipt.get('waterChecks', []))} water native/Kahlua checks, "
                f"{len(receipt['controls'])} rejected production controls")
    except Exception as error:
        code = 1
        receipt["status"] = "FAIL"
        receipt["error"] = str(error)
        print("FAULT resource approach: " + str(error), file=os.sys.stderr)
    if args.receipt:
        args.receipt.parent.mkdir(parents=True, exist_ok=True)
        args.receipt.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    return code


if __name__ == "__main__":
    raise SystemExit(main())
