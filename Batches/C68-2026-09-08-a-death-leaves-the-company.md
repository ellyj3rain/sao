# C68 - A death leaves the company

| Field | Record |
| --- | --- |
| Batch | `C68` |
| Date | 2026-09-08 |
| Name | A death leaves the company |
| Status | Closed append-only batch - awaiting live receipts (a save where a member of a company dies and the panel stops naming them, and where the last survivor of a house keeps its ground) |
| Threads | [`T-004`](THREADS.md#t-004), [`T-008`](THREADS.md#t-008) |

## Record

`Identity.markDead` is the funnel every death path reaches, and its own
comments say twice why a thing belongs there rather than on a call
site: every death path funnels here, so the instrument goes here too.

It forgets nine things about a dead survivor - perception, voice,
conditions, habits, the smoker assert, the pair cooldowns, politics,
the locomotion job, the controller agent - and never touched
`s.groups`. So a dead member stayed on the roster forever.

`electLeader` and `groupSize` have always filtered the dead when they
run, so the roster has always MEANT living membership. Nothing ran them
on a death. Three things followed:

- `groupOf` was the only reader disagreeing with the two that decide,
  so a corpse answered as a member and could hold `leads` while
  `leaderOf` still named them.
- The store grew for the life of the save, the way `dormantLastMet` did
  before `[B51]`.
- The widow release fired when a housemate LEFT and never when one
  DIED. A survivor whose company died around them was left alone in a
  house the rule says may not exist, never released - so the group's
  ground never became theirs, and the controller's `aloneAgain` line,
  which fires when membership dissolves under someone, never spoke for
  a death.

One call site re-elected: `SAO_Controller`, and only when the corpse
had been the leader. A non-leader's death left the house untouched, and
the dormant half of the county - where nearly every death happens - had
no equivalent at all.

None of it was reachable before `[C67]`, because no company existed.

## What changed

`SAO.Standing.releaseDead(id)` removes the dead member's row and
settles the house: a new chair if the corpse held it, and the widow
release if one living person is left in it.

Which house they died in stays on the record as `rec.diedInGroup`,
because death is durable here and a person belonged somewhere when it
happened. That is also what the controller now reads, in place of the
`groupOf` call that only worked because nothing had cleaned up yet.

`markDead` calls it beside the other nine forgets, guarded the same
way, so every death path reaches it. The one call site that did this
for one path is gone.

## What was measured

Twenty-four counties, 216 people, 1096 days owed, one OS process each,
against the real shipped map. The `[C67]` column is the tree this batch
was cut from.

| | `[C67]` | `[C68]` |
| --- | --- | --- |
| roster rows belonging to the dead, median | 25 | 0 |
| houses founded over the run, median | 17 | 20 |
| houses standing at day 1096, median (mean) | 0 (0.5) | 0 (0.3) |
| survivors at day 1096, median | 4 | 4 |
| counties ending with a house standing | - | 6 / 24 |

The first row is the batch. The rest are here because this batch
changes what one of `[C67]`'s numbers MEANS, and a reader comparing the
two runs without that would conclude companies had stopped forming.

`[C67]` reported "counties forming at least one company: 24 of 24",
counted as house names present in the store at the end. That was a
sound proxy for houses ever founded on that tree, precisely because
nothing was ever removed from `s.groups`. Once the dead leave the
roster, a house whose whole roster died leaves no name behind, so the
same count answers "standing at the end" instead - and reads 6 of 24.

So the founding is now counted at the founding verb, which answers the
question directly on either tree: a median of 20 houses founded per
county, minimum 10, in all 24. Companies form exactly as often. What
the old number could not distinguish is that almost none of them are
still standing after three years, because the county attrits to a
handful of people and, until this batch, their houses stayed on the
books as rosters of corpses.

`standingHouses` is the honest measure of that and is unchanged either
side of this batch - median 0, mean 0.5 against 0.3. This batch removes
phantom houses, not real ones.

## What the gate refused

Border 136 measures the house after a death. A house of three loses two
members - deaths, never departures - and the border reads the roster,
the living count, whether the corpse is still in it, whether the last
member was released, whether they kept the ground, and whether they
kept a designation with no house to do it for.

Against the `[C67]` tree it returns

```
founded=3 afterOneDeath=3/2 corpseInHouse=company-sao-1
afterTwoDeaths=3/1 lastMemberGroup=company-sao-1
lastMemberClaim=lost lastMemberJob=leads
```

three rows and one living member, the survivor still inside a house the
widow rule says cannot exist, the group's ground lost rather than
inherited, and `leads` still on a corpse.

The border also kills the CHAIR of its own separate house, because this
batch deleted the one call site that handled exactly that. On the
`[C67]` tree that case returns `chairDied=sao-4:chair-test`: the dead
leader still holds the chair and the survivor is still in the house.
So a played company could be led by a corpse, and the panel would have
said so. On this tree it returns `nil:nil`.

The first draft of that case borrowed the three survivors the rest of
the border was using and decided their fate, which broke every
assertion after it - the widow's claim came back lost when the fix
keeps it. It has its own people and its own house now.

The two persistence borders were run against the new field before the
batch closed: 31 reports 71 fields written and every one read, and the
save-compatibility border reports nothing a running save could lose.

## Not in this batch

Mourning. A survivor now leaves the company when they die and the
record says which one they left, but nobody grieves them for it. What
the living owe the dead of their own house is its own question.

Company size, and the attrition, both carried forward from `[C67]`
unchanged.
