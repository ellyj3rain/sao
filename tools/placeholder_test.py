#!/usr/bin/env python3
r"""Border 36 - the player is never shown a placeholder.

Two rules, both found the same afternoon from two screenshots.

1. NO NON-ASCII IN A STRING THE PLAYER READS.
   The County Ledger rendered `Danilo Sumpter (1m) - & [?]`. The format
   is `"%s (%.0fm) - %s [%s]%s"` and `doing` fell back to `"…"` - U+2026
   - which has no glyph in the game's font and came out as a stray `&`.
   So the one line that meant "I don't know what they are doing" was
   also the one line that looked broken. Comments are exempt: nineteen
   em-dashes live in this tree's headers and none of them reach a
   screen.

2. "Unnamed" IS ABSENCE, NOT A NAME.
   `backfillName` reads a name off the engine shell, so it needs a
   BODY. A survivor the county has never materialised carries the
   sentinel by design. Bonds form among the dormant, so the Ledger
   rendered five rows of `Unnamed & Unnamed` - a true fact about the
   county, printed as though the ledger knew who they were.

   The convention already existed in four places - `idByName` refuses
   the sentinel outright, `SAO_Radio` and three sites in
   `SAO_Controller` each re-spell it - and the surfaces the player
   actually reads were the ones that did not. `Identity.knownName`
   is that rule with one name; `displayName` must keep rendering the
   sentinel, because beliefs are keyed by it.

WHAT COUNTS AS PLAYER-FACING
----------------------------
A string handed to `addOption`, `row`, `header`, `Say`, `HaloTextHelper`
or `drawText`. `log()` is the console, which is a debug surface and is
excluded - deliberately, and stated here rather than left to be
inferred from the absence of a finding.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from menu_reach import strip_lua                       # noqa: E402

SENTINEL = "Unnamed"
# The surfaces a player reads.
SHOWN = re.compile(
    r"\b(addOption|addOptionOnTop|addSubMenu|row|header|Say|"
    r"addGoodText|addBadText|addText|drawText)\s*\(")
# Files whose job IS the sentinel: the naming pass, and the identity
# module that defines both renders.
OWNS_SENTINEL = {"SAO_Population.lua", "SAO_Identity.lua"}


def player_facing_lines(src):
    """Line numbers holding the TEXT ARGUMENTS of a display call.

    A call can wrap, so the span runs until its parens balance - but it
    stops at the first `function` keyword, because
    `addOption("Talk to X", nil, function() ... end)` passes a callback
    whose body is ordinary code and not something anybody reads. The
    first draft of this marked the whole call and reported two `log()`
    lines inside a menu callback as player-facing text: the instrument
    was measuring proximity to a display call rather than the argument
    to one.
    """
    lines = src.split("\n")
    marked = set()
    for i, line in enumerate(lines):
        for call in SHOWN.finditer(line):
            depth = 0
            rest = line[call.end() - 1:]
            for j in range(i, min(i + 12, len(lines))):
                segment = rest if j == i else lines[j]
                stop = re.search(r"\bfunction\b", segment)
                marked.add(j + 1)
                if stop:
                    break
                depth += segment.count("(") - segment.count(")")
                if depth <= 0:
                    break
    return marked


def main():
    faults = []
    print("=" * 74)
    print("WHAT THE PLAYER IS SHOWN")
    print("=" * 74)

    non_ascii, raw_names = [], []
    for path in sorted(LUA.rglob("*.lua")):
        raw = path.read_text(encoding="utf-8", errors="replace")
        code = strip_lua(raw, strings=False)      # comments gone, strings kept
        shown = player_facing_lines(code)

        for n, line in enumerate(code.split("\n"), 1):
            # 1. a non-ASCII character surviving the comment strip is in
            #    code - and every string literal here is player-facing
            #    or a key, neither of which wants a glyph the font lacks.
            for ch in line:
                if ord(ch) > 126:
                    non_ascii.append((path.name, n, hex(ord(ch)),
                                      line.strip()[:52]))
        # 2. a bare `.forename` reaching a surface the player reads,
        #    either written into the call or carried one hop through a
        #    local. The one-hop form is the one real code uses -
        #    `local pName19 = rec.forename or "them"` and then
        #    `addOption(pName19 .. "...")` - and a first draft of this
        #    border caught only the direct form, so it could not find
        #    either of the two defects that produced it. That is the
        #    same dataflow Border 31 resolves for [B41].
        if path.name in OWNS_SENTINEL:
            continue
        code_lines = code.split("\n")
        tainted = {}
        for n, line in enumerate(code_lines, 1):
            bind = re.match(r"\s*local\s+(\w+)\s*=", line)
            if not bind:
                continue
            # Follow the assignment, not a fixed span. A flat
            # three-line window swallowed the NEXT statement, and when
            # that statement happened to say `knownName` the taint was
            # cancelled by a line that had nothing to do with it - so
            # the border could not find the very defect it was
            # written for.
            window = line
            for k in range(1, 4):
                if n - 1 + k >= len(code_lines):
                    break
                nxt = code_lines[n - 1 + k]
                unbalanced = window.count("(") - window.count(")") > 0
                # Trailing operator: `local x = foo(a) or`
                trails = re.search(r"(=|\(|,|\.\.|\band\b|\bor\b)\s*$",
                                   window.rstrip())
                # LEADING operator on the next line, which is how this
                # tree actually wraps: `local x = f(a)` then
                # `    and f(a).forename or "them"`. Looking only
                # backwards missed that shape entirely, and it is the
                # shape the menu label used.
                leads = re.match(r"(and\b|or\b|\.\.|\))", nxt.lstrip())
                if not (unbalanced or trails or leads):
                    break
                window += " " + nxt
            head = window.split("local ", 1)[-1]
            if re.search(r"\.forename\b", head) \
                    and SENTINEL not in head and "knownName" not in head:
                tainted[bind.group(1)] = n
        for n, line in enumerate(code_lines, 1):
            if n not in shown:
                continue
            if re.search(r"\.forename\b", line) \
                    and SENTINEL not in line and "knownName" not in line:
                raw_names.append((path.name, n, line.strip()[:52]))
                continue
            for var, at in tainted.items():
                # Scope is approximated by proximity, and the
                # approximation is stated rather than hidden: a binding
                # must come BEFORE the use and stay within reach of it.
                # Without the ordering rule, `local line = ...forename`
                # in one function at line 1890 tainted an unrelated
                # `line` at 559 in another - names are reused, and a
                # file-wide taint map is not a scope.
                if not (at < n and n - at <= 30):
                    continue
                if re.search(r"\b%s\b" % re.escape(var), line):
                    raw_names.append(
                        (path.name, n,
                         f"{line.strip()[:40]}  <- `{var}` from "
                         f".forename at line {at}"))
                    break

    print(f"  non-ASCII in code:        {len(non_ascii)}")
    for name, n, ch, txt in non_ascii:
        faults.append(
            f"{name}:{n} has {ch} in code - the game's font has no glyph "
            f"for it and it renders as a stray character: {txt}")

    print(f"  raw forename on a surface: {len(raw_names)}")
    for name, n, txt in raw_names:
        faults.append(
            f"{name}:{n} puts a raw `.forename` on a surface the player "
            f'reads - it shows "{SENTINEL}" to somebody the county has '
            f"not met yet. Use Identity.knownName: {txt}")

    # 3. The rule has to exist to be read.
    ident = strip_lua((LUA / "shared" / "SAO_Identity.lua").read_text(
        encoding="utf-8", errors="ignore"), strings=False)
    body = re.search(r"function Identity\.knownName\(.*?\n(.*?)\nend",
                     ident, re.S)
    has_rule = body is not None and f'"{SENTINEL}"' in body.group(1)
    print(f"  Identity.knownName:       "
          f"{'refuses the sentinel' if has_rule else 'MISSING OR TOOTHLESS'}")
    if not has_rule:
        faults.append(
            f"Identity.knownName does not exist or no longer refuses "
            f'"{SENTINEL}" - every surface that reads it is showing the '
            "placeholder again")

    # 4. displayName must NOT refuse it: beliefs are keyed by that name.
    disp = re.search(r"function Identity\.displayName\(.*?\n(.*?)\nend",
                     ident, re.S)
    if disp and f'"{SENTINEL}"' in disp.group(1):
        faults.append(
            "Identity.displayName now refuses the sentinel - beliefs are "
            "keyed by that string (`b.people[name]`) and idByName indexes "
            "it, so a record with no name would stop being findable. The "
            "refusal belongs in knownName, not here")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print("  36) placeholder: nothing the player reads carries a glyph the "
          "font lacks, and")
    print("      no surface renders the no-name sentinel as though it were "
          "somebody's name")
    return 0


if __name__ == "__main__":
    sys.exit(main())
