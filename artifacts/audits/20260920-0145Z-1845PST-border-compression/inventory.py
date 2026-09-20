"""Read-only inventory of this baseline's two Python gate invocation forms."""
import ast
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from lua_read import strip_lua


CONTRACTS = {
    "person_continuity": {
        "lua": "Identity Body AfflictedReturn CrossedTransfer Age Appearance Binding",
        "java": "SAOIsoPlayerShell SAONativeSnapshot SAOHibernation SAOReturnBody SAODurableText SAOBodyScale SAOBodyScaleWeave",
    },
    "time_population_world": {
        "lua": "History Record Population Census World WorldGenesis Places PlaceAttachment WorldDevelopment",
        "java": "SAORecord SAOWorldCensus SAOGround",
    },
    "perception_knowledge": {
        "lua": "Perception Knowledge Claims Lessons", "java": "SAOPerceptionScanner",
    },
    "disposition_health": {
        "lua": "Disposition Conditions Traits Habits Drugs Course Neuro PathogenPressure", "java": "",
    },
    "standing_relationships": {
        "lua": "Standing Command Recognition Organization Settlement Isolation", "java": "SAOSettlement",
    },
    "decision_and_life_producers": {
        "lua": "Integration Branching Pressure Labor Adaptation Material", "java": "",
    },
    "action_execution": {
        "lua": "Controller Needs Locomotion Driving Animals Medical Gesture Nuke",
        "java": "SAOMovement SAORouteState SAOCombat SAOCombatGate SAONeeds SAOEquipment SAOBuild SAOFence SAODriver SAODriveState SAODriveLaw SAOCrossedDriver SAOAnimals SAOZombieDirector",
    },
    "communication_presentation": {
        "lua": "Exchange Communication PlayerInteraction Voice Radio RadioEar Harness UI Inspect MedicalWindow Telemetry", "java": "",
    },
    "compatibility": {"lua": "Absorb Neighbours PathogenEvents", "java": "SAOKnox"},
    "runtime_bootstrap": {
        "lua": "Hash Rand Log Seams Sandbox GraphPersistence",
        "java": "Main SAOAgent SAOMeleeTransformer SAOBridge SAOBridgeBootstrap",
    },
}


def runtime_inventory(test_rows):
    files = sorted(list((ROOT / "mod/42.20/media/lua").rglob("*.lua"))
                   + list((ROOT / "java/src").rglob("*.java")))
    owners = {}
    for contract, members in CONTRACTS.items():
        for extension, names in members.items():
            for name in names.split():
                filename = ("SAO_" + name if extension == "lua" else name) + "." + extension
                assert filename not in owners, filename
                owners[filename] = contract
    assert set(owners) == {path.name for path in files}, {
        "unmapped": sorted({p.name for p in files} - set(owners)),
        "missing": sorted(set(owners) - {p.name for p in files}),
    }
    known_lua = {p.stem.removeprefix("SAO_"): p for p in files if p.suffix == ".lua"}
    known_java = {p.stem: p for p in files if p.suffix == ".java"}
    fixture = '-- SAO.False.run()\nlocal x="SAO.False.run()"\nSAO.True.run()'
    assert re.findall(r"\bSAO\.([A-Za-z_][A-Za-z_0-9]*)", strip_lua(fixture)) == ["True"]
    rows = []
    for path in files:
        raw = path.read_bytes()
        source = raw.decode("utf-8-sig")
        if path.suffix == ".lua":
            code = strip_lua(source)
            refs = {known_lua[name].relative_to(ROOT).as_posix()
                    for name in re.findall(r"\bSAO\.([A-Za-z_][A-Za-z_0-9]*)", code)
                    if name in known_lua and known_lua[name] != path}
            registrations = sorted(set(re.findall(r"\bEvents\.([A-Za-z_0-9]+)\.Add", code)))
        else:
            # Java references remain lexical candidates; strings and comments may contribute.
            refs = {known_java[name].relative_to(ROOT).as_posix()
                    for name in re.findall(r"\b[A-Za-z_][A-Za-z_0-9]*\b", source)
                    if name in known_java and known_java[name] != path}
            registrations = []
        rows.append({
            "path": path.relative_to(ROOT).as_posix(),
            "sha256": hashlib.sha256(raw).hexdigest(),
            "lines_including_comments": len(source.splitlines()),
            "review_contract": owners[path.name],
            "lexical_dependencies": sorted(refs),
            "direct_event_registration_names": registrations,
            "gate_scripts_naming_file": [row["path"] for row in test_rows
                                         if path.name in row["lexical_production_references"]],
        })
    result = {
        "schema": "sao-runtime-review-inventory/1",
        "scope": "Lua under mod/42.20/media/lua and Java under java/src",
        "source_files": len(rows),
        "lua_files": sum(p.suffix == ".lua" for p in files),
        "java_files": sum(p.suffix == ".java" for p in files),
        "review_contracts": CONTRACTS,
        "limits": "Review groupings are not a new package layout or proof of sole ownership. Lua references omit comments and strings but do not resolve dynamic dispatch; Java references may include comments and strings. Neither graph proves execution or coverage. File lengths include comments. Shipping metadata, translations and jars are separate assembly inputs.",
        "entries": rows,
    }
    (HERE / "runtime-inventory.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"Runtime map: {len(rows)} source files, every file assigned once; lexical-reader control passed")


def entry_points(source):
    executable = "\n".join(line for line in source.splitlines()
                           if not line.lstrip().startswith("#"))
    direct = set(re.findall(r'"\$PY" tools/([a-z_0-9]+)\.py', executable))
    loops = re.findall(r"for mirror in \\?\n(.*?)\ndo", executable, re.S)
    loop_names = set()
    for loop in loops:
        loop_names.update(re.findall(r"\b([a-z_0-9]+)\b", loop))
    return direct | loop_names


def main():
    fixture = ('# "$PY" tools/comment.py\n'
               '"$PY" tools/direct.py\n'
               'for mirror in \\\n    loop_test\ndo\n'
               '"$PY" "tools/$mirror.py"\ndone\n')
    assert entry_points(fixture) == {"direct", "loop_test"}
    assert entry_points(fixture.replace("tools/direct.py", "tools/changed.py")) == {
        "changed", "loop_test"}
    assert entry_points(fixture.replace("    loop_test", "    changed_test")) == {
        "direct", "changed_test"}
    gate = (ROOT / "tools/check.sh").read_text(encoding="utf-8")
    names = entry_points(gate)
    all_tests = {p.stem for p in (ROOT / "tools").glob("*_test.py")}
    assert all_tests <= names, sorted(all_tests - names)
    rows = []
    for name in sorted(names):
        path = ROOT / "tools" / (name + ".py")
        raw = path.read_bytes()
        source = raw.decode("utf-8-sig")
        header = ast.get_docstring(ast.parse(source)) or ""
        rows.append({
            "path": path.relative_to(ROOT).as_posix(),
            "sha256": hashlib.sha256(raw).hexdigest(),
            "test_file": name in all_tests,
            "declared_title": header.splitlines()[0] if header else None,
            "lexical_production_references": sorted(set(re.findall(
                r"\bSAO[_A-Za-z0-9]+\.(?:lua|java)\b", source))),
            "behavioral_coverage": "not assessed by this inventory",
        })
    result = {
        "schema": "sao-border-entry-inventory/1",
        "source_commit": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "gate_sha256": hashlib.sha256((ROOT / "tools/check.sh").read_bytes()).hexdigest(),
        "gate_lines": len(gate.splitlines()),
        "distinct_python_entry_points": len(rows),
        "test_files": len(all_tests),
        "method": "Explicit $PY tools/name.py calls and named entries in the mirror loop; comments excluded.",
        "instrument_controls": "Exact fixture enumeration; direct and loop substitutions change membership; comments excluded.",
        "limits": "Static entry-point inventory. Does not count repeated invocations, subprocesses, cases, controls, or effective behavioral coverage.",
        "entries": rows,
    }
    output = HERE / "inventory.json"
    output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"Inventory: {len(rows)} entry points, {len(all_tests)} test files; controls passed")
    runtime_inventory(rows)


if __name__ == "__main__":
    main()
