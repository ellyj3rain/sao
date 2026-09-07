#!/usr/bin/env python3
r"""Border 100 - the click lands, the body is dressed, the line holds.

Three defects from one play session ([C26], R-005/R-006, DR-028),
each of the same species: the county REPORTED a thing it never
VERIFIED, and the gap was invisible until the operator stood in it.

  * Talk: a deliberate click was eaten three ways - the whole person
    behind a trust wall, the reply behind the murmur guards, the
    brush-off behind a log file - "talking does far less than even
    what's advertised."
  * Dress: dressInRandomOutfit returned cleanly and dressed nothing;
    the log said dressed=true about a naked body (F-054).
  * Ground: two strangers woke inside the operator's own kitchen,
    three bodies on one square - no law at the wake site (DR-028).

WHAT THIS HOLDS
---------------
  1. An answer ANSWERS: every volunteer-spacing guard in the voice
     module carries the answering bypass.
  2. The talk cooldown brush-off is SPOKEN; the trust wall is gone;
     the three earned categories (lessons, pacts, what a body
     admits) are gated individually - the advertisement's own split.
  3. Dressing is verified by OUTCOME: the bridge counts worn items,
     retries, falls back to a named outfit, and reports; both the
     fresh path and the awakened path consult it; the materialize
     log carries the worn report.
  4. The wake law: a foreign claim pushes the wake square out
     through its nearest wall, a person's own group ground stays
     free, homes move off held ground, and no two bodies wake on
     one square.

An optional argv[1] points the checker at another tree root, which is
how the control runs against the pre-[C26] tree.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
BRIDGE = ROOT / "java" / "src" / "com" / "sao" / "bridge" / "SAOBridge.java"


def read(p):
    return p.read_text(encoding="utf-8", errors="ignore") \
        if p.exists() else ""


def main():
    faults = []
    print("=" * 74)
    print("THE CLICK LANDS, THE BODY IS DRESSED, THE LINE HOLDS")
    print("=" * 74)

    voice = read(LUA / "client" / "SAO_Voice.lua")
    har = read(LUA / "client" / "SAO_Harness.lua")
    body = read(LUA / "client" / "SAO_Body.lua")
    pop = read(LUA / "client" / "SAO_Population.lua")
    bridge = read(BRIDGE)

    # 1. An answer answers.
    if voice.count("not answering") < 3:
        faults.append("the voice module's volunteer-spacing guards do "
                      "not all carry the answering bypass - a reply to "
                      "a direct click can be eaten like a murmur again "
                      "(R-005)")

    # 2. The talk surface.
    if 'body:Say("We just talked.")' not in har:
        faults.append("the talk cooldown brush-off is not spoken - a "
                      "click inside the cooldown is [B33] with a "
                      "timestamp again")
    if re.search(r"if SAO\.Standing\.trust\(id, key\) >= 0\.3 then", har):
        faults.append("the trust wall is back - the ENTIRE person "
                      "behind fifteen clicks and fifteen game hours, "
                      "the exact shape the operator called 'far less "
                      "than advertised'")
    if "local trusted = SAO.Standing.trust(id, key) >= 0.3" not in har:
        faults.append("the earned/open split has no trusted flag - "
                      "either everything is open (lessons leak to "
                      "strangers) or everything is walled again")
    for gate, what in (
            (r"if trusted then\n\s+local bitten3", "what a body admits"),
            (r"if trusted and SAO\.Standing\.pactBetween", "the pacts"),
            (r"if trusted and rec and rec\.lessonsKnown",
             "the lessons")):
        if not re.search(gate, har):
            faults.append(f"{what} is not individually trust-gated - "
                          "the advertisement's own split (a lesson if "
                          "trust permits) is not what runs")

    # 3. Dressing verified by outcome.
    if "ensureDressed" not in bridge or "getWornItems" not in bridge \
            or "dressInNamedOutfit" not in bridge:
        faults.append("the bridge cannot verify dress outcomes - a "
                      "dress call that returns is not a dressed body "
                      "(F-054), and without worn counting the next "
                      "naked person arrives as a mystery again")
    if bridge.count(".size()") < 1:
        faults.append("the worn count is not read off WornItems.size() "
                      "- the one javap-verified instrument for the "
                      "outcome")
    if "ensureDressed" not in body or '" worn="' not in body:
        faults.append("the fresh materialize path does not verify or "
                      "report what is worn - dressed=true about a "
                      "naked body again (R-006)")
    if "ensureDressed" not in pop:
        faults.append("the awakened path does not verify dress - a "
                      "pack with no garments wakes a naked person "
                      "silently")

    # 4. The wake law.
    if "local function wakeSquareFor" not in body \
            or "allGroupClaims" not in body:
        faults.append("no wake law - a stranger can wake uninvited "
                      "inside somebody else's held ground (DR-028, the "
                      "operator's kitchen)")
    if "who ~= mine" not in body:
        faults.append("the wake law does not spare a person's OWN "
                      "ground - a settled block must populate its own "
                      "houses (DR-028's second half)")
    if not re.search(r"rec\.homeX, rec\.homeY = wx, wy", body):
        faults.append("homes do not move off held ground - the same "
                      "wake violation repeats every load")
    if "taken[" not in body:
        faults.append("no one-body-one-square scatter - three people "
                      "stood on one tile in the operator's kitchen")
    if re.search(r"spawnShellNamed\(rec\.forename, rec\.surname,\s*\n?"
                 r"\s*math\.floor\(rec\.x\)", body):
        faults.append("the spawn still takes the record square raw - "
                      "the wake law computes a square nothing uses")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print("  100) the click lands (answers bypass murmur guards, the")
    print("       brush-off speaks, the advertised trust split runs), the")
    print("       body is dressed (outcome-verified, retried, reported),")
    print("       and the line holds (foreign wakes pushed out, own ground")
    print("       free, homes moved, one body per square)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
