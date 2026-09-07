#!/usr/bin/env python3
r"""Border 83 - a top-level function is at the top level.

[C5] found `P.tell` never closed: `P.reportReturn`, `P.cryForHelp`,
and `P.announceDeparture` - three column-zero function statements -
were being DEFINED INSIDE tell's body, because an insertion at [B19]'s
era landed between tell's loops and its tail. Legal Lua, compiles
clean, passes every syntax gate, and means none of the three existed
until the first tell of a session: the departure announcement, the
distress cry, and the scout report were nil for the whole opening
window, their callers pcall-swallowing the absence. The B42
silent-surface class, produced by indentation nobody could see.

WHAT THIS HOLDS
---------------
Every `function ...` statement written at column zero in the mod's Lua
is reached at block depth zero. A column-zero function is a declaration
of intent to be top-level; reaching one nested means an unclosed block
above it has swallowed everything since.

An optional argv[1] points the checker at another tree root, which is
how the control runs against the pre-fix state.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"

STR1 = re.compile(r'"(?:\\.|[^"\\])*"')
STR2 = re.compile(r"'(?:\\.|[^'\\])*'")
LONGSTR = re.compile(r"\[\[.*?\]\]", re.S)
COMMENT = re.compile(r"--.*$")
TOK = re.compile(r"\b(?:function|then|do|end|until|elseif)\b")


def strip(src):
    src = LONGSTR.sub('""', src)
    out = []
    for line in src.splitlines():
        line = STR1.sub('""', line)
        line = STR2.sub("''", line)
        out.append(COMMENT.sub("", line))
    return out


def main():
    faults = []
    checked = 0
    for path in sorted(LUA.rglob("*.lua")):
        depth = 0
        checked += 1
        for number, line in enumerate(strip(
                path.read_text(encoding="utf-8", errors="ignore")), 1):
            if depth == 0 and re.match(r"function\s", line) is None:
                pass
            if re.match(r"function\s", line) and depth > 0:
                faults.append(
                    f"{path.name}:{number} declares a column-zero "
                    f"function at block depth {depth} - an unclosed "
                    "block above it has swallowed everything since")
            for tok in TOK.findall(line):
                if tok in ("function", "then", "do"):
                    depth += 1
                elif tok in ("end", "until"):
                    depth -= 1
                elif tok == "elseif":
                    depth -= 1  # cancel the then it adds on this line
        if depth != 0:
            faults.append(f"{path.name} ends at block depth {depth} - "
                          "the file's blocks do not balance")
    if checked == 0:
        # Border 54's own law: a verdict about an empty set says
        # nothing. This border reads the mod's Lua; no Lua, no pass.
        faults.append("no Lua files found to check - this verdict would "
                      "be a statement about an empty set")
    print("=" * 74)
    print("A TOP-LEVEL FUNCTION IS AT THE TOP LEVEL")
    print("=" * 74)
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  83) top-level functions: {checked} Lua files, every column-zero")
    print("      function reached at depth zero, every file's blocks balanced")
    return 0


if __name__ == "__main__":
    sys.exit(main())
