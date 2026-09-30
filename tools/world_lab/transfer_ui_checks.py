"""Installed transfer/eat actions retain native effects without off-slot UI."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess


def run(work, game, jdk, baseline_only=False):
    root = Path(__file__).resolve().parents[2]
    work = Path(work) / "native-transfer-ui"
    work.mkdir()
    game, jdk = Path(game), Path(jdk)
    suffix = ".exe" if os.name == "nt" else ""
    needs = (root / "mod/42.20/media/lua/client/SAO_Needs.lua").read_text(encoding="utf-8")
    handover = (root / "mod/42.20/media/lua/shared/SAO_Handover.lua").read_text(encoding="utf-8")
    native = (game / "media/lua/client/TimedActions/ISInventoryTransferAction.lua").read_text(encoding="utf-8-sig")
    native_eat = (game / "media/lua/shared/TimedActions/ISEatFoodAction.lua").read_text(encoding="utf-8-sig")
    native_pill = (game / "media/lua/shared/TimedActions/ISTakePillAction.lua").read_text(encoding="utf-8-sig")
    native_menu = (game / "media/lua/client/ISUI/ISInventoryPaneContextMenu.lua").read_text(encoding="utf-8-sig")
    fixture = (root / "tools/world_lab/TransferUiChecks.lua").read_text(encoding="utf-8")
    jar = game / "projectzomboid.jar"
    subprocess.run([str(jdk / ("javac" + suffix)), "-cp", str(jar), "-d", str(work),
                    str(root / "tools/luacheck/LuaRun.java")], check=True, capture_output=True, timeout=60)
    def changed(before, after):
        assert needs.count(before) == 1, "eat control seam differs: " + before
        return needs.replace(before, after, 1)

    variants = [("production", needs, None),
                ("npc-loot-ui", needs.replace("self.selectedContainer = nil", "-- native player UI retained", 1),
                 "selectButtonForContainer"),
                ("missing-native-facing", needs.replace("self.saoFacingContainer = self.selectedContainer",
                                                        "self.saoFacingContainer = nil", 1),
                 "NPC transfer lost native animation or source-facing identity"),
                ("collection-source-tile", needs.replace(
                    'local approachX, approachY, approachZ = N.approach(body, "food", x, y, z)',
                    'local approachX, approachY, approachZ = x, y, z', 1),
                 "commitment reappraisal lost source or approach identity"),
                ("collection-unadmitted", needs.replace(
                    'and SAO.Standing.mayAttemptBelieved(id, x, y, context.admission)',
                    'and true', 1), "unadmitted source was approached"),
                ("collection-retry-unguarded", needs.replace('if context.commitmentId then', 'if false then', 1),
                 "accepted route lost private evidence"),
                ("eat-player-ui", changed("if not checked or shell ~= true then", "if true then"),
                 "inventoryPane"),
                ("eat-leaked-helper", changed("if previousContainers then menu.getContainers = previousContainers end",
                                             "-- restoration removed"), "EAT_CHECK:helper restored after success"),
                ("eat-absent-ignition", changed("and not action:getRequiredItem() then return nil end",
                                               "and false then return nil end"), "EAT_CHECK:missing ignition refuses smoke"),
                ("eat-blocked-heat", changed("square == current or current:canReachTo(square)", "true"),
                 "EAT_CHECK:blocked world heat refused"),
                ("eat-player-isolation", changed("if not checked or shell ~= true then", "if false then"),
                 "EAT_CHECK:ordinary player keeps native UI lookup"),
                ("eat-queue-refused", changed(
                    'local queued = N.queueVerified(ISEatFoodAction:new(body, item, 1))\n    if queued then log(id .. " lights one up") end',
                    'local action = ISEatFoodAction:new(body, item, 1)\n    local queued = action and pcall(function() ISTimedActionQueue.add(action) end)\n    if queued then log(id .. " lights one up") end'),
                 "EAT_CHECK:queue rejection remains refusal"),
                ("eat-refusal-bypassed", changed(
                    "local action = ISEatFoodAction:new(body, item, 1)\n    if not action then return false end\n    local queued",
                    "local action = ISEatFoodAction:new(body, item, 1)\n    local queued"),
                 "EAT_CHECK:construction refusal precedes direct eating fallback")]
    if baseline_only:
        variants = variants[:1]
    verdicts = []
    for label, source, expected in variants:
        script = work / (label + ".lua")
        script.write_text(fixture + "\n" + native + "\n" + native_menu + "\n" + native_eat + "\n" + native_pill
                          + "\nlocal needs=(function()\n" + source
                          + "\nend)()\nlocal function checked(label, fn) local ok, value = pcall(fn); "
                            "assert(ok, label .. ': ' .. tostring(value)); return value end\n"
                            "RESULT=checked('transfer',CheckTransferUi) .. '; ' .. checked('collection',CheckCollectApproach) "
                            ".. '; ' .. checked('eat',CheckEatUi)\n", encoding="utf-8")
        result = subprocess.run([str(jdk / ("java" + suffix)), "-cp", str(jar) + os.pathsep + str(work),
                                 "LuaRun", str(script), "--", "RESULT"], cwd=game,
                                capture_output=True, text=True, timeout=60)
        output = result.stdout + result.stderr
        (work / (label + ".log")).write_text(output, encoding="utf-8")
        if expected is None:
            assert result.returncode == 0 and "PASS installed transfer action" in output and "PASS accepted work" in output \
                and "PASS installed eat action" in output, output
        elif label.startswith("collection-"):
            assert source != needs and result.returncode == 0 and "FAIL " + expected in output, label + ": " + output
        else:
            assert source != needs and result.returncode != 0 and expected in output, label + ": " + output
        verdicts.append({"label": label, "exit": result.returncode, "expected": expected,
                         "logSha256": hashlib.sha256(output.encode("utf-8")).hexdigest()})
        print("PASS installed action boundary: " + label, flush=True)
    print("PASS installed NPC transfer, collection and eat construction; "
          + str(len(variants) - 1) + " boundary defects rejected")
    handover_verdicts = handover_ui(work, game, jdk, handover, fixture, native, baseline_only)
    receivers = native_receivers(root, work, game, jdk, needs, fixture, native, native_menu, native_eat, native_pill,
                                baseline_only)
    paths = [root / "mod/42.20/media/lua/client/SAO_Needs.lua", Path(__file__),
             root / "tools/world_lab/TransferUiChecks.lua", root / "tools/world_lab/EatActionProbe.java",
             root / "mod/42.20/media/lua/shared/SAO_Handover.lua",
             root / "tools/globals_census_test.py"]
    native_paths = [game / "projectzomboid.jar", game / "media/lua/shared/TimedActions/ISEatFoodAction.lua",
                   game / "media/lua/shared/TimedActions/ISTakePillAction.lua",
                   game / "media/lua/client/ISUI/ISInventoryPaneContextMenu.lua",
                   game / "media/scripts/generated/items/drainable.txt",
                   game / "media/scripts/generated/items/food.txt"]
    receipt = {"schema": "sao-installed-consume-checks/1", "baselineOnly": baseline_only,
        "sourceHashes": {path.relative_to(root).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest() for path in paths},
        "installedHashes": {path.relative_to(game).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest() for path in native_paths},
        "luaVariants": verdicts, "handoverUiVariants": handover_verdicts, "nativeReceivers": receivers,
        "limits": "Headless installed Kahlua/native items, inventory, shell and effects; controlled queue/animation receiver, "
                  "controlled geometry and explicitly controlled Pharmacology classifier/lifecycle; no rendered gameplay claim."}
    (work / "consume-receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")


def handover_ui(work, game, jdk, source, fixture, native, baseline_only):
    suffix = ".exe" if os.name == "nt" else ""
    def changed(before, after):
        assert source.count(before) == 1, "handover UI mutation seam differs: " + before
        return source.replace(before, after, 1)
    variants = [("production", source, None),
        ("old-npc-loot-page", changed("self.selectedContainer = nil", "-- player UI retained"),
         "setForceSelectedContainer"),
        ("old-inherited-update", changed("function transferClass:update()", "function transferClass:unusedUpdate()"),
         "HANDOVER_UI_CHECK:NPC update keeps native recipient facing"),
        ("missing-facing", changed("self.saoFacingContainer = self.selectedContainer", "self.saoFacingContainer = nil"),
         "HANDOVER_UI_CHECK:NPC update keeps native recipient facing"),
        ("player-panel-erased", changed("if self.saoOffSlot then", "if true then"),
         "HANDOVER_UI_CHECK:ordinary player selected container remains native")]
    if baseline_only:
        variants = variants[:1]
    verdicts = []
    for label, variant, expected in variants:
        script = work / ("handover-" + label + ".lua")
        script.write_text(fixture + "\n" + native + "\n" + variant
            + "\nRESULT=CheckHandoverUi()\n", encoding="utf-8")
        result = subprocess.run([str(jdk / ("java" + suffix)), "-cp", str(game / "projectzomboid.jar")
            + os.pathsep + str(work), "LuaRun", str(script), "--", "RESULT"], cwd=game,
            capture_output=True, text=True, timeout=60)
        output = result.stdout + result.stderr
        (work / ("handover-" + label + ".log")).write_text(output, encoding="utf-8")
        if expected is None:
            assert result.returncode == 0 and "PASS installed handover UI boundary:" in output, output
        else:
            assert variant != source and result.returncode != 0 and expected in output, label + ": " + output
        verdicts.append({"label": label, "expected": expected, "exit": result.returncode,
            "logSha256": hashlib.sha256(output.encode("utf-8")).hexdigest()})
        print("PASS installed handover boundary: " + label, flush=True)
    return verdicts


def native_receivers(root, work, game, jdk, needs, fixture, native, native_menu, native_eat, native_pill,
                     baseline_only):
    """Compile only into the caller's private test directory, never java/out."""
    classes = work / "classes"
    classes.mkdir()
    generated = work / "SAOVersion.java"
    generated.write_text("package com.sao; public final class SAOVersion { public static final String VALUE = "
                         + json.dumps((root / "VERSION").read_text(encoding="utf-8-sig").strip()) + "; }\n",
                         encoding="utf-8")
    suffix = ".exe" if os.name == "nt" else ""
    classpath = os.pathsep.join(map(str, (game / "projectzomboid.jar", game / "ZombieBuddy.jar")))
    result = subprocess.run([str(jdk / ("javac" + suffix)), "-encoding", "UTF-8", "-cp", classpath,
        "-d", str(classes), *map(str, sorted((root / "java/src").rglob("*.java"))), str(generated),
        str(root / "tools/luacheck/MovementCrossingProbe.java"), str(root / "tools/world_lab/EatActionProbe.java")],
        capture_output=True, text=True, timeout=120)
    (work / "receivers-compile.log").write_text(result.stdout + result.stderr, encoding="utf-8")
    assert result.returncode == 0, result.stdout + result.stderr
    shutil.copy2(game / "stdlib.lua", work / "stdlib.lua")
    def changed(before, after):
        assert needs.count(before) == 1, "native consume control seam differs: " + before
        return needs.replace(before, after, 1)

    variants = [("production", needs, None),
        ("pack-through-food", changed('if foodOnly and not instanceof(item, "Food") then', 'if false then'),
         "NATIVE_EAT_CHECK:native direct pack constructor admitted"),
        ("pill-player-ui", changed('wrapNpcConsumeConstructor(ISTakePillAction, false)', '-- pill constructor unwrapped'),
         "inventoryPane"),
        ("food-rejected", changed('if foodOnly and not instanceof(item, "Food") then', 'if foodOnly then'),
         "attempted index: Type of non-table: null"),
        ("pill-pharmacology-omitted", changed('wrapPharmacology(ISTakePillAction)', '-- pill pharmacology unwrapped'),
         "NATIVE_EAT_CHECK:classified ISTakePillAction captured before native use"),
        ("food-pharmacology-omitted", changed('wrapPharmacology(ISEatFoodAction)', '-- food pharmacology unwrapped'),
         "NATIVE_EAT_CHECK:classified ISEatFoodAction captured before native use"),
        ("native-completion-bypassed", changed(
            'and not action:getRequiredItem() then return nil end\n        return action',
            'and not action:getRequiredItem() then return nil end\n'
            '        if action then action.complete = function() return true end end\n        return action'),
         "NATIVE_EAT_CHECK:native nicotine OnEat hunger effect")]
    if baseline_only:
        variants = variants[:1]
    verdicts, checks = [], []
    for label, source, expected in variants:
        script = work / ("receivers-" + label + ".lua")
        script.write_text(fixture + "\n" + native + "\n" + native_menu + "\n" + native_eat + "\n" + native_pill
            + "\nlocal needs=(function()\n" + source + "\nend)()\nNATIVE_EAT_RESULT=CheckNativeEat()\n", encoding="utf-8")
        result = subprocess.run([str(jdk / ("java" + suffix)), "-Duser.home=" + str(work), "-Djava.awt.headless=true",
            "-Dstdout.encoding=UTF-8", "--enable-native-access=ALL-UNNAMED", "-cp", str(classes) + os.pathsep + classpath,
            "EatActionProbe", str(game), str(script)], cwd=work, capture_output=True, text=True, timeout=120)
        output = result.stdout + result.stderr
        (work / ("receivers-" + label + ".log")).write_text(output, encoding="utf-8")
        if expected is None:
            assert result.returncode == 0 and "PASS real installed consume receivers" in output, output
            checks = [line.removeprefix("NATIVE_EAT_CHECK ").removesuffix("=true")
                      for line in output.splitlines() if line.startswith("NATIVE_EAT_CHECK ") and line.endswith("=true")]
            print(next(line for line in output.splitlines() if "PASS real installed consume receivers" in line), flush=True)
        else:
            assert result.returncode != 0 and expected in output, label + ": " + output
        verdicts.append({"label": label, "exit": result.returncode, "expected": expected,
                         "logSha256": hashlib.sha256(output.encode("utf-8")).hexdigest()})
        print("PASS real consume receiver control: " + label, flush=True)
    return {"checks": checks, "variants": verdicts}
