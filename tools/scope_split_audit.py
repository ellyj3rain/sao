#!/usr/bin/env python3
"""F-030-class scanner: file-local declared AFTER a bare assignment to the
same name (the writer hits a global, later readers hit the never-assigned
local upvalue). Reports candidates for hand-verification. Verified on the
synthetic case before the sweep."""
import re, sys, pathlib
from pcall_audit import strip_lua
from scanner_inventory import lexical_context

def strip(code):
    return strip_lua(code)

def audit(path):
    lines = strip(pathlib.Path(path).read_text(encoding="utf-8")).split("\n")
    decls = {}   # name -> first file-level 'local NAME' line (col 0 only)
    for i, line in enumerate(lines, 1):
        m = re.match(r"local\s+([A-Za-z_]\w*)\s*(=|$)", line)
        if m and m.group(1) not in decls:
            decls[m.group(1)] = i
    hits = []
    for name, declline in decls.items():
        for i, line in enumerate(lines[:declline - 1], 1):
            # bare assignment: NAME = ... not preceded by 'local', not a
            # field (.NAME / :NAME), not comparison (==)
            for m in re.finditer(
                    r"(?<![\w.:])" + re.escape(name) + r"\s*=(?!=)", line):
                before = line[:m.start()]
                if re.search(r"\blocal\s+$", before):
                    continue
                if re.search(r"\blocal\b[^=]*$", before):
                    continue
                # A constructor's NAME=value is a key, not an assignment to
                # the same-named lexical/global variable. Track brace depth
                # in stripped code, including multi-line constructors.
                prefix = '\n'.join(lines[:i - 1]) + '\n' + line[:m.start()]
                if lexical_context(prefix)[1]:
                    continue
                hits.append((name, i, declline, line.strip()[:70]))
    return hits

def main():
    files = sys.argv[1:]
    if files == ['--inventory']:
        from scanner_inventory import current
        files = current().runtime_lua()
    if not files:
        print("FAULT: scope-split audit received no Lua sources")
        return 2
    total = 0
    for f in files:
        for name, at, decl, text in audit(f):
            total += 1
            print(f"{pathlib.Path(f).name}:{at} writes '{name}' before its "
                  f"local decl at :{decl}  | {text}")
    print("candidates:", total)
    return 1 if total else 0

if __name__ == '__main__':
    sys.exit(main())
