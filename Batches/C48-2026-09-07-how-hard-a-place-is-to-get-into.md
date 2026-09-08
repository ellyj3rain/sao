# C48 - How hard a place is to get into

| Field | Record |
|---|---|
| Batch | `C48` |
| Date | 2026-09-07 |
| Name | How hard a place is to get into |
| Status | Closed append-only batch - awaiting live receipts (a scout's log line carrying the ways in beside the rooms and the score; a house chosen over a shop of the same size because it has fewer doors) |
| Threads | [`T-004`](THREADS.md#t-004), [`T-003`](THREADS.md#t-003) |

## Record

DR-037 says houses matter and people take advantage of the buildings
that are there, and the outcomes the operator described - a
neighbourhood that becomes gated, choke points read once the ground is
clear, houses put to different purposes - all rest on the county being
able to tell one building from another as shelter.

It could not. The scout weighed rooms, area and water, and could not
see a door. A glass-fronted shop with eleven ways in beat a house with
three whenever it had one more room, and nothing anywhere in the
county knew the difference.

**The count is real and it is the boarding's own.** The scout counts
the doors and windows on a candidate's squares using the same
predicate [C44] uses to board one, so what the scout counts and what
somebody would later have to shut are the same set of things rather
than two ideas of a way in. It reads the loaded cell, because the
scout is standing in the neighbourhood, and loads nothing itself -
loading ground is [C46]'s and has its own border.

**It is a tie-break, and that is the whole design.** Adding a
coefficient for ways-in would price a door against a room, and nothing
in this county gives that rate; inventing one would be exactly the
authoring DR-037 forbids. What is defensible is narrower and enough:
where two places score within one room's worth of each other, the one
with fewer ways in wins. The margin is the score's own unit, now named
once so the score and the margin cannot drift apart, and nobody has
had to decide what a door is worth.

**Counted only when it could matter.** Reading a building's perimeter
is real work, so it happens only for a candidate close enough to the
best to win a tie. An unreadable count is refused rather than guessed
and never wins.

**Border 121 holds the shape rather than the number.** It reads the
score expression and fails if ways-in appears anywhere inside it,
because the moment somebody multiplies the count by something, an
invented rate has entered the county through the back door. It also
holds that the margin is the score's own named unit, that the
predicate is shared with the boarding, that nothing here loads ground,
and that the Lua reads the field the Java sends - one more colon in a
protocol string being exactly the kind of drift that fails in silence.

**Not in this batch.** Anything about what a place is FOR - a house
put to a different purpose than the one beside it. Choke points, which
are about a neighbourhood's shape rather than a building's perimeter.
Whether a house's people ever act on the count: they can board a
window ([C44]) and they can be told what their place is like ([C46]),
and whether those meet is theirs.

This governed record is the portable project history for this unit.
