# C40 - The county stands on its own

| Field | Record |
|---|---|
| Batch | `C40` |
| Date | 2026-09-07 |
| Name | The county stands on its own |
| Status | Closed append-only batch - awaiting live receipts (both mods installed and the switch off: their people keep their own menu, this county keeps its own, and the log says nothing is absorbed; the switch on and [C7]'s superimposition as before) |
| Threads | [`T-030`](THREADS.md#t-030), [`T-007`](THREADS.md#t-007) |

## Record

DR-035: the operator's assessment of 2026-09-07 is that the
neighbour framework is not needed, is close to redundant against the
art and systems this county now has, and has a restrictive author -
so development should be self-contained rather than factoring that
dependency in. This is [C39]'s law one step further: there the cost
was a requirement on the user, here it is a dependency in the
design.

**Two things [C39] left standing, corrected first.** Both manifests
still told the player the mod requires Infirmities and Even More
Traits, and CREDITS still said `require=` names those two. Neither
was true the moment [C39] shipped, and no border reads the
description. They say what is true now: ZombieBuddy loads the Java
component and nothing else is required.

**One switch, off.** `NeighbourBridge` gates the only two paths that
ran another mod's code. Off - the default, and what a fresh world
gets - `SAO_Absorb` never reads their namespace, never wraps their
spawn or teardown, and absorbs nobody; `SAO_Neighbours` never
predicts or rewrites their per-survivor menu, so every person the
player right-clicks gets this county's own menu and nobody's surface
is touched. On, DR-015 and DR-022 hold exactly as written - they are
not repealed, they are no longer assumed.

**The prompt hold waits to be asked too.** Holding a prompt means
replacing two of their functions with wrappers of ours, which is a
reach into their code whatever it is for, and it defaulted on. It
defaults off now, so a fresh world with both mods installed touches
nothing of theirs at all. The switch and its ratified words are
unchanged and still true - the player can turn it on, and the last
line already points at those mods' own options for the same job.

**What stays always on, and why it is different.** The county still
never treats their people as threats, never targets them, and keeps
their keys in their own domain (DR-009's defensive half, `SAOKnox`
in Java). That reads two animation variables and four modData keys
and calls none of their functions: it protects a neighbour's game
rather than using their work, costs nothing when they are absent,
and would be wrong to drop.

**Border 114** holds the law itself rather than this instance:
every reach into a foreign namespace in the tree is either the
defensive predicate or behind the bridge; the bridge defaults off in
the options file; both entry points ask before they read; no
manifest requires anything but the loader; and the description does
not claim a requirement the manifest does not carry - the exact
defect this batch opened by finding. Its control is the pre-batch
tree.

**Not in this batch.** ZombieBuddy, which is a loader and not a
borrowed system - a mod cannot attach a Java agent to the running
game by itself, so the requirement is real; removing the bridge
code altogether rather than closing it, which would throw away
working ratified work for a player who wants the two joined.

This governed record is the portable project history for this unit.
