#!/usr/bin/env python3
r"""Border 146 - the engine's own names reach the county by mode, and
a run that cannot name anybody says so ([C86]).

The shipped code asks its host six questions a dormant county once had
no live answer for: how many forenames, which forename, how many
surnames, which surname, what a trade pays in its perk, and what trades
exist at all. Everything past those questions was already the county's
own - [C73] drew the name indexes off SAO.Rand, [B19] reads the perk
through the census row - so the difference between a county that names
nobody and one named out of the engine's own pools is whether anything
answers.

[C86] answered twice over. LuaRun's --engine mode exposes the real
shipped bridge and runs the game's own two-phase script pass, so the
engine's own data sits behind the six questions. The sweep prelude,
which used to stub all six away, forwards them: with an engine behind
it a county names its people and skills them; without one the forwards
answer nil and the shipped sentinels stand exactly as they did before -
the callers are pcall-wrapped, type-check what comes back, and draw
only after a count, so a nil costs no draw and a plain county's
sequence is untouched.

THIS BORDER MEASURES THE RECORDS AND THE DRAWS, NOT THE CALLS.

Everything below runs the shipped modules behind the REAL sweep
prelude - the one the dump runs, not a private stand-in - because the
merge lives in that prelude and holding it anywhere else would hold a
different thing.

The properties:

  * THE PLAIN COUNTY STANDS. With no engine behind it, every person
    keeps the Unnamed/Survivor sentinels, the forwards answer nil
    without throwing, and the answers the harness owns (the owed days)
    still answer - the merge replaced nothing.
  * THE ENGINE RUN NAMES PEOPLE, FROM THE POOLS. Every person comes
    out with a forename from the pool for their own sex and a surname
    from the surname pool, checked against the bridge's own answers
    rather than a list shipped here.
  * THE ENGINE RUN SKILLS PEOPLE. Census.skillOf, the shipped funnel,
    answers a number rather than the -1 of a county with no engine
    behind it, and the catalog holds more trades than the base table
    alone.
  * THE DRAW IS STILL THE COUNTY'S, IN BOTH MODES. The same save twice
    produces the same names and the same following draws, and a
    different save produces different ones. [C66] holds per mode.
  * THE TWO MODES ARE TWO COUNTIES. The same save, run plain and run
    with engine data, lands on different draws - a name costs two
    draws at Identity.create and the catalog grew - so neither run
    reproduces the other and a row must cite the dump that made it.
  * A RUN THAT WOULD NAME NOBODY SAYS SO. --engine with the fill
    chunks absent fails loudly - no VALUE, a named error - rather than
    a county of sentinels sailing through as an engine run.

An optional argv[1] points the checker at another tree root, which is
how its control runs. Against the [C85] tree the plain half faults
because the prelude has no forwards to ask, the engine half faults
because a stub that forwards nothing leaves the county unnamed even
with the engine's own pools exposed behind it, and the text half
faults because the fill chunk, the flag and this border's gate entry
are not there.
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
SWEEP = ROOT / "tools" / "sweep"
PRELUDE_FILE = SWEEP / "prelude.lua"
FILL_CHUNK = SWEEP / "engine_fill.lua"
DUMP = ROOT / "tools" / "county_dump.py"
SWEEPER = ROOT / "tools" / "county_sweep.py"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"
SAO_JAR = ROOT / "mod" / "42.20" / "media" / "java" / "SAO.jar"
ENGINE_FILL_LUA = PZ_DIR / "media" / "lua" / "shared" / "NPCs" / \
    "MainCreationMethods.lua"

MODULES = [
    "shared/SAO_Log.lua", "shared/SAO_Hash.lua", "shared/SAO_Rand.lua",
    "shared/SAO_Census.lua", "shared/SAO_History.lua",
    "shared/SAO_Disposition.lua", "shared/SAO_Conditions.lua",
    "shared/SAO_Habits.lua", "shared/SAO_Claims.lua", "shared/SAO_Identity.lua",
]

# One probe, both modes. It asks the six questions the way the shipped
# code does, makes forty people the way the county does, reads what a
# trade pays through the shipped funnel, and then draws three times -
# so the same save run plain and run with engine data can be compared
# draw for draw.
PROBE = r'''(function()
  _G.__save = "SAVE_ID"
  getWorld = function() return {
      getWorld = function() return _G.__save end,
      getMetaGrid = function() return nil end } end

  -- The forwards, through the merged stub. Where there is no engine
  -- behind it they answer nil; a tree without the merge has no
  -- forward to ask and the call itself throws.
  local fok, fval = pcall(function()
      return SAOJavaBridge:forenameCount(false) end)
  local owed = tostring(SAOJavaBridge:daysBehindAtStart(false))
  local listedLen, listedColon = 0, false
  pcall(function()
      local listed = tostring(SAOJavaBridge:listProfessions())
      listedLen = #listed
      listedColon = string.find(listed, ":", 1, true) ~= nil
  end)

  -- The engine's own pools, read through the bridge itself, so
  -- membership is checked against what the engine holds and not
  -- against a list this border would have to keep.
  local mset, fset, sset = {}, {}, {}
  local mc = 0
  pcall(function()
      mc = tonumber(SAOJavaBridge:forenameCount(false)) or 0
      for i = 0, mc - 1 do
          mset[SAOJavaBridge:forenameAt(false, i)] = true end
      local fc = tonumber(SAOJavaBridge:forenameCount(true)) or 0
      for i = 0, fc - 1 do
          fset[SAOJavaBridge:forenameAt(true, i)] = true end
      local sc = tonumber(SAOJavaBridge:surnameCount()) or 0
      for i = 0, sc - 1 do
          sset[SAOJavaBridge:surnameAt(i)] = true end
  end)

  -- Forty people, the way the county makes them: made, then given
  -- their past - genesis's own order, which is where the census seam
  -- deals a trade. Without the settled past a person has no trade to
  -- read, and measuring skillOf on one would measure nothing.
  local people, sample = {}, {}
  for i = 1, 40 do
      local r = SAO.Identity.create(nil, nil, 10, 10, 0)
      pcall(function() SAO.History.generate(r.id, r) end)
      people[#people + 1] = r
      if i <= 5 then
          sample[#sample + 1] = tostring(r.forename) .. "/"
              .. tostring(r.surname)
      end
  end

  local sentinels, named, inPool = 0, 0, 0
  for _, r in ipairs(people) do
      local f, s = tostring(r.forename), tostring(r.surname)
      if f == "Unnamed" and s == "Survivor" then sentinels = sentinels + 1 end
      if f ~= "Unnamed" and s ~= "Survivor" then named = named + 1 end
      local female = SAO.Identity.femaleOf and SAO.Identity.femaleOf(r)
      local pool = female and fset or mset
      if pool[f] and sset[s] then inPool = inPool + 1 end
  end

  -- What a trade pays, through the shipped funnel: the census row,
  -- then the engine's own definition behind it.
  local skilled = 0
  for id, _ in pairs(SAO.Identity.all()) do
      local v = tonumber(SAO.Census.skillOf(id, "Doctor"))
      if v and v >= 0 then skilled = skilled + 1 end
  end
  local catalog = 0
  pcall(function()
      catalog = #(SAO.Census.catalog().rows or {}) end)

  -- What the county draws next, after the same forty people. Two runs
  -- of the same save agree here or the draw is not the county's; the
  -- plain and engine runs of the same save DISAGREE here, because a
  -- name costs two draws and the catalog grew.
  local d1 = SAO.Rand.int(1, 1000)
  local d2 = SAO.Rand.int(1, 1000)
  local d3 = SAO.Rand.int(1, 1000)

  return "fok=" .. tostring(fok) .. " fval=" .. tostring(fval)
    .. " owed=" .. owed
    .. " sentinels=" .. sentinels .. " named=" .. named
    .. " inPool=" .. inPool
    .. " skilled=" .. skilled .. " catalog=" .. catalog
    .. " mc=" .. mc
    .. " listedLen=" .. listedLen
    .. " listedColon=" .. tostring(listedColon)
    .. " triple=" .. d1 .. "x" .. d2 .. "x" .. d3
    .. " sample=" .. table.concat(sample, "|")
end)()'''


def build():
    cls = OUT / "LuaRun.class"
    if cls.exists() and cls.stat().st_mtime >= SRC.stat().st_mtime:
        return True
    OUT.mkdir(parents=True, exist_ok=True)
    done = subprocess.run(
        [str(JDK / "javac.exe"), "-cp", str(PZ), "-d", str(OUT), str(SRC)],
        capture_output=True, text=True, timeout=300)
    return done.returncode == 0


def run(save, expr, engine, fill):
    """One VM. Returns (returncode, full stdout). The classpath carries
    the mod's jar only where engine data was asked for; LuaRun compiles
    against the engine jar alone either way."""
    expr = expr.replace("SAVE_ID", save)
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(STDLIB, work / "stdlib.lua")
        for c in OUT.glob("*.class"):
            shutil.copy2(c, work / c.name)
        prelude = (PRELUDE_FILE.read_text(encoding="utf-8"))
        pre = work / "prelude.lua"
        pre.write_text(prelude, encoding="utf-8")
        cp = "%s;%s;." % (PZ, SAO_JAR) if engine else "%s;." % PZ
        args = [str(JDK / "java.exe"), "-cp", cp, "LuaRun"]
        if engine:
            args += ["--engine", str(PZ_DIR)]
        args += [str(pre)]
        if engine and fill:
            # The game's own fill file, then the chunk that calls its
            # fill functions by name - the game's own load order,
            # engine Lua before mod Lua.
            args += [str(ENGINE_FILL_LUA), str(FILL_CHUNK)]
        args += [str(LUA / m) for m in MODULES if (LUA / m).exists()]
        args += ["--", expr]
        done = subprocess.run(args, cwd=str(work), capture_output=True,
                              text=True, timeout=900)
    return done.returncode, done.stdout or ""


def value_of(output):
    at = output.find("VALUE ")
    if at < 0:
        return None
    return output[at + 6:].strip().split("\n")[0]


def numbers(line):
    return {k: v for k, v in re.findall(r"([\w.]+)=([-\w./:'|]+)", line or "")}


def pools_of(output):
    m = re.search(r"ENGINE pools male=(\d+) female=(\d+) surnames=(\d+)"
                  r" professions=(\d+)", output or "")
    if not m:
        return None
    return tuple(int(x) for x in m.groups())


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") \
        if path.exists() else ""


def main():
    faults = []
    print("=" * 74)
    print("THE ENGINE'S OWN NAMES, OR THE SENTINELS - BY MODE")
    print("=" * 74)

    prelude_text = read(PRELUDE_FILE)
    runner_text = read(SRC)
    seams = {
        "the prelude forwards the engine's six questions":
            "forenameCount = __forward" in prelude_text
            and "listProfessions = __forward" in prelude_text,
        "the prelude captures the real bridge before stubbing it":
            "local __engineBridge = SAOJavaBridge" in prelude_text,
        "the fill chunk calls the game's own fills by name":
            "BaseGameCharacterDetails.DoMaleForename()" in read(FILL_CHUNK),
        "the runner loads the bridge by name, not by class":
            'Class.forName("com.sao.bridge.SAOBridge")' in runner_text
            and "import com.sao.bridge" not in runner_text,
        "a run that would name nobody reports itself":
            "engine data absent" in runner_text,
        "the drivers ask for engine data only when told":
            "--engine" in read(DUMP) and "--engine" in read(SWEEPER),
        "the gate runs this border":
            "tools/engine_data_test.py" in read(CHECK),
    }

    vm_ready = JDK.exists() and PZ.exists() and STDLIB.exists() \
        and SRC.exists()
    if not vm_ready:
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
        print("  146) the engine's own names by mode: TEXT ONLY, the "
              "engine install is absent")
        return 0
    if not build():
        print("  FAULT: LuaRun does not compile against the installed jar")
        return 1

    engine_ready = SAO_JAR.exists() and ENGINE_FILL_LUA.exists() \
        and FILL_CHUNK.exists()
    if not engine_ready:
        missing = []
        if not SAO_JAR.exists():
            missing.append("the mod jar (%s) - bash tools/build-java.sh"
                           % SAO_JAR)
        if not ENGINE_FILL_LUA.exists():
            missing.append("the game's own fill file (%s)" % ENGINE_FILL_LUA)
        if not FILL_CHUNK.exists():
            missing.append("the fill chunk (%s)" % FILL_CHUNK)
        print("  SKIPPED the engine half - " + "; ".join(missing))

    # THE PLAIN COUNTY STANDS - twice, to hold its own replay too.
    rc_p, out_p = run("ReplaySave", PROBE, engine=False, fill=False)
    line_p = value_of(out_p)
    rc_p2, out_p2 = run("ReplaySave", PROBE, engine=False, fill=False)
    line_p2 = value_of(out_p2)
    print()
    print("     the plain county, through the real prelude, no engine:")
    print("       " + str(line_p))
    if line_p is None or line_p2 is None:
        faults.append("the plain probe did not answer: %s"
                      % str(line_p or (out_p + out_p2))[-300:])
    else:
        got_p = numbers(line_p)
        if got_p.get("sentinels") != "40":
            faults.append(
                "the plain run left the sentinel on only %s of 40 people. "
                "With no engine behind the forwards there is nowhere for "
                "a name to come from, and a name appearing here would be "
                "invented" % got_p.get("sentinels"))
        if got_p.get("named") != "0":
            faults.append(
                "the plain run named %s of 40 people without an engine "
                "behind it" % got_p.get("named"))
        if got_p.get("fok") != "true":
            faults.append(
                "asking the stub for a forename count threw. The merged "
                "prelude forwards the engine's six questions and answers "
                "nil where there is no engine behind it; a tree without "
                "the merge has no forward to ask")
        elif got_p.get("fval") != "nil":
            faults.append(
                "the forward answered %s with no engine behind it. "
                "There is nothing behind the stub to read a count from, "
                "and an answer here would be invented"
                % got_p.get("fval"))
        if got_p.get("owed") != "1096":
            faults.append(
                "the harness's own answer moved: daysBehindAtStart said "
                "%s rather than the owed days. The merge forwards the "
                "engine's questions and must not touch the harness's"
                % got_p.get("owed"))
        if got_p.get("skilled") != "0":
            faults.append(
                "the plain run answered a trade's pay for %s of 40 "
                "people. Through a nil forward the census falls to -1; a "
                "number here means the boost was invented or read from "
                "somewhere other than the engine" % got_p.get("skilled"))
        if got_p.get("listedColon") != "false":
            faults.append(
                "the plain run read a profession list (%s chars) with "
                "no engine behind it" % got_p.get("listedLen"))
        if line_p != line_p2:
            faults.append(
                "the same plain save produced two different runs, so a "
                "plain county cannot be replayed - which is what [C66] "
                "exists for")

    # THE ENGINE RUN, its replay, and a different save.
    got_e = pools_e = None
    if engine_ready:
        rc_e, out_e = run("ReplaySave", PROBE, engine=True, fill=True)
        line_e = value_of(out_e)
        rc_e2, out_e2 = run("ReplaySave", PROBE, engine=True, fill=True)
        line_e2 = value_of(out_e2)
        rc_o, out_o = run("OtherSave", PROBE, engine=True, fill=True)
        line_o = value_of(out_o)
        pools_e = pools_of(out_e)
        print()
        print("     the same save with engine data on:")
        print("       ENGINE pools male=%d female=%d surnames=%d "
              "professions=%d" % pools_e
              if pools_e else "       (no ENGINE line: %s)" % out_e[-200:])
        print("       " + str(line_e))
        print("     its replay, and a different save:")
        print("       " + str(line_e2))
        print("       " + str(line_o))
        if line_e is None:
            faults.append("the engine probe did not answer: %s"
                          % (out_e[-300:] if out_e else "no output"))
        else:
            got_e = numbers(line_e)
            if pools_e is None or min(pools_e) <= 0:
                faults.append(
                    "the engine reported pools male=%s - a run that "
                    "would name nobody is a run that did not happen"
                    % (pools_e,))
            if got_e.get("named") != "40":
                faults.append(
                    "the engine run left %s of 40 people on the "
                    "sentinel. The pools sit exposed behind the bridge "
                    "and the prelude forwards to them; a sentinel here "
                    "means the question is not being asked or not being "
                    "answered" % got_e.get("named"))
            if got_e.get("inPool") != "40":
                faults.append(
                    "only %s of 40 people drew a forename from the pool "
                    "for their own sex and a surname from the surname "
                    "pool, checked against the bridge's own answers"
                    % got_e.get("inPool"))
            try:
                skilled_e = int(got_e.get("skilled") or 0)
            except ValueError:
                skilled_e = 0
            if skilled_e < 1:
                faults.append(
                    "the shipped funnel answered nobody's trade in the "
                    "engine run: skillOf fell to -1 for all 40, so the "
                    "engine's own pay is not being read through the "
                    "census row")
            try:
                cat_e = int(got_e.get("catalog") or 0)
                cat_p = int(numbers(line_p).get("catalog") or 0)
            except ValueError:
                cat_e = cat_p = 0
            if line_p is not None and cat_e <= cat_p:
                faults.append(
                    "the catalog did not grow: %s trades with the engine "
                    "on against %s without it, so listProfessions is not "
                    "reaching the catalog" % (cat_e, cat_p))
            if got_e.get("owed") != "1096":
                faults.append(
                    "the harness's own answer moved in engine mode: "
                    "daysBehindAtStart said %s" % got_e.get("owed"))
            if got_e.get("fval") in (None, "nil", "0"):
                faults.append(
                    "the forward answered %s for a forename count with "
                    "the engine behind it" % got_e.get("fval"))
            if got_e.get("listedColon") != "true":
                faults.append(
                    "listProfessions answered nothing with the engine "
                    "behind it, so the catalog cannot have grown from it")
            if line_e != line_e2:
                faults.append(
                    "the same save with engine data on produced two "
                    "different runs, so an engine county cannot be "
                    "replayed - [C66] holds per mode or it holds "
                    "nothing")
            if line_e == line_o:
                faults.append(
                    "two different saves produced the same engine "
                    "county, so the draw is not seeded off the save")

        # THE TWO MODES ARE TWO COUNTIES - same save, draw for draw.
        if line_p is not None and got_e is not None:
            if got_e.get("triple") == numbers(line_p).get("triple"):
                faults.append(
                    "the plain run and the engine run of the same save "
                    "landed on the same next draws (%s). A name costs "
                    "two draws at Identity.create and the catalog grew, "
                    "so the two runs are different counties; agreeing "
                    "here means the engine half changed nothing, and "
                    "the rows it dumps would be indistinguishable from "
                    "plain rows" % got_e.get("triple"))
            else:
                print()
                print("     the same save, run plain and run with engine"
                      " data,")
                print("     lands on different draws:")
                print("       plain:  %s" % numbers(line_p).get("triple"))
                print("       engine: %s" % got_e.get("triple"))

        # A RUN THAT WOULD NAME NOBODY SAYS SO. The fill chunks left
        # out is what a future game rename or a moved file looks like
        # from inside a run.
        rc_f, out_f = run("ReplaySave", 'return "ran"',
                          engine=True, fill=False)
        print()
        print("     --engine with the fill chunks absent:")
        tail = [l for l in (out_f or "").strip().split("\n") if l.strip()]
        print("       " + (tail[-1] if tail else "(no output)"))
        if value_of(out_f) is not None:
            faults.append(
                "an engine run with no name pools answered VALUE anyway. "
                "A run that would name nobody is a run that did not "
                "happen, and it must refuse rather than report a county "
                "of sentinels as an engine run")
        elif "engine data absent" not in (out_f or ""):
            faults.append(
                "an engine run with no name pools failed without naming "
                "what was absent: %s" % (out_f or "")[-200:])

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
        print("  146) the engine's own names by mode: FAIL")
        return 1
    print("  146) the plain county stands unchanged behind the merged "
          "prelude,")
    print("        the engine run names and skills its people from the "
          "engine's")
    print("        own data on the county's own draw, the two modes are "
          "two")
    print("        counties from one save, and a run that would name "
          "nobody")
    print("        refuses: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())