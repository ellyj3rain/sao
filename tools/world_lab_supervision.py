"""Wall-bounded supervision of the runner's own native child process."""
from __future__ import annotations

import ctypes
from contextlib import contextmanager
from ctypes import wintypes
import json
import os
from pathlib import Path
import subprocess
import time


class OwnedJob:
    """Windows closes this unnamed job if the supervising Python process dies.

    Only the Popen child is assigned. Closing the job cannot terminate the
    user's other games, viewers, shells or Python processes.
    """
    def __init__(self, process=None):
        self.handle = None
        self.runner_lifetime = process is None
        if os.name != "nt":
            return
        size = ctypes.c_size_t

        class Limits(ctypes.Structure):
            _fields_ = [("processTime", ctypes.c_int64), ("jobTime", ctypes.c_int64),
                        ("flags", wintypes.DWORD), ("minWorkingSet", size),
                        ("maxWorkingSet", size), ("activeProcesses", wintypes.DWORD),
                        ("affinity", size), ("priority", wintypes.DWORD),
                        ("scheduling", wintypes.DWORD)]

        class Extended(ctypes.Structure):
            _fields_ = [("limits", Limits), ("ioCounters", ctypes.c_uint64 * 6),
                        ("processMemory", size), ("jobMemory", size),
                        ("peakProcessMemory", size), ("peakJobMemory", size)]

        self.api = ctypes.WinDLL("kernel32", use_last_error=True)
        self.api.CreateJobObjectW.argtypes = (ctypes.c_void_p, wintypes.LPCWSTR)
        self.api.CreateJobObjectW.restype = wintypes.HANDLE
        self.api.SetInformationJobObject.argtypes = (wintypes.HANDLE, ctypes.c_int,
                                                     ctypes.c_void_p, wintypes.DWORD)
        self.api.SetInformationJobObject.restype = wintypes.BOOL
        self.api.AssignProcessToJobObject.argtypes = (wintypes.HANDLE, wintypes.HANDLE)
        self.api.AssignProcessToJobObject.restype = wintypes.BOOL
        self.api.CloseHandle.argtypes = (wintypes.HANDLE,)
        self.api.CloseHandle.restype = wintypes.BOOL
        handle = self.api.CreateJobObjectW(None, None)
        if not handle:
            raise ctypes.WinError(ctypes.get_last_error())
        try:
            settings = Extended()
            settings.limits.flags = 0x2000  # JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
            if not self.api.SetInformationJobObject(handle, 9, ctypes.byref(settings), ctypes.sizeof(settings)):
                raise ctypes.WinError(ctypes.get_last_error())
            # The pseudo-handle -1 names this supervising process. Its future
            # children inherit job membership at CreateProcess time.
            target = -1 if process is None else int(process._handle)
            if not self.api.AssignProcessToJobObject(handle, wintypes.HANDLE(target)):
                raise ctypes.WinError(ctypes.get_last_error())
        except BaseException:
            self.api.CloseHandle(handle)
            raise
        self.handle = handle

    def close(self):
        if self.handle is not None:
            if self.runner_lifetime:
                raise RuntimeError("runner job belongs to the process lifetime")
            self.api.CloseHandle(self.handle)
            self.handle = None


_runner_job = None


def own_runner_lifetime():
    """Own future children before creation, including a crash immediately after.

    This unnamed, non-inherited handle is deliberately held until the runner
    process exits. Windows then closes it even after forced termination. Only
    this dedicated runner and children created afterwards join this job.
    """
    global _runner_job
    if os.name == "nt" and _runner_job is None:
        _runner_job = OwnedJob()


def reap(process):
    if process.poll() is None:
        try:
            process.terminate()
        except (ProcessLookupError, PermissionError):
            if process.poll() is None:
                raise
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


@contextmanager
def owned_child(command, **kwargs):
    own_runner_lifetime()
    process = subprocess.Popen(command, **kwargs)
    try:
        yield process
    finally:
        reap(process)


class LogTail:
    def __init__(self, path):
        self.path, self.offset, self.tail = Path(path), 0, b""

    def failure(self):
        try:
            with self.path.open("rb") as stream:
                stream.seek(self.offset)
                chunk = stream.read(1024 * 1024)
                self.offset = stream.tell()
        except FileNotFoundError:
            return None
        text = self.tail + chunk
        self.tail = text[-256:]
        for marker in (b"OutOfMemoryError", b"[StudyWorld] stopped", b"[StudyObserver] FAILED",
                       b"A fatal error has been detected by the Java Runtime Environment"):
            if marker in text:
                return marker.decode("ascii")
        return None


class Progress:
    def __init__(self, path, field, started):
        self.path, self.field = Path(path), field
        self.value, self.last, self.seen = None, started, False

    def failure(self, now, startup_grace, stale_seconds):
        try:
            if self.path.stat().st_size > 64 * 1024:
                return "oversized " + self.path.name
            value = json.loads(self.path.read_bytes())
            if value.get("status") == "failed":
                return "failed " + self.path.name
            progress = value[self.field]
            if isinstance(progress, bool) or not isinstance(progress, int) or progress < 0:
                raise ValueError("invalid heartbeat")
            if self.value is not None and progress < self.value:
                return "regressed " + self.path.name
            if progress != self.value:
                self.value, self.last, self.seen = progress, now, True
        except (OSError, ValueError, KeyError, TypeError):
            # A brief unavailable/partial publication never renews the lease.
            pass
        limit = stale_seconds if self.seen else startup_grace
        if now - self.last >= limit:
            return "stalled " + self.path.name if self.seen else "missing " + self.path.name
        return None


def stop_request(path, reason):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(".tmp")
    temporary.write_text(reason + "\n", encoding="ascii")
    os.replace(temporary, path)


def supervise(process, attempt, stop_path, timeout, observer, *, clock=time.monotonic,
              sleep=time.sleep, startup_grace=180, stale_seconds=45, shutdown_grace=30,
              own_job=True):
    """Request native exit first, then reap only our child if it cannot exit.

    UI pause still advances logicCalls and captured-image sequence. World age
    intentionally is not a heartbeat: a paused simulation is healthy.
    """
    attempt = Path(attempt)
    started = clock()
    progress = [Progress(attempt / "observer-state.json", "logicCalls", started),
                Progress(attempt / "native-view/native.json", "sequence", started)] if observer else []
    logs = [LogTail(attempt / name) for name in ("stdout.log", "stderr.log")]
    reason, failure, requested, forced, job = None, None, None, False, None
    try:
        job = OwnedJob(process) if own_job else None
        while process.poll() is None:
            now = clock()
            if requested is None:
                found = next((why for item in logs if (why := item.failure())), None)
                if not found:
                    found = next((why for item in progress
                                  if (why := item.failure(now, startup_grace, stale_seconds))), None)
                if found:
                    reason, failure = "producer-failure", found
                elif now - started >= timeout:
                    reason = "wall-time-limit"
                if reason:
                    requested = now
                    stop_request(stop_path, reason)
            elif now - requested >= shutdown_grace:
                forced = True
                failure = failure or "native shutdown exceeded its grace period"
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)
                break
            sleep(0.25)
        return {"wallSeconds": round(clock() - started, 3), "limitSeconds": timeout,
                "stopReason": reason, "failure": failure, "forced": forced,
                "exitCode": process.returncode,
                "progress": {item.path.name: item.value for item in progress}}
    finally:
        # Includes Ctrl-C, failure to create the job and failures to publish a
        # stop request. A failed supervisor must not leave its child running.
        if job:
            job.close()
        reap(process)
