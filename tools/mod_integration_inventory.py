#!/usr/bin/env python3
"""Record every installed Workshop mod as an integration candidate.

The receipt describes installed source and compatible metadata. It neither
activates mods nor grants a character knowledge, recipes, skills or permission.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re

from world_lab_profiles import DEFAULT_WORKSHOP, metadata


def version(value):
    if not isinstance(value, str) or not re.fullmatch(r"\d+(?:\.\d+){0,3}", value):
        raise ValueError("invalid numeric version: " + str(value))
    parts = tuple(map(int, value.split(".")))
    return parts + (0,) * (4 - len(parts))


def candidates(root, engine):
    """Keep every metadata variant; identify the newest compatible payload."""
    common = root / "common" / "mod.info"
    fallback = common if common.is_file() else root / "mod.info"
    rows = []
    for folder in sorted(p for p in root.iterdir() if p.is_dir()):
        if not re.fullmatch(r"42(?:\.\d+){0,3}", folder.name):
            continue
        info = folder / "mod.info"
        if not info.is_file():
            info = fallback
        if not info.is_file():
            continue
        values = metadata(info)
        minimum = version(values["versionMin"]) if values.get("versionMin") else (0,) * 4
        maximum = version(values["versionMax"]) if values.get("versionMax") else (999,) * 4
        rows.append((version(folder.name), folder, info, values,
                     version(folder.name) <= engine and minimum <= engine <= maximum))
    if not rows and fallback.is_file():
        values = metadata(fallback)
        minimum = version(values["versionMin"]) if values.get("versionMin") else (0,) * 4
        maximum = version(values["versionMax"]) if values.get("versionMax") else (999,) * 4
        rows.append(((0,) * 4, root, fallback, values, minimum <= engine <= maximum))
    return rows


def inventory(workshop_root, engine_version, catalogue=None):
    workshop_root = Path(workshop_root).resolve()
    if not workshop_root.is_dir():
        raise ValueError("Workshop content directory unavailable")
    engine = version(engine_version)
    known = {row["id"] for row in (catalogue or {}).get("external", [])}
    installed, errors = [], []
    for package in sorted(workshop_root.iterdir()):
        mods = package / "mods"
        if not package.name.isdigit() or not mods.is_dir():
            continue
        for root in sorted(p for p in mods.iterdir() if p.is_dir()):
            try:
                variants = candidates(root, engine)
                available = [row for row in variants if row[4]]
                selected = max(available, key=lambda row: row[0]) if available else None
                selected = selected or (max(variants, key=lambda row: row[0]) if variants else None)
                if selected is None:
                    raise ValueError("no metadata for supported payload or root")
                _, payload, info, values, compatible = selected
                if not values.get("id"):
                    raise ValueError("metadata has no mod id")
                installed.append({
                    "workshopId": package.name, "id": values["id"],
                    "name": values.get("name", values["id"]),
                    "packageRoot": root.relative_to(workshop_root).as_posix(),
                    "payload": payload.relative_to(root).as_posix(),
                    "metadata": info.relative_to(root).as_posix(),
                    "metadataSha256": hashlib.sha256(info.read_bytes()).hexdigest(),
                    "modVersion": values.get("modversion"),
                    "versionMin": values.get("versionMin"), "versionMax": values.get("versionMax"),
                    "requires": values.get("require", ""),
                    "compatibility": "metadata-compatible" if compatible else "metadata-incompatible",
                    "candidate": True, "catalogued": values["id"] in known,
                    "variants": [{"payload": path.relative_to(root).as_posix(),
                                  "metadata": source.relative_to(root).as_posix(),
                                  "compatible": supported}
                                 for _, path, source, _, supported in variants],
                })
            except (OSError, ValueError) as exc:
                errors.append({"packageRoot": root.relative_to(workshop_root).as_posix(),
                               "candidate": True, "reason": str(exc)})
    counts = Counter(row["id"] for row in installed)
    return {"schema": "sao-installed-integration-candidates/1",
            "engineVersion": engine_version, "authority": "installed-metadata-only",
            "activated": False, "sourceIntegrationEstablished": False,
            "installed": installed, "errors": errors,
            "duplicateIds": sorted(key for key, count in counts.items() if count > 1),
            "counts": {"roots": len(installed) + len(errors), "resolved": len(installed),
                       "unresolved": len(errors), "uncatalogued": sum(not row["catalogued"] for row in installed)}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workshop-root", type=Path, default=DEFAULT_WORKSHOP)
    parser.add_argument("--engine-version", required=True)
    parser.add_argument("--catalog", type=Path, default=Path(__file__).with_name("world_lab") / "mod_catalog.json")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    catalogue = json.loads(args.catalog.read_text(encoding="utf-8-sig"))
    result = inventory(args.workshop_root, args.engine_version, catalogue)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps({"output": str(args.output), "counts": result["counts"],
                      "duplicateIds": result["duplicateIds"]}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
