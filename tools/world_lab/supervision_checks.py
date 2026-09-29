"""Bounded lifecycle checks; no gameplay or throughput claims."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
from unittest.mock import patch

import world_lab_run as Run
import world_lab_supervision as S


class Clock:
    def __init__(self):
        self.now = 0

    def read(self):
        return self.now

    def advance(self, seconds):
        self.now += seconds


class Child:
    def __init__(self, clock, exits=None):
        self.clock, self.exits, self.returncode = clock, exits, None
        self.terminations = 0

    def poll(self):
        if self.exits is not None and self.clock.now >= self.exits:
            self.returncode = 0
        return self.returncode

    def terminate(self):
        self.terminations += 1
        self.returncode = 99

    def kill(self):
        self.terminate()

    def wait(self, timeout=None):
        assert self.returncode is not None, "unbounded child wait"
        return self.returncode


def run():
    with tempfile.TemporaryDirectory(prefix="study-supervision-") as folder:
        root = Path(folder)
        stop = root / "cache/Lua/stop.txt"
        clock = Clock()
        child = Child(clock)
        result = S.supervise(child, root, stop, 4, False, clock=clock.read, sleep=clock.advance,
                             shutdown_grace=2, own_job=False)
        assert result["stopReason"] == "wall-time-limit" and result["forced"]
        assert child.terminations == 1 and clock.now == 6, "live child escaped wall limit"
        assert stop.read_text().strip() == "wall-time-limit"

        clock = Clock()
        child = Child(clock, exits=4.5)
        result = S.supervise(child, root, stop, 4, False, clock=clock.read, sleep=clock.advance,
                             shutdown_grace=2, own_job=False)
        assert result["stopReason"] == "wall-time-limit" and not result["forced"]
        assert result["failure"] is None and child.terminations == 0, "native shutdown was killed"

        (root / "stderr.log").write_text("java.lang.OutOfMemoryError: Java heap space\n")
        clock = Clock()
        child = Child(clock)
        result = S.supervise(child, root, stop, 600, False, clock=clock.read, sleep=clock.advance,
                             shutdown_grace=2, own_job=False)
        assert result["failure"] == "OutOfMemoryError" and child.terminations == 1 and clock.now == 2
        assert Run.runtime_errors("", "java.lang.OutOfMemoryError: Java heap space"), "OOM hidden by log parser"
        (root / "stderr.log").write_text("")

        progress = S.Progress(root / "observer-state.json", "logicCalls", 0)
        assert progress.failure(2, 3, 1) is None
        assert progress.failure(3, 3, 1).startswith("missing"), "missing startup heartbeat accepted"
        for counter in range(4, 8):
            progress.path.write_text(json.dumps({"logicCalls": counter, "paused": True, "hours": 1}))
            assert progress.failure(counter, 3, 1) is None, "pause was treated as a stalled simulation"
        assert progress.failure(8, 3, 1).startswith("stalled"), "frozen heartbeat renewed itself"
        progress.path.write_text("{")
        assert progress.failure(9, 3, 1).startswith("stalled"), "partial publication renewed heartbeat"
        progress.path.write_text(json.dumps({"logicCalls": 1}))
        assert progress.failure(10, 3, 1).startswith("regressed")
        progress.path.write_text(json.dumps({"status": "failed", "logicCalls": 10}))
        assert progress.failure(10, 3, 1).startswith("failed")

        clock = Clock()
        child = Child(clock)
        result = S.supervise(child, root, stop, 600, True, clock=clock.read, sleep=clock.advance,
                             startup_grace=3, stale_seconds=1, shutdown_grace=2, own_job=False)
        assert result["stopReason"] == "producer-failure" and result["forced"]
        assert child.terminations == 1 and "observer-state" in result["failure"]

        # Loss of the supervisor's ability to publish must still reap its child.
        clock = Clock()
        child = Child(clock)
        blocking = root / "file-not-directory"
        blocking.write_text("fixture")
        try:
            S.supervise(child, root, blocking / "stop.txt", 1, False, clock=clock.read,
                        sleep=clock.advance, own_job=False)
        except OSError:
            pass
        else:
            raise AssertionError("failed stop publication was concealed")
        assert child.terminations == 1, "supervisor failure orphaned its child"

        clock = Clock()
        child = Child(clock)
        try:
            with patch.object(S, "own_runner_lifetime"), patch.object(S.subprocess, "Popen", return_value=child):
                with S.owned_child(["fixture"]):
                    raise OSError("run publication failed immediately after spawn")
        except OSError:
            pass
        assert child.terminations == 1, "post-spawn publication failure orphaned child"

        log = ("[StudyLaunch] started attempt=1 save=fixture hours=2\n"
               "[StudyLaunch] wall-limit attempt=1 save=fixture start=2 end=2.4\n"
               "[StudyLaunch] native-save-returned attempt=1\n")
        assert Run.terminal(log, 1, "fixture", 1, True)["stopReason"] == "wall-time-limit"
        for invalid in (log, log.replace("start=2", "start=1"), log.replace("end=2.4", "end=1"),
                        log + "[StudyObserver] stop hours=2.4\n"):
            try:
                Run.terminal(invalid, 1, "fixture", 1, invalid != log)
            except ValueError:
                pass
            else:
                raise AssertionError("wall-limit receipt passed as a horizon or admitted invalid identity/time")

        supervised = ("[StudyLaunch] started attempt=1 save=fixture hours=2\n"
                      "[StudyWorld] frame=2 hours=2.4 loaded=10 people=2\n"
                      "[StudyLaunch] supervisor-stop attempt=1 save=fixture start=2 end=2.4 reason=checkpoint\n"
                      "[StudyLaunch] native-save-returned attempt=1\n")
        result = Run.terminal(supervised, 1, "fixture", 1, True, 2.4)
        assert result["stopReason"] == "checkpoint" and result["endHours"] == 2.4
        legacy = supervised.replace(" save=fixture start=2 end=2.4", "")
        recovered = Run.terminal(legacy, 1, "fixture", 1, True, 2.4)
        assert recovered["receiptFormat"] == "supervisor-stop/1-recovered"
        for invalid in (supervised + supervised, legacy.replace("frame=2 hours=2.4", "frame=2 hours=2.3"),
                        supervised.replace("save=fixture start=2", "save=other start=2")):
            try:
                Run.terminal(invalid, 1, "fixture", 1, True, 2.4)
            except ValueError:
                pass
            else:
                raise AssertionError("invalid supervisor-stop terminal receipt was admitted")

    if os.name == "nt":
        child = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(30)"],
                                 creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            job = S.OwnedJob(child)
            job.close()
            # Windows chooses the exit code for kill-on-close; the evidence is
            # that a 30-second child is reaped within this five-second bound.
            assert child.wait(timeout=5) is not None, "job closure orphaned the native-child substitute"
        finally:
            if child.poll() is None:
                child.terminate()
                child.wait(timeout=5)
        with tempfile.TemporaryDirectory(prefix="study-owner-loss-") as folder:
            marker = Path(folder) / "child.pid"
            parent_code = (
                "import sys,subprocess,time; from pathlib import Path; "
                "sys.path.insert(0,sys.argv[1]); import world_lab_supervision as s; "
                "s.own_runner_lifetime(); "
                "child=subprocess.Popen([sys.executable,'-c','import time; time.sleep(30)'],"
                "creationflags=subprocess.CREATE_NO_WINDOW); "
                "Path(sys.argv[2]).write_text(str(child.pid)); time.sleep(30)"
            )
            parent = subprocess.Popen([sys.executable, "-c", parent_code,
                                       str(Path(S.__file__).parent), str(marker)],
                                      creationflags=subprocess.CREATE_NO_WINDOW)
            handle = None
            try:
                until = time.monotonic() + 5
                while not marker.exists() and parent.poll() is None and time.monotonic() < until:
                    time.sleep(0.02)
                assert marker.exists(), "owned launcher failed before child publication"
                api = S.ctypes.WinDLL("kernel32", use_last_error=True)
                api.OpenProcess.argtypes = (S.wintypes.DWORD, S.wintypes.BOOL, S.wintypes.DWORD)
                api.OpenProcess.restype = S.wintypes.HANDLE
                api.WaitForSingleObject.argtypes = (S.wintypes.HANDLE, S.wintypes.DWORD)
                api.WaitForSingleObject.restype = S.wintypes.DWORD
                api.CloseHandle.argtypes = (S.wintypes.HANDLE,)
                handle = api.OpenProcess(0x100000, False, int(marker.read_text()))
                assert handle, "cannot observe owned test child"
                assert api.WaitForSingleObject(handle, 0) == 258, "test child exited before owner loss"
                parent.terminate()
                parent.wait(timeout=5)
                assert api.WaitForSingleObject(handle, 5000) == 0, "hard supervisor death orphaned new child"
            finally:
                if parent.poll() is None:
                    parent.terminate()
                    parent.wait(timeout=5)
                if handle:
                    api.CloseHandle(handle)
    print("PASS bounded native supervision: wall limit, fatal error, pause, stale/failed producer, shutdown and owner loss")


if __name__ == "__main__":
    run()
