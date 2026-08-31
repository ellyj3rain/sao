#!/usr/bin/env python3
"""Cross-file invariant sweep ([A22]): mechanical verification of the
contracts that live between files. Reports; humans judge."""
import re, pathlib

root = pathlib.Path(__file__).resolve().parent.parent
lroot = root / "mod/42.20/media/lua"
ctl = (lroot / "client/SAO_Controller.lua").read_text(encoding="utf-8")

# 1. MOVEMENT_STATES keys vs the locomotion tick's state list.
mv_block = re.search(r"local MOVEMENT_STATES = \{(.*?)\}", ctl, re.S).group(1)
mv_keys = set(re.findall(r"(\w+) = true", mv_block))
tick_block = re.search(
    r"-- Locomotion verdicts drive state exits.*?SAO\.Locomotion\.tick",
    ctl, re.S).group(0)
tick_states = set(re.findall(r'agent\.state == "(\w+)"', tick_block))
print("1) MOVEMENT keys missing from locomotion tick:",
      sorted(mv_keys - tick_states) or "none")
print("   tick states not in MOVEMENT map:",
      sorted(tick_states - mv_keys) or "none")

# 2. setState states vs PRESSURE map (default 'errand' is legal; list
# which states rely on the default so intent is reviewable).
pr_block = re.search(r"local PRESSURE_ANSWER = \{(.*?)\n\}", ctl, re.S).group(1)
pr_keys = set(re.findall(r"(\w+) = \"", pr_block))
set_states = set(re.findall(r'setState\([^,]+, [^,]+, "(\w+)"', ctl))
print("2) states relying on the 'errand' default:",
      sorted(set_states - pr_keys))

# 3. takePurpose writes vs close-out branches.
writes = set(re.findall(r'agent\.takePurpose = "(\w+)"', ctl))
handled = set(re.findall(r'agent\.takePurpose == "(\w+)"', ctl))
print("3) takePurpose written but never handled:",
      sorted(writes - handled) or "none")

# 4. Bridge verbs: Lua calls vs Java definitions.
lua_calls = set()
for f in list((lroot / "client").glob("*.lua")) + list((lroot / "shared").glob("*.lua")):
    lua_calls |= set(re.findall(r"SAOJavaBridge:(\w+)\(",
                                f.read_text(encoding="utf-8")))
java = (root / "java/src/com/sao/bridge/SAOBridge.java").read_text(encoding="utf-8")
java_defs = set(re.findall(r"public [\w.<>\[\]]+ (\w+)\(", java))
print("4) Lua-called verbs missing in SAOBridge:",
      sorted(lua_calls - java_defs) or "none")

# 5. Voice: every literal event key used has EVENTS lines (re-run of A21).
used = set()
for f in list((lroot / "client").glob("*.lua")) + list((lroot / "shared").glob("*.lua")):
    used |= set(re.findall(r'onEvent\([^,]+, "(\w+)"',
                           f.read_text(encoding="utf-8")))
voice = (lroot / "client/SAO_Voice.lua").read_text(encoding="utf-8")
ev_block = re.search(r"local EVENTS = \{(.*?)\n\}", voice, re.S).group(1)
ev_keys = set(re.findall(r"(\w+)\s*=\s*\{", ev_block))
print("5) voice events used but undefined:", sorted(used - ev_keys) or "none")

# 6. [B6 lesson -> B5 border] A TAKE state must be entered with WORK
# QUEUED. The water-run bug entered TAKE having queued nothing, so the
# survivor stood in place until the deadline lapsed and the carried
# vessels never moved. Heuristic: for every setState(..., "TAKE", ...)
# site, look back 15 lines in the same file for a queuing call.
QUEUERS = ("depositSpareFood", "depositWater", "takeStoredWater",
           "queueTake", "queueDrinkFrom", "queueEat", "shareBandageWith",
           "ISTimedActionQueue.add", "queueReload", "queueGrab")
ctl = (lroot / "client/SAO_Controller.lua").read_text(encoding="utf-8")
lines = ctl.split("\n")
bare = []
for i, line in enumerate(lines):
    if 'setState(agent, id, "TAKE"' in line:
        window = "\n".join(lines[max(0, i - 15):i + 1])
        if not any(q in window for q in QUEUERS):
            bare.append(i + 1)
print("6) TAKE states entered with no queued work (line numbers):",
      bare or "none")

# 7. [B9 lesson] SENSOR SCALE: a reading compared against magnitudes
# that disagree across sites is the tell that someone guessed the
# units (B6 compared a 0..2 temperature deficit against 8 and 12).
# Heuristic: group numeric comparisons per Lua-side reader and flag
# any reader whose literals span more than 20x - honest about false
# positives (a legitimately wide-range reading will show up here).
READERS = ("SAO.Needs.cold", "SAO.Needs.woundInfection",
           "SAO.Needs.dirtyBandages", "SAO.Needs.bleeding",
           "SAOJavaBridge:sickness", "SAOJavaBridge:woundInfection",
           "SAOJavaBridge:coldStrength", "SAOJavaBridge:countEdibleNearby",
           "SAOJavaBridge:countStoredWaterNearby")
scales = {}
for f in list((lroot / "client").glob("*.lua")) + list((lroot / "shared").glob("*.lua")):
    text = f.read_text(encoding="utf-8")
    for reader in READERS:
        for m in re.finditer(re.escape(reader) + r"\([^)]*\)\s*[<>]=?\s*([\d.]+)",
                             text):
            scales.setdefault(reader, set()).add(float(m.group(1)))
flagged = []
for reader, values in scales.items():
    lo = min(v for v in values if v > 0) if any(v > 0 for v in values) else 0
    hi = max(values)
    if lo > 0 and hi / lo > 20:
        flagged.append(f"{reader} {sorted(values)}")
print("7) sensor scale disagreement across sites:", flagged or "none")

# 8. [B7/B6 lesson] STATE CONTRACTS: every state the controller can
# ENTER must be dispatched by something that can get the person OUT -
# a movement verdict, the action queue, or its own hold gate. The
# WARMING bug was a state with no gate (it evaporated); the water-run
# bug was a state with no work. RE_EVALUATED states are the honest
# fourth kind: the decision re-derives them from live world state
# every tick, so they need no gate of their own.
RE_EVALUATED = {"IDLE", "ALERT"}
targets = set(re.findall(r'setState\([^,]+,[^,]+,\s*"(\w+)"', ctl))
mv = set(re.findall(r"(\w+) = true",
                    re.search(r"local MOVEMENT_STATES = \{(.*?)\n\}", ctl, re.S).group(1)))
loco = set(re.findall(r'agent\.state == "(\w+)"',
                      re.search(r"-- Locomotion verdicts drive state exits(.*?)SAO\.Locomotion\.tick",
                                ctl, re.S).group(1)))
action_src = ctl[ctl.index('-- Need-action holds'):]
action = set(re.findall(r'agent\.state == "(\w+)"', action_src[:600]))
gated = set(re.findall(r'if agent\.state == "(\w+)" then', ctl))
orphans = sorted(s for s in targets
                 if s not in RE_EVALUATED and s not in gated
                 and not (s in mv and s in loco) and s not in action)
print("8) states with no exit dispatcher:", orphans or "none")

# 9. [B16 lesson] FIELD NAMES: a field READ that nothing anywhere
# WRITES is the silent-nothing bug - B10's first draft cleared
# `r.debt` when the field is `owedToMe`, and the clear did nothing at
# all. Collects writes three ways (direct, multiple assignment, table
# literal) across the whole tree, so a flag means no site anywhere
# writes that name.
KNOWN_READ_ONLY = {
    # Written through a call chain (rel(...).greeted = true), which no
    # receiver-anchored pattern can see.
    "greeted",
    # Legacy migration field: old saves carry rec.lessons and migrate()
    # converts it; new code never writes it, by design.
    "lessons",
}
RECV = ("rec", "r", "meta", "meta0", "metaA", "metaB", "metaC", "metaS",
        "metaH", "metaW", "metaA8", "meta2", "metaK", "agent", "pb",
        "pb0", "pb2", "hr", "hr2", "mrec", "orec", "wrec", "lrec",
        "rec2", "drec", "hh")
fwrites, freads = set(), {}
for f in (list((lroot / "client").glob("*.lua"))
          + list((lroot / "shared").glob("*.lua"))
          + list((lroot / "server").glob("*.lua"))):
    txt = f.read_text(encoding="utf-8")
    fwrites |= set(re.findall(r"\b\w+\.(\w+)\s*[,=][^=]", txt))
    fwrites |= set(re.findall(r"[{,]\s*(\w+)\s*=", txt))
    for m in re.finditer(r"\b(" + "|".join(RECV) + r")\.(\w+)\b(?!\s*=(?!=))",
                         txt):
        freads.setdefault(m.group(2), set()).add(f.name)
orphan_fields = sorted(k for k in freads
                       if k not in fwrites and k not in KNOWN_READ_ONLY)
print("9) claim fields read but never written:", orphan_fields or "none")

# 10. [B50 lesson] NEWS KINDS: a `kind` written into govHistory or the
# radio wire is only real if some renderer handles it. Both renderers
# dispatch through if/elseif chains - a closed set pretending to be an
# open one - so a new kind lands, asserts clean, and displays nothing.
# That is exactly how [B23]'s creed turn was recorded faithfully and
# read by nobody.
#
# Non-news kinds are allowlisted rather than tolerated as noise: `row`
# and `header` are the Ledger's own row constructors and were never
# news.
UI_KINDS = {"row", "header"}
kinds_written, kinds_read = set(), set()
for f in (list((lroot / "client").glob("*.lua"))
          + list((lroot / "shared").glob("*.lua"))
          + list((lroot / "server").glob("*.lua"))):
    txt = f.read_text(encoding="utf-8")
    # plain form: kind = "x"
    kinds_written |= set(re.findall(r'kind\s*=\s*"(\w+)"', txt))
    # conditional form: kind = cond and "a" or "b"
    for m in re.finditer(r'kind\s*=\s*[^,\n]*?and\s+"(\w+)"\s+or\s+"(\w+)"',
                         txt):
        kinds_written |= {m.group(1), m.group(2)}
for name in ("client/SAO_UI.lua", "server/SAO_Radio.lua"):
    txt = (lroot / name).read_text(encoding="utf-8")
    kinds_read |= set(re.findall(r'kind\s*==\s*"(\w+)"', txt))
unrendered = sorted(kinds_written - kinds_read - UI_KINDS)
print("10) news kinds written but rendered by nobody:",
      unrendered or "none")

# 11. [B55 lesson] DESIGNATION LITERALS: a `designation == "..."`
# compared against a value nothing can ever BE is invisible to every
# other border - the Lua is valid, the field access is legitimate, and
# the feature simply never fires. `groupShape` compared against
# "forage" while the designation is "forager", which held forageShare
# at zero and made pacts structurally impossible for the entire life
# of the project.
#
# The canon is Census.JOB_PERK's keys plus the two designations that
# ride no perk: quartermaster (organised is a trait, not a skill) and
# leads.
canon_src = (lroot / "shared/SAO_Census.lua").read_text(encoding="utf-8")
canon_block = re.search(r"Census\.JOB_PERK = \{(.*?)\}", canon_src, re.S)
DESIGNATIONS = set(re.findall(r"(\w+)\s*=", canon_block.group(1))) if canon_block else set()
DESIGNATIONS |= {"quartermaster", "leads"}
bad_desig = set()
for f in (list((lroot / "client").glob("*.lua"))
          + list((lroot / "shared").glob("*.lua"))
          + list((lroot / "server").glob("*.lua"))):
    txt = f.read_text(encoding="utf-8")
    for m in re.finditer(r'designation\s*==\s*"(\w+)"', txt):
        if m.group(1) not in DESIGNATIONS:
            bad_desig.add(f"{f.name}:{m.group(1)}")
print("11) designation literals nothing can ever be:",
      sorted(bad_desig) or "none")

# 12) A want Lua asks for that the Java side cannot answer.
#
# [B24] generalised. Border 11 catches one vocabulary crossing one
# boundary; this catches the sharpest boundary in the codebase. Lua
# passes takeWantedFromNearby a kind as a bare string and Java's
# `wants` switch ends in `default: return false`, so a kind nobody
# handles is not an error - it is a survivor who quietly never picks
# anything up, forever, with nothing logged.
jroot = root / "java/src/com/sao/engine"
wants_src = (jroot / "SAONeeds.java").read_text(encoding="utf-8")
wants_block = re.search(r"private static boolean wants\(.*?\n    \}", wants_src, re.S)
HANDLED = set(re.findall(r'case\s+"(\w+)"\s*:', wants_block.group(0))) if wants_block else set()
asked = {}
for f in (list((lroot / "client").glob("*.lua"))
          + list((lroot / "shared").glob("*.lua"))
          + list((lroot / "server").glob("*.lua"))):
    txt = f.read_text(encoding="utf-8")
    for m in re.finditer(r'takeWantedFromNearby\(\s*[^,]+,\s*[^,]+,\s*"(\w+)"', txt):
        asked.setdefault(m.group(1), f.name)
unanswerable = sorted(f"{v}:{k}" for k, v in asked.items() if k not in HANDLED)
print("12) wants Lua asks for that Java cannot answer:", unanswerable or "none")
