#!/usr/bin/env python3
r"""Border 39 - the county's history is written and read by the same list.

[B23] found `creed` written by the election and *"until this line,
dropped silently by the reader"* - a governance event recorded in
`govHistory` that the Chronicle had no branch for, so it happened, was
stored, and was never once shown. That was fixed for `creed` and the
class was left open.

It had two more instances. `chair` and `unseated` were written from
three sites between them and rendered by nothing - and both are the
kinds that are about the PLAYER: a house giving you a seat, and taking
it back when their trust in you ran out. The Chronicle recorded the
county's governance faithfully and dropped the two events the player
was actually in.

A third defect of the same family sat next to them. Every other kind
carries the subject its rendering needs - `creed` the creed, `form` the
form, `policy` the policy, `schism` how many walked out, `pact` the
other house - and `abandon` carried a timestamp and nothing else. So
the Chronicle could say a house gave up their ground and never say
which ground, which is the difference between a fact and a place you
could go and look at.

WHAT THIS HOLDS
---------------
  1. Every kind written into `govHistory` has a branch that renders it.
  2. Every branch that renders a kind has a writer that produces it.
  3. Every field a renderer reads off an event is a field some writer
     of that kind puts there - otherwise the line renders blank and
     nobody notices, which is how `abandon` read for its whole life.

The writer scan has to handle a subscripted receiver:
`pr[1].govHistory[#pr[1].govHistory + 1]` is how the pact code writes,
and a pattern expecting a plain name reports `pact` and `pactBroke` as
rendered-but-never-written. That was this border's first result and it
was wrong.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
STANDING = LUA / "shared" / "SAO_Standing.lua"
UI = LUA / "client" / "SAO_UI.lua"

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from menu_reach import strip_lua                       # noqa: E402

HISTORY = "govHistory"
KIND = re.compile(r'kind\s*=\s*"(\w+)"')
RENDER = re.compile(r'ev\.kind\s*==\s*"(\w+)"')


def written_tables(src):
    """Every `<receiver>.govHistory[...] = { ... }` and what it holds.

    Brace-counted, not pattern-matched. Two shapes defeat a regex here
    and both are in the shipped code: the index expression contains its
    own brackets - `pr[1].govHistory[#pr[1].govHistory + 1]` - so a
    `[^\\]]+` subscript stops in the wrong place, and a table whose
    fields wrap over several lines runs past any fixed window. The
    first draft of this border used both of those and reported three
    kinds as rendered-but-never-written that are written plainly.
    """
    out = []
    for m in re.finditer(r"\.%s\s*\[" % HISTORY, src):
        eq = src.find("= {", m.end())
        if eq < 0 or eq - m.end() > 120:
            continue
        i, depth = eq + 2, 0
        while i < len(src):
            if src[i] == "{":
                depth += 1
            elif src[i] == "}":
                depth -= 1
                if depth == 0:
                    out.append(src[eq + 3:i])
                    break
            i += 1
    return out


def main():
    faults = []
    print("=" * 74)
    print("WHAT THE COUNTY RECORDS, AND WHAT IT SHOWS")
    print("=" * 74)

    standing = strip_lua(STANDING.read_text(encoding="utf-8",
                                            errors="ignore"),
                         strings=False)
    ui = strip_lua(UI.read_text(encoding="utf-8", errors="ignore"),
                   strings=False)

    # A kind is not always a literal. The wire's feud/peace writer says
    #
    #     kind = (field == "declaredAtHours") and "feud" or "peace",
    #
    # and a scan looking for `kind = "..."` sees no kind at all - which
    # reads as "these kinds are rendered and never written" and is a
    # false fault in a gate. Every string literal in the kind
    # EXPRESSION counts, so a conditional writer declares both of the
    # kinds it can produce. govHistory has no computed kind today; this
    # is here so the first one does not fail the build.
    written = {}
    for body in written_tables(standing):
        expr = re.search(r"kind\s*=\s*([^,\n]*(?:\n[^,\n]*)?)", body)
        if not expr:
            continue
        kinds = re.findall(r'"(\w+)"', expr.group(1))
        if not kinds:
            continue
        fields = set(re.findall(r"(\w+)\s*=", body)) - {"kind"}
        for kind in kinds:
            written.setdefault(kind, set()).update(fields)

    rendered = {}
    for m in RENDER.finditer(ui):
        # The branch runs to the next `elseif ev.kind` or the loop end.
        rest = ui[m.end():]
        stop = re.search(r'elseif\s+ev\.kind\s*==|^\s*end\s*$', rest, re.M)
        body = rest[:stop.start()] if stop else rest[:900]
        rendered[m.group(1)] = set(re.findall(r"\bev\.(\w+)", body))

    print(f"  kinds written : {', '.join(sorted(written)) or 'NONE'}")
    print(f"  kinds rendered: {', '.join(sorted(rendered)) or 'NONE'}")

    if not written:
        faults.append(
            f"no writes into {HISTORY} were found at all - this border's "
            "reading of how the history is written is out of date, and a "
            "border that cannot see the writers cannot hold anything")
        return report(faults)

    for kind in sorted(set(written) - set(rendered)):
        faults.append(
            f"`{kind}` is written into {HISTORY} and the Chronicle has no "
            "branch for it - the county records the event, stores it, and "
            "never once shows it ([B23]'s defect)")
    for kind in sorted(set(rendered) - set(written)):
        faults.append(
            f"the Chronicle renders `{kind}` and nothing writes it - a "
            "branch that can never run, promising a line the county "
            "cannot produce")

    for kind in sorted(set(written) & set(rendered)):
        missing = rendered[kind] - written[kind] - {"kind", "atHours"}
        for field in sorted(missing):
            faults.append(
                f"the Chronicle reads `ev.{field}` on a `{kind}` event and "
                f"no writer of `{kind}` puts it there - the line renders "
                "with a hole in it and nothing says so")

    return report(faults)


def report(faults):
    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print("  39) chronicle: every governance event the county records is "
          "one it can show,")
    print("      and every line it shows is built from fields the record "
          "actually carries")
    return 0


if __name__ == "__main__":
    sys.exit(main())
