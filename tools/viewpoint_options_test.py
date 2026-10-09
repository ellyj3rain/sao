#!/usr/bin/env python3
"""Controlled SAO-owned Viewpoint options registration under installed Kahlua."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "mod/42.20/media/lua/client/SAO_Viewpoint_Options.lua"
PROBE = ROOT / "tools/luacheck/PhysicalMeansLuaProbe.java"
GAME = Path("C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid")
JDK = Path("C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin")

PRELUDE = r'''
local function event()
    local value = { handlers = {} }
    function value.Add(fn) table.insert(value.handlers, fn) end
    return value
end
Events = { OnGameBoot = event(), OnGameStart = event() }
__pages, __titles, __loads, __loot, __baseOptions, __existingApply = {}, {}, 0, nil, 0, 0
PZAPI = { ModOptions = { pages = __pages } }
function PZAPI.ModOptions:getOptions(id) return self.pages[id] end
function PZAPI.ModOptions:create(id, label)
    local page = { id = id, label = label, titles = {}, binds = {} }
    function page:addTitle(title)
        table.insert(self.titles, title)
        table.insert(__titles, title)
    end
    function page:addTickBox(id, label, value)
        self.loot = { id = id, label = label, value = value,
            getValue = function(self) return self.value end }
        return self.loot
    end
    function page:addKeyBind(id, label)
        local option = { id = id, label = label, element = {
            keyCode = 1, btn = { setTitle = function(self, title)
                self.title = title
            end } } }
        table.insert(self.binds, option)
        return option
    end
    self.pages[id] = page
    return page
end
function PZAPI.ModOptions:load() __loads = __loads + 1 end
MainOptions = {
    addModOptionsPanel = function() __baseOptions = __baseOptions + 1 end,
    onKeyboardLayoutChanged = function() end,
}
ISSetKeybindDialog = {
    onKeyRelease = function() end, onDefault = function() end,
    onClear = function() end, onMouseButtonDown = function() end,
}
Keyboard = { KEY_ESCAPE = 27 }
Viewpoint = nil
'''

CASES = r'''
local checks = 0
local function check(name, good)
    if not good then error("VIEWPOINT_OPTIONS:" .. name) end
    checks = checks + 1
end
check("no_premature_page", __pages.SurvivorAwareness == nil)
check("boot_retry_registered", #Events.OnGameBoot.handlers == 1)
check("pending_marker_clear", SAOViewpointOptionsLoaded ~= true)
local existing = PZAPI.ModOptions:create("SurvivorAwareness", "Survivor Awareness")
function existing:apply() __existingApply = __existingApply + 1 end
for _, fn in ipairs(Events.OnGameBoot.handlers) do fn() end
check("late_keys_still_pending", SAOViewpointOptionsLoaded ~= true)
local K = {
    count = function() return 1 end,
    id = function() return "viewMode" end,
    label = function() return "View mode" end,
    group = function() return "Camera" end,
    loot = function() return true end,
    get = function() return "F8" end,
    fallback = function() return "F8" end,
    tooltip = function() return "Switch camera view" end,
    trigger = function() return 119 end,
    holds = function() return false end,
    display = function(value) return value end,
    set = function(id, value) __set = { id, value } end,
    captured = function() return "F8" end,
    without = function(_, value) return value end,
}
Viewpoint = { Keys = K, Loot = {
    setEnabled = function(value) __loot = value end,
} }
for _, fn in ipairs(Events.OnGameStart.handlers) do fn() end
local page = __pages.SurvivorAwareness
check("sao_page", page and page.id == "SurvivorAwareness")
check("source_page_absent", __pages.Viewpoint == nil)
check("viewpoint_section", page.titles[1] == "Viewpoint")
check("camera_section", page.titles[2] == "Camera")
check("one_key", #page.binds == 1 and page.binds[1].id == "viewMode")
check("loot_control", page.loot and page.loot.id == "lootMenu")
check("owned_page", SAO.Viewpoint.Options.page == page)
check("no_foreign_options_global", ViewpointOptions == nil)
for _, fn in ipairs(Events.OnGameBoot.handlers) do fn() end
check("no_duplicate_registration", #page.titles == 2 and #page.binds == 1)
MainOptions:addModOptionsPanel()
check("base_options_retained", __baseOptions == 1)
check("key_visible", page.binds[1].element.btn.title == "F8")
check("options_loaded", __loads == 1)
check("loot_applied", __loot == true)
page:apply()
check("existing_apply_preserved", __existingApply == 1)
__result = checks
'''

LATE_BEFORE = r'''
for _, fn in ipairs(Events.OnGameBoot.handlers) do fn() end
for _, fn in ipairs(Events.OnGameStart.handlers) do fn() end
Viewpoint = { Keys = { count = function() return 0 end },
    Loot = { setEnabled = function(value) __loot = value end } }
getPlayer = function() return {} end
'''

LATE_AFTER = r'''
local checks = 0
local function check(name, good)
    if not good then error("VIEWPOINT_OPTIONS_LATE:" .. name) end
    checks = checks + 1
end
check("installed_after_start", SAOViewpointOptionsLoaded == true)
check("sao_page_only", __pages.SurvivorAwareness ~= nil and __pages.Viewpoint == nil)
check("late_options_loaded", __loads == 1)
check("late_loot_applied", __loot == true)
check("no_duplicate_boot_handler", #Events.OnGameBoot.handlers == 1)
check("no_duplicate_start_handler", #Events.OnGameStart.handlers == 1)
__result = checks
'''


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def changed(source: bytes, old: bytes, new: bytes) -> bytes:
    if source.count(old) != 1:
        raise AssertionError(f"test anchor moved: {old!r}")
    return source.replace(old, new, 1)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True, type=Path)
    out = parser.parse_args().out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    inputs = [Path(__file__), SOURCE, PROBE, GAME / "projectzomboid.jar",
              GAME / "stdlib.lua"]
    before = {str(path): sha(path) for path in inputs}
    receipt = {
        "schema": "sao-viewpoint-options-controlled/1",
        "status": "INCOMPLETE",
        "boundary": __doc__,
        "inputsBefore": before,
        "runs": [],
    }

    def save():
        (out / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")

    def run(name, args):
        result = subprocess.run(args, cwd=out, capture_output=True, timeout=120)
        log = out / f"{name}.log"
        log.write_bytes(result.stdout + result.stderr)
        receipt["runs"].append({"name": name, "exitCode": result.returncode,
                                "logSha256": sha(log)})
        save()
        return result.returncode, log.read_text(errors="replace")

    save()
    try:
        (out / "prelude.lua").write_text(PRELUDE)
        (out / "cases.lua").write_text(CASES)
        (out / "late-before.lua").write_text(LATE_BEFORE)
        (out / "late-after.lua").write_text(LATE_AFTER)
        (out / "stdlib.lua").write_bytes((GAME / "stdlib.lua").read_bytes())
        classes = out / "classes"
        classes.mkdir()
        code, log = run("compile", [str(JDK / "javac.exe"), "-encoding", "UTF-8",
                                    "-cp", str(GAME / "projectzomboid.jar"),
                                    "-d", str(classes), str(PROBE)])
        assert code == 0, log
        cp = os.pathsep.join([str(classes), str(GAME / "projectzomboid.jar")])
        source = SOURCE.read_bytes()
        variants = [
            ("production", source, None),
            ("wrong-page-lookup", changed(source,
                b'options:getOptions("SurvivorAwareness")',
                b'options:getOptions("Viewpoint")'), "existing_apply_preserved"),
            ("premature-page", changed(source,
                b"and ISSetKeybindDialog and keys())",
                b"and ISSetKeybindDialog)"), "no_premature_page"),
            ("missing-section", changed(source,
                b'page:addTitle("Viewpoint")',
                b'page:addTitle("Other")'), "viewpoint_section"),
            ("clobbered-apply", changed(source,
                b'    local previousApply = page.apply\n    function page:apply(...)\n        if type(previousApply) == "function" then previousApply(self, ...) end\n        apply()\n    end',
                b'    page.apply = apply'), "existing_apply_preserved"),
            ("premature-marker", changed(source,
                b'if not SAO.Viewpoint.Options.eventsInstalled then',
                b'SAOViewpointOptionsLoaded = true\nif not SAO.Viewpoint.Options.eventsInstalled then'),
             "pending_marker_clear"),
        ]
        for name, body, expected in variants:
            file = out / f"{name}.lua"
            file.write_bytes(body)
            code, log = run(name, [str(JDK / "java.exe"), "-cp", cp,
                                   "PhysicalMeansLuaProbe", str(out / "prelude.lua"),
                                   str(file), str(out / "cases.lua"),
                                   "--", "__result"])
            if expected:
                assert code != 0 and "VIEWPOINT_OPTIONS:" + expected in log, (name, log)
            else:
                assert code == 0 and "VALUE " in log, log
                receipt["checks"] = int(float(log.split("VALUE ", 1)[1].split()[0]))
        code, log = run("late-after-start", [str(JDK / "java.exe"), "-cp", cp,
            "PhysicalMeansLuaProbe", str(out / "prelude.lua"), str(out / "production.lua"),
            str(out / "late-before.lua"), str(out / "production.lua"),
            str(out / "late-after.lua"), "--", "__result"])
        assert code == 0 and "VALUE " in log, log
        receipt["lateFallbackChecks"] = int(float(log.split("VALUE ", 1)[1].split()[0]))
        after = {str(path): sha(path) for path in inputs}
        assert before == after, "source changed during test"
        receipt.update(status="PASS", inputsAfter=after, inverseControls=5)
        save()
        print(f"PASS {receipt['checks']} checks, {receipt['lateFallbackChecks']} late checks, 5 inverse controls")
        return 0
    except Exception as error:
        receipt.update(status="FAIL", error=str(error))
        save()
        raise


if __name__ == "__main__":
    raise SystemExit(main())
