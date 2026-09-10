#!/usr/bin/env python3
r"""Dump the decision moments from a county sweep run.

Speakeasy's record 24 ratified where the dataset's rows come from: a
person's own record put to a language model, which decides as that
person, in that situation, among the options actually available. The
operator chose the first target on 2026-09-09 - the work words a
company deals, record 21's founding example - and a row's first three
parts have to come from somewhere real: the person, the situation,
the options.

This is that somewhere. It runs the same counties the sweep runs -
the shipped modules, in Kahlua, driven through the mod's own tick
handler, genesis through its own path from the map's own spawn
regions - and where the sweep counts houses, this watches the verb
that deals the work. `SAO.Standing.electLeader` is wrapped from
outside, exactly as the sweep wraps `formCompany`, so the mod carries
no test hook of its own: at every call that finds a roster of two or
more living members, the moment is taken down whole - every member's
record, traits, conditions, habits, lessons and age, their belief
set with each belief's provenance, the trust each member holds
toward each other, the company's creed and claim, and the county
hour - then the real election runs, and what the tree dealt lands
beside it as the authored outcome the dataset exists to replace.

The choice is not captured, because it is not the county's to make.
That fourth part of a row is the language model's, decided as the
person, and it arrives in Speakeasy as a proposal the operator rules
on. What this hands over is what they decide FROM: nothing selected,
nothing hidden - the whole record and the whole belief set,
serialized generically so the instrument cannot quietly curate what
the model sees.

WHAT IT IS NOT. Not a border and not in the gate: it asserts
nothing, passes nothing and fails nothing. The dump is data against
the install that produced it and lands outside the tree, like the
sweep's world cache. Re-running the same county name reproduces the
same county ([C66] - same code, same map, same spawn points), which
is what makes a row's citation of county and hour answerable rather
than invented.

THE ENGINE MODE

`--engine` exposes the real shipped bridge and loads the game's own
data through it: the name pools, filled by the game's own fill
functions, and the profession definitions, registered by the game's
own two-phase script pass. A row from an engine dump carries real
names in `name` and real boosts under `skills`, where a plain dump
carries the sentinel and zeros.

It is a DIFFERENT county from the same save name run without the
flag. A name costs two county draws at `Identity.create`, and
`listProfessions` grows the catalog the occupation draw runs against,
so the draws diverge from the first person onward. [C66] holds per
harness shape: same name plus `--engine` reproduces the engine county,
same name without it reproduces the plain one, and neither reproduces
the other. The ratified rows cite the plain dump, which is preserved
data against the install that produced it; rows from an engine dump
cite the engine dump.

  python tools/county_dump.py --runs 12
  python tools/county_dump.py --runs 24 --out C:/wherever
  python tools/county_dump.py --runs 12 --engine
"""
import argparse
import concurrent.futures
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile
import time

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import county_sweep as Sweep                                    # noqa: E402

# What the dump's own Lua reaches for, by module, so a missing one
# reports on its own line rather than as a silent nil. The sweep's
# module check exists because a harness result is only as good as its
# module list - twice a whole set of numbers meant nothing because a
# loaded module was not - and that check covers the loaded modules'
# references, not this block's.
DUMP_NEEDS = ["Identity", "Census", "History", "Disposition",
              "Conditions", "Habits", "Lessons", "Perception",
              "Standing"]

RUN = r'''(function()
  _G.__world = 'RUN_NAME'
  local s = ModData.getOrCreate('SurvivorAwareness_Standing')
  local rows = {}
  local captureFailures = 0
  local firstCaptureError = nil

  -- JSON, written here rather than imported because the county's own
  -- tree owes the dataset no dependency. Numbers, strings, booleans,
  -- tables walked as arrays where the keys are exactly 1..n and as
  -- maps otherwise; anything else renders as null. Depth-capped so a
  -- cycle cannot hang the run, and a cycle at all in a person's
  -- record would itself be a finding.
  local function esc(t)
    local v = tostring(t)
    v = string.gsub(v, "\\\\", "\\\\")
    v = string.gsub(v, '"', '\\"')
    v = string.gsub(v, "\n", "\\n")
    v = string.gsub(v, "\r", "\\r")
    v = string.gsub(v, "\t", "\\t")
    return v
  end
  local function ser(v, depth)
    if v == nil then return "null" end
    local tv = type(v)
    if tv == "number" then
      if v == math.floor(v) and v == v and math.abs(v) < 1e15 then
        return string.format("%.0f", v)
      end
      return tostring(v)
    elseif tv == "string" then
      return '"' .. esc(v) .. '"'
    elseif tv == "boolean" then
      if v then return "true" end
      return "false"
    elseif tv == "table" then
      if depth > 8 then return "null" end
      local cnt, maxK, isArr = 0, 0, true
      for k in pairs(v) do
        cnt = cnt + 1
        if type(k) == "number" and k >= 1 and k == math.floor(k) then
          if k > maxK then maxK = k end
        else
          isArr = false
        end
      end
      if isArr and maxK == cnt and cnt > 0 then
        local a = {}
        for i = 1, cnt do a[i] = ser(v[i], depth + 1) end
        return "[" .. table.concat(a, ",") .. "]"
      end
      local m = {}
      for k, val in pairs(v) do
        local key
        if type(k) == "number" then
          -- JSON keys are strings, always: a sparse or zero-based
          -- table reaches here and its keys still have to quote.
          key = '"' .. string.format("%.0f", k) .. '"'
        else
          key = '"' .. esc(tostring(k)) .. '"'
        end
        m[#m + 1] = key .. ":" .. ser(val, depth + 1)
      end
      return "{" .. table.concat(m, ",") .. "}"
    end
    return "null"
  end

  local function ok1(f)
    local ok, v = pcall(f)
    if ok then return v end
    return nil
  end

  -- One member as the row's person half: the record the county
  -- already carries, the traits, conditions, habits and lessons read
  -- off their own pillars, the census's class and skills for the
  -- work the tree can deal, and the whole belief set. Nothing here
  -- selects; the serializer takes whatever is there.
  local function memberSnap(id)
    local rec = SAO.Identity.get(id)
    local snap = { id = id }
    snap.name = ok1(function()
      return rec.forename .. " " .. rec.surname end)
    -- [C87] The plain reading beside the key: a row reads "Elliot
    -- Segura", the engine's own English rendering of its own key
    -- (the prelude's `plainNameOf`). The raw key stays in `name` -
    -- the engine's storage, unchanged and recoverable.
    snap.displayName = ok1(function()
      return plainNameOf(rec.forename, rec.surname) end)
    snap.record = rec
    snap.age = ok1(function() return SAO.History.ageOf(id) end)
    snap.circle = ok1(function() return SAO.Disposition.circle(id) end)
    snap.traits = ok1(function() return SAO.Disposition.traits(id) end)
    snap.conditions = ok1(function() return SAO.Conditions.of(id) end)
    snap.habits = ok1(function() return SAO.Habits.of(id) end)
    snap.lessons = ok1(function()
      return SAO.Lessons.renderClaims(id) end)
    snap.occupationClass = ok1(function()
      return SAO.Census.classOf(rec.occupation) end)
    snap.skills = ok1(function()
      local out = {}
      for job, perk in pairs(SAO.Census.JOB_PERK or {}) do
        out[job] = SAO.Census.skillOf(id, perk) or 0
      end
      return out end)
    snap.beliefs = SAO.Perception.beliefs[id]
    snap.designationBefore = rec and rec.designation or nil
    snap.designatedByBefore = rec and rec.designatedBy or nil
    return snap
  end

  -- Standing toward the others in the situation: the trust each
  -- member holds toward each other member, and whether they are
  -- hostile. The election's own sum reads the same values.
  local function relationsFor(members)
    local out = {}
    for _, a in ipairs(members) do
      local row = {}
      for _, b in ipairs(members) do
        if a ~= b then
          row[b] = {
            trust = ok1(function()
              return SAO.Standing.trust(a, b) end),
            hostile = ok1(function()
              return SAO.Standing.isHostileTo(a, b) end) == true,
          }
        end
      end
      out[a] = row
    end
    return out
  end

  -- The moment, before the deal: living roster, the company's creed
  -- and claim, the county hour. Nil when the roster holds fewer than
  -- two living members - a widow release or an emptied faction is
  -- not a deal.
  local function capture(groupName)
    groupName = tostring(groupName)
    local members = {}
    for id, g in pairs(s.groups or {}) do
      if g == groupName then
        local rec = SAO.Identity and SAO.Identity.get(id) or nil
        if not (rec and rec.dead) then
          members[#members + 1] = id
        end
      end
    end
    if #members < 2 then return nil end
    table.sort(members)
    local okH, hours = pcall(function()
      return SAO.History.countyHours() end)
    local row = {
      county = _G.__world,
      hours = okH and hours or nil,
      group = groupName,
      size = #members,
      creed = ok1(function()
        local c = SAO.Standing.creedOf(groupName)
        return c and c.name or nil end),
      claim = s.groupClaims and s.groupClaims[groupName] or nil,
      relations = relationsFor(members),
      roster = {},
    }
    for _, id in ipairs(members) do
      row.roster[#row.roster + 1] = memberSnap(id)
    end
    return row
  end

  local realElect = SAO.Standing.electLeader
  SAO.Standing.electLeader = function(groupName)
    local ok, row = pcall(capture, groupName)
    local a, b = realElect(groupName)
    if not ok then
      captureFailures = captureFailures + 1
      if firstCaptureError == nil then
        firstCaptureError = tostring(row)
      end
    elseif row then
      for _, m in ipairs(row.roster) do
        local rec = SAO.Identity.get(m.id)
        if rec then
          m.designationAfter = rec.designation
          m.designatedByAfter = rec.designatedBy
        end
      end
      local meta = s.groupMeta and s.groupMeta[tostring(groupName)]
      row.leaderAfter = meta and meta.leaderId or nil
      rows[#rows + 1] = row
    end
    return a, b
  end

  -- No county is built here; the tick handler the mod registered
  -- builds it through its own real cadence, as in the sweep.
  local tick = _G.__handlers.OnTick
  for i = 1, 240 * 9000 do
    tick()
    if i % 240 == 0
      and (tonumber(s.yearsRun) or 0) >= (tonumber(s.yearsOwed) or -1) then
      break
    end
  end
  local alive, dead = 0, 0
  for _, r in pairs(SAO.Identity.all()) do
    if r.dead then dead = dead + 1 else alive = alive + 1 end
  end
  local parts = {}
  for _, row in ipairs(rows) do
    parts[#parts + 1] = ser(row, 0)
  end
  local err = "null"
  if firstCaptureError ~= nil then
    err = '"' .. esc(firstCaptureError) .. '"'
  end
  return '{"county":"' .. esc(_G.__world) .. '","alive":' .. alive
    .. ',"dead":' .. dead .. ',"moments":' .. #rows
    .. ',"captureFailures":' .. captureFailures
    .. ',"firstCaptureError":' .. err
    .. ',"rows":[' .. table.concat(parts, ",") .. ']}'
end)()'''


def one(name, lua, owed, refill, engine=False):
    prelude = (Sweep.SWEEP / "prelude.lua").read_text(encoding="utf-8")
    prelude = prelude.replace("_G.__owed = 1096", "_G.__owed = %d" % owed)
    if refill is not None:
        prelude = prelude.replace("RefillDays = 2.0",
                                  "RefillDays = %s" % refill)
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(Sweep.STDLIB, work / "stdlib.lua")
        for c in Sweep.OUT.glob("*.class"):
            shutil.copy2(c, work / c.name)
        pre = work / "prelude.lua"
        pre.write_text(prelude, encoding="utf-8")
        cp = "%s;%s;." % (Sweep.PZ, Sweep.SAO_JAR) if engine \
            else "%s;." % Sweep.PZ
        args = [str(Sweep.JDK / "java.exe"), "-cp", cp, "LuaRun"]
        if engine:
            args += ["--engine", str(Sweep.GAME)]
        args += [str(pre)]
        if engine:
            # The game's own fill file, then the chunk that calls its
            # fill functions - before the mod's modules, which is the
            # game's own load order: engine Lua first, mod Lua after.
            args += [str(Sweep.ENGINE_FILL_LUA),
                     str(Sweep.SWEEP / "engine_fill.lua")]
        args += [str(Sweep.CACHE / "map.lua"),
                 str(Sweep.SWEEP / "places.lua")]
        args += [str(lua / m) for m in Sweep.MODULES
                 if (lua / m).exists()]
        args += [str(Sweep.CACHE / "regions.lua"), "--",
                 RUN.replace("RUN_NAME", name)]
        try:
            done = subprocess.run(args, cwd=str(work), capture_output=True,
                                  text=True, timeout=3600)
        except subprocess.TimeoutExpired:
            return None, "timeout after an hour"
    out = done.stdout or ""
    at = out.find("VALUE ")
    if at < 0:
        tail = (done.stderr or out).strip().splitlines()
        return None, tail[-1] if tail else "no value came back"
    try:
        return json.loads(out[at + 6:].strip()), None
    except ValueError as bad:
        return None, "unparsable value: %s" % bad


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--runs", type=int, default=12)
    ap.add_argument("--days", type=int, default=1096,
                    help="days the county owes at genesis")
    ap.add_argument("--refill", default=None,
                    help="RefillDays, through the sandbox rather than the code")
    ap.add_argument("--lua", default=None,
                    help="another tree's lua root, for a before/after")
    ap.add_argument("--workers", type=int, default=6)
    ap.add_argument("--out", default=None,
                    help="where the dump lands; default a stamped "
                         "directory beside the sweep cache")
    ap.add_argument("--engine", action="store_true",
                    help="expose the real bridge and load the game's own "
                         "name pools and profession definitions; rows "
                         "carry real names and boosts, and the county "
                         "differs from a plain run of the same name "
                         "(see the engine mode above)")
    args = ap.parse_args()

    print("=" * 74)
    print("COUNTY DUMP - decision moments from the county sweep")
    print("=" * 74)

    if not (Sweep.JDK.exists() and Sweep.PZ.exists() and Sweep.STDLIB.exists()
            and Sweep.SRC.exists() and Sweep.GAME.exists()):
        print("  SKIPPED - no JDK, engine jar, stdlib, runner or game.")
        print("  This runs the shipped modules in the engine's own VM "
              "against the")
        print("  shipped map, so it needs the game installed. Nothing "
              "is asserted,")
        print("  so there is nothing to fail.")
        return 0
    if args.engine and not Sweep.SAO_JAR.exists():
        print("  the mod jar is not built (%s)." % Sweep.SAO_JAR)
        print("  Engine mode exposes the shipped bridge, so build it "
              "first: bash tools/build-java.sh")
        return 1
    if args.engine and not Sweep.ENGINE_FILL_LUA.exists():
        print("  the game's own fill file is not where this install "
              "has it (%s)" % Sweep.ENGINE_FILL_LUA)
        return 1

    lua = pathlib.Path(args.lua).resolve() if args.lua \
        else Sweep.ROOT / "mod" / "42.20" / "media" / "lua"
    if not lua.is_dir():
        print("  no lua tree at %s" % lua)
        return 1

    missing, loaded = Sweep.modules_referenced(lua)
    absent = [n for n in DUMP_NEEDS
              if n not in loaded and n not in Sweep.NOT_DORMANT]
    if absent:
        print()
        print("  THE DUMP ITSELF REACHES FOR MODULES NOT LOADED:")
        for name in absent:
            print("      SAO.%s" % name)
        print("  Every capture would die inside its own pcall and the "
              "dump would")
        print("  report moments that mean nothing. Load them or "
              "declare them.")
        return 1
    print("  every module the dump reaches for is loaded (%d modules)"
          % len(loaded))
    if missing:
        print()
        print("  loaded code references modules not loaded; the sweep "
              "reports the same and its argument holds here")

    newest = 0
    maps = Sweep.World.maps_dir(Sweep.GAME)
    if maps.is_dir():
        for d in maps.iterdir():
            f = d / "spawnpoints.lua"
            if f.is_file():
                newest = max(newest, f.stat().st_mtime)
    have = (Sweep.CACHE / "map.lua").exists() \
        and (Sweep.CACHE / "regions.lua").exists()
    if not have or (Sweep.CACHE / "map.lua").stat().st_mtime < newest:
        print("  reading the shipped world ...")
        got = Sweep.World.build(Sweep.GAME, Sweep.CACHE)
        if not got:
            print("  no shipped maps found under %s" % maps)
            return 1
        print("  %d towns, %d spawn points, %d buildings"
              % (got["towns"], got["points"], got["buildings"]))
    else:
        print("  world cached at %s" % Sweep.CACHE)

    if not Sweep.build_runner():
        print("  LuaRun will not compile against the installed jar")
        return 1

    base = pathlib.Path(args.out) if args.out \
        else pathlib.Path(tempfile.gettempdir()) / "sao-decision-dump"
    dest = base / time.strftime("%Y%m%d-%H%M%S")
    dest.mkdir(parents=True, exist_ok=True)

    print("  %d counties, %d days owed, one process each; dump to %s%s"
          % (args.runs, args.days, dest,
             "; engine data on" if args.engine else ""))
    if args.engine:
        print("  engine data on: rows carry real names and real "
              "profession boosts.")
        print("  Same name plus --engine reproduces this county; "
              "without it the")
        print("  plain county - a different one - answers ([C66] per "
              "harness shape).")
    print()

    moments, members, failed = 0, 0, 0
    with concurrent.futures.ThreadPoolExecutor(
            max_workers=args.workers) as pool:
        futures = {pool.submit(one, "County%03d" % k, lua, args.days,
                               args.refill, args.engine): k
                   for k in range(args.runs)}
        for f in concurrent.futures.as_completed(futures):
            k = futures[f]
            r, why = f.result()
            if not r:
                failed = failed + 1
                print("  run %-3d did not finish: %s" % (k, why))
                continue
            pathlib.Path(dest / ("%s.json" % r["county"])).write_text(
                json.dumps(r, indent=1), encoding="utf-8")
            moments = moments + r["moments"]
            members = members + sum(m["size"] for m in r["rows"])
            if r["captureFailures"]:
                print("  run %-3d alive=%-4d moments=%-4d "
                      "CAPTURE FAILURES: %d (%s)"
                      % (k, r["alive"], r["moments"],
                         r["captureFailures"], r["firstCaptureError"]))
            else:
                print("  run %-3d alive=%-4d moments=%-4d "
                      "biggest roster=%d"
                      % (k, r["alive"], r["moments"],
                         max([m["size"] for m in r["rows"]] or [0])))

    print()
    print("  %d counties finished, %d did not" % (args.runs - failed, failed))
    print("  %d decision moments, %d member-rows among them"
          % (moments, members))
    print("  each moment is a real election the tree dealt; each member "
          "in one is")
    print("  a row's first three parts waiting on their fourth.")
    print("  The dump landed at %s - data against the install that "
          "produced it," % dest)
    print("  not in the tree. Re-run the same county name and you get "
          "the same county.")
    return 0


if __name__ == "__main__":
    sys.exit(main())