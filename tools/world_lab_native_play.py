#!/usr/bin/env python3
"""Launch the real native menu and retain participant evidence for player play.

The game's own UI chooses saves, characters, mods and start flows. This launcher
does not author StudyWorld, select a save, create a player or impose a stop time.
Mousecat owns the frame; the native game owns input, save and quit.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import uuid

import world_lab as Lab
import world_lab_run as Run
import world_lab_session as Session
import world_lab_participant_feed as Feed
import world_lab_video_archive as Archive
import world_lab_start_context as StartContext
import world_lab_native_communication as Communication

HOST_SCHEMA = "sao.native-play-host/1"
RUN_SCHEMA = "sao.native-play-run/1"
OBJECTIVE_REVIEW_SCHEMA = "sao-native-objective-reviews/1"
MAX_OBJECTIVE_REVIEWS = 8
MAX_OBJECTIVE_ATTEMPTS = 64
MAX_OBJECTIVE_SOURCE_BYTES = 131073


def validate_objective_review_source(value, receipt):
    """Admit only a detached native-thread snapshot bound to its exact body bytes."""
    Lab.require(isinstance(value, dict) and set(value) == {"schema", "sessionId", "pid", "attempt", "captureEpoch",
        "save", "saveMode", "playerIndex", "playerSqlId", "capturedAtUnixMs", "worldHours", "countyHours",
        "sampleSha256", "bodySample", "omittedReviews", "reviews"}
        and value["schema"] == OBJECTIVE_REVIEW_SCHEMA, "native objective source schema differs")
    sample = value["bodySample"]
    Lab.require(isinstance(sample, str) and sample.endswith("\n")
        and len(sample.encode("utf-8")) <= 64 * 1024
        and hashlib.sha256(sample.encode("utf-8")).hexdigest() == value["sampleSha256"],
        "native objective body sample differs")
    body = json.loads(sample, object_pairs_hook=_unique_pairs,
        parse_constant=lambda _: (_ for _ in ()).throw(ValueError("nonfinite native objective body")))
    Feed.validate_body(body, receipt)
    for field in ("sessionId", "pid", "attempt", "save", "saveMode", "playerIndex", "playerSqlId",
                  "capturedAtUnixMs", "worldHours"):
        Lab.require(type(value[field]) is type(body[field]) and value[field] == body[field],
                    "native objective body identity or clock differs")
    Lab.require(body["ready"] and body["alive"], "native objective player body unavailable")
    Lab.integer(value["captureEpoch"], 1, 2**53 - 1, "native objective capture epoch")
    county_hours = Feed.number(value["countyHours"])
    Lab.integer(value["omittedReviews"], 0, 1024 * 64, "native objective omitted reviews")
    rows = value["reviews"]
    Lab.require(isinstance(rows, list) and len(rows) <= MAX_OBJECTIVE_REVIEWS,
                "native objective review count differs")
    for row in rows:
        Lab.require(isinstance(row, dict) and set(row) == {"processId", "revision", "playerId",
            "helperId", "commitmentId", "outboundReceiptId", "watchReceiptId", "returnReceiptId",
            "report", "review"}, "native objective review fields differ")
        for field in ("processId", "playerId", "helperId", "commitmentId", "outboundReceiptId",
                      "watchReceiptId", "returnReceiptId"):
            Feed.text(row[field], 512)
        Lab.integer(row["revision"], 1, 2**31 - 1, "native objective revision")
        report, review = row["report"], row["review"]
        Lab.require(isinstance(report, dict) and set(report) == {"status", "channel", "deliveredAt"}
            and report["status"] == "completed" and report["channel"] == "spoken",
            "native objective returned report differs")
        Lab.require(isinstance(review, dict) and set(review) == {"status", "reviewedAt", "attempts"}
            and review["status"] == "inspected", "native objective player review differs")
        delivered, inspected = Feed.number(report["deliveredAt"]), Feed.number(review["reviewedAt"])
        Lab.require(delivered <= inspected <= county_hours, "native objective review clock differs")
        attempts = review["attempts"]
        Lab.require(isinstance(attempts, list) and len(attempts) <= MAX_OBJECTIVE_ATTEMPTS,
                    "native objective attempt count differs")
        for attempt in attempts:
            Lab.require(isinstance(attempt, dict) and set(attempt) == {"id", "stepId", "owner",
                "status", "x", "y", "z", "startedAt", "endedAt"}, "native objective attempt fields differ")
            for field, limit in (("id", 512), ("stepId", 80), ("owner", 160), ("status", 80)):
                Feed.text(attempt[field], limit)
            Lab.require(attempt["stepId"] in ("outbound", "return")
                and attempt["status"] in ("pending", "arrived", "failed", "interrupted"),
                "native objective attempt status differs")
            for field in ("x", "y"):
                Feed.number(attempt[field], -(2**31), 2**31)
            Feed.number(attempt["z"], -32, 32)
            Feed.number(attempt["startedAt"])
            Lab.require(attempt["status"] == "pending" or attempt["endedAt"] is not None,
                "native objective terminal attempt clock differs")
            if attempt["endedAt"] is not None:
                Feed.number(attempt["endedAt"])
                Lab.require(attempt["endedAt"] >= attempt["startedAt"], "native objective attempt clock differs")
    return body


def _unique_pairs(pairs):
    result = {}
    for key, value in pairs:
        Lab.require(key not in result, "duplicate native objective body field")
        result[key] = value
    return result


class ObjectiveReviewArchive:
    """Retain each newly observed source review once, with the existing event envelope."""
    def __init__(self, source_root, receipt, event):
        self.root, self.receipt, self.event = Path(source_root), receipt, event
        self.seen = {}
        self.omission_counts = {}
        self.last_raw = None
        self.latest = None

    def collect(self, path):
        if not path.exists(): return False
        raw, value = Feed.read(path, MAX_OBJECTIVE_SOURCE_BYTES)
        if raw == self.last_raw: return False
        body = validate_objective_review_source(value, self.receipt)
        new = []
        snapshot_keys = set()
        for index, row in enumerate(value["reviews"]):
            key = (body["saveMode"], body["save"], body["playerIndex"], body["playerSqlId"],
                   value["captureEpoch"],
                   row["processId"], row["revision"], row["playerId"], row["helperId"])
            Lab.require(key not in snapshot_keys, "native objective duplicate review key")
            snapshot_keys.add(key)
            digest = hashlib.sha256(Feed.encoded(row)).hexdigest()
            prior = self.seen.get(key)
            Lab.require(prior is None or prior == digest, "native objective review changed after recording")
            if prior is None: new.append((index, key, row, digest))
        identity = (body["saveMode"], body["save"], body["playerIndex"], body["playerSqlId"],
                    value["captureEpoch"])
        omission_new = value["omittedReviews"] > self.omission_counts.get(identity, 0)
        if not new and not omission_new:
            self.last_raw = raw
            return False
        Lab.require(len(self.seen) + len(new) <= 8192, "native objective review archive capacity reached")
        sample_raw = value["bodySample"].encode("utf-8")
        samples = self.root / "body-samples"
        samples.mkdir(exist_ok=True)
        sample_path = samples / (value["sampleSha256"] + ".json")
        if sample_path.exists():
            Lab.require(sample_path.read_bytes() == sample_raw, "native objective body sample changed")
        else:
            sample_path.write_bytes(sample_raw)
        source_hash = hashlib.sha256(raw).hexdigest()
        sources = self.root / "objective-reviews"
        sources.mkdir(exist_ok=True)
        target = sources / (source_hash + ".json")
        if target.exists():
            Lab.require(target.read_bytes() == raw, "native objective review source changed")
        else:
            target.write_bytes(raw)
        for index, key, row, digest in new:
            self.event("native-objective-review", pid=body["pid"], attempt=body["attempt"],
                save=body["save"], saveMode=body["saveMode"], playerIndex=body["playerIndex"],
                playerSqlId=body["playerSqlId"], sampleSha256=value["sampleSha256"],
                sourceObservedAtUnixMs=body["capturedAtUnixMs"], worldHours=body["worldHours"],
                countyHours=value["countyHours"], captureEpoch=value["captureEpoch"],
                objectiveSourceFile="objective-reviews/" + target.name,
                objectiveSourceSha256=source_hash, objectiveSourceRecord=index,
                objectiveReviewSha256=digest, processId=row["processId"], revision=row["revision"],
                playerId=row["playerId"], helperId=row["helperId"],
                returnReceiptId=row["returnReceiptId"], reviewedAtHours=row["review"]["reviewedAt"])
            self.seen[key] = digest
        if omission_new:
            self.event("native-objective-review-omitted", pid=body["pid"], attempt=body["attempt"],
                save=body["save"], saveMode=body["saveMode"], playerIndex=body["playerIndex"],
                playerSqlId=body["playerSqlId"], sampleSha256=value["sampleSha256"],
                sourceObservedAtUnixMs=body["capturedAtUnixMs"], countyHours=value["countyHours"],
                captureEpoch=value["captureEpoch"],
                objectiveSourceFile="objective-reviews/" + target.name,
                objectiveSourceSha256=source_hash, omittedReviews=value["omittedReviews"])
            self.omission_counts[identity] = value["omittedReviews"]
        self.latest = (value, source_hash)
        self.last_raw = raw
        return True

    def sections_for(self, body, capture):
        """Project bounded source reviews only into their current native body epoch."""
        if not self.latest or not body or not body.get("ready") or not capture:
            return []
        source, source_hash = self.latest
        if capture.get("captureEpoch") != source["captureEpoch"] or capture.get("binding") != "persisted":
            return []
        if source["capturedAtUnixMs"] > body["capturedAtUnixMs"]:
            return []
        for field in ("saveMode", "save", "playerIndex", "playerSqlId"):
            if source[field] != body[field] or capture.get(field) != body[field]:
                return []

        def display(value):
            text = str(value)
            return text if len(text.encode("utf-16-le")) // 2 <= 384 else "sha256:" + hashlib.sha256(text.encode()).hexdigest()

        def label(value):
            prefix = "Objective report · "
            text = str(value)
            budget = 160 - len(prefix.encode("utf-16-le")) // 2
            return prefix + (text if len(text.encode("utf-16-le")) // 2 <= budget
                else "sha256:" + hashlib.sha256(text.encode()).hexdigest())

        sections = []
        for row in source["reviews"]:
            record_hash = hashlib.sha256(Feed.encoded(row)).hexdigest()
            rows = [{"label": "Process", "value": display(row["processId"])},
                {"label": "Helper", "value": display(row["helperId"])},
                {"label": "Returned report", "value": "Completed by spoken report at county hour " + str(row["report"]["deliveredAt"])},
                {"label": "Player inspection", "value": "Inspected at county hour " + str(row["review"]["reviewedAt"])},
                {"label": "Native world hour", "value": str(source["worldHours"])},
                {"label": "Capture epoch", "value": str(source["captureEpoch"])},
                {"label": "Return receipt", "value": display(row["returnReceiptId"])},
                {"label": "Review record SHA256", "value": record_hash},
                {"label": "Recorded attempts", "value": str(len(row["review"]["attempts"]))}]
            for index, attempt in enumerate(row["review"]["attempts"][:32], 1):
                rows.append({"label": "Attempt " + str(index), "value": display(
                    attempt["stepId"] + " · " + attempt["status"] + " · " + attempt["owner"]
                    + " · (" + ", ".join(str(attempt[axis]) for axis in ("x", "y", "z")) + ")")})
            if len(row["review"]["attempts"]) > 32:
                rows.append({"label": "Further attempts", "value": str(len(row["review"]["attempts"]) - 32)
                    + " more retained in the exact source record"})
            sections.append({"id": "objective-review-" + record_hash[:24],
                "label": label(row["helperId"]),
                "source": "SAO Organization · sha256:" + source_hash,
                "perspective": "Player inspection · separate source clock", "status": "available",
                "message": "An inspected report and route attempts are recorded; this does not establish success or a learning verdict."
                    + " Source sample " + str(source["capturedAtUnixMs"]) + " ms; county hour "
                    + str(source["countyHours"]) + ". Video has a separate clock.",
                "rows": rows})
        return sections


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def local_file(path):
    path = Path(path)
    Lab.require(path.is_absolute() and path.is_file() and not path.is_symlink(), "native dependency must be a regular absolute file")
    return path.resolve()


def command(game, adapter, session, attempt, encoder, sao_jar=None):
    """Retain the installed native launcher options and its real user cache."""
    game = Path(game).resolve()
    definition = json.loads(local_file(game / "ProjectZomboid64.json").read_text(encoding="utf-8"))
    Lab.require(definition.get("mainClass") in ("zombie/gameStates/MainScreenState", "zombie.gameStates.MainScreenState"),
                "native main menu entry differs")
    vm = definition.get("vmArgs")
    Lab.require(isinstance(vm, list) and all(isinstance(arg, str) for arg in vm), "native JVM arguments differ")
    Lab.require(not any(arg.startswith(("-javaagent:", "-Dstudy.", "-Duser.home=")) for arg in vm),
                "native launcher contains a conflicting study or home override")
    if "-XX:+UseZGC" not in vm:
        vm = [*vm, "-XX:+UseZGC"]
    classpath = definition.get("classpath")
    Lab.require(isinstance(classpath, list) and all(isinstance(p, str) and p in (".", "projectzomboid.jar", "ZombieBuddy.jar") for p in classpath),
                "native classpath differs")
    cp = [*classpath]
    if "ZombieBuddy.jar" not in cp: cp.append("ZombieBuddy.jar")
    agents = ([f"-javaagent:{local_file(sao_jar)}=sao"] if sao_jar is not None else [])
    agents.append(f"-javaagent:{local_file(adapter)}=native-play")
    properties = {
        "nativePlay": "true", "participantInput": "true", "participantSession": session,
        "participantLease": attempt.parent.parent / "participant-input-lease.json",
        "participantState": attempt / "participant-state.json", "attempt": 1,
        "interactionDirectory": attempt / "interaction",
        "showWindow": "true", "viewDirectory": attempt / "native-view",
        "videoEncoder": local_file(encoder), "videoFps": 120,
    }
    return [str(local_file(game / "jre64/bin/java.exe")), *agents,
        *(f"-Dstudy.{key}={value}" for key, value in properties.items()), *vm,
        "-cp", os.pathsep.join(cp), "zombie.gameStates.MainScreenState"]


def existing_game():
    """Use command-line ownership, not a window title or a java name alone."""
    if os.name != "nt": raise ValueError("native play currently requires Windows")
    query = "$rows = @(Get-CimInstance Win32_Process -Filter \"Name='java.exe' OR Name='javaw.exe' OR Name='ProjectZomboid64.exe'\" | Where-Object { $_.Name -eq 'ProjectZomboid64.exe' -or $_.CommandLine -match 'zombie.gameStates.MainScreenState' } | Select-Object ProcessId); ConvertTo-Json -Compress -InputObject $rows"
    result = subprocess.run(["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", query],
        capture_output=True, text=True, check=True, timeout=15)
    return json.loads(result.stdout or "[]")


class NativePlayFeed(Feed.ParticipantFeed):
    """Reuse source validators while keeping interactive play outside StudyWorld."""
    def __init__(self, run, destination, receipt, study_id, video_module=None, objective_archive=None):
        super().__init__(run, destination, receipt, study_id, video_module)
        self.objective_archive = objective_archive
        self.communication = Communication.NativeCommunication(self.native.parent, self.destination, receipt, self.run.parent)
        self.video_contexts = {}
        self.last_video_capture_epoch = 0

    def video_capture_context(self, manifest):
        stream = Feed.canonical_uuid(manifest.get("streamId"))
        name = f"video-{stream}-native-context.json"
        source = self.native / name
        if not source.exists():
            Lab.require(not manifest.get("segments"), "native video segments lack capture context")
            return None
        raw, context = Feed.read(source, 64 * 1024)
        Feed.validate_capture_context(context, self.receipt, stream_id=stream)
        previous = self.video_contexts.get(stream)
        Lab.require(previous is None or previous == raw, "native video capture context changed")
        Lab.require(previous is not None or len(self.video_contexts) < 128,
                    "native video capture stream limit reached")
        Lab.require(context["captureEpoch"] >= self.last_video_capture_epoch,
                    "native video capture epoch regressed")
        target = self.destination / name
        Lab.require(not target.is_symlink(), "published native video capture context is unsafe")
        if target.exists():
            Lab.require(not target.is_symlink() and target.read_bytes() == raw,
                        "published native video capture context differs")
        else:
            pending = target.with_name(name + ".tmp")
            pending.write_bytes(raw)
            os.replace(pending, target)
        self.video_contexts[stream] = raw
        self.last_video_capture_epoch = context["captureEpoch"]
        return context

    def body(self, *, now=None):
        path = self.native.parent / "participant-state.json"
        if not path.exists(): return None
        raw, value = Feed.read(path, 64 * 1024)
        Feed.validate_body(value, self.receipt, now=now)
        if self.previous_body:
            previous_raw, previous = self.previous_body
            Lab.require(value["capturedAtUnixMs"] >= previous["capturedAtUnixMs"], "native player sample time regressed")
            Lab.require(value["capturedAtUnixMs"] != previous["capturedAtUnixMs"] or raw == previous_raw,
                        "native player sample time reused")
        if self.previous_body is None or raw != self.previous_body[0]: self.body_sequence += 1
        self.previous_body = raw, value
        return value

    def publish_play(self, ended=False):
        self.run_receipt()
        frame, body = self.frame(), self.body()
        people = []
        if body and body["ready"]:
            identity = [body["saveMode"], body["save"], body["playerIndex"], body["playerSqlId"]]
            identity_pin = hashlib.sha256(Feed.encoded(identity)).hexdigest()[:24]
            people = [{"id": f"native-player-{identity_pin}", "label": body["body"]["label"],
                "summary": "The player you selected in the native game. This body sample has its own clock.",
                "sections": [{"id": "participant-body", "label": "Native body", "source": "Native participant adapter",
                    "perspective": "Engine body sample", "status": "available", "message": "Separately timed from the recorded frame.",
                    "rows": [{"label": "Position", "value": ", ".join(str(body['body'][k]) for k in ('x', 'y', 'z'))},
                        {"label": "World hour", "value": str(body['worldHours'])},
                        {"label": "Native save", "value": f"{body['saveMode']} / {body['save']}"},
                        {"label": "Native slot / SQL id", "value": f"0 / {body['playerSqlId']}"}]}]}]
            if "startContext" in body:
                people[0]["sections"].append(StartContext.person_section(body["startContext"]))
        communication_state = None
        try:
            nearby, communication_state = self.communication.project(body)
            people.extend(nearby)
        except (ValueError, UnicodeError, OSError):
            # Speech source failure withholds its capability without degrading
            # native pixels or substituting another character's observations.
            pass
        video = video_capture = None
        source = self.native / "latest-video.json"
        if self.video and source.is_file():
            raw, value = Feed.read(source)
            video_capture = self.video_capture_context(value)
            if raw != self.previous_video:
                self.video_view = Feed.publish_video_with_cameras(self.video, value)
                self.previous_video = raw
            video = self.video_view
            Lab.require(video is not None and video.get("streamId") == value["streamId"],
                        "native video relay stream differs")
        frame_capture = frame.get("captureContext")
        if frame_capture is not None and video_capture is not None and frame_capture["captureEpoch"] == video_capture["captureEpoch"]:
            for field in ("saveMode", "save", "bodyObserved", "binding", "worldClock", "playerIndex", "playerSqlId"):
                Lab.require(frame_capture.get(field) == video_capture.get(field),
                            "native frame/video capture identity differs")
        if people and self.objective_archive is not None:
            people[0]["sections"].extend(self.objective_archive.sections_for(body, frame_capture))
        value = {"schema": "mousecat.native-view/1", "sessionId": self.session, "sequence": self.sequence + 1,
            "capturedAtUnixMs": frame["capturedAtUnixMs"], "image": frame["image"], "state": "ended" if ended else "running",
            "title": "Native play", "summary": "Native game pixels. Save, character, start flow and physical input belong to the game. Unreviewed.",
            "people": people, "lastCommandSequence": self.communication.cursor,
            "commandActions": ["speak"] if not ended and communication_state is not None
                and Communication.same_body(communication_state, body)
                and any(person.get("sections", [{}])[0].get("status") == "available"
                    for person in communication_state["nearby"]["people"]) else [],
            "camera": {"mode": "automatic", "personIds": [], "summary": "Whole native framebuffer; native player camera"}}
        if "nativeCamera" in frame:
            value["nativeCamera"] = frame["nativeCamera"]
            if frame["nativeCamera"]["ready"]:
                labels = {"isometric": "isometric", "viewpoint-first": "first person",
                          "viewpoint-third": "third person", "viewpoint-free": "free camera"}
                value["camera"]["summary"] = (
                    "Whole native framebuffer; completed " + labels[frame["nativeCamera"]["mode"]] + " frame")
        value["recording"] = {"schema": "mousecat.native-recording/1", "id": self.study_id,
            "attempt": 1, "mode": "interactive", "status": "ended" if ended else "recording"}
        if people:
            detail = communication_state if communication_state is not None and Communication.same_body(communication_state,body) else body
            value["inspection"] = {"sequence": self.body_sequence, "capturedAtUnixMs": detail["capturedAtUnixMs"],
                "worldHours": detail["worldHours"], "status": "available", "message": "Participant and speech samples have separate source clocks.",
                "omittedPeople": detail.get("nearby",{}).get("omittedPeople",0),
                "omittedEvents": detail.get("nearby",{}).get("omittedEvents",0)}
        if self.communication.result is not None: value["commandResult"] = self.communication.result
        if communication_state is not None and Communication.same_body(communication_state,body):
            value["communicationBindingEpoch"] = communication_state["bindingEpoch"]
        if video is not None: value["video"] = video
        if frame_capture is not None: value["captureContext"] = frame_capture
        if video_capture is not None: value["videoCaptureContext"] = video_capture
        comparison = Feed.encoded({key: item for key, item in value.items() if key != "sequence"})
        if comparison == self.last_input: return False
        self.sequence += 1; value["sequence"] = self.sequence
        Session.atomic(self.destination / "latest.json", value); self.last_input = comparison
        return True


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    for option in ("out", "session", "game", "jdk", "video-encoder", "watcher", "registry"):
        parser.add_argument("--" + option, required=True)
    parser.add_argument("--sao-jar")
    parser.add_argument("--prepare-only", action="store_true")
    args = parser.parse_args(argv)
    session = Feed.canonical_uuid(args.session)
    out = Path(args.out).resolve()
    Lab.require(not out.exists() and out.is_absolute(), "native play output must be a new absolute session directory")
    game, jdk = Path(args.game).resolve(), Path(args.jdk).resolve()
    local_file(game / "projectzomboid.jar"); local_file(game / "ZombieBuddy.jar"); local_file(jdk / "javac.exe")
    local_file(args.video_encoder); local_file(args.watcher); local_file(args.registry)
    Lab.require(not existing_game(), "A native game is already running. Return to that game before starting another.")
    out.mkdir(parents=True)
    native = out / "participant-run"; attempt = native / "attempts/0001"; attempt.mkdir(parents=True)
    (attempt / "interaction/commands").mkdir(parents=True)
    events = out / "events.jsonl"
    logged_objective_events = {}
    pending_objective_events = {}
    host = {"schema": HOST_SCHEMA, "sessionId": session, "supervisorPid": os.getpid(), "pid": 0,
        "phase": "starting", "message": "Preparing native participant observation…", "updatedAtUnixMs": 0}
    def publish_host(phase, message):
        host.update(phase=phase, message=message, updatedAtUnixMs=int(time.time() * 1000))
        Session.atomic(out / "host.json", host)
    def event(kind, **fields):
        logical = None
        if kind == "native-objective-review":
            # The main JSONL may grow through a long player session. Give the
            # trial a bounded immutable event envelope to pin independently.
            logical = tuple(fields[key] for key in ("saveMode", "save", "playerIndex",
                "playerSqlId", "captureEpoch", "processId", "revision", "playerId", "helperId"))
            if logical in logged_objective_events:
                Lab.require(logged_objective_events[logical] == fields["objectiveReviewSha256"],
                    "native objective retry changed its recorded review")
                return
        if logical is not None and logical in pending_objective_events:
            raw = pending_objective_events[logical]
            Lab.require(json.loads(raw)["objectiveReviewSha256"] == fields["objectiveReviewSha256"],
                "native objective retry changed its pending review")
        else:
            row = {"schema": "sao.native-play-event/1", "sessionId": session,
                "atUnixMs": int(time.time() * 1000), "kind": kind, **fields}
            raw = Feed.encoded(row)
            if logical is not None:
                pending_objective_events[logical] = raw
        if logical is not None:
            target_dir = out / "objective-reviews/events"
            target_dir.mkdir(parents=True, exist_ok=True)
            target = target_dir / (hashlib.sha256(raw).hexdigest() + ".json")
            if target.exists():
                Lab.require(target.read_bytes() == raw, "native objective event changed")
            else:
                pending = target.with_name(target.name + ".tmp")
                pending.write_bytes(raw)
                os.replace(pending, target)
        with events.open("ab") as file:
            offset = file.tell()
            try:
                file.write(raw)
                if logical is not None:
                    file.flush()
                    os.fsync(file.fileno())
                    logged_objective_events[logical] = fields["objectiveReviewSha256"]
                    pending_objective_events.pop(logical, None)
            except OSError:
                file.truncate(offset)
                raise
    publish_host("starting", "Compiling source-bound participant observation…")
    (out / "adapter").mkdir()
    adapter = Run.build_participant_adapter(out / "adapter", game, jdk)
    native_command = command(game, adapter, session, attempt, args.video_encoder, args.sao_jar)
    plan = {"schema": "sao.native-play-launch/1", "sessionId": session, "mode": "native-menu",
        "command": native_command, "workingDirectory": str(game), "userCache": "native-default",
        "saveSelection": "native-LoadGameScreen", "sourcePins": {name: digest(Lab.ROOT / 'tools/world_lab' / name) for name in Run.PARTICIPANT_SOURCES},
        "engineSha256": digest(game / "projectzomboid.jar"), "adapterSha256": digest(adapter),
        "saoAgentSha256": digest(local_file(args.sao_jar)) if args.sao_jar else None,
        "launcherSha256": digest(__file__), "nativeModsOverride": False, "nativeSoundDisabled": False}
    Session.atomic(out / "launch.json", plan)
    if args.prepare_only:
        publish_host("prepared", "Source-bound native menu launch prepared; no game was started.")
        return 0
    # Recheck immediately before creating the sole native producer.
    Lab.require(not existing_game(), "Another native game started during preparation")
    video, video_pin = Feed.load_video_module(args.watcher)
    stdout = (attempt / "stdout.log").open("wb"); stderr = (attempt / "stderr.log").open("wb")
    environment = os.environ.copy(); environment.pop("_JAVA_OPTIONS", None)
    environment.setdefault("SteamAppId", "108600")
    process = subprocess.Popen(native_command, cwd=game, stdout=stdout, stderr=stderr, env=environment,
        creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    host["pid"] = process.pid
    receipt = {"schema": "sao-study-run/1", "sourceSchema": RUN_SCHEMA, "launchMode": "native-menu",
        "sessionId": session, "pid": process.pid, "host": "player", "participantInput": True,
        "window": "visible", "watch": True, "launchNumber": 1, "observerDirectory": "attempts/0001",
        "status": "running", "save": None, "packageSha256": None, "definitionSha256": None,
        "evidenceScope": "native-player-recording", "authoredStudy": False, "launcher": plan, "videoBridge": video_pin}
    objective_reviews = ObjectiveReviewArchive(out, receipt, event)
    objective_error = None
    archive = None
    feed = None; registered = False; recording_failure = None
    body_path = attempt / "participant-state.json"; previous_body = None
    destination = out / "feeds/0001"
    body_identity = None; body_interval = 0; last_body = None
    try:
        # Establish native process custody before any observation setup. A
        # failure in the archive, registry or run receipt preserves this PID.
        publish_host("menu", "Choose Load, save and character in the native game.")
        Session.atomic(native / "run.json", receipt)
        event("native-started", pid=process.pid, nativeMenu=True)
        archive = Archive.start(out, session, run_name="participant-run")
        while process.poll() is None:
            if body_path.exists():
                try:
                    raw, body = Feed.read(body_path)
                    Feed.validate_body(body, {**receipt, "save": None})
                except (FileNotFoundError, PermissionError):
                    time.sleep(.1); continue
                if raw != previous_body:
                    if last_body:
                        Lab.require(body["capturedAtUnixMs"] > last_body["capturedAtUnixMs"],
                                    "native body sample time reused or regressed")
                    previous_body = raw
                    sample_pin = hashlib.sha256(raw).hexdigest()
                    # Immutable independently timed body samples retain every
                    # accepted native selection, including menu/unbound states.
                    samples = out / "body-samples"; samples.mkdir(exist_ok=True)
                    sample = samples / (sample_pin + ".json")
                    if sample.exists():
                        Lab.require(sample.read_bytes() == raw, "retained native body sample differs")
                    else: sample.write_bytes(raw)
                    if body["ready"]:
                        event("native-body-sample", pid=body["pid"], attempt=body["attempt"],
                              saveMode=body["saveMode"], save=body["save"],
                              playerIndex=body["playerIndex"], playerSqlId=body["playerSqlId"],
                              sampleSha256=sample_pin,
                              sourceObservedAtUnixMs=body["capturedAtUnixMs"])
                    identity = (body["saveMode"], body["save"], body["playerIndex"], body["playerSqlId"]) if body["ready"] else None
                    reset = bool(body["ready"] and last_body and last_body["ready"]
                                 and body["worldHours"] < last_body["worldHours"])
                    changed = identity != body_identity or reset
                    if changed and body_identity is not None:
                        event("native-player-interval-ended", interval=body_interval,
                              identity=list(body_identity), sourceObservedAtUnixMs=body["capturedAtUnixMs"],
                              sampleSha256=sample_pin, reason="world-clock-reset" if reset else "native-body-boundary")
                    if body["ready"]:
                        if changed:
                            body_interval += 1
                            event("native-player-interval-started", interval=body_interval,
                                  saveMode=body["saveMode"], save=body["save"], playerIndex=body["playerIndex"],
                                  playerSqlId=body["playerSqlId"], label=body["body"]["label"],
                                  sampleSha256=sample_pin, sourceObservedAtUnixMs=body["capturedAtUnixMs"])
                            publish_host("playing", "Native player selected. Input stays with the game.")
                    elif host["phase"] == "playing":
                        event("native-player-unbound", sourceObservedAtUnixMs=body["capturedAtUnixMs"])
                        publish_host("menu", "Native player is unbound. Use the game to choose your next save or character.")
                    body_identity = identity; last_body = body
            objective_path = attempt / "objective-review-state.json"
            if objective_path.exists():
                try:
                    objective_reviews.collect(objective_path)
                    objective_error = None
                except (ValueError, OSError, UnicodeError) as error:
                    reason = str(error)[:1000]
                    if reason != objective_error:
                        event("objective-review-source-withheld", reason=reason)
                        objective_error = reason
            if (attempt / "native-view/native.json").exists() and recording_failure is None:
                if feed is None: feed = NativePlayFeed(native, destination, receipt, session, video, objective_reviews)
                try:
                    try: feed.communication.process(last_body)
                    except (ValueError, UnicodeError, OSError) as error:
                        event("communication-source-withheld", reason=str(error)[:1000])
                    feed.publish_play()
                    if not registered:
                        Feed.register_feed(args.registry, "native-play-" + session[:8], "Native play",
                            "project:survivor-awareness", destination, session)
                        registered = True; event("observation-registered", viewId="native-play-" + session[:8])
                except (ValueError, OSError) as error:
                    # Source turnover is retried; a game is never quit to make
                    # its observation look successful.
                    event("observation-retry", reason=str(error)[:1000])
            if archive and archive.error:
                recording_failure = str(archive.error)
                event("recording-failed", reason=recording_failure[:1000])
                publish_host("playing" if body_identity else "menu", "The game is running; recording encountered an error.")
                archive.close(); archive = None
            time.sleep(.1)
    finally:
        if process.poll() is not None:
            objective_path = attempt / "objective-review-state.json"
            if objective_path.exists():
                try: objective_reviews.collect(objective_path)
                except (ValueError, OSError, UnicodeError) as error:
                    reason = str(error)[:1000]
                    if reason != objective_error:
                        event("objective-review-source-withheld", reason=reason)
            if body_identity is not None:
                event("native-player-interval-ended", interval=body_interval, identity=list(body_identity),
                      reason="native-exit", lastSourceObservedAtUnixMs=last_body["capturedAtUnixMs"],
                      terminalClock="native-process-exit-observed-at-event-time")
            stdout.close(); stderr.close()
            log = (attempt / "stdout.log").read_text(encoding="utf-8", errors="replace")
            errors = (attempt / "stderr.log").read_text(encoding="utf-8", errors="replace")
            returned = "[StudyLaunch] native-save-returned attempt=1" in log
            receipt.update(exitCode=process.returncode, nativeSaveReturned=returned,
                status="completed" if process.returncode == 0 and returned and not recording_failure else "incomplete",
                terminal="native-exit", recordingError=recording_failure,
                logs={"stdout.log": digest(attempt/'stdout.log'), "stderr.log": digest(attempt/'stderr.log')})
            # The collector binds immutable media to this terminal receipt.
            # Reconcile its final standing after the bounded close below.
            Session.atomic(native / "run.json", receipt)
            terminal_observation_error = None
            if feed:
                try: feed.publish_play(ended=True)
                except (ValueError, OSError) as error:
                    terminal_observation_error = str(error)
                    event("terminal-observation-failed", reason=terminal_observation_error[:1000])
            else:
                terminal_observation_error = "native observation feed unavailable at exit"
            archive_close_error = None
            if archive:
                try: archive.close()
                except (ValueError, OSError) as error:
                    archive_close_error = {"type": type(error).__name__, "reason": str(error)[:1000]}
            archive_error = archive_close_error or (archive.error if archive else recording_failure)
            if terminal_observation_error or archive_error:
                recording_failure = terminal_observation_error or str(archive_error)
                if archive_error: event("recording-failed", reason=str(archive_error)[:1000])
                receipt.update(status="incomplete", recordingError=recording_failure)
            # The latest durable run status follows archive close/catalog work.
            Session.atomic(native / "run.json", receipt)
            recording_complete = False
            recording = None
            if archive and not archive_error and feed and receipt["status"] == "completed":
                try:
                    import world_lab_participant_session as ParticipantSession
                    recording = ParticipantSession.require_recording(destination, session, session)
                    recording_complete = True
                except (ValueError, OSError, KeyError) as error:
                    event("recording-qualification-failed", reason=str(error)[:1000])
                    receipt.update(status="incomplete", recordingError=str(error)[:1000])
                    Session.atomic(native / "run.json", receipt)
            def write_completion():
                Session.atomic(out / "recording-completion.json", {
                    "schema": "sao.native-play-recording-completion/1", "sessionId": session,
                    "complete": recording_complete, "recording": recording,
                    "nativeSaveReturned": returned, "archiveError": archive_error or recording_failure})
            write_completion()
            if feed:
                try:
                    Archive.publish_native_play_finality(out, destination)
                except (ValueError, OSError, KeyError) as error:
                    # A missing or inconsistent final attestation cannot
                    # certify the replay, even if the earlier archive check passed.
                    event("recording-finality-failed", reason=str(error)[:1000])
                    recording_complete = False
                    recording_failure = str(error)[:1000]
                    receipt.update(status="incomplete", recordingError=recording_failure)
                    Session.atomic(native / "run.json", receipt)
                    write_completion()
                    try:
                        Archive.publish_native_play_finality(out, destination)
                    except (ValueError, OSError, KeyError) as second_error:
                        event("recording-finality-unavailable", reason=str(second_error)[:1000])
            event("native-ended", exitCode=process.returncode, nativeSaveReturned=returned,
                recordingComplete=recording_complete)
            publish_host("ended", "The native game ended. Its recording and source receipts are retained.")
        else:
            # Supervisor failure preserves the player's still-running process.
            publish_host("failed", "Observation ended while the native game remains running; return to the game to save or quit.")
            if archive: archive.close()
            stdout.close(); stderr.close()
    return process.returncode or 0


if __name__ == "__main__":
    try: sys.exit(main())
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        print(json.dumps({"schema": "sao.native-play-error/1", "message": str(error)}), file=sys.stderr)
        sys.exit(1)
