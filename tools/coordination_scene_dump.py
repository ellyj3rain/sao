#!/usr/bin/env python3
"""Capture production coordination choices from declared headless situations.

The situation catalogue is authored evidence, not sampled gameplay.  It fixes
only source-owned decision-time facts and a split before execution.  Proposal
reception, private appraisal, feasible options, choice, return delivery and the
decision/outcome horizon all run through shipped SAO code.  ZAO-owned people
resolve through the registered ZAO execution adapter and shared Driver.

No expected response appears in the catalogue.  The emitted choice is whatever
the production owners actually form.  Every row remains conditioning-ineligible
until Speakeasy binds an independent task review.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from typing import Any

import county_dump as Dump
import enacted_coordination_test as Border


ROOT = Path(__file__).resolve().parent.parent
LUA = ROOT / "mod/42.20/media/lua"
ZAO_ROOT = ROOT.parent / "zombie-awareness"
ZAO_LUA = ZAO_ROOT / "mod/42.20/media/lua"

GRAPH = LUA / "shared/SAO_GraphPersistence.lua"
INFERENCE = LUA / "shared/SAO_CoordinationInference.lua"
ORGANIZATION = LUA / "shared/SAO_Organization.lua"
COMMUNICATION = LUA / "shared/SAO_Communication.lua"
STANDING = LUA / "shared/SAO_Standing.lua"
COORDINATION = LUA / "shared/SAO_Coordination.lua"
PERCEPTION = LUA / "shared/SAO_Perception.lua"
CONTROLLER = LUA / "client/SAO_Controller.lua"
CAPTURE = ROOT / "tools/sweep/decision_capture.lua"

ZAO_MAINTENANCE = ZAO_LUA / "shared/ZAO_Maintenance.lua"
ZAO_MIND = ZAO_LUA / "shared/ZAO_Mind.lua"
ZAO_DRIVER = ZAO_LUA / "client/ZAO_Driver.lua"
ZAO_AFFLICTED = ZAO_LUA / "client/ZAO_Afflicted.lua"
ZAO_CROSSED = ZAO_LUA / "client/ZAO_Crossed.lua"
ZAO_EXECUTION_OWNER = ZAO_LUA / "shared/ZAO_ExecutionOwner.lua"
ZAO_CONTROLLER = ZAO_LUA / "client/ZAO_Controller.lua"

SCHEMA = "sao-coordination-scene-catalogue"
OUTPUT_SCHEMA = "sao-coordination-scene-dump"


def scene(scene_id: str, split: str, actor_kind: str, *, relationship: float,
          pressure: float, activity: str = "idle", hostile: bool = False,
          destination_known: bool = True, designation: str | None = None,
          pressure_kind: str = "physical") -> dict[str, Any]:
    return {
        "sceneId": scene_id,
        "sourceLineage": f"coordination-scene:{scene_id}",
        "split": split,
        "actorKind": actor_kind,
        "relationship": relationship,
        "hostile": hostile,
        "activity": activity,
        "competingPressure": pressure,
        "pressureKind": pressure_kind,
        "destinationKnown": destination_known,
        "designation": designation,
    }


# Splits are declared before production execution.  There is no expected label
# in this table and the exporter refuses to partition by observed choice.
SCENES = [
    scene("train-survivor-trusted", "train", "survivor",
          relationship=.62, pressure=.12, designation="mechanic"),
    scene("train-afflicted-pressured", "train", "afflicted",
          relationship=.48, pressure=.86),
    scene("train-crossed-occupied", "train", "crossed",
          relationship=.41, pressure=.18, activity="driving",
          pressure_kind="predatory"),
    scene("train-survivor-hostile", "train", "survivor",
          relationship=-.72, pressure=.21, hostile=True),
    scene("train-afflicted-unfamiliar", "train", "afflicted",
          relationship=.04, pressure=.16),
    scene("train-crossed-trusted", "train", "crossed",
          relationship=.54, pressure=.24, pressure_kind="predatory"),
    scene("train-survivor-pressured", "train", "survivor",
          relationship=.50, pressure=.91, designation="forager"),
    scene("train-afflicted-occupied", "train", "afflicted",
          relationship=.58, pressure=.20, activity="acquiring-food"),
    scene("train-crossed-hostile", "train", "crossed",
          relationship=-.61, pressure=.32, hostile=True,
          pressure_kind="predatory"),
    scene("train-survivor-unfamiliar", "train", "survivor",
          relationship=.08, pressure=.09),

    scene("validation-afflicted-trusted", "validation", "afflicted",
          relationship=.37, pressure=.27, designation="carpenter"),
    scene("validation-crossed-pressured", "validation", "crossed",
          relationship=.46, pressure=.83, destination_known=False,
          pressure_kind="predatory"),
    scene("validation-survivor-occupied", "validation", "survivor",
          relationship=.55, pressure=.14, activity="treat"),
    scene("validation-afflicted-hostile", "validation", "afflicted",
          relationship=-.43, pressure=.35, hostile=True),
    scene("validation-crossed-unfamiliar", "validation", "crossed",
          relationship=.02, pressure=.19, pressure_kind="predatory"),

    scene("test-crossed-trusted", "test", "crossed",
          relationship=.33, pressure=.29, designation="metalworker",
          pressure_kind="predatory"),
    scene("test-survivor-pressured", "test", "survivor",
          relationship=.71, pressure=.79),
    scene("test-afflicted-occupied", "test", "afflicted",
          relationship=.44, pressure=.22, activity="feeding"),
    scene("test-crossed-hostile", "test", "crossed",
          relationship=-.51, pressure=.26, hostile=True,
          pressure_kind="predatory"),
    scene("test-survivor-unfamiliar", "test", "survivor",
          relationship=.11, pressure=.17),
]


def canonical(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True,
                      separators=(",", ":")).encode("utf-8")


def digest(value: Any) -> str:
    return hashlib.sha256(canonical(value)).hexdigest()


def indexed_bytes(path: Path) -> bytes:
    """Return the exact Git blob that the evidence source will publish.

    Windows may materialize a tracked LF blob as CRLF in the checkout.  The
    manifest is consumed from an immutable commit, so hashing checkout bytes
    would make the same source unverifiable after publication.  Require the
    working copy to agree with its index entry, then hash that index blob.
    """
    resolved = path.resolve()
    if resolved.is_relative_to(ROOT):
        repository = ROOT
    elif resolved.is_relative_to(ZAO_ROOT):
        repository = ZAO_ROOT
    else:
        raise RuntimeError("source path is outside the sister repositories: "
                           + str(path))
    relative = resolved.relative_to(repository).as_posix()
    clean = subprocess.run(
        ["git", "-C", str(repository), "diff", "--quiet", "--", relative],
        capture_output=True,
    )
    if clean.returncode != 0:
        raise RuntimeError("evidence source differs from Git index: " +
                           source_name(resolved))
    blob = subprocess.run(
        ["git", "-C", str(repository), "show", ":" + relative],
        capture_output=True,
    )
    if blob.returncode != 0:
        detail = blob.stderr.decode("utf-8", errors="replace").strip()
        raise RuntimeError("indexed evidence source unavailable: " +
                           source_name(resolved) + (": " + detail if detail else ""))
    return blob.stdout


def indexed_hash(path: Path) -> str:
    return hashlib.sha256(indexed_bytes(path)).hexdigest()


def lua_value(value: Any) -> str:
    if value is None:
        return "nil"
    if value is True:
        return "true"
    if value is False:
        return "false"
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=True)
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        return repr(value)
    if isinstance(value, list):
        return "{" + ",".join(lua_value(item) for item in value) + "}"
    if isinstance(value, dict):
        return "{" + ",".join(
            "[" + lua_value(str(key)) + "]=" + lua_value(item)
            for key, item in sorted(value.items())) + "}"
    raise TypeError(f"cannot encode Lua value: {type(value).__name__}")


PRELUDE = r'''
local scene = __SCENE__
_G.__now = 100
plainNameOf = function(first, last) return first .. " " .. last end
getSpecificPlayer = function() return nil end
getCell = function() return nil end
instanceof = function(value, kind) return value and value.kind == kind end

local function eventSlot()
  return { Add=function() end, Remove=function() end }
end
Events = setmetatable({}, { __index=function(t, key)
  local slot = eventSlot(); rawset(t, key, slot); return slot
end })

local function body(id, x)
  local value = { id=id, kind="IsoPlayer", x=x, y=10, z=0,
    data={ SAOPersonId=id }, needs={ hunger=scene.competingPressure,
      thirst=0.10, fatigue=0.08 } }
  function value:getX() return self.x end
  function value:getY() return self.y end
  function value:getZ() return self.z end
  function value:getModData() return self.data end
  function value:isDead() return false end
  return value
end

local originId = "origin-" .. scene.sceneId
local actorId = "actor-" .. scene.sceneId
local originBody, actorBody = body(originId, 10), body(actorId, 11)
local origin = { id=originId, forename="Rowan", surname="Source",
  occupation="survivor", hunger=.10, x=10, y=10, z=0 }
local actor = { id=actorId, forename="Avery", surname="Recipient",
  occupation="survivor", designation=scene.designation,
  hunger=scene.competingPressure, x=11, y=10, z=0 }
local pathogen = nil
if scene.actorKind ~= "survivor" then
  actor.bodyOwner = "ZAO"
  actor.bodyOwnerToken = "scene-owner:" .. scene.sceneId
  pathogen = { personId=actorId, terminalState=scene.actorKind,
    currentForm="none", decayState=scene.actorKind, history={},
    identityAxes={ verbs=1, perception=1 },
    driver={ version=1, revision=1, currentActivity=scene.activity,
      sinceHours=99, updatedAtHours=100 },
    maintenance={ version=1, receiptSequence=0, lastAdvancedHours=100 } }
  if scene.actorKind == "crossed" then
    pathogen.maintenance.predatory = { pressure = scene.pressureKind == "predatory"
      and scene.competingPressure or 0 }
    if scene.pressureKind == "predatory" then
      actorBody.needs.hunger = .08
    end
  else
    pathogen.maintenance.nutrition = { humanMeals=0 }
  end
  actor.pathogenState = { terminalState=scene.actorKind,
    decayState=scene.actorKind, currentForm="none", formPerformance=0,
    attributeMutations={}, source="authored-headless-scene" }
end
local people = { [originId]=origin, [actorId]=actor }

_G.__stores = {
  SurvivorAwareness_Graph = {
    schema=3, branching={ patterns={}, offices={} },
    organization={ organizations={}, offices={}, claims={}, decisions={} },
    settlement={ bases={} }, material={ stores={}, reconciliations={},
      sourceOwners={} }, communication={ messages={} },
    player={ claims={} }, migrations={} },
  SurvivorAwareness_Standing = { schema=4,
    relations={ [actorId]={ [originId]={ trust=scene.relationship,
      hostile=scene.hostile } } },
    groups={ [originId]="scene-group", [actorId]="scene-group" },
    claims={}, groupMeta={}, groupClaims={}, migrations={} },
}
ModData = { getOrCreate=function(key)
  __stores[key] = __stores[key] or {}; return __stores[key]
end }

SAO = {
  History={ countyHours=function() return __now end,
    ageOf=function() return 31 end },
  Branching={}, Settlement={}, Material={}, PlayerInteraction={},
  Identity={
    get=function(id) return people[tostring(id)] end,
    all=function() return people end,
    idByName=function() return nil end,
    beliefKey=function(rec) return rec and rec.id end,
    displayName=function(rec) return rec and (rec.forename .. " " .. rec.surname) end,
  },
  Body={ active={ [originId]=originBody }, foreign={},
    get=function(id) return tostring(id) == originId and originBody
      or (tostring(id) == actorId and scene.actorKind == "survivor" and actorBody)
      or nil end,
    hasRepresentation=function(id) return tostring(id) == originId
      or tostring(id) == actorId end,
  },
  Disposition={ circle=function() return "near" end,
    traits=function() return { patience=.5, aggression=.2, nerve=.6,
      discipline=.5, initiative=.5, selfPreservation=.6, compassion=.4,
      talkativeness=.5 } end,
    describe=function() return "scene" end },
  Conditions={ of=function() return {} end },
  Habits={ of=function() return {} end },
  Lessons={ renderClaims=function() return {} end,
    has=function() return false end, weight=function() return 0 end },
  Census={ JOB_PERK={}, classOf=function() return "survivor" end,
    skillOf=function() return 0 end },
  Rand={ state=function() return "coordination-scenes-v1", 0 end },
  Needs={ read=function(seen) return seen and seen.needs or nil end,
    bleeding=function() return 0 end },
  Log={ line=function() end },
  Locomotion={ jobs={}, cancel=function() end },
}

SAOJavaBridge = {
  canConverseNow=function(_, a, b, reach)
    local dx, dy = a:getX() - b:getX(), a:getY() - b:getY()
    return dx * dx + dy * dy <= reach * reach
  end,
}

ZAO = {
  Pathogen={
    stateOf=function(id) return tostring(id) == actorId and pathogen or nil end,
    attributeString=function() return "" end,
    ensureDriverToken=function() return actor.bodyOwnerToken end,
  },
  StateStore={ store=function()
    __stores.ZombieAwareness = __stores.ZombieAwareness or {}
    return __stores.ZombieAwareness
  end },
  State={ of=function(rec) return rec and rec.id == actorId and pathogen or nil end },
  Sandbox={ policy=function() return { enabled=true, controller=true,
    mind=true, settlement=false } end },
  Settlement={ active=function() return {} end },
  Afflicted={ options=function() return {} end, execute=function() return false end },
  Crossed={ options=function() return {} end, execute=function() return false end },
}

function __scene() return scene end
function __originId() return originId end
function __actorId() return actorId end
function __actorBody() return actorBody end
function __pathogen() return pathogen end
'''


PROBE = r'''(function()
  local scene, originId, actorId = __scene(), __originId(), __actorId()
  if scene.actorKind ~= "survivor" then
    SAO.Body.foreign[actorId] = __actorBody()
    assert(ZAO.Controller.acceptExternal(actorId, __actorBody(),
      "scene-owner:" .. scene.sceneId, scene.actorKind) == true,
      "ZAO execution owner refused the living human shell")
  end
  assert(SAO.GraphPersistence.bind() == true, "graph bind failed")
  local capture = SAODecisionCapture.beginCoordination({
    runId="scene-run:" .. scene.sceneId,
    county="SceneCounty:" .. scene.sceneId })
  local org = SAO.Organization
  org.createOrganization("scene-group", { minX=0,minY=0,maxX=20,maxY=20 },
    "declared-headless-situation")
  org.join("scene-group", originId)
  org.join("scene-group", actorId)
  local proposal = {
    purpose="carry-food-to-requester",
    scope={ quantity=1, category="food" },
    requiredCapabilities={ acquire=true, carry=true, deliver=true },
  }
  if scene.destinationKnown then
    proposal.destination={ minX=8,minY=8,maxX=12,maxY=12,z=0 }
  end
  local process = org.raiseMatter(originId, "food-delivery", "scene-group",
    proposal, { actorId }, { sourceLineage=scene.sourceLineage,
      syntheticStartingConditions=true })
  assert(process ~= nil, "matter was not raised")
  local message = SAO.Communication.send(originId, actorId,
    "process-proposal", { processId=process.id, revision=process.revision })
  message.transportAdmitted=true
  message.channel="spoken"
  message.transportEvidence={ kind="headless-native-distance", distance=1 }
  assert(SAO.Communication.deliver(message) == true,
    "proposal communication was not delivered")
  assert(SAO.Perception.recordAidRequest(actorId, "scene-group", __now,
    "requested", originId, "food", process.id, process.revision,
    "spoken", { messageId=message.id }) == true,
    "recipient did not acquire the proposal")
  local body = scene.actorKind == "survivor" and __actorBody() or nil
  local formed = SAO.Controller.appraiseCoordination(actorId, body,
    scene.activity)
  assert(formed == 1, "production controller did not form one response")
  local result = capture.finish()
  return result
end)()'''


def source_paths() -> list[Path]:
    return [GRAPH, INFERENCE, ORGANIZATION, COMMUNICATION, STANDING, PERCEPTION,
            COORDINATION, CONTROLLER, ZAO_MAINTENANCE, ZAO_MIND, ZAO_DRIVER,
            ZAO_AFFLICTED, ZAO_CROSSED, ZAO_EXECUTION_OWNER,
            ZAO_CONTROLLER, CAPTURE]


def evidence_paths() -> list[Path]:
    return source_paths() + [Path(__file__).resolve()]


def source_name(path: Path) -> str:
    path = path.resolve()
    if path.is_relative_to(ROOT):
        return "sao/" + path.relative_to(ROOT).as_posix()
    if path.is_relative_to(ZAO_ROOT):
        return "zao/" + path.relative_to(ZAO_ROOT).as_posix()
    raise RuntimeError("source path is outside the sister repositories: " + str(path))


def run_scene(spec: dict[str, Any], *,
              controller_source: str | None = None,
              coordination_source: str | None = None,
              zao_driver_source: str | None = None,
              zao_afflicted_source: str | None = None,
              zao_crossed_source: str | None = None,
              zao_execution_owner_source: str | None = None,
              zao_controller_source: str | None = None) -> dict[str, Any]:
    prelude = PRELUDE.replace("__SCENE__", lua_value(spec))
    with tempfile.TemporaryDirectory(prefix="sao-coordination-scene-") as tmp:
        work = Path(tmp)
        shutil.copy2(Border.STDLIB, work / "stdlib.lua")
        for compiled in Border.OUT.glob("LuaRun*.class"):
            shutil.copy2(compiled, work / compiled.name)
        prelude_path, probe_path = work / "prelude.lua", work / "probe.lua"
        prelude_path.write_text(prelude, encoding="utf-8")
        probe_path.write_text("__result = " + PROBE, encoding="utf-8")
        replacements = {
            CONTROLLER: controller_source,
            COORDINATION: coordination_source,
            ZAO_DRIVER: zao_driver_source,
            ZAO_AFFLICTED: zao_afflicted_source,
            ZAO_CROSSED: zao_crossed_source,
            ZAO_EXECUTION_OWNER: zao_execution_owner_source,
            ZAO_CONTROLLER: zao_controller_source,
        }
        loaded = []
        for path in source_paths()[:-1]:
            source = replacements.get(path)
            if source is None:
                loaded.append(path)
            else:
                replacement = work / (path.stem + "-replacement.lua")
                replacement.write_text(source, encoding="utf-8")
                loaded.append(replacement)
        command = [str(Border.JDK / "java.exe"), "-cp",
                   f"{Border.PZ}{os.pathsep}.", "LuaRun", str(prelude_path)]
        command += [str(path) for path in loaded]
        command += [str(CAPTURE), str(probe_path), "--", "__result"]
        done = subprocess.run(command, cwd=work, capture_output=True,
                              text=True, encoding="utf-8", errors="replace",
                              timeout=60)
    output = (done.stdout or "") + (done.stderr or "")
    lines = [line[6:] for line in (done.stdout or "").splitlines()
             if line.startswith("VALUE ")]
    if done.returncode != 0 or len(lines) != 1:
        raise RuntimeError(f"{spec['sceneId']} production scene failed: {output[-4000:]}")
    capture = json.loads(lines[0])
    county = "SceneCounty:" + spec["sceneId"]
    run_id = "scene-run:" + spec["sceneId"]
    Dump.validate_coordination_capture(capture, county, run_id)
    if capture["eventCount"] != 1:
        raise RuntimeError(f"{spec['sceneId']} emitted {capture['eventCount']} choices")
    return capture["events"][0]


def build() -> tuple[dict[str, Any], list[dict[str, Any]], dict[str, Any]]:
    catalogue = {"schema": SCHEMA, "schemaVersion": 1,
                 "partitionRule": "declared-before-production-execution",
                 "syntheticStartingConditions": True, "scenes": SCENES}
    catalogue["contentSha256"] = digest(catalogue)
    rows = []
    index = []
    for spec in SCENES:
        row = run_scene(spec)
        rows.append(row)
        index.append({
            "sceneId": spec["sceneId"],
            "sourceLineage": spec["sourceLineage"],
            "split": spec["split"],
            "actorKind": spec["actorKind"],
            "namespace": row["namespace"],
            "response": row["choice"]["optionId"].removeprefix("coordination:"),
        })
    manifest = {
        "schema": OUTPUT_SCHEMA,
        "schemaVersion": 1,
        "catalogueSha256": catalogue["contentSha256"],
        "rowCount": len(rows),
        "sourceHashes": {source_name(path): indexed_hash(path)
                          for path in evidence_paths()},
        "index": index,
        "standing": "candidate-observation",
        "exclusions": ["synthetic-starting-conditions",
                       "learned-shadow-not-executed-in-source-scenes",
                       "learned-runtime-not-authoritative",
                       "decline-withdraw-unobserved",
                       "loaded-gameplay-unobserved"],
    }
    manifest["contentSha256"] = digest(manifest)
    return catalogue, rows, manifest


def output_bytes(catalogue: dict[str, Any], rows: list[dict[str, Any]],
                 manifest: dict[str, Any]) -> dict[str, bytes]:
    return {
        "catalogue.json": canonical(catalogue) + b"\n",
        "decisions.jsonl": b"".join(canonical(row) + b"\n" for row in rows),
        "manifest.json": canonical(manifest) + b"\n",
    }


def publish(destination: Path, files: dict[str, bytes], check: bool) -> None:
    if check:
        for name, data in files.items():
            if (destination / name).read_bytes() != data:
                raise RuntimeError("saved scene evidence differs: " + name)
        return
    if destination.exists():
        if all((destination / name).is_file()
               and (destination / name).read_bytes() == data
               for name, data in files.items()):
            return
        raise RuntimeError("destination already contains different evidence")
    destination.parent.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix=f".{destination.name}.",
                                    dir=destination.parent))
    try:
        for name, data in files.items():
            (staging / name).write_bytes(data)
        os.replace(staging, destination)
    except BaseException:
        shutil.rmtree(staging, ignore_errors=True)
        raise


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    required = evidence_paths() + [Border.PZ, Border.STDLIB,
                                 Border.JDK / "java.exe", Border.JDK / "javac.exe"]
    missing = [path for path in required if not path.is_file()]
    if missing:
        parser.error("required source/runtime absent: " + ", ".join(map(str, missing)))
    built, detail = Border.compile_runner()
    if not built:
        parser.error("Lua runner compile failed: " + detail[-1000:])
    try:
        catalogue, rows, manifest = build()
        publish(args.out, output_bytes(catalogue, rows, manifest), args.check)
    except (Dump.Sweep.EvidenceError, OSError, RuntimeError, ValueError,
            subprocess.SubprocessError) as error:
        parser.exit(1, "REFUSED: " + str(error) + "\n")
    counts: dict[str, int] = {}
    for entry in manifest["index"]:
        counts[entry["response"]] = counts.get(entry["response"], 0) + 1
    print(f"wrote {len(rows)} production choices to {args.out}")
    print("responses " + json.dumps(counts, sort_keys=True))
    print("manifest " + manifest["contentSha256"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
