#!/usr/bin/env python3
r"""Border 53 - an answer is decided by who asked, not by how it reads.

[B46] found the second half of "talking doesn't surface anything".
With the tick fixed a reply could reach the player, and then had to
survive one more gate:

    if not force and ZombRand(100) >= math.floor(chatty(id) * 100) then
        return
    end

`D.talkativeness` runs 0.20 to 0.85, so a reserved survivor ignored a
direct question four times in five, in silence, and from outside that
is identical to a mod that does not work.

The roll is right for the rest of the vocabulary. Temperament decides
whether anyone VOLUNTEERS anything and which line comes out of the
rotation; it must not decide whether being spoken to registers at all,
because the player performed a deliberate act and a click that does
nothing is the [B33] shape - a world that looks normal and quietly is
not.

WHY THIS IS A CALL SITE AND NOT A LIST
--------------------------------------
The first attempt named the events: `talkBack`, `joinYes`, `walkNo`.
This border killed it on its first run. `company`, `ownCompany` and
`parting` are each raised BOTH from a menu handler and from the tick
loop - the same words are a reply when you asked and a murmur when
nobody did. No set of names can be right about that, and the ten
minutes the set survived also held `smokeShare`, which went in on the
strength of how the line reads and fires between two survivors who
never heard from the player at all.

So the surface says so instead. `V.answer` is the player's entry point
and `V.onEvent` is everyone else's, and the two rules below are what
keep that true. They are structural: nothing has to be remembered, and
a dual-use event is answered when raised from a click and murmured
when raised from the loop, which is what it should always have been.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
VOICE = LUA / "client" / "SAO_Voice.lua"
SURFACE = "SAO_Harness.lua"

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from menu_reach import strip_lua                       # noqa: E402

ANSWER = re.compile(r"Voice\.answer\(")
EVENT = re.compile(r"Voice\.onEvent\(")


def main():
    faults = []
    print("=" * 74)
    print("AN ANSWER IS DECIDED BY WHO ASKED")
    print("=" * 74)

    voice = VOICE.read_text(encoding="utf-8", errors="ignore")
    for name in ("function V.answer(", "function V.onEvent("):
        if name not in voice:
            faults.append(
                f"SAO_Voice.lua no longer defines `{name[9:-1]}`. If the "
                "player's entry point is gone, every reply is back under "
                "the talkativeness roll and a reserved survivor ignores "
                "four questions in five - in silence")

    counts = {}
    for path in sorted(LUA.rglob("*.lua")):
        if path.name == VOICE.name:
            continue
        src = strip_lua(path.read_text(encoding="utf-8", errors="ignore"),
                        strings=False)
        counts[path.name] = (len(ANSWER.findall(src)),
                             len(EVENT.findall(src)))

    answers_here, events_here = counts.get(SURFACE, (0, 0))
    strays = {f: n for f, (n, _) in counts.items()
              if n and f != SURFACE}

    print(f"  {SURFACE}: {answers_here} answer(s), {events_here} murmur(s)")
    print("  answers raised anywhere else: "
          + (", ".join(f"{f} ({n})" for f, n in sorted(strays.items()))
             or "none"))

    if answers_here == 0:
        faults.append(
            f"{SURFACE} raises no answers at all. Every verb the player has "
            "goes through that file, so either the menu has gone silent or "
            "its calls have drifted back onto the murmur path")

    if events_here:
        faults.append(
            f"{SURFACE} raises {events_here} event(s) through `onEvent`. "
            "That file is nothing but menu handlers, so every line it "
            "raises is somebody answering a click - and on the murmur path "
            "a reserved survivor will swallow four in five, which is the "
            "exact defect [B46] was reported for")

    for f, n in sorted(strays.items()):
        faults.append(
            f"{f} raises {n} answer(s) through `V.answer`, and it is not "
            "the player's surface. The talkativeness bypass exists because "
            "somebody clicked something; granting it to the tick loop "
            "makes the quiet as talkative as the rest and takes a "
            "disposition out of the world")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  53) answer set: the {answers_here} replies to the player all "
          "come from the player's own surface, and nothing else claims to "
          "be answering anyone")
    return 0


if __name__ == "__main__":
    sys.exit(main())
