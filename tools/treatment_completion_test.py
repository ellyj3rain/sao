#!/usr/bin/env python3
"""Border 183 - open-wound treatment publishes only a native result.

The production owner is executed in the installed Kahlua VM against a small
ISApplyBandage seam. The probe distinguishes queue admission, interruption,
native refusal, an ineffective dirty dressing, effective completion, exact
patient binding, saved-result consumption, and unavailable live work after a
reload. Body-unload cases bind the owner's real action handle to distinct Lua
and native queues, exercise active and unstarted cancellation, and retain
ownership when either queue or cancellation result is unknown.
"""
import pathlib
import re
import shutil
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
TREATMENT = ROOT / "mod/42.20/media/lua/shared/SAO_Treatment.lua"
NEEDS = ROOT / "mod/42.20/media/lua/client/SAO_Needs.lua"
CONTROLLER = ROOT / "mod/42.20/media/lua/client/SAO_Controller.lua"
HARNESS = ROOT / "mod/42.20/media/lua/client/SAO_Harness.lua"
IDENTITY = ROOT / "mod/42.20/media/lua/shared/SAO_Identity.lua"
RUNNER = ROOT / "tools/luacheck/LuaRun.java"
OUT = ROOT / "java/out/luacheck"
PZ_DIR = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")


PRELUDE = r'''
SAO = { History = { ticks = function() return 100 end } }
_G.__stores, _G.__queue, _G.__queueReject = {}, {}, false
_G.__trust, _G.__voice, _G.__customXP, _G.__nativeXP = {}, 0, 0, 0
_G.__logs, _G.__gesture = 0, 0
_G.__timedQueues, _G.__cancelMode = {}, nil
_G.__clearCalls, _G.__stopCalls, _G.__cancelCalls = 0, 0, 0
ModData = { getOrCreate = function(key)
    __stores[key] = __stores[key] or {}; return __stores[key]
end }
SAO.Log = { line = function(_, _) __logs = __logs + 1 end }
local function pair(from, to) return tostring(from) .. ">" .. tostring(to) end
SAO.Standing = {
    adjustTrust = function(from, to, delta)
        local key = pair(from, to)
        __trust[key] = (__trust[key] or 0) + delta
    end,
    playerKey = function(body)
        local name = body and body.getUsername and body:getUsername() or nil
        return name and ("player:" .. tostring(name)) or nil
    end,
    isPlayerKey = function(key)
        return key and string.sub(tostring(key), 1, 7) == "player:"
    end,
}
SAO.Voice = { onEvent = function() __voice = __voice + 1 end }
SAO.Gesture = { cpr = function() __gesture = __gesture + 1 end }
SAOJavaBridge = { grantXP = function(_, _, perk, amount)
    if perk == "Doctor" then __customXP = __customXP + amount end
end }
SAO.Controller = { agents = { b = {} } }

local function list(values)
    return { size = function() return #values end,
        get = function(_, i) return values[i + 1] end }
end
local function inventory()
    local value = {}
    function value:contains(item) return item.container == self end
    function value:Remove(item) if item.container == self then item.container = nil end end
    return value
end
local function part(index)
    local value = { index = index, bleedingValue = true,
        bandagedValue = false, life = 0 }
    function value:getIndex() return self.index end
    function value:bleeding() return self.bleedingValue end
    function value:bandaged() return self.bandagedValue end
    function value:getBandageLife() return self.life end
    function value:setBandaged(nextValue, life)
        self.bandagedValue, self.life = nextValue, life or 0
    end
    return value
end
local function body(id, x, username)
    local value = { id = id, x = x, y = 0, z = 0, inventory = inventory(),
        parts = {}, username = username, knockedDown = false, health = 1 }
    function value:getModData()
        return self.id and { SAOPersonId = self.id } or {}
    end
    function value:getUsername() return self.username end
    function value:getInventory() return self.inventory end
    function value:getX() return self.x end
    function value:getY() return self.y end
    function value:getZ() return self.z end
    function value:getBodyDamage()
        local owner = self
        return { getBodyParts = function() return list(owner.parts) end }
    end
    function value:isKnockedDown() return self.knockedDown end
    function value:getHealth() return self.health end
    function value:getCharacterActions()
        if __cancelMode == "native-unknown" then error("native queue unavailable") end
        return list(self.nativeActions or {})
    end
    return value
end
local function item(id, dirty, holder)
    local value = { id = id, dirty = dirty, container = holder,
        fullType = dirty and "Base.DirtyBandage" or "Base.Bandage" }
    function value:getID() return self.id end
    function value:getFullType() return self.fullType end
    function value:getType() return self.dirty and "DirtyBandage" or "Bandage" end
    function value:getContainer() return self.container end
    return value
end
local function reset(partValue)
    partValue.bleedingValue, partValue.bandagedValue, partValue.life = true, false, 0
end

_G.bodyA, _G.bodyB = body("a", 0, nil), body("b", 1, nil)
_G.bodyP = body(nil, 0, "operator")
_G.partA, _G.partB = part(1), part(2)
_G.partP = part(3)
bodyA.parts, bodyB.parts, bodyP.parts = { partA }, { partB }, { partP }
_G.item = item
_G.reset = reset
_G.makeBody = body
_G.__bodies = { a = bodyA, b = bodyB, ["player:operator"] = bodyP }
SAO.Body = { active = __bodies, foreign = {}, get = function(id)
    if __hideBodies then return nil end
    return __bodies[tostring(id)]
end }
function getSpecificPlayer(_) return bodyP end
function instanceof(value, kind)
    return kind == "LuaTimedActionNew" and value.getTable ~= nil
end

ISApplyBandage = {}
function ISApplyBandage:derive(_)
    local child = {}; child.__index = child
    setmetatable(child, { __index = self }); return child
end
function ISApplyBandage.new(self, character, patient, dressing, wound, doIt)
    local action = { character = character, otherPlayer = patient,
        item = dressing, bodyPart = wound, doIt = doIt }
    setmetatable(action, { __index = self }); return action
end
function ISApplyBandage.complete(self)
    if self.nativeRefuse then return false end
    local life = self.item.dirty and 0 or 5
    self.bodyPart:setBandaged(true, life)
    self.character:getInventory():Remove(self.item)
    if life > 0 then __nativeXP = __nativeXP + 1 end
    return true
end
function ISApplyBandage.stop(_)
    __stopCalls = __stopCalls + 1
    if __cancelMode == "stop-refused" then return false end
    return true
end
function ISApplyBandage.forceCancel(_)
    __cancelCalls = __cancelCalls + 1
    if __cancelMode == "cancel-refused" then return false end
    return true
end
function ISApplyBandage.isStarted(self)
    return self.action and self.action.started
end

ISTimedActionQueue = {
    queues = __timedQueues,
    add = function(action)
        if __queueReject then return end
        __queue[action] = true; __lastAction = action
    end,
    hasAction = function(action)
        if __cancelMode == "lua-unknown" then return nil end
        return __queue[action] == true
    end,
    getTimedActionQueue = function(character) return __timedQueues[character] end,
    clear = function(character)
        __clearCalls = __clearCalls + 1
        if __cancelMode == "clear-error" then error("native clear refused") end
        local owner = __timedQueues[character]
        if owner.current then owner.current:stop() end
        if __cancelMode == "clear-after-stop" then error("clear incomplete") end
        for _, action in ipairs(owner.queue) do __queue[action] = nil end
        owner.queue = {}
        if __cancelMode ~= "stale-current" then owner.current = nil end
        if __cancelMode ~= "native-retained" then character.nativeActions = {} end
        return owner
    end,
}
SAO.Needs = { queueVerified = function(action)
    if __queueReject then return false end
    __queue[action] = true; __lastAction = action; return true
end }
'''


PROBE = r'''
(function()
  local checks = {}
  local function check(name, value)
    checks[#checks + 1] = name .. "=" .. tostring(value and true or false)
  end
  local function trust(from, to)
    return __trust[tostring(from) .. ">" .. tostring(to)] or 0
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
  local function aidEffect(actor, patient, at)
    return { effect = {
      trust = { { from = patient, to = actor, delta = 0.15 },
        { from = actor, to = patient, delta = 0.03 } },
      voice = { actor = actor, kind = "aid", at = at },
      aid = { actor = actor, recipient = patient, at = at, xp = 1.5 },
      gesture = "cpr-if-critical", log = actor .. " aids " .. patient,
    } }
  end

  bodyB.knockedDown = true
  local item1 = item(1, false, bodyA.inventory)
  local receipt = SAO.Treatment.begin("a", bodyA, "b", bodyB, item1,
    partB, aidEffect("a", "b", 100))
  check("queued_without_effect", receipt and receipt.status == "pending"
    and trust("b", "a") == 0 and trust("a", "b") == 0
    and __voice == 0 and __customXP == 0
    and SAO.Controller.agents.b.aidedAt == nil)
  check("patient_and_part_are_durable", receipt and receipt.patientId == "b"
    and receipt.actorId == "a" and receipt.bodyPartIndex == 2
    and scalarTree(receipt))
  local queueLogs = __logs
  SAO.Treatment._runtime[receipt.id].action:complete()
  check("effective_completion_publishes_once",
    SAO.Treatment.result(receipt.id).status == "completed"
    and partB:bandaged() and partB:getBandageLife() == 5
    and item1:getContainer() == nil and trust("b", "a") == 0.15
    and trust("a", "b") == 0.03 and __voice == 1
    and __customXP == 1.5 and __nativeXP == 1
    and SAO.Controller.agents.b.aidedAt == 100
    and __gesture == 1 and __logs == queueLogs + 1)
  SAO.Treatment.reconcile(true)
  check("completed_result_is_idempotent", trust("b", "a") == 0.15
    and __voice == 1 and __customXP == 1.5 and __gesture == 1)

  reset(partB); bodyB.knockedDown = false
  local item2 = item(2, false, bodyA.inventory)
  local interrupted = SAO.Treatment.begin("a", bodyA, "b", bodyB, item2,
    partB, aidEffect("a", "b", 110))
  SAO.Treatment._runtime[interrupted.id].action:stop()
  check("interruption_withholds_consequences",
    SAO.Treatment.result(interrupted.id).status == "interrupted"
    and item2:getContainer() == bodyA.inventory
    and trust("b", "a") == 0.15 and __voice == 1
    and __customXP == 1.5)

  reset(partB)
  local item3 = item(3, true, bodyA.inventory)
  local ineffective = SAO.Treatment.begin("a", bodyA, "b", bodyB, item3,
    partB, aidEffect("a", "b", 120))
  SAO.Treatment._runtime[ineffective.id].action:complete()
  check("ineffective_dressing_is_not_care",
    SAO.Treatment.result(ineffective.id).status == "ineffective"
    and partB:bandaged() and partB:getBandageLife() == 0
    and trust("b", "a") == 0.15 and __voice == 1
    and __customXP == 1.5 and __nativeXP == 1)

  reset(partB)
  local item4 = item(4, false, bodyA.inventory)
  local refused = SAO.Treatment.begin("a", bodyA, "b", bodyB, item4,
    partB, aidEffect("a", "b", 130))
  SAO.Treatment._runtime[refused.id].action.nativeRefuse = true
  SAO.Treatment._runtime[refused.id].action:complete()
  check("native_refusal_is_ineffective",
    SAO.Treatment.result(refused.id).status == "ineffective"
    and item4:getContainer() == bodyA.inventory and not partB:bandaged()
    and trust("b", "a") == 0.15 and __voice == 1)

  reset(partB)
  local item5 = item(5, false, bodyA.inventory)
  local changed = SAO.Treatment.begin("a", bodyA, "b", bodyB, item5,
    partB, aidEffect("a", "b", 140))
  bodyB.id = "somebody-else"
  SAO.Treatment._runtime[changed.id].action:complete()
  bodyB.id = "b"
  check("patient_change_refuses_mutation",
    SAO.Treatment.result(changed.id).status == "ineffective"
    and item5:getContainer() == bodyA.inventory and not partB:bandaged()
    and trust("b", "a") == 0.15)

  reset(partB)
  local item6 = item(6, false, bodyA.inventory)
  local wrongPatient = SAO.Treatment.begin("a", bodyA, "wrong", bodyB,
    item6, partB, aidEffect("a", "wrong", 150))
  check("patient_identity_is_required", wrongPatient == nil
    and item6:getContainer() == bodyA.inventory)

  reset(partA)
  local selfItem = item(7, false, bodyA.inventory)
  local selfCare = SAO.Treatment.begin("a", bodyA, "a", bodyA, selfItem,
    partA, { effect = { log = "self care" } })
  SAO.Treatment._runtime[selfCare.id].action:complete()
  check("self_treatment_uses_same_result", selfCare.status == "completed"
    and partA:bandaged() and trust("b", "a") == 0.15
    and __voice == 1 and __customXP == 1.5)

  reset(partB)
  local item8 = item(8, false, bodyA.inventory)
  local unknown = SAO.Treatment.begin("a", bodyA, "b", bodyB, item8,
    partB, aidEffect("a", "b", 160))
  SAO.Treatment._runtime[unknown.id] = nil
  SAO.Treatment.reconcile(true)
  local duplicate = SAO.Treatment.begin("a", bodyA, "b", bodyB, item8,
    partB, aidEffect("a", "b", 160))
  check("reload_unknown_withholds_and_reserves", unknown.status == "pending"
    and duplicate == nil and trust("b", "a") == 0.15 and __voice == 1)
  local released = SAO.Treatment.releasePerson("b", "body-unloaded")
  check("participant_release_drops_live_work", released == 1
    and unknown.status == "released")

  reset(partB)
  __queueReject = true
  local item9 = item(9, false, bodyA.inventory)
  local queueRefused = SAO.Treatment.begin("a", bodyA, "b", bodyB, item9,
    partB, aidEffect("a", "b", 170))
  __queueReject = false
  check("queue_refusal_withholds_consequences", queueRefused == nil
    and trust("b", "a") == 0.15 and __voice == 1
    and item9:getContainer() == bodyA.inventory)

  reset(partB)
  local item10 = item(10, false, bodyA.inventory)
  local saved = SAO.Treatment.begin("a", bodyA, "b", bodyB, item10,
    partB, aidEffect("a", "b", 180))
  saved.status, saved.completedAt = "completed", 180
  SAO.Treatment._runtime[saved.id] = nil
  __bodies.a = nil
  SAO.Treatment.rebindWorld()
  SAO.Treatment.reconcile(true)
  check("reload_waits_for_skill_body", saved.effectApplied == false
    and trust("b", "a") == 0.30 and __voice == 2
    and __customXP == 1.5)
  __bodies.a = bodyA
  SAO.Treatment.reconcile(true)
  local afterReloadTrust, afterReloadVoice = trust("b", "a"), __voice
  SAO.Treatment.rebindWorld()
  SAO.Treatment.reconcile(true)
  check("saved_completion_consumes_once", saved.effectApplied == true
    and afterReloadTrust == 0.30 and afterReloadVoice == 2
    and trust("b", "a") == afterReloadTrust and __voice == afterReloadVoice
    and __customXP == 3.0)

  reset(partB)
  local playerItem = item(11, false, bodyP.inventory)
  local playerCare = SAO.Treatment.begin("player:operator", bodyP,
    "b", bodyB, playerItem, partB,
    { effect = { trust = { { from = "b", to = "player:operator",
        delta = 0.15 } }, log = "player treats b" } })
  SAO.Treatment._runtime[playerCare.id].action:complete()
  check("player_identity_uses_same_owner", playerCare.status == "completed"
    and trust("b", "player:operator") == 0.15)

  -- Each case uses the action produced by the real Treatment.begin owner,
  -- with separate Lua membership and the exact native handle held by its actor.
  local nextUnloadItem = 30
  local function unloadFixture(active, mode)
    reset(partB)
    __cancelMode = nil
    __clearCalls, __stopCalls, __cancelCalls = 0, 0, 0
    nextUnloadItem = nextUnloadItem + 1
    local dressing = item(nextUnloadItem, false, bodyA.inventory)
    local rec = SAO.Treatment.begin("a", bodyA, "b", bodyB, dressing,
      partB, aidEffect("a", "b", 185))
    local live = SAO.Treatment._runtime[rec.id]
    local action = live.action
    local other = { character = bodyA, action = { started = true },
      stop = function() error("unrelated action stopped") end }
    action.action = active and { started = true, getTable = function() return action end } or nil
    local owner = { character = bodyA, current = active and action or other,
      queue = active and { action } or { other, action } }
    function owner:removeFromQueue(removing)
      if __cancelMode == "remove-error" then error("queue removal refused") end
      for i, value in ipairs(self.queue) do
        if value == removing then table.remove(self.queue, i); break end
      end
      __queue[removing] = nil
    end
    __timedQueues[bodyA] = owner
    __queue[action], __queue[other] = true, not active
    bodyA.nativeActions = { active and action.action or other.action }
    __cancelMode = mode
    return rec, live, owner, other, dressing
  end
  local function finishFixture(rec)
    -- Keep later verdicts observable even when a production mutation leaves
    -- this case pending. This is fixture teardown, never an unload witness.
    local live = SAO.Treatment._runtime[rec.id]
    if live then live.unloadBlocked, live.unloadInterrupt = nil, nil end
    SAO.Treatment.releasePerson("b", "fixture-reset")
  end
  local oldTrust, oldVoice, oldXP, oldNative =
    trust("b", "a"), __voice, __customXP, __nativeXP
  local active, activeLive, activeOwner, _, activeItem = unloadFixture(true)
  local stopped = SAO.Treatment.interruptForBodyUnload("b", "region-unloaded")
  check("unload_current_stops_native_and_lua", stopped == true
    and active.status == "interrupted" and active.reason == "region-unloaded"
    and __clearCalls == 1 and __stopCalls == 1
    and #bodyA.nativeActions == 0 and #activeOwner.queue == 0
    and SAO.Treatment._runtime[active.id] == nil)
  activeLive.action:complete()
  check("unload_withholds_all_care", activeItem.container == bodyA.inventory
    and not partB:bandaged() and trust("b", "a") == oldTrust
    and __voice == oldVoice and __customXP == oldXP and __nativeXP == oldNative)
  finishFixture(active)

  local waiting, waitingLive, waitingOwner, other, waitingItem = unloadFixture(false)
  local cancelled = SAO.Treatment.interruptForBodyUnload("b", "region-unloaded")
  check("unload_queued_preserves_other_actions", cancelled == true
    and waiting.status == "interrupted" and __clearCalls == 0
    and __cancelCalls == 1 and #waitingOwner.queue == 1
    and waitingOwner.queue[1] == other and waitingOwner.current == other
    and __queue[other] == true and __queue[waitingLive.action] == nil
    and bodyA.nativeActions[1] == other.action
    and waitingItem.container == bodyA.inventory)
  finishFixture(waiting)

  local retained, retainedLive, retainedOwner = unloadFixture(true)
  __queue[retainedLive.action] = nil
  retainedOwner.queue, retainedOwner.current = {}, nil
  check("unload_native_presence_outlives_lua", SAO.Treatment.interruptForBodyUnload("b") == true
    and __clearCalls == 1 and #bodyA.nativeActions == 0
    and retained.status == "interrupted")
  finishFixture(retained)

  local stale, staleLive, staleOwner = unloadFixture(true, "stale-current")
  check("unload_uses_membership_not_stale_pointer",
    SAO.Treatment.interruptForBodyUnload("b") == true
    and staleOwner.current == staleLive.action and #staleOwner.queue == 0
    and #bodyA.nativeActions == 0 and stale.status == "interrupted")
  finishFixture(stale)

  local failuresHeld, retriesStopped = true, true
  for _, mode in ipairs({ "lua-unknown", "native-unknown", "clear-error",
      "clear-after-stop", "native-retained", "stop-refused",
      "cancel-refused", "remove-error", "missing-runtime" }) do
    local activeCase = mode ~= "cancel-refused" and mode ~= "remove-error"
    local rec, live = unloadFixture(activeCase, mode)
    if mode == "missing-runtime" then SAO.Treatment._runtime[rec.id] = nil end
    local interrupted = SAO.Treatment.interruptForBodyUnload("b", "region-unloaded")
    SAO.Treatment.reconcile(true)
    failuresHeld = failuresHeld and interrupted == false and rec.status == "pending"
      and (mode == "missing-runtime" or SAO.Treatment._runtime[rec.id] == live)
      and not partB:bandaged() and __customXP == oldXP and __nativeXP == oldNative
      and trust("b", "a") == oldTrust and __voice == oldVoice
    __cancelMode = nil
    if mode == "missing-runtime" then SAO.Treatment._runtime[rec.id] = live end
    retriesStopped = retriesStopped
      and SAO.Treatment.interruptForBodyUnload("b", "region-unloaded") == true
      and rec.status == "interrupted" and SAO.Treatment._runtime[rec.id] == nil
    finishFixture(rec)
  end
  check("unload_failure_retains_ownership", failuresHeld)
  check("unload_retry_closes_only_after_cancellation", retriesStopped)
  check("unload_no_owned_work_is_safe", SAO.Treatment.interruptForBodyUnload("b") == true)

  local missing, missingLive, missingOwner = unloadFixture(true)
  SAO.Treatment._runtime[missing.id] = nil
  missingOwner.queue, missingOwner.current = {}, nil
  __queue[missingLive.action], bodyA.nativeActions = nil, {}
  check("same_world_missing_handle_remains_unknown",
    SAO.Treatment.interruptForBodyUnload("b") == false and missing.status == "pending")
  SAO.Treatment._runtime[missing.id] = missingLive
  SAO.Treatment.interruptForBodyUnload("b")
  finishFixture(missing)

  local restored, restoredLive, restoredOwner = unloadFixture(true)
  SAO.Treatment.rebindWorld()
  __hideBodies = true
  local retainedLua = SAO.Treatment.interruptForBodyUnload("b") == false
    and restored.status == "pending" and SAO.Treatment._runtime[restored.id] == nil
  restoredOwner.queue, restoredOwner.current = {}, nil
  __queue[restoredLive.action] = nil
  local retainedNative = SAO.Treatment.interruptForBodyUnload("b") == false
    and restored.status == "pending"
  __hideBodies = nil
  check("reload_pending_checks_actual_actor_queues", retainedLua and retainedNative)

  -- A new world represents new bodies; no action is fabricated from the saved
  -- scalar receipt. The current actor's real queues witness its absence.
  bodyA, bodyB = makeBody("a", 0), makeBody("b", 1)
  bodyA.parts, bodyB.parts = { partA }, { partB }
  __bodies.a, __bodies.b = bodyA, bodyB
  __timedQueues, __queue = {}, {}
  ISTimedActionQueue.queues = __timedQueues
  check("reload_pending_unload_is_interrupted_without_credit",
    SAO.Treatment.interruptForBodyUnload("b", "new-world-unload") == true
    and restored.status == "interrupted" and restored.reason == "new-world-unload"
    and SAO.Treatment._runtime[restored.id] == nil
    and trust("b", "a") == oldTrust and __voice == oldVoice
    and __customXP == oldXP and __nativeXP == oldNative and not partB:bandaged())

  local dormant = unloadFixture(true)
  SAO.Treatment.rebindWorld()
  __bodies.a = nil
  __timedQueues, __queue = {}, {}
  ISTimedActionQueue.queues = __timedQueues
  check("reload_pending_without_actor_representation_is_inert",
    SAO.Treatment.interruptForBodyUnload("b") == true
    and dormant.status == "interrupted" and __customXP == oldXP
    and __nativeXP == oldNative and trust("b", "a") == oldTrust)
  __bodies.a = bodyA

  ModData.getOrCreate("SurvivorAwareness_Treatments").schema = 2
  SAO.Treatment.rebindWorld()
  reset(partB)
  local item12 = item(12, false, bodyA.inventory)
  local future = SAO.Treatment.begin("a", bodyA, "b", bodyB, item12,
    partB, aidEffect("a", "b", 190))
  check("future_schema_is_refused", future == nil)
  return table.concat(checks, "|")
end)()
'''


EXPECTED = {
    "queued_without_effect", "patient_and_part_are_durable",
    "effective_completion_publishes_once", "completed_result_is_idempotent",
    "interruption_withholds_consequences",
    "ineffective_dressing_is_not_care", "native_refusal_is_ineffective",
    "patient_change_refuses_mutation", "patient_identity_is_required",
    "self_treatment_uses_same_result", "reload_unknown_withholds_and_reserves",
    "participant_release_drops_live_work",
    "queue_refusal_withholds_consequences", "saved_completion_consumes_once",
    "reload_waits_for_skill_body",
    "player_identity_uses_same_owner", "future_schema_is_refused",
    "unload_current_stops_native_and_lua", "unload_withholds_all_care",
    "unload_queued_preserves_other_actions", "unload_failure_retains_ownership",
    "unload_retry_closes_only_after_cancellation", "unload_no_owned_work_is_safe",
    "unload_native_presence_outlives_lua",
    "unload_uses_membership_not_stale_pointer",
    "reload_pending_checks_actual_actor_queues",
    "reload_pending_unload_is_interrupted_without_credit",
    "reload_pending_without_actor_representation_is_inert",
    "same_world_missing_handle_remains_unknown",
}


def run_probe(treatment_path=TREATMENT):
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
             str(prelude), str(treatment_path), str(probe), "--", "__result"],
            cwd=work, capture_output=True, text=True, timeout=300)
    output = (done.stdout or "") + (done.stderr or "")
    lines = (done.stdout or "").strip().splitlines()
    value = lines[-1][6:] if lines and lines[-1].startswith("VALUE ") else None
    return value, output


def mutation_control():
    source = TREATMENT.read_text(encoding="utf-8")
    needle = """    runtime[id].action = action
    log(actor .. \" began treating \" .. patient .. \" as \" .. id)"""
    mutation = """    runtime[id].action = action
    rec.status = \"completed\"
    applyRecordEffect(rec, runtime[id])
    rec.status = \"pending\"
    log(actor .. \" began treating \" .. patient .. \" as \" .. id)"""
    controls = [
        ("queue-credit", needle, mutation, "queued_without_effect"),
        ("native-stop", "return ISTimedActionQueue.clear(live.actorBody)",
         "return true", "unload_current_stops_native_and_lua"),
        ("queued-removal", "return owner:removeFromQueue(action)",
         "return true", "unload_queued_preserves_other_actions"),
        ("premature-release", "    if live and (live.unloadInterrupt or live.unloadBlocked) then return false end",
         "", "unload_failure_retains_ownership"),
        ("same-world-proof", "or not restoredPending[tostring(rec.id)]",
         "", "same_world_missing_handle_remains_unknown"),
        ("restored-action-proof", "or not restoredActionAbsent(rec)",
         "", "reload_pending_checks_actual_actor_queues"),
    ]
    for label, old, new, expected in controls:
        if source.count(old) != 1:
            return False, label + " mutation anchor absent"
        with tempfile.TemporaryDirectory() as tmp:
            broken = pathlib.Path(tmp) / "SAO_Treatment_broken.lua"
            broken.write_text(source.replace(old, new, 1), encoding="utf-8")
            value, detail = run_probe(broken)
        verdicts = dict(re.findall(r"([a-z0-9_]+)=(true|false)", value or ""))
        if verdicts.get(expected) != "false":
            return False, label + " mutation was not named: " + detail[-500:]
    return True, "six controls reject premature credit, missing cancellation and unproved restored-action absence"


def static_contract():
    treatment = TREATMENT.read_text(encoding="utf-8")
    needs = NEEDS.read_text(encoding="utf-8")
    controller = CONTROLLER.read_text(encoding="utf-8")
    harness = HARNESS.read_text(encoding="utf-8")
    identity = IDENTITY.read_text(encoding="utf-8")
    required = (
        "function T.begin", "function T.reconcile", "function T.releasePerson",
        "function T.interruptForBodyUnload",
        "function bandageClass:complete", "ISApplyBandage.complete",
        "effectiveDressing", "patientId", "bodyPartIndex", "effectApplied",
    )
    if any(anchor not in treatment for anchor in required):
        return False, "treatment owner anchors absent"
    for name in ("bandageSelf", "aidWound"):
        start = needs.find("function N." + name)
        end = needs.find("\nend", start)
        body = needs[start:end if end >= 0 else len(needs)]
        if "SAO.Treatment.begin" not in body or "ISApplyBandage:new" in body:
            return False, "Needs bypasses Treatment: " + name
    option_start = harness.find('person:addOption("Bandage their "')
    option_end = harness.find('person:addOption("Ask to walk with me"', option_start)
    if option_start < 0 or option_end < 0:
        return False, "player treatment option absent"
    option = harness[option_start:option_end]
    if "SAO.Treatment.begin" not in option or "ISApplyBandage:new" in option \
            or "adjustTrust" in option:
        return False, "player treatment still creates queue-time credit"
    if 'aidResult == "treated"' in controller:
        return False, "controller still treats admission as completion"
    if "SAO.Treatment.reconcile()" not in controller \
            or "SAO.Treatment.releasePerson" not in controller:
        return False, "controller does not reconcile or release treatment"
    if "SAO.Treatment.forgetPerson" not in identity:
        return False, "death does not release pending treatment"
    return True, "all open-wound callers use the result owner"


def main():
    print("=" * 74)
    print("OPEN-WOUND TREATMENT PUBLISHES ONLY A NATIVE RESULT")
    print("=" * 74)
    required = [TREATMENT, RUNNER]
    missing = [path for path in required if not path.is_file()]
    if missing:
        print("  FAULT: repository input absent: " + ", ".join(
            str(path.relative_to(ROOT)) for path in missing))
        return 1
    installed = [PZ, STDLIB, JDK / "java.exe", JDK / "javac.exe"]
    if not all(path.is_file() for path in installed):
        print("Border 183 SKIPPED: installed game VM or JDK absent")
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
        print("  " + detail[-2500:].replace("\n", " "))
        return 1
    print("  183) interrupted, ineffective, completed, reloaded, self, NPC, "
          "and player treatment preserve patient-bound completion")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
