#!/usr/bin/env python3
r"""Border 74 - a per-tick walk over a store the save never shrinks.

`SAO.Identity.all()` returns the whole store, and the store keeps the
dead on purpose - *"death is durable: the record stays"*. It is
ModData, so the graveyard grows for the life of a save and across
every session of it. `s.relations` is the same, one dimension worse:
`[id][otherKey]`, and its only removal is a rekey migration.

The measured historical population pass ran every 240 frames - about four
seconds at 60fps - and walked `Identity.all()` eight times. The current
site-by-site census below declares the production walks, including removals.

Measured on the engine, best of two runs at 500 and 1500 repetitions
so the JVM's start-up cancels, one walk with the body those walks
share (reject the dead, reject anyone with a body, then a distance
test):

      records   ms per walk   x8 per pass
          500         0.187         1.50
        2,500         0.242         1.94
        5,500         0.516         4.13
       10,500         1.015         8.12
       30,500         2.616        20.93

About 0.086 ms per thousand records, per walk. At thirty thousand
graves the population pass spends more than a whole 60fps frame just
walking past the dead, every four seconds, and nothing bounds it.

WHY NOT SIMPLY BUDGET ALL EIGHT
-------------------------------
Because they do not all mean the same thing. `materializeBand` must
see everyone near the player NOW; spreading it across passes would
delay a survivor appearing. [B51] budgeted the one whose cost was
measured as a single 220 ms stall - the daily drift over relations -
and left the rest declared rather than surgically rewritten on the
strength of a number nobody had asked for yet.

So this is [B50]'s answer again: what cannot be bounded from here is
DECLARED, site by site, with what limits it - not "this is provably
fine" but "this is what it costs and why it is shaped this way, and a
person can check the reason".

WHAT IS CHECKED
---------------
  * every `runSub` in the population tick names a declared function,
    so a new sub cannot be added without saying what it walks
  * a declared function that has gone is a fault
  * the walk count declared for each function is the count in the
    code, so an added walk is a fault even inside a declared function
  * a function declared BUDGETED must still have a budget and a break
"""
import contextlib
import io
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from lua_read import function_body, strip_lua

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
POP = LUA / "client" / "SAO_Population.lua"
OWNERS = {
    "ensurePopulation": "PopulationAdmissions",
    "inhabitKnox": "PopulationRepresentation",
    "materializeBand": "PopulationRepresentation",
    "dormantLife": "DormantPopulation",
    "dormantAttrition": "DormantPopulation",
    "dormantEncounters": "DormantPopulation",
    "dormantSettle": "DormantPopulation",
    "dormantProvision": "DormantPopulation",
}

# What one walk costs, so the declarations below are about a measured
# thing rather than a worry. Records -> milliseconds, [B51].
COST = ((500, 0.187), (2500, 0.242), (5500, 0.516),
        (10500, 1.015), (30500, 2.616))

# Every function the population tick runs, how many times it walks the
# whole identity store, and what bounds that.
SUBS = {
    "consumeProvisioningResults": (0, "none",
        "[C63] scans at most 32 entries from WorldSources' bounded 2,048-result "
        "ledger and never walks the identity store"),
    "ensurePopulation": (2, "unbudgeted",
        "counts the living against the sandbox cap and places arrivals. "
        "Both walks are once per pass and neither can be sliced without "
        "the cap being computed from half a county"),
    "inhabitKnox": (0, "none",
        "walks no store at all - it asks the bridge what Knox bodies are "
        "near and adopts them"),
    "dormantLife": (1, "unbudgeted",
        "ages needs and moves dormant survivors along their errands. One "
        "walk, whole store, every pass"),
    "dormantAttrition": (2, "unbudgeted",
        "the county's deaths off-screen. Two walks - one to find "
        "candidates, one to resolve them"),
    "dormantEncounters": (2, "budgeted",
        "the outer walk finds up to ENCOUNTER_BUDGET records with a "
        "rotating cursor, and [B51] added the second to build the "
        "living list ONCE rather than walk the store per outer record"),
    "materializeBand": (1, "unbudgeted",
        "builds and tears down bodies around the player. Deliberately "
        "NOT budgeted: it must see everyone near the player now, and "
        "spreading it across passes would delay a survivor appearing "
        "where somebody is standing"),
    "dormantSettle": (0, "none",
        "[C108] the compatibility seam returns zero. Its former whole-store "
        "walk and automatic collective claim/home rewrite were retired; "
        "person-private residence decisions retain their own arrival and "
        "assent owners instead of a scheduler manufacturing settlement"),
    "dormantProvision": (0, "none",
        "[C63] the compatibility seam is a no-op: need dates are not "
        "inventory and cannot overwrite native shelf/water evidence"),
    "dailyCounty": (1, "unbudgeted",
        "[C127] one identity walk per completed county day settles age "
        "and habits before the day's digest. The persisted day guard "
        "prevents a repeat on reload; the whole roster settles before "
        "observation so a newly dead person cannot appear alive in it. "
        "Telemetry's own separate walk remains declared in ELSEWHERE"),
}

# Walks over persisted structures outside the population file, with
# the same declaration.
ELSEWHERE = {
    ("SAO_Standing.lua", "S.driftStandings"): ("budgeted",
        "ages the county's feelings once a game day over `s.relations`, "
        "which is `[id][otherKey]` in the save and whose only removal is "
        "a rekey. [B51] measured the single-shot walk at 5 ms over "
        "fifteen thousand entries and 231 ms over six hundred and "
        "thirty thousand - a quarter-second freeze on one frame - and "
        "spread it over passes at DRIFT_BUDGET rows each, which "
        "measured flat at about 2 ms a pass as the graveyard grew"),
    ("SAO_Telemetry.lua", "T.county"): ("unbudgeted",
        "[C65] writes the county's one line a day and walks the whole "
        "identity store once to count it - living, dead, need, groups, "
        "claims and how shut the places are. Every grave is in that "
        "walk, because the store is what the dead never leave. "
        "Deliberately NOT budgeted, and the two reasons are different "
        "from driftStandings'. It is LINEAR where that one was "
        "quadratic: this border's own cost table puts a single pass at "
        "2.6 ms over thirty thousand records, once per county day, "
        "against 231 ms for the walk [B51] had to slice. And a cursor "
        "would make it wrong rather than slow - a county line assembled "
        "from half a county on one day and half on the next is not a "
        "count of anything, and the whole point of the line is that it "
        "is a snapshot somebody can fit a model to"),
}

RUNSUB = re.compile(r'runSub\(\s*"([^"]+)"\s*,\s*([A-Za-z_][\w.]*)')
ALL_WALK = re.compile(r"in pairs\(\s*(?:SAO\.)?Identity\.all\(\)\s*\)")
# "Budgeted" has to mean the walk is GUARDED by a budget, not that the
# word appears somewhere in the function. [B51]'s control removed one
# use of DRIFT_BUDGET and the first draft of this border stayed green:
# the constant was still named in the tail condition, and
# `function_body` returns real source, so a mention in a COMMENT would
# have satisfied it too. It is read from the stripped body now, and it
# has to be a condition with a break to act on it.
#
# The two budgeted walks are not spelled the same and neither spelling
# is wrong. `driftStandings` tests the constant directly - `rows >=
# DRIFT_BUDGET`. `dormantEncounters` counts a local DOWN from one -
# `local outerBudget = ENCOUNTER_BUDGET` then `outerBudget <= 0`. A
# rule demanding the constant appear in the condition passed the first
# and failed the second, of code that has been correct since [A16].
#
# So: a condition on something named for a budget, a break to act on
# it, and an ALL_CAPS constant somewhere in the body for the number to
# have come from. The last is what keeps `if myBudget then` from
# counting.
GUARD = re.compile(
    r"\b(?:if|elseif|while|until)\b[^\n]*?"
    r"\b\w*(?i:budget)\w*\b[^\n]*?\b(?:then|do)\b")
CONST = re.compile(r"\b[A-Z][A-Z0-9_]*BUDGET\b")
BREAK = re.compile(r"^\s*break\b", re.M)


def budgeted(stripped_body):
    """A budget condition the break actually hangs off.

    Not "a budget somewhere and a break somewhere". [B51]'s control C
    replaced `elseif rows >= DRIFT_BUDGET then break` with `elseif
    false then` and this border stayed green, because the SAME
    constant was still named in the tail condition that decides
    whether the day is finished - a real condition, doing real work,
    and not the one holding the loop back. The break has to be in the
    branch the budget opens.
    """
    if not stripped_body or not CONST.search(stripped_body):
        return False
    for m in GUARD.finditer(stripped_body):
        if BREAK.search(stripped_body[m.end():m.end() + 160]):
            return True
    return False


def check_files(files):
    faults = []
    print("=" * 74)
    print("A PER-TICK WALK OVER A STORE THE SAVE NEVER SHRINKS")
    print("=" * 74)

    if POP.name not in files:
        print()
        print("VERDICT:")
        print("  FAULT: SAO_Population.lua is gone, and with it the tick "
              "this border is about")
        return 1
    src = files[POP.name]
    text = strip_lua(src)

    named = {fn for _, fn in RUNSUB.findall(src)}
    if not named:
        print()
        print("VERDICT:")
        print("  FAULT: no runSub call was found, so this border read no "
              "tick at all - a verdict about an empty set")
        return 1

    total = 0
    for fn in sorted(named):
        if fn == "function":       # the anonymous sub, declared below
            continue
        if fn not in SUBS:
            faults.append(
                f"the population tick runs `{fn}` and nothing declares what "
                "it walks. `Identity.all()` is the whole store including "
                "every grave, and the store is in the save - so a walk "
                "added here costs about 0.086 ms per thousand records, "
                "every pass, forever. Say how many times it walks and what "
                "bounds that")

    for fn, (want, how, what) in sorted(SUBS.items()):
        owner = OWNERS.get(fn)
        owner_src, owner_text = src, text
        if owner:
            path = LUA / "client" / ("SAO_" + owner + ".lua")
            if path.name not in files:
                faults.append(f"{fn}'s declared owner {path.name} is missing")
                continue
            wrapper = function_body(text, fn, text)
            if not wrapper or not re.search(r"SAO\." + owner + r"\." + fn + r"\s*\(", wrapper):
                faults.append(f"{fn}'s scheduler wrapper does not call its declared owner {owner}")
            owner_src = files[path.name]
            owner_text = strip_lua(owner_src)
            alias = {"PopulationAdmissions": "A", "PopulationRepresentation": "R",
                     "DormantPopulation": "D"}[owner]
            if not re.search(r"\b" + alias + r"\." + fn + r"\s*=\s*" + fn + r"\b", owner_text):
                faults.append(f"{owner}.{fn} no longer exports the function whose walk is counted")
        body = function_body(owner_src, fn, owner_text)
        if body is None:
            faults.append(
                f"`{fn}` is declared as a tick sub and its owner "
                "has no such function - either it was renamed, in which "
                "case this list is stale, or the walk it declared is gone")
            continue
        got = len(ALL_WALK.findall(strip_lua(body)))
        total += got
        if got != want:
            faults.append(
                f"`{fn}` walks the whole identity store {got} time(s) and "
                f"is declared as walking it {want}. {what}. Each walk is "
                "linear in every survivor who ever lived, so the count is "
                "the thing that matters and it changed without anybody "
                "saying so")
        elif how == "budgeted" and not budgeted(
                function_body(owner_text, fn, owner_text)):
            faults.append(
                f"`{fn}` is declared BUDGETED and no condition in it tests a "
                "budget constant and breaks. It walks a store nothing "
                "bounds, on a 240-frame cadence")
        print(f"     {fn:<20} walks={got}  {how}")

    for (fname, fn), (how, what) in sorted(ELSEWHERE.items()):
        other = files.get(fname)
        if other is None:
            faults.append(f"{fname} is declared here and does not exist")
            continue
        bare = strip_lua(other)
        body = function_body(other, fn, bare)
        if body is None:
            faults.append(
                f"{fname} has no `{fn}`, and it is declared as a walk over "
                "a persisted store")
            continue
        if how == "budgeted" and not budgeted(function_body(bare, fn, bare)):
            faults.append(
                f"`{fn}` is declared BUDGETED and no condition in it tests a "
                f"budget constant and breaks. {what}")
        print(f"     {fname}:{fn:<18} {how}")

    print(f"  identity-store walks per pass: {total}")
    print("  measured cost per walk        : "
          + ", ".join(f"{n:,}->{ms}ms" for n, ms in COST))

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  74) tick walks: all {len(SUBS)} population subs and "
          f"{len(ELSEWHERE)} other store walks declare what bounds them, "
          f"and the {total} walks per pass are the {total} declared")
    return 0


def main():
    files = {p.name: p.read_text(encoding="utf-8", errors="ignore")
             for p in LUA.rglob("*.lua")}
    status = check_files(files)
    if status:
        return status
    controls = [
        ("SAO_DormantPopulation.lua", "local function dormantSettle()\n    return 0\nend",
         "local function dormantSettle()\n    for _, rec in pairs(SAO.Identity.all()) do\n"
         "        rec.homeX = 100\n    end\n    return 1\nend",
         "`dormantSettle` walks the whole identity store 1 time(s) and is declared as walking it 0"),
        ("SAO_DormantPopulation.lua", "D.dormantSettle = dormantSettle", "D.dormantSettle = nil",
         "DormantPopulation.dormantSettle no longer exports"),
        ("SAO_DormantPopulation.lua", "local function dormantLife(conf, tickCounter)",
         "local function dormantLife(conf, tickCounter)\n    for _, rec in pairs(SAO.Identity.all()) do local id = rec.id end",
         "`dormantLife` walks the whole identity store 2 time(s) and is declared as walking it 1"),
    ]
    for filename, before, after, expected in controls:
        source = files.get(filename, "")
        if source.count(before) != 1:
            print(f"  FAULT: tick-walk control anchor drift: {filename}: {expected}")
            return 1
        mutated = dict(files)
        mutated[filename] = source.replace(before, after, 1)
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            exit_code = check_files(mutated)
        if exit_code != 1 or "  FAULT: " not in output.getvalue() or expected not in output.getvalue():
            print(f"  FAULT: tick-walk control did not reject its defect: {expected}")
            return 1
        print(f"  CONTROL rejected: {expected}")
    # A mention in prose must not invent a new walk in the census.
    comments = dict(files)
    anchor = "local function dormantSettle()"
    comments["SAO_DormantPopulation.lua"] = files["SAO_DormantPopulation.lua"].replace(
        anchor, anchor + "\n    -- for _, rec in pairs(SAO.Identity.all()) do end", 1)
    with contextlib.redirect_stdout(io.StringIO()):
        comment_status = check_files(comments)
    if comment_status:
        print("  FAULT: a commented identity walk changed the executable census")
        return 1
    print(f"  74) tick-walk controls: {len(controls)} rejected; comment-only walk ignored")
    return 0


if __name__ == "__main__":
    sys.exit(main())
