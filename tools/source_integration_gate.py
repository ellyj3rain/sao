#!/usr/bin/env python3
"""Guard source-integration lineage without equating an activated mod with ownership."""
from __future__ import annotations

import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
CONTRACTS = ROOT / "tools/source_integration_contracts.json"
CATALOGUE = ROOT / "tools/world_lab/mod_catalog.json"
REQUIRED_EVIDENCE = {"producer", "consumer", "verification"}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def evidence_exists(row):
    roles = {item.get("role") for item in row.get("evidence", [])}
    require(roles == REQUIRED_EVIDENCE,
            row["catalogRef"] + " must have producer, consumer and verification evidence")
    for item in row["evidence"]:
        require(set(item) == {"role", "path", "anchor"},
                row["catalogRef"] + " evidence fields differ")
        path = ROOT / item["path"]
        require(path.is_file(), row["catalogRef"] + " evidence path is absent: " + item["path"])
        require(item["anchor"] in path.read_text(encoding="utf-8-sig", errors="replace"),
                row["catalogRef"] + " evidence anchor is absent: " + item["anchor"])


def main():
    contracts, catalogue = read(CONTRACTS), read(CATALOGUE)
    require(contracts.get("schema") == "sao-source-integration-lineage/3",
            "source integration lineage schema differs")
    require(catalogue.get("schema") == "sao-study-mod-catalog/3",
            "study catalogue schema differs")

    authority = contracts.get("authority")
    require(isinstance(authority, dict)
            and authority.get("claudeSession") == "96f8350a-b694-418c-90bf-514ae17a52d4"
            and authority.get("claudeTranscriptSha256") == "8c7c8d53a3b3bad558799da06efd03eac0b33840bd76f97fed2f2d069eb1ffab",
            "Claude execution lineage is absent")
    for key in ("claimAudit", "priorArt"):
        require((ROOT / authority[key]).is_file(), "authority artifact is absent: " + authority[key])
    audit = (ROOT / authority["claimAudit"]).read_text(encoding="utf-8-sig")
    require(authority["claudeTranscriptSha256"] in audit
            and "Every other mod in the credits was already ported as SAO's own work." in audit,
            "completion-claim reconciliation lost its immutable evidence")

    owned_catalog = {row["id"]: row for row in catalogue["sourceOwned"]}
    baseline = contracts.get("ownedBaseline")
    require(isinstance(baseline, list), "owned baseline is unavailable")
    require({row.get("catalogRef") for row in baseline} == set(owned_catalog),
            "owned baseline and study catalogue differ")
    for row in baseline:
        require(set(row) == {"catalogRef", "status", "capabilities", "provenImplementation", "evidence", "knownGaps"},
                "owned baseline fields differ for " + str(row.get("catalogRef")))
        require(row["status"] == "proven-implementation"
                and row["capabilities"] == owned_catalog[row["catalogRef"]]["capabilities"],
                "proven implementation or capabilities differ for " + row["catalogRef"])
        require(isinstance(row["provenImplementation"], str) and row["provenImplementation"]
                and isinstance(row["knownGaps"], list),
                "implementation record must retain evidence and a known-gap list for " + row["catalogRef"])
        evidence_exists(row)

    external_catalog = {row["id"]: row for row in catalogue["external"]}
    principle = contracts.get("principle", "")
    require("canonical SAO world ontology defines relevance through causal participation" in principle
            and "cannot exclude" in principle,
            "the lineage record is trying to define an ontology boundary")
    directives = contracts.get("recoveredIntegrationDirectives")
    domain = contracts.get("domainEvidenceSources")
    comparison = contracts.get("comparisonToOwned")
    support = contracts.get("support")
    require(all(isinstance(rows, list) for rows in (directives, domain, comparison, support)),
            "external classifications are unavailable")

    directive_refs = []
    for row in directives:
        require(set(row) == {"id", "catalogRefs", "state", "authority", "knownCausalSurface", "rule"}
                and row["state"] == "open" and row["authority"]
                and isinstance(row["catalogRefs"], list) and row["catalogRefs"]
                and isinstance(row["knownCausalSurface"], list) and row["knownCausalSurface"],
                "recovered integration directive fields differ for " + str(row.get("id")))
        require(len(row["knownCausalSurface"]) == len(set(row["knownCausalSurface"])),
                "integration directive has duplicate known causal links: " + row["id"])
        require("non-exhaustive" in row["rule"] and "not a boundary" in row["rule"],
                "integration directive was turned into a scope boundary: " + row["id"])
        require(isinstance(row["rule"], str) and row["rule"],
                "integration directive must state that its causal list is non-exhaustive: " + row["id"])
        for ref in row["catalogRefs"]:
            require(ref in external_catalog
                    and external_catalog[ref]["studyRole"] == "integration-directive",
                    "recovered integration directive role differs for " + ref)
            directive_refs.append(ref)

    def validate_rows(rows, role, status):
        for row in rows:
            require(set(row) == {"catalogRef", "studyRole", "status", "rule"}
                    and row["studyRole"] == role and row["status"] == status
                    and isinstance(row["rule"], str) and row["rule"],
                    role + " classification differs for " + str(row.get("catalogRef")))
            require(external_catalog[row["catalogRef"]]["studyRole"] == role,
                    "catalogue role differs for " + row["catalogRef"])

    validate_rows(domain, "domain-evidence", "domain-evidence")
    validate_rows(comparison, "comparison-evidence", "comparison-evidence")
    support_refs = []
    for row in support:
        require(set(row) == {"catalogRef", "studyRole", "status"}
                and row["studyRole"] == "support" and row["status"] == "external-support-only",
                "support dependency was promoted to capability ownership")
        require(external_catalog[row["catalogRef"]]["studyRole"] == "support",
                "support role differs for " + row["catalogRef"])
        support_refs.append(row["catalogRef"])

    classified = directive_refs + [row["catalogRef"] for row in domain + comparison] + support_refs
    require(len(classified) == len(set(classified)) and set(classified) == set(external_catalog),
            "each external mod must retain exactly one integration standing")
    obligations = contracts.get("knownOpenObligations")
    require(isinstance(obligations, list) and obligations, "known open obligations are unavailable")
    ids = [row.get("id") for row in obligations]
    require(len(ids) == len(set(ids)), "duplicate open source-integration obligation")
    for row in obligations:
        require(set(row) == {"id", "state", "authority", "missing"}
                and row["state"] in ("open", "verification-open") and row["authority"]
                and isinstance(row["missing"], list) and row["missing"],
                "open obligation fields differ for " + str(row.get("id")))

    print(f"source integration lineage: {len(baseline)} implementation families retain evidence")
    print(f"source integration lineage: {len(directive_refs)} loaded entries have recovered integration directives; activation grants no completion")
    print(f"source integration lineage: {len(domain)} domain evidence sources, {len(comparison)} owned-system comparisons, {len(support)} support libraries")
    print("source integration lineage: known open obligations, non-exhaustive: " + ", ".join(ids))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, OSError, KeyError, TypeError, json.JSONDecodeError) as error:
        print("source integration lineage: " + str(error), file=sys.stderr)
        raise SystemExit(1)
