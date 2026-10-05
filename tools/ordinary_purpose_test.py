"""D1 ordinary-purpose production dispatch in installed Kahlua.

Native bodies, queues and organization/planning inputs are controlled. Existing
owners supply execution; this is not rendered gameplay or training acceptance.
"""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess
import flee_continuity_test as fixture
from native_proof_preflight import installed_presence

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "_scratch/d1-shared-reasoning/ordinary-purpose"
FILES = {
    "models": ROOT / "mod/42.20/media/lua/shared/SAO_CognitiveModels.lua",
    "cognition": ROOT / "mod/42.20/media/lua/shared/SAO_Cognition.lua",
    "needs": ROOT / "mod/42.20/media/lua/client/SAO_Needs.lua",
    "controller": ROOT / "mod/42.20/media/lua/client/SAO_Controller.lua",
    "cases": ROOT / "tools/ordinary_purpose_cases.lua",
}

def run():
    OUT.mkdir(parents=True, exist_ok=True)
    jar = fixture.GAME / "projectzomboid.jar"
    preflight = installed_presence([*FILES.values(), Path(__file__), Path(fixture.__file__), fixture.RUNNER, jar, fixture.GAME / "stdlib.lua",Path(__file__).with_name('native_proof_preflight.py')], fixture.GAME, fixture.JDK, "ordinary purpose")
    if preflight is not None:
        raise SystemExit(preflight)
    inputs = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in [*FILES.values(), Path(__file__), Path(fixture.__file__), fixture.RUNNER, jar, fixture.GAME / "stdlib.lua",Path(__file__).with_name('native_proof_preflight.py')]}
    receipt = {"schema": "sao-ordinary-purpose-proof/1", "status": "INCOMPLETE", "inputs": inputs, "variants": [], "boundary": __doc__}
    def invoke(command):
        result = subprocess.run(list(map(str, command)), cwd=OUT, capture_output=True, text=True, timeout=120)
        return result.returncode, result.stdout + result.stderr
    code, log = invoke([fixture.JDK / "javac.exe", "-cp", jar, "-d", OUT, fixture.RUNNER])
    assert code == 0, log
    shutil.copy2(fixture.GAME / "stdlib.lua", OUT / "stdlib.lua")
    (OUT / "prelude.lua").write_text(fixture.PRELUDE + "\nrequire=function()end\nISInventoryTransferAction={derive=function()return {}end}\n", encoding="utf-8")
    sources = {name: path.read_text(encoding="utf-8") for name, path in FILES.items()}
    variants = [
        ("production", None, None, None, None),
        ("discard-person-values", "controller", "local traits = SAO.Disposition.traits(id)\n    local initiative, discipline",
         "local traits = {initiative=.5,discipline=.5,compassion=.5,selfPreservation=.5}\n    local initiative, discipline", "chosen_responsibility_releases_owned_study"),
        ("cancel-selected-study", "controller", 'if activity ~= "study" and not agent.studyCancellationPending and SAO.Study then',
         'if SAO.Study then', "live_caller_preserves_chosen_study"),
        ("foreign-commitment", "controller", 'local eligible = commitment.actorId == tostring(id) and type(commitment.acceptedAt) == "number"',
         'local eligible = true and type(commitment.acceptedAt) == "number"', "foreign_assent_cannot_compete"),
        ("future-commitment", "controller", 'and commitment.acceptedAt >= 0 and commitment.acceptedAt <= now',
         'and commitment.acceptedAt >= 0', "future_assent_cannot_compete"),
        ("urgent-purpose", "controller", 'or math.max(needs.hunger, needs.thirst) >= policy().desperation\n        or needs.endurance',
         'or false\n        or needs.endurance', "urgent_need_keeps_existing_owner"),
        ("foreign-body", "controller", 'and SAO.Needs.ownsRecoveryBody(id, body)) then return nil end',
         'and true) then return nil end', "foreign_body_cannot_choose"),
        ("ignore-resource-cooldown", "controller", 'if carried or tick >= (retryAt or 0) then',
         'if true then', "deferred_food_does_not_hide_carried_water"),
        ("inherit-other-resource-cooldown", "controller", 'if category == "water" then retryAt = agent.nextWaterAt else retryAt = agent.nextForageAt end',
         'retryAt = category == "water" and agent.nextWaterAt or agent.nextForageAt', "water_keeps_independent_retry_clock"),
        ("discard-failed-resource-alternative", "controller", 'return decideNeedsAndCompanion(id, agent, body, tick, needs, ordinaryExcluded)',
         'return true', "failed_food_reconsiders_carried_water"),
        ("discard-failed-activity-alternative", "controller", 'ordinaryExcluded[offered.key] = true',
         'ordinaryExcluded[offered.key] = true; if true then return true end', "failed_study_reconsiders_recovery"),
        ("replace-delayed-commitment", "controller", 'if pending.commitmentId then selected = {id=pending.commitmentId} end',
         '-- selected responsibility discarded', "delayed_release_dispatches_selected_not_first"),
        ("lose-delayed-identity", "controller", 'agent.studyCancellationPending = { body = body, action = action, commitmentId = commitment.id }',
         'agent.studyCancellationPending = { body = body, action = action }', "pending_cancellation_retains_selected_identity"),
        ("replace-practice", "controller", 'if purpose and purpose.id == offered.payload.id and not purpose.resourceCategory',
         'if purpose and not purpose.resourceCategory', "changed_practice_does_not_inherit_selection"),
        ("discard-outcome-prediction", "models", 'adjustment = predicted.adjustment',
         'adjustment = 0', "contrary_recovery_changes_actual_dispatch"),
        ("cancel-foreign-queue", "controller", 'if member ~= action then return false end',
         'if false then return false end', "foreign_queued_action_is_not_cancelled"),
    ]
    for name, file, old, new, marker in variants:
        texts = dict(sources)
        if file:
            assert texts[file].count(old) == 1, name
            texts[file] = texts[file].replace(old, new, 1)
        texts["controller"] = texts["controller"].replace("return Ctl\n", fixture.EXPOSE)
        for key, value in texts.items():
            (OUT / (key + ".lua")).write_text(value, encoding="utf-8")
        command = [fixture.JDK / "java.exe", "-cp", os.pathsep.join([str(jar), str(OUT)]), "LuaRun", "prelude.lua", "models.lua", "cognition.lua", "needs.lua", "controller.lua", "cases.lua", "--", "__result"]
        code, log = invoke(command)
        (OUT / (name + ".log")).write_text(log, encoding="utf-8")
        receipt["variants"].append({"name": name, "command": list(map(str, command)),
            "cwd": str(OUT), "exit": code, "expected": marker,
            "mutation": {"source": file, "before": old, "after": new} if file else None,
            "sha256": hashlib.sha256(log.encode()).hexdigest()})
        (OUT / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
        assert (code != 0 and "PURPOSE:" + marker in log) if marker else (code == 0 and "VALUE PASS ordinary purpose" in log), log
        print(name + ": " + log.strip().splitlines()[-1], flush=True)
    receipt["inputs_after"] = {p: hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in inputs}
    assert receipt["inputs_after"] == inputs
    receipt["status"] = "PASS"
    (OUT / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")

if __name__ == "__main__":
    try:
        run()
    except Exception as error:
        print("FAIL ordinary purpose:", error, flush=True)
        raise SystemExit(1)
