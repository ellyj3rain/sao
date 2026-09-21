#!/usr/bin/env python3
"""Production provisioning lifecycle/capture cases for Border 179.

The installed Kahlua VM executes WorldSources, SourceUse, Needs, Controller and
decision_capture. Native holders and vanilla queue/actions are explicit adapters;
native inventory fidelity is covered by WorldTransferProbe.
"""
import json
import pathlib
import re
import shutil
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
CASES = ROOT / "tools/sweep/provisioning_lifecycle_cases.lua"
CAPTURE = ROOT / "tools/sweep/decision_capture.lua"
PERCEPTION = ROOT / "mod/42.20/media/lua/shared/SAO_Perception.lua"
ATTACHMENT = ROOT / "mod/42.20/media/lua/shared/SAO_PlaceAttachment.lua"

EXPECTED = {
    "acquire_performed", "store_performed", "no_consumption_or_need_credit",
    "queued_is_not_performed", "queue_without_move_releases", "rejected_enqueue",
    "interrupt_before_move", "interrupt_after_move", "reload_before_move",
    "reload_after_move_once", "unavailable_destination_pending",
    "both_holders_conflict", "neither_holder_conflict", "standing_revocation_prevents_mutation",
    "acquired_contents_mismatch", "physical_anchor_refresh",
    "completed_work_credit_once", "credit_actor_status_order",
    "queue_has_no_social_credit", "capture_transfer_bound",
    "capture_decision_frozen", "capture_item_units",
    "capture_required_result_failure", "capture_required_person_failure",
    "standing_food_refusal", "desperate_food_admission", "legacy_medication_route",
    "legacy_missing_context",
    "nearby_approach_exact", "nearby_route_refusal", "nearby_standing_refusal",
    "nearby_reached_transfer",
    "production_inspection_geometry", "production_anchor_recall",
    "production_anchor_exact_scope", "production_consume_anchor",
    "production_inspection_no_attachment", "production_anchor_access_route",
    "production_building_visit_preserved",
}

ADAPTERS = r'''
plainNameOf = function(first, last) return first .. " " .. last end
SAO.History.ageOf = function() return 31 end
SAO.Disposition = {circle=function() return "near" end,
    traits=function() return {patience=0.7} end, describe=function() return "fixture" end}
SAO.Conditions = {of=function() return {tired=false} end}
SAO.Habits = {of=function() return {keepsWatch=true} end}
SAO.Lessons = {renderClaims=function() return {shelter=true} end}
SAO.Census = {JOB_PERK={forager="Foraging"}, classOf=function() return "farmer" end,
    skillOf=function() return 2 end}
SAO.Rand = {state=function() return "lifecycle-seed", 17 end}
SAO.Voice = {onEvent=function() __voiceCalls = __voiceCalls + 1 end}
SAO.Standing.adjustTrust = function() __trustCalls = __trustCalls + 1 end
SAO.Standing.addDebt = function() __debtCalls = __debtCalls + 1 end
SAO.Standing.settleDebt = function() __debtCalls = __debtCalls + 1 end
SAO.Standing.mayTakeCurrent = function(id,x,y,admission)
    __standingAdmission = admission
    return admission == "desperate" or __standingAllowed ~= false
end
SAO.Standing.mayAttemptBelieved = function(id,x,y,admission)
    __attempt = {id=id,x=x,y=y,admission=admission}
    return __attemptAllowed ~= false
end
SAO.Perception.beliefs = {}
SAO.Perception.learnInspectedSource = function(id, place, sourceId, tick, provenance)
    local actor = tostring(id)
    __known[actor] = __known[actor] or {}
    local belief = __known[actor][place.id] or {cx=place.cx,cy=place.cy,sourceFacts={}}
    __known[actor][place.id] = belief
    belief.sourceFacts[sourceId] = SAO.WorldSources.beliefFact(sourceId)
    belief.at, belief.source = tick, provenance
    __lastLearn = {place=place,sourceId=sourceId,provenance=provenance}
    return true
end
ISInventoryTransferAction = {}
function ISInventoryTransferAction:derive(name)
    local child = {}; child.__index = child
    setmetatable(child, {__index=self}); return child
end
function ISInventoryTransferAction:new(character,item,src,dest)
    return setmetatable({character=character,item=item,srcContainer=src,destContainer=dest},
        {__index=self})
end
function ISInventoryTransferAction:isValid() return __nativeValid ~= false end
function ISInventoryTransferAction:transferItem(item)
    __nativeMoves = __nativeMoves + 1
    __move()
end
ISTimedActionQueue.add = function(action)
    __queueCalls = __queueCalls + 1
    if __queueReject then return end
    __queued, __busy = action, true
end
ISTimedActionQueue.hasAction = function(action) return __queued == action and __busy end
local eatNew, drinkNew = ISEatFoodAction.new, ISDrinkFluidAction.new
ISEatFoodAction.new = function(...)
    __consumeCalls = __consumeCalls + 1; return eatNew(...)
end
ISDrinkFluidAction.new = function(...)
    __consumeCalls = __consumeCalls + 1; return drinkNew(...)
end
SAOJavaBridge.hasPendingActions = function() return __busy end
SAOJavaBridge.containerAccessibleNow = function() return __accessible end
SAOJavaBridge.worldTransferPosition = function() return "AT:8:8:0" end
SAOJavaBridge.worldTransferOffer = function() return __offerText end
SAOJavaBridge.carriedWorldTransferItem = function() return __carriedText end
SAOJavaBridge.worldStoreTransferState = function()
    if __holderState == "UNAVAILABLE" then return "UNAVAILABLE" end
    if __carriedItem and not __destinationItem then return "CARRIED" end
    if __destinationItem and not __carriedItem then return "TRANSFERRED" end
    return "CONFLICT"
end
SAOJavaBridge.findFoodSource = function(self,body,radius)
    __searchedRadius = radius; return __discoveredSource
end
SAOJavaBridge.foodSourceWithinReach = function() return __withinReach ~= false end
SAOJavaBridge.foodSourceItem = function() return __sourceItem end
SAOJavaBridge.foodSourceContainer = function() return __sourceContainer end
SAOJavaBridge.bindWorldStoreAction = function()
    __bindCalls = __bindCalls + 1; return __bindAnswer
end
SAOJavaBridge.bindWorldSourceAction = function()
    __bindCalls = __bindCalls + 1; return __bindAnswer
end
SAOJavaBridge.worldSourceActionOriginContainer = function() return __originContainer end
SAOJavaBridge.grantXP = function(self,body,perk,amount)
    __xpCalls = __xpCalls + 1; __xpPerk = perk; __xpAmount = amount
end
'''


def _dependencies():
    # Border 179 imports this module; defer its reciprocal fixture import.
    import source_use_test as source
    import provisioning_transfer_cases as transfers
    return source, transfers


def _prelude(source, transfers):
    values = dict(transfers.SNAPSHOTS)
    values.update(store_row=transfers.transfer_row(),
                  acquire_row=transfers.transfer_row("acquire"),
                  anchor_accessible=transfers.SNAPSHOTS["acquire_pre"].replace(
                      "access=unknown", "access=accessible", 1))
    encoded = "\n".join(f"__{key} = {json.dumps(value)}" for key, value in values.items())
    return source.ACTION_PRELUDE + "\n" + ADAPTERS + "\n" + encoded


def _run(work, source, transfers, overrides=None):
    overrides = overrides or {}
    prelude = work / "prelude.lua"
    prelude.write_text(_prelude(source, transfers), encoding="utf-8")
    chunks = [prelude]
    for path in (source.WORLD, source.NEEDS, source.SOURCE_USE,
                 source.CONTROLLER, CAPTURE):
        text = overrides.get(path.name)
        if text is not None:
            destination = work / path.name
            destination.write_text(text, encoding="utf-8")
            chunks.append(destination)
        else:
            chunks.append(path)
    probe = work / "cases.lua"
    probe.write_text("__lifecycleResult = " + CASES.read_text(encoding="utf-8"),
                     encoding="utf-8")
    chunks.append(probe)
    # Load the real producer after adapter-based lifecycle coverage. These
    # cases cannot accidentally exercise the earlier perception test double.
    for path in (PERCEPTION, ATTACHMENT):
        text = overrides.get(path.name)
        if text is not None:
            destination = work / path.name
            destination.write_text(text, encoding="utf-8")
            chunks.append(destination)
        else:
            chunks.append(path)
    anchor_probe = work / "perception-cases.lua"
    anchor_probe.write_text("__productionPerceptionCases = true\n"
        "__lifecycleResult = __lifecycleResult .. '|' .. "
        + CASES.read_text(encoding="utf-8"), encoding="utf-8")
    chunks.append(anchor_probe)
    done = subprocess.run([str(source.JDK / "java.exe"), "-cp", f"{source.PZ};.",
        "LuaRun", *map(str, chunks), "--", "__lifecycleResult"],
        cwd=work, capture_output=True, text=True, timeout=120)
    detail = (done.stdout or "") + (done.stderr or "")
    lines = (done.stdout or "").strip().splitlines()
    value = lines[-1][6:] if lines and lines[-1].startswith("VALUE ") else ""
    checks = dict(re.findall(r"([a-z0-9_]+)=(true|false)", value))
    return checks, detail


def _compile(work, source):
    shutil.copy2(source.STDLIB, work / "stdlib.lua")
    compiled = subprocess.run([str(source.JDK / "javac.exe"), "-cp", str(source.PZ),
        "-d", str(work), str(source.RUNNER)], capture_output=True, text=True, timeout=120)
    if compiled.returncode:
        raise RuntimeError((compiled.stderr or compiled.stdout)[-2000:])


def run_cases(overrides=None):
    source, transfers = _dependencies()
    with tempfile.TemporaryDirectory(prefix="sao-transfer-lifecycle-") as temporary:
        work = pathlib.Path(temporary)
        _compile(work, source)
        return _run(work, source, transfers, overrides)


MUTATIONS = (
    ("authority-at-transfer", "SAO_Needs.lua",
     "if not self:isValid() then self.dontAdd = true; return end", "if false then return end",
     "standing_revocation_prevents_mutation"),
    ("performed-holder-proof", "SAO_SourceUse.lua",
     'if state == "TRANSFERRED" then', 'if state == "TRANSFERRED" or state == "CARRIED" then',
     "queue_without_move_releases"),
    ("work-credit-idempotence", "SAO_Controller.lua",
     'if not record or order <= (tonumber(record.provisioningCreditOrder) or 0) then',
     'if not record then', "completed_work_credit_once"),
    ("transfer-capture-binding", "decision_capture.lua",
     'if reservation then event.reservationId = reservation.id',
     'if reservation then event.unboundReservationId = reservation.id',
     "capture_transfer_bound"),
    ("inspection-anchor-geometry", "SAO_Perception.lua",
     "belief.cx, belief.cy, belief.z = place.cx, place.cy, place.z",
     "belief.x, belief.y, belief.z = place.cx, place.cy, place.z",
     "production_inspection_geometry"),
    ("inspection-social-separation", "SAO_Perception.lua",
     "if not belief.sourceId then places[key] = belief end",
     "if true then places[key] = belief end",
     "production_inspection_no_attachment"),
)


def main():
    source, transfers = _dependencies()
    if not all(path.is_file() for path in (source.PZ, source.STDLIB,
            source.JDK / "java.exe", source.JDK / "javac.exe")):
        print("Provisioning lifecycle SKIPPED: installed game VM or JDK absent")
        return 0
    paths = {path.name: path for path in (source.NEEDS, source.SOURCE_USE,
                                        source.CONTROLLER, source.WORLD,
                                        CAPTURE, PERCEPTION)}
    with tempfile.TemporaryDirectory(prefix="sao-transfer-lifecycle-") as temporary:
        work = pathlib.Path(temporary)
        _compile(work, source)
        checks, detail = _run(work, source, transfers)
        failed = sorted(name for name, value in checks.items() if value != "true")
        if set(checks) != EXPECTED or failed:
            print(f"FAIL provisioning lifecycle missing={sorted(EXPECTED-set(checks))} "
                  f"extra={sorted(set(checks)-EXPECTED)} failed={failed}")
            print(detail[-2500:])
            return 1
        print(f"PASS {len(checks)} production provisioning lifecycle/capture cases")
        for name, filename, before, after, expected in MUTATIONS:
            text = paths[filename].read_text(encoding="utf-8")
            if text.count(before) != 1:
                print(f"FAIL lifecycle control anchor count: {name}")
                return 1
            altered, detail = _run(work, source, transfers,
                                   {filename: text.replace(before, after, 1)})
            if set(altered) != EXPECTED or altered.get(expected) != "false":
                print(f"FAIL lifecycle mutation {name} did not flip {expected}")
                print(detail[-2500:])
                return 1
            print(f"PASS lifecycle mutation {name}: {expected}=false")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
