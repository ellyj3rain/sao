#!/usr/bin/env python3
r"""[B35] Lines nobody can hear, and events nobody defined.

`V.onEvent` resolves by exact key:

    local list = EVENTS[event]
    if not list then return end

So an event name nothing defines is silently dropped - the survivor
simply says nothing - and dialogue nothing requests is written and
unreachable. Both halves are the same class from opposite ends, and
both are invisible in play: silence looks like silence either way.

Reading this correctly took three attempts, which is why the method is
written down rather than assumed:

  1. Matching only a literal IMMEDIATELY after the id argument missed
     every conditional name - `onEvent(id, knewThem and "notThem" or
     "witnessed", tick)` - and reported NINE unreachable events. Eight
     of the nine were reachable.

  2. Capturing every literal in the call fixed that, and introduced a
     false positive from the other direction: strings in the call that
     are not event names at all, like the trauma claim
     "nothing-left-to-lose" that SELECTS an event.

  3. So the comparison is only ever made against the EVENTS table
     itself. A literal that is not a key is not evidence of anything;
     a key with no literal anywhere is.

The residue after all that was exactly one genuinely dead entry -
`introduce`, appearing once in the whole tree, in its own definition.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
VOICE = LUA / "client" / "SAO_Voice.lua"


def table_keys(src, name, end_marker):
    i = src.index(f"local {name} = {{")
    j = src.index(end_marker, i)
    return set(re.findall(r"^\s{4}(\w+)\s*=", src[i:j], re.M))


def call_body(s, k):
    """Balanced-paren body of a call whose '(' has just been consumed."""
    depth, start = 1, k
    while k < len(s) and depth:
        if s[k] in "([{":
            depth += 1
        elif s[k] in ")]}":
            depth -= 1
        k += 1
    return s[start:k - 1]


def main():
    src = VOICE.read_text(encoding="utf-8", errors="ignore")
    events = table_keys(src, "EVENTS", "\nlocal function pick")
    lines = table_keys(src, "LINES", "\nlocal EVENTS = {")

    requested, sites = set(), {}
    for p in sorted(LUA.rglob("*.lua")):
        s = p.read_text(encoding="utf-8", errors="ignore")
        # [B46] TWO entry points now. `V.answer` is the player's -
        # everything SAO_Harness.lua raises is somebody replying to a
        # click, and those bypass the talkativeness roll (Border 53).
        # This border fired the moment the harness moved across, which
        # is the right behaviour and the reason it is widened here
        # rather than the reason it is loosened: an event reachable
        # through EITHER call is reachable, and through neither is not.
        for m in re.finditer(r"Voice\.(?:onEvent|answer)\(", s):
            for lit in re.findall(r'"([^"]+)"', call_body(s, m.end())):
                requested.add(lit)
                sites.setdefault(lit, []).append(
                    f"{p.name}:{s[:m.start()].count(chr(10)) + 1}")

    states = set()
    for p in sorted(LUA.rglob("*.lua")):
        s = p.read_text(encoding="utf-8", errors="ignore")
        for m in re.finditer(r"Voice\.onTransition\(", s):
            states |= set(re.findall(r'"([^"]+)"', call_body(s, m.end())))

    print("=" * 70)
    print(f"EVENTS defined: {len(events)}    "
          f"LINES (states) defined: {len(lines)}")
    print("=" * 70)

    # Only names that ARE keys count as requests; a literal that is not
    # a key is a claim id, a reason, a label - not evidence.
    unheard = sorted(events - requested)
    unheard_states = sorted(
        lines - {s for s in states if s in lines}
        - {"IDLE", "ROAM", "HOMEWARD"})

    print(f"\n  EVENTS no call site can reach: {len(unheard)}")
    for e in unheard:
        print(f"    {e}   (written, unhearable)")
    if not unheard:
        print("    none - every written event has a caller")

    # [B35] Not listed, and deliberately so. onTransition is called
    # from setState with the state as a VARIABLE, so every one of the
    # 18 state line-sets is reached through a name this tool cannot
    # read. Printing them as "unnamed" every run would be seventeen
    # lines of expected output forever, which is the noise [B31]
    # forbids - a border that cries wolf is a border people stop
    # reading. Counted, said once, not enumerated.
    print(f"\n  state LINES: {len(lines)} defined, reached through "
          "setState's variable")
    print("    UNCHECKABLE by this tool, and said so rather than "
          "counted as clean")

    print()
    print("VERDICT:")
    print(f"  unhearable events: {len(unheard)}")
    if unheard:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
