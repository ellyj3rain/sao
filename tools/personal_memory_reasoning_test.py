"""Installed Kahlua: dated autobiographical recall changes actual inquiry dispatch.

Source admission, native observation and current clarity are controlled. Full
production Memory, Concepts, Planning, Cognition and Controller execute. No
rendered-game, trained-model, clinical or historical-corpus completion claim.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import concept_knowledge_test as existing
from native_proof_preflight import installed_presence

ROOT = existing.ROOT
FILES = dict(existing.FILES)
FILES.update(memory=ROOT / "mod/42.20/media/lua/shared/SAO_PersonalMemory.lua",
             memory_cases=ROOT / "tools/personal_memory_reasoning_cases.lua")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "_scratch/d1-person-history/reasoning")
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    f = existing.fixture
    jar = f.GAME / "projectzomboid.jar"
    paths = [*FILES.values(), Path(__file__), Path(existing.__file__), Path(f.__file__), f.RUNNER, jar, f.GAME / "stdlib.lua"]
    paths.append(Path(__file__).with_name('native_proof_preflight.py'))
    preflight = installed_presence(paths, f.GAME, f.JDK, "personal memory reasoning")
    if preflight is not None:
        raise SystemExit(preflight)
    pins = lambda: {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    receipt = {"schema": "sao-personal-memory-reasoning-proof/1", "status": "INCOMPLETE", "inputs": pins(), "runs": [], "boundary": __doc__}
    def save():
        (out / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    def invoke(command):
        result = subprocess.run(list(map(str, command)), cwd=out, capture_output=True, text=True, timeout=120)
        return result.returncode, result.stdout + result.stderr
    save()
    code, log = invoke([f.JDK / "javac.exe", "-cp", jar, "-d", out, f.RUNNER])
    assert code == 0, log
    shutil.copy2(f.GAME / "stdlib.lua", out / "stdlib.lua")
    (out / "prelude.lua").write_text(f.PRELUDE + "\nrequire=function()end\nISInventoryTransferAction={derive=function()return {}end}\n__ordinaryPerception={} for k,v in pairs(SAO.Perception) do __ordinaryPerception[k]=v end\n", encoding="utf-8")
    (out / "capture.lua").write_text("__conceptModules={planning=SAO.ProceduralPlanning,locomotion=SAO.Locomotion,perception=SAO.Perception}\nSAO.Perception=__ordinaryPerception\n", encoding="utf-8")
    original = {name: path.read_text(encoding="utf-8") for name, path in FILES.items()}
    original["controller"] = original["controller"].replace("return Ctl\n", f.EXPOSE)
    original["cases"] = original.pop("ordinary") + "\n" + original["cases"] + "\n" + original.pop("memory_cases")
    variants = [
        ("production", None, None, None),
        ("drop-memory-consumer", "concepts", 'if memory and type(memory.relations)=="function" then', 'if false then'),
        ("ignore-neuro-access", "memory", "if retained>=RECALL_THRESHOLD and clarity>0 then", "if retained>=RECALL_THRESHOLD then"),
        ("ignore-current-custody", "memory", "not ok or initial==nil or not equal(initial,state.initial)", "not ok or initial==nil"),
        ("restore-historical-veto", "concepts", "recalledContrary[#recalledContrary+1]=copy(edge)", 'denied[edge.from.."|"..edge.into]=copy(edge)'),
        ("discard-memory-omissions", "concepts", 'if ok and rootStatus=="truncated" then', 'if false then'),
        ("teach-private-autobiography", "concepts", '(edge.basis=="personal-association" or edge.basis=="taught-association")', '(edge.basis=="personal-association" or edge.basis=="taught-association" or edge.basis=="autobiographical-association")'),
    ]
    order = ["models", "cognition", "needs", "perception", "concepts", "planning", "locomotion", "capture", "controller", "memory", "cases"]
    markers = {"drop-memory-consumer": "dated_first_job_changes_inferred_means", "ignore-neuro-access": "present_impairment_withholds_recalled_premise", "ignore-current-custody": "rebound_custody_cannot_support_inference", "restore-historical-veto": "fresh_positive_survives_recalled_counterexample", "discard-memory-omissions": "omitted_history_is_not_claimed_complete", "teach-private-autobiography": "autobiography_not_automatically_taught"}
    for name, owner, old, new in variants:
        sources = dict(original)
        if owner:
            assert sources[owner].count(old) == 1, name
            sources[owner] = sources[owner].replace(old, new)
        for key, source in sources.items():
            (out / (key + ".lua")).write_text(source, encoding="utf-8")
        command = [f.JDK / "java.exe", "-cp", os.pathsep.join([str(jar), str(out)]), "LuaRun", "prelude.lua", *[key + ".lua" for key in order], "--", "__result"]
        code, log = invoke(command)
        (out / (name + ".log")).write_bytes(log.encode("utf-8"))
        receipt["runs"].append({"name": name, "exitCode": code, "log": name + ".log", "logSha256": hashlib.sha256(log.encode()).hexdigest()})
        save()
        assert (code != 0 and "CONCEPT:" + markers[name] in log) if owner else (code == 0 and "PASS autobiography reasoning" in log), log
        print(name + ": " + next((line for line in log.splitlines() if "VALUE " in line or "ERROR " in line), log[-800:]), flush=True)
    assert receipt["inputs"] == pins(), "inputs changed during check"
    receipt["status"] = "PASS"
    save()


if __name__ == "__main__":
    main()
