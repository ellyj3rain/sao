#!/usr/bin/env python3
r"""Border 50 - the engine's own parser, before the game gets it.

[B45] rewrote six `if` conditions across line breaks and said so in
its own record: nothing in `check.sh` would have caught a broken one.
The game would have, at load - which is the worst place to find out,
and which is exactly the shape of the symptom [B44] came from. An
operator seeing that some mods did not load cannot tell a syntax
error in our tree from anything else that went wrong that launch.

Every batch this project ships edits Lua. Twenty-three files, ten
thousand lines, and until now the first thing to read any of it was
the engine.

NOT A REIMPLEMENTATION
----------------------
There is no hand-written Lua parser here and there must never be one -
a parser that disagrees with the engine is worse than no parser,
because it is trusted. This calls the compiler that ships inside
`projectzomboid.jar`: `se.krka.kahlua.luaj.compiler.LuaCompiler`,
driven by `tools/luacheck/LuaSyntax.java`. The verdict is the engine's
verdict, the same discipline [B41] used for `IsoGameCharacter`,
[B42] for `InventoryItem`, and [B44] for the standard library.

Because it is a real compile and not a lint, it also catches what a
lexer would not: Kahlua's own structural limits. A function that
overruns the local-variable or upvalue ceiling is accepted by every
syntax highlighter and refused by this.

The class is built on demand into `java/out/` (gitignored) and rebuilt
whenever the source is newer, so there is no artifact to go stale.

SKIPs when the JDK or the engine jar is absent.
"""
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
SRC = ROOT / "tools" / "luacheck" / "LuaSyntax.java"
OUT = ROOT / "java" / "out" / "luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"
    r"\projectzomboid.jar")


def build():
    cls = OUT / "LuaSyntax.class"
    if cls.exists() and cls.stat().st_mtime >= SRC.stat().st_mtime:
        return True
    OUT.mkdir(parents=True, exist_ok=True)
    done = subprocess.run(
        [str(JDK / "javac.exe"), "-cp", str(PZ), "-d", str(OUT), str(SRC)],
        capture_output=True, text=True, timeout=300)
    if done.returncode != 0:
        print("  could not build the checker:")
        for line in (done.stderr or "").strip().split("\n")[:6]:
            print("    " + line)
        return False
    return True


def main():
    faults = []
    print("=" * 74)
    print("THE ENGINE'S OWN PARSER, ON OUR LUA")
    print("=" * 74)

    files = sorted(LUA.rglob("*.lua"))
    if not (JDK.exists() and PZ.exists() and SRC.exists()):
        print("  SKIPPED - no JDK, no engine jar, or no checker source")
        print("  50) lua syntax: SKIPPED, engine absent")
        return 0
    if not build():
        print()
        print("VERDICT:")
        print("  FAULT: the syntax checker itself will not compile, so "
              "nothing read the Lua this run. A border that cannot run is "
              "not a border that passed")
        return 1

    done = subprocess.run(
        [str(JDK / "java.exe"), "-cp", f"{PZ};{OUT}", "LuaSyntax"]
        + [str(p) for p in files],
        capture_output=True, text=True, timeout=600)
    lines = [x for x in (done.stdout or "").strip().split("\n") if x]

    if not files:
        faults.append(
            "there are no Lua files under mod/42.20/media/lua to read, so "
            "this border's clean verdict would be a statement about an "
            "empty set. [B47] found it printing 'all 0 shipped Lua files "
            "compile' and passing")

    ok = [x for x in lines if x.startswith("OK ")]
    bad = [x for x in lines if x.startswith("FAIL ")]
    print(f"  files read by Kahlua's compiler: {len(ok)} accepted, "
          f"{len(bad)} refused")

    if len(lines) != len(files):
        faults.append(
            f"{len(files)} Lua files were handed to the compiler and "
            f"{len(lines)} verdicts came back - something died mid-run, and "
            "an unread file is not a passing file")
        for line in (done.stderr or "").strip().split("\n")[:4]:
            if line:
                print("    stderr: " + line)

    root = str(ROOT) + "\\"
    for line in bad:
        rest = line[5:].replace(root, "").replace("\\", "/")
        faults.append(
            f"{rest} - the engine's own compiler refuses this file, so the "
            "game will refuse it too, at load, where it looks to an "
            "operator like the mod simply did not load")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  50) lua syntax: all {len(ok)} shipped Lua files compile "
          "under the engine's own Kahlua compiler")
    return 0


if __name__ == "__main__":
    sys.exit(main())
