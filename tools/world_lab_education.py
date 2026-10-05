"""Bind an optional source registry to a study before person genesis.

The native EducationRegistry owns semantic and per-person admission. This
loader checks the independent source pins and retains identical launch inputs
through a saved continuation.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

import world_lab as Lab

MAX_BYTES = 16 * 1024 * 1024
FIELDS = {"raw", "rawSha256", "definitionSha256", "sourceBankSha256", "sourceArchiveSha256"}


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        Lab.require(key not in result, "education registry has duplicate JSON fields")
        result[key] = value
    return result


def validate(value, definition_sha):
    Lab.require(isinstance(value, dict) and set(value) == FIELDS, "education source fields differ")
    for field in FIELDS - {"raw"}:
        Lab.require(isinstance(value[field], str) and Lab.re.fullmatch(r"[a-f0-9]{64}", value[field]),
                    "education source hash differs: " + field)
    raw = value["raw"]
    Lab.require(isinstance(raw, str) and 0 < len(raw.encode("utf-8")) <= MAX_BYTES,
                "education registry source exceeds bound")
    Lab.require(hashlib.sha256(raw.encode("utf-8")).hexdigest() == value["rawSha256"],
                "education registry raw source differs")
    registry = json.loads(raw, object_pairs_hook=unique_object)
    Lab.require(isinstance(registry, dict) and registry.get("schema") in (
        "speakeasy-person-education-runtime-registry/1", "speakeasy-person-education-runtime-registry/2",
        "speakeasy-person-education-runtime-registry/3"),
        "education registry schema differs")
    Lab.require(value["definitionSha256"] == definition_sha == registry.get("worldDefinitionSha256"),
                "education registry world differs")
    for field in ("sourceBankSha256", "sourceArchiveSha256"):
        Lab.require(registry.get(field) == value[field], "education registry independent pin differs: " + field)
    return value


def select(args, definition_sha, previous=None):
    path = getattr(args, "education_registry", None)
    bank = getattr(args, "education_bank_sha256", None)
    archive = getattr(args, "education_archive_sha256", None)
    if path is None:
        Lab.require(bank is None and archive is None, "education pins require a registry source")
        old = previous.get("educationSource") if previous is not None else None
        return validate(old, definition_sha) if old is not None else None
    path = Path(path)
    Lab.require(path.is_file() and not path.is_symlink() and 0 < path.stat().st_size <= MAX_BYTES,
                "education registry requires a bounded regular file")
    raw = path.read_bytes().decode("utf-8")
    value = validate(dict(raw=raw, rawSha256=hashlib.sha256(raw.encode("utf-8")).hexdigest(),
                          definitionSha256=definition_sha, sourceBankSha256=bank,
                          sourceArchiveSha256=archive), definition_sha)
    if previous is not None:
        Lab.require(previous.get("educationSource") == value,
                    "saved education registry source cannot change")
    return value


def add_arguments(parser):
    parser.add_argument("--education-registry", type=Path,
                        help="source-reconstructed personal registry staged before initial genesis")
    parser.add_argument("--education-bank-sha256", help="independent assessed/source bank identity")
    parser.add_argument("--education-archive-sha256", help="independent literal source archive identity")


def verify_binding(source, save_name, stdout):
    Lab.require(isinstance(save_name, str) and save_name and not any(c.isspace() for c in save_name),
                "education native save identity differs")
    marker = "[StudyWorld] education source bound=" + source["rawSha256"] + " save=" + save_name
    Lab.require(any(line.rstrip().endswith(marker) for line in stdout.splitlines()),
                "native education source binding was not observed")


def forward(command, args):
    for name in ("education_registry", "education_bank_sha256", "education_archive_sha256"):
        value = getattr(args, name, None)
        if value is not None:
            command.extend(("--" + name.replace("_", "-"), str(value)))
