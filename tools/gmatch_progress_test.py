#!/usr/bin/env python3
r"""Border 68 - a gmatch that never ends.

The engine implements `string.gmatch` in its own `stdlib.lua`:

    function string.gmatch(str, pattern)
        local init = 1
        local function gmatch_it()
            if init <= str:len() then
                local s, e = str:find(pattern, init)
                if s then
                    local oldInit = init
                    init = e + 1
                    return str:match(pattern, oldInit)
                end
            end
        end
        return gmatch_it
    end

`init` advances to `e + 1`. For a **zero-width match** `find` returns
`s = i, e = i - 1`, so `init` becomes `i` again - exactly where it
was - and the iterator returns the same empty match forever. Standard
Lua guards against this. This does not.

Measured in the engine, on `"a|b||c"`:

    "[^|]+"   ->  3 pieces, finished
    "[^|]*"   ->  still going at 50,001, stopped only by a counter

In a game that is the Lua thread hung, permanently, with no error and
no log line. It is the worst failure shape this project has a name
for - worse than [B44]'s throw, because a throw at least reaches
`console.txt`.

WHAT THIS CHECKS
----------------
Every `gmatch` pattern in the tree is handed to the engine as
`string.find("", pattern)`. If the engine finds it in an empty string,
the pattern is zero-width-capable and the iterator built from it will
never terminate.

That is not a heuristic about `*` versus `+`. It is the same question
the runtime asks, put to the same runtime.

All ten of our sites currently use patterns ending in `+`, which is
why nothing hangs today. The point is that nothing said so, and the
difference between `+` and `*` here is the difference between a mod
and a locked-up game.

DYNAMIC PATTERNS
----------------
`SAO_Perception.split` builds `"([^" .. sep .. "]+)"` at runtime, so
its text is not in the source to test. It is declared instead, with
the separators it is actually called with - the same argue-or-fix rule
Borders 49, 51, 64 and 67 use.
"""
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
SRC = ROOT / "tools" / "luacheck" / "LuaRun.java"
OUT = ROOT / "java" / "out" / "luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from menu_reach import strip_lua                       # noqa: E402

# Every gmatch, anchored on the word itself so both spellings are
# caught: `string.gmatch(subject, "pat")` and `subject:gmatch("pat")`.
ANY = re.compile(r"gmatch\s*\(")

QUOTED = re.compile(r'"((?:[^"\\]|\\.)*)"')


def call_text(src, open_paren):
    """One call's argument text, respecting nesting and string literals."""
    depth, i, n = 0, open_paren, len(src)
    while i < n:
        c = src[i]
        if c == '"':
            i += 1
            while i < n and src[i] != '"':
                i += 2 if src[i] == "\\" else 1
        elif c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return src[open_paren + 1:i]
        elif c == "\n" and i - open_paren > 300:
            return None
        i += 1
    return None


def literal_pattern(args):
    """The exact final argument, if it is a quoted pattern literal.

    Last, not first. `gmatch(tostring(line or ""), "[^|]+")` carries a
    quoted empty string in its SUBJECT, and a reader taking the first
    literal would test that instead - then report the pattern as
    empty-matching when the real one is fine.

    Three drafts of this border misread these calls with regexes: one
    knew only the two-argument spelling, one anchored two patterns at
    different offsets so they never lined up, and one could not survive
    a subject containing both parentheses and a quote. A call is a
    nested structure; it wanted a scanner, not a pattern.
    """
    if args is None:
        return None
    # Concatenation in the SUBJECT does not make the pattern dynamic.
    # Split top-level arguments while preserving quoted commas/nesting.
    start, depth, quote, i = 0, 0, None, 0
    while i < len(args):
        char = args[i]
        if quote:
            if char == "\\":
                i += 2
                continue
            if char == quote:
                quote = None
        elif char in ('"', "'"):
            quote = char
        elif char in "([{":
            depth += 1
        elif char in ")]}":
            depth -= 1
        elif char == "," and depth == 0:
            start = i + 1
        i += 1
    literal = QUOTED.fullmatch(args[start:].strip())
    return literal.group(1) if literal else None

# Patterns built at runtime, and why they cannot match empty.
DYNAMIC = {
    ("SAO_LeisureMusic.lua", "source-dance-choice"):
        "extracts the two fixed JukeboxMenu onEnableDancing/onDisableDancing function definitions; every pattern requires the nonempty literal function prefix and closing end",
    ("SAO_Perception.lua", "split"):
        "builds `\"([^\" .. sep .. \"]+)\"`. The `+` is in the literal "
        "half, so the pattern needs at least one character whatever the "
        "separator is, and `split` is only ever called with \"|\" and "
        "\":\" - single characters that are inert inside a set",
}


def registered_dynamic(name, args, src):
    """Only the declared split construction and its actual inert separators.

    A filename alone is not authority for another dynamic gmatch site. A new
    construction or separator must be examined rather than inherit this claim.
    """
    if name == 'SAO_LeisureMusic.lua' and args is not None:
        compact = re.sub(r"\s+", "", args)
        declaration = 'localpattern="JukeboxMenu%."..name.."=function%(player%)%s+.-%s+end"'
        source = re.sub(r"\s+", "", src)
        if (compact == 'pattern'
                and declaration in source
                and 'ipairs({"onEnableDancing","onDisableDancing"})' in source
                and 'ifcount~=1thenerror(' in source):
            return (name, 'source-dance-choice')
        return None
    if name != "SAO_Perception.lua" or args is None:
        return None
    compact = re.sub(r"\s+", "", args)
    if compact != 's,"([^"..sep.."]+)"':
        return None
    calls = list(re.finditer(r"\bsplit\s*\(", src))
    separators = []
    for call in calls:
        text = call_text(src, call.end() - 1)
        if text == "s, sep":  # The registered function declaration.
            continue
        pattern = literal_pattern(text)
        if pattern not in ("|", ":"):
            return None
        separators.append(pattern)
    return (name, "split") if separators and set(separators) == {"|", ":"} else None


def build():
    cls = OUT / "LuaRun.class"
    if cls.exists() and cls.stat().st_mtime >= SRC.stat().st_mtime:
        return True
    OUT.mkdir(parents=True, exist_ok=True)
    return subprocess.run(
        [str(JDK / "javac.exe"), "-cp", str(PZ), "-d", str(OUT), str(SRC)],
        capture_output=True, text=True, timeout=300).returncode == 0


def ask_engine(patterns):
    """Which of these does the engine find inside an empty string?"""
    parts = []
    for i, p in enumerate(patterns):
        parts.append(
            'r[#r+1] = (string.find("", P' + str(i) + ') and "Y" or "N")')
    setup = "\n".join(
        'local P' + str(i) + ' = "' + p + '"' for i, p in enumerate(patterns))
    expr = ("(function() " + setup + " local r = {} "
            + " ".join(parts) + ' return table.concat(r) end)()')
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(STDLIB, work / "stdlib.lua")
        for c in OUT.glob("*.class"):
            shutil.copy2(c, work / c.name)
        done = subprocess.run(
            [str(JDK / "java.exe"), "-cp", f"{PZ};.", "LuaRun", "--", expr],
            cwd=str(work), capture_output=True, text=True, timeout=300)
    tail = (done.stdout or "").strip().split("\n")[-1] if done.stdout else ""
    if not tail.startswith("VALUE "):
        return None, (tail or (done.stderr or "").strip())[:200]
    return tail[6:].strip(), None


def main():
    from source_scanner_baseline import Baseline
    baseline = Baseline()
    faults = []
    print("=" * 74)
    print("A GMATCH THAT NEVER ENDS")
    print("=" * 74)

    literal, dynamic, total = {}, [], 0
    for path in sorted(LUA.rglob("*.lua")):
        src = strip_lua(path.read_text(encoding="utf-8", errors="ignore"),
                        strings=False)
        for m in ANY.finditer(src):
            total += 1
            line = src.count("\n", 0, m.start()) + 1
            args = call_text(src, m.end() - 1)
            pat = literal_pattern(args)
            if pat is not None:
                literal.setdefault(pat, []).append(f"{path.name}:{line}")
            else:
                if baseline.preserved(path, line):
                    continue
                registered = registered_dynamic(path.name, args, src)
                dynamic.append((path.name, line, registered))
                if registered == ('SAO_LeisureMusic.lua', 'source-dance-choice'):
                    for name in ('onEnableDancing', 'onDisableDancing'):
                        pattern = 'JukeboxMenu%.' + name + ' = function%(player%)%s+.-%s+end'
                        literal.setdefault(pattern, []).append(f'{path.name}:{line} fixed dynamic variant')

    print(f"  gmatch call sites : {total}")
    print(f"  literal patterns  : {len(literal)}")
    print(f"  built at runtime  : {len(dynamic)}")

    if total == 0:
        faults.append(
            "not one gmatch was found, which cannot be true of a mod that "
            "parses every bridge string it is handed - the reading failed "
            "rather than the code being clean")

    if not (JDK.exists() and PZ.exists() and STDLIB.exists()
            and SRC.exists()):
        print("  SKIPPED the engine check - no JDK, jar, stdlib or runner")
    elif not build():
        faults.append(
            "the VM runner will not compile, so no pattern was put to the "
            "engine and the literal half of this border checked nothing")
    elif literal:
        keys = sorted(literal)
        answer, err = ask_engine(keys)
        if answer is None or len(answer) != len(keys):
            faults.append(
                f"the engine would not test the patterns: {err}")
        else:
            for pat, verdict in zip(keys, answer):
                where = ", ".join(literal[pat])
                print(f"     {'EMPTY-MATCHES' if verdict == 'Y' else 'needs a char'}"
                      f"  {pat!r:<22} {where}")
                if verdict == "Y":
                    faults.append(
                        f"the pattern {pat!r} at {where} matches the empty "
                        "string, and this engine's gmatch advances `init` to "
                        "`e + 1` - which for a zero-width match is where it "
                        "already was. The loop never ends: no error, no log "
                        "line, the Lua thread simply stops. Require at least "
                        "one character")

    for name, line, key in dynamic:
        if key is None:
            faults.append(
                f"{name}:{line} builds its gmatch pattern at runtime, so "
                "this border cannot hand it to the engine. Declare in "
                "DYNAMIC why it cannot match empty - a pattern that can "
                "will hang the game with nothing said")

    for key in sorted(DYNAMIC):
        if not any(registered == key for _, _, registered in dynamic):
            faults.append(
                f"DYNAMIC argues {key[0]}'s `{key[1]}` and it no longer "
                "builds a pattern at runtime - the entry describes no code")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  68) gmatch progress: the engine says none of the "
          f"{len(literal)} literal patterns match an empty string, and the "
          f"{len(DYNAMIC)} built at runtime is argued")
    return 0


if __name__ == "__main__":
    sys.exit(main())
