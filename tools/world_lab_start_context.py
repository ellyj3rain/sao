"""Validate and present separately timed native start-flow observations."""
from __future__ import annotations

import math
import world_lab as Lab

SCHEMA = "sao-native-start-context/1"
STATUSES = {"absent", "unknown", "invalid", "pending", "ready", "failed"}
FIELDS = {
    "whereIWas": {
        "text": {"scenario", "lifecycleState", "setupFailureReason", "anchorName", "locationName"},
        "integer": {"lifecycleVersion", "kitVersion"},
        "flag": {"setupComplete", "setupFailed", "lifecycleProtected", "placementVerified",
                 "failureRestored", "failureRestoreTimedOut", "challengeFailed"},
        "number": {"originX", "originY", "originZ", "startX", "startY", "startZ", "safeX", "safeY", "safeZ"},
    },
    "tiyl": {
        "text": {"originId", "scriptedStartId", "scriptedPartnerSex", "scriptedStartState",
                 "scriptedStartInstanceId", "posterStoryId"},
        "integer": {"schemaVersion"},
        "flag": {"outcomesApplied", "originSpawnPending", "originSpawnApplied", "originTraitApplied",
                 "serverOriginRegistered", "scriptedPartnerDead", "scriptedPartnerBuried", "scriptedStartComplete"},
        "number": {"originSpawnX", "originSpawnY", "originSpawnZ"},
    },
}


def _text(value, maximum):
    Lab.require(type(value) is str, "native start text differs")
    try:
        units = len(value.encode("utf-16-le")) // 2
    except UnicodeEncodeError:
        Lab.require(False, "native start text has an unpaired surrogate")
    Lab.require(units <= maximum and not any(ord(char) < 32 and char not in "\t\n\r" for char in value),
                "native start text differs")


def validate_sample(sample, body):
    Lab.require(type(sample) is dict and set(sample) == {"capturedAtUnixMs", "worldHours", "context"},
                "native start sample fields differ")
    Lab.integer(sample["capturedAtUnixMs"], 1, body["capturedAtUnixMs"], "native start observation time")
    hours = sample["worldHours"]
    Lab.require(type(hours) in (int, float) and math.isfinite(hours) and 0 <= hours <= body["worldHours"],
                "native start world clock differs")
    context = sample["context"]
    Lab.require(type(context) is dict and set(context) == {"schema", "observed", "available", "whereIWas", "tiyl", "scenarioReady"}
                and context["schema"] == SCHEMA, "native start context fields differ")
    Lab.require(type(context["observed"]) is bool and type(context["available"]) is bool
                and context["observed"] and "body" in body, "native start body unavailable")
    Lab.require(context["scenarioReady"] is None or type(context["scenarioReady"]) is bool,
                "native scenario readiness differs")
    for name, fields in FIELDS.items():
        record = context[name]
        Lab.require(type(record) is dict and set(record) == {"sourceKey", "status", "values", "invalidFields", "note"},
                    "native start record fields differ")
        keys = (None, "WhereIWas", "KnoxScenarios") if name == "whereIWas" else (None, "TIYL")
        Lab.require(record["sourceKey"] in keys and type(record["status"]) is str and record["status"] in STATUSES,
                    "native start record owner or status differs")
        _text(record["note"], 360)
        allowed = set().union(*fields.values())
        values, invalid = record["values"], record["invalidFields"]
        Lab.require(type(values) is dict and set(values) <= allowed and type(invalid) is list
                    and len(invalid) <= len(allowed) + 1 and all(type(key) is str and key in allowed | {"$root"} for key in invalid)
                    and len(set(invalid)) == len(invalid) and not set(values).intersection(invalid),
                    "native start values or invalid fields differ")
        for key, value in values.items():
            if key in fields["text"]: _text(value, 160)
            elif key in fields["flag"]: Lab.require(type(value) is bool, "native start flag differs")
            elif key in fields["integer"]: Lab.integer(value, 0, 100000, "native start version")
            else: Lab.require(type(value) in (int, float) and math.isfinite(value) and abs(value) <= 1_000_000_000,
                              "native start coordinate differs")
        if record["status"] == "absent":
            Lab.require(record["sourceKey"] is None and not values and not invalid, "absent native start record contains data")
        if not context["available"]:
            Lab.require(record["status"] == "unknown" and record["sourceKey"] is None and not values and not invalid,
                        "unavailable native start context contains asserted data")
        if values or record["status"] in {"pending", "ready", "failed"}:
            Lab.require(record["sourceKey"] is not None, "native start data has no source root")
        if invalid: Lab.require(record["status"] == "invalid", "invalid native start fields claim another status")
        if record["status"] == "ready":
            Lab.require(not invalid, "invalid native start claims readiness")
            if name == "whereIWas":
                Lab.require(values.get("setupComplete") is True and values.get("lifecycleState") == "ready"
                            and type(values.get("scenario")) is str and bool(values["scenario"])
                            and values.get("setupFailed") is not True, "scenario ready without applied setup")
            else:
                Lab.require(values.get("originSpawnApplied") is True and values.get("serverOriginRegistered") is True
                            and values.get("originSpawnPending") is False and bool(values.get("originId"))
                            and values.get("scriptedStartState") != "failed",
                            "origin ready without applied server placement")
    if context["scenarioReady"] is True:
        record = context["whereIWas"]; values = record["values"]
        Lab.require(context["available"] and record["status"] == "ready" and values.get("setupFailed") is False
                    and values.get("lifecycleProtected") is False, "scenario safety readiness is unsupported")
    if not context["available"]:
        Lab.require(context["scenarioReady"] is None, "unavailable native context asserts readiness")
    return sample


def person_section(sample):
    """Human-readable facts retain their start sample clock and native root."""
    context = sample["context"]
    rows = []
    labels = {"absent": "No start record", "unknown": "Not confirmed", "invalid": "Record needs inspection",
              "pending": "Setup in progress", "ready": "Setup recorded complete", "failed": "Setup recorded a failure"}
    for name, title, identity in (("whereIWas", "Scenario", "scenario"), ("tiyl", "Background", "originId")):
        record = context[name]; values = record["values"]
        rows.append({"label": title, "value": values.get(identity) or labels[record["status"]]})
        if record["sourceKey"] is not None:
            rows.append({"label": f"{title} setup", "value": labels[record["status"]] + ". " + record["note"]})
        if name == "tiyl" and values.get("scriptedStartId"):
            rows.append({"label": "Scripted start", "value": values["scriptedStartId"]})
    if not context["available"]:
        message = "Native start records are unavailable in this sample. " + context["whereIWas"]["note"]
    elif context["scenarioReady"] is True:
        message = "The scenario recorded completed setup and released its setup protection. This sample does not establish companion admission or later success."
    else:
        message = "Start selection and applied setup are recorded separately. Companion admission and later outcomes have their own evidence."
    return {"id": "native-start-context", "label": "Character start", "source": "Native player start records",
            "perspective": "Separately timed start sample", "status": "available" if context["available"] else "unavailable",
            "message": message, "rows": rows + [{"label": "Start observed at", "value": str(sample["capturedAtUnixMs"])},
                                               {"label": "Start world hour", "value": str(sample["worldHours"])}]}
