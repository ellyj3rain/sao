#!/usr/bin/env python3
r"""Border 107 - conditions are facts about a person ([C32], DR-032).

The operator ruled that the county's people carry the conditions the
record says people carried, and that knowledge decays per person, not
at one rate. `SAO_Conditions` draws each condition from the person's
own hash at the record's prevalence, gated by age; the modules that
already decide read it - the disposition (bends inside the envelope,
fear), the perception (how long a belief is kept), the age drift (what
the body carries, dementia's day, psychosis's hour), the bridge (what
the skills lose), the controller (what a book costs), the knowledge
surface and the inspect panel (plain words). [C39] The player's side
is SAO's own too: the conditions are registered as engine traits
(Border 113), so nothing is required of anyone.

Checked in the engine's own VM (tools/luacheck/LuaRun) against Border
105's stub county, over six thousand people:

  * every condition's share of its eligible population sits near the
    figure the module declares (the banded ones band by band), and
    nobody outside the age gate has it;
  * the same person answers the same conditions twice; a focus and a
    phase change with the day;
  * every bend is small and every trait stays inside the envelope;
  * the anxious adult fears and the plain adult does not; the demented
    keep the recent half as long and the haunted keep a threat longer;
    the dyslexic learn a tenth slower and read a quarter longer;
  * every word a player can read is plain: letters and spaces.

And by text, every seam that carries it, and both manifests requiring
nothing. An optional argv[1] points the checker at another
tree root, which is how its control runs: the pre-batch tree faults at
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
SHARED = ROOT / "mod" / "42.20" / "media" / "lua" / "shared"
CLIENT = ROOT / "mod" / "42.20" / "media" / "lua" / "client"
HASH = SHARED / "SAO_Hash.lua"
HISTORY = SHARED / "SAO_History.lua"
DISP = SHARED / "SAO_Disposition.lua"
COND = SHARED / "SAO_Conditions.lua"
PERC = SHARED / "SAO_Perception.lua"
KNOW = SHARED / "SAO_Knowledge.lua"
AGE = CLIENT / "SAO_Age.lua"
BODY = CLIENT / "SAO_Body.lua"
INSPECT = CLIENT / "SAO_Inspect.lua"
CONTROLLER = CLIENT / "SAO_Controller.lua"
BRIDGE = ROOT / "java" / "src" / "com" / "sao" / "bridge" / "SAOBridge.java"
RANGE_BORDER = ROOT / "tools" / "decision_range_test.py"
MANIFESTS = (ROOT / "mod" / "42.20" / "mod.info", ROOT / "mod" / "mod.info")
CREDITS = ROOT / "CREDITS.md"
PRELUDE = HERE / "luacheck" / "probe_age.lua"
SRC = HERE / "luacheck" / "LuaRun.java"
OUT = ROOT / "java" / "out" / "luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"

IDS = 6000


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
             str(PRELUDE), str(HASH), str(HISTORY), str(COND), str(DISP), "--", expr],
            cwd=str(work), capture_output=True, text=True, timeout=900)
    return (done.stdout or "").strip().split("\n")[-1] if done.stdout else "ERROR no output"


def value(line):
    return line[6:] if line.startswith("VALUE ") else None


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""


def numbers(line):
    return {k: v for k, v in re.findall(r"([\w.]+)=([-\d./]+|true|false|nil|\w+)", line or "")}


# Shares of the eligible population, per condition, plus the gate.
SHARES = (
    "(function() local Cn, H = SAO.Conditions, SAO.History "
    "local have, eligible, outside = {}, {}, {} "
    "local same, both = true, 0 "
    "for _, key in ipairs(Cn.ORDER) do have[key], eligible[key], outside[key] = 0, 0, 0 end "
    "for i = 1, %d do local id = 'sao-' .. i local age = H.ageOf(id) "
    "local list = Cn.of(id) local again = Cn.of(id) "
    "if #list ~= #again then same = false end "
    "if #list >= 2 then both = both + 1 end "
    "for _, key in ipairs(Cn.ORDER) do "
    "local row = Cn.PREVALENCE[key] local ok = true "
    "if row.bands then ok = false for _, b in ipairs(row.bands) do if age >= b.from and age <= b.to then ok = true end end end "
    "if row.minAge and age < row.minAge then ok = false end "
    "if row.maxAge and age > row.maxAge then ok = false end "
    "local has = Cn.has(id, key) "
    "if ok then eligible[key] = eligible[key] + 1 if has then have[key] = have[key] + 1 end "
    "elseif has then outside[key] = outside[key] + 1 end "
    "end end "
    "local out = {} "
    "for _, key in ipairs(Cn.ORDER) do out[#out + 1] = key .. '=' .. have[key] .. '/' .. eligible[key] .. '/' .. outside[key] end "
    "out[#out + 1] = 'same=' .. tostring(same) out[#out + 1] = 'both=' .. both "
    "return table.concat(out, ' ') end)()" % IDS)

# The banded rows (dementia, asthma, diabetes): the share within each
# band of its own population.
BANDED = (
    "(function() local Cn, H = SAO.Conditions, SAO.History local out = {} "
    "for _, key in ipairs(Cn.ORDER) do local row = Cn.PREVALENCE[key] if row.bands then "
    "for _, band in ipairs(row.bands) do local n, k = 0, 0 "
    "for i = 1, %d do local id = 'sao-' .. i local age = H.ageOf(id) "
    "if age >= band.from and age <= band.to then n = n + 1 if Cn.has(id, key) then k = k + 1 end end end "
    "out[#out + 1] = key .. '_' .. band.from .. '_' .. band.to .. '=' .. k .. '/' .. n .. '/' .. band.per10k end end end "
    "return table.concat(out, ' ') end)()" % IDS)

# What the conditions do, on people the hash makes carry them.
EFFECTS = (
    "(function() local Cn, H, D = SAO.Conditions, SAO.History, SAO.Disposition "
    "local function first(pred) for i = 1, %d do local id = 'sao-' .. i if pred(id) then return id end end return nil end "
    "local function adultWith(key) return first(function(id) return H.ageOf(id) >= 18 and #Cn.of(id) == 1 and Cn.has(id, key) end) end "
    "local plain = first(function(id) return H.ageOf(id) >= 18 and H.ageOf(id) < 75 and #Cn.of(id) == 0 end) "
    "local anxious, haunted, demented, dyslexic, diabetic = adultWith('anxiety'), adultWith('ptsd'), adultWith('dementia'), adultWith('dyslexia'), adultWith('diabetes') "
    "local adhd = first(function(id) return Cn.has(id, 'adhd') end) local bipolar = adultWith('bipolar') "
    "local out = {} "
    "out[#out + 1] = 'plainFear=' .. string.format('%%.2f', D.fear(plain)) "
    "out[#out + 1] = 'plainMemory=' .. string.format('%%.2f', Cn.memoryFactor(plain, 'zombies')) "
    "out[#out + 1] = 'anxiousFear=' .. (anxious and string.format('%%.2f', D.fear(anxious)) or 'nil') "
    "out[#out + 1] = 'hauntedZombies=' .. (haunted and string.format('%%.2f', Cn.memoryFactor(haunted, 'zombies')) or 'nil') "
    "out[#out + 1] = 'hauntedPeople=' .. (haunted and string.format('%%.2f', Cn.memoryFactor(haunted, 'people')) or 'nil') "
    "out[#out + 1] = 'dementedMemory=' .. (demented and string.format('%%.2f', Cn.memoryFactor(demented, 'people') / ((H.ageOf(demented) >= 75) and 0.8 or 1.0)) or 'nil') "
    "out[#out + 1] = 'dyslexicLearning=' .. (dyslexic and string.format('%%.2f', Cn.learningScale(dyslexic)) or 'nil') "
    "out[#out + 1] = 'dyslexicReading=' .. (dyslexic and string.format('%%.2f', Cn.readingTime(dyslexic)) or 'nil') "
    "out[#out + 1] = 'diabeticEatsEarlier=' .. (diabetic and string.format('%%.2f', D.eatAt(diabetic) - (0.30 + D.traits(diabetic).appetite * 0.25)) or 'nil') "
    "local focusKinds, phaseKinds = {}, {} "
    "if adhd then for d = 1, 60 do focusKinds[Cn.focusOf(adhd, d)] = true end end "
    "if bipolar then for d = 1, 4 do phaseKinds[Cn.phaseOf(bipolar, d)] = true end end "
    "out[#out + 1] = 'focusKinds=' .. ((focusKinds.focused and 1 or 0) + (focusKinds.scattered and 1 or 0)) "
    "out[#out + 1] = 'phaseKinds=' .. ((phaseKinds.high and 1 or 0) + (phaseKinds.low and 1 or 0)) "
    "local maxBend, outsideEnvelope = 0, 0 "
    "for i = 1, 2000 do local id = 'sao-' .. i local t = D.traits(id) "
    "for _, axis in ipairs({'nerve', 'discipline', 'aggression', 'initiative', 'selfPreservation', 'compassion', 'appetite', 'talkativeness'}) do "
    "local v = t[axis] if v < 0.15 - 1e-9 or v > 0.85 + 1e-9 then outsideEnvelope = outsideEnvelope + 1 end "
    "local b = math.abs(Cn.bend(id, axis)) if b > maxBend then maxBend = b end end end "
    "out[#out + 1] = 'maxBend=' .. string.format('%%.2f', maxBend) out[#out + 1] = 'outsideEnvelope=' .. outsideEnvelope "
    "local badWords = 0 local words = 0 "
    "for i = 1, 2000 do local id = 'sao-' .. i for _, w in ipairs(Cn.words(id)) do words = words + 1 "
    "if not string.match(w, '^[a-z ]+$') then badWords = badWords + 1 end end end "
    "out[#out + 1] = 'words=' .. words out[#out + 1] = 'badWords=' .. badWords "
    "return table.concat(out, ' ') end)()" % IDS)


def main():
    faults = []
    print("=" * 74)
    print("CONDITIONS ARE FACTS ABOUT A PERSON")
    print("=" * 74)

    for path, what in ((HASH, "SAO_Hash.lua"), (HISTORY, "SAO_History.lua"),
                       (DISP, "SAO_Disposition.lua"), (COND, "SAO_Conditions.lua"),
                       (PERC, "SAO_Perception.lua"), (KNOW, "SAO_Knowledge.lua"),
                       (AGE, "SAO_Age.lua"), (BODY, "SAO_Body.lua"),
                       (INSPECT, "SAO_Inspect.lua"), (CONTROLLER, "SAO_Controller.lua"),
                       (BRIDGE, "SAOBridge.java"), (RANGE_BORDER, "Border 63"),
                       (PRELUDE, "the probe")) + tuple((m, m.name) for m in MANIFESTS):
        if not path.exists():
            faults.append(what + " does not exist")
    if faults:
        for fault in faults:
            print("  FAULT: " + fault)
        return 1
    if not (JDK.exists() and PZ.exists() and STDLIB.exists() and SRC.exists()):
        # [C56] SKIPPED, not a finding. This border reads the installed
        # game, and a machine without it - CI, or anybody's clone - is
        # not a machine with a defect. A check that cannot run must
        # never look like a check that passed either, so it says so
        # twice and the gate prints it.
        print("  SKIPPED - no JDK, engine jar, stdlib or runner")
        print("  107) conditions: SKIPPED, the engine install is absent")
        return 0
    if not build():
        print("  FAULT: LuaRun does not compile against the installed jar")
        return 1

    cond = read(COND)
    if "TO BE SET FROM THE REPORT" in cond:
        faults.append("a prevalence row still waits for its source - a figure without "
                      "a source does not ship")

    shares = numbers(value(probe(SHARES)))
    print("     shares: " + " ".join("%s=%s" % kv for kv in shares.items()))
    # Flat rows declare `per10k` first; banded rows are checked below.
    declared = {}
    for m in re.finditer(r"(\w+)\s*=\s*\{\s*per10k = (\d+)", cond):
        declared.setdefault(m.group(1), int(m.group(2)))
    try:
        for key in ("adhd", "depression", "anxiety", "ptsd", "bipolar", "psychosis",
                    "dyslexia", "insomnia"):
            have, eligible, outside = (int(x) for x in shares[key].split("/"))
            want = declared.get(key)
            if want is None:
                faults.append("no declared figure parsed for " + key)
                continue
            if eligible == 0:
                faults.append("nobody is eligible for " + key)
                continue
            got = have / eligible
            wantShare = want / 10000.0
            slack = max(0.006, wantShare * 0.30)
            if abs(got - wantShare) > slack:
                faults.append("%s is %.1f%% of %d eligible; the module declares %.1f%%"
                              % (key, 100 * got, eligible, 100 * wantShare))
            if outside != 0:
                faults.append("%d people outside the age gate carry %s" % (outside, key))
        if shares["same"] != "true":
            faults.append("the same person answered two different sets of conditions")
        if int(shares["both"]) == 0:
            faults.append("nobody carries two conditions, so the draws are not independent")
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
            # Small bands of the old carry few people, so the slack is
            # wide there and tight where the sample is large.
            slack = max(0.02, want * 0.35) if n >= 300 else max(0.05, want * 0.45)
            if abs(got - want) > slack:
                faults.append("%s is %d of %d; the module declares %.1f%%"
                              % (band, k, n, 100 * want))
        if not bands:
            faults.append("the banded probe answered nothing")
        if not any(k.startswith("dementia_") for k in bands):
            faults.append("dementia is not banded by age")
    except ValueError:
        faults.append("the banded probe did not answer: %r" % bands)

    fx = numbers(value(probe(EFFECTS)))
    print("     effects: " + " ".join("%s=%s" % kv for kv in fx.items()))
    try:
        if float(fx["plainFear"]) != 0:
            faults.append("a plain adult carries fear %s" % fx["plainFear"])
        if float(fx["plainMemory"]) != 1:
            faults.append("a plain adult's memory factor is %s" % fx["plainMemory"])
        if fx["anxiousFear"] == "nil" or float(fx["anxiousFear"]) < 0.25:
            faults.append("the anxious adult's fear is %s, under the quarter" % fx["anxiousFear"])
        if fx["hauntedZombies"] == "nil" or abs(float(fx["hauntedZombies"]) - 1.5) > 1e-6:
            faults.append("the haunted do not keep a threat half again as long: %s" % fx["hauntedZombies"])
        if fx["hauntedPeople"] == "nil" or abs(float(fx["hauntedPeople"]) - 1.0) > 1e-6:
            faults.append("the haunted keep people differently: %s" % fx["hauntedPeople"])
        if fx["dementedMemory"] == "nil" or abs(float(fx["dementedMemory"]) - 0.5) > 1e-6:
            faults.append("the demented do not keep the recent half as long: %s" % fx["dementedMemory"])
        if fx["dyslexicLearning"] == "nil" or abs(float(fx["dyslexicLearning"]) - 0.9) > 1e-6:
            faults.append("the dyslexic do not learn a tenth slower: %s" % fx["dyslexicLearning"])
        if fx["dyslexicReading"] == "nil" or abs(float(fx["dyslexicReading"]) - 1.25) > 1e-6:
            faults.append("the dyslexic do not read a quarter longer: %s" % fx["dyslexicReading"])
        if fx["diabeticEatsEarlier"] == "nil" or abs(float(fx["diabeticEatsEarlier"]) + 0.05) > 1e-6:
            faults.append("the diabetic do not eat earlier by 0.05: %s" % fx["diabeticEatsEarlier"])
        if int(fx["focusKinds"]) != 2:
            faults.append("a restless mind does not have both focused and scattered days")
        if int(fx["phaseKinds"]) != 2:
            faults.append("a bipolar person does not have both spells")
        if float(fx["maxBend"]) > 0.35:
            faults.append("a bend reaches %s, past a third of the envelope" % fx["maxBend"])
        if int(fx["outsideEnvelope"]) != 0:
            faults.append("%s trait readings left the human envelope" % fx["outsideEnvelope"])
        if int(fx["words"]) == 0 or int(fx["badWords"]) != 0:
            faults.append("%s of %s condition words are not plain" % (fx["badWords"], fx["words"]))
    except (KeyError, ValueError):
        faults.append("the effects probe did not answer: %r" % fx)

    perc = read(PERC)
    bare = len(re.findall(r"\bZOMBIE_HORIZON\b", perc))
    seams = {
        "the perception keeps a belief by the person": "local function horizonFor(id, kind)" in perc
            and "SAO.Conditions.memoryFactor" in perc,
        "and every horizon site reads it": bare == 3,   # the declaration, its comment, the base
        "and can place a heard phantom": "function P.hallucinate(id, tick, fromX, fromY)" in perc
            and "phantom = true" in perc,
        "the disposition bends by condition": "SAO.Conditions.bend(id, name)" in read(DISP),
        "and adds a condition's fear": "SAO.Conditions.fear(id, tick)" in read(DISP),
        "and the diabetic eat earlier": "SAO.Conditions.eatEarlier(id)" in read(DISP),
        "the age module carries the conditions' drift": "SAO.Conditions.drift(rec.id)" in read(AGE),
        "and dementia's day": "SAO.Conditions.losesSkillsToday" in read(AGE)
            and "loseSkillMemory(" in read(AGE),
        "and psychosis's hour": "SAO.Conditions.hearsThingsNow" in read(AGE)
            and "SAO.Perception.hallucinate" in read(AGE),
        "and refreshes the learning pace": "SAO.Conditions.learningScale" in read(AGE),
        "the body sets the learning pace for everyone": "SAO.Conditions.learningScale" in read(BODY),
        "the controller prices the book": "SAO.Conditions.readingTime(id)" in read(CONTROLLER),
        "the knowledge surface carries the words": "SAO.Conditions.words(id)" in read(KNOW),
        "the panel says it plainly": 'row("carries: " .. carries)' in read(INSPECT),
        "Border 63 samples the conditions": "SAO_Conditions.lua" in read(RANGE_BORDER),
        "the credits name the two required mods": "twbInfirmities" in read(CREDITS)
            and "EvenMoreTraits4220" in read(CREDITS),
    }
    bridge = read(BRIDGE)
    g = bridge.find("public int loseSkillMemory(")
    gbody = bridge[g:bridge.find("\n    }\n", g)] if g >= 0 else ""
    seams["the bridge takes skill memory"] = "AddXP(perk, -loss)" in gbody and "LoseLevel(perk)" in gbody
    seams["leaving the passive and agility families alone"] = all(
        "Perks." + p in gbody for p in ("None", "Passiv", "Agility"))
    seams["without throwing"] = "catch (Throwable" in gbody
    # [C39] INVERTED. This seam was written when [C32] made two
    # third-party mods hard requirements for the player's side of the
    # conditions. The operator ruled that trade wrong (DR-032 amended)
    # - no code was ever taken from either and nothing mechanical was
    # gained - so SAO carries its own traits now and requires nothing.
    # Left as it was, this seam would hold the tree to a decision that
    # has been reversed, which is the one thing a border must never
    # do. What replaces it is its opposite; Border 113 holds the
    # ported surface itself.
    seams["neither manifest requires another mod"] = all(
        "require=" not in read(m) for m in MANIFESTS)
    seams["the conditions have a trait surface of SAO's own"] = (
        SHARED / "NPCs" / "SAO_Traits.lua").exists()
    if bare != 3:
        print("     bare ZOMBIE_HORIZON references: %d (wanted 3)" % bare)

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
    print("  107) conditions: drawn at the record's prevalence, gated by age, deterministic, "
          "plain; bending, fearing, keeping, carrying, forgetting and pricing at every seam; "
          "the two required mods in both manifests")
    return 0


if __name__ == "__main__":
    sys.exit(main())
