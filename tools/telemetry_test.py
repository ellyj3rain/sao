#!/usr/bin/env python3
r"""Border 26 - the instrument must not perturb what it measures.

[B38]. The operator's direction: start measuring - what people
learn is data.

Nothing was missing from the record - `lessonMeta[key]` has carried
`{src, of, atHours}` per person per lesson since [A17]. The gap was
that the collected thing never left the process.

An instrument earns its place by being unable to change the reading.
So the invariants here are not about what is measured; they are about
the measuring being inert:

  1. **It writes to nothing.** No assignment to any survivor record,
     belief, claim or standing anywhere in the module. A telemetry
     module that mutates a record is a gameplay feature wearing a
     lab coat.
  2. **It cannot throw into the simulation.** Every call from the mod
     into telemetry is existence-checked AND wrapped in pcall, so a
     broken instrument stops measuring rather than stopping the
     county.
  3. **It hooks the funnel, not a call site.** Deaths are emitted from
     `Identity.markDead`, which every death path goes through - four
     call sites across three files - rather than from the dormant roll
     that prompted it.
  4. **Its output is machine-readable.** The encoder is driven here
     against Python's own JSON parser, including the strings that
     break naive escaping.
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
TEL = LUA / "client" / "SAO_Telemetry.lua"


def esc(s):
    """Mirror of the shipped `esc`, in the shipped order."""
    s = str(s)
    s = s.replace("\\", "\\\\")
    s = s.replace('"', '\\"')
    s = s.replace("\n", " ")
    return s


def encode(fields):
    """Mirror of the shipped `encode`."""
    parts = []
    for k in sorted(fields):
        v = fields[k]
        if isinstance(v, bool):
            out = "true" if v else "false"
        elif isinstance(v, (int, float)):
            out = f"{int(v)}" if float(v) == int(v) else f"{v:.4f}"
        else:
            out = '"' + esc(v) + '"'
        parts.append('"' + esc(k) + '":' + out)
    return "{" + ",".join(parts) + "}"


def main():
    src = TEL.read_text(encoding="utf-8", errors="ignore")
    ok, faults = {}, []

    print("=" * 70)
    print("THE INSTRUMENT DOES NOT PERTURB")
    print("=" * 70)

    # 1. Writes to nothing. Assignments to its OWN table are fine -
    # buffers and the enabled flag - so this looks for writes into the
    # simulation's own structures.
    writes = re.findall(
        r"^\s*(rec|other|b|belief|claim)\.\w+\s*=(?!=)", src, re.M)
    ok["writes to no record"] = not writes
    print(f"  writes into a survivor record : "
          f"{len(writes)} {'(none)' if not writes else writes[:3]}")

    mutators = [m for m in ("markDead", "adjustTrust", "learn(", "bond(",
                            "claim(", "setVisible")
                if m in src]
    ok["calls nothing that changes the world"] = not mutators
    print(f"  calls that would change the world: "
          f"{mutators or 'none'}")

    # 2. Cannot throw into the simulation.
    print()
    calls = []
    for f in sorted(LUA.rglob("*.lua")):
        if f.name == "SAO_Telemetry.lua":
            continue
        txt = f.read_text(encoding="utf-8", errors="ignore")
        for m in re.finditer(r"SAO\.Telemetry\.(\w+)", txt):
            line_start = txt.rfind("\n", 0, m.start()) + 1
            window = txt[max(0, line_start - 220):m.end() + 40]
            calls.append((f.name, m.group(1), "pcall" in window))
    guarded = [c for c in calls if c[2]]
    # Two references per site by design - the existence check and the
    # pcall - so this counts REFERENCES, and says so.
    print(f"  references into telemetry: {len(calls)}, "
          f"pcall-guarded: {len(guarded)}")
    for name, fn, g in calls:
        print(f"    {'yes' if g else 'NO '}  {name} -> {fn}")
    ok["every call is guarded"] = len(calls) > 0 and len(guarded) == len(calls)

    # 3. Hooks the funnel.
    ident = (LUA / "shared" / "SAO_Identity.lua").read_text(
        encoding="utf-8", errors="ignore")
    # The GUARD form, not the name. `SAO.Telemetry.died` survives on
    # the pcall line after the branch above it is disabled, so a bare
    # name check passes while nothing is measured.
    ok["death is hooked at the funnel"] = (
        "if SAO.Telemetry and SAO.Telemetry.died then" in ident
        and "pcall(SAO.Telemetry.died," in ident
        and "function Identity.markDead" in ident)
    death_sites = sum(
        f.read_text(encoding="utf-8", errors="ignore").count("markDead")
        for f in LUA.rglob("*.lua"))
    print(f"\n  markDead mentions across the tree: {death_sites} "
          f"(hooked once, at the funnel)")

    ok["learning is hooked where it lands"] = "SAO.Telemetry.learned" in (
        LUA / "shared" / "SAO_Lessons.lua").read_text(
            encoding="utf-8", errors="ignore")

    # 4. The output parses.
    print()
    print("=" * 70)
    print("THE OUTPUT PARSES")
    print("=" * 70)
    cases = [
        {"kind": "learned", "who": "sao-7", "lesson": "trust-carefully",
         "weight": 1.0, "via": "lived", "day": 12, "hours": 288.5},
        {"kind": "died", "who": "sao-9", "cause": 'shot by "someone"',
         "day": 40},
        {"kind": "county", "living": 216, "dead": 3, "perPerson": 1.6667},
        # The strings that break naive escaping.
        {"kind": "learned", "cost": "a name with \\ and \" in it",
         "note": "a line\nbreak", "flag": True},
    ]
    all_parsed = True
    for c in cases:
        line = encode(c)
        try:
            back = json.loads(line)
        except ValueError as e:
            all_parsed = False
            faults.append(f"encoder produced invalid JSON: {e}")
            print(f"  FAIL  {line[:70]}")
            continue
        print(f"  ok    {line[:88]}")
        if "who" in c and back.get("who") != c["who"]:
            all_parsed = False
            faults.append("a value did not survive the round trip")
    ok["the encoder emits valid JSON"] = all_parsed

    ok["numbers stay numbers"] = json.loads(
        encode({"a": 12, "b": 1.5}))["a"] == 12

    # The encoder above is a MIRROR - it runs in Python, so deleting an
    # escape from the shipped Lua cannot make it fail. GOVERNANCE's
    # clause, hit again in the very batch that wrote it: the shipped
    # rule has to be required present. Order matters too - backslash
    # must be escaped before quote, or the quote's own backslash gets
    # doubled.
    shipped_escapes = [
        r'string.gsub(s, "\\", "\\\\")',
        '''string.gsub(s, '"', '\\\\"')''',
        r'string.gsub(s, "\n", " ")',
    ]
    present = [e for e in shipped_escapes if e in src]
    ok["the shipped encoder escapes all three"] = (
        len(present) == len(shipped_escapes))
    print(f"  shipped escapes present: {len(present)}/"
          f"{len(shipped_escapes)}")
    if len(present) == len(shipped_escapes):
        bs = src.index(shipped_escapes[0])
        qt = src.index(shipped_escapes[1])
        ok["and escapes backslash before quote"] = bs < qt
    else:
        ok["and escapes backslash before quote"] = False

    print()
    print("VERDICT:")
    for k, v in ok.items():
        print(f"  {'yes' if v else 'NO '}  {k}")
    for f in faults:
        print(f"  FAULT: {f}")
    good = all(ok.values()) and not faults
    if not good:
        print("  FAULT: the instrument can perturb, throw, or emit "
              "something nothing can read")
        return 1
    print(f"  26) telemetry: inert, {len(calls)} guarded references, "
          "death hooked at the funnel, output parses")
    return 0


if __name__ == "__main__":
    sys.exit(main())
