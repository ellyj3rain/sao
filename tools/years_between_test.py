#!/usr/bin/env python3
r"""Border 118 - the years between are lived, not invented ([C45], DR-036).

A save beginning in 1996 has three years of county behind it, and the
people the player meets are the people who lived them. The county's own
machinery runs forward over those days before anybody is materialised,
and whoever is alive at the end is who they walk into.

WHAT THIS HOLDS
---------------
  1. EVERY CALL IN A SIMULATED DAY IS THE LIVE COUNTY'S OWN. The years
     pass drives the same dormant day, the same road meetings, the same
     attrition, the same softening, the same age table. If it ever
     grows a call of its own - a settlement placed, a relation set, a
     house named - it has stopped being history and become fiction,
     and that is the failure this border exists for (DR-037's ruling:
     they either manage it or they do not).
  2. It is DAILY, and the number is the measured one (F-055), with the
     frame arithmetic named rather than spelled.
  3. It is SLICED and cannot hang: a budget per pass, and it picks up
     where it stopped.
  4. It runs AFTER genesis and BEFORE the band, and holds the band
     while it works - nobody is materialised into a county that has
     not finished happening.
  5. A 1993 start owes nothing, and an unreadable clock is not read as
     nothing owed.

An optional argv[1] points the checker at another tree root, which is
how its control runs: the pre-batch tree has no pass at all.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
POP = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Population.lua"
RECORD = ROOT / "java" / "src" / "com" / "sao" / "engine" / "SAORecord.java"
BRIDGE = ROOT / "java" / "src" / "com" / "sao" / "bridge" / "SAOBridge.java"
FINDINGS = ROOT / "FINDINGS.md"
CHECK = ROOT / "tools" / "check.sh"

# What one simulated day is allowed to call. Every one of these is a
# function the live county already runs on its own cadence.
ALLOWED_IN_A_DAY = {
    "dormantLife", "dormantEncounters", "dormantAttrition",
    "SAO.Standing.driftStandings", "SAO.Identity.all",
    "SAO.Age.dailyRoll", "SAO.Age.settleHabits",
    # [C46] The one exception, and it is admitted on evidence rather
    # than on assertion. Looking at a claim's ground is new to the
    # years - the live county never needs it, because a person with a
    # body can see where they are standing - so this rule caught it,
    # correctly, on its first run. It is allowed because it OBSERVES
    # and does not act: Border 119 holds that the whole survey path
    # saves no chunk, adds no barricade and places nothing. If that
    # border ever goes, this entry is a hole, and the two are meant to
    # be read together.
    "lookAtSomeGround",
    # [C65] The county line, written once a day. This is not an
    # exception like the one above: `dailyCounty` is run by
    # `populationTick` on the live county's own cadence, and the years
    # call the same function rather than reaching past it. It is here
    # because this list is by name and the name is new.
    #
    # The first draft of [C65] called `SAO.Telemetry.county` from the
    # simulated day directly and this rule refused it, correctly. What
    # it caught was a real gap: [B38] said the county was written once
    # a day and had wired it to `bootDigest`, which runs once per
    # session load.
    "dailyCounty",
}

# Shapes that would mean the pass had started inventing rather than
# running. Not an exhaustive list of every bad call - it is the list of
# the ones that would be tempting.
FORBIDDEN_IN_A_DAY = (
    "joinGroup", "electLeader", "setGroupClaim", "claim(", "bond(",
    "adjustTrust", "markDead", "Identity.create", "History.generate",
    "AddBarricadeToObject", "boardWindow", "addVirtualZombie",
)


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""


def strip_comments(text):
    out = []
    for line in text.split("\n"):
        at = line.find("--")
        out.append(line[:at] if at >= 0 else line)
    return "\n".join(out)


def body_of(text, header, end="\nend\n"):
    at = text.find(header)
    if at < 0:
        return ""
    stop = text.find(end, at + len(header))
    return text[at:stop if stop > 0 else len(text)]


def main():
    faults = []
    print("=" * 74)
    print("THE YEARS BETWEEN ARE LIVED, NOT INVENTED")
    print("=" * 74)

    pop = read(POP)
    day = strip_comments(body_of(pop, "local function oneYearsDay(conf, day)"))
    if not day:
        print("  FAULT: there is no simulated day, so a save beginning years "
              "after the fall meets a county that has not lived them")
        return 1

    # 1. The day calls the live county's own work, and nothing else.
    #
    # Read past the declaration line, or the function matches its own
    # name and reports itself as a stray call - which is what this
    # border did on its first run against correct code. And count the
    # `pcall(name, ...)` form, because three of the four subsystems are
    # handed to pcall as values rather than called with parentheses, so
    # a parenthesis-only scan saw none of them and would have passed a
    # day that drove nothing at all.
    inner = day[day.find("\n") + 1:]
    called = set(re.findall(r"([A-Za-z_][\w.]*)\s*\(", inner))
    called |= set(re.findall(r"pcall\(\s*([A-Za-z_][\w.]*)\s*[,)]", inner))
    called -= {"pcall", "function", "pairs", "ipairs", "tonumber", "tostring", "if"}
    stray = sorted(c for c in called if c not in ALLOWED_IN_A_DAY)
    print("     a simulated day calls: " + ", ".join(sorted(called)))

    # And it must actually drive them: a day that calls nothing is not
    # a day, and every one of these is a thing the live county does to
    # people who have no body.
    for required in ("dormantLife", "dormantEncounters", "dormantAttrition",
                     "SAO.Standing.driftStandings", "SAO.Age.dailyRoll",
                     "SAO.Age.settleHabits"):
        if required not in called:
            faults.append(
                "a simulated day does not drive %s, so that part of the "
                "county simply did not happen for however many years the "
                "save begins with behind it" % required)
    if stray:
        faults.append(
            "a simulated day calls %s, which the live county does not run on "
            "its own cadence. The years are the county's machinery run "
            "forward; a call that only exists here is the pass inventing "
            "history instead of living it" % ", ".join(stray))
    for bad in FORBIDDEN_IN_A_DAY:
        if bad in day:
            faults.append(
                "a simulated day reaches for '%s' directly. Houses, leaders, "
                "bonds, claims and deaths must arrive the way they arrive in "
                "play - out of the meetings and the age table - or the county "
                "the player meets was written rather than lived" % bad)

    checks = {
        # 2. Daily, measured, named.
        "the cadence is named with its frame arithmetic":
            re.search(r"local YEARS_TICKS_PER_DAY = \d+", pop) is not None,
        "a day actually advances that counter":
            "tickCounter = tickCounter + YEARS_TICKS_PER_DAY" in day,
        "and the measurement is on record":
            "F-055" in read(FINDINGS) and "F-055" in pop,

        # 3. Sliced, cannot hang.
        "there is a budget per pass":
            re.search(r"local YEARS_BUDGET_MS = \d+", pop) is not None,
        "the budget is actually read":
            "YEARS_BUDGET_MS" in body_of(pop, "local function runTheYears(conf)"),
        "and progress survives the slice":
            "s.yearsRun = run" in pop,

        # 4. After genesis, before the band, holding it.
        "the county must exist first":
            "genesisSettled()" in body_of(pop, "local function runTheYears(conf)"),
        "the band is held while the years are lived":
            "if livingTheYears then return end" in pop,

        # 5. Nothing owed, versus nothing known.
        "a 1993 start owes nothing":
            "Math.max(0, recordDayOf(" in read(RECORD),
        # [C63] took the day-zero switch as a parameter, so these name
        # the function rather than one spelling of its signature.
        "an unreadable clock is not nothing owed":
            "return -1;" in body_of(read(RECORD),
                                    "public static int daysBehindAtStart(",
                                    "\n    }\n")
            and "days < 0 then" in pop,
        "the bridge asks the record and decides nothing":
            "public int daysBehindAtStart(" in read(BRIDGE)
            and "SAORecord.daysBehindAtStart(" in read(BRIDGE),
        "the gate runs this border":
            "tools/years_between_test.py" in read(CHECK),
    }

    # The ordering law, read off the tick rather than assumed.
    genesis_at = pop.find('runSub("genesis"')
    years_at = pop.find('runSub("years"')
    band_at = pop.find('runSub("band"')
    checks["genesis, then the years, then the band"] = (
        0 <= genesis_at < years_at < band_at)

    print()
    for k, v in checks.items():
        print(f"  {'yes' if v else 'NO '}  {k}")
        if not v:
            faults.append(k)

    print()
    print("VERDICT:")
    if faults:
        for f in dict.fromkeys(faults):
            print("  FAULT: " + f)
        return 1
    print("  118) the years between are lived: every call in a simulated day "
          "is the live county's own, at the measured daily cadence, sliced, "
          "after genesis and before the band")
    return 0


if __name__ == "__main__":
    sys.exit(main())
