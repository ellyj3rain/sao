#!/usr/bin/env python3
r"""Border 33 - the player's own eyes reach the player's own belief store.

[B27] shipped the Lua for this and wrote a good comment about it:

    The player perceives through the SAME function every survivor does.
    ... This is what gives them something to tell: you cannot pass on
    what you never took in.

It never once ran. `SAOBridge.perceive` opened with

    if (!(object instanceof SAOIsoPlayerShell shell)) { return ""; }

and the real player is a plain IsoPlayer, so for seventy-nine batches
the player's every scan came back empty. They could relay what somebody
TOLD them and could never relay what they SAW.

WHY NOTHING CAUGHT IT
---------------------
`P.observe` creates the store before it ever reaches the bridge:

    local b = store(id)            -- store exists from here on
    ...
    if seen ~= "" then             -- every belief write is inside this

So `P.beliefs[playerKey]` was a real, live, growing-scanCount table that
contained nothing. `P.tell` opens `if not from then return 0 end`, which
therefore never fired. Nothing was nil, nothing errored, no log line was
written, and the menu option simply never appeared. **The existence of
the player's belief store is not evidence that the player perceives**,
and any check that asserts the store exists is measuring the wrong
thing. This one asserts the chain instead.

WHAT IT READS
-------------
Nothing this file asserts is modelled here. Three artifacts, none of
them authored by this mod's Python:

  1. projectzomboid.jar - is the real player's class actually an
     IsoGameCharacter? Walked up the extends chain with javap. If the
     engine ever reparents IsoPlayer, the widening is wrong and this
     says so rather than assuming.
  2. SAO.jar - the SHIPPED bytecode of `perceive`: the type its
     instanceof gate admits, and the descriptor of the `scan` it
     dispatches to. Source comments cannot satisfy this.
  3. The shipped Lua - that the real player object is handed to
     Perception.observe on the tick.

Break any one link and the player is deaf and blind to their own life.
"""
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
SHIPPED = ROOT / "mod" / "42.20" / "media" / "java" / "SAO.jar"

JAVAP = pathlib.Path(
    r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin\javap.exe")
PZ = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"
    r"\projectzomboid.jar")

# The class the engine hands us for the person at the keyboard.
REAL_PLAYER = "zombie.characters.IsoPlayer"
# The type the scanner must be willing to take.
WIDE = "zombie.characters.IsoGameCharacter"


def javap(jar, *classes, code=False):
    args = [str(JAVAP)]
    if code:
        args.append("-c")
    args += ["-cp", str(jar), *classes]
    try:
        done = subprocess.run(args, capture_output=True, text=True,
                              timeout=180)
    except (OSError, subprocess.SubprocessError) as exc:
        return None, str(exc)
    if done.returncode != 0 and not done.stdout.strip():
        return None, (done.stderr or "").strip()[:200]
    return done.stdout, None


sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from menu_reach import strip_lua                       # noqa: E402

# GOVERNANCE's "prose is not code": a link that greps a call form passes
# on the comment explaining the call after the call itself is gone. That
# cost `save_compat_test` twenty-six batches of false "0 dropped", and
# it is live here - the handoff below sits four lines under a fifteen-
# line comment block naming everything this border looks for, so
# commenting the call out would leave every identifier in place.
#
# `strip_lua` already existed for exactly this and blanks comments AND
# string bodies while preserving offsets, so a match still points at the
# real file. This first shipped with a second copy of that stripper -
# two spellings of one rule, which is the defect [B40] is named for -
# and reads the shared one instead.
decommented = strip_lua


def ancestry(start):
    """Walk the engine's own extends chain, one javap call per hop."""
    chain, seen, current = [start], {start}, start
    for _ in range(12):
        out, err = javap(PZ, current)
        if out is None:
            return chain, err
        m = re.search(r"\bclass\s+\S+\s+extends\s+([\w.$]+)", out)
        if not m:
            return chain, None
        parent = m.group(1)
        chain.append(parent)
        if parent in seen or parent == "java.lang.Object":
            return chain, None
        seen.add(parent)
        current = parent
    return chain, "chain did not terminate"


def main():
    faults = []

    print("=" * 74)
    print("THE PLAYER'S OWN EYES")
    print("=" * 74)

    # -- 1. The engine's hierarchy, not our belief about it ------------
    if not PZ.exists():
        print(f"  SKIPPED - no engine jar at {PZ}")
        print("  33) player eyes: SKIPPED, engine jar absent")
        return 0
    if not JAVAP.exists():
        print(f"  SKIPPED - no javap at {JAVAP}")
        print("  33) player eyes: SKIPPED, javap absent")
        return 0

    chain, err = ancestry(REAL_PLAYER)
    print(f"  engine hierarchy: {' -> '.join(c.split('.')[-1] for c in chain)}")
    if err:
        print(f"    (walk ended: {err})")
    if WIDE not in chain:
        faults.append(
            f"{REAL_PLAYER} is not a {WIDE} in this build - the scanner's "
            "parameter type cannot accept the real player")

    # -- 2. The shipped bytecode, not the source ----------------------
    if not SHIPPED.exists():
        faults.append(f"no shipped jar at {SHIPPED}")
        print("\nVERDICT:")
        for f in faults:
            print(f"  FAULT: {f}")
        return 1

    out, err = javap(SHIPPED, "com.sao.bridge.SAOBridge", code=True)
    if out is None:
        print(f"  could not read shipped bytecode: {err}")
        faults.append("the shipped jar would not disassemble")
        out = ""

    body = ""
    m = re.search(r"^  public java\.lang\.String perceive\(java\.lang\."
                  r"Object\);\n(.*?)(?=\n  \S|\Z)", out, re.S | re.M)
    if not m:
        faults.append("SAOBridge.perceive(Object) is not in the shipped "
                      "jar - the Lua calls a method that cannot answer")
    else:
        body = m.group(1)

    gates = re.findall(r"instanceof\s+#\d+\s+//\s*class\s+(\S+)", body)
    gates = [g.replace("/", ".") for g in gates]
    print(f"  perceive admits:  {', '.join(gates) or 'nothing'}")
    if not gates:
        faults.append("perceive has no instanceof gate at all - its "
                      "shape is not what this border was written for")
    elif not any(g in chain for g in gates):
        faults.append(
            f"perceive's gate admits {gates} and the real player is a "
            f"{REAL_PLAYER}, which is none of them - every scan the "
            'player makes returns "" and their store stays empty')

    calls = re.findall(
        r"invokestatic\s+#\d+\s+//\s*Method\s+"
        r"com/sao/engine/SAOPerceptionScanner\.scan:\(L([^;]+);\)", body)
    calls = [c.replace("/", ".") for c in calls]
    print(f"  dispatches to:    scan({', '.join(calls) or 'nothing'})")
    if not calls:
        faults.append("perceive does not dispatch to "
                      "SAOPerceptionScanner.scan - the chain is cut "
                      "between the bridge and the scanner")
    elif not any(c in chain for c in calls):
        faults.append(
            f"scan takes {calls}, which the real player is not - the "
            "gate may admit them but the scanner will not")

    # -- 3. The shipped Lua hands over the real player -----------------
    #
    # NOT a proximity match. An earlier form of this link asked only
    # whether a `getSpecificPlayer(0)` appeared within 600 characters of
    # a `Perception.observe(`, which is the "prose is not code" defect
    # one level up: the two calls can sit beside each other while the
    # thing actually handed over is something else entirely. What has
    # to be true is that the BODY argument is the object the engine
    # named as the player, so the binding is followed by name.
    tree = "".join(p.read_text(encoding="utf-8", errors="ignore")
                   for p in sorted(LUA.rglob("*.lua")))
    code = decommented(tree)

    def bodied(text):
        """The variable the engine bound, in observe's BODY position."""
        for bind in re.finditer(
                r"local\s+(\w+)\s*=\s*getSpecificPlayer\(\s*0\s*\)", text):
            var = bind.group(1)
            window = text[bind.end():bind.end() + 600]
            # observe(id, body, tick, asleep) - the body is second.
            if re.search(r"Perception\.observe\(\s*[^,()]+,\s*"
                         + re.escape(var) + r"\s*[,)]", window):
                return var
        return None

    handoff = bodied(code)
    if handoff:
        told = ("`" + handoff + "`, bound from getSpecificPlayer(0), is the "
                "body argument to Perception.observe")
    else:
        told = "NOTHING"
    print("  lua hands over:   " + told)
    if not handoff:
        if bodied(tree):
            why = (" - the handoff survives only inside a COMMENT; the "
                   "code that ran is gone")
        elif re.search(r"getSpecificPlayer\(\s*0\s*\)(?:.|\n){0,600}?"
                       r"Perception\.observe\(", code):
            why = (" - a getSpecificPlayer(0) does sit near an observe "
                   "call, but the object being scanned is not the one it "
                   "bound")
        else:
            why = " - the player never scans"
        faults.append(
            "no Lua path hands the real player to Perception.observe as "
            "the body it scans" + why + ", whatever the Java would allow")

    # -- The thing that hid this ---------------------------------------
    perc = decommented((LUA / "shared" / "SAO_Perception.lua").read_text(
        encoding="utf-8", errors="ignore"))
    guarded = re.search(r'if\s+seen\s*~=\s*""\s+then', perc)
    print()
    print("  note: P.observe creates the store BEFORE it reaches the")
    print("  bridge and writes beliefs only inside "
          f"{'`if seen ~= \"\" then`' if guarded else '(guard not found)'}.")
    print("  A live store with a rising scanCount is what an EMPTY")
    print("  player looks like. Store existence proves nothing.")
    if not guarded:
        faults.append(
            "the `seen ~= \"\"` guard in P.observe is gone - this "
            "border's account of the failure no longer matches the code")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print("  33) player eyes: the real player is an IsoGameCharacter, "
          "the shipped gate admits one,")
    print("      the shipped scan takes one, and the tick hands the "
          "player over - they see for themselves")
    return 0


if __name__ == "__main__":
    sys.exit(main())
