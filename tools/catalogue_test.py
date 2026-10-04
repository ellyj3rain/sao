"""Controls for the shared C catalogue migration; no repository writes.

Run only after the manifest and current catalogue have been rendered. Mutations
operate on detached manifest objects and temporary index/JSON inputs. The actual
version/map/receipt checks retain their existing entry points.
"""
from __future__ import annotations

import ast
import argparse
from copy import deepcopy
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT / "tools"))
import catalogue as c
import version_replay as v


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--receipt', type=Path, help='Write the complete source-pinned control receipt.')
    args = parser.parse_args()
    manifest = c.load_catalogue(ROOT)
    files = [ROOT / name for name in (c.MANIFEST, "BATCH_LOG.md", "tools/catalogue.py",
             "tools/version_replay.py", "tools/map_reference_test.py", "tools/receipts_test.py",
             "Batches/C_RECATALOG.json", "Batches/history/c-20261003-source/tools/version_replay.py")]
    files.append(Path(__file__).resolve())
    if manifest.get("publicationAvailability") is not None:
        files.extend(ROOT / name for name in (c.PUBLICATION_AVAILABILITY, c.PUBLICATION_SOURCE_AUDIT))
    for source in manifest["sources"].values():
        files.extend(ROOT / source[field] for field in ("archive_path", "original_path"))

    def hashes():
        return {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
                for path in dict.fromkeys(files)}

    before = hashes()
    results = []

    def check(name, passed, detail=None):
        results.append({"name": name, "passed": bool(passed), "detail": detail})

    faults = c.validate_catalogue(ROOT, manifest)
    check("production catalogue", not faults, faults)
    if faults:
        print(json.dumps({"status": "FAIL", "checks": results}, indent=2))
        return 1
    _data, units, rows = v.catalogue_inputs()
    check("production replay and index coverage", [unit[0] for unit in units] == list(rows))
    previous = ast.parse(
        (ROOT / "Batches/history/c-20261003-source/tools/version_replay.py").read_text(encoding="utf-8-sig"))
    old_units = next(ast.literal_eval(node.value) for node in previous.body
                     if isinstance(node, ast.Assign)
                     and any(isinstance(target, ast.Name) and target.id == "UNITS" for target in node.targets))
    check("A/B tier rows unchanged", v.UNITS == [row for row in old_units if row[0][0] in "AB"])
    generations = c.historical_generations(ROOT, manifest)
    check("source generation coverage", set(generations[manifest["source_generation"]]) == c.SOURCE_IDS
          and len(set().union(*generations.values())) == 127)
    check("maturity remains pre-alpha", all(row[3].endswith("-pre-alpha") for row in v.replay(units)))

    def mutation(name, change, expected):
        candidate = deepcopy(manifest)
        change(candidate)
        changed = candidate != manifest
        findings = c.validate_catalogue(ROOT, candidate)
        check(name, changed and any(expected in finding for finding in findings), findings)

    mutation("missing source", lambda d: d["sources"].pop("C1"), "source coverage")
    mutation("duplicate unit", lambda d: d["units"].append(deepcopy(d["units"][0])), "unique C1..Cn")
    mutation("missing owner", lambda d: d["units"][0].update(owners=["absent-catalogue-control.lua"]), "owner does not exist")
    if manifest.get("publicationAvailability") is not None:
        mutation("missing availability binding", lambda d: d.pop("publicationAvailability"), "owner does not exist")
        mutation("wrong availability hash", lambda d: d["publicationAvailability"].update(sha256="0"*64), "availability binding")
        mutation("other contract cannot use local recovery exception", lambda d: d["units"][0].update(owners=list(c.LOCAL_RECOVERY_OWNERS)), "owner does not exist")
        with tempfile.TemporaryDirectory(prefix="sao-publication-control-") as directory:
            detached = Path(directory)
            reference = manifest["sources"]["C120"]["archive_path"]
            record = detached / reference
            record.parent.mkdir(parents=True)
            record.write_bytes((ROOT / reference).read_bytes())
            original = c.read_json(ROOT / c.PUBLICATION_AVAILABILITY)
            original_audit = c.read_json(ROOT / c.PUBLICATION_SOURCE_AUDIT)

            def availability_case(name, change, expected):
                document, audit, candidate = deepcopy(original), deepcopy(original_audit), deepcopy(manifest)
                change(document, audit, candidate)
                audit["owners"] = deepcopy(document["owners"])
                audit_path = detached / c.PUBLICATION_SOURCE_AUDIT
                audit_path.parent.mkdir(parents=True, exist_ok=True)
                audit_path.write_text(json.dumps(audit)+'\n', encoding='utf-8')
                document["sourceAudit"]["sha256"] = hashlib.sha256(audit_path.read_bytes()).hexdigest()
                path = detached / c.PUBLICATION_AVAILABILITY
                path.write_text(json.dumps(document)+'\n', encoding='utf-8')
                candidate["publicationAvailability"]["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
                allowed, findings = c.publication_availability(detached, candidate)
                check(name, not allowed and any(expected in item for item in findings), findings)

            availability_case("resealed wrong owner blob hash", lambda d, a, m: d["owners"][0].update(sha256="0"*64), "owner provenance")
            availability_case("resealed wrong Git object", lambda d, a, m: d["owners"][0].update(gitBlob="0"*40), "owner provenance")
            availability_case("resealed foreign owner", lambda d, a, m: d["owners"][0].update(path="absent-foreign-owner.lua"), "owner provenance")
            availability_case("resealed public owner status", lambda d, a, m: d["owners"][0].update(availability="published"), "owner provenance")
            availability_case("resealed wrong owner contract", lambda d, a, m: d["owners"][0].update(contract="C32"), "owner provenance")
            availability_case("resealed wrong source record", lambda d, a, m: d["owners"][0]["sourceRecord"].update(sha256="0"*64), "owner provenance")
            availability_case("resealed duplicate owner", lambda d, a, m: d["owners"].__setitem__(1, deepcopy(d["owners"][0])), "owner availability")
            availability_case("resealed unknown audit field", lambda d, a, m: a.update(sourceRedistributionGranted=True), "audit provenance")
            availability_case("resealed wrong public base", lambda d, a, m: d.update(publicBase="0"*40), "availability identity")
            availability_case("resealed false local publication", lambda d, a, m: m["sources"]["C120"].update(publication="merged"), "local source status")
            availability_case("resealed wrong source archive", lambda d, a, m: a.update(archiveCommit="0"*40), "audit provenance")
            availability_case("resealed extra owner", lambda d, a, m: d["owners"].append(deepcopy(d["owners"][0])), "audit provenance")
    mutation("missing delivered scope", lambda d: d["units"][0].update(delivered_scope=[]), "delivered_scope")
    mutation("invalid dependency", lambda d: d["units"][0].update(depends_on=["C999"]), "invalid dependency")
    mutation("missing interface reason", lambda d: next(u for u in d["units"] if u["depends_on"]).update(dependency_reasons={}), "interface reasons")
    mutation("unknown continuation boundary", lambda d: d["unnumbered_continuation"].update(boundaries=["C999"]), "current contract IDs")
    mutation("unknown correction source", lambda d: d['source_relations'][0].update(to_id='C999'), "distinct preserved sources")
    mutation("duplicate correction", lambda d: d['source_relations'].append(deepcopy(d['source_relations'][0])), "duplicate source relation")
    mutation("invalid version source", lambda d: d["units"][0].update(version_sources=["C999"]), "version_sources exceed")
    mutation("missing primary home", lambda d: d["sources"]["C1"].update(primary="C999"), "primary home")
    mutation("missing contribution", lambda d: d["sources"]["C1"].update(contributions=[]), "contribution edges")
    mutation("unmapped contribution", lambda d: d["sources"]["C1"]["contributions"][0].update(unit="C999"), "disagree with unit source membership")
    mutation("missing anchor", lambda d: d["sources"]["C1"]["contributions"][0].update(anchors=[]), "source anchors")
    mutation("changed source hash", lambda d: d["sources"]["C1"].update(sha256="0" * 64), "source hash mismatch")
    mutation("changed parent hash", lambda d: d["parent_manifest"].update(sha256="0" * 64), "parent manifest hash")
    mutation("escaping archive path", lambda d: d["sources"]["C1"].update(archive_path="../outside.md"), "outside the repository")
    mutation("C118 completion loss", lambda d: d["sources"]["C118"].update(implementation="open"), "C118 completed/merged")
    mutation("C119 publication loss", lambda d: d["sources"]["C119"].update(publication="local-unmerged"), "C119 completed/merged")
    mutation("C120 false closure", lambda d: d["sources"]["C120"].update(implementation="completed"), "C120 implemented/verified")
    mutation("C120 false publication", lambda d: d["sources"]["C120"].update(publication="merged"), "C120 implemented/verified")
    mutation("C120 verification loss", lambda d: d["sources"]["C120"].update(verification="unverified"), "C120 implemented/verified")
    mutation("reordered delivered contributions", lambda d: d["units"].reverse(), "last delivered source contribution")

    dashed = "| [C1](Batches/Catalogue/C1-2026-10-03-scope.md) | 2026-10-03 | Scope | T-001 |"
    compact = "| [C1](Batches/Catalogue/C1-20261003-2230Z-1530PST-scope.md) | 2026-10-03 | Scope | T-001 |"
    check("preserved filename formats", len(c.index_rows(dashed)) == 1 and len(c.index_rows(compact)) == 1 and len(c.index_rows(compact.replace("PST", "PDT"))) == 1)
    for name, text, expected in (
        ("duplicate indexed identifier", dashed + "\n" + dashed, "duplicate BATCH_LOG"),
        ("dashed date mismatch", dashed.replace("| 2026-10-03 |", "| 2026-10-02 |"), "filename carries"),
        ("compact date mismatch", compact.replace("| 2026-10-03 |", "| 2026-10-02 |"), "filename carries"),
        ("malformed indexed row", "| [C1] missing-record |", "unmatched BATCH_LOG"),
        ("record identity mismatch", dashed.replace("/C1-", "/C2-"), "does not identify"),
        ("empty index", "# Batch log\n", "zero indexed rows"),
    ):
        try:
            c.index_rows(text)
            check(name, False, "invalid row was accepted")
        except c.CatalogueError as exc:
            check(name, expected in str(exc), str(exc))
    with tempfile.TemporaryDirectory(prefix="sao-catalogue-control-") as directory:
        path = Path(directory) / "duplicate.json"
        path.write_text('{"sources": {}, "sources": {}}', encoding="utf-8")
        try:
            c.read_json(path)
            check("duplicate JSON key", False)
        except c.CatalogueError as exc:
            check("duplicate JSON key", "duplicate JSON key" in str(exc), str(exc))
    after = hashes()
    check("relevant inputs unchanged", before == after)
    result = {"schema": "sao.catalogue-validator-controls/1",
              "timestamp": datetime.now(timezone.utc).isoformat(),
              "status": "PASS" if all(item["passed"] for item in results) else "FAIL",
              "checks": results, "inputsBefore": before, "inputsAfter": after,
              "boundary": "Detached catalogue and index controls; no simulation, rendering or whole-contract completion claim."}
    if args.receipt:
        args.receipt.write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
    print(f"Catalogue controls: {result['status']} ({len(results)} checks and controls)")
    for item in results:
        if not item['passed']:
            print(f"FAULT: {item['name']}: {item['detail']}")
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
