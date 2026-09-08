# C55 - Seeing a death is not seeing who did it

| Field | Record |
|---|---|
| Batch | `C55` |
| Date | 2026-09-08 |
| Name | Seeing a death is not seeing who did it |
| Status | Closed append-only batch - awaiting live receipts (a survivor shot at distance in front of a friend who never sees the shooter: the friend mourns and declares nothing; the same killing at arm's length, where they do) |
| Threads | [`T-001`](THREADS.md#t-001), [`T-007`](THREADS.md#t-007) |

## Record

SESSION_STATE has carried this as a standing gap since [B39]: the
witness rule keys on a recent close sighting of the victim rather than
on the killing itself. Read at the code, it is narrower in one way and
much worse in another.

Narrower: `WITNESS_FRESH` is 120 frames, about two seconds. Nobody
walks anywhere in two seconds, so a fresh close sighting of the victim
is, in practice, being there when they died. That half of the gap is
almost not a gap.

Worse: **nothing ever asked whether the witness saw the KILLER.** The
engine's own attacker tag names who did it, and both sites took that
name and spent it - eight tenths of trust at the death site, six at
the wounding - on a witness whose only belief was about the victim. A
survivor standing ten tiles from somebody shot from forty tiles away,
by a person behind a wall they had never laid eyes on, dropped their
trust in that person and could declare a blood feud. That is
omniscience, which Law 1 calls a failure of the decision model.

**The two halves of the law split.** Law 1 names oblivion as a failure
too, so what the witness did see still lands: they know somebody they
were watching is dead, the death goes onto their own belief, they
mourn, and it travels down the roads from there. Being unable to name
the killer is not a reason to be ignorant of the killing. What they
could not have seen no longer lands on a name, and the log says so.

**Each half of the county is asked in the currency it has**, which is
[B47]'s rule for the live and dormant branches. A live witness holds
beliefs, so the question is whether they hold a fresh OBSERVED belief
of the killer at the place it happened - not merely somewhere, and not
told. A dormant witness holds none, because a record has no beliefs to
carry a sighting, so the question is positional: was the killer
themselves within reach of the death, near enough that somebody near
enough to see the death saw them too. Two predicates, one per
currency, `sawThemThere` and `wasThere`.

**Both sites, not one.** The death site and the wounding site had the
same defect written the same way; the third site of that shape - a
fighter earning respect - is not it, because there the belief is about
the person being judged, which is correct.

**Border 127** lifts the two predicates out of the controller by text
and runs them in the engine's VM: the melee kill where the witness saw
the killer over the body, the shot from forty tiles where they saw
only the victim, a fresh sighting of the killer somewhere else
entirely, a stale one at the right place, a told belief rather than an
observed one, a witness with no belief store at all, and the dormant
half over a killer at the death, one far off, one with no position at
all, the player, and a loaded body outranking a stale record.

Its first lift was wrong and the border said so rather than passing:
counting `do`/`then`/`end` truncated two of the three predicates,
because a one-line `if ... then return false end` opens and closes on
the same line, and the probe came back empty. Column zero is the rule
now, and if the file ever stops indenting inside its file-scope
locals, the lift returns something that will not load - which this
border reports.

**Not in this batch.** The player's own looting still does not deplete
a place, which is the other standing gap of that vintage; the
mechanism for reading it is uncertain and was not guessed at here.

This governed record is the portable project history for this unit.
