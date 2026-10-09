#!/usr/bin/env python3
"""Own one fresh visible participant attempt, its observation feed and release.

This session never resumes an observer save. Checkpoint and stop finish this
attempt through the existing native save/exit request; no continuation is offered.
"""
from __future__ import annotations

import hashlib
import subprocess
from pathlib import Path
import time

import world_lab as Lab
import world_lab_participant_feed as Feed

SOURCE_POLL_SECONDS = .01


def require_archive(archive):
    error = getattr(archive, "error", None)
    Lab.require(error is None, "participant archive failed: " + str(error)[:512])


def require_recording(destination, study_id, native_session):
    """Keep a completed native save distinct from a complete replay delivery."""
    view = Feed.read(Path(destination) / "latest.json")[1]
    video = view.get("video") or {}
    Lab.require(view.get("sessionId") == native_session and video.get("state") == "ended"
                and bool(video.get("segments")), "participant video did not finish with retained media")
    index = Feed.read(Path(destination) / "archive-index.json", 4*1024*1024)[1]
    Lab.require(index.get("schema") == "mousecat.native-video-archive/1"
                and index.get("sessionId") == native_session and index.get("studyId") == study_id
                and type(index.get("attempt")) is int and index["attempt"] == 1
                and index.get("streamId") == video.get("streamId")
                and index.get("coverage") == "complete-published-segments" and index.get("tailConfirmed") is True
                and type(index.get("segmentCount")) is int and index["segmentCount"] > 0
                and bool(index.get("pages")), "participant archive is incomplete or belongs to another source")
    root = Path(destination).resolve().parents[1]
    archive = Feed.read(root / "video-archive/archive.json", 4*1024*1024)[1]
    attempts, epochs = archive.get("attempts"), archive.get("streams")
    Lab.require(archive.get("schema") == "sao.native-video-archive/1"
                and archive.get("studyId") == study_id and archive.get("source") == str(root)
                and archive.get("status") == "stopped" and archive.get("error") is None
                and archive.get("priorFailureCount") == 0
                and isinstance(attempts, list) and len(attempts) == 1
                and type(attempts[0].get("attempt")) is int and attempts[0]["attempt"] == 1
                and attempts[0].get("nativeProvenance", {}).get("sessionId") == native_session
                and attempts[0].get("nativeProvenance", {}).get("status") == "completed"
                and isinstance(epochs, list) and bool(epochs),
                "participant recording archive owner or completion differs")
    seen = set()
    for epoch in epochs:
        stream = Feed.canonical_uuid(epoch.get("streamId"))
        Lab.require(stream not in seen and type(epoch.get("attempt")) is int and epoch["attempt"] == 1
                    and epoch.get("coverage") == "complete-published-segments"
                    and epoch.get("tailConfirmed") is True and epoch.get("lateAttachment") is False
                    and type(epoch.get("retainedSegments")) is int and epoch["retainedSegments"] > 0,
                    "participant recording has an incomplete geometry epoch")
        seen.add(stream)
    Lab.require(video.get("streamId") in seen, "participant final recording epoch is absent")
    return {**{key:index[key] for key in ("generation","segmentCount","coverage","ptsStartMs","ptsEndMs")},
            "geometryEpochs": epochs}


def request_stop(run, reason):
    import world_lab_supervision as Supervision
    Supervision.stop_request(Path(run) / "cache/Lua/StudyRunnerStop0001.txt", reason)


def consume_commands(feed, study, native_session, acknowledged, release, stop):
    """Consume exactly the next immutable command and acknowledge rejections."""
    sequence = acknowledged + 1
    path = Path(feed) / "commands" / f"{sequence:016d}.json"
    if not path.exists(): return acknowledged, None
    try:
        command = Feed.read(path, 8192)[1]
        required = {"schema", "sessionId", "sequence", "action"}
        Lab.require(isinstance(command, dict) and set(command) == required
                    and command["schema"] == "mousecat.native-view-command/1"
                    and command["sessionId"] == native_session
                    and type(command["sequence"]) is int and command["sequence"] == sequence,
                    "participant command owner or sequence differs")
        Lab.require(command["action"] in ("checkpoint", "stop") and study["status"] == "running"
                    and study["canCheckpoint"] and not study["canContinue"],
                    "participant supports save-and-finish while running")
        release("native-" + command["action"])
        stop("operator-" + command["action"])
        result = {"sequence": sequence, "status": "applied", "message": "Native save and finish requested"}
    except (ValueError, KeyError, TypeError, OSError) as error:
        result = {"sequence": sequence, "status": "rejected", "message": str(error)[:512]}
    Feed.atomic(Path(feed) / "participant-command-receipt.json", {
        "schema": "sao-participant-command-receipt/1", "sessionId": native_session,
        "studyId": study["id"], "sequence": sequence, "result": result})
    return sequence, result


def supervise(args):
    import world_lab_session as Session
    import world_lab_video_archive as Archive
    import world_lab_participant_lease as Lease

    Lab.require(getattr(args, "participant_input", False) is True and getattr(args, "window", "visible") == "visible",
                "participant session requires visible player mode")
    Lab.require(getattr(args, "video_encoder", None) is not None, "participant studies require continuous native recording")
    Lab.require(not getattr(args, "auto_continue", False) and not getattr(args, "attach_running_session", None)
                and not getattr(args, "gameplay_lua_update", None) and not getattr(args, "reviewed_errors", None),
                "participant session requires one fresh attempt")
    Lab.require(not getattr(args, "observer_layout", None) and not getattr(args, "site_controls", False),
                "participant session refuses observer controls")
    for name in ("package", "out", "game", "jdk", "watcher", "registry"):
        setattr(args, name, Path(getattr(args, name)).resolve())
    Lab.require(not args.out.exists() or not any(args.out.iterdir()), "participant session output is not empty")
    video_module, video_provenance = Feed.load_video_module(args.watcher)
    args.out.mkdir(parents=True, exist_ok=True)
    duration = Session.bounded_duration(args.duration if args.duration is not None else 3600)
    study = Session.new_state(args.label, duration, False)
    state_path = args.out / "study-session.json"
    Session.atomic(state_path, study)
    (args.out / "session-commands").mkdir()
    run = args.out / "participant-run"
    destination = args.out / "feeds/0001"
    runner = archive = broker = publisher = None
    registered = selected = False
    acknowledged, result = 0, None
    first_hours = None
    published_sources = None
    try:
        archive = Archive.start(args.out, study["id"], run_name="participant-run",
            max_bytes=getattr(args, "video_archive_max_bytes", Archive.DEFAULT_MAX_BYTES),
            min_free_bytes=getattr(args, "video_archive_min_free_bytes", Archive.DEFAULT_MIN_FREE_BYTES))
        require_archive(archive)
        runner = subprocess.Popen(Session.participant_command(args, duration))
        receipt = Session.wait_for_run(run / "run.json", runner)
        Feed.validate_receipt(receipt)
        Session.save_state(state_path, study, status="running", attempt=1, feedGeneration=1,
                           canCheckpoint=True, canContinue=False)
        publisher = Feed.ParticipantFeed(run, destination, receipt, study["id"], video_module)
        broker = Lease.ParticipantLeaseBroker(run)
        Session.atomic(args.out / "participant-bridge.json", {
            "schema": "sao-participant-observation-bridge/1", "studyId": study["id"], "sessionId": receipt["sessionId"],
            "attempt": 1, "pid": receipt["pid"], "videoValidator": video_provenance,
            "pipelineSha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            "feedSha256": hashlib.sha256(Path(Feed.__file__).read_bytes()).hexdigest(),
            "nativeInput": "Native keyboard/mouse; explicit leased input inbox", "bodyClock": "Independent native sample"})
        while runner.poll() is None:
            cycle_started = time.monotonic()
            require_archive(archive)
            broker.poll()
            acknowledged, next_result = consume_commands(destination, study, receipt["sessionId"], acknowledged,
                broker.release, lambda reason: request_stop(run, reason))
            if next_result is not None: result = next_result
            if (publisher.native / "native.json").exists():
                try:
                    sources = publisher.publication_sources()
                    if sources != published_sources or next_result is not None:
                        body = publisher.body()
                        if body is not None and body.get("body") is not None:
                            if first_hours is None: first_hours = body["worldHours"]
                            if study["worldHours"] != body["worldHours"]:
                                Session.save_state(state_path, study, worldHours=body["worldHours"],
                                    accumulatedWorldHours=max(0, body["worldHours"] - first_hours))
                        publisher.publish(study, acknowledged, result)
                        published_sources = sources
                except (FileNotFoundError, PermissionError):
                    # A producer can retire a rolling asset between immutable
                    # manifest and byte reads. Windows atomic replacement can
                    # also briefly deny a concurrent reader; retry its next
                    # complete frame without accepting partial or invalid data.
                    pass
                else:
                    if not registered:
                        Feed.register_feed(args.registry, args.view_id, args.label, getattr(args, "project_ref", None),
                                           destination, receipt["sessionId"])
                        registered = True
                    if not selected:
                        Session.open_mousecat(args, destination, receipt["sessionId"])
                        selected = True
            remaining = SOURCE_POLL_SECONDS - (time.monotonic() - cycle_started)
            if remaining > 0: time.sleep(remaining)
        final = Feed.validate_receipt(Feed.read(run / "run.json", Feed.MAX_RUN_JSON)[1], receipt["sessionId"])
        broker.release("native-attempt-ended")
        success = runner.returncode == 0 and final["status"] == "completed"
        terminal = final.get("terminal") or {}
        hours = final.get("lastHours", study["worldHours"])
        elapsed = max(0, terminal.get("endHours", hours) - terminal.get("startHours", hours))
        Session.save_state(state_path, study, status="closed" if success else "failed",
            canCheckpoint=False, canContinue=False, worldHours=hours, accumulatedWorldHours=elapsed,
            lastStopReason=str(terminal.get("stopReason") or final["status"])[:80])
        if (publisher.native / "native.json").exists():
            publisher.publish(study, acknowledged, result)
        # Collect the final native manifest and close retention before exit.
        archive.close()
        require_archive(archive)
        if success:
            recording = require_recording(destination, study["id"], receipt["sessionId"])
            Session.atomic(args.out / "participant-recording-completion.json", {
                "schema":"sao-participant-recording-completion/1", "studyId":study["id"],
                "sessionId":receipt["sessionId"], **recording})
        archive = None
        return 0 if success else runner.returncode or 1
    except BaseException as error:
        Session.save_state(state_path, study, status="failed", canCheckpoint=False, canContinue=False,
                           lastStopReason="participant-orchestration-failed")
        Session.atomic(args.out / "participant-orchestration-failure.json", {
            "schema": "sao-participant-orchestration-failure/1", "studyId": study["id"],
            "atUnixMs": int(time.time() * 1000), "errorType": type(error).__name__, "reason": str(error)[:1000]})
        if publisher is not None and (publisher.native / "native.json").exists():
            try:
                publisher.publish(study, acknowledged, result)
            except (OSError, ValueError, KeyError, TypeError) as projection_error:
                Session.atomic(args.out / "participant-failed-projection.json", {
                    "schema": "sao-participant-failed-projection/1", "studyId": study["id"],
                    "atUnixMs": int(time.time() * 1000), "reason": str(projection_error)[:1000]})
        raise
    finally:
        try:
            if broker is not None: broker.release("participant-session-exit")
        finally:
            try:
                if runner is not None and runner.poll() is None:
                    try:
                        request_stop(run, "participant-session-exit")
                    finally:
                        try:
                            # The runner retains its child job and owns the
                            # finite save/shutdown path even if release or stop
                            # publication fails. Do not kill its Python custody.
                            runner.wait(timeout=duration + 60)
                        except subprocess.TimeoutExpired:
                            Session.atomic(args.out / "participant-retained-owner.json", {
                                "schema": "sao-participant-retained-owner/1", "studyId": study["id"],
                                "runnerPid": runner.pid, "nativeSessionId": publisher.session if publisher else None,
                                "atUnixMs": int(time.time() * 1000), "reason": "native-owner-exceeded-bounded-exit",
                                "custody": "Native runner retains child ownership; no duplicate launch"})
                            raise
            finally:
                try:
                    if archive is not None: archive.close()
                finally:
                    if broker is not None: broker.close()
