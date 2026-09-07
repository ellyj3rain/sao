#!/usr/bin/env python3
r"""Border 111 - an order lands through standing ([C37], DR-033 ruled).

The operator ruled that no authority table is authored: whether a
person does what they are told is decided by the Standing that exists
- houses, leaders, designations, trust - and the competence the giver
has shown, the way CAO's Authority pillar decides it. SAO_Command
carries that check: the giver's command standing (an office over the
person, or a proven hand, shaded by the person's trust in them), the
person's conformity read off the initiative axis and their discipline,
three bands, a reason with every no; then the envelope - what the
person would do at all - with the person's own reason.

Checked in the engine's own VM (tools/luacheck/LuaRun) against Border
105's stub county with a stub Standing installed, the real
disposition loaded over the flat one:

  * CAO's own tuning invariant on flat traits: the default person
    under a peer scores 0.445 and complies cleanly;
  * over the county sampled - the leader's word taken by everyone,
    the disliked stranger's by nobody and for the right reason, the
    stranger's by the share the axes give with the reason "sees no
    standing", the reluctant band where CAO put it;
  * the chair is the leader; a proven hand stands as a second, in a
    fight by kills and in a job by the teaching margin;
  * the envelope: nobody fights unarmed, a small child is too afraid,
    another's ground is not walked onto, ground believed to be
    somebody's is not walked onto;
  * every word plain.

And by text, every seam: each ask in the harness through the gate,
the raw trust line gone from the crew, the three answers and the
answer seen, the gesture map, the panel row, the controller's margin
read from the module, the roadmap and the registry. An optional
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
COND = SHARED / "SAO_Conditions.lua"
DISP = SHARED / "SAO_Disposition.lua"
COMMAND = SHARED / "SAO_Command.lua"
HARNESS = CLIENT / "SAO_Harness.lua"
VOICE = CLIENT / "SAO_Voice.lua"
GESTURE = CLIENT / "SAO_Gesture.lua"
INSPECT = CLIENT / "SAO_Inspect.lua"
CONTROLLER = CLIENT / "SAO_Controller.lua"
ARCH = ROOT / "ARCHITECTURE.md"
ROADMAP = ROOT / "ROADMAP.md"
REGISTRY = ROOT / "DECISION_REGISTRY.md"
CHECK = ROOT / "tools" / "check.sh"
PRELUDE = HERE / "luacheck" / "probe_age.lua"
SRC = HERE / "luacheck" / "LuaRun.java"
OUT = ROOT / "java" / "out" / "luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"

IDS = 6000

# A Standing the command surface can read, installed over the probe's
# empty one; a player of five kills and Aiming 4; nobody has a body.
STUB = (
    "local trustT, groups, leaders, chairs, seconds = {}, {}, {}, {}, {} "
    "SAO.Standing.trust = function(id, key) return trustT[id] and trustT[id][key] or 0 end "
    "SAO.Standing.groupOf = function(id) return groups[id] end "
    "SAO.Standing.leaderOf = function(g) return leaders[g] end "
    "SAO.Standing.playerChairOf = function(g) return chairs[g] end "
    "SAO.Standing.secondOf = function(g) return seconds[g] end "
    "SAO.Standing.isPlayerKey = function(k) return string.sub(tostring(k), 1, 7) == 'player:' end "
    "SAO.Standing.playerKey = function(b) return 'player:me' end "
    "SAO.Standing.mayEnter = function(id, x, y) return x ~= 99 end "
    "SAO.Standing.isHostileTo = function() return false end "
    "SAO.Body = { get = function(id) return nil end } "
    "SAO.Controller = { agents = {}, tick = function() return 1000 end } "
    "SAO.Perception = { believesClaimed = function(id, x, y) if x == 77 then return 'other' end return nil end, "
    "nearestBelievedZombie = function() return nil end, believedThreatCount = function() return 1 end } "
    "SAO.Census.JOB_PERK = { watch = 'Aiming' } "
    "SAO.Census.skillOf = function(id, perk) return 0 end "
    "getSpecificPlayer = function(n) return { getZombieKills = function() return 5 end, "
    "getPerkLevel = function() return 4 end, getUsername = function() return 'me' end } end "
    "Perks = { Aiming = 'Aiming' } "
    "local Cmd, H = SAO.Command, SAO.History local me = 'player:me' "
    "local function setTrust(id, v) trustT[id] = trustT[id] or {} trustT[id][me] = v end ")


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
             str(PRELUDE), str(HASH), str(HISTORY), str(COND), str(DISP),
             str(COMMAND), "--", expr],
            cwd=str(work), capture_output=True, text=True, timeout=900)
    return (done.stdout or "").strip().split("\n")[-1] if done.stdout else "ERROR no output"


def value(line):
    return line[6:] if line.startswith("VALUE ") else None


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""


def numbers(line):
    return {k: v for k, v in re.findall(r"([\w.]+)=([-\w./']+)", line or "")}


# CAO's tuning invariant, on flat traits: the default person under a
# peer complies cleanly at 0.445.
FLAT = (
    "(function() " + STUB +
    "SAO.Disposition.traits = function(id) return { nerve = 0.5, discipline = 0.5, aggression = 0.5, "
    "initiative = 0.5, selfPreservation = 0.5, compassion = 0.5, appetite = 0.5, talkativeness = 0.5 } end "
    "local v, r, s, st, o = Cmd.obedience(me, 'sao-1', 'walk', nil) "
    "return 'verdict=' .. v .. ' score=' .. string.format('%.3f', s) .. ' standing=' .. string.format('%.2f', st) "
    ".. ' office=' .. o .. ' reason=' .. tostring(r) end)()")

# The county sampled under four givers.
SAMPLE = (
    "(function() " + STUB +
    "local out = {} "
    "local function tally(label, setup) local c, rl, rf, bad, band = 0, 0, 0, 0, 0 "
    "for i = 1, %d do local id = 'sao-' .. i setup(id) "
    "local v, r, s = Cmd.obedience(me, id, 'walk', nil) "
    "if v == 'complies' then c = c + 1 elseif v == 'reluctant' then rl = rl + 1 "
    "if not (s >= Cmd.RELUCTANT_AT and s < Cmd.COMPLIES_AT) then band = band + 1 end "
    "else rf = rf + 1 end "
    "if v ~= 'complies' and r ~= label then bad = bad + 1 end end "
    "out[#out + 1] = string.format('%%s=%%d/%%d/%%d/%%d/%%d', label:gsub(' ', '_'), c, rl, rf, bad, band) end "
    "tally('sees no standing in you', function(id) end) "
    "tally('their leader', function(id) groups[id] = 'h' leaders['h'] = me end) "
    "tally('does not think much of you', function(id) groups[id] = nil setTrust(id, -0.8) end) "
    "return table.concat(out, ' ') end)()" % IDS)

# Offices and the proven hand, on one person with flat trust.
OFFICES = (
    "(function() " + STUB +
    "local id = 'sao-7' local out = {} "
    "local function st(kind, job) local s, o = Cmd.standingOf(me, id, kind, job) return string.format('%.2f', s) .. '/' .. o end "
    "out[#out + 1] = 'stranger=' .. st('walk') "
    "out[#out + 1] = 'fight=' .. st('engage') "
    "out[#out + 1] = 'watch=' .. st('work', 'watch') "
    "out[#out + 1] = 'medic=' .. st('work', 'medic') "
    "groups[id] = 'h' leaders['h'] = 'sao-2' seconds['h'] = me out[#out + 1] = 'second=' .. st('walk') "
    "seconds['h'] = nil chairs['h'] = me out[#out + 1] = 'chair=' .. st('walk') "
    "chairs['h'] = nil leaders['h'] = me setTrust(id, 0.6) out[#out + 1] = 'leader_liked=' .. st('walk') "
    "setTrust(id, -1) out[#out + 1] = 'leader_hated=' .. st('walk') "
    "return table.concat(out, ' ') end)()")

# The envelope: the reasons a person who would take the word still
# says no. The leader asks, so the word itself is never the reason.
ENVELOPE = (
    "(function() " + STUB +
    "local out = {} local child = nil "
    "for i = 1, 3000 do local id = 'sao-' .. i if H.ageOf(id) <= 7 then child = id break end end "
    "local adult = nil for i = 1, 3000 do local id = 'sao-' .. i if H.ageOf(id) >= 30 and H.ageOf(id) <= 40 then adult = id break end end "
    "for _, id in ipairs({ child, adult }) do groups[id] = 'h' end leaders['h'] = me "
    "local v, r = Cmd.order(me, adult, 'engage', nil) out[#out + 1] = 'unarmed=' .. v .. '/' .. tostring(r):gsub(' ', '_') "
    "SAO.Controller.agents[adult] = { armed = true } SAO.Controller.agents[child] = { armed = true } "
    "v, r = Cmd.order(me, child, 'engage', nil) out[#out + 1] = 'child=' .. v .. '/' .. tostring(r):gsub(' ', '_') "
    "v, r = Cmd.order(me, adult, 'travel', { x = 99, y = 1 }) out[#out + 1] = 'ground=' .. v .. '/' .. tostring(r):gsub(' ', '_') "
    "v, r = Cmd.order(me, adult, 'travel', { x = 77, y = 1 }) out[#out + 1] = 'believed=' .. v .. '/' .. tostring(r):gsub(' ', '_') "
    "v, r = Cmd.order(me, adult, 'travel', { x = 1, y = 1 }) out[#out + 1] = 'open=' .. v .. '/' .. tostring(r) "
    "v, r = Cmd.order(me, adult, 'hold', nil) out[#out + 1] = 'hold=' .. v .. '/' .. tostring(r) "
    "return table.concat(out, ' ') end)()")

WORDS = (
    "(function() " + STUB +
    "local n, bad = 0, 0 "
    "for i = 1, 400 do local id = 'sao-' .. i "
    "for _, w in ipairs({ Cmd.describe(id, me) }) do n = n + 1 if not string.match(w, '^[a-z ,]+$') then bad = bad + 1 end end "
    "groups[id] = 'h' leaders['h'] = me "
    "for _, w in ipairs({ Cmd.describe(id, me) }) do n = n + 1 if not string.match(w, '^[a-z ,]+$') then bad = bad + 1 end end end "
    "return 'words=' .. n .. ' bad=' .. bad end)()")


def main():
    faults = []
    print("=" * 74)
    print("AN ORDER LANDS THROUGH STANDING")
    print("=" * 74)
    for path, what in ((HASH, "SAO_Hash.lua"), (HISTORY, "SAO_History.lua"),
                       (COND, "SAO_Conditions.lua"), (DISP, "SAO_Disposition.lua"),
                       (COMMAND, "SAO_Command.lua"), (HARNESS, "SAO_Harness.lua"),
                       (VOICE, "SAO_Voice.lua"), (GESTURE, "SAO_Gesture.lua"),
                       (INSPECT, "SAO_Inspect.lua"), (CONTROLLER, "SAO_Controller.lua"),
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

    flat = numbers(value(probe(FLAT)))
    print("     flat: " + " ".join("%s=%s" % kv for kv in flat.items()))
    if flat.get("verdict") != "complies" or flat.get("score") != "0.445" \
            or flat.get("standing") != "0.40" or flat.get("office") != "none":
        faults.append("CAO's tuning invariant does not hold: the default person "
                      "under a peer answered %r" % flat)

    sample = numbers(value(probe(SAMPLE)))
    print("     county: " + " ".join("%s=%s" % kv for kv in sample.items()))
    try:
        for label, want in (("sees_no_standing_in_you", "stranger"),
                            ("their_leader", "leader"),
                            ("does_not_think_much_of_you", "disliked")):
            c, rl, rf, bad, band = (int(x) for x in sample[label].split("/"))
            total = c + rl + rf
            if total != IDS:
                faults.append("%s tallied %d of %d" % (want, total, IDS))
            if want == "leader" and c != IDS:
                faults.append("the leader's word is taken by %d of %d; an office "
                              "at 0.8 alone clears the band" % (c, IDS))
            if want == "disliked" and c != 0:
                faults.append("the disliked stranger's word is taken by %d; at "
                              "standing 0 nobody can clear 0.44" % c)
            if want == "stranger":
                if c == 0 or rl == 0:
                    faults.append("the stranger's word: %d comply, %d reluctant - the "
                                  "axes should spread the county across the bands"
                                  % (c, rl))
                if c / IDS < 0.5:
                    faults.append("the stranger's word is taken by %.0f%%; CAO's "
                                  "tuning makes the default person comply, so most "
                                  "should" % (100 * c / IDS))
            if want != "leader" and bad:
                faults.append("%d people under the %s gave a reason other than "
                              "the one CAO's order names" % (bad, want))
            if band:
                faults.append("%d reluctant verdicts under the %s fell outside "
                              "CAO's 0.34 .. 0.44 band" % (band, want))
    except (KeyError, ValueError):
        faults.append("the county probe did not answer: %r" % sample)

    offices = numbers(value(probe(OFFICES)))
    print("     offices: " + " ".join("%s=%s" % kv for kv in offices.items()))
    want = {"stranger": "0.40/none", "fight": "0.65/proven", "watch": "0.65/proven",
            "medic": "0.40/none", "second": "0.65/second", "chair": "0.80/leader",
            "leader_liked": "1.00/leader", "leader_hated": "0.30/leader"}
    for k, v in want.items():
        if offices.get(k) != v:
            faults.append("office: %s is %s, wanted %s" % (k, offices.get(k), v))

    env = numbers(value(probe(ENVELOPE)))
    print("     envelope: " + " ".join("%s=%s" % kv for kv in env.items()))
    wantE = {"unarmed": "refuses/has_nothing_to_fight_with",
             "child": "refuses/is_too_afraid",
             "ground": "refuses/will_not_walk_onto_someone_else's_ground",
             "believed": "refuses/believes_that_ground_is_somebody's",
             "open": "complies/nil", "hold": "complies/nil"}
    for k, v in wantE.items():
        if env.get(k) != v:
            faults.append("envelope: %s is %s, wanted %s" % (k, env.get(k), v))

    w = numbers(value(probe(WORDS)))
    print("     words: " + " ".join("%s=%s" % kv for kv in w.items()))
    try:
        if int(w["words"]) == 0 or int(w["bad"]) != 0:
            faults.append("%s of %s panel words are not plain" % (w["bad"], w["words"]))
    except (KeyError, ValueError):
        faults.append("the words probe did not answer: %r" % w)

    cmd, hs, vo = read(COMMAND), read(HARNESS), read(VOICE)
    ge, ins, ctl = read(GESTURE), read(INSPECT), read(CONTROLLER)
    asks = hs.count("onYourWord(")
    seams = {
        "the module carries CAO's offices, weights and bands":
            "Cmd.OFFICE = { leader = 0.80, second = 0.65, none = 0.40 }" in cmd
            and "Cmd.COMPLIES_AT = 0.44" in cmd and "Cmd.RELUCTANT_AT = 0.34" in cmd,
        "conformity is read off the initiative axis, inverted":
            "1 - (t.initiative or 0.5)" in cmd,
        "the word comes first, then the envelope":
            "Cmd.obedience(giverKey, id, kind, job)" in cmd
            and "Cmd.envelope(id, kind, arg)" in cmd,
        "the harness routes every ask through the gate (thirteen asks and the wrapper)":
            asks >= 14 and "SAO.Command.order(key, id, kind, arg)" in hs,
        "the chair's call and the crew land through it":
            "\"travel\", { x = gx7, y = gy7 }" in hs and "\"board\",\n" in hs
            and "trust(r8.id, pKey8) >= 0.4" not in hs,
        "the three answers exist and are the player's":
            all(k in vo for k in ("orderYes", "orderGrudging", "orderNo"))
            and "Voice.answer(id, \"orderNo\")" in hs,
        "an answer is seen as well as heard":
            "SAO.Gesture.onEvent(id, event, tick)" in vo.split("function V.answer")[-1],
        "the gesture map carries the three":
            "orderNo = \"negative\"" in ge and "orderGrudging = \"frustrated\"" in ge,
        "the panel says whether they would take your word":
            "on your word: " in ins and "SAO.Command.describe(id, pKey)" in ins,
        "the controller's teaching margin is the module's":
            "SAO.Command.TEACH_MARGIN" in ctl and "theirs33 + 3 then" not in ctl,
        "the architecture names the surface as Standing's":
            "SAO_Command" in read(ARCH),
        "the roadmap marks the slice shipped":
            "SHIPPED as `[C37]`" in read(ROADMAP),
        "the registry records the build under DR-033":
            "[C37]" in read(REGISTRY).split("DR-033")[-1].split("## DR-034")[0],
        "the gate runs this border":
            "tools/command_test.py" in read(CHECK),
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
    print("  111) an order lands through standing: CAO's check on the county's "
          "own standing, refusal with its reason, every ask through the gate")
    return 0


if __name__ == "__main__":
    sys.exit(main())
