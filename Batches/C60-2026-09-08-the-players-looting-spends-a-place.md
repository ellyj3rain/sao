# C60 - The player's looting spends a place

| Field | Record |
|---|---|
| Batch | `C60` |
| Date | 2026-09-08 |
| Name | The player's looting spends a place |
| Status | Closed append-only batch - awaiting live receipts (a shop the player strips, and the county's foragers stopping walking to it; the panel reading it as spent) |
| Threads | [`T-003`](THREADS.md#t-003) |

## Record

`SESSION_STATE` has carried this since [B39]: the player's own looting
does not deplete a place. A survivor taking something calls
`SAO_Places.take` and the place is spent for everybody. The player's
looting called nothing, so a shop the player had stripped still read as
full stock, `isSpent` stayed false, and the county kept sending
foragers to it.

**Read, not hooked.** Nothing here counts the player's actions. The
engine marks a container looted when it has been emptied -
`ItemContainer.isHasBeenLooted`, javap-verified on the installed jar,
a flag SAO never writes - so the honest reading is the ground itself:
how many containers around the place the game says are done with. A
read cannot miss a way of taking things that nobody thought to hook,
and it costs nothing when the player is standing somewhere that is not
a place at all.

`SAONeeds.lootedNearby` walks the squares the way
`countStoredWaterNearby` already does and answers `looted@total`, so
the caller can tell an empty room from a stripped one. The bridge
exposes it; `Age.playerLoots` calls it on the player's own ten-minute
pass, which is where everything else about them already happens.

**The tally is raised, never lowered.** `Pl.observeLooted` takes the
count to the place's ledger and only ever increases it. A place the
county already spent does not refill because the player walked in, the
count is held at the place's capacity, and the refill stamp moves only
when the count actually raises the tally - so standing in an untouched
room does not reset its clock. Zero, a negative, a missing place and a
missing count all do nothing.

**Border 129** runs the real `SAO_Places` in the engine's VM: a
four-room place spent from three takes to its capacity of twelve with
`isSpent` turning over; a lower reading changing nothing; the county's
own three takes surviving a lower reading with its stamp untouched;
and every degenerate input answering zero. By text: the engine method
reads the engine's flag and writes none, the bridge exposes it, and the
player's pass goes through the place ledger rather than around it.

**Not in this batch.** The county's belief about a place is separate
from the place's stock and is untouched here: a survivor who believed a
shop was stocked still believes it until they go and look, which is
Perception's business and correct.

This governed record is the portable project history for this unit.
