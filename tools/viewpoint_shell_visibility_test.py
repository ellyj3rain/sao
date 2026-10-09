#!/usr/bin/env python3
"""Exercise the pinned Viewpoint capture method with SAO's visibility advice."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
JDK = Path("C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin")
GAME = Path("C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid")
VENDOR = ROOT / "vendor/viewpoint/Viewpoint-0.1.5a-hotfix.jar"
VENDOR_SHA = "94FEDDA302AB6C17BA1B38495789E4C9781D52823FB8204214C85402E3CAB41F"
WEAVE = ROOT / "java/src/com/sao/agent/SAOViewpointShellVisibilityWeave.java"
BOOTSTRAP = ROOT / "java/src/com/sao/SAOViewpointBootstrap.java"
SHELL = ROOT / "java/src/com/sao/engine/SAOIsoPlayerShell.java"
PROBE = ROOT / "tools/viewpoint_shell_visibility/VisibilityProbe.java"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def run(command: list[str], *, home: Path | None = None) -> str:
    env = dict(os.environ)
    if home is not None:
        env["JAVA_TOOL_OPTIONS"] = f"-Duser.home={home}"
    result = subprocess.run(command, cwd=ROOT, env=env, text=True,
                            capture_output=True, timeout=90)
    if result.returncode:
        raise AssertionError(f"exit {result.returncode}: {command}\n"
                             f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}")
    return result.stdout


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    assert sha(VENDOR) == VENDOR_SHA, "Viewpoint source JAR changed"
    assert "public volatile boolean removalPending;" in SHELL.read_text(encoding="utf-8")
    assert "SAOViewpointShellVisibilityWeave.install()" in BOOTSTRAP.read_text(encoding="utf-8")

    native_cp = os.pathsep.join(map(str, (VENDOR, GAME / "projectzomboid.jar",
                                           GAME / "ZombieBuddy.jar")))
    signature = run([str(JDK / "javap.exe"), "-classpath", native_cp,
                     "-p", "viewpoint.models.ModelCapture"])
    exact = ("static boolean capture(viewpoint.core.Frame, "
             "zombie.core.skinnedmodel.model.ModelSlotRenderData, "
             "zombie.characters.IsoGameCharacter, boolean, "
             "viewpoint.models.ModelCapture$Pose, float, float, float, float);")
    assert exact in signature, "pinned capture signature changed"
    characters = run([str(JDK / "javap.exe"), "-classpath", native_cp,
                      "-p", "-c", "viewpoint.models.Characters"])
    range_signature = ("private static boolean inRange(zombie.iso.IsoMovingObject, "
                       "float, float, float);")
    assert range_signature in characters, "pinned character range signature changed"
    range_call = characters.index("// Method inRange:")
    fresh_call = characters.index("// Method fresh:")
    blob_call = characters.index("// Method viewpoint/render/SceneData.blob:")
    capture_call = characters.index("// Method viewpoint/models/ModelCapture.capture:")
    assert range_call < fresh_call < blob_call < capture_call, \
        "range check no longer precedes forced alpha, ground blob and capture"
    assert "// Field zombie/core/skinnedmodel/model/ModelSlotRenderData.alpha:F" in characters, \
        "fresh alpha assignment changed"

    with tempfile.TemporaryDirectory(prefix="sao-viewpoint-visibility-") as directory:
        temporary = Path(directory)
        classes = temporary / "classes"
        classes.mkdir()
        cp = os.pathsep.join((str(ROOT / "java/out"), native_cp))
        run([str(JDK / "javac.exe"), "-cp", cp, "-d", str(classes),
             str(WEAVE), str(BOOTSTRAP), str(PROBE)])
        runtime_cp = os.pathsep.join((str(classes), cp))
        baseline = run([str(JDK / "java.exe"), "-cp", runtime_cp,
                        "com.sao.VisibilityProbe", "original"], home=temporary)

        manifest = temporary / "MANIFEST.MF"
        manifest.write_text("Manifest-Version: 1.0\n"
                            "Premain-Class: com.sao.VisibilityProbe\n"
                            "Can-Retransform-Classes: true\n\n", encoding="ascii")
        agent = temporary / "visibility-probe.jar"
        run([str(JDK / "jar.exe"), "--create", "--file", str(agent),
             "--manifest", str(manifest), "-C", str(classes),
             "com/sao/VisibilityProbe.class"])
        woven = run([str(JDK / "java.exe"), "-javaagent:" + str(agent),
                     "-cp", runtime_cp, "com.sao.VisibilityProbe", "woven"], home=temporary)

    expected_original = ("PASS instrumentation state",
                         "PASS original published pending shell shape enters ground blob path",
                         "PASS original failed publication shell shape enters ground blob path",
                         "PASS original squareless shell enters ground blob path",
                         "PASS original pending shell reaches capture body",
                         "PASS original squareless shell reaches capture body",
                         "PASS TOTAL 6")
    expected_woven = ("PASS instrumentation state",
                      "PASS weave transformed pinned class",
                      "PASS published pending shell shape excluded before ground blob",
                      "PASS failed publication shell shape excluded before ground blob",
                      "PASS squareless shell excluded before ground blob",
                      "PASS active shell retained in character range",
                      "PASS foreign player retained in character range",
                      "PASS published pending shell shape has no model capture",
                      "PASS failed publication shell shape has no model capture",
                      "PASS squareless shell has no model capture",
                      "PASS active SAO shell reaches original capture",
                      "PASS foreign character reaches original capture",
                      "PASS TOTAL 12")
    assert tuple(baseline.splitlines()) == expected_original, baseline
    assert tuple(woven.splitlines()) == expected_woven, woven
    receipt = {
        "schema": "sao-viewpoint-shell-visibility-offline/1",
        "status": "PASS",
        "scope": "pinned Viewpoint method and bytecode advice; no game launch or rendered acceptance",
        "sourceSha256": {str(file.relative_to(ROOT)).replace("\\", "/"): sha(file)
                         for file in (VENDOR, WEAVE, BOOTSTRAP, SHELL, PROBE)},
        "captureSignature": exact,
        "rangeSignature": range_signature,
        "rangeCallPrecedesForcedAlphaBlobCapture": True,
        "originalControls": baseline.splitlines(),
        "wovenControls": woven.splitlines(),
        "remaining": [
            "Characters.snapshot still calls CharacterRate.drawn and KeptSnapshots.use after a skipped capture, but guarded SAO shells fail its earlier range check",
            "Failed publication is represented by its observable pending-and-square field shape; the native failure transaction is not run",
            "No loaded game, rendered pixel, or live render-thread race observation was made",
        ],
    }
    output = args.out.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": "PASS", "original": 6, "woven": 12,
                      "receipt": str(output)}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
