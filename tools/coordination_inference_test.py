#!/usr/bin/env python3
"""Border 193: actual appraisal submits only a guarded shadow snapshot.

The installed Kahlua VM executes the production Organization and inference Lua.
A recording bridge proves the learned result cannot choose the response, while
stale revision, current-owner drift, foreign output and hidden-condition inputs
are refused.  Survivor plus two distinct ZAO-owned people traverse the same
mechanism without an actor-kind or condition label entering model input.
"""
from __future__ import annotations

import base64
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

import enacted_coordination_test as Enacted


ROOT = Path(__file__).resolve().parents[1]
LUA = ROOT / "mod/42.20/media/lua"
INFERENCE = LUA / "shared/SAO_CoordinationInference.lua"
ORGANIZATION = LUA / "shared/SAO_Organization.lua"
GRAPH = LUA / "shared/SAO_GraphPersistence.lua"
IDENTITY = LUA / "shared/SAO_Identity.lua"
PARITY = ROOT / "tools/fixtures/coordination-r67/parity.tsv"
BUNDLE_SHA = "02edcdc1caf7489f0871f63e35af2c2cc26966ec74c0cf30eb63d155b1acb33c"


def lua_literal(value):
    if value is None:
        raise ValueError("the canonical parity fixture unexpectedly contains null")
    if value is True:
        return "true"
    if value is False:
        return "false"
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, list):
        return "{" + ",".join(lua_literal(item) for item in value) + "}"
    if isinstance(value, dict):
        return "{" + ",".join(
            "[" + json.dumps(str(key), ensure_ascii=False) + "]="
            + lua_literal(item) for key, item in value.items()) + "}"
    raise TypeError(type(value))


def exact_fixture() -> tuple[str, str]:
    line = PARITY.read_text(encoding="utf-8").splitlines()[1].split("\t")
    canonical = base64.b64decode(line[1]).decode("utf-8")
    return lua_literal(json.loads(canonical)), canonical


PRELUDE = rf'''
_G.__now = 100
_G.__people = {{}}
_G.__owners = {{}}
_G.__submitted = {{}}
_G.__pollModes = {{}}
_G.__cancelled = {{}}
_G.__nextPollMode = "valid"
local function person(id)
  __people[id] = __people[id] or {{ id=id }}
  return __people[id]
end
SAO = {{
  History = {{ countyHours=function() return __now end }},
  Identity = {{ get=person }},
  Communication = {{ actorSnapshot=function(id)
    return __owners[id]
  end }},
}}
SAOJavaBridge = {{
  coordinationBundleStatus=function(self)
    return "READY\t{BUNDLE_SHA}\tr67-r66-coordination-fp32-v1\tmodel\t11804"
  end,
  submitCoordinationShadow=function(self, requestId, input, features, options)
    __submitted[requestId] = {{ input=input, features=features, options=options }}
    __pollModes[requestId] = __nextPollMode
    __nextPollMode = "valid"
    return "QUEUED\t" .. requestId .. "\tinput-" .. requestId
  end,
  pollCoordinationShadow=function(self, requestId)
    local mode = __pollModes[requestId]
    if mode == "pending" then return "PENDING" end
    local bundle = mode == "foreign" and string.rep("0", 64)
      or "{BUNDLE_SHA}"
    local input = mode == "wrong-input" and "wrong"
      or "input-" .. requestId
    if mode == "failed" then return "FAILED\tfixture" end
    return "READY\t" .. bundle .. "\t" .. input
      .. "\taccept\taccept=0.6,qualify=0.1,counter-propose=0.1,defer=0.1,contest=0.1"
      .. "\t100\t200"
  end,
  cancelCoordinationShadow=function(self, requestId)
    __cancelled[requestId] = true
    __pollModes[requestId] = nil
    return "CANCELLED\t" .. requestId
  end,
}}
'''


def probe(exact_lua: str, exact_json: str) -> str:
    return rf'''(function()
  local stage = "setup"
  local ok, outcome = pcall(function()
  local checks = {{}}
  local function check(name, value) checks[name] = value == true end
  local function empty(value)
    for _ in pairs(value or {{}}) do return false end
    return true
  end
  local exact = {exact_lua}
  stage = "canonical"
  check("canonical_python_parity",
    SAO.CoordinationInference.canonical(exact) == [==[{exact_json}]==])

  local Org, Inf = SAO.Organization, SAO.CoordinationInference
  local tooWide = {{}}
  for index = 1, 513 do tooWide["field-" .. index] = index end
  local acceptedWide = pcall(function() Inf.canonical(tooWide) end)
  check("canonical_table_bound", acceptedWide == false)
  local function owner(id, bodyOwner, activity, pressure)
    local rec = SAO.Identity.get(id)
    rec.bodyOwner = bodyOwner == "SAO" and nil or bodyOwner
    __owners[id] = {{ bodyOwner=bodyOwner, executor=bodyOwner == "ZAO"
        and "ZAO.Driver" or "SAO.Controller", represented=false,
      currentActivity=activity, canAcquire=true, canCarry=true,
      canDeliver=true, canExecute=true,
      competingPressure=pressure, competingPressureAvailable=true }}
  end
  local function appraise(id, bodyOwner, activity, pressure, choice, hidden)
    owner(id, bodyOwner, activity, pressure)
    local proposal = {{
      purpose="carry-food-to-requester",
      destination={{ minX=1,minY=1,maxX=2,maxY=2,z=0 }},
      scope={{ category="food",quantity=1 }},
      requiredCapabilities={{ acquire=true,carry=true,deliver=true }},
    }}
    if hidden == "proposal" then
      proposal.pathogen = "must-not-enter-model"
    end
    local process = Org.raiseMatter("origin-" .. id, "food-delivery", "g",
      proposal, {{ id }}, {{ source="fixture" }})
    Org.recordReception(process.id, id, process.revision, "spoken",
      process.originatorId, {{ distance=1,kind="headless-native-distance" }})
    local constraints = {{ represented=false, currentActivity=activity,
      executionOwnerAvailable=true, ownNeedAvailable=true, contest=false }}
    if hidden == true or hidden == "constraints" then
      constraints.diet = "must-not-enter-model"
    end
    local interests = {{ designation="mechanic",ownGroup="g" }}
    if hidden == "interests" then
      interests.diagnosis = "must-not-enter-model"
    end
    local response = Org.appraiseMatter(process.id, id, {{
      choice=choice or "accept", owner="fixture.private",
      executor=bodyOwner == "ZAO" and "ZAO.Driver" or "SAO.Controller",
      bodyOwner=bodyOwner, currentActivity=activity, relationship=0.6,
      ownNeed=pressure, destinationKnown=true, canAcquire=true,
      canCarry=true, canDeliver=true, canExecute=true,
      interests=interests,
      constraints=constraints,
      inputOwners={{ currentActivity=bodyOwner == "ZAO" and "ZAO.Driver"
          or "SAO.Controller", capabilities=bodyOwner == "ZAO"
          and "ZAO.Driver" or "SAO.Controller",
        ownNeed=bodyOwner == "ZAO" and "ZAO.Maintenance" or "SAO.Needs",
        relationship="SAO.Standing", interests="SAO.Identity+SAO.Standing",
        constraints="fixture.private" }},
    }})
    return process, response
  end
  local function pendingFor(personId)
    for requestId, value in pairs(Inf.pending) do
      if value.personId == personId then return requestId, value end
    end
  end
  local function latest() return Inf.observations[#Inf.observations] end

  stage = "survivor-appraise"
  local survivor, survivorResponse = appraise("survivor", "SAO", "idle", 0.12)
  local survivorRequest = pendingFor("survivor")
  check("response_precedes_shadow", survivorResponse.response == "accept"
    and survivorRequest ~= nil and empty(survivor.commitments))
  stage = "survivor-poll"
  Inf.poll()
  check("unchanged_shadow_observed", latest().status == "observed"
    and latest().actualResponse == "accept"
    and latest().predictedResponse == "accept"
    and latest().authoritative == false
    and survivor.participants.survivor.responses["1"].response == "accept"
    and empty(survivor.commitments))

  stage = "zao-paths"
  local firstZAO = appraise("zao-one", "ZAO", "idle", 0.81, "qualify")
  local firstRequest = pendingFor("zao-one")
  local firstInput = firstRequest and __submitted[firstRequest].input or ""
  Inf.poll()
  local secondZAO = appraise("zao-two", "ZAO", "driving", 0.21, "defer")
  local secondRequest = pendingFor("zao-two")
  local secondInput = secondRequest and __submitted[secondRequest].input or ""
  Inf.poll()
  check("shared_zao_driver_distinct_state", firstRequest ~= nil
    and secondRequest ~= nil and firstInput ~= secondInput
    and string.find(firstInput, '"executor":"ZAO.Driver"', 1, true) ~= nil
    and string.find(secondInput, '"executor":"ZAO.Driver"', 1, true) ~= nil
    and string.find(firstInput, "afflicted", 1, true) == nil
    and string.find(firstInput, "crossed", 1, true) == nil
    and string.find(secondInput, "afflicted", 1, true) == nil
    and string.find(secondInput, "crossed", 1, true) == nil
    and firstZAO.participants["zao-one"].responses["1"].response == "qualify"
    and secondZAO.participants["zao-two"].responses["1"].response == "defer")

  stage = "stale"
  local stale = appraise("stale", "SAO", "idle", 0.1)
  Org.reviseMatter(stale.id, stale.originatorId,
    {{ purpose="revised", destination={{ minX=3,minY=3,maxX=4,maxY=4 }} }}, {{}})
  Inf.poll()
  check("stale_revision_withheld", latest().status == "withheld"
    and string.find(latest().reason, "revision", 1, true) ~= nil)

  stage = "owner-change"
  local changed = appraise("changed", "ZAO", "idle", 0.2)
  __owners.changed.currentActivity = "driving"
  Inf.poll()
  check("owner_drift_withheld", latest().status == "withheld"
    and latest().reason == "execution-owner-state-changed")

  stage = "foreign"
  __nextPollMode = "foreign"
  local foreign = appraise("foreign", "SAO", "idle", 0.1)
  Inf.poll()
  check("foreign_result_withheld", latest().status == "withheld"
    and latest().reason == "foreign-or-malformed-result")

  stage = "hidden"
  local beforePending, beforeSubmitted = Inf.status().pending,
    Inf.status().submitted
  local hidden, hiddenResponse = appraise("hidden", "ZAO", "idle", 0.3,
    "accept", "constraints")
  local hiddenProposal, hiddenProposalResponse = appraise("hidden-proposal",
    "SAO", "idle", 0.2, "accept", "proposal")
  local hiddenInterests, hiddenInterestsResponse = appraise("hidden-interests",
    "ZAO", "idle", 0.4, "accept", "interests")
  check("hidden_condition_refused_but_response_kept",
    hiddenResponse.response == "accept"
    and hiddenProposalResponse.response == "accept"
    and hiddenInterestsResponse.response == "accept"
    and Inf.status().pending == beforePending
    and Inf.status().submitted == beforeSubmitted
    and Inf.status().refused >= 3)

  stage = "person-forget"
  __nextPollMode = "pending"
  local forgotten = appraise("forgotten", "ZAO", "idle", 0.5)
  local forgottenRequest = pendingFor("forgotten")
  local removed = Inf.forgetPerson("forgotten")
  check("person_forget_cancels_pending", forgottenRequest ~= nil
    and removed == 1 and pendingFor("forgotten") == nil
    and __cancelled[forgottenRequest] == true)

  stage = "reset"
  __nextPollMode = "pending"
  local reset = appraise("reset", "SAO", "idle", 0.1)
  check("reset_has_pending", Inf.status().pending == 1)
  Inf.reset()
  check("world_reset_clears_transient", Inf.status().pending == 0
    and #Inf.observations == 0 and Inf.status().authoritative == false)

  return Inf.canonical(checks)
  end)
  if ok then return outcome end
  return "probe-error:" .. stage .. ":" .. tostring(outcome)
end)()'''


def main() -> int:
    installed = [Enacted.PZ, Enacted.STDLIB, Enacted.JDK / "java.exe",
                 Enacted.JDK / "javac.exe"]
    if not all(path.is_file() for path in installed):
        print("Border 193 SKIPPED: installed Kahlua VM or JDK absent")
        return 0
    built, detail = Enacted.compile_runner()
    if not built:
        print("Border 193 FAULT: Lua runner compile failed: " + detail[-1000:])
        return 1
    exact_lua, exact_json = exact_fixture()
    with tempfile.TemporaryDirectory(prefix="sao-coordination-shadow-") as tmp:
        work = Path(tmp)
        shutil.copy2(Enacted.STDLIB, work / "stdlib.lua")
        for compiled in Enacted.OUT.glob("LuaRun*.class"):
            shutil.copy2(compiled, work / compiled.name)
        prelude = work / "prelude.lua"
        test = work / "probe.lua"
        prelude.write_text(PRELUDE, encoding="utf-8")
        test.write_text("__result = " + probe(exact_lua, exact_json),
                        encoding="utf-8")
        result = subprocess.run(
            [str(Enacted.JDK / "java.exe"), "-cp", f"{Enacted.PZ};.", "LuaRun",
             str(prelude), str(INFERENCE), str(ORGANIZATION), str(test),
             "--", "__result"], cwd=work, capture_output=True, text=True,
            encoding="utf-8", errors="replace", timeout=300)
    lines = (result.stdout or "").strip().splitlines()
    value = lines[-1][6:] if lines and lines[-1].startswith("VALUE ") else None
    try:
        checks = json.loads(value or "null")
    except json.JSONDecodeError:
        checks = None
    expected = {
        "canonical_python_parity", "canonical_table_bound",
        "response_precedes_shadow",
        "unchanged_shadow_observed", "shared_zao_driver_distinct_state",
        "stale_revision_withheld", "owner_drift_withheld",
        "foreign_result_withheld", "hidden_condition_refused_but_response_kept",
        "person_forget_cancels_pending", "reset_has_pending",
        "world_reset_clears_transient",
    }
    static = ("SAO.CoordinationInference.poll()" in
              (LUA / "client/SAO_Controller.lua").read_text(encoding="utf-8")
              and "SAO.CoordinationInference.reset()" in
              GRAPH.read_text(encoding="utf-8")
              and "SAO.CoordinationInference.forgetPerson" in
              IDENTITY.read_text(encoding="utf-8"))
    failed = sorted(name for name in expected
                    if not isinstance(checks, dict) or checks.get(name) is not True)
    if result.returncode or failed or not static:
        print("Border 193 FAULT: failed=" + repr(failed)
              + " static=" + repr(static))
        print(((result.stdout or "") + (result.stderr or ""))[-4000:])
        return 1
    print("Border 193 PASS: real appraisal stayed authoritative; exact JSON, "
          "Survivor and distinct ZAO-owner snapshots, stale/foreign/hidden "
          "refusal, person-death cancellation and world-reset cancellation "
          "executed in Kahlua")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
