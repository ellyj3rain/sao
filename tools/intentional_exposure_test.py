#!/usr/bin/env python3
"""Border 173: intentional, interruptible, exact-once Crossed exposure."""
from __future__ import annotations

from pathlib import Path
import os
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parent.parent
ZAO = ROOT.parent / "zombie-awareness"
GAME = Path(os.environ.get("PZ_DIR", r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"))
JDK = Path(os.environ.get("JDK_BIN", r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin"))
RUNNER = ROOT / "tools/luacheck/LuaRun.java"
STATE = ZAO / "mod/42.20/media/lua/shared/ZAO_StateStore.lua"
PATHOGEN = ZAO / "mod/42.20/media/lua/shared/ZAO_Pathogen.lua"
EXPOSURE = ZAO / "mod/42.20/media/lua/client/ZAO_Exposure.lua"
EVENTS = ROOT / "mod/42.20/media/lua/shared/SAO_PathogenEvents.lua"

HOST = r'''
local durable = {}
ModData = { getOrCreate = function(key)
    durable[key] = durable[key] or {}
    return durable[key]
end }
Events = { OnGameStart = { Add = function() end, Remove = function() end } }
local records = {
    carrier = { id = "carrier", x = 10, y = 10 },
    target = { id = "target", x = 12, y = 10 },
    target2 = { id = "target2", x = 10.5, y = 10 },
}
local function body(id, x, y)
    local data = { SAOPersonId = id }
    return {
        x = x, y = y, data = data, paths = 0, cleared = 0, faces = 0,
        getX = function(self) return self.x end,
        getY = function(self) return self.y end,
        getZ = function() return 0 end,
        getModData = function(self) return self.data end,
        pathToCharacter = function(self) self.paths = self.paths + 1 end,
        faceThisObject = function(self) self.faces = self.faces + 1 end,
        setTarget = function(self, value)
            assert(value == nil)
            self.cleared = self.cleared + 1
        end,
    }
end
local carrierBody = body("carrier", 10, 10)
local targetBody = body("target", 12, 10)
local target2Body = body("target2", 10.5, 10)
local transfers, transferReady = 0, true
local sourceOwned = {}
SAO = {
    Identity = {
        get = function(id) return records[tostring(id)] end,
        all = function() return records end,
    },
    Body = {
        active = { target = targetBody, target2 = target2Body },
        hasRepresentation = function() return false end,
        canTransfer = function() return true end,
    },
    WorldSources = {
        ownsActor = function(id) return sourceOwned[tostring(id)] == true end,
    },
    CrossedTransfer = { begin = function(id, seen, token)
        assert(id == "target" and seen == targetBody and token:sub(1, 6) == "blood:")
        if not transferReady then return false, "body-busy" end
        transfers = transfers + 1
        return true, "transferred"
    end },
    Rand = { unit = function() return 0.25 end },
    Adaptation = { observe = function() return true end },
    Neuro = { recordTerminal = function() end },
}
ZAO = {
    Controller = { controlled = { carrier = carrierBody } },
    Sandbox = { policy = function() return {
        crossedOdds = 0.5, afflictedSusceptibility = 2.0,
    } end },
}
function __bodies() return carrierBody, targetBody, target2Body end
function __transfers() return transfers end
function __transferReady(value) transferReady = value end
function __durable() return durable["ZombieAwareness_State"] end
function __protect(id, value) sourceOwned[tostring(id)] = value == true end
function __record(id) return records[tostring(id)] end
'''

AFTER_STATE = r'''
local root = ZAO.StateStore.store()
root.people.carrier = { personId = "carrier", terminalState = "crossed",
    currentForm = "none", attributeMutations = {}, history = {} }
root.people.target = { personId = "target", terminalState = "afflicted",
    currentForm = "none", attributeMutations = {}, history = {} }
root.people.target2 = { personId = "target2", terminalState = "afflicted",
    currentForm = "none", attributeMutations = {}, history = {} }
ZAO.State = { of = function(rec)
    return ZAO.StateStore.read(rec.id)
end }
'''

PROBE = r'''(function()
    local carrier, target, target2 = __bodies()
    local carrierState = ZAO.Pathogen.stateOf("carrier")

    -- The former three-tile daily proximity pass observes but cannot roll.
    -- The daily county pass also cannot overwrite a record while the exact
    -- source-use transaction owns that person.
    __protect("target", true)
    SAO.PathogenEvents.simulateDay(0)
    assert(__record("target").pathogenState == nil,
        "source-owned actor received pathogen snapshot")
    __protect("target", false)
    assert(__record("target2").pathogenState ~= nil,
        "unowned actor did not receive pathogen observation")
    assert(ZAO.Pathogen.stateOf("target").terminalState == "afflicted")
    assert(ZAO.Pathogen.stateOf("target").exposureTokens == nil,
        "daily proximity produced an exposure result")

    -- Approach is a live action and does not complete at proximity alone.
    assert(ZAO.Exposure.step(carrier, "carrier", carrierState,
        target, "target", 1, 0.0) == true)
    assert(carrier.paths == 1 and carrier.cleared == 1,
        "approach did not own movement and clear feeding target")
    assert(ZAO.Pathogen.stateOf("target").terminalState == "afflicted")
    carrier.x = 10.8
    assert(ZAO.Exposure.step(carrier, "carrier", carrierState,
        target, "target", 2, 0.01) == true)
    assert(ZAO.Pathogen.stateOf("target").terminalState == "afflicted",
        "contact completed without its action interval")
    __transferReady(false)
    assert(ZAO.Exposure.step(carrier, "carrier", carrierState,
        target, "target", 3, 0.04) == true)
    assert(ZAO.Pathogen.stateOf("target").terminalState == "crossed")
    assert(__transfers() == 0
        and ZAO.Exposure.activeFor("carrier").phase == "transfer-pending",
        "busy body did not retain a durable transfer retry")
    __transferReady(true)
    assert(ZAO.Exposure.resumePending(0.05) == true)
    assert(__transfers() == 1, "pending conversion did not transfer once")

    local root = __durable()
    local result, token = nil, nil
    for key, value in pairs(root.exposureResults) do
        if value.targetId == "target" then result, token = value, key end
    end
    assert(result and result.phase == "converted" and result.receipt.converted)
    local before = #ZAO.Pathogen.stateOf("target").history
    local repeated = ZAO.Pathogen.expose("target", carrierState, 0, {
        token = token, kind = "crossed-blood-exposure", completed = true,
        carrierId = "carrier", targetId = "target", atHours = 0.04,
    })
    assert(repeated == result.receipt and __transfers() == 1)
    assert(#ZAO.Pathogen.stateOf("target").history == before,
        "replayed receipt rolled or recorded twice")
    assert(ZAO.Pathogen.expose("target2", carrierState, 0, {}) == false,
        "pathogen accepted a result with no completed action")
    assert(ZAO.Pathogen.expose("target2", carrierState, 0, {
        token = "forged", kind = "crossed-blood-exposure", completed = true,
        carrierId = "carrier", targetId = "target2", atHours = 1.0,
        phase = "resolving",
    }) == false, "pathogen accepted a forged completed action")

    -- Contact breaks before completion: an observed interruption, no roll.
    carrier.x = 10
    assert(ZAO.Exposure.step(carrier, "carrier", carrierState,
        target2, "target2", 4, 2.0) == true)
    carrier.x = 20
    assert(ZAO.Exposure.step(carrier, "carrier", carrierState,
        target2, "target2", 5, 2.01) == false)
    assert(ZAO.Pathogen.stateOf("target2").terminalState == "afflicted")
    local interrupted = false
    for _, value in pairs(root.exposureResults) do
        if value.targetId == "target2" and value.phase == "interrupted" then
            interrupted = true
        end
    end
    assert(interrupted, "broken contact left no durable interruption")
    return "intentional exposure holds"
end)()'''


def run(pathogen: str, exposure: str, events: str) -> subprocess.CompletedProcess[str]:
    jar, stdlib = GAME / "projectzomboid.jar", GAME / "stdlib.lua"
    with tempfile.TemporaryDirectory(prefix="sao-intentional-exposure-") as tmp:
        work = Path(tmp)
        shutil.copy2(stdlib, work / "stdlib.lua")
        (work / "host.lua").write_text(HOST, encoding="utf-8")
        (work / "pathogen.lua").write_text(pathogen, encoding="utf-8")
        (work / "exposure.lua").write_text(exposure, encoding="utf-8")
        (work / "events.lua").write_text(events, encoding="utf-8")
        (work / "setup.lua").write_text(AFTER_STATE, encoding="utf-8")
        compiled = subprocess.run(
            [str(JDK / "javac.exe"), "-cp", str(jar), "-d", str(work), str(RUNNER)],
            cwd=work, capture_output=True, text=True, timeout=60)
        if compiled.returncode:
            return compiled
        return subprocess.run(
            [str(JDK / "java.exe"), "-cp", f"{jar}{os.pathsep}{work}", "LuaRun",
             str(work / "host.lua"), str(STATE), str(work / "setup.lua"),
             str(work / "pathogen.lua"), str(work / "exposure.lua"),
             str(work / "events.lua"), "--", PROBE],
            cwd=work, capture_output=True, text=True, timeout=60)


def main() -> int:
    required = [GAME / "projectzomboid.jar", GAME / "stdlib.lua",
                JDK / "java.exe", JDK / "javac.exe", RUNNER,
                STATE, PATHOGEN, EXPOSURE, EVENTS]
    if not all(path.is_file() for path in required):
        print("Border 173 SKIPPED: installed game VM, JDK, or paired ZAO branch absent")
        return 0
    pathogen = PATHOGEN.read_text(encoding="utf-8-sig")
    exposure = EXPOSURE.read_text(encoding="utf-8-sig")
    events = EVENTS.read_text(encoding="utf-8-sig")
    fixed = run(pathogen, exposure, events)
    if fixed.returncode or "VALUE intentional exposure holds" not in fixed.stdout:
        print("REFUSED: intentional exposure production path failed\n"
              + fixed.stdout + fixed.stderr)
        return 1
    controls = [
        ("feeding exclusion", exposure, "carrier:setTarget(nil)",
         "carrier:getTarget()"),
        ("contact duration", exposure,
         "< CONTACT_HOURS then", "< 0.0 then"),
        ("contact interruption", exposure,
         "and apart > BREAK_RANGE then", "and apart > 999.0 then"),
        ("exact-once receipt", pathogen,
         "if state.exposureTokens[token] then return state.exposureTokens[token] end",
         "if false then return state.exposureTokens[token] end"),
        ("live-action authorization", pathogen,
         "local action = store.exposures\n        and store.exposures[carrierId] or nil",
         "local action = actionResult"),
        ("source transaction ownership", events,
         "and not sourceOwnsActor(id) then", "then"),
    ]
    for name, original, old, new in controls:
        if original.count(old) != 1:
            print(f"REFUSED: {name} mutation seam changed")
            return 1
        psrc, esrc, vsrc = pathogen, exposure, events
        if original is pathogen:
            psrc = pathogen.replace(old, new, 1)
        elif original is events:
            vsrc = events.replace(old, new, 1)
        else:
            esrc = exposure.replace(old, new, 1)
        result = run(psrc, esrc, vsrc)
        if result.returncode == 0:
            print(f"REFUSED: {name} mutation survived\n" + result.stdout + result.stderr)
            return 1
    print("Border 173 PASS: proximity and forged receipts cannot roll; source-owned daily mutation is held; approach, contact time, interruption, non-feeding, exact-once result and one-way transfer execute in Kahlua; six controls fail")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
