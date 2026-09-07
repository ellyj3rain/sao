#!/usr/bin/env python3
r"""Border 93 - every SAO.<Module>.<fn> call has a definition somewhere.

The [C14] sweep instrument, promoted. The class is F-030/F-039's
shape: a call to a function no module defines, wrapped in the pcall
this tree wraps everything in, is a silent no-op forever - the
anchored origins that never fired, the medic's walk that never
ticked. Nothing at runtime ever says so.

Idioms enumerated (analysis discipline - the first run of this
instrument flagged nine "missing" functions that were all one
UNENUMERATED definition idiom, `local Census = {} ... SAO.Census =
Census`; the reader was wrong, not the Lua):

  definitions:  function SAO.X.name(...)
                function Alias.name(...)      local Alias = SAO.X
                                              or SAO.X = Alias export
                SAO.X.name = ... / Alias.name = ...  (any indent)
  call sites:   SAO.X.name(   fully qualified only - alias-form calls
                resolve inside their own module, where a missing local
                target errors loudly instead of silently.

Comments are stripped first (prose is not code). The verdict refuses
an empty reading: zero call sites means the reader broke, not that
the tree is clean.
"""
import pathlib
import re
import sys
import collections

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"


def strip(src):
    out = []
    for line in src.split("\n"):
        i = line.find("--")
        out.append(line[:i] if i >= 0 else line)
    return "\n".join(out)


def main():
    print("=" * 74)
    print("EVERY CALL HAS A TARGET")
    print("=" * 74)

    files = {p: p.read_text(encoding="utf-8", errors="ignore")
             for p in sorted(LUA.rglob("*.lua"))}
    if not files:
        print()
        print("VERDICT:")
        print("  FAULT: no Lua was read - a verdict about an empty set")
        return 1

    alias_of = {}
    for p, src in files.items():
        for m in re.finditer(r"^local\s+(\w+)\s*=\s*(SAO\.\w+)\s*$",
                             src, re.M):
            alias_of[(p, m.group(1))] = m.group(2)
        for m in re.finditer(r"^(SAO\.\w+)\s*=\s*(\w+)\s*$", src, re.M):
            alias_of[(p, m.group(2))] = m.group(1)

    stripped = {p: strip(s) for p, s in files.items()}

    defined = set()
    for p, src in stripped.items():
        for m in re.finditer(r"function\s+(SAO\.\w+)\.(\w+)\s*\(", src):
            defined.add((m.group(1), m.group(2)))
        for m in re.finditer(r"^\s*(SAO\.\w+)\.(\w+)\s*=", src, re.M):
            defined.add((m.group(1), m.group(2)))
        for m in re.finditer(r"function\s+(\w+)\.(\w+)\s*\(", src):
            mod = alias_of.get((p, m.group(1)))
            if mod:
                defined.add((mod, m.group(2)))
        for m in re.finditer(r"^\s*(\w+)\.(\w+)\s*=", src, re.M):
            mod = alias_of.get((p, m.group(1)))
            if mod:
                defined.add((mod, m.group(2)))

    calls = collections.defaultdict(list)
    for p, src in stripped.items():
        for m in re.finditer(r"(SAO\.\w+)\.(\w+)\s*\(", src):
            calls[(m.group(1), m.group(2))].append(
                f"{p.name}:{src[:m.start()].count(chr(10)) + 1}")

    print(f"  definitions: {len(defined)}   distinct qualified calls: "
          f"{len(calls)}")

    faults = []
    if not calls:
        faults.append("no qualified call site was read at all - the "
                      "reader is broken, not the tree clean")
    for (mod, fn), sites in sorted(calls.items()):
        if (mod, fn) not in defined:
            faults.append(
                f"{mod}.{fn} is called at {', '.join(sites[:3])} and "
                "defined nowhere - inside this tree's pcall discipline "
                "that is a silent no-op forever (F-030/F-039's shape)")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  93) call targets: all {len(calls)} distinct qualified calls")
    print("      resolve to a definition; the silent no-op class is empty")
    return 0


if __name__ == "__main__":
    sys.exit(main())
