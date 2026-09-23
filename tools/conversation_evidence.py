#!/usr/bin/env python3
"""Export an authored conversation input using production SAO knowledge owners.

The people and clock are controlled scenario inputs. Identity, history,
acquisition, perception, conditioning and cataloguing execute shipped code.
This is neither recorded player speech nor a sampled play session.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

import county_sweep as Sweep
import world_knowledge_evidence as World

ROOT = Path(__file__).resolve().parents[1]
LUA = ROOT / "mod/42.20/media/lua"
CAPTURE = ROOT / "tools/sweep/conversation_capture.lua"
ENCODER = ROOT / "tools/sweep/decision_capture.lua"
TOPICS = ["self", "person", "zombies", "dead", "food", "water", "house",
          "ground", "lessons", "mutations", "world", "before", "started"]

SETUP = r'''
_G.__world = "C76ConversationControlled"
_G.__hours = 48
_G.__owed = 0
ModData.get = function(key) return __md[key] end
SAOConversationHost = { readOwners = function()
    return { durable = __md, beliefs = SAO.Perception.beliefs,
        beliefVersion = SAO.Perception.beliefVersion }
end }
-- These calendar answers are measured from the shipped SAORecord class by
-- calendar_values() before this host starts. No knowledge reader is replaced.
GameTime.getInstance = function() return {
    getWorldAgeHours = function() return __hours end,
    getStartYear = function() return 1993 end,
    getStartMonth = function() return 6 end,
    getStartDay = function() return 8 end,
    getYear = function() return 1993 end,
    getMonth = function() return 6 end,
    getDay = function() return 10 end,
    getTimeOfDay = function() return 0 end,
    getCalender = function() return { getTimeInMillis = function() return 0 end } end
} end
SAOJavaBridge.countyInstant = function(self, hour)
    if hour == 0 then return "1993-07-09T00:00:00" end
    if hour == 48 then return "1993-07-11T00:00:00" end
    return nil
end
SAOJavaBridge.recordHour = function(self, day)
    if day == -8 then return -192 end
    if day == -7 then return -168 end
    return nil
end
SAOJavaBridge.countyDate = function(self, hour) return nil end
local person
for i = 1, 16 do
    local candidate = SAO.Identity.create("Mara", "Reed", 10600, 9700, 0)
    if SAO.History.ageInYear(candidate.id, 1993) >= 18 then person = candidate; break end
end
assert(person, "adult scenario person absent")
local listener = SAO.Identity.create("Jon", "Vale", 10601, 9700, 0)
SAO.History.generate(person.id, person, 0)
SAO.History.generate(listener.id, listener, 0)
person.originRegion = "Muldraugh, KY"
listener.originRegion = "Muldraugh, KY"
assert(SAO.WorldKnowledge.markCountyPresence(person, true))
assert(SAO.WorldKnowledge.markCountyPresence(listener, false))
SAO.Perception.sawPerson(person.id, "Jon Vale", listener.x, listener.y,
    SAO.History.ticks(), listener.id, 1)
SAO.Perception.sawPerson(listener.id, "Mara Reed", person.x, person.y,
    SAO.History.ticks(), person.id, 1)
-- Finish the normal owner initialization before beginning read-only evidence.
SAO.Standing.allGroupClaims()
SAO.Standing.trust(person.id, listener.id)
SAO.Standing.trust(listener.id, person.id)
SAO.WorldSources.source("absent")
__conversationPerson, __conversationListener = person, listener
__conversationRequest = { inputOrigin = "authored", runId = "c76-authored-conversation-v1",
    county = "C76ConversationControlled", eventId = "historical-outage-001",
    personId = person.id, listenerRef = listener.id,
    utterance = "Do you remember the telephone outage on July 2?" }
'''


def encoded(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True,
                      separators=(",", ":"), allow_nan=False).encode("utf-8")


def digest(value):
    return hashlib.sha256(encoded(value)).hexdigest()


def inputs():
    return [LUA / name for name in Sweep.MODULES] + [CAPTURE, ENCODER,
        ROOT / "tools/conversation_evidence.py", ROOT / "tools/county_sweep.py",
        ROOT / "tools/world_knowledge_evidence.py", Sweep.SWEEP / "prelude.lua",
        Sweep.SRC, Sweep.PZ, Sweep.STDLIB, Sweep.SAO_JAR]


def source_hashes():
    return {World.source_label(path): World.sha256(path) for path in inputs()}


def run(expression="SAOConversationCapture.take(__conversationRequest)", *,
        knowledge=None, capture=None):
    """Run one isolated scenario; optional source paths are for mutation controls."""
    if not Sweep.build_runner():
        raise RuntimeError("installed Kahlua runner did not compile")
    with tempfile.TemporaryDirectory(prefix="sao-conversation-vm-") as temporary:
        work = Path(temporary)
        shutil.copy2(Sweep.STDLIB, work / "stdlib.lua")
        for path in Sweep.OUT.glob("LuaRun*.class"):
            shutil.copy2(path, work / path.name)
        setup = work / "setup.lua"
        setup.write_text(SETUP, encoding="utf-8")
        paths = [LUA / name for name in Sweep.MODULES]
        if knowledge is not None:
            paths[paths.index(LUA / "shared/SAO_Knowledge.lua")] = Path(knowledge)
        command = [str(Sweep.JDK / "java.exe"), "-cp", f"{Sweep.PZ};.", "LuaRun",
                   str(Sweep.SWEEP / "prelude.lua"), *map(str, paths),
                   str(ENCODER), str(capture or CAPTURE), str(setup), "--", expression]
        done = subprocess.run(command, cwd=work, capture_output=True, text=True,
                              encoding="utf-8", errors="replace", timeout=120)
        values = [line[6:] for line in done.stdout.splitlines() if line.startswith("VALUE ")]
        if done.returncode or len(values) != 1 or any(
                line.startswith("ERROR ") for line in done.stdout.splitlines()):
            raise RuntimeError("conversation VM refused: " + (done.stdout + done.stderr)[-1800:])
        value = json.loads(values[0])
        return freeze(value) if value.get("schema") == "sao-conversation-observation" else value


def observation(value):
    raw = copy.deepcopy(value)
    raw["schema"] = "sao-conversation-observation"
    ns = raw["namespace"]
    label = ns["runId"] + "/" + ns["county"] + "/" + ns["eventId"]
    raw["snapshotRef"] = raw["catalogue"]["snapshotRef"] = label
    for index, claim in enumerate(raw["catalogue"]["claims"], 1):
        claim["ref"] = label + f"/claim/{index:04d}"
    return raw


def freeze(raw):
    """Bind references to all observed bytes, including the authored question."""
    value = copy.deepcopy(raw)
    ref = "sao-conversation/sha256-" + digest(observation(raw))
    value["schema"] = "sao-conversation-capture"
    value["snapshotRef"] = value["catalogue"]["snapshotRef"] = ref
    for index, claim in enumerate(value["catalogue"]["claims"], 1):
        claim["ref"] = ref + f"/claim/{index:04d}"
    return value


def validate(value):
    if value.get("schema") != "sao-conversation-capture" or value.get("schemaVersion") != 1:
        raise ValueError("conversation capture refused: " + str(value.get("coverage", {})))
    catalogue, context, ns = value["catalogue"], value["context"], value["namespace"]
    if value["coverage"]["status"] != "complete" or value["coverage"]["failures"] not in ({}, []):
        raise ValueError("source coverage incomplete")
    if value["coverage"]["topics"] != TOPICS or not value["coverage"]["readers"]:
        raise ValueError("topic coverage incomplete")
    if catalogue["personId"] != ns["personId"] or context["personId"] != ns["personId"]:
        raise ValueError("person binding differs")
    if catalogue["listenerRef"] != context["listenerRef"]:
        raise ValueError("listener binding differs")
    if (value['sourceState']['person']['id'] != context['personId']
            or value['sourceState']['listener']['id'] != context['listenerRef']
            or context['personId'] == context['listenerRef']):
        raise ValueError("source participant binding differs")
    if catalogue["atTick"] != context["atTick"] or context["atTick"] != ns["hour"] * 9000:
        raise ValueError("clock binding differs")
    if catalogue["snapshotRef"] != value["snapshotRef"]:
        raise ValueError("snapshot binding differs")
    if freeze(observation(value)) != value:
        raise ValueError("snapshot content identity differs")
    if value["trainingEligible"] is not False or value["inputOrigin"] != "authored":
        raise ValueError("capture standing differs")
    encoded(value)


def generate(destination):
    destination = Path(destination).resolve()
    if destination.exists():
        raise ValueError("destination exists; captured evidence is immutable")
    before = source_hashes()
    calendar = World.calendar_values()
    value = run()
    validate(value)
    if before != source_hashes():
        raise ValueError("source changed during capture")
    manifest = {"schema": "sao-conversation-evidence", "schemaVersion": 1,
                "captureSha256": digest(value), "sources": before,
                "calendarControl": calendar,
                "scope": "controlled-people-production-owners",
                "scenario": {"people": "authored identities; adult selected by production age",
                             "ground": "authored Muldraugh coordinates; no native ground claim",
                             "encounter": "authored mutual sighting supplied to Perception",
                             "clock": "controlled hour 48; installed SAORecord calendar checked",
                             "runtime": "installed Kahlua; bodyless production modules"}}
    manifest["contentSha256"] = digest(manifest)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".conversation-", dir=destination.parent) as temporary:
        stage = Path(temporary) / "evidence"
        stage.mkdir()
        for name, content in (("capture.json", value), ("manifest.json", manifest)):
            (stage / name).write_bytes(json.dumps(content, ensure_ascii=False, indent=2,
                                                 sort_keys=True, allow_nan=False).encode() + b"\n")
        os.rename(stage, destination)
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    try:
        manifest = generate(args.out)
    except (OSError, ValueError, RuntimeError) as error:
        parser.exit(1, "REFUSED: " + str(error) + "\n")
    print("Captured authored input: " + manifest["captureSha256"])


if __name__ == "__main__":
    main()
