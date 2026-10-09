#!/usr/bin/env python3
"""Exercise SAO's represented-body menu bridge through Viewpoint's own collector.

This is a controlled Kahlua menu and body fixture. It establishes selected
source behavior and catches bridge regressions; it does not observe a game UI.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parent.parent
BRIDGE = ROOT / "mod/42.20/media/lua/client/SAO_Viewpoint.lua"
UPSTREAM_VIEWPOINT = ROOT / (
    "_scratch/d2-leisure-01/viewpoint21/steamcmd-anon-20261008T003202Z/"
    "workshop-intake/steamapps/workshop/content/108600/3809306528/"
    "mods/Viewpoint/42/media/lua/client/Viewpoint_Interact.lua"
)
VIEWPOINT = ROOT / "mod/42.20/media/lua/client/SAO_Viewpoint_Interact.lua"
VIEWPOINT_JAR = UPSTREAM_VIEWPOINT.parents[2] / "java/client/Viewpoint.jar"
GAME = Path("C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid")
JDK = Path("C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin")
PROBE = ROOT / "tools/luacheck/PhysicalMeansLuaProbe.java"

BRIDGE_SHA = "38a6a99c350d3b2bea37099295b02c242821690795076b6d03cdae008efc7f48"
VIEWPOINT_SHA = "b4c05a54d3325555bbc75eeab64ff01c157838ebed54b251b7b38c2f019895d4"
UPSTREAM_SHA = "40334e734637eb79cdc701c6c4e7080d6a786d21fc9237928e24b47624dfb74a"
VIEWPOINT_JAR_SHA = "94fedda302ab6c17ba1b38495789e4c9781d52823fb8204214c85402e3cab41f"

PRELUDE = r'''
local function event()
    local e = { handlers = {} }
    function e.Add(fn) table.insert(e.handlers, fn) end
    function e.Remove(fn)
        for i = #e.handlers, 1, -1 do
            if e.handlers[i] == fn then table.remove(e.handlers, i) end
        end
    end
    return e
end
Events = { OnTick = event(), OnFillWorldObjectContextMenu = event() }
Viewpoint = { Keys = {} }
ISWorldObjectContextMenu = {}
ISContextMenu = {}
ISVehicleMenu = {}
DebugContextMenu = {}
AnimalContextMenu = {}
function instanceof(value, cls)
    return type(value) == "table" and value.classes and value.classes[cls] == true or false
end
function getTexture() return nil end
function getText(key) return key end
function isoToScreenX() return 0 end
function isoToScreenY() return 0 end
function getCell() return { getDrag = function() return nil end } end
local open = {
    getIsVisible = function() return false end,
    hideAndChildren = function(self) self.hidden = true end,
}
function getPlayerContextMenu() return open end
__player = { getPlayerNum = function() return 0 end }
local square = {
    getX = function() return 1 end,
    getY = function() return 2 end,
    getZ = function() return 0 end,
}
function __body(tag)
    local body = { tag = tag, square = square,
        classes = { IsoObject = true, IsoGameCharacter = true } }
    function body:isDead() return self.dead == true end
    function body:getSquare() return self.square end
    return body
end
__a, __b, __junk = __body("A"), __body("B"), __body("junk")
__records = {
    a = { id = "a", name = "Mara" },
    b = { id = "b", name = "Noel" },
}
__current = { a = __a, b = __b }
SAO = {
    Body = {
        active = { a = __a }, foreign = { b = __b },
        get = function(id) return __current[id] end,
    },
    Identity = {
        get = function(id) return __records[id] end,
        knownName = function(rec) return rec.name end,
    },
}
__effects = {}
__occupied = nil
__lastMenu = nil
local function menu()
    local m = { options = {}, submenus = {}, numOptions = 1 }
    function m:addOption(name, target, callback)
        local option = { name = name, target = target, onSelect = callback }
        table.insert(self.options, option)
        self.numOptions = #self.options + 1
        return option
    end
    function m:addSubMenu(root, sub)
        root.subOption = #self.submenus + 1
        self.submenus[root.subOption] = sub
    end
    function m:getSubMenu(index) return self.submenus[index] end
    function m:getOptionFromName(name)
        for _, option in ipairs(self.options) do
            if option.name == name then return option end
        end
    end
    function m:isEmpty() return #self.options == 0 end
    return m
end
local function person(m, id, name)
    local talk = m:addOption("Talk to " .. name, nil, function(_, body)
        table.insert(__effects, { id = id, verb = "talk", body = body })
    end)
    local root = m:addOption(name .. "...", nil, nil)
    local sub = menu()
    m:addSubMenu(root, sub)
    sub:addOption("Look them over", nil, function(_, body)
        table.insert(__effects, { id = id, verb = "look", body = body })
    end)
    if id == "a" then __aTalk, __aRoot, __aSub = talk, root, sub
    else __bTalk, __bRoot, __bSub = talk, root, sub end
end
function ISWorldObjectContextMenu.createMenu(playerNum, worldobjects)
    local m = menu()
    if __neighbour then
        local root = m:addOption("Mara...", nil, nil)
        local sub = menu()
        m:addSubMenu(root, sub)
        __neighbourTalk = sub:addOption("Talk to them", nil, function(_, body)
            table.insert(__effects, { id = "a", verb = "neighbour-talk", body = body })
        end)
    else
        person(m, "a", "Mara")
    end
    person(m, "b", "Noel")
    if __occupied then __aTalk.param1 = __occupied end
    __lastMenu = m
    for _, callback in ipairs(Events.OnFillWorldObjectContextMenu.handlers) do
        callback(playerNum, m, worldobjects)
    end
    return m
end
__lateWorldMenu = ISWorldObjectContextMenu
ISWorldObjectContextMenu = nil
'''

CASES = r'''
local checks = 0
local function check(name, value)
    checks = checks + 1
    if not value then error("VIEWPOINT_BRIDGE:" .. name) end
end
local V = SAO.Viewpoint
ISWorldObjectContextMenu = __lateWorldMenu
check("available", V.available())
check("not_installed_early", #Events.OnFillWorldObjectContextMenu.handlers == 0)
local early = ViewpointInteract.harvest(__player, __a)
check("late_menu_resolved", early.labels ~= nil)
check("late_registration", #early.labels == 0)
check("tick_installer", #Events.OnTick.handlers == 1)
Events.OnTick.handlers[1]()
check("installed_after_tick", #Events.OnFillWorldObjectContextMenu.handlers == 1
    and Events.OnFillWorldObjectContextMenu.handlers[1] == V.bindPersonMenu)
check("tick_removed", #Events.OnTick.handlers == 0)

local a = ViewpointInteract.harvest(__player, __a)
check("exact_body_a", #a.labels == 2 and a.labels[1] == "Talk to Mara"
    and a.labels[2] == "Look them over")
check("a_talk_argument", __aTalk.param1 == __a)
check("a_look_argument", __aSub:getOptionFromName("Look them over").param1 == __a)
check("foreign_menu_untouched", __bTalk.param1 == nil
    and __bSub:getOptionFromName("Look them over").param1 == nil)
check("root_menu_untouched", __aRoot.param1 == nil and __bRoot.param1 == nil)
check("callback_retained", ViewpointInteract.actions[1].fn == __aTalk.onSelect)
ViewpointInteract.run(__player, 1)
check("original_callback_a", #__effects == 1 and __effects[1].id == "a"
    and __effects[1].body == __a)

local junk = ViewpointInteract.harvest(__player, __junk)
check("unrelated_object_ignored", #junk.labels == 0 and __aTalk.param1 == nil
    and __bTalk.param1 == nil)

local b = ViewpointInteract.harvest(__player, __b)
check("exact_body_b", #b.labels == 2 and b.labels[1] == "Talk to Noel"
    and b.labels[2] == "Look them over")
check("b_talk_argument", __bTalk.param1 == __b)
check("unselected_a_untouched", __aTalk.param1 == nil)
ViewpointInteract.run(__player, 1)
check("original_callback_b", #__effects == 2 and __effects[2].id == "b"
    and __effects[2].body == __b)

__neighbour = true
SAO.Neighbours = {
    bridgeOpen = function() return true end,
    profileFor = function(id) return id == "a" and { name = "Mara" } or nil end,
}
local neighbour = ViewpointInteract.harvest(__player, __a)
check("neighbour_exact_body", #neighbour.labels == 1
    and neighbour.labels[1] == "Talk to them" and __neighbourTalk.param1 == __a)
check("neighbour_foreign_menu_untouched", __bTalk.param1 == nil)
ViewpointInteract.run(__player, 1)
check("neighbour_original_callback", #__effects == 3
    and __effects[3].verb == "neighbour-talk" and __effects[3].body == __a)
__neighbour = nil
SAO.Neighbours = nil

__current.a = __body("replacement")
local stale = ViewpointInteract.harvest(__player, __a)
check("stale_body_rejected", #stale.labels == 0)
__current.a = __a
__records.a.dead = true
check("dead_record_rejected", #ViewpointInteract.harvest(__player, __a).labels == 0)
__records.a.dead = nil
__a.dead = true
check("dead_body_rejected", #ViewpointInteract.harvest(__player, __a).labels == 0)
__a.dead = nil
__a.square = nil
check("unsquared_body_rejected", V.bindPersonMenu(0, ISWorldObjectContextMenu.createMenu(0, {}), {__a}) == false)
__a.square = __b:getSquare()

__occupied = __b
local occupied = ViewpointInteract.harvest(__player, __a)
check("occupied_option_preserved", __aTalk.param1 == __b)
check("occupied_talk_not_collected", #occupied.labels == 1
    and occupied.labels[1] == "Look them over")
check("look_still_owned", __aSub:getOptionFromName("Look them over").param1 == __a)
__occupied = nil

local saved = ViewpointInteract
ViewpointInteract = nil
local noSource = ISWorldObjectContextMenu.createMenu(0, {__a})
check("source_absent_refused", V.bindPersonMenu(0, noSource, {__a}) == false
    and __aTalk.param1 == nil)
ViewpointInteract = saved
local withJava = Viewpoint
Viewpoint = nil
local noJava = ISWorldObjectContextMenu.createMenu(0, {__a})
check("renderer_absent_refused", V.bindPersonMenu(0, noJava, {__a}) == false
    and __aTalk.param1 == nil)
Viewpoint = withJava
check("nil_context_refused", V.bindPersonMenu(0, nil, {__a}) == false)
__result = checks
'''


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def replace_once(raw: bytes, old: bytes, new: bytes) -> bytes:
    if raw.count(old) != 1:
        raise AssertionError(f"inverse control anchor moved: {old!r}")
    return raw.replace(old, new, 1)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    inputs = [Path(__file__), BRIDGE, VIEWPOINT, UPSTREAM_VIEWPOINT,
              VIEWPOINT_JAR, PROBE,
              GAME / "projectzomboid.jar", GAME / "stdlib.lua"]
    before = {str(path): sha(path) for path in inputs}
    receipt = {
        "schema": "sao-viewpoint-bridge-controlled/1",
        "status": "INCOMPLETE",
        "boundary": __doc__,
        "sourcePins": {
            "saoBridgeSha256": BRIDGE_SHA,
            "saoViewpointInteractSha256": VIEWPOINT_SHA,
            "upstreamViewpointInteractSha256": UPSTREAM_SHA,
            "viewpointJarSha256": VIEWPOINT_JAR_SHA,
        },
        "inputsBefore": before,
        "runs": [],
        "controls": [],
    }

    def save() -> None:
        (out / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")

    def run(name: str, command: list[str], cwd: Path) -> tuple[int, str]:
        result = subprocess.run(command, cwd=cwd, capture_output=True, timeout=120)
        log = out / f"{name}.log"
        log.write_bytes(result.stdout + result.stderr)
        receipt["runs"].append({"name": name, "exitCode": result.returncode,
                                "logSha256": sha(log)})
        save()
        return result.returncode, log.read_text(encoding="utf-8", errors="replace")

    save()
    try:
        assert before[str(BRIDGE)] == BRIDGE_SHA, "SAO bridge source pin changed"
        assert before[str(VIEWPOINT)] == VIEWPOINT_SHA, "SAO collector source pin changed"
        assert before[str(UPSTREAM_VIEWPOINT)] == UPSTREAM_SHA, "upstream collector source pin changed"
        assert before[str(VIEWPOINT_JAR)] == VIEWPOINT_JAR_SHA, "Viewpoint package pin changed"
        (out / "prelude.lua").write_text(PRELUDE, encoding="utf-8")
        (out / "cases.lua").write_text(CASES, encoding="utf-8")
        shutil.copyfile(GAME / "stdlib.lua", out / "stdlib.lua")
        source = BRIDGE.read_bytes()
        variants = [("baseline", source, None),
                    ("unrelated-object", replace_once(source,
                        b"object == body and bodies.get(id) == body",
                        b"bodies.get(id) == body"), "unrelated_object_ignored"),
                    ("stale-body", replace_once(source,
                        b"bodies.get(id) == body",
                        b"true"), "stale_body_rejected"),
                    ("occupied-option", replace_once(source,
                        b"option.param1 ~= nil", b"false"), "occupied_option_preserved"),
                    ("missing-viewpoint", replace_once(source,
                        b"if not V.available() or not context then return false end",
                        b"if not context then return false end"), "source_absent_refused"),
                    ("renderer-absent", replace_once(source,
                        b"return Viewpoint and Viewpoint.Keys ~= nil\n        and type(ViewpointInteract) == \"table\"",
                        b"return type(ViewpointInteract) == \"table\""),
                        "renderer_absent_refused")]
        with tempfile.TemporaryDirectory(prefix="sao-viewpoint-bridge-") as tmp:
            classes = Path(tmp)
            cp = str(GAME / "projectzomboid.jar")
            code, log = run("compile-probe", [str(JDK / "javac.exe"), "-encoding", "UTF-8",
                                              "-cp", cp, "-d", str(classes), str(PROBE)], out)
            assert code == 0, log
            cp = os.pathsep.join([str(classes), cp])
            for name, raw, expected_failure in variants:
                variant = out / f"{name}-bridge.lua"
                variant.write_bytes(raw)
                code, log = run(name, [str(JDK / "java.exe"), "-cp", cp,
                                       "PhysicalMeansLuaProbe", str(out / "prelude.lua"),
                                       str(VIEWPOINT), str(variant), str(out / "cases.lua"),
                                       "--", "__result"], out)
                if expected_failure:
                    assert code != 0 and f"VIEWPOINT_BRIDGE:{expected_failure}" in log, (name, log)
                    receipt["controls"].append({"name": name,
                                                "expectedFailure": expected_failure,
                                                "variantSha256": sha(variant)})
                else:
                    assert code == 0 and "VALUE " in log, log
                    receipt["checks"] = int(float(log.split("VALUE ", 1)[1].split()[0]))
            static_menu = out / "static-menu-capture-viewpoint.lua"
            static_menu.write_bytes(replace_once(VIEWPOINT.read_bytes(),
                b"    W = ISWorldObjectContextMenu\n    if not W",
                b"    if not W"))
            code, log = run("static-menu-capture", [str(JDK / "java.exe"), "-cp", cp,
                "PhysicalMeansLuaProbe", str(out / "prelude.lua"), str(static_menu),
                str(out / "baseline-bridge.lua"), str(out / "cases.lua"),
                "--", "__result"], out)
            assert code != 0 and "VIEWPOINT_BRIDGE:late_menu_resolved" in log, log
            receipt["controls"].append({"name": "static-menu-capture",
                "expectedFailure": "late_menu_resolved",
                "variantSha256": sha(static_menu)})
        after = {str(path): sha(path) for path in inputs}
        assert after == before, "test or selected source changed during qualification"
        receipt["inputsAfter"] = after
        receipt["status"] = "PASS"
        save()
        print(f"PASS {receipt['checks']} controlled checks; {len(receipt['controls'])} inverse controls")
        return 0
    except Exception as error:
        receipt["status"] = "FAIL"
        receipt["error"] = str(error)
        save()
        raise


if __name__ == "__main__":
    raise SystemExit(main())
