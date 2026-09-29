#!/usr/bin/env python3
"""Resolve a named study loadout into exact local mod roots and a receipt.

The catalogue records proven SAO implementations and external evidence sources.
A profile activates external content for observation; its labels do not define the
world ontology and activation never asserts source integration.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys


CATALOG_SCHEMA = "sao-study-mod-catalog/3"
PROFILE_SCHEMA = "sao-study-mod-profile/3"
DEFAULT_CATALOG = Path(__file__).with_name("world_lab") / "mod_catalog.json"
DEFAULT_WORKSHOP = Path(r"C:\Program Files (x86)\Steam\steamapps\workshop\content\108600")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def load(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def metadata(path):
    values = {}
    for line in Path(path).read_text(encoding="utf-8-sig", errors="replace").splitlines():
        if "=" in line and not line.startswith("#"):
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip().lstrip("\\")
    return values


def mod_metadata(root):
    """Return the newest B42 metadata, then common/root as a compatibility floor."""
    root = Path(root)
    candidates = sorted(root.glob("42*/mod.info"))
    if not candidates and (root / "common/mod.info").is_file():
        candidates = [root / "common/mod.info"]
    if not candidates and (root / "mod.info").is_file():
        candidates = [root / "mod.info"]
    require(candidates, "native mod metadata unavailable: " + root.name)
    return candidates[-1], metadata(candidates[-1])


def validate_catalog(value):
    require(isinstance(value, dict) and set(value) == {"schema", "sourceOwned", "external"},
            "invalid mod catalogue fields")
    require(value["schema"] == CATALOG_SCHEMA, "unsupported mod catalogue")
    owned_ids, external_ids = set(), set()
    for row in value["sourceOwned"]:
        require(isinstance(row, dict) and set(row) == {"id", "label", "owner", "evidence", "capabilities", "record"},
                "invalid source-owned capability row")
        require(re.fullmatch(r"[a-z][a-z0-9-]{1,63}", row["id"] or "") and row["id"] not in owned_ids,
                "invalid or duplicate source-owned capability")
        require(row["owner"] == "SurvivorAwareness" and isinstance(row["evidence"], str)
                and row["record"] == "proven-implementation"
                and isinstance(row["capabilities"], list) and row["capabilities"],
                "invalid source-owned capability ownership")
        owned_ids.add(row["id"])
    for row in value["external"]:
        required = {"id", "label", "workshopId", "family", "capabilities", "dependencies", "studyRole"}
        require(isinstance(row, dict) and set(row) == required, "invalid external mod row")
        require(isinstance(row["id"], str) and row["id"] and "," not in row["id"]
                and "/" not in row["id"] and "\\" not in row["id"] and row["id"] not in external_ids,
                "invalid or duplicate external mod id")
        require(re.fullmatch(r"[0-9]{6,12}", row["workshopId"] or ""), "invalid Workshop id")
        require(row["studyRole"] in ("integration-directive", "domain-evidence", "comparison-evidence", "support")
                and isinstance(row["dependencies"], list)
                and isinstance(row["capabilities"], list) and row["capabilities"],
                "invalid external study role")
        external_ids.add(row["id"])
    for row in value["external"]:
        require(all(dep in external_ids for dep in row["dependencies"]),
                "unknown external dependency for " + row["id"])
    return value


def validate_profile(value, catalogue):
    require(isinstance(value, dict)
            and set(value) == {"schema", "id", "label", "enabled", "disabled"},
            "invalid mod profile fields")
    require(value["schema"] == PROFILE_SCHEMA
            and re.fullmatch(r"[a-z][a-z0-9-]{1,47}", value["id"] or ""),
            "unsupported or invalid mod profile")
    known = {row["id"] for row in catalogue["external"]}
    enabled, disabled = value["enabled"], value["disabled"]
    require(isinstance(enabled, list) and isinstance(disabled, list)
            and len(enabled) == len(set(enabled)) and len(disabled) == len(set(disabled))
            and not set(enabled) & set(disabled), "duplicate or conflicting profile selection")
    require(set(enabled) | set(disabled) == known, "profile must classify every external catalogue entry")
    return value


def locate(workshop_root, row):
    mods = Path(workshop_root) / row["workshopId"] / "mods"
    require(mods.is_dir(), "Workshop item unavailable for " + row["id"])
    matches = []
    for root in sorted(p for p in mods.iterdir() if p.is_dir()):
        try:
            info, values = mod_metadata(root)
        except ValueError:
            continue
        if values.get("id") == row["id"]:
            matches.append((root, info, values))
    require(len(matches) == 1, "expected one installed mod root for " + row["id"])
    return matches[0]


def resolve(profile_path, catalogue_path=DEFAULT_CATALOG, workshop_root=DEFAULT_WORKSHOP,
            explicit=(), enable=(), disable=()):
    catalogue_path, profile_path = Path(catalogue_path), Path(profile_path)
    catalogue = validate_catalog(load(catalogue_path))
    profile = validate_profile(load(profile_path), catalogue)
    rows = {row["id"]: row for row in catalogue["external"]}
    enabled = set(profile["enabled"]) | set(enable)
    enabled -= set(disable)
    require(set(enable) <= rows.keys() and set(disable) <= rows.keys(), "unknown profile override")
    changed = True
    while changed:
        changed = False
        for mod_id in tuple(enabled):
            for dependency in rows[mod_id]["dependencies"]:
                require(dependency not in set(disable),
                        f"disabled dependency {dependency} is required by {mod_id}")
                if dependency not in enabled:
                    enabled.add(dependency); changed = True

    explicit_roots, explicit_ids = [], {}
    for source in explicit:
        root = Path(source).resolve()
        info, values = mod_metadata(root)
        mod_id = values.get("id")
        require(mod_id and mod_id not in explicit_ids, "invalid or duplicate explicit mod")
        explicit_roots.append(root); explicit_ids[mod_id] = str(info.relative_to(root))

    roots, activated = list(explicit_roots), []
    for mod_id in profile["enabled"] + [m for m in sorted(enabled) if m not in profile["enabled"]]:
        if mod_id not in enabled:
            continue
        require(mod_id not in explicit_ids, "profile mod duplicates explicit mod: " + mod_id)
        root, info, values = locate(workshop_root, rows[mod_id])
        roots.append(root.resolve())
        activated.append({"id": mod_id, "label": rows[mod_id]["label"],
                          "family": rows[mod_id]["family"], "studyRole": rows[mod_id]["studyRole"],
                          "workshopId": rows[mod_id]["workshopId"],
                          "metadata": str(info.relative_to(root)).replace("\\", "/"),
                          "versionMin": values.get("versionMin"), "versionMax": values.get("versionMax"),
                          "capabilities": rows[mod_id]["capabilities"]})
    disabled_rows = [{"id": mod_id, "label": rows[mod_id]["label"],
                      "family": rows[mod_id]["family"], "studyRole": rows[mod_id]["studyRole"],
                      "capabilities": rows[mod_id]["capabilities"]}
                     for mod_id in profile["disabled"] if mod_id not in enabled]
    receipt = {"schema": PROFILE_SCHEMA, "id": profile["id"], "label": profile["label"],
               "catalogSha256": digest(catalogue_path), "profileSha256": digest(profile_path),
               "explicit": [{"id": key, "metadata": value} for key, value in explicit_ids.items()],
               "activatedExternal": activated, "disabledExternal": disabled_rows,
               "sourceOwnedBaseline": catalogue["sourceOwned"]}
    return roots, receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("profile", type=Path)
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG)
    parser.add_argument("--workshop-root", type=Path, default=DEFAULT_WORKSHOP)
    parser.add_argument("--mod", action="append", default=[], type=Path)
    parser.add_argument("--enable-mod", action="append", default=[])
    parser.add_argument("--disable-mod", action="append", default=[])
    args = parser.parse_args()
    roots, receipt = resolve(args.profile, args.catalog, args.workshop_root,
                             args.mod, args.enable_mod, args.disable_mod)
    print(json.dumps({"roots": [str(root) for root in roots], "profile": receipt}, indent=2))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, KeyError, TypeError, json.JSONDecodeError) as error:
        print("world_lab_profiles: " + str(error), file=sys.stderr)
        raise SystemExit(1)
