# C54 - The objection picks the car

| Field | Record |
|---|---|
| Batch | `C54` |
| Date | 2026-09-08 |
| Name | The objection picks the car |
| Status | Closed append-only batch - awaiting live receipts (a house with a loud van and a quiet hatchback sending a noise-wary forager out in the hatchback; the same person walking when the yard holds only the van; the log saying which) |
| Threads | [`T-003`](THREADS.md#t-003), [`T-002`](THREADS.md#t-002) |

## Record

Day Zero slice 5, vehicles as composition. The pieces the slice names
were mostly there: the quartermaster appraises the yard, a runnable
car doubles a venture's range, the party is capped by the car's real
free seats, and the trip burns the real tank by the real distance.
What was missing was one link, and it was a defect rather than an
absence.

**F-057.** `SAO_Standing.roadworthy` read the whole motor pool and
returned one car - the roomiest openable runner. The venture then
applied the goer's own objection to that one car: somebody who has
learned that noise is a debt refuses a loud one and walks, which is
[B19]'s decision and is right. With one car returned, the refusal
discarded the yard. A house holding a loud six-seater and a quiet
hatchback sent that person out on foot, past a car they would have
taken. Nothing looked wrong in the log, which said the loud car was
left where it sat - true, and complete about the wrong question.

**The criterion goes in with the ask.** `roadworthy` takes a loudness
ceiling now and skips any car at or above it, so what comes back is
the roomiest car this person would actually take. Passing nothing
gives the answer it always gave, which is what the county panel does,
so the reading of what a house can drive has not moved. Where the
yard holds only loud runners the answer is nothing and the walk
happens exactly as before, and it is said as a choice about the yard
rather than about one car.

The second loudness test at the call site is deleted rather than left
sitting: the appraisal cannot return a car this person refuses, so a
test after it could only ever be dead code that reads like a live
guard.

**The shape is general and is named in F-057.** A chooser that
returns its own best candidate, to a caller holding a veto over the
result, turns that veto into a refusal of the whole set. Either the
criterion goes in with the ask or the set comes back. The other two
gates on the same car were checked against that shape and are not it:
`canHotwire` bites only when there is no open runner at all, because
the appraisal prefers openness first; and the seat cap reads the
chosen car rather than choosing, with roomiest-first meaning the
largest acceptable car is already the one offered.

**Border 126** runs the real `roadworthy` in the engine's VM over four
pools built for the cases that decide it: a loud roomy runner beside a
quiet small one, which is the defect stated as a pair; a yard of only
loud runners, where the walk must survive; a locked six beside an open
two, where openability must still outrank room under a ceiling; and
two wrecks beside a runner, where a car that does not run must never
come back. Its control is the pre-batch tree, which hands the loud car
to the person who refuses it.

**Not in this batch.** Party size does not choose the car, and does
not need to: roomiest-first already offers the largest car the goer
will take, so there is nothing better for a headcount to pick. A
second car for the overflow is a different capability and is not
scoped.

This governed record is the portable project history for this unit.
