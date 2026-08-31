#!/usr/bin/env python3
r"""Border 64 - a tick is a frame, so a tick count is not a duration.

Established from the operator's own session log, not from memory.

The boot digest fires when `tickCounter % TICK_INTERVAL == 0` with
`TICK_INTERVAL = 240`, and in the log it appears at **frame 240**. The
two counters are the same counter: `OnTick` runs once per rendered
frame. And that machine ran at **64.5 frames a second** over its 217
seconds of play - not 60.

So every comment in this tree that read `600 ticks -- ~10s` was wrong
everywhere except on a machine holding exactly sixty. It was 9.3s for
the operator, 20s at 30fps, 4.2s at 144Hz.

Worse than the comments: the county's pace is the player's hardware.
Better frames, faster county.

TWO CLAUSES
-----------
1. **A duration comment must name its assumption.** Any comment stating
   seconds within a few lines of a frame count has to say `fps` or
   `frames`, so the next reader knows the number is conditional rather
   than a fact. Cheap, and it makes the assumption impossible to state
   silently again.

2. **What the player feels in real time must be measured in real
   time.** `REAL_TIME` names the places where a tick count would make
   the simulation depend on the frame rate in a way somebody would
   notice, and requires each to read the engine's own wall clock.
   Today that is the voice cooldown: it exists so a survivor does not
   talk over themselves, that is about the player's ears, and ears keep
   real time regardless of what the graphics card manages.

Only one entry, and it is argued rather than listed. The rest of the
tree counts frames on purpose - a decision cadence, a roam interval and
a population pulse are all simulation pacing, and pacing that rides the
frame budget is a defensible choice as long as nobody calls it seconds.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from menu_reach import strip_lua                       # noqa: E402

# `~10s`, `10s`, `30s .. 90s`, `ten seconds` are all duration claims.
SECONDS = re.compile(r"~?\d+(?:\.\d+)?\s*s\b|\bseconds\b")
# No leading word boundary: "30fps" has none, and the first draft of
# this border flagged its own explanation for saying it.
NAMES_IT = re.compile(r"fps|frame", re.I)
# A constant already measured in milliseconds is real time by
# construction and has nothing to assume about frames.
REAL_CLOCK = re.compile(r"_MS\b|nowMs|getTimestampMs", re.I)
COMMENT = re.compile(r"--(.*)$")

# Where a tick count would make the simulation follow the frame rate in
# a way the player would feel, and what must therefore read the clock.
REAL_TIME = {
    "SAO_Voice.lua": (
        "getTimestampMs",
        "the cooldown between a person's spoken lines. It exists so a "
        "survivor does not talk over themselves, which is about the "
        "player's ears; ears keep real time whatever the graphics card "
        "manages. In frames it was 20s at 30fps and 4.2s at 144Hz - the "
        "better your hardware, the chattier the county"),
}


def main():
    faults = []
    print("=" * 74)
    print("A TICK IS A FRAME")
    print("=" * 74)

    srcs = {p: p.read_text(encoding="utf-8", errors="ignore")
            for p in sorted(LUA.rglob("*.lua"))}
    if not srcs:
        print()
        print("VERDICT:")
        print("  FAULT: no Lua was read, so nothing here was checked")
        return 1

    claims, named = 0, 0
    for path, raw in srcs.items():
        lines = raw.split("\n")
        for n, line in enumerate(lines, 1):
            m = COMMENT.search(line)
            if not m or not SECONDS.search(m.group(1)):
                continue
            # Only comments sitting on or beside a frame count - prose
            # elsewhere in the file is discussing the world, not
            # promising a cadence.
            window = "\n".join(lines[max(0, n - 3):n + 2])
            if not re.search(r"=\s*\d{2,}|\btick", window, re.I):
                continue
            if REAL_CLOCK.search(window):
                continue
            claims += 1
            if NAMES_IT.search(m.group(1)) or NAMES_IT.search(window):
                named += 1
            else:
                faults.append(
                    f"{path.name}:{n} states a duration beside a frame "
                    "count and does not say so: \"" + m.group(1).strip()[:60]
                    + "\". A tick is one rendered frame - the operator's "
                    "machine ran at 64.5 of them a second, and a 30fps "
                    "machine would halve every number here. Say `fps` or "
                    "`frames`, so the next reader knows the seconds are "
                    "conditional")

    print(f"  duration claims beside a frame count: {claims}")
    print(f"  naming the assumption               : {named}")

    if claims == 0:
        faults.append(
            "not one duration claim was found next to a frame count, which "
            "cannot be true of a mod whose every cadence is a tick count - "
            "the reading failed rather than the code being clean")

    for name, (needle, why) in sorted(REAL_TIME.items()):
        src = next((s for p, s in srcs.items() if p.name == name), None)
        if src is None:
            faults.append(
                f"REAL_TIME names {name} and no such file exists - the "
                "entry describes no code")
            continue
        if needle not in strip_lua(src, strings=False):
            faults.append(
                f"{name} no longer reads `{needle}`, so it is back to "
                f"counting frames. That is {why}")

    print(f"  must keep real time                 : {len(REAL_TIME)} "
          f"({', '.join(sorted(REAL_TIME)) or 'none'})")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  64) tick duration: all {claims} duration claims name the "
          f"frame rate they assume, and the {len(REAL_TIME)} thing(s) the "
          "player feels in real time read the engine's clock")
    return 0


if __name__ == "__main__":
    sys.exit(main())
