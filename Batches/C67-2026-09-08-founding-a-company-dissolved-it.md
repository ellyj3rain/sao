# C67 - Founding a company dissolved it

| Field | Record |
| --- | --- |
| Batch | `C67` |
| Date | 2026-09-08 |
| Name | Founding a company dissolved it |
| Status | Closed append-only batch - awaiting live receipts (a save played far enough that two survivors keep company, and the panel names a leader for them) |
| Threads | [`T-004`](THREADS.md#t-004), [`T-008`](THREADS.md#t-008) |

## Record

No company has ever formed in this project. Not in a sweep, not in a
save, not once since companies were built.

A company was founded by joining one member and then the other:

```lua
SAO.Standing.joinGroup(idA, groupName)
SAO.Standing.joinGroup(idB, groupName)
```

`joinGroup` elects, and `electLeader` performs the widow release at a
roster of one - "a group of one is a memory, not a membership. The last
member is RELEASED." So the first join created a house of one and
freed its only member. The second join created a house of one again and
freed that one too. The house was empty before the second line
finished, and the county went back to strangers.

Everything downstream of a company was therefore unreachable code: the
election, the creed, the designations, the chair, the steward, feuds,
pacts, schisms, the radio news of any of them, and the perception gate
that reads a company from three tiles away. `checkSchism` batch-joins
its leavers and elects once, with a comment saying exactly why - so the
hazard was known, at one site, and the two sites where a company is
actually born never got the same treatment.

## What changed

`SAO.Standing.formCompany(ids, groupName)` writes the roster whole and
elects once, over a house that already exists. Three sites use it:

| Site | What is founded |
| --- | --- |
| `SAO_Population.lua` | the dormant road meeting |
| `SAO_Exchange.lua` | the observed conversation |
| `SAO_Absorb.lua` | a Knox house, as the county meets more of it |

Knox adoption had the same defect from a different direction: adoptees
arrive one at a time, so each was released before the next appeared and
the house could never assemble no matter how many of it were adopted.
Their `groupId` is now kept on the record - their assertion, stored as
theirs - and the house forms from everyone the county has met of it.

The widow release is not the defect and is not removed. It is a rule
about a roster that SHRANK, and it is right. `electLeader` is the verb
that settles a roster and it is called from both directions, so it
cannot tell growth from loss - and read as loss, a house being born
looks exactly like a house ending. This batch stops the rule firing in
the middle of a founding. It still fires everywhere else, and a house
of one still may not be founded.

`joinGroup` is unchanged and still in use: once there IS a house, a
single joiner is exactly right.

## What was measured

Twenty-four counties, 216 people, 1096 days owed, one OS process each,
against the real shipped map - eleven towns, 89 spawn points, 2831
buildings read out of the game's own `.lotheader` files. The only
difference between the two columns is this batch.

| | before | after |
| --- | --- | --- |
| counties forming at least one company | 0 / 24 | 24 / 24 |
| houses founded over the run, median | 0 | 17 |
| pairs above the company line, median | 264 | 266 |
| survivors at day 1096, median | 1 | 4 |
| counties with anybody alive | 16 / 24 | 21 / 24 |

The second row counts distinct house names in the store at the end
of a run, which is houses EVER FOUNDED rather than houses standing:
`markDead` forgets nine things about a dead survivor and never touches
`s.groups`, so a dead member's row stays on the roster. See below.

The third row is the one that names the defect. Two hundred and
sixty-four pairs already stood above the 0.5 company line in the broken
tree, and none of them could keep company. The trust economy was
working the entire time; nothing could be built out of it.

The fifth row was not designed and is not claimed as a target: people
who keep company live longer, which is what the pillars say should
happen and had never been observable.

Genesis originates people in bonded units at trust 0.85 for family and
0.70 for friends, both over the line, standing on the same tile. A
family of two should have kept company on the first pass after genesis
in every county ever run. That is how large the silence was.

## Why the sweep did not find it for so long

It did. Companies came back 0 of N in every configuration the harness
was ever run in - a packed county, a scattered county, an invented
building lattice, the real map, hand-built units, real genesis. Each
time the harness was corrected the number survived, and each time it
was read as the harness still being wrong. It was never the harness.

One harness gap did hide the shape of the failure: `SAO_Census.lua` was
not in the module list, so `SAO.Census` was nil, nobody in any measured
county held an occupation, and the call that deals designations died
silently inside a `pcall`. That is fixed in the harness, not in the
mod, and it is why the sweep could not see that a formed house also had
no work in it.

## What the gate refused

Border 135 measures the house, not the call. A border asserting that
the founding site calls `joinGroup` twice would have passed the defect,
because it did call it, correctly, twice. A border asserting that
`formCompany` exists would pass any future rewrite that spells the name
and dissolves the house anyway.

So it runs the real modules in the engine's VM, founds a company
however the tree in front of it founds one, and then asks whether
anybody is in it. Founding it however the tree founds it is what makes
the control work: against the `C66` tree the branch takes the two
consecutive joins and the house comes back with `born=0`, no leader, no
work dealt, and a third member unable to join.

It also holds the three properties the fix must not cost:

- a house that shrinks to one still releases its last member and clears
  their designation
- a house of one may not be founded
- a standing house still takes a joiner through the plain single verb

The gate also refused the batch twice on its own bookkeeping: the new
border was invoked by `check.sh` while untracked by git, and
`SESSION_STATE.md` still said 134 borders and 149 mirrors.

## Not in this batch

Company SIZE. The largest house in twenty-four counties was three, and
that is the temperament gate doing what `[A27]` says it does - loners
refuse, band-people cap at three - crossed with a road path that only
grows a house when one of the two is unattached. Whether the county
should reach houses of eight or fifteen is a question about the
gradient, and the gradient can be measured now that it is not zero.

The attrition. 216 people to a median of four over three years is the
county deciding, not this batch, and the ratio is already ruled good by
default and named as a candidate for a sandbox dial.

A death leaving the company. `Identity.markDead` is the funnel every
death path reaches and it forgets nine things - perception, voice,
conditions, habits, the smoker assert, the pair cooldowns, politics,
the locomotion job, the controller agent - and never touches
`s.groups`. So a dead member stays on the roster forever: the widow is
released when a housemate LEAVES and not when one DIES, `leaderOf` can
name a corpse because nothing re-elects on a death, and the store grows
for the life of the save the way `dormantLastMet` did before `[B51]`.
None of it was reachable while no company existed. All of it is
reachable now, and it is the next batch rather than a late addition to
this one.
