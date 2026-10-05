"""D1 personal conceptual means and actual Controller/Locomotion inquiry.

Installed Kahlua executes full production Lua owners. Native visibility rows
and movement receiver are controlled; native producer has its own probe.
Negative associations are retained-record fixtures, not live absence learning.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import flee_continuity_test as fixture
from native_proof_preflight import installed_presence

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "_scratch/d1-shared-reasoning/concepts/lua-tokenless"
FILES = {
    "models": ROOT / "mod/42.20/media/lua/shared/SAO_CognitiveModels.lua",
    "cognition": ROOT / "mod/42.20/media/lua/shared/SAO_Cognition.lua",
    "needs": ROOT / "mod/42.20/media/lua/client/SAO_Needs.lua",
    "perception": ROOT / "mod/42.20/media/lua/shared/SAO_Perception.lua",
    "concepts": ROOT / "mod/42.20/media/lua/shared/SAO_ConceptKnowledge.lua",
    "planning": ROOT / "mod/42.20/media/lua/shared/SAO_ProceduralPlanning.lua",
    "locomotion": ROOT / "mod/42.20/media/lua/client/SAO_Locomotion.lua",
    "controller": ROOT / "mod/42.20/media/lua/client/SAO_Controller.lua",
    "ordinary": ROOT / "tools/ordinary_purpose_cases.lua",
    "cases": ROOT / "tools/concept_knowledge_cases.lua",
}

def run():
    global OUT
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,default=OUT)
    parser.add_argument('--variants',nargs='+')
    args=parser.parse_args();OUT=args.output.resolve()
    OUT.mkdir(parents=True, exist_ok=True)
    jar = fixture.GAME / "projectzomboid.jar"
    paths = [*FILES.values(), Path(__file__), Path(fixture.__file__), fixture.RUNNER, jar, fixture.GAME / "stdlib.lua"]
    paths.append(Path(__file__).with_name('native_proof_preflight.py'))
    preflight = installed_presence(paths, fixture.GAME, fixture.JDK, "concept knowledge")
    if preflight is not None:
        raise SystemExit(preflight)
    inputs = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    receipt = {"schema": "sao-concept-knowledge-proof/1", "status": "INCOMPLETE", "inputs": inputs,
               "variants": [], "boundary": __doc__}
    def invoke(command):
        result = subprocess.run(list(map(str, command)), cwd=OUT, capture_output=True, text=True, timeout=120)
        return result.returncode, result.stdout + result.stderr
    compile_command = [fixture.JDK / "javac.exe", "-cp", jar, "-d", OUT, fixture.RUNNER]
    code, log = invoke(compile_command)
    receipt["compile"] = {"command": list(map(str, compile_command)), "exit": code}
    assert code == 0, log
    shutil.copy2(fixture.GAME / "stdlib.lua", OUT / "stdlib.lua")
    (OUT / "prelude.lua").write_text(fixture.PRELUDE + "\nrequire=function()end\nISInventoryTransferAction={derive=function()return {}end}\n__ordinaryPerception={} for k,v in pairs(SAO.Perception) do __ordinaryPerception[k]=v end\n", encoding="utf-8")
    (OUT / "capture.lua").write_text("__conceptModules={planning=SAO.ProceduralPlanning,locomotion=SAO.Locomotion,perception=SAO.Perception}\nSAO.Perception=__ordinaryPerception\n", encoding="utf-8")
    sources = {name: path.read_text(encoding="utf-8") for name, path in FILES.items()}
    variants = [
        ("production", None, None, None, None),
        ("restore-source-identity-churn", "concepts", "if reusable(prior,id,identity,provenance.acquiredAt) and prior.affirmed==(edge.affirmed~=false)",
         "if reusable(prior,id,identity,provenance.acquiredAt) and prior.sourceId==provenance.sourceId and prior.affirmed==(edge.affirmed~=false)", "six_objects_are_two_propositions"),
        ("discard-additional-witness", "concepts", "witness(s,prior,provenance)",
         "-- additional witness discarded", "distinct_witnesses_retained_privately"),
        ("rewrite-primary-acquisition", "concepts", "witness(s,prior,provenance)",
         "prior.sourceId=provenance.sourceId;prior.acquiredAt=provenance.acquiredAt;witness(s,prior,provenance)", "primary_acquisition_immutable"),
        ("discard-witness-refresh", "concepts", "prior.lastObservedAt=math.max(prior.lastObservedAt,provenance.acquiredAt)",
         "-- refresh discarded", "witness_refresh_retains_first_time"),
        ("ignore-semantic-polarity", "concepts", "if reusable(prior,id,identity,provenance.acquiredAt) and prior.affirmed==(edge.affirmed~=false)",
         "if reusable(prior,id,identity,provenance.acquiredAt)", "changed_polarity_mints_revision"),
        ("reuse-foreign-semantic-row", "concepts", "if reusable(prior,id,identity,provenance.acquiredAt) and prior.affirmed==(edge.affirmed~=false)",
         "if prior and prior.affirmed==(edge.affirmed~=false)", "canonical_observation_replaces_foreign_row"),
        ("ignore-semantic-basis", "concepts", "and prior.basis==provenance.basis then\n        witness(s,prior,provenance)",
         "and true then\n        witness(s,prior,provenance)", "changed_basis_mints_revision"),
        ("unbounded-witness-admission", "concepts", "if #support.rows>=MAX_WITNESSES then",
         "if false then", "witness_bound_exposes_truncation"),
        ("drop-ordinary-association", "concepts", '{"house", "typically-contains", "bedroom"}',
         '{"unrelated-place", "typically-contains", "bedroom"}', "cold_general_association"),
        ("mutate-on-query", "concepts", "local edges,denied,omitted,recalledContrary,sourceTruncated=available(id,contextId,background)",
         "state(id,true);local edges,denied,omitted,recalledContrary,sourceTruncated=available(id,contextId,background)", "query_does_not_write_knowledge"),
        ("ignore-contrary-premise", "concepts", "and edge.affirmed==false then",
         "and false then", "local_contradiction_blocks_expected_path"),
        ("globalize-local-exception", "concepts", "(edge.contextId==nil or edge.contextId==contextId) and edge.affirmed==false",
         "true and edge.affirmed==false", "local_exception_does_not_erase_general_prior"),
        ("accept-foreign-belief", "concepts", "valid(edge) and edge.actorId==id",
         "valid(edge) and true", "foreign_retained_relation_rejected"),
        ("lose-acquired-generalization", "concepts", 'basis="personal-association",sourceId=receipt.id',
         'basis="observed-relation",sourceId=receipt.id', "canonical_pair_generalizes_modally"),
        ("ignore-observed-means", "planning", "if means then", "if false then",
         "observed_means_precede_unlocated_room_label"),
        ("globalize-search-attempts", "planning", "local attempts=retained and retained.inquiry and retained.inquiry.attempts or {}",
         "for _,p in pairs(s and s.purposes or {}) do if p.inquiry and p.inquiry.goal==goal then retained=p;break end end\n    local attempts=retained and retained.inquiry and retained.inquiry.attempts or {}",
         "new_building_gets_own_search_budget"),
        ("ignore-stale-body-token", "perception", "not SAO.Needs or not SAO.Needs.ownsRecoveryBody or not SAO.Needs.ownsRecoveryBody(id,body)\n        or not finiteSoundNumber(tick)",
         "not SAO.Body or SAO.Body.get(id)~=body or not finiteSoundNumber(tick)", "stale_token_observation_rejected"),
        ("reuse-unavailable-observer", "perception", 'concepts.readerStatus~="available" or not finiteSoundNumber(tick)',
         'not finiteSoundNumber(tick)', "missing_bridge_explicitly_unavailable"),
        ("skip-standing", "controller", 'not purpose or not step or not SAO.Standing.mayAttemptBelieved(id,step.x,step.y,"standing")',
         'not purpose or not step', "standing_refuses_inquiry"),
        ("discard-inquiry-dispatch", "controller", 'if inquiry and inquiry.status=="actionable" then',
         'if false then', "refresh_preserves_actual_inquiry_choice"),
        ("accept-replaced-native-job", "controller", 'or not job or job~=binding.job or job.body~=body then',
         'or not job or job.body~=body then', "replacement_job_cannot_complete_inquiry"),
        ("lose-route-attempt", "planning", 'purpose.inquiry.attempts[step.target]={at=at,status=job.result=="arrived" and "approached" or "route-blocked"}',
         '-- attempt forgotten', "arrival_does_not_invent_object"),
        ("lose-budget-diagnostic", "concepts", 'else out.limitReached=true;out.omittedDerivations=out.omittedDerivations+1 end',
         'else out.omittedDerivations=out.omittedDerivations+1 end', "depth_exhaustion_is_not_absence"),
    ]
    if args.variants:
        variants=[v for v in variants if v[0] in args.variants]
        assert len(variants)==len(args.variants),'unknown or repeated variant'
    for name, file, old, new, marker in variants:
        texts = dict(sources)
        if file:
            assert texts[file].count(old) == 1, name
            texts[file] = texts[file].replace(old, new, 1)
        texts["controller"] = texts["controller"].replace("return Ctl\n", fixture.EXPOSE)
        texts["cases"] = texts.pop("ordinary") + "\n" + texts["cases"]
        for key, value in texts.items():
            (OUT / (key + ".lua")).write_text(value, encoding="utf-8")
        command = [fixture.JDK / "java.exe", "-cp", os.pathsep.join([str(jar), str(OUT)]), "LuaRun",
                   "prelude.lua", "models.lua", "cognition.lua", "needs.lua", "perception.lua", "concepts.lua",
                   "planning.lua", "locomotion.lua", "capture.lua", "controller.lua", "cases.lua", "--", "__result"]
        code, log = invoke(command)
        (OUT / (name + ".log")).write_bytes(log.encode("utf-8"))
        receipt["variants"].append({"name": name, "command": list(map(str, command)), "cwd": str(OUT),
            "exit": code, "expected": marker, "mutation": {"source": file, "before": old, "after": new} if file else None,
            "sha256": hashlib.sha256(log.encode()).hexdigest()})
        (OUT / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
        assert (code != 0 and "CONCEPT:" + marker in log) if marker else (code == 0 and "VALUE PASS concepts" in log), log
        print(name + ": " + log.strip().splitlines()[-1], flush=True)
    receipt["inputs_after"] = {p: hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in inputs}
    assert receipt["inputs_after"] == inputs
    receipt["status"] = "PASS"
    (OUT / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")

if __name__ == "__main__":
    try:
        run()
    except Exception as error:
        print("FAIL conceptual knowledge:", error, flush=True)
        raise SystemExit(1)
