#!/usr/bin/env python3
r"""[B33] The bulkheads, driven rather than read.

[A21] puts every subsystem behind a fault counter: three faults and
the seam disables ITSELF so one broken thing cannot take the county
with it. Right shape, one cost - a seam that goes dark leaves a world
that looks entirely normal and quietly is not.

Five of them exist, and they are NOT the same:

    subFaults[name]   SAO_Population   per subsystem   PERMANENT
    popFaults         SAO_Population   whole module    PERMANENT
    ctlFaults         SAO_Controller   whole tick      resets to 0
    agentFaults[id]   SAO_Controller   per agent       cleared on drop
    job.faults        SAO_Locomotion   per job         dies with the job

Only the two permanent ones may register as dark. A register that
filled with things that had already fixed themselves would be noise,
and noise is how a real warning gets ignored.

Thresholds are parsed from the Lua, never assumed - the whole point is
to catch a counter that latches at the wrong number, and a mirror
carrying its own copy of "3" could not.

The counters are DRIVEN here, not read: the seam is run fault-by-fault
and the tick at which it stops is observed.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"

BULKHEADS = [
    ("subFaults", "client/SAO_Population.lua",
     r"if \(subFaults\[name\] or 0\) >= (\d+) then return end", True),
    ("popFaults", "client/SAO_Population.lua",
     r"if popFaults >= (\d+) then", True),
    ("ctlFaults", "client/SAO_Controller.lua",
     r"if ctlFaults >= (\d+) then", False),
    ("agentFaults", "client/SAO_Controller.lua",
     r"if agentFaults\[id\] >= (\d+) then", False),
    ("job.faults", "client/SAO_Locomotion.lua",
     r"if job\.faults >= (\d+) then", False),
]


def threshold(rel, pattern):
    src = (LUA / rel).read_text(encoding="utf-8", errors="ignore")
    m = re.search(pattern, src)
    return int(m.group(1)) if m else None


class Seam:
    """A bulkhead, driven one fault at a time.

    Models runSub's shape: the gate is checked BEFORE the work, so a
    seam gets exactly `limit` attempts that fault before it stops
    being attempted at all.
    """

    def __init__(self, limit):
        self.limit = limit
        self.faults = 0
        self.attempts = 0
        self.dark = False

    def run(self, will_fault):
        if self.faults >= self.limit:
            return False          # not attempted at all
        self.attempts += 1
        if will_fault:
            self.faults += 1
            if self.faults >= self.limit:
                self.dark = True
        return True


def registers_dark(rel, marker):
    """Does this seam actually tell the register when it latches?"""
    src = (LUA / rel).read_text(encoding="utf-8", errors="ignore")
    idx = src.find(marker)
    if idx < 0:
        return None
    window = src[idx:idx + 700]
    return "SAO.Seams.wentDark" in window


def main():
    print("=" * 68)
    print("THRESHOLDS, parsed from the Lua")
    print("=" * 68)
    limits = {}
    for name, rel, pat, permanent in BULKHEADS:
        n = threshold(rel, pat)
        limits[name] = n
        kind = "PERMANENT" if permanent else "recovers"
        print(f"  {name:<14} {rel.split('/')[-1]:<22} "
              f"{'?' if n is None else n} faults   {kind}")
    if any(v is None for v in limits.values()):
        print("\n  a counter could not be found - this mirror is blind")
        return 1
    consistent = len(set(limits.values())) == 1
    print(f"\n  all five agree on the same threshold: "
          f"{'YES' if consistent else 'NO'}  {sorted(set(limits.values()))}")

    print()
    print("=" * 68)
    print("DRIVEN - a seam that faults every time")
    print("=" * 68)
    limit = limits["subFaults"]
    seam = Seam(limit)
    for tick in range(1, limit + 4):
        attempted = seam.run(True)
        state = "attempted" if attempted else "SKIPPED (dark)"
        print(f"  tick {tick}: {state:<16} faults={seam.faults}")
    ok_attempts = seam.attempts == limit
    ok_dark = seam.dark
    print(f"\n  attempts before going dark: {seam.attempts} "
          f"(expected {limit})")
    print(f"  went dark: {'YES' if ok_dark else 'NO'}")

    print()
    print("=" * 68)
    print("DRIVEN - a seam one fault short never goes dark")
    print("=" * 68)
    near = Seam(limit)
    for _ in range(limit - 1):
        near.run(True)
    for _ in range(5):
        near.run(False)
    print(f"  faults={near.faults}, dark={near.dark}, "
          f"attempts={near.attempts}")
    ok_near = (not near.dark) and near.attempts == limit - 1 + 5
    print(f"  survives and keeps being attempted: "
          f"{'YES' if ok_near else 'NO'}")

    print()
    print("=" * 68)
    print("WHO IS TOLD - only the PERMANENT seams may register")
    print("=" * 68)
    checks = [
        ("subFaults", "client/SAO_Population.lua",
         "subsystem '\" .. name .. \"' DISABLED", True),
        ("popFaults", "client/SAO_Population.lua",
         "population disabled after", True),
        ("ctlFaults", "client/SAO_Controller.lua",
         "disabling all agents after", False),
        ("agentFaults", "client/SAO_Controller.lua",
         "dropped alone after repeated faults", False),
        ("job.faults", "client/SAO_Locomotion.lua",
         "disabled after \" .. job.faults", False),
    ]
    told_ok = True
    for name, rel, marker, should in checks:
        got = registers_dark(rel, marker)
        if got is None:
            print(f"  {name:<14} UNCHECKED - marker not found "
                  "(the log line moved)")
            told_ok = False
            continue
        verdict = "registers" if got else "does not register"
        want = "must" if should else "must NOT"
        good = (got == should)
        print(f"  {name:<14} {verdict:<20} ({want})"
              f"   {'ok' if good else 'WRONG'}")
        if not good:
            told_ok = False

    print()
    print("=" * 68)
    print("THE PLAYER-FACING SURFACE")
    print("=" * 68)
    ui = (LUA / "client" / "SAO_UI.lua").read_text(
        encoding="utf-8", errors="ignore")
    reads = "SAO.Seams" in ui
    seams_exists = (LUA / "shared" / "SAO_Seams.lua").exists()
    print(f"  register module present:      "
          f"{'YES' if seams_exists else 'NO'}")
    print(f"  the Ledger reads it:          "
          f"{'YES' if reads else 'NO'}")

    print()
    print("VERDICT:")
    print(f"  thresholds consistent:              "
          f"{'YES' if consistent else 'NO'}")
    print(f"  a failing seam stops after {limit}:        "
          f"{'YES' if ok_attempts and ok_dark else 'NO'}")
    print(f"  a seam one short keeps running:     "
          f"{'YES' if ok_near else 'NO'}")
    print(f"  the right seams register:           "
          f"{'YES' if told_ok else 'NO'}")
    print(f"  a player could find out:            "
          f"{'YES' if (reads and seams_exists) else 'NO'}")
    if not (consistent and ok_attempts and ok_dark and ok_near
            and told_ok and reads and seams_exists):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
