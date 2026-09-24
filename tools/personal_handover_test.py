#!/usr/bin/env python3
"""Border 182 - personal handovers publish only native completion.

The production owner keeps scalar records in ModData and live engine handles
only in the current VM. This probe drives a small inventory/action seam in the
installed Kahlua runner: queue acceptance, native completion, interruption,
holder conflict, bilateral terms, partial debt, idempotent reconciliation,
reload-safe pending state, and future-schema refusal.
"""
import pathlib
import re
import shutil
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
HANDOVER = ROOT / "mod/42.20/media/lua/shared/SAO_Handover.lua"
NEEDS = ROOT / "mod/42.20/media/lua/client/SAO_Needs.lua"
EXCHANGE = ROOT / "mod/42.20/media/lua/client/SAO_Exchange.lua"
CONTROLLER = ROOT / "mod/42.20/media/lua/client/SAO_Controller.lua"
IDENTITY = ROOT / "mod/42.20/media/lua/shared/SAO_Identity.lua"
RUNNER = ROOT / "tools/luacheck/LuaRun.java"
OUT = ROOT / "java/out/luacheck"
PZ_DIR = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")


PRELUDE = r'''
SAO = { History = { ticks = function() return 100 end },
        Log = { line = function(_, _) __logs = (__logs or 0) + 1 end } }
_G.__stores, _G.__logs, _G.__voice = {}, 0, 0
_G.__trust, _G.__debt, _G.__settled = {}, {}, {}
_G.__queue = {}
ModData = { getOrCreate = function(key)
    __stores[key] = __stores[key] or {}; return __stores[key]
end }

local function pair(map, from, to)
    local key = tostring(from) .. ">" .. tostring(to)
    map[key] = (map[key] or 0)
    return key
end
SAO.Standing = {
    adjustTrust = function(from, to, delta)
        local key = pair(__trust, from, to)
        __trust[key] = __trust[key] + delta
    end,
    addDebt = function(creditor, debtor, amount)
        local key = pair(__debt, creditor, debtor)
        __debt[key] = __debt[key] + (amount or 1)
    end,
    settleDebt = function(creditor, debtor, amount)
        local key = pair(__settled, creditor, debtor)
        __settled[key] = __settled[key] + (amount or 1)
    end,
}
SAO.Voice = { onEvent = function() __voice = __voice + 1 end }
SAO.Needs = {
    queueVerified = function(action)
        if __queueReject then return false end
        __queue[action] = true
        __lastAction = action
        return true
    end,
}
ISTimedActionQueue = {
    add = function(action) __queue[action] = true; __lastAction = action end,
    hasAction = function(action) return __queue[action] == true end,
}

ISInventoryTransferAction = {}
function ISInventoryTransferAction:derive(_)
    local child = {}
    child.__index = child
    setmetatable(child, { __index = self })
    return child
end
function ISInventoryTransferAction.new(self, character, item, source, destination)
    local action = { character = character, item = item,
        sourceInventory = source, destinationInventory = destination }
    setmetatable(action, { __index = self })
    return action
end
function ISInventoryTransferAction.isValid(self)
    return self.character ~= nil and self.item ~= nil
        and self.sourceInventory ~= nil and self.destinationInventory ~= nil
end
function ISInventoryTransferAction.transferItem(self, item)
    item:setContainer(self.destinationInventory)
    return true
end
function ISInventoryTransferAction.stop(_) return true end

local function body(id, x, y, z)
    local inventory = {}
    local value = { id = id, x = x, y = y, z = z, inventory = inventory }
    function value:getModData() return { SAOPersonId = self.id } end
    function value:getInventory() return self.inventory end
    function value:getX() return self.x end
    function value:getY() return self.y end
    function value:getZ() return self.z end
    return value
end
local function item(id, fullType, container)
    local value = { id = id, fullType = fullType, container = container }
    function value:getID() return self.id end
    function value:getFullType() return self.fullType end
    function value:getContainer() return self.container end
    function value:setContainer(nextContainer) self.container = nextContainer end
    return value
end
_G.bodyA, _G.bodyB, _G.bodyC = body("a", 0, 0, 0), body("b", 1, 0, 0),
    body("c", 2, 0, 0)
_G.item1 = item(1, "Base.Apple", bodyA.inventory)
_G.item2 = item(2, "Base.Banana", bodyA.inventory)
_G.item3 = item(3, "Base.Pear", bodyA.inventory)
_G.item4 = item(4, "Base.CannedBeans", bodyA.inventory)
_G.item5 = item(5, "Base.Apple", bodyA.inventory)
_G.item6 = item(6, "Base.WaterBottle", bodyB.inventory)
_G.item7 = item(7, "Base.Bread", bodyA.inventory)
_G.item8 = item(8, "Base.Coffee", bodyA.inventory)
_G.item9 = item(9, "Base.WaterBottle", bodyB.inventory)
_G.item10 = item(10, "Base.JuiceBox", bodyB.inventory)
_G.item11 = item(11, "Base.Cigarettes", bodyC.inventory)
'''

PROBE = r'''
(function()
  local checks = {}
  local function check(name, value)
    checks[#checks + 1] = name .. "=" .. tostring(value and true or false)
  end
  local function scalarTree(value, depth)
    depth = depth or 0
    if depth > 8 then return false end
    local kind = type(value)
    if kind == "nil" or kind == "string" or kind == "number"
        or kind == "boolean" then return true end
    if kind ~= "table" then return false end
    for key, child in pairs(value) do
      if not scalarTree(key, depth + 1) or not scalarTree(child, depth + 1) then
        return false
      end
    end
    return true
  end
  local function trust(from, to) return __trust[tostring(from) .. ">" .. tostring(to)] or 0 end
  local function debt(from, to) return __debt[tostring(from) .. ">" .. tostring(to)] or 0 end

  local receipt = SAO.Handover.begin("a", bodyA, "b", bodyB, item1,
    "food", { effect = { trust = { { from = "b", to = "a", delta = 0.2 } },
      voice = { actor = "a", kind = "share", at = 100 }, log = "complete" } })
  check("queued_without_effect", receipt and receipt.status == "pending"
    and trust("b", "a") == 0 and __voice == 0 and debt("a", "b") == 0)
  check("durable_record_is_scalar", scalarTree(ModData.getOrCreate(
    "SurvivorAwareness_Handovers").records[receipt.id]))
  local action = SAO.Handover._runtime[receipt.id].action
  action:transferItem(item1)
  check("native_completion_publishes_once", SAO.Handover.result(receipt.id)
    .status == "completed" and trust("b", "a") == 0.2 and __voice == 1)
  SAO.Handover.reconcile()
  check("reconcile_is_idempotent", trust("b", "a") == 0.2 and __voice == 1)

  __queueReject = true
  local refused = SAO.Handover.begin("a", bodyA, "b", bodyB, item2,
    "food", { effect = { trust = { { from = "b", to = "a", delta = 1 } } } })
  __queueReject = false
  check("queue_refusal_has_no_effect", refused == nil and trust("b", "a") == 0.2)

  local interrupted = SAO.Handover.begin("a", bodyA, "b", bodyB, item3,
    "food", { effect = { trust = { { from = "b", to = "a", delta = 1 } } } })
  SAO.Handover._runtime[interrupted.id].action:stop()
  check("interruption_has_no_effect", SAO.Handover.result(interrupted.id)
    .status == "interrupted" and trust("b", "a") == 0.2)

  local unacceptedTerms = SAO.Handover.proposeTerms("a", "b", "food", "drink",
    nil, 100)
  local unacceptedFirst = SAO.Handover.begin("a", bodyA, "b", bodyB, item2,
    "food", { termsId = unacceptedTerms, leg = "first" })
  local earlyAccepted = SAO.Handover.acceptTerms(unacceptedTerms, 100)
  __queueReject = true
  local unacceptedSecond = SAO.Handover.begin("b", bodyB, "a", bodyA, item10,
    "drink", { termsId = unacceptedTerms, leg = "second" })
  __queueReject = false
  SAO.Handover.cancelTerms(unacceptedTerms, "second-leg-refused")
  check("unaccepted_proposal_has_no_debt", unacceptedFirst and not earlyAccepted
    and unacceptedSecond == nil and SAO.Handover.result(unacceptedFirst.id)
      .status == "released" and debt("a", "b") == 0)

  local partialTerms = SAO.Handover.proposeTerms("a", "b", "food", "drink",
    { trust = { { from = "a", to = "b", delta = 0.5 } } }, 100)
  local partial = SAO.Handover.begin("a", bodyA, "b", bodyB, item4, "food",
    { termsId = partialTerms, leg = "first" })
  local partialSecond = SAO.Handover.begin("b", bodyB, "a", bodyA, item9,
    "drink", { termsId = partialTerms, leg = "second" })
  local partialAccepted = SAO.Handover.acceptTerms(partialTerms, 100)
  SAO.Handover._runtime[partialSecond.id].action:stop()
  SAO.Handover._runtime[partial.id].action:transferItem(item4)
  check("partial_term_creates_debt_after_completion",
    partialAccepted and SAO.Handover.result(partial.id).status == "completed"
    and debt("a", "b") == 1 and SAO.Handover.result(partialTerms) == nil)
  local partialRecord = ModData.getOrCreate("SurvivorAwareness_Handovers").terms[partialTerms]
  check("partial_term_is_terminal", partialRecord.status == "partial"
    and trust("a", "b") == 0)

  local fullTerms = SAO.Handover.proposeTerms("a", "b", "food", "drink",
    { trust = {
        { from = "a", to = "b", delta = 0.05 },
        { from = "b", to = "a", delta = 0.05 },
      }, voice = { actor = "a", kind = "barter", at = 100 }, log = "trade" }, 100)
  local first = SAO.Handover.begin("a", bodyA, "b", bodyB, item5, "food",
    { termsId = fullTerms, leg = "first" })
  local second = SAO.Handover.begin("b", bodyB, "a", bodyA, item6, "drink",
    { termsId = fullTerms, leg = "second" })
  local firstAction = SAO.Handover._runtime[first.id].action
  local secondAction = SAO.Handover._runtime[second.id].action
  local fullAccepted = SAO.Handover.acceptTerms(fullTerms, 100)
  firstAction:transferItem(item5)
  check("full_term_waits_for_both_legs", fullAccepted
    and trust("a", "b") == 0.0
    and trust("b", "a") == 0.2)
  secondAction:transferItem(item6)
  check("full_term_publishes_after_both", ModData.getOrCreate(
    "SurvivorAwareness_Handovers").terms[fullTerms].status == "completed"
    and trust("a", "b") == 0.05 and trust("b", "a") == 0.25
    and debt("a", "b") == 1)
  SAO.Handover.reconcile()
  check("full_term_reconcile_is_idempotent", trust("a", "b") == 0.05
    and trust("b", "a") == 0.25)

  local reloaded = SAO.Handover.begin("a", bodyA, "b", bodyB, item7, "food",
    { effect = { trust = { { from = "b", to = "a", delta = 1 } } } })
  SAO.Handover._runtime[reloaded.id] = nil
  SAO.Handover.reconcile(true)
  check("reload_pending_withholds_credit", SAO.Handover.result(reloaded.id)
    .status == "pending" and trust("b", "a") == 0.25)
  local duplicate = SAO.Handover.begin("a", bodyA, "b", bodyB, item7, "food",
    { effect = { trust = { { from = "b", to = "a", delta = 1 } } } })
  check("reload_pending_blocks_duplicate", duplicate == nil
    and trust("b", "a") == 0.25)

  local conflict = SAO.Handover.begin("a", bodyA, "b", bodyB, item8, "food",
    { effect = { trust = { { from = "b", to = "a", delta = 1 } } } })
  local conflictAction = SAO.Handover._runtime[conflict.id].action
  item8:setContainer(bodyC.inventory)
  __queue[conflictAction] = false
  SAO.Handover.reconcile(true)
  check("holder_conflict_withholds_credit", SAO.Handover.result(conflict.id)
    .status == "conflict" and trust("b", "a") == 0.25)

  local deathPending = SAO.Handover.begin("c", bodyC, "b", bodyB, item11,
    "smoke", { effect = { trust = { { from = "b", to = "c", delta = 1 } } } })
  local forgotten = SAO.Handover.forgetPerson("c")
  check("death_releases_live_handover", forgotten == 1 and deathPending
    and SAO.Handover.result(deathPending.id).status == "released"
    and SAO.Handover._runtime[deathPending.id] == nil
    and trust("b", "c") == 0)

  local badTerms = SAO.Handover.proposeTerms("a", "a", "food", "drink", nil, 100)
  check("same_actor_terms_refused", badTerms == nil)
  ModData.getOrCreate("SurvivorAwareness_Handovers").schema = 3
  local future = SAO.Handover.proposeTerms("a", "b", "food", "drink", nil, 100)
  check("future_schema_refused", future == nil)
  return table.concat(checks, "|")
end)()
'''

EXPECTED = {
    "queued_without_effect", "durable_record_is_scalar",
    "native_completion_publishes_once",
    "reconcile_is_idempotent", "queue_refusal_has_no_effect",
    "interruption_has_no_effect", "partial_term_creates_debt_after_completion",
    "unaccepted_proposal_has_no_debt", "partial_term_is_terminal",
    "full_term_waits_for_both_legs",
    "full_term_publishes_after_both", "full_term_reconcile_is_idempotent",
    "reload_pending_withholds_credit", "reload_pending_blocks_duplicate",
    "holder_conflict_withholds_credit",
    "death_releases_live_handover",
    "same_actor_terms_refused", "future_schema_refused",
}


def run_probe(handover_path=HANDOVER):
    OUT.mkdir(parents=True, exist_ok=True)
    compiled = subprocess.run(
        [str(JDK / "javac.exe"), "-cp", str(PZ), "-d", str(OUT), str(RUNNER)],
        capture_output=True, text=True, timeout=300)
    if compiled.returncode:
        return None, compiled.stderr or compiled.stdout
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(STDLIB, work / "stdlib.lua")
        for cls in OUT.glob("LuaRun*.class"):
            shutil.copy2(cls, work / cls.name)
        prelude = work / "prelude.lua"
        probe = work / "probe.lua"
        prelude.write_text(PRELUDE, encoding="utf-8")
        probe.write_text("__result = " + PROBE, encoding="utf-8")
        done = subprocess.run(
            [str(JDK / "java.exe"), "-cp", f"{PZ};.", "LuaRun",
             str(prelude), str(handover_path), str(probe), "--", "__result"],
            cwd=work, capture_output=True, text=True, timeout=300)
    output = (done.stdout or "") + (done.stderr or "")
    lines = (done.stdout or "").strip().splitlines()
    value = lines[-1][6:] if lines and lines[-1].startswith("VALUE ") else None
    return value, output


def mutation_control():
    source = HANDOVER.read_text(encoding="utf-8")
    needle = """    runtime[id].action = action
    if t and leg then"""
    mutation = """    runtime[id].action = action
    if not termsId then applyRecordEffect(rec) end
    if t and leg then"""
    if source.count(needle) != 1:
        return False, "queue-credit mutation anchor absent"
    with tempfile.TemporaryDirectory() as tmp:
        broken = pathlib.Path(tmp) / "SAO_Handover_broken.lua"
        broken.write_text(source.replace(needle, mutation), encoding="utf-8")
        value, detail = run_probe(broken)
    verdicts = dict(re.findall(r"([a-z0-9_]+)=(true|false)", value or ""))
    if verdicts.get("queued_without_effect") != "false":
        return False, "queue-credit mutation was not named: " + detail[-500:]
    return True, "queue-created social credit rejected as queued_without_effect"


def static_contract():
    handover = HANDOVER.read_text(encoding="utf-8")
    needs = NEEDS.read_text(encoding="utf-8")
    exchange = EXCHANGE.read_text(encoding="utf-8")
    controller = CONTROLLER.read_text(encoding="utf-8")
    identity = IDENTITY.read_text(encoding="utf-8")
    required = [
        "function H.begin", "function H.reconcile", "destinationInventory",
        "function H.proposeTerms", "function H.acceptTerms",
        "function H.cancelTermLeg", "function H.forgetPerson",
        "function transferClass:transferItem",
    ]
    if any(anchor not in handover for anchor in required):
        return False, "handover owner anchors absent"
    for name in ("shareFoodWith", "shareDrinkWith", "shareSmokeWith",
                 "shareAllWith", "shareDisinfectantWith", "passReadingTo"):
        start = needs.find("function N." + name)
        if start < 0:
            return False, "needs function absent: " + name
        end = needs.find("\nend", start)
        body = needs[start:end if end >= 0 else len(needs)]
        if "SAO.Handover.begin" not in body:
            return False, "needs function bypasses Handover: " + name
    if "ISTimedActionQueue.add(ISInventoryTransferAction:new" in needs:
        return False, "Needs retains a raw person-to-person transfer"
    if "SAO.Standing.addDebt" in exchange:
        return False, "exchange creates debt before native completion"
    if ("SAO.Handover.proposeTerms" not in exchange
            or "SAO.Handover.acceptTerms" not in exchange):
        return False, "exchange has no bilateral terms"
    yield_start = controller.find("-- [C118] The robbed hand")
    yield_end = controller.find("if threat.dist <= fleeAt", yield_start)
    if yield_start < 0 or yield_end < 0:
        return False, "yield seam absent"
    yield_body = controller[yield_start:yield_end]
    if "SAO.Handover.begin" not in yield_body:
        return False, "yield bypasses Handover"
    if "ISInventoryTransferAction:new" in yield_body:
        return False, "yield still queues a raw inventory transfer"
    reading_start = controller.find("if passedTo and SAO.Needs.passReadingTo")
    reading_end = controller.find("elseif idleRec and idleRec.keepsake", reading_start)
    if reading_start < 0 or reading_end < 0:
        return False, "reading handover seam absent"
    reading_body = controller[reading_start:reading_end]
    if ("kind = \"passItOn\"" not in reading_body
            or "SAO.Voice.onEvent" in reading_body):
        return False, "reading credit precedes Handover completion"
    if "SAO.Handover.forgetPerson" not in identity:
        return False, "death does not release live Handover state"
    return True, "handover owner and personal call sites are wired"


def main():
    print("=" * 74)
    print("PERSONAL HANDOVERS PUBLISH ONLY NATIVE COMPLETION")
    print("=" * 74)
    required = [HANDOVER, RUNNER]
    missing = [path for path in required if not path.is_file()]
    if missing:
        print("  FAULT: repository input absent: " + ", ".join(
            str(path.relative_to(ROOT)) for path in missing))
        return 1
    installed = [PZ, STDLIB, JDK / "java.exe", JDK / "javac.exe"]
    if not all(path.is_file() for path in installed):
        print("Border 182 SKIPPED: installed game VM or JDK absent")
        return 0
    static_ok, static_detail = static_contract()
    print("  static contract: " + ("PASS" if static_ok else "FAIL")
          + " (" + static_detail + ")")
    value, detail = run_probe()
    found, failed = set(), []
    if value:
        for name, raw in re.findall(r"([a-z0-9_]+)=(true|false)", value):
            found.add(name)
            if raw != "true":
                failed.append(name)
    control_ok, control_detail = mutation_control()
    print("  mutation control: " + ("PASS" if control_ok else "FAIL")
          + " (" + control_detail + ")")
    if not static_ok or not control_ok or found != EXPECTED or failed:
        print("  FAULT: missing=" + repr(sorted(EXPECTED - found))
              + " failed=" + repr(failed) + " value=" + repr(value))
        print("  " + detail[-2000:].replace("\n", " "))
        return 1
    print("  182) queued, interrupted, conflicted, reloaded, and partial "
          "personal handovers withhold social credit until native proof")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
