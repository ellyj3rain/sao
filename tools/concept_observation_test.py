"""Installed native visibility/geometry with controlled rooms and objects; no rendered-world claim."""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import sys
from native_proof_preflight import installed_presence

ROOT = Path(__file__).resolve().parents[1]
GAME = Path(os.environ.get("PZ_DIR", r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"))
JDK = Path(os.environ.get("JDK_BIN", r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin"))
OUT = ROOT / "_scratch/d1-concept-observation"
SOURCE = ROOT / "java/src/com/sao/engine/SAOConceptObservation.java"
BRIDGE = ROOT / "java/src/com/sao/bridge/SAOBridge.java"
PROBE = ROOT / "tools/javacheck/ConceptObservationProbe.java"
BOOT = ROOT / "tools/luacheck/MovementCrossingProbe.java"
RECOVERY_SOURCE = ROOT / "java/src/com/sao/engine/SAORecoveryPlace.java"


def run(selected_variants=None):
    OUT.mkdir(parents=True, exist_ok=True)
    jars = [GAME / "projectzomboid.jar", GAME / "ZombieBuddy.jar", ROOT / "mod/42.20/media/java/SAO.jar"]
    cp = os.pathsep.join(map(str, jars))
    files = [SOURCE, RECOVERY_SOURCE, BRIDGE, PROBE, BOOT, Path(__file__), *jars]
    files.append(Path(__file__).with_name('native_proof_preflight.py'))
    preflight = installed_presence(files, GAME, JDK, "concept observation")
    if preflight is not None:
        raise SystemExit(preflight)
    pins = lambda: {str(p.relative_to(ROOT)) if p.is_relative_to(ROOT) else str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
    receipt = {"schema": "sao.concept-observation-proof/1", "status": "INCOMPLETE", "boundary": __doc__, "inputs": pins(), "variants": []}
    (OUT / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    variants = [
        ("production", None, None, None),
        ("workbench-omitted", 'if (name.equals("workbench")) return "workbench";', '', "visible_workbench_object_observed"),
        ("foreign-workbench-holder", 'holder.getSourceGrid() == square', 'true', "workbench_foreign_container_withheld"),
        ("foreign-workbench-parent", 'holder.getParent() == object', 'true', "workbench_foreign_parent_withheld"),
        ("ignore-visibility", "if (!SAOPerceptionScanner.canSeeWorldSquareNow(body, square, radius)) continue;", "if (square == null) continue;", "visible_bed_observed"),
        ("foreign-owner", 'data.rawget("SAOExternalOwner") != null', "false", "foreign_owner_refused"),
        ("duplicate-object", "!seenObjects.add(object)", "false", "duplicate_native_object_once"),
        ("authored-room-as-fact", 'row.rawset("concept", "room")', 'row.rawset("concept", currentRoom.getName())', "authored_room_labels_not_observed"),
        ("ignore-range", "radius < 1 || radius > 14", "false", "invalid_range_refused"),
        ("hidden-building-gate", "if (square.getBuildingDef() == null) continue;", "if (square.getBuildingDef() == null || next.getBuildingDef() == null || square.getBuildingDef().getID() != next.getBuildingDef().getID()) continue;", "hidden_building_does_not_change_frontier"),
        ("require-external-token", 'Object identity = data.rawget("SAOPersonId");', 'if (data.rawget("SAOExternalToken") == null) return null; Object identity = data.rawget("SAOPersonId");', "ordinary_tokenless_observer_admitted"),
    ]
    original = SOURCE.read_text(encoding="utf-8")
    if selected_variants is not None:
        variants = [v for v in variants if v[0] in selected_variants]
        assert len(variants) == len(selected_variants), 'unknown concept-observation variant'
    for name, old, new, marker in variants:
        target = OUT / name
        target.mkdir(exist_ok=True)
        source = original
        if old:
            assert source.count(old) == 1, name
            source = source.replace(old, new, 1)
        candidate = target / SOURCE.name
        candidate.write_text(source, encoding="utf-8")
        compile_command = [JDK / "javac.exe", "-encoding", "UTF-8", "-cp", cp, "-d", target, candidate, RECOVERY_SOURCE, BRIDGE, PROBE, BOOT]
        compiled = subprocess.run(list(map(str, compile_command)), capture_output=True, text=True, timeout=120)
        (target / "compile.log").write_text(compiled.stdout + compiled.stderr, encoding="utf-8")
        assert compiled.returncode == 0, compiled.stdout + compiled.stderr
        command = [JDK / "java.exe", "-Duser.home=" + str(target), "-Djava.awt.headless=true", "-Djava.library.path=" + str(GAME), "-cp", str(target) + os.pathsep + cp, "ConceptObservationProbe"]
        result = subprocess.run(list(map(str, command)), cwd=GAME, capture_output=True, text=True, timeout=90)
        log = result.stdout + result.stderr
        (target / "run.log").write_text(log, encoding="utf-8")
        receipt["variants"].append({"name": name, "exit": result.returncode, "expectedFailure": marker,
            "log": str((target / "run.log").relative_to(OUT)), "logSha256": hashlib.sha256(log.encode()).hexdigest(),
            "classes": {str(p.relative_to(target)): hashlib.sha256(p.read_bytes()).hexdigest() for p in target.rglob("*.class")}})
        (OUT / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
        assert (result.returncode != 0 and "CONCEPT:" + marker in log) if marker else (result.returncode == 0 and "PASS concept observation" in log), log
        print(name + ": " + (marker or next(line for line in log.splitlines() if line.startswith("PASS concept observation"))), flush=True)
    receipt["inputsAfter"] = pins()
    assert receipt["inputsAfter"] == receipt["inputs"], "native proof inputs changed"
    receipt["status"] = "PASS"
    (OUT / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    try:
        run()
    except Exception as error:
        print("FAIL concept observation: " + str(error), file=sys.stderr)
        raise SystemExit(1)
