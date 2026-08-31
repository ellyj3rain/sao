#!/usr/bin/env python3
r"""Border 30 - a trade can find the book its road back rides on.

[B22] built the road back: *"A struggling medic can read, the
dressings start holding, and the evidence against them stops
accumulating. When there is no book there is no road, and the job goes
to someone else - which is the scarcity doing its work."*

For one designation in five the road could never open, and it looked
exactly like scarcity.

TWO VOCABULARIES FOR ONE SKILL
------------------------------
`Census.JOB_PERK` holds PERK IDS - what `PerkFactory.PerkList` calls a
skill, which is what `getPerkLevel` matches against. Item scripts use
a different keyword for the same thing:

    perk id                 Doctor
    script keyword          SkillTrained = FirstAid

`SAONeeds.teachesPerk` compares `book.getSkillTrained()` against the
string it is handed, with `equalsIgnoreCase`. Hand it a perk id and
the medic's book is never found - `readSkillBook` returns "", and the
branch below reads that as "the place does not hold one".

Measured against the shipped scripts: **zero** books train `Doctor`,
**five** train `FirstAid`.

WHAT THIS CHECKS
----------------
Every value in `JOB_PERK`, resolved through `BOOK_SKILL`, must name a
keyword some shipped book actually trains - or be declared bookless
with a reason. The corpus is the game's own `media/scripts`, so a
build that renames a skill fails here rather than quietly closing
somebody's road back.

It deliberately does NOT require every perk to have a book. `scout`
rides `Lightfooted`, and no book in the game trains it under any
spelling - that is the game's truth and [B22]'s "no book, no road"
handles it honestly. The fault is a name that CANNOT match, not a
skill nobody wrote a manual for.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CENSUS = (ROOT / "mod" / "42.20" / "media" / "lua" / "shared"
          / "SAO_Census.lua")
CTRL = (ROOT / "mod" / "42.20" / "media" / "lua" / "client"
        / "SAO_Controller.lua")
SCRIPTS = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"
    r"\media\scripts")

# Perks no shipped book teaches, with the reason. A skill nobody wrote
# a manual for is the game's answer, not a defect in ours.
BOOKLESS = {
    "Lightfooted": "no shipped book trains it under any spelling; the "
                   "scout's road back is closed by the game, not by a "
                   "name that cannot match",
}


def table(src, name):
    m = re.search(rf"Census\.{name} = \{{(.*?)\n\}}", src, re.S)
    if not m:
        raise SystemExit(f"book_vocabulary: Census.{name} moved; blind")
    out = dict(re.findall(r"(\w+)\s*=\s*\"([^\"]+)\"", m.group(1)))
    if not out:
        raise SystemExit(f"book_vocabulary: parsed no {name} rows; blind")
    return out


def shipped_keywords():
    if not SCRIPTS.exists():
        return None
    found = set()
    for f in SCRIPTS.rglob("*.txt"):
        try:
            text = f.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        found.update(re.findall(r"SkillTrained\s*=\s*([A-Za-z]+)", text))
    return found


def main():
    src = CENSUS.read_text(encoding="utf-8", errors="ignore")
    ctrl = CTRL.read_text(encoding="utf-8", errors="ignore")
    jobs = table(src, "JOB_PERK")
    books = table(src, "BOOK_SKILL")

    keywords = shipped_keywords()
    if keywords is None:
        print("30) book vocabulary: SKIPPED - no game install to read "
              "the shipped item scripts from")
        return 0

    print("=" * 74)
    print(f"THE ROAD BACK, PER TRADE - {len(keywords)} skills have books")
    print("=" * 74)
    print(f"  {'designation':<12} {'perk id':<14} {'asks a book for':<14} "
          f"books")
    faults = []
    for job in sorted(jobs):
        perk = jobs[job]
        asks = books.get(perk, perk)
        n = sum(1 for k in keywords if k.lower() == asks.lower())
        if n:
            note = ""
        elif perk in BOOKLESS:
            note = "  (bookless, by the game)"
        else:
            note = "  <- ASKS FOR A BOOK THAT CANNOT EXIST"
            faults.append(
                f"{job} rides perk {perk!r} and asks books for "
                f"{asks!r}, which no shipped book trains - the road "
                "back cannot open and it reads as scarcity")
        print(f"  {job:<12} {perk:<14} {asks:<14} {n}{note}")

    print()
    for perk, why in sorted(BOOKLESS.items()):
        print(f"  bookless: {perk} - {why}")

    # A mapping that maps nothing is worse than none: it looks like the
    # problem is handled.
    useless = [k for k, v in books.items() if k == v]
    for k in useless:
        faults.append(f"BOOK_SKILL maps {k!r} to itself, which does "
                      "nothing and reads as though it did")

    # [B41] The subject is read, not just held. `rec.reading` has
    # always carried the item's full type and every reader tested
    # truthiness, so a survivor carried a specific manual and the
    # county knew only that they held something.
    links = {
        "the book's subject is read from the engine":
            "it46:getSkillTrained()" in ctrl,
        "a manual goes to whoever the work belongs to":
            "if wants46 then" in ctrl
            and "SAO.Census.bookSkillFor(jp46)" in ctrl,
        "and boredom still decides who gets a novel":
            "elseif not passedTo" in ctrl
            and "(tonumber(bored46) or 0) > 0.3" in ctrl,
        "the study path asks for a book keyword":
            "local book48 = SAO.Census.bookSkillFor(perk48)" in ctrl,
        "and reads with it": "readSkillBook(body, book48)" in ctrl,
        "and fetches with it": "body, 10, book48)" in ctrl,
        "the perk id is still used for skill levels":
            "SAO.Census.JOB_PERK[idleRec.designation]" in ctrl,
    }
    print()
    for k, v in links.items():
        print(f"  {'yes' if v else 'NO '}  {k}")
        if not v:
            faults.append(k)

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  30) book vocabulary: {len(jobs)} trades, every one asks "
          "for a book that can exist")
    return 0


if __name__ == "__main__":
    sys.exit(main())
