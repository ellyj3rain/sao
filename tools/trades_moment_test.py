#!/usr/bin/env python3
r"""Border 148 - the trades the engine pays for, as the hinge of a
row ([C88]).

The operator ruled where the next rows point: a new target the
trades open up - rows authored where the person's trade is the
situation's hinge. The plain county never had trades: every skill
came back minus one because no body carries a profession. The engine
county pays real boosts, and the survey that came before this border
measured where a trade actually decides something inside the dump's
own moments. Exactly two places, both inside the election the dump
already wraps:

  * the dealt work yields to the member's own best hand - the house
    hands the rifle to whoever can shoot - when their pay for
    another job beats their pay for the dealt one by three or more;
  * an unmet house need pulls the best-paid hand into the gap, skill
    first, class affinity as tiebreak, once per election.

The harvest that came before this border found four redirects and
eight promotions in six engine counties - and all eight promotions
went to zero-pay hands, so the trade decided none of them. Read
closer, the whole harvest holds no Foraging pay at all: no
profession in the catalog boosts it, so the forager pull is never a
trade's decision - it is the class the county's own rule points at.
A row that would say what decided a moment needs what the house was
missing when it asked, and that was the one thing the row did not
hold.

So the row now holds the house's need state as the election opened -
the shelves' and water's words, whether the hearth burns, who the
house feuds with - read through the same verbs the need-pull reads
inside the election, read once at entry because the deal writes the
have-set mid-election and the state the question is asked of is the
state as it stood. A house holding nothing reads as holding nothing:
the absent store stays absent in the row rather than a dressed-up
zero.

THIS BORDER FORCES BOTH MOMENTS THROUGH THE TREE'S OWN INSTRUMENT -
the real prelude, the engine's own name pools and profession
definitions, the dump's own capture - by wrapping the county's tick
so the forcing runs at the first tick, after the capture wrapper
installs, so a forced election lands as a real captured row rather
than as the border's own reading of the store. It holds:

  * EVERY ROW CARRIES THE NEED STATE, and a house holding nothing
    says so by absence, not by a dressed-up zero.
  * THE REDIRECT ROW SHOWS THE TRADE DECIDING: the person's own pay
    for the won job beats their pay for the dealt job by the
    margin, re-derived from the row's own skills table rather than
    trusted from the designation that moved.
  * THE PROMOTION ROW SHOWS THE NEED AND THE ANSWER TOGETHER: lean
    shelves in the row's need state, the outdoors hand the county's
    rule points at pulled into the gap ahead of the settled hand the
    row also shows, one person moved by the election and not the
    house reshuffled - and the row's skills table records that no
    forager trade paid, which is itself evidence.
  * THE VOTE IS ARITHMETIC, NOT CONTEST: the border boosts one
    member's trust so the hinge person is never the leader, and the
    row's own leaderAfter is the boosted member.

If the engine install is absent the border says so and holds only
the text; if the catalog offers no such trade within the scan's
bound the border prints what the scan found and skips rather than
manufacture a moment.

An optional argv[1] points the checker at another tree root, which
is how its control runs.
"""
import json
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
PRELUDE_FILE = ROOT / "tools" / "sweep" / "prelude.lua"
DUMP = ROOT / "tools" / "county_dump.py"
STANDING = LUA / "shared" / "SAO_Standing.lua"

sys.path.insert(0, str(ROOT / "tools"))
import county_sweep as Sweep                                    # noqa: E402
import county_dump                                              # noqa: E402

# The dealt word for a class, in the deal's own spelling.
DEALT_FOR_CLASS = {
    "hardened": "watch",
    "outdoors": "scout",
    "carer": "medic",
    "settled": "quartermaster",
}

# The forcing chunk. It loads after the mod's modules and before the
# dump's own chunk, so it can wrap the county's tick handler; the
# dump reads the handler after installing its capture wrapper, so
# the forcing runs at the FIRST tick inside real captured rows. The
# scan asks the deal's own question (exactly one other job clearing
# the dealt pay by 3+, so a redirect is the person's own trade and
# never an order between ties) and the need-pull's own question (the
# outdoors hand the county's rule points at, a settled hand beside
# it as the other candidate, a mapped-class house so no member is
# dealt forager, so the lean shelves alone decide).
FORCING = r'''-- [C88] The forcing chunk, wrapped around the county's own tick.
do
  local function make(x, y)
    local r = SAO.Identity.create(nil, nil, x, y, 0)
    pcall(function() SAO.History.generate(r.id, r) end)
    r.homeX, r.homeY, r.homeZ = x, y, 0
    r.lastWaterDay, r.lastFoodDay, r.lastRiskDay = 0, 0, 0
    return r
  end

  local JOB_PERK = SAO.Census.JOB_PERK or {}
  local function pays(id)
    local t = {}
    for job, perk in pairs(JOB_PERK) do
      local v = SAO.Census.skillOf(id, perk)
      if type(v) ~= "number" then v = -1 end
      t[job] = v
    end
    return t
  end
  local function clsOf(rec)
    return SAO.Census.classOf(rec.occupation)
  end
  local function dealtOf(cls)
    return (cls == "hardened" and "watch")
      or (cls == "outdoors" and "scout")
      or (cls == "carer" and "medic")
      or (cls == "settled" and "quartermaster")
      or "forager"
  end
  local function redirectOf(id, cls)
    local p = pays(id)
    local dealt = dealtOf(cls)
    local dealtLvl = JOB_PERK[dealt] and p[dealt] or 0
    if dealtLvl < 0 then dealtLvl = 0 end
    local clearJob, clears = nil, 0
    for job in pairs(JOB_PERK) do
      if job ~= dealt and p[job] >= dealtLvl + 3 then
        clearJob = job
        clears = clears + 1
      end
    end
    if clears == 1 then return clearJob, clears end
    return nil, clears
  end

  _G.__c88Force = function()
    local people = {}
    for i = 1, 160 do
      people[#people + 1] = make(
        10500 + (i % 20) * 6, 9000 + math.floor(i / 20) * 6)
    end
    local p0, p1, p2 = people[1], people[2], people[3]
    local held = {}
    for _, r in ipairs({ p0, p1, p2 }) do held[r.id] = true end

    local function pick(cond)
      for _, r in ipairs(people) do
        if not held[r.id] and cond(r) then
          held[r.id] = true
          return r
        end
      end
      return nil
    end
    local m = pick(function(r)
      return redirectOf(r.id, clsOf(r)) ~= nil end)
    local f = pick(function(r)
      local cls = clsOf(r)
      local _, clears = redirectOf(r.id, cls)
      return cls == "outdoors" and clears == 0 end)
    local z = pick(function(r)
      local cls = clsOf(r)
      local _, clears = redirectOf(r.id, cls)
      local p = pays(r.id)
      return cls == "settled"
        and clears == 0 and p.forager < 1 end)
    local la = pick(function(r) return true end)
    local lb = pick(function(r)
      local cls = clsOf(r)
      return cls == "hardened" or cls == "carer" or cls == "settled" end)
    local x = pick(function(r) return true end)

    local function key(r) return tostring(r.id) end
    local parts = {}
    parts[#parts + 1] = "made=" .. #people
    parts[#parts + 1] = "m=" .. (m and key(m) or "none")
    parts[#parts + 1] = "mjob="
      .. (m and redirectOf(m.id, clsOf(m)) or "none")
    parts[#parts + 1] = "f=" .. (f and key(f) or "none")
    parts[#parts + 1] = "fpay=" .. (f and pays(f.id).forager or "none")
    parts[#parts + 1] = "z=" .. (z and key(z) or "none")
    parts[#parts + 1] = "la=" .. (la and key(la) or "none")
    parts[#parts + 1] = "lb=" .. (lb and key(lb) or "none")
    parts[#parts + 1] = "x=" .. (x and key(x) or "none")
    p0.probeReport = table.concat(parts, " ")

    SAO.Standing.formCompany({ p0.id, p1.id }, "probe-report")

    local okP, errP = pcall(function()
      if not (m and f and z and la and lb and x) then return end
      local function boost(ids, leadId)
        for _, id in ipairs(ids) do
          if id ~= leadId then
            SAO.Standing.adjustTrust(id, leadId, 1.0)
          end
        end
      end
      boost({ m.id, x.id, la.id }, la.id)
      SAO.Standing.formCompany({ m.id, x.id, la.id }, "probe-a")
      boost({ f.id, z.id, lb.id }, lb.id)
      SAO.Standing.formCompany({ f.id, z.id, lb.id }, "probe-b")
      SAO.Standing.setLarder("probe-b", "lean", 0)
      SAO.Standing.electLeader("probe-b")
    end)
    p1.probeProbe = okP and "probes ok"
      or ("probe error: " .. tostring(errP))
    SAO.Standing.formCompany({ p1.id, p2.id }, "probe-report2")
  end
end

do
  local realTick = _G.__handlers and _G.__handlers.OnTick or nil
  if type(realTick) == "function" then
    local forced = false
    _G.__handlers.OnTick = function()
      if not forced then
        forced = true
        pcall(_G.__c88Force)
      end
      return realTick()
    end
  end
end
'''


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") \
        if path.exists() else ""


def numbers(line):
    return {k: v for k, v in re.findall(r"([\w.]+)=([-\w./:' ]+?)(?=\s\w+=|$)",
                                        line or "")}


def snap_of(row, pid):
    for s in row.get("roster") or []:
        if s.get("id") == pid:
            return s
    return None


def redirect_from_row(snap):
    """The deal's own question, asked of the row's own evidence: the
    dealt word for the snap's class, its pay, and every other job
    clearing it by the margin."""
    cls = snap.get("occupationClass")
    dealt = DEALT_FOR_CLASS.get(cls, "forager")
    skills = snap.get("skills") or {}
    dealt_pay = skills.get(dealt, -1)
    if not isinstance(dealt_pay, (int, float)) or dealt_pay < 0:
        dealt_pay = 0
    clears = [j for j, pay in skills.items()
              if j != dealt and isinstance(pay, (int, float))
              and pay >= dealt_pay + 3]
    return cls, dealt, dealt_pay, clears


def run_probe(name):
    """The dump's own invocation with the forcing chunk added before
    its own chunk, one day owed - the forcing lands at the first
    tick and the county stops after its first day."""
    prelude = (Sweep.SWEEP / "prelude.lua").read_text(encoding="utf-8")
    prelude = prelude.replace("_G.__owed = 1096", "_G.__owed = 1")
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(Sweep.STDLIB, work / "stdlib.lua")
        for c in Sweep.OUT.glob("*.class"):
            shutil.copy2(c, work / c.name)
        pre = work / "prelude.lua"
        pre.write_text(prelude, encoding="utf-8")
        forcing = work / "forcing.lua"
        forcing.write_text(FORCING, encoding="utf-8")
        cp = "%s;%s;." % (Sweep.PZ, Sweep.SAO_JAR)
        args = [str(Sweep.JDK / "java.exe"), "-cp", cp, "LuaRun",
                "--engine", str(Sweep.GAME), str(pre),
                str(Sweep.ENGINE_FILL_LUA),
                str(Sweep.SWEEP / "engine_fill.lua"),
                str(Sweep.CACHE / "map.lua"),
                str(Sweep.SWEEP / "places.lua")]
        args += [str(LUA / m) for m in Sweep.MODULES
                 if (LUA / m).exists()]
        args += [str(Sweep.CACHE / "regions.lua"), str(forcing), "--",
                 county_dump.RUN.replace("RUN_NAME", name)]
        try:
            done = subprocess.run(args, cwd=str(work), capture_output=True,
                                  text=True, timeout=1200)
        except subprocess.TimeoutExpired:
            return None, "timeout after twenty minutes"
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
    faults = []
    print("=" * 74)
    print("THE TRADES THE ENGINE PAYS FOR, AS THE HINGE OF A ROW")
    print("=" * 74)

    dump = read(DUMP)
    standing = read(STANDING)
    seams = {
        "the row holds the house's need state as the election opened":
            "need = {" in dump
            and "SAO.Standing.larderOf(groupName)" in dump
            and "SAO.Standing.waterStoreOf(groupName)" in dump
            and "SAO.Standing.hearthOf(groupName)" in dump
            and "SAO.Standing.feudBetween(groupName, g2)" in dump,
        "the capture reads the same verbs the need-pull reads":
            "S.larderOf(groupName)" in standing
            and "S.waterStoreOf(groupName)" in standing
            and "S.hearthOf(groupName)" in standing
            and "S.feudBetween(groupName, g2)" in standing,
        "the dump's own record says why ([C88])":
            "[C88]" in dump,
        "the gate runs this border":
            "tools/trades_moment_test.py" in read(CHECK),
    }

    vm_ready = (Sweep.JDK.exists() and Sweep.PZ.exists()
                and Sweep.STDLIB.exists() and Sweep.GAME.exists()
                and Sweep.SRC.exists())
    if vm_ready and not Sweep.SAO_JAR.exists():
        print("  the mod jar is not built (%s); engine mode needs it"
              % Sweep.SAO_JAR)
        vm_ready = False
    if vm_ready and not Sweep.ENGINE_FILL_LUA.exists():
        print("  the game's own fill file is not where this install "
              "has it (%s)" % Sweep.ENGINE_FILL_LUA)
        vm_ready = False
    if vm_ready and not ((Sweep.CACHE / "map.lua").exists()
                         and (Sweep.CACHE / "regions.lua").exists()):
        print("  reading the shipped world ...")
        if not Sweep.World.build(Sweep.GAME, Sweep.CACHE):
            print("  no shipped maps to read")
            vm_ready = False
    if not vm_ready:
        print("  SKIPPED the forced moments - no JDK, engine jar, "
              "stdlib, runner, game, mod jar or shipped world")
        for k, v in seams.items():
            print("  %s  %s" % ("yes" if v else "NO ", k))
            if not v:
                faults.append(k)
        print()
        if faults:
            print("VERDICT: FAIL")
            return 1
        print("  148) the trades as a row's hinge: TEXT ONLY, the "
              "engine install is absent")
        return 0
    if not Sweep.build_runner():
        print("  FAULT: LuaRun will not compile against the "
              "installed jar")
        return 1

    data, err = run_probe("Border148")
    if data is None:
        print("  FAULT: the instrument would not run - %s" % err)
        return 1
    print("  one engine county, one day owed: %d moments, "
          "captureFailures=%s"
          % (data["moments"], data["captureFailures"]))
    if data.get("firstCaptureError"):
        faults.append("a capture failed inside the instrument's own "
                      "pcall: %s" % data["firstCaptureError"][:200])

    rows = data["rows"]
    groups = {}
    for r in rows:
        groups.setdefault(r["group"], []).append(r)

    # The row shape: every captured election carries the need state,
    # and a house holding nothing says so by absence.
    bare = [i for i, r in enumerate(rows)
            if not isinstance(r.get("need"), dict)
            or not isinstance(r["need"].get("feuds"), dict)]
    if bare:
        faults.append("%d of %d captured rows carry no need state - "
                      "a row that would say the trade was the hinge "
                      "does not know what the house was missing when "
                      "it asked" % (len(bare), len(rows)))

    rep = groups.get("probe-report") or []
    rep2 = groups.get("probe-report2") or []
    if not rep:
        print("  FAULT: the forcing chunk left no report row, so "
              "the border cannot tell a miss from a crash")
        faults.append("no probe-report row came back")
        return verdict(faults, seams)
    report = ((rep[0]["roster"][0].get("record") or {})
              .get("probeReport") or "")
    print("  the scan's report: " + report)
    got = numbers(report)
    shapes = all(got.get(k, "none") not in ("none", "")
                 for k in ("m", "f", "z", "la", "lb", "x"))
    if not shapes:
        print("  SKIPPED the forced moments - the catalog offered "
              "no such trade within the scan's bound; the border "
              "will not manufacture a moment")
        for k, v in seams.items():
            print("  %s  %s" % ("yes" if v else "NO ", k))
            if not v:
                faults.append(k)
        print()
        if faults:
            print("VERDICT: FAIL")
            return 1
        print("  148) the trades as a row's hinge: TEXT ONLY, the "
              "catalog held no hinge within the bound")
        return 0
    if not rep2:
        faults.append("no probe-report2 row came back, so the "
                      "border cannot tell a formed probe from a "
                      "crashed one")
    else:
        probe_note = ((rep2[0]["roster"][0].get("record") or {})
                      .get("probeProbe") or "absent")
        if probe_note != "probes ok":
            faults.append("the forcing chunk reported: %s" % probe_note)

    pa = groups.get("probe-a") or []
    pb = groups.get("probe-b") or []
    if not pa or not pb:
        faults.append("the forced companies left no captured rows "
                      "(probe-a: %d, probe-b: %d)" % (len(pa), len(pb)))
        return verdict(faults, seams)

    # THE REDIRECT ROW. The person's own trade decided the dealt
    # work, and the row's own skills show the margin - re-derived
    # here, not trusted from the designation that moved.
    a = pa[0]
    msnap = snap_of(a, got.get("m"))
    print()
    print("  the redirect row (probe-a, founding):")
    if msnap is None:
        faults.append("the hinge person is not in the captured "
                      "roster of the redirect row")
    else:
        cls, dealt, dealt_pay, clears = redirect_from_row(msnap)
        print("    class=%s dealt=%s(pay %s) skills=%s"
              % (cls, dealt, dealt_pay,
                 json.dumps(msnap.get("skills"))))
        print("    designationBefore=%r designationAfter=%r"
              % (msnap.get("designationBefore"),
                 msnap.get("designationAfter")))
        after = msnap.get("designationAfter")
        if "designationBefore" in msnap:
            faults.append("the redirect person carried a "
                          "designation before the founding election "
                          "(%r), so the row does not hold both sides "
                          "of the moment"
                          % msnap.get("designationBefore"))
        if len(clears) != 1:
            faults.append("the redirect row's own skills show %d "
                          "jobs clearing the dealt pay by the "
                          "margin, so the redirect is an order "
                          "between ties rather than one person's "
                          "own trade" % len(clears))
        elif after != clears[0]:
            faults.append("the dealt work moved to %r while the "
                          "row's own skills show the one clear "
                          "margin in %r - the trade did not decide "
                          "this row" % (after, clears[0]))
        else:
            print("    the trade decided: pay %s for %s clears pay "
                  "%s for the dealt %s by the margin"
                  % (msnap["skills"][clears[0]], clears[0],
                     dealt_pay, dealt))
        if "larder" in (a.get("need") or {}):
            faults.append("probe-a's row carries a larder state "
                          "nobody set - the capture reads a store "
                          "the house does not hold")
        if a.get("leaderAfter") != got.get("la"):
            faults.append("the row's leader is %r, not the boosted "
                          "member %r - the vote was a contest the "
                          "border did not arrange"
                          % (a.get("leaderAfter"), got.get("la")))

    # THE PROMOTION ROW. The need state the house was asked of, and
    # the trade that answered, in one row - and only one person
    # moved.
    b1 = pb[0]
    lean = [r for r in pb
            if ((r.get("need") or {}).get("larder") or {})
            .get("word") == "lean"]
    print()
    print("  the promotion row (probe-b):")
    if "larder" in (b1.get("need") or {}):
        faults.append("the founding row already carried a larder "
                      "state the border had not set when it was "
                      "captured")
    if not lean:
        faults.append("no captured probe-b row carries the lean "
                      "shelves the border set, so the need state "
                      "the promotion answered is not in the row")
        return verdict(faults, seams)
    b2 = lean[0]
    fsnap = snap_of(b2, got.get("f"))
    if fsnap is None:
        faults.append("the promoted person is not in the captured "
                      "roster of the promotion row")
        return verdict(faults, seams)
    lard = (b2.get("need") or {}).get("larder") or {}
    print("    the need as the election opened: larder=%s"
          % json.dumps(lard))
    if lard.get("word") != "lean" or lard.get("count") != 0:
        faults.append("the row's need state reads %r rather than "
                      "the lean shelves the border set, so the "
                      "capture is not the state the need-pull "
                      "answered" % lard)
    fcls = fsnap.get("occupationClass")
    fskills = fsnap.get("skills") or {}
    before, after = fsnap.get("designationBefore"), \
        fsnap.get("designationAfter")
    print("    the pulled hand: class=%s skills=%s "
          "designationBefore=%r designationAfter=%r"
          % (fcls, json.dumps(fskills), before, after))
    if fcls != "outdoors":
        faults.append("the pulled member reads class=%r rather than "
                      "the outdoors hand the county's own rule "
                      "points at, so the row does not show what "
                      "decided the pull" % fcls)
    if before != "scout":
        faults.append("the promotion row's before is %r rather than "
                      "the dealt word for an outdoors hand, so the "
                      "row does not hold both sides of the moment"
                      % before)
    if after != "forager":
        faults.append("the lean shelves pulled the dealt work to "
                      "%r rather than the forager gap" % after)
    # The affinity arithmetic, re-derived from the row: no forager
    # trade pays in this catalog (the survey measured the whole
    # harvest), so the pull is decided between the two candidates
    # the row shows - and only one person moves.
    zsnap = snap_of(b2, got.get("z"))
    if zsnap is not None:
        zcls = zsnap.get("occupationClass")
        zdealt = DEALT_FOR_CLASS.get(zcls, "forager")
        zafter = zsnap.get("designationAfter")
        print("    the other candidate: class=%s dealt=%s "
              "designationAfter=%r"
              % (zcls, zdealt, zafter))
        if zcls != "settled":
            faults.append("the other candidate reads class=%r "
                          "rather than settled, so the row does not "
                          "show the county's rule deciding between "
                          "two candidates" % zcls)
        if zafter != zdealt:
            faults.append("the promotion moved a second hand (%r "
                          "-> %r), but a house changes a person at "
                          "a time" % (zdealt, zafter))
    if b2.get("leaderAfter") != got.get("lb"):
        faults.append("the promotion row's leader is %r, not the "
                      "boosted member %r"
                      % (b2.get("leaderAfter"), got.get("lb")))

    return verdict(faults, seams)


def verdict(faults, seams):
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
        print("  148) the trades as a row's hinge: FAIL")
        return 1
    print("  148) every row carries the need state, the redirect "
          "shows the trade's own margin in the row's skills, the "
          "promotion shows the lean shelves and the hand the "
          "county's rule points at together, and a house holding "
          "nothing says so by absence: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())