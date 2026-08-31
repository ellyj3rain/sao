#!/usr/bin/env python3
r"""Border 28 - nobody knows anything for no reason.

The operator, correcting a reading of relational and procedural
learning as a field on a record: *"this is, like, an ontological axes.
This is not... that is something that is born from the principle that
I've established. That is not itself the principle. which should be
demonstrated throughout the entire simulation."*

So this border does not define the principle and does not add a
taxonomy. It enumerates **every place an agent comes to hold
something** and requires each one to say HOW - using the mod's own
vocabulary, which already existed:

    procedural  `observed`, `lived`      they were there, they did it
    relational  `told`, `heard`,         it came through somebody
                `witnessed`

An acquisition that says neither is knowledge arriving from a
registry, a global, or by fiat, and it is the root of the defect class
[B35], [B35] and [B37] each fixed one instance of.

WHAT IT FOUND
-------------
`P.learnPlace` wrote `source = "observed"` unconditionally, so no
caller could state anything. Two callers had already written the truth
in a comment directly above the call:

    -- Told, not seen: they know it because somebody standing there
    -- said so.
    SAO.Perception.learnPlace(key, id, myGround)

The manner of acquisition was stated in prose and lost in the data.
A Knox camp read out of another mod's registry was recorded as
something the survivor had seen.

TWO THINGS DELIBERATELY NOT FAULTS
----------------------------------
Reads and forgets. The first draft matched any indexing of a belief
table and reported 31 violations, most of them `local pb =
b.people[name]` and `b.zombies[key] = nil`. Reading what you already
believe acquires nothing and forgetting is its opposite; counting
either measures something else.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
PERC = LUA / "shared" / "SAO_Perception.lua"

_WRITE = (r"(?:[A-Za-z_]\w*)\.(?:people|zombies|places|factions|known)"
          r"\[[^\]]*\]\s*=\s*(?!nil)")
_LEARN = (r"(?:Lessons\.learn|Perception\.learnPlace|"
          r"Perception\.learnBuilding)\s*\(")
_KNOWN = r"lessonsKnown\[[^\]]*\]\s*=\s*(?!nil)"
ACQUIRES = re.compile(f"{_WRITE}|{_LEARN}|{_KNOWN}")

PROCEDURAL = {"observed", "lived"}
RELATIONAL = {"told", "heard", "witnessed"}
# Wide enough to span a table literal. The belief records here run to
# nine fields, so a six-line window sat entirely above the `source`
# line inside `learnBuilding` and reported the one function whose
# whole job is provenance as having none.
WINDOW = 14

# Allowlisted rather than tolerated as noise, the way `invariant_sweep`
# names its non-news kinds. Each needs a reason that is about the code
# and not about the checker.
ALLOWED = {
    # The save migration. An old world's lessons predate provenance
    # entirely; inventing one for them would be worse than the gap.
    ("shared/SAO_Lessons.lua", "rec.lessonsKnown[key] = 1.0"),
}


def classify(lines, i, line):
    lo, hi = max(0, i - WINDOW), min(len(lines), i + WINDOW + 1)
    window = "\n".join(lines[lo:hi])
    marks = set(re.findall(r'"(observed|lived|told|heard|witnessed)"',
                           window))
    proc, rel = marks & PROCEDURAL, marks & RELATIONAL
    if proc and rel:
        return "both", marks
    if proc:
        return "procedural", marks
    if rel:
        return "relational", marks
    # A call that passes provenance as a VARIABLE carries it just as
    # well as one passing a literal - `Lessons.learn(id, k, w, src, of)`
    # is the settled-past generator handing on what it decided.
    if re.search(r"learn\([^)]*,\s*(src|source|prov)\b", line):
        return "carried", marks
    # And a write whose source comes from a PARAMETER carries it. The
    # bodies of learnPlace and learnBuilding are the two functions that
    # exist to receive provenance, so demanding a literal inside them
    # would demand the opposite of the thing.
    if re.search(r"source = tostring\(source or|source = source\b", window):
        return "carried", marks
    return "NEITHER", marks


def main():
    buckets = {"procedural": [], "relational": [], "both": [],
               "carried": [], "NEITHER": []}
    for f in sorted(LUA.rglob("*.lua")):
        lines = f.read_text(encoding="utf-8", errors="ignore").splitlines()
        rel_path = f.relative_to(LUA).as_posix()
        for i, line in enumerate(lines):
            s = line.strip()
            if s.startswith("--") or "] = nil" in s:
                continue
            if s.startswith("function ") or " function " in s:
                continue
            if not ACQUIRES.search(line):
                continue
            if (rel_path, s) in ALLOWED:
                continue
            kind, marks = classify(lines, i, line)
            buckets[kind].append((rel_path, i + 1, s[:88]))

    total = sum(len(v) for v in buckets.values())
    print("=" * 74)
    print(f"WHERE KNOWLEDGE COMES FROM - {total} acquisitions")
    print("=" * 74)
    for kind in ("procedural", "relational", "both", "carried"):
        n = len(buckets[kind])
        print(f"  {kind:<11} {n:>3}  "
              f"({100.0 * n / max(total, 1):>3.0f}%)")
    print(f"  {'unaccounted':<11} {len(buckets['NEITHER']):>3}")
    print(f"  allowlisted {len(ALLOWED)}: the save migration, which "
          "predates provenance")

    src = PERC.read_text(encoding="utf-8", errors="ignore")
    links = {
        "learnPlace takes provenance":
            "function P.learnPlace(id, ownerKey, bounds, source)" in src,
        "learnBuilding takes it too":
            "function P.learnBuilding(id, place, tick, source)" in src,
        # The default is the whole point. Defaulting to "observed" is
        # how a registry read came to be recorded as something seen.
        "omission is unknown, never observed":
            'source = tostring(source or "unknown")' in src
            and 'at = b.lastScanAt, source = "observed"' not in src,
    }
    print()
    print("  THE SHIPPED LINKS")
    for k, v in links.items():
        print(f"    {'yes' if v else 'NO '}  {k}")

    print()
    print("VERDICT:")
    if buckets["NEITHER"]:
        for path, ln, text in buckets["NEITHER"]:
            print(f"  FAULT: {path}:{ln} acquires without saying how")
            print(f"         {text}")
        return 1
    if not all(links.values()):
        print("  FAULT: the acquisition path cannot carry provenance")
        return 1
    print(f"  28) acquisition: {total} sites, every one says how it "
          "was come by")
    return 0


if __name__ == "__main__":
    sys.exit(main())
