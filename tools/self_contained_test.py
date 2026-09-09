#!/usr/bin/env python3
r"""Border 114 - the county stands on its own ([C40], DR-035).

No capability of this mod may require another survivor mod, and
nothing of it may run through one unless the player asks. Two paths
did, on every world start: taking the neighbour framework's people
over through its own spawn and teardown functions, and rewriting the
inside of its per-survivor menu. Both are behind one switch that
defaults off. A third - holding their prompts, which replaces two of
their functions with wrappers of ours - had a switch already and
defaulted on; it defaults off now, so a fresh world reaches into
another mod zero times.

What stays always on is a different kind of thing and is checked as
one: the county never treats their people as threats and never
confuses their keys with its own. That reads a few marks and calls
none of their functions - it protects a neighbour's game rather than
using their work.

WHAT THIS HOLDS
---------------
  1. Every reach into a foreign namespace in the Lua tree is inside a
     file that asks the bridge first. A new one appearing anywhere
     else is a fault, whoever wrote it.
  2. The bridge exists, defaults off, and both entry points gate on
     it - the world-start absorption and the menu superimposition.
     Every other door into their namespace defaults off too.
  3. The defensive half calls none of their code: SAOKnox reads marks
     and nothing more.
  4. No manifest requires anything but the loader, and the
     description does not claim a requirement the manifest does not
     carry. [C39] left exactly that untrue for a day because no
     border read the description, which is why this one does.

An optional argv[1] points the checker at another tree root, which is
how its control runs: the pre-batch tree faults at every seam.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
ABSORB = LUA / "client" / "SAO_Absorb.lua"
NEIGHBOURS = LUA / "client" / "SAO_Neighbours.lua"
HARNESS = LUA / "client" / "SAO_Harness.lua"
POPULATION = LUA / "client" / "SAO_Population.lua"
SANDBOX_LUA = LUA / "client" / "SAO_Sandbox.lua"
OPTIONS = ROOT / "mod" / "42.20" / "media" / "sandbox-options.txt"
KNOX = ROOT / "java" / "src" / "com" / "sao" / "engine" / "SAOKnox.java"
CREDITS = ROOT / "CREDITS.md"
REGISTRY = ROOT / "DECISION_REGISTRY.md"
CHECK = ROOT / "tools" / "check.sh"
MANIFESTS = (ROOT / "mod" / "42.20" / "mod.info", ROOT / "mod" / "mod.info")

SWITCH = "NeighbourBridge"

# The other mod's namespace, by every name it has been seen under. A
# bare `KS` is theirs too - [C3] found ours had been testing that name
# for its whole life while their global was the long one.
FOREIGN = re.compile(r"\bKnoxSurvivors\w*|(?<![\w.])KS(?![\w])")

# Files allowed to name it, and what each must do about the switch.
#
#   "gates"   - reads the switch and returns before it reads theirs
#   "reads"   - names it in a way that runs no code of theirs and
#               costs nothing when they are absent, with the reason
ALLOWED = {
    "SAO_Absorb.lua": ("gates",
                       "the absorption itself - the deepest use there is, "
                       "wrapping their spawn and calling their teardown"),
    "SAO_Neighbours.lua": ("gates",
                           "the menu superimposition, and the prompt hold "
                           "that has its own older switch"),
    "SAO_Harness.lua": ("reads",
                        "reads their world table to report on it, and asks "
                        "SAO_Neighbours whether a menu is theirs - which "
                        "answers no while the bridge is closed"),
    "SAO_Population.lua": ("reads",
                           "reads their world table for the census and asks "
                           "their namespace whether a body is one of theirs; "
                           "drives nothing"),
    "SAO_Sandbox.lua": ("reads",
                        "names two of their sandbox dials to leave them "
                        "alone, which is the opposite of using them"),
    "SAO_Claims.lua": ("reads",
                       "[C81] the holder constant, named ONCE so that the "
                       "twenty-four branches that used to say `rec.knox` "
                       "can ask a property instead. It is a string in a "
                       "table and reaches no namespace of theirs; a county "
                       "with them absent reads it and finds nobody held"),
}


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""


def strip_comments(text):
    out = []
    for line in text.split("\n"):
        at = line.find("--")
        out.append(line[:at] if at >= 0 else line)
    return "\n".join(out)


def main():
    faults = []
    print("=" * 74)
    print("THE COUNTY STANDS ON ITS OWN")
    print("=" * 74)

    # 1. Who names them, and is that file allowed to.
    named = {}
    for path in sorted(LUA.rglob("*.lua")):
        hits = FOREIGN.findall(strip_comments(read(path)))
        if hits:
            named[path.name] = len(hits)
    print("     names the neighbour: " + (", ".join(
        "%s (%d)" % kv for kv in sorted(named.items())) or "nobody"))
    for name, count in sorted(named.items()):
        if name not in ALLOWED:
            faults.append(
                "%s reaches into another mod's namespace %d time(s) and is not "
                "one of the files allowed to. A county that stands on its own "
                "has one door, not a door per file" % (name, count))
    for name, (kind, _) in sorted(ALLOWED.items()):
        if name not in named and (LUA / "client" / name).exists():
            print("     note: %s no longer names them at all" % name)

    # 2. The switch, and the two gates.
    options = read(OPTIONS)
    declared = re.search(
        r"option SurvivorAwareness\.%s \{\s*type = boolean, default = (\w+)"
        % SWITCH, options)
    if not declared:
        faults.append("%s is not on the options page, so the two paths that run "
                      "another mod's code have no door at all" % SWITCH)
    elif declared.group(1) != "false":
        faults.append("%s defaults to %s. Off is the whole point: a fresh world "
                      "must run nothing through another author's code"
                      % (SWITCH, declared.group(1)))
    else:
        print("     the bridge: declared, default off")

    # And every other door into their namespace, by the same law: a
    # fresh world must reach into another mod zero times. The prompt
    # hold replaces two of their functions with wrappers of ours, which
    # is a reach whatever it is for, and it used to default on.
    for other in ("HoldNeighbourPrompts",):
        found = re.search(
            r"option SurvivorAwareness\.%s \{\s*type = boolean, default = (\w+)"
            % other, options)
        if not found:
            faults.append("%s has gone from the options page" % other)
        elif found.group(1) != "false":
            faults.append(
                "%s defaults to %s. It reaches into another mod's namespace to "
                "do its job, so a fresh world doing it means nobody asked"
                % (other, found.group(1)))
        else:
            print("     %s: default off" % other)

    absorb, neighbours = read(ABSORB), read(NEIGHBOURS)

    # The world-start handler's own body, not the whole file. Read
    # against the file, `wrapSpawnActor(ns)` matches its own DEFINITION
    # three hundred lines above the gate and the order test inverts -
    # which is this border's own first finding, against correct code.
    at = absorb.find("Events.OnGameStart.Add(function()")
    start_body = absorb[at:absorb.find("\nend\n", at)] if at >= 0 else ""

    gates = {
        # The order matters, not just the presence: the ask must come
        # before the first read of their namespace on that path.
        "the world-start absorption asks before it looks":
            "if not bridgeOpen() then" in start_body
            and "namespace()" in start_body
            and start_body.index("if not bridgeOpen() then")
                < start_body.index("namespace()"),
        "the ten-minute mirror asks first":
            absorb.count("if not bridgeOpen() then return end") >= 1,
        "the absorption's door reads the switch":
            "sv.%s == true" % SWITCH in absorb,
        "the menu prediction asks first":
            "function Nb.willSuperimpose(recId, worldobjects)\n    if not Nb.bridgeOpen() then return false end"
            in neighbours,
        "the menu rewrite asks first":
            "local function superimposePersonRoot(playerNum, context, worldobjects)\n    if not Nb.bridgeOpen() then return end"
            in neighbours,
        "the menu's door reads the switch":
            "sv.%s == true" % SWITCH in neighbours,
    }

    # 3. The defensive half uses none of their code.
    knox = read(KNOX)
    calls = re.findall(r"\bKnoxSurvivors\w*\s*\.\s*\w+\s*\(", knox)
    gates["the defensive predicate calls none of their functions"] = not calls
    gates["and reads their marks through the engine"] = (
        "getVariableBoolean" in knox and "getModData" in knox)

    # 4. The manifests and the description.
    for manifest in MANIFESTS:
        text = read(manifest)
        require = re.search(r"^require=(.*)$", text, re.M)
        if require:
            faults.append("%s requires %s" % (manifest.parent.name,
                                              require.group(1).strip()))
        description = re.search(r"^description=(.*)$", text, re.M)
        body = description.group(1) if description else ""
        for claimed in ("Infirmities", "Even More Traits", "twbInfirmities",
                        "EvenMoreTraits"):
            if claimed in body:
                faults.append(
                    "%s's description tells the player the mod requires '%s' "
                    "and the manifest requires nothing. A description is read "
                    "by every player and by no border until this one"
                    % (manifest.parent.name, claimed))
        if "ZombieBuddy" not in body:
            faults.append("%s's description does not name the one requirement "
                          "there is" % manifest.parent.name)

    gates["the credits say nothing of ours runs through theirs"] = (
        "nothing of this county's runs through it" in read(CREDITS))
    gates["the registry carries the ruling"] = (
        "## DR-035 - The county stands on its own" in read(REGISTRY))
    gates["the gate runs this border"] = "tools/self_contained_test.py" in read(CHECK)

    print()
    for k, v in gates.items():
        print(f"  {'yes' if v else 'NO '}  {k}")
        if not v:
            faults.append(k)

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print("  FAULT: " + f)
        return 1
    print("  114) the county stands on its own: one door, closed by default; "
          "what is always on uses none of their code; nothing required but "
          "the loader")
    return 0


if __name__ == "__main__":
    sys.exit(main())
