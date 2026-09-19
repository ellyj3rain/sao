#!/usr/bin/env python3
"""Border 163: native person components survive the actual engine codecs.

Builds the shipped snapshot implementation and PersonSnapshotProbe against the
installed jar in private scratch. The probe uses real engine item factories,
containers, players, Stats, BodyDamage and XP with explicit headless registry,
appearance/audio/event fixtures. It does not launch a world or use save files.
Source mutations must compile and fail for the stated reason. An optional first
argument selects another source tree, as required by the gate's absent-Lua control.
"""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

from menu_reach import strip_lua


DEFAULT_ROOT = Path(__file__).resolve().parent.parent
JDK = Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ = Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid\projectzomboid.jar")
PASS = "PASS native snapshot:"
MUTATIONS = [
    ("empty-native-inventory",
     "serialize(buffer -> shell.getInventory().save(buffer)),",
     "serialize(buffer -> new ItemContainer().save(buffer)),",
     "Restored item identity/type/container differs"),
    ("omit-native-stats",
     "shell.getStats().load(buffer, snapshot.version());",
     "buffer.position(buffer.limit());",
     "native stats"),
    ("omit-native-wounds",
     "shell.getBodyDamage().load(buffer, snapshot.version());",
     "buffer.position(buffer.limit());",
     "native wound state"),
    ("omit-native-experience",
     "shell.getXp().load(buffer, snapshot.version());",
     "buffer.position(buffer.limit());",
     "native XP and traits"),
    ("lose-primary-reference",
     "shell.setPrimaryHandItem(item(items, equipment.primary()));",
     "shell.setPrimaryHandItem(null);",
     "Equipment restoration did not preserve references"),
    ("accept-corruption",
     "if (!MessageDigest.isEqual(hash(Arrays.copyOf(bytes, payloadSize)),\n"
     "                Arrays.copyOfRange(bytes, payloadSize, bytes.length))) {",
     "if (false) {",
     "checksum corruption accepted"),
    ("accept-old-native-version",
     "if (version != VERIFIED_WORLD_VERSION || IsoWorld.getWorldVersion() != version) {",
     "if (false) {",
     "unsupported native version accepted"),
    ("drop-nested-item-silently",
     "if (!facts.equals(snapshot.manifest().items())) {",
     "if (false) {",
     "missing nested unequipped script accepted"),
    ("omit-native-item-processing",
     "IsoWorld.instance.currentCell.addToProcessItems(restored);",
     "/* missing native processing registration */",
     "root and nested food not registered for native processing"),
    ("omit-native-item-unregister",
     "IsoWorld.instance.currentCell.addToProcessItemsRemove(carried);",
     "/* missing native processing removal */",
     "recursive native processing removal"),
    ("accept-missing-custom-perk",
     "if (perk == null || perk == PerkFactory.Perks.MAX || !name.equals(perk.getId())) {",
     "if (false) {",
     "missing custom perk accepted by preflight"),
    ("accept-missing-custom-trait",
     "if (!Registries.CHARACTER_TRAIT.contains(ResourceLocation.of(name))) {",
     "if (false) {",
     "missing custom trait accepted by preflight"),
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", nargs="?", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--receipt", type=Path)
    args = parser.parse_args()
    root = args.root.resolve()
    source = root / "java/src/com/sao/engine/SAONativeSnapshot.java"
    probe = root / "tools/luacheck/PersonSnapshotProbe.java"
    body = root / "mod/42.20/media/lua/client/SAO_Body.lua"
    hibernation = root / "java/src/com/sao/engine/SAOHibernation.java"
    receipt = {"border": 163, "results": [], "commands": []}
    try:
        for path in (source, probe, body, hibernation):
            if not path.is_file():
                raise RuntimeError(f"Required person snapshot source missing: {path.name}")
        body_text = strip_lua(body.read_text(encoding="utf-8-sig"))
        if not re.search(r"SAOJavaBridge\s*:\s*validateHibernation\s*\(", body_text):
            raise RuntimeError("Body transition does not validate captured state")
        if not re.search(r"SAOJavaBridge\s*:\s*awaken\s*\(", body_text):
            raise RuntimeError("Body materialization does not restore person state")
        handoff = hibernation.read_text(encoding="utf-8-sig")
        for method in ("capture", "validate", "restore"):
            if not re.search(r"SAONativeSnapshot\." + method + r"\s*\(", handoff):
                raise RuntimeError(f"Hibernation does not use native {method}")
        if not all(path.is_file() for path in (PZ, JDK / "javac.exe", JDK / "java.exe")):
            print("SKIPPED native person snapshot VM: installed engine/JDK absent")
            return 0
        original = source.read_text(encoding="utf-8-sig")
        with tempfile.TemporaryDirectory(prefix="sao-person-snapshot-") as tmp:
            scratch = Path(tmp)

            def run(argv, cwd):
                result = subprocess.run([str(value) for value in argv], cwd=cwd,
                                        capture_output=True, text=True,
                                        encoding="utf-8", errors="replace", timeout=60)
                receipt["commands"].append({
                    "argv": [str(value) for value in argv], "cwd": str(cwd),
                    "returncode": result.returncode, "stdout": result.stdout,
                    "stderr": result.stderr,
                })
                return result

            def case(name, text):
                work = scratch / name
                work.mkdir()
                changed = work / "SAONativeSnapshot.java"
                changed.write_text(text, encoding="utf-8")
                classes = work / "classes"
                classes.mkdir()
                compiled = run([JDK / "javac.exe", "-encoding", "UTF-8", "-cp", PZ,
                                "-d", classes, changed, probe], work)
                if compiled.returncode:
                    raise RuntimeError(f"{name} did not compile: {compiled.stderr}")
                return run([JDK / "java.exe", f"-Duser.home={work}", "-cp",
                            os.pathsep.join((str(classes), str(PZ))),
                            "PersonSnapshotProbe"], work)

            production = case("production", original)
            if production.returncode or PASS not in production.stdout:
                raise RuntimeError("Native roundtrip failed: "
                                   + production.stdout + production.stderr)
            receipt["results"].append({"case": "production", "passed": True})
            print("PASS native person components and refusal controls")
            for name, before, after, reason in MUTATIONS:
                if original.count(before) != 1:
                    raise RuntimeError(f"Control {name} no longer has exactly one source target")
                changed = original.replace(before, after, 1)
                if changed == original:
                    raise RuntimeError(f"Control {name} did not change the source")
                result = case(name, changed)
                if not result.returncode or reason not in result.stdout + result.stderr:
                    raise RuntimeError(f"Control {name} did not fail for {reason}: "
                                       + result.stdout + result.stderr)
                receipt["results"].append({"case": name, "passed": True, "reason": reason})
                print(f"CONTROL {name}: {reason}")
        receipt["status"] = "PASS"
        print("  163) PASS -- native person snapshot")
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
        receipt["status"] = "FAIL"
        receipt["error"] = str(error)
        print("FAULT " + str(error))
    if args.receipt:
        args.receipt.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    return 0 if receipt.get("status") == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
