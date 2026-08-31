#!/usr/bin/env python3
r"""Border 78 - four answers, spelled five ways.

`SAO_Controller` states the domain in its own comment:

    The four answers (DR-011, [A18]): what is the pressure doing to
    this body right now - need, designation, chosen rest, or errand.

Every transition passes through `setState`, which fills the answer from
an explicit argument, then a per-state map, then `"errand"`. It is one
of the load-bearing facts about this framework: a survivor is never
doing nothing, and what they are doing is one of four things.

[B52] found the tree spelling five. Four sites answered `"rest"` and
three answered `"chosen rest"` - the evening seat, sleep, a short rest
with a weapon in reach, and a mourner standing where somebody fell,
against a roamer who chose to stop and a sweep that can keep till
morning.

**It cost nothing, and that is the problem.** Nothing in the tree
compares against either spelling; the three behavioural readers ask
`== "need"` and `== "designation"`. So the split was free, invisible,
and waiting - the day somebody writes `answer == "chosen rest"` it
silently misses four of the seven rests in the county, and the bug is
in code that was written years after the mistake.

This is Border 11's shape for designations, applied to the answer.

WHAT IS CHECKED
---------------
  * every literal an answer is ASSIGNED - the per-state map's values,
    the `or "errand"` fallback, a `pressure = { answer = "..." }`, and
    `setState`'s fifth argument - is one of the four
  * every literal an answer is COMPARED AGAINST is one of the four, so
    a reader cannot ask for a value nothing sets
  * every one of the four is actually produced somewhere, so the
    domain describes the county rather than an older one

Read from string-blanked source with offsets preserved, so a `why`
string containing a comma cannot split an argument list and prose
mentioning an old spelling cannot count as code.
"""
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from lua_read import strip_lua

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"

ANSWERS = {
    "need": "the pressure is a need - hunger, thirst, injury, a threat",
    "designation": "the house gave them this, and they are on it",
    "chosen rest": "they chose to stop; not collapse, not idleness",
    "errand": "the fallback, so a survivor is never doing nothing",
}

SET_STATE = re.compile(r"\bsetState\s*\(")
# Every place the word `answer` is assigned to. There are two shapes
# and the first two drafts each handled exactly one of them:
#
#   `answer = "..."`                      a table field, or a plain
#                                         assignment
#   `why, answer = "walks the watch", "designation"`
#                                         a MULTIPLE assignment, where
#                                         Lua pairs the nth name with
#                                         the nth value
#
# Draft one matched `answer\s*=\s*"..."` and read the second shape
# backwards, taking the WHY for the answer - seven of them. Draft two
# handled the namelist and anchored to the line start, which is not
# where a table field lives, so it stopped seeing `pressure = { answer
# = "rest" }` at all - and the control that reverts THIS BATCH'S OWN
# FIX stayed green.
ANSWER_AT = re.compile(r"(?<![\w.])answer\s*=(?!=)")
COMPARE_LIT = re.compile(r"\.answer\s*(?:==|~=)\s*\"([^\"]*)\"")
MAP_LIT = re.compile(r"\b[A-Z][A-Z0-9_]*\s*=\s*\"([^\"]*)\"")
FALLBACK = re.compile(r"\bPRESSURE_ANSWER\[[^\]]+\]\s*or\s*\"([^\"]*)\"")


def args_of(blank, open_at):
    """Top-level argument spans of a call, as (start, end) offsets."""
    depth, i, spans, start = 1, open_at, [], open_at
    while i < len(blank) and depth:
        c = blank[i]
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
            if depth == 0:
                spans.append((start, i))
                return spans
        elif c == "," and depth == 1:
            spans.append((start, i))
            start = i + 1
        i += 1
    return spans


def main():
    faults = []
    print("=" * 74)
    print("FOUR ANSWERS, SPELLED FIVE WAYS")
    print("=" * 74)

    files = sorted(LUA.rglob("*.lua"))
    if not files:
        print()
        print("VERDICT:")
        print("  FAULT: no Lua was read, so no answer was examined")
        return 1

    assigned, compared = {}, {}
    for path in files:
        raw = path.read_text(encoding="utf-8", errors="ignore")
        blank = strip_lua(raw)
        rel = path.relative_to(ROOT).as_posix()

        def note(store, value, at):
            store.setdefault(value, []).append(
                f"{rel}:{raw.count(chr(10), 0, at) + 1}")

        # The per-state map, and the `or "errand"` fallback under it.
        block = re.search(r"PRESSURE_ANSWER\s*=\s*\{", blank)
        if block:
            end = blank.find("}", block.end())
            for m in MAP_LIT.finditer(raw, block.end(), end):
                note(assigned, m.group(1), m.start())
        for m in FALLBACK.finditer(raw):
            note(assigned, m.group(1), m.start())

        # `answer = "..."`, and `why, answer = "...", "..."` - by
        # POSITION, because Lua's multiple assignment pairs the nth
        # name with the nth value.
        for m in ANSWER_AT.finditer(blank):
            line_start = blank.rfind("\n", 0, m.start()) + 1
            line_end = blank.find("\n", m.end())
            line_end = len(blank) if line_end < 0 else line_end
            before = blank[line_start:m.start()]
            # A namelist only when a comma sits at depth zero before
            # `answer` on this line - inside a `{` it is a table field
            # and the comma belongs to the field before it.
            depth, at = 0, 0
            for c in before:
                if c in "([{":
                    depth += 1
                elif c in ")]}":
                    depth -= 1
                elif c == "," and depth == 0:
                    at += 1
            values, depth, start = [], 0, m.end()
            for i in range(m.end(), line_end):
                c = blank[i]
                if c in "([{":
                    depth += 1
                elif c in ")]}":
                    depth -= 1
                    if depth < 0:
                        break
                elif c == "," and depth == 0:
                    values.append((start, i))
                    start = i + 1
            values.append((start, min(line_end, len(blank))))
            if at >= len(values):
                continue
            a, b = values[at]
            lit = re.match(r"\s*\"([^\"]*)\"\s*$", raw[a:b])
            if lit:
                note(assigned, lit.group(1), a)

        # `setState(agent, id, STATE, why, ANSWER)` - the fifth
        # argument, found on the BLANKED source so a `why` holding a
        # comma cannot split the list, then read from the real one.
        for m in SET_STATE.finditer(blank):
            spans = args_of(blank, m.end())
            if len(spans) < 5:
                continue
            a, b = spans[4]
            lit = re.match(r"\s*\"([^\"]*)\"\s*$", raw[a:b])
            if lit:
                note(assigned, lit.group(1), a)

        for m in COMPARE_LIT.finditer(raw):
            if blank[m.start(1) - 1] != '"':
                continue
            note(compared, m.group(1), m.start())

    print(f"  answers assigned : {len(assigned)}  "
          f"({', '.join(sorted(assigned)) or 'none'})")
    print(f"  answers compared : {len(compared)}  "
          f"({', '.join(sorted(compared)) or 'none'})")
    print(f"  domain           : {len(ANSWERS)}")

    if not assigned or not compared:
        faults.append(
            "no answer was assigned, or none compared, which cannot be true "
            "of the field every transition fills. The reading failed rather "
            "than the code being clean")

    for value, where in sorted(assigned.items()):
        if value not in ANSWERS:
            faults.append(
                f"`{value}` is set as a pressure answer at {where[0]}"
                f"{f' (and {len(where) - 1} more)' if len(where) > 1 else ''}"
                f" and is not one of the four: {', '.join(sorted(ANSWERS))}. "
                "Nothing compares against it, so it costs nothing today - "
                "and the day somebody reads for one of the four, this "
                "survivor is silently not among them")
    for value, where in sorted(compared.items()):
        if value not in ANSWERS:
            faults.append(
                f"`{value}` is compared against a pressure answer at "
                f"{where[0]} and nothing ever sets it, so that branch is "
                "unreachable and reads as though it were live")
    for value in sorted(ANSWERS):
        if value not in assigned:
            faults.append(
                f"`{value}` is one of the four answers ({ANSWERS[value]}) "
                "and nothing in the tree sets it. Either a path was lost or "
                "the domain describes an older county")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  78) pressure answers: every answer set or read is one of the "
          f"{len(ANSWERS)}, and all {len(ANSWERS)} are set somewhere")
    return 0


if __name__ == "__main__":
    sys.exit(main())
