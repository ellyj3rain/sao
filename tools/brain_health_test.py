#!/usr/bin/env python3
"""Border 172: event-derived, owner-correct brain health in installed Kahlua."""
from __future__ import annotations

from pathlib import Path
import os
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parent.parent
ZAO_ROOT = ROOT.parent / "zombie-awareness"
GAME = Path(os.environ.get("PZ_DIR", r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"))
JDK = Path(os.environ.get("JDK_BIN", r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin"))
RUNNER = ROOT / "tools/luacheck/LuaRun.java"
NEURO = ROOT / "mod/42.20/media/lua/shared/SAO_Neuro.lua"
STATE = ZAO_ROOT / "mod/42.20/media/lua/shared/ZAO_StateStore.lua"
BRAIN = ZAO_ROOT / "mod/42.20/media/lua/shared/ZAO_Brain.lua"

HOST = r'''
local durable = {}
ModData = { getOrCreate = function(key)
    durable[key] = durable[key] or {}
    return durable[key]
end }
Events = { OnGameStart = { Add = function() end, Remove = function() end } }
SandboxVars = { SurvivorAwareness = { Neuroinflammation = true } }
local records = {}
local now = 0
SAO = {
    History = { countyHours = function() return now end },
    Identity = { get = function(id) return records[tostring(id)] end },
    Habits = { withdrawalPhase = function() return 0 end },
}
ZAO = {}
function __record(id, values)
    values = values or {}
    values.id = id
    records[id] = values
    return values
end
function __clock(value) now = value end
function __store() return durable["ZombieAwareness_State"] end
'''

PROBE = r'''(function()
    local function close(a, b, tolerance, message)
        assert(math.abs(a - b) <= (tolerance or 0.0000001),
            (message or "values differ") .. ": " .. tostring(a) .. " / " .. tostring(b))
    end

    -- Equal event histories agree whether callbacks arrive once or hourly.
    local whole = __record("whole", { knoxInfected = true,
        infectionStartedAtHours = 0, biteDeathAtHours = 48,
        infectionSpanHours = 48 })
    SAO.Neuro.observe(whole, 0, "infection")
    SAO.Neuro.observe(whole, 48, "elapsed")
    local wholeState = SAO.Neuro.stateOf(whole)
    assert(whole.brainHealth == nil, "SAO shadowed ZAO's durable owner")
    assert(__store().brain.whole == wholeState, "ZAO did not own brain history")
    assert(wholeState.burden > 0.5, "Knox course added no material burden")

    local partitioned = __record("partitioned", { knoxInfected = true,
        infectionStartedAtHours = 0, biteDeathAtHours = 48,
        infectionSpanHours = 48 })
    SAO.Neuro.observe(partitioned, 0, "infection")
    for hour = 1, 48 do SAO.Neuro.observe(partitioned, hour, "elapsed") end
    close(wholeState.burden, SAO.Neuro.stateOf(partitioned).burden, 0.000001,
        "interval partition changed Knox result")

    -- A repeat at the durable cursor is reload-safe and cannot double-charge.
    local beforeRepeat = wholeState.burden
    SAO.Neuro.observe(whole, 48, "reload-repeat")
    close(beforeRepeat, wholeState.burden, 0.0000001,
        "same timestamp charged twice")

    -- A newly observed toxin applies after its timestamp, never backward.
    local toxin = __record("toxin", { currentToxicBurden = 0,
        drinkPoisonTotal = 10000 })
    SAO.Neuro.observe(toxin, 0, "initial")
    SAO.Neuro.observe(toxin, 12, "clean")
    assert(SAO.Neuro.stateOf(toxin).active.toxin == 0,
        "historical poison total became current exposure")
    toxin.currentToxicBurden = 100
    SAO.Neuro.observe(toxin, 12, "poisoned")
    SAO.Neuro.observe(toxin, 24, "elapsed")
    local expected = SAO.Neuro.project(0, { toxin = 1, clearance = 1 }, 12, 24, true)
    close(SAO.Neuro.stateOf(toxin).burden, expected, 0.000001,
        "new exposure was charged outside its actual interval")
    local backcharged = SAO.Neuro.project(0, { toxin = 1, clearance = 1 }, 0, 24, true)
    assert(math.abs(expected - backcharged) > 0.05,
        "causality control lacks discriminating power")

    -- ZAO terminal state wins over an unwritten/stale SAO-looking field.
    __store().people.owner = { terminalState = "crossed" }
    local owner = __record("owner", { terminalState = "afflicted" })
    SAO.Neuro.observe(owner, 0, "owner")
    assert(SAO.Neuro.stateOf(owner).active.terminal == "crossed")
    assert(SAO.Neuro.loadOf(owner) >= 0.90)

    -- Standalone SAO retains the same contract and afflicted floor.
    local installed = ZAO
    ZAO = nil
    local standalone = __record("standalone", { afflictedReturn = true })
    SAO.Neuro.observe(standalone, 0, "standalone")
    assert(standalone.brainHealth ~= nil and SAO.Neuro.loadOf(standalone) >= 0.30)
    ZAO = installed

    -- The off switch is neutral, retains history, and moves the cursor so a
    -- disabled interval is not accrued when the option is re-enabled.
    local disabled = __record("disabled", { woundInfected = true })
    SAO.Neuro.observe(disabled, 0, "wound")
    SandboxVars.SurvivorAwareness.Neuroinflammation = false
    SAO.Neuro.observe(disabled, 10, "disabled")
    local disabledState = SAO.Neuro.stateOf(disabled)
    local beforeOff = disabledState.burden
    local historyCount = #disabledState.history
    SAO.Neuro.observe(disabled, 20, "disabled-elapsed")
    close(disabledState.burden, beforeOff, 0.0000001,
        "disabled interval accumulated")
    assert(SAO.Neuro.loadOf(disabled) == 0 and SAO.Neuro.clarityOf(disabled) == 1)
    assert(#disabledState.history >= historyCount, "off switch erased history")
    SandboxVars.SurvivorAwareness.Neuroinflammation = true
    SAO.Neuro.observe(disabled, 20, "enabled")
    close(disabledState.burden, beforeOff, 0.0000001,
        "re-enable backcharged disabled interval")
    SAO.Neuro.observe(disabled, 30, "enabled-elapsed")
    assert(disabledState.burden > beforeOff, "re-enabled cause did not resume")

    local points = SAO.Neuro.series(disabled, 30, 30, 64)
    assert(#points >= 3, "graph is not a history")
    local changed = false
    for index = 2, #points do
        if math.abs(points[index].load - points[index - 1].load) > 0.000001 then
            changed = true
        end
    end
    assert(changed, "history graph contains only one scalar value")
    return "brain history holds"
end)()'''


def run(neuro_source: str) -> subprocess.CompletedProcess[str]:
    jar, stdlib = GAME / "projectzomboid.jar", GAME / "stdlib.lua"
    with tempfile.TemporaryDirectory(prefix="sao-brain-health-") as tmp:
        work = Path(tmp)
        shutil.copy2(stdlib, work / "stdlib.lua")
        (work / "host.lua").write_text(HOST, encoding="utf-8")
        (work / "neuro.lua").write_text(neuro_source, encoding="utf-8")
        compiled = subprocess.run(
            [str(JDK / "javac.exe"), "-cp", str(jar), "-d", str(work), str(RUNNER)],
            cwd=work, capture_output=True, text=True, timeout=60)
        if compiled.returncode:
            return compiled
        return subprocess.run(
            [str(JDK / "java.exe"), "-cp", f"{jar}{os.pathsep}{work}", "LuaRun",
             str(work / "host.lua"), str(STATE), str(BRAIN), str(work / "neuro.lua"),
             "--", PROBE], cwd=work, capture_output=True, text=True, timeout=60)


def main() -> int:
    required = [GAME / "projectzomboid.jar", GAME / "stdlib.lua",
                JDK / "java.exe", JDK / "javac.exe", RUNNER, NEURO, STATE, BRAIN]
    if not all(path.is_file() for path in required):
        print("Border 172 SKIPPED: installed game VM, JDK, or paired ZAO branch absent")
        return 0
    source = NEURO.read_text(encoding="utf-8-sig")
    fixed = run(source)
    if fixed.returncode or "VALUE brain history holds" not in fixed.stdout:
        print("REFUSED: brain-health production path failed\n" + fixed.stdout + fixed.stderr)
        return 1

    controls = [
        ("Knox interval integration",
         "+ knoxContribution(active, fromHours, toHours, decayRate)", "+ 0.0"),
        ("current toxic burden", "rec and rec.currentToxicBurden",
         "rec and rec.drinkPoisonTotal"),
        ("off-switch interval", "or enabled == false then return burden end",
         "then return burden end"),
        ("ZAO terminal owner", "terminal = state and state.terminalState or nil",
         "terminal = rec.terminalState"),
    ]
    for name, old, new in controls:
        if source.count(old) != 1:
            print(f"REFUSED: {name} mutation seam changed")
            return 1
        result = run(source.replace(old, new, 1))
        if result.returncode == 0:
            print(f"REFUSED: {name} mutation survived\n" + result.stdout + result.stderr)
            return 1
    print("Border 172 PASS: exact event intervals, reload cursor, ZAO ownership, current exposure, off switch, standalone fallback and history graph; four controls fail")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
