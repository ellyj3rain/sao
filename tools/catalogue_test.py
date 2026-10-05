"""Controls for C product chronology and the retained shared map; no repository writes.

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
    products = c.load_product_catalogue(ROOT)
    files = [ROOT / name for name in (c.MANIFEST, "BATCH_LOG.md", "tools/catalogue.py",
             "tools/version_replay.py", "tools/map_reference_test.py", "tools/receipts_test.py",
             "Batches/C_RECATALOG.json", "Batches/history/c-20261003-source/tools/version_replay.py")]
    files.append(Path(__file__).resolve())
    files.append(ROOT / c.PRODUCT_MANIFEST)
    files.extend(ROOT / unit["recordPath"] for unit in products["units"])
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
    product_faults = c.validate_product_catalogue(ROOT, products, manifest)
    check("production product partition and index", not product_faults, product_faults)
    if product_faults:
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
    check("product tiers replace contract credit once", units == v.UNITS +
          [(u["id"], u["tier"], u["rationale"]) for u in products["units"]] + v.POST_C_UNITS)
    check("all raw sources version-owned once", [edge["sourceId"] for u in products["units"]
          for edge in u["sourceContributions"]] == [f"C{i}" for i in range(1, 121)])
    check("CAO replay caps unchanged", v.fmt(v.bump(v.parse_version("1.12.0.0-pre-alpha"), "minor")) == "2.0.0.0-pre-alpha"
          and v.fmt(v.bump(v.parse_version("1.1.16.0-pre-alpha"), "kohai")) == "1.2.0.0-pre-alpha"
          and v.fmt(v.bump(v.parse_version("1.1.1.24-pre-alpha"), "patch")) == "1.1.2.0-pre-alpha")
    with tempfile.TemporaryDirectory(prefix="sao-version-product-control-") as directory:
        from unittest.mock import patch
        wrong = Path(directory) / "VERSION"
        wrong.write_bytes(b"0.0.0.0-pre-alpha\n")
        with patch.object(v, "VERSION_FILE", wrong):
            findings, _ = v.validate()
        check("stale version coordinate refuses product replay", any("VERSION states" in f for f in findings), findings)

    def product_mutation(name, change, expected):
        candidate = deepcopy(products)
        change(candidate)
        findings = c.validate_product_catalogue(ROOT, candidate, manifest)
        changed = json.dumps(candidate, sort_keys=True) != json.dumps(products, sort_keys=True)
        check(name, changed and any(expected in finding for finding in findings), findings)

    product_mutation("product missing unit", lambda d: d["units"].pop(), "product")
    product_mutation("product duplicate unit", lambda d: d["units"].append(deepcopy(d["units"][0])), "unique C1..Cn")
    product_mutation("product overlap", lambda d: d["units"][-1].update(first=1), "partition")
    product_mutation("product source order", lambda d: d["units"][0]["sourceContributions"][0].update(sourceId="C120"), "chronological range")
    product_mutation("product missing source", lambda d: d["units"][0]["sourceContributions"].pop(), "product")
    product_mutation("product raw source pin", lambda d: d["units"][0]["sourceContributions"][0].update(sha256="0" * 64), "source pin")
    product_mutation("product shared map pin", lambda d: d["sourceManifest"].update(sha256="0" * 64), "source manifest pin")
    product_mutation("product generation collision", lambda d: d.update(generation=manifest["generation"]), "collides")
    forged_findings = c.validate_product_catalogue(ROOT, deepcopy(manifest), manifest)
    check("shared contract map refuses product authority", any("product schema" in f for f in forged_findings)
          and any("partition" in f for f in forged_findings), forged_findings)
    product_mutation("product source generation collision", lambda d: d.update(generation=manifest["source_generation"]), "collides")
    product_mutation("product unknown tier", lambda d: d["units"][0].update(tier="invented"), "tier")
    product_mutation("product index name mismatch", lambda d: d["units"][0].update(name="Known bad name"), "index path/date/name")
    product_mutation("product record path escape", lambda d: d["units"][0].update(recordPath="../outside.md"), "outside Batches/Products")
    product_mutation("product reordered range", lambda d: d["units"][0].update(first=120, last=1), "partition")
    product_mutation("product pre-source date", lambda d: d["units"][0].update(date="1900-01-01"), "precedes")
    product_mutation("product malformed identifier", lambda d: d["units"][0].update(id={"foreign": "C1"}), "unique C1..Cn")
    product_mutation("product malformed source identifier", lambda d: d["units"][0]["sourceContributions"][0].update(sourceId={"foreign": "C1"}), "source pin")
    product_mutation("product boolean range", lambda d: d["units"][0].update(first=True), "partition")
    product_mutation("product forged source count", lambda d: d.update(sourceCount=119), "declared sourceCount")
    product_mutation("product forged product count", lambda d: d.update(productCount=999), "declared productCount")

    def mutation(name, change, expected):
        candidate = deepcopy(manifest)
        change(candidate)
        changed = candidate != manifest
        findings = c.validate_catalogue(ROOT, candidate)
        check(name, changed and any(expected in finding for finding in findings), findings)

    mutation("missing source", lambda d: d["sources"].pop("C1"), "source coverage")
    mutation("duplicate unit", lambda d: d["units"].append(deepcopy(d["units"][0])), "unique C1..Cn")
    mutation("missing owner", lambda d: d["units"][0].update(owners=["absent-catalogue-control.lua"]), "owner does not exist")
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
