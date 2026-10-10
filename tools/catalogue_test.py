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
             "tools/session_state_test.py", "tools/doc_currency_test.py",
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
    check("production replay and index coverage", [unit[0] for unit in units] ==
          [label for label in rows if label not in v.POST_C_AGGREGATIONS])
    previous = ast.parse(
        (ROOT / "Batches/history/c-20261003-source/tools/version_replay.py").read_text(encoding="utf-8-sig"))
    old_units = next(ast.literal_eval(node.value) for node in previous.body
                     if isinstance(node, ast.Assign)
                     and any(isinstance(target, ast.Name) and target.id == "UNITS" for target in node.targets))
    reconciliation = json.loads((ROOT / "Batches/VERSION_SCOPE_RECONCILIATION.json").read_bytes())
    assessed_ab = [row for row in reconciliation["rows"] if row["batch"].startswith(("A", "B"))]
    prior_ab = [row for row in old_units if row[0][0] in "AB"]
    check("A/B historical labels and prior tiers preserved",
          [(row["batch"], row["previousTier"]) for row in assessed_ab] == [(row[0], row[1]) for row in prior_ab])
    check("A/B current credit follows complete feature-scope assessment",
          v.UNITS == [(row["batch"], row["tier"], row["reason"]) for row in assessed_ab])
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
    child = compact.replace("C1", "D3.1")
    nested = child.replace("D3.1", "D3.1.2")
    check("complete dotted record identities", list(c.index_rows(child + "\n" + nested)) == ["D3.1", "D3.1.2"]
          and c.batch_parent("D3.1.2") == "D3.1" and c.batch_parent("D3") is None)
    active_text = "Active: [D3 — Parent](Batches/D3-20261003-2230Z-1530PST-parent.md)"
    check("active parent is separate from delivered child", c.active_batch(child + "\n" + active_text)[0] == "D3"
          and list(c.index_rows(child + "\n" + active_text)) == ["D3.1"])
    with patch.object(sys, "argv", [sys.argv[0]]):
        import session_state_test as state
        import receipts_test as receipts
        import doc_currency_test as docs
    check("state tip reads complete child identity", state.ROW.findall(child) == ["D3.1"]
          and state.AS_OF.search("**As of** [D3.1], parent D3 continues").group(1) == "D3.1")
    check("receipt citations retain complete child identities",
          receipts.BATCH_CITATION.findall("[D3] [D3.1] [D3.1.2]") == ["D3", "D3.1", "D3.1.2"])
    check("dotted authorship remains provenance", docs.PROVENANCE.sub("", "authored at `[D3.1]`") == "")
    # Detached chronology owns its predecessor credit. A real child closing in
    # POST_C_UNITS must not pre-credit or duplicate this fixture's child.
    fixture_predecessors = [("D1", "minor", "Detached predecessor capability."),
                            ("D2", "kohai", "Detached predecessor extension.")]
    fixture_units = fixture_predecessors + [("D3.1", "patch", "Detached child-credit control.")]
    fixture_rows = dict.fromkeys(["D1", "D2", "D3.1"])
    check("child closure preserves active parent", not v.post_c_faults(fixture_rows, "D3", fixture_units, {}, "D3"))
    aggregate_rows = dict.fromkeys(["D1", "D2", "D3.1", "D3"])
    aggregate = {"D3": ("D3.1",)}
    with patch.object(v, "POST_C_UNITS", fixture_predecessors):
        predecessor_trace = v.replay()
    with patch.object(v, "POST_C_UNITS", fixture_units):
        credited_trace = v.replay()
        with patch.object(v, "POST_C_AGGREGATIONS", aggregate):
            aggregated_trace = v.replay()
    check("closed parent aggregation owns no additional tier",
          not v.post_c_faults(aggregate_rows, "D4", fixture_units, aggregate, "D4")
          and aggregated_trace == credited_trace and len(credited_trace) == len(predecessor_trace) + 1)
    later_units = fixture_units + [("D3.2", "patch", "Detached later improvement control.")]
    check("later child preserves closed aggregation history",
          not v.post_c_faults(dict.fromkeys(["D1", "D2", "D3.1", "D3", "D3.2"]),
                              "D4", later_units, aggregate, "D4"))
    check("closed parent can declare next scope before it opens",
          not v.post_c_faults(aggregate_rows, None, fixture_units, aggregate, "D4"))
    check("OPEN parent building subset cannot receive minor completion credit",
          any("building the OPEN D3" in fault for fault in v.post_c_faults(
              fixture_rows, "D3", fixture_predecessors + [("D3.1", "minor", "Unfinished feature subset.")], {}, "D3")))
    check("deeper OPEN parent subset cannot bypass completed-feature credit guard",
          any("building the OPEN D3" in fault for fault in v.post_c_faults(
              dict.fromkeys(["D1", "D2", "D3.1.1"]), "D3",
              fixture_predecessors + [("D3.1.1", "minor", "Nested unfinished feature subset.")], {}, "D3")))
    for name, indexed, credit, aggregations, active, expected in (
        ("duplicate child credit refuses", fixture_rows, fixture_units + [fixture_units[-1]], {}, "D3", "duplicate"),
        ("unclassified child closure refuses", fixture_rows, fixture_predecessors, {}, "D3", "coverage"),
        ("reordered child credit refuses", fixture_rows, list(reversed(fixture_units)), {}, "D3", "chronological"),
        ("parent double credit refuses", aggregate_rows, fixture_units + [("D3", "minor", "Invalid repeated child credit.")], aggregate, "D4", "cannot also receive"),
        ("missing aggregation owner refuses", aggregate_rows, fixture_units, {"D3": ("D3.2",)}, "D4", "exact credited descendants"),
        ("duplicate aggregation owner refuses", aggregate_rows, fixture_units, {"D3": ("D3.1", "D3.1")}, "D4", "unique descendant"),
        ("parent before children refuses", dict.fromkeys(["D1", "D2", "D3", "D3.1"]), fixture_units, aggregate, "D4", "follow its credited descendants"),
        ("consumed active parent refuses", aggregate_rows, fixture_units, aggregate, "D3", "unconsumed"),
        ("malformed child credit refuses", fixture_rows, fixture_units[:-1] + [("D3..1", "patch", "Malformed control.")], {}, "D3", "malformed"),
        ("unknown child tier refuses", fixture_rows, fixture_units[:-1] + [("D3.1", "parent", "Unknown tier control.")], {}, "D3", "scope tier"),
    ):
        findings = v.post_c_faults(indexed, active, credit, aggregations, active)
        check(name, any(expected in finding for finding in findings), findings)
    findings = v.post_c_faults(fixture_rows, "D3", fixture_units, {}, "D3.2")
    check("child label cannot replace active parent implicitly", any("explicitly active" in finding for finding in findings), findings)
    for malformed in ("D3.", "D3..1", "D3.a", "D3.1x"):
        try:
            c.batch_parent(malformed)
            check("malformed complete identity " + malformed, False)
        except c.CatalogueError:
            check("malformed complete identity " + malformed, True)
    for bad_active in (active_text + "\n" + active_text, active_text.replace("D3 —", "D3..1 —")):
        try:
            c.active_batch(bad_active)
            check("malformed or duplicate active scope refuses", False)
        except c.CatalogueError:
            check("malformed or duplicate active scope refuses", True)
    for name, text, expected in (
        ("duplicate indexed identifier", dashed + "\n" + dashed, "duplicate BATCH_LOG"),
        ("dashed date mismatch", dashed.replace("| 2026-10-03 |", "| 2026-10-02 |"), "filename carries"),
        ("compact date mismatch", compact.replace("| 2026-10-03 |", "| 2026-10-02 |"), "filename carries"),
        ("malformed indexed row", "| [C1] missing-record |", "unmatched BATCH_LOG"),
        ("record identity mismatch", dashed.replace("/C1-", "/C2-"), "does not identify"),
        ("empty index", "# Batch log\n", "zero indexed rows"),
        ("duplicate dotted indexed identifier", child + "\n" + child, "duplicate BATCH_LOG"),
        ("malformed dotted indexed identifier", child.replace("D3.1", "D3..1"), "unmatched BATCH_LOG"),
        ("dotted record identity mismatch", child.replace("/D3.1-", "/D3.2-"), "does not identify"),
        ("dotted record date mismatch", child.replace("| 2026-10-03 |", "| 2026-10-02 |"), "filename carries"),
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
