#!/usr/bin/env python3
r"""Border 54 - a pass that survives the artifact being gone.

Border 32 already claims *"every one able to fail"*. Its test is
`FAILS.search(src)` - it greps each mirror's own source for a `return
1`. That proves a fail path exists in the TEXT. It proves nothing
about whether that path is reachable with real data.

Which is how [B46]'s Border 52 shipped a draft that printed `call
sites with a tick argument: 0` and reported clean: it had a `return 1`,
so Border 32 was satisfied, and it was examining nothing.

It is the same mistake that put the Category header flicker in the
operator's game. A previous session searched for `ISResizableButton.lua`,
found nothing, and concluded the class was absent - the file is spelled
`ISResizeableButton.lua`, with an extra 'e'. In both cases a search
that could not see the thing was reported as the thing not being there.

THE TEST
--------
Run every gated border against a BLINDED tree: the whole repository as
it stands, with `mod/42.20/media/lua` emptied. A border that reads the
mod and still prints its clean verdict is not reading the mod. Its pass
is a statement about an empty set, and an empty set satisfies almost
any claim you can phrase - "nothing calls a name the engine lacks" is
true of no code at all.

That is a live check, not a grep, so it cannot be satisfied by a fail
path nobody reaches.

On its first run it found three:

  * `lua_syntax_test` - printed **"all 0 shipped Lua files compile"**
    and passed, two batches after [B45] shipped it
  * `lua_stdlib_test` - "nothing calls a standard-library name this
    engine does not have", of nothing
  * `item_api_test` - zero call sites examined, clean verdict

WHAT IS DECLARED, AND WHY THAT IS NOT A LOOPHOLE
------------------------------------------------
Some borders genuinely do not read the mod's Lua - they read the
documents, the session state, or the tool directory. Blinding the Lua
must not move them, and a fault for standing still would be noise.

So they are declared, with what they DO read. The declaration is
checked in both directions: a border that stops surviving blinding has
started reading the Lua and its entry is now false, which is a fault.
An entry naming a border that no longer exists is a fault. The list
cannot quietly grow, because adding to it is the only way to make this
border pass and the reason has to be written down.

FOUR STATES, NOT A BOOL
-----------------------
[B50] found the first draft reading four different outcomes as one
bool, and being wrong about a border because of it. They are now
separate:

  * **clean**   - it ran and passed with no Lua. Vacuous unless declared.
  * **refused** - it ran and went red. Correct: it reads the Lua.
  * **absent**  - check.sh invokes it and `git ls-files` does not list
    it. Not a verdict at all; the border exists on one machine.
  * **silent**  - it ran and printed nothing, so it threw. **Counted,
    not faulted.** This border exists to catch a *clean verdict about
    an empty set*; a traceback is the loud opposite of that. Seventeen
    mirrors do this, and saying so is worth more than pretending it is
    the defect this border is named for.
"""
import pathlib
import re
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

ROOT = pathlib.Path(__file__).resolve().parent.parent
TOOLS = ROOT / "tools"
CHECK = TOOLS / "check.sh"
LUA_REL = pathlib.Path("mod") / "42.20" / "media" / "lua"
VERDICT = re.compile(r"^  \d+\)", re.M)

# Borders that do not read the mod's Lua at all, and what they read
# instead. Blinding the Lua cannot move them, so surviving it is
# correct rather than vacuous.
NOT_ABOUT_LUA = {
    "doc_currency_test.py":
        "reads the markdown headers and VERSION - documents, not code",
    "state_counts_test.py":
        "[B52] counts batch records, borders and gated mirrors, and "
        "checks SESSION_STATE.md states those figures. Its subject is "
        "how much of this tree there is; the mod's Lua is one of the "
        "things counted and never one of the things read",
    "session_state_test.py":
        "reads SESSION_STATE.md against BATCH_LOG.md; the Lua has no "
        "opinion about which batch is current",
    "gate_reach_test.py":
        "reads tools/ and check.sh. It is the border about borders, and "
        "the mod's Lua is not its subject",
    "engine_facts_test.py":
        "[B50] reads the ENGINE - Kahlua's behaviour, the jar's "
        "bytecode, the install root's stdlib.lua. Its whole subject is "
        "the ground this mod stands on rather than the mod, so blinding "
        "our Lua correctly moves it not at all",
    "art_derived_test.py":
        "[B51] reads the shipped PNGs and regenerates them from "
        "tools/make_art.py. Its subject is two images and the "
        "arithmetic that draws them; the mod's Lua neither draws the "
        "art nor reads it, so removing it cannot change whether the "
        "icon in the repository is the icon the generator makes",
    "hibernation_pact_test.py":
        "[B51] reads SAOHibernation.java - both ends of a record that "
        "goes Java -> the SAVE -> Java. That there is no Lua end IS "
        "this border's subject: Lua carries the packed string and "
        "never looks inside it, which is why Border 15 could not pair "
        "it and why this exists. Surviving a blinding is the claim, "
        "not an accident of it",
    "bridge_safety_test.py":
        "[B50] reads java/src and walks the bridge's call graph. Lua is "
        "what CALLS these methods, not what makes them exception-safe, "
        "so removing it cannot change whether a path reaches a catch",
    "protocol_field_test.py":
        "[B50] reads java/src - the delimited strings the Java side "
        "builds before any Lua sees them. The Lua half is what those "
        "strings are read BY, not what they are built by, so removing "
        "it cannot change whether a builder sanitises its own fields",
}


def gated():
    """The mirrors check.sh actually invokes, both spellings."""
    src = CHECK.read_text(encoding="utf-8", errors="ignore")
    named = set(re.findall(r"tools/([a-z_0-9]+)\.py", src))
    loop = re.search(r"for mirror in \\?\n(.*?)\ndo", src, re.S)
    if loop:
        named |= set(re.findall(r"([a-z_0-9]+_test)", loop.group(1)))
    return {n + ".py" for n in named if (TOOLS / (n + ".py")).exists()}


def blinded_tree(dest):
    """The tracked working tree, with every shipped Lua file removed."""
    listed = subprocess.run(["git", "ls-files"], cwd=str(ROOT),
                            capture_output=True, text=True, timeout=300)
    if listed.returncode != 0:
        return False
    for rel in listed.stdout.split("\n"):
        rel = rel.strip()
        if not rel:
            continue
        src = ROOT / rel
        if not src.is_file() or src.suffix == ".lua":
            continue
        out = dest / rel
        out.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, out)
    (dest / LUA_REL).mkdir(parents=True, exist_ok=True)
    return True


def run_here(name):
    """The same mirror, unblinded, so "moved" means moved.

    [B52] added Border 77, which made SESSION_STATE's counts stale,
    which turned Border 76 red - and this border then reported that
    `state_counts_test.py` had started reading the mod's Lua, because
    all it knew was that the blinded run went red. It was red either
    way. A border cannot be MOVED by blinding if it was already
    refusing; the comparison has to be against the same border run
    against the real tree.
    """
    done = subprocess.run([sys.executable, "tools/" + name], cwd=str(ROOT),
                          capture_output=True, text=True, timeout=600)
    return done.returncode == 0


def run_blind(dest, name):
    """One of: 'clean', 'refused', 'absent', 'silent'.

    The first draft returned a bool - `returncode == 0 and a verdict
    line`. That reads four different things as one, and [B50] paid for
    it: a border written that day was invoked by check.sh but not yet
    `git add`ed, so `git ls-files` never copied it into the blinded
    tree, so the subprocess could not start, so it "did not survive
    blinding", so its declaration was reported false.

    A border that was not there was reported as a border that failed.
    That is the ISResizableButton mistake in the instrument written to
    catch the ISResizableButton mistake - which is the argument for
    separating "ran and refused" from "was never asked".
    """
    if not (dest / "tools" / name).is_file():
        return name, "absent"
    done = subprocess.run([sys.executable, "tools/" + name], cwd=str(dest),
                          capture_output=True, text=True, timeout=600)
    if not (done.stdout or "").strip():
        return name, "silent"
    if done.returncode == 0 and VERDICT.search(done.stdout):
        return name, "clean"
    return name, "refused"


def main():
    faults = []
    print("=" * 74)
    print("A PASS THAT SURVIVES THE ARTIFACT BEING GONE")
    print("=" * 74)

    mirrors = sorted(gated())
    if not mirrors:
        print()
        print("VERDICT:")
        print("  FAULT: check.sh invokes no mirrors this border can see, so "
              "it would be reporting on an empty set - which is the exact "
              "defect it exists to catch")
        return 1

    dest = ROOT / "java" / "out" / "blind"
    shutil.rmtree(dest, ignore_errors=True)
    dest.mkdir(parents=True, exist_ok=True)
    if not blinded_tree(dest):
        print()
        print("VERDICT:")
        print("  FAULT: could not build the blinded tree, so no border was "
              "tested. A border that cannot run is not a border that passed")
        return 1

    with ThreadPoolExecutor(max_workers=8) as pool:
        results = dict(pool.map(lambda n: run_blind(dest, n), mirrors))
    shutil.rmtree(dest, ignore_errors=True)

    survivors = sorted(n for n, state in results.items() if state == "clean")

    for name in sorted(n for n, st in results.items() if st == "absent"):
        faults.append(
            f"check.sh invokes {name} and `git ls-files` does not list it, "
            "so it is not in the repository - it exists on this machine and "
            "nowhere else. Anyone who clones this tree gets a gate that "
            "references a border it does not have. `git add` it")
    silent = sorted(n for n, st in results.items() if st == "silent")
    print(f"  gated mirrors run blind: {len(mirrors)}")
    print(f"  passed with no Lua     : {len(survivors)}  "
          f"({', '.join(survivors) or 'none'})")
    print(f"  threw with no Lua      : {len(silent)}  (not a fault here - a "
          "traceback is the loud opposite of a vacuous pass)")
    print(f"  declared not-about-Lua : {len(NOT_ABOUT_LUA)}")

    for name in survivors:
        if name in NOT_ABOUT_LUA:
            continue
        faults.append(
            f"{name} passes with every Lua file removed. Its verdict is a "
            "statement about an empty set, and an empty set satisfies "
            "almost any claim - so the pass says nothing about the mod. "
            "Make it refuse an empty reading, or declare in NOT_ABOUT_LUA "
            "what it reads instead")

    for name, why in sorted(NOT_ABOUT_LUA.items()):
        if not (TOOLS / name).exists():
            faults.append(
                f"NOT_ABOUT_LUA declares {name} and no such border exists - "
                "the exemption outlived its subject")
        elif name not in results:
            faults.append(
                f"NOT_ABOUT_LUA declares {name} and check.sh does not run "
                "it, so this border never tested the claim")
        elif results[name] in ("refused", "silent") and run_here(name):
            faults.append(
                f"{name} is declared as not reading the mod's Lua, and "
                "blinding the Lua now changes its verdict - so it does read "
                "it. The entry is false; delete it and let the border stand "
                "on the real test")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  54) vacuous pass: all {len(mirrors)} gated mirrors were run "
          f"against a tree with no Lua in it, and the {len(NOT_ABOUT_LUA)} "
          "that still passed are the ones that never read it")
    return 0


if __name__ == "__main__":
    sys.exit(main())
