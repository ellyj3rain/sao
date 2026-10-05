"""Shared readers for the current C catalogue and its retained source generations.

Catalogue membership describes delivered contracts. It never promotes a source's
implementation, verification or publication status, or assigns credit per edge.
"""
from __future__ import annotations

from datetime import date
import hashlib
import json
from pathlib import Path, PurePosixPath
import re

MANIFEST = "Batches/C_SHARED_BOUNDARIES.json"
PRODUCT_MANIFEST = "Batches/C_PRODUCT_CATALOGUE.json"
PRODUCT_SCHEMA = "sao.c-product-catalogue/1"
SCHEMA = "sao.c-shared-boundaries/1"
GENERATION = "20261003-shared-boundaries"
SOURCE_IDS = {f"C{i}" for i in range(1, 121)}
SHA256 = re.compile(r"[0-9a-f]{64}\Z")
INDEX_ROW = re.compile(
    r"^\|\s*\[([A-Z]\d+)\]\(([^)]+)\)\s*\|\s*(\d{4}-\d{2}-\d{2})"
    r"\s*\|\s*([^|]+?)\s*\|\s*(.*?)\s*\|\s*$")
INDEX_CANDIDATE = re.compile(r"^\|\s*[\[\x60\s]*[A-Z]\d+\b")
RECORD_NAME = re.compile(
    r"(?P<id>[A-Z]\d+)-(?:(?P<dashed>\d{4}-\d{2}-\d{2})-"
    r"|(?P<compact>\d{8})-\d{4}Z-\d{4}P(?:ST|DT)-).+\.md\Z")


class CatalogueError(ValueError):
    pass


def _object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise CatalogueError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def read_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"), object_pairs_hook=_object)
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise CatalogueError(f"cannot read {path}: {exc}") from exc


def load_catalogue(root: Path):
    return read_json(root / MANIFEST)


def load_product_catalogue(root: Path):
    """Product chronology/version authority; the shared map remains separate."""
    return read_json(root / PRODUCT_MANIFEST)


def validate_product_catalogue(root: Path, data, shared=None, check_index=True):
    """CAO-style adjacent capability partition of the exact retained C sources."""
    if not isinstance(data, dict):
        return ["product manifest is not an object"]
    faults = []
    if data.get("schema") != PRODUCT_SCHEMA:
        faults.append("product schema differs")
    generation = data.get("generation")
    if not isinstance(generation, str) or not re.fullmatch(r"[a-z0-9][a-z0-9-]{0,79}", generation):
        faults.append("product generation must be a distinct portable identity")
    if shared is None:
        try:
            shared = load_catalogue(root)
        except CatalogueError as exc:
            return faults + [str(exc)]
    shared_faults = validate_catalogue(root, shared)
    if shared_faults:
        return faults + shared_faults
    if generation in (shared["generation"], shared["source_generation"]):
        faults.append("product generation collides with preserved source or contract generation")
    if data.get("sourceGeneration") != shared["source_generation"]:
        faults.append("product source generation differs from retained source")
    pin = data.get("sourceManifest")
    if (not isinstance(pin, dict) or pin.get("path") != MANIFEST
            or pin.get("sha256") != hashlib.sha256((root / MANIFEST).read_bytes()).hexdigest()):
        faults.append("product source manifest pin differs")
    units = data.get("units")
    if not isinstance(units, list) or not units or any(not isinstance(u, dict) for u in units):
        return faults + ["product units must be a nonempty object list"]
    for field, expected in (("sourceCount", len(SOURCE_IDS)), ("productCount", len(units))):
        if field in data and (type(data[field]) is not int or data[field] != expected):
            faults.append(f"product declared {field} differs from actual coverage")
    if [u.get("id") for u in units] != [f"C{i}" for i in range(1, len(units) + 1)]:
        faults.append("product IDs must be unique C1..Cn in order")
    next_source, source_ids, records = 1, [], set()
    for unit in units:
        label = str(unit.get("id"))
        first, last = unit.get("first"), unit.get("last")
        valid_range = (type(first) is int and type(last) is int
                       and 1 <= first <= last <= len(SOURCE_IDS))
        if not valid_range or first != next_source:
            faults.append(f"{label} product partition has a gap, overlap or reordered range")
        if valid_range:
            next_source = last + 1
        if unit.get("tier") not in ("minor", "kohai", "patch", "hotfix"):
            faults.append(f"{label} product tier is unknown")
        for field in ("name", "date", "recordPath", "rationale"):
            if not _text(unit.get(field)):
                faults.append(f"{label} product has no {field}")
        if valid_range and isinstance(unit.get("date"), str):
            last_id = f"C{last}"
            end_date = record_date(shared["sources"][last_id]["original_path"], last_id)
            if unit["date"] < end_date:
                faults.append(f"{label} product date precedes its last retained source")
        path = local_path(root, unit.get("recordPath"))
        if not path or not path.is_file() or not str(unit.get("recordPath", "")).startswith("Batches/Products/"):
            faults.append(f"{label} product record is absent or outside Batches/Products")
        elif unit["recordPath"] in records:
            faults.append(f"{label} duplicates a product record")
        else:
            records.add(unit["recordPath"])
            try:
                if record_date(unit["recordPath"], label) != unit.get("date"):
                    faults.append(f"{label} product record date differs")
            except CatalogueError as exc:
                faults.append(str(exc))
        contributions = unit.get("sourceContributions")
        if not isinstance(contributions, list) or not contributions or any(not isinstance(c, dict) for c in contributions):
            faults.append(f"{label} product contributions must be a nonempty object list")
            continue
        ids = [c.get("sourceId") for c in contributions]
        if valid_range and ids != [f"C{i}" for i in range(first, last + 1)]:
            faults.append(f"{label} product contributions disagree with its chronological range")
        source_ids.extend(ids)
        for contribution in contributions:
            source_id = contribution.get("sourceId")
            source = shared["sources"].get(source_id) if isinstance(source_id, str) else None
            if (source is None or contribution.get("path") != source["archive_path"]
                    or contribution.get("sha256") != source["sha256"]):
                faults.append(f"{label} product contribution source pin or path differs")
    if source_ids != [f"C{i}" for i in range(1, len(SOURCE_IDS) + 1)] or next_source != len(SOURCE_IDS) + 1:
        faults.append("product partition must cover all retained C1..C120 exactly once in order")
    if check_index:
        try:
            rows = index_rows((root / "BATCH_LOG.md").read_text(encoding="utf-8-sig"))
            c_rows = {key: value for key, value in rows.items() if key.startswith("C")}
            if list(c_rows) != [u.get("id") for u in units]:
                faults.append("product index coverage or order differs")
            for unit in units:
                unit_id = unit.get("id")
                row = c_rows.get(unit_id) if isinstance(unit_id, str) else None
                if row and any(row[key] != unit.get(field) for key, field in
                               (("path", "recordPath"), ("name", "name"), ("date", "date"))):
                    faults.append(f"{unit.get('id')} product index path/date/name differs")
        except (CatalogueError, OSError) as exc:
            faults.append(str(exc))
    return faults


def _text(value):
    return isinstance(value, str) and bool(value.strip())


def _strings(value, minimum=0):
    return (isinstance(value, list) and len(value) >= minimum
            and all(_text(item) for item in value)
            and len(value) == len(set(value)))


def local_path(root: Path, value):
    """Require a portable repository path; never follow a manifest outside it."""
    if not _text(value) or "\\" in value or ":" in value:
        return None
    rel = PurePosixPath(value)
    if rel.is_absolute() or ".." in rel.parts:
        return None
    path = (root / value).resolve()
    return path if path.is_relative_to(root.resolve()) else None


def record_date(path: str, batch: str):
    match = RECORD_NAME.fullmatch(PurePosixPath(path).name)
    if not match or match["id"] != batch:
        raise CatalogueError(f"record filename does not identify {batch}: {path}")
    value = match["dashed"] or (match["compact"][:4] + "-"
            + match["compact"][4:6] + "-" + match["compact"][6:])
    try:
        return date.fromisoformat(value).isoformat()
    except ValueError as exc:
        raise CatalogueError(f"invalid record date: {path}") from exc


def index_rows(text: str):
    """Read every batch-looking row, refusing malformed and duplicate entries."""
    result = {}
    for number, line in enumerate(text.splitlines(), 1):
        if not INDEX_CANDIDATE.match(line):
            continue
        match = INDEX_ROW.fullmatch(line)
        if not match:
            raise CatalogueError(f"unmatched BATCH_LOG indexed row at line {number}")
        batch, path, day, name, threads = match.groups()
        if batch in result:
            raise CatalogueError(f"duplicate BATCH_LOG identifier: {batch}")
        if not path.startswith("Batches/") or ".." in PurePosixPath(path).parts:
            raise CatalogueError(f"invalid BATCH_LOG record path: {path}")
        if record_date(path, batch) != day:
            raise CatalogueError(f"BATCH_LOG dates {batch} {day}; filename carries {record_date(path, batch)}")
        result[batch] = {"path": path, "date": day, "name": name, "threads": threads}
    if not result:
        raise CatalogueError("BATCH_LOG parses to zero indexed rows")
    return result


def validate_catalogue(root: Path, data):
    faults = []
    if not isinstance(data, dict):
        return ["catalogue manifest is not an object"]
    if data.get("schema") != SCHEMA or data.get("generation") != GENERATION:
        faults.append("catalogue schema or generation differs from the current C migration")
    if not _text(data.get("source_generation")):
        faults.append("catalogue has no source generation")
    if not _text(data.get("archive_ref")) or not re.fullmatch(r"[0-9a-f]{40}", str(data.get("archive_commit", ""))):
        faults.append("catalogue has no exact archive ref/commit provenance")
    parent = data.get("parent_manifest")
    if not isinstance(parent, dict):
        faults.append("catalogue parent_manifest must carry path and sha256")
    else:
        path = local_path(root, parent.get("path"))
        expected = parent.get("sha256")
        if parent.get("path") != "Batches/C_RECATALOG.json" or not path or not path.is_file():
            faults.append("catalogue parent manifest is not the retained C_RECATALOG.json")
        elif not isinstance(expected, str) or not SHA256.fullmatch(expected) or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            faults.append("catalogue parent manifest hash differs from its retained generation")
    sources, units = data.get("sources"), data.get("units")
    if not isinstance(sources, dict):
        return faults + ["catalogue sources must be an object"]
    if set(sources) != SOURCE_IDS:
        faults.append("catalogue source coverage must be exactly C1 through C120")
    if not isinstance(units, list) or not units:
        return faults + ["catalogue units must be a nonempty list"]
    if any(not isinstance(unit, dict) for unit in units):
        return faults + ["catalogue unit must be an object"]
    unit_ids = [unit.get("id") for unit in units]
    if unit_ids != [f"C{i}" for i in range(1, len(units) + 1)]:
        faults.append("catalogue unit IDs must be unique C1..Cn in catalogue order")
    valid_ids = {item for item in unit_ids if isinstance(item, str)}
    memberships = {source: set() for source in sources}
    record_paths, ordering = set(), []
    for unit in units:
        label = str(unit.get("id"))
        for field in ("name", "rationale", "date", "path"):
            if not _text(unit.get(field)):
                faults.append(f"{label} has no {field}")
        for field in ("owners", "inputs", "outputs", "state", "delivered_scope", "sources", "version_sources"):
            if not _strings(unit.get(field), 1):
                faults.append(f"{label} {field} must be a nonempty unique string list")
        for field in ("depends_on", "remaining"):
            if not _strings(unit.get(field)):
                faults.append(f"{label} {field} must be a unique string list")
        if unit.get("tier") not in ("minor", "kohai", "patch"):
            faults.append(f"{label} tier does not classify a delivered C capability scope")
        path = local_path(root, unit.get("path"))
        if (not path or not path.is_file()
                or not str(unit.get("path", "")).startswith("Batches/Catalogue/")):
            faults.append(f"{label} current record is absent or outside the repository")
        else:
            if unit["path"] in record_paths:
                faults.append(f"{label} duplicates a current record path")
            record_paths.add(unit["path"])
            try:
                if record_date(unit["path"], label) != unit.get("date"):
                    faults.append(f"{label} record filename date differs from its catalogue date")
            except CatalogueError as exc:
                faults.append(str(exc))
        for owner in unit.get("owners", []) if _strings(unit.get("owners")) else []:
            path = local_path(root, owner)
            if not path or not path.exists():
                faults.append(f"{label} owner does not exist in the repository: {owner}")
        if _strings(unit.get("depends_on")):
            reasons = unit.get("dependency_reasons", {})
            if not isinstance(reasons, dict) or set(reasons) != set(unit["depends_on"]) or not all(_text(v) for v in reasons.values()):
                faults.append(f"{label} dependencies require exact nonempty interface reasons")
            for dependency in unit["depends_on"]:
                if dependency not in valid_ids or dependency == label:
                    faults.append(f"{label} invalid dependency: {dependency}")
        if _strings(unit.get("sources")):
            for source in unit["sources"]:
                if source not in sources:
                    faults.append(f"{label} names an unknown source: {source}")
                else:
                    memberships[source].add(label)
        if _strings(unit.get("version_sources"), 1) and _strings(unit.get("sources")):
            if not set(unit["version_sources"]).issubset(unit["sources"]):
                faults.append(f"{label} version_sources exceed its contributing sources")
            if set(unit["version_sources"]).issubset(SOURCE_IDS):
                ordering.append(max(int(source[1:]) for source in unit["version_sources"]))
    if ordering != sorted(ordering):
        faults.append("catalogue order does not follow last delivered source contribution")
    archive_paths = set()
    for source, item in sources.items():
        if not isinstance(item, dict):
            faults.append(f"{source} source must be an object")
            continue
        for field in ("implementation", "verification", "publication"):
            if not _text(item.get(field)):
                faults.append(f"{source} has no explicit {field} status")
        if not _strings(item.get("remaining")):
            faults.append(f"{source} remaining obligations must be a unique string list")
        expected = item.get("sha256")
        if not isinstance(expected, str) or not SHA256.fullmatch(expected):
            faults.append(f"{source} has no valid sha256")
        for field in ("original_path", "archive_path"):
            path = local_path(root, item.get(field))
            if not path or not path.is_file():
                faults.append(f"{source} {field} is absent or outside the repository")
            elif hashlib.sha256(path.read_bytes()).hexdigest() != expected:
                faults.append(f"{source} {field} source hash mismatch")
        if isinstance(item.get("original_path"), str):
            try:
                record_date(item["original_path"], source)
            except CatalogueError as exc:
                faults.append(str(exc))
        archive = item.get("archive_path")
        if isinstance(archive, str):
            if not archive.startswith("Batches/history/c-20261003-source/"):
                faults.append(f"{source} archive_path does not name the frozen source generation")
            if archive in archive_paths:
                faults.append(f"{source} duplicates another source's archive path")
            archive_paths.add(archive)
        primary = item.get("primary")
        if not isinstance(primary, str) or primary not in valid_ids or primary not in memberships[source]:
            faults.append(f"{source} primary home is not a contributing current unit")
        edges = item.get("contributions")
        if not isinstance(edges, list) or not edges:
            faults.append(f"{source} has no scoped contribution edges")
            continue
        edge_units, edge_keys = set(), set()
        for edge in edges:
            if not isinstance(edge, dict) or not _text(edge.get("unit")):
                faults.append(f"{source} contribution must name a unit")
                continue
            edge_units.add(edge["unit"])
            if edge["unit"] not in valid_ids or not _text(edge.get("scope")) or not _strings(edge.get("anchors"), 1):
                faults.append(f"{source} contribution lacks a valid unit, scope or source anchors")
            else:
                key = (edge["unit"], edge["scope"], tuple(edge["anchors"]))
                if key in edge_keys:
                    faults.append(f"{source} duplicates a contribution edge")
                edge_keys.add(key)
        if edge_units != memberships[source]:
            faults.append(f"{source} contribution edges disagree with unit source membership")
    for source in ("C118", "C119"):
        item = sources.get(source, {})
        if not isinstance(item, dict) or item.get("implementation") != "completed" or item.get("publication") != "merged":
            faults.append(f"{source} completed/merged component status was lost")
    item = sources.get("C120", {})
    if (not isinstance(item, dict) or item.get("implementation") != "implemented"
            or item.get("publication") != "local-unmerged"
            or not _text(item.get("verification"))
            or not re.match(r"verified(?:$|[ :;,.-])", item["verification"].lower())):
        faults.append("C120 implemented/verified/local-unmerged component status was lost")
    continuation = data.get("unnumbered_continuation")
    if continuation is not None:
        boundaries = continuation.get("boundaries") if isinstance(continuation, dict) else None
        if not _strings(boundaries, 1) or not set(boundaries).issubset(valid_ids):
            faults.append("unnumbered continuation must resolve to current contract IDs")
    relations = data.get("source_relations", [])
    if not isinstance(relations, list):
        faults.append("source relations must be a list")
    else:
        seen_relations = set()
        for edge in relations:
            if (not isinstance(edge, dict) or edge.get("from_id") not in SOURCE_IDS
                    or edge.get("to_id") not in SOURCE_IDS or edge.get("from_id") == edge.get("to_id")
                    or edge.get("relation") not in ("corrects", "supersedes", "contributes-to")
                    or not _text(edge.get("rationale")) or not _strings(edge.get("anchors"), 1)):
                faults.append("source relation requires distinct preserved sources, typed meaning and provenance")
                continue
            key = (edge['from_id'], edge['to_id'], edge['relation'])
            if key in seen_relations:
                faults.append("duplicate source relation")
            seen_relations.add(key)
    return faults


def historical_generations(root: Path, data):
    """Return exact labels by source generation, without changing receipt prose."""
    generations = {data["source_generation"]: set(data["sources"])}
    parent = read_json(root / data["parent_manifest"]["path"])
    if (not isinstance(parent, dict) or parent.get("schema") != "sao.c-recatalog/1"
            or not isinstance(parent.get("units"), list)
            or any(not isinstance(unit, dict) or not isinstance(unit.get("sources"), list)
                   for unit in parent["units"]) or not _text(parent.get("date"))):
        raise CatalogueError("prior C catalogue has no readable source generation")
    labels = {item["former"] for unit in parent["units"] for item in unit.get("sources", [])
              if isinstance(item, dict) and isinstance(item.get("former"), str)}
    if labels != {f"C{i}" for i in range(1, 128)}:
        raise CatalogueError("prior C catalogue does not preserve its 127 source labels")
    generations["c-before-" + parent["date"]] = labels
    return generations
