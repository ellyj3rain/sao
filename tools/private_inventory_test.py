#!/usr/bin/env python3
"""Border 184: exact, recursive, actor-private native inventory views."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import subprocess
import tempfile
import time


ROOT = pathlib.Path(__file__).resolve().parent.parent
GAME = pathlib.Path(os.environ.get(
    "PZ_DIR", r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"))
PZ = GAME / "projectzomboid.jar"
ZB = GAME / "ZombieBuddy.jar"
JDK = pathlib.Path(os.environ.get(
    "JDK_BIN", r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin"))


def sha(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def static_contract(root: pathlib.Path) -> list[str]:
    private = (root / "java/src/com/sao/engine/SAOPrivateInventory.java").read_text(
        encoding="utf-8-sig")
    needs = (root / "java/src/com/sao/engine/SAONeeds.java").read_text(
        encoding="utf-8-sig")
    bridge = (root / "java/src/com/sao/bridge/SAOBridge.java").read_text(
        encoding="utf-8-sig")
    standing = (root / "mod/42.20/media/lua/shared/SAO_Standing.lua").read_text(
        encoding="utf-8-sig")
    provisioning = (root / "mod/42.20/media/lua/shared/SAO_Provisioning.lua").read_text(
        encoding="utf-8-sig")
    controller = (root / "mod/42.20/media/lua/client/SAO_Controller.lua").read_text(
        encoding="utf-8-sig")
    sources = (root / "java/src/com/sao/engine/SAOWorldSources.java").read_text(
        encoding="utf-8-sig")
    plan = (root / "artifacts/audits/20260921-1838Z-1138PST-complete-private-inventory/PLAN.md").read_text(
        encoding="utf-8-sig")
    lua_decisions = "\n".join((root / name).read_text(encoding="utf-8-sig") for name in (
        "mod/42.20/media/lua/client/SAO_Animals.lua",
        "mod/42.20/media/lua/client/SAO_Controller.lua",
        "mod/42.20/media/lua/client/SAO_Harness.lua",
        "mod/42.20/media/lua/client/SAO_Needs.lua",
        "mod/42.20/media/lua/client/SAO_RadioEar.lua",
        "mod/42.20/media/lua/shared/SAO_Standing.lua",
    ))
    checks = {
        "read-only owner": "Project Zomboid remains the inventory owner" in plan,
        "coverage matrix": all(term in plan for term in (
            "Static containers", "Vehicle containers", "Placed items",
            "Corpse containers", "Person privacy", "Coverage")),
        "protocol": 'PROTOCOL = "SAOPI1"' in private,
        "recursive carriage": "collectItems(nested.getInventory()" in private,
        "direct parents": "parentItemId" in private and "fact.parentItemId()" in private,
        "holder surfaces": all(kind in private for kind in (
            '"container"', '"vehicle"', '"ground"', '"corpse"')),
        "aggregate refused": 'append("|aggregate=refused")' in private,
        "dormant world unknown": 'finish(normalized, "dormant", "complete", "unknown"' in private,
        "source identities": all(name in sources for name in (
            "privateContainerId", "privateVehicleId", "privateGroundId")),
        "bridge views": all(name in bridge for name in (
            "privateCarriedItems", "privateInventoryLoaded",
            "privateInventoryDormant", "privateContainerItems",
            "privateCorpseItems", "privateDormantHasRadio")),
        "java decisions use view": ".getItems()" not in needs
            and "nearestPrivateSource" in needs and "privateStoreItems" in needs,
        "lua carried decisions use bridge": "privateCarriedItems" in lua_decisions,
        "lua root scans removed": ":getItems()" not in lua_decisions,
        "exact dormant radio": "privateDormantHasRadio" in standing
            and "hibernation:find" not in standing,
        "bounded totals refused": "privateInventoryLoaded(body, 12)" in controller
            and "aggregate=refused" in controller
            and "quartermaster-native-scan" not in controller
            and "countEdibleNearby(body, 12)" not in controller
            and "countStoredWaterNearby(body, 12)" not in controller,
        "inferred totals retired": "local STANDING_SCHEMA = 4" in standing
            and "migrateInferredMaterialClaims" in standing
            and "completeMaterialClaimAllowed" in standing,
        "complete claims require coverage": "evidence.completeCoverage == true" in standing
            and "completeCoverage = true" in provisioning,
    }
    missing = [name for name, passed in checks.items() if not passed]
    if missing:
        raise RuntimeError("Private inventory contract missing: " + ", ".join(missing))
    return list(checks)


def run(command, cwd, phase, case, receipt, timeout=120):
    start = time.perf_counter()
    result = subprocess.run([str(value) for value in command], cwd=cwd,
        capture_output=True, text=True, encoding="utf-8", errors="replace",
        timeout=timeout)
    receipt["commands"].append({
        "phase": phase, "case": case, "returncode": result.returncode,
        "seconds": time.perf_counter() - start,
        "stdout": result.stdout, "stderr": result.stderr,
    })
    return result


def execute(root: pathlib.Path, receipt: dict) -> None:
    source = root / "java/src/com/sao/engine/SAOPrivateInventory.java"
    original = source.read_text(encoding="utf-8-sig")
    before = "collectItems(nested.getInventory(), found, seen, depth + 1);"
    after = "/* mutation omits nested carried items */"
    if original.count(before) != 1:
        raise RuntimeError("Nested-carriage mutation target drifted")

    with tempfile.TemporaryDirectory(prefix="sao-private-inventory-") as raw:
        work = pathlib.Path(raw)
        production = work / "production"
        production.mkdir()
        generated = work / "SAOVersion.java"
        version = (root / "VERSION").read_text(encoding="utf-8-sig").strip()
        generated.write_text(
            "package com.sao; public final class SAOVersion { "
            f'public static final String VALUE = "{version}"; '
            "private SAOVersion() {} }\n", encoding="utf-8")
        inputs = sorted((root / "java/src").rglob("*.java"))
        inputs.extend((generated,
            root / "tools/luacheck/PrivateInventoryProbe.java"))
        classpath = os.pathsep.join(map(str, (PZ, ZB)))
        compiled = run([JDK / "javac.exe", "-encoding", "UTF-8", "-cp",
            classpath, "-d", production, *inputs], work, "compile",
            "production", receipt)
        if compiled.returncode:
            raise RuntimeError("Private inventory production compile failed: "
                + compiled.stdout + compiled.stderr)
        result = run([JDK / "java.exe", f"-Duser.home={work}", "-cp",
            os.pathsep.join(map(str, (production, PZ, ZB))),
            "PrivateInventoryProbe"], work, "probe", "production", receipt)
        if result.returncode or "PASS private inventory" not in result.stdout:
            raise RuntimeError("Private inventory production probe failed: "
                + result.stdout + result.stderr)
        print(result.stdout.strip())
        receipt["results"].append({"case": "production", "passed": True})

        mutation = work / "mutation"
        mutation.mkdir()
        changed = mutation / "SAOPrivateInventory.java"
        changed.write_text(original.replace(before, after, 1), encoding="utf-8")
        mutated_classes = mutation / "classes"
        mutated_classes.mkdir()
        mutated = run([JDK / "javac.exe", "-encoding", "UTF-8", "-cp",
            os.pathsep.join(map(str, (production, PZ, ZB))), "-d",
            mutated_classes, changed], mutation, "compile", "omit-nested",
            receipt)
        if mutated.returncode:
            raise RuntimeError("Private inventory control did not compile: "
                + mutated.stdout + mutated.stderr)
        controlled = run([JDK / "java.exe", f"-Duser.home={mutation}", "-cp",
            os.pathsep.join(map(str, (mutated_classes, production, PZ, ZB))),
            "PrivateInventoryProbe"], mutation, "probe", "omit-nested",
            receipt)
        output = controlled.stdout + controlled.stderr
        if controlled.returncode == 0 or "nested_loaded" not in output:
            raise RuntimeError("Nested-carriage control did not fail specifically: " + output)
        print("CONTROL omit-nested: nested_loaded")
        receipt["results"].append({"case": "omit-nested", "passed": True,
            "reason": "nested_loaded"})
        print("Border 184 PASS: complete private inventory view")


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", nargs="?", type=pathlib.Path, default=ROOT)
    parser.add_argument("--receipt", type=pathlib.Path)
    args = parser.parse_args(argv)
    root = args.root.resolve()
    receipt = {"border": 184, "checks": [], "results": [], "commands": []}
    try:
        receipt["checks"] = static_contract(root)
        required = (PZ, ZB, JDK / "javac.exe", JDK / "java.exe")
        if not all(path.is_file() for path in required):
            receipt["status"] = "SKIPPED"
            print("Border 184 SKIPPED: installed game VM or JDK absent; "
                "static private-inventory contract checked")
        else:
            receipt["engine_sha256"] = sha(PZ)
            receipt["compiler_sha256"] = sha(JDK / "javac.exe")
            execute(root, receipt)
            receipt["status"] = "PASS"
    except Exception as error:
        receipt["status"] = "FAIL"
        receipt["error"] = str(error)
        print("FAULT private inventory: " + str(error), file=os.sys.stderr)
        code = 1
    else:
        code = 0
    if args.receipt:
        args.receipt.parent.mkdir(parents=True, exist_ok=True)
        args.receipt.write_text(json.dumps(receipt, indent=2) + "\n",
            encoding="utf-8")
    return code


if __name__ == "__main__":
    raise SystemExit(main())
