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


PUBLICATION_AVAILABILITY = "Batches/C_PUBLICATION_AVAILABILITY.json"
PUBLICATION_SOURCE_AUDIT = "Batches/Transitions/C-20261003-publication-source-audit.json"
LOCAL_RECOVERY_OWNERS = {
    "mod/42.20/media/lua/client/SAO_RecoveryPose.lua": "8c812c15598a9429d65552dc798a13c524b6edfe66f1250594c624cd7b63c481",
    "java/src/com/sao/engine/SAORecoveryPose.java": "48389bbfe8a6b936157c8fec8a9f6c5fa55eb179d8f347a34555352777a8f8d0",
}
COMPRESSION_ARCHIVE = "1b01e546f782656e76c9faffc4535a942adfa40c"
LOCAL_RECOVERY_GIT_BLOBS = {
    "mod/42.20/media/lua/client/SAO_RecoveryPose.lua": "ea658ae44f987e950defb5b9127118ac58ae5e25",
    "java/src/com/sao/engine/SAORecoveryPose.java": "4218b5605f72b4178da70377de79aacbccae7791",
}


def publication_availability(root: Path, data):
    """Authenticate two preserved local owners without admitting arbitrary absent files."""
    descriptor = data.get("publicationAvailability")
    if descriptor is None:
        return set(), []
    faults = []
    allowed = set()
    try:
        path = local_path(root, descriptor.get("path")) if isinstance(descriptor, dict) else None
        if (not path or descriptor.get("path") != PUBLICATION_AVAILABILITY
                or set(descriptor) != {"path", "sha256"}
                or not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != descriptor.get("sha256")):
            raise CatalogueError("publication availability binding differs")
        availability = read_json(path)
        if (not isinstance(availability, dict)
                or set(availability) != {"schema", "publicBase", "generation", "sourceAudit", "owners"}
                or availability.get("schema") != "sao.catalogue-publication-availability/1"
                or availability.get("generation") != GENERATION
                or availability.get("publicBase") != "6bfcd46e72146b941db6c26086201bc79e883a40"):
            raise CatalogueError("publication availability identity differs")
        audit_ref = availability.get("sourceAudit")
        audit_path = local_path(root, audit_ref.get("path")) if isinstance(audit_ref, dict) else None
        if (not audit_path or audit_ref.get("path") != PUBLICATION_SOURCE_AUDIT
                or set(audit_ref) != {"path", "sha256"} or not audit_path.is_file()
                or hashlib.sha256(audit_path.read_bytes()).hexdigest() != audit_ref.get("sha256")):
            raise CatalogueError("publication source audit binding differs")
        audit = read_json(audit_path)
        rows = availability.get("owners")
        if (not isinstance(audit, dict)
                or set(audit) != {"schema", "archiveCommit", "archiveRef", "sourceGeneration", "owners", "boundary"}
                or not _text(audit.get("boundary"))
                or audit.get("schema") != "sao.catalogue-publication-source-audit/1"
                or audit.get("archiveCommit") != COMPRESSION_ARCHIVE
                or data.get("archive_commit") != COMPRESSION_ARCHIVE
                or audit.get("archiveRef") != data.get("archive_ref")
                or audit.get("sourceGeneration") != data.get("source_generation")
                or not isinstance(rows, list) or len(rows) != 2
                or rows != audit.get("owners")):
            raise CatalogueError("publication source audit provenance differs")
        source = data.get("sources", {}).get("C120")
        if (not isinstance(source, dict) or source.get("publication") != "local-unmerged"
                or source.get("sha256") != "1705c6a801bcf882a8f2a47242c1ff4ce1b4e0c00772e2a4a505f95f8aef8c34"):
            raise CatalogueError("publication local source status differs")
        for row in rows:
            if (not isinstance(row, dict)
                    or set(row) != {"path", "contract", "availability", "archiveCommit", "gitBlob", "sha256", "sourceId", "sourceRecord"}
                    or row.get("path") not in LOCAL_RECOVERY_OWNERS
                    or row.get("contract") != "C34" or row.get("availability") != "local-unpublished"
                    or row.get("archiveCommit") != COMPRESSION_ARCHIVE or row.get("sourceId") != "C120"
                    or row.get("sha256") != LOCAL_RECOVERY_OWNERS.get(row.get("path"))
                    or row.get("gitBlob") != LOCAL_RECOVERY_GIT_BLOBS.get(row.get("path"))
                    or row.get("sourceRecord") != {"path": source.get("archive_path"), "sha256": source.get("sha256")}):
                raise CatalogueError("publication owner provenance differs")
            record = local_path(root, source["archive_path"])
            if not record or not record.is_file() or hashlib.sha256(record.read_bytes()).hexdigest() != source["sha256"]:
                raise CatalogueError("publication archived source record differs")
            owner = local_path(root, row["path"])
            if not owner or owner.exists() or ("C34", row["path"]) in allowed:
                raise CatalogueError("publication owner availability differs")
            allowed.add(("C34", row["path"]))
        if {path for _unit, path in allowed} != set(LOCAL_RECOVERY_OWNERS):
            raise CatalogueError("publication owner inventory differs")
    except (CatalogueError, OSError, TypeError, AttributeError) as exc:
        faults.append(str(exc))
        allowed.clear()
    return allowed, faults


def validate_catalogue(root: Path, data):
    faults = []
    if not isinstance(data, dict):
        return ["catalogue manifest is not an object"]
    unpublished_owners, availability_faults = publication_availability(root, data)
    faults.extend(availability_faults)
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
            if (not path or not path.exists()) and (label, owner) not in unpublished_owners:
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
