#!/usr/bin/env python3
r"""[B35] Keys from one domain, tested by something that knows another.

Three domains exist: `sao-<n>` for ours, `player:<name>` for the real
player, `foreign:<name>` for another mod's people. Only the first has
an Identity record.

So `SAO.Identity.get(key)` returns nil for two of the three domains,
and the guard shape decides whether that is safe:

    if rec and not rec.dead        EXCLUDES the player.  Wrong on any
                                   collection that can hold a player
                                   key - the branch silently never
                                   runs for them.

    if not (rec and rec.dead)      INCLUDES them. Right: absent is not
                                   dead, and only the dead are being
                                   screened out.

The difference is one word order and the failure is invisible, because
a branch that never opens looks exactly like a branch whose condition
was false. It has now bitten three times:

    [B33]   foreign people, label written one way and looked up another
    [B35]  the dormant place-learner, so no dormant survivor could
            learn the player's claim
    [B35]  base selection, so a survivor would claim straight over
            ground the player already held

This sweeps the collections that are KNOWN to mix domains - the claim
tables and the belief `places` map, all of which the player appears in
- and reports any Identity.get guard inside them written in the
exclusive form without an isPlayerKey escape.

It deliberately does NOT sweep every Identity.get in the tree. Most
take a survivor id from `Ctl.agents` or `Identity.all()` and can never
see another domain; flagging those would be the noise [B31] forbids.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"

# Iterators whose KEY can be a player: key as well as a survivor id.
# [B35] `re.S` and a tolerant gap, because the loop header is not
# always on one line - SAO_Controller:1630 wraps after `pairs(`, and
# matching per-line reported zero findings over the very defect this
# tool was written for.
MIXED = re.compile(
    r"for\s+(\w+)\s*,\s*\w+\s+in\s+pairs\(\s*"
    r"(?:SAO\.Standing\.allPersonalClaims\(\)"
    r"|SAO\.Standing\.allGroupClaims\(\)"
    r"|[\w.]*\bplaces\b[\w.]*)", re.S)


def strip_lua(src):
    out, i, n = list(src), 0, len(src)
    while i < n:
        c = src[i]
        if c == "-" and src.startswith("--", i):
            end = src.find("\n", i)
            end = n if end < 0 else end
            for k in range(i, end):
                out[k] = " "
            i = end
            continue
        if c in "'\"":
            j = i + 1
            while j < n and src[j] != c and src[j] != "\n":
                j += 2 if src[j] == "\\" else 1
            for k in range(i + 1, min(j, n)):
                out[k] = "_"
            i = min(j + 1, n)
            continue
        i += 1
    return "".join(out)


def main():
    findings, checked = [], 0
    for path in sorted(LUA.rglob("*.lua")):
        raw = path.read_text(encoding="utf-8", errors="ignore")
        src = strip_lua(raw)
        lines = src.split("\n")
        for m in MIXED.finditer(src):
            n = src[:m.start()].count("\n")
            keyvar = m.group(1)
            body = "\n".join(lines[n:n + 20])
            # [B35] Identity.get is often reached through a guarded
            # chain - `SAO.Identity and SAO.Identity.get and
            # SAO.Identity.get(k) or nil` - which is how a CORRECT
            # site is written, so a pattern that only saw the bare
            # call was blind to exactly the shape worth comparing
            # against.
            got = re.search(
                r"local\s+(\w+)\s*=[^\n]*?SAO\.Identity\.get\(\s*"
                + re.escape(keyvar) + r"\s*\)", body)
            if not got:
                continue
            checked += 1
            rec = got.group(1)
            exclusive = re.search(
                re.escape(rec) + r"\s+and\s+not\s+" + re.escape(rec)
                + r"\.dead", body)
            escaped = "isPlayerKey" in body
            rel = str(path.relative_to(ROOT)).replace("\\", "/")
            if exclusive and not escaped:
                findings.append((rel, n + 1, keyvar, rec))

    print("=" * 70)
    print("Identity.get guards inside collections that MIX key domains")
    print("=" * 70)
    print(f"  guarded sites examined: {checked}")
    print(f"  written exclusively, with no isPlayerKey escape: "
          f"{len(findings)}")
    for rel, ln, keyvar, rec in findings:
        print(f"\n  {rel}:{ln}")
        print(f"      iterates `{keyvar}`, which can hold a player key")
        print(f"      guards `{rec} and not {rec}.dead`, so the player")
        print(f"      - who has no record and is never dead - is skipped")

    # [B37] The same law, applied to a constant instead of a key: a
    # value two files must agree on, declared twice, fails silently
    # when one moves. The county wire's band was written in
    # server/SAO_Radio (the channel registered) and again in
    # client/SAO_RadioEar (the test that hears the player) - change
    # one and the county broadcasts on a band it does not listen to,
    # with no error and no log, and the only symptom is survivors
    # not hearing you, which is what the feature looks like when
    # nobody is talking.
    print()
    print("=" * 70)
    print("CONSTANTS TWO FILES MUST AGREE ON")
    print("=" * 70)
    shared_consts = {"101200": "the county wire band"}
    dupes = []
    for lit, what in shared_consts.items():
        where = []
        for path in sorted(LUA.rglob("*.lua")):
            s = path.read_text(encoding="utf-8", errors="ignore")
            for m in re.finditer(r"\b" + lit + r"\b", s):
                where.append(f"{path.name}:{s[:m.start()].count(chr(10))+1}")
        print(f"  {lit}  ({what}): {len(where)} literal(s)  "
              f"{', '.join(where)}")
        if len(where) > 1:
            dupes.append((lit, what, where))
    if not dupes:
        print("  each is declared once and read from there")

    # [B40] The same law, in the shape it actually recurs in.
    #
    # Counting a bare literal works for a radio band and not for a
    # REACH: `8` appears everywhere and means nothing on its own. What
    # matters is where it appears - a comparison against a claim's
    # bounds is asking "am I near this place", and the tolerance in
    # that comparison is a reach somebody declared somewhere.
    #
    # `PLACE_SIGHT` was a file-level local in SAO_Perception, read four
    # times there for FORGETTING, while SAO_Population spelled the
    # number eight times for LEARNING. Its own comment claimed the two
    # halves used the same reach - "learning and forgetting should not
    # have different reaches" - and nothing made that true. Moving it
    # would have split them in silence.
    print()
    print("=" * 70)
    print("REACHES IN CLAIM COMPARISONS")
    print("=" * 70)
    bare = []
    named = 0
    # Only the OUTWARD tolerance shape: a minimum widened downward or
    # a maximum widened upward. `min - n` and `max + n` ask "am I
    # within n of this place".
    #
    # `c.maxY - c.minY + 1` is a SPAN, not a tolerance, and
    # `c.minY + ZombRand(...)` picks a point inside the claim. A first
    # pass matched any arithmetic on a bound and reported both as
    # findings - twenty-four of them, most of which were neither a
    # reach nor wrong.
    pattern = re.compile(
        r"\bmin([XY])\s*-\s*(\w+)|\bmax([XY])\s*\+\s*(\w+)")
    for path in sorted(LUA.rglob("*.lua")):
        text = path.read_text(encoding="utf-8", errors="ignore")
        for i, line in enumerate(text.splitlines(), start=1):
            if line.strip().startswith("--"):
                continue
            for m in pattern.finditer(line):
                token = m.group(2) or m.group(4)
                # A one-tile expansion is geometry, not policy: it
                # widens a rectangle to test adjacency, and there is
                # no reach to declare. Anything larger is a distance
                # somebody chose.
                if token == "1":
                    named += 1
                elif token.isdigit():
                    bare.append((path.name, i, m.group(0), line.strip()[:60]))
                else:
                    named += 1
    print(f"  comparisons against a claim bound: {named + len(bare)}")
    print(f"    reading a declared reach: {named}")
    print(f"    spelling a bare number:   {len(bare)}")
    for name, ln, frag, ctx in bare[:8]:
        print(f"      {name}:{ln}  {frag}   {ctx}")
    if bare:
        dupes.append(("claim reach", "a bare number where a reach "
                      "should be read", [f"{n}:{l}" for n, l, _, _ in bare]))

    print()
    print("VERDICT:")
    print(f"  domain-blind guards: {len(findings)}")
    print(f"  constants declared more than once: {len(dupes)}")
    if findings or dupes:
        return 1
    if checked == 0:
        print("  NOTHING WAS EXAMINED - the iterator patterns no longer")
        print("  match anything, so this tool is measuring nothing")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
