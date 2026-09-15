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
    # [C36] Not a property of any person: it decides whether the game's
    # own broadcasts and papers are keyed to the calendar, which the
    # server-side record module does once per save and at every
    # container fill. Neither half of the simulation reads it.
    "RecordOnCalendar": "server/SAO_Record.lua",
    # [C40] Not a property of any person either: it decides whether
    # this county runs anything through another survivor mod at all
    # (DR-035). Read by the two modules that would, and by neither
    # half of the simulation.
    "NeighbourBridge": "client/SAO_Absorb.lua",
    # [C104] The eight record dials. None is a property of a person:
    # each decides whether one subsystem's doings are WRITTEN to the
    # county record - the screen's own promise is "off: it still
    # happens, it is just not recorded" - so none belongs to either
    # half's behavior, and each is owned by the seam that gates its
    # recording. Branching, Pressure and Labor gate the graph the
    # Integration pass assembles (the whole record, the pressure sums
    # in it, and the work counted toward trades); Organization,
    # Settlement, Material and Communication gate the Recognition
    # seams that write the org, base, counted-store and message
    # records; PlayerInteraction gates the player-claims module
    # itself.
    "Branching": "shared/SAO_Integration.lua",
    "Pressure": "shared/SAO_Integration.lua",
    "Labor": "shared/SAO_Integration.lua",
    "Organization": "shared/SAO_Recognition.lua",
    "Settlement": "shared/SAO_Recognition.lua",
    "Material": "shared/SAO_Recognition.lua",
    "Communication": "shared/SAO_Recognition.lua",
    "PlayerInteraction": "shared/SAO_PlayerInteraction.lua",
    # [C115] The two dials the screen-revision ruling added whose
    # readers live in their own modules. The openness horizon is read
    # where the pull is computed - Standing's companyPull is the one
    # law of a person's need, served to both halves through the same
    # shared seam - so neither half reads the dial directly and the
    # module that computes the need owns it. The drive's speed cap is
    # read by the driving face at order time, because Java cannot
    # read SandboxVars: the value crosses the bridge with the order.
    "OpennessHorizonMonths": "shared/SAO_Standing.lua",
    "DriveSpeedCap": "client/SAO_Driving.lua",
    # [C119] Not a property of any person: it decides whether this
    # world's government answers the Knox Event at all, and when it
    # does the strike's day, towns and circles are drawn for the
    # WORLD, not per person - so neither half of the simulation has
    # an opinion about it and the nuke module, which owns the draw,
    # the strike and the fallout, owns the dial too.
    "WeekOneNuke": "client/SAO_Nuke.lua",
    # [C121] A smoke break is a body's act - a cigarette in a hand,
    # an animation a witness can see - so the dormant half has no
    # body to read it from. The habit itself is drawn and carried
    # for every person in both halves through the shared SAO_Habits,
    # and the dial governs only the visible act: the needs module,
    # which owns the body's acts, reads it, and the controller asks
    # that seam.
    "RealSmoking": "client/SAO_Needs.lua",
    # [C125] The neuroinflammation graph is owned by SAO_Neuro:
    # both active and dormant passes advance through SAO_Neuro,
    # and SAO_Neuro.isActive() queries the sandbox option.
    "Neuroinflammation": "shared/SAO_Neuro.lua",
}


def reads(text, option):
    """Every way this tree spells reading an option.

    Boundary-counted, not substring-counted: the first draft counted
    `sv.Material` inside `sv.MaterializeRadius` and so held Material
    read while Border 16 - which was boundary-aware - held it dead.
    Two borders disagreeing about the same dial is one of them not
    looking at the code, and it was this one.

    [C104]'s two helper spellings are counted only where the text
    itself binds the helper to this mod's own options table, the same
    control Border 16 now applies: the binding line is what makes a
    `dial("X")` or `options.X` a read of OUR table rather than a name
    match, and deleting it is what stops the calls from counting.
    """
    lower = option[0].lower() + option[1:]

    def count(pattern):
        return len(re.findall(pattern, text))

    n = (count(rf"sv\.{option}\b")
         + count(rf"SurvivorAwareness\.{option}\b")
         + count(rf"conf\.{lower}\b")
         + count(rf"policy\(\)\.{lower}\b"))
    if re.search(r"local function dial\(\w+\).{0,300}?SurvivorAwareness",
                 text, re.S):
        n += count(rf'dial\(\s*"{option}"\s*\)')
    if re.search(r"local options = SandboxVars[^\n]*SurvivorAwareness",
                 text):
        n += count(rf"options\.{option}\b")
    return n


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
    # [C115] ROAD_TRUST graduated out of this table: what a road
    # meeting is worth is the RoadMeetingWorth dial now (the number
    # the operator's own [C111] ruling moved from 0.005 to 0.02, made
    # a dial by the screen-revision ruling of 2026-09-13). It is
    # tracked one block above, read off the dormant file with the
    # ruled figure as its fallback - the named-constant job this
    # table did for it is done by the option half of this border.
    tunables = {
        "MEET_RANGE": "how near two drifting days must cross",
        "ENCOUNTER_BUDGET": "outer records swept per pass",
        "MEET_COOLDOWN": "one meeting per pair per this many ticks",
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

    # [B39]'s link, INVERTED by [C25] (DR-027): the ErrandRadius
    # option is deleted from the screen - how far a person goes is
    # knowledge and desire, never a dial - so the dormant day must
    # reach through the county's derived horizons and the knowledge
    # search, and the dial may not return anywhere in the tree.
    # Prose is not code: the modules that KILLED the dial name it in
    # their comments (as the batch records do), so the absence check
    # reads the tree with comments stripped. Border 99 sweeps the
    # options and translation surfaces raw.
    stripped_tree = "".join(
        "\n".join(line[:line.find("--")] if line.find("--") >= 0
                  else line for line in body.split("\n"))
        for body in files.values())
    links = {
        "the day's reach derives from the county's horizons":
            "comfortHorizon()" in dormant,
        "need cuts ahead of curiosity through the knowledge search":
            "nearestOffering" in dormant,
        "the errand dial is gone from the whole tree":
            "ErrandRadius" not in stripped_tree,
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
