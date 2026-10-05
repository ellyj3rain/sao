"""Explicit, saved-boundary delivery of a named gameplay source repair.

The gameplay transition and the positive-frame error disposition are
independent manifests. Neither edits a save nor rewrites a predecessor verdict.
"""
from __future__ import annotations

from contextlib import contextmanager
from collections import Counter
import copy
import hashlib
import os
from pathlib import Path
import re
import shutil
import stat
import uuid

import world_lab as Lab

FILES = frozenset(("42.20/media/lua/client/SAO_DormantPopulation.lua",
                   "42.20/media/lua/client/SAO_Population.lua"))
PROFILES = {
    "recovery-completion-callback": frozenset(("42.20/media/lua/client/SAO_RecoveryPose.lua",)),
    "recovery-callback-preparation": frozenset((
        "42.20/media/lua/client/SAO_RecoveryPose.lua",
        "42.20/media/lua/client/SAO_Needs.lua",
        "42.20/media/lua/client/SAO_Controller.lua")),
    "recovery-callback-preparation-rebind": frozenset((
        "42.20/media/lua/client/SAO_RecoveryPose.lua",
        "42.20/media/lua/client/SAO_Needs.lua",
        "42.20/media/lua/client/SAO_Controller.lua")),
    "recovery-callback-preparation-budgets": frozenset((
        "42.20/media/lua/client/SAO_RecoveryPose.lua",
        "42.20/media/lua/client/SAO_Needs.lua",
        "42.20/media/lua/client/SAO_Controller.lua")),
    "population-resume": FILES,
    "private-threat-contacts": frozenset((
        "42.20/media/lua/shared/SAO_Perception.lua",
        "42.20/media/lua/client/SAO_ConflictResponse.lua")),
    "threat-gesture-release": frozenset((
        "42.20/media/lua/client/SAO_Gesture.lua",
        "42.20/media/lua/client/SAO_ConflictResponse.lua")),
    "d1-shared-reasoning": frozenset((
        "42.20/media/lua/client/SAO_Controller.lua",
        "42.20/media/lua/client/SAO_Cooking.lua",
        "42.20/media/lua/client/SAO_DormantPopulation.lua",
        "42.20/media/lua/client/SAO_Exchange.lua",
        "42.20/media/lua/client/SAO_Needs.lua",
        "42.20/media/lua/client/SAO_Study.lua",
        "42.20/media/lua/shared/SAO_Communication.lua",
        "42.20/media/lua/shared/SAO_ConceptKnowledge.lua",
        "42.20/media/lua/shared/SAO_Perception.lua",
        "42.20/media/lua/shared/SAO_ProceduralPlanning.lua",
        "42.20/media/lua/shared/SAO_Cognition.lua",
        "42.20/media/lua/shared/SAO_CognitiveModels.lua",
        "42.20/media/lua/shared/SAO_Organization.lua",
        "42.20/media/java/SAO.jar")),
}
PROFILE_FILES = frozenset().union(*PROFILES.values())
MOD = "SurvivorAwareness"
UPDATE_SCHEMA = "sao.study-gameplay-lua-update/1"
SOURCE_UPDATE_SCHEMA = "sao.study-gameplay-source-update/2"
SOURCE_SUBSET_SCHEMA = "sao.study-gameplay-source-update/3"
ERROR_SCHEMA = "sao.study-reviewed-errors/1"
DISPOSITION = "saved-continuation-with-reviewed-errors"
CALLBACK_ERROR_SCHEMA = "sao.study-reviewed-callback-save/1"
CALLBACK_DISPOSITION_SCHEMA = "sao.study-callback-error-disposition/1"
CALLBACK_DISPOSITION = "saved-continuation-with-reviewed-callback-failure"
CALLBACK_PROFILE = "recovery-completion-callback"
CALLBACK_POSE = "42.20/media/lua/client/SAO_RecoveryPose.lua"
CALLBACK_BEFORE = "6c52eec13104763f42a0d7858843425c479f25d10628b43a6a570dabd2c3518b"
CALLBACK_AFTER = "e3c1cf3d63295482f642a14b90b4ba176f997b2c132ed6e30a7e1bfc599de228"
CALLBACK_PREPARATION_PROFILE = "recovery-callback-preparation"
CALLBACK_REBIND_PROFILE = "recovery-callback-preparation-rebind"
CALLBACK_BUDGETS_PROFILE = "recovery-callback-preparation-budgets"
CALLBACK_PROFILES = frozenset((CALLBACK_PROFILE, CALLBACK_PREPARATION_PROFILE, CALLBACK_REBIND_PROFILE, CALLBACK_BUDGETS_PROFILE))
CALLBACK_BUDGETS_NEEDS_AFTER = 'dce2a6916d22fb70811193ab7edf8636a612fd8b305f139b5a7425f6869efdd0'
CALLBACK_BUDGETS_CONTROLLER_AFTER = '23a8124778d878fa3a63ab3b02f02565b287a759885f7c49ebb7bf0b4d6970f4'
CALLBACK_REBIND_NEEDS_AFTER = 'dce2a6916d22fb70811193ab7edf8636a612fd8b305f139b5a7425f6869efdd0'
CALLBACK_REBIND_CONTROLLER_AFTER = '1c76b439d990533d591ab8fa2a08c8ae604ecdaa5525ac3590c29c52f60c1509'
CALLBACK_NEEDS = "42.20/media/lua/client/SAO_Needs.lua"
CALLBACK_CONTROLLER = "42.20/media/lua/client/SAO_Controller.lua"
CALLBACK_NEEDS_BEFORE = "c904b95c94613cbba003728c87f5ba5ed8f2a8944cbedfb0f9d9bd41c8084871"
CALLBACK_NEEDS_AFTER = "7f7b672ff5513c0d541207efc79885ecff825a83b267bd06cee69caccdf72279"
CALLBACK_CONTROLLER_BEFORE = "7a7a2587235e7e219a7d4991ca128fb5e9d57b788f0dace629e5348b2c25c0e4"
CALLBACK_CONTROLLER_AFTER = "f52f7a3d12ed3cc4abbcfc7dc11acb4b29038f75c60c8f97c378d4745239890c"
CALLBACK_RECEIPT = "13525936a836a8035f5a756306a239837edeac9839b19c6aa9dda3907b66fe7d"
CALLBACK_ENGINE = "e1a69eb743ede60b213a0fe7f8b83d4fcab773036d256cc4543a336f3b058a33"
CALLBACK_STATE = "2538e4b2f95e18c6a4d1ca7e8e8823a6da4a6d9072c40763b21e6cdf01b25ad7"
CALLBACK_VIEW = "db9f645e2bbdc7be1ed5e9206b80672f93153c60bbf2be4af372b3e401af2d22"
CALLBACK_FRAME = "562ddfced091700c1d4487e78cf0d6073c910d7d97176b964cd2753feefb3bc0"
CALLBACK_DIAGNOSIS = "d0cc844ccea9ae3b440e85ace040f3c916e0a1d71b7e9e6c6c2cc260cceab98a"
CALLBACK_PROOF = "3a7adbe0d7e176002fbfc9b0e322a93c65d98df5ea71c604440edc40d712c664"
CALLBACK_SAVE_EVIDENCE = "781dd857d8f70a5fa00223d599a9d85e01e2c33d9339896464f826006925b9c1"
CALLBACK_ERRORS = (
    "Lua fail. Message: Tried to call nil", "Lua fail. Message:",
    "ERROR: General      f:843> Lua((MOD:Horse Mod)).complete> Exception thrown",
    "java.lang.RuntimeException:  at KahluaUtil.fail(KahluaUtil.java:100).",
    "run supervision: [StudyObserver] FAILED",
    "observer evidence: native observer participation or advancement evidence failed")
CALLBACK_PREDECESSOR = {"sessionId": "63aeeb64-939a-4ce6-becd-51dc222a13e8",
    "attempt": 1, "save": "2624568553350387025", "receiptSha256": CALLBACK_RECEIPT}
CALLBACK_QUALIFICATION = {"originalStatus": "incomplete", "observerStatus": "failed",
    "worldFrameSequence": 1, "population": 0, "nativeSaveReturned": True,
    "historicalSuccessCredit": False}
GROUND_TILES = frozenset((18, 19, 21, 22, 23))
# This explicit incident was reviewed against installed save/load bytecode.
# The attempt-bound manifest must retain its exact stack and evidence; this is
# not a general LungeState exception allowance.
LUNGE_ERRORS = (
    "ERROR: Multiplayer  f:34894> StateMachine.stateExecute> Exception thrown",
    "java.lang.IllegalStateException: Forward Direction cannot be zero length vector. at IsoGameCharacter.setForwardDirection(IsoGameCharacter.java:2829). Message: State execute error: LungeState")
LUNGE_STACK_SHA256 = "661d83ab68278c2693214c298d86d4fef6adf0b21a3171a2136776fd2c6bd8d0"
ANIMATION_ERRORS = (
    "ERROR: General      f:3936> AdvancedAnimator.checkModifiedFiles> Exception thrown",
    'java.lang.NullPointerException: Cannot read field "bodyModel" because the return value of "zombie.characters.animals.AnimalDefinitions.getDef(String)" is null at AnimalVisual.getModel(AnimalVisual.java:83).')
ANIMATION_STACK_SHA256 = "779de6ad1049e52614819a4fac1fd293ca9ff268e69ebed1bbfdd9c598e64042"
ANIMATION_BONE_COUNTS_SHA256 = "2f3fc559b78e4900d46a55db4df2ca3ce06e58b7541381852cfecc5d5d797c68"
ANIMATION_BONE_FRAMES_SHA256 = "c6765b99215f13eaa56fdd0d0eed301864c16dc174d4cc77f876d96d97d38b8c"


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def file_path(path):
    # Inspect lexical ancestors before resolving: Windows junctions are reparse
    # points but are not reported as symlinks. Include cwd ancestors for relative
    # inputs, and refuse every reparse tag rather than just junctions.
    path = Path(path).absolute()
    for part in (*reversed(path.parents), path):
        info = part.lstat()
        Lab.require(not stat.S_ISLNK(info.st_mode)
                    and not (getattr(info, "st_file_attributes", 0)
                             & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400)),
                    "delivery input must have no linked or reparse ancestors")
    Lab.require(stat.S_ISREG(info.st_mode),
                "delivery input must be a regular non-linked file")
    return path.resolve()


def publish(path, value):
    path.write_bytes(Lab.canonical(value))


def binding(receipt, receipt_sha):
    return {"sessionId": receipt["sessionId"], "attempt": receipt["launchNumber"],
            "save": receipt["save"], "receiptSha256": receipt_sha}


def process_live(pid):
    # Reuse the host's read-only Windows process test; import lazily to avoid a
    # runner/session import cycle. No process is signalled by this query.
    from world_lab_session import native_process_live
    return native_process_live(pid)


def saved_boundary(receipt, disposition=None):
    Lab.require(receipt.get("status") in ("completed", "incomplete")
                and receipt.get("exitCode") == 0 and receipt.get("host") == "observer"
                and receipt.get("terminal", {}).get("nativeSaveReturned") is True,
                "delivery requires a terminal observer save")
    supervision = receipt.get("supervision", {})
    qualified = disposition is not None and disposition.get("schema") == CALLBACK_DISPOSITION_SCHEMA
    if qualified:
        _callback_qualification(receipt, disposition)
    Lab.require(supervision.get("forced") is False and (supervision.get("failure") is None
                or qualified and supervision.get("failure") == "[StudyObserver] FAILED"),
                "forced or failed native owner cannot continue")
    Lab.require(type(receipt.get("pid")) is int and not process_live(receipt["pid"]),
                "delivery requires the native process to have exited")


def error_rows(logs, positive_only=False):
    rows = []
    for name in ("stdout.log", "stderr.log"):
        for line, text in enumerate(logs[name].splitlines(), 1):
            if "ERROR:" not in text:
                continue
            frame = re.search(r"\bf:(\d+)", text)
            if positive_only and frame is not None and int(frame[1]) == 0:
                continue
            rows.append({"log": name, "line": line, "text": text.strip()})
    return rows


def lunge_bundle(evidence, receipt):
    Lab.require(set(evidence) == {"path", "sha256"}, "lunge evidence fields differ")
    path = file_path(evidence["path"])
    Lab.require(digest(path) == evidence["sha256"], "lunge evidence hash differs")
    diagnosis = Lab.load(path)
    incident = diagnosis["incident"]
    Lab.require(diagnosis["schema"] == "sao.native-lunge-diagnosis/1"
                and diagnosis["status"] == "ANALYZED_WITH_QUALIFICATIONS"
                and diagnosis["sessionId"] == receipt["sessionId"]
                and diagnosis["attempt"] == receipt["launchNumber"]
                and diagnosis["save"] == receipt["save"]
                and diagnosis["engineJarSha256"] == receipt["engineJarSha256"]
                and diagnosis["originalVerdict"] == receipt["status"] == "incomplete"
                and incident["frame"] == 34894 and incident["episodesInRetainedStderr"] == 1
                and incident["runtimeErrorRows"] == list(LUNGE_ERRORS)
                and incident["stackSha256"] == LUNGE_STACK_SHA256
                and incident["stderrSha256"] == receipt["logs"]["stderr.log"],
                "lunge incident/engine/predecessor differs")
    names = {"receipt.json": evidence["sha256"], incident["stackFile"]: LUNGE_STACK_SHA256,
             diagnosis["bytecodeInputsFile"]: diagnosis["bytecodeInputsSha256"]}
    for name, expected in names.items():
        Lab.require(Path(name).name == name and digest(file_path(path.parent / name)) == expected,
                    "lunge retained evidence differs")
    bytecode = Lab.load(path.parent / diagnosis["bytecodeInputsFile"])
    Lab.require(bytecode["jarSha256"] == receipt["engineJarSha256"], "lunge bytecode engine differs")
    required = {"zombie.ai.StateMachine", "zombie.ai.states.LungeState", "zombie.characters.IsoGameCharacter",
                "zombie.characters.IsoZombie", "zombie.iso.IsoMovingObject", "zombie.iso.IsoDirections"}
    Lab.require(required <= {row["class"] for row in bytecode["classes"]}, "lunge save/load evidence incomplete")
    for row in bytecode["classes"]:
        name = row["bytecodeFile"].replace("\\", "/").rsplit("/", 1)[-1]
        Lab.require(row["exitCode"] == 0 and digest(file_path(path.parent / name)) == row["bytecodeSha256"],
                    "lunge bytecode evidence differs")
        names[name] = row["bytecodeSha256"]
    return path.parent, names, diagnosis


def animation_bundle(evidence, receipt):
    Lab.require(set(evidence) == {"path", "sha256"}, "animation evidence fields differ")
    path = file_path(evidence["path"])
    Lab.require(digest(path) == evidence["sha256"], "animation evidence hash differs")
    diagnosis = Lab.load(path)
    incident = diagnosis["incident"]
    Lab.require(diagnosis["schema"] == "sao.native-animation-incident/1"
                and diagnosis["status"] == "ANALYZED_WITH_QUALIFICATIONS"
                and diagnosis["sessionId"] == receipt["sessionId"]
                and diagnosis["attempt"] == receipt["launchNumber"]
                and diagnosis["save"] == receipt["save"]
                and diagnosis["engineJarSha256"] == receipt["engineJarSha256"]
                and diagnosis["originalVerdict"] == receipt["status"] == "incomplete"
                and incident["frame"] == 3936 and incident["episodesInRetainedStderr"] == 1
                and incident["runtimeErrorRows"] == list(ANIMATION_ERRORS)
                and incident["stackSha256"] == ANIMATION_STACK_SHA256
                and incident["boneCountsSha256"] == ANIMATION_BONE_COUNTS_SHA256
                and incident["boneFramesSha256"] == ANIMATION_BONE_FRAMES_SHA256
                and incident["stderrSha256"] == receipt["logs"]["stderr.log"],
                "animation incident/engine/predecessor differs")
    names = {"receipt.json": evidence["sha256"], incident["stackFile"]: ANIMATION_STACK_SHA256,
             diagnosis["bytecodeInputsFile"]: diagnosis["bytecodeInputsSha256"],
             diagnosis["repairProofFile"]: diagnosis["repairProofSha256"]}
    for name, expected in names.items():
        Lab.require(Path(name).name == name and digest(file_path(path.parent / name)) == expected,
                    "animation retained evidence differs")
    proof = Lab.load(path.parent / diagnosis["repairProofFile"])
    Lab.require(proof["schema"] == "sao-native-animation-diagnosis/1"
                and proof["status"] == "REPAIR_VERIFIED_NATIVE_ACCEPTANCE_OPEN"
                and proof["engine"]["sha256"] == receipt["engineJarSha256"]
                and proof["proof"]["wrongBooleanDefectControls"] == 1
                and proof["proof"]["observerLifecycleBaselines"] == 2,
                "observer constructor repair proof differs")
    bytecode = Lab.load(path.parent / diagnosis["bytecodeInputsFile"])
    Lab.require(bytecode["jarSha256"] == receipt["engineJarSha256"], "animation bytecode engine differs")
    required = {"zombie.characters.IsoPlayer", "zombie.core.skinnedmodel.visual.AnimalVisual",
                "zombie.core.skinnedmodel.ModelManager", "zombie.core.skinnedmodel.advancedanimation.AdvancedAnimator",
                "zombie.Lua.LuaManager$GlobalObject", "zombie.core.skinnedmodel.model.jassimp.ImportedSkeleton"}
    Lab.require(required <= {row["class"] for row in bytecode["classes"]}, "animation ownership evidence incomplete")
    for row in bytecode["classes"]:
        name = row["bytecodeFile"]
        Lab.require(Path(name).name == name and row["exitCode"] == 0
                    and digest(file_path(path.parent / name)) == row["bytecodeSha256"],
                    "animation bytecode evidence differs")
        names[name] = row["bytecodeSha256"]
    return path.parent, names, diagnosis


def reviewed_errors(destination, receipt, manifest_path, logs, detected_runtime_errors):
    """Return qualified continuation, retaining every prior error and verdict."""
    destination = Path(destination)
    manifest_path = file_path(manifest_path)
    value = Lab.load(manifest_path)
    if value.get("schema") == CALLBACK_ERROR_SCHEMA:
        return _reviewed_callback(destination, receipt, manifest_path, value, logs, detected_runtime_errors)
    required = {"schema", "predecessor", "engineJarSha256", "errors", "evidence"}
    Lab.require(set(value) in (required, required | {"lungeIncident"}, required | {"animationIncident"})
                and value["schema"] == ERROR_SCHEMA, "reviewed-error manifest fields differ")
    Lab.require(value["predecessor"] == binding(receipt, digest(destination / "run.json")),
                "reviewed-error predecessor differs")
    saved_boundary(receipt)
    Lab.require(value["engineJarSha256"] == receipt["engineJarSha256"], "reviewed engine differs")
    rows = error_rows(logs, positive_only=True)
    lunge = value.get("lungeIncident")
    animation = value.get("animationIncident")
    Lab.require(rows == value["errors"] and len(rows) == (1256 if animation else 6 if lunge else 5),
                "reviewed error fingerprints/count differ")
    ground, bones, bone_frames = [], Counter(), Counter()
    for row in rows:
        if (lunge and row["text"] == LUNGE_ERRORS[0]) or (animation and row["text"] == ANIMATION_ERRORS[0]):
            continue
        match = re.fullmatch(r'ERROR: General\s+f:(\d+) at ImportedSkeleton\.collectBoneFrames\s+> Could not find bone index for node name: "([^"]+)"', row["text"]) if animation else None
        if match:
            Lab.require(3910 <= int(match[1]) <= 3953, "animation bone event outside reviewed interval")
            bones[match[2]] += 1
            bone_frames[match[1] + ":" + match[2]] += 1
        else:
            ground.append(row)
    if animation:
        Lab.require(sum(bones.values()) == 1250 and Lab.seal(dict(bones)) == ANIMATION_BONE_COUNTS_SHA256
                    and Lab.seal(dict(bone_frames)) == ANIMATION_BONE_FRAMES_SHA256,
                    "animation bone fingerprints/count differ")
    tiles = []
    for row in ground:
        match = re.fullmatch(r"ERROR: General\s+f:[1-9]\d* at CellLoader\.DoTileObjectCreation\s+> CellLoader> missing tile vegetation_groundcover_01_(\d+)", row["text"])
        Lab.require(match is not None, "unreviewed positive-frame error")
        tiles.append(int(match[1]))
    Lab.require(set(tiles) == GROUND_TILES and len(tiles) == 5, "unreviewed groundcover tile/count")
    expected_runtime = list(ANIMATION_ERRORS) if animation else list(LUNGE_ERRORS) if lunge else []
    Lab.require(detected_runtime_errors == receipt.get("runtimeErrors") == expected_runtime,
                "unreviewed native runtime failure")
    if lunge:
        bundle_root, bundle_files, diagnosis = lunge_bundle(lunge, receipt)
        stack = (bundle_root / diagnosis["incident"]["stackFile"]).read_text(encoding="utf-8")
        Lab.require(logs["stderr.log"].count(stack) == 1, "exact reviewed lunge stack missing or repeated")
    if animation:
        bundle_root, bundle_files, diagnosis = animation_bundle(animation, receipt)
        stack = (bundle_root / diagnosis["incident"]["stackFile"]).read_text(encoding="utf-8")
        Lab.require(logs["stderr.log"].count(stack) == 1, "exact reviewed animation stack missing or repeated")
    evidence = value["evidence"]
    Lab.require(set(evidence) == {"path", "sha256"}, "reviewed evidence fields differ")
    source = file_path(evidence["path"])
    Lab.require(digest(source) == evidence["sha256"], "reviewed fallback evidence differs")
    text = source.read_text(encoding="utf-8")
    Lab.require(all(marker in text for marker in ("DoTileObjectCreation", "hasNoTextures", "missing-tile-debug.png", "missing-tile.png")),
                "reviewed native fallback evidence is incomplete")
    result = {"schema": "sao.study-error-disposition/1", "disposition": DISPOSITION,
              "predecessor": value["predecessor"], "manifestSha256": digest(manifest_path),
              "originalStatus": receipt["status"], "originalRuntimeErrors": receipt["runtimeErrors"],
              "reviewedErrors": rows, "allLogErrors": error_rows(logs), "evidence": evidence}
    if lunge:
        result["lungeIncident"] = {"evidence": lunge, "files": bundle_files,
                                  "limitations": diagnosis["recommendation"]["limitations"]}
    if animation:
        result["animationIncident"] = {"evidence": animation, "files": bundle_files,
                                      "limitations": diagnosis["recommendation"]["limitations"]}
    return result


def _callback_pin(value, expected=None):
    Lab.require(isinstance(value, dict) and set(value) == {"path", "sha256"},
                "callback evidence pin fields differ")
    path = file_path(value["path"])
    Lab.require(digest(path) == value["sha256"] and (expected is None or value["sha256"] == expected),
                "callback evidence hash differs")
    return path


def callback_source_pins(profile):
    """Exact reviewed source tuples; preparation guard proof is separately attributed."""
    Lab.require(profile in CALLBACK_PROFILES, "unknown callback source profile")
    pins = {CALLBACK_POSE: (CALLBACK_BEFORE, CALLBACK_AFTER)}
    if profile == CALLBACK_PREPARATION_PROFILE:
        pins[CALLBACK_NEEDS] = (CALLBACK_NEEDS_BEFORE, CALLBACK_NEEDS_AFTER)
        pins[CALLBACK_CONTROLLER] = (CALLBACK_CONTROLLER_BEFORE, CALLBACK_CONTROLLER_AFTER)
    elif profile == CALLBACK_REBIND_PROFILE:
        Lab.require(isinstance(CALLBACK_REBIND_NEEDS_AFTER, str)
                    and re.fullmatch(r"[0-9a-f]{64}", CALLBACK_REBIND_NEEDS_AFTER) is not None
                    and isinstance(CALLBACK_REBIND_CONTROLLER_AFTER, str)
                    and re.fullmatch(r"[0-9a-f]{64}", CALLBACK_REBIND_CONTROLLER_AFTER) is not None,
                    "callback rebind source pins are not frozen")
        pins[CALLBACK_NEEDS] = (CALLBACK_NEEDS_BEFORE, CALLBACK_REBIND_NEEDS_AFTER)
        pins[CALLBACK_CONTROLLER] = (CALLBACK_CONTROLLER_BEFORE, CALLBACK_REBIND_CONTROLLER_AFTER)
    elif profile == CALLBACK_BUDGETS_PROFILE:
        Lab.require(isinstance(CALLBACK_BUDGETS_NEEDS_AFTER, str)
                    and re.fullmatch(r"[0-9a-f]{64}", CALLBACK_BUDGETS_NEEDS_AFTER) is not None
                    and isinstance(CALLBACK_BUDGETS_CONTROLLER_AFTER, str)
                    and re.fullmatch(r"[0-9a-f]{64}", CALLBACK_BUDGETS_CONTROLLER_AFTER) is not None,
                    "callback budgets source pins are not frozen")
        pins[CALLBACK_NEEDS] = (CALLBACK_NEEDS_BEFORE, CALLBACK_BUDGETS_NEEDS_AFTER)
        pins[CALLBACK_CONTROLLER] = (CALLBACK_CONTROLLER_BEFORE, CALLBACK_BUDGETS_CONTROLLER_AFTER)
    return pins


def _callback_qualification(receipt, disposition):
    Lab.require(disposition.get("schema") == CALLBACK_DISPOSITION_SCHEMA
                and disposition.get("disposition") == CALLBACK_DISPOSITION
                and disposition.get("predecessor") == CALLBACK_PREDECESSOR
                and disposition.get("originalReceiptSeal") == Lab.seal(receipt) == CALLBACK_RECEIPT
                and binding(receipt, CALLBACK_RECEIPT) == CALLBACK_PREDECESSOR
                and receipt.get("status") == "incomplete"
                and receipt.get("runtimeErrors") == list(CALLBACK_ERRORS),
                "callback qualification differs from exact failed predecessor")
    approval = Lab.load(_callback_pin(disposition["callbackIncident"]["approval"]))
    update_pin = disposition["callbackIncident"]["update"]
    update = Lab.load(_callback_pin(update_pin))
    Lab.require(update_shape(update) in CALLBACK_PROFILES and update["predecessor"] == CALLBACK_PREDECESSOR,
                "callback qualification update differs")
    Lab.require(approval == disposition["callbackIncident"]["approvedReview"]
                and approval == _callback_approval(update_pin["sha256"]),
                "callback root approval unavailable or changed")


def _callback_approval(update_sha):
    return {"schema": "sao.reviewed-callback-save-approval/1", "status": "APPROVED",
        "predecessor": copy.deepcopy(CALLBACK_PREDECESSOR), "engineJarSha256": CALLBACK_ENGINE,
        "updateSha256": update_sha, "diagnosisSha256": CALLBACK_DIAGNOSIS,
        "factoryProofSha256": CALLBACK_PROOF, "saveEvidenceSha256": CALLBACK_SAVE_EVIDENCE,
        "qualification": copy.deepcopy(CALLBACK_QUALIFICATION)}


def verify_callback_observer(destination, receipt, disposition):
    """Read exact failed evidence; it supplies no healthy-observer verdict."""
    _callback_qualification(receipt, disposition)
    destination = Path(destination)
    attempt = destination / "attempts/0001"
    state_path, view_path = attempt / "observer-state.json", attempt / "native-view/native.json"
    Lab.require(digest(file_path(state_path)) == CALLBACK_STATE and digest(file_path(view_path)) == CALLBACK_VIEW,
                "callback failed observer or native view changed")
    state, view = Lab.load(state_path), Lab.load(view_path)
    Lab.require(state["status"] == "failed" and state["worldAdvanced"] is True
                and state["hours"] == receipt["terminal"]["endHours"]
                and "SAO_RecoveryPose.lua:245" in state["failure"]
                and state["detached"] is True and state["objects"] == state["squareMemberships"] == 0,
                "callback failed observer incident differs")
    files = {"observer-state.json": {"path": str(state_path), "sha256": CALLBACK_STATE},
             "native-view.json": {"path": str(view_path), "sha256": CALLBACK_VIEW}}
    for index, image in enumerate([view["image"], *[v["image"] for v in view.get("views", [])]]):
        name = image["file"]
        Lab.require(Path(name).name == name, "unsafe callback native image")
        image_path = file_path(view_path.parent / name)
        Lab.require(digest(image_path) == image["sha256"], "callback native image changed")
        files["native-image-" + str(index) + ".png"] = {"path": str(image_path), "sha256": image["sha256"]}
    Lab.require(len(receipt["observations"]) == 1, "callback requires exactly one original world frame")
    relative, frame_hash = next(iter(receipt["observations"].items()))
    frame_path = (destination / "cache" / relative).resolve()
    Lab.require(frame_path.is_relative_to(destination.resolve() / "cache/Lua/StudyWorld")
                and frame_hash == CALLBACK_FRAME and digest(file_path(frame_path)) == CALLBACK_FRAME,
                "callback original world frame changed")
    frame = Lab.load(frame_path)
    Lab.require(frame["sequence"] == 1 and frame["countyHours"] == 2 and frame["people"] == []
                and frame["population"]["total"] == frame["population"]["captured"] == 0
                and frame["save"] == receipt["save"] and frame["definitionSha256"] == receipt["definitionSha256"],
                "callback initial population-zero frame differs")
    files["original-world-frame.json"] = {"path": str(frame_path), "sha256": CALLBACK_FRAME}
    return {"state": state, "view": view, "files": files,
            "qualification": copy.deepcopy(CALLBACK_QUALIFICATION)}


def _reviewed_callback(destination, receipt, manifest_path, value, logs, detected):
    required = {"schema", "predecessor", "engineJarSha256", "runtimeErrors", "detectedRuntimeErrors",
                "approval", "diagnosis", "factoryProof", "saveEvidence", "update"}
    Lab.require(set(value) == required, "callback review manifest fields differ")
    Lab.require(value["predecessor"] == binding(receipt, digest(destination / "run.json")) == CALLBACK_PREDECESSOR
                and Lab.load(destination / "run.json") == receipt,
                "callback exact predecessor UUID/save/receipt differs")
    Lab.require(value["engineJarSha256"] == receipt["engineJarSha256"] == CALLBACK_ENGINE
                and value["runtimeErrors"] == receipt["runtimeErrors"] == list(CALLBACK_ERRORS)
                and value["detectedRuntimeErrors"] == detected == list(CALLBACK_ERRORS[:4]),
                "callback exact six receipt and four detected fault fingerprints differ")
    Lab.require(receipt["terminal"] == {"endHours": 2.248784065246582, "nativeSaveReturned": True,
                "receiptFormat": "supervisor-stop/2", "startHours": 2.0, "stopReason": "producer-failure"}
                and receipt["supervision"]["forced"] is False
                and receipt["supervision"]["failure"] == "[StudyObserver] FAILED",
                "callback failed native save boundary differs")
    for name in ("stdout.log", "stderr.log"):
        Lab.require(digest(file_path(destination / "attempts/0001" / name)) == receipt["logs"][name]
                    and logs[name] == (destination / "attempts/0001" / name).read_text(encoding="utf-8", errors="replace"),
                    "callback original log bytes/content changed")
    Lab.require(logs["stderr.log"].count(CALLBACK_ERRORS[2]) == 1
                and logs["stdout.log"].count("sao-2 recovery admission accepted: sleep at bed:3424.0:10901.0:0.0:2:6e7239a1") == 1,
                "callback fault/admission count differs")
    diagnosis = _callback_pin(value["diagnosis"], CALLBACK_DIAGNOSIS)
    proof_path = _callback_pin(value["factoryProof"], CALLBACK_PROOF)
    save_evidence = _callback_pin(value["saveEvidence"], CALLBACK_SAVE_EVIDENCE)
    proof = Lab.load(proof_path)
    Lab.require(proof["status"] == "PASS" and len(proof["variants"]) == 4
                and [v["exit"] for v in proof["variants"]] == [0, 1, 1, 1], "callback installed factory proof differs")
    update_path = _callback_pin(value["update"])
    update = Lab.load(update_path)
    Lab.require(update_shape(update) in CALLBACK_PROFILES and update["predecessor"] == CALLBACK_PREDECESSOR,
                "callback requires an exact reviewed source profile")
    approval = Lab.load(_callback_pin(value["approval"]))
    expected_approval = _callback_approval(value["update"]["sha256"])
    Lab.require(approval == expected_approval, "callback explicit root-approved review differs or missing")
    result = {"schema": CALLBACK_DISPOSITION_SCHEMA, "disposition": CALLBACK_DISPOSITION,
        "predecessor": copy.deepcopy(value["predecessor"]), "manifestSha256": digest(manifest_path),
        "originalReceiptSeal": Lab.seal(receipt), "originalStatus": receipt["status"],
        "originalRuntimeErrors": list(receipt["runtimeErrors"]), "reviewedErrors": error_rows(logs, True),
        "allLogErrors": error_rows(logs), "evidence": value["diagnosis"],
        "callbackIncident": {"approval": value["approval"], "approvedReview": approval,
            "qualification": copy.deepcopy(CALLBACK_QUALIFICATION), "update": value["update"], "files": {}}}
    saved_boundary(receipt, result)
    observer = verify_callback_observer(destination, receipt, result)
    files = result["callbackIncident"]["files"]
    files.update(observer["files"])
    for name, path in (("diagnosis.json", diagnosis), ("factory-proof.json", proof_path),
                       ("save-evidence.json", save_evidence), ("approval.json", _callback_pin(value["approval"])),
                       ("required-update.json", update_path)):
        files[name] = {"path": str(path), "sha256": digest(path)}
    for v in proof["variants"]:
        path = file_path(proof_path.parent / (v["name"] + ".log"))
        Lab.require(digest(path) == v["logSha256"], "callback factory control log changed")
        files["factory-" + v["name"] + ".log"] = {"path": str(path), "sha256": digest(path)}
    Lab.require(proof["inputsAfter"] == proof["inputs"], "callback factory proof input continuity differs")
    for source, expected in proof["inputs"].items():
        path = file_path(source)
        Lab.require(digest(path) == expected, "callback factory proof source dependency changed")
        if path.suffix in (".py", ".lua", ".java"):
            files["factory-source-" + expected + path.suffix] = {"path": str(path), "sha256": expected}
    Lab.require(len(receipt["saveFiles"]) == 439, "callback original saved inventory count differs")
    for relative, expected in receipt["saveFiles"].items():
        path = (destination / "cache" / relative).resolve()
        Lab.require(path.is_relative_to(destination.resolve() / "cache/Saves")
                    and digest(file_path(path)) == expected, "callback saved byte differs")
    validate_update(destination, receipt, update_path, result)
    return result


def update_shape(value):
    required = {"schema", "predecessor", "modId", "files"}
    Lab.require(isinstance(value, dict) and set(value) in (required, required | {"profile"})
                and value["modId"] == MOD,
                "gameplay update manifest fields differ")
    profile = value.get("profile", "population-resume")
    Lab.require(isinstance(profile, str) and profile in PROFILES,
                "unknown gameplay update profile")
    schema = SOURCE_UPDATE_SCHEMA if profile == "d1-shared-reasoning" else UPDATE_SCHEMA
    subset = profile == "d1-shared-reasoning" and value["schema"] == SOURCE_SUBSET_SCHEMA
    Lab.require(value["schema"] == schema or subset, "gameplay update profile schema differs")
    rows = value["files"]
    if subset:
        Lab.require(isinstance(rows, list) and 0 < len(rows) <= len(PROFILES[profile])
                    and all(isinstance(row, dict) and isinstance(row.get("path"), str) for row in rows),
                    "gameplay subset requires nonempty file records")
        paths = {row["path"] for row in rows}
        Lab.require(len(paths) == len(rows) and paths <= PROFILES[profile],
                    "gameplay subset requires unique allowed profile paths")
    else:
        Lab.require(isinstance(rows, list) and len(rows) == len(PROFILES[profile])
                    and all(isinstance(row, dict) and isinstance(row.get("path"), str) for row in rows)
                    and {row.get("path") for row in rows} == PROFILES[profile],
                    "gameplay update requires exactly the files of its named profile")
    for row in rows:
        Lab.require(set(row) == {"path", "source", "beforeSha256", "afterSha256"},
                    "gameplay update file fields differ")
        if profile in CALLBACK_PROFILES:
            expected = callback_source_pins(profile)[row["path"]]
            Lab.require((row["beforeSha256"], row["afterSha256"]) == expected,
                        "callback update must have the exact reviewed per-file source pins")
    return profile


def update_directory(value):
    return "gameplay-source-update" if value["schema"] in (SOURCE_UPDATE_SCHEMA, SOURCE_SUBSET_SCHEMA) else "gameplay-lua-update"


def observation_update_parent(destination, receipt):
    """Authenticate a derived predecessor before any gameplay source change."""
    destination = Path(destination)
    original = Lab.load(destination / "run.json")
    if original == receipt:
        return None
    # Lazy import preserves the existing runner -> delivery module direction.
    import world_lab_run as Run
    side = file_path(destination / Run.OBSERVATION_RECONCILIATION)
    value = Lab.load(side)
    Lab.require(isinstance(value, dict) and isinstance(value.get("packagePath"), str),
                "gameplay predecessor reconciliation package missing")
    Lab.require(Run.verify_run(destination, value["packagePath"]) == receipt,
                "gameplay predecessor differs from fully verified reconciliation")
    return side


def validate_update(destination, receipt, manifest_path, disposition=None):
    destination = Path(destination)
    path = file_path(manifest_path)
    value = Lab.load(path)
    update_shape(value)
    observation_update_parent(destination, receipt)
    Lab.require(value["predecessor"] == binding(receipt, digest(destination / "run.json")),
                "gameplay update predecessor differs")
    if value.get("profile") in CALLBACK_PROFILES:
        Lab.require(disposition is not None, "callback update requires explicit callback disposition")
        _callback_qualification(receipt, disposition)
        Lab.require(digest(path) == disposition["callbackIncident"]["update"]["sha256"], "callback approved update changed")
    saved_boundary(receipt, disposition)
    rows = value["files"]
    for row in rows:
        before = file_path(destination / "cache/mods" / MOD / row["path"])
        after = file_path(row["source"])
        Lab.require(receipt["mods"][MOD][row["path"]] == row["beforeSha256"] == digest(before),
                    "gameplay update predecessor bytes differ")
        Lab.require(digest(after) == row["afterSha256"] != row["beforeSha256"],
                    "gameplay update source bytes differ or are unchanged")
    return value


def apply_update(destination, attempt, previous, receipt, manifest_path, disposition=None):
    value = validate_update(destination, previous, manifest_path, disposition)
    retained = attempt / update_directory(value)
    retained.mkdir()
    shutil.copyfile(manifest_path, retained / "manifest.json")
    Lab.require(Lab.load(retained / "manifest.json") == value, "staged gameplay manifest changed")
    shutil.copyfile(destination / "run.json", retained / "previous-run.json")
    reconciliation_hash = None
    if Lab.load(retained / "previous-run.json") != previous:
        import world_lab_run as Run
        side = file_path(destination / Run.OBSERVATION_RECONCILIATION)
        shutil.copyfile(side, retained / Run.OBSERVATION_RECONCILIATION)
        # Preserve the decoder that authenticated this side before gameplay bytes
        # change. Future history replays semantics with current code, while these
        # exact archived bytes keep the original source authority inspectable.
        for name in Run.RECONCILIATION_SOURCES:
            source = file_path(Path(Run.__file__).resolve().parent / name)
            target = retained / Run.RECONCILIATION_DECODER / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
        Lab.require(Run.verify_observation_reconciliation_parent(destination,
            retained / "previous-run.json", retained / Run.OBSERVATION_RECONCILIATION) == previous,
            "staged gameplay predecessor reconciliation differs")
        reconciliation_hash = digest(retained / Run.OBSERVATION_RECONCILIATION)
    # Stage and verify every old/new byte before replacing any cached source.
    for row in value["files"]:
        for group, source, expected in (
                ("before", destination / "cache/mods" / MOD / row["path"], row["beforeSha256"]),
                ("after", Path(row["source"]), row["afterSha256"])):
            target = retained / group / row["path"]
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
            Lab.require(digest(target) == expected, "staged gameplay bytes differ")
    provenance = {"directory": retained.relative_to(destination).as_posix(),
                  "manifestSha256": digest(retained / "manifest.json"),
                  "predecessor": value["predecessor"]}
    if reconciliation_hash is not None:
        provenance["observationReconciliationSha256"] = reconciliation_hash
    receipt["mods"] = copy.deepcopy(previous["mods"])
    for row in value["files"]:
        target = destination / "cache/mods" / MOD / row["path"]
        staged = target.with_name(target.name + ".activate-" + uuid.uuid4().hex)
        try:
            shutil.copyfile(retained / "after" / row["path"], staged)
            os.replace(staged, target)
        finally:
            if staged.exists(): staged.unlink()
        receipt["mods"][MOD][row["path"]] = row["afterSha256"]
    receipt["gameplayLuaUpdates"] = [*previous.get("gameplayLuaUpdates", []), provenance]


def retain_review(destination, attempt, previous, receipt, manifest_path, disposition):
    retained = attempt / "reviewed-errors"
    retained.mkdir()
    shutil.copyfile(manifest_path, retained / "manifest.json")
    shutil.copyfile(destination / "run.json", retained / "previous-run.json")
    callback = disposition.get("schema") == CALLBACK_DISPOSITION_SCHEMA
    if callback:
        _callback_qualification(previous, disposition)
        target = retained / "callback-incident"
        target.mkdir()
        for name, source in disposition["callbackIncident"]["files"].items():
            Lab.require(Path(name).name == name, "unsafe callback retained file")
            shutil.copyfile(file_path(source["path"]), target / name)
            Lab.require(digest(target / name) == source["sha256"], "retained callback evidence changed")
        for name in ("stdout.log", "stderr.log"):
            shutil.copyfile(destination / "attempts/0001" / name, target / name)
            Lab.require(digest(target / name) == previous["logs"][name], "retained callback original log changed")
    else:
        shutil.copyfile(disposition["evidence"]["path"], retained / "CellLoader.bytecode.txt")
    for key, directory in (("lungeIncident", "lunge-incident"), ("animationIncident", "animation-incident")):
        if key in disposition:
            source = Path(disposition[key]["evidence"]["path"]).parent
            target = retained / directory
            target.mkdir()
            for name, expected in disposition[key]["files"].items():
                shutil.copyfile(source / name, target / name)
                Lab.require(digest(target / name) == expected, "staged incident evidence differs")
    publish(retained / "disposition.json", disposition)
    receipt["reviewedErrorContinuations"] = [*previous.get("reviewedErrorContinuations", []), {
        "directory": retained.relative_to(destination).as_posix(),
        "manifestSha256": digest(retained / "manifest.json"),
        "dispositionSha256": digest(retained / "disposition.json"),
        "predecessor": disposition["predecessor"], "disposition": disposition["disposition"]}]


def verify_history(destination, receipt):
    destination = Path(destination)
    latest = None
    for entry in receipt.get("gameplayLuaUpdates", []):
        relative = entry["directory"]
        Lab.require(re.fullmatch(r"attempts/\d{4}/gameplay-(?:lua|source)-update", relative) is not None,
                    "unsafe gameplay provenance path")
        root = destination / relative
        Lab.require(digest(root / "manifest.json") == entry["manifestSha256"]
                    and digest(root / "previous-run.json") == entry["predecessor"]["receiptSha256"],
                    "gameplay update provenance differs")
        manifest, prior = Lab.load(root / "manifest.json"), Lab.load(root / "previous-run.json")
        update_shape(manifest)
        if "observationReconciliationSha256" in entry:
            import world_lab_run as Run
            side = file_path(root / Run.OBSERVATION_RECONCILIATION)
            Lab.require(digest(side) == entry["observationReconciliationSha256"],
                        "gameplay observation reconciliation provenance differs")
            prior = Run.verify_observation_reconciliation_parent(destination,
                root / "previous-run.json", side)
        Lab.require(manifest["predecessor"] == entry["predecessor"] == binding(prior, digest(root / "previous-run.json"))
                    and root.name == update_directory(manifest),
                    "gameplay predecessor inventory differs")
        expected = copy.deepcopy(prior["mods"])
        for row in manifest["files"]:
            Lab.require(digest(root / "before" / row["path"]) == row["beforeSha256"] == expected[MOD][row["path"]]
                        and digest(root / "after" / row["path"]) == row["afterSha256"],
                        "retained gameplay bytes differ")
            expected[MOD][row["path"]] = row["afterSha256"]
        latest = expected
    if latest is not None:
        Lab.require(receipt["mods"] == latest, "gameplay update changed unrelated mod pins")
    for entry in receipt.get("reviewedErrorContinuations", []):
        relative = entry["directory"]
        Lab.require(re.fullmatch(r"attempts/\d{4}/reviewed-errors", relative) is not None,
                    "unsafe reviewed-error provenance path")
        root = destination / relative
        Lab.require(digest(root / "manifest.json") == entry["manifestSha256"]
                    and digest(root / "previous-run.json") == entry["predecessor"]["receiptSha256"]
                    and digest(root / "disposition.json") == entry["dispositionSha256"],
                    "reviewed-error provenance differs")
        disposition = Lab.load(root / "disposition.json")
        if disposition.get("schema") == CALLBACK_DISPOSITION_SCHEMA:
            prior = Lab.load(root / "previous-run.json")
            Lab.require(disposition["disposition"] == entry["disposition"] == CALLBACK_DISPOSITION
                        and disposition["predecessor"] == entry["predecessor"] == CALLBACK_PREDECESSOR
                        and disposition["originalReceiptSeal"] == Lab.seal(prior)
                        and prior["status"] == "incomplete" and prior["runtimeErrors"] == list(CALLBACK_ERRORS),
                        "retained callback predecessor changed")
            for name, source in disposition["callbackIncident"]["files"].items():
                Lab.require(Path(name).name == name and digest(file_path(root / "callback-incident" / name)) == source["sha256"],
                            "retained callback incident evidence changed")
            for name in ("stdout.log", "stderr.log"):
                Lab.require(digest(file_path(root / "callback-incident" / name)) == prior["logs"][name],
                            "retained callback original log changed")
            continue
        Lab.require(disposition["disposition"] == entry["disposition"] == DISPOSITION
                    and disposition["predecessor"] == entry["predecessor"]
                    and digest(root / "CellLoader.bytecode.txt") == disposition["evidence"]["sha256"],
                    "reviewed-error evidence differs")
        for key, directory in (("lungeIncident", "lunge-incident"), ("animationIncident", "animation-incident")):
            if key in disposition:
                for name, expected in disposition[key]["files"].items():
                    Lab.require(Path(name).name == name and digest(root / directory / name) == expected,
                                "retained incident evidence differs")


@contextmanager
def resume_guard(destination, gameplay=False):
    """One resume owner; restore prelaunch failures, never an active JVM's files."""
    destination = Path(destination)
    lock = (destination / "resume-owner.lock").open("a+b")
    acquired = False
    try:
        lock.seek(0); lock.write(b"0"); lock.flush(); lock.seek(0)
        if os.name == "nt":
            import msvcrt
            msvcrt.locking(lock.fileno(), msvcrt.LK_NBLCK, 1)
        else:
            import fcntl
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        acquired = True
        previous = Lab.load(destination / "run.json")
        # All paths are existing predecessor inputs, not manifest-supplied paths.
        paths = [destination / "run.json", destination / "StudyLoadingAgent.jar",
                 destination / "cache/options.ini", destination / "cache/mods/default.txt",
                 destination / "cache/mods" / previous["mapName"] / "42.20/media/lua/client/ZZStudyLaunch.lua"]
        if gameplay:
            paths += [destination / "cache/mods" / MOD / name for name in PROFILE_FILES
                      if name in previous["mods"][MOD]]
        before = {file_path(path): path.read_bytes() for path in paths}
        attempt = destination / "attempts" / f"{previous['launchNumber'] + 1:04d}"
        Lab.require(not attempt.exists(), "next native attempt already exists")
        state = {"nativeStarted": False}
        try:
            yield state
        except BaseException:
            if not state["nativeStarted"]:
                for path, content in before.items():
                    if path.read_bytes() != content:
                        temporary = path.with_name(path.name + ".restore-" + uuid.uuid4().hex)
                        temporary.write_bytes(content); os.replace(temporary, path)
                if attempt.exists():
                    failures = destination / "delivery-failures"
                    failures.mkdir(exist_ok=True)
                    os.replace(attempt, failures / (attempt.name + "-" + uuid.uuid4().hex))
            raise
    finally:
        if acquired:
            lock.seek(0)
            if os.name == "nt":
                import msvcrt
                msvcrt.locking(lock.fileno(), msvcrt.LK_UNLCK, 1)
            else:
                import fcntl
                fcntl.flock(lock, fcntl.LOCK_UN)
        lock.close()
