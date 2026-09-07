#!/usr/bin/env python3
r"""Border 92 - player-facing copy is ratified, not drafted (DR-018).

The operator, on the [C12] copy: "'The road never quickens' - that is
the worst... you do this pretty much every time you're creating copy
or front end... it's a Claude-ism." And the refinement: "It doesn't
have to be boring. You're just bad at making things interesting."

No regex recognizes bad prose, so this border does not try. It holds
the one thing a gate CAN hold: the player-facing copy shipped is
EXACTLY the copy that was ratified. Every label, value, and tooltip
on the sandbox surface is declared here verbatim; a change to any of
them - a new option, a reworded tooltip, a register drifting back -
fails the gate until the new copy is re-declared, which is the
deliberate act of putting it in front of the operator's eyes. The
Ledger's own strings are covered by their SOURCES list below.

An optional argv[1] points the checker at another tree root, which is
how the control runs against the pre-[C13] copy.
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
TRANS = (ROOT / "mod" / "42.20" / "media" / "lua" / "shared"
         / "Translate" / "EN" / "Sandbox.json")
UI = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_UI.lua"

NL = "\\" + "n"
P = "Sandbox_SurvivorAwareness_"

# The ratified copy, verbatim ([C13], DR-018).
RATIFIED = {
    "Sandbox_SurvivorAwareness": "~ Survivor Awareness",
    P + "Enable": "Enable survivors",
    P + "Enable_tooltip":
        "Survivors spawn from the map's spawn towns, persist across "
        "sessions, and act whether or not you are nearby." + NL
        + "Turn off for a world without them.",
    P + "PopulationGoverned": "Set the population manually",
    P + "PopulationGoverned_tooltip":
        "Off: the population is sized automatically from the installed map"
        + NL + "(about 18 per spawn town, roughly 216 on the full map, so "
        "map mods add people automatically)." + NL
        + "On: the number below is used instead.",
    P + "Population": "Population (manual)",
    P + "Population_tooltip":
        "The number of living survivors maintained, used only when manual "
        "population is on." + NL
        + "Only nearby survivors have live bodies; the rest are simulated "
        "at low cost." + NL
        + "An existing world keeps the number it was created with and "
        "refills toward it over time.",
    P + "NewcomersGoverned": "Set the newcomer limit manually",
    P + "NewcomersGoverned_tooltip":
        "Off: the county can grow to three times the population as "
        "newcomers arrive." + NL
        + "On: the limit below is used instead.",
    P + "Newcomers": "Newcomer limit (manual)",
    P + "Newcomers_tooltip":
        "The maximum total population reachable through newcomer "
        "arrivals, used only when the manual limit is on." + NL
        + "Set at or below the population to stop newcomer arrivals "
        "entirely.",
    P + "RoadTraffic": "Newcomer group size",
    P + "RoadTraffic_tooltip":
        "How many people arrive together in a newcomer group. Groups "
        "arrive roughly once a month." + NL
        + "Whether they settle depends on the county's wars, creeds, and "
        "season.",
    P + "RoadPressureStep": "Newcomer arrival speed-up",
    P + "RoadPressureStep_tooltip":
        "How much the wait between newcomer groups shortens as the game "
        "goes on." + NL
        + "At None, arrivals stay about a month apart for the whole game.",
    P + "RoadPressureStep_option1": "None",
    P + "RoadPressureStep_option2": "Very low",
    P + "RoadPressureStep_option3": "Low",
    P + "RoadPressureStep_option4": "Medium",
    P + "RoadPressureStep_option5": "High",
    P + "RoadPressureStep_option6": "Very high",
    P + "MaterializeRadius": "Presence radius (tiles)",
    P + "MaterializeRadius_tooltip":
        "Survivors within this many tiles of you get a live body in the "
        "world." + NL
        + "Survivors farther away are simulated without a body.",
    P + "HibernateRadius": "Hibernate radius (tiles)",
    P + "HibernateRadius_tooltip":
        "Live survivors farther than this many tiles from you return to "
        "simulation at their current position." + NL
        + "Keep it comfortably above the presence radius, or survivors "
        "will appear and disappear repeatedly at the boundary.",
    P + "RefillDays": "Days before replacement after a death",
    P + "RefillDays_tooltip":
        "After a death, the county waits this many in-game days before a "
        "new survivor can spawn at a spawn town" + NL
        + "(never at the death site, never near you). At 0, replacement "
        "is immediate.",
    P + "Desperation": "Desperation threshold",
    P + "Desperation_tooltip":
        "The hunger or thirst level above which survivors take claimed "
        "food and water and ignore objections." + NL
        + "Lower values mean they take sooner; at the maximum they never "
        "take.",
    P + "TrustToCompany": "Trust required for companionship",
    P + "TrustToCompany_tooltip":
        "The mutual trust level required before two survivors travel "
        "together (a trusted third can join)." + NL
        + "Lower values form groups more easily.",
    # [C25] ErrandRadius left the surface entirely (DR-027): how far
    # a person goes is knowledge and desire now, not a dial, so there
    # is no copy to ratify.
    P + "Voice": "Survivors speak",
    P + "Voice_tooltip":
        "Survivors say short lines at meaningful moments: fleeing, "
        "warnings, thanks, grief." + NL
        + "Off: identical behavior, no lines.",
    P + "DayZero": "Day Zero start",
    P + "DayZero_tooltip":
        "The county starts before the outbreak: no fear, no losses, no "
        "learned lessons yet." + NL
        + "Pairs well with low zombie counts and slow turning.",
    P + "Telemetry": "Write telemetry log",
    P + "Telemetry_tooltip":
        "Writes events (lessons learned, deaths, daily summaries) to "
        "SAO_telemetry.jsonl in your Zomboid folder." + NL
        + "Has no effect on gameplay. Turn off if you do not want the "
        "file.",
    P + "DormantRisk": "Off-screen danger multiplier",
    P + "DormantRisk_tooltip":
        "Death risk multiplier for survivors outside the loaded area."
        + NL + "0 disables off-screen deaths. 1 matches the danger near "
        "you. Higher values are deadlier." + NL
        + "Risk is reduced by learned lessons, group membership, and a "
        "hardened past.",
    P + "HoldNeighbourPrompts": "Hold other survivor mods' prompts",
    # [C17] Declared with the operator's eyes on the batch report.
    P + "RestoreTakenZombies": "Restore zombies taken by survivor spawns",
    P + "RestoreTakenZombies_tooltip":
        "Each survivor spawn removes one nearby zombie, so the population "
        "is exchanged rather than added." + NL
        + "On: the county places one replacement zombie on distant town "
        "ground for each one taken, a few per day, never near you." + NL
        + "The map keeps the total it had, moved to where people crowded."
        + NL
        + "Off: taken zombies stay gone. The running balance is kept "
        "either way, so turning this on later repays gradually.",
    P + "HoldNeighbourPrompts_tooltip":
        "Suppresses overhead messages and narration from other survivor "
        "mods." + NL
        + "Held messages are counted on the County Ledger and released "
        "when this is turned off." + NL
        + "The same messages can usually also be disabled in those mods' "
        "own options.",
    # [C36] Ratified by the operator in chat on 2026-09-07, after a first
    # draft was refused for its register.
    P + "RecordOnCalendar": "Date broadcasts and newspapers by the calendar",
    # The words as ratified; the second line is broken at its sentence
    # ends because Border 16 fits 150 characters to a tooltip line.
    P + "RecordOnCalendar_tooltip":
        "The game's radio and TV schedule and its dated newspapers follow "
        "the in-game date instead of counting from the day the world "
        "began." + NL
        + "The Knox Event schedule starts July 9, 1993." + NL
        + "A world that starts earlier receives it from that date; a world "
        "that starts later receives it already in progress." + NL
        + "Newspapers show the newest issue printed by the current date." + NL
        + "Off: the schedule counts from the day the world began and "
        "newspapers are dated at random, as in the unmodded game.",
    # [C40] Ratified unchanged by the operator in chat, 2026-09-07.
    # The tooltip is broken at its sentence ends because
    # Border 16 fits 150 characters to a line; the words are as seen.
    P + "NeighbourBridge": "Take over another survivor mod's people",
    P + "NeighbourBridge_tooltip":
        "Off, this mod runs nothing through another survivor mod. It "
        "still never treats that mod's people as enemies." + NL
        + "On, and if such a mod is installed, its people become this "
        "mod's people." + NL
        + "They get the same memory, temperament and history everyone "
        "here has, and their own menu carries this mod's options." + NL
        + "Turning this on makes this mod call the other mod's code. "
        "Leave it off unless you want the two joined.",
}

# Struck register, held out of the named UI sources by literal match -
# the two examples the operator ruled on, kept as tripwires.
STRUCK = ("never quickens", "between death and the ground")


def main():
    faults = []
    print("=" * 74)
    print("PLAYER-FACING COPY IS RATIFIED, NOT DRAFTED")
    print("=" * 74)

    try:
        shipped = json.loads(TRANS.read_text(encoding="utf-8",
                                             errors="ignore"))
        ui = UI.read_text(encoding="utf-8", errors="ignore")
    except (OSError, ValueError) as e:
        print()
        print("VERDICT:")
        print(f"  FAULT: the copy cannot be read at all ({e})")
        return 1

    for key, want in sorted(RATIFIED.items()):
        got = shipped.get(key)
        if got is None:
            faults.append(f"{key} is missing - ratified copy was removed")
        elif got != want:
            faults.append(f"{key} differs from the ratified copy:\n"
                          f"       shipped:  {got!r}\n"
                          f"       ratified: {want!r}\n"
                          "       (new copy needs the operator's eyes - "
                          "re-declare it here once ratified)")
    for key in sorted(shipped):
        if key not in RATIFIED:
            faults.append(f"{key} shipped without ratification - declare "
                          "its copy here once the operator has seen it")

    for phrase in STRUCK:
        if phrase in ui:
            faults.append(f"the Ledger carries struck register again "
                          f"({phrase!r}) - the exact copy DR-018 removed")

    print(f"  ratified strings held: {len(RATIFIED)}")
    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print("  92) ratified copy: every player-facing string on the sandbox")
    print("      surface matches the declaration verbatim, nothing shipped")
    print("      unratified, and the struck register stays struck")
    return 0


if __name__ == "__main__":
    sys.exit(main())
