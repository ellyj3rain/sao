#!/usr/bin/env python3
"""Verify complete candidate discovery, numeric payloads and duplicate identities."""
from __future__ import annotations

import importlib.util
from pathlib import Path
import tempfile

SOURCE = Path(__file__).with_name("mod_integration_inventory.py")


def load(path):
    spec = importlib.util.spec_from_file_location("candidate_inventory", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8")


def exercise(module, root):
    result = module.inventory(root, "42.21", {"external": [{"id": "Known"}]})
    by_root = {row["packageRoot"]: row for row in result["installed"]}
    numeric = by_root["1/mods/Numeric"]
    checks = {
        "numeric_latest_compatible_payload": numeric["payload"] == "42.20"
            and len(numeric["variants"]) == 3,
        "unknown_installed_roots_remain_candidates": result["counts"]["roots"] == 5
            and result["counts"]["resolved"] == 4 and result["counts"]["uncatalogued"] == 3
            and all(row["candidate"] for row in result["installed"]),
        "common_metadata_can_own_version_payload": by_root["2/mods/Common"]["payload"] == "42.20"
            and by_root["2/mods/Common"]["metadata"] == "common/mod.info",
        "incompatible_source_is_retained_explicitly": by_root["3/mods/Legacy"]["compatibility"]
            == "metadata-incompatible",
        "duplicate_id_does_not_erase_distinct_source": result["duplicateIds"] == ["Duplicate"]
            and len([row for row in result["installed"] if row["id"] == "Duplicate"]) == 2,
        "unresolved_root_is_retained_as_unchecked": result["counts"]["unresolved"] == 1
            and result["errors"][0]["packageRoot"] == "5/mods/Unresolved"
            and result["errors"][0]["candidate"] is True,
        "inventory_does_not_activate_or_establish_integration": result["activated"] is False
            and result["sourceIntegrationEstablished"] is False,
    }
    return checks


def main():
    print("Border 231: Installed integration candidate discovery")
    with tempfile.TemporaryDirectory(prefix="sao-integration-inventory-") as directory:
        work = Path(directory)
        root = work / "workshop"
        for payload in ("42.9", "42.20", "42.30"):
            write(root / "1/mods/Numeric" / payload / "mod.info", "id=Known\nname=Numeric\n")
        write(root / "2/mods/Common/common/mod.info", "id=Duplicate\nversionMin=42.20\n")
        (root / "2/mods/Common/42.20/media").mkdir(parents=True)
        write(root / "3/mods/Legacy/mod.info", "id=Legacy\nversionMax=42.19\n")
        write(root / "4/mods/Other/mod.info", "id=Duplicate\n")
        (root / "5/mods/Unresolved").mkdir(parents=True)
        checks = exercise(load(SOURCE), root)
        for name, passed in checks.items():
            if not passed:
                raise AssertionError(name)
        source = SOURCE.read_text(encoding="utf-8")
        controls = [
            ("lexical-version-selection", "max(available, key=lambda row: row[0])",
                "max(available, key=lambda row: row[1].name)", "numeric_latest_compatible_payload"),
            ("named-only-whitelist", 'if not values.get("id"):',
                'if values.get("id") not in known: continue\n                if not values.get("id"):',
                "unknown_installed_roots_remain_candidates"),
        ]
        for name, before, after, expected in controls:
            if source.count(before) != 1:
                raise AssertionError(name + ": mutation anchor changed")
            path = work / (name + ".py")
            write(path, source.replace(before, after, 1))
            try:
                mutated = exercise(load(path), root)
            except KeyError:
                if expected != "unknown_installed_roots_remain_candidates":
                    raise
                # Missing rows are the whitelist defect; use the actual producer
                # output to name it, instead of accepting an unrelated exception.
                mutant = load(path).inventory(root, "42.21", {"external": [{"id": "Known"}]})
                mutated = {expected: mutant["counts"]["resolved"] == 4}
            if mutated[expected] is not False:
                raise AssertionError(name + ": restored defect did not fail " + expected)
            print("CONTROL", name, "refused", expected)
        print("PASS integration inventory:", len(checks), "cases,", len(controls), "executing controls")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
