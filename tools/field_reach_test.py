#!/usr/bin/env python3
r"""Border 31 - a field written onto a person is a field somebody reads.

[B37] shipped `ageOf` and closed saying nothing read it. [B40] found
`rec.originAnchored` written at genesis with one mention in the whole
mod. Both were caught by hand, late, and only because somebody went
looking.

A field written and never read is not harmless. It is a fact the
simulation goes to the trouble of establishing and then cannot act
on - which reads, from outside, exactly like a feature that exists.

THE BLIND SPOT THIS CLOSES
--------------------------
The hand sweep that found `originAnchored` counted `rec.field`
textually, so it could not see a read through a string key:

    daysWithout(rec, "lastWaterDay", today)   -- reads rec[field]

Five of its twenty-three candidates were that shape - `lastWaterDay`,
`lastFoodDay` and others reported dead while being read every day.
An instrument with a blind spot that size is not measuring what it
says it measures.

So this resolves the one dataflow that actually occurs here: a
function that indexes a record by one of its own parameters, and the
string literals its callers hand to that parameter. That is bounded,
checkable, and covers the real idiom rather than guessing.

WHAT IS AND IS NOT A FAULT
--------------------------
Writing `nil` is not a write - `rec.backstory = nil` is [A14]'s
deliberate clearing, and the whole point is that the field should not
exist. Fields consumed only by the save layer, or by an external
reader like telemetry, are named in READ_ELSEWHERE with where.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"

# Names that hold a survivor record in this tree.
RECORD = r"(?:rec|rec\d+|mate|other|orec\d*|idleRec|recA|recB|r)"

WRITE = re.compile(rf"\b{RECORD}\.(\w+)\s*=\s*(?!=)([^\n]*)")


def is_write(value):
    """Assigning nil is not writing a field, it is removing one.

    `rec.backstory = nil` is [A14]'s deliberate clearing and the whole
    point is that the field should not exist. A lookahead cannot say
    this: `\\s*(?!nil\\b)` backtracks to consuming zero spaces and then
    passes, which is how `backstory` was reported dead when it is
    never written at all.
    """
    return not value.lstrip().startswith("nil")
# A function that indexes a record by one of its parameters. The
# second parameter is the field name - `daysWithout(rec, field, today)`.
DYNAMIC_DEF = re.compile(
    r"local function (\w+)\(\s*(\w+)\s*,\s*(\w+)[^)]*\)")

# [B41] Fields the bridge fills with an ITEM'S FULL TYPE. Being read
# is not enough for these: a field holding `Base.PhotoAlbum` that is
# only ever tested for truthiness is a subject the county throws away,
# and it passes every check above while doing it.
#
# `reading` was that shape until [B41] and `keepsake` until [B41] -
# both written from `item.getFullType()` in the bridge, both consumed
# as booleans, so the county knew somebody was carrying SOMETHING and
# never what.
SUBJECT_FIELDS = {
    "reading": "carriedDisplayCategory -> item.getFullType()",
    "keepsake": "carriedMemento -> item.getFullType()",
}

# Fields nothing in the Lua reads on purpose, with where they go.
READ_ELSEWHERE = {
    "beforeXP": "SAO_LeisureSkill retains the measured native XP precondition in its persisted receipt; receipt() and consume() return the whole copied receipt",
    "afterXP": "SAO_LeisureSkill retains the measured native XP postcondition alongside appliedDelta in that same returned receipt",
    "providerName": "SAO_LeisureSkill retains the authenticated provider in its persisted and returned receipt",
    "receiverSourceId": "SAO_LeisureSkill retains the native XP receiver provenance in its persisted and returned receipt",
    "receiverRevision": "SAO_LeisureSkill retains the native XP receiver revision in its persisted and returned receipt",
    "danceInvitation": "SAO_Identity persists the accepted invitation audit; StudyWorld copies the private person record",
    "duetInvitation": "SAO_Identity persists the accepted invitation audit; StudyWorld copies the private person record",
    "gameInputDecision": "SAO_Identity persists the private minigame decision audit; StudyWorld copies the private person record",
    "personalMemoryAdmission": "SAO_Identity global ModData persists the attachment "
                               "audit; StudyWorld copies it into the private person record",
    "recoveryPoseExit": "SAO_Identity global ModData persists the exact-body exit "
                        "audit; StudyWorld copies it into the private person record",
    "greyApplied": "SAO_Appearance guards its own one-shot with it",
    "knowsTradeGround": "recorded for telemetry and the record; the "
                        "county does not act on it yet",
    "returnSaveTouched": "ZAO's ZAOSaveGeneration selects identities that "
                         "entered the cross-file return protocol",
    "lastLivingHealth": "ZAO_Diet snapshots the source person's observed "
                        "living health when a completed human-origin meal "
                        "derives donor-conditioned Afflicted protection",
}


# These two entries are observation/save audit stamps, not decision inputs.
# Verify the actual owner projection instead of exempting a dead field by name.
AUDIT_FIELDS = {"personalMemoryAdmission", "recoveryPoseExit", "danceInvitation", "duetInvitation", "gameInputDecision"}


def audit_projection_present(observer, identity):
    from menu_reach import strip_lua
    observer = strip_lua(observer, strings=False)
    identity = strip_lua(identity, strings=False)
    copier = re.search(
        r"local\s+function\s+copy\(value,\s*path,\s*budget,\s*seen,\s*depth\)"
        r"(?P<body>.*?)\nend", observer, re.S)
    if not copier or not all(re.search(pattern, copier.group("body")) for pattern in (
        r"for\s+_,\s*key\s+in\s+ipairs\(keys\(value\)\)\s+do",
        r"local\s+field\s*=\s*copy\(value\[key\],",
        r"if\s+field\s*~=\s*nil\s+then\s+result\[key\],\s*members\s*=\s*field,",
        r"return\s+result",
    )):
        return False
    return all(re.search(pattern, observer) for pattern in (
        r"local\s+records\s*=\s*SAO\.Identity\.all\(\)\s*"
        r"local\s+recordIds\s*=\s*keys\(records\)",
        r"for\s+_,\s*id\s+in\s+ipairs\(recordIds\)\s+do\s*"
        r"local\s+rec\s*=\s*records\[id\]",
        r'local\s+recordView\s*=\s*\{\}\s*'
        r'for\s+key,\s*value\s+in\s+pairs\(rec\)\s+do\s+'
        r'if\s+key\s*~=\s*"cognition"\s+then\s+'
        r'recordView\[key\]\s*=\s*value\s+end\s+end',
        r'record\s*=\s*copy\(recordView,\s*"people\."\s*\.\.\s*tostring\(id\)',
        r"local\s+function\s+copy\(value,\s*path,\s*budget,\s*seen,\s*depth\)",
    )) and all(re.search(pattern, identity) for pattern in (
        r"ModData\.getOrCreate\(STORE_KEY\)",
        r"function\s+Identity\.all\(\)\s*local\s+s\s*=\s*store\(\)\s*"
        r"return\s+s\s+and\s+s\.records\s+or\s*\{\}\s*end",
    ))


def audit_projection_owned():
    try:
        observer = (ROOT / "tools/world_lab/StudyWorld.lua").read_text(encoding="utf-8")
        identity = (LUA / "shared/SAO_Identity.lua").read_text(encoding="utf-8")
    except OSError:
        return False
    return audit_projection_present(observer, identity)


def files():
    return {p: p.read_text(encoding="utf-8", errors="ignore")
            for p in sorted(LUA.rglob("*.lua"))}


def dynamic_readers(src_all):
    """Functions that index a record by a parameter, and the literals
    their callers pass to it."""
    readers, literals = {}, set()
    for text in src_all.values():
        for m in DYNAMIC_DEF.finditer(text):
            fn, recparam, keyparam = m.group(1), m.group(2), m.group(3)
            body = text[m.end():m.end() + 900]
            if re.search(rf"\b{recparam}\[\s*{keyparam}\s*\]", body):
                readers[fn] = keyparam
    for text in src_all.values():
        for fn in readers:
            for call in re.finditer(rf"\b{fn}\(([^)]*)\)", text):
                for lit in re.findall(r'"(\w+)"', call.group(1)):
                    literals.add(lit)
    return readers, literals


def main():
    src_all = files()
    tree = "".join(src_all.values())

    written = {}
    for path, text in src_all.items():
        for i, line in enumerate(text.splitlines(), start=1):
            s = line.strip()
            if s.startswith("--"):
                continue
            for m in WRITE.finditer(line):
                if not is_write(m.group(2)):
                    continue
                written.setdefault(m.group(1), f"{path.name}:{i}")

    readers, dyn = dynamic_readers(src_all)

    print("=" * 74)
    print(f"FIELDS WRITTEN ONTO A PERSON - {len(written)} of them")
    print("=" * 74)
    print(f"  dynamic readers found: {len(readers)}  "
          f"{', '.join(sorted(readers)) or 'none'}")
    print(f"  field names they are handed: {len(dyn)}  "
          f"{', '.join(sorted(dyn)) or 'none'}")

    dead = []
    audit_owned = audit_projection_owned()
    for field in sorted(AUDIT_FIELDS):
        if field not in READ_ELSEWHERE or not audit_owned:
            dead.append((field, "AUDIT_CONSUMER", 0))
    for field, where in sorted(written.items()):
        # A read is any mention not immediately followed by `=`.
        reads = len(re.findall(rf"\.{field}\b(?!\s*=(?!=))", tree))
        writes = len(re.findall(rf"\.{field}\s*=(?!=)", tree))
        if reads > 0 or field in dyn or field in READ_ELSEWHERE:
            continue
        dead.append((field, where, writes))

    print()
    if dead:
        print("  WRITTEN AND NEVER READ:")
        for field, where, n in dead:
            print(f"    {field:<22} {n} write(s)   {where}")
    else:
        print("  every field written onto a person is read by something")

    # [B41] Being read is not enough for a field holding a subject.
    print()
    print("  SUBJECT FIELDS - the value must be consumed, not just tested")
    for field, source in sorted(SUBJECT_FIELDS.items()):
        if field not in written:
            dead.append((field, "SUBJECT_FIELDS", 0))
            print(f"    NO   {field} is declared a subject field and is "
                  "written nowhere")
            continue
        consumed = bool(re.search(rf"tostring\(\s*\w+\.{field}\s*\)", tree))
        print(f"    {'yes' if consumed else 'NO '}  {field:<10} {source}")
        if not consumed:
            dead.append((field, "SUBJECT_UNREAD", 0))

    print()
    for f, why in sorted(READ_ELSEWHERE.items()):
        seen = f in written
        print(f"  {'yes' if seen else 'NO '}  {f} - {why}")
        if not seen:
            dead.append((f, "READ_ELSEWHERE", 0))

    print()
    print("VERDICT:")
    if dead:
        for field, where, _ in dead:
            if where == "SUBJECT_UNREAD":
                print(f"  FAULT: {field} holds an item's full type and its "
                      "value is never consumed - the county knows somebody "
                      "carries something and never what")
            elif where == "SUBJECT_FIELDS":
                print(f"  FAULT: {field} is declared a subject field and is "
                      "written nowhere - the declaration outlived it")
            elif where == "AUDIT_CONSUMER":
                print(f"  FAULT: {field} is an external audit stamp but its "
                      "owned save/private observer projection is missing")
            elif where == "READ_ELSEWHERE":
                print(f"  FAULT: {field} is named in READ_ELSEWHERE and "
                      "no longer written anywhere - the exemption "
                      "outlived the field")
            else:
                print(f"  FAULT: {field} is written at {where} and read "
                      "by nothing - a fact the simulation establishes "
                      "and cannot act on")
        return 1
    print(f"  31) field reach: {len(written)} fields written, every one "
          f"read; {len(readers)} dynamic reader(s) resolved")
    return 0


if __name__ == "__main__":
    sys.exit(main())
