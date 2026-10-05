#!/usr/bin/env python3
"""Build a portable, provenance-bearing view of SAO development continuity.

The catalogue remains authoritative. This producer projects recorded membership,
chronology, owners and declared dependencies; it does not infer dependency from
textual mention, shared ownership, or contribution order. Run with --write after
the current product and shared-boundary manifests are ready. --check checks artifact currency.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import posixpath
import re
import sys
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parent.parent
SCHEMA = "development.continuity-graph/1"
MANIFEST = "Batches/C_SHARED_BOUNDARIES.json"
HISTORY = "Batches/history/c-20261003-source"
PARENT = "Batches/C_RECATALOG.json"
PROOF = "_scratch/shared-reasoning/verification-summary.json"
TRANSITION = "Batches/Transitions/C-20261003-compression.json"
PRODUCT_TRANSITION = "Batches/Transitions/C-20261005-product-consolidation.json"
PRODUCT_TRANSITION_RECORD = "Batches/Transitions/C-20261005-product-consolidation.md"
PRODUCT_APPLICATION = "artifacts/audits/20261005-c-product-consolidation/application.json"
PRODUCT_PUBLICATION = "artifacts/audits/20261005-c-product-consolidation/pr137-publication.json"
OUTPUT = "artifacts/continuity"
RELATIONS = {"chronology", "contributes-to", "depends-on", "corrects", "supersedes",
             "shares-owner", "concept-membership", "records", "product-contribution"}
EVIDENCE = {"source-fact", "deterministic-projection", "derived-summary", "illustration", "unknown"}
SHA = re.compile(r"sha256:[0-9a-f]{64}\Z")
ROW = re.compile(r"^\|\s*\[([ABC]\d+)\]\(([^)]+)\)\s*\|\s*([^|]+)\|\s*([^|]+)\|([^\n]*)", re.M)


class GraphError(ValueError):
    pass


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


def digest(value):
    return "sha256:" + hashlib.sha256(value).hexdigest()


def safe_path(path):
    """Local provenance may be linked, but never interpreted as active content."""
    if not isinstance(path, str) or not path or len(path) > 4096:
        return False
    decoded = unquote(path)
    return (not decoded.startswith(("/", "\\")) and not re.search(r"[:\\?#\x00-\x1f]", decoded)
            and all(p not in ("", ".", "..") for p in decoded.split("/")))


def unique_json(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise GraphError(f"Duplicate JSON key: {key}")
        result[key] = value
    return result


def record_summary(text):
    body = text.split("## Record", 1)[-1] if "## Record" in text else text
    paragraphs = re.split(r"\n\s*\n", body)
    for p in paragraphs:
        if p.strip() and not p.lstrip().startswith(("|", "#", "<!--")):
            return " ".join(p.split())[:720]
    return "Recorded development unit; follow the source for its scope and evidence."


def metadata(text, key):
    found = re.search(r"^\|\s*" + re.escape(key) + r"\s*\|\s*(.*?)\s*\|\s*$", text, re.M | re.I)
    return found.group(1) if found else ""


def status(implementation="unknown", verification="unknown", publication="unknown"):
    return dict(implementation=implementation, verification=verification, publication=publication)


class Builder:
    def __init__(self, root):
        self.root = Path(root).resolve()
        self.nodes = {}
        self.edges = {}
        self.vector = {}

    def read(self, path):
        if not safe_path(path):
            raise GraphError(f"Unsafe source path: {path}")
        resolved = (self.root / path).resolve()
        if not resolved.is_relative_to(self.root) or not resolved.is_file():
            raise GraphError(f"Missing source file: {path}")
        data = resolved.read_bytes()
        self.vector[path] = digest(data)
        return data.decode("utf-8-sig")

    def json(self, path):
        return json.loads(self.read(path), object_pairs_hook=unique_json)

    def source(self, path, locator=None):
        if path not in self.vector:
            self.read(path)
        src = {"path": path, "revision": self.vector[path]}
        if locator:
            src["locator"] = locator
        return src

    def node(self, id, kind, label, summary, sources, tags=(), status_value=None, **extra):
        if id in self.nodes:
            old = self.nodes[id]
            for src in sources:
                if src not in old["sources"]:
                    old["sources"].append(src)
            return id
        self.nodes[id] = {"id": id, "kind": kind, "label": label, "summary": summary,
                          "status": status_value or status(), "sources": sources, "tags": list(tags), **extra}
        return id

    def edge(self, from_id, to_id, relation, sources, rationale, evidence="source-fact"):
        seed = [from_id, to_id, relation, sources, rationale]
        id = "edge:" + hashlib.sha256(canonical(seed)).hexdigest()[:24]
        self.edges[id] = {"id": id, "from": from_id, "to": to_id, "relation": relation,
                          "evidenceClass": evidence, "provenance": sources, "rationale": rationale}

    def sequence(self, ids, source, rationale):
        for before, after in zip(ids, ids[1:]):
            self.edge(before, after, "chronology", [source], rationale, "deterministic-projection")

    def named_ref(self, owner, kind, value, source, rationale):
        node = self.node(kind + ":" + value, kind, value, rationale, [source], [kind])
        self.edge(owner, node, "records", [source], rationale)
        return node


def _historical_records(b):
    index = HISTORY + "/BATCH_LOG.md"
    rows = list(ROW.finditer(b.read(index)))
    expected = {f"A{i}" for i in range(1, 30)} | {f"B{i}" for i in range(1, 53)} | {f"C{i}" for i in range(1, 121)}
    labels = [m[1] for m in rows]
    if len(labels) != len(expected) or set(labels) != expected:
        raise GraphError("Frozen index must contain exactly A1–A29, B1–B52 and source C1–C120 once")
    by_label, texts, order, by_path = {}, {}, [], {}
    for era in "ABC":
        b.node("era:" + era, "era", "Era " + era, "Recorded letter era; status is carried by its component records.",
               [b.source(index)], [era])
    for m in rows:
        label, original_path, date, title, threads = (v.strip() for v in m.groups())
        path = HISTORY + "/" + original_path if label.startswith("C") else original_path
        text = b.read(path)
        source = b.source(path)
        node_id = ("source:c-20261003:" if label.startswith("C") else "batch:") + label
        kind = "source-record" if label.startswith("C") else "batch"
        raw_status = metadata(text, "Status") or "No explicit status field recorded"
        b.node(node_id, kind, label + " · " + title, record_summary(text), [source],
               [label[0], "source-c-20261003" if label.startswith("C") else "current-ab", date],
               status("recorded: " + raw_status), recordedStatus=raw_status)
        b.edge(node_id, "era:" + label[0], "concept-membership", [b.source(index, label)], "Indexed in era " + label[0] + ".")
        by_label[label], texts[label] = node_id, (path, text, threads)
        by_path[original_path] = node_id
        order.append(node_id)
        commits = metadata(text, "Local Git commits")
        for commit in sorted(set(re.findall(r"\b[0-9a-f]{7,40}\b", commits))):
            b.named_ref(node_id, "commit", commit, b.source(path, "Local Git commits"),
                        "Commit identifier recorded in this batch's Local Git commits field; no ancestry is inferred.")
    b.sequence(order, b.source(index), "Adjacent entries in the preserved development index; dates may differ from index order.")
    # A bare identifier may name an earlier generation (especially in a source
    # table of superseded entries). Only an exact linked record path resolves it.
    for label, (path, text, _) in texts.items():
        original = path.removeprefix(HISTORY + "/")
        for href in sorted(set(re.findall(r"\]\(([^)]+)\)", text))):
            local = href.split("#", 1)[0]
            target = local if local.startswith("Batches/") else posixpath.normpath(str(PurePosixPath(original).parent / local))
            if target in by_path and by_path[target] != by_label[label]:
                b.edge(by_label[label], by_path[target], "records", [b.source(path, "markdown link: " + href)],
                       "Explicit linked record reference; the exact target path supplies the generation. A reference establishes no dependency or correction.")
    return by_label, texts


def _threads(b, by_label, texts):
    path = HISTORY + "/Batches/THREADS.md"
    text = b.read(path)
    family, thread = None, None
    for number, line in enumerate(text.splitlines(), 1):
        match = re.search(r"^## (TF-\d+)\s*-\s*(.+)", line)
        if match:
            family = b.node("concept:" + match[1], "concept", match[1] + " · " + match[2],
                            "Recorded thread family in the preserved source-generation thread index.", [b.source(path, f"line {number}")], ["thread-family"])
        match = re.search(r"^### .*?(T-\d+)\s*-\s*(.+)", line)
        if match:
            thread = b.node("concept:" + match[1], "concept", match[1] + " · " + match[2],
                            "Recorded development thread; membership is classification, not a runtime dependency.", [b.source(path, f"line {number}")], ["thread"])
            if family:
                b.edge(thread, family, "concept-membership", [b.source(path, f"line {number}")], "Thread appears under this family heading.")
        if line.startswith("**Batches**") and thread:
            for label in re.findall(r"`([ABC]\d+)`", line):
                if label not in by_label:
                    raise GraphError(f"Thread index has unknown source label {label}")
                b.edge(by_label[label], thread, "concept-membership", [b.source(path, f"line {number}")], "Explicit preserved thread-index membership.")
    # Late source records may be newer than the thread-index lists; preserve their own declarations too.
    for label, (path, text, indexed_threads) in texts.items():
        declared = metadata(text, "Threads") or metadata(text, "Thread") or indexed_threads
        for thread_id in sorted(set(re.findall(r"\bT-\d+\b", declared))):
            concept = "concept:" + thread_id
            if concept not in b.nodes:
                b.node(concept, "concept", thread_id, "Thread identifier declared by a source record.", [b.source(path, "Thread")], ["thread"])
            b.edge(by_label[label], concept, "concept-membership", [b.source(path, "Thread/Threads")], "Thread identifier explicitly declared by this source record or its frozen index row.")


def _raw_generation(b, by_label):
    manifest = b.json(PARENT)
    if manifest.get("old_count") != 127 or manifest.get("new_count") != 50:
        raise GraphError("Historical recatalogue must preserve the recorded 127-to-50 generation")
    source = b.source(PARENT)
    archive = b.named_ref("era:C", "branch", manifest["source_ref"], source, "Recorded original-C archive reference.")
    b.named_ref(archive, "commit", manifest["source_commit"], source, "Recorded commit of the original-C archive; no live branch or ancestry claim.")
    raw = {}
    for index, unit in enumerate(manifest["units"]):
        for position, item in enumerate(unit["sources"]):
            label = item["former"]
            if label in raw or not re.fullmatch(r"[0-9a-f]{64}", item["sha256"]):
                raise GraphError("Duplicate original source or malformed original blob hash: " + label)
            evidence = b.source(PARENT, f"/units/{index}/sources/{position}")
            id = "source:c-raw-20260919:" + label
            title = PurePosixPath(item["path"]).stem
            b.node(id, "raw-record", label + " · " + title, "Original C generation preserved in Git. " + item["path"] + "; blob SHA-256 " + item["sha256"] + ".",
                   [evidence], ["C", "raw-c-20260919"], archiveRef=manifest["source_ref"], archivePath=item["path"], blobRevision="sha256:" + item["sha256"])
            b.edge(id, by_label[unit["batch"]], "contributes-to", [evidence], "Explicit former-source membership in the 2026-09-19 consolidation.")
            b.edge(archive, id, "records", [evidence], "The manifest records this blob at the archived Git reference; archivePath is not a working-tree hyperlink.")
            raw[label] = id
    if set(raw) != {f"C{i}" for i in range(1, 128)}:
        raise GraphError("Original C generation must cover C1–C127 exactly")
    b.sequence([raw[f"C{i}"] for i in range(1, 128)], source, "Original raw-C identifier sequence, before the 2026-09-19 consolidation.")


def _current_catalogue(b, by_label):
    if not (b.root / MANIFEST).is_file():
        return False
    # The dedicated checker owns comprehensive catalogue validation. Importing it
    # keeps graph generation from accepting a different meaning of source status.
    from catalogue import load_catalogue, validate_catalogue
    manifest = load_catalogue(b.root)
    faults = validate_catalogue(b.root, manifest)
    if faults:
        raise GraphError("Invalid shared-boundary catalogue: " + "; ".join(faults))
    b.read("tools/catalogue.py")
    b.read(MANIFEST)
    for number, unit in enumerate(manifest["units"]):
        src = b.source(MANIFEST, f"/units/{number}")
        record = b.source(unit["path"])
        id = "contract:20261003:" + unit["id"]
        b.node(id, "contract", unit["id"] + " · " + unit["name"], " ".join(unit["delivered_scope"]), [src, record],
               ["C", "current-shared-boundary", unit["tier"], unit["date"]],
               status("delivered baseline", "component evidence; see source records", "component-specific; see contributions"),
               remaining=unit["remaining"], state=unit["state"], inputs=unit["inputs"], outputs=unit["outputs"])
        b.edge(id, "era:C", "concept-membership", [src], "Current C shared-contract classification.")
        for owner in unit["owners"]:
            oid = "owner:" + owner
            owner_sources = [src]
            if (b.root / owner).is_file():
                owner_sources.append(b.source(owner))
            b.node(oid, "owner", PurePosixPath(owner).name, owner, owner_sources, ["declared-owner"], ownerPath=owner)
            b.edge(id, oid, "shares-owner", [src], "This contract explicitly declares this owner path; shared ownership alone is not a dependency.")
        for direction in ("inputs", "outputs"):
            for value in unit[direction]:
                iid = "interface:" + hashlib.sha256(value.encode("utf-8")).hexdigest()[:24]
                b.node(iid, "interface", value, "Literal shared-contract interface declaration.", [src], ["declared-interface"])
                b.edge(id, iid, "records", [src], direction[:-1].capitalize() + " interface: " + value)
        reasons = unit.get("dependency_reasons", {})
        for target in unit["depends_on"]:
            reason = reasons.get(target, "Explicit depends_on declaration in the shared-boundary manifest.") if isinstance(reasons, dict) else "Explicit depends_on declaration in the shared-boundary manifest."
            b.edge(id, "contract:20261003:" + target, "depends-on", [src], str(reason))
    for label, item in manifest["sources"].items():
        src = b.source(MANIFEST, "/sources/" + label)
        # The archived bytes are separately hashed by the catalogue validator.
        b.read(item["archive_path"])
        b.nodes[by_label[label]]["status"] = status(item["implementation"], item["verification"], item["publication"])
        b.nodes[by_label[label]]["sources"].append(src)
        b.nodes[by_label[label]]["remaining"] = item["remaining"]
        for contribution in item["contributions"]:
            target = "contract:20261003:" + contribution["unit"]
            evidence = [src, b.source(item["archive_path"], "; ".join(contribution["anchors"]))]
            b.edge(by_label[label], target, "contributes-to", evidence, contribution["scope"])
    originals = {item["original_path"]: item["archive_path"] for item in manifest["sources"].values()}
    for number, relation in enumerate(manifest.get("source_relations", [])):
        if (relation.get("from_id") not in manifest["sources"] or relation.get("to_id") not in manifest["sources"]
                or relation.get("relation") not in ("corrects", "supersedes", "contributes-to")
                or not isinstance(relation.get("rationale"), str) or not relation["rationale"].strip()
                or not isinstance(relation.get("anchors"), list) or not relation["anchors"]
                or any(anchor not in originals for anchor in relation["anchors"])):
            raise GraphError("Invalid explicit source relation or source-generation anchor")
        evidence = [b.source(MANIFEST, f"/source_relations/{number}")]
        evidence.extend(b.source(originals[anchor]) for anchor in relation["anchors"])
        b.edge(by_label[relation["from_id"]], by_label[relation["to_id"]], relation["relation"], evidence, relation["rationale"])
    # Current order is a classification display order. It is deliberately not a
    # chronology edge, because nonadjacent source contributions share contracts.
    archive = b.named_ref("era:C", "branch", manifest["archive_ref"], b.source(MANIFEST, "/archive_ref"), "Recorded source-generation preservation reference.")
    b.named_ref(archive, "commit", manifest["archive_commit"], b.source(MANIFEST, "/archive_commit"), "Recorded commit preserving the source generation.")
    return True


def _local_reasoning(b, by_label):
    continuation = b.json(MANIFEST).get("unnumbered_continuation") if MANIFEST in b.vector else None
    proof_path = continuation["receipt"]["path"] if continuation else PROOF
    if not (b.root / proof_path).is_file() and not continuation:
        return
    proof = b.json(proof_path)
    evidence = [b.source(proof_path)]
    for doc in ("SESSION_STATE.md", "ARCHITECTURE.md"):
        if (b.root / doc).is_file():
            evidence.append(b.source(doc, "shared reasoning continuation"))
    base = proof["workingDirectory"].replace("\\", "/").rstrip("/") + "/"
    pins = proof.get("inputs", {}).get("production", [])
    matching = bool(pins)
    for pin in pins:
        raw_path = pin["path"].replace("\\", "/")
        if not raw_path.casefold().startswith(base.casefold()):
            raise GraphError("Proof production path leaves its recorded working directory")
        path = raw_path[len(base):]
        b.read(path)
        matching = matching and b.vector[path] == "sha256:" + pin["sha256"]
        evidence.append(b.source(path))
    verified = matching and proof.get("status") == "PASS_WITH_SCOPED_REUSE"
    id = "extension:shared-reasoning:20261003"
    summary = proof["scope"] + " " + proof["evidenceBoundary"]
    remaining = proof.get("openAcceptance", [])
    if continuation:
        receipt = continuation.get("receipt", {})
        if "sha256:" + receipt.get("sha256", "") != b.vector[proof_path]:
            raise GraphError("Manifest continuation receipt differs from the graph's local proof")
        evidence.append(b.source(MANIFEST, "/unnumbered_continuation"))
        summary = continuation["implemented"] + " " + continuation["evidenceBoundary"]
        remaining = [continuation["remainingDJoin"], "Revised rendered recovery and end-to-end acceptance remain open."]
    b.node(id, "extension", "Local shared reasoning · unnumbered", summary, evidence,
           ["C", "local", "shared-reasoning", "rendered-acceptance-open"],
           status("implemented", "verified with scoped reuse; production pins match" if verified else "recorded proof requires input reconciliation", "local-unmerged"),
           remaining=remaining, recordedAt=proof.get("recordedAt"),
           proofApplicability={"productionPinsMatch": matching, "pinCount": len(pins)})
    if continuation:
        for target in continuation["boundaries"]:
            b.edge(id, "contract:20261003:" + target, "contributes-to", [b.source(MANIFEST, "/unnumbered_continuation/boundaries")],
                   "The manifest records this local, unnumbered extension against this shared contract; delivered historical scope retains its own status.")
    b.edge(id, by_label["C120"], "records", [b.source(proof_path, "/preservedStatus/C120")],
           proof["preservedStatus"]["C120"] + " The unnumbered continuation is recorded separately from the preserved source component.")
    for label in ("C118", "C119", "C120"):
        src = b.source(proof_path, "/preservedStatus/" + label)
        b.nodes[by_label[label]]["sources"].append(src)
        b.nodes[by_label[label]]["measuredStatusNote"] = proof["preservedStatus"][label]
        # Only a fallback before catalogue generation; published graph requires it.
        if b.nodes[by_label[label]]["status"]["publication"] == "unknown":
            b.nodes[by_label[label]]["status"] = status("implemented" if label == "C120" else "completed", "verified locally; rendered acceptance remains distinct", "local-unmerged" if label == "C120" else "merged")
    branch = b.named_ref(id, "branch", proof["branch"], b.source(proof_path, "/branch"), "Branch recorded by the local reasoning verification receipt.")
    b.named_ref(branch, "commit", proof["head"], b.source(proof_path, "/head"), "HEAD recorded by the local receipt; local modifications are not claimed to be committed.")


def _catalogue_transition(b, by_label):
    event = b.json(TRANSITION)
    if (event.get("schema") != "sao.catalogue-transition/1"
            or event.get("id") != "catalogue-compression:C:20261003"
            or event.get("beforeEra") != "D"):
        raise GraphError("Invalid C compression transition identity")
    mapping = b.json(event["mapping"]["path"])
    verification = b.json(event["verification"]["path"])
    for field in ("mapping", "verification"):
        if b.vector[event[field]["path"]] != "sha256:" + event[field]["sha256"]:
            raise GraphError("Compression transition provenance hash mismatch")
    if (event["sourceGeneration"] != mapping["source_generation"]
            or event["resultGeneration"] != mapping["generation"]
            or event["sourceCount"] != len(mapping["sources"])
            or event["contractCount"] != len(mapping["units"])
            or event["contributionCount"] != sum(len(s["contributions"]) for s in mapping["sources"].values())
            or event["verifiedAt"] != verification["recordedAt"]
            or event["versionAfterReplay"] != verification["catalogue"]["version"]):
        raise GraphError("Compression transition disagrees with preserved mapping or verification")
    src = b.source(TRANSITION)
    evidence = [src, b.source(event["record"]), b.source(event["mapping"]["path"]),
                b.source(event["verification"]["path"])]
    id = b.node("event:" + event["id"], "catalogue-event", event["label"], event["summary"],
                evidence, ["C", "catalogue-compression", "before-D", event["verifiedAt"][:10]],
                status("applied: 120 source records to 35 shared contracts",
                       "original migration verification retained", "local-unmerged at event recording"),
                recordedAt=event["recordedAt"], remaining=["D had not started when this event was recorded."])
    b.edge(id, "era:C", "concept-membership", [src], "Compression closes the C catalogue before D.")
    for predecessor in event["afterNodes"]:
        if predecessor not in b.nodes:
            raise GraphError("Compression transition has an absent chronology predecessor")
        b.edge(predecessor, id, "chronology", [src], "Recorded work precedes the applied C compression event.")
    for label in mapping["sources"]:
        b.edge(by_label[label], id, "contributes-to", [src], "Preserved source record is an input to this catalogue transformation.")
    for unit in mapping["units"]:
        b.edge(id, "contract:20261003:" + unit["id"], "records", [src], "This shared contract is an output of the recorded compression mapping.")


def _product_catalogue(b, by_label):
    """Project the product ledger without relabeling sources or contracts."""
    from catalogue import PRODUCT_MANIFEST, load_product_catalogue, validate_product_catalogue
    products = load_product_catalogue(b.root)
    faults = validate_product_catalogue(b.root, products)
    if faults:
        raise GraphError("Invalid product catalogue: " + "; ".join(faults))
    b.read(PRODUCT_MANIFEST)
    ordered = []
    for number, unit in enumerate(products["units"]):
        src = b.source(PRODUCT_MANIFEST, f"/units/{number}")
        record = b.source(unit["recordPath"])
        node = "product:" + products["generation"] + ":" + unit["id"]
        if node in b.nodes:
            raise GraphError("Product generation identity collides with a recorded node")
        b.node(node, "product-batch", unit["id"] + " · " + unit["name"],
               unit["rationale"], [src, record], ["C", "current-c-product"],
               status("classified product capability; retained component states remain separate",
                      "source-scoped evidence; see contributions", "component-specific; see sources"),
               generation=products["generation"], first=unit["first"], last=unit["last"],
               tier=unit["tier"], recordPath=unit["recordPath"])
        b.edge(node, "era:C", "concept-membership", [src], "Product-era classification in the current ledger.")
        for contribution in unit["sourceContributions"]:
            b.edge(by_label[contribution["sourceId"]], node, "product-contribution",
                   [src, b.source(contribution["path"])],
                   "Exact retained source belongs to this adjacent product/version unit once.")
        ordered.append(node)
    b.sequence([by_label["B52"], *ordered], b.source(PRODUCT_MANIFEST),
               "Current product chronology partitions the retained C source order after B; contract membership remains separate.")
    return ordered


def _product_event_pin(b, value, path):
    if (not isinstance(value, dict) or value.get("path") != path
            or not isinstance(value.get("sha256"), str)
            or not SHA.fullmatch("sha256:" + value["sha256"])):
        raise GraphError("Product correction provenance path/hash differs: " + path)
    result = b.json(path)
    if b.vector[path] != "sha256:" + value["sha256"]:
        raise GraphError("Product correction provenance hash mismatch: " + path)
    if not isinstance(result, dict):
        raise GraphError("Product correction provenance is not an object: " + path)
    return result


def _product_transition(b, product_nodes):
    """Record the applied correction with its published predecessor preserved."""
    from catalogue import PRODUCT_MANIFEST
    event = b.json(PRODUCT_TRANSITION)
    if (not isinstance(event, dict) or event.get("schema") != "sao.catalogue-transformation/1"
            or event.get("id") != "product-consolidation:C:20261005"):
        raise GraphError("Invalid product correction identity")
    shared = _product_event_pin(b, event.get("sourceManifest"), MANIFEST)
    products = _product_event_pin(b, event.get("productManifest"), PRODUCT_MANIFEST)
    application = _product_event_pin(b, event.get("application"), PRODUCT_APPLICATION)
    correction = event.get("correctionOf")
    if not isinstance(correction, dict):
        raise GraphError("Product correction has no published predecessor")
    published = _product_event_pin(b, correction.get("snapshot"), PRODUCT_PUBLICATION)
    merge = published.get("mergeCommit")
    if (type(correction.get("pullRequest")) is not int or correction["pullRequest"] != 137
            or not isinstance(merge, dict) or correction.get("mergeCommit") != merge.get("oid")
            or not isinstance(merge.get("oid"), str) or not re.fullmatch(r"[0-9a-f]{40}", merge["oid"])
            or correction.get("title") != published.get("title")
            or correction.get("url") != published.get("url")
            or not isinstance(correction.get("meaning"), str) or not correction["meaning"].strip()
            or not isinstance(published.get("body"), str) or not published["body"].strip()):
        raise GraphError("Product correction published identity differs from its snapshot")
    preserved = event.get("preserved")
    publication = event.get("publication")
    expected_nodes = ["product:" + products["generation"] + ":" + unit["id"] for unit in products["units"]]
    if (event.get("generation") != products["generation"]
            or event.get("sourceGeneration") != shared["source_generation"]
            or type(event.get("sourceCount")) is not int or event["sourceCount"] != len(shared["sources"])
            or type(event.get("productCount")) is not int or event["productCount"] != len(products["units"])
            or product_nodes != expected_nodes or any(node not in b.nodes for node in expected_nodes)
            or not isinstance(preserved, dict) or preserved.get("sharedContracts") != len(shared["units"])
            or preserved.get("currentSourceRecords") != len(shared["sources"])
            or not isinstance(publication, dict) or not isinstance(publication.get("status"), str)
            or not publication["status"].strip()):
        raise GraphError("Product correction disagrees with current product/source generation")
    _product_event_pin(b, application.get("productManifest"), PRODUCT_MANIFEST)
    if (application.get("schema") != "sao-c-product-application/1"
            or application.get("standing") != "LOCAL_APPLIED_PUBLIC_RECONCILIATION_PENDING"
            or event.get("standing") != application["standing"]
            or application.get("generation") != event["generation"]
            or type(application.get("productCount")) is not int or application["productCount"] != event["productCount"]
            or type(application.get("sourceCount")) is not int or application["sourceCount"] != event["sourceCount"]
            or application.get("ownershipContractsRetained") != len(shared["units"])
            or not isinstance(application.get("atUtc"), str) or not application["atUtc"].strip()
            or not isinstance(application.get("boundary"), str) or not application["boundary"].strip()
            or not isinstance(application.get("version"), str)
            or not re.fullmatch(r"\d+\.\d+\.\d+\.\d+-pre-alpha", application["version"])):
        raise GraphError("Product correction application disagrees with its generation")
    previous = "event:catalogue-compression:C:20261003"
    if previous not in b.nodes:
        raise GraphError("Product correction has no retained predecessor event")
    src = b.source(PRODUCT_TRANSITION)
    evidence = [src, b.source(PRODUCT_TRANSITION_RECORD), b.source(PRODUCT_APPLICATION),
                b.source(PRODUCT_PUBLICATION), b.source(PRODUCT_MANIFEST), b.source(MANIFEST)]
    node = b.node("event:" + event["id"], "catalogue-event", "C product catalogue correction",
                  correction["meaning"], evidence, ["C", "product-consolidation", event["generation"]],
                  status(application["standing"], "Pinned local application and catalogue metadata; component evidence retains its scope.", publication["status"]),
                  generation=event["generation"], sourceGeneration=event["sourceGeneration"],
                  recordedAt=application["atUtc"], versionAtApplication=application["version"],
                  correctedPullRequest=correction["pullRequest"], remaining=[application["boundary"]])
    b.edge(node, previous, "corrects", [src, b.source(PRODUCT_PUBLICATION)],
           "Corrects the product-consolidation interpretation; the 35-contract ownership mapping remains preserved.")
    b.edge(previous, node, "chronology", [src, b.source(PRODUCT_APPLICATION)],
           "The recorded 2026-10-03 mapping precedes its dated 2026-10-05 product correction.")
    for product in product_nodes:
        b.edge(node, product, "records", [src, b.source(PRODUCT_APPLICATION), b.source(PRODUCT_MANIFEST)],
               "The applied correction records this current product classification without additional version or runtime credit.")
    b.named_ref(node, "commit", merge["oid"], b.source(PRODUCT_PUBLICATION, "/mergeCommit/oid"),
                "Exact PR137 merge identity retained by the corrective event's publication snapshot.")


def _active_batch(b):
    """Retain indexed D-and-later records and the explicitly active batch.

    Closure preserves declared predecessors and dependencies. Implementation,
    verification and publication remain separate source-recorded dimensions.
    """
    index = "BATCH_LOG.md"
    text = b.read(index)
    active = re.findall(r"^Active: \[([A-Z]\d+) — ([^\]]+)\]\(([^)]+)\)", text, re.M)
    if len(active) > 1 or text.count("Active:") != len(active):
        raise GraphError("Invalid active batch index")
    delivered = re.findall(r"^\| \[([D-Z]\d+)\]\(([^)]+)\) \| [^|]+ \| ([^|]+) \|", text, re.M)
    entries = [(label, name.strip(), path, False) for label, path, name in delivered]
    entries.extend((label, name, path, True) for label, name, path in active)
    if len({label for label, _, _, _ in entries}) != len(entries):
        raise GraphError("Duplicate indexed batch identity")
    for label, name, path, is_active in entries:
        _indexed_batch(b, index, label, name, path, is_active)


def _indexed_batch(b, index, label, name, path, is_active):
    record = b.read(path)
    expected_status = "OPEN -" if is_active else "CLOSED -"
    if (metadata(record, "Batch") != label or metadata(record, "Name") != name
            or not metadata(record, "Status").startswith(expected_status)
            or "batch:" + label in b.nodes or label.startswith("C")):
        raise GraphError("Indexed batch identity or " + ("open status" if is_active else "closed status") + " disagrees with its record")
    previous = metadata(record, "Follows")
    if previous not in b.nodes:
        raise GraphError("Active batch has an absent chronology predecessor")
    fields = [metadata(record, key) for key in ("Implementation", "Verification", "Publication")]
    if not all(fields):
        raise GraphError("Active batch needs explicit implementation, verification and publication status")
    contracts = [v.strip() for v in metadata(record, "Shared contracts").split(",")]
    if (not contracts or len(set(contracts)) != len(contracts)
            or any("contract:20261003:" + v not in b.nodes for v in contracts)):
        raise GraphError("Active batch has invalid declared shared contracts")
    source = b.source(path)
    era = "era:" + label[0]
    b.node(era, "era", "Era " + label[0], "Recorded letter era; status belongs to its component records.",
           [source], [label[0]])
    node = b.node("batch:" + label, "active-batch" if is_active else "batch", label + " · " + name,
                  record_summary(record.split("## Outcome", 1)[-1]),
                  [b.source(index, "Active batch" if is_active else label), source],
                  [label[0], "active" if is_active else "delivered"], status(*fields),
                  recordedStatus=metadata(record, "Status"), recordedAt=metadata(record, "Opened"),
                  closedAt=metadata(record, "Closed") if not is_active else "")
    b.edge(previous, node, "chronology", [source], "The batch explicitly follows this preserved event or record.")
    b.edge(node, era, "concept-membership", [source], "The authoritative index records this numbered batch in its letter era.")
    for contract in contracts:
        b.edge(node, "contract:20261003:" + contract, "depends-on", [source],
               "This batch declares the shared contract as an inherited implementation boundary.")
    branch = metadata(record, "Branch")
    if branch:
        b.named_ref(node, "branch", branch, source, "Working branch recorded for the active batch; no publication is inferred.")


def build_graph(root=ROOT, require_manifest=True):
    b = Builder(root)
    producer = "tools/development_graph.py"
    if (b.root / producer).is_file():
        b.read(producer)
    by_label, texts = _historical_records(b)
    _threads(b, by_label, texts)
    _raw_generation(b, by_label)
    ready = _current_catalogue(b, by_label)
    if require_manifest and not ready:
        raise GraphError("Current shared-boundary manifest is required for production generation")
    _local_reasoning(b, by_label)
    if ready:
        _catalogue_transition(b, by_label)
        products = _product_catalogue(b, by_label)
        _product_transition(b, products)
        _active_batch(b)
        if "batch:D1" in b.nodes:
            from catalogue import PRODUCT_MANIFEST
            b.edge(products[-1], "batch:D1", "chronology", [b.source(PRODUCT_MANIFEST), b.source("BATCH_LOG.md")],
                   "Delivered D follows the current C product chronology; its recorded contract predecessor remains preserved.")
    graph = {"schema": SCHEMA, "projectRef": "project:survivor-awareness", "sourceVector": [{"sourceRef": p, "revision": rev} for p, rev in sorted(b.vector.items())],
             "nodes": sorted(b.nodes.values(), key=lambda n: n["id"]), "edges": sorted(b.edges.values(), key=lambda e: e["id"]),
             "views": [
                 {"id": "contracts", "label": "Current shared contracts", "nodeKinds": ["contract", "extension", "batch", "active-batch"], "relations": ["depends-on", "contributes-to", "records"]},
                 {"id": "ownership", "label": "Contracts, owners and interfaces", "nodeKinds": ["contract", "owner", "interface", "extension", "batch", "active-batch"], "relations": ["shares-owner", "depends-on", "records"]},
                 {"id": "continuity", "label": "Contribution continuity", "nodeKinds": ["raw-record", "source-record", "contract", "extension", "catalogue-event", "batch", "active-batch"], "relations": ["contributes-to", "records", "depends-on", "chronology"]},
                 {"id": "chronology", "label": "Recorded source chronology", "nodeKinds": ["batch", "source-record", "era", "extension", "catalogue-event", "active-batch"], "relations": ["chronology", "concept-membership"]},
                 {"id": "concepts", "label": "Recorded concepts and threads", "nodeKinds": ["batch", "source-record", "concept", "era", "active-batch"], "relations": ["concept-membership"]},
                 {"id": "provenance", "label": "Recorded branches and commits", "nodeKinds": ["branch", "commit", "batch", "raw-record", "source-record", "extension", "era", "active-batch"], "relations": ["records"]},
                 {"id": "all", "label": "All recorded relations", "nodeKinds": sorted({n["kind"] for n in b.nodes.values()}), "relations": sorted(RELATIONS)}]}
    for view in graph["views"]:
        if view["id"] != "all":
            view["nodeKinds"].append("product-batch")
        if view["id"] == "continuity":
            view["relations"].append("product-contribution")
            view["relations"].append("corrects")
        if view["id"] == "provenance":
            view["nodeKinds"].append("catalogue-event")
    kinds = {node["kind"] for node in graph["nodes"]}
    for view in graph["views"]:
        view["nodeKinds"] = [kind for kind in view["nodeKinds"] if kind in kinds]
    graph["revision"] = digest(canonical(graph))
    validate_graph(graph)
    return graph


def validate_graph(graph):
    if graph.get("schema") != SCHEMA or graph.get("projectRef") != "project:survivor-awareness":
        raise GraphError("Wrong continuity schema or project identity")
    revision = graph.get("revision")
    if not isinstance(revision, str) or not SHA.fullmatch(revision):
        raise GraphError("Graph revision must be a SHA-256 content revision")
    body = {k: v for k, v in graph.items() if k != "revision"}
    if digest(canonical(body)) != revision:
        raise GraphError("Graph content does not match its revision")
    vector = {}
    for item in graph["sourceVector"]:
        path, rev = item["sourceRef"], item["revision"]
        if not safe_path(path) or not SHA.fullmatch(rev) or path in vector:
            raise GraphError("Malformed or duplicate sourceVector entry")
        vector[path] = rev
    def sources(items):
        if not isinstance(items, list) or not items:
            raise GraphError("Every node and relation requires nonempty provenance")
        for item in items:
            if vector.get(item.get("path")) != item.get("revision") or item.get("path") not in vector:
                raise GraphError("Provenance revision must match sourceVector")
    ids = set()
    kinds = set()
    for node in graph["nodes"]:
        if not isinstance(node["id"], str) or not node["id"] or node["id"] in ids:
            raise GraphError("Duplicate or empty node id")
        ids.add(node["id"])
        kinds.add(node["kind"])
        if not all(isinstance(node.get(k), str) and node[k] for k in ("kind", "label", "summary")):
            raise GraphError("Node presentation fields must be nonempty strings")
        if not all(isinstance(node.get("status", {}).get(k), str) and node["status"][k] for k in ("implementation", "verification", "publication")):
            raise GraphError("Node status must preserve three explicit dimensions")
        if not isinstance(node.get("tags"), list) or not all(isinstance(t, str) for t in node["tags"]):
            raise GraphError("Node tags must be a string list")
        sources(node.get("sources"))
        for media in node.get("mediaRefs", []):
            if media.get("kind") not in ("image", "audio", "video") or not safe_path(media.get("href")):
                raise GraphError("Unsafe optional media reference")
    edges = set()
    for edge in graph["edges"]:
        if edge["id"] in edges or edge["from"] not in ids or edge["to"] not in ids:
            raise GraphError("Duplicate relation id or dangling relation endpoint")
        edges.add(edge["id"])
        if edge["relation"] not in RELATIONS or edge["evidenceClass"] not in EVIDENCE or not edge.get("rationale"):
            raise GraphError("Unknown relation/evidence class or missing rationale")
        sources(edge.get("provenance"))
    view_ids = set()
    for view in graph["views"]:
        if view["id"] in view_ids or not set(view["nodeKinds"]) <= kinds or not set(view["relations"]) <= RELATIONS:
            raise GraphError("Duplicate or malformed graph view")
        view_ids.add(view["id"])


def render_html(graph):
    validate_graph(graph)
    payload = json.dumps(graph, ensure_ascii=False, separators=(",", ":")).replace("&", "\\u0026").replace("<", "\\u003c").replace("\u2028", "\\u2028").replace("\u2029", "\\u2029")
    return HTML.replace("__GRAPH_JSON__", payload)


def artifacts(graph):
    return {"development-graph.json": json.dumps(graph, ensure_ascii=False, indent=2) + "\n", "index.html": render_html(graph)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--write", action="store_true")
    mode.add_argument("--check", action="store_true")
    args = parser.parse_args()
    try:
        graph = build_graph()
        rendered = artifacts(graph)
        if args.write:
            out = ROOT / OUTPUT
            out.mkdir(parents=True, exist_ok=True)
            for name, text in rendered.items():
                (out / name).write_text(text, encoding="utf-8", newline="\n")
        if args.check:
            for name, text in rendered.items():
                path = ROOT / OUTPUT / name
                if not path.is_file() or path.read_text(encoding="utf-8") != text:
                    raise GraphError("Generated artifact is absent or stale: " + str(path.relative_to(ROOT)))
        print(json.dumps({"status": "PASS", "schema": SCHEMA, "revision": graph["revision"], "nodes": len(graph["nodes"]), "edges": len(graph["edges"]), "sources": len(graph["sourceVector"]), "written": args.write, "currencyChecked": args.check}))
        return 0
    except (GraphError, ValueError, KeyError, OSError) as exc:
        print("FAIL: " + str(exc), file=sys.stderr)
        return 1


HTML = r'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>SAO development continuity</title><style>
:root{color-scheme:dark;font:15px system-ui,sans-serif;background:#10171e;color:#e4edf5}*{box-sizing:border-box}body{margin:0}header{padding:18px 24px;border-bottom:1px solid #354454;display:flex;align-items:center;gap:20px;flex-wrap:wrap}h1{font-size:21px;margin:0}header p{margin:4px 0;color:#a8bacb;font-size:13px}#controls{padding:12px 24px;display:flex;gap:10px;align-items:center;flex-wrap:wrap;border-bottom:1px solid #354454}input,select,button{font:inherit;color:inherit;background:#1c2a36;border:1px solid #526273;border-radius:5px;padding:7px 10px}input{min-width:250px}button{cursor:pointer}button:hover{background:#304559}button:focus-visible,a:focus-visible{outline:2px solid #ffe198}#layout{display:grid;grid-template-columns:minmax(0,1fr) 380px;height:calc(100vh - 175px);min-height:400px}#stage{position:relative;overflow:hidden;background:radial-gradient(#33404c 1px,transparent 1px);background-size:22px 22px}svg{width:100%;height:100%;touch-action:none}#details{overflow:auto;padding:22px;border-left:1px solid #354454}#details h2{font-size:20px;margin:0 0 12px}#details h3{font-size:14px;color:#bacddd;margin:22px 0 7px}#details p,#details li{line-height:1.55;overflow-wrap:anywhere}#details ul{padding-left:18px}a{color:#9bceff}code{font-size:12px;overflow-wrap:anywhere}small{color:#afc0ce}#counts{margin-left:auto;font-size:13px;color:#bacddd}.node{cursor:pointer}.node rect{fill:#213241;stroke:#688195;stroke-width:1.2}.node.contract rect{fill:#244c47;stroke:#78d8b9}.node.extension rect{fill:#4d3d23;stroke:#e9ba67}.node.active-batch rect{fill:#243e5d;stroke:#9bcaff}.node.raw-record rect{fill:#342e43;stroke:#a193c1}.node.selected rect{stroke:#ffe198;stroke-width:3}.node text{fill:#eef5fa;font-size:14px;pointer-events:none}.node .kind{fill:#b0c5d3;font-size:10px}.edge{stroke:#58748d;stroke-width:1;fill:none;opacity:.3;cursor:pointer}.edge:hover,.edge.selected{stroke:#ffe198;stroke-width:2;opacity:1}.edge.depends-on{stroke:#80d7b3;opacity:.6}.lane{fill:#b2c7d6;font-size:14px;font-weight:600}.badge{display:inline-block;font-size:11px;padding:3px 7px;margin:3px 5px 3px 0;background:#2b3e4c;border-radius:4px}#empty{display:none;position:absolute;inset:35% 10%;text-align:center;color:#bfced9}#legend{position:absolute;bottom:12px;left:16px;background:#14222ee8;padding:8px 12px;font-size:12px;color:#bfcfdb;border-radius:5px}#relations button{display:block;text-align:left;width:100%;margin:5px 0;font-size:12px}#source-list li{margin:8px 0}@media(max-width:850px){#layout{grid-template-columns:1fr;height:auto}#stage{height:65vh}#details{border-left:0;border-top:1px solid #354454;max-height:65vh}header,#controls{padding:12px}input{min-width:170px}}
</style></head><body><header><div><h1>SAO development continuity</h1><p>Product chronology, shared contracts and measured component status</p></div><small id="revision"></small></header>
<div id="controls"><label>View <select id="view"></select></label><label>Search <input id="search" type="search" placeholder="Batch, owner, concept or phrase"></label><label>Relation <select id="relation"><option value="">All in view</option></select></label><button id="fit">Fit</button><button id="zoomin" aria-label="Zoom in">+</button><button id="zoomout" aria-label="Zoom out">−</button><button id="clear">Clear selection</button><span id="counts" aria-live="polite"></span></div>
<main id="layout"><section id="stage" aria-label="Interactive development graph"><svg id="graph" role="img" aria-label="Development relations; select a node to inspect its sources" tabindex="0"><defs><marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M 0 0 L 10 5 L 0 10 z" fill="#86a1b6"/></marker></defs><g id="viewport"></g></svg><div id="empty">No matching nodes. Change the view or search.</div><div id="legend">Drag to pan · wheel or ± to zoom · select for evidence</div></section><aside id="details" aria-label="Selected graph evidence"></aside></main>
<script type="application/json" id="graph-data">__GRAPH_JSON__</script><script>
'use strict';
const data=JSON.parse(document.getElementById('graph-data').textContent),byId=new Map(data.nodes.map(n=>[n.id,n]));
const $=id=>document.getElementById(id),NS='http://www.w3.org/2000/svg',svg=$('graph'),port=$('viewport');let selected=null,visible=[],activeEdges=[],positions=new Map(),zoom=1,px=20,py=30,drag=null,focused=null;
const el=(tag,text,parent,cls)=>{const e=document.createElement(tag);if(text!==undefined)e.textContent=text;if(cls)e.className=cls;if(parent)parent.append(e);return e;};
const sv=(tag,attrs,parent)=>{const e=document.createElementNS(NS,tag);for(const [k,v]of Object.entries(attrs))e.setAttribute(k,String(v));if(parent)parent.append(e);return e;};
function safeLink(path){if(typeof path!=='string')return null;let p;try{p=decodeURIComponent(path)}catch{return null}if(!p||/[:\\?#\x00-\x1f]/.test(p)||p.startsWith('/')||p.split('/').some(x=>!x||x==='.'||x==='..'))return null;return '../../'+p.split('/').map(encodeURIComponent).join('/')}
function sourceList(sources){const ul=el('ul',undefined,$('details'));ul.id='source-list';for(const s of sources){const li=el('li',undefined,ul),href=safeLink(s.path);if(href){const a=el('a',s.path,li);a.href=href;a.target='_blank';a.rel='noopener noreferrer'}else el('span',s.path,li);if(s.locator)el('div',s.locator,li);el('code',s.revision,li)}}
function transform(){port.setAttribute('transform',`translate(${px},${py}) scale(${zoom})`)}
function fit(){if(!positions.size)return;const ps=[...positions.values()],w=Math.max(...ps.map(p=>p.x))+270,h=Math.max(...ps.map(p=>p.y))+65;zoom=Math.max(.035,Math.min(1.2,(svg.clientWidth-40)/w,(svg.clientHeight-50)/h));px=(svg.clientWidth-w*zoom)/2;py=30;transform()}
function introduction(){const d=$('details');d.replaceChildren();el('h2','Explore the recorded development',d);el('p','Select a shared contract to inspect its owners, interfaces, delivered baseline and remaining work. Current C products partition source chronology. The separate 35-contract map records shared boundaries; both retain their source generations.',d);el('h3','How to read the graph',d);el('p','Arrows retain their stated relation. A recorded mention, a shared owner and a contribution are different from an explicit dependency. Current contract order does not recreate a chronological source history.',d);el('p','Original C1–C127, preserved C1–C120 and current product and shared-contract C labels have separate node identities. Git archive paths are displayed as metadata, not working-file links.',d);el('p','Implementation, verification and publication are independent. Component evidence does not close broader contract extensions or rendered acceptance.',d);el('h3','Snapshot',d);el('p',`${data.nodes.length} nodes · ${data.edges.length} relations · ${data.sourceVector.length} pinned input files`,d);el('code',data.revision,d);const a=el('a','Machine-readable JSON',el('p',undefined,d));a.href='development-graph.json'}
function selectNode(id){selected=id;const n=byId.get(id),d=$('details');d.replaceChildren();el('h2',n.label,d);el('span',n.kind,d,'badge');for(const tag of n.tags)el('span',tag,d,'badge');el('p',n.summary,d);el('h3','Measured status',d);for(const [k,v]of Object.entries(n.status))el('p',`${k}: ${v}`,d);if(n.measuredStatusNote)el('p',n.measuredStatusNote,d);if(n.recordedStatus)el('p','Original record status: '+n.recordedStatus,d);for(const key of ['remaining','state','inputs','outputs'])if(n[key]?.length){el('h3',key.charAt(0).toUpperCase()+key.slice(1),d);const ul=el('ul',undefined,d);for(const t of n[key])el('li',t,ul)}if(n.archiveRef){el('h3','Archived Git blob',d);el('p',n.archiveRef+' : '+n.archivePath,d);el('code',n.blobRevision,d)}if(n.ownerPath){el('h3','Declared owner',d);const href=safeLink(n.ownerPath);if(href){const a=el('a',n.ownerPath,d);a.href=href;a.target='_blank';a.rel='noopener noreferrer'}}if(n.mediaRefs?.length){el('h3','Optional media references',d);for(const m of n.mediaRefs)el('p',`${m.label||m.kind}: ${m.href}`,d)}el('h3','Sources and revisions',d);sourceList(n.sources);el('h3','Recorded relations',d);const focus=el('button','Show this node and its neighbours',d);focus.onclick=()=>{focused=id;$('search').value='';$('view').value='all';$('relation').value='';render();fit()};const list=el('div',undefined,d);list.id='relations';for(const e of data.edges.filter(e=>e.from===id||e.to===id)){const other=byId.get(e.from===id?e.to:e.from);const button=el('button',`${e.from===id?'→':'←'} ${e.relation} · ${other.label}`,list);button.onclick=()=>selectEdge(e)}highlight()}
function selectEdge(e){selected=e.id;const d=$('details');d.replaceChildren();el('h2',e.relation,d);el('span',e.evidenceClass,d,'badge');for(const [label,id]of [['From',e.from],['To',e.to]]){const p=el('p',label+': ',d),button=el('button',byId.get(id).label,p);button.onclick=()=>selectNode(id)}el('p',e.rationale,d);el('h3','Relation provenance',d);sourceList(e.provenance);highlight()}
function highlight(){for(const g of port.querySelectorAll('[data-id]'))g.classList.toggle('selected',g.getAttribute('data-id')===selected)}
function render(){const view=data.views.find(v=>v.id===$('view').value),q=$('search').value.trim().toLowerCase(),rel=$('relation').value;const neighbours=focused?new Set([focused,...data.edges.filter(e=>e.from===focused||e.to===focused).flatMap(e=>[e.from,e.to])]):null;visible=data.nodes.filter(n=>view.nodeKinds.includes(n.kind)&&(!neighbours||neighbours.has(n.id))&&(!q||[n.label,n.summary,...n.tags].join(' ').toLowerCase().includes(q)));const ids=new Set(visible.map(n=>n.id));activeEdges=data.edges.filter(e=>ids.has(e.from)&&ids.has(e.to)&&view.relations.includes(e.relation)&&(!rel||e.relation===rel));positions=new Map();port.replaceChildren();const priority=['era','raw-record','batch','source-record','product-batch','contract','extension','active-batch','catalogue-event','owner','interface','concept','branch','commit'];const kinds=[...new Set(visible.map(n=>n.kind))].sort((a,b)=>priority.indexOf(a)-priority.indexOf(b));let columnOffset=0;kinds.forEach(kind=>{const list=visible.filter(n=>n.kind===kind).sort((a,b)=>a.label.localeCompare(b.label,undefined,{numeric:true}));const columns=Math.min(5,Math.max(1,Math.ceil(Math.sqrt(list.length*Math.max(.5,svg.clientWidth/svg.clientHeight)*77/300)))),rows=Math.ceil(list.length/columns);sv('text',{x:columnOffset*300,y:-12,class:'lane'},port).textContent=kind+' · '+list.length;list.forEach((n,i)=>positions.set(n.id,{x:(columnOffset+Math.floor(i/rows))*300,y:(i%rows)*77}));columnOffset+=columns});for(const e of activeEdges){const a=positions.get(e.from),b=positions.get(e.to),same=a.x===b.x;const path=sv('path',{d:same?`M${a.x+254},${a.y+25} C${a.x+315},${a.y+25} ${b.x+315},${b.y+25} ${b.x+254},${b.y+25}`:`M${a.x+254},${a.y+25} C${(a.x+b.x+254)/2},${a.y+25} ${(a.x+b.x+254)/2},${b.y+25} ${b.x},${b.y+25}`,class:'edge '+e.relation,'marker-end':'url(#arrow)','data-id':e.id},port);path.onclick=event=>{event.stopPropagation();selectEdge(e)}}for(const n of visible){const p=positions.get(n.id),g=sv('g',{transform:`translate(${p.x},${p.y})`,class:'node '+n.kind,'data-id':n.id,tabindex:0,role:'button','aria-label':n.label},port);sv('rect',{width:254,height:55,rx:6},g);sv('text',{x:12,y:20},g).textContent=n.label.length>36?n.label.slice(0,35)+'…':n.label;sv('text',{x:12,y:41,class:'kind'},g).textContent=n.kind+' · '+n.status.publication;sv('title',{},g).textContent=n.label;g.onclick=event=>{event.stopPropagation();selectNode(n.id)};g.onkeydown=event=>{if(event.key==='Enter'||event.key===' '){event.preventDefault();selectNode(n.id)}}}$('empty').style.display=visible.length?'none':'block';$('counts').textContent=`${visible.length} nodes · ${activeEdges.length} relations`;highlight();transform()}
for(const v of data.views){const o=el('option',v.label,$('view'));o.value=v.id}for(const r of [...new Set(data.edges.map(e=>e.relation))].sort()){const o=el('option',r,$('relation'));o.value=r}$('revision').textContent='Snapshot '+data.revision.slice(7,19);$('view').onchange=()=>{focused=null;render();fit()};$('search').oninput=()=>{focused=null;render();fit()};$('relation').onchange=render;$('fit').onclick=fit;$('clear').onclick=()=>{focused=null;selected=null;introduction();render();fit()};function scale(f,cx=svg.clientWidth/2,cy=svg.clientHeight/2){const z=Math.max(.02,Math.min(6,zoom*f)),ratio=z/zoom;px=cx-(cx-px)*ratio;py=cy-(cy-py)*ratio;zoom=z;transform()}$('zoomin').onclick=()=>scale(1.3);$('zoomout').onclick=()=>scale(1/1.3);svg.addEventListener('wheel',e=>{e.preventDefault();const r=svg.getBoundingClientRect();scale(e.deltaY<0?1.12:1/1.12,e.clientX-r.left,e.clientY-r.top)},{passive:false});svg.addEventListener('pointerdown',e=>{if(e.target.closest('.node,.edge'))return;drag={x:e.clientX,y:e.clientY,px,py};svg.setPointerCapture(e.pointerId)});svg.addEventListener('pointermove',e=>{if(drag){px=drag.px+e.clientX-drag.x;py=drag.py+e.clientY-drag.y;transform()}});svg.addEventListener('pointerup',()=>drag=null);svg.addEventListener('pointercancel',()=>drag=null);svg.addEventListener('keydown',e=>{if(e.key==='+')scale(1.3);else if(e.key==='-')scale(1/1.3);else if(e.key==='0')fit()});window.addEventListener('resize',fit);introduction();render();fit();
</script></body></html>
'''


if __name__ == "__main__":
    raise SystemExit(main())
