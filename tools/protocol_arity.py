#!/usr/bin/env python3
r"""Border 15 ([B31]) - a wire format that grew on one side only.

The mod passes several ad-hoc delimited protocols across the Lua/Java
boundary. Java builds a string; Lua tears it apart with a pattern. Add
a field to the producer and forget the parser, and the pattern simply
stops matching: the Lua takes its `if not x then return nil end`
branch, the feature goes quiet, and nothing is raised anywhere.

That is [B24]'s shape. [B31] checked `appraiseVehiclesNear`'s ten
fields against its ten capture groups by hand, and [B31] checked the
vehicle name by hand. Hand-checking does not scale, and it is exactly
the kind of thing that stops happening on a tired evening.

## Why this needs three hops rather than one

The producer and consumer do NOT share a name. Lua calls
`SAOJavaBridge:findFoodSource`; the bridge forwards to
`SAONeeds.findFoodSourceNear`. A border matching on names alone would
pair nothing and report a clean sweep - which is worse than useless,
because it would look like evidence.

So: the bridge is read first to map its public verb to the engine
method behind it, then the engine method's delimiter count gives the
producer arity, then the Lua function that CALLS that verb is searched
for the pattern it parses the answer with.

## What it deliberately does not do

A producer with no statically pairable parser is REPORTED, not failed.
Some answers are parsed far from the call site, some rows are
variable-length, and guessing an arity to force a comparison would
manufacture false findings. [B31] settled that a noisy border is worse
than a missing one, so unpaired producers are printed as unchecked and
the check passes.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LABEL = "15) delimited protocols whose ends disagree:"

# Verbs whose Lua end deliberately reads only a prefix, and what the
# unread tail is. Empty as of [B52], which read `scoutBase`'s last
# four fields rather than declare them - they were the score that
# chose the building, and a county that cannot say why it settled
# somewhere is not the county this mod claims to build.
PREFIX_OK = {}
DELIMS = (":", "@", "|")

# [B31] Comma is EXCLUDED, and said so out loud rather than left to a
# tuple nobody reads. It is a record separator in appraiseVehiclesNear
# and it appears inside human-readable strings, so pairing on it would
# produce false matches. Producers that use only comma are enumerated
# below and printed as excluded, because a producer this border cannot
# see must not be one it silently omits.
EXCLUDED_DELIM = ","


def brace_body(src, start):
    depth, i = 1, start
    while i < len(src) and depth:
        if src[i] == "{":
            depth += 1
        elif src[i] == "}":
            depth -= 1
        i += 1
    return src[start:i]


def bridge_map():
    """public bridge verb -> engine method name."""
    out = {}
    path = ROOT / "java/src/com/sao/bridge/SAOBridge.java"
    if not path.is_file():
        return out
    src = path.read_text(encoding="utf-8", errors="ignore")
    for m in re.finditer(r"public String (\w+)\([^)]*\)\s*\{", src):
        body = brace_body(src, m.end())
        # [B31] Any engine class. Restricting this to SAONeeds
        # made three producers invisible rather than unchecked.
        call = re.search(r"\bSAO[A-Za-z]*\.(\w+)\(", body)
        if call:
            out[m.group(1)] = call.group(1)
    return out


def producer_arity():
    """engine method -> (delimiter, field count) for the widest one."""
    out = {}
    for path in sorted((ROOT / "java/src").rglob("*.java")):
        src = path.read_text(encoding="utf-8", errors="ignore")
        for m in re.finditer(r"public static String (\w+)\([^)]*\)\s*\{", src):
            body = brace_body(src, m.end())
            counts = {}
            for d in DELIMS:
                n = len(re.findall(r'\.append\("' + re.escape(d) + r'"\)', body))
                n += len(re.findall(r'\+\s*"' + re.escape(d) + r'"\s*\+', body))
                if n:
                    counts[d] = n
            if counts:
                best = max(counts, key=lambda k: counts[k])
                out[m.group(1)] = (best, counts[best] + 1)
    return out


def comma_only_producers():
    """Producers built from commas alone - excluded, but not hidden."""
    out = {}
    for path in sorted((ROOT / "java/src").rglob("*.java")):
        src = path.read_text(encoding="utf-8", errors="ignore")
        for m in re.finditer(r"public static String (\w+)\([^)]*\)\s*\{",
                             src):
            body = brace_body(src, m.end())
            if any(re.search(r'\.append\("' + re.escape(d) + r'"\)', body)
                   or re.search(r'\+\s*"' + re.escape(d) + r'"\s*\+', body)
                   for d in DELIMS):
                continue
            n = len(re.findall(
                r'\+\s*"' + re.escape(EXCLUDED_DELIM) + r'"\s*\+', body))
            n += len(re.findall(
                r'\.append\("' + re.escape(EXCLUDED_DELIM) + r'"\)', body))
            if n:
                out[m.group(1)] = n + 1
    return out


def lua_functions():
    """(file, name, body) for every Lua function."""
    out = []
    for path in sorted((ROOT / "mod/42.20/media/lua").rglob("*.lua")):
        src = path.read_text(encoding="utf-8", errors="ignore")
        starts = [(m.start(), m.group(0))
                  for m in re.finditer(r"^\s*(local )?function [\w.:]+", src,
                                       re.M)]
        for i, (pos, head) in enumerate(starts):
            end = starts[i + 1][0] if i + 1 < len(starts) else len(src)
            out.append((path.name, head.strip(), src[pos:end]))
    return out


def balanced_arg(src, start):
    """Text from `start` to the paren that closes the call."""
    depth, i = 1, start
    while i < len(src) and depth:
        if src[i] == "(":
            depth += 1
        elif src[i] == ")":
            depth -= 1
            if depth == 0:
                return src[start:i]
        i += 1
    return None


def capture_groups(pattern):
    """Lua capture groups: unescaped ( not preceded by %."""
    n, i = 0, 0
    while i < len(pattern):
        c = pattern[i]
        if c == "%":
            i += 2
            continue
        if c == "(":
            n += 1
        i += 1
    return n


def main():
    verbs = bridge_map()
    produced = producer_arity()
    if not verbs or not produced:
        print(LABEL, "SKIPPED (java sources not readable)")
        return 0

    checked, unpaired, bad = [], [], []
    accounted = set()
    for verb, engine in sorted(verbs.items()):
        if engine not in produced:
            continue
        delim, fields = produced[engine]
        found = None
        for fname, head, body in lua_functions():
            call = body.find("SAOJavaBridge:" + verb)
            if call < 0:
                continue
            # [B31] The parse NEAREST the call, and never one before
            # it. These are written immediately after the bridge call
            # because that is where the answer is; taking the first
            # match in the function grabbed an unrelated pattern from
            # further down a very large one.
            best_at = None
            for mm in re.finditer(r"match\(", body):
                if mm.start() < call:
                    continue
                arg = balanced_arg(body, mm.end())
                if arg is None:
                    continue
                pat = "".join(re.findall(r'"([^"]*)"', arg))
                if not pat or delim not in pat:
                    continue
                if best_at is None or mm.start() < best_at:
                    best_at = mm.start()
                    found = (fname, head, capture_groups(pat),
                             pat.rstrip().endswith("$"))
            if found:
                break
        if not found:
            unpaired.append(f"{verb} -> {engine} ({fields} fields, "
                            f"'{delim}') - no field parse found")
            accounted.add(engine)
            continue
        fname, head, groups, anchored = found
        accounted.add(engine)
        # [B31] An UNANCHORED pattern is allowed to read a prefix -
        # arity-equality alone would call correct code a defect. It was
        # `scout` that showed this, emitting ten fields to a parser
        # that took the first six and ended on a bare delimiter with no
        # '$'. [B52] made that parser read all ten, so the example is
        # history rather than a live case; the allowance stays, and
        # [B52] added the requirement that a prefix be DECLARED.
        if anchored:
            ok = groups == fields
            how = "must equal"
        else:
            ok = groups <= fields
            how = "must not exceed"
        checked.append((verb, engine, delim, fields, fname, groups,
                        anchored))
        if not ok:
            bad.append(f"{verb} -> {engine}: java writes {fields} "
                       f"'{delim}'-separated fields, {fname} parses "
                       f"{groups} capture groups ({how}"
                       f"{', pattern is anchored' if anchored else ''})")

    # [B52] A prefix pairing is CORRECT code and was reported as
    # information for nine batches: `scoutBase: prefix 6/10`. What it
    # means is that Java computes four fields, sends them across the
    # bridge, and nothing reads them - and in that case the four were
    # `rooms:area:water:score`, the reasoning that chose one building
    # over every other the scout could see. Not spare data. The whole
    # claim of this framework is that a decision follows from facts,
    # and a decision whose reasons are computed and thrown away is
    # indistinguishable from one that was scripted.
    #
    # So a prefix now has to be declared. Reading a prefix is still
    # allowed - it is sometimes right - but somebody has to say what
    # the unread tail is and why nobody wants it.
    for verb, engine, delim, fields, fname, groups, anchored in checked:
        if anchored or groups == fields or verb in PREFIX_OK:
            continue
        bad.append(
            f"{verb} -> {engine}: java writes {fields} '{delim}'-separated "
            f"fields and {fname} reads the first {groups}. The other "
            f"{fields - groups} are computed, sent, and dropped - either "
            "read them, stop building them, or declare in PREFIX_OK what "
            "the tail is and why nobody wants it")

    # [B31] A producer the enumerator can SEE but that lands in no
    # bucket is the hole this batch exists to close: it would read as
    # coverage rather than as a gap. Failing on it is what makes "0
    # unchecked" mean complete.
    missing = sorted(set(produced) - accounted)
    if bad or missing:
        print(LABEL)
        for line in bad:
            print("     " + line)
        for name in missing:
            d, n = produced[name]
            print(f"     {name} builds {n} '{d}'-separated fields and is "
                  "reachable from no bridge verb - unaccounted for")
        return 1

    print(LABEL, f"none ({len(checked)} paired, {len(unpaired)} unchecked)")
    for verb, engine, delim, fields, fname, groups, anchored in checked:
        shape = "exact" if anchored else f"prefix {groups}/{fields}"
        print(f"       {verb}: {shape}")
    for line in unpaired:
        print(f"       unchecked: {line}")
    for name, n in sorted(comma_only_producers().items()):
        print(f"       excluded: {name} builds {n} ','-separated fields "
              "- ',' is a record separator and appears in prose")
    return 0


if __name__ == "__main__":
    sys.exit(main())
