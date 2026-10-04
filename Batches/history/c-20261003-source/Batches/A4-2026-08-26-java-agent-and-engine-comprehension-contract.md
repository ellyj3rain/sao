# A4 - Java agent and engine-comprehension contract

| Field | Record |
|---|---|
| Batch | `A4` |
| Date | 2026-08-26 |
| Name | Java agent and engine-comprehension contract |
| Status | Closed append-only batch - play verification pending (no play receipt) |
| Threads | [`T-008`](THREADS.md#t-008) |
| Superseded entries | `A7`-`A8` |
| Local Git commits | `7ec167d`, `99477a3` - local Git retains the full pre-seam history as engineering evidence |
| Provenance | Joined with immediately adjacent entries: the prior assistant fragmented this single piece of work across the listed raw entries; their substance is consolidated here. That fragmentation is the reason this catalog exists, and this note is its attribution. |

## Record

Two engine truths forced their own delivery path: Build 42 refuses to render a
bare non-local IsoPlayer (its render filter demands the exact class), and
Kahlua cannot define Java classes. So the framework carries a compiled agent:
a Java IsoPlayer subclass (isLocalPlayer=false), SAOBridge exposed into the
Lua environment by a stability-polling watchdog over LuaManager's exposer, a
javac+jar build against the installed game jar, and later self-attach through
the bundled ByteBuddyAgent so no dev-launch flag is needed. Materialization
prefers the bridge with a bare-Lua fallback, and the honest-degradation shape
(no Java -> thinner but functioning Lua) became load-bearing project idiom.

ENGINE_CONTRACT.md was written in the same step: every Java file of the
reference implementation read to completion and distilled into a
lifecycle-ordered contract with source citations - spawn and teardown
sequences, movement supervision with hold-aware stall detection, outgoing
melee through the player's own pressedAttack behind a bytecode patch, the
incoming perception bridge. Comprehension first, implementation second: the
operator's direction, and the reason the later layers did not pay per-failure
archaeology.

This governed record is the portable project history for this unit. Anything it
was found to have asserted against later corrections is corrected in place above
with the correction cited; the raw entries remain reachable through
[`FORMER_LABELS.md`](FORMER_LABELS.md).
