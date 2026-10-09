#!/usr/bin/env python3
"""Focused real-source and known-bad controls for the continuity graph producer.

This does not execute simulation checks. It verifies the graph's projection and
artifact safety against the current catalogue and a detached receipt fixture.
"""
from __future__ import annotations

import copy
import json
import re
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import development_graph as dg


def reseal(graph):
    graph["revision"] = dg.digest(dg.canonical({k: v for k, v in graph.items() if k != "revision"}))
    return graph


class ContinuityGraphChecks(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.graph = dg.build_graph()
        cls.nodes = {n["id"]: n for n in cls.graph["nodes"]}
        cls.manifest = json.loads((dg.ROOT / dg.MANIFEST).read_text(encoding="utf-8-sig"))
        from catalogue import PRODUCT_MANIFEST
        cls.products = json.loads((dg.ROOT / PRODUCT_MANIFEST).read_text(encoding="utf-8-sig"))

    def bad(self, mutate, message):
        graph = copy.deepcopy(self.graph)
        mutate(graph)
        reseal(graph)
        with self.assertRaisesRegex(dg.GraphError, message):
            dg.validate_graph(graph)

    def test_actual_generations_are_complete_and_distinct(self):
        kinds = [n["kind"] for n in self.graph["nodes"]]
        self.assertEqual(len([n for n in self.graph["nodes"] if n["kind"] == "batch"
                              and "current-ab" in n["tags"]]), 81)
        self.assertEqual(kinds.count("source-record"), 120)
        self.assertEqual(kinds.count("raw-record"), 127)
        self.assertEqual(kinds.count("contract"), len(self.manifest["units"]))
        self.assertIn("source:c-20261003:C1", self.nodes)
        self.assertIn("source:c-raw-20260919:C1", self.nodes)
        self.assertIn("contract:20261003:C1", self.nodes)

    def test_actual_projection_matches_all_manifest_contributions_and_dependencies(self):
        contributions = {(e["from"], e["to"], e["rationale"]) for e in self.graph["edges"] if e["relation"] == "contributes-to" and e["from"].startswith("source:c-20261003:") and e["to"].startswith("contract:")}
        expected = {("source:c-20261003:" + label, "contract:20261003:" + edge["unit"], edge["scope"]) for label, src in self.manifest["sources"].items() for edge in src["contributions"]}
        self.assertEqual(contributions, expected)
        dependencies = {(e["from"], e["to"]) for e in self.graph["edges"]
                        if e["relation"] == "depends-on" and e["from"].startswith("contract:")}
        expected = {("contract:20261003:" + u["id"], "contract:20261003:" + t) for u in self.manifest["units"] for t in u["depends_on"]}
        self.assertEqual(dependencies, expected)

    def test_current_status_preserves_measured_component_results(self):
        for label in ("C118", "C119", "C120"):
            expected = self.manifest["sources"][label]
            self.assertEqual(self.nodes["source:c-20261003:" + label]["status"], {k: expected[k] for k in ("implementation", "verification", "publication")})
        self.assertEqual(self.nodes["source:c-20261003:C118"]["status"]["publication"], "merged")
        self.assertEqual(self.nodes["source:c-20261003:C119"]["status"]["publication"], "merged")
        self.assertEqual(self.nodes["source:c-20261003:C120"]["status"]["publication"], "local-unmerged")
        extension = self.nodes["extension:shared-reasoning:20261003"]
        proof = json.loads((dg.ROOT / self.manifest["unnumbered_continuation"]["receipt"]["path"]).read_text(encoding="utf-8"))
        base = proof["workingDirectory"].replace("\\", "/").rstrip("/") + "/"
        matches = all(dg.digest((dg.ROOT / pin["path"].replace("\\", "/")[len(base):]).read_bytes())
                      == "sha256:" + pin["sha256"] for pin in proof["inputs"]["production"])
        self.assertEqual(extension["proofApplicability"]["productionPinsMatch"], matches)
        if not matches:
            self.assertEqual(extension["status"]["verification"], "recorded proof requires input reconciliation")
        self.assertEqual(extension["status"]["publication"], "local-unmerged")
        self.assertTrue(any("rendered" in r for r in extension["remaining"]))

    def test_product_chronology_keeps_contract_and_source_identities(self):
        products = [n for n in self.graph["nodes"] if n["kind"] == "product-batch"]
        expected = {"product:" + self.products["generation"] + ":" + u["id"] for u in self.products["units"]}
        self.assertEqual({n["id"] for n in products}, expected)
        self.assertEqual(sum(n["kind"] == "contract" for n in self.graph["nodes"]), 35)
        contributions = [e for e in self.graph["edges"] if e["relation"] == "product-contribution"]
        self.assertEqual(len(contributions), 120)
        self.assertEqual({e["from"] for e in contributions},
                         {"source:c-20261003:C" + str(i) for i in range(1, 121)})
        self.assertTrue(all(e["to"] in expected for e in contributions))
        last = "product:" + self.products["generation"] + ":" + self.products["units"][-1]["id"]
        self.assertTrue(any(e["from"] == last and e["to"] == "batch:D1"
                            and e["relation"] == "chronology" for e in self.graph["edges"]))
        self.assertIn("contract:20261003:C1", self.nodes)
        self.assertIn("source:c-20261003:C1", self.nodes)
        self.assertIn("product:" + self.products["generation"] + ":C1", self.nodes)

    def test_product_generation_collision_control(self):
        # Product loading uses the catalogue reader, so mutate its detached JSON
        # directly; other production readers and preserved source bytes remain.
        import catalogue
        wrong = copy.deepcopy(self.products)
        wrong["generation"] = self.manifest["generation"]
        with patch.object(catalogue, "load_product_catalogue", return_value=wrong):
            with self.assertRaisesRegex(dg.GraphError, "collides"):
                dg.build_graph()

    def test_product_node_contract_identity_collision_control(self):
        product = next(n for n in self.graph["nodes"] if n["kind"] == "product-batch")
        self.bad(lambda g: next(n for n in g["nodes"] if n["id"] == product["id"]).update(
                 id="contract:20261003:C1"), "[Dd]uplicate|duplicate")

    def test_product_node_source_identity_collision_control(self):
        product = next(n for n in self.graph["nodes"] if n["kind"] == "product-batch")
        self.bad(lambda g: next(n for n in g["nodes"] if n["id"] == product["id"]).update(
                 id="source:c-20261003:C1"), "[Dd]uplicate|duplicate")

    def test_explicit_corrections_and_supersession_match_source_generation(self):
        for relation in self.manifest.get("source_relations", []):
            matches = [e for e in self.graph["edges"] if e["from"] == "source:c-20261003:" + relation["from_id"] and e["to"] == "source:c-20261003:" + relation["to_id"] and e["relation"] == relation["relation"]]
            self.assertEqual(len(matches), 1)
            self.assertEqual(matches[0]["rationale"], relation["rationale"])
            self.assertTrue(any(s["path"].startswith(dg.HISTORY + "/Batches/") for s in matches[0]["provenance"]))

    def test_explicit_source_relation_controls(self):
        for field, bad in (("to_id", "C999"), ("anchors", ["Batches/missing.md"]), ("relation", "implies")):
            with self.subTest(field=field):
                manifest = copy.deepcopy(self.manifest)
                self.assertTrue(manifest.get("source_relations"), "The production manifest must retain its explicit corrections")
                manifest["source_relations"][0][field] = bad
                b = dg.Builder(dg.ROOT)
                refs, _ = dg._historical_records(b)
                with patch("catalogue.load_catalogue", return_value=manifest), self.assertRaisesRegex(dg.GraphError, "source relation"):
                    dg._current_catalogue(b, refs)

    def test_original_archive_paths_are_metadata_not_working_file_provenance(self):
        for node in self.graph["nodes"]:
            if node["kind"] == "raw-record":
                self.assertTrue(node["archiveRef"].startswith("archive/"))
                self.assertEqual([s["path"] for s in node["sources"]], [dg.PARENT])
                self.assertTrue(dg.SHA.fullmatch(node["blobRevision"]))

    def test_no_current_contract_chronology_or_inferred_text_dependencies(self):
        for edge in self.graph["edges"]:
            if edge["relation"] == "chronology":
                self.assertNotEqual(self.nodes[edge["from"]]["kind"], "contract")
                self.assertNotEqual(self.nodes[edge["to"]]["kind"], "contract")
            if edge["relation"] == "depends-on" and edge["from"].startswith("contract:"):
                self.assertTrue(all(s["path"] == dg.MANIFEST for s in edge["provenance"]))
            if any(s.get("locator", "").startswith("markdown link:") for s in edge["provenance"]):
                self.assertEqual(edge["relation"], "records")

    def test_revision_is_deterministic_for_unchanged_inputs(self):
        self.assertEqual(self.graph, dg.build_graph())
        self.assertEqual(dg.render_html(self.graph), dg.render_html(self.graph))

    def test_graph_uses_native_simulation_repository_identity(self):
        self.assertEqual(self.graph["projectRef"], "project:survivor-awareness")
        for split_ref in ("project:sao", "project:mousecat", "survivor-awareness"):
            with self.subTest(projectRef=split_ref):
                self.bad(lambda g: g.update(projectRef=split_ref), "project identity")

    def test_compression_is_a_preserved_event_before_d(self):
        event_id = "event:catalogue-compression:C:20261003"
        self.assertEqual(self.nodes[event_id]["kind"], "catalogue-event")
        self.assertIn("era:D", self.nodes)
        self.assertEqual(self.nodes["batch:D1"]["kind"], "batch")
        self.assertTrue(self.nodes["batch:D1"]["recordedStatus"].startswith("CLOSED -"))
        record = (dg.ROOT / "Batches/D1-20261004-0124Z-1824PST-shared-reasoning.md").read_text(encoding="utf-8-sig")
        self.assertEqual(self.nodes["batch:D1"]["status"],
                         {key.lower(): dg.metadata(record, key)
                          for key in ("Implementation", "Verification", "Publication")})
        self.assertEqual(self.nodes["batch:D1"]["closedAt"], dg.metadata(record, "Closed"))
        self.assertIn("D had not started when this event was recorded.", self.nodes[event_id]["remaining"])
        self.assertTrue(any(e["from"] == event_id and e["to"] == "batch:D1"
                            and e["relation"] == "chronology" for e in self.graph["edges"]))
        self.assertEqual(sum(n["kind"] == "contract" for n in self.graph["nodes"]), 35)
        incoming = {e["from"] for e in self.graph["edges"] if e["to"] == event_id and e["relation"] == "contributes-to"}
        self.assertEqual(incoming, {"source:c-20261003:C" + str(i) for i in range(1, 121)})
        outgoing = {e["to"] for e in self.graph["edges"] if e["from"] == event_id and e["relation"] == "records"}
        self.assertEqual(outgoing, {"contract:20261003:C" + str(i) for i in range(1, 36)})
        before = {e["from"] for e in self.graph["edges"] if e["to"] == event_id and e["relation"] == "chronology"}
        self.assertEqual(before, {"source:c-20261003:C120", "extension:shared-reasoning:20261003"})
        chronology = next(v for v in self.graph["views"] if v["id"] == "chronology")
        self.assertIn("catalogue-event", chronology["nodeKinds"])

    def test_compression_event_refuses_changed_count_or_evidence(self):
        original = dg.Builder.json
        for mutate, message in ((lambda e: e.update(contractCount=71), "disagrees"),
                                (lambda e: e["mapping"].update(sha256="0" * 64), "hash mismatch"),
                                (lambda e: e.update(afterNodes=["absent"]), "absent chronology")):
            def altered(builder, path):
                value = original(builder, path)
                if path == dg.TRANSITION:
                    mutate(value)
                return value
            with self.subTest(message=message), patch.object(dg.Builder, "json", altered):
                with self.assertRaisesRegex(dg.GraphError, message):
                    dg.build_graph()

    def test_product_correction_records_applied_generation_and_public_history(self):
        event_id = "event:product-consolidation:C:20261005"
        self.assertTrue(event_id in self.nodes, "actual corrective event missing")
        node = self.nodes[event_id]
        application = json.loads((dg.ROOT / dg.PRODUCT_APPLICATION).read_text(encoding="utf-8"))
        self.assertEqual(node["generation"], self.products["generation"])
        self.assertEqual(node["status"]["implementation"], application["standing"])
        self.assertEqual(node["versionAtApplication"], application["version"])
        self.assertEqual(node["status"]["publication"], "REQUIRED_CHECKS_AND_PROTECTED_MERGE_PENDING")
        self.assertEqual({s["path"] for s in node["sources"]},
                         {dg.PRODUCT_TRANSITION, dg.PRODUCT_TRANSITION_RECORD, dg.PRODUCT_APPLICATION,
                          dg.PRODUCT_PUBLICATION, dg.MANIFEST, "Batches/C_PRODUCT_CATALOGUE.json"})
        outputs = {e["to"] for e in self.graph["edges"] if e["from"] == event_id
                   and e["relation"] == "records" and e["to"].startswith("product:")}
        self.assertEqual(outputs, {"product:" + self.products["generation"] + ":" + u["id"] for u in self.products["units"]})
        previous = "event:catalogue-compression:C:20261003"
        self.assertTrue(any(e["from"] == event_id and e["to"] == previous and e["relation"] == "corrects"
                            for e in self.graph["edges"]))
        self.assertTrue(any(e["from"] == previous and e["to"] == event_id and e["relation"] == "chronology"
                            for e in self.graph["edges"]))
        self.assertTrue(any(e["from"] == event_id and e["to"] == "commit:50c8994d7195bbb56117eea562f17e8c84fb7f91"
                            and e["relation"] == "records" for e in self.graph["edges"]))
        self.assertFalse(any(e["from"] == event_id and e["to"] == "batch:D1" and e["relation"] == "chronology"
                             for e in self.graph["edges"]))
        continuity = next(v for v in self.graph["views"] if v["id"] == "continuity")
        self.assertIn("corrects", continuity["relations"])

    def test_product_correction_rejects_corrupt_pins(self):
        original = dg.Builder.json
        for field in ("sourceManifest", "productManifest", "application", "snapshot"):
            def altered(builder, path):
                value = original(builder, path)
                if path == dg.PRODUCT_TRANSITION:
                    pin = value["correctionOf"][field] if field == "snapshot" else value[field]
                    pin["sha256"] = "0" * 64
                return value
            with self.subTest(field=field), patch.object(dg.Builder, "json", altered):
                with self.assertRaisesRegex(dg.GraphError, "Product correction provenance hash mismatch"):
                    dg.build_graph()

    def test_product_correction_rejects_foreign_generation_application_or_publication(self):
        original = dg.Builder.json
        controls = [
            (dg.PRODUCT_TRANSITION, lambda e: e.update(generation="foreign-generation"), "current product/source generation"),
            (dg.PRODUCT_TRANSITION, lambda e: e.update(productCount=999), "current product/source generation"),
            (dg.PRODUCT_TRANSITION, lambda e: e["preserved"].update(sharedContracts=99), "current product/source generation"),
            (dg.PRODUCT_APPLICATION, lambda e: e.update(generation="foreign-generation"), "application disagrees"),
            (dg.PRODUCT_APPLICATION, lambda e: e.update(standing="PUBLISHED"), "application disagrees"),
            (dg.PRODUCT_APPLICATION, lambda e: e["productManifest"].update(sha256="0" * 64), "provenance hash mismatch"),
            (dg.PRODUCT_PUBLICATION, lambda e: e["mergeCommit"].update(oid="f" * 40), "published identity differs"),
        ]
        for target, mutate, message in controls:
            def altered(builder, path):
                value = original(builder, path)
                if path == target:
                    mutate(value)
                return value
            with self.subTest(target=target, message=message), patch.object(dg.Builder, "json", altered):
                with self.assertRaisesRegex(dg.GraphError, message):
                    dg.build_graph()

    def test_product_correction_refuses_missing_current_evidence(self):
        original = dg.Builder.read
        for target in (dg.PRODUCT_TRANSITION, dg.PRODUCT_TRANSITION_RECORD,
                       dg.PRODUCT_APPLICATION, dg.PRODUCT_PUBLICATION):
            def absent(builder, path):
                if path == target:
                    raise dg.GraphError("Missing source file: " + path)
                return original(builder, path)
            with self.subTest(target=target), patch.object(dg.Builder, "read", absent):
                with self.assertRaisesRegex(dg.GraphError, "Missing source file"):
                    dg.build_graph()

    def test_closed_batch_has_only_declared_dependencies(self):
        dependencies = {e["to"] for e in self.graph["edges"]
                        if e["from"] == "batch:D1" and e["relation"] == "depends-on"}
        self.assertEqual(dependencies, {"contract:20261003:C" + str(n) for n in (23, 30, 32, 33, 34)})
        for view_id in ("contracts", "ownership", "continuity"):
            view = next(v for v in self.graph["views"] if v["id"] == view_id)
            self.assertIn(self.nodes["batch:D1"]["kind"], view["nodeKinds"])
            self.assertIn("contract", view["nodeKinds"])
            self.assertIn("depends-on", view["relations"])

    def open_batch_read(self, builder, path):
        """Detached index/record fixture; production remains actually closed."""
        result = self.original_read(builder, path)
        if path == "BATCH_LOG.md":
            match = re.search(r"^\| \[D1\]\(([^)]+)\) \| [^|]+ \| ([^|]+) \|.*$", result, re.M)
            self.assertIsNotNone(match)
            result = result[:match.start()] + result[match.end():]
            # This fixture reopens D1 before its successors exist. A later
            # closed batch cannot precede the reopened chronology owner.
            result = re.sub(r"^\| \[[D-Z]\d+\].*$", "", result, flags=re.M)
            result += "\nActive: [D1 — " + match[2].strip() + "](" + match[1] + ")\n"
        elif path.startswith("Batches/D1-"):
            self.assertIn("| Status | CLOSED -", result)
            result = result.replace("| Status | CLOSED -", "| Status | OPEN -", 1)
        return result

    original_read = staticmethod(dg.Builder.read)

    def test_open_fixture_preserves_dependencies_and_chronology(self):
        with patch.object(dg.Builder, "read", lambda builder, path: self.open_batch_read(builder, path)):
            graph = dg.build_graph()
        node = next(n for n in graph["nodes"] if n["id"] == "batch:D1")
        self.assertEqual(node["kind"], "active-batch")
        self.assertTrue(node["recordedStatus"].startswith("OPEN -"))
        self.assertEqual({e["to"] for e in graph["edges"]
                          if e["from"] == "batch:D1" and e["relation"] == "depends-on"},
                         {"contract:20261003:C" + str(n) for n in (23, 30, 32, 33, 34)})
        self.assertTrue(any(e["from"] == "event:catalogue-compression:C:20261003"
                            and e["to"] == "batch:D1" and e["relation"] == "chronology"
                            for e in graph["edges"]))

    def test_closed_batch_refuses_malformed_identity_status_or_dependency(self):
        self.check_batch_record_controls(False)

    def test_open_fixture_refuses_malformed_identity_status_or_dependency(self):
        self.check_batch_record_controls(True)

    def check_batch_record_controls(self, is_open):
        original = dg.Builder.read
        for before, after, message in (
                ("| Batch | D1 |", "| Batch | D2 |", "identity"),
                ("| Status | " + ("OPEN -" if is_open else "CLOSED -"),
                 "| Status | UNKNOWN -", "open status" if is_open else "closed status"),
                ("| Follows | event:catalogue-compression:C:20261003 |", "| Follows | absent |", "predecessor"),
                ("| Shared contracts | C23,", "| Shared contracts | C999,", "shared contracts")):
            landed = []
            def altered(builder, path):
                result = self.open_batch_read(builder, path) if is_open else original(builder, path)
                if path.startswith("Batches/D1-"):
                    self.assertIn(before, result)
                    result = result.replace(before, after)
                    landed.append(True)
                return result
            with self.subTest(message=message), patch.object(dg.Builder, "read", altered):
                with self.assertRaisesRegex(dg.GraphError, message):
                    dg.build_graph()
                self.assertTrue(landed)

    def test_all_input_revisions_match_actual_bytes(self):
        for source in self.graph["sourceVector"]:
            self.assertEqual(source["revision"], dg.digest((dg.ROOT / source["sourceRef"]).read_bytes()), source["sourceRef"])

    def test_source_revisions_reject_stale_provenance_control(self):
        self.bad(lambda g: g["nodes"][0]["sources"][0].update(revision="sha256:" + "0" * 64), "Provenance revision")

    def test_revision_rejects_unsealed_mutation_control(self):
        graph = copy.deepcopy(self.graph)
        graph["nodes"][0]["label"] += " altered"
        with self.assertRaisesRegex(dg.GraphError, "content does not match"):
            dg.validate_graph(graph)

    def test_dangling_endpoint_control(self):
        self.bad(lambda g: g["edges"][0].update(to="missing-node"), "dangling relation")

    def test_missing_provenance_control(self):
        self.bad(lambda g: g["edges"][0].update(provenance=[]), "nonempty provenance")

    def test_duplicate_identity_controls(self):
        for field in ("nodes", "edges", "sourceVector", "views"):
            with self.subTest(field=field):
                self.bad(lambda g, key=field: g[key].append(copy.deepcopy(g[key][0])), "[Dd]uplicate|duplicate")

    def test_status_dimension_control(self):
        self.bad(lambda g: g["nodes"][0]["status"].pop("publication"), "three explicit dimensions")

    def test_unknown_relation_and_evidence_controls(self):
        for field in ("relation", "evidenceClass"):
            with self.subTest(field=field):
                self.bad(lambda g, key=field: g["edges"][0].update({key: "invented"}), "Unknown relation")

    def test_unsafe_media_controls_and_safe_optional_reference(self):
        for href in ("javascript:alert(1)", "https://example.test/x.png", "../x.png", "/x.png", "a/%2e%2e/x.png", "C:/x.png", "a\\x.png", "a//x.png", "a.png?x=1"):
            with self.subTest(href=href):
                self.bad(lambda g, ref=href: g["nodes"][0].update(mediaRefs=[{"kind": "image", "href": ref}]), "Unsafe optional media")
        graph = copy.deepcopy(self.graph)
        graph["nodes"][0]["mediaRefs"] = [{"kind": "image", "href": "artifacts/illustrations/example.png", "label": "Recorded illustration"}]
        dg.validate_graph(reseal(graph))

    def test_html_escapes_embedded_source_script_control(self):
        graph = copy.deepcopy(self.graph)
        payload = '</script><script>globalThis.injected=true</script><img src=x onerror="alert(1)">'
        graph["nodes"][0]["label"] = payload
        html = dg.render_html(reseal(graph))
        self.assertNotIn(payload, html)
        self.assertIn("\\u003c/script>", html)
        self.assertNotIn("innerHTML", html)
        self.assertNotIn("fetch(", html)
        self.assertEqual(html.count("</script>"), 2)

    def test_portable_proof_pins_detect_changed_production_control(self):
        with tempfile.TemporaryDirectory(prefix="sao-continuity-proof-") as temp:
            root = Path(temp)
            production = root / "mod" / "component.lua"
            production.parent.mkdir()
            production.write_bytes(b"actual source")
            receipt = {"workingDirectory": "X:\\old-machine\\sao", "inputs": {"production": [{"path": "X:\\old-machine\\sao\\mod\\component.lua", "sha256": dg.digest(b"actual source")[7:]}]},
                       "status": "PASS_WITH_SCOPED_REUSE", "scope": "Local continuation.", "evidenceBoundary": "Controlled checks only.",
                       "branch": "neo/test", "head": "a" * 40, "preservedStatus": {k: "Recorded component status." for k in ("C118", "C119", "C120")}, "openAcceptance": ["Rendered acceptance open."]}
            proof_path = root / dg.PROOF
            proof_path.parent.mkdir(parents=True)
            proof_path.write_text(json.dumps(receipt), encoding="utf-8")
            def evaluate():
                b = dg.Builder(root)
                refs = {label: "source:" + label for label in ("C118", "C119", "C120")}
                for label, id in refs.items():
                    b.node(id, "source-record", label, "Fixture.", [b.source(dg.PROOF)])
                dg._local_reasoning(b, refs)
                return b.nodes["extension:shared-reasoning:20261003"]
            self.assertTrue(evaluate()["proofApplicability"]["productionPinsMatch"])
            production.write_bytes(b"changed source")
            stale = evaluate()
            self.assertFalse(stale["proofApplicability"]["productionPinsMatch"])
            self.assertNotIn("verified", stale["status"]["verification"])
            self.assertEqual(stale["status"]["publication"], "local-unmerged")


if __name__ == "__main__":
    result = unittest.main(verbosity=2, exit=False)
    raise SystemExit(0 if result.result.wasSuccessful() else 1)
