# C46 - The ground is read during the years

| Field | Record |
|---|---|
| Batch | `C46` |
| Date | 2026-09-07 |
| Name | The ground is read during the years |
| Status | Closed append-only batch - awaiting live receipts (a 1996 start whose survivors' panels say what their places are - the ways in and how many are shut - read off ground nobody was standing on; a 1993 start unchanged) |
| Threads | [`T-007`](THREADS.md#t-007), [`T-003`](THREADS.md#t-003) |

## Record

The operator ruled the years between run for real - the ground is
loaded and the work happens - rather than the pass recording an
outcome and dressing the world to match on arrival. This is the
loading half, and it is deliberately only that half.

**Why it has to be done this way.** The engine holds a sliding window
of eight by eight chunks around each player and it follows them
(`IsoChunkMap.CHUNKS_PER_WIDTH`, verified). There is no window to put
a distant claim in, so the cell answers nothing for ground nobody is
near, and during the years nobody is near anything. A chunk can
however be loaded on its own - constructed against the cell, pointed
at its world coordinates and read off disk - which is what the
engine's own streamer does and what this does.

**What it costs.** F-055 measured the ground a whole county's
households stand on at 432 chunks and 406 KB, against a shipped map of
3.7 GB. It is nothing, and it is the same ground every time. One claim
is looked at per simulated day on a rotation, and ground read inside
the last thirty simulated days is not read again.

**What the county learns.** The ways into the place a person holds,
and how many of them are already shut. That lands on their record and
the panel says it. It is a fact about ground that was actually read,
not a number the pass decided.

**WHAT IT DOES NOT DO, AND WHY THAT IS THE POINT.** It writes nothing.
No barricade is added, no object placed, no chunk saved.
`IsoChunk.Save` writes into the player's own save directory through
shared static buffers (`ChunkMapFilenames.getDir` on
`Core.gameSaveWorld`, the static `sliceBuffer` under `WriteLock`, read
off the bytecode), and no part of this mod has a live receipt yet.
Reading tells the county what its places are like; changing them is
the next piece and is not smuggled in with this one.

**The guards.** A chunk the live world already holds is never loaded
again - it is read where it sits, through the cell, which is free and
safe, and counted separately. A cap of eight chunks per survey, when a
claim spans four at worst. Every engine call inside a catch, because
this runs at world creation while the streamer is busy and a survey
that throws must cost the county nothing.

**Border 119** exists for the one thing that matters: nothing in the
survey path may save a chunk, add a barricade or place an object. It
names those shapes and fails on any of them, because a later batch
reaching for them from inside this path would be doing it to a real
person's save.

**Border 118 caught this batch, correctly.** Its rule is that every
call inside a simulated day must be one the live county already makes,
and looking at ground is new - the live county never needs it, because
a person with a body can see where they are standing. The survey is
admitted as the one exception, on the evidence of Border 119 rather
than on assertion, and the two borders are written to be read
together.

**Not in this batch.** Doing anything to the ground during the years:
adding the plank, spending the materials out of a dormant person's
packed inventory, saving the chunk. That needs a live receipt for the
loading first, and it is where the risk actually lives.

This governed record is the portable project history for this unit.
