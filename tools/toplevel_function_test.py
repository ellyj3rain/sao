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
TOK = re.compile(r"\b(?:function|then|do|repeat|end|until|elseif)\b")


def strip(src):
    # Preserve line positions while removing every Lua comment/string form,
    # including --[=[ ... ]=] and escaped quotes inside short strings.
    from lua_read import strip_lua
    return strip_lua(src).splitlines()


def function_sites(source, source_factories=()):
    blocks, sites, swallow_do = [], [], False
    for number, line in enumerate(strip(source), 1):
        if re.match(r'function\s', line):
            sites.append((number, len(blocks), len(blocks) == 1 and blocks[0] in ('iife', 'source-factory')))
        for match in re.finditer(r'\b(function|if|for|while|do|repeat|end|until)\b', line):
            word = match.group()
            if word in ('for', 'while'):
                blocks.append(word)
                swallow_do = True
            elif word == 'do':
                if swallow_do:
                    swallow_do = False
                else:
                    blocks.append(word)
            elif word == 'function':
                # An explicit immediately invoked constructor intentionally
                # declares its source-derived methods inside its factory.
                factory = re.search(r'local\s+\w+\s*=\s*\(\s*$', line[:match.start()])
                named = re.search(r'local\s+function\s+(\w+)\s*\(', line)
                source_factory = named and named.group(1) in source_factories
                blocks.append('iife' if factory else 'source-factory' if source_factory else word)
            elif word in ('if', 'repeat'):
                # elseif is a whole token and does not match this branch.
                blocks.append(word)
            elif blocks:
                blocks.pop()
            else:
                blocks.append('unmatched-end')
    return sites, len(blocks)


def reader_controls():
    # The motivating missing end must still swallow the next module function.
    sites, depth = function_sites('function P.tell()\nfunction P.report()\nend\n')
    assert (2, 1, False) in sites and depth == 1
    good = 'local Core = (function()\nfunction Core:run()\nend\nreturn Core\nend)()\n'
    assert function_sites(good) == ([(2, 1, True)], 0)
    broken = good.replace('function Core:run()\nend', 'function Core:run()\n')
    assert function_sites(broken)[1] == 1
    commented = '--[=[ function P.bad() ]=]\nfunction P.good()\nend\n'
    assert function_sites(commented) == ([(2, 0, False)], 0)
    return 4


def main():
    from source_scanner_baseline import Baseline
    baseline = Baseline()
    reader_controls()
    faults = []
    checked = 0
    for path in sorted(LUA.rglob("*.lua")):
        checked += 1
        raw = path.read_text(encoding="utf-8", errors="ignore")
        # The qualified Yoga adapter instantiates its renamed source class
        # through a named factory. Its methods deliberately live in that body.
        factories = ()
        consumer = baseline._consumers.get(str(path.relative_to(ROOT)).replace('\\', '/'), {})
        if path.name == 'SAO_LeisureExercise.lua' and consumer:
            from scanner_inventory import sha
            if sha(path.read_bytes()) == consumer.get('sha256') and 'return SAONpcYogaCore' in raw:
                factories = ('buildYogaSource',)
        sites, depth = function_sites(raw, factories)
        for number, site_depth, factory in sites:
            if site_depth > 0 and not factory and not baseline.preserved(path, number):
                faults.append(
                    f"{path.name}:{number} declares a column-zero "
                    f"function at block depth {site_depth} - an unclosed "
                    "block above it has swallowed everything since")
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
