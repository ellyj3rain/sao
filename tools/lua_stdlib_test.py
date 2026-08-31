#!/usr/bin/env python3
r"""Border 48 - the standard library this engine actually has.

Reported from a live session: the console was flooding and other mods
looked like they had failed to load. The flood was ours -

    java.lang.RuntimeException: Object tried to call nil in offersOf

`SAO_Places.lua:235` read `if not next(out) then return nil end`, and
**`next` is not callable here**. Project Zomboid's Lua is Kahlua, whose
`BaseLib` registers `collectgarbage, debugstacktrace, error, getfenv,
getmetatable, pcall, print, rawequal, rawget, rawset, select, setfenv,
setmetatable, tonumber, tostring, type, unpack` - and no `next`.

[B45] CORRECTION: this border first shipped reading only the six
`se.krka.kahlua.stdlib` classes, and on that basis reported that the
engine has no `require`. It has one - `se.krka.kahlua.require.Require`
installs it from its own package, and 1213 vanilla call sites depend
on it. The registry read was incomplete and the claim built on it was
false. `KNOWN_PRESENT` now holds names the engine's own shipped Lua
proves callable; if the read cannot see one of them, this border
reports its OWN blindness instead of making a claim about the engine.

It threw inside the `pcall` in `Pl.at`, so nothing surfaced but the
log. The county went on choosing places for its dormant half with **no
contents resolved** - the whole of [B38]'s work reading what a room
actually holds, silently inert - and the console filled hard enough to
push the operator's mod-loading phase out of the file, which is how a
defect of ours became "some of my mods did not load".

WHY THIS IS A BORDER AND NOT A NOTE
-----------------------------------
`next` is not exotic. It is the idiomatic Lua emptiness test, and it
will be reached for again. The habitual standard library is a short,
knowable set, and which parts of it exist here is a fact about the
engine that can be read rather than remembered - the same discipline
[B41] used for `IsoGameCharacter` and [B42] for `InventoryItem`.

The registry is extracted from `projectzomboid.jar` itself. The
candidate set is the names a Lua author types without thinking. A call
to a candidate the engine does not register is a fault.

SKIPs when javap or the jar is absent.
"""
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
JAVAP = pathlib.Path(
    r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin\javap.exe")
PZ_DIR = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
# [B50] The engine also defines part of its standard library IN LUA,
# in a stdlib.lua at the install root that Kahlua loads on startup.
# `assert` lives there, and reading only the Java side reported it
# absent - the same mistake [B45] corrected for `require`, made a
# second time in the same place for the same reason.
STDLIB = PZ_DIR / "stdlib.lua"

LIBS = ("se.krka.kahlua.stdlib.BaseLib",
        "se.krka.kahlua.stdlib.TableLib",
        "se.krka.kahlua.stdlib.StringLib",
        "se.krka.kahlua.stdlib.MathLib",
        "se.krka.kahlua.stdlib.OsLib",
        "se.krka.kahlua.stdlib.CoroutineLib",
        # [B45] `require` lives in its OWN package and installs itself
        # separately. Reading only stdlib made this border say the
        # engine has no `require` while 1213 vanilla call sites and the
        # first line of ISPanel.lua say otherwise. The list below is
        # why KNOWN_PRESENT exists.
        "se.krka.kahlua.require.Require")

# Names proven callable by the engine's own shipped Lua, not by memory.
# If the registry read above cannot see one of these, this border is
# reading too few classes and must say so about ITSELF rather than
# make a claim about the engine - which is exactly the mistake [B44]
# shipped and [B45] found.
KNOWN_PRESENT = ("require", "pairs", "pcall", "print", "tostring",
                 # [B50] Defined in stdlib.lua, not in a Java class -
                 # this border called it absent until it read that file.
                 "assert")

# What a Lua author types without thinking. Each is checked against the
# engine's own registry rather than assumed present OR absent - that is
# the point: `select` reads as exotic and IS provided, `next` reads as
# fundamental and is NOT.
HABITUAL = {
    "next", "assert", "xpcall", "loadstring", "load", "dofile",
    "require", "rawlen", "ipairs", "pairs", "select", "unpack",
    "rawget", "rawset", "tonumber", "tostring", "type", "error",
    "pcall", "print", "setmetatable", "getmetatable", "collectgarbage",
}

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from menu_reach import strip_lua                       # noqa: E402


def lua_side():
    """Names the engine's own stdlib.lua defines, in Lua."""
    if not STDLIB.exists():
        return set()
    text = STDLIB.read_text(encoding="utf-8", errors="ignore")
    return set(re.findall(r"^function\s+([a-z][a-zA-Z]*)\s*\(", text,
                          re.M))


def registry():
    if not (JAVAP.exists() and PZ.exists()):
        return None
    names = set()
    for lib in LIBS:
        try:
            done = subprocess.run(
                [str(JAVAP), "-c", "-p", "-cp", str(PZ), lib],
                capture_output=True, text=True, timeout=180)
        except (OSError, subprocess.SubprocessError):
            continue
        names |= set(re.findall(r"String ([a-z][a-zA-Z]*)", done.stdout or ""))
    names |= lua_side()
    return names or None


def main():
    faults = []
    print("=" * 74)
    print("THE STANDARD LIBRARY THIS ENGINE HAS")
    print("=" * 74)

    have = registry()
    if have is None:
        print("  SKIPPED - no javap or no engine jar to read the registry")
        print("  48) lua stdlib: SKIPPED, engine absent")
        return 0

    blind = [n for n in KNOWN_PRESENT if n not in have]
    if blind:
        faults.append(
            "this border cannot see " + ", ".join(f"`{n}`" for n in blind)
            + ", which the engine's own shipped Lua calls - so the "
            "registry read here is INCOMPLETE and every 'absent' below is "
            "unproven. Widen LIBS before trusting a word of it")

    missing = sorted(HABITUAL - have)
    print(f"  engine registers {len(have)} names across "
          f"{len(LIBS)} libraries")
    print(f"  habitual names it does NOT provide: {', '.join(missing)}")

    if "next" in have:
        faults.append(
            "the engine now registers `next`, so this border's account of "
            "why [B44] threw is out of date - re-read it before trusting "
            "anything else here")

    seen_files = sorted(LUA.rglob("*.lua"))
    if not seen_files:
        faults.append(
            "no Lua files were read, so 'nothing calls a name this engine "
            "lacks' is true of an empty set and says nothing about the mod")

    used = {}
    for path in seen_files:
        code = strip_lua(path.read_text(encoding="utf-8", errors="ignore"),
                         strings=False)
        for n, line in enumerate(code.split("\n"), 1):
            # a bare global call: not `:name(`, not `.name(`, not a
            # definition
            for m in re.finditer(r"(?<![\w.:])([a-z][a-zA-Z]*)\s*\(", line):
                name = m.group(1)
                if name in missing:
                    used.setdefault(name, []).append(f"{path.name}:{n}")

    print(f"  Lua files read: {len(seen_files)}")
    total = sum(len(v) for v in used.values())
    print(f"  calls to a name the engine lacks: {total}")
    for name, sites in sorted(used.items()):
        for site in sites:
            faults.append(
                f"{site} calls `{name}()`, which this engine's Lua does "
                f"not provide - it raises \"Object tried to call nil\", and "
                "inside a pcall that is indistinguishable from the feature "
                "quietly doing nothing")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print("  48) lua stdlib: nothing calls a standard-library name this "
          "engine does not have")
    return 0


if __name__ == "__main__":
    sys.exit(main())
