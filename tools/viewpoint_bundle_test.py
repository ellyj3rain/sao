#!/usr/bin/env python3
"""Offline Viewpoint bundle and activation qualification; never starts the game."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import zipfile
from adapt_viewpoint_framecaps import adapt as adapt_framecaps, ADAPTED_SHA256 as FRAMECAPS_SHA256


ROOT = Path(__file__).resolve().parents[1]
VENDOR = ROOT / "vendor/viewpoint/Viewpoint-0.1.5a-hotfix.jar"
PIN = "94FEDDA302AB6C17BA1B38495789E4C9781D52823FB8204214C85402E3CAB41F"
JDK = Path("C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin")
GAME = Path("C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid")
PROBE = ROOT / "tools/viewpoint_bundle/ActivationProbe.java"
OVERRIDE = "viewpoint/ModLua.class"
FRAMECAPS = "viewpoint/game/FrameCaps.class"
SCRIPTS = (
    "SAO_Viewpoint_Interact.lua",
    "SAO_Viewpoint_Loot.lua",
    "SAO_Viewpoint_Mouse.lua",
    "SAO_Viewpoint_Options.lua",
)
SAO_WEAVES = (
    ("SAOBodyScaleWeave.java", "zombie.core.skinnedmodel.animation.AnimationPlayer",
     "updateModelTransformsInternal"),
    ("SAOCalloutWeave.java", "zombie.characters.IsoGameCharacter", "Callout"),
    ("SAOLootDensityWeave.java", "zombie.inventory.ItemPickerJava", "density"),
    ("SAOOrientationWeave.java", "zombie.WorldSoundManager$WorldSound", "orientation"),
    ("SAOMeleeTransformer.java", "zombie/ai/states/SwipeStatePlayer", "melee"),
    ("SAODanceCycleWeave.java", "zombie.characters.CharacterTimedActions.LuaTimedActionNew",
     "dance"),
    ("SAOZombieBuddyLoadWeave.java", "zombie.ZomboidFileSystem", "mod-loading"),
)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def run(args: list[str], *, cwd: Path | None = None, home: Path | None = None) -> str:
    env = dict(os.environ)
    if home is not None:
        env["JAVA_TOOL_OPTIONS"] = f"-Duser.home={home}"
    process = subprocess.run(args, cwd=cwd, env=env, text=True,
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if process.returncode != 0:
        raise AssertionError(f"command failed ({process.returncode}): {args}\n"
                             f"stdout:\n{process.stdout}\nstderr:\n{process.stderr}")
    return process.stdout


def viewpoint_entries(archive: Path, *, allow_sao: bool = False) -> dict[str, bytes]:
    with zipfile.ZipFile(archive) as zf:
        names = zf.namelist()
        assert len(names) == len(set(names)), "duplicate JAR entry"
        assert all(name.startswith("viewpoint/") or name.startswith("META-INF/")
                   or (allow_sao and name.startswith("com/"))
                   for name in names), "unexpected source package"
        assert all(".." not in Path(name).parts and "\\" not in name
                   for name in names), "unsafe JAR entry"
        return {name: zf.read(name) for name in names if name.startswith("viewpoint/")}


def source_equivalent(source: dict[str, bytes], shipped: dict[str, bytes]) -> bool:
    return (source.keys() == shipped.keys()
            and all(source[name] == shipped[name] for name in source if name not in (OVERRIDE, FRAMECAPS))
            and source[OVERRIDE] != shipped[OVERRIDE]
            and shipped[FRAMECAPS] == adapt_framecaps(source[FRAMECAPS]))


def overlap_inventory(jar: Path) -> tuple[list[dict[str, str]], dict[str, object]]:
    with zipfile.ZipFile(jar) as zf:
        classes = sorted(name[:-6].replace("/", ".") for name in zf.namelist()
                         if re.fullmatch(r"viewpoint/Patch_[^/]+\.class", name))
    cp = os.pathsep.join(str(item) for item in (jar, GAME / "projectzomboid.jar",
                                                  GAME / "ZombieBuddy.jar"))
    dump = run([str(JDK / "javap.exe"), "-classpath", cp, "-v", *classes])
    patches: list[dict[str, str]] = []
    for block in re.split(r"(?=^Classfile )", dump, flags=re.MULTILINE):
        name = re.search(r"^public class (viewpoint\.Patch_\S+)", block, re.MULTILINE)
        target = re.search(r'^\s*className="([^"]+)"', block, re.MULTILINE)
        method = re.search(r'^\s*methodName="([^"]+)"', block, re.MULTILINE)
        if name is not None:
            assert target is not None and method is not None, f"unreadable patch target {name.group(1)}"
            patches.append({"patch": name.group(1), "target": target.group(1),
                            "method": method.group(1)})
    assert len(patches) == len(classes) == 61, (len(patches), len(classes))
    weaves: list[dict[str, str]] = []
    for source_name, target, method in SAO_WEAVES:
        text = (ROOT / "java/src/com/sao/agent" / source_name).read_text(encoding="utf-8")
        assert target in text, source_name
        if source_name in ("SAOBodyScaleWeave.java", "SAOCalloutWeave.java"):
            assert method in text, source_name
        weaves.append({"source": source_name, "target": target.replace("/", "."),
                       "method": method})
    radio = (ROOT / "java/src/com/sao/agent/SAORadioPlaybackWeave.java").read_text(
        encoding="utf-8")
    radio_set = radio.split("TARGETS=Set.of(", 1)[1].split(");", 1)[0]
    for target in re.findall(r'"([^"]+)"', radio_set):
        weaves.append({"source": "SAORadioPlaybackWeave.java", "target": target,
                       "method": "multiple"})
    by_target = {item["target"] for item in patches}
    overlap = sorted(by_target.intersection(item["target"] for item in weaves))
    exact = [{"target": patch["target"], "method": patch["method"]}
             for patch in patches for weave in weaves
             if patch["target"] == weave["target"] and patch["method"] == weave["method"]]
    shell = (ROOT / "java/src/com/sao/engine/SAOIsoPlayerShell.java").read_text(
        encoding="utf-8")
    shell_overlap = [{"target": item["target"], "method": item["method"]}
                     for item in patches if item["target"] == "zombie.characters.IsoPlayer"
                     and re.search(r"public\s+\w+\s+" + re.escape(item["method"]) + r"\s*\(", shell)]
    return patches, {"sameClassTargets": overlap, "sameMethodTargets": exact,
                     "saoShellMethodOverrides": shell_overlap,
                     "sameClassDetails": [
                         {"target": target,
                          "viewpointMethods": sorted(item["method"] for item in patches
                                                     if item["target"] == target),
                          "saoWeaves": [item for item in weaves if item["target"] == target]}
                         for target in overlap],
                     "saoWeaveTargets": weaves}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--jar", type=Path, default=ROOT / "mod/42.20/media/java/SAO.jar")
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    jar = args.jar.resolve()
    checks: list[str] = []

    def check(name: str, condition: bool) -> None:
        if not condition:
            raise AssertionError(name)
        checks.append(name)

    check("pinned vendor hash", sha(VENDOR) == PIN)
    source = viewpoint_entries(VENDOR)
    shipped = viewpoint_entries(jar, allow_sao=True)
    check("source viewpoint entries", len(source) == 825)
    check("shipped viewpoint entries", len(shipped) == 825)
    check("source classes and shaders preserved except two pinned SAO adaptations",
          source_equivalent(source, shipped))
    check("adapted FrameCaps class SHA pinned",
          hashlib.sha256(shipped[FRAMECAPS]).hexdigest() == FRAMECAPS_SHA256)
    try:
        adapt_framecaps(source[FRAMECAPS][:-1] + bytes([source[FRAMECAPS][-1] ^ 1]))
    except ValueError:
        checks.append("FrameCaps adaptation rejects source drift")
    else:
        raise AssertionError("FrameCaps adaptation accepted source drift")
    damaged = dict(shipped)
    damaged["viewpoint/shaders/lib/common.glsl"] += b"\nknown-bad-control\n"
    check("byte-equivalence instrument detects shader damage",
          not source_equivalent(source, damaged))
    check("overridden Lua fallback bundled", OVERRIDE in shipped)
    with zipfile.ZipFile(jar) as zf:
        check("SAO bootstrap bundled", "com/sao/SAOViewpointBootstrap.class" in zf.namelist())
        check("SAO staged-shell visibility advice bundled", all(name in zf.namelist()
              for name in (
                  "com/sao/agent/SAOViewpointShellVisibilityWeave.class",
                  "com/sao/agent/SAOViewpointShellVisibilityWeave$RangeEnter.class",
                  "com/sao/agent/SAOViewpointShellVisibilityWeave$CaptureEnter.class",
              )))
        check("SAO completed-frame advice bundled", all(name in zf.namelist()
              for name in (
                  "com/sao/agent/SAOViewpointFrameTelemetry.class",
                  "com/sao/agent/SAOViewpointFrameTelemetry$RenderExit.class",
              )))

    lua_source = (ROOT / "java/src/viewpoint/ModLua.java").read_text(encoding="utf-8")
    check("only four incorporated Lua files are listed",
          all(name in lua_source for name in SCRIPTS)
          and "SAO_Viewpoint_FrameCapOptions.lua" not in lua_source)
    check("Lua fallback checks individual script completion", all(marker in lua_source for marker in (
          "ViewpointInteract.run", "ViewpointLoot.closeWindow",
          "SAOViewpointMouseLoaded", "SAOViewpointOptionsLoaded")))
    check("Lua fallback does not enumerate the SAO client folder", "listFiles" not in lua_source)
    check("four script files ship", all((ROOT / "mod/42.20/media/lua/client" / name).is_file()
                                         for name in SCRIPTS))
    check("package license and credits mirror source", all(
          (ROOT / name).read_bytes() == (ROOT / "mod" / name).read_bytes()
          for name in ("LICENSE", "CREDITS.md")))
    check("Viewpoint license ships", (ROOT / "vendor/viewpoint/LICENSE").read_bytes()
          == (ROOT / "mod/VIEWPOINT-LICENSE.txt").read_bytes())
    check("Lua marker contracts ship", all(marker in (
          ROOT / "mod/42.20/media/lua/client" / script).read_text(encoding="utf-8")
          for script, marker in (("SAO_Viewpoint_Mouse.lua", "SAOViewpointMouseLoaded = true"),
                                 ("SAO_Viewpoint_Options.lua", "SAOViewpointOptionsLoaded = true"))))

    cp = os.pathsep.join(str(item) for item in (jar, GAME / "projectzomboid.jar",
                                                  GAME / "ZombieBuddy.jar"))
    main_code = run([str(JDK / "javap.exe"), "-classpath", cp, "-c", "com.sao.Main"])
    native_code = run([str(JDK / "javap.exe"), "-classpath", cp, "-c", "-p",
                       "com.sao.SAOViewpointBootstrap$NativeRuntime"])
    mod_lua_code = run([str(JDK / "javap.exe"), "-classpath", cp, "-c", "-p",
                        "viewpoint.ModLua"])
    framecaps_code = run([str(JDK / "javap.exe"), "-classpath", cp, "-c", "-p",
                          "viewpoint.game.FrameCaps"])
    check("main entry invokes bundle bootstrap", "SAOViewpointBootstrap.start" in main_code)
    check("native guard uses installed dedicated state", "GameServer.server" in native_code)
    check("native build pin is consulted", "BuildPin.supported" in native_code)
    check("native source main and package patches registered",
          "viewpoint/Main.main" in native_code and "PatchEngine.applyPatches" in native_code
          and "String viewpoint" in native_code)
    check("staged-shell visibility guard precedes Viewpoint patch registration",
          "SAOViewpointShellVisibilityWeave.install" in native_code
          and native_code.index("SAOViewpointShellVisibilityWeave.install")
          < native_code.index("PatchEngine.applyPatches"))
    check("frame telemetry attempt precedes Viewpoint patch registration",
          "SAOViewpointFrameTelemetry.install" in native_code
          and native_code.index("SAOViewpointFrameTelemetry.install")
          < native_code.index("PatchEngine.applyPatches"))
    check("pinned FrameCaps initializer assigns false before ON",
          re.search(r"134:\s+iconst_0\s+135:\s+nop\s+136:\s+nop\s+137:\s+putstatic\s+#278\s+// Field ON:Z",
                    framecaps_code) is not None)
    check("bundled Lua class names four scripts", all(name in mod_lua_code for name in SCRIPTS)
          and "FrameCapOptions" not in mod_lua_code)

    patches, overlap = overlap_inventory(jar)
    check("Viewpoint patch inventory covers source classes", len(patches) == 61)
    check("same target classes identified", overlap["sameClassTargets"] == [
          "zombie.characters.IsoGameCharacter",
          "zombie.core.skinnedmodel.animation.AnimationPlayer"])
    check("same class patches address distinct methods", not overlap["sameMethodTargets"])
    check("SAO shell LOS override intersects Viewpoint base patch",
          overlap["saoShellMethodOverrides"] == [
              {"target": "zombie.characters.IsoPlayer", "method": "updateLOS"}])

    with tempfile.TemporaryDirectory(prefix="sao-viewpoint-bundle-") as temp:
        tmp = Path(temp)
        classes = tmp / "classes"
        classes.mkdir()
        run([str(JDK / "javac.exe"), "-cp", cp, "-d", str(classes), str(PROBE)])
        probe_output = run([str(JDK / "java.exe"), "-cp", os.pathsep.join((str(classes), cp)),
                            "com.sao.ActivationProbe"], home=tmp)
        frame_probe = tmp / "FrameCapsProbe.java"
        frame_probe.write_text(
            "public class FrameCapsProbe { public static void main(String[] args) throws Exception {"
            "if (Class.forName(\"viewpoint.game.FrameCaps\").getField(\"ON\").getBoolean(null))"
            "throw new AssertionError(\"source FPS override active\");"
            "System.out.println(\"PASS native frame caps retained\"); }}", encoding="utf-8")
        run([str(JDK / "javac.exe"), "-cp", cp, "-d", str(classes), str(frame_probe)])
        frame_probe_output = run([str(JDK / "java.exe"), "-cp", os.pathsep.join((str(classes), cp)),
                                  "FrameCapsProbe"], home=tmp)
    check("adapted FrameCaps initializes with override disabled",
          "PASS native frame caps retained" in frame_probe_output)
    expected = [line for line in probe_output.splitlines() if line.startswith("PASS ")]
    check("activation probe cases", "PASS TOTAL 14" in probe_output and len(expected) == 15)

    receipt = {
        "schema": "sao-viewpoint-bundle-offline/1",
        "status": "PASS",
        "scope": "packaged Java bundle, source bytes, Lua fallback and controlled activation; no game launch",
        "vendorJarSha256": sha(VENDOR),
        "shippingJarSha256": sha(jar),
        "sourceViewpointEntries": len(source),
        "shippedViewpointEntries": len(shipped),
        "viewpointPatchTargets": patches,
        "overlapInventory": overlap,
        "sourceJavaSha256": {
            str(path.relative_to(ROOT)).replace("\\", "/"): sha(path)
            for path in (
                ROOT / "java/src/com/sao/Main.java",
                ROOT / "java/src/com/sao/SAOViewpointBootstrap.java",
                ROOT / "java/src/com/sao/agent/SAOViewpointShellVisibilityWeave.java",
                ROOT / "java/src/com/sao/agent/SAOViewpointFrameTelemetry.java",
                ROOT / "tools/adapt_viewpoint_framecaps.py",
                ROOT / "java/src/viewpoint/ModLua.java",
                ROOT / "java/src/com/sao/engine/SAOWeekOnePrivateStore.java",
                ROOT / "tools/build-java.sh",
            )
        },
        "checks": checks,
        "probe": expected,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": "PASS", "checks": len(checks), "probeCases": 14,
                      "receipt": str(args.out.resolve())}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
