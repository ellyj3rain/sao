# C15 - Whole minds survive the reload

| Field | Record |
|---|---|
| Batch | `C15` |
| Date | 2026-08-29 |
| Name | Whole minds survive the reload |
| Status | Closed append-only batch - play verification pending (no play receipt) |
| Threads | [`T-006`](THREADS.md#t-006) |

## Record

DR-020, the operator's Crucible pick past the recommended subset:
everything a survivor believes survives save/reload - zombies,
people, factions, places, the whole mind - where before, every
reload woke the county with amnesia while its records persisted
forever.

**The bind.** At game start the perception store binds to a ModData
table (`SurvivorAwareness_Beliefs`, the house key convention), so the
engine itself saves and loads it with the world - the same zero-copy
idiom the identity store has used since [A6]. Entries written before
the bind (module load precedes ModData) are carried in, not lost. A
re-bind guard makes a second game-start event a no-op.

**Two time axes, told apart.** A frame count from a dead session is
meaningless in a live one - worse, a stale large tick stamp reads as
ultra-fresh against the new session's small ticks. On bind, every
tick-stamped field rebases to 0: a new session starts at tick 0, so 0
IS "just refreshed", every table gets exactly one decay horizon of
grace, and the [B49] frame-paced decay law resumes untouched. The
world-hours stamps (`atHours`, the out-terms) are spared by name and
carry a belief's REAL age across the reload for the readers that need
it - the search, the worry clock, the tell windows. The durable laws
underneath stand as they were: dead-flagged people never decay
(F-033), and places prune by proximity, not time.

**Bounded as before.** Growth is held by the same two hands that held
it in-session: the decay pass (zombie sightings, live-people
horizons, cry marks) and the death funnel (`P.forget` via markDead).
Persistence adds no new accumulation - it makes the existing bounded
store durable.

**The border.** Border 94 (`tools/whole_minds_test.py`): the bind,
the game-start hook, the rebase with its Hours exemption, the re-bind
guard, the carry-over, and the two durability laws. Control: the
pre-[C15] tree, which fails six ways.

This governed record is the portable project history for this unit.
