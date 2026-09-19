#!/usr/bin/env python3
"""Border 167: native Kahlua string limits cannot truncate durable person state.

The engine's actual Kahlua table codec runs in private scratch. Bridge methods
are extracted verbatim; recording native-codec sinks isolate this adapter seam.
Border 163 separately exercises the real person codecs. No game or save files.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
PZ = Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid\projectzomboid.jar")
JDK = Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
METHODS = ("hibernate", "validateHibernation", "captureReturnLiving", "captureReturn",
           "captureReturnVisual", "validateReturnVisual", "restoreReturnLiving",
           "restoreReturnVisual", "returnMaterialsMatch", "awaken")
PASS = "PASS actual bridge adapter methods"
MUTATIONS = (
    ("no-fragmentation", "helper", "if (bytes.length <= SHORT_BYTES) return value;", "if (true) return value;", "oversize string was not fragmented"),
    ("oversized-fragments", "helper", "CHUNK_BYTES = 16000", "CHUNK_BYTES = 40000", "fragment exceeds native byte bound"),
    ("ignore-order-integrity", "helper", "if (!expectedHash.equals(digest(utf8(text))))", "if (false)", "reordered chunks accepted"),
    ("ignore-version", "helper", '|| !Double.valueOf(1).equals(table.rawget("version"))', "|| false", "unsupported version accepted"),
    ("ignore-declared-length", "helper", "if (total != expectedBytes)", "if (false)", "false length accepted"),
    ("accept-large-chunk", "helper", "bytes.length > CHUNK_BYTES", "false", "oversize chunk accepted"),
    ("bridge-writer-bypass", "bridge", "SAODurableText.pack(com.sao.engine.SAOHibernation.hibernate(shell))", "com.sao.engine.SAOHibernation.hibernate(shell)", "bridge writer bypassed durable packing"),
    ("bridge-reader-bypass", "bridge", "com.sao.engine.SAOHibernation.validate(SAODurableText.unpack(packed))", "com.sao.engine.SAOHibernation.validate(packed instanceof String text ? text : null)", "bridge reader bypassed durable unpacking"),
)

STUBS = {
    "SAOAgent.java": "package com.sao.agent; public final class SAOAgent { public static void log(String text) { System.out.println(text); } }",
    "SAOIsoPlayerShell.java": """package com.sao.engine;
public final class SAOIsoPlayerShell extends zombie.characters.IsoPlayer {
    private static zombie.characters.SurvivorDesc desc() {
        var result = new zombie.characters.SurvivorDesc(); result.getHumanVisual().setSkinTextureName("fixture"); return result;
    }
    public SAOIsoPlayerShell() { super(null, desc(), 0, 0, 0, false); }
}""",
    "SAODurableProbeSink.java": """package com.sao.engine;
public final class SAODurableProbeSink { public static String payload, visual, last; public static int restores;
    public static void restore(String text) { restores++; last = text; }
}""",
    "SAOHibernation.java": """package com.sao.engine;
public final class SAOHibernation {
    public static String hibernate(SAOIsoPlayerShell body) { return SAODurableProbeSink.payload; }
    public static boolean validate(String text) { return SAODurableProbeSink.payload.equals(text); }
    public static String awaken(SAOIsoPlayerShell body, String text, double hours) {
        SAODurableProbeSink.restore(text); return "AWAKENED fixture";
    }
}""",
    "SAONativeSnapshot.java": """package com.sao.engine;
public final class SAONativeSnapshot {
    public static String captureReturnLiving(SAOIsoPlayerShell body) { return SAODurableProbeSink.payload; }
    public static String captureReturn(zombie.characters.IsoZombie source, SAOIsoPlayerShell body) { return SAODurableProbeSink.payload; }
    public static String captureReturnVisual(zombie.characters.IsoGameCharacter body) { return SAODurableProbeSink.visual; }
    public static boolean validateReturnVisual(String text) { return SAODurableProbeSink.visual.equals(text); }
    public static void restoreStaged(SAOIsoPlayerShell body, String text) { SAODurableProbeSink.restore(text); }
    public static void restoreReturnVisual(SAOIsoPlayerShell body, String text) { SAODurableProbeSink.restore(text); }
    public static void unregister(SAOIsoPlayerShell body) { }
    public static boolean returnMaterialsMatch(zombie.characters.IsoZombie body, String text) { return SAODurableProbeSink.payload.equals(text); }
}""",
}

VISUAL_PROBE = """import com.sao.engine.SAONativeSnapshot;
import java.nio.ByteBuffer;
import java.util.*;
import java.security.MessageDigest;
public final class NativeVisualValidationProbe {
    static String envelope(byte[] bytes) throws Exception {
        return "1;249;" + Base64.getEncoder().encodeToString(bytes) + ";"
            + HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes));
    }
    public static void main(String[] args) throws Exception {
        var visual = new zombie.core.skinnedmodel.visual.HumanVisual(null);
        visual.setSkinTextureName("fixture");
        ByteBuffer buffer = ByteBuffer.allocate(16384); visual.save(buffer);
        byte[] bytes = Arrays.copyOf(buffer.array(), buffer.position());
        if (!SAONativeSnapshot.validateReturnVisual(envelope(bytes))) throw new AssertionError("valid native visual refused");
        if (SAONativeSnapshot.validateReturnVisual(envelope(new byte[0]))) throw new AssertionError("empty native visual accepted");
        if (SAONativeSnapshot.validateReturnVisual(envelope(Arrays.copyOf(bytes, bytes.length - 1))))
            throw new AssertionError("truncated native visual accepted");
        if (SAONativeSnapshot.validateReturnVisual(envelope(bytes).replace("1;249;", "1;248;")))
            throw new AssertionError("old native visual version accepted");
        System.out.println("PASS actual read-only native visual validation");
    }
}
"""


def surface(source):
    methods = []
    for name in METHODS:
        matches = list(re.finditer(r"    public [^\n]+\b" + re.escape(name) + r"\([^\n]*\) \{", source))
        if len(matches) != 1:
            raise RuntimeError(f"Bridge adapter {name} must have one actual source method")
        start = matches[0].start()
        opening = source.index("{", start)
        depth = 1
        end = opening + 1
        while depth and end < len(source):
            if source[end] == "{": depth += 1
            elif source[end] == "}": depth -= 1
            end += 1
        if depth: raise RuntimeError(f"Incomplete bridge method {name}")
        methods.append(source[start:end])
    return """import com.sao.agent.SAOAgent;
import com.sao.engine.SAODurableText;
import com.sao.engine.SAOIsoPlayerShell;
import zombie.characters.IsoGameCharacter;
public final class DurableBridgeSurface {
""" + "\n".join(methods) + "\n}\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", nargs="?", type=Path, default=ROOT)
    parser.add_argument("--receipt", type=Path)
    args = parser.parse_args()
    root = args.root.resolve()
    helper = root / "java/src/com/sao/engine/SAODurableText.java"
    bridge = root / "java/src/com/sao/bridge/SAOBridge.java"
    probe = root / "tools/luacheck/DurableTextProbe.java"
    snapshot = root / "java/src/com/sao/engine/SAONativeSnapshot.java"
    receipt = {"border": 167, "commands": [], "results": [],
               "limits": "Actual native Kahlua serializer and actual bridge method source; recording native-codec sinks isolate adapters. No game, world or save launch."}
    try:
        for path in (helper, bridge, probe, snapshot):
            if not path.is_file(): raise RuntimeError(f"Required durable text source missing: {path.name}")
        originals = {"helper": helper.read_text(encoding="utf-8-sig"), "bridge": bridge.read_text(encoding="utf-8-sig")}
        surface(originals["bridge"])
        if not all(path.is_file() for path in (PZ, JDK / "javac.exe", JDK / "java.exe")):
            print("SKIPPED durable text native VM: installed engine/JDK absent")
            return 0
        receipt["hashes"] = {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in (PZ, helper, bridge, probe, snapshot, Path(__file__))}
        with tempfile.TemporaryDirectory(prefix="sao-durable-text-") as tmp:
            scratch = Path(tmp)
            def run(argv, cwd):
                result = subprocess.run([str(arg) for arg in argv], cwd=cwd, capture_output=True,
                                        text=True, encoding="utf-8", errors="replace", timeout=60)
                receipt["commands"].append({"argv": [str(arg) for arg in argv], "cwd": str(cwd),
                                            "returncode": result.returncode, "stdout": result.stdout, "stderr": result.stderr})
                return result
            for name in ("zombie.world.moddata.GlobalModData", "se.krka.kahlua.j2se.KahluaTableImpl", "zombie.GameWindow$StringUTF"):
                evidence = run([JDK / "javap.exe", "-classpath", PZ, "-c", "-p", name], scratch)
                if evidence.returncode: raise RuntimeError("Native serializer evidence unavailable")
            visual_source = scratch / "NativeVisualValidationProbe.java"
            visual_source.write_text(VISUAL_PROBE, encoding="utf-8")
            visual_classes = scratch / "visual-classes"; visual_classes.mkdir()
            compiled = run([JDK / "javac.exe", "-encoding", "UTF-8", "-cp", PZ, "-d", visual_classes, snapshot, visual_source], scratch)
            if compiled.returncode: raise RuntimeError("Native visual validation compile failed: " + compiled.stderr)
            visual = run([JDK / "java.exe", "-cp", os.pathsep.join((str(visual_classes), str(PZ))), "NativeVisualValidationProbe"], scratch)
            if visual.returncode or "PASS actual read-only native visual validation" not in visual.stdout:
                raise RuntimeError("Native visual validation failed: " + visual.stdout + visual.stderr)
            receipt["results"].append({"case": "native-visual-validation", "passed": True})
            def case(name, texts):
                work = scratch / name; work.mkdir()
                files = {**STUBS, "SAODurableText.java": texts["helper"], "DurableBridgeSurface.java": surface(texts["bridge"])}
                for filename, text in files.items(): (work / filename).write_text(text, encoding="utf-8")
                classes = work / "classes"; classes.mkdir()
                compiled = run([JDK / "javac.exe", "-encoding", "UTF-8", "-cp", PZ, "-d", classes,
                                *[work / filename for filename in files], probe], work)
                if compiled.returncode: raise RuntimeError(f"{name} compile failed: {compiled.stderr}")
                return run([JDK / "java.exe", "--enable-native-access=ALL-UNNAMED", f"-Duser.home={work}",
                            "-cp", os.pathsep.join((str(classes), str(PZ))), "DurableTextProbe"], work)
            production = case("production", originals)
            if production.returncode or PASS not in production.stdout:
                raise RuntimeError("Durable text production failed: " + production.stdout + production.stderr)
            receipt["results"].append({"case": "production", "passed": True})
            print("PASS native Kahlua durable text and bridge adapters")
            for name, owner, before, after, reason in MUTATIONS:
                if originals[owner].count(before) != 1: raise RuntimeError(f"Control {name} target changed")
                changed = dict(originals); changed[owner] = changed[owner].replace(before, after, 1)
                result = case(name, changed)
                if result.returncode == 0 or reason not in result.stdout + result.stderr:
                    raise RuntimeError(f"Control {name} failed for wrong reason: {result.stdout}{result.stderr}")
                receipt["results"].append({"case": name, "passed": True, "reason": reason})
                print(f"CONTROL {name}: {reason}")
        receipt["status"] = "PASS"
        print("  167) PASS -- durable person text")
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
        receipt["status"] = "FAIL"; receipt["error"] = str(error)
        print("FAULT " + str(error))
    if args.receipt:
        args.receipt.parent.mkdir(parents=True, exist_ok=True)
        args.receipt.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    return 0 if receipt.get("status") == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
