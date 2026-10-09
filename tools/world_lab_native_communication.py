"""Source-owned native speech queue, independently timed from the framebuffer.

Mousecat's immutable command is only a request. The native game-thread receipt
establishes emission/reception/judgment; neither this bridge nor the UI invents
understanding, action completion, a controller or private knowledge.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import time

import world_lab as Lab
import world_lab_participant_feed as Feed
import world_lab_session as Session

STATE_SCHEMA = "sao.native-interaction-state/1"
WIRE_SCHEMA = "sao.native-interaction-command/1"
MAX_STATE = 128 * 1024


def text(value, maximum, *, empty=False):
    Feed.text(value, maximum, empty=empty)
    Lab.require(len(value.encode("utf-16-le")) // 2 <= maximum
                and (empty or bool(value.strip())), "native speech text boundary differs")
    return value


def fields(value, required, optional=()):
    Lab.require(isinstance(value, dict) and set(required) <= value.keys()
                and value.keys() <= set(required) | set(optional), "native communication fields differ")


def validate_state(value, receipt, now=None):
    now = int(time.time() * 1000) if now is None else now
    fields(value, ("schema", "sessionId", "pid", "attempt", "save", "saveMode", "playerIndex",
                   "playerSqlId", "capturedAtUnixMs", "gameThreadDurationNs", "worldHours", "bindingEpoch", "status", "nearby", "lastCommandSequence"),
           ("commandResult",))
    Lab.require(type(value["pid"]) is int and type(value["attempt"]) is int
                and value["schema"] == STATE_SCHEMA and value["sessionId"] == receipt["sessionId"]
                and value["pid"] == receipt["pid"] and value["attempt"] == receipt["launchNumber"],
                "native communication process identity differs")
    Lab.require(type(value["playerIndex"]) is int and value["playerIndex"] == 0
                and type(value["playerSqlId"]) is int and -1 <= value["playerSqlId"] < 2**31,
                "native communication character slot differs")
    text(value["save"], 160, empty=True); text(value["saveMode"], 80, empty=True)
    Lab.integer(value["capturedAtUnixMs"], 1, 2**53-1, "speech clock")
    Lab.require(0 <= now - value["capturedAtUnixMs"] <= 3000, "native communication sample is stale or future")
    Feed.number(value["worldHours"])
    Lab.integer(value["bindingEpoch"],0,2**53-1,"native speech body lifetime")
    Lab.integer(value["gameThreadDurationNs"],0,2**53-1,"native speech game thread duration")
    if value["status"] == "available": Lab.require(value["bindingEpoch"] > 0, "native speech lifetime unbound")
    Lab.require(value["status"] in ("available", "unavailable"), "native communication status differs")
    fields(value["nearby"], ("people", "omittedPeople", "omittedEvents"))
    for key in ("omittedPeople","omittedEvents"): Lab.integer(value["nearby"][key],0,2**53-1,"speech coverage")
    people = value["nearby"]["people"]
    Lab.require(isinstance(people, list) and len(people) <= 16
                and (value["status"] == "available" or not people), "native communication people differ")
    ids = set()
    for person in people:
        fields(person, ("id", "label", "summary", "sections", "events"))
        ident = text(person["id"], 128)
        Lab.require(ident not in ids and not ident.startswith("native-player-"), "native communication person identity differs")
        ids.add(ident); text(person["label"], 160, empty=True); text(person["summary"], 4096, empty=True)
        Lab.require(isinstance(person["sections"], list) and len(person["sections"]) == 1,
                    "native communication sections differ")
        section = person["sections"][0]
        fields(section, ("id", "label", "source", "perspective", "status", "message", "rows"))
        Lab.require(section["id"] == "native-communication" and section["status"] in ("available", "unavailable"),
                    "native communication hearing differs")
        for key, maximum in (("label",160),("source",160),("perspective",160),("message",1024)):
            text(section[key], maximum, empty=True)
        Lab.require(isinstance(section["rows"], list) and len(section["rows"]) <= 8, "native communication rows differ")
        for row in section["rows"]:
            fields(row, ("label", "value")); text(row["label"],160); text(row["value"],384,empty=True)
        Lab.require(isinstance(person["events"], list) and len(person["events"]) <= 24, "native speech events differ")
        event_ids = set()
        for event in person["events"]:
            fields(event, ("id", "capturedAtUnixMs", "worldHours", "source", "stage", "summary", "actorId", "recipientId", "correlationId"))
            text(event["id"],128); Lab.require(event["id"] not in event_ids, "native speech event repeated")
            event_ids.add(event["id"])
            Lab.integer(event["capturedAtUnixMs"],1,value["capturedAtUnixMs"],"native speech event clock")
            Feed.number(event["worldHours"], high=value["worldHours"])
            for key, maximum in (("source",160),("stage",128),("summary",1024),("actorId",128),("recipientId",128),("correlationId",128)):
                text(event[key],maximum,empty=key == "summary")
            Lab.require(event["stage"].startswith("utterance-") and event["recipientId"] == ident,
                        "native speech reception identity differs")
    Lab.integer(value["lastCommandSequence"],0,2**53-1,"native speech cursor")
    if "commandResult" in value:
        result = value["commandResult"]; fields(result, ("sequence", "status", "message"))
        Lab.require(type(result["sequence"]) is int and result["sequence"] > 0
                    and result["sequence"] == value["lastCommandSequence"]
                    and result["status"] in ("applied", "rejected", "unknown"), "native speech result differs")
        text(result["message"],512)
    else: Lab.require(value["lastCommandSequence"] == 0, "native speech cursor has no result")
    return value


def same_body(state, body):
    return bool(body and body["ready"] and body["alive"] and state["status"] == "available"
        and all(state[key] == body[key] for key in ("sessionId", "pid", "attempt", "save", "saveMode", "playerIndex", "playerSqlId"))
        and abs(state["capturedAtUnixMs"] - body["capturedAtUnixMs"]) <= 3000
        and (state["worldHours"] >= body["worldHours"] if state["capturedAtUnixMs"] >= body["capturedAtUnixMs"]
             else body["worldHours"] >= state["worldHours"]))


class NativeCommunication:
    def __init__(self, attempt, destination, receipt, evidence_root):
        self.directory = Path(attempt) / "interaction"
        self.destination, self.receipt, self.evidence = Path(destination), receipt, Path(evidence_root)
        self.version = None; self.raw = None; self.state = None
        self.forwarded = None; self.result = None; self.cursor = 0
        self.last_archived = None

    def sample(self, now=None):
        path = self.directory / "state.json"
        version = Feed.source_version(path, MAX_STATE, optional=True)
        if version is None: return None
        if version != self.version:
            raw, state = Feed.read(path, MAX_STATE)
            Lab.require(version == Feed.source_version(path, MAX_STATE), "native communication source changed during read")
            validate_state(state, self.receipt, now)
            if self.state:
                Lab.require(state["capturedAtUnixMs"] > self.state["capturedAtUnixMs"]
                            or (state["capturedAtUnixMs"] == self.state["capturedAtUnixMs"] and raw == self.raw),
                            "native communication source clock reused or regressed")
                Lab.require(state["lastCommandSequence"] >= self.cursor, "native speech cursor regressed")
                Lab.require(state["bindingEpoch"] >= self.state["bindingEpoch"], "native speech lifetime regressed")
                if state["bindingEpoch"] == self.state["bindingEpoch"]:
                    Lab.require(all(state[key] == self.state[key] for key in ("save","saveMode","playerIndex","playerSqlId"))
                                and state["worldHours"] >= self.state["worldHours"], "native speech lifetime reused")
                if state["lastCommandSequence"] == self.cursor and self.result:
                    Lab.require(state.get("commandResult") == self.result, "native speech outcome changed")
            self.version, self.raw, self.state = version, raw, state
        else: validate_state(self.state, self.receipt, now)
        state = self.state
        if state["lastCommandSequence"] > self.cursor:
            Lab.require(self.forwarded == state["lastCommandSequence"] == self.cursor + 1,
                        "native speech outcome has no forwarded source command")
            self.cursor = state["lastCommandSequence"]; self.result = state["commandResult"]; self.forwarded = None
            self.archive_sample()
        semantic = Feed.encoded({key:value for key,value in state.items() if key not in ("capturedAtUnixMs", "worldHours", "gameThreadDurationNs")})
        if semantic != self.last_archived:
            self.archive_sample(); self.last_archived = semantic
        return state

    def archive_sample(self):
        root = self.evidence / "interaction-samples"; root.mkdir(exist_ok=True)
        target = root / (hashlib.sha256(self.raw).hexdigest() + ".json")
        if target.exists(): Lab.require(target.read_bytes() == self.raw, "retained native communication sample differs")
        else:
            with target.open("xb") as file: file.write(self.raw)

    def process(self, body, now=None):
        now = int(time.time() * 1000) if now is None else now
        state = self.sample(now)
        if self.forwarded is not None: return state
        sequence = self.cursor + 1
        source = self.destination / "commands" / f"{sequence:016d}.json"
        if not source.exists(): return state
        try:
            version = Feed.source_version(source, 8192); raw, command = Feed.read(source, 8192)
            Lab.require(version == Feed.source_version(source, 8192), "native speech command changed during read")
            fields(command, ("schema", "sessionId", "sequence", "action", "personId", "text", "inputMode", "bindingEpoch"))
            Lab.require(command["schema"] == "mousecat.native-view-command/1"
                        and command["sessionId"] == self.receipt["sessionId"]
                        and type(command["sequence"]) is int and command["sequence"] == sequence
                        and command["action"] == "speak", "native speech command binding differs")
            text(command["personId"],128); text(command["text"],384)
            Lab.require(command["inputMode"] in ("typed", "dictated"), "native speech input origin differs")
            Lab.require(state is not None and same_body(state,body)
                        and 0 <= now - body["capturedAtUnixMs"] <= 3000,
                        "native speaker body changed or is unavailable")
            Lab.require(type(command["bindingEpoch"]) is int and command["bindingEpoch"] > 0
                        and command["bindingEpoch"] == state["bindingEpoch"], "queued utterance native lifetime changed")
            person = next((p for p in state["nearby"]["people"] if p["id"] == command["personId"]),None)
            Lab.require(person is not None and person["sections"][0]["status"] == "available",
                        "native speech recipient is unavailable")
            wire = {"schema": WIRE_SCHEMA, "sessionId": self.receipt["sessionId"], "pid": self.receipt["pid"],
                "attempt": body["attempt"], "sequence": sequence, "save": body["save"], "saveMode": body["saveMode"],
                "playerIndex": body["playerIndex"], "playerSqlId": body["playerSqlId"],
                "issuedAtUnixMs": now, "expiresAtUnixMs": now + 5000,
                "bindingEpoch": command["bindingEpoch"],
                **{key: command[key] for key in ("personId", "text", "inputMode")}}
        except (ValueError, UnicodeError, OSError, KeyError, TypeError) as error:
            # A refusal packet preserves sequence continuity but cannot enter
            # the fixed native speech schema or execute an utterance.
            wire = {"schema": "sao.native-interaction-rejection/1", "sequence": sequence, "reason": str(error)[:512]}
        target = self.directory / "commands" / f"{sequence:016d}.json"
        Lab.require(not target.exists() and not target.is_symlink(), "native speech wire sequence already exists")
        Session.atomic(target, wire); self.forwarded = sequence
        return state

    def project(self, body, now=None):
        state = self.sample(now)
        if state is None: return [], None
        return (state["nearby"]["people"] if same_body(state,body) else []), state
