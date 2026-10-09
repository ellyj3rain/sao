#!/usr/bin/env python3
"""Exact Week One options, D2 reseal composition, native registry and UI."""
from pathlib import Path
import argparse
import json
import os
import shutil
import subprocess
import tempfile

import d2_source_registration as reg
import weekone_sandbox_controls as weekone

ROOT = weekone.ROOT
GAME = Path(os.environ.get("PZ_DIR", r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"))
JDK = Path(os.environ.get("JDK_BIN", r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin"))
JAVA = ROOT / "tools/weekone_sandbox_controls/WeekOneSandboxProbe.java"
UI_CASES = ROOT / "tools/weekone_sandbox_controls/ui_cases.lua"
KAHUA_JAVA = ROOT / "tools/d2_leisure_music/MusicProbe.java"
D2_CATALOG = ROOT / "mod/42.20/media/lua/shared/SAO_SourceSandboxPages.lua"
OWNER_UI = ROOT / "mod/42.20/media/lua/client/SAO_Sandbox.lua"
NATIVE_TICKBOX = GAME / "media/lua/client/ISUI/ISTickBox.lua"
D2_REPORT = ROOT / "_scratch/d2-leisure-01/source-package-03/import.json"


def check(name, good, checks):
    if not good:
        raise AssertionError(name)
    checks.append(name)


def expect_refusal(name, fn, controls):
    try:
        fn()
    except (ValueError, AssertionError):
        controls.append(name)
        return
    raise AssertionError("inverse did not refuse: " + name)


def strip_weekone(text):
    rows = [row for row in reg.parse(text)
            if row["kind"] == "block" and row.get("id") in weekone.layout()]
    if len(rows) != 24:
        raise AssertionError("canonical Week One block count")
    for row in rows:
        if text.count(row["raw"]) != 1:
            raise AssertionError("ambiguous Week One block " + row["id"])
        text = text.replace(row["raw"], "", 1)
    return text


def run(command, cwd, out, name, receipt):
    result = subprocess.run(list(map(str, command)), cwd=cwd, capture_output=True,
                            timeout=120)
    log = out / (name + ".log")
    log.write_bytes(result.stdout + result.stderr)
    receipt["runs"].append({"name": name, "exitCode": result.returncode,
                             "sha256": weekone.sha(log.read_bytes())})
    return result.returncode, log.read_text(encoding="utf-8", errors="replace")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    jars = [GAME / "projectzomboid.jar", *sorted((GAME / "jars").glob("*.jar"))]
    inputs = [Path(__file__), Path(reg.__file__), Path(weekone.__file__),
              weekone.SOURCE, weekone.INSTALLED, weekone.OPTIONS, weekone.PAGES,
              weekone.LOCALE, JAVA, UI_CASES, KAHUA_JAVA, D2_CATALOG, OWNER_UI,
              NATIVE_TICKBOX, D2_REPORT, GAME / "stdlib.lua", *jars]
    receipt = {
        "schema": "sao.weekone-sandbox-native-proof/1", "status": "INCOMPLETE",
        "boundary": "Installed ScriptParser/CustomSandboxOptions, SandboxOptions registry and Kahlua screen wrappers; no rendered game menu claim.",
        "inputsBefore": {str(p): weekone.sha(p.read_bytes()) for p in inputs},
        "checks": [], "inverseControls": [], "runs": [],
    }

    def save():
        (out / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n",
                                          encoding="utf-8")

    try:
        checks = receipt["checks"]
        controls = receipt["inverseControls"]
        source = weekone.source_text()
        current = weekone.OPTIONS.read_text(encoding="utf-8")
        locale = weekone.LOCALE.read_text(encoding="utf-8")
        check("selected_source_sha", weekone.sha(source.encode("utf-8"))
              == weekone.SOURCE_SHA256, checks)
        check("exact_24_source_declarations", len(weekone.source_rows(reg.parse)) == 24,
              checks)
        check("owned_original_strike_default_off",
              "option BanditsWeekOne.EventFinalSolution {\n"
              "    type = boolean, default = false," in weekone.owned_source_text(),
              checks)
        check("canonical_registration_exact", weekone.compose_sandbox(
              current, reg.parse, reg.repage_options, reg.merge_header) == current,
              checks)
        check("canonical_page_map_exact", weekone.PAGES.read_text(encoding="utf-8")
              == weekone.page_map_text(reg.parse), checks)
        check("canonical_locale_exact", weekone.compose_locale(locale) == locale,
              checks)
        check("creator_variant_absent", "BanditsWeekOne.Variant"
              not in weekone.layout(), checks)
        native_tick = NATIVE_TICKBOX.read_text(encoding="utf-8")
        check("native_mouse_enable_guard", "if self.enable and self.mouseOverOption"
              in native_tick, checks)
        check("native_joypad_disabled_option_guard", "if self.disabledOptions[self.optionsIndex[self.joypadIndex]]"
              in native_tick, checks)

        without = strip_weekone(current)
        recovered = weekone.compose_sandbox(without, reg.parse,
                                            reg.repage_options, reg.merge_header)
        check("d2_reseal_restores_all_24", all(
              id in {row.get("id") for row in reg.parse(recovered)}
              for id in weekone.layout()), checks)
        original_default = current.replace(
            "option BanditsWeekOne.EventFinalSolution {\n"
            "    type = boolean, default = false,",
            "option BanditsWeekOne.EventFinalSolution {\n"
            "    type = boolean, default = true,", 1)
        check("prior_integrated_default_migrates_once",
              original_default != current and weekone.compose_sandbox(
                  original_default, reg.parse, reg.repage_options,
                  reg.merge_header) == current, checks)
        expect_refusal("partial_registration_refused", lambda:
            weekone.compose_sandbox(current.replace(
                next(row["raw"] for row in reg.parse(current)
                     if row.get("id") == "BanditsWeekOne.EventArson"), "", 1),
                reg.parse, reg.repage_options, reg.merge_header), controls)
        expect_refusal("changed_strike_definition_refused", lambda:
            weekone.compose_sandbox(current.replace(
                "option BanditsWeekOne.EventFinalSolution {\n"
                "    type = boolean, default = false,",
                "option BanditsWeekOne.EventFinalSolution {\n"
                "    type = boolean, default = 1,", 1),
                reg.parse, reg.repage_options, reg.merge_header), controls)
        expect_refusal("changed_locale_refused", lambda:
            weekone.compose_locale(locale.replace(
                '"Sandbox_SAO_WeekOne_Control_EventFinalSolution": "Original Week One strike"',
                '"Sandbox_SAO_WeekOne_Control_EventFinalSolution": "Wrong"', 1)), controls)

        # A controlled D2 reseal starts without the Week One appendix. Current
        # D2 source fragments are pinned afresh here; the older full report has
        # an unrelated ContextMenu source-seal drift.
        report = json.loads(D2_REPORT.read_text(encoding="utf-8"))
        rows = [row for row in report["mergeRequired"] if row["enginePath"] in (
            "media/sandbox-options.txt", "media/lua/shared/Translate/EN/Sandbox.json")]
        check("d2_seven_option_fragments", sum(row["enginePath"]
              == "media/sandbox-options.txt" for row in rows) == 7, checks)
        with tempfile.TemporaryDirectory(prefix="sao-weekone-reseal-") as tmp:
            package = Path(tmp)
            target = package / "media/sandbox-options.txt"
            target.parent.mkdir(parents=True)
            target.write_text(without, encoding="utf-8")
            (package / "mod.info").write_text("id=SurvivorAwareness\n", encoding="utf-8")
            for row in rows:
                original = reg.PACKAGE / row["fragment"]
                copy = package / row["fragment"]
                copy.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(original, copy)
                row["sha256"] = weekone.sha(copy.read_bytes())
            locale_original = next(row for row in rows if row["enginePath"].endswith("Sandbox.json"))
            locale_path = package / locale_original["enginePath"]
            locale_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(package / locale_original["fragment"], locale_path)
            planned, audit, _ = reg.plan(package, {"mergeRequired": rows,
                                                  "registrations": {}})
            option_result = planned["media/sandbox-options.txt"].decode("utf-8")
            locale_result = json.loads(planned["media/lua/shared/Translate/EN/Sandbox.json"])
            planned_ids = [row.get("id") for row in reg.parse(option_result)
                           if row["kind"] == "block"]
            check("actual_d2_plan_restores_24", all(planned_ids.count(id) == 1
                  for id in weekone.layout()), checks)
            check("actual_d2_plan_restores_locale", all(
                  locale_result[key] == value
                  for key, value in weekone.locale_entries().items()), checks)
            check("d2_156_preserved", audit["sourceSandboxLayout"]["optionCount"]
                  == 156, checks)
            manifest = out / "expected-pages.tsv"
            manifest.write_text("".join(id + "\t" + page + "\n" for id, (_, page)
                                        in weekone.layout().items()), encoding="utf-8")
            native_sandbox = out / "resealed-sandbox-options.txt"
            native_sandbox.write_text(option_result, encoding="utf-8")
            with tempfile.TemporaryDirectory(prefix="sao-weekone-sandbox-java-") as jtmp:
                work = Path(jtmp)
                shutil.copyfile(GAME / "stdlib.lua", work / "stdlib.lua")
                cp = os.pathsep.join(map(str, jars))
                status, log = run([JDK / "javac.exe", "-encoding", "UTF-8",
                                   "-cp", cp, "-d", work, JAVA, KAHUA_JAVA],
                                  work, out, "compile", receipt)
                check("native_probe_compiles", status == 0, checks)
                status, log = run([JDK / "java.exe", "--enable-native-access=ALL-UNNAMED",
                                   "-Djava.awt.headless=true", "-cp", str(work)
                                   + os.pathsep + cp, "WeekOneSandboxProbe",
                                   weekone.SOURCE, native_sandbox, manifest, GAME],
                                  GAME, out, "native-registration", receipt)
                check("native_receiver_passes", status == 0
                      and "PASS native Week One sandbox" in log, checks)
                source_manifest = out / "ui-sources.tsv"
                source_manifest.write_text("".join(k + "\t" + str(v) + "\n" for k, v in [
                    ("Owned:D2Catalog", D2_CATALOG),
                    ("Owned:WeekOneCatalog", weekone.PAGES),
                    ("Owned:Sandbox", OWNER_UI),
                ]), encoding="utf-8")
                status, log = run([JDK / "java.exe", "--enable-native-access=ALL-UNNAMED",
                                   "-Djava.awt.headless=true", "-cp", str(work)
                                   + os.pathsep + cp, "MusicProbe", source_manifest,
                                   UI_CASES], work, out, "kahlua-ui", receipt)
                check("dual_order_ui_passes", status == 0
                      and "PASS Week One sandbox UI" in log, checks)
                original_owner = OWNER_UI.read_text(encoding="utf-8")
                for name, old, replacement, marker in [
                    ("missing-source-last-owned-selection",
                     "if rule.preferOwned then\n                    for _, row in ipairs(rows) do",
                     "if false then\n                    for _, row in ipairs(rows) do",
                     "WEEKONE_SANDBOX_UI:source-last_owned_page_"),
                    ("missing-joypad-strike-disable",
                     'control:disableOption("", true)',
                     'control.disabledOptions[""] = nil',
                     "WEEKONE_SANDBOX_UI:creator_controls_later_choice_"),
                ]:
                    check(name + "_mutation_anchor", original_owner.count(old) == 1,
                          checks)
                    variant = out / (name + ".lua")
                    variant.write_text(original_owner.replace(old, replacement, 1),
                                       encoding="utf-8")
                    inverse_manifest = out / (name + "-sources.tsv")
                    inverse_manifest.write_text("".join(k + "\t" + str(v) + "\n"
                        for k, v in [("Owned:D2Catalog", D2_CATALOG),
                                     ("Owned:WeekOneCatalog", weekone.PAGES),
                                     ("Owned:Sandbox", variant)]), encoding="utf-8")
                    status, log = run([JDK / "java.exe", "--enable-native-access=ALL-UNNAMED",
                                       "-Djava.awt.headless=true", "-cp", str(work)
                                       + os.pathsep + cp, "MusicProbe", inverse_manifest,
                                       UI_CASES], work, out, name, receipt)
                    check(name + "_flips_verdict", status != 0 and marker in log,
                          checks)
                    controls.append(name)
        receipt["inputsAfter"] = {str(p): weekone.sha(p.read_bytes()) for p in inputs}
        check("inputs_unchanged", receipt["inputsAfter"] == receipt["inputsBefore"], checks)
        receipt["status"] = "PASS"
        save()
        print("PASS Week One sandbox", len(checks), "checks,", len(controls), "inverses")
        return 0
    except Exception as error:
        receipt["status"] = "FAIL"
        receipt["failure"] = str(error)
        save()
        raise


if __name__ == "__main__":
    raise SystemExit(main())
