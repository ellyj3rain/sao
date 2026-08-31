#!/usr/bin/env python3
r"""Border 58 - a report that runs before the thing it reports on.

From the operator's own session log, one line, at frame 240:

    [SAO][POP] day 1: 0 living, 0 dead, 0 companies, 0 at war
                      / target 0 (sandbox-governed)

Two hundred and thirty-four people were created moments later. The
boot digest - [A22]'s *"the console opens with the state of the
world"* - sat at the TOP of `populationTick`, before
`runSub("genesis", ...)`. On a new world it is structurally guaranteed
to describe an empty county, because the county has not been made yet.

A report that cannot be wrong because it never looks.

AND THE NUMBER WAS WORSE THAN THE ZEROES
----------------------------------------
`target 0`. Zero is the shipped sandbox default and it means *size it
from the map* ([B38], and [B44] put exactly that in the option's
label). The digest printed `conf.population` - the raw option - rather
than `resolveTarget(conf)`, which is what genesis actually uses and
which resolved to a real number seconds later.

So the one line meant to tell an operator what world they are in said
this mod is configured to create nobody. The most alarming thing it
could possibly say, and false.

AND THE ONE GATE THAT NEVER SPOKE
---------------------------------
Every subsystem in that tick runs through `runSub`, which counts its
own faults and marks a seam dark so the Ledger reports it. One did
not: the presence band, behind a bare `if px then` with no else. When
`getSpecificPlayer(0)` returns nothing the band simply does not
happen, no body is ever built, and nothing anywhere says why - which
is the same silence [B47] found on the panel, one level further down.

WHAT THIS CHECKS
----------------
Three things about `SAO_Population.lua`, by source order and by which
names appear where. Crude, and exact: the defect was an ordering, and
an ordering is a thing you can read.

  1. The digest is called AFTER every `runSub` in the tick.
  2. The digest resolves the target rather than printing the option.
  3. The band's gate has an else - the skip is reported, not silent.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
POP = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Population.lua"

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from menu_reach import strip_lua                       # noqa: E402

TICK = re.compile(r"^local function populationTick\(\)(.*?)^end", re.M | re.S)
DIGEST = re.compile(r"^local function bootDigest\(conf\)(.*?)^end", re.M | re.S)


def main():
    faults = []
    print("=" * 74)
    print("A REPORT THAT RUNS BEFORE THE THING IT REPORTS ON")
    print("=" * 74)

    if not POP.exists():
        print()
        print("VERDICT:")
        print("  FAULT: SAO_Population.lua is gone, so nothing here was "
              "checked and this border's silence means nothing")
        return 1
    src = strip_lua(POP.read_text(encoding="utf-8", errors="ignore"),
                    strings=False)

    digest = DIGEST.search(src)
    tick = TICK.search(src)
    if not digest:
        faults.append(
            "no `bootDigest` function - the digest is back inline, which is "
            "where it was when it reported an empty county on every new "
            "world")
    if not tick:
        faults.append(
            "no `populationTick` function to read, so the ordering this "
            "border exists to check could not be checked at all")

    if tick:
        body = tick.group(1)
        subs = [m.start() for m in re.finditer(r"runSub\s*\(", body)]
        calls = [m.start() for m in re.finditer(r"bootDigest\s*[,)]", body)]
        print(f"  runSub calls in the tick : {len(subs)}")
        print(f"  bootDigest calls         : {len(calls)}")

        if not subs:
            faults.append(
                "the tick runs no subsystems at all, so either the county "
                "does nothing or this border is reading the wrong function")
        elif not calls:
            faults.append(
                "the tick never calls bootDigest, so the county opens "
                "silently and [A22]'s line - the one that says what world "
                "you are in - is gone")
        elif min(calls) < max(subs):
            faults.append(
                "bootDigest is called before the last runSub. On a new "
                "world the subsystems below it have not made the county "
                "yet, so the digest describes an empty one - which is "
                "exactly what the operator's log caught it doing: "
                "'0 living, 0 dead' immediately before 234 people were "
                "created")

        gate = re.search(r"if px then(.*?)^    end", body, re.S | re.M)
        if not gate:
            faults.append(
                "the presence band's gate is not the shape this border "
                "knows how to read; check by hand that a skipped band "
                "still reports, and re-teach this border")
        elif "else" not in gate.group(1):
            faults.append(
                "the band's `if px then` has no else. Every other "
                "subsystem in this tick runs through runSub and marks a "
                "seam dark when it dies; this one just does not happen. "
                "No body gets built and nothing says why, which is "
                "[B47]'s silence one level further down")

    if digest:
        body = digest.group(1)
        resolves = "resolveTarget(" in body
        print(f"  digest resolves the target: {resolves}")
        if not resolves:
            faults.append(
                "bootDigest does not call resolveTarget. The sandbox "
                "default is 0 and 0 means 'size it from the map', so "
                "printing the raw option makes the county's opening line "
                "read 'target 0' - this mod is configured to create "
                "nobody - while genesis goes on to create two hundred "
                "and thirty-four people")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print("  58) digest order: the county's opening line runs after the "
          "county exists, names the resolved target, and the one gate "
          "that could silently skip the live half now says so")
    return 0


if __name__ == "__main__":
    sys.exit(main())
