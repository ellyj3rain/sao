#!/usr/bin/env python3
r"""Border 13 ([B26]) - engine-string literals that match nothing.

[B24] was a string that matched nothing, and it killed the pact layer
for the life of the project. Border 11 caught that shape for one
in-repo vocabulary; border 12 caught it across the Lua/Java boundary.
Both compare our strings against OUR OWN canon.

This one compares them against the GAME. [B26] found four literals
that no border could ever have caught, because every one of them was
internally consistent and simply described an engine that had moved
on:

    "FirstAid".equals(item.getCategory())   - getCategory never
                                              returns a display
                                              category, so 53 items
                                              were unreachable
    "Tool".equals(item.getCategory())       - same, 72 items
    "Base.Cigarettes"                       - renamed in B21
    endsWith("Seeds")                       - B21 names seeds
                                              singular; 1 of 79

An item name or display category that the game does not produce is
not an error anywhere. It is a want that is simply never satisfied.

## Honesty about availability

This needs the game's own script data. If the install is not present
the check reports SKIPPED, never "none" - a check that cannot run must
not look like a check that passed.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
# The same install tools/build-java.sh compiles against.
GAME = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
SCRIPTS = GAME / "media" / "scripts"

LABEL = "13) engine-string literals matching nothing the engine produces:"


def engine_vocabularies():
    """(item names, display categories) the game actually ships."""
    items, cats = set(), set()
    for f in SCRIPTS.rglob("*.txt"):
        try:
            txt = f.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        items.update(re.findall(r"^\s*item\s+([A-Za-z0-9_]+)\s*$",
                                txt, re.M))
        cats.update(m.strip() for m in re.findall(
            r"DisplayCategory\s*=\s*([A-Za-z0-9_]+)\s*,", txt))
    return items, cats


def ours():
    """Literals we compare engine strings against, with their site."""
    full, disp, wrong = {}, {}, {}
    src = list((ROOT / "java/src").rglob("*.java"))
    src += list((ROOT / "mod/42.20/media/lua").rglob("*.lua"))
    for f in src:
        txt = f.read_text(encoding="utf-8", errors="ignore")
        # "Base.X".equals(<anything>getFullType())
        for m in re.finditer(
                r'"Base\.([A-Za-z0-9_]+)"\s*\.equals\([^)]*getFullType',
                txt):
            full.setdefault(m.group(1), f.name)
        # "X".equals(<anything>getDisplayCategory())
        for m in re.finditer(
                r'"([A-Za-z0-9_]+)"\s*\.equals\([^)]*getDisplayCategory',
                txt):
            disp.setdefault(m.group(1), f.name)
        # carriedDisplayCategory(body, "X") on either side
        for m in re.finditer(
                r'carriedDisplayCategory\([^,]+,\s*"([A-Za-z0-9_]+)"', txt):
            disp.setdefault(m.group(1), f.name)
        # "X".equals(<anything>getCategory()) - the WRONG accessor.
        for m in re.finditer(
                r'"([A-Za-z0-9_]+)"\s*\.equals\([^)]*getCategory\(\)',
                txt):
            wrong.setdefault(m.group(1), f.name)
    return full, disp, wrong


def main():
    if not SCRIPTS.is_dir():
        print(LABEL, "SKIPPED (game data not found)")
        return 0
    items, cats = engine_vocabularies()
    if not items or not cats:
        print(LABEL, "SKIPPED (game data unreadable)")
        return 0
    full, disp, wrong = ours()
    dead = []
    for name, where in sorted(full.items()):
        if name not in items:
            dead.append(f"{where}:Base.{name} (no such item)")
    for name, where in sorted(disp.items()):
        if name not in cats:
            dead.append(f"{where}:{name} (no such DisplayCategory)")
    # Second rule: a real DisplayCategory read through getCategory(),
    # which returns the Java-class category and can never produce one.
    # This is how [B26]'s `medical` and `tool` stayed dead - the value
    # was right, the accessor was wrong, and nothing was inconsistent
    # enough for any other border to notice.
    for name, where in sorted(wrong.items()):
        if name in cats:
            dead.append(f"{where}:{name} (a DisplayCategory read via "
                        "getCategory)")
    print(LABEL, dead or "none")
    return 1 if dead else 0


if __name__ == "__main__":
    sys.exit(main())
