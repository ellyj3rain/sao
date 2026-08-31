#!/usr/bin/env python3
r"""Border 49 - a number that already has a name, typed anyway.

[B45] named `ARRIVAL_REACH` and `TALK_REACH` and found, on the way,
that three tiles ALREADY had a name: `MEET_RANGE` in Population, read
at exactly one site since [B41]. The live half of the same spatial
question had been typed as `9.0` in three places, and nothing connected
them - not because anyone decided the two were different, but because
a name in one file is invisible to a number in another.

That is the specific failure this border exists for. Border 47 counts
bare radii and refuses to let the count rise; it cannot tell a fresh
one-off from a number that duplicates a rule already spoken for.

WHAT COUNTS AS A REACH
----------------------
Derived, never listed - a listed set drifts. A reach is any ALL_CAPS
constant that appears on the right of one of Border 47's two radius
forms (`x*x + y*y <= NAME` or `<= NAME * NAME`, and `*dist* <= NAME`),
whose declaration assigns it a bare number. That definition earns its
keep twice: it admits `WITNESS_REACH` and excludes `WITNESS_FRESH`,
which is compared the same way but against a tick count, not a
distance.

It also excludes `P.PLACE_SIGHT` and `P.FACTION_SIGHT`, which are BOX
MARGINS - added to a bounding box's edges, never squared against a
radius. That exclusion is deliberate: twelve tiles of box margin and a
twelve-tile radius are not the same claim, and calling them a collision
would teach the allowlist to hold entries that mean nothing.

WHY TREE-WIDE
-------------
`SAO_Controller.lua:115` already reads `SAO.Perception.EARSHOT`, so a
constant in another module is not out of reach - it is merely
unmentioned. A collision confined to one file would have missed the
forty at `SAO_Controller.lua` against `P.GROUND_REACH`, which is one of
the two this border found on its first run.

WHAT THE ALLOWLIST IS
---------------------
Not a suppression list. [B40] kept two feud reaches apart on purpose
and WROTE THE REASON DOWN, and that written reason is the whole of the
discipline. An entry here is that reason. A collision is either wired
to the name or argued in a sentence - there is no third state where it
sits unexamined.

And an entry must still collide. If the number moves or the constant
goes, the argument has outlived what it argued about and says nothing
true any more; that is a fault in the other direction.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from menu_reach import strip_lua                       # noqa: E402
from reach_scan import bare_reaches, line_of           # noqa: E402

NAME = r"(?:[A-Za-z_][\w.]*\.)?([A-Z][A-Z0-9_]{2,})"
SQ_NAME = re.compile(
    r"(\w+)\s*\*\s*\1\s*\+\s*(\w+)\s*\*\s*\2\s*<=\s*" + NAME)
FLAT_NAME = re.compile(r"\b\w*[Dd]ist\w*\s*<=\s*" + NAME)
DECL = re.compile(
    r"^\s*(?:local\s+)?(?:[A-Za-z_][\w.]*\.)?([A-Z][A-Z0-9_]{2,})"
    r"\s*=\s*([0-9][0-9.]*)\s*(?:--.*)?$", re.M)
SQ_VAL = re.compile(
    r"(\w+)\s*\*\s*\1\s*\+\s*(\w+)\s*\*\s*\2\s*<=\s*([0-9][0-9.]*)")
FLAT_VAL = re.compile(r"\b\w*[Dd]ist\w*\s*<=\s*([0-9][0-9.]*)")

# Each key is (file, tiles, constant). Each value is why the two are
# NOT one rule - which is to say, why moving one must not move the
# other. A sentence that would not survive being read aloud to someone
# holding both sites is not an argument and does not belong here.
ALLOWED = {
    ("SAO_Harness.lua", 3.0, "ARRIVAL_REACH"):
        "`survivorNear` - which survivor the CURSOR is over when the "
        "context menu opens. Three tiles of mouse tolerance and three "
        "tiles of having-got-there are not one rule: the first is a "
        "claim about pointing accuracy on a 2.5D grid, the second about "
        "bodies. Make arrival stricter and the menu must not get harder "
        "to click; widen the click and nobody has arrived anywhere.",
    ("SAO_Harness.lua", 3.0, "MEET_RANGE"):
        "The same cursor tolerance against the DORMANT road meeting. "
        "`MEET_RANGE` decides that two records with no bodies crossed "
        "paths in a county nobody is watching. There is no cursor "
        "within a hundred miles of that question.",
    ("SAO_UI.lua", 40.0, "GROUND_REACH"):
        "The Ledger's list. Forty tiles here is how far away a survivor "
        "can be and still be worth a LINE ON A PANEL; forty in "
        "`P.GROUND_REACH` is how far a person learns the ground around "
        "them. One is a question about a reader's attention and the "
        "other about a survivor's senses, and the day the panel gets "
        "longer or shorter the county must not start noticing more or "
        "less of the world.",
    ("SAO_Controller.lua", 40.0, "GROUND_REACH"):
        "The memorial walk. Forty tiles here is how far someone will "
        "TRAVEL to stand where their dead lie; forty tiles in "
        "`P.GROUND_REACH` is how far they LEARN the ground around them. "
        "One is willingness, the other is perception. Widen what a "
        "person notices and this must not follow, or grief would start "
        "tracking eyesight.",
    ("SAO_Controller.lua", 10.0, "EARSHOT"):
        "The armorer. Ten tiles here is who is PRESENT when a weapon "
        "comes out of the stores; `P.EARSHOT` is who could have HEARD "
        "it. A handout is a thing you are at, not a thing you overhear, "
        "and the day earshot changes for walls or weather the armory "
        "must not empty differently.",
    ("SAO_Controller.lua", 10.0, "WITNESS_REACH"):
        "The armorer again, against the third ten in the tree. "
        "`WITNESS_REACH` is who could have SEEN a death - a claim about "
        "sightlines that [B43] argued into one rule from three "
        "spellings. Being present for a handover is not a claim about "
        "sightlines. Three tens, three rules: present, audible, "
        "visible. They share a scale because a room is a room, and "
        "nothing more than that.",
}


def main():
    faults = []
    print("=" * 74)
    print("A NUMBER THAT ALREADY HAS A NAME")
    print("=" * 74)

    srcs = {p: strip_lua(p.read_text(encoding="utf-8", errors="ignore"),
                         strings=False)
            for p in sorted(LUA.rglob("*.lua"))}

    declared, used_as_reach = {}, set()
    for src in srcs.values():
        for m in DECL.finditer(src):
            declared[m.group(1)] = float(m.group(2))
        for m in SQ_NAME.finditer(src):
            used_as_reach.add(m.group(3))
        for m in FLAT_NAME.finditer(src):
            used_as_reach.add(m.group(1))
    reaches = {n: declared[n] for n in sorted(used_as_reach) if n in declared}

    print("  reaches with a name: "
          + ", ".join(f"{n}={v:g}" for n, v in sorted(reaches.items())))

    seen = set()
    for path, src in srcs.items():
        for off, tiles, _spelling in bare_reaches(src):
            for name, value in reaches.items():
                if abs(tiles - value) > 1e-6:
                    continue
                line = src.count("\n", 0, off) + 1
                key = (path.name, tiles, name)
                seen.add(key)
                if key in ALLOWED:
                    continue
                faults.append(
                    f"{path.name}:{line} compares against {tiles:g} tiles, "
                    f"and {tiles:g} tiles is already called `{name}`. Wire "
                    "it to the name, or add the pair to ALLOWED in this "
                    "file with the reason moving one must not move the "
                    "other - the way [B40] kept two feud reaches apart "
                    "and wrote down why")

    print(f"  collisions found: {len(seen)}   argued in ALLOWED: "
          f"{len(ALLOWED)}")

    for key in sorted(ALLOWED):
        if key not in seen:
            faults.append(
                f"ALLOWED holds an argument for {key[1]:g} tiles against "
                f"`{key[2]}` in {key[0]}, and that collision is gone. The "
                "reason has outlived the thing it was about; delete it "
                "rather than leave a sentence that no longer describes "
                "any code")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  49) reach collisions: every one of the {len(seen)} numbers "
          "that duplicates a named reach is argued, and every argument "
          "still has something to argue about")
    return 0


if __name__ == "__main__":
    sys.exit(main())
