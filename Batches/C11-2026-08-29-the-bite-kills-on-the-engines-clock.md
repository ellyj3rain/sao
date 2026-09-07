# C11 - The bite kills on the engine's clock

| Field | Record |
|---|---|
| Batch | `C11` |
| Date | 2026-08-29 |
| Name | The bite kills on the engine's clock |
| Status | Closed append-only batch - play verification pending (no play receipt) |
| Threads | [`T-002`](THREADS.md#t-002), [`T-008`](THREADS.md#t-008) |

## Record

The operator's item 4: the dormant bite-risk formula
(`0.10 + min(0.5, since/480)`) carried a comment calling it "the
engine's own turning odds" with no citation. The verification pass the
order demanded (F-047) found something better than a correction: the
engine has no turning ODDS at all. A bite infects with CERTAINTY on
this build - `BodyPart.SetBitten` sets the Knox infection under any
saliva transmission, and no probability roll exists anywhere in the
path - and the infected die EXACTLY at `infectionTime +
pickMortalityDuration` (48-72 hours on the Apocalypse default,
trait-scaled), where `BodyDamage.Update` drives the course to
`ReduceGeneralHealth(110)`. So the formula was not relabeled as
tuning; it was replaced by the law it falsely claimed.

**Read, not mirrored - and mirrored only where the engine had not
spoken.** As a body goes dark, `biteHoursLeft` reads the engine's own
clock off that body (`isInfected`, `infectionTime`,
`infectionMortalityDuration`, on the character's own hours-survived
axis) and the record carries the death hour. When a body goes dark
infected before the course stamped its clock, `biteWindowHours`
mirrors the sandbox table with the bytecode citation - the [A26]
dormant-mirror idiom. Past the hour, dormant death is DUE, bypassing
the ambient roll entirely; scratch-borne infection is carried the
same way, because the clock reads infection, not the bite wound.

**Who rises mirrors the engine.** The dormant turning predicate is
`shouldBecomeZombieAfterDeath`'s (F-044): the infected turn, and
under Everyone's Infected every dormant death turns - which the old
code never did. The wound-infection multiplier (x1.6, the septic
kind, unrelated to Knox) survives labeled as OUR tuning in so many
words.

**Named approximations, stated rather than discovered.** The
hibernation pack restores a bite as `SetBitten(true)`, which
re-infects with certainty but restarts the course clock - a woken
bitten survivor's window begins again. The mirror window omits the
Resilient/Prone-to-Illness scaling, because dormant records do not
reliably carry those traits. Both are conservative (people live
slightly longer, never shorter than the engine would allow).

**The border.** Border 90 (`tools/bite_clock_test.py`): the formula
and its false claim are gone, the bridge reads the engine's clock and
the record carries it, the mirror is cited and carries the engine's
own bands, due deaths are not rolled, the turning predicate mirrors
Everyone's Infected, and the surviving constant owns itself. Control:
the pre-[C11] tree, which fails all eight ways.

This governed record is the portable project history for this unit.
