#!/usr/bin/env python3
r"""[B34] The pcalls whose failure nobody would ever learn about.

The bulkheads ([B33]) at least COUNT their faults. The wider surface
is every pcall that swallows an error with no counter, no log and no
checked result - those fail silently, forever, with nothing raised
anywhere.

There are 531 of them, and cataloguing all 531 would be worthless: the
overwhelming majority are defensive reads with a safe default, which is
exactly what pcall is for. This ranks them instead, on one question -
IF THIS FAILED, WOULD ANYTHING BE LOST?

    CHECKED    the result is bound and acted on. Not a silent site.
    READ       result discarded, body only reads. A failure costs one
               tick of one value and the default carries it.
    WRITE      result discarded, body MUTATES something that outlives
               the call - a record field, a standing, a belief.
    PERSISTED  result discarded, body writes into ModData, which is
               what survives the session. The most expensive kind:
               a failure here loses saved state and says nothing.

Only WRITE and PERSISTED are worth a human's attention, and only the
reachable ones among those are worth changing.

The classifier is deliberately conservative about CHECKED: anything
whose result is bound to a name is treated as checked, even if the
name is then ignored, because guessing at "bound but unused" would
manufacture findings. That undercounts the problem rather than
inflating it, which is the correct direction to be wrong in.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"

# Writes that outlive the call.
PERSIST = re.compile(r"ModData\.getOrCreate|ModData\.add|ModData\.create")
MUTATE = re.compile(
    r"(?<![=~<>])=(?!=)"                      # a real assignment
    r"|table\.insert|table\.remove"
    r"|SAO\.Standing\.(?:set|adjust|bond|feud|declare|peace|join|leave)"
    r"|SAO\.Perception\.(?:observe|tell|note|forget)"
    r"|SAO\.Identity\.(?:add|remove|kill)"
)


def strip_lua(src):
    """Blank comments and string bodies, preserving offsets."""
    out = list(src)
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c == "-" and src.startswith("--", i):
            m = re.match(r"--\[(=*)\[", src[i:])
            if m:
                close = "]" + m.group(1) + "]"
                end = src.find(close, i)
                end = n if end < 0 else end + len(close)
            else:
                end = src.find("\n", i)
                end = n if end < 0 else end
            for k in range(i, end):
                if out[k] != "\n":
                    out[k] = " "
            i = end
            continue
        if c == "[":
            m = re.match(r"\[(=*)\[", src[i:])
            if m:
                close = "]" + m.group(1) + "]"
                end = src.find(close, i)
                end = n if end < 0 else end + len(close)
                for k in range(i, end):
                    if out[k] != "\n":
                        out[k] = " "
                i = end
                continue
        if c in "'\"":
            j = i + 1
            while j < n:
                if src[j] == "\\":
                    j += 2
                    continue
                if src[j] == c or src[j] == "\n":
                    break
                j += 1
            for k in range(i + 1, min(j, n)):
                out[k] = "_"
            i = min(j + 1, n)
            continue
        i += 1
    return "".join(out)


def body_of(src, open_paren):
    """Text inside pcall(...), by balanced parens."""
    depth, j = 1, open_paren + 1
    while j < len(src) and depth:
        if src[j] in "([{":
            depth += 1
        elif src[j] in ")]}":
            depth -= 1
        j += 1
    return src[open_paren + 1:j - 1], j


def classify(prefix, body):
    """CHECKED / PERSISTED / WRITE / READ."""
    tail = prefix[-90:]
    # Result bound to a name, or consumed by a condition or return.
    if re.search(r"(?:local\s+[\w\s,]+|[\w.\[\]]+)\s*=\s*$", tail):
        return "CHECKED"
    if re.search(r"\b(?:if|elseif|while|return|and|or|not)\s*\(?\s*$",
                 tail):
        return "CHECKED"
    if PERSIST.search(body):
        return "PERSISTED"
    if MUTATE.search(body):
        return "WRITE"
    return "READ"


def once_only(rows_src):
    """Persisted once-only writes with anything callable after them."""
    guard = re.compile(r"if\s+(?:\w+\s+and\s+)?not\s+([\w.]+)\s+then")
    unsafe, checked = [], 0
    for path in sorted(LUA.rglob("*.lua")):
        src = strip_lua(path.read_text(encoding="utf-8", errors="ignore"))
        rel = str(path.relative_to(ROOT)).replace("\\", "/")
        for m in re.finditer(r"\bpcall\s*\(", src):
            body, _ = body_of(src, m.end() - 1)
            if classify(src[:m.start()], body) != "PERSISTED":
                continue
            for g in guard.finditer(body):
                name = g.group(1)
                after = body[g.end():]
                am = re.search(re.escape(name) + r"\s*=(?!=)", after)
                if not am:
                    continue
                checked += 1
                calls = re.findall(r"([\w.:]+)\s*\(", after[am.end():])
                if calls:
                    unsafe.append({
                        "file": rel,
                        "line": src[:m.start()].count("\n") + 1,
                        "name": name,
                        "after": ", ".join(calls),
                    })
    return unsafe, checked




def main():
    rows = []
    for path in sorted(LUA.rglob("*.lua")):
        raw = path.read_text(encoding="utf-8", errors="ignore")
        src = strip_lua(raw)
        rel = str(path.relative_to(ROOT)).replace("\\", "/")
        for m in re.finditer(r"\bpcall\s*\(", src):
            body, _ = body_of(src, m.end() - 1)
            kind = classify(src[:m.start()], body)
            rows.append({
                "file": rel,
                "line": src[:m.start()].count("\n") + 1,
                "kind": kind,
                "body": " ".join(body.split())[:88],
            })

    order = ["PERSISTED", "WRITE", "READ", "CHECKED"]
    counts = {k: sum(1 for r in rows if r["kind"] == k) for k in order}
    print("=" * 70)
    print(f"{len(rows)} pcall sites across the Lua tree")
    print("=" * 70)
    for k in order:
        print(f"  {k:<10} {counts[k]:>4}")
    print()
    print("  CHECKED and READ are pcall doing its job and are not")
    print("  listed. Only a discarded result over a lasting write can")
    print("  lose something without saying so.")

    unsafe, checked = once_only(rows)

    print()
    print("=" * 70)
    print("THE GATE - a once-only persisted write must be LAST")
    print("=" * 70)
    print("  A guard of the form `if not X` opens exactly once in the")
    print("  life of a world. If anything throws between the write")
    print("  landing and the end of the pcall, the flag is kept, the")
    print("  work it was guarding is lost, and the guard can never")
    print("  open again. Nothing is logged, because the pcall is")
    print("  discarded. Putting the write last removes the window.")
    print()
    for r in unsafe:
        print(f"  UNSAFE: {r['file']}:{r['line']}")
        print(f"      writes {r['name']} but is not the last "
              "statement in its pcall")
        print(f"      still in the pcall after it: {r['after']}")
        print("      (that list is taken from the text after the "
              "write's target, so it can include the write's own "
              "right-hand side - the point is that the pcall does "
              "not end there)")
    if not unsafe:
        print(f"  {checked} once-only persisted write(s) examined, "
              "each the last statement in its pcall.")
        return 0
    return 1


if __name__ == "__main__":
    sys.exit(main())
