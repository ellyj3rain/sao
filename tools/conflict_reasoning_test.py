"""Private conflict appraisal and exact native attempt feedback in installed Kahlua.

Real shared modules and conceptual priors; controlled personal records, clock,
native offer availability and result callbacks. No rendered combat acceptance.
"""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import hashlib
import json
import os
import shutil
import subprocess
from native_proof_preflight import installed_presence

ROOT = Path(__file__).resolve().parents[1]
GAME = Path(os.environ.get("PZ_DIR", r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"))
JDK = Path(os.environ.get("JDK_BIN", r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin"))
OUT = ROOT / "_scratch/d1-shared-reasoning/conflict/reasoning"
FILES = {name: ROOT / ("mod/42.20/media/lua/shared/SAO_" + module + ".lua") for name, module in
         [("models", "CognitiveModels"), ("disposition", "Disposition"), ("concepts", "ConceptKnowledge"),
          ("pressure", "PathogenPressure"), ("cognition", "Cognition"), ("planning", "ProceduralPlanning")]}
FILES["cases"] = ROOT / "tools/conflict_reasoning_cases.lua"
PRELUDE = """
require=function() end
records={};clock=10
SAO={Identity={get=function(id)return records[id]end},
 History={countyHours=function()return clock end},
 Hash={unit=function()return .5 end,of=function()return 1 end},
 Conditions={bend=function(id,key)return records[id].conditionEchoes[key] or 0 end}}
ModData={get=function()return nil end}
"""
CONTROLS = [
    ("personal-values", "models", "local v=frame.values", "local v={selfPreservation=.5,aggression=.5,nerve=.5,discipline=.5,compassion=.5}", "personal_values_change_choice"),
    ("causal-premise", "models", "if relation and relation.supported then", "if relation then", "causal_premise_changes_choice_at_fixed_values"),
    ("continuity", "cognition", "frame.preserveContinuity=prior.evidenceKey==frame.evidenceKey", "frame.preserveContinuity=false", "progressing_route_survives_clock_and_distance_refresh"),
    ("foreign-values", "cognition", 'supplied.values.actorId~=id', 'false', "foreign_values_refused"),
    ("route-feedback", "planning", 'failure.routeKey==routeKey', 'false', "route_failure_private_and_relevant"),
    ("current-token", "planning", 'or token.id~=admission.correlationId', 'or false', "wrong_native_result_token_refused"),
    ("refusal-revision", "planning", 'or result.frameId~=purpose.conflict.appraisal.frameId', 'or false', "stale_refusal_revision_refused"),
    ("owner-kind", "planning", 'token.owner~=CONFLICT_OWNERS[offer.kind]', 'false', "native_owner_kind_checked"),
    ("available-execution", "models", 'kind=offer.kind,available=offer.available,continuing=', 'kind=offer.kind,available=true,continuing=', "unknown_contact_admits_watch_only"),
    ("arguments-drive-selection", "models", 'merit=merit+amount', 'merit=merit', "personal_values_change_choice"),
    ("ranged-as-contact", "models", 'if exposure and (not ranged or close) then', 'if exposure then', "native_range_changes_applicable_choice"),
    ("ranged-invulnerability", "models", 'if exposure and (not ranged or close) then', 'if exposure and not ranged then', "nearby_threat_still_exposes_ranged_actor"),
    ("recognized-risk-discarded", "models", 'and not concerning', 'and true', "recognized_risk_changes_watch_judgment"),
    ("foreign-risk-owner", "cognition", 'frame.risk.actorId~=id', 'false', "foreign_risk_owner_refused"),
    ("foreign-risk-contact", "cognition", 'frame.risk.contactKey~=frame.threat.key', 'false', "foreign_risk_contact_refused"),
    ("foreign-risk-source", "cognition", 'frame.risk.source~=frame.threat.source', 'false', "foreign_risk_source_refused"),
    ("risk-relearns-encounter", "pressure", 'function Pathogen.appraise(id, threat)\n    local rec=SAO.Identity and SAO.Identity.get(id)', 'function Pathogen.appraise(id, threat)\n    local rec=SAO.Identity and SAO.Identity.get(id)\n    if rec then rec.mutationKnowledge=rec.mutationKnowledge or {} end', "recognized_appraisal_acquires_no_encounter"),
    ("risk-omitted-from-continuity", "cognition", 'material.atHours=nil;material.threat.at=nil', 'material.atHours=nil;material.threat.at=nil;material.risk=nil', "own_changed_experience_reopens_choice"),
    ("malformed-risk-knowledge", "pressure", 'if type(knowledge)~="table" then knowledge=nil end', 'if type(knowledge)~="table" then knowledge={weight=1,source="lived"} end', "recognized_risk_changes_watch_judgment"),
]


def run(production_only=False):
    OUT.mkdir(parents=True, exist_ok=True)
    jar = GAME / "projectzomboid.jar"
    runner = ROOT / "tools/luacheck/LuaRun.java"
    perception = ROOT / "mod/42.20/media/lua/shared/SAO_Perception.lua"
    paths = [*FILES.values(), perception, Path(__file__), jar, runner, GAME / "stdlib.lua"]
    paths.append(Path(__file__).with_name('native_proof_preflight.py'))
    preflight = installed_presence(paths, GAME, JDK, "conflict reasoning")
    if preflight is not None:
        raise SystemExit(preflight)
    pins = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    receipt = {"schema": "sao-conflict-reasoning-proof/1", "at": datetime.now(timezone.utc).isoformat(),
               "status": "INCOMPLETE", "inputs": pins, "boundary": __doc__, "variants": []}
    def write():
        (OUT / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    def invoke(command):
        result = subprocess.run(list(map(str, command)), cwd=OUT, capture_output=True, text=True, timeout=90)
        return result.returncode, result.stdout + result.stderr
    command = [JDK / "javac.exe", "-cp", jar, "-d", OUT, runner]
    code, log = invoke(command)
    receipt["compile"] = {"command": list(map(str, command)), "exit": code}
    (OUT / "compile.log").write_text(log)
    if code:
        write();raise RuntimeError(log)
    shutil.copy2(GAME / "stdlib.lua", OUT / "stdlib.lua")
    # Execute the exact pure ordering owner; other Perception queries remain controlled.
    owner = perception.read_text(encoding="utf-8-sig")
    sorter = owner.split("local function sortSightEvidence(", 1)[1].split("local function zombieReports(", 1)[0]
    (OUT / "prelude.lua").write_text(PRELUDE + "\nSAO.Perception=SAO.Perception or {}\nlocal P=SAO.Perception\nlocal function sortSightEvidence(" + sorter, encoding="utf-8")
    sources = {key: path.read_text(encoding="utf-8-sig") for key, path in FILES.items()}
    variants = [("production", None, None, None, None)] + ([] if production_only else CONTROLS)
    for name, file, before, after, target in variants:
        texts = dict(sources)
        if file:
            if texts[file].count(before) != 1: raise RuntimeError(name + ": mutation anchor")
            texts[file] = texts[file].replace(before, after, 1)
        for key, source in texts.items(): (OUT / (key + ".lua")).write_text(source)
        command = [JDK / "java.exe", "-cp", os.pathsep.join([str(jar), str(OUT)]), "LuaRun", "prelude.lua",
                   *[key + ".lua" for key in FILES], "--", "__result"]
        code, log = invoke(command)
        (OUT / (name + ".log")).write_text(log)
        receipt["variants"].append({"name": name, "command": list(map(str, command)), "exit": code,
                                    "target": target, "logSha256": hashlib.sha256(log.encode()).hexdigest()})
        write()
        if file:
            if not target or code == 0 or "CONFLICT:" + target not in log: raise RuntimeError(name + ": control failed\n" + log[-2500:])
        elif code or "VALUE PASS conflict reasoning" not in log:
            raise RuntimeError(log[-6000:])
        print(name + ": " + log.strip().splitlines()[-1], flush=True)
    after = {path: hashlib.sha256(Path(path).read_bytes()).hexdigest() for path in pins}
    receipt["inputs_after"] = after
    if pins != after: write();raise RuntimeError("Inputs changed during conflict proof")
    receipt["status"] = "PASS"
    write()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--production-only", action="store_true")
    parser.add_argument("--output-dir", type=Path)
    args = parser.parse_args()
    if args.output_dir is not None:
        OUT = args.output_dir.resolve()
    try:
        run(args.production_only)
    except Exception as error:
        print("FAIL conflict reasoning:", error, flush=True)
        raise SystemExit(1)
