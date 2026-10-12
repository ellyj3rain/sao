#!/usr/bin/env python3
"""Current native workspace/material consumer, selected by affected contract."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
CHECKS = ROOT / "tools/workspace_consumer_checks"
GAME = Path(os.environ.get("PZ_DIR", r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"))
JDK = Path(os.environ.get("JDK_BIN", r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin"))
CASES = {"normal": "logging-cases.lua", "saveflow": "logging-saveflow.lua"}
CASES.update({f"parent-{name}": f"logging-parent-{name}.lua" for name in ("abandon", "cursor", "definition")})
CASES.update({f"craft-{name}": f"logging-craft-{name}.lua" for name in ("manual", "phase", "owner")})
CASES.update({f"relation-{name}": f"logging-relation-{name}.lua" for name in ("replace", "missing", "corrupt")})
HELPERS = [CHECKS / name for name in (
    "WorkspaceConsumerNativeProbe.java", "WorkspaceBuildNativeProbe.java", "SiteObserverNativeProbe.java",
    "NormalWorkspaceConsumerProbe.java", "LoggingWorkspaceConsumerProbe.java")]
JAVA = [ROOT / name for name in (
    "java/src/com/sao/engine/SAOWorldSources.java", "java/src/com/sao/bridge/SAOBridge.java",
    "java/src/com/sao/engine/SAOExtractionObservation.java", "tools/recipe_ingredient_checks/RecipeIngredientNativeProbe.java",
    "tools/construction_policy_checks/ConstructionPolicyNativeProbe.java", "tools/recipe_policy_checks/RecipePolicyNativeProbe.java",
    "tools/luacheck/MovementCrossingProbe.java")] + HELPERS
CONTROLS = {
    "request": ("parent-abandon", "SAO_ResourceProduction.lua",
        "or not SAO.ProceduralPlanning.extractionRequestCurrent or SAO.ProceduralPlanning.extractionRequestCurrent(rt.id,rt.work)~=true",
        "or false", "workspace_logging_parent_change_refuses_tree"),
    "continuation": ("craft-phase", "SAO_ResourceProduction.lua", "local function craftStartedInputs(c)\n",
        "local function craftStartedInputs(c)\n    if true then return true end\n", "workspace_logging_native_craft_change_blocks_attempt"),
    "stamp": ("normal", "SAO_ResourceProduction.lua",
        "assignment.object:getModData().SAOPhysicalResult=workspace.copy(assignment.relation)",
        "-- omitted actual native relationship write", "workspace_logging_cold_native_result_match"),
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_receipt(out, receipt):
    (out / "receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--required", action="store_true")
    parser.add_argument("--case", choices=sorted(CASES), default="normal")
    parser.add_argument("--control", choices=sorted(CONTROLS))
    parser.add_argument("--reuse-classes", type=Path)
    args = parser.parse_args()
    if args.control and args.case != CONTROLS[args.control][0]:
        parser.error("control requires --case " + CONTROLS[args.control][0])
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    classes = out / "classes"
    classes.mkdir()
    base_driver = ROOT / "tools/d3_recipe_consumer_test.py"
    prelude_source = ROOT / "tools/recipe_consumer_checks/prelude.lua"
    local_owned = [Path(__file__), base_driver, prelude_source, CHECKS / "scene-ports.lua", *JAVA,
                   *(CHECKS / name for name in CASES.values()), ROOT / "java/dist/SAOAgent.jar"]
    missing = [str(path) for path in local_owned if not path.is_file()]
    if missing:
        write_receipt(out, {"status": "FAIL", "missingOwned": missing, "executedChecks": 0})
        print("FAIL owned workspace consumer inputs absent")
        return 1
    spec = importlib.util.spec_from_file_location("workspace_recipe_inputs", base_driver)
    base = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(base)
    owned = base.OWNED + [ROOT / "mod/42.20/media/lua/shared/SAO_ConstructionPolicy.lua",
                          ROOT / "mod/42.20/media/lua/shared/SAO_ExtractionPolicy.lua"]
    native = base.NATIVE + [GAME / name for name in (
        "media/lua/shared/TimedActions/ISChopTreeAction.lua", "media/lua/server/BuildingObjects/ISBuildUtil.lua",
        "media/lua/server/BuildingObjects/ISBuildingObject.lua", "media/lua/server/BuildingObjects/ISBuildIsoEntity.lua",
        "media/lua/client/BuildingObjects/TimedActions/ISBuildAction.lua", "media/lua/shared/TimedActions/ISEquipWeaponAction.lua",
        "media/lua/server/CraftRecipeCode/CraftRecipe_BuildMenu.lua", "media/lua/server/BuildingObjects/ISShovelGroundCursor.lua",
        "media/lua/shared/BuildingObjects/TimedActions/ISShovelGround.lua")]
    declarations = sorted((GAME / "media/scripts/generated/items").glob("*.txt"))
    declarations += [GAME / name for name in (
        "media/scripts/generated/fluids.txt", "media/scripts/generated/energies.txt", "media/scripts/generated/timedactions.txt",
        "media/scripts/generated/recipes/recipes_fixing.txt", "media/scripts/generated/recipes/recipes.txt",
        "media/scripts/generated/recipes/recipes_carpentry.txt", "media/scripts/generated/recipes/recipes_metalWelding.txt",
        "media/scripts/generated/recipes/recipes_ammunition.txt",
        "media/scripts/generated/entities/furniture/entity_carpentry_table_lvl1.txt",
        "media/scripts/generated/entities/blacksmith/workstations/entity_grindstone.txt", "media/newtiledefinitions.tiles")]
    native_inputs = [*native, *declarations, GAME / "projectzomboid.jar", GAME / "ZombieBuddy.jar", GAME / "stdlib.lua",
                     JDK / "java.exe", JDK / "javac.exe", Path(sys.executable)]
    missing_owned = [str(path) for path in owned if not path.is_file()]
    missing_native = [str(path) for path in native_inputs if not path.is_file()]
    if not (GAME / "media/scripts/generated/items").is_dir():
        missing_native.append(str(GAME / "media/scripts/generated/items"))
    if missing_owned or missing_native:
        status = "FAIL" if missing_owned else "NATIVE_UNAVAILABLE"
        write_receipt(out, {"status": status, "missingOwned": missing_owned, "missingNative": missing_native,
                           "required": args.required, "executedChecks": 0, "boundary": "Unavailable native inputs are not executed proof."})
        print(status + " workspace consumer inputs absent")
        return 1 if missing_owned or args.required else 0
    inputs = list(dict.fromkeys([*local_owned, *owned, *native_inputs]))
    pins = {str(path): digest(path) for path in inputs}
    compile_inputs = [*JAVA, ROOT / "java/dist/SAOAgent.jar", GAME / "projectzomboid.jar", GAME / "ZombieBuddy.jar", JDK / "javac.exe"]
    compile_pins = {str(path): digest(path) for path in compile_inputs}
    cp = os.pathsep.join(map(str, [ROOT / "java/dist/SAOAgent.jar", GAME / "projectzomboid.jar", GAME / "ZombieBuddy.jar"]))
    wrapper_source = ROOT / "tools/recipe_ingredient_checks/RecipeIngredientNativeProbe.java"
    wrapper = out / wrapper_source.name
    content = wrapper_source.read_text(encoding="utf-8-sig")
    if content.count("System.exit(0);") != 1:
        raise ValueError("private bootstrap wrapper requires exactly one original final exit")
    wrapper.write_text(content.replace("System.exit(0);", ""), encoding="utf-8")
    compilation_sources = [wrapper if path == wrapper_source else path for path in JAVA]
    compile_command = [str(JDK / "javac.exe"), "-encoding", "UTF-8", "-cp", cp, "-d", str(classes), *map(str, compilation_sources)]
    reused = None
    if args.reuse_classes:
        previous = args.reuse_classes.resolve()
        old = json.loads((previous / "receipt.json").read_text(encoding="utf-8"))
        if old.get("compileExit") != 0 or old.get("compilePins") != compile_pins or not old.get("executables"):
            raise ValueError("retained compiled source/dependency/executable provenance changed")
        for name, expected in old["executables"].items():
            source = previous / "classes" / name
            target = classes / name
            if not source.resolve().is_relative_to((previous / "classes").resolve()) or not target.resolve().is_relative_to(classes):
                raise ValueError("retained executable leaves compilation root")
            if digest(source) != expected:
                raise ValueError("retained executable changed: " + name)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
        compile_exit = 0
        reused = {"receipt": str(previous / "receipt.json"), "sha256": digest(previous / "receipt.json")}
    else:
        compiled = subprocess.run(compile_command, capture_output=True, text=True, timeout=90)
        (out / "compile.log").write_text(compiled.stdout + compiled.stderr, encoding="utf-8")
        compile_exit = compiled.returncode
        if compile_exit:
            write_receipt(out, {"status": "FAIL", "compileExit": compile_exit, "compileCommand": compile_command,
                               "pins": pins, "compilePins": compile_pins, "executedChecks": 0})
            print(compiled.stdout + compiled.stderr)
            return 1
    prelude = out / "prelude.lua"
    content = prelude_source.read_text(encoding="utf-8-sig").replace("__prepareIntegratedNative()", "__prepareWorkspaceNative()")
    content = content.replace("setPerkLevelDebug(Perks.Maintenance,10)", "setPerkLevelDebug(Perks.Maintenance,2)")
    prelude.write_text(content + "\nfunction getDebug()return false end -- isolated nonrendering endpoint\n", encoding="utf-8")
    selected = [prelude, *native, *owned, CHECKS / "scene-ports.lua", CHECKS / CASES[args.case]]
    captured = []
    for index, source in enumerate(selected):
        target = out / f"{index:02d}-{source.name}"
        content = source.read_text(encoding="utf-8-sig")
        if args.control and source.name == CONTROLS[args.control][1]:
            _, _, before, after, _ = CONTROLS[args.control]
            if content.count(before) != 1:
                raise ValueError("control must change exactly one current source clause")
            content = content.replace(before, after)
        target.write_text('print("WORKSPACE_LOADING",' + json.dumps(source.name) + ')\n' + content, encoding="utf-8")
        captured.append(target)
    shutil.copy2(GAME / "stdlib.lua", out / "stdlib.lua")
    command = [str(JDK / "java.exe"), "--enable-native-access=ALL-UNNAMED", "-Duser.home=" + str(out),
               "-Djava.library.path=" + str(GAME), "-Dsao.game=" + str(GAME), "-cp", str(classes) + os.pathsep + cp,
               "LoggingWorkspaceConsumerProbe", str(GAME), *map(str, captured)]
    run = subprocess.run(command, cwd=GAME, capture_output=True, text=True, timeout=120)
    (out / "run.log").write_text(run.stdout + run.stderr, encoding="utf-8")
    checks = dict(re.findall(r"CHECK (workspace_[a-z0-9_]+)=(true|false)", run.stdout))
    expected = set(re.findall(r'check\("([a-z0-9_]+)"', (CHECKS / CASES[args.case]).read_text(encoding="utf-8-sig")))
    stable = pins == {str(path): digest(path) for path in inputs}
    status = "PASS" if stable and run.returncode == 0 and set(checks) == expected and all(value == "true" for value in checks.values()) else "FAIL"
    receipt = {"schema": "sao-d3.20-native-workspace-consumer/1", "status": status, "case": args.case,
               "pins": pins, "inputStable": stable, "compilePins": compile_pins, "compileExit": compile_exit,
               "compileCommand": compile_command, "reusedCompilation": reused, "privateWrapperDelta": "remove only original final System.exit(0)",
               "executables": {str(path.relative_to(classes)): digest(path) for path in classes.rglob("*.class")},
               "exitCode": run.returncode, "checks": checks, "missing": sorted(expected - set(checks)),
               "command": command, "logSha256": digest(out / "run.log"),
               "capturedFiles": {str(path.relative_to(out)): digest(path) for path in captured},
               "projections": {str(path.relative_to(out)): digest(path) for path in out.glob("*.json") if path.name != "receipt.json"},
               "boundary": "Same actual native individual/original consumers and current original source/action/personal owners. Clock/Standing/route/same-actor lookup/native metadata/animation end are isolated ports. Native dictionary paths stay inside output. No game/UI/server/peer/trained-model/full D3 claim."}
    if args.control:
        detector = CONTROLS[args.control][4]
        receipt["control"] = {"name": args.control, "detector": detector, "mutation": CONTROLS[args.control][1:4]}
        receipt["status"] = "DETECTED" if stable and checks.get(detector) == "false" else "UNDETECTED"
    write_receipt(out, receipt)
    print(receipt["status"], str(len(checks)) + "/" + str(len(expected)), "exit", run.returncode, "receipt", out / "receipt.json")
    if receipt["status"] not in ("PASS", "DETECTED"):
        print((run.stdout + run.stderr)[-6000:])
    return 0 if receipt["status"] in ("PASS", "DETECTED") else 1


if __name__ == "__main__":
    sys.exit(main())
