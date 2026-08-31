#!/usr/bin/env python3
r"""Border 29 - every option governs the whole county.

[B39] found `Desperation` read nine times in the live path and zero
times in the dormant one, so the county's own property law applied
only to whoever happened to be loaded. That was not one defect, it was
an instance - so this counts every option on the screen against both
halves and refuses to let the next one hide.

[B39] is what it found on its first run: the dormant day's reach was
a hardcoded 24 while `ErrandRadius` - *"How far a survivor looks for
food, water, weapons, and ammunition when need sends them
searching"* - governed the live path five times and the dormant path
never.

WHAT IS AND IS NOT A FAULT
--------------------------
Not every option belongs in both halves, and pretending otherwise
would make this noise. An option that is read ONLY in the live path
must be named here with a reason about the code - the way
`invariant_sweep` names its non-news kinds - and an option read in
NEITHER is dead either way.

The reason has to be about what the option means. "A dormant survivor
has no body to speak from" is a reason; "it just is" is not.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
OPTS = ROOT / "mod" / "42.20" / "media" / "sandbox-options.txt"

LIVE = "SAO_Controller.lua"
DORMANT = "SAO_Population.lua"

# An option read in NEITHER SAO_Controller nor SAO_Population is not
# automatically a fault - some are owned by the module they belong to.
# Named here with the file, so "read somewhere else" is a claim that
# can be checked rather than a shrug.
#
# There is deliberately no live-only allowlist. The first draft had
# one for `Voice` and it did nothing: `Voice` is read in SAO_Voice.lua
# and never in the live path either, so the entry described a case the
# rule could not flag. An allowlist whose removal changes nothing is
# the same defect as a control that cannot fail.
OWNED_ELSEWHERE = {
    "Voice": "client/SAO_Voice.lua",
    "Telemetry": "client/SAO_Telemetry.lua",
    # [B45] Not a county property at all - it decides whether another
    # mod's overhead prompts reach the player. Neither half of the
    # simulation has an opinion about it, and forcing it into one would
    # be inventing a reading to satisfy a rule.
    "HoldNeighbourPrompts": "client/SAO_Neighbours.lua",
}


def reads(text, option):
    """Every way this tree spells reading an option."""
    lower = option[0].lower() + option[1:]
    return (text.count(f"sv.{option}")
            + text.count(f"SurvivorAwareness.{option}")
            + text.count(f"conf.{lower}")
            + text.count(f"policy().{lower}"))


def main():
    options = re.findall(r"option SurvivorAwareness\.(\w+)",
                         OPTS.read_text(encoding="utf-8", errors="ignore"))
    files = {p.name: p.read_text(encoding="utf-8", errors="ignore")
             for p in LUA.rglob("*.lua")}
    live, dormant = files.get(LIVE, ""), files.get(DORMANT, "")
    tree = "".join(files.values())

    print("=" * 74)
    print(f"EVERY OPTION, AGAINST BOTH HALVES - {len(options)} on the screen")
    print("=" * 74)
    print(f"  {'option':<20} {'live':>5} {'dormant':>8} {'tree':>6}")

    faults = []
    for o in sorted(options):
        l, d, t = reads(live, o), reads(dormant, o), reads(tree, o)
        note = ""
        if t == 0:
            note = "  <- READ BY NOBODY"
            faults.append(f"{o} is on the screen and read nowhere at all")
        elif l > 0 and d == 0:
            note = "  <- LIVE ONLY"
            faults.append(
                f"{o} governs the live path {l} times and the dormant "
                "path never - the county's own policy applying only to "
                "whoever happens to be loaded")
        elif l == 0 and d == 0:
            owner = OWNED_ELSEWHERE.get(o)
            if owner and owner.split("/")[-1] in files:
                note = f"  (owned by {owner.split('/')[-1]})"
            else:
                note = "  <- UNCLAIMED"
                faults.append(
                    f"{o} is read in neither path and no module claims it")
        print(f"  {o:<20} {l:>5} {d:>8} {t:>6}{note}")

    print()
    for o, where in sorted(OWNED_ELSEWHERE.items()):
        owned = LUA / where
        mark = "yes" if owned.exists() else "NO "
        print(f"  {mark}  {o} is owned by {where}")
        if not owned.exists():
            faults.append(f"{o} claims to be owned by {where}, which "
                          "does not exist")

    # [B41] The dormant social path's tunables, named.
    #
    # A magic number is not wrong the way a live-only option is wrong -
    # it is unreadable. `dx*dx + dy*dy <= 9.0` sat under a docstring
    # saying two survivors meet "within 3 tiles", which is the same
    # shape [B40] found: a comment asserting an invariant the code
    # only happened to satisfy. Squaring a NAMED range makes the two
    # agree by construction.
    #
    # Each must be declared AND used - a constant nobody reads is a
    # comment with a semicolon.
    print()
    print("  TUNABLES IN THE DORMANT SOCIAL PATH")
    tunables = {
        "MEET_RANGE": "how near two drifting days must cross",
        "ENCOUNTER_BUDGET": "outer records swept per pass",
        "MEET_COOLDOWN": "one meeting per pair per this many ticks",
        "ROAD_TRUST": "what a road meeting is worth",
        "WIDE_BERTH": "how far a hostile pair is stepped apart",
    }
    for name, what in tunables.items():
        declared = f"local {name} = " in dormant
        used = len(re.findall(name, dormant)) > 1
        good = declared and used
        print(f"    {'yes' if good else 'NO '}  {name:<18} {what}")
        if not declared:
            faults.append(f"{name} is not declared - the tunable it "
                          "names is a magic number again")
        elif not used:
            faults.append(f"{name} is declared and never read - a "
                          "constant nobody uses is a comment with a "
                          "semicolon")
    # The whole point: the range and its square agree by construction.
    if "MEET_RANGE * MEET_RANGE" not in dormant:
        faults.append("the meeting range is no longer squared from the "
                      "named range, so the docstring's 3 tiles and the "
                      "code's distance can drift apart again")

    # [B39]'s own link, required present rather than assumed.
    links = {
        "the day's reach comes from the option":
            "local function dayReach()" in dormant
            and "tonumber(sv.ErrandRadius)" in dormant,
        "and the hardcoded reach is gone":
            "local reach = 24" not in dormant,
    }
    print()
    for k, v in links.items():
        print(f"  {'yes' if v else 'NO '}  {k}")
        if not v:
            faults.append(k)

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  29) option reach: {len(options)} options, none live-only "
          "without a reason, none read by nobody")
    return 0


if __name__ == "__main__":
    sys.exit(main())
