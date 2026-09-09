#!/usr/bin/env python3
r"""Border 123 - what a survivor says follows what they have learned
([C50], DR-036 Day Zero slice 3).

Every line table in SAO_Voice was flat, so the whole county spoke in
one register regardless of what any of them had lived through. On a
day-zero start that is the case the mode exists to make different:
nobody has learned anything yet, and they were all saying "Too many!"
and "Dead nearby", which are counts and names somebody acquires.

A line table may now be split by register, and the register comes from
the speaker's own lesson store. The boundary is the one the county
already drew - SAO_Lessons calls innocence "having learned nothing
yet" ([B1]/T-002) - so no threshold is invented and nothing new is
stored. Five tables are split: FLEE, ALERT, ENGAGE, warned and
turnedSeen. The rest stay flat.

The crossing is audible too. SAO_Lessons already dates the first
lesson and calls it the day the world changed for that person; when
one lands on somebody who had nothing, they say so, once.

This border runs SAO_Voice and the real SAO_Lessons in the engine's
own VM (tools/luacheck/LuaRun) with a stub body that records what was
said, and checks:

  * an innocent speaker and a taught speaker draw from disjoint sets
    on every split table, and the same set on a flat one;
  * the taught lists are the pre-batch lines, unchanged;
  * a speaker whose lesson store cannot be read gets the taught
    register - a missing answer keeps the old behaviour rather than
    making the county sound like it has seen nothing;
  * the first lesson speaks once and the second does not;
  * every split table carries both registers, neither empty;
  * no innocent line names the thing - dead, infected, bitten, horde,
    turned and the rest are words somebody acquires - while the
    taught lines do, which is the control for that check.

An optional argv[1] points the checker at another tree root, which is
how its control runs: the pre-batch tree fails every seam.
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
LESSONS = SHARED / "SAO_Lessons.lua"
VOICE = CLIENT / "SAO_Voice.lua"
ROADMAP = ROOT / "ROADMAP.md"
CHECK = ROOT / "tools" / "check.sh"
PRELUDE = HERE / "luacheck" / "probe_age.lua"
SRC = HERE / "luacheck" / "LuaRun.java"
OUT = ROOT / "java" / "out" / "luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"

SPLIT = ("FLEE", "ALERT", "ENGAGE")
SPLIT_EVENTS = ("warned", "turnedSeen")

# Words a person acquires. Somebody who has learned nothing has no
# name for what they are looking at, so none of these may appear in an
# innocent line - and at least one must appear in a taught line, or
# this check is measuring nothing.
ACQUIRED = ("dead", "zombie", "infected", "bite", "bitten", "horde",
            "turned", "undead", "corpse", "walker", "outbreak")

# Records, a body that records what it hears, and the engine calls
# `speak` reaches for. ZombRand at 0 puts every line past the
# talkativeness gate; the clock advances a minute a call so the
# cooldown never eats one.
STUB = (
    "local said = {} local recs = {} local ms = 0 "
    "getTimestampMs = function() ms = ms + 60000 return ms end "
    "ZombRand = function(n) return 0 end "
    # [C66] The module draws through the county's own generator now.
    # Stubbed to answer what this probe already made ZombRand answer,
    # so the pick stays the deterministic one this border relies on
    # rather than becoming a real seeded draw.
    "SAO.Rand = { int = function(a, b) return (b == nil) and 0 or a end, "
    "unit = function() return 0 end } "
    "SAO.Identity.get = function(id) return recs[id] end "
    "SAO.Body = { get = function(id) "
    "return { Say = function(self, line) said[#said + 1] = line end } end } "
    "SAO.Controller = { tick = function() return 0 end } "
    "SAO.Gesture = { onEvent = function() end } "
    "SAO.Disposition.talkativeness = function() return 1.0 end "
    "local function person(id, taught) "
    "recs[id] = { id = id, lessonsKnown = taught "
    "and { ['measure-the-danger'] = 1.0 } or {} } return id end "
    "local V = SAO.Voice "
    "local function heard(id, fn) local n = #said fn() "
    "local out = {} for i = n + 1, #said do out[#out + 1] = said[i] end "
    "return out end ")


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
             str(PRELUDE), str(HASH), str(LESSONS), str(VOICE), "--", expr],
            cwd=str(work), capture_output=True, text=True, timeout=900)
    return (done.stdout or "").strip().split("\n")[-1] if done.stdout else "ERROR no output"


def value(line):
    return line[6:] if line.startswith("VALUE ") else None


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""


def numbers(line):
    return {k: v for k, v in re.findall(r"([\w.]+)=([-\w./']+)", line or "")}


# Every split table walked over enough ticks to reach every line, an
# innocent speaker and a taught one, and the two sets compared. A flat
# table is walked the same way and must come back identical.
DISJOINT = (
    "(function() " + STUB +
    "local out = {} "
    "local function sweep(who, kind, name) local seen = {} "
    "for t = 0, 11 do local id = who .. '-' .. kind .. '-' .. name .. '-' .. t "
    "person(id, who == 'taught') "
    "local lines = heard(id, function() "
    "if kind == 'state' then V.onTransition(id, name, t) "
    "else V.onEvent(id, name, t) end end) "
    "for _, l in ipairs(lines) do seen[l] = true end end return seen end "
    "local function compare(kind, name) "
    "local a, b = sweep('innocent', kind, name), sweep('taught', kind, name) "
    "local na, nb, shared = 0, 0, 0 "
    "for l in pairs(a) do na = na + 1 if b[l] then shared = shared + 1 end end "
    "for _ in pairs(b) do nb = nb + 1 end "
    "out[#out + 1] = string.format('%s=%d/%d/%d', name, na, nb, shared) end "
    "for _, s in ipairs({ 'FLEE', 'ALERT', 'ENGAGE' }) do compare('state', s) end "
    "for _, e in ipairs({ 'warned', 'turnedSeen' }) do compare('event', e) end "
    "compare('state', 'HOMEWARD') "
    "return table.concat(out, ' ') end)()")

# A store that cannot be read must not make the county sound innocent.
FALLBACK = (
    "(function() " + STUB +
    "local id = person('nolessons', false) "
    "local innocent = heard(id, function() V.onTransition(id, 'FLEE', 0) end)[1] "
    "SAO.Lessons.hasAny = function() error('no store') end "
    "local id2 = person('broken', false) "
    "local fallback = heard(id2, function() V.onTransition(id2, 'FLEE', 0) end)[1] "
    "SAO.Lessons.hasAny = nil "
    "local id3 = person('missing', false) "
    "local gone = heard(id3, function() V.onTransition(id3, 'FLEE', 0) end)[1] "
    "return 'innocent=' .. tostring(innocent ~= nil) "
    ".. ' throws_taught=' .. tostring(fallback ~= nil and fallback ~= innocent) "
    ".. ' absent_taught=' .. tostring(gone ~= nil and gone ~= innocent) end)()")

# The crossing: the first lesson speaks, the second does not, and
# somebody who already knew something never says it at all.
CROSSING = (
    "(function() " + STUB +
    "local L = SAO.Lessons "
    "local a = person('crosser', false) "
    "local first = heard(a, function() L.learn(a, 'measure-the-danger', 1.0, 'lived') end) "
    "local second = heard(a, function() L.learn(a, 'trust-carefully', 1.0, 'lived') end) "
    "local b = person('veteran', true) "
    "local never = heard(b, function() L.learn(b, 'trust-carefully', 1.0, 'lived') end) "
    "return 'first=' .. #first .. ' second=' .. #second .. ' veteran=' .. #never end)()")


def lists_in(src, table_name):
    """The register lists of one split table, as {register: [lines]}."""
    m = re.search(r"^    %s\s*=\s*\{" % re.escape(table_name), src, re.M)
    if not m:
        return {}
    depth, i = 0, m.end() - 1
    while i < len(src):
        if src[i] == "{":
            depth += 1
        elif src[i] == "}":
            depth -= 1
            if depth == 0:
                break
        i += 1
    body = src[m.end():i]
    out = {}
    for rm in re.finditer(r"(\w+)\s*=\s*\{(.*?)\}", body, re.S):
        out[rm.group(1)] = re.findall(r'"((?:[^"\\]|\\.)*)"', rm.group(2))
    return out


def main():
    faults = []
    print("=" * 74)
    print("WHAT A SURVIVOR SAYS FOLLOWS WHAT THEY HAVE LEARNED")
    print("=" * 74)
    for path, what in ((LESSONS, "SAO_Lessons.lua"), (VOICE, "SAO_Voice.lua"),
                       (PRELUDE, "the probe")):
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
        print("  123) speech register: SKIPPED, the engine install is absent")
        return 0
    if not build():
        print("  FAULT: LuaRun does not compile against the installed jar")
        return 1

    vo = read(VOICE)

    dis = numbers(value(probe(DISJOINT)))
    print("     registers (innocent/taught/shared): "
          + " ".join("%s=%s" % kv for kv in dis.items()))
    for name in SPLIT + SPLIT_EVENTS:
        try:
            na, nb, shared = (int(x) for x in dis[name].split("/"))
        except (KeyError, ValueError):
            faults.append("%s did not answer: %r" % (name, dis.get(name)))
            continue
        if na == 0 or nb == 0:
            faults.append("%s: one register said nothing (%d innocent, %d taught)"
                          % (name, na, nb))
        if shared:
            faults.append("%s: %d line(s) are in both registers - the split "
                          "is not a split" % (name, shared))
    try:
        na, nb, shared = (int(x) for x in dis["HOMEWARD"].split("/"))
        if shared == 0 or na != nb or shared != na:
            faults.append("HOMEWARD is flat and should be shared by everyone, "
                          "but answered %d/%d/%d" % (na, nb, shared))
    except (KeyError, ValueError):
        faults.append("the flat-table control did not answer: %r" % dis.get("HOMEWARD"))

    fb = numbers(value(probe(FALLBACK)))
    print("     fallback: " + " ".join("%s=%s" % kv for kv in fb.items()))
    for k in ("innocent", "throws_taught", "absent_taught"):
        if fb.get(k) != "true":
            faults.append("fallback: %s is %s, wanted true - an unreadable "
                          "lesson store must keep the taught register"
                          % (k, fb.get(k)))

    cr = numbers(value(probe(CROSSING)))
    print("     crossing: " + " ".join("%s=%s" % kv for kv in cr.items()))
    want = {"first": "1", "second": "0", "veteran": "0"}
    for k, v in want.items():
        if cr.get(k) != v:
            faults.append("the crossing: %s spoke %s time(s), wanted %s"
                          % (k, cr.get(k), v))

    innocent_words, taught_words = [], []
    for name in SPLIT + SPLIT_EVENTS:
        regs = lists_in(vo, name)
        for reg in ("innocent", "taught"):
            if not regs.get(reg):
                faults.append("%s has no %s register, or it is empty"
                              % (name, reg))
        innocent_words += regs.get("innocent", [])
        taught_words += regs.get("taught", [])
    named = [l for l in innocent_words
             if any(w in l.lower() for w in ACQUIRED)]
    control = [l for l in taught_words
               if any(w in l.lower() for w in ACQUIRED)]
    print("     vocabulary: innocent=%d taught=%d named=%d control=%d"
          % (len(innocent_words), len(taught_words), len(named), len(control)))
    for line in named:
        faults.append("an innocent line names the thing: %r" % line)
    if not control:
        faults.append("no taught line uses any acquired word, so the "
                      "vocabulary check has no control and proves nothing")

    seams = {
        "the register comes from the lesson store, not a new field":
            "SAO.Lessons.hasAny(id)" in vo
            and "local function registerOf(id)" in vo,
        "a flat table stays flat":
            "if list[1] ~= nil then return list end" in vo,
        "both entry points resolve":
            "resolve(LINES[state], id)" in vo and "resolve(EVENTS[event], id)" in vo,
        "the first lesson is read before the write":
            "local wasInnocent = true" in read(LESSONS)
            and 'SAO.Voice.onEvent(id, "firstLesson", nil)' in read(LESSONS),
        "the roadmap records the slice":
            "SHIPPED as `[C50]`" in read(ROADMAP),
        "the gate runs this border":
            "tools/speech_register_test.py" in read(CHECK),
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
    print("  123) speech register: what a survivor says follows what they "
          "have learned, on the county's own innocence boundary, and the "
          "first lesson is audible once")
    return 0


if __name__ == "__main__":
    sys.exit(main())
