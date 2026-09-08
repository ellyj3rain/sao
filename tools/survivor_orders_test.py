#!/usr/bin/env python3
r"""Border 122 - survivor orders use the command check ([C49], DR-033).

[C37] routed the player's asks through SAO_Command and left
survivor-to-survivor orders alone. Three existed and each decided for
itself: the keeper rousing the house (no check at all), a housemate
objecting to someone leaving (its own hardcoded authority test in
SAO_Controller), and an owner telling a trespasser to go (obeyed by
anyone not starving). DR-033 rules out hardcoded authority tables.

This border checks two things.

**SAO_Command reads existing records rather than new constants.**
Three Standing facts became inputs:

  * divided houses - formOf ([B23]) and leansToward ([B24]). In a
    divided house the leader's office does not apply to a member
    leaning the other way, and still applies to members with no lean,
    who are most of the county. secondOf was already nil there, so
    the second needed no change;
  * designations - DR-033 names them alongside houses and leaders.
    The watch has standing in a rousing; a member holding a dealt job
    has standing in that job without a skill comparison;
  * claims - an owner standing on ground they hold has standing in
    the matter of someone leaving it.

Each is worth the same as a proven hand (a second's standing), so no
band, weight or threshold changed.

**All three orders route through the check.** They use one wrapper,
onTheirWord, matching the harness's onYourWord, replying with the
same three lines through the murmur path. The hardcoded test is gone:
no heavyVoice, no leader-plus-trust threshold, no house-form test
outside SAO_Command.

Runs in the engine's VM (tools/luacheck/LuaRun) over Border 105's
stub county with a stub Standing installed and the real disposition
loaded - the same instrument Border 111 uses. An optional argv[1]
points the checker at another tree root, which is how its control
runs: the pre-batch tree fails every seam.
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
CONTROLLER = CLIENT / "SAO_Controller.lua"
HARNESS = CLIENT / "SAO_Harness.lua"
REGISTRY = ROOT / "DECISION_REGISTRY.md"
ROADMAP = ROOT / "ROADMAP.md"
CHECK = ROOT / "tools" / "check.sh"
PRELUDE = HERE / "luacheck" / "probe_age.lua"
SRC = HERE / "luacheck" / "LuaRun.java"
OUT = ROOT / "java" / "out" / "luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"

IDS = 4000

# A Standing the command surface can read: houses, leaders, seconds,
# chairs, trust, house form, which way one member leans, whose claim
# covers a square, and the designation the house dealt. Nobody has a
# body: every value this border checks is read from records.
STUB = (
    "local trustT, groups, leaders, chairs, seconds = {}, {}, {}, {}, {} "
    "local forms, leans, claims, desig = {}, {}, {}, {} "
    "SAO.Standing.trust = function(id, key) return trustT[id] and trustT[id][key] or 0 end "
    "SAO.Standing.groupOf = function(id) return groups[id] end "
    "SAO.Standing.leaderOf = function(g) return leaders[g] end "
    "SAO.Standing.playerChairOf = function(g) return chairs[g] end "
    "SAO.Standing.secondOf = function(g) if forms[g] ~= 'ladder' then return nil end return seconds[g] end "
    "SAO.Standing.formOf = function(g) return forms[g] or 'empty' end "
    "SAO.Standing.leansToward = function(id) return leans[id] end "
    "SAO.Standing.insideClaim = function(id, x, y) local c = claims[id] "
    "return c ~= nil and x >= c[1] and x <= c[3] and y >= c[2] and y <= c[4] end "
    "SAO.Standing.isPlayerKey = function(k) return string.sub(tostring(k), 1, 7) == 'player:' end "
    "SAO.Standing.playerKey = function(b) return 'player:me' end "
    "SAO.Standing.mayEnter = function() return true end "
    "SAO.Standing.isHostileTo = function() return false end "
    "SAO.Identity = { get = function(k) if desig[k] then return { designation = desig[k] } end return nil end } "
    "SAO.Body = { get = function(id) return nil end } "
    "SAO.Controller = { agents = {}, tick = function() return 1000 end } "
    "SAO.Perception = { believesClaimed = function() return nil end, "
    "nearestBelievedZombie = function() return nil end, believedThreatCount = function() return 1 end } "
    "SAO.Census.JOB_PERK = { forager = 'Foraging', medic = 'Doctor', watch = 'Aiming', "
    "scout = 'Lightfooted', cook = 'Cooking' } "
    "SAO.Census.skillOf = function() return 0 end "
    "getSpecificPlayer = function(n) return nil end "
    "Perks = {} "
    "local Cmd = SAO.Command local me = 'player:me' "
    "local function setTrust(id, giver, v) trustT[id] = trustT[id] or {} trustT[id][giver] = v end ")


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


# One leader and four members. An undivided house gives its leader the
# office over everyone. A divided one withholds it from members leaning
# the other way and keeps it over members with no lean and members on
# the leader's side. The chair is checked alongside the leader, because
# the player sits in it and the same fact governs the player's orders.
DIVIDED = (
    "(function() " + STUB +
    "local out = {} local g = 'h' local lead = 'sao-1' "
    "groups['sao-2'] = g groups['sao-3'] = g groups['sao-4'] = g groups[lead] = g "
    "leans[lead] = 'wall' leans['sao-2'] = 'wall' leans['sao-3'] = 'road' "
    "local function o(who, id) return Cmd.officeOf(who, id) end "
    "forms[g] = 'ladder' leaders[g] = lead "
    "out[#out + 1] = 'ladder_same=' .. o(lead, 'sao-2') "
    "out[#out + 1] = 'ladder_other=' .. o(lead, 'sao-3') "
    "out[#out + 1] = 'ladder_none=' .. o(lead, 'sao-4') "
    "seconds[g] = 'sao-2' out[#out + 1] = 'ladder_second=' .. o('sao-2', 'sao-3') "
    "forms[g] = 'divided' "
    "out[#out + 1] = 'divided_same=' .. o(lead, 'sao-2') "
    "out[#out + 1] = 'divided_other=' .. o(lead, 'sao-3') "
    "out[#out + 1] = 'divided_none=' .. o(lead, 'sao-4') "
    "out[#out + 1] = 'divided_second=' .. o('sao-2', 'sao-3') "
    "leaders[g] = nil chairs[g] = me leans[me] = 'wall' "
    "out[#out + 1] = 'divided_chair_same=' .. o(me, 'sao-2') "
    "out[#out + 1] = 'divided_chair_other=' .. o(me, 'sao-3') "
    "leans[me] = nil "
    "out[#out + 1] = 'divided_chair_unread=' .. o(me, 'sao-3') "
    "return table.concat(out, ' ') end)()")

# Matter standing, where no office applies: the watch in a rousing, a
# dealt job in that job, a claim in the matter of leaving it. Each is
# worth a second's standing, the same value a proven hand already had,
# so no new band enters the check.
MATTER = (
    "(function() " + STUB +
    "local out = {} local id = 'sao-9' "
    "local function st(who, kind, arg) local s, o = Cmd.standingOf(who, id, kind, arg) "
    "return string.format('%.2f', s) .. '/' .. o end "
    "out[#out + 1] = 'nobody_rouse=' .. st('sao-2', 'rouse', nil) "
    "desig['sao-2'] = 'watch' out[#out + 1] = 'watch_rouse=' .. st('sao-2', 'rouse', nil) "
    "out[#out + 1] = 'watch_walk=' .. st('sao-2', 'walk', nil) "
    "desig['sao-3'] = 'medic' "
    "out[#out + 1] = 'medic_own=' .. st('sao-3', 'work', 'medic') "
    "out[#out + 1] = 'medic_other=' .. st('sao-3', 'work', 'cook') "
    "claims['sao-4'] = { 10, 10, 20, 20 } "
    "out[#out + 1] = 'owner_on=' .. st('sao-4', 'leave', { x = 15, y = 15 }) "
    "out[#out + 1] = 'owner_off=' .. st('sao-4', 'leave', { x = 90, y = 90 }) "
    "out[#out + 1] = 'nobody_leave=' .. st('sao-5', 'leave', { x = 15, y = 15 }) "
    "out[#out + 1] = 'no_ground=' .. st('sao-4', 'leave', nil) "
    "return table.concat(out, ' ') end)()")

# The county sampled under the three orders. The watch's rousing is
# obeyed more than an ordinary housemate's, the owner's order off their
# own claim more than a stranger's order about nothing, and an owner
# the county despises is mostly refused.
SAMPLE = (
    "(function() " + STUB + "local out = {} "
    "local function tally(label, kind, arg, setup) local c, rl, rf = 0, 0, 0 "
    "for i = 1, %d do local id = 'sao-' .. i setup(id) "
    "local v = Cmd.obedience('sao-keeper', id, kind, arg) "
    "if v == 'complies' then c = c + 1 elseif v == 'reluctant' then rl = rl + 1 else rf = rf + 1 end end "
    "out[#out + 1] = string.format('%%s=%%d/%%d/%%d', label, c, rl, rf) end "
    "tally('peer', 'rouse', nil, function(id) end) "
    "desig['sao-keeper'] = 'watch' "
    "tally('watch', 'rouse', nil, function(id) end) "
    "desig['sao-keeper'] = nil claims['sao-keeper'] = { 0, 0, 50, 50 } "
    "tally('ground', 'leave', { x = 5, y = 5 }, function(id) end) "
    "tally('hated', 'leave', { x = 5, y = 5 }, function(id) setTrust(id, 'sao-keeper', -1) end) "
    "return table.concat(out, ' ') end)()" % IDS)


def main():
    faults = []
    print("=" * 74)
    print("SURVIVOR ORDERS USE THE COMMAND CHECK")
    print("=" * 74)
    for path, what in ((COMMAND, "SAO_Command.lua"),
                       (CONTROLLER, "SAO_Controller.lua"),
                       (HARNESS, "SAO_Harness.lua"), (PRELUDE, "the probe")):
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
        print("  122) survivor orders use the command check: SKIPPED, the engine install is absent")
        return 0
    if not build():
        print("  FAULT: LuaRun does not compile against the installed jar")
        return 1

    div = numbers(value(probe(DIVIDED)))
    print("     divided: " + " ".join("%s=%s" % kv for kv in div.items()))
    wantD = {"ladder_same": "leader", "ladder_other": "leader",
             "ladder_none": "leader", "ladder_second": "second",
             "divided_same": "leader", "divided_other": "none",
             "divided_none": "leader", "divided_second": "none",
             "divided_chair_same": "leader", "divided_chair_other": "none",
             "divided_chair_unread": "leader"}
    for k, v in wantD.items():
        if div.get(k) != v:
            faults.append("divided house: %s is %s, wanted %s"
                          % (k, div.get(k), v))

    mat = numbers(value(probe(MATTER)))
    print("     matter: " + " ".join("%s=%s" % kv for kv in mat.items()))
    wantM = {"nobody_rouse": "0.40/none", "watch_rouse": "0.65/proven",
             "watch_walk": "0.40/none", "medic_own": "0.65/proven",
             "medic_other": "0.40/none", "owner_on": "0.65/proven",
             "owner_off": "0.40/none", "nobody_leave": "0.40/none",
             "no_ground": "0.40/none"}
    for k, v in wantM.items():
        if mat.get(k) != v:
            faults.append("matter standing: %s is %s, wanted %s"
                          % (k, mat.get(k), v))

    sample = numbers(value(probe(SAMPLE)))
    print("     county: " + " ".join("%s=%s" % kv for kv in sample.items()))
    try:
        peer = [int(x) for x in sample["peer"].split("/")]
        watch = [int(x) for x in sample["watch"].split("/")]
        ground = [int(x) for x in sample["ground"].split("/")]
        hated = [int(x) for x in sample["hated"].split("/")]
        for label, row in (("peer", peer), ("watch", watch),
                           ("ground", ground), ("hated", hated)):
            if sum(row) != IDS:
                faults.append("the %s tally counted %d of %d"
                              % (label, sum(row), IDS))
        if watch[0] <= peer[0]:
            faults.append("the watch's rousing is obeyed by %d and an "
                          "ordinary housemate's by %d; the designation adds "
                          "nothing" % (watch[0], peer[0]))
        if watch[2] != 0:
            faults.append("%d refuse the watch outright; a second's standing "
                          "alone clears the band" % watch[2])
        if ground[0] <= peer[0]:
            faults.append("the owner's order off their own claim is obeyed by "
                          "%d and a stranger's order about nothing by %d; the "
                          "claim adds nothing" % (ground[0], peer[0]))
        # A despised owner keeps the claim and loses the trust term:
        # standing 0.65 shaded by trust -1 is 0.15, which most of the
        # county cannot clear and a very deferential few still can. So
        # the assertion is the distribution, not a zero.
        if hated[2] <= IDS // 2:
            faults.append("only %d of %d refuse an owner they despise; "
                          "trust at -1 should carry most of the county "
                          "below the band" % (hated[2], IDS))
        if hated[0] >= IDS // 20:
            faults.append("%d of %d still obey an owner they despise; a "
                          "claim gives standing, not automatic compliance"
                          % (hated[0], IDS))
        if peer[2] == 0 or peer[1] == 0:
            faults.append("a peer's order is never refused and never "
                          "grudging (%d/%d/%d); the county should spread "
                          "across the bands" % tuple(peer))
    except (KeyError, ValueError):
        faults.append("the county probe did not answer: %r" % sample)

    cmd, ctl, hs = read(COMMAND), read(CONTROLLER), read(HARNESS)
    seams = {
        "SAO_Command knows the two controller-only kinds":
            '"rouse"' in cmd and '"leave"' in cmd
            and '"work", "engage", "rouse", "leave" }' in cmd,
        "the divided-house test lives in SAO_Command":
            "function Cmd.leansAway(group, id, giverKey)" in cmd
            and "if Cmd.leansAway(group, id, giverKey) then return \"none\" end" in cmd,
        "the designation and the claim are read from records":
            "designationOf(giverKey) == \"watch\"" in cmd
            and "SAO.Standing.insideClaim(giverKey, arg.x, arg.y)" in cmd
            and "designationOf(giverKey) == arg" in cmd,
        "matter standing reuses the proven-hand value, adding no threshold":
            cmd.count("Cmd.OFFICE.second") == 1
            and "Cmd.COMPLIES_AT = 0.44" in cmd
            and "Cmd.RELUCTANT_AT = 0.34" in cmd,
        "SAO_Controller has its own onYourWord equivalent":
            "local function onTheirWord(giverId, id, kind, arg, act)" in ctl
            and "SAO.Command.order(giverId, id, kind, arg)" in ctl,
        # The same three lines through the other entry point.
        # V.answer skips the talkativeness cooldown because a click
        # deserves a reply ([B46], Border 46); the tick loop must not
        # have that exemption or quiet survivors stop being quiet. A
        # taciturn survivor refuses silently and is still seen to,
        # because onEvent raises the gesture.
        "replies use the same three lines through V.onEvent":
            "SAO.Voice.onEvent(id, \"orderNo\", tickCount)" in ctl
            and "SAO.Voice.onEvent(id, \"orderGrudging\", tickCount)" in ctl
            and "SAO.Voice.answer(id, \"orderNo\")" in hs
            and "SAO.Voice.answer(id, \"orderNo\")" not in ctl,
        "the keeper's rousing is checked and seeing someone flee is not":
            "rouseCompany(id, kBody, id .. \" wakes the house\", true)" in ctl
            and "rouseCompany(id, fleeBody)" in ctl
            and "onTheirWord(id, otherId, \"rouse\", nil, nil)" in ctl,
        "a warning that landed skips the check":
            "local landed = SAO.Perception.tell(id, otherId, tickCount)" in ctl
            and "if spoken and not (type(landed) == \"number\"" in ctl,
        "the objection goes through SAO_Command":
            "onTheirWord(objector, id," in ctl and "\"hold\", nil, nil) then" in ctl,
        "the hardcoded authority test is deleted":
            "heavyVoice" not in ctl and "local sameSide" not in ctl
            and "local formHV" not in ctl,
        "no authority test remains in SAO_Controller":
            not re.search(r"leaderOf\([^)]*\)\s*==\s*\w+\s*$", ctl, re.M)
            and "trust(id, objector)\n" not in ctl,
        "the trespass order goes through SAO_Command":
            "onTheirWord(id, trespasserId," in ctl
            and "\"leave\"," in ctl and "if heeds then" in ctl
            and "if not desperate then" not in ctl,
        "onTheirWord is called exactly three times":
            ctl.count("onTheirWord(") == 4,
        "the registry records the build under DR-033":
            "[C49]" in read(REGISTRY).split("DR-033")[-1].split("## DR-034")[0],
        "the roadmap records the slice as shipped":
            "SHIPPED as `[C49]`" in read(ROADMAP),
        "the gate runs this border":
            "tools/survivor_orders_test.py" in read(CHECK),
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
    print("  122) survivor orders use the command check: orders between "
          "survivors go through SAO_Command, reading divided houses, "
          "designations and claims; no hardcoded authority test")
    return 0


if __name__ == "__main__":
    sys.exit(main())
