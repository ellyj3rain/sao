#!/usr/bin/env python3
r"""Border 179 - private observation becomes exact performed native use.

The shipped WorldSources and SourceUse lifecycle runs inside PZ's Kahlua VM.
Behavior cases distinguish observation from access, drive both timed-action
legs, exercise interruption/reload/refusal/conflict recovery and verify ordered
immutable result delivery. Static call/form anchors cover the wider Controller,
Body and Dormant wiring; they are reported as anchors, not behavioral controls.
Installed engine APIs are checked separately.
"""
import json
import pathlib
import re
import shutil
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
WORLD = ROOT / "mod/42.20/media/lua/shared/SAO_WorldSources.lua"
SOURCE_USE = ROOT / "mod/42.20/media/lua/client/SAO_SourceUse.lua"
CROSSED_TRANSFER = ROOT / "mod/42.20/media/lua/client/SAO_CrossedTransfer.lua"
CONTROLLER = ROOT / "mod/42.20/media/lua/client/SAO_Controller.lua"
BODY = ROOT / "mod/42.20/media/lua/client/SAO_Body.lua"
DORMANT = ROOT / "mod/42.20/media/lua/client/SAO_DormantPopulation.lua"
NEEDS = ROOT / "mod/42.20/media/lua/client/SAO_Needs.lua"
STANDING = ROOT / "mod/42.20/media/lua/shared/SAO_Standing.lua"
JAVA = ROOT / "java/src/com/sao/engine/SAOWorldSources.java"
NEEDS_JAVA = ROOT / "java/src/com/sao/engine/SAONeeds.java"
BRIDGE = ROOT / "java/src/com/sao/bridge/SAOBridge.java"
RUNNER = ROOT / "tools/luacheck/LuaRun.java"
OUT = ROOT / "java/out/luacheck"
JAR = ROOT / "mod/42.20/media/java/SAO.jar"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"


def snapshot(cx, cy, revision, sources):
    lines = [
        f"H|protocol=SAOWS1|status=OBSERVED|detail=|mode=test|cx={cx}"
        f"|cy={cy}|revision={revision}|sources={len(sources)}"
    ]
    for source in sources:
        quantities = "".join(
            f"|q:{key}={value:.6f}"
            for key, value in source.get("quantities", {}).items())
        lines.append(
            "S|id={id}|fp={fp}|rev={rev}|kind={kind}|x={x}|y={y}|z=0"
            "|building={building}|explored=1|state={state}|access=unknown"
            "|container=counter{quantities}".format(
                id=source["id"], fp=source["fp"], rev=source["rev"],
                kind=source.get("kind", "container"), x=source["x"],
                y=source["y"], building=source["building"],
                state=source.get("state", "available"),
                quantities=quantities))
        for item in source.get("items", []):
            lines.append(
                "I|source={source}|id={id}|type={type}|uses=1"
                "|amount={amount:.6f}|fluid={fluid}|poison=0|rotten=0"
                "|cats={cats}".format(source=source["id"], id=item["id"],
                    type=item["type"], amount=item["amount"],
                    fluid=item.get("fluid", ""), cats=item["cats"]))
    return "\n".join(lines + ["E", ""])


def source(source_id, fp, rev, x, y, building, item_id, item_type,
           category="food", amount=0.0, kind="container"):
    return {"id": source_id, "fp": fp, "rev": rev, "kind": kind,
            "x": x, "y": y, "building": building,
            "quantities": {category: amount if category == "water" else 1},
            "items": [{"id": item_id, "type": item_type, "amount": amount,
                       "fluid": "Water" if category == "water" else "",
                       "cats": category}]}


FOOD = source("C:food-token:0", "food-fp", "food-r1", 8, 8, 42,
              101, "Base.Apple")
FOOD_POST = dict(FOOD, rev="food-r2", state="spent", quantities={}, items=[])
WATER = source("C:water-token:0", "water-fp", "water-r1", 16, 8, 43,
               102, "Base.WaterBottle", "water", 1.0)
WATER_POST = dict(WATER, rev="water-r2", state="spent", quantities={}, items=[])
RELOAD = source("C:reload-token:0", "reload-fp", "reload-r1", 24, 8, 44,
                103, "Base.Banana")
CHANGED = source("C:changed-token:0", "changed-fp", "changed-r1", 32, 8, 45,
                 104, "Base.Orange")
CHANGED_POST = source("C:changed-token:0", "changed-fp", "changed-r2", 32, 8,
                      45, 104, "Base.Orange")
GROUND = source("G:ground-token", "ground-fp", "ground-r1", 40, 8, 46,
                105, "Base.Pear", kind="ground")
VEHICLE = source("V:77:2", "vehicle-fp", "vehicle-r1", 48, 8, -1,
                 106, "Base.CannedBeans", kind="vehicle")
DUO = {
    "id": "C:duo-token:0", "fp": "duo-fp", "rev": "duo-r1",
    "kind": "container", "x": 64, "y": 8, "building": 50,
    "quantities": {"food": 1, "tools": 1},
    "items": [
        {"id": 201, "type": "Base.Apple", "amount": 0.0, "cats": "food"},
        {"id": 202, "type": "Base.Hammer", "amount": 0.0, "cats": "tools"},
    ],
}
DUO_POST = dict(DUO, rev="duo-r2", items=[DUO["items"][1]],
                quantities={"tools": 1})
DUO_BAD = dict(DUO, rev="duo-r3", items=[
    {"id": 202, "type": "Base.BallPeenHammer", "amount": 0.0,
     "cats": "tools"}], quantities={"tools": 1})
DUO_RECOVERED = dict(DUO, rev="duo-r4", items=[
    {"id": 202, "type": "Base.BallPeenHammer", "amount": 0.0,
     "cats": "tools"},
    {"id": 203, "type": "Base.Banana", "amount": 0.0,
     "cats": "food"}], quantities={"food": 1, "tools": 1})
VEHICLE_MOVED = dict(VEHICLE, x=56, rev="vehicle-r1")
VEHICLE_OUTSIDE = dict(VEHICLE, x=60, rev="vehicle-r1")
VEHICLE_MOVED_POST = dict(VEHICLE, x=56, rev="vehicle-r2", state="spent",
                          quantities={}, items=[])

SNAPSHOTS = {
    "food": snapshot(1, 1, "food-chunk-1", [FOOD]),
    "food_post": snapshot(1, 1, "food-chunk-2", [FOOD_POST]),
    "water": snapshot(2, 1, "water-chunk-1", [WATER]),
    "water_post": snapshot(2, 1, "water-chunk-2", [WATER_POST]),
    "reload": snapshot(3, 1, "reload-chunk-1", [RELOAD]),
    "changed": snapshot(4, 1, "changed-chunk-1", [CHANGED]),
    "changed_post": snapshot(4, 1, "changed-chunk-2", [CHANGED_POST]),
    "ground": snapshot(5, 1, "ground-chunk-1", [GROUND]),
    "ground_post": snapshot(5, 1, "ground-chunk-2", []),
    "vehicle": snapshot(6, 1, "vehicle-chunk-1", [VEHICLE]),
    "vehicle_moved": snapshot(7, 1, "vehicle-chunk-moved", [VEHICLE_MOVED]),
    "vehicle_outside": snapshot(7, 1, "vehicle-chunk-outside", [VEHICLE_OUTSIDE]),
    "vehicle_moved_post": snapshot(7, 1, "vehicle-chunk-post",
                                   [VEHICLE_MOVED_POST]),
    "vehicle_old_empty": snapshot(6, 1, "vehicle-old-empty", []),
    "duo": snapshot(8, 1, "duo-chunk-1", [DUO]),
    "duo_post": snapshot(8, 1, "duo-chunk-2", [DUO_POST]),
    "duo_bad": snapshot(8, 1, "duo-chunk-3", [DUO_BAD]),
    "duo_recovered": snapshot(8, 1, "duo-chunk-4", [DUO_RECOVERED]),
    "wrong_chunk": snapshot(9, 9, "wrong-chunk", []),
}

PRELUDE = r'''
SAO = { History = { countyHours = function() return 48 end },
        Log = { line = function() end } }
_G.__stores, _G.__handlers = {}, {}
ModData = { getOrCreate = function(key)
    __stores[key] = __stores[key] or {}; return __stores[key]
end }
Events = setmetatable({}, { __index = function(t, key)
    local slot = { Add = function(fn) __handlers[key] = fn end,
        Remove = function() end }
    rawset(t, key, slot); return slot
end })
_G.bodyA, _G.bodyB, _G.bodyC, _G.bodyG, _G.bodyV = {}, {}, {}, {}, {}
_G.__records = {
  a={id="a"}, b={id="b"}, c={id="c"}, d={id="d"},
  g={id="g"}, v={id="v"}, wrong={id="wrong"},
}
_G.__bodies = { a=bodyA, b=bodyB, c=bodyC, g=bodyG, v=bodyV,
                wrong={} }
SAO.Identity = { get = function(id) return __records[tostring(id)] end }
SAO.Body = {
  get = function(id) return __bodies[tostring(id)] end,
  hasRepresentation = function(id) return __bodies[tostring(id)] ~= nil end,
}
SAO.Standing = {
  mayEnterBelieved = function() return true end,
  mayAttemptBelieved = function() return true end,
}
SAO.Perception = { _known = {}, knownPlaces = function(id)
  return SAO.Perception._known[tostring(id)] or {}
end }
_G.__places = {
  [42]={id=42,cx=8,cy=8}, [43]={id=43,cx=16,cy=8},
  [44]={id=44,cx=24,cy=8}, [45]={id=45,cx=32,cy=8},
  [46]={id=46,cx=40,cy=8},
  [47]={id=47,cx=48,cy=8,minX=47,minY=7,maxX=49,maxY=9},
}
SAO.Places = { at = function(x,y)
  for _, p in pairs(__places) do if p.cx == x and p.cy == y then return p end end
end }
'''

PROBE = r'''(function()
  local checks = {}
  local function check(name, value)
    checks[#checks+1] = name .. "=" .. tostring(value and true or false)
  end
  local function apply(text)
    return SAO.WorldSources.applySnapshot(SAO.WorldSources.parse(text))
  end
  apply(%(food)s); apply(%(water)s); apply(%(reload)s)
  apply(%(changed)s); apply(%(ground)s); apply(%(vehicle)s)
  local exact = function(sourceId, revision, category, cx, cy, place)
    local _, _, _, facts = SAO.WorldSources.beliefSnapshot(place)
    return { cx=cx, cy=cy, sources={[category]=true}, sourceAccess={},
      sourceRevision=sourceId .. "@" .. revision, sourceFacts=facts }
  end
  SAO.Perception._known.a = { [42]=exact("C:food-token:0","food-r1","food",8,8,__places[42]) }
  SAO.Perception._known.b = { [42]=exact("C:food-token:0","food-r1","food",8,8,__places[42]),
    [43]=exact("C:water-token:0","water-r1","water",16,8,__places[43]) }
  SAO.Perception._known.c = { [44]=exact("C:reload-token:0","reload-r1","food",24,8,__places[44]) }
  SAO.Perception._known.d = { [42]=exact("C:food-token:0","food-r1","food",8,8,__places[42]) }
  SAO.Perception._known.g = { [46]=exact("G:ground-token","ground-r1","food",40,8,__places[46]) }
  SAO.Perception._known.v = { [45]=exact("C:changed-token:0","changed-r1","food",32,8,__places[45]) }
  SAO.Perception._known.wrong = {
    [42]=exact("C:food-token:0","not-the-revision","food",8,8,__places[42]) }

  check("observed_not_accessible",
    SAO.WorldSources.nearestObserved("a",0,0,"food",100) ~= nil
    and SAO.WorldSources.nearestBelieved("a",0,0,"food",100) == nil)
  local vehicleOffers = SAO.WorldSources.observedAt(__places[47])
  local _, vehicleRevisions = SAO.WorldSources.beliefSnapshot(__places[47])
  check("vehicle_in_place_observation", vehicleOffers.food == 1
    and string.find(vehicleRevisions,"V:77:2@vehicle-r1",1,true) ~= nil)
  local r = SAO.WorldSources.beginAction(__places[42],"food","a",bodyA,1,"standing")
  check("private_exact_begin", r and r.itemId == 101
    and __records.a.worldSourceReservation == r.id)
  local locked = SAO.WorldSources.beginAction(__places[42],"food","b",bodyB,1,"standing")
  check("source_wide_lock", locked == nil)
  local wrong, wrongWhy = SAO.WorldSources.beginAction(
    __places[42],"food","wrong",__bodies.wrong,1,"standing")
  check("private_revision_gate", wrong == nil
    and wrongWhy == "observed-revision-unavailable")
  local dormant, dormantWhy = SAO.WorldSources.beginAction(
    __places[42],"food","d",{},1,"standing")
  check("live_body_gate", dormant == nil and dormantWhy == "no-live-body")

  SAO.WorldSources.prepareActionPre(r.id,"a")
  SAO.WorldSources.markTransferred(r.id,"a")
  SAO.WorldSources.markNative(r.id,"a","completed",1,"native-complete")
  SAO.WorldSources.applySnapshot(SAO.WorldSources.parse(%(food_post)s),r.id)
  SAO.WorldSources.reconcileActionSnapshot(r.id,"a",1,1)
  local receipt = SAO.WorldSources.finishAction(r.id,"a")
  check("completed_exact_once", receipt and receipt.status == "completed"
    and receipt.preRevision == "food-r1" and receipt.postRevision == "food-r2"
    and __records.a.lastFoodDay == 2
    and SAO.WorldSources.finishAction(r.id,"a") == nil)

  local water = SAO.WorldSources.beginAction(__places[43],"water","b",bodyB,1,"standing")
  SAO.WorldSources.prepareActionPre(water.id,"b")
  SAO.WorldSources.markTransferred(water.id,"b")
  SAO.WorldSources.markNative(water.id,"b","interrupted",0.25,"native-partial-stop")
  SAO.WorldSources.applySnapshot(SAO.WorldSources.parse(%(water_post)s),water.id)
  SAO.WorldSources.reconcileActionSnapshot(water.id,"b",2,1)
  local partial = SAO.WorldSources.finishAction(water.id,"b")
  check("partial_without_credit", partial and partial.status == "interrupted"
    and partial.quantity == 0.25 and __records.b.lastWaterDay == nil)

  local reload = SAO.WorldSources.beginAction(__places[44],"food","c",bodyC,1,"standing")
  check("reload_owner_kept", reload and SAO.WorldSources.reconcileReservations() == 0
    and SAO.WorldSources.reservation(reload.id).status == "reserved")
  SAO.WorldSources.release(reload.id,"control")

  local changed = SAO.WorldSources.beginAction(__places[45],"food","v",bodyV,1,"standing")
  SAO.WorldSources.applySnapshot(SAO.WorldSources.parse(%(changed_post)s))
  local changedSource = SAO.WorldSources.source("C:changed-token:0")
  check("revision_change_conflicts", changed and changedSource
    and changedSource.state == "conflicted"
    and changedSource.conflict.reason == "native-revision-changed-during-reservation")
  SAO.WorldSources.failAction(changed.id,"v","revision-changed")

  local ground = SAO.WorldSources.beginAction(__places[46],"food","g",bodyG,1,"standing")
  SAO.WorldSources.prepareActionPre(ground.id,"g")
  SAO.WorldSources.markTransferred(ground.id,"g")
  SAO.WorldSources.markNative(ground.id,"g","completed",1,"native-complete")
  SAO.WorldSources.applySnapshot(SAO.WorldSources.parse(%(ground_post)s),ground.id)
  SAO.WorldSources.reconcileActionSnapshot(ground.id,"g",5,1)
  local groundReceipt = SAO.WorldSources.finishAction(ground.id,"g")
  check("expected_ground_removal", groundReceipt
    and groundReceipt.postRevision == "removed"
    and SAO.WorldSources.source("G:ground-token") == nil)

  return table.concat(checks,"|")
end)()''' % {key: json.dumps(value) for key, value in SNAPSHOTS.items()}

ACTION_PRELUDE = r'''
SAO = { History = {
    countyHours = function() return 48 end,
    ticks = function() return 4800 end,
  }, Log = { line = function() end } }
_G.__stores, _G.__handlers = {}, {}
ModData = { getOrCreate = function(key)
    __stores[key] = __stores[key] or {}; return __stores[key]
end }
Events = setmetatable({}, { __index = function(t, key)
    local slot = { Add = function(fn) __handlers[key] = fn end,
        Remove = function() end }
    rawset(t, key, slot); return slot
end })

local function newBody(x, y)
    local body = { x=x, y=y, z=0 }
    function body:getX() return self.x end
    function body:getY() return self.y end
    function body:getZ() return self.z end
    return body
end
_G.__newBody = newBody
_G.__records, _G.__bodies, _G.__known, _G.__places = {}, {}, {}, {}
SAO.Identity = {
    get = function(id) return __records[tostring(id)] end,
    all = function() return __records end,
}
SAO.Body = {
    get = function(id) return __bodies[tostring(id)] end,
    hasRepresentation = function(id) return __bodies[tostring(id)] ~= nil end,
    active = __bodies,
    foreign = {},
    prepareExternalTransfer = function(rec, body, owner, token)
        if body == nil then return false, "missing-body" end
        __preparedTransfers = (__preparedTransfers or 0) + 1
        rec.bodyTransfer = { owner=owner, token=token }
        return true, "prepared"
    end,
    commitExternalTransfer = function(rec)
        local pending = rec.bodyTransfer
        if not pending then return false, "no-transfer" end
        local body = SAO.Body.active[rec.id]
        SAO.Body.active[rec.id] = nil
        SAO.Body.foreign[rec.id] = body
        rec.bodyOwner, rec.bodyOwnerToken = pending.owner, pending.token
        rec.bodyTransfer = nil
        return true, "transferred"
    end,
}
ZAO = { Controller = { acceptExternal = function() return true end } }
SAO.Places = { at = function(x, y)
    for _, place in pairs(__places) do
        if place.cx == x and place.cy == y then return place end
    end
end }
SAO.Perception = {
    knownPlaces = function(id) return __known[tostring(id)] or {} end,
    learnSource = function(id, place, sourceId)
        __learnedSource = tostring(sourceId)
        local belief = (__known[tostring(id)] or {})[place.id]
        if not belief then return false end
        local fact = SAO.WorldSources.beliefFact(sourceId)
        local belongs = fact and (fact.buildingId == tostring(place.id)
            or (fact.kind == "vehicle" and fact.x >= place.minX
                and fact.x < place.maxX and fact.y >= place.minY
                and fact.y < place.maxY))
        belief.sourceFacts[tostring(sourceId)] = belongs and fact or nil
        if not belongs then __forgotSource = tostring(sourceId) end
        return true
    end,
    forgetSource = function(id, placeId, sourceId)
        __forgotSource = tostring(sourceId)
        local belief = (__known[tostring(id)] or {})[placeId]
        if belief and belief.sourceFacts then
            belief.sourceFacts[tostring(sourceId)] = nil
        end
        return true
    end,
}
SAO.Standing = {
    mayAttemptBelieved = function() return true end,
    -- C63 asks the final bind whether this exact source belongs to held
    -- group ground. Most C62 cases remain ungrouped; the primary shipped
    -- lifecycle case proves that exact held-ground context reaches its receipt.
    groupOf = function(id)
        return __groupByActor and __groupByActor[tostring(id)] or nil
    end,
    groupClaimOf = function(group)
        return __groupClaims and __groupClaims[tostring(group)] or nil
    end,
    provisioningContextAt = function(id, x, y)
        if __standingStoreUnavailable then return nil, nil end
        local group = __groupByActor and __groupByActor[tostring(id)] or nil
        if not group then return "personal", nil end
        local claim = __groupClaims and __groupClaims[tostring(group)] or nil
        if claim and x >= claim.minX and x <= claim.maxX
            and y >= claim.minY and y <= claim.maxY then
            return "held-group", tostring(group), claim.claimIncarnation
        end
        return "personal", nil
    end,
    mayTakeCurrent = function(id, x, y, admission)
        __standingX, __standingY, __standingAdmission = x, y, admission
        return __standingAllowed ~= false
    end,
}
SAO.Locomotion = {
    order = function(id, body, x, y, z)
        __lastOrder = { id=id, x=x, y=y, z=z }
        return __routeAllowed ~= false
    end,
    cancel = function(id)
        __routeCancels = (__routeCancels or 0) + 1
    end,
}
SAO.Needs = {
    busy = function() return __busy == true end,
    queueVerified = function(action)
        if __queueReject then return false end
        __queued, __busy = action, true
        return true
    end,
    worldSourceTransferAction = function()
        return { kind="transfer" }
    end,
}

ISTimedActionQueue = { clear = function()
    __queueClears = (__queueClears or 0) + 1
    local action = __queued
    __queued, __busy = nil, false
    if action and action.stop then action:stop() end
end }

ISEatFoodAction = {
    new = function(self, character, item, fraction)
        local action = { character=character, item=item,
            fraction=fraction, kind="eat" }
        setmetatable(action, { __index=self }); return action
    end,
    complete = function() return true end,
    stop = function() return true end,
}
ISDrinkFluidAction = {
    new = function(self, character, item, fraction)
        __lastDrinkFraction = fraction
        local action = { character=character, item=item,
            fraction=fraction, kind="drink" }
        setmetatable(action, { __index=self }); return action
    end,
    complete = function() return true end,
    stop = function() return true end,
}
ISGrabItemAction = { new = function(self, character, item)
    return { character=character, item=item, kind="grab" }
end }

SAOJavaBridge = {
    worldSourceActionTarget = function() return __targetAnswer end,
    bindWorldSourceAction = function() return __bindAnswer end,
    worldSourceActionItem = function() return __sourceItem end,
    worldSourceActionContainer = function() return __sourceContainer end,
    worldSourceActionPermissionContainer = function() return __permissionContainer end,
    worldSourceActionWorldItem = function() return __worldItem end,
    carriedWorldSourceItem = function() return __carriedItem end,
    carriedWorldSourceMeasure = function() return __measure end,
    beginWorldSourceUse = function() return __beginAllowed ~= false end,
    finishWorldSourceUse = function()
        if __finishThrows then error("fixture settlement failure") end
        return __finishOutcome
    end,
    observeWorldChunk = function() return __observeText end,
    clearWorldSourceAction = function() __clears = (__clears or 0) + 1 end,
}
'''

ACTION_PROBE = r'''(function()
  local checks = {}
  local STORE = "SurvivorAwareness_WorldSources"
  local function check(name, value)
    checks[#checks+1] = name .. "=" .. tostring(value and true or false)
  end
  local function place(id, x, y, minX, minY, maxX, maxY)
    return { id=id, cx=x, cy=y, minX=minX or x, minY=minY or y,
        maxX=maxX or (x+1), maxY=maxY or (y+1) }
  end
  local function reset(actor, p, category, text)
    __stores[STORE] = { schema=3 }
    __records, __bodies, __known, __places = {}, {}, {}, { [p.id]=p }
    SAO.Body.active, SAO.Body.foreign = __bodies, {}
    __preparedTransfers = 0
    local body = __newBody(p.cx, p.cy)
    __records[actor] = { id=actor }
    __bodies[actor] = body
    SAO.WorldSources.applySnapshot(SAO.WorldSources.parse(text))
    local sources, revision, access, facts =
        SAO.WorldSources.beliefSnapshot(p)
    __known[actor] = { [p.id] = { cx=p.cx, cy=p.cy,
        minX=p.minX, minY=p.minY, maxX=p.maxX, maxY=p.maxY,
        sources=sources, sourceRevision=revision, sourceAccess=access,
        sourceFacts=facts } }
    __targetAnswer = "READY:" .. p.cx .. ":" .. p.cy .. ":0:"
        .. p.cx .. ":" .. p.cy .. ":0"
    __bindAnswer = "BOUND:" .. p.cx .. ":" .. p.cy .. ":0"
    __observeText, __sourceItem = text, { exact=true }
    __sourceContainer, __permissionContainer = {}, {}
    __worldItem, __carriedItem = {}, nil
    __measure, __beginAllowed, __finishOutcome = 1, true,
        "APPLIED:completed:1:native-complete"
    __finishThrows = false
    __routeAllowed, __standingAllowed, __routeCancels = true, true, 0
    __queueReject, __busy, __queued, __queueClears = false, false, nil, 0
    __learnedSource, __forgotSource, __lastDrinkFraction = nil, nil, nil
    __groupByActor, __groupClaims = {}, {}
    return body, facts
  end
  local function toTransfer(actor, body, p, category)
    local began = SAO.SourceUse.begin(actor, body, p, category, "standing")
    local reservation = SAO.WorldSources.reservation(
        __records[actor].worldSourceReservation)
    local first = began and SAO.SourceUse.onMovementDone(
        actor, body, "arrived") or "failed"
    local second = first == "moving" and SAO.SourceUse.onMovementDone(
        actor, body, "arrived") or "failed"
    return reservation, first, second
  end

  -- Schema 2 observation data survives, but its generic lock cannot be
  -- relabeled as an executable C62 action.
  __records.m = { id="m", worldSourceReservation="old-r" }
  __stores[STORE] = { schema=2, sources={ keep={ id="keep" } },
      reservations={ ["old-r"]={ id="old-r", actorId="m",
          sourceId="keep", status="reserved", category="food" } } }
  local kept = SAO.WorldSources.source("keep")
  local migrated = __stores[STORE]
  check("schema2_migration", kept and migrated.schema == 5
      and migrated.reservations["old-r"].status == "released"
      and migrated.results["old-r"].detail == "schema-2-action-incompatible"
      and __records.m.worldSourceReservation == nil)

  -- A maximum-size v2 ledger can contain both historical results and active
  -- observation locks. Migration remains within the v5 save bounds instead
  -- of retaining both complete sets indefinitely.
  __stores[STORE] = { schema=2, results={}, reservations={},
      resultByActor={}, resultCounts={} }
  for i = 1, 2048 do
      local oldId, actor = "old-" .. tostring(i), "old-actor-" .. tostring(i)
      __stores[STORE].results[oldId] = { reservationId=oldId,
          actorId=actor, status="completed", order=i,
          acknowledgements={ provisioning=1 } }
      __stores[STORE].resultByActor[actor] = oldId
      local lockId, lockActor = "lock-" .. tostring(i),
          "lock-actor-" .. tostring(i)
      __stores[STORE].reservations[lockId] = { id=lockId,
          actorId=lockActor, sourceId="source-" .. tostring(i),
          status="reserved", category="food" }
  end
  SAO.WorldSources.source("migration-probe")
  local boundedResults, boundedReservations, stillReserved = 0, 0, false
  for _ in pairs(__stores[STORE].results) do
      boundedResults = boundedResults + 1
  end
  for _, reservation in pairs(__stores[STORE].reservations) do
      boundedReservations = boundedReservations + 1
      if reservation.status == "reserved" then stillReserved = true end
  end
  check("schema2_migration_bounded", __stores[STORE].schema == 5
      and boundedResults <= 2048 and boundedReservations <= 2048
      and not stillReserved)

  __stores[STORE] = { schema=6, sentinel="future-owned" }
  __records.future = { id="future",
      worldSourceReservation="future-reservation" }
  local future = SAO.WorldSources.source("future-probe")
  local futurePending = SAO.WorldSources.pendingActionFor("future")
  local futureExit = SAO.SourceUse.beforeStateChange(
      "future",__newBody(0,0),"IDLE","TRAVEL","future-schema")
  check("future_schema_refused", future == nil
      and __stores[STORE].schema == 6
      and __stores[STORE].sentinel == "future-owned"
      and __stores[STORE].sources == nil and futurePending
      and futurePending.unavailable == true and futureExit == false
      and __records.future.worldSourceReservation == "future-reservation")

  -- Private facts remain compact and a stale actor still attempts the exact
  -- remembered revision; current global state is deferred to arrival.
  local p45 = place(45,32,8,32,8,33,9)
  local staleBody, staleFacts = reset("stale",p45,"food",%(changed)s)
  SAO.WorldSources.applySnapshot(SAO.WorldSources.parse(%(changed_post)s))
  local stale = SAO.WorldSources.beginAction(p45,"food","stale",
      staleBody,1,"standing")
  local staleFact = staleFacts["C:changed-token:0"]
  check("compact_private_stale_attempt", stale and staleFact
      and staleFact.items == nil and staleFact.candidates.food.id == 104)
  SAO.WorldSources.release(stale.id,"fixture")

  -- Execute the shipped SourceUse module through both native action legs and
  -- its exact READY/BOUND protocols.
  local p42 = place(42,8,8,8,8,9,9)
  local body = reset("run",p42,"food",%(food)s)
  __groupByActor.run = "house"
  __groupClaims.house = { minX=8, minY=8, maxX=9, maxY=9,
    claimIncarnation=7 }
  local run, first, second = toTransfer("run",body,p42,"food")
  local transferQueued = second == "using" and __queued.kind == "transfer"
  __carriedItem, __busy, __observeText = __sourceItem, false, %(food_post)s
  local transferTick = SAO.SourceUse.tick("run",body)
  local native = __queued
  __finishOutcome = "APPLIED:completed:1:native-complete"
  native:complete(); __busy = false
  local final = SAO.SourceUse.tick("run",body)
  local runReceipt = __stores[STORE].results[run.id]
  check("shipped_protocol_and_completion", first == "moving"
      and transferQueued and transferTick == "pending" and native.kind == "eat"
      and final == "completed" and runReceipt.status == "completed"
      and runReceipt.provisioningGroup == "house"
      and runReceipt.provisioningContext == "held-group"
      and runReceipt.provisioningClaimIncarnation == 7
      and runReceipt.materialProjectionEnabled == true
      and __learnedSource == "C:food-token:0")

  -- The R9 bridge is deterministic and isolated: provisioning receives
  -- ordered copies, cannot mutate the ledger and may acknowledge repeatedly.
  __stores[STORE].results["fixture-later"] = {
      reservationId="fixture-later", actorId="later", sourceId="fixture",
      status="completed", order=(runReceipt.order or 0)+1,
      acknowledgements={} }
  local delivered = SAO.WorldSources.completedResults("provisioning")
  local refusedConsumer = SAO.WorldSources.completedResults("recognition")
  delivered[1].status = "mutated-copy"
  local firstAck = SAO.WorldSources.acknowledgeResult(
      run.id,"provisioning")
  local repeatAck = SAO.WorldSources.acknowledgeResult(
      run.id,"provisioning")
  local remaining = SAO.WorldSources.completedResults("provisioning")
  check("ordered_isolated_result_delivery", #delivered == 2
      and delivered[1].reservationId == run.id
      and delivered[2].reservationId == "fixture-later"
      and runReceipt.status == "completed" and #refusedConsumer == 0
      and firstAck and repeatAck and #remaining == 1
      and remaining[1].reservationId == "fixture-later")
  SAO.WorldSources.acknowledgeResult("fixture-later","provisioning")

  -- An unavailable Standing store is not an ungrouped actor. The final bind
  -- refuses before the native transfer and publishes no completed receipt.
  local faultBody = reset("context-fault",p42,"food",%(food)s)
  __standingStoreUnavailable = true
  local faultReservation, faultFirst, faultSecond =
      toTransfer("context-fault",faultBody,p42,"food")
  __standingStoreUnavailable = false
  local faultReceipt = __stores[STORE].results[faultReservation.id]
  check("attribution_unavailable_refuses_before_transfer",
      faultFirst == "moving" and faultSecond == "failed"
      and faultReceipt and faultReceipt.status == "conflict"
      and faultReceipt.detail == "provisioning-context-unavailable")

  -- A generic LoadGridsquare/observeAt scan can land after vanilla transfer
  -- and before SourceUse polls it. It must defer to the reservation-owned
  -- exact post scan instead of declaring the actor's own delta concurrent.
  body = reset("observation-race",p42,"food",%(food)s)
  local race = toTransfer("observation-race",body,p42,"food")
  __carriedItem, __busy, __observeText = __sourceItem, false, %(food_post)s
  local autoObserved, autoWhy = SAO.WorldSources.observeChunk(1,1)
  local heldSource = SAO.WorldSources.source("C:food-token:0")
  local raceTransfer = SAO.SourceUse.tick("observation-race",body)
  local raceNative = __queued
  raceNative:complete(); __busy = false
  local raceFinal = SAO.SourceUse.tick("observation-race",body)
  check("generic_observation_defers_to_action", race
      and not autoObserved and autoWhy == "reservation-protected"
      and heldSource and heldSource.revision == "food-r1"
      and raceTransfer == "pending" and raceFinal == "completed"
      and __stores[STORE].conflictBySource["C:food-token:0"] == nil)

  -- The advertised ledger bound is itself deliverable in durable sequence;
  -- no recursive Kahlua sort sits between R9 and its complete input set.
  body = reset("delivery-bound",p42,"food",%(food)s)
  for i = 2048, 1, -1 do
      local receiptId = string.format("bound-%%04d",i)
      __stores[STORE].results[receiptId] = {
          reservationId=receiptId, actorId="bound-actor-" .. tostring(i),
          sourceId="fixture", status="completed", order=i,
          acknowledgements={} }
  end
  local boundedDelivery = SAO.WorldSources.completedResults("provisioning")
  local deliveryOrdered = #boundedDelivery == 2048
  for i = 1, #boundedDelivery do
      if boundedDelivery[i].order ~= i then deliveryOrdered = false break end
  end
  check("max_result_delivery_ordered", deliveryOrdered
      and boundedDelivery[1].reservationId == "bound-0001"
      and boundedDelivery[2048].reservationId == "bound-2048")

  body = reset("capacity",p42,"food",%(food)s)
  for i = 1, 2048 do
      __stores[STORE].results["acked-" .. tostring(i)] = {
          reservationId="acked-" .. tostring(i), actorId="old",
          status="completed", order=i,
          acknowledgements={ provisioning=1 } }
  end
  local afterAckCapacity = SAO.WorldSources.beginAction(
      p42,"food","capacity",body,1,"standing")
  check("acknowledged_results_do_not_block", afterAckCapacity ~= nil)
  if afterAckCapacity then
      SAO.WorldSources.release(afterAckCapacity.id,"fixture")
  end

  -- Threat/deadline after transfer is a zero-use interruption, never an
  -- unspent release.
  body = reset("interrupt",p42,"food",%(food)s)
  local interrupted = toTransfer("interrupt",body,p42,"food")
  __carriedItem, __busy, __observeText = __sourceItem, false, %(food_post)s
  SAO.SourceUse.interrupt("interrupt",body,"threat-interrupted")
  local interruptedReceipt = __stores[STORE].results[interrupted.id]
  check("transfer_interrupt_reconciles", interruptedReceipt
      and interruptedReceipt.status == "interrupted"
      and interruptedReceipt.quantity == 0
      and __records.interrupt.lastFoodDay == nil)

  -- A native-begin refusal after transfer takes the same reconciliation path.
  body = reset("refused",p42,"food",%(food)s)
  local refused = toTransfer("refused",body,p42,"food")
  __carriedItem, __busy, __beginAllowed, __observeText =
      __sourceItem, false, false, %(food_post)s
  SAO.SourceUse.tick("refused",body)
  local refusedReceipt = __stores[STORE].results[refused.id]
  check("native_begin_refusal_reconciles", refusedReceipt
      and refusedReceipt.status == "interrupted"
      and refusedReceipt.detail == "native-snapshot-refused")

  -- Every refusal after exact transfer retains source ownership and awards no
  -- need credit, including measurement and water-empty failures.
  body = reset("measure",p42,"food",%(food)s)
  local measure = toTransfer("measure",body,p42,"food")
  __carriedItem, __busy, __measure, __observeText =
      __sourceItem, false, -1, %(food_post)s
  local measureVerdict = SAO.SourceUse.tick("measure",body)
  local measureReceipt = __stores[STORE].results[measure.id]
  local p43 = place(43,16,8,16,8,17,9)
  body = reset("empty",p43,"water",%(water)s)
  local empty = toTransfer("empty",body,p43,"water")
  __carriedItem, __busy, __measure, __observeText =
      __sourceItem, false, 0, %(water_post)s
  local emptyVerdict = SAO.SourceUse.tick("empty",body)
  local emptyReceipt = __stores[STORE].results[empty.id]
  local emptyCredited = __records.empty.lastWaterDay ~= nil
  body = reset("prechanged",p43,"water",%(water)s)
  local prechanged = toTransfer("prechanged",body,p43,"water")
  __carriedItem, __busy, __measure, __observeText =
      __sourceItem, false, 0.4, %(water_post)s
  local prechangedVerdict = SAO.SourceUse.tick("prechanged",body)
  local prechangedReceipt = __stores[STORE].results[prechanged.id]
  check("post_transfer_refusals_reconcile",
      measureVerdict == "interrupted" and measureReceipt
      and measureReceipt.detail == "native-measure-refused"
      and emptyVerdict == "interrupted" and emptyReceipt
      and emptyReceipt.detail == "native-water-empty"
      and not emptyCredited and prechangedVerdict == "interrupted"
      and prechangedReceipt
      and prechangedReceipt.detail == "native-prestart-measure-changed"
      and __records.prechanged.lastWaterDay == nil)

  -- A malformed or throwing bridge settlement cannot abandon a transferred
  -- source delta or infer successful use.
  body = reset("invalid",p42,"food",%(food)s)
  local invalid = toTransfer("invalid",body,p42,"food")
  __carriedItem, __busy, __observeText = __sourceItem, false, %(food_post)s
  SAO.SourceUse.tick("invalid",body)
  local invalidAction = __queued
  __finishOutcome = "INVALID"
  invalidAction:complete(); __busy = false
  local invalidVerdict = SAO.SourceUse.tick("invalid",body)
  local invalidReceipt = __stores[STORE].results[invalid.id]
  local invalidCredited = __records.invalid.lastFoodDay ~= nil
  body = reset("thrown",p42,"food",%(food)s)
  local thrown = toTransfer("thrown",body,p42,"food")
  __carriedItem, __busy, __observeText = __sourceItem, false, %(food_post)s
  SAO.SourceUse.tick("thrown",body)
  local thrownAction = __queued
  __finishThrows = true
  thrownAction:complete(); __busy = false
  local thrownVerdict = SAO.SourceUse.tick("thrown",body)
  local thrownReceipt = __stores[STORE].results[thrown.id]
  check("settlement_failures_reconcile",
      invalidVerdict == "interrupted" and invalidReceipt
      and invalidReceipt.detail == "native-settlement-invalid"
      and thrownVerdict == "interrupted" and thrownReceipt
      and thrownReceipt.detail == "native-settlement-refused"
      and not invalidCredited
      and __records.thrown.lastFoodDay == nil)

  -- Central state exits preserve one-action ownership. The internal approach
  -- continuation stays live; external travel releases untouched work; combat
  -- after a proved transfer reconciles zero use before it can proceed.
  body = reset("initial-projection",p42,"food",%(food)s)
  SAO.SourceUse.begin("initial-projection",body,p42,"food","standing")
  local initialProjection = SAO.SourceUse.beforeStateChange(
      "initial-projection",body,"IDLE","SOURCEWARD","initial projection")
  local initialPending = SAO.WorldSources.pendingActionFor("initial-projection")
  SAO.SourceUse.interrupt("initial-projection",body,"fixture")
  body = reset("continue",p42,"food",%(food)s)
  toTransfer("continue",body,p42,"food")
  local continuation = SAO.SourceUse.beforeStateChange(
      "continue",body,"SOURCEWARD","SOURCEUSE","continuation")
  local continued = SAO.WorldSources.pendingActionFor("continue")
  SAO.SourceUse.interrupt("continue",body,"fixture")
  body = reset("travel",p42,"food",%(food)s)
  local travel = SAO.SourceUse.begin("travel",body,p42,"food","standing")
  local travelExit = SAO.SourceUse.beforeStateChange(
      "travel",body,"SOURCEWARD","TRAVEL","operator order")
  local travelResult = __stores[STORE].results[
      __stores[STORE].resultByActor.travel]
  body = reset("engage",p42,"food",%(food)s)
  local engage = toTransfer("engage",body,p42,"food")
  __carriedItem, __observeText = __sourceItem, %(food_post)s
  local engageExit = SAO.SourceUse.beforeStateChange(
      "engage",body,"SOURCEUSE","ENGAGE","operator order")
  local engageResult = __stores[STORE].results[engage.id]
  check("state_exits_close_ownership", initialProjection and initialPending
      and initialPending.phase == "approaching-place"
      and continuation and continued and continued.phase == "transferring"
      and travel and travelExit and travelResult.status == "released"
      and engageExit and __queueClears == 1 and engageResult
      and engageResult.status == "interrupted"
      and __records.engage.lastFoodDay == nil)

  -- Public order preflights consult the durable owner even if the controller
  -- label was lost between reservation and state assignment.
  body = reset("idletravel",p42,"food",%(food)s)
  SAO.SourceUse.begin("idletravel",body,p42,"food","standing")
  local idleTravel = SAO.WorldSources.pendingActionFor("idletravel")
  local idleTravelExit = SAO.SourceUse.beforeStateChange(
      "idletravel",body,"IDLE","TRAVEL","operator order")
  local idleTravelReceipt = __stores[STORE].results[idleTravel.id]
  body = reset("idleengage",p42,"food",%(food)s)
  local idleEngage = toTransfer("idleengage",body,p42,"food")
  __carriedItem, __observeText = __sourceItem, %(food_post)s
  local idleEngageExit = SAO.SourceUse.beforeStateChange(
      "idleengage",body,"IDLE","ENGAGE","operator order")
  local idleEngageReceipt = __stores[STORE].results[idleEngage.id]
  check("stale_state_order_preflight", idleTravelExit
      and idleTravelReceipt.status == "released" and idleEngageExit
      and idleEngageReceipt.status == "interrupted"
      and __records.idleengage.lastFoodDay == nil)

  -- Crossed ownership may be requested during either source leg. An unspent
  -- route releases before transfer; a proved physical transfer retains the
  -- durable conversion request while exact post-state reconciliation closes.
  body = reset("crossedroute",p42,"food",%(food)s)
  SAO.SourceUse.begin("crossedroute",body,p42,"food","standing")
  local crossedRoute = SAO.WorldSources.pendingActionFor("crossedroute")
  local crossedRouteOk = SAO.CrossedTransfer.begin(
      "crossedroute",body,"crossed:route",48)
  local crossedRouteReceipt = __stores[STORE].results[crossedRoute.id]
  check("crossed_unspent_releases", crossedRouteOk
      and crossedRouteReceipt.status == "released"
      and __records.crossedroute.bodyOwner == "ZAO"
      and __records.crossedroute.worldSourceReservation == nil
      and __preparedTransfers == 1 and __routeCancels == 1)

  body = reset("crosseduse",p42,"food",%(food)s)
  local crossedUse = toTransfer("crosseduse",body,p42,"food")
  __carriedItem = __sourceItem
  local crossedFirst, crossedWhy = SAO.CrossedTransfer.begin(
      "crosseduse",body,"crossed:use",48)
  local retainedIntent = __records.crosseduse.crossedTransferPending
  __observeText = %(food_post)s
  local crossedRetried = SAO.CrossedTransfer.resumePending()
  local crossedUseReceipt = __stores[STORE].results[crossedUse.id]
  check("crossed_transfer_reconciles", crossedFirst == false
      and crossedWhy == "source-action-pending" and retainedIntent
      and retainedIntent.token == "crossed:use" and crossedRetried
      and crossedUseReceipt.status == "interrupted"
      and crossedUseReceipt.quantity == 0
      and __records.crosseduse.lastFoodDay == nil
      and __records.crosseduse.bodyOwner == "ZAO"
      and __records.crosseduse.crossedTransferPending == nil
      and __queueClears == 1 and __preparedTransfers == 1)

  -- A category with no ratified native consequence is refused before it can
  -- reserve or transfer anything.
  local p50 = place(50,64,8,64,8,65,9)
  body = reset("scope",p50,"tools",%(duo)s)
  local scoped, scopeWhy = SAO.SourceUse.begin(
      "scope",body,p50,"tools","standing")
  check("unsupported_category_untouched", scoped == false
      and scopeWhy == "unsupported-category" and __queued == nil
      and __records.scope.worldSourceReservation == nil
      and SAO.WorldSources.source("C:duo-token:0").revision == "duo-r1")

  -- Literal BOUND is not silently accepted after the bridge protocol gained
  -- current source coordinates.
  body = reset("protocol",p42,"food",%(food)s)
  SAO.SourceUse.begin("protocol",body,p42,"food","standing")
  SAO.SourceUse.onMovementDone("protocol",body,"arrived")
  __bindAnswer = "BOUND"
  local protocolResult = SAO.SourceUse.onMovementDone(
      "protocol",body,"arrived")
  check("bind_protocol_arity", protocolResult == "failed"
      and __queued == nil and __records.protocol.worldSourceReservation == nil)

  -- Resume a partially depleted drink by the remaining absolute amount:
  -- 0.5 target - 0.2 already applied = 0.3; 0.3 / 0.8 current = 0.375.
  body = reset("drink",p43,"water",%(water)s)
  local drink = toTransfer("drink",body,p43,"water")
  __carriedItem, __busy, __measure = __sourceItem, false, 1
  SAO.SourceUse.tick("drink",body)
  __busy, __measure, __queued = false, 0.8, nil
  local resumed = SAO.SourceUse.resume("drink",body)
  check("drink_reload_partition", resumed == "SOURCEUSE"
      and math.abs((__lastDrinkFraction or 0) - 0.375) < 0.0001
      and drink.useBaseline == 1)
  SAO.WorldSources.release(drink.id,"fixture")

  -- Losing the carried item across reload is ambiguity, so it produces no
  -- completed-use credit.
  body = reset("missing",p43,"water",%(water)s)
  local missing = toTransfer("missing",body,p43,"water")
  missing.transferProven, missing.phase = true, "using"
  __carriedItem, __busy, __queued, __observeText = nil, false, nil,
      %(water_post)s
  local missingResume = SAO.SourceUse.resume("missing",body)
  local missingFinal = SAO.SourceUse.tick("missing",body)
  local missingReceipt = __stores[STORE].results[missing.id]
  check("missing_reload_item_no_credit", missingResume == "SOURCEUSE"
      and missingFinal == "interrupted" and missingReceipt.status == "interrupted"
      and __records.missing.lastWaterDay == nil)

  -- Missing and terminal record joins repair themselves rather than freezing
  -- Controller, body teardown and dormant movement forever.
  body = reset("pointer",p42,"food",%(food)s)
  __records.pointer.worldSourceReservation = "missing-reservation"
  local missingPointer = SAO.WorldSources.pendingActionFor("pointer")
  local terminal = SAO.WorldSources.beginAction(
      p42,"food","pointer",body,1,"standing")
  SAO.WorldSources.release(terminal.id,"fixture-terminal")
  __records.pointer.worldSourceReservation = terminal.id
  local terminalPointer = SAO.WorldSources.pendingActionFor("pointer")
  local repairs = 0
  for _ in pairs(__stores[STORE].pointerRepairs) do repairs = repairs + 1 end
  check("stale_pointer_repairs", missingPointer == nil
      and terminalPointer == nil
      and __records.pointer.worldSourceReservation == nil and repairs == 2)

  -- Any applied chunk is insufficient; only the exact expected source delta
  -- closes. A concurrent unrelated item change conflicts.
  body = reset("exact",p50,"food",%(duo)s)
  local exact = SAO.WorldSources.beginAction(p50,"food","exact",body,1,"standing")
  SAO.WorldSources.prepareActionPre(exact.id,"exact")
  SAO.WorldSources.markTransferred(exact.id,"exact")
  SAO.WorldSources.markNative(exact.id,"exact","completed",1,"native-complete")
  SAO.WorldSources.applySnapshot(SAO.WorldSources.parse(%(wrong_chunk)s),exact.id)
  local wrongAccepted = SAO.WorldSources.reconcileActionSnapshot(
      exact.id,"exact",9,9)
  SAO.WorldSources.applySnapshot(SAO.WorldSources.parse(%(duo_post)s),exact.id)
  local exactAccepted = SAO.WorldSources.reconcileActionSnapshot(
      exact.id,"exact",8,1)
  check("exact_post_chunk_required", wrongAccepted == false
      and exactAccepted == true and SAO.WorldSources.finishAction(
          exact.id,"exact").status == "completed")

  body = reset("concurrent",p50,"food",%(duo)s)
  local concurrent = SAO.WorldSources.beginAction(
      p50,"food","concurrent",body,1,"standing")
  SAO.WorldSources.prepareActionPre(concurrent.id,"concurrent")
  SAO.WorldSources.markTransferred(concurrent.id,"concurrent")
  SAO.WorldSources.markNative(concurrent.id,"concurrent","completed",1,
      "native-complete")
  SAO.WorldSources.applySnapshot(SAO.WorldSources.parse(%(duo_bad)s),concurrent.id)
  local concurrentAccepted, concurrentWhy =
      SAO.WorldSources.reconcileActionSnapshot(concurrent.id,"concurrent",8,1)
  check("unrelated_delta_conflicts", concurrentAccepted == false
      and concurrentWhy == "native-source-conflict"
      and SAO.WorldSources.finishAction(concurrent.id,"concurrent") == nil)
  local historical = SAO.WorldSources.source("C:duo-token:0")
  SAO.WorldSources.failAction(concurrent.id,"concurrent",concurrentWhy)
  SAO.WorldSources.applySnapshot(SAO.WorldSources.parse(%(duo_recovered)s))
  local recoveredSource = SAO.WorldSources.source("C:duo-token:0")
  local recoveredBody = __newBody(64,8)
  __records.recovered, __bodies.recovered = { id="recovered" }, recoveredBody
  local recoveredSources, recoveredRevision, recoveredAccess, recoveredFacts =
      SAO.WorldSources.beliefSnapshot(p50)
  __known.recovered = { [p50.id] = { cx=p50.cx, cy=p50.cy,
      minX=p50.minX, minY=p50.minY, maxX=p50.maxX, maxY=p50.maxY,
      sources=recoveredSources, sourceRevision=recoveredRevision,
      sourceAccess=recoveredAccess, sourceFacts=recoveredFacts } }
  local recovered = SAO.WorldSources.beginAction(
      p50,"food","recovered",recoveredBody,1,"standing")
  check("terminal_conflict_recovers", historical and historical.key
      and historical.resolvedAt ~= nil and recoveredSource
      and recoveredSource.revision == "duo-r4" and recovered ~= nil
      and __stores[STORE].conflictBySource["C:duo-token:0"] == nil)
  if recovered then SAO.WorldSources.release(recovered.id,"fixture") end

  -- Vehicle identity migrates chunks only inside the observed half-open place;
  -- the old chunk cannot delete the newer observation.
  local p47 = place(47,48,8,47,7,60,10)
  body = reset("vehicle",p47,"food",%(vehicle)s)
  local vehicle = SAO.WorldSources.beginAction(
      p47,"food","vehicle",body,1,"standing")
  vehicle.currentSourceX, vehicle.currentSourceY = 56, 8
  SAO.WorldSources.applySnapshot(SAO.WorldSources.parse(%(vehicle_moved)s),
      vehicle.id)
  for i = 1, 260 do
      local cx = 100 + i
      local emptyChunk = "H|protocol=SAOWS1|status=OBSERVED|detail="
          .. "|mode=test|cx=" .. tostring(cx)
          .. "|cy=99|revision=compact-" .. tostring(i)
          .. "|sources=0\nE\n"
      SAO.WorldSources.applySnapshot(SAO.WorldSources.parse(emptyChunk))
  end
  local movedChunkProtected = __stores[STORE].chunks["7:1"] ~= nil
      and SAO.WorldSources.source("V:77:2") ~= nil
  SAO.WorldSources.prepareActionPre(vehicle.id,"vehicle")
  SAO.WorldSources.markTransferred(vehicle.id,"vehicle")
  SAO.WorldSources.markNative(vehicle.id,"vehicle","completed",1,
      "native-complete")
  SAO.WorldSources.applySnapshot(SAO.WorldSources.parse(%(vehicle_moved_post)s),
      vehicle.id)
  local vehicleFresh = SAO.WorldSources.reconcileActionSnapshot(
      vehicle.id,"vehicle",7,1)
  local vehicleReceipt = vehicleFresh and SAO.WorldSources.finishAction(
      vehicle.id,"vehicle") or nil
  SAO.WorldSources.applySnapshot(SAO.WorldSources.parse(%(vehicle_old_empty)s))
  local vehicleSource = SAO.WorldSources.source("V:77:2")
  check("vehicle_chunk_migrates", vehicleReceipt
      and vehicleReceipt.status == "completed" and vehicleSource
      and vehicleSource.state ~= "conflicted" and vehicleSource.chunkX == 7
      and movedChunkProtected)

  body = reset("outside",p47,"food",%(vehicle)s)
  __targetAnswer = "READY:59:8:0:60:8:0"
  __observeText = %(vehicle_outside)s
  SAO.SourceUse.begin("outside",body,p47,"food","standing")
  local outside = SAO.SourceUse.onMovementDone("outside",body,"arrived")
  check("vehicle_place_boundary", outside == "failed"
      and __forgotSource == "V:77:2")

  return table.concat(checks,"|")
end)()''' % {key: json.dumps(value) for key, value in SNAPSHOTS.items()}

ACTION_EXPECTED = {
    "schema2_migration", "schema2_migration_bounded",
    "future_schema_refused", "compact_private_stale_attempt",
    "shipped_protocol_and_completion",
    "attribution_unavailable_refuses_before_transfer",
    "transfer_interrupt_reconciles",
    "ordered_isolated_result_delivery", "native_begin_refusal_reconciles",
    "generic_observation_defers_to_action",
    "max_result_delivery_ordered",
    "acknowledged_results_do_not_block",
    "post_transfer_refusals_reconcile", "settlement_failures_reconcile",
    "state_exits_close_ownership", "stale_state_order_preflight",
    "crossed_unspent_releases",
    "crossed_transfer_reconciles", "unsupported_category_untouched",
    "bind_protocol_arity",
    "drink_reload_partition", "missing_reload_item_no_credit",
    "stale_pointer_repairs",
    "exact_post_chunk_required", "unrelated_delta_conflicts",
    "terminal_conflict_recovers",
    "vehicle_chunk_migrates", "vehicle_place_boundary",
}

EXPECTED = {"observed_not_accessible", "vehicle_in_place_observation",
            "private_exact_begin", "source_wide_lock",
            "private_revision_gate", "live_body_gate", "completed_exact_once",
            "partial_without_credit", "reload_owner_kept",
            "revision_change_conflicts", "expected_ground_removal"}


def kahlua_probe():
    OUT.mkdir(parents=True, exist_ok=True)
    compiled = subprocess.run(
        [str(JDK / "javac.exe"), "-cp", str(PZ), "-d", str(OUT), str(RUNNER)],
        capture_output=True, text=True, timeout=300)
    if compiled.returncode:
        return None, (compiled.stderr or compiled.stdout)
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(STDLIB, work / "stdlib.lua")
        for cls in OUT.glob("LuaRun*.class"):
            shutil.copy2(cls, work / cls.name)
        prelude = work / "prelude.lua"
        prelude.write_text(PRELUDE, encoding="utf-8")
        done = subprocess.run(
            [str(JDK / "java.exe"), "-cp", f"{PZ};.", "LuaRun",
             str(prelude), str(WORLD), "--", PROBE], cwd=work,
            capture_output=True, text=True, timeout=300)
    output = (done.stdout or "") + (done.stderr or "")
    lines = (done.stdout or "").strip().splitlines()
    value = lines[-1][6:] if lines and lines[-1].startswith("VALUE ") else None
    return value, output


def action_probe():
    OUT.mkdir(parents=True, exist_ok=True)
    compiled = subprocess.run(
        [str(JDK / "javac.exe"), "-cp", str(PZ), "-d", str(OUT), str(RUNNER)],
        capture_output=True, text=True, timeout=300)
    if compiled.returncode:
        return None, (compiled.stderr or compiled.stdout)
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(STDLIB, work / "stdlib.lua")
        for cls in OUT.glob("LuaRun*.class"):
            shutil.copy2(cls, work / cls.name)
        prelude = work / "action-prelude.lua"
        prelude.write_text(ACTION_PRELUDE, encoding="utf-8")
        probe_chunk = work / "action-probe.lua"
        probe_chunk.write_text("__actionResult = " + ACTION_PROBE,
                               encoding="utf-8")
        done = subprocess.run(
            [str(JDK / "java.exe"), "-cp", f"{PZ};.", "LuaRun",
             str(prelude), str(WORLD), str(SOURCE_USE),
             str(CROSSED_TRANSFER), str(probe_chunk),
             "--", "__actionResult"],
            cwd=work, capture_output=True, text=True, timeout=300)
    output = (done.stdout or "") + (done.stderr or "")
    lines = (done.stdout or "").strip().splitlines()
    value = lines[-1][6:] if lines and lines[-1].startswith("VALUE ") else None
    return value, output


def production_contract(texts):
    (world, use, crossed, controller, body, dormant, needs, standing,
     java, needs_java, bridge) = texts
    required = [
        (world, "live ~= body"),
        (world, "beliefHasRevision(belief, id, source.revision)"),
        (world, "not pendingFor(value, id, nil)"),
        (world, "expectedActionPost"),
        (world, "prepareActionPre"),
        (world, "reconcileActionSnapshot"),
        (world, "schema-2-action-incompatible"),
        (world, "legacy-unattributed"),
        (world, "provisioningClaimIncarnation ="),
        (world, "function WS.pendingActionFor"),
        (world, 'category ~= "food" and category ~= "water"'),
        (world, "function WS.completedResults(consumer)"),
        (world, 'receipt.status == "completed"'),
        (use, "carriedWorldSourceItem"),
        (use, "carriedWorldSourceMeasure"),
        (use, "markTransferred"),
        (use, "^BOUND:(%-?%d+)"),
        (use, "vehicle-left-observed-place"),
        (use, "SAO.Perception.learnSource"),
        (use, "ISEatFoodAction:complete"),
        (use, "ISDrinkFluidAction:stop"),
        (use, "worldSourceActionPermissionContainer"),
        (use, "mayTakeCurrent"),
        (use, "provisioningContextAt"),
        (use, "reservation.provisioningClaimIncarnation"),
        (use, "function SU.beforeStateChange"),
        (use, "function SU.closeForOwnershipTransfer"),
        (use, "function SU.runtimeState"),
        (crossed, "SAO.SourceUse.closeForOwnershipTransfer"),
        (controller, 'SOURCEUSE = "need"'),
        (controller, "SAO.SourceUse.interrupt"),
        (controller, "SAO.SourceUse.beforeStateChange"),
        (controller, "SAO.SourceUse.runtimeState(pendingSource)"),
        (controller, "selectedThreat("),
        (controller, "SAO.CrossedTransfer.resumePending"),
        (body, "SAO.WorldSources.pendingActionFor(id)"),
        (dormant, "SAO.WorldSources.pendingActionFor(id)"),
        (needs, "containerAccessibleNow"),
        (standing, "function S.mayTakeCurrent"),
        (java, "SAONeeds.containerAccessibleNow(shell"),
        (java, "findItem(shell == null ? null : shell.getInventory()"),
        (java, "getSquareForArea(part.getArea())"),
        (java, 'return "BOUND:"'),
        (needs_java, "vehicle.getSquareForArea(area)"),
        (bridge, "SAOWorldSources.resetRuntimeForWorld"),
    ]
    return all(fragment in text for text, fragment in required)


def contract_anchor_probe():
    paths = [WORLD, SOURCE_USE, CROSSED_TRANSFER, CONTROLLER, BODY, DORMANT,
             NEEDS, STANDING, JAVA, NEEDS_JAVA, BRIDGE]
    baseline = tuple(path.read_text(encoding="utf-8") for path in paths)
    if not production_contract(baseline):
        return False, "baseline production contract is incomplete"
    controls = [
        (0, "live ~= body", "false"),
        (0, "beliefHasRevision(belief, id, source.revision)", "true"),
        (0, "not pendingFor(value, id, nil)", "true"),
        (0, "expectedActionPost", "acceptAnyActionPost"),
        (0, "prepareActionPre", "skipActionPre"),
        (0, "reconcileActionSnapshot", "acceptAnySnapshot"),
        (0, "function WS.pendingActionFor", "function WS.uncheckedActionFor"),
        (0, 'category ~= "food" and category ~= "water"', "false"),
        (0, "function WS.completedResults(consumer)",
         "function WS.mutableResults(consumer)"),
        (1, "carriedWorldSourceItem", "carriedAnyItem"),
        (1, "carriedWorldSourceMeasure", "guessedWorldSourceMeasure"),
        (1, "markTransferred", "assumeTransferred"),
        (1, "ISEatFoodAction:complete", "ISEatFoodAction:finish"),
        (1, "ISDrinkFluidAction:stop", "ISDrinkFluidAction:halt"),
        (1, "worldSourceActionPermissionContainer", "worldSourceActionContainer"),
        (1, "mayTakeCurrent", "mayTakeRemembered"),
        (1, "provisioningContextAt", "guessProvisioningContext"),
        (1, "reservation.provisioningClaimIncarnation",
         "reservation.missingClaimIncarnation"),
        (1, "function SU.beforeStateChange", "function SU.ignoreStateChange"),
        (1, "function SU.closeForOwnershipTransfer",
         "function SU.abandonForOwnershipTransfer"),
        (1, "function SU.runtimeState", "function SU.guessRuntimeState"),
        (2, "SAO.SourceUse.closeForOwnershipTransfer",
         "SAO.SourceUse.detach"),
        (3, 'SOURCEUSE = "need"', 'SOURCEUSE = "errand"'),
        (3, "SAO.SourceUse.beforeStateChange", "SAO.SourceUse.ignoreStateChange"),
        (3, "SAO.SourceUse.runtimeState(pendingSource)",
         "SAO.SourceUse.runtimeState(nil)"),
        (4, "SAO.WorldSources.pendingActionFor(id)",
         "SAO.WorldSources.uncheckedActionFor(id)"),
        (5, "SAO.WorldSources.pendingActionFor(id)",
         "SAO.WorldSources.uncheckedActionFor(id)"),
        (6, "containerAccessibleNow", "containerWasAccessible"),
        (7, "function S.mayTakeCurrent", "function S.mayTakeRemembered"),
        (8, "SAONeeds.containerAccessibleNow(shell", "SAONeeds.containerWasAccessibleNow(shell"),
        (8, "findItem(shell == null ? null : shell.getInventory()", "findAnyItem(shell == null ? null : shell.getInventory()"),
        (8, "getSquareForArea(part.getArea())", "getSquare()"),
        (9, "vehicle.getSquareForArea(area)", "vehicle.getSquare()"),
        (10, "SAOWorldSources.resetRuntimeForWorld", "SAOWorldSources.keepRuntimeForWorld"),
    ]
    for index, old, new in controls:
        mutated = list(baseline)
        if old not in mutated[index]:
            return False, f"control anchor missing: {old}"
        mutated[index] = mutated[index].replace(old, new)
        if production_contract(tuple(mutated)):
            return False, f"ANCHOR REMOVAL SURVIVED: {old}"
    return True, f"{len(controls)} required call/form anchors present"


def engine_probe():
    if not JAR.is_file():
        return False, "shipped SAO.jar missing"
    OUT.mkdir(parents=True, exist_ok=True)
    vehicle_probe = ROOT / "tools/luacheck/VehicleAccessTargetProbe.java"
    compiled = subprocess.run(
        [str(JDK / "javac.exe"), "-cp", f"{JAR};{PZ}", "-d", str(OUT),
         str(vehicle_probe)], capture_output=True, text=True, timeout=120)
    if compiled.returncode:
        return False, (compiled.stderr or compiled.stdout)[:500]
    selected = subprocess.run(
        [str(JDK / "java.exe"), "-cp", f"{JAR};{PZ};{OUT}",
         "VehicleAccessTargetProbe"], capture_output=True, text=True,
        timeout=120)
    if selected.returncode or "PASS origin-vs-part-area" not in selected.stdout:
        return False, (selected.stderr or selected.stdout)[:500]
    commands = [
        [str(JDK / "javap.exe"), "-classpath", str(JAR),
         "com.sao.engine.SAOWorldSources"],
        [str(JDK / "javap.exe"), "-classpath", str(JAR),
         "com.sao.bridge.SAOBridge"],
        [str(JDK / "javap.exe"), "-classpath", str(PZ),
         "zombie.iso.IsoGridSquare"],
        [str(JDK / "javap.exe"), "-classpath", str(PZ),
         "zombie.vehicles.BaseVehicle"],
    ]
    outputs = []
    for command in commands:
        done = subprocess.run(command, capture_output=True, text=True, timeout=120)
        if done.returncode:
            return False, (done.stderr or done.stdout)[:500]
        outputs.append(done.stdout or "")
    required = [
        (outputs[0], "actionTarget"), (outputs[0], "bindAction"),
        (outputs[0], "carriedActionMeasure"),
        (outputs[0], "beginUse"), (outputs[0], "finishUse"),
        (outputs[1], "carriedWorldSourceMeasure"),
        (outputs[1], "beginWorldSourceUse"),
        (outputs[2], "isFree(boolean)"), (outputs[2], "isSomethingTo"),
        (outputs[3], "canAccessContainer"),
        (outputs[3], "getSquareForArea"),
    ]
    missing = [needle for text, needle in required if needle not in text]
    return not missing, "missing=" + repr(missing)


def main():
    print("=" * 74)
    print("PRIVATE SOURCE OBSERVATION BECOMES PERFORMED NATIVE USE")
    print("=" * 74)
    repository_inputs = [
        WORLD, SOURCE_USE, CROSSED_TRANSFER, CONTROLLER, BODY, DORMANT,
        NEEDS, STANDING, JAVA, NEEDS_JAVA, BRIDGE, RUNNER, JAR,
        ROOT / "tools/luacheck/VehicleAccessTargetProbe.java",
    ]
    missing = [path for path in repository_inputs if not path.is_file()]
    if missing:
        print("  FAULT: repository input absent: " + ", ".join(
            str(path.relative_to(ROOT)) for path in missing))
        return 1
    installed_inputs = [PZ, STDLIB, JDK / "java.exe", JDK / "javac.exe",
                        JDK / "javap.exe"]
    if not all(path.is_file() for path in installed_inputs):
        print("Border 179 SKIPPED: installed game VM or JDK absent")
        return 0
    value, detail = kahlua_probe()
    found, failed = set(), []
    if value:
        for name, raw in re.findall(r"([a-z_]+)=(true|false)", value):
            found.add(name)
            if raw != "true":
                failed.append(name)
    ledger_ok = found == EXPECTED and not failed
    action_value, action_detail = action_probe()
    action_found, action_failed = set(), []
    if action_value:
        for name, raw in re.findall(r"([a-z0-9_]+)=(true|false)", action_value):
            action_found.add(name)
            if raw != "true":
                action_failed.append(name)
    action_ok = action_found == ACTION_EXPECTED and not action_failed
    runtime_ok = ledger_ok and action_ok
    anchors_ok, anchors_detail = contract_anchor_probe()
    engine_ok, engine_detail = engine_probe()
    print(f"  durable ledger: {'PASS' if ledger_ok else 'FAIL'}")
    print(f"  shipped action lifecycle: {'PASS' if action_ok else 'FAIL'}")
    print(f"  static contract anchors: {'PASS' if anchors_ok else 'FAIL'}"
          f" ({anchors_detail})")
    print(f"  installed engine seam: {'PASS' if engine_ok else 'FAIL'}")
    if not ledger_ok:
        print(f"  FAULT: missing={sorted(EXPECTED-found)} failed={failed} value={value!r}")
        print("  " + detail[-1000:].replace("\n", " "))
    if not action_ok:
        print("  FAULT: action missing="
              f"{sorted(ACTION_EXPECTED-action_found)} failed={action_failed} "
              f"value={action_value!r}")
        print("  " + action_detail[-1500:].replace("\n", " "))
    if not engine_ok:
        print("  FAULT: " + engine_detail)
    if runtime_ok and anchors_ok and engine_ok:
        print("  179) exact source access and native use preserve private knowledge,"
              " current permission and revision-bound results")
    return 0 if runtime_ok and anchors_ok and engine_ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
