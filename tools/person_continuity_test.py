#!/usr/bin/env python3
"""Border 169: complete native person state survives repeated wakes.

Compiles the shipped v4 snapshot and the installed-engine probe. Each control
removes one continuation or refusal seam and must make the same probe fail for
that state, rather than merely matching source text.
"""

import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parent.parent
JDK = Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ = Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid\projectzomboid.jar")
PASS = "PASS native snapshot: v3/v4"
MUTATIONS = [
    ("unsafe-nutrition-weight",
     "if (!Float.isFinite(weight) || weight < 35.0f || weight > 1000.0f) {",
     "if (!Float.isFinite(weight) || false || weight > 1000.0f) {",
     "unsafe nutrition weight accepted"),
    ("omit-nutrition-cadence",
     'setField(nutrition, Nutrition.class, "updatedWeight", in.readInt());',
     "in.readInt();",
     "nutrition continuation state"),
    ("reuse-fitness-component",
     "Fitness fitness = new Fitness(shell);",
     "Fitness fitness = shell.getFitness();",
     "fitness continuation state"),
    ("omit-learning-state",
     "restoreLearning(shell, sections[7]);",
     "/* missing learning restore */",
     "recipe reading media and descriptor boost state"),
    ("accept-missing-boost-perk",
     "for (String id : boosts.keySet()) requirePerk(id);",
     "/* missing descriptor-perk preflight */",
     "missing custom perk accepted by preflight"),
    ("omit-native-appearance",
     "visual.load(input, VERIFIED_WORLD_VERSION);",
     "input.position(input.limit());",
     "human skin texture"),
    ("accept-missing-outfit",
     'if (outfit == null) throw new IOException("Outfit unavailable: " + state.outfit());',
     'if (false) throw new IOException("Outfit unavailable: " + state.outfit());',
     "missing outfit reference accepted"),
    ("omit-hair-growth-timing",
     'setField(shell, IsoGameCharacter.class, "hairGrowTiming", state.hairGrowTiming());',
     "/* missing hair growth timing */",
     "human hair growth timing"),
    ("omit-character-metadata",
     "restoreCharacterModData(shell, sections[9]);",
     "/* missing durable character metadata */",
     "durable character ModData and runtime ownership"),
    ("accept-unsupported-character-metadata",
     "if (!KahluaTableImpl.canSave(key, value)) {",
     "if (false) {",
     "unsupported durable character ModData accepted"),
    ("omit-fluid-content-check",
     "checkFluidFacts(items, snapshot.manifest().fluids());",
     "/* missing exact fluid-content check */",
     "missing fluid definition accepted"),
    ("drop-native-v3-reader",
     "} else if (packed != null && packed.startsWith(PREFIX_V3)) {",
     "} else if (false) {",
     "native v3 reader compatibility"),
]


def main():
    source = ROOT / "java/src/com/sao/engine/SAONativeSnapshot.java"
    probe = ROOT / "tools/luacheck/PersonSnapshotProbe.java"
    hibernation = ROOT / "java/src/com/sao/engine/SAOHibernation.java"
    bridge = ROOT / "java/src/com/sao/bridge/SAOBridge.java"
    body = ROOT / "mod/42.20/media/lua/client/SAO_Body.lua"
    returned = ROOT / "mod/42.20/media/lua/client/SAO_AfflictedReturn.lua"
    try:
        for path in (source, probe, hibernation, bridge, body, returned):
            if not path.is_file():
                raise RuntimeError(f"Required continuity source missing: {path.name}")
        if not all(path.is_file() for path in (PZ, JDK / "javac.exe", JDK / "java.exe")):
            print("SKIPPED native person continuity VM: installed engine/JDK absent")
            return 0

        native = source.read_text(encoding="utf-8-sig")
        body_text = body.read_text(encoding="utf-8-sig")
        return_text = returned.read_text(encoding="utf-8-sig")
        hibernation_text = hibernation.read_text(encoding="utf-8-sig")
        bridge_text = bridge.read_text(encoding="utf-8-sig")
        static = {
            "v4-writer": 'private static final String PREFIX_V4 = "v4;";' in native,
            "v3-reader": 'private static final String PREFIX_V3 = "v3;";' in native,
            "native-routing": hibernation_text.count("SAONativeSnapshot.isNative(packed)") >= 2,
            "bridge-version": "hibernationVersion(Object packed)" in bridge_text,
            "legacy-sidecar-only": re.search(
                r"snapshotVersion\s*<\s*4\s+and\s+rec\.bodyVisual", body_text) is not None,
            "migration-provenance": "rec.hibernationMigration = { from = snapshotVersion" in body_text,
            "new-capture-clears-sidecar": "rec.bodyVisual = pending.visual" in body_text,
            "return-clears-sidecar":
                "if hibernationVersion(p.packed) >= 4 then rec.bodyVisual = nil" in return_text,
        }
        missing = [name for name, present in static.items() if not present]
        if missing:
            raise RuntimeError("Continuity routing missing: " + ", ".join(missing))

        with tempfile.TemporaryDirectory(prefix="sao-person-continuity-") as tmp:
            scratch = Path(tmp)

            def run_case(name, text):
                work = scratch / name
                work.mkdir()
                changed = work / "SAONativeSnapshot.java"
                changed.write_text(text, encoding="utf-8")
                classes = work / "classes"
                classes.mkdir()
                compiled = subprocess.run([
                    str(JDK / "javac.exe"), "-encoding", "UTF-8", "-cp", str(PZ),
                    "-d", str(classes), str(changed), str(probe),
                ], cwd=work, capture_output=True, text=True, encoding="utf-8",
                    errors="replace", timeout=60)
                if compiled.returncode:
                    raise RuntimeError(f"{name} did not compile: {compiled.stderr}")
                return subprocess.run([
                    str(JDK / "java.exe"), f"-Duser.home={work}", "-cp",
                    os.pathsep.join((str(classes), str(PZ))), "PersonSnapshotProbe",
                ], cwd=work, capture_output=True, text=True, encoding="utf-8",
                    errors="replace", timeout=60)

            production = run_case("production", native)
            if production.returncode or PASS not in production.stdout:
                raise RuntimeError("Continuity roundtrip failed: "
                                   + production.stdout + production.stderr)
            print("PASS complete native person continuity and migration routing")
            for name, before, after, reason in MUTATIONS:
                if native.count(before) != 1:
                    raise RuntimeError(f"Control {name} no longer has exactly one source target")
                changed = native.replace(before, after, 1)
                result = run_case(name, changed)
                if not result.returncode or reason not in result.stdout + result.stderr:
                    raise RuntimeError(f"Control {name} did not fail for {reason}: "
                                       + result.stdout + result.stderr)
                print(f"CONTROL {name}: {reason}")
        print("  169) PASS -- native person continuity")
        return 0
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
        print("FAULT " + str(error))
        return 1


if __name__ == "__main__":
    sys.exit(main())
