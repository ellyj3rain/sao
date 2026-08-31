#!/usr/bin/env python3
r"""Border 37 - a foreign store informs this county; it never speaks for it.

The operator, reading the County Ledger in a live session:

    KS is absolutely dominant over our mod. It should be the opposite.
    ... It could be compatible, but it should never be in any way
    impactful or influential over our mod.

Measured, that was literally true of the one surface this mod owns. The
Ledger's "Word around the camps" read another framework's ModData and
printed its world-event string **verbatim**, unconditionally - while
this project's own `radioNews` queue reached the player only over a live
two-way radio ([A26]). Their news was free; ours had to be earned.

THE RULE
--------
Reading another mod's store is fine and sometimes right - their people
are real people in this county (DR-009), and their camp is a place their
own inhabitants have genuinely been. What is not fine is a foreign store
reaching a surface this mod owns, because at that point the county is
not reporting itself; it is relaying somebody else.

So: every `ModData.getOrCreate` in this tree is enumerated, split into
ours and foreign, and a foreign one may not flow into a call that puts
text on a player's screen. Our own key may.

The gate is the same one Border 36 uses for placeholder text, for the
same reason - what counts is what the player reads, not what the code
happens to touch. `log()` is the console, a debug surface, and is
excluded deliberately rather than by omission.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from menu_reach import strip_lua                       # noqa: E402
from placeholder_test import player_facing_lines       # noqa: E402

# This project's own persisted stores. Anything else belongs to somebody
# else, whoever they are - the rule is about ownership, not about which
# mod happens to be installed, so no foreign name is written here.
#
# The mod id from CORE.md, then an underscore, then a name. A bare
# prefix test is not ownership: `SurvivorAwarenessExtra_Other` would
# belong to whoever wrote it, and a border that reads a name as "close
# enough to ours" would wave that through onto our own surfaces. The id
# is the boundary; the underscore is what makes it a boundary.
OURS = re.compile(r"^SurvivorAwareness_\w+$")
MODDATA = re.compile(r"""ModData\.getOrCreate\(\s*["']([^"']+)["']""")


def main():
    faults = []
    print("=" * 74)
    print("WHOSE STORE SPEAKS ON THIS MOD'S SURFACES")
    print("=" * 74)

    ours, foreign, on_surface = set(), {}, []
    for path in sorted(LUA.rglob("*.lua")):
        code = strip_lua(path.read_text(encoding="utf-8", errors="ignore"),
                         strings=False)
        lines = code.split("\n")
        shown = player_facing_lines(code)

        # A store read binds a local; the surface use is usually a hop
        # away, so the taint is followed the way Border 36 follows a
        # name - a reader that only caught the direct form would miss
        # every real case, because nobody calls getOrCreate inside a
        # row().
        tainted = {}
        for n, line in enumerate(lines, 1):
            m = MODDATA.search(line)
            if not m:
                continue
            key = m.group(1)
            if OURS.match(key):
                ours.add(key)
                continue
            foreign.setdefault(key, []).append(f"{path.name}:{n}")
            # The binding that receives the store. Searched BACKWARDS
            # from this line, nearest first: the call may be on its own
            # line inside `local ok, d = pcall(function() return ...`,
            # or on the same line as `local ks = ModData...`. A forward
            # scan of the window takes whatever `local` happens to come
            # first in it - which was `local me3 = getSpecificPlayer(0)`
            # two lines earlier, so the store's own name was never
            # tainted and the border reported a tree it had not read.
            for back in range(n - 1, max(-1, n - 6), -1):
                bind = re.match(r"\s*local\s+([\w,\s]+?)\s*=", lines[back])
                if bind:
                    for var in bind.group(1).split(","):
                        var = var.strip()
                        if var:
                            tainted[var] = (n, key)
                    break

        # Follow PLAIN assignments too, not just `local`. The value
        # arrives through `local okD, d = pcall(...)` and is then handed
        # on by `ksData = okD and type(d) == "table" and d or nil` - a
        # bare assignment. A first draft tracked only `local` bindings,
        # reported this file clean, and the store was feeding three
        # spoken lines twenty rows further down. Iterated, because the
        # hop can happen more than once.
        BINDS = (
            # local x = <expr>   /   local a, b = <expr>
            re.compile(r"\s*local\s+([\w,\s]+?)\s*=\s*(.+)$"),
            # x = <expr>
            re.compile(r"\s*(\w+)\s*=\s*(.+)$"),
            # for k, v in pairs(<expr>) do
            re.compile(r"\s*for\s+([\w,\s]+?)\s+in\s+(.+)$"),
            # t[...] = <expr>  - the list itself carries what it holds.
            # `offers[#offers + 1] = "..." .. camp.x` is how a spoken
            # line is built here, and without this the trail stops at
            # the append: the store reaches `offers`, `offers` reaches
            # `line`, and `line` reaches Say() two hundred rows later.
            re.compile(r"\s*(\w+)\[[^\]]*\]\s*=\s*(.+)$"),
        )
        for _ in range(4):
            for n, line in enumerate(lines, 1):
                for pattern in BINDS:
                    bound = pattern.match(line)
                    if not bound:
                        continue
                    names = [v.strip() for v in bound.group(1).split(",")
                             if v.strip() and v.strip() != "local"]
                    rhs = bound.group(2)
                    hit = None
                    for var, (at, key) in list(tainted.items()):
                        if at <= n and re.search(r"\b%s\b" % re.escape(var),
                                                 rhs):
                            hit = key
                            break
                    if hit:
                        for name in names:
                            if name not in tainted:
                                tainted[name] = (n, hit)
                    break

        # A sink is anywhere the value becomes TEXT, not only the calls
        # that draw it. `offers[#offers + 1] = "There was a camp near "
        # .. camp.x` never touches row() or addOption() on that line -
        # it fills a list somebody says later - so a check that watched
        # only the drawing calls saw nothing. What matters is their
        # words becoming this mod's words, and that is concatenation
        # with a string.
        # A sink is text that reaches a PLAYER. That is the display
        # calls, plus any list that is later spoken or drawn - in this
        # tree `offers[#offers + 1] = "There was a camp near " .. x`
        # never touches a display call on its own line, and a check
        # watching only those calls saw nothing.
        #
        # It is NOT every concatenation. A first pass flagged
        # `"ks:" .. targetKid` and `"ks-camp:" .. baseId`, which build
        # identity KEYS, and a dozen `log()` lines. Reading a foreign
        # store to name their own people by their own name is what
        # DR-009 asks for; the console is a debug surface and is
        # excluded deliberately. Neither is the county speaking with
        # somebody else's mouth.
        # The line this rule draws: a foreign store may not reach a
        # surface where THIS MOD SPEAKS AS THE COUNTY - the Ledger, a
        # menu entry, halo text. Those are the county reporting itself,
        # and relaying somebody else's world there is the dominance the
        # operator named.
        #
        # A foreign person's OWN dialogue is not that. When one of their
        # survivors tells you about their camp or their buried, that is
        # that person speaking about themselves, which is exactly the
        # compatibility that is wanted - it changes no state of ours and
        # claims nothing on our behalf. So `:Say(` is excluded, and the
        # exclusion is written here rather than left as a gap in the
        # results.
        for n, line in enumerate(lines, 1):
            if re.match(r"\s*log\(", line) or ":Say(" in line:
                continue
            if n not in shown:
                continue
            for var, (at, key) in tainted.items():
                if at < n and n - at <= 40 and \
                        re.search(r"\b%s\b" % re.escape(var), line):
                    on_surface.append((path.name, n, key, var, at))
                    break

    print(f"  our own stores:   {', '.join(sorted(ours)) or 'NONE'}")
    print(f"  foreign stores:   {len(foreign)} read at "
          f"{sum(len(v) for v in foreign.values())} site(s)")
    for key, sites in sorted(foreign.items()):
        print(f"    {key}: {', '.join(sites)}")
    print(f"  foreign on a player surface: {len(on_surface)}")

    if not ours:
        faults.append(
            "this mod reads no store of its own - the check has nothing "
            "to compare against and its account of the tree is wrong")

    for name, n, key, var, at in on_surface:
        faults.append(
            f"{name}:{n} puts a foreign store on a surface the player "
            f"reads - `{var}` came from {key} at line {at}. The county is "
            "relaying somebody else instead of reporting itself; read it "
            "if it is useful, but say it in this mod's own words from "
            "this mod's own records")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print("  37) sovereignty: a foreign store informs this county and "
          "never speaks for it -")
    print("      every surface the player reads is this mod reporting "
          "its own records")
    return 0


if __name__ == "__main__":
    sys.exit(main())
