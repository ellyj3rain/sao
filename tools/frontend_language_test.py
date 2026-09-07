#!/usr/bin/env python3
r"""Border 91 - the front end speaks player (DR-017).

The operator, on the sandbox surface: why should a user have to know
that five means forty-eight-to-seventy-two hours, or that zero means
default? That is engine language, not front-end language - the
principle is representationality.

The class: a player-facing label or description that requires the
internal representation to read. Its forms, each of which this
surface carried: the mode-sentinel ("0 = size it from the map",
"0 = follow world population"), the coded scale ("0 = none, 5 = an
exodus", "1 quiet - 12 constant"), the state-decode ("on = one
county, one voice"), and the apology that proves the encoding leaked
("Zero does NOT mean...", "Zero derives from..."). [C12] re-cut the
surface: a mode is a worded switch, a coded scale is worded values
(the engine's own enum options render them), a genuine quantity keeps
its number in plain units, and the one translation from word to
internal sentinel happens in the policy reader alone.

WHAT THIS HOLDS
---------------
  1. No label or tooltip on the county's sandbox page carries a
     number-equals-meaning decode or a boolean-state decode.
  2. No tooltip apologizes for a sentinel ("zero does not mean",
     "zero derives", "at zero it follows/sizes").
  3. Every enum option declares all its worded values, and none of
     the words is a number in disguise.
  4. The mode switches exist (PopulationGoverned, NewcomersGoverned),
     their numbers have no sentinel floor (min >= 1), and the policy
     reader is the ONE place the worded surface becomes the internal
     sentinel.

An optional argv[1] points the checker at another tree root, which is
how the control runs against the pre-[C12] tree.
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
OPTS = ROOT / "mod" / "42.20" / "media" / "sandbox-options.txt"
TRANS = (ROOT / "mod" / "42.20" / "media" / "lua" / "shared"
         / "Translate" / "EN" / "Sandbox.json")
POP = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Population.lua"

DECODE = re.compile(r"\b\d+(?:\.\d+)?\s*=\s*[A-Za-z]")
STATE_DECODE = re.compile(r"\b(?:on|off|true|false)\s*=\s*[A-Za-z]",
                          re.IGNORECASE)
APOLOGY = re.compile(
    r"(?:zero|0)\s+(?:does\s+not\s+mean|does\s+NOT\s+mean|derives|means)"
    r"|at\s+zero\s+(?:it|the\s+county)\s+(?:follows|sizes)",
    re.IGNORECASE)


def main():
    faults = []
    print("=" * 74)
    print("THE FRONT END SPEAKS PLAYER")
    print("=" * 74)

    try:
        opts = OPTS.read_text(encoding="utf-8", errors="ignore")
        trans = json.loads(TRANS.read_text(encoding="utf-8",
                                           errors="ignore"))
        pop = POP.read_text(encoding="utf-8", errors="ignore")
    except (OSError, ValueError) as e:
        print()
        print("VERDICT:")
        print(f"  FAULT: the surface cannot be read at all ({e})")
        return 1

    ours = {k: v for k, v in trans.items()
            if k.startswith("Sandbox_SurvivorAwareness")}
    if not ours:
        faults.append("no county sandbox translations were read - this "
                      "verdict would be about an empty set")

    # 1 + 2. The banned phrasings, over every label and tooltip.
    for key, value in sorted(ours.items()):
        text = str(value)
        if DECODE.search(text):
            faults.append(f"{key} carries a number-equals-meaning decode "
                          f"({DECODE.search(text).group(0)!r}) - engine "
                          "language on the player's screen")
        if STATE_DECODE.search(text):
            faults.append(f"{key} decodes a switch state in prose "
                          f"({STATE_DECODE.search(text).group(0)!r}) - "
                          "the switch's own words should carry it")
        if APOLOGY.search(text):
            faults.append(f"{key} apologizes for a sentinel "
                          f"({APOLOGY.search(text).group(0)!r}) - the "
                          "apology is the proof the encoding leaked")

    # 3. Enums carry all their worded values.
    for m in re.finditer(
            r"option\s+SurvivorAwareness\.(\w+)\s*\{(.*?)\}", opts, re.S):
        name, body = m.group(1), m.group(2)
        em = re.search(r"type\s*=\s*enum.*?numValues\s*=\s*(\d+)",
                       body, re.S)
        if not em:
            continue
        for i in range(1, int(em.group(1)) + 1):
            key = f"Sandbox_SurvivorAwareness_{name}_option{i}"
            word = ours.get(key)
            if not word:
                faults.append(f"enum {name} has no worded value {i} - the "
                              "player reads a bare number")
            elif re.search(r"\d", str(word)):
                faults.append(f"{key} ({word!r}) is a number in disguise")

    # 4. The mode switches and the one translation site.
    for switch, number in (("PopulationGoverned", "Population"),
                           ("NewcomersGoverned", "Newcomers")):
        if f"SurvivorAwareness.{switch}" not in opts:
            faults.append(f"the {switch} switch is gone - the number "
                          "below it needs a sentinel again")
        nm = re.search(r"option\s+SurvivorAwareness\." + number
                       + r"\s*\{(.*?)\}", opts, re.S)
        if nm and re.search(r"min\s*=\s*0", nm.group(1)):
            faults.append(f"{number} reaches down to 0 again - a floor "
                          "that exists only to spell a mode")
    if "PopulationGoverned == true" not in pop \
            or "NewcomersGoverned == true" not in pop:
        faults.append("the policy reader no longer manufactures the "
                      "internal sentinel from the worded switches - "
                      "either the sentinel leaked back to the screen or "
                      "the switches read nothing")
    if "RoadPressureStep" not in pop:
        faults.append("the worded pressure steps never become the road "
                      "scalar - the enum is a dial wired to nothing")

    # [C22] The page may not lie the other way either: a manual number
    # field editable while its switch is off is a dial that will not
    # apply. The gating lives in SAO_Sandbox.lua, on vanilla's own
    # per-frame idiom.
    #
    # [C24] And the gating must be ATTACHABLE. The first cut hung its
    # hook on `SandboxOptionsScreenPanel`, which vanilla declares as a
    # per-file LOCAL - the guard read a nil global and skipped without
    # a word, so a border that only demanded the hook's text passed
    # while the code was dead, and the operator typed 45445 into a
    # locked field on a verified deploy (R-003, F-053). This clause now
    # demands three things: the hook goes through the one class vanilla
    # actually exposes as a global (SandboxOptionsScreen), it gates the
    # page panels those instances own (item.panel), and the
    # cannot-attach path is LOUD (Seams.wentDark) - because the silent
    # skip is the mechanism by which the first hook died.
    sb_path = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Sandbox.lua"
    sb = sb_path.read_text(encoding="utf-8", errors="ignore")         if sb_path.exists() else ""
    if "PopulationGoverned" not in sb or "NewcomersGoverned" not in sb             or "setEditable(false)" not in sb:
        faults.append("the manual number fields are not gated behind "
                      "their switches - a field the player can edit "
                      "before selecting the manual option is a lie on "
                      "the screen (the operator's [C22] correction)")
    if re.search(r"if\s+SandboxOptionsScreenPanel", sb):
        faults.append("the gating hook hangs on SandboxOptionsScreenPanel "
                      "again - vanilla declares that class as a per-file "
                      "LOCAL (SandboxOptions.lua:5), so the guard reads nil "
                      "and the gating silently never exists (F-053, the "
                      "defect the operator photographed)")
    if "SandboxOptionsScreen.create" not in sb or ".panel" not in sb:
        faults.append("the gating does not attach through "
                      "SandboxOptionsScreen:create onto the page panel "
                      "instances - the one path vanilla exposes as a real "
                      "global (F-053)")
    if sb.count("Seams.wentDark") < 2:
        faults.append("the gating hook can fail to attach without saying "
                      "so - the silent skip is exactly how the first hook "
                      "died on the operator's screen (F-053); both the "
                      "missing-global and the no-panel paths must be loud")

    print(f"  county translations read: {len(ours)}")
    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print("  91) the front end speaks player: no decode tables, no sentinel")
    print("      apologies, worded enum values throughout, and the one")
    print("      word-to-sentinel translation lives in the policy reader")
    return 0


if __name__ == "__main__":
    sys.exit(main())
