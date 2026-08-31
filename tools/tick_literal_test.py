#!/usr/bin/env python3
r"""Border 52 - a clock told what time it is.

Reported from play, and it took four sessions to chase: *"Talking
doesn't surface anything."*

`SAO_Harness.lua` answered every player verb through
`SAO.Voice.onEvent(id, "talkBack", 0)`. That last argument is the
tick. `speak` gates on it:

    local last = lastSpokeAt[id] or -COOLDOWN
    if not force and (tick - last) < COOLDOWN then return end

With a real `lastSpokeAt` - any positive tick at which that survivor
last said anything - and a `tick` of zero, the subtraction is hugely
negative, so it is always under the cooldown and always returns
without a word. A survivor who had not spoken since load answered
once, and that answer stamped `lastSpokeAt[id] = 0`, after which
`0 - 0` is under the cooldown too, forever.

Nineteen call sites, and every one of them was a REPLY TO THE PLAYER:
talking back, agreeing to walk with you, refusing, letting you into
the group, turning you away, taking a deal, refusing one, accepting
the chair, being paid, parting, coming along. The whole conversational
surface of the mod answered at most once per person per session.

WHY A LITERAL AND NOT A BUG IN THE COOLDOWN
-------------------------------------------
The cooldown is right. What was wrong is that a value which can only
be known at the moment of the call was TYPED at the call instead - and
zero is the most dangerous constant to type into arithmetic, because
it is a plausible number rather than an obvious absence. `nil` would
have thrown on the first subtraction and been fixed in an hour.

[B27] built `SAO.Controller.tick()` for exactly this - "the player's
half of the experience loop is driven by a menu click rather than by
this loop" - and used it at the two sites that stamp beliefs. The
voice replies kept the zero for a hundred batches.

[B46] moved the resolution into `Voice` itself, so a caller outside
the tick loop leaves the argument out and the one place that can know
answers the question. This border keeps it that way.

DERIVED, NOT LISTED
-------------------
A tick-taking function is found by reading its `function` line: any
parameter named `tick` or `tickCount`. Call sites are matched on the
method name, not the receiver, because the definitions use module-local
aliases (`function V.onEvent`) and the calls use the public path
(`SAO.Voice.onEvent`) - matching names is the conservative direction,
since it can only check more calls than strictly necessary.

The lookbehind excludes a preceding word character only - `retell(`
must not match `tell` - and deliberately NOT a preceding dot, because
every real call here is qualified (`SAO.Perception.tell`). The first
draft excluded dots too and checked nothing at all while reporting
clean, which is the vacuous pass this project keeps naming; the
printed count of checked call sites is there so that state cannot
look like a verdict.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from menu_reach import strip_lua                       # noqa: E402

DEF = re.compile(r"function\s+[A-Za-z_][\w.]*[.:](\w+)\s*\(([^)]*)\)")
TICKY = ("tick", "tickCount")
NUMBER = re.compile(r"^-?[0-9][0-9.]*$")

# A tick that is genuinely a constant, and why. Keyed by file, function
# and the value, because a line number drifts and an argument does not.
# The same discipline as [B40]'s two feud reaches, [B45]'s three tens
# and [B45]'s one neighbour: the exception is not suppressed, it is
# argued, and an argument whose call has gone is a fault of its own.
ALLOWED = {
    ("SAO_Population.lua", "learnBuilding", "0"):
        "[B39]. A survivor knows the building they were standing in "
        "when the world ended, and they did not hear about it - they "
        "lived it. Zero is not a missing clock here, it is the earliest "
        "stamp there is, so freshness arithmetic reads this as the "
        "oldest thing they know, which is exactly true of it.",
}


def args_at(src, open_paren):
    """Split one call's arguments, respecting nesting. None if unclosed."""
    depth, start, out = 0, open_paren + 1, []
    for i in range(open_paren, len(src)):
        c = src[i]
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
            if depth == 0:
                out.append(src[start:i])
                return out
        elif c == "," and depth == 1:
            out.append(src[start:i])
            start = i + 1
        elif c == "\n" and depth == 1 and i - open_paren > 400:
            return None
    return None


def main():
    faults = []
    print("=" * 74)
    print("A CLOCK TOLD WHAT TIME IT IS")
    print("=" * 74)

    srcs = {p: strip_lua(p.read_text(encoding="utf-8", errors="ignore"),
                         strings=False)
            for p in sorted(LUA.rglob("*.lua"))}

    # name -> the argument index that is a tick
    ticky = {}
    for src in srcs.values():
        for m in DEF.finditer(src):
            params = [a.strip() for a in m.group(2).split(",")]
            for i, a in enumerate(params):
                if a in TICKY:
                    ticky[m.group(1)] = i

    print("  functions that take a tick: "
          + ", ".join(f"{n}(#{i + 1})" for n, i in sorted(ticky.items())))

    checked, argued = 0, set()
    for path, src in srcs.items():
        for name, index in ticky.items():
            for m in re.finditer(r"(?<![\w])" + name + r"\s*\(", src):
                args = args_at(src, m.end() - 1)
                if args is None or len(args) <= index:
                    continue
                checked += 1
                value = args[index].strip()
                if NUMBER.match(value):
                    key = (path.name, name, value)
                    if key in ALLOWED:
                        argued.add(key)
                        continue
                    line = src.count("\n", 0, m.start()) + 1
                    faults.append(
                        f"{path.name}:{line} calls `{name}` with the "
                        f"literal `{value}` where the tick goes. A tick is "
                        "only knowable at the moment of the call, and a "
                        "number typed there does not become one - it "
                        "becomes arithmetic against a real clock that "
                        "quietly never passes. Leave the argument out and "
                        "let the one place that can know answer it")

    print(f"  call sites with a tick argument: {checked}   "
          f"constants argued: {len(argued)}/{len(ALLOWED)}")

    for key in sorted(ALLOWED):
        if key not in argued:
            faults.append(
                f"ALLOWED argues the literal `{key[2]}` at `{key[1]}` in "
                f"{key[0]} and that call is gone. The reason has outlived "
                "what it was about; delete it rather than leave a sentence "
                "standing over no code")
    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  52) tick literals: of {checked} calls that carry a tick, "
          f"none was handed a number instead of a clock except the "
          f"{len(argued)} that mean it")
    return 0


if __name__ == "__main__":
    sys.exit(main())
