#!/usr/bin/env python3
"""F-030-class scanner: file-local declared AFTER a bare assignment to the
same name (the writer hits a global, later readers hit the never-assigned
local upvalue). Reports candidates for hand-verification. Verified on the
synthetic case before the sweep."""
import re, sys, pathlib

def strip(code):
    code = re.sub(r'"(\\.|[^"\\])*"', '""', code)
    code = re.sub(r"'(\\.|[^'\\])*'", "''", code)
    return "\n".join(line.split("--")[0] for line in code.split("\n"))

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
                hits.append((name, i, declline, line.strip()[:70]))
    return hits

files = sys.argv[1:]
total = 0
for f in files:
    for name, at, decl, text in audit(f):
        total += 1
        print(f"{pathlib.Path(f).name}:{at} writes '{name}' before its "
              f"local decl at :{decl}  | {text}")
print("candidates:", total)
