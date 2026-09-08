#!/usr/bin/env python3
r"""Border 124 - the habits are the player's too ([C51], DR-032 S6).

[C39] registered the county's conditions as engine character traits so
the player could carry what the county's people carry, and left the
habits behind. SAO_Habits is the same kind of module as SAO_Conditions
- drawn from the person's own hash at the record's prevalence, lived
on the record, drifting every ten minutes - but nothing offered one at
creation, nothing stamped one onto a survivor's shell, and nothing
would have driven one on the player if it had.

This border holds five claims.

**Priced on the game's own scale.** Every registered habit anchors to
a vanilla trait and takes that trait's cost, read off the installed
`character_traits.txt`. All five anchor to `base:smoker`, because the
habits differ only in schedule and the engine ships exactly one trait
of that shape.

**Cannabis is not registered.** SAO_Habits gives it no withdrawal
schedule, so `Hb.drift` returns nothing for it, and a costed trait
that does nothing to the player would be a lie about the game. The
county still draws it.

**Smoking is vanilla's.** The engine ships `SMOKER`; SAO registers no
second name for one fact, and SAO_Disposition answers from the trait
for the player.

**The player's habit has somewhere to live.** Every write path in
SAO_Habits needs a record, and the player has none: without a store
the dry clock would run from world zero and never reset, a drink would
do nothing, and the habit could never lapse - maximum withdrawal from
the first minute, forever, with no counterplay. A bound table stands
in, and SAO_Traits binds the player's own modData, which the save
persists.

**The withdrawal drives on the player.** `Age.playerPass` calls
`SAO.Habits.drift` on the same ten-minute pass the county's people
get, applies what it returns without a second roll (the shakes were
already rolled inside `drift`), and settles the habit on the day
boundary. A drink is read off `CharacterStat.INTOXICATION` rising
rather than hooked to an action.

The record-side claims run in the engine's own VM (tools/luacheck/
LuaRun) over Border 105's stub county with the real SAO_Habits and
SAO_Hash loaded. An optional argv[1] points the checker at another
tree root, which is how its control runs: the pre-batch tree fails
every seam.
"""
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
HERE = pathlib.Path(__file__).resolve().parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
HASH = LUA / "shared" / "SAO_Hash.lua"
HISTORY = LUA / "shared" / "SAO_History.lua"
HABITS = LUA / "shared" / "SAO_Habits.lua"
TRAITS = LUA / "shared" / "NPCs" / "SAO_Traits.lua"
DISP = LUA / "shared" / "SAO_Disposition.lua"
AGE = LUA / "client" / "SAO_Age.lua"
BODY = LUA / "client" / "SAO_Body.lua"
IDENTITY = LUA / "shared" / "SAO_Identity.lua"
UI = LUA / "shared" / "Translate" / "EN" / "UI_EN.txt"
CHECK = ROOT / "tools" / "check.sh"
PRELUDE = HERE / "luacheck" / "probe_age.lua"
SRC = HERE / "luacheck" / "LuaRun.java"
OUT = ROOT / "java" / "out" / "luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"
VANILLA_TRAITS = (PZ_DIR / "media" / "scripts" / "generated" / "characters"
                  / "character_traits.txt")

STUB = (
    "local recs = {} "
    "SAO.Identity.get = function(id) return recs[id] end "
    "local Hb = SAO.Habits ")


def build():
    cls = OUT / "LuaRun.class"
    if cls.exists() and cls.stat().st_mtime >= SRC.stat().st_mtime:
        return True
    OUT.mkdir(parents=True, exist_ok=True)
    done = subprocess.run(
        [str(JDK / "javac.exe"), "-cp", str(PZ), "-d", str(OUT), str(SRC)],
        capture_output=True, text=True, timeout=300)
    return done.returncode == 0


def probe(expr):
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(STDLIB, work / "stdlib.lua")
        for c in OUT.glob("*.class"):
            shutil.copy2(c, work / c.name)
        done = subprocess.run(
            [str(JDK / "java.exe"), "-cp", f"{PZ};.", "LuaRun",
             str(PRELUDE), str(HASH), str(HISTORY), str(HABITS), "--", expr],
            cwd=str(work), capture_output=True, text=True, timeout=900)
    return (done.stdout or "").strip().split("\n")[-1] if done.stdout else "ERROR no output"


def value(line):
    return line[6:] if line.startswith("VALUE ") else None


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""


def numbers(line):
    return {k: v for k, v in re.findall(r"([\w.]+)=([-\w./']+)", line or "")}


def vanilla_costs():
    """Every vanilla trait's cost, off the installed script."""
    text = read(VANILLA_TRAITS)
    out = {}
    for m in re.finditer(
            r"character_trait_definition\s+base:([\w ]+)\s*\{(.*?)\n\s*\}",
            text, re.S):
        cm = re.search(r"Cost\s*=\s*(-?\d+)", m.group(2))
        if cm:
            out[m.group(1).strip()] = int(cm.group(1))
    return out


# A key with no record answers the draw; a key with a table bound
# answers that table, and every write path reaches it. The player's
# case in one probe: the clock resets on a drink, the withdrawal
# clears with it, and three weeks dry loses the habit for good.
BOUND = (
    "(function() " + STUB +
    "local key = 'player:me' "
    "local store = {} "
    "Hb.assert(key, { drinker = true }) "
    "local drawnPhase = Hb.withdrawalPhase(key, 100) "
    "local drankUnbound = Hb.drank(key, 100) "
    "Hb.bindRecord(key, store) "
    "local drank = Hb.drank(key, 100) "
    "local afterDrink = Hb.withdrawalPhase(key, 100) "
    "local shakes = Hb.withdrawalPhase(key, 100 + 13) "
    "local deep = Hb.withdrawalPhase(key, 100 + 80) "
    "local settled = Hb.settleDrinker(key, 100 + Hb.HOURS_TO_LOSE + 1) "
    "local stillHas = Hb.has(key, 'drinker') "
    "return 'unbound_phase=' .. drawnPhase "
    ".. ' unbound_drink=' .. tostring(drankUnbound) "
    ".. ' bound_drink=' .. tostring(drank) "
    ".. ' after_drink=' .. afterDrink "
    ".. ' shakes=' .. shakes .. ' deep=' .. deep "
    ".. ' settled=' .. tostring(settled) "
    ".. ' still_has=' .. tostring(stillHas) end)()")

# The record still outranks the assertion, so a habit lost stays lost
# across a reload that re-reads the trait. And an assertion reaches
# only the key it names: the county's draw is the same before and
# after the player's is asserted, which is the whole point of keying
# it rather than switching the module into a mode.
OUTRANK = (
    "(function() " + STUB +
    "local key = 'player:me' local store = { habitsQuit = { drinker = true } } "
    "local drawn, after = 0, 0 "
    "for i = 1, 400 do local id = 'sao-' .. i recs[id] = { id = id } "
    "if Hb.has(id, 'drinker') then drawn = drawn + 1 end end "
    "Hb.bindRecord(key, store) Hb.assert(key, { drinker = true }) "
    "local quitWins = Hb.has(key, 'drinker') "
    "for i = 1, 400 do local id = 'sao-' .. i "
    "if Hb.has(id, 'drinker') then after = after + 1 end end "
    "return 'quit_wins=' .. tostring(quitWins) "
    ".. ' drawn=' .. drawn .. ' asserted=' .. after end)()")

# A player who did not take the trait and drinks often enough becomes
# a drinker, on the same arithmetic a survivor gains it by - four
# points a drink against one off an hour, the habit at two hundred.
# That follows from binding a store rather than from anything written
# for it, so it is checked rather than assumed.
GAIN = (
    "(function() " + STUB +
    "local key = 'player:me' local store = {} Hb.bindRecord(key, store) "
    "Hb.assert(key, {}) "
    "local before = Hb.has(key, 'drinker') "
    "local drinks = math.ceil(Hb.GAIN_AT / Hb.GAIN_PER_DRINK) "
    "for i = 1, drinks do Hb.drank(key, 100) end "
    "local after = Hb.has(key, 'drinker') "
    "local few = {} Hb.bindRecord('player:two', few) Hb.assert('player:two', {}) "
    "for i = 1, 5 do Hb.drank('player:two', 100) end "
    "local light = Hb.has('player:two', 'drinker') "
    "return 'before=' .. tostring(before) .. ' after=' .. tostring(after) "
    ".. ' light=' .. tostring(light) .. ' drinks=' .. drinks end)()")

# Cannabis costs the player nothing, which is why it is not offered.
NOCOST = (
    "(function() " + STUB +
    "local key = 'player:me' local store = {} Hb.bindRecord(key, store) "
    "Hb.assert(key, { cannabis = true }) "
    "local n = 0 for _ in pairs(Hb.drift(key, 240, 1)) do n = n + 1 end "
    "Hb.assert(key, { cocaine = true }) "
    "local m = 0 for _ in pairs(Hb.drift(key, 240, 1)) do m = m + 1 end "
    "return 'cannabis_stats=' .. n .. ' cocaine_stats=' .. m end)()")


def main():
    faults = []
    print("=" * 74)
    print("THE HABITS ARE THE PLAYER'S TOO")
    print("=" * 74)
    for path, what in ((HABITS, "SAO_Habits.lua"), (TRAITS, "SAO_Traits.lua"),
                       (AGE, "SAO_Age.lua"), (PRELUDE, "the probe")):
        if not path.exists():
            faults.append(what + " does not exist")
    if faults:
        for fault in faults:
            print("  FAULT: " + fault)
        return 1
    if not (JDK.exists() and PZ.exists() and STDLIB.exists() and SRC.exists()):
        print("  FAULT: no JDK, engine jar, stdlib or runner - nothing ran on the engine")
        return 1
    if not build():
        print("  FAULT: LuaRun does not compile against the installed jar")
        return 1

    traits, habits, age = read(TRAITS), read(HABITS), read(AGE)

    # Every registered habit's cost is its anchor's, off vanilla's file.
    costs = vanilla_costs()
    if not costs:
        faults.append("vanilla's own character_traits.txt did not parse, so no "
                      "cost could be checked against it")
    anchors = dict(re.findall(r'^\s*(\w+)\s*=\s*"(\w+)",\s*$',
                              traits.split("T.HABIT_ANCHOR = {")[-1]
                              .split("}")[0], re.M)) if "T.HABIT_ANCHOR" in traits else {}
    declared = dict((k, int(v)) for k, v in re.findall(
        r"^\s*(\w+)\s*=\s*(-\d+),", traits.split("T.ANCHOR_COST = {")[-1]
        .split("}")[0], re.M)) if "T.ANCHOR_COST" in traits else {}
    print("     habit anchors: " + " ".join(
        "%s=%s(%s)" % (k, declared.get(v), v) for k, v in sorted(anchors.items())))
    if not anchors:
        faults.append("no habit anchors are declared, so nothing is registered")
    for key, anchor in anchors.items():
        if anchor not in costs:
            faults.append("%s anchors to base:%s, which is not a vanilla trait"
                          % (key, anchor))
        elif declared.get(anchor) != costs[anchor]:
            faults.append("%s anchors to base:%s: SAO says %s, vanilla's own "
                          "file says %s" % (key, anchor, declared.get(anchor),
                                            costs[anchor]))

    bound = numbers(value(probe(BOUND)))
    print("     bound store: " + " ".join("%s=%s" % kv for kv in bound.items()))
    wantB = {"unbound_phase": "4", "unbound_drink": "false",
             "bound_drink": "true", "after_drink": "0", "shakes": "1",
             "deep": "4", "settled": "true", "still_has": "false"}
    for k, v in wantB.items():
        if bound.get(k) != v:
            faults.append("the bound store: %s is %s, wanted %s - %s"
                          % (k, bound.get(k), v,
                             "without a store the player is at maximum "
                             "withdrawal forever with no counterplay"))

    out = numbers(value(probe(OUTRANK)))
    print("     precedence: " + " ".join("%s=%s" % kv for kv in out.items()))
    if out.get("quit_wins") != "false":
        faults.append("a habit quit does not outrank the assertion, so a "
                      "player's lapsed habit comes back at every reload")
    try:
        if int(out["drawn"]) != int(out["asserted"]):
            faults.append("asserting one person's habits changed the county's "
                          "draw (%s then %s of 400)"
                          % (out["drawn"], out["asserted"]))
        if int(out["drawn"]) == 0:
            faults.append("nobody in 400 drew the drinker, so the draw is not "
                          "being exercised and the comparison proves nothing")
    except (KeyError, ValueError):
        faults.append("the precedence probe did not answer: %r" % out)

    gn = numbers(value(probe(GAIN)))
    print("     acquired: " + " ".join("%s=%s" % kv for kv in gn.items()))
    if gn.get("before") != "false" or gn.get("after") != "true":
        faults.append("drinking %s times did not make a bound player a "
                      "drinker (before %s, after %s); the gain arithmetic "
                      "does not reach the player's store"
                      % (gn.get("drinks"), gn.get("before"), gn.get("after")))
    if gn.get("light") != "false":
        faults.append("five drinks made a player a drinker; the gain should "
                      "take the same two hundred points it takes a survivor")

    nc = numbers(value(probe(NOCOST)))
    print("     cannabis: " + " ".join("%s=%s" % kv for kv in nc.items()))
    if nc.get("cannabis_stats") != "0":
        faults.append("cannabis costs the player %s stat(s), so it should be "
                      "registered as a trait rather than skipped"
                      % nc.get("cannabis_stats"))
    if nc.get("cocaine_stats") in (None, "0"):
        faults.append("cocaine costs nothing either, so the cannabis check "
                      "has no control and proves nothing")

    order = re.search(r"Hb\.ORDER = \{(.*?)\}", habits)
    keys = set(re.findall(r'"(\w+)"', order.group(1))) if order else set()
    registered = set(anchors) | set(
        re.findall(r"(\w+)\s*=", traits.split("T.HABIT_UNPRICED = {")[-1]
                   .split("}")[0]) if "T.HABIT_UNPRICED" in traits else [])
    missing = keys - registered
    if missing:
        faults.append("habit(s) in Hb.ORDER neither registered nor explicitly "
                      "unpriced: %s" % ", ".join(sorted(missing)))
    for key in sorted(anchors):
        if 'UI_trait_SAO_%s = "' % key not in read(UI):
            faults.append("%s is registered with no name a player can read" % key)

    seams = {
        "the assertion is the habit module's own":
            "Hb.asserted = Hb.asserted or {}" in habits
            and "function Hb.assert(id, set)" in habits
            and "function Hb.forget(id)" in habits,
        "a key with no record can have one bound":
            "function Hb.bindRecord(id, tbl)" in habits
            and "return Hb.bound[tostring(id)]" in habits,
        "the player's store is their own modData, which the save keeps":
            "md.SAOHabits = md.SAOHabits or {}" in traits
            and "SAO.Habits.bindRecord(key, md.SAOHabits)" in traits,
        "smoking is vanilla's trait, not a second name for it":
            'T.HABIT_VANILLA = { smoker = "SMOKER" }' in traits
            and "D.assertedSmoker" in read(DISP)
            and "function D.assertSmoker(id, value)" in read(DISP),
        "the habit rides the trait at materialisation":
            "function T.stampHabits(id, character)" in traits
            and "SAO.Traits.stampHabits(rec.id, body)" in read(BODY),
        "the player's traits are read onto their key":
            "SAO.Habits.assert(key, habits)" in traits
            and "SAO.Disposition.assertSmoker(key" in traits,
        "the withdrawal drives on the player's own pass":
            "SAO.Habits.drift(key, nil, pass)" in age
            and "SAO.Habits.settleDrinker(key)" in age,
        "the withdrawal is not rolled twice":
            "if type(habit) == \"table\" and stats then" in age
            and "chance(DRIFT_CHANCE" not in age.split(
                "if type(habit) == \"table\"")[1].split("end")[0],
        "a drink is read off the engine's own level":
            "CharacterStat.INTOXICATION" in age
            and "function Age.playerDrinks(player, key)" in age
            and "Age.playerDrinks(me, key)" in age,
        "the dead drop their assertion":
            "SAO.Habits.forget, rec.id" in read(IDENTITY),
        "the gate runs this border":
            "tools/habit_traits_test.py" in read(CHECK),
    }
    print()
    for k, v in seams.items():
        print(f"  {'yes' if v else 'NO '}  {k}")
        if not v:
            faults.append(k)

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print("  FAULT: " + f)
        return 1
    print("  124) the habits are the player's too: %d registered at vanilla's "
          "own price, cannabis skipped for costing nothing, smoking left to "
          "vanilla, and the withdrawal driven on the player's own pass"
          % len(anchors))
    return 0


if __name__ == "__main__":
    sys.exit(main())
