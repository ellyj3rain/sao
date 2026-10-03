#!/usr/bin/env python3
"""Keep one native study save available across bounded observer attempts.

The native runner still owns every launch, save, validation and continuation.
This supervisor owns only the durable session settings and the transition from
one completed attempt to the next.  Mousecat lifecycle requests arrive through
Speakeasy's allowlisted observer bridge; no browser request carries a command,
path or executable.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import uuid

import world_lab as Lab


SCHEMA = "sao-study-session/1"
COMMAND_SCHEMA = "sao-study-session-command/1"
MIN_ATTEMPT_SECONDS = 30
MAX_ATTEMPT_SECONDS = 604800


def atomic(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_bytes(Lab.canonical(value))
    os.replace(temporary, path)


def bounded_duration(value) -> int:
    Lab.integer(value, MIN_ATTEMPT_SECONDS, MAX_ATTEMPT_SECONDS, "attempt duration")
    return value


def public_state(state):
    """Validate the state consumed by Speakeasy without exposing local paths."""
    required = {"schema", "id", "label", "status", "attempt", "attemptDurationSeconds",
                "autoContinue", "worldHours", "accumulatedWorldHours", "canCheckpoint",
                "canContinue", "updatedAtUnixMs", "datasetAdmission", "behavioralVerdict",
                "lastStopReason", "feedGeneration", "processedCommands"}
    Lab.require(isinstance(state, dict) and set(state) == required, "study session fields differ")
    Lab.require(state["schema"] == SCHEMA and str(uuid.UUID(state["id"])) == state["id"],
                "study session identity differs")
    Lab.require(isinstance(state["label"], str) and 0 < len(state["label"]) <= 160,
                "study session label differs")
    Lab.require(state["status"] in ("starting", "running", "saved", "continuing", "failed"),
                "study session status differs")
    Lab.integer(state["attempt"], 0, 2**31 - 1, "study attempt")
    bounded_duration(state["attemptDurationSeconds"])
    Lab.require(type(state["autoContinue"]) is bool and type(state["canCheckpoint"]) is bool
                and type(state["canContinue"]) is bool, "study session switch differs")
    Lab.number(state["worldHours"], 0, 2**53 - 1, "study world hours")
    Lab.number(state["accumulatedWorldHours"], 0, 2**53 - 1, "accumulated study hours")
    Lab.integer(state["updatedAtUnixMs"], 0, 2**53 - 1, "study update time")
    Lab.require(state["datasetAdmission"] == "unreviewed" and state["behavioralVerdict"] is None,
                "study session crossed the review boundary")
    Lab.require(state["lastStopReason"] is None or isinstance(state["lastStopReason"], str)
                and len(state["lastStopReason"]) <= 80, "study stop reason differs")
    Lab.integer(state["feedGeneration"], 0, 2**31 - 1, "feed generation")
    Lab.require(isinstance(state["processedCommands"], list) and len(state["processedCommands"]) <= 256
                and len(set(state["processedCommands"])) == len(state["processedCommands"])
                and all(isinstance(value, str) and len(value) <= 180 for value in state["processedCommands"]),
                "processed session commands differ")
    Lab.require(state["canCheckpoint"] == (state["status"] == "running")
                and state["canContinue"] == (state["status"] == "saved"),
                "study session controls differ")
    return state


def save_state(path: Path, state, **changes):
    state.update(changes, updatedAtUnixMs=int(time.time() * 1000))
    public_state(state)
    atomic(path, state)
    return state


def new_state(label: str, duration: int, auto_continue: bool):
    state = {"schema": SCHEMA, "id": str(uuid.uuid4()), "label": label,
             "status": "starting", "attempt": 0,
             "attemptDurationSeconds": bounded_duration(duration),
             "autoContinue": auto_continue, "worldHours": 0,
             "accumulatedWorldHours": 0, "canCheckpoint": False,
             "canContinue": False, "updatedAtUnixMs": int(time.time() * 1000),
             "datasetAdmission": "unreviewed", "behavioralVerdict": None,
             "lastStopReason": None, "feedGeneration": 0, "processedCommands": []}
    return public_state(state)


def command_files(root: Path, state):
    if not root.exists():
        return []
    Lab.require(root.is_dir() and not root.is_symlink(), "unsafe study session command directory")
    processed = set(state["processedCommands"])
    return [path for path in sorted(root.glob("*.json")) if path.name not in processed]


def apply_commands(root: Path, state_path: Path, state, expected_session=None):
    continue_requested = False
    for path in command_files(root, state):
        Lab.require(path.resolve().parent == root.resolve() and not path.is_symlink()
                    and path.stat().st_size <= 8192, "unsafe study session command")
        value = Lab.load(path)
        required = {"schema", "sessionId", "sequence", "action"}
        Lab.require(isinstance(value, dict) and required <= value.keys()
                    and value["schema"] == COMMAND_SCHEMA
                    and str(uuid.UUID(value["sessionId"])) == value["sessionId"],
                    "study session command differs")
        Lab.integer(value["sequence"], 1, 2**53 - 1, "study session command sequence")
        Lab.require(expected_session is None or value["sessionId"] == expected_session,
                    "study session command belongs to another native attempt")
        Lab.require(path.name == f"{value['sessionId']}-{value['sequence']:016d}.json",
                    "study session command filename differs")
        if value["action"] == "configure":
            Lab.require(set(value) == required | {"attemptDurationSeconds", "autoContinue"}
                        and type(value["autoContinue"]) is bool, "study configuration fields differ")
            state["attemptDurationSeconds"] = bounded_duration(value["attemptDurationSeconds"])
            state["autoContinue"] = value["autoContinue"]
        elif value["action"] == "continue":
            Lab.require(set(value) == required and state["status"] == "saved",
                        "study cannot continue from this state")
            continue_requested = True
        else:
            raise ValueError("unsupported study session command")
        state["processedCommands"].append(path.name)
        state["processedCommands"] = state["processedCommands"][-256:]
        save_state(state_path, state)
        # Persist consumption before removing the immutable inbox event. A
        # crash in between sees the durable receipt and cannot replay it.
        path.unlink()
    return continue_requested


def wait_for_run(run_path: Path, process, timeout=180):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if run_path.exists():
            value = Lab.load(run_path)
            if value.get("status") == "running":
                return value
        if process.poll() is not None:
            raise subprocess.CalledProcessError(process.returncode, process.args)
        time.sleep(0.1)
    raise TimeoutError("native study did not publish a running receipt")


def stop_process(process):
    if process is None or process.poll() is not None:
        return
    process.terminate()
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        process.kill(); process.wait(timeout=10)


def recover_failed_save(state_path: Path, state, receipt):
    """Restore control only after the native validator has closed the run."""
    if state["status"] != "failed":
        Lab.require(state["status"] == "saved", "reload requires a normally saved session")
        return state
    Lab.require(receipt.get("status") == "completed" and receipt.get("exitCode") == 0
                and not receipt.get("runtimeErrors") and receipt.get("terminal"),
                "failed session has no verified native save")
    terminal = receipt["terminal"]
    elapsed = max(0, terminal["endHours"] - terminal["startHours"])
    return save_state(state_path, state, status="saved", canCheckpoint=False, canContinue=True,
                      worldHours=receipt["lastHours"],
                      accumulatedWorldHours=state["accumulatedWorldHours"] + elapsed,
                      lastStopReason=terminal.get("stopReason", "saved"))


def wait_for_terminal_projection(feed: Path, native_session: str, study_id: str,
                                 expected_status: str, timeout=5):
    """Let the bridge publish the terminal session state before it is reaped."""
    deadline = time.monotonic() + timeout
    while True:
        try:
            value = Lab.load(feed / "latest.json")
            study = value.get("study", {})
            if (value.get("schema") == "mousecat.native-view/1"
                    and value.get("sessionId") == native_session
                    and value.get("state") == "ended"
                    and study.get("id") == study_id
                    and study.get("status") == expected_status):
                return True
        except (OSError, ValueError, KeyError, TypeError):
            pass
        if time.monotonic() >= deadline:
            return False
        time.sleep(0.05)


def attempt_review_outbox(root: Path, attempt: int) -> Path:
    """Keep terminal evidence and its delivery receipt bound to one attempt."""
    Lab.integer(attempt, 1, 2**31 - 1, "review attempt")
    return root / "review" / f"{attempt:04d}"


def runner_command(args, resume, duration):
    command = [sys.executable, str(Path(__file__).with_name("world_lab_run.py")), str(args.package),
               "--out", str(args.out / "native-run"), "--game", str(args.game), "--jdk", str(args.jdk),
               "--host", "observer", "--watch", "--window", args.window,
               "--timeout", str(duration)]
    if getattr(args, "observer_layout", None) is not None:
        command.extend(("--observer-layout", str(args.observer_layout)))
    if getattr(args, "video_encoder", None) is not None:
        command.extend(("--video-encoder", str(args.video_encoder),
                        "--video-fps", str(getattr(args, "video_fps", 120))))
    if resume:
        command.append("--resume")
        if getattr(args, "refresh_observer_adapter", False):
            command.append("--refresh-observer-adapter")
    else:
        for mod in args.mod:
            command.extend(("--mod", str(mod)))
        if args.profile is not None:
            command.extend(("--profile", str(args.profile), "--catalog", str(args.catalog),
                            "--workshop-root", str(args.workshop_root)))
            for mod_id in args.enable_mod:
                command.extend(("--enable-mod", mod_id))
            for mod_id in args.disable_mod:
                command.extend(("--disable-mod", mod_id))
    return command


def watcher_command(args, feed: Path, state_path: Path, commands: Path, attempt: int):
    command = [sys.executable, str(args.watcher), "--run", str(args.out / "native-run"),
               "--package", str(args.package), "--out", str(feed),
               "--registry", str(args.registry), "--view-id", args.view_id,
               "--label", args.label, "--session-state", str(state_path),
               "--session-commands", str(commands),
               "--sao-validator", str(Path(__file__).with_name("world_lab_run.py")),
               "--review-outbox", str(attempt_review_outbox(args.out, attempt)),
               "--review-endpoint", args.review_endpoint]
    if args.project_ref:
        command.extend(("--project-ref", args.project_ref))
    if getattr(args, "site_controls", False):
        command.append("--site-controls")
    return command


def start_watcher(args, state_path, commands, state):
    state["feedGeneration"] += 1
    save_state(state_path, state)
    feed = args.out / "feeds" / f"{state['feedGeneration']:04d}"
    return subprocess.Popen(watcher_command(args, feed, state_path, commands, state["attempt"])), feed


def supervise(args):
    args.package = args.package.resolve(); args.out = args.out.resolve()
    args.game = args.game.resolve(); args.jdk = args.jdk.resolve()
    args.watcher = args.watcher.resolve(); args.registry = args.registry.resolve()
    if args.profile is not None:
        args.profile = args.profile.resolve(); args.catalog = args.catalog.resolve()
        args.workshop_root = args.workshop_root.resolve()
    state_path, commands = args.out / "study-session.json", args.out / "session-commands"
    if state_path.exists():
        state = public_state(Lab.load(state_path))
        receipt_path = args.out / "native-run/run.json"
        Lab.require(receipt_path.exists(), "saved session has no native run")
        state = recover_failed_save(state_path, state, Lab.load(receipt_path))
        save_state(state_path, state,
                   attemptDurationSeconds=(args.duration if args.duration is not None
                                           else state["attemptDurationSeconds"]),
                   autoContinue=(args.auto_continue if args.auto_continue is not None
                                 else state["autoContinue"]))
    else:
        Lab.require(not args.out.exists() or not any(args.out.iterdir()), "new study session output is not empty")
        args.out.mkdir(parents=True, exist_ok=True)
        state = new_state(args.label, args.duration if args.duration is not None else 3600,
                          bool(args.auto_continue))
        atomic(state_path, state)
    commands.mkdir(parents=True, exist_ok=True)

    runner = watcher = None
    try:
        while True:
            resume = state["attempt"] > 0
            native_session = (Lab.load(args.out / "native-run/run.json")["sessionId"]
                              if resume else None)
            if state["status"] == "saved":
                watcher, feed = start_watcher(args, state_path, commands, state)
                while True:
                    if apply_commands(commands, state_path, state, native_session):
                        save_state(state_path, state, status="continuing", canContinue=False)
                        watcher.wait(timeout=10)
                        watcher = None
                        break
                    if watcher.poll() is not None:
                        raise subprocess.CalledProcessError(watcher.returncode, watcher.args)
                    time.sleep(0.1)
            duration = state["attemptDurationSeconds"]
            save_state(state_path, state, status="continuing" if resume else "starting",
                       canCheckpoint=False, canContinue=False)
            runner = subprocess.Popen(runner_command(args, resume, duration))
            receipt = wait_for_run(args.out / "native-run/run.json", runner)
            native_session = receipt["sessionId"]
            state["attempt"] = receipt["launchNumber"]
            save_state(state_path, state, status="running", canCheckpoint=True, canContinue=False)
            watcher, feed = start_watcher(args, state_path, commands, state)
            while runner.poll() is None:
                apply_commands(commands, state_path, state, native_session)
                time.sleep(0.1)
            code = runner.returncode; runner = None
            receipt = Lab.load(args.out / "native-run/run.json")
            if code != 0 or receipt.get("status") != "completed":
                save_state(state_path, state, status="failed", canCheckpoint=False, canContinue=False,
                           lastStopReason=receipt.get("status", "runner-failed"))
                if not wait_for_terminal_projection(feed, native_session, state["id"], "failed"):
                    print("world_lab_session: terminal projection was not acknowledged", file=sys.stderr)
                return code or 1
            terminal = receipt["terminal"]
            elapsed = max(0, terminal["endHours"] - terminal["startHours"])
            reason = terminal.get("stopReason", "saved")
            save_state(state_path, state, status="saved", canCheckpoint=False, canContinue=True,
                       worldHours=receipt["lastHours"],
                       accumulatedWorldHours=state["accumulatedWorldHours"] + elapsed,
                       lastStopReason=reason)
            if state["autoContinue"] and reason == "wall-time-limit":
                stop_process(watcher); watcher = None
                save_state(state_path, state, status="continuing", canContinue=False)
                continue
            # The watcher remains on the saved final frame and accepts a later
            # continue/configure request. A restarted supervisor creates a new
            # control feed over the same verified save.
            while True:
                if apply_commands(commands, state_path, state, native_session):
                    save_state(state_path, state, status="continuing", canContinue=False)
                    watcher.wait(timeout=10)
                    watcher = None
                    break
                if watcher.poll() is not None:
                    raise subprocess.CalledProcessError(watcher.returncode, watcher.args)
                time.sleep(0.1)
    finally:
        stop_process(watcher)
        if runner is not None and runner.poll() is None:
            # The native runner owns its bounded save/cleanup path. Do not kill
            # it merely because the small orchestration process is closing.
            runner.wait()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", type=Path)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--game", required=True, type=Path)
    parser.add_argument("--jdk", required=True, type=Path)
    parser.add_argument("--mod", action="append", default=[], type=Path)
    parser.add_argument("--profile", type=Path,
                        help="validated external capability study profile")
    parser.add_argument("--catalog", type=Path, default=Path(__file__).with_name("world_lab") / "mod_catalog.json")
    parser.add_argument("--workshop-root", type=Path,
                        default=Path(r"C:\Program Files (x86)\Steam\steamapps\workshop\content\108600"))
    parser.add_argument("--enable-mod", action="append", default=[])
    parser.add_argument("--disable-mod", action="append", default=[])
    parser.add_argument("--watcher", required=True, type=Path,
                        help="Speakeasy tools/world_watch.py")
    parser.add_argument("--registry", required=True, type=Path,
                        help="Mousecat native-view registry")
    parser.add_argument("--view-id", default="survival-observatory")
    parser.add_argument("--label", default="Survival simulation")
    parser.add_argument("--review-endpoint", default="http://127.0.0.1:4317/mcp",
                        help="Mousecat MCP endpoint for immediate terminal review handoff")
    parser.add_argument("--project-ref")
    parser.add_argument("--duration", type=int,
                        help="wall seconds per native attempt (default: 3600)")
    parser.add_argument("--auto-continue", action=argparse.BooleanOptionalAction, default=None,
                        help="start another saved attempt after a wall-time checkpoint")
    parser.add_argument("--window", choices=("visible", "hidden"), default="visible")
    parser.add_argument("--observer-layout", type=Path,
                        help="native observation areas, independent of the saved world")
    parser.add_argument("--site-controls", action="store_true",
                        help="publish independent camera controls to a compatible viewer")
    parser.add_argument("--video-encoder", type=Path,
                        help="local FFmpeg executable for continuous native H.264 video")
    parser.add_argument("--video-fps", type=int, default=120,
                        help="native video capture ceiling (30-120; default: 120); renderer remains uncapped")
    parser.add_argument("--refresh-observer-adapter", action="store_true",
                        help="rebuild isolated observer infrastructure on verified continuation")
    args = parser.parse_args()
    if args.duration is not None:
        bounded_duration(args.duration)
    Lab.integer(args.video_fps, 30, 120, "native video capture ceiling")
    return supervise(args)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, OSError, KeyError, subprocess.SubprocessError) as error:
        print(f"world_lab_session: {error}", file=sys.stderr)
        raise SystemExit(1)
