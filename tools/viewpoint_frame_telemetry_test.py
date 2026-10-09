#!/usr/bin/env python3
"""Qualify pinned Viewpoint render telemetry and strict native-feed acceptance."""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

import world_lab_participant_feed as Feed
import world_lab_run as Run

ROOT = Path(__file__).resolve().parents[1]
JDK = Path("C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin")
GAME = Path("C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid")
VENDOR = ROOT / "vendor/viewpoint/Viewpoint-0.1.5a-hotfix.jar"
PIN = "94fedda302ab6c17ba1b38495789e4c9781d52823fb8204214c85402e3cab41f"
SOURCES = [
    ROOT / "java/src/com/sao/agent/SAOViewpointFrameTelemetry.java",
    ROOT / "java/src/com/sao/SAOViewpointBootstrap.java",
    ROOT / "tools/viewpoint_frame_telemetry/CameraProbe.java",
    *(ROOT / "tools/world_lab" / name for name in Run.PARTICIPANT_SOURCES),
]


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def execute(arguments: list[str], *, home: Path | None = None) -> str:
    env = dict(os.environ)
    if home is not None:
        arguments = [arguments[0], "-Duser.home=" + str(home), *arguments[1:]]
    result = subprocess.run(arguments, cwd=ROOT, env=env, text=True, capture_output=True,
                            timeout=90)
    if result.returncode:
        raise AssertionError(f"exit {result.returncode}: {arguments}\n"
                             f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}")
    return result.stdout + result.stderr


def feed_controls() -> int:
    count = 0
    for mode in ("isometric", "viewpoint-first", "viewpoint-third", "viewpoint-free", "unavailable"):
        camera = {"schema": "sao.native-frame-camera/1",
                  "mode": mode, "ready": mode != "unavailable"}
        assert Feed.validate_native_camera(camera) == camera
        count += 1
        altered = {**camera, "ready": not camera["ready"]}
        try:
            Feed.validate_native_camera(altered)
        except ValueError:
            count += 1
        else:
            raise AssertionError("native camera readiness inverse passed")
    sample = {"schema": "sao.native-frame-camera/1", "mode": "viewpoint-third", "ready": True}
    manifest = {"segments": [{"firstFrameSequence": 3, "lastFrameSequence": 5,
                              "cameraFrames": [
                                  {"frameSequence": 3, "camera": sample},
                                  {"frameSequence": 5, "camera": sample}]}]}
    Feed.validate_video_camera_frames(manifest)
    count += 1
    for mutation in (
            lambda v: v["segments"][0]["cameraFrames"][0].update(frameSequence=4),
            lambda v: v["segments"][0]["cameraFrames"][1].update(frameSequence=3),
            lambda v: v["segments"][0]["cameraFrames"][1]["camera"].update(ready=False),
            lambda v: v["segments"][0]["cameraFrames"].append(
                {"frameSequence": 6, "camera": sample}),
    ):
        altered = copy.deepcopy(manifest)
        mutation(altered)
        try:
            Feed.validate_video_camera_frames(altered)
        except ValueError:
            count += 1
        else:
            raise AssertionError("native video camera inverse passed")
    Feed.validate_video_camera_frames({"segments": [{"firstFrameSequence": 1,
                                                     "lastFrameSequence": 1}]})
    count += 1
    return count


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, required=True)
    arguments = parser.parse_args()
    output = arguments.out.resolve()
    output.mkdir(parents=True, exist_ok=False)
    assert sha(VENDOR) == PIN, "pinned Viewpoint vendor JAR changed"
    before = {str(path.relative_to(ROOT)).replace("\\", "/"): sha(path) for path in SOURCES}
    classes = output / "classes"
    classes.mkdir()
    cp = os.pathsep.join(map(str, (
        ROOT / "java/out", VENDOR, GAME / "projectzomboid.jar", GAME / "ZombieBuddy.jar")))
    compiler = execute([str(JDK / "javac.exe"), "-cp", cp, "-d", str(classes),
                        *(str(path) for path in SOURCES)])
    (output / "compile.log").write_text(compiler, encoding="utf-8")
    agent_manifest = output / "agent.mf"
    agent_manifest.write_text("Manifest-Version: 1.0\nPremain-Class: CameraProbe\n"
                              "Can-Retransform-Classes: true\n\n", encoding="ascii")
    agent = output / "camera-probe.jar"
    execute([str(JDK / "jar.exe"), "--create", "--file", str(agent),
             "--manifest", str(agent_manifest), "-C", str(classes), "CameraProbe.class"])
    runtime_cp = os.pathsep.join((str(classes), cp))
    java_log = execute([str(JDK / "java.exe"), "-javaagent:" + str(agent),
                        "-cp", runtime_cp, "CameraProbe"], home=output)
    (output / "camera-probe.log").write_text(java_log, encoding="utf-8")
    match = re.search(r"(?m)^PASS (\d+)$", java_log)
    assert match, java_log
    feed_checks = feed_controls()
    after = {key: sha(ROOT / key) for key in before}
    assert before == after, "production source changed during qualification"
    receipt = {
        "schema": "sao-viewpoint-frame-telemetry-offline/1", "status": "PASS",
        "scope": "pinned SceneDrawer transform and controlled render/capture clock; no GL or game launch",
        "javaChecks": int(match.group(1)), "feedChecks": feed_checks,
        "sourceSha256": before, "sourceCurrent": True,
        "vendorJarSha256": sha(VENDOR), "probeLogSha256": sha(output / "camera-probe.log"),
        "limitations": [
            "A real GL frame and SpriteRenderer render-thread order need installed-game observation.",
            "Mousecat can display the frame label only after its native view consumer admits the new field.",
        ],
    }
    target = output / "receipt.json"
    target.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": "PASS", "javaChecks": receipt["javaChecks"],
                      "feedChecks": feed_checks, "receipt": str(target),
                      "sha256": sha(target)}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
