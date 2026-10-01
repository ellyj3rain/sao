#!/usr/bin/env python3
"""Border 184: exact, recursive, actor-private native inventory views."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import subprocess
import tempfile
import time
import shutil


ROOT = pathlib.Path(__file__).resolve().parent.parent
GAME = pathlib.Path(os.environ.get(
    "PZ_DIR", r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"))
PZ = GAME / "projectzomboid.jar"
ZB = GAME / "ZombieBuddy.jar"
JDK = pathlib.Path(os.environ.get(
    "JDK_BIN", r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin"))

INSPECTION_PRELUDE = r'''
local stores = {}
ModData = { getOrCreate = function(key)
    stores[key] = stores[key] or {}; return stores[key]
end, get = function(key) return stores[key] end }
Events = setmetatable({}, { __index = function(t, key)
    local entry = { Add = function() end, Remove = function() end }; rawset(t,key,entry); return entry
end })
hours, permitted, inspectCalls = 2, true, 0
bodies, records, memories = {}, {}, {}
SAO = { Log = { line = function() end },
    History = { countyHours = function() return hours end,
        ticksFromHours = function(h) return h * 9000 end },
    Places = { at = function() return nil end },
    Identity = { get = function(id) return records[id] end },
    Body = { get = function(id) return bodies[id] end },
    Needs = { retireRecovery = function() end },
    Standing = { mayTakeCurrent = function() return permitted end } }
for _, id in ipairs({"a", "b", "c", "d", "e", "f", "g", "h", "i"}) do records[id] = { id = id }; bodies[id] = {} end
SAOJavaBridge = { worldInspectionMemory = function(self, body)
        memories[body] = memories[body] or {}; return memories[body]
    end,
    worldInspectionCandidates = function() return candidateText end,
    worldInspectContainer = function(self, body, id, fp, x, y, z)
        inspectCalls = inspectCalls + 1; return snapshotText
    end }
checks = 0
function check(name, passed) assert(passed, name); checks = checks + 1; print("CASE " .. name) end
'''

INSPECTION_CASES = r'''
local W, P = SAO.WorldSources, SAO.Perception
local originalSnapshot = snapshotText
local function facts(id)
    local result = {}; for _, place in pairs(P.knownPlaces(id,true)) do
        for key, fact in pairs(place.sourceFacts or {}) do result[key] = fact end
    end; return result
end
local function count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
-- Native truth may already know a holder through another participant. That
-- alone must never teach either actor or suppress their own inspection.
local packet = string.match(snapshotText, "^[^\n]+\n(.*)$")
check("other_observation_is_not_personal", W.applySnapshot(W.parse(packet)) and count(facts("a")) == 0)
local ctx = W.inspectionCandidate("a", bodies.a, "standing", 12)
check("offer_without_knowledge", ctx ~= nil and count(facts("a")) == 0 and inspectCalls == 0)
check("foreign_context_refused", not W.inspectContainer("b", bodies.b, ctx) and inspectCalls == 0)
permitted = false
local ok, why = W.inspectContainer("a", bodies.a, ctx)
check("permission_rechecked_before_fill", not ok and why == "current-claim-refused" and inspectCalls == 0)
check("unpermitted_not_offered", W.inspectionCandidate("a", bodies.a, "standing",12) == nil)
permitted = true
ctx = W.inspectionCandidate("a", bodies.a, "standing",12)
local forged={}; for k,v in pairs(ctx) do forged[k]=v end
check("unowned_context_refused", not W.inspectContainer("a", bodies.a, forged) and inspectCalls == 0)
W.resetRuntime()
check("reset_drops_lua_intent", not W.inspectContainer("a", bodies.a, ctx) and inspectCalls == 0)
ctx = W.inspectionCandidate("a", bodies.a, "standing",12)
check("actual_snapshot_inspected", W.inspectContainer("a", bodies.a, ctx) and inspectCalls == 1)
local remembered = facts("a")[ctx.sourceId]
check("empty_holder_private_fact", remembered and remembered.state == "spent"
    and remembered.explored and count(remembered.quantities) == 0)
check("only_exact_holder_learned", count(facts("a")) == 1)
check("other_actor_not_taught", count(facts("b")) == 0)
local nextCtx = W.inspectionCandidate("a", bodies.a, "standing",12)
check("empty_holder_not_repeated", not nextCtx or nextCtx.sourceId ~= ctx.sourceId)
local second = W.inspectionCandidate("b", bodies.b, "standing",12)
check("second_actor_still_unknown", second and second.sourceId == ctx.sourceId and count(facts("b")) == 0)
check("second_actor_must_inspect", W.inspectContainer("b", bodies.b, second) and inspectCalls == 2
    and count(facts("b")) == 1)
local value = ModData.get("SurvivorAwareness_WorldSources")
check("inspection_no_acquisition_receipt", count(value.reservations) == 0 and count(value.results) == 0)
local original = candidateText
candidateText = string.gsub(candidateText, "reachable=1", "reachable=0")
local failed = W.inspectionCandidate("c", bodies.c, "standing",12)
check("exact_failed_approach_recorded", W.inspectionFailed("c", bodies.c, failed, "done:Failed"))
local alternate = W.inspectionCandidate("c", bodies.c, "standing",12)
check("failed_holder_not_immediately_reselected", not alternate or alternate.sourceId ~= failed.sourceId)
hours = hours + 0.25
local retried = W.inspectionCandidate("c", bodies.c, "standing",12)
check("bounded_retry_expires", retried and retried.sourceId == failed.sourceId)
check("flee_does_not_penalize", not W.inspectionFailed("c", bodies.c, retried, "interrupted:FLEE"))
retried = W.inspectionCandidate("c", bodies.c, "standing",12)
check("flee_reselection_allowed", retried and retried.sourceId == failed.sourceId)
W.inspectionFailed("c", bodies.c, retried, "done:FailedObstacle:FAILED_BLOCKED_DIAGONAL")
candidateText = original
check("actual_reach_overrides_route_refusal", W.inspectionCandidate("c", bodies.c, "standing",12) ~= nil)
local valid = candidateText
candidateText = string.gsub(valid, "|reachable=1", "|reachable=1|reachable=1")
check("duplicate_protocol_key_refused", W.inspectionCandidate("d", bodies.d, "standing",12) == nil)
candidateText = valid
local stale = W.inspectionCandidate("d", bodies.d, "standing",12)
snapshotText = string.gsub(snapshotText, "|x=11|", "|x=12|")
check("changed_source_receipt_not_taught", not W.inspectContainer("d", bodies.d, stale) and count(facts("d")) == 0)
snapshotText = originalSnapshot
local acknowledged, reject = {}, false
SAO.ProceduralPlanning = {
 admitInspection = function(id, receipt) return receipt.actorId == id and receipt.purposeId == 'purpose' end,
 consumeInspectionResult = function(id, receipt)
  if reject then return false end
  local actual = W.inspectionOutcome(id, receipt.id)
  if not actual or actual.status == 'admitted' then return false end
  acknowledged[receipt.id] = (acknowledged[receipt.id] or 0) + 1
  return true
 end
}
local priorInspectCalls = inspectCalls
local planned = W.inspectionCandidate('e', bodies.e, 'standing', 12)
local admitted = W.beginPurposeInspection('e', bodies.e, planned, 'purpose', 'step')
check('purpose_admission_is_not_inspection_or_stock', admitted and admitted.status == 'admitted'
 and inspectCalls == priorInspectCalls and count(facts('e')) == 0 and not admitted.nativeInspected)
check('other_actor_cannot_read_inspection_receipt', W.inspectionOutcome('f', admitted.id) == nil)
local detached = W.inspectionOutcome('e', admitted.id); detached.status = 'completed'; detached.nativeInspected = true
check('detached_result_cannot_grant_inspection', W.inspectionOutcome('e', admitted.id).status == 'admitted')
check('native_empty_inspection_completes_exact_attempt', W.inspectContainer('e', bodies.e, planned)
 and W.inspectionOutcome('e', admitted.id).nativeInspected == true
 and W.inspectionOutcome('e', admitted.id).privateLearned == true
 and facts('e')[planned.sourceId].state == 'spent' and count(value.results) == 0)
W.reconcilePurposeInspections('e', bodies.e)
check('inspection_delivery_is_exactly_once', acknowledged[admitted.id] == 1)
local failedPurpose = W.inspectionCandidate('f', bodies.f, 'standing', 12)
local failedReceipt = W.beginPurposeInspection('f', bodies.f, failedPurpose, 'purpose', 'step')
W.inspectionFailed('f', bodies.f, failedPurpose, 'order-refused')
check('refused_order_never_teaches_or_completes', failedReceipt
 and W.inspectionOutcome('f', failedReceipt.id).status == 'failed'
 and W.inspectionOutcome('f', failedReceipt.id).nativeInspected == false and count(facts('f')) == 0)
local resumed = W.inspectionCandidate('g', bodies.g, 'standing', 12)
local resumedReceipt = W.beginPurposeInspection('g', bodies.g, resumed, 'purpose', 'step')
W.resetRuntime(); W.reconcilePurposeInspections('g', bodies.g)
check('reload_retires_lost_runtime_inspection', resumedReceipt
 and W.inspectionOutcome('g', resumedReceipt.id).status == 'interrupted'
 and not W.inspectionOutcome('g', resumedReceipt.id).nativeInspected and count(facts('g')) == 0)
reject = true
local pendingDelivery = W.inspectionCandidate('h', bodies.h, 'standing', 12)
local retainedReceipt = W.beginPurposeInspection('h', bodies.h, pendingDelivery, 'purpose', 'step')
W.inspectContainer('h', bodies.h, pendingDelivery)
check('unacknowledged_inspection_stays_durable', records.h.worldInspectionReceipts[1].status == 'completed'
 and records.h.worldInspectionReceipts[1].planningAcknowledged ~= true)
reject = false; W.reconcilePurposeInspections('h', bodies.h)
check('retained_inspection_delivery_retries', acknowledged[retainedReceipt.id] == 1
 and records.h.worldInspectionReceipts[1].planningAcknowledged == true)
local handoff = W.inspectionCandidate('h', bodies.h, 'standing', 12, pendingDelivery.sourceId)
local handoffReceipt = W.beginPurposeInspection('h', bodies.h, handoff, 'purpose', 'step')
records.h.dead = true
SAO.Controller.agents.h = { rec = records.h }
SAO.SourceUse = { closeForOwnershipTransfer = function() return false end }
check('pending_source_closure_retains_inspection_owner', not SAO.Controller.drop('h')
 and W.inspectionOutcome('h', handoffReceipt.id).status == 'admitted'
 and SAO.Controller.agents.h ~= nil and memories[bodies.h].pending == handoff)
SAO.SourceUse.closeForOwnershipTransfer = function() return true end
check('dead_or_external_owner_handoff_retires_admission', SAO.Controller.drop('h') and handoffReceipt
 and W.inspectionOutcome('h', handoffReceipt.id).status == 'interrupted'
 and W.inspectionOutcome('h', handoffReceipt.id).reason == 'controller-drop'
 and not W.inspectionOutcome('h', handoffReceipt.id).nativeInspected
 and acknowledged[handoffReceipt.id] == 1 and memories[bodies.h].pending == nil
 and SAO.Controller.agents.h == nil)
local deceased = W.inspectionCandidate('i', bodies.i, 'standing', 12)
local deathReceipt = W.beginPurposeInspection('i', bodies.i, deceased, 'purpose', 'step')
records.i.bodyOwner = 'ZAO'; SAO.Body.foreign.i = bodies.i
bodies.i.isDead = function() return true end
bodies.i.getX = function() return 11 end; bodies.i.getY = function() return 22 end
bodies.i.getZ = function() return 0 end
check('native_death_owner_retires_inspection_admission', SAO.Controller.observeExternalDeath('i', bodies.i, 'ZAO')
 and records.i.dead == true and W.inspectionOutcome('i', deathReceipt.id).status == 'interrupted'
 and W.inspectionOutcome('i', deathReceipt.id).reason == 'death'
 and not W.inspectionOutcome('i', deathReceipt.id).nativeInspected
 and count(facts('i')) == 0 and memories[bodies.i].pending == nil
 and acknowledged[deathReceipt.id] == 1)
RESULT = "PASS inspection Lua " .. checks
'''


def inspection_lua(root, work, production, receipt):
    shutil.copyfile(GAME / "stdlib.lua", work / "stdlib.lua")
    prelude = work / "inspection-prelude.lua"
    prelude.write_text(INSPECTION_PRELUDE + "\ncandidateText=[=[" +
        (work / "candidates.txt").read_text(encoding="utf-8") +
        "]=]\nsnapshotText=[=[" + (work / "snapshot.txt").read_text(encoding="utf-8") + "]=]\n",
        encoding="utf-8")
    case = work / "inspection-cases.lua"
    case.write_text(INSPECTION_CASES, encoding="utf-8")
    controller = (root / "mod/42.20/media/lua/client/SAO_Controller.lua").read_text(encoding="utf-8-sig")
    drop_text = ('SAO.Controller={agents={}}\nSAO.Locomotion={cancel=function() end}\n'
        'local Ctl=SAO.Controller\nlocal log=function() end\nlocal clearLoadedContact=function() end\n'
        'function Ctl.drop(id)' + controller.split('function Ctl.drop(id)', 1)[1].split('local setStateRef', 1)[0])
    drop_text += ('\nlocal tickCount,hostTickCount=900,12\nCtl.pendingCorpses={}\n'
        'SAO.Body.foreign={}; SAO.Body.active={}\n'
        'SAO.Identity.updatePosition=function(rec,x,y,z) rec.x,rec.y,rec.z=x,y,z end\n'
        'SAO.Identity.markDead=function(rec,tick,cause) rec.dead=true; return true end\n'
        'local witnessDeath=function() return "native-death" end\nlocal tellPlayerOfDeath=function() end\n'
        'local function retireDeadBodyWork' + controller.split('local function retireDeadBodyWork', 1)[1]
        .split('local function decisionIntervalFor', 1)[0])
    drop = work / "inspection-controller-drop.lua"
    drop.write_text(drop_text, encoding="utf-8")
    inputs = [prelude, root / "mod/42.20/media/lua/shared/SAO_WorldSources.lua",
        root / "mod/42.20/media/lua/shared/SAO_Perception.lua", drop, case]
    result = run([JDK / "java.exe", "-cp", os.pathsep.join(map(str,(production,PZ,ZB))),
        "LuaRun", *inputs, "--", "RESULT"], work, "probe", "inspection-lua", receipt)
    if result.returncode or "VALUE PASS inspection Lua" not in result.stdout:
        raise RuntimeError("Inspection Lua failed: " + result.stdout + result.stderr)
    print(result.stdout.strip())
    receipt["results"].append({"case":"inspection-lua", "passed":True})
    source = inputs[1].read_text(encoding="utf-8-sig")
    controls = [
        ("omit-private-inspection", "learned = SAO.Perception.learnInspectedSource(actorId,\n            transferPlace(actorId, source), context.sourceId, tick, \"native-container-inspection\")",
            "learned = true", "empty_holder_private_fact"),
        ("repeat-empty", "and (sourceId ~= nil or not personallyInspected(known, row))",
            "and true", "empty_holder_not_repeated"),
        ("ignore-route-failure", "if not delayed and (sourceId == nil or row.id == sourceId)",
            "if true and (sourceId == nil or row.id == sourceId)", "failed_holder_not_immediately_reselected"),
        ("penalize-flee", "local INSPECTION_ACCESS_FAILURE = {", "local INSPECTION_ACCESS_FAILURE = { [\"interrupted:FLEE\"] = true,", "flee_does_not_penalize"),
        ("leak-on-offer", "memory.pending = context",
            "memory.pending = context\n            SAO.Perception.learnInspectedSource(actorId, transferPlace(actorId, value.sources[row.id]), row.id, 0, 'bad-offer')", "offer_without_knowledge"),
        ("permission-after-fill", "if not (SAO.Standing and SAO.Standing.mayTakeCurrent\n        and SAO.Standing.mayTakeCurrent(actorId, context.sourceX, context.sourceY,\n            context.admission)) then return refused(\"current-claim-refused\") end",
            "if false then return refused(\"current-claim-refused\") end", "permission_rechecked_before_fill"),
        ("forget-current-coordinates", "or source.x ~= context.sourceX or source.y ~= context.sourceY or source.z ~= context.sourceZ", "or false", "changed_source_receipt_not_taught"),
        ("teach-all-chunk-holders", "if not learnedOk or not learned then return refused(\"private-inspection-unavailable\") end",
            "for otherId, otherSource in pairs(snapshot.sources) do SAO.Perception.learnInspectedSource(actorId, transferPlace(actorId, otherSource), otherId, 0, 'bad-bulk') end\n    if not learnedOk or not learned then return refused(\"private-inspection-unavailable\") end", "only_exact_holder_learned"),
    ]
    controls += [
        ("lose-purpose-success", 'finishPurposeInspection(actorId, context, "completed", "native-container-inspection", true)',
            'finishPurposeInspection(actorId, context, "completed", "native-container-inspection", false)', 'native_empty_inspection_completes_exact_attempt'),
        ("lose-reload-interruption", 'receipt.status, receipt.reason, receipt.atHours = "interrupted", "inspection-runtime-owner-not-retained", nowHours()',
            'receipt.reason = "unrecorded interruption"', 'reload_retires_lost_runtime_inspection'),
        ("lose-handoff-interruption", 'receipt.status, receipt.reason, receipt.atHours = "interrupted", tostring(reason or "owner-retired"), nowHours()',
            'receipt.reason = "unrecorded handoff"', 'dead_or_external_owner_handoff_retires_admission'),
    ]
    for name, before, after, marker in controls:
        if source.count(before) != 1:
            raise RuntimeError("Inspection Lua control drift: " + name)
        changed = work / (name + ".lua")
        changed.write_text(source.replace(before, after, 1), encoding="utf-8")
        controlled = run([JDK / "java.exe", "-cp", os.pathsep.join(map(str,(production,PZ,ZB))),
            "LuaRun", prelude, changed, inputs[2], drop, case, "--", "RESULT"],
            work, "control", name, receipt)
        if "ERROR " not in controlled.stdout or marker not in controlled.stdout:
            raise RuntimeError("Inspection Lua control did not reject " + name + ": " + controlled.stdout + controlled.stderr)
        receipt["results"].append({"case":name, "passed":True, "reason":marker})
        print("CONTROL " + name + ": " + marker)
    for reason, marker in [('controller-drop', 'dead_or_external_owner_handoff_retires_admission'),
                          ('death', 'native_death_owner_retires_inspection_admission')]:
        before = 'SAO.WorldSources.interruptPurposeInspections(id, body, "' + reason + '")'
        if drop_text.count(before) != 1:
            raise RuntimeError("Controller inspection retirement control drift: " + reason)
        name = "controller-omits-inspection-retirement-" + reason
        changed_drop = work / (name + ".lua")
        changed_drop.write_text(drop_text.replace(before, '-- retirement omitted', 1), encoding="utf-8")
        controlled = run([JDK / "java.exe", "-cp", os.pathsep.join(map(str,(production,PZ,ZB))),
            "LuaRun", prelude, inputs[1], inputs[2], changed_drop, case, "--", "RESULT"],
            work, "control", name, receipt)
        if "ERROR " not in controlled.stdout or marker not in controlled.stdout:
            raise RuntimeError("Controller inspection retirement control did not reject: " + controlled.stdout + controlled.stderr)
        receipt["results"].append({"case":name, "passed":True, "reason":marker})
        print("CONTROL " + name + ": " + marker)


def inspection_controls(root, work, production, receipt):
    source = (root / "java/src/com/sao/engine/SAOWorldSources.java").read_text(encoding="utf-8-sig")
    controls = [
        ("native-square-unsupported-iterator", "for (int objectIndex = 0; objectIndex < square.getObjects().size(); objectIndex++) {\n                    IsoObject object = square.getObjects().get(objectIndex);",
            "for (IsoObject object : square.getObjects()) {", "inspected_native_holder_offers_exact_transfer"),
        ("native-square-unsupported-copy", "for (int objectIndex = 0; objectIndex < square.getObjects().size(); objectIndex++) {\n                    IsoObject object = square.getObjects().get(objectIndex);",
            "for (IsoObject object : new ArrayList<>(square.getObjects())) {", "inspected_native_holder_offers_exact_transfer"),
        ("omit-native-fill", "try { ItemPickerJava.fillContainer(container, shell); }", "try { /* missing native opening */ }", "native_fill_once"),
        ("repeat-native-roll", "if (!container.isExplored()) {\n                try { ItemPickerJava.fillContainer", "if (true) {\n                try { ItemPickerJava.fillContainer", "repeat_inspection_no_roll"),
        ("foreign-native-binding", "var bindings = INSPECTIONS.get(shell);", "var bindings = INSPECTIONS.values().iterator().next();", "foreign_actor_refused"),
        ("lost-native-reach", "|| !SAONeeds.containerAccessibleNow(shell, container)) return \"ACCESS_REFUSED\";", ") return \"ACCESS_REFUSED\";", "unreachable_refused"),
        ("stale-native-object", "|| !square.getObjects().contains(object)\n                    || binding.index", "|| false\n                    || binding.index", "cloned_identity_refused"),
        ("lost-native-visibility", "if (!SAOPerceptionScanner.canSeeWorldSquareNow(shell, square, radius)) continue;", "if (square == null) continue;", "opaque_holder_not_offered"),
        ("lost-native-reset", "INSPECTIONS.clear();", "/* retained old world bindings */", "world_reset_drops_offers"),
        ("lost-native-lock", "(object instanceof IsoThumpable locked && locked.isLockedToCharacter(shell))", "false", "lock_rechecked_at_inspection"),
        ("omit-own-inspection-revision", "binding.observedRevision = source.revision;", "/* no own evidence */", "own_inspection_admits_direct_food"),
        ("stale-private-stock-authority", "return current.equals(observed) || remembered.contains(current);", "return observed != null || !remembered.isEmpty();", "stale_private_revision_cannot_reveal_added_stock"),
        ("drop-existing-private-memory", "var remembered = rememberedContainerRevisions(person, id, fingerprint);", "var remembered = java.util.Set.<String>of();", "unchanged_private_memory_survives_reset"),
    ]
    for name, before, after, marker in controls:
        if source.count(before) != 1:
            raise RuntimeError("Native inspection control drift: " + name)
        directory = work / name; directory.mkdir()
        changed = directory / "SAOWorldSources.java"
        changed.write_text(source.replace(before,after,1),encoding="utf-8")
        classes = directory / "classes"; classes.mkdir()
        compiled = run([JDK / "javac.exe", "-encoding", "UTF-8", "-cp",
            os.pathsep.join(map(str,(production,PZ,ZB))), "-d", classes, changed], directory,
            "compile",name,receipt)
        if compiled.returncode:
            raise RuntimeError("Native inspection control compile failed " + name + ": " + compiled.stderr)
        controlled = run([JDK / "java.exe", f"-Duser.home={directory}", "-cp",
            os.pathsep.join(map(str,(classes,production,PZ,ZB))), "ContainerInspectionProbe"], GAME,
            "control",name,receipt)
        if controlled.returncode == 0 or "AssertionError: " + marker not in controlled.stderr:
            raise RuntimeError("Native inspection control did not reject " + name + ": " + controlled.stdout + controlled.stderr)
        receipt["results"].append({"case":name,"passed":True,"reason":marker})
        print("CONTROL " + name + ": " + marker)
    private_source = (root / "java/src/com/sao/engine/SAOPrivateInventory.java").read_text(encoding="utf-8-sig")
    before = "SAOWorldSources.knowsContainerContents(person,\n                    object, container, containerIndex)"
    if private_source.count(before) != 1:
        raise RuntimeError("Global-explored privacy control drift")
    directory = work / "global-explored-private"; directory.mkdir()
    changed = directory / "SAOPrivateInventory.java"
    changed.write_text(private_source.replace(before,"container.isExplored()",1),encoding="utf-8")
    classes=directory / "classes"; classes.mkdir()
    compiled=run([JDK / "javac.exe","-encoding","UTF-8","-cp",
        os.pathsep.join(map(str,(production,PZ,ZB))),"-d",classes,changed],directory,
        "compile","global-explored-private",receipt)
    if compiled.returncode:
        raise RuntimeError("Privacy restoration control compile failed: " + compiled.stderr)
    controlled=run([JDK / "java.exe",f"-Duser.home={directory}","-cp",
        os.pathsep.join(map(str,(classes,production,PZ,ZB))),"ContainerInspectionProbe"],GAME,
        "control","global-explored-private",receipt)
    marker="other_behind_wall_cannot_read_stock"
    if controlled.returncode==0 or "AssertionError: " + marker not in controlled.stderr:
        raise RuntimeError("Global explored control did not reproduce cross-person leak: " + controlled.stdout + controlled.stderr)
    print("CONTROL global-explored-private: " + marker)
    receipt["results"].append({"case":"global-explored-private","passed":True,"reason":marker})


def sha(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def static_contract(root: pathlib.Path) -> list[str]:
    private = (root / "java/src/com/sao/engine/SAOPrivateInventory.java").read_text(
        encoding="utf-8-sig")
    needs = (root / "java/src/com/sao/engine/SAONeeds.java").read_text(
        encoding="utf-8-sig")
    bridge = (root / "java/src/com/sao/bridge/SAOBridge.java").read_text(
        encoding="utf-8-sig")
    standing = (root / "mod/42.20/media/lua/shared/SAO_Standing.lua").read_text(
        encoding="utf-8-sig")
    provisioning = (root / "mod/42.20/media/lua/shared/SAO_Provisioning.lua").read_text(
        encoding="utf-8-sig")
    controller = (root / "mod/42.20/media/lua/client/SAO_Controller.lua").read_text(
        encoding="utf-8-sig")
    sources = (root / "java/src/com/sao/engine/SAOWorldSources.java").read_text(
        encoding="utf-8-sig")
    plan = (root / "artifacts/audits/20260921-1838Z-1138PST-complete-private-inventory/PLAN.md").read_text(
        encoding="utf-8-sig")
    lua_decisions = "\n".join((root / name).read_text(encoding="utf-8-sig") for name in (
        "mod/42.20/media/lua/client/SAO_Animals.lua",
        "mod/42.20/media/lua/client/SAO_Controller.lua",
        "mod/42.20/media/lua/client/SAO_Harness.lua",
        "mod/42.20/media/lua/client/SAO_Needs.lua",
        "mod/42.20/media/lua/client/SAO_RadioEar.lua",
        "mod/42.20/media/lua/shared/SAO_Standing.lua",
    ))
    checks = {
        "read-only owner": "Project Zomboid remains the inventory owner" in plan,
        "coverage matrix": all(term in plan for term in (
            "Static containers", "Vehicle containers", "Placed items",
            "Corpse containers", "Person privacy", "Coverage")),
        "protocol": 'PROTOCOL = "SAOPI1"' in private,
        "recursive carriage": "collectItems(nested.getInventory()" in private,
        "direct parents": "parentItemId" in private and "fact.parentItemId()" in private,
        "holder surfaces": all(kind in private for kind in (
            '"container"', '"vehicle"', '"ground"', '"corpse"')),
        "aggregate refused": 'append("|aggregate=refused")' in private,
        "dormant world unknown": 'finish(normalized, "dormant", "complete", "unknown"' in private,
        "source identities": all(name in sources for name in (
            "privateContainerId", "privateVehicleId", "privateGroundId")),
        "bridge views": all(name in bridge for name in (
            "privateCarriedItems", "privateInventoryLoaded",
            "privateInventoryDormant", "privateContainerItems",
            "privateCorpseItems", "privateDormantHasRadio")),
        "java decisions use view": ".getItems()" not in needs
            and "nearestPrivateSource" in needs and "privateStoreItems" in needs,
        "lua carried decisions use bridge": "privateCarriedItems" in lua_decisions,
        "lua root scans removed": ":getItems()" not in lua_decisions,
        "exact dormant radio": "privateDormantHasRadio" in standing
            and "hibernation:find" not in standing,
        "bounded totals refused": "privateInventoryLoaded(body, 12)" in controller
            and "aggregate=refused" in controller
            and "quartermaster-native-scan" not in controller
            and "countEdibleNearby(body, 12)" not in controller
            and "countStoredWaterNearby(body, 12)" not in controller,
        "inferred totals retired": "local STANDING_SCHEMA = 4" in standing
            and "migrateInferredMaterialClaims" in standing
            and "completeMaterialClaimAllowed" in standing,
        "complete claims require coverage": "evidence.completeCoverage == true" in standing
            and "completeCoverage = true" in provisioning,
    }
    missing = [name for name, passed in checks.items() if not passed]
    if missing:
        raise RuntimeError("Private inventory contract missing: " + ", ".join(missing))
    return list(checks)


def run(command, cwd, phase, case, receipt, timeout=120):
    start = time.perf_counter()
    result = subprocess.run([str(value) for value in command], cwd=cwd,
        capture_output=True, text=True, encoding="utf-8", errors="replace",
        timeout=timeout)
    receipt["commands"].append({
        "phase": phase, "case": case, "returncode": result.returncode,
        "seconds": time.perf_counter() - start,
        "stdout": result.stdout, "stderr": result.stderr,
    })
    return result


def execute(root: pathlib.Path, receipt: dict) -> None:
    source = root / "java/src/com/sao/engine/SAOPrivateInventory.java"
    original = source.read_text(encoding="utf-8-sig")
    before = "collectItems(nested.getInventory(), found, seen, depth + 1);"
    after = "/* mutation omits nested carried items */"
    if original.count(before) != 1:
        raise RuntimeError("Nested-carriage mutation target drifted")

    with tempfile.TemporaryDirectory(prefix="sao-private-inventory-") as raw:
        work = pathlib.Path(raw)
        production = work / "production"
        production.mkdir()
        generated = work / "SAOVersion.java"
        version = (root / "VERSION").read_text(encoding="utf-8-sig").strip()
        generated.write_text(
            "package com.sao; public final class SAOVersion { "
            f'public static final String VALUE = "{version}"; '
            "private SAOVersion() {} }\n", encoding="utf-8")
        inputs = sorted((root / "java/src").rglob("*.java"))
        inputs.extend((generated,
            root / "tools/luacheck/PrivateInventoryProbe.java",
            root / "tools/luacheck/ContainerInspectionProbe.java",
            root / "tools/luacheck/MovementCrossingProbe.java",
            root / "tools/luacheck/LuaRun.java"))
        classpath = os.pathsep.join(map(str, (PZ, ZB)))
        compiled = run([JDK / "javac.exe", "-encoding", "UTF-8", "-cp",
            classpath, "-d", production, *inputs], work, "compile",
            "production", receipt)
        if compiled.returncode:
            raise RuntimeError("Private inventory production compile failed: "
                + compiled.stdout + compiled.stderr)
        result = run([JDK / "java.exe", f"-Duser.home={work}", "-cp",
            os.pathsep.join(map(str, (production, PZ, ZB))),
            "PrivateInventoryProbe"], work, "probe", "production", receipt)
        if result.returncode or "PASS private inventory" not in result.stdout:
            raise RuntimeError("Private inventory production probe failed: "
                + result.stdout + result.stderr)
        print(result.stdout.strip())
        receipt["results"].append({"case": "production", "passed": True})
        inspection = run([JDK / "java.exe", f"-Duser.home={work}", "-cp",
            os.pathsep.join(map(str, (production, PZ, ZB))),
            "ContainerInspectionProbe", work], GAME, "probe", "native-inspection", receipt)
        if inspection.returncode or "PASS container inspection" not in inspection.stdout:
            raise RuntimeError("Native inspection probe failed: " + inspection.stdout + inspection.stderr)
        print(inspection.stdout.strip())
        receipt["results"].append({"case": "native-inspection", "passed": True})
        inspection_lua(root, work, production, receipt)
        inspection_controls(root, work, production, receipt)

        mutation = work / "mutation"
        mutation.mkdir()
        changed = mutation / "SAOPrivateInventory.java"
        changed.write_text(original.replace(before, after, 1), encoding="utf-8")
        mutated_classes = mutation / "classes"
        mutated_classes.mkdir()
        mutated = run([JDK / "javac.exe", "-encoding", "UTF-8", "-cp",
            os.pathsep.join(map(str, (production, PZ, ZB))), "-d",
            mutated_classes, changed], mutation, "compile", "omit-nested",
            receipt)
        if mutated.returncode:
            raise RuntimeError("Private inventory control did not compile: "
                + mutated.stdout + mutated.stderr)
        controlled = run([JDK / "java.exe", f"-Duser.home={mutation}", "-cp",
            os.pathsep.join(map(str, (mutated_classes, production, PZ, ZB))),
            "PrivateInventoryProbe"], mutation, "probe", "omit-nested",
            receipt)
        output = controlled.stdout + controlled.stderr
        if controlled.returncode == 0 or "nested_loaded" not in output:
            raise RuntimeError("Nested-carriage control did not fail specifically: " + output)
        print("CONTROL omit-nested: nested_loaded")
        receipt["results"].append({"case": "omit-nested", "passed": True,
            "reason": "nested_loaded"})
        print("Border 184 PASS: complete private inventory view")


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", nargs="?", type=pathlib.Path, default=ROOT)
    parser.add_argument("--receipt", type=pathlib.Path)
    args = parser.parse_args(argv)
    root = args.root.resolve()
    receipt = {"border": 184, "checks": [], "results": [], "commands": []}
    bound = (
        "java/src/com/sao/engine/SAOPrivateInventory.java",
        "java/src/com/sao/engine/SAOWorldSources.java",
        "java/src/com/sao/engine/SAOPerceptionScanner.java",
        "mod/42.20/media/lua/shared/SAO_WorldSources.lua",
        "mod/42.20/media/lua/shared/SAO_Perception.lua",
        "mod/42.20/media/lua/client/SAO_Controller.lua",
        "tools/private_inventory_test.py", "tools/luacheck/PrivateInventoryProbe.java",
        "tools/luacheck/ContainerInspectionProbe.java", "tools/luacheck/MovementCrossingProbe.java",
        "tools/luacheck/LuaRun.java",
    )
    receipt["source_sha256"] = {name: sha(root / name) for name in bound}
    try:
        receipt["checks"] = static_contract(root)
        required = (PZ, ZB, JDK / "javac.exe", JDK / "java.exe")
        if not all(path.is_file() for path in required):
            receipt["status"] = "SKIPPED"
            print("Border 184 SKIPPED: installed game VM or JDK absent; "
                "static private-inventory contract checked")
        else:
            receipt["engine_sha256"] = sha(PZ)
            receipt["compiler_sha256"] = sha(JDK / "javac.exe")
            execute(root, receipt)
            if any(sha(root / name) != digest for name,digest in receipt["source_sha256"].items()):
                raise RuntimeError("Bound inspection input changed during validation")
            receipt["status"] = "PASS"
    except Exception as error:
        receipt["status"] = "FAIL"
        receipt["error"] = str(error)
        print("FAULT private inventory: " + str(error), file=os.sys.stderr)
        code = 1
    else:
        code = 0
    if args.receipt:
        args.receipt.parent.mkdir(parents=True, exist_ok=True)
        args.receipt.write_text(json.dumps(receipt, indent=2) + "\n",
            encoding="utf-8")
    return code


if __name__ == "__main__":
    raise SystemExit(main())
