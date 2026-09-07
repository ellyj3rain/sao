#!/usr/bin/env python3
r"""Border 108 - habits are facts about a person ([C33], DR-032, S6).

The dependency model the catalogue settled on comes into SAO's habits:
The Alcoholic's drinker (hours since the last drink, four withdrawal
phases, the habit lost after three weeks dry and gained by drinking
often) and N and C's schedule for the users the county fell with (a
dependency lost after eighteen to twenty clean days, withdrawal at
days one, five and ten). A habit is drawn at the record's prevalence
and then lives on the record; what it carries reaches the body every
pass; a drinker with the shakes takes a drink through the engine's
own fluid action, or goes to where one is.

Checked in the engine's own VM (tools/luacheck/LuaRun) against Border
105's stub county with a record store installed:

  * the drinker's share of adults near the declared figure, nobody
    under eighteen; the users' shares near theirs;
  * the phases by hours dry; a drink taken resets them and is
    remembered; three weeks dry and the habit is gone; fifty drinks in
    an hour and a non-drinker has it;
  * a user's tier by clean days, and the dependency gone past the
    person's own eighteen to twenty;
  * what a habit carries per pass is the mod's hourly figure over six;
  * every word plain.

And by text, every seam: the engine's fluid surfaces in Java, the
bridge, the needs module's drink and its wrap of the drink action, the
controller's drink and its seeking, the age module's drift and the day
that settles a habit, the knowledge surface and the panel. An optional
argv[1] points the checker at another tree root, which is how its
control runs: the pre-batch tree faults at every seam.
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
SHARED = ROOT / "mod" / "42.20" / "media" / "lua" / "shared"
CLIENT = ROOT / "mod" / "42.20" / "media" / "lua" / "client"
HASH = SHARED / "SAO_Hash.lua"
HISTORY = SHARED / "SAO_History.lua"
HABITS = SHARED / "SAO_Habits.lua"
KNOW = SHARED / "SAO_Knowledge.lua"
AGE = CLIENT / "SAO_Age.lua"
NEEDS = CLIENT / "SAO_Needs.lua"
INSPECT = CLIENT / "SAO_Inspect.lua"
CONTROLLER = CLIENT / "SAO_Controller.lua"
BRIDGE = ROOT / "java" / "src" / "com" / "sao" / "bridge" / "SAOBridge.java"
NEEDS_JAVA = ROOT / "java" / "src" / "com" / "sao" / "engine" / "SAONeeds.java"
CREDITS = ROOT / "CREDITS.md"
PRELUDE = HERE / "luacheck" / "probe_age.lua"
SRC = HERE / "luacheck" / "LuaRun.java"
OUT = ROOT / "java" / "out" / "luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"

IDS = 6000

# A record store the habits can live on, installed over the probe's
# empty Identity.
STORE = ("local store = {} SAO.Identity.get = function(id) local r = store[id] "
         "if not r then r = { id = id } store[id] = r end return r end ")


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
    return {k: v for k, v in re.findall(r"([\w.]+)=([-\d./]+|true|false|nil|[a-z_]+)", line or "")}


SHARES = (
    "(function() " + STORE + "local Hb, H = SAO.Habits, SAO.History "
    "local have, eligible, outside = {}, {}, {} "
    "for _, key in ipairs(Hb.ORDER) do have[key], eligible[key], outside[key] = 0, 0, 0 end "
    "for i = 1, %d do local id = 'sao-' .. i local age = H.ageOf(id) "
    "for _, key in ipairs(Hb.ORDER) do local row = Hb.PREVALENCE[key] local ok = true "
    "if row.bands then ok = false for _, b in ipairs(row.bands) do if age >= b.from and age <= b.to then ok = true end end end "
    "if row.minAge and age < row.minAge then ok = false end "
    "if row.maxAge and age > row.maxAge then ok = false end "
    "local has = Hb.has(id, key) "
    "if ok then eligible[key] = eligible[key] + 1 if has then have[key] = have[key] + 1 end "
    "elseif has then outside[key] = outside[key] + 1 end end end "
    "local out = {} for _, key in ipairs(Hb.ORDER) do out[#out + 1] = key .. '=' .. have[key] .. '/' .. eligible[key] .. '/' .. outside[key] end "
    "return table.concat(out, ' ') end)()" % IDS)

DRINKER = (
    "(function() " + STORE + "local Hb, H = SAO.Habits, SAO.History "
    "local d, n = nil, nil "
    "for i = 1, %d do local id = 'sao-' .. i if H.ageOf(id) >= 18 then "
    "if not d and Hb.has(id, 'drinker') then d = id end "
    "if not n and not Hb.has(id, 'drinker') then n = id end end end "
    "if not d or not n then return 'nodrinker=true' end "
    "local out = {} "
    "out[#out + 1] = 'p6=' .. Hb.withdrawalPhase(d, 6) out[#out + 1] = 'p13=' .. Hb.withdrawalPhase(d, 13) "
    "out[#out + 1] = 'p25=' .. Hb.withdrawalPhase(d, 25) out[#out + 1] = 'p49=' .. Hb.withdrawalPhase(d, 49) "
    "out[#out + 1] = 'p73=' .. Hb.withdrawalPhase(d, 73) "
    "local w73 = Hb.words(d, 73)[1] out[#out + 1] = 'w73=' .. (w73 and w73:gsub(' ', '_') or 'nil') "
    "local drift = Hb.drift(d, 73, 1) out[#out + 1] = 'stress73=' .. string.format('%%.4f', drift.STRESS or 0) "
    "out[#out + 1] = 'pain73=' .. string.format('%%.4f', drift.PAIN or 0) "
    "out[#out + 1] = 'wants73=' .. tostring(Hb.wantsDrink(d, 73)) "
    "Hb.drank(d, 100) out[#out + 1] = 'p105=' .. Hb.withdrawalPhase(d, 105) "
    "out[#out + 1] = 'dry110=' .. Hb.hoursDry(d, 110) "
    "out[#out + 1] = 'wants105=' .. tostring(Hb.wantsDrink(d, 105)) "
    "local drift0 = Hb.drift(d, 105, 2) local k = 0 for _ in pairs(drift0) do k = k + 1 end out[#out + 1] = 'drift105=' .. k "
    "out[#out + 1] = 'settleEarly=' .. tostring(Hb.settleDrinker(d, 100 + 500)) "
    "out[#out + 1] = 'settleLate=' .. tostring(Hb.settleDrinker(d, 100 + 505)) "
    "out[#out + 1] = 'stillDrinker=' .. tostring(Hb.has(d, 'drinker')) "
    "for i = 1, 50 do Hb.drank(n, 200) end out[#out + 1] = 'gained=' .. tostring(Hb.has(n, 'drinker')) "
    "return table.concat(out, ' ') end)()" % IDS)

USERS = (
    "(function() " + STORE + "local Hb, H = SAO.Habits, SAO.History "
    # A user of cocaine and nothing else, so the loads and the settling
    # read one dependency (the draws are independent and can stack).
    "local u = nil for i = 1, %d do local id = 'sao-' .. i if Hb.has(id, 'cocaine') and #Hb.of(id) == 1 then u = id break end end "
    "if not u then return 'nouser=true' end "
    "local out = {} "
    "out[#out + 1] = 't0=' .. tostring(Hb.userTier(u, 'cocaine', 0)) "
    "out[#out + 1] = 't1=' .. tostring(Hb.userTier(u, 'cocaine', 24)) "
    "out[#out + 1] = 't5=' .. tostring(Hb.userTier(u, 'cocaine', 5 * 24)) "
    "out[#out + 1] = 't10=' .. tostring(Hb.userTier(u, 'cocaine', 10 * 24)) "
    "local drift = Hb.drift(u, 5 * 24, 3) out[#out + 1] = 'stress5=' .. string.format('%%.4f', drift.STRESS or 0) "
    "local w = Hb.words(u, 5 * 24)[1] out[#out + 1] = 'w5=' .. (w and w:gsub('[ ,]', '_') or 'nil') "
    "out[#out + 1] = 'lose=' .. Hb.daysToLose(u) "
    "out[#out + 1] = 'settled17=' .. Hb.settleUsers(u, 17 * 24) "
    "out[#out + 1] = 'settled21=' .. Hb.settleUsers(u, 21 * 24) "
    "out[#out + 1] = 'stillUser=' .. tostring(Hb.has(u, 'cocaine')) "
    "return table.concat(out, ' ') end)()" % IDS)

BANDED = (
    "(function() " + STORE + "local Hb, H = SAO.Habits, SAO.History local out = {} "
    "for _, key in ipairs(Hb.ORDER) do local row = Hb.PREVALENCE[key] if row.bands then "
    "for _, band in ipairs(row.bands) do local n, k = 0, 0 "
    "for i = 1, %d do local id = 'sao-' .. i local age = H.ageOf(id) "
    "if age >= band.from and age <= band.to then n = n + 1 if Hb.has(id, key) then k = k + 1 end end end "
    "out[#out + 1] = key .. '_' .. band.from .. '_' .. band.to .. '=' .. k .. '/' .. n .. '/' .. band.per10k end end end "
    "return table.concat(out, ' ') end)()" % IDS)

WORDS = (
    "(function() " + STORE + "local Hb = SAO.Habits local words, bad = 0, 0 "
    "for i = 1, 3000 do local id = 'sao-' .. i for _, w in ipairs(Hb.words(id, 30)) do words = words + 1 "
    "if not string.match(w, '^[a-z ,]+$') then bad = bad + 1 end end end "
    "return 'words=' .. words .. ' bad=' .. bad end)()")


def main():
    faults = []
    print("=" * 74)
    print("HABITS ARE FACTS ABOUT A PERSON")
    print("=" * 74)
    for path, what in ((HASH, "SAO_Hash.lua"), (HISTORY, "SAO_History.lua"),
                       (HABITS, "SAO_Habits.lua"), (KNOW, "SAO_Knowledge.lua"),
                       (AGE, "SAO_Age.lua"), (NEEDS, "SAO_Needs.lua"),
                       (INSPECT, "SAO_Inspect.lua"), (CONTROLLER, "SAO_Controller.lua"),
                       (BRIDGE, "SAOBridge.java"), (NEEDS_JAVA, "SAONeeds.java"),
                       (PRELUDE, "the probe")):
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

    habits = read(HABITS)
    if "TO BE SET FROM THE REPORT" in habits:
        faults.append("a prevalence row still waits for its source - a figure without "
                      "a source does not ship")

    shares = numbers(value(probe(SHARES)))
    print("     shares: " + " ".join("%s=%s" % kv for kv in shares.items()))
    declared = {m.group(1): int(m.group(2)) for m in
                re.finditer(r"(\w+)\s*=\s*\{\s*per10k = (\d+)", habits)}
    banded_keys = set(re.findall(r"(\w+)\s*=\s*\{\s*bands = \{", habits))
    try:
        for key in ("drinker", "cannabis", "cocaine", "opioids", "stimulants", "sedatives"):
            have, eligible, outside = (int(x) for x in shares[key].split("/"))
            if outside != 0:
                faults.append("%d people outside the age gate carry %s" % (outside, key))
            if key in banded_keys:
                continue   # checked band by band below
            want = declared.get(key)
            if want is None:
                faults.append("no declared figure parsed for " + key)
                continue
            if eligible == 0:
                faults.append("nobody is eligible for " + key)
                continue
            got, wantShare = have / eligible, want / 10000.0
            if abs(got - wantShare) > max(0.006, wantShare * 0.30):
                faults.append("%s is %.2f%% of %d eligible; the module declares %.2f%%"
                              % (key, 100 * got, eligible, 100 * wantShare))
    except (KeyError, ValueError):
        faults.append("the shares probe did not answer: %r" % shares)

    bands = numbers(value(probe(BANDED)))
    print("     by band: " + " ".join("%s=%s" % kv for kv in bands.items()))
    try:
        for band, val in bands.items():
            k, n, per10k = (int(x) for x in val.split("/"))
            if n < 20:
                continue
            got, want = k / n, per10k / 10000.0
            slack = max(0.02, want * 0.35) if n >= 300 else max(0.05, want * 0.45)
            if abs(got - want) > slack:
                faults.append("%s is %d of %d; the module declares %.2f%%"
                              % (band, k, n, 100 * want))
        if banded_keys and not bands:
            faults.append("the banded probe answered nothing")
    except ValueError:
        faults.append("the banded probe did not answer: %r" % bands)

    d = numbers(value(probe(DRINKER)))
    print("     drinker: " + " ".join("%s=%s" % kv for kv in d.items()))
    want = {"p6": "0", "p13": "1", "p25": "2", "p49": "3", "p73": "4",
            "w73": "very_sick_for_a_drink", "stress73": "0.0500", "pain73": "0.0050",
            "wants73": "true", "p105": "0", "dry110": "10", "wants105": "false",
            "drift105": "0", "settleEarly": "false", "settleLate": "true",
            "stillDrinker": "false", "gained": "true"}
    if d.get("nodrinker") == "true":
        faults.append("no drinker and no non-drinker among the adults sampled")
    else:
        for k, v in want.items():
            if d.get(k) != v:
                faults.append("the drinker: %s is %s, wanted %s" % (k, d.get(k), v))

    u = numbers(value(probe(USERS)))
    print("     user: " + " ".join("%s=%s" % kv for kv in u.items()))
    if u.get("nouser") == "true":
        if declared.get("cocaine", 0) > 0:
            faults.append("cocaine is declared and nobody of %d carries it" % IDS)
    else:
        wantU = {"t0": "nil", "t1": "medium", "t5": "bad", "t10": "mild",
                 "stress5": "0.0200", "w5": "used_cocaine__sweating_it_out",
                 "settled17": "0", "settled21": "1", "stillUser": "false"}
        for k, v in wantU.items():
            if u.get(k) != v:
                faults.append("the user: %s is %s, wanted %s" % (k, u.get(k), v))
        try:
            if not (18 <= int(u["lose"]) <= 20):
                faults.append("the clean days to lose are %s" % u["lose"])
        except (KeyError, ValueError):
            faults.append("the clean days did not answer")

    w = numbers(value(probe(WORDS)))
    print("     words: " + " ".join("%s=%s" % kv for kv in w.items()))
    try:
        if int(w["words"]) == 0 or int(w["bad"]) != 0:
            faults.append("%s of %s habit words are not plain" % (w["bad"], w["words"]))
    except (KeyError, ValueError):
        faults.append("the words probe did not answer: %r" % w)

    nj, br, nl = read(NEEDS_JAVA), read(BRIDGE), read(NEEDS)
    ctl, ag = read(CONTROLLER), read(AGE)
    seams = {
        "the engine's drink is a fluid in the Alcoholic category":
            "FluidCategory.Alcoholic" in nj and "isFluidContainer()" in nj
            and "getFluidContainer()" in nj,
        "the fullest drink carried": "bestCarriedDrinkAlcohol(" in nj,
        "and the nearest container holding one, into the same source":
            "findDrinkSourceNear(" in nj and "firstDrinkIn(" in nj and "SOURCES.put(shell, best)" in nj,
        "the bridge exposes the three": all(s in br for s in
            ("findCarriedAlcohol(", "findAlcoholSource(", "isAlcoholicDrink(")),
        "the needs module drinks a quarter through the vanilla action":
            "ISDrinkFluidAction:new(body, item, 0.25)" in nl,
        "and finds a drink": "findAlcoholSource(body" in nl,
        "and counts every drink our bodies take":
            "ISDrinkFluidAction.SAOHabitsWrapped" in nl and "SAO.Habits.drank(" in nl,
        "the controller takes a drink for the shakes": "SAO.Habits.wantsDrink(id)" in ctl
            and "SAO.Needs.drinkCarriedAlcohol(id, body)" in ctl,
        "and goes to where one is, through the forage path":
            "SAO.Needs.findDrinkSource(id, body)" in ctl
            and ctl.find('"FORAGE",\n                        "the shakes') > 0,
        "and respects a claim on the way": "will not take a drink from a claimed place" in ctl,
        "the age module carries the habits every pass": "SAO.Habits.drift(rec.id" in ag,
        "and the day settles them": "SAO.Habits.settleDrinker(rec.id)" in ag
            and "SAO.Habits.settleUsers(rec.id)" in ag and "Age.settleHabits, rec, today" in ag,
        "the knowledge surface carries the words": "SAO.Habits.words(id)" in read(KNOW),
        "the panel says them beside the conditions": "SAO.Habits.describe(id)" in read(INSPECT),
        "the credits name the mods": "## The Alcoholic (axxessdenied)" in read(CREDITS)
            and "## N and C's Narcotics" in read(CREDITS),
    }
    print()
    print("  THE SEAMS")
    for k, v in seams.items():
        print("    %s  %s" % ("yes" if v else "NO ", k))
        if not v:
            faults.append("seam missing: " + k)

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print("  FAULT: " + f)
        return 1
    print("  108) habits: the drinker and the users drawn at the record's prevalence, the phases "
          "and the tiers on the record, the drink taken and found through the engine's own "
          "fluids, every seam carrying it")
    return 0


if __name__ == "__main__":
    sys.exit(main())
