#!/usr/bin/env python3
"""D3.4: actual private water planning/Controller, installed plumbing/refill actions.

Native receivers, source acquisition and surrounding world are bounded controls.
The native plumbing instrument separately qualifies loaded native supplier binding.
Classes and candidate chunks are isolated; shared java/out is never written.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
CASES = ROOT / "tools/luacheck/d3_plumbing_controller_cases.lua"
COLLECTOR_CASES = ROOT / "tools/luacheck/d3_rain_collector_controller_cases.lua"
NAMES = ("models", "cognition", "labor", "planner", "locomotion", "production", "controller", "needs")
NATIVE_NAMES = ("ISBaseObject", "TimedActions/ISBaseTimedAction", "TimedActions/ISTakeWaterAction",
                "TimedActions/ISEquipWeaponAction", "TimedActions/ISInventoryTransferAction",
                "TimedActions/ISPlumbItem", "TimedActions/ISDrinkFluidAction")
CONTROLS = [
    ("urgent-production-intake", "controller", "    hydrationProductionContext(id, agent, body, context)\n    local purpose, step = planning.planResource(id, context)",
     "    local purpose, step = planning.planResource(id, context)", "urgent_thirst_acquires_exact_private_wrench"),
    ("connection-is-not-water", "planner", 'purpose.status, purpose.awaitingStock, purpose.awaitingReassessment = "maintained", nil, true\n        purpose.plumbing.connectedWorkId',
     'purpose.status, purpose.awaitingStock, purpose.awaitingReassessment = "completed", nil, true\n        purpose.plumbing.connectedWorkId', "native_connection_keeps_same_water_objective_open"),
    ("exact-acquisition-result", "planner", "if purpose.plumbing and (authoritative.actorId ~= receipt.actorId", "if false and (authoritative.actorId ~= receipt.actorId", "wrong_wrench_source_revision_cannot_advance"),
    ("retained-water-category", "controller", "local category = retained and (retainedStep and retainedStep.acquiredItemId or retained.admission or continuation)",
     "local category = retained and (retainedStep and retainedStep.acquiredItemId or retained.admission)", "acquired_wrench_returns_to_retained_fixture_under_water_purpose"),
    ("blocked-water-arbitration", "controller", "local continuation = retained == waterPurpose and waterContinuation",
     "local continuation = retained and retained.plumbing ~= nil", "blocked_connected_water_does_not_suppress_higher_food_pressure"),
]
COLLECTOR_CONTROLS = [
    ("collector-private-observed-site", [("labor", "private = private and observed", "private = private"),
                                        ("production", 'if option.kind=="build-rain-collector" and (not collector or not SAO.Body.get(id)',
                                         'if false and (not collector or not SAO.Body.get(id)')], "", "",
     "unobserved_roof_site_is_not_a_private_construction_alternative"),
    ("collector-distinct-input-count", "planner", "counts[input.inputIndex] = counts[input.inputIndex] + 1",
     'counts[input.inputIndex] = counts[input.inputIndex] + (required.category == "garbage-bag" and required.count or 1)', "one_exact_bag_cannot_cover_four_native_recipe_inputs"),
    ("collector-pending-admission", "planner", "if current and purpose.admission and purpose.admission.stepId == current.id then",
     "if false then", "collector_pending_material_admission_is_not_recompiled"),
    ("collector-exact-source-result", [("planner", "if purpose.collector and (authoritative.actorId ~= receipt.actorId",
                                      "if false and (authoritative.actorId ~= receipt.actorId"),
                                     ("planner", "if purpose.plumbing and (authoritative.actorId ~= receipt.actorId",
                                      "if false and (authoritative.actorId ~= receipt.actorId")], "", "",
     "wrong_exact_material_source_revision_cannot_advance_collector"),
    ("collector-canonical-result", "planner", "local canonical = owner and owner.outcome and owner.outcome(id, receipt.id)\n    local plumbing",
     "local canonical = receipt\n    local plumbing", "caller_forged_placement_cannot_replace_native_canonical_result"),
    ("collector-is-not-water", "planner", 'if consumed and completed and collector then\n        purpose.status, purpose.awaitingStock, purpose.awaitingReassessment = "maintained", nil, true',
     'if consumed and completed and collector then\n        purpose.status, purpose.awaitingStock, purpose.awaitingReassessment = "completed", nil, true',
     "native_collector_creation_advances_construction_without_fulfilling_water"),
    ("collector-empty-pressure-arbitration", "controller", "local continuation = retained == waterPurpose and waterContinuation",
     "local continuation = retained and retained.collector ~= nil", "empty_constructed_supply_allows_higher_food_pressure"),
]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out", type=Path, default=ROOT / "_scratch/d3.4-controller-01")
    ap.add_argument("--controls", choices=("selected", "all", "none"), default="selected")
    ap.add_argument("--syntax-only", action="store_true")
    ap.add_argument("--collector-only", action="store_true", help="Run the rain-collector continuation of the same hydration purpose.")
    ap.add_argument("--required", action="store_true", help="Fail when installed native proof inputs are unavailable.")
    args = ap.parse_args()
    # Classify missing import/bootstrap inputs before loading the real module
    # graph. A missing owned helper must never become an optional native skip.
    imports = [ROOT / "tools" / (name + ".py") for name in
               ("native_proof_preflight", "resource_execution_test", "resource_production_test",
                "source_use_test", "study_test", "lua_read")]
    if args.collector_only:
        imports.append(ROOT / "tools/d3_rain_collector_test.py")
    missing_imports = [str(path) for path in imports if not path.is_file()]
    if missing_imports:
        print("FAILED D3 plumbing Controller: owned proof inputs absent: " + ", ".join(missing_imports))
        return 1
    sys.dont_write_bytecode = True
    import resource_execution_test as execution
    import resource_production_test as refill
    from lua_read import function_body
    from native_proof_preflight import presence
    GAME, JDK = execution.GAME, execution.JDK
    files = {name: refill.FILES[name] for name in NAMES}
    selected_cases = COLLECTOR_CASES if args.collector_only else CASES
    collector_fixture = ROOT / "tools/resource_production_checks/rain_collector_cases.lua"
    collector_probe = ROOT / "tools/resource_production_checks/RainCollectorNativeProbe.java"
    if args.collector_only:
        import d3_rain_collector_test as collector_native
        files.update({name: refill.FILES[name] for name in ("sources", "perception", "experience")})
    native = []
    native_names = NATIVE_NAMES + (("TimedActions/ISTimedActionQueue", "BuildingObjects/ISBuildingObject",
                                  "BuildingObjects/ISBuildIsoEntity", "BuildingObjects/TimedActions/ISBuildAction")
                                 if args.collector_only else ())
    for name in native_names:
        path = GAME / "media/lua/shared" / (name + ".lua")
        if not path.is_file():
            path = GAME / "media/lua/client" / (name + ".lua")
        if args.collector_only and not path.is_file():
            path = GAME / "media/lua/server" / (name + ".lua")
        native.append(path)
    owned = [Path(__file__).resolve(), selected_cases, *imports, *files.values(),
             ROOT / "tools/luacheck/LuaRun.java", ROOT / "tools/luacheck/LuaSyntax.java"]
    if args.collector_only:
        owned += [collector_fixture, collector_probe, ROOT / "tools/luacheck/window_repair_cases.lua",
                  ROOT / "tools/luacheck/d3_native_boarding_cases.lua", ROOT / "tools/resource_production_checks/plumbing_cases.lua"]
    installed = [GAME / "projectzomboid.jar", GAME / "stdlib.lua", JDK / "java.exe", JDK / "javac.exe", *native]
    if args.collector_only:
        installed += [GAME / "media/scripts/generated" / name for name in
                      ("items/weapon.txt", "items/container.txt", "items/normal.txt", "timedactions.txt",
                       "entities/outdoors/entity_raincollector.txt", "entities/outdoors/entity_raincollector_tarp.txt")]
    unavailable = presence(owned, installed, args.required, "D3 plumbing Controller")
    if unavailable is not None:
        return unavailable
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    texts = {name: path.read_text(encoding="utf-8-sig") for name, path in files.items()}
    cases = selected_cases.read_text(encoding="utf-8")
    collector_sources = collector_native.sources() if args.collector_only else None
    expected = set(re.findall(r"check\('([a-z0-9_]+)'", cases))
    pins = {str(path.relative_to(ROOT)): digest(path) for path in owned}
    runs = []
    controls = []
    with tempfile.TemporaryDirectory(prefix="sao-d34-controller-") as directory:
        work = Path(directory)
        shutil.copy2(GAME / "stdlib.lua", work / "stdlib.lua")
        driver = (ROOT / "tools/luacheck/LuaRun.java").read_text(encoding="utf-8")
        driver = driver.replace("LuaClosure c = LuaCompiler.loadis(r, path, env);",
                                'System.err.println("LOADING " + path); LuaClosure c = LuaCompiler.loadis(r, path, env);')
        driver = driver.replace("String m = t.getMessage();", 't.printStackTrace(); Object partial = env.rawget("__plumbingResults"); '
                                'if (partial != null) System.out.println("PARTIAL " + render(partial)); String m = t.getMessage();')
        (work / "LuaRun.java").write_text(driver, encoding="utf-8")
        probe = collector_probe if args.collector_only else work / "LuaRun.java"
        build = subprocess.run([str(JDK / "javac.exe"), "-cp", str(GAME / "projectzomboid.jar"), "-d", str(work),
                                str(probe), str(ROOT / "tools/luacheck/LuaSyntax.java")],
                               capture_output=True, text=True, timeout=60)
        (out / "compile.log").write_text(build.stdout + build.stderr, encoding="utf-8")
        if build.returncode:
            raise RuntimeError("private runner compile: " + build.stderr[-2500:])
        cp = str(work) + os.pathsep + str(GAME / "projectzomboid.jar")
        syntax = subprocess.run([str(JDK / "java.exe"), "-Djava.awt.headless=true", "-cp", cp, "LuaSyntax",
                                 *map(str, (files["planner"], files["controller"], files["labor"], selected_cases))],
                                capture_output=True, text=True, timeout=60)
        (out / "syntax.log").write_text(syntax.stdout + syntax.stderr, encoding="utf-8")
        syntax_pass = syntax.returncode == 0 and len(re.findall(r"^OK\t", syntax.stdout, re.M)) == 8

        def run(label, mutation=None, target=None):
            code = dict(texts)
            # A selected control executes the actual causal prefix through its
            # named assertion. Later stages depend on the deliberately removed
            # behavior and do not provide evidence for that control.
            run_cases = cases
            if target:
                boundary = "-- control-boundary: " + target
                if cases.count(boundary) != 1:
                    raise RuntimeError(label + ": control boundary is not unique")
                run_cases = cases.split(boundary, 1)[0] + ("\nend\n" if args.collector_only
                                                         else "\n__plumbingResults=table.concat(checks,'\\n')\n")
            run_expected = set(re.findall(r"check\('([a-z0-9_]+)'", run_cases))
            if mutation:
                selected_mutations = mutation if isinstance(mutation, list) else [mutation]
                for name, before, after in selected_mutations:
                    if code[name].count(before) != 1:
                        raise RuntimeError(label + ": mutation anchor is not unique")
                    code[name] = code[name].replace(before, after, 1)
            paths = []

            def add(name, value):
                path = work / (name + ".lua")
                path.write_text(value, encoding="utf-8")
                paths.append(path)

            if args.collector_only:
                # Reuse the native owner's validated load order and receiver
                # setup. Only its test invocation is replaced by Controller cases.
                for filename, chunk in collector_sources.items():
                    name = filename[:-4]
                    if name == "base":
                        chunk = "__collectorEmit=print\n" + chunk
                    elif name == "rain-fixture":
                        chunk = chunk.split("function __runRainCollectorCases()", 1)[0]
                    elif name in code:
                        chunk = code[name]
                    add(name, chunk)
            else:
                add("prelude", refill.PRELUDE + "\nISInventoryPage={dirtyUI=function() end}\nfixture()\n")
            portable = function_body(code["needs"], "N.portableWaterItem")
            add("portable-water", "local N={}\nfunction N.portableWaterItem(" + portable + "end\n__portableWaterItem=N.portableWaterItem\n")
            if args.collector_only:
                paths.append(GAME / "media/lua/shared/TimedActions/ISDrinkFluidAction.lua")
                add("locomotion", code["locomotion"])
            else:
                paths.extend(native)
                for name in ("models", "cognition", "labor", "planner", "locomotion", "production"):
                    add(name, code[name])
            add("controller", execution.controller_phases(code["controller"]))
            phase = code["controller"].split("-- Native production owns its exact resource-transformation action until it retires.", 1)[1].split(
                "-- Food preparation owns its routes and exact transfers as one operation.", 1)[0]
            add("owner-tick", "local selectedThreat=function() return nil end\nfunction resourceOwnerTick(id,agent,body,tickCount)\n"
                + execution.COMMON + phase + "\nend\n")
            drink = code["needs"].split("function N.drinkCarried", 1)[1].split("-- Ask the world for clean water", 1)[0]
            thirst = code["controller"].split("    -- Thirst: the sharper clock", 1)[1].split("    -- Hunger:", 1)[0]
            add("drink-controller", execution.COMMON + "\nlocal N=SAO.Needs\nlocal log=function() end\nfunction N.drinkCarried" + drink
                + "\nfunction Ctl.testThirst(id,agent,body,tick,needs)\nlocal selection=nil\nlocal cognitionStarted=function(v) return v end\n"
                + "local beginContainerInspection=function() return false end\nlocal beginObservedUse=function() return false end\n"
                + "local knownSource=function() return nil end\nlocal log=function() end\n-- Thirst: the sharper clock" + thirst + "\nreturn false\nend\n")
            add("cases", run_cases)
            if args.collector_only:
                add("run", "local ok,reason=pcall(__runCollectorControllerCases)\n__collectorEmit(__plumbingResults or '')\nif not ok then error(reason) end\n")
            command = ([str(JDK / "java.exe"), "--enable-native-access=ALL-UNNAMED", "-Djava.awt.headless=true", "-Duser.home=" + str(work), "-cp", cp,
                        "RainCollectorNativeProbe", str(GAME), *map(str, paths)] if args.collector_only else
                       [str(JDK / "java.exe"), "-Djava.awt.headless=true", "-cp", cp, "LuaRun", *map(str, paths), "--", "__plumbingResults"])
            done = subprocess.run(command, cwd=work,
                                  capture_output=True, text=True, timeout=60)
            log = out / (label + ".log")
            log.write_text(done.stdout + done.stderr, encoding="utf-8")
            checks = {name: value for name, value in re.findall(r"([a-z0-9_]+)=(true|false)", done.stdout)
                      if name in run_expected}
            runtime_error = "ERROR " in done.stdout
            row = {"name": label, "exitCode": done.returncode, "runtimeError": runtime_error,
                   "checks": checks, "missing": sorted(run_expected - set(checks)),
                   "failed": sorted(key for key, value in checks.items() if value != "true"),
                   "outputLog": str(log), "logSha256": digest(log)}
            runs.append(row)
            if target:
                controls.append({"name": label, "expectedFailure": target,
                                 "killed": done.returncode == 0 and not runtime_error and checks.get(target) == "false"})
            return row

        normal = None if args.syntax_only else run("baseline")
        if normal and not normal["exitCode"] and not normal["runtimeError"] and not normal["missing"] and not normal["failed"] and args.controls != "none":
            for name, file, before, after, target in (COLLECTOR_CONTROLS if args.collector_only else CONTROLS):
                run(name, file if isinstance(file, list) else (file, before, after), target)
    preserved = all(digest(ROOT / path) == pin for path, pin in pins.items())
    passed = syntax_pass and preserved and (args.syntax_only or normal is not None and not normal["exitCode"]
        and not normal["runtimeError"] and not normal["missing"] and not normal["failed"]
        and all(row["killed"] for row in controls))
    receipt = {"status": "PASS" if passed else "FAIL", "mode": "syntax" if args.syntax_only else "native-collector-controller" if args.collector_only else "native-plumbing-controller",
               "sourcePins": pins, "sourcePreserved": preserved, "syntax": {"exitCode": syntax.returncode, "passed": syntax_pass, "requiredVerdicts": 8},
               "normal": normal, "controls": controls, "runs": runs,
               "actual": ["production P/Labor private demand, interpretation and exact canonical admission/result consumption",
                          "production Controller urgent/proactive resource context, dispatch, source continuation, RESOURCE retirement and thirst drink dispatch",
                          "installed ISPlumbItem/ISTakeWaterAction/ISDrinkFluidAction",
                          "production ResourceProduction native plumbing/refill option, custody, queue, return and canonical effect owner"],
               "controlled": ["surrounding world/body/queue/native receiver methods", "personally observed source projection and exact SourceUse transfer boundary",
                              "native supplier fixture binding and DrinkFluid bodily receiver", "saved scalar copy; engine snapshot/save coverage belongs existing native instruments"],
               "unverified": ["loaded game acceptance", "physical supplier Java binding and SourceUse native transfer in this instrument"]}
    if args.collector_only:
        receipt["reusableFixturePrefixSha256"] = hashlib.sha256(collector_sources["rain-fixture.lua"].split(
            "function __runRainCollectorCases()", 1)[0].encode("utf-8")).hexdigest()
        receipt["actual"] += ["installed four entity definitions and registered native recipe requirements",
                              "native BuildLogic/CraftRecipeData manual input payment and kept hammer",
                              "installed ISBuildIsoEntity/ISBuildAction and native GameEntityFactory empty collector components",
                              "production Perception site observation/read and native Kahlua scalar save/load roundtrip"]
        receipt["controlled"] = ["unattached actor/map/queue/dispatch/sound/UI and wrappers around native Java recipe/item interfaces",
                                 "exact personally known SourceUse acquisition/transport boundary",
                                 "later rain quantity and supplier binding; native weather/geometry belongs the separate material proof",
                                 "native DrinkFluid bodily receiver"]
    (out / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(f"D3 {'rain collector' if args.collector_only else 'plumbing'} Controller {'PASS' if passed else 'FAIL'}: {len(normal['checks']) if normal else 0}/{len(expected) if normal else 0} cases, "
          f"{sum(row['killed'] for row in controls)}/{len(controls)} controls")
    print(f"Receipt: {out / 'receipt.json'}")
    if normal and (normal["failed"] or normal["missing"] or normal["runtimeError"]):
        print("Failed=" + repr(normal["failed"]) + " missing=" + repr(normal["missing"]))
        print(Path(normal["outputLog"]).read_text(encoding="utf-8")[-2200:])
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
