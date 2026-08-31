#!/usr/bin/env python3
r"""Border 72 - a per-id cache that outlives the id.

`Identity.markDead` says it plainly:

    Death is durable: the record stays (a person existed and died
    there), the body's corpse belongs to the engine, and the world does
    not refill the loss immediately.

That is a design decision and a good one. The county remembers its
dead. **Nothing else was told to forget them.**

[B51] found `SAO.Perception.forget` and `SAO.Voice.forget` already
written - the exactly-right functions, nilling the exactly-right
tables - and called from ONE place: `SAO_Harness` tearing down a test
id. So every survivor who ever died left their beliefs about the whole
world and their last spoken line in memory for the rest of the
session, and two pair-keyed cooldown tables kept an entry for every
pair they had ever met or argued with, entries nothing would read
again.

That is the written-but-never-reached class, and it is invisible to
every other border here: the code is correct, the tables are right,
the functions exist. The only thing missing is a caller.

WHAT THIS CHECKS
----------------
Every module-scope table indexed by a survivor id is declared with the
function that clears it, and that function must be **reachable from a
death**: either `Identity.markDead` names it, or the function that
clears the table calls `Identity.markDead` itself.

Two directions, so the list describes the tree rather than the tree of
some earlier batch:

  * a declared cache whose table or forget has gone is a fault
  * a per-id cache nobody declared is a fault

The second is what makes this hold up. A new cache keyed by id is the
easiest thing in the world to add, and the day it is added is the only
day anybody is thinking about who clears it.

WHY NOT JUST DELETE THE DEAD
----------------------------
Because the record staying is the point - graves, causes of death, the
memorial in the UI and `diedAtHours` all read it, and [B41] already
paid for one field in that record. The dead are kept; the caches that
were only ever about the living are not.
"""
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from lua_read import function_body

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
IDENTITY = "SAO_Identity.lua"
MARK_DEAD = "markDead"

# Every module-scope table keyed by a survivor id, the function that
# clears one id out of it, and how that function is reached from a
# death.
#
#   "named"  - Identity.markDead names the forget in its own body
#   "calls"  - the clearing function calls Identity.markDead itself,
#              so the clear and the death are the same event
CACHES = {
    ("SAO_Perception.lua", "P.beliefs"): (
        "P.forget", "named",
        "everything one survivor believes about the world - zombies, "
        "people, factions and places, four tables per believer. The "
        "largest of these by far, and the one that had a forget "
        "nobody called"),
    ("SAO_Voice.lua", "lastSpokeMs"): (
        "V.forget", "named",
        "the wall clock of a survivor's last line, for the ten-second "
        "cooldown"),
    ("SAO_Voice.lua", "lastLine"): (
        "V.forget", "named",
        "the last thing a survivor said, so they do not say it twice "
        "in a row"),
    ("SAO_Population.lua", "dormantLastMet"): (
        "Pop.forgetPairs", "named",
        "a PAIR-keyed meeting clock - one entry per pair of dormant "
        "survivors who have crossed paths, quadratic in the county and "
        "unreadable by anybody once either of them is dead"),
    ("SAO_Standing.lua", "politickAt"): (
        "S.forgetPolitics", "named",
        "a PAIR-keyed doctrine clock, the same shape and the same "
        "problem"),
    ("SAO_Controller.lua", "Ctl.agents"): (
        "updateAgent", "calls",
        "the live agent registry. Cleared on both death branches "
        "INLINE rather than through markDead, which is correct - this "
        "is the controller's own teardown order and moving it into a "
        "shared module would be worse. It is declared so the census is "
        "the whole census"),
    ("SAO_Controller.lua", "agentFaults"): (
        "Ctl.forget", "named",
        "a per-agent fault counter. It clears itself at three, so a "
        "survivor who faulted twice and then died kept their count "
        "forever - one integer, and the reason to fix it is that "
        "\"one integer\" is how every one of these starts"),
    ("SAO_Controller.lua", "Ctl.agents"): (
        "updateAgent", "calls",
        "the live agent registry. Cleared on both death branches "
        "INLINE rather than through markDead, which is correct - this "
        "is the controller's own teardown order and moving it into a "
        "shared module would be worse. Declared so the census is the "
        "whole census"),
    ("SAO_Body.lua", "Body.active"): (
        "SAO_Controller.lua:updateAgent", "calls",
        "the engine handle for a spawned body. [B51] made both death "
        "branches clear BOTH handle tables: the passive branch cleared "
        "only `knox` and the other only `active`, which is very "
        "probably right about which agents are in which - and nilling "
        "an absent key costs nothing, while being very probably right "
        "costs a batch the day it stops being true"),
    ("SAO_Body.lua", "Body.knox"): (
        "SAO_Controller.lua:updateAgent", "calls",
        "the engine handle for a Knox inhabitant the county adopted, "
        "cleared on both death branches for the same reason"),
    ("SAO_Locomotion.lua", "Loco.jobs"): (
        "Loco.cancel", "named",
        "a survivor's queued move, holding a reference to their body. "
        "`Loco.cancel` was reached only from `Ctl.drop`, and death "
        "clears the agent registry inline without going through it - "
        "so every dead survivor's job stayed, holding their corpse"),
}

# Module-scope tables this border's shape rule matches and that are
# NOT keyed by a survivor id. Declared rather than quietly narrowed,
# because the rule that catches them is the same rule that catches the
# real ones and loosening it would cost more than it saves.
NOT_A_SURVIVOR_ID = {
    ("SAO_Places.lua", "Pl.cache"): (
        "keyed by `def:getID()` - a BUILDING id out of the engine's "
        "own grid, not a person. Its own comment says so: \"the cache "
        "is keyed by building id and origin, both of which belong to "
        "one world\", and `Pl.reset()` drops the whole thing on a "
        "world change, which is the right lifetime for it. The shape "
        "rule matched a local named `id`; being keyed by an id is not "
        "the same as being keyed by a survivor"),
}

# What an index has to look like to be a survivor id. `subFaults[name]`
# is keyed by subsystem name, of which there are eight, and is not one
# of these.
ID_INDEX = re.compile(
    r"^(id[A-Za-z0-9]*|[a-z][A-Za-z0-9]*Id|rec\.id|pairKey"
    r"|tostring\(\s*id[A-Za-z0-9]*\s*\))$")

DECL = re.compile(
    r"^(?:local\s+([A-Za-z_]\w*)\s*=\s*\{\}"
    r"|([A-Za-z_]\w*\.[A-Za-z_]\w*)\s*=\s*(?:\2\s*or\s*)?\{\})", re.M)


def indexed(table):
    """`table[` in either spelling.

    A declaration reads `P.beliefs` and the code that clears it reads
    `P.beliefs[id] = nil`, so the qualified form has to match. A bare
    local reads `dormantLastMet[key]` and must NOT match somebody
    else's `other.dormantLastMet`. The first draft used one negative
    lookbehind for both and so rejected every qualified name - it
    reported that `P.forget` does not clear `P.beliefs`, of a function
    whose entire body is `P.beliefs[id] = nil`.
    """
    short = table.split(".")[-1]
    if "." in table:
        return r"(?:" + re.escape(table) + r"|(?<![\w.])"             + re.escape(short) + r")\["
    return r"(?<![\w.])" + re.escape(short) + r"\["


def namespace_of(src, alias):
    """`local P = SAO.Perception` -> "SAO.Perception".

    The declarations name a forget the way its own module writes it -
    `P.forget`, `Pop.forgetPairs` - and `markDead` calls it the way
    every other module has to, through `SAO.`. Without this mapping
    the check degenerates: the first draft asked whether the string
    "forget" appeared in markDead's body, which is true of that body
    the moment ANY module's forget is called. Control A - remove the
    Perception call, the exact defect this border exists for - passed
    it, and that is the only reason this function exists.
    """
    m = re.search(r"^local\s+" + re.escape(alias) + r"\s*=\s*(SAO\.\w+)\s*$",
                  src, re.M)
    return m.group(1) if m else None


def main():
    faults = []
    print("=" * 74)
    print("A PER-ID CACHE THAT OUTLIVES THE ID")
    print("=" * 74)

    files = {p.name: p.read_text(encoding="utf-8", errors="ignore")
             for p in LUA.rglob("*.lua")}
    if not files:
        print()
        print("VERDICT:")
        print("  FAULT: no Lua was read, so no cache was examined - a "
              "verdict about an empty set")
        return 1

    ident = files.get(IDENTITY)
    if ident is None:
        print()
        print("VERDICT:")
        print(f"  FAULT: {IDENTITY} is gone, and with it the one funnel "
              "every death path reaches")
        return 1
    dead_body = function_body(ident, "Identity." + MARK_DEAD)
    if not dead_body:
        print()
        print("VERDICT:")
        print(f"  FAULT: {IDENTITY} has no `Identity.{MARK_DEAD}` - either "
              "it was renamed, in which case every entry below is stale, or "
              "death no longer funnels anywhere")
        return 1

    # THE CENSUS: module-scope tables actually indexed by an id.
    found = set()
    for fname, src in sorted(files.items()):
        names = {a or b for a, b in DECL.findall(src)}
        for name in names:
            short = name.split(".")[-1]
            hits = re.findall(indexed(name) + r"\s*([^\][]+?)\s*\]", src)
            if any(ID_INDEX.match(h) for h in hits):
                found.add((fname, name))

    print(f"  Lua files read      : {len(files)}")
    print(f"  per-id caches found : {len(found)}")
    print(f"  declared            : {len(CACHES)}")
    print(f"  matched but not a person: {len(NOT_A_SURVIVOR_ID)}")

    for key, why in sorted(NOT_A_SURVIVOR_ID.items()):
        if key in CACHES:
            faults.append(
                f"{key[0]}:{key[1]} is declared both as a per-id cache and "
                "as not being one. One of the two entries is false")
        elif key not in found:
            faults.append(
                f"{key[0]}:{key[1]} is declared as matching this border's "
                "shape rule without being a survivor cache, and it no "
                "longer matches - so the exemption is protecting nothing "
                f"and hiding whatever replaces it ({why[:40]}...)")

    for key in sorted(found - set(CACHES) - set(NOT_A_SURVIVOR_ID)):
        faults.append(
            f"{key[0]} has a module-scope `{key[1]}` keyed by a survivor id "
            "and nobody declared who clears it. The county keeps its dead on "
            "purpose and this table was only ever about the living, so every "
            "death leaves an entry nothing will read again. Say which "
            "function forgets one id, and make a death reach it")

    for (fname, table), (forget, how, what) in sorted(CACHES.items()):
        src = files.get(fname)
        if src is None:
            faults.append(
                f"a cache is declared in {fname} and no such file exists")
            continue
        short = table.split(".")[-1]
        if not re.search(indexed(table), src):
            faults.append(
                f"{fname} no longer has `{table}` - the entry describes a "
                "table that is gone, so this border has been checking "
                "nothing about it")
            continue

        # A forget may live in another module - the two body handles
        # are cleared by the controller's own death branches, in the
        # file that owns the teardown order rather than the file that
        # owns the table. Declared as `File.lua:function` when so.
        home, fname_fn = src, forget
        if ":" in forget:
            where, fname_fn = forget.split(":", 1)
            home = files.get(where)
            if home is None:
                faults.append(
                    f"{table}'s forget is declared to live in {where} and "
                    "no such file exists")
                continue
        fbody = function_body(home, fname_fn)
        if fbody is None:
            faults.append(
                f"{fname} has no `{forget}`, and it is what was supposed to "
                f"clear `{table}` on death")
            continue
        if how != "self" and not re.search(
                indexed(table) + r".*?\]\s*=\s*nil", fbody):
            faults.append(
                f"{fname}:{forget} is declared as what clears `{table}` and "
                "nothing in it sets an entry to nil. Either it stopped "
                "clearing or the entry names the wrong function")
            continue

        if how == "named":
            alias, _, fn = fname_fn.partition(".")
            ns = namespace_of(home, alias) if fn else None
            if ns is None:
                faults.append(
                    f"`{fname_fn}` is declared as a forget markDead calls by "
                    f"name, and `local {alias} = SAO.Something` is not in "
                    "its file - so there is no way to know what the rest of "
                    "the tree has to write to reach it")
            elif (ns + "." + fn) not in dead_body:
                faults.append(
                    f"`{ns}.{fn}` clears {table} ({what}) and "
                    f"Identity.{MARK_DEAD} does not name it. The function is "
                    "correct and nothing calls it on a death - which is the "
                    "exact shape [B51] found, where two forgets had been "
                    "written and were reached only by the test harness")
        elif how == "calls":
            if MARK_DEAD not in fbody:
                faults.append(
                    f"`{forget}` is declared as clearing {table} inline at "
                    f"the death itself, and it no longer calls {MARK_DEAD}. "
                    "So the clear and the death are now two events, and "
                    "there is nothing left tying them together")
        print(f"     {fname}:{table:<18} <- {forget} ({how})")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  72) forget on death: all {len(CACHES)} per-id caches are "
          "cleared by a function a death actually reaches")
    return 0


if __name__ == "__main__":
    sys.exit(main())
