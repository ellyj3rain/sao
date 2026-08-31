#!/usr/bin/env python3
r"""Border 57 - a registry nobody can see is a subsystem nobody can check.

The operator played a session and asked whether the mod had worked.
The log carried 234 identities, 235 history reads, 340 population
lines - and not one body ever materialising. Whether that meant nobody
came near them or the live half never ran, nothing in the game could
say.

The Ledger read "The County - 234 living, 3 dead". It counts
IDENTITIES. `SAO.Body.active` - the registry of everyone actually
standing in the world - was not read by the panel at all, and neither
was `SAO.Body.knox`. `Body.activeCount()` existed and had exactly one
caller: a debug submenu three levels down.

And `Near you` cannot answer it either, because that section vanishes
when it is empty. Absent-because-nobody-is-near and
absent-because-nobody-exists look the same.

That is [B33]'s shape - a world running differently with nothing
saying so - sitting in the one surface built to prevent it.

THE RULE
--------
Every registry of PEOPLE must be readable from the Ledger.

Not every table: this is scoped to the two modules that hold bodies
and agents, because those are the ones whose emptiness is
indistinguishable from failure. `Seams.dark` being empty means nothing
broke; `Body.active` being empty means either a quiet neighbourhood or
a dead subsystem, and the player deserves to know which.

A registry found in those modules and not declared here is a fault, so
a new one cannot be added without either a surface or an argument. A
declaration whose registry has gone is also a fault - the list
describes what exists, not what used to.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
LEDGER = LUA / "client" / "SAO_UI.lua"
HOLDERS = ("SAO_Body.lua", "SAO_Controller.lua")

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from menu_reach import strip_lua                       # noqa: E402

# `X.name = X.name or {}` - the module-scope self-init idiom.
REGISTRY = re.compile(r"^(\w+)\.(\w+)\s*=\s*\1\.\2\s+or\s+\{\}", re.M)

# Each registry of people, and what the Ledger may read to show it.
# The reader is named so "it is on the panel" is a claim that can be
# checked rather than a thing somebody remembers doing.
SURFACED = {
    "Body.active": ("activeCount",
                    "how many of ours are standing in the world"),
    "Body.knox": ("knoxCount",
                  "Knox inhabitants with a shell - as loaded as ours, "
                  "because the player can walk up to them either way"),
    "Ctl.agents": ("Controller.agents",
                   "who is under decision this tick; the panel walks it "
                   "directly for the Near you list"),
}


def main():
    faults = []
    print("=" * 74)
    print("A REGISTRY NOBODY CAN SEE")
    print("=" * 74)

    if not LEDGER.exists():
        print()
        print("VERDICT:")
        print("  FAULT: SAO_UI.lua is gone, so no registry has a surface at "
              "all and the county's health is unknowable from inside the "
              "game")
        return 1
    ledger = strip_lua(LEDGER.read_text(encoding="utf-8", errors="ignore"),
                       strings=False)

    found = {}
    for name in HOLDERS:
        path = LUA / "client" / name
        if not path.exists():
            faults.append(
                f"{name} is gone and this border still expects to read its "
                "registries - the list has outlived its subject")
            continue
        src = strip_lua(path.read_text(encoding="utf-8", errors="ignore"),
                        strings=False)
        for m in REGISTRY.finditer(src):
            root, field = m.group(1), m.group(2)
            if root == "SAO":          # the module namespace, not a registry
                continue
            found[f"{root}.{field}"] = name

    print(f"  registries of people: {len(found)}  "
          f"({', '.join(sorted(found)) or 'none'})")
    print(f"  declared with a surface: {len(SURFACED)}")

    if not found:
        faults.append(
            "no registry was found in either module, which cannot be true "
            "of a mod that puts people in the world - the reading failed "
            "rather than the code being clean")

    for reg, where in sorted(found.items()):
        if reg not in SURFACED:
            faults.append(
                f"{reg} is a registry of people declared in {where} and no "
                "surface shows it. Its emptiness would be indistinguishable "
                "from the subsystem being dead, which is what [B47] found "
                "the Ledger doing about `Body.active` for the life of the "
                "project. Give it a reader and declare it here")
            continue
        reader, why = SURFACED[reg]
        if reader not in ledger:
            faults.append(
                f"{reg} is declared as surfaced through `{reader}` ({why}) "
                "and the Ledger does not mention it. The declaration is "
                "false: nothing on the panel would change if that registry "
                "emptied")

    for reg in sorted(SURFACED):
        if reg not in found:
            faults.append(
                f"{reg} is declared here and no longer exists in "
                f"{' or '.join(HOLDERS)} - the entry describes no code")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  57) registry surface: all {len(found)} registries of people "
          "reach the Ledger, so an empty county and a dead subsystem no "
          "longer read the same")
    return 0


if __name__ == "__main__":
    sys.exit(main())
