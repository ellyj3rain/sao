"""Consumer controls for passive start records; all body fixtures are synthetic."""
import unittest
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import world_lab_participant_feed as Feed
import world_lab_start_context as Start

MOUSECAT_VALIDATOR = Path(os.environ.get("MOUSECAT_REPO", str(Path(__file__).resolve().parents[2] / "mousecat-development-continuity"))) / "src/core/native-view.mjs"


def fixture():
    body = {"schema": "sao-native-participant/1", "sessionId": "00000000-0000-4000-8000-000000000004",
            "pid": 123, "attempt": 1, "saveMode": "Sandbox", "save": "fixture-save", "playerIndex": 0,
            "playerSqlId": 1, "capturedAtUnixMs": 10000, "worldHours": 2.5, "ready": True,
            "displayFocused": True, "alive": True, "body": {"x": 1, "y": 2, "z": 0, "label": "Synthetic player"}}
    record = lambda: {"sourceKey": None, "status": "absent", "values": {}, "invalidFields": [], "note": "No start record."}
    context = {"schema": Start.SCHEMA, "observed": True, "available": True,
               "whereIWas": record(), "tiyl": record(), "scenarioReady": None}
    body["startContext"] = {"capturedAtUnixMs": 9900, "worldHours": 2.4, "context": context}
    receipt = {"sessionId": body["sessionId"], "pid": 123, "save": None, "launchMode": "native-menu"}
    return body, receipt


class NativeStartFeed(unittest.TestCase):
    def accept(self, body, receipt): return Feed.validate_body(body, receipt, now=10000)
    def reject(self, body, receipt):
        with self.assertRaises((ValueError, AssertionError)): self.accept(body, receipt)

    def test_legacy_and_original_native_samples_remain_accepted(self):
        body, receipt = fixture(); body.pop("startContext"); self.accept(body, receipt)
        body.pop("saveMode"); receipt.pop("launchMode"); self.accept(body, receipt)

    def test_start_has_independent_clock_and_human_projection(self):
        body, receipt = fixture(); self.accept(body, receipt)
        section = Start.person_section(body["startContext"])
        self.assertEqual(section["rows"][-2]["value"], "9900")
        self.assertEqual(section["rows"][-1]["value"], "2.4")
        self.assertEqual(section["label"], "Character start")

    def test_observer_context_cannot_gain_native_start_authority(self):
        body, receipt = fixture(); receipt.pop("launchMode"); body.pop("saveMode"); self.reject(body, receipt)

    def test_future_and_regressed_source_world_clock_are_rejected(self):
        for field, value in [("capturedAtUnixMs", 10001), ("worldHours", 2.6), ("worldHours", float("nan")), ("worldHours", True)]:
            with self.subTest(field=field, value=value):
                body, receipt = fixture(); body["startContext"][field] = value; self.reject(body, receipt)

    def test_unbound_or_unobserved_player_cannot_claim_context(self):
        body, receipt = fixture(); body.pop("body"); body.update(ready=False, playerSqlId=-1); self.reject(body, receipt)
        body, receipt = fixture(); body["startContext"]["context"]["observed"] = False; self.reject(body, receipt)

    def test_pending_scenario_does_not_become_safe_ready(self):
        body, receipt = fixture(); context = body["startContext"]["context"]
        context["whereIWas"].update(sourceKey="WhereIWas", status="pending", values={"scenario": "Tourist", "setupComplete": False, "lifecycleProtected": True})
        context["scenarioReady"] = False; self.accept(body, receipt)
        context["scenarioReady"] = True; self.reject(body, receipt)

    def test_complete_legacy_setup_has_unknown_protection(self):
        body, receipt = fixture(); context = body["startContext"]["context"]
        context["whereIWas"].update(sourceKey="KnoxScenarios", status="ready", values={"scenario": "Tourist", "setupComplete": True, "lifecycleState": "ready"})
        self.accept(body, receipt); context["scenarioReady"] = True; self.reject(body, receipt)
        context["whereIWas"]["values"].update(setupFailed=False, lifecycleProtected=False); self.accept(body, receipt)

    def test_background_requires_server_applied_placement_for_ready(self):
        body, receipt = fixture(); life = body["startContext"]["context"]["tiyl"]
        life.update(sourceKey="TIYL", status="unknown", values={"originId": "fixture-origin", "scriptedStartId": "partner"})
        self.accept(body, receipt); life["status"] = "ready"; self.reject(body, receipt)
        life["values"].update(originSpawnApplied=True, serverOriginRegistered=True, originSpawnPending=False); self.accept(body, receipt)
        life["values"]["scriptedStartState"] = "failed"; self.reject(body, receipt)

    def test_invalid_and_unavailable_records_preserve_uncertainty(self):
        body, receipt = fixture(); context = body["startContext"]["context"]
        context["whereIWas"].update(sourceKey="WhereIWas", status="invalid", invalidFields=["setupComplete"])
        self.accept(body, receipt)
        context["available"] = False; self.reject(body, receipt)
        for record in [context["whereIWas"], context["tiyl"]]: record.update(sourceKey=None, status="unknown", values={}, invalidFields=[])
        self.accept(body, receipt); context["scenarioReady"] = True; self.reject(body, receipt)

    @unittest.skipUnless(shutil.which("node") and MOUSECAT_VALIDATOR.is_file(), "actual Mousecat validator checkout and Node required")
    def test_native_producer_to_mousecat_validator_preserves_available_and_unavailable_start(self):
        import world_lab_native_play as Native
        from world_lab_native_play04_test import Fixture
        script = "import {readFileSync} from 'node:fs'; const {validateNativeView}=await import(process.argv[1]); validateNativeView(JSON.parse(readFileSync(0,'utf8'))); console.log('PASS');"
        for state in ("absent", "unavailable", "pending", "failed", "invalid", "unicode"):
            with self.subTest(state=state), tempfile.TemporaryDirectory(prefix="sao-start-projection-controlled-") as directory:
                f = Fixture(Path(directory)); f.out.mkdir()
                receipt = f.receipt(); Feed.atomic(f.out / "participant-run/run.json", receipt)
                body = f.body(); sample = fixture()[0]["startContext"]
                sample.update(capturedAtUnixMs=body["capturedAtUnixMs"]-1, worldHours=body["worldHours"]-0.001)
                context = sample["context"]
                if state == "unavailable":
                    context["available"] = False
                    for record in (context["whereIWas"], context["tiyl"]):
                        record.update(status="unknown", note="Native own-key map unavailable.")
                elif state in ("pending", "failed"):
                    context["whereIWas"].update(sourceKey="WhereIWas", status=state,
                        values={"scenario":"Tourist", "setupComplete":False, "setupFailed":state=="failed"})
                    context["scenarioReady"] = False
                elif state == "invalid":
                    context["whereIWas"].update(sourceKey="WhereIWas", status="invalid", invalidFields=["scenario"],
                        note="The source classified its scenario text invalid.")
                elif state == "unicode":
                    context["whereIWas"].update(sourceKey="WhereIWas", status="unknown", values={"scenario":"\U0001f680"*80},
                        note="Saved scenario fields are present; setup readiness is unknown.")
                body["startContext"] = sample
                Feed.validate_body(body, receipt, now=f.now)
                f.write_sources(body)
                producer = Native.NativePlayFeed(f.out / "participant-run", f.destination, receipt, f.session)
                self.assertTrue(producer.publish_play())
                value = Feed.read(f.destination / "latest.json")[1]
                section = value["people"][0]["sections"][-1]
                self.assertEqual(section["status"], "unavailable" if state == "unavailable" else "available")
                self.assertEqual(context["whereIWas"]["status"], "unknown" if state in ("unavailable", "unicode") else state)
                checked = subprocess.run(["node", "--input-type=module", "-e", script, MOUSECAT_VALIDATOR.resolve().as_uri()],
                    input=json.dumps(value), capture_output=True, text=True, encoding="utf-8", timeout=15)
                self.assertEqual(checked.returncode, 0, checked.stderr)
                self.assertEqual(checked.stdout.strip(), "PASS")
                if state == "unavailable":
                    self.assertIn("Not confirmed", [row["value"] for row in section["rows"]])
                    self.assertIn("Native own-key map unavailable.", section["message"])
                elif state == "unicode":
                    self.assertEqual(section["rows"][0]["value"], "\U0001f680"*80)

    def test_protocol_unsafe_text_is_rejected_and_native_utf16_limit_is_preserved(self):
        bad = ["\ud800", "\udc00", "x\x00y", "x\x08y", "x\x0by", "x\x0cy", "x\x1fy"]
        for text in bad:
            for target in ("scenario", "note"):
                with self.subTest(text=repr(text), target=target):
                    body, receipt = fixture(); record = body["startContext"]["context"]["whereIWas"]
                    record.update(sourceKey="WhereIWas", status="unknown")
                    if target == "scenario": record["values"]["scenario"] = text
                    else: record["note"] = text
                    self.reject(body, receipt)
        body, receipt = fixture(); record = body["startContext"]["context"]["whereIWas"]
        record.update(sourceKey="WhereIWas", status="unknown", values={"scenario":"\U0001f680"*81})
        self.reject(body, receipt)
        record["values"]["scenario"] = "\U0001f680"*80
        record["note"] = "\U0001f680"*160
        self.accept(body, receipt)

    def test_bounded_exact_fields_and_native_types(self):
        mutations = [lambda c: c.update(extra=True), lambda c: c["tiyl"].update(sourceKey="Foreign"),
                     lambda c: c["tiyl"].update(note="x"*361), lambda c: c["tiyl"].update(invalidFields=["schemaVersion", "schemaVersion"]),
                     lambda c: c["tiyl"].update(sourceKey="TIYL", status="unknown", values={"schemaVersion": True}),
                     lambda c: c["tiyl"].update(sourceKey="TIYL", status="unknown", values={"originId": "x"*161}),
                     lambda c: c["tiyl"].update(sourceKey="TIYL", status="unknown", values={"originSpawnApplied": 1}),
                     lambda c: c["tiyl"].update(sourceKey="TIYL", status="unknown", values={"originSpawnX": float("inf")})]
        for index, mutate in enumerate(mutations):
            with self.subTest(index=index):
                body, receipt = fixture(); mutate(body["startContext"]["context"]); self.reject(body, receipt)


if __name__ == "__main__": unittest.main()
