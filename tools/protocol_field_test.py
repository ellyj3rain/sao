#!/usr/bin/env python3
r"""Border 70 - somebody else's text in our protocol.

Everything the Java side tells Lua, it tells as a delimited string. The
perception frame is `'|'`-separated and `':'`-fielded; the vehicle
appraisal is `','`-separated and `'@'`-fielded; the world census is
`'|'`-separated and `'='`-fielded.

Most of the values in those strings are ours - numbers we computed,
kinds we named. Some are not:

  * a profession's namespace and path come from whatever mod
    registered it
  * a vehicle's script name comes from whatever mod added it
  * a survivor's forename and surname come from the engine's own
    name lists, which mods extend

[B50] found `SAOBridge.listProfessions()` packing a profession's
namespace and path with neither sanitised. A single `'|'` in a modded
profession path would split one entry into two; the Lua half reads
each with `string.match(entry, "^([^:]+):(.+)$")`, so the fragment
without a colon returns nil and is silently skipped - leaving a
phantom trade in the census and a real one missing, with nothing said.

The operator runs two hundred and thirty-four mods. This is not a
hypothetical about hostile input; it is a question of whether anybody
has ever put a punctuation mark in a name.

WHAT THIS CHECKS
----------------
Each builder is declared with the delimiters its own protocol uses,
and its method body must strip every one of them from the values it
packs. Not a global rule about which characters are dangerous -
`':'` is a delimiter in the perception frame and ordinary text in the
census's `key=value` rows, and a border that insisted on one answer
would be wrong in half the tree.

A builder that is not declared is a fault, and a declaration for a
builder that has gone is a fault, so the list describes the protocol
this mod actually speaks.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
JAVA = ROOT / "java" / "src" / "com" / "sao"

# Where a delimited string is built, and the delimiters that protocol
# uses. Every one must be stripped from the values packed into it.
BUILDERS = {
    ("SAOBridge.java", "listProfessions"): (
        "|:",
        "profession namespaces and paths, straight out of another "
        "mod's registration"),
    ("SAOPerceptionScanner.java", "appendIfVisible"): (
        "|:",
        "the name of every person and Knox inhabitant in view"),
    ("SAONeeds.java", "appraiseVehiclesNear"): (
        ",@",
        "a vehicle's script name, straight out of whatever mod added "
        "it"),
    ("SAOWorldCensus.java", "surveyItems"): (
        "|=",
        "item category names from the loaded world's own registry"),
    ("SAOHibernation.java", "hibernate"): (
        ";,*@=",
        "the full type of every item a hibernating survivor carries, "
        "straight out of whatever mod added it - and this one is "
        "written to the SAVE, so a corrupted row is somebody's "
        "inventory gone rather than a bad frame the next tick replaces"),
    ("SAONeeds.java", "findNamedCorpsesNear"): (
        "|:",
        "the forename and surname of the county's dead"),
}

METHOD = re.compile(r"^\s{4}(?:public|private|protected|static).*?"
                    r"\b(\w+)\s*\(", re.M)


def method_body(src, name):
    """The text of one method, by brace balance."""
    for m in METHOD.finditer(src):
        if m.group(1) != name:
            continue
        start = src.find("{", m.end())
        if start < 0:
            continue
        depth, i = 0, start
        while i < len(src):
            if src[i] == "{":
                depth += 1
            elif src[i] == "}":
                depth -= 1
                if depth == 0:
                    return src[start:i]
            i += 1
    return None


def strips(body, ch):
    """Does this body remove `ch` from something?"""
    esc = re.escape(ch)
    return bool(re.search(r"replace\(\s*['\"]" + esc + r"['\"]", body))


def main():
    faults = []
    print("=" * 74)
    print("SOMEBODY ELSE'S TEXT IN OUR PROTOCOL")
    print("=" * 74)

    if not JAVA.exists():
        print()
        print("VERDICT:")
        print("  FAULT: the Java source is gone, so no protocol was read")
        return 1

    srcs = {p.name: p.read_text(encoding="utf-8", errors="ignore")
            for p in JAVA.rglob("*.java")}
    print(f"  Java files read : {len(srcs)}")
    print(f"  builders declared: {len(BUILDERS)}")

    for (fname, method), (delims, what) in sorted(BUILDERS.items()):
        src = srcs.get(fname)
        if src is None:
            faults.append(
                f"{fname} is declared as building a protocol and no such "
                "file exists - the entry describes no code")
            continue
        body = method_body(src, method)
        if body is None:
            faults.append(
                f"{fname} no longer has a `{method}` - either it was "
                "renamed, in which case this list is stale, or the "
                "protocol it built is gone")
            continue

        # A builder may sanitise inline or through a helper it calls;
        # follow one hop, because that is how every one of these is
        # actually written.
        reach = body
        for helper in re.findall(r"(\w+)\s*\(", body):
            hb = method_body(src, helper)
            if hb:
                reach += hb

        missing = [c for c in delims if not strips(reach, c)]
        print(f"     {fname}:{method}  delimiters {delims!r}  "
              f"{'ok' if not missing else 'MISSING ' + repr(''.join(missing))}")
        if missing:
            faults.append(
                f"{fname}:{method} packs {what}, and its protocol is "
                f"delimited by {delims!r} - but nothing strips "
                f"{''.join(missing)!r} from what it packs. One of those "
                "characters in a value splits a record in half, and the "
                "Lua half skips the fragment it cannot parse: a phantom "
                "entry appears, a real one goes missing, and nothing is "
                "said either way")

    declared = {(f, m) for f, m in BUILDERS}
    for fname, src in sorted(srcs.items()):
        for m in re.finditer(r"append\(\s*['\"][|,@=]['\"]\s*\)", src):
            line = src.count("\n", 0, m.start()) + 1
            owner = None
            for (f, meth) in declared:
                if f != fname:
                    continue
                body = method_body(src, meth)
                if body and src[m.start():m.start() + 20] in body:
                    owner = meth
                    break
            if owner is None:
                faults.append(
                    f"{fname}:{line} appends a delimiter and belongs to no "
                    "declared builder. Any string packed beside it needs "
                    "that delimiter stripped, and nothing here says which "
                    "delimiters this protocol uses or what it packs")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  70) protocol fields: all {len(BUILDERS)} delimited builders "
          "strip their own delimiters from the foreign text they pack")
    return 0


if __name__ == "__main__":
    sys.exit(main())
