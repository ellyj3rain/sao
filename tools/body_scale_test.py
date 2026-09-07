#!/usr/bin/env python3
r"""Border 104 - the body is scaled from inside the animation player
([C29], DR-032).

The vanilla renderer scales no character: the model instance's scale
field is read by the vehicle class alone, the model script's scale
only by the world-object and item drawers (ENGINE_CONTRACT Addendum
F). A body's size can change in one place - the per-bone model
transforms the animation player builds in updateModelTransformsInternal
and the renderer skins from. This border holds that SAO puts its
scaler there, and nowhere else, and that the weave really lands on
the installed game's class.

WHAT THIS HOLDS
---------------
  1. The weave targets exactly AnimationPlayer.updateModelTransformsInternal,
     with an exit advice that calls SAOBodyScale.apply and nothing more.
  2. Only SAO's own shell carries a size (a public field); everything
     else costs an instanceof and returns.
  3. The scaler scales the three axes and the translation and leaves
     the homogeneous row alone (uniform, about the model origin at the
     feet), and holds bad asks to a range instead of drawing nobody.
  4. Both load paths install the weave: Main (ZombieBuddy) and premain.
  5. The bridge exposes set/get/report; the body reads its size from
     the age once it is dressed; the harness carries the click and the
     report line that are the receipt.
  6. The real defect, off the game: the installed jar's AnimationPlayer
     bytes are woven by SAO's own weaver, the original never mentions
     the scaler, the woven class does, and the woven class links and
     verifies under the JVM (a broken frame fails here, not in play).

An optional argv[1] points the checker at another tree root, which is
how the control runs against the pre-[C29] tree: no weaver, no field,
no harness - it faults every way.
"""
import os
import pathlib
import re
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
JAVA = ROOT / "java" / "src" / "com" / "sao"
SCALE = JAVA / "agent" / "SAOBodyScale.java"
WEAVE = JAVA / "agent" / "SAOBodyScaleWeave.java"
SHELL = JAVA / "engine" / "SAOIsoPlayerShell.java"
MAIN = JAVA / "Main.java"
AGENT = JAVA / "agent" / "SAOAgent.java"
BRIDGE = JAVA / "bridge" / "SAOBridge.java"
HISTORY = ROOT / "mod" / "42.20" / "media" / "lua" / "shared" / "SAO_History.lua"
BODY = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Body.lua"
HARNESS = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Harness.lua"
JAR = ROOT / "java" / "dist" / "SAOAgent.jar"
CHECK = ROOT / "tools" / "javacheck" / "BodyScaleWeaveCheck.java"

# The same JDK and game the build script uses (tools/build-java.sh).
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ = pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ_JAR = PZ / "projectzomboid.jar"
ZB_JAR = PZ / "ZombieBuddy.jar"


def read(path):
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def main():
    faults = []
    print("=" * 74)
    print("THE BODY IS SCALED FROM INSIDE THE ANIMATION PLAYER")
    print("=" * 74)

    scale = read(SCALE)
    weave = read(WEAVE)
    shell = read(SHELL)
    main_src = read(MAIN)
    agent = read(AGENT)
    bridge = read(BRIDGE)
    history = read(HISTORY)
    body = read(BODY)
    harness = read(HARNESS)

    # 1. The weave and its one target.
    if 'TARGET = "zombie.core.skinnedmodel.animation.AnimationPlayer"' not in weave:
        faults.append("the weaver does not name AnimationPlayer as its target")
    if 'METHOD = "updateModelTransformsInternal"' not in weave:
        faults.append("the weaver does not name updateModelTransformsInternal")
    if "@Advice.OnMethodExit" not in weave or "SAOBodyScale.apply(self)" not in weave:
        faults.append("the advice is not an exit advice calling SAOBodyScale.apply")
    if "@Advice.OnMethodEnter" in weave:
        faults.append("an enter advice is present; the scale belongs after the transforms are built")
    if "RedefinitionStrategy.RETRANSFORMATION" not in weave:
        faults.append("the weave does not retransform an already-loaded class")

    # 2. Only the shell carries a size.
    if not re.search(r"public\s+volatile\s+float\s+bodyScale\s*=\s*1f;", shell):
        faults.append("SAOIsoPlayerShell carries no bodyScale field")
    if "instanceof SAOIsoPlayerShell shell" not in scale:
        faults.append("the scaler does not key on SAO's own shell")

    # 3. The arithmetic.
    for entry in ("m00", "m01", "m02", "m10", "m11", "m12", "m20", "m21", "m22", "m30", "m31", "m32"):
        if not re.search(r"matrix\.%s\s*\*=\s*scale;" % entry, scale):
            faults.append("scaleMatrix does not scale " + entry)
    for entry in ("m03", "m13", "m23", "m33"):
        if re.search(r"matrix\.%s\s*\*=" % entry, scale):
            faults.append("scaleMatrix scales the homogeneous entry " + entry)
    if "Float.isNaN(scale) || scale <= 0f" not in scale:
        faults.append("clamp does not refuse NaN, zero and negatives")

    # 4. Both load paths install it.
    if "SAOBodyScaleWeave.install()" not in main_src:
        faults.append("Main (the ZombieBuddy path) does not install the weave")
    if "SAOBodyScaleWeave.install(instrumentation)" not in agent:
        faults.append("premain does not install the weave")

    # 5. Bridge, body, harness.
    for name in ("setBodyScale", "getBodyScale", "bodyScaleReport"):
        if ("public " not in bridge) or (name + "(" not in bridge):
            faults.append("the bridge lacks " + name)
    if "function H.heightScaleOf(id)" not in history:
        faults.append("SAO_History has no heightScaleOf")
    if not re.search(r"if age >= GROWTH_ADULT then return 1\.0 end", history):
        faults.append("heightScaleOf does not answer 1 for an adult")
    dressed_at = body.find("SAOJavaBridge:ensureDressed(")
    sized_at = body.find("SAOJavaBridge:setBodyScale(body, scale)")
    if dressed_at < 0 or sized_at < 0 or sized_at < dressed_at:
        faults.append("the body is not sized after it is dressed")
    if "Scale this survivor to three quarters" not in harness \
            or "Restore this survivor's size" not in harness:
        faults.append("the harness lacks the size click or its restore")
    if "bodyScaleReport()" not in harness:
        faults.append("the harness does not print the weave report")

    # 6. The real defect, off the game.
    missing = [str(p) for p in (JAR, CHECK, PZ_JAR, ZB_JAR, JDK / "javac.exe", JDK / "java.exe")
               if not p.exists()]
    if missing:
        faults.append("cannot run the weave check; missing: " + ", ".join(missing))
    else:
        with tempfile.TemporaryDirectory() as tmp:
            classpath = os.pathsep.join(str(p) for p in (PZ_JAR, ZB_JAR, JAR))
            compile_cmd = [str(JDK / "javac.exe"), "-cp", classpath, "-d", tmp, str(CHECK)]
            compiled = subprocess.run(compile_cmd, capture_output=True, text=True)
            if compiled.returncode != 0:
                faults.append("the weave check does not compile: "
                              + (compiled.stderr or compiled.stdout).strip()[:400])
            else:
                run_cmd = [str(JDK / "java.exe"), "-cp", os.pathsep.join([classpath, tmp]),
                           "BodyScaleWeaveCheck"]
                ran = subprocess.run(run_cmd, capture_output=True, text=True, timeout=300)
                out = (ran.stdout or "") + (ran.stderr or "")
                for line in out.strip().splitlines():
                    print("     " + line.strip())
                if "WEAVE PASS" not in out:
                    faults.append("the weave check did not pass on the installed game's class")
                if "original-mentions-scaler=false" not in out:
                    faults.append("the original class already mentions the scaler (the weave proves nothing)")
                if "woven-class-verified=true" not in out:
                    faults.append("the woven class did not link and verify")

    if faults:
        for fault in faults:
            print("  FAULT: " + fault)
        return 1
    print("  104) body scale: the weave targets one method with an exit advice,")
    print("       only the shell carries a size, the arithmetic is uniform about the")
    print("       feet, both load paths install it, the body is sized after it is")
    print("       dressed, the harness carries the click and the report, and the")
    print("       installed class weaves, links and verifies off the game")
    return 0


if __name__ == "__main__":
    sys.exit(main())
