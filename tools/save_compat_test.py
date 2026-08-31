#!/usr/bin/env python3
r"""[B36] A live save must survive every deploy.

The operator keeps two worlds as test ground - one fresh in Irvington,
one with companions already - and deploys land under them constantly.
A save does not break loudly. A field that a running world stores and
a new build stops reading is simply ignored; a field a new build
expects and an old world never wrote reads as nil, and the branch that
needed it quietly stops happening. Neither errors. Both are permanent
for that world.

[B34] checked this once, by hand, against one commit. Once is not a
guarantee - it is a thing somebody remembered to do.

This compares the persisted surface against a BASELINE COMMIT and
fails when a field a save may already hold stops being read. Adding is
safe and needs no permission; REMOVING is what strands a world.

The persisted surface is the two ModData tables:

    SurvivorAwareness_Standing   claims, groups, groupMeta, relations,
                                 promises, radioNews, onAir, ...
    SurvivorAwareness_*          identity records and their fields

Reads and writes are both counted, because a field written and never
read again is dead weight in a save, while a field read and never
written is a branch waiting for something that will never arrive.
"""
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA_REL = "mod/42.20/media/lua"
BASELINE_FILE = ROOT / "tools" / "save_baseline.txt"

# [B42] Drops that have been read and are not losses, each with the
# reason. A name here must actually be dropped or this file fails on
# the declaration itself, so the list cannot quietly outlive its case.
ACCEPTED_DROPS = {
    "jobEvents":
        "a key in ANOTHER framework's ModData table, never a field of "
        "ours. It entered this census only because our code referenced "
        "it while rendering their world-event string on the County "
        "Ledger; removing that read removed the mention. Their store "
        "still holds it and their mod still owns it.",
}

# Names that hold persisted state, from store() and getOrCreate sites.
HOLDERS = r"(?:s|s\d+|sM|sT|sP|sX|s70|sP\d*|meta|meta\d+|metaC|rec|c|r)"
FIELD = re.compile(HOLDERS + r"\.(\w+)\s*(=(?!=)|\W)")


# [B36] Session-only stores, excluded because losing a field there
# strands nobody. SAO_Seams holds which subsystems went dark this
# session ([B33]) and is a plain Lua table by design.
SESSION_ONLY = {"SAO_Seams.lua"}


def strip_comments(src):
    """[B41] Prose is not a persisted field.

    This read raw source, comments included, so a field NAMED in a
    comment counted as part of the persisted surface. That is harmless
    in the ADDED direction and quietly fatal in the DROPPED one -
    because the normal way to remove a field is to remove it and leave
    a comment saying why, and the comment then keeps the name alive in
    the very check that exists to notice the removal.

    Found by removing two dead fields and being told 0 dropped, when
    the only reason was that the notes explaining their removal
    mentioned them by name.
    """
    out, i, n = [], 0, len(src)
    while i < n:
        if src.startswith("--[[", i):
            end = src.find("]]", i)
            i = n if end < 0 else end + 2
            continue
        if src.startswith("--", i):
            end = src.find("\n", i)
            i = n if end < 0 else end
            continue
        out.append(src[i])
        i += 1
    return "".join(out)


def surface_at(rev=None):
    """Every field name touched on a persisted holder.

    The holder pattern is deliberately GENEROUS: it cannot prove a
    table came from ModData, so it takes anything shaped like one. In
    the ADDED direction that costs nothing, since adding is safe. In
    the DROPPED direction it can raise a false alarm about a field
    that was never persisted - which costs a moment's reading, against
    a missed real one that costs a live world. That is the right way
    round to be wrong, and it is why this errs wide rather than
    narrow.
    """
    out = set()
    lua = ROOT / LUA_REL
    for p in sorted(lua.rglob("*.lua")):
        if p.name in SESSION_ONLY:
            continue
        rel = p.relative_to(ROOT).as_posix()
        if rev is None:
            src = p.read_text(encoding="utf-8", errors="ignore")
        else:
            r = subprocess.run(["git", "show", f"{rev}:{rel}"],
                               cwd=ROOT, capture_output=True,
                               text=True, errors="ignore")
            if r.returncode != 0:
                continue
            src = r.stdout
        out |= {m.group(1) for m in FIELD.finditer(strip_comments(src))}
    return out


def main():
    if not BASELINE_FILE.exists():
        print("save compat: no baseline recorded yet")
        return 0
    baseline_rev = BASELINE_FILE.read_text(encoding="utf-8").split()[0]

    old = surface_at(baseline_rev)
    new = surface_at(None)
    if not old:
        print(f"save compat: SKIPPED - baseline {baseline_rev} is not "
              "in this checkout")
        return 0

    dropped = sorted(old - new)
    added = sorted(new - old)

    print("=" * 70)
    print(f"Persisted surface against {baseline_rev}")
    print("=" * 70)
    print(f"  fields then: {len(old)}    now: {len(new)}")
    print(f"  ADDED  {len(added)}  (safe - an old world simply has "
          "no value there)")
    if added:
        print(f"    {', '.join(added[:14])}"
              + (" ..." if len(added) > 14 else ""))
    # [B42] A drop that has been read and understood can be declared
    # here, with the reason, so the acceptance lives in the repository
    # instead of in whoever happened to read the output that day. This
    # is the case the docstring above already anticipated: the holder
    # pattern errs wide and can name a field that was never ours.
    #
    # It cannot become a rubber stamp. An entry that is NOT in the
    # dropped set is itself a fault - either the field came back, or it
    # was never dropped and the note is describing a world that does
    # not exist. That is [B41]'s rule about an allowlist whose removal
    # changes nothing, applied to this one.
    accepted = sorted(n for n in dropped if n in ACCEPTED_DROPS)
    real = [n for n in dropped if n not in ACCEPTED_DROPS]
    stale = sorted(n for n in ACCEPTED_DROPS if n not in dropped)

    print(f"  DROPPED {len(dropped)}  ({len(accepted)} declared)")
    for d in real:
        print(f"    {d}   <- a live world may hold this and nothing "
              "reads it now")
    for d in accepted:
        print(f"    {d}   <- declared: {ACCEPTED_DROPS[d]}")

    print()
    print("VERDICT:")
    print(f"  fields a running save could lose: {len(real)}")
    if real:
        print("  If this is deliberate, record the migration in the")
        print("  batch and re-baseline. Silence here is how two test")
        print("  worlds diverge from the code that made them.")
    for d in stale:
        print(f"  FAULT: `{d}` is declared an accepted drop and is not "
              "dropped - the declaration describes a tree this is not")
    return 1 if (real or stale) else 0


if __name__ == "__main__":
    sys.exit(main())
