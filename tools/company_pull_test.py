#!/usr/bin/env python3
r"""Border 152 - need stands alongside trust ([C111]).

The operator's ruling (2026-09-12, on the queue's item 3): a road
meeting is worth more, most people not only want but NEED to be
around people, and trust is not always the principal determinant of
whether a group forms - which depends on how far along into the
apocalypse the world is. Until that batch every formation gate read
trust alone, and with a meeting worth 0.005 the company line was two
hundred meetings off: a house could only ever grow out of trust
settled at genesis, and nobody lonely ever founded anything.

The law this border holds, from both sides:

  * The pull is three factors the county already holds - appetite
    (who somebody is), isolation (where they are right now), and
    openness (how far the county's condition makes company a need
    rather than a risk, months since the fall over a horizon of six
    - the one number here that is not already the county's, stated
    so the operator can move it; [C115] made the move real, and the
    horizon and the meeting's worth are the operator's dials now,
    each default the ruled figure).
  * Need substitutes for trust not yet built; it NEVER cancels trust
    already spent against somebody - the pull reads only where trust
    is not negative.
  * Zero whenever any factor cannot be read - offline, a bare VM, a
    dead or unknown id - so every gate degrades to trust alone,
    which is the law that ran before.
  * Every company door reads the pair standing - the road, the
    table, the companion seam, the player's own asks - and
    temperament still gates after the line clears; need does not
    overrule temperament.
  * Read once a county hour and held; a person's need does not
    change inside one.

The [C111] batch record closed with: "A border for this law belongs
to the end pass with the rest of the deferred verification; none was
written here, per the standing order." This is that border. The
arithmetic is MEASURED, not described: the VM runs the shipped
Standing behind the real sweep prelude, holds the isolation surface
the way a fixture holds a position, and steps the county's condition
through the split clock's own seam (recordDay - the fact clockMonths
reads).

The loaded conversation also runs here: delivered company may change home
coordinates, but moving into an unclaimed home creates no ownership. Actual
anchor claims retain their bounds, existing claims survive an unclaimed move,
and refusal changes neither home nor ownership. The production Exchange,
Standing, Organization and Communication modules run together in Kahlua;
source controls must fail the named behavioral checks.

An optional argv[1] points the checker at another tree root, which
is how its control runs.
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
CHECK = ROOT / "tools" / "check.sh"
SRC = HERE / "luacheck" / "LuaRun.java"
OUT = ROOT / "java" / "out" / "luacheck"
PRELUDE_FILE = ROOT / "tools" / "sweep" / "prelude.lua"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"

# The dormant county's own module set - what carries Standing and the
# history it reads. The same set Border 147 runs.
MODULES = [
    "shared/SAO_Log.lua", "shared/SAO_Hash.lua", "shared/SAO_Rand.lua",
    "shared/SAO_Census.lua", "shared/SAO_History.lua",
    "shared/SAO_Disposition.lua", "shared/SAO_Conditions.lua",
    "shared/SAO_Habits.lua", "shared/SAO_Claims.lua", "shared/SAO_Identity.lua",
    "shared/SAO_Lessons.lua", "shared/SAO_WorldKnowledge.lua", "shared/SAO_Knowledge.lua",
    "shared/SAO_Seams.lua", "shared/SAO_Standing.lua",
    "shared/SAO_Perception.lua", "shared/SAO_Places.lua",
    "client/SAO_Age.lua", "client/SAO_Telemetry.lua",
    "shared/SAO_PhysicalFacts.lua",
    "client/SAO_PopulationAdmissions.lua",
    "client/SAO_PopulationRepresentation.lua",
    "client/SAO_DormantPopulation.lua",
    "client/SAO_Population.lua",
]

PROBE = r"""(function()
  -- People are created in the county the prelude runs, exactly as
  -- the dump would see them, before anything is pinned; no pass runs
  -- in this probe, the pull and the standing are read directly.
  local function make(x, y)
    local r = SAO.Identity.create(nil, nil, x, y, 0)
    pcall(function() SAO.History.generate(r.id, r) end)
    return r
  end
  local me = make(10500, 9000)
  local mate = make(10503, 9000)
  local hermit = make(10600, 9100)
  local half = make(10600, 9200)
  local stranger = make(10700, 9300)

  -- The county's condition is stepped through its own seam: the
  -- split clock ([C61]) reads recordDay, so recordDay is what this
  -- probe holds - a fixture controlling the fact, not the formula.
  -- The isolation surface is held the way a fixture holds a
  -- position: per-person readings, pinned to the numbers this
  -- border measures, and nil for an id the county cannot read.
  _G.__months = 6
  SAO.History.recordDay = function()
    return (_G.__months or 6) * 30.0
  end
  SAO.Isolation = {
    of = function(id)
      if id == me.id then
        return { appetite = 0.8, isolation = 1.0 }
      elseif id == hermit.id then
        return { appetite = 0.1, isolation = 1.0 }
      elseif id == half.id then
        return { appetite = 0.8, isolation = 0.5 }
      end
      return nil
    end,
  }
  local function nextHour()
    _G.__hours = (_G.__hours or 0) + 1.0
  end

  local S = SAO.Standing
  -- Six months into collapse: openness is the whole horizon.
  local pullFull = S.companyPull(me.id)            -- 0.8
  local pullHermit = S.companyPull(hermit.id)      -- 0.1
  local pullHalf = S.companyPull(half.id)          -- 0.4
  -- The condition changes inside one county hour and the pull is
  -- held - a person's need does not change inside one.
  _G.__months = 3
  local memoHeld = S.companyPull(me.id)            -- 0.8 still
  nextHour()
  local pullHalved = S.companyPull(me.id)          -- 0.4

  -- Back at the horizon's end, in its own county hour (the memo
  -- above is doing its job, so the door readings must not borrow the
  -- months-3 hour's pull). The standing a company door reads: trust
  -- toward a mate, plus the pull. A fifth of trust and a
  -- four-fifths need is a whole line.
  nextHour()
  _G.__months = 6
  S.adjustTrust(me.id, mate.id, 0.2)
  local standCarry = S.companyStanding(me.id, mate.id)
  local bar = 0.5
  pcall(function()
    bar = tonumber(SandboxVars.SurvivorAwareness.TrustToCompany) or 0.5
  end)
  local doorYes = standCarry >= bar and 1 or 0
  -- No trust at all toward a stranger: need alone at the door, and
  -- a fully isolated sociable person's need carries the whole line.
  local standAlone = S.companyStanding(me.id, stranger.id)
  local doorAlone = standAlone >= bar and 1 or 0
  -- A quarrel, struck in one stroke so the arithmetic is exact:
  -- trust already spent against somebody. Need is standing right
  -- there at 0.8 and must not soften a word of it.
  S.adjustTrust(me.id, half.id, -0.4)
  local standQuarrel = S.companyStanding(me.id, half.id)
  -- An id the county cannot read: zero, which degrades every gate
  -- to trust alone - and trust toward an unknown is honestly zero.
  local pullUnknown = S.companyPull("nobody")
  local standUnknown = S.companyStanding("nobody", mate.id)

  -- An ordinary county, before the fall has had time to make company
  -- a need: the pull carries nobody, and the standing is the
  -- acquaintance and nothing else.
  nextHour()
  _G.__months = 0
  local pullBefore = S.companyPull(me.id)
  S.adjustTrust(me.id, stranger.id, 0.15)
  local standBefore = S.companyStanding(me.id, stranger.id)
  -- The memo holds this side of the clock too.
  _G.__months = 6
  local memoAfter = S.companyPull(me.id)

  return "pullFull=" .. tostring(pullFull)
    .. " pullHermit=" .. tostring(pullHermit)
    .. " pullHalf=" .. tostring(pullHalf)
    .. " memoHeld=" .. tostring(memoHeld)
    .. " pullHalved=" .. tostring(pullHalved)
    .. " standCarry=" .. tostring(standCarry)
    .. " doorYes=" .. tostring(doorYes)
    .. " standAlone=" .. tostring(standAlone)
    .. " doorAlone=" .. tostring(doorAlone)
    .. " standQuarrel=" .. tostring(standQuarrel)
    .. " pullUnknown=" .. tostring(pullUnknown)
    .. " standUnknown=" .. tostring(standUnknown)
    .. " pullBefore=" .. tostring(pullBefore)
    .. " standBefore=" .. tostring(standBefore)
    .. " memoAfter=" .. tostring(memoAfter)
end)()"""


MOVE_IN_MODULES = MODULES[:MODULES.index("shared/SAO_Standing.lua") + 1] + [
    "shared/SAO_Perception.lua", "shared/SAO_Organization.lua",
    "shared/SAO_Communication.lua",
]

MOVE_IN_PROBE = r'''(function()
  local S, Org = SAO.Standing, SAO.Organization
  local checks, bodies, readings, voices = {}, {}, {}, {}
  local function check(name, value)
    if value ~= true then error("MOVE_IN_CHECK:" .. name) end
    checks[#checks + 1] = name
  end
  local function count(rows)
    local n = 0
    for _ in pairs(rows or {}) do n = n + 1 end
    return n
  end
  local function sameClaim(actual, expected)
    return actual ~= nil and expected ~= nil
      and actual.minX == expected.minX and actual.minY == expected.minY
      and actual.maxX == expected.maxX and actual.maxY == expected.maxY
      and actual.z == expected.z
  end
  local function home(rec)
    return { homeX=rec.homeX, homeY=rec.homeY, homeZ=rec.homeZ }
  end
  local function sameHome(a, b)
    return a.homeX == b.homeX and a.homeY == b.homeY and a.homeZ == b.homeZ
  end
  _G.__hours = 240
  -- Fixtures hold physical access, current personal needs, and voice output.
  -- Company choice, delivery, roster, bond and claim writes are production.
  SAO.Controller = { agents={} }
  SAO.Body = { active=bodies, get=function(id) return bodies[id] end,
    hasRepresentation=function(id) return bodies[id] ~= nil end }
  SAO.Isolation = { of=function(id) return readings[id] end }
  SAO.Needs = { read=function() return { hunger=0, thirst=0 } end }
  SAO.Gesture = { meet=function() end }
  SAO.Voice = { onEvent=function(id, event)
    local key = id .. ":" .. event
    voices[key] = (voices[key] or 0) + 1
  end }
  SAOJavaBridge.canConverseNow = function(self, a, b, reach)
    return a ~= nil and b ~= nil and a.z == b.z
      and (a.x-b.x)^2 + (a.y-b.y)^2 <= reach^2
  end
  SAOJavaBridge.buildingBoundsAt = function() return nil end
  local function make(prefix)
    local a = SAO.Identity.ensure(prefix .. "-a", prefix, "Anchor", 42, 43, 0)
    local b = SAO.Identity.ensure(prefix .. "-z", prefix, "Mover", 44, 43, 0)
    a.homeX, a.homeY, a.homeZ = 111.25, 117.75, 2
    b.homeX, b.homeY, b.homeZ = 321.5, 335.25, 0
    for _, rec in ipairs({a, b}) do
      bodies[rec.id] = { id=rec.id, x=rec.x, y=rec.y, z=rec.z }
      readings[rec.id] = { appetite=1, experiencedContact=1, isolation=0 }
      -- These future cooldowns keep unrelated item requests out of the case.
      SAO.Controller.agents[rec.id] = { state="IDLE", nextShareAt=1e9,
        nextBarterAt=1e9, nextSmokeShareAt=1e9, nextElectionAt=1e9 }
    end
    S.adjustTrust(a.id, b.id, 0.8)
    S.adjustTrust(b.id, a.id, 0.8)
    return a, b
  end
  local function exchange(a, b)
    SAO.Exchange.betweenPair(a.id, SAO.Controller.agents[a.id],
      bodies[a.id], b.id, bodies[b.id], 100)
  end
  local function delivered(a, b)
    local p = Org.latestMatter(a.id, "company-formation")
    local row = p and p.participants[b.id]
    local key = p and tostring(p.revision)
    local response = row and row.responses[key]
    local reception = row and row.receptions[key]
    return S.sameGroup(a.id, b.id) and reception ~= nil
      and reception.channel == "spoken" and response ~= nil
      and response.response == "accept" and response.delivered == true
      and Org.activeCommitment(b.id, "company-formation") ~= nil
  end

  local a, b = make("unclaimed")
  check("fixture_existing_bond", S.bond(a.id, b.id) == true)
  exchange(a, b)
  check("unclaimed_delivered_agreement", delivered(a, b))
  check("unclaimed_home", sameHome(b, a))
  check("unclaimed_no_ownership", count(S.allPersonalClaims()) == 0
    and count(ModData.getOrCreate("SurvivorAwareness_Standing").groupClaims) == 0
    and count(Org.claims) == 0)
  check("unclaimed_movein_voices", voices[a.id .. ":movein"] == 1
    and voices[a.id .. ":company"] == 1)
  check("unclaimed_bond_preserved", S.isBondedTo(a.id, b.id)
    and S.isBondedTo(b.id, a.id))

  a, b = make("claimed")
  local bounds = { minX=80, minY=90, maxX=125, maxY=140, z=3 }
  S.claim(a.id, bounds.minX, bounds.minY, bounds.maxX, bounds.maxY, bounds.z)
  local anchorClaim = S.claimOf(a.id)
  exchange(a, b)
  check("claimed_delivered_agreement", delivered(a, b))
  check("claimed_home", sameHome(b, a))
  check("actual_claim_bounds", sameClaim(S.claimOf(b.id), bounds))
  check("anchor_claim_unchanged", S.claimOf(a.id) == anchorClaim
    and sameClaim(anchorClaim, bounds))

  a, b = make("existing")
  local old = { minX=600, minY=700, maxX=650, maxY=760, z=1 }
  S.claim(b.id, old.minX, old.minY, old.maxX, old.maxY, old.z)
  S.claim("unrelated-owner", 1000, 1000, 1001, 1005, 0)
  local moverClaim, unrelated = S.claimOf(b.id), S.claimOf("unrelated-owner")
  local claimCount = count(S.allPersonalClaims())
  exchange(a, b)
  check("existing_delivered_agreement", delivered(a, b))
  check("existing_home", sameHome(b, a))
  check("existing_mover_claim_preserved", S.claimOf(b.id) == moverClaim
    and sameClaim(moverClaim, old))
  check("unrelated_claim_preserved", S.claimOf("unrelated-owner") == unrelated
    and count(S.allPersonalClaims()) == claimCount and S.claimOf(a.id) == nil)

  a, b = make("refused")
  S.claim(a.id, 1, 2, 3, 4, 0)
  S.claim(b.id, 8, 9, 10, 12, 1)
  local aHome, bHome = home(a), home(b)
  local aClaim, bClaim = S.claimOf(a.id), S.claimOf(b.id)
  -- The recipient wants space: real Standing pressure exceeds their trust.
  readings[b.id] = { appetite=0, experiencedContact=1, isolation=0 }
  check("fixture_personal_refusal", S.circleRefuses(b.id,
    "company-" .. a.id, a.id) == true)
  exchange(a, b)
  check("refusal_answered", voices[b.id .. ":ownCompany"] == 1
    and not S.sameGroup(a.id, b.id)
    and Org.latestMatter(a.id, "company-formation") == nil)
  check("refusal_home_unchanged", sameHome(a, aHome) and sameHome(b, bHome))
  check("refusal_claims_unchanged", S.claimOf(a.id) == aClaim
    and S.claimOf(b.id) == bClaim and voices[a.id .. ":movein"] == nil)
  return "PASS " .. tostring(#checks) .. " " .. table.concat(checks, " ")
end)()'''

# Mutation anchors select production statements; the Kahlua checks, not text
# absence, decide whether the changed behavior is caught.
CLAIM_COPY = """                        SAO.Standing.claim(moverId, ac.minX, ac.minY,
                            ac.maxX, ac.maxY, ac.z or 0)"""
OLD_GROUND_FALLBACK = """
                    else
                        local mnX, mnY, mxX, mxY =
                            SAO.Standing.groundAround(
                                SAO.Body.get(anchorId),
                                anchorRec.homeX, anchorRec.homeY, 4)
                        SAO.Standing.claim(moverId, mnX, mnY, mxX, mxY,
                            anchorRec.homeZ or 0)"""
MOVE_IN_CONTROLS = (
    ("restored_ground_fallback", CLAIM_COPY, CLAIM_COPY + OLD_GROUND_FALLBACK,
     "unclaimed_no_ownership"),
    ("lost_actual_claim", CLAIM_COPY, "                        local unchanged = true",
     "actual_claim_bounds"),
    ("erased_existing_claim", CLAIM_COPY,
     CLAIM_COPY + "\n                    else\n                        SAO.Standing.releaseClaim(moverId)",
     "existing_mover_claim_preserved"),
    ("lost_home_update", "                moverRec.homeX = anchorRec.homeX",
     "                moverRec.homeX = moverRec.homeX", "unclaimed_home"),
)


def build(output=OUT):
    cls = output / "LuaRun.class"
    if cls.exists() and cls.stat().st_mtime >= SRC.stat().st_mtime:
        return True
    output.mkdir(parents=True, exist_ok=True)
    done = subprocess.run(
        [str(JDK / "javac.exe"), "-cp", str(PZ), "-d", str(output), str(SRC)],
        capture_output=True, text=True, timeout=300)
    return done.returncode == 0


def probe(expr, classes=OUT):
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(STDLIB, work / "stdlib.lua")
        for c in classes.glob("*.class"):
            shutil.copy2(c, work / c.name)
        prelude = work / "prelude.lua"
        prelude.write_text(PRELUDE_FILE.read_text(encoding="utf-8"),
                           encoding="utf-8")
        args = [str(JDK / "java.exe"), "-cp", "%s;." % PZ, "LuaRun",
                str(prelude)]
        args += [str(LUA / m) for m in MODULES if (LUA / m).exists()]
        args += ["--", expr]
        done = subprocess.run(args, cwd=str(work), capture_output=True,
                              text=True, timeout=900)
    out = done.stdout or ""
    at = out.find("VALUE ")
    if at < 0:
        return "ERROR " + (out + (done.stderr or "")).strip()[-400:]
    return out[at + 6:].strip().split("\n")[0]


def move_in_checks(source, classes):
    """Production conversation and ownership, with private compiled helpers."""
    faults = []
    with tempfile.TemporaryDirectory(prefix="sao-company-movein-") as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(STDLIB, work / "stdlib.lua")
        for compiled in classes.glob("LuaRun*.class"):
            shutil.copy2(compiled, work / compiled.name)
        (work / "prelude.lua").write_text(read(PRELUDE_FILE), encoding="utf-8")
        (work / "probe.lua").write_text("__result = " + MOVE_IN_PROBE,
                                       encoding="utf-8")

        def run(text):
            (work / "exchange.lua").write_text(text, encoding="utf-8")
            args = [str(JDK / "java.exe"), "-cp", "%s;." % PZ, "LuaRun",
                    str(work / "prelude.lua")]
            args += [str(LUA / module) for module in MOVE_IN_MODULES]
            args += [str(work / "exchange.lua"), str(work / "probe.lua"),
                     "--", "__result"]
            result = subprocess.run(args, cwd=work, capture_output=True,
                                    text=True, timeout=180)
            return result.returncode, (result.stdout or "") + (result.stderr or "")

        code, output = run(source)
        if code or "VALUE PASS 18 " not in output:
            return ["production move-in probe failed: " + output[-1800:]]
        print("  PASS production Exchange/Standing/Organization/Communication: "
              "4 move-in cases, 18 checks")
        for name, old, new, reason in MOVE_IN_CONTROLS:
            if source.count(old) != 1:
                faults.append("move-in control seam differs: " + name)
                continue
            code, output = run(source.replace(old, new))
            if not code or "MOVE_IN_CHECK:" + reason not in output:
                faults.append("move-in control did not fail for " + reason
                              + ": " + output[-1800:])
            else:
                print("  PASS rejected " + name + ": " + reason)
    return faults


def numbers(line):
    return {k: v for k, v in re.findall(r"([\w.]+)=([-\w./:' ]+?)(?=\s\w+=|$)",
                                        line or "")}


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") \
        if path.exists() else ""


def main():
    faults = []
    print("=" * 74)
    print("NEED STANDS ALONGSIDE TRUST")
    print("=" * 74)

    standing = read(LUA / "shared" / "SAO_Standing.lua")
    population = read(LUA / "client" / "SAO_DormantPopulation.lua")
    controller = read(LUA / "client" / "SAO_Controller.lua")
    harness = read(LUA / "client" / "SAO_Harness.lua")
    exchange = read(LUA / "client" / "SAO_Exchange.lua")

    seams = {
        "the pull reads the live isolation surface, not a static factor":
            "SAO.Isolation.of(id)" in standing,
        # [C115] The move [C111] stated is real now: the horizon is
        # the operator's dial, read with the ruled half year as the
        # fallback (also the declared default), and the openness
        # divides by what was read, not by a hardcoded six.
        "the horizon is the operator's dial, the ruled half year its default":
            "tonumber(sv.OpennessHorizonMonths)) or 6.0" in standing
            and "months / horizon" in standing
            and "months / 6.0" not in standing,
        "need never cancels trust already spent":
            "if t < 0 then return t end" in standing,
        "the pull is read once a county hour and held":
            "if hour ~= pullHour then" in standing,
        # [C115] Same graduation: what a road meeting is worth is the
        # RoadMeetingWorth dial now (the number the operator's own
        # ruling moved from 0.005 to 0.02), read per meeting with the
        # ruled figure as the fallback, applied both ways.
        "a road meeting is worth more, both ways":
            "tonumber(sv.RoadMeetingWorth)) or 0.02" in population
            and population.count("adjustTrust(idA, idB, roadTrust())") == 1
            and population.count("adjustTrust(idB, idA, roadTrust())") == 1,
        "the road reads the pair standing":
            population.count("companyStanding(") >= 3,
        "the companion seam reads the pair standing":
            controller.count("companyStanding(") >= 1,
        "the player's own asks read the pair standing":
            harness.count("companyStanding(") >= 1,
        "the table reads the pair standing, both sides":
            exchange.count("companyStanding(") >= 2,
        "temperament still gates company after the line clears":
            population.count("circleRefuses") >= 1,
        "the gate runs this border":
            "tools/company_pull_test.py" in read(CHECK),
    }

    if not (JDK.exists() and PZ.exists() and STDLIB.exists()
            and SRC.exists()):
        print("  SKIPPED the VM - no JDK, engine jar, stdlib or runner")
        print()
        for k, v in seams.items():
            print("  %s  %s" % ("yes" if v else "NO ", k))
            if not v:
                faults.append(k)
        print()
        if faults:
            print("VERDICT: FAIL")
            return 1
        print("  152) need stands alongside trust: TEXT ONLY, the "
              "engine install is absent")
        return 0
    # Border 152 owns its compiler output. Other checkers import the legacy
    # build/probe defaults, so keep that API while this executable uses a
    # private lifetime and cannot race their shared helper.
    with tempfile.TemporaryDirectory(prefix="sao-company-pull-runner-") as tmp:
        classes = pathlib.Path(tmp)
        if not build(classes):
            print("  FAULT: LuaRun does not compile against the installed jar")
            return 1
        line = probe(PROBE, classes)
        faults.extend(move_in_checks(exchange, classes))
    got = numbers(line)
    print()
    print("     a sociable person alone, six months into collapse:")
    print("       " + line)
    print()

    if line.startswith("ERROR"):
        print("  FAULT: the VM would not run the probe")
        print("  " + line[:400])
        return 1

    want = {
        "pullFull": ("0.8",
                     "the full pull came back %s; appetite 0.8 at full "
                     "isolation in a county at the horizon's end must "
                     "read 0.8"),
        "pullHermit": ("0.1",
                       "a hermit's pull came back %s; an appetite of 0.1 "
                       "is a need that carries almost nothing, and it "
                       "must"),
        "pullHalf": ("0.4",
                     "a half-isolated person's pull came back %s; where "
                     "they are right now is half the product"),
        "memoHeld": ("0.8",
                     "the pull moved inside one county hour (%s); a "
                     "person's need does not change inside one"),
        "pullHalved": ("0.4",
                       "at three months the pull came back %s; the "
                       "horizon is six, so three months is half the "
                       "need"),
        "standCarry": ("1",
                       "trust 0.2 plus pull 0.8 came back %s; the "
                       "standing at a company door is the sum"),
        "doorYes": ("1",
                    "trust a fifth and need four fifths did not clear "
                    "the company line (%s); need substitutes for trust "
                    "not yet built"),
        "standAlone": ("0.8",
                       "with no trust at all the standing came back %s; "
                       "it must be the pull alone"),
        "doorAlone": ("1",
                      "a fully isolated sociable person's need did not "
                      "carry the whole line by itself (%s); in a county "
                      "six months into collapse it must"),
        "standQuarrel": ("-0.4",
                         "a quarrel of -0.4 with need standing at 0.8 "
                         "came back %s; need NEVER cancels trust already "
                         "spent against somebody"),
        "pullUnknown": ("0",
                        "an unreadable id pulled %s; zero whenever any "
                        "factor cannot be read"),
        "standUnknown": ("0",
                         "an unreadable id stood at %s; every gate "
                         "degrades to trust alone, and trust toward an "
                         "unknown is honestly zero"),
        "pullBefore": ("0",
                       "in an ordinary county the pull came back %s; "
                       "need carries nobody before the fall has made "
                       "company a need"),
        "standBefore": ("0.15",
                        "in an ordinary county the standing came back "
                        "%s; it must be the acquaintance and nothing "
                        "else"),
        "memoAfter": ("0",
                      "the pull moved inside one county hour (%s); the "
                      "memo must hold on this side of the clock too"),
    }
    for key, (expected, story) in want.items():
        if got.get(key) != expected:
            faults.append(story % got.get(key))

    print()
    for k, v in seams.items():
        print("  %s  %s" % ("yes" if v else "NO ", k))
        if not v:
            faults.append(k)

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print("  FAULT: " + f)
        print("  152) need stands alongside trust: FAIL")
        return 1
    print("  152) appetite times isolation times openness, summed onto "
          "trust only where trust is not negative, zero when unreadable, "
          "held within the county hour, at every door; delivered move-in "
          "does not invent ownership (4 production-source controls): PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
