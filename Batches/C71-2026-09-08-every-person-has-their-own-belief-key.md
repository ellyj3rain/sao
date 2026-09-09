# C71 - Every person has their own belief key

| Field | Record |
| --- | --- |
| Batch | `C71` |
| Date | 2026-09-08 |
| Name | Every person has their own belief key |
| Status | Closed append-only batch - awaiting its first live receipt |
| Threads | [`T-006`](THREADS.md#t-006), [`T-008`](THREADS.md#t-008) |

## Record

A survivor's beliefs about people are held in
`Perception.beliefs[id].people`, keyed by `Identity.displayName` - the
person's name, or the string `"Unnamed"` when the record has not got
one. `backfillName` reads a name off the engine shell the first time a
body is built for somebody, so a survivor the county has never
materialised has the sentinel by design.

A dormant county materialises nobody. Measured in the engine's own VM
against the shipped map: **271 people, 271 of them `"Unnamed"`, one
distinct display name for the entire county.**

So every belief about every one of them landed on one string. The
county's whole memory of its dead was a single slot per head, and each
death overwrote the last.

Two things compounded it, and a third sat beside it.

**The news read a store instead of opening one.** The dormant
attrition pass reached `P.beliefs[hearer]` directly and skipped when it
was absent. A belief store is created by being told something or by
scanning with a body; a dormant survivor has done neither, so the news
of a death reached nobody who had never been told anything by anybody.
Measured over eight counties of 1096 days: the median county had **one
person in it holding any belief about any person at all.**

**The dial that stops the county collecting also silenced its news.**
`dormantAttrition` returns before anything when `DormantRisk` is zero,
and the delivery of news about deaths that had already happened sat
inside that return. A player turning the risk down left every pending
notice undelivered for the life of the save.

**A corpse has no fellows.** The hearers were the bonded partner and
`fellowsOf(id)`, which reads the roster - and `[C68]` takes a corpse
off the roster at the moment of death, correctly. The news is due a
day or two later, by which time the dead person's roster row is gone,
so the company half of "word finds the bonded and the company" has
reached nobody since `[C68]`. `releaseDead` already writes
`rec.diedInGroup` for exactly this reason and nothing here read it.

**And a meeting wrote nothing down.** A dormant meeting is a firsthand
sighting: two people three tiles apart, trading lessons, arguing
doctrine, passing grudges and credits, founding houses. Neither party
recorded having seen the other, or where. Over eight counties, **not
one survivor believed a living person was anywhere.**

## What changed

`Identity.beliefKey(rec)` is the one way a record renders as a belief
key: the name where there is one, the id where there is not.
`idByName` indexes the id too, so a key still resolves to whoever it
names. `knownName` is untouched and still refuses the sentinel, so an
id can never reach a player-facing surface (DR-017) - `displayName`
stays what a person is called and `beliefKey` is who they are.

Every site that keys a person-belief reads it: the death news, the
witness and fighter predicates in `SAO_Controller`, three colour and
condition reads in `SAO_Exchange`, `cryForHelp` and
`announceDeparture`. Three of those carried a `== "Unnamed"` guard,
which was this rule half-written - a person the county had not named
could not be witnessed dying, when what was missing was a key for
them. The radio keeps two answers to two questions: whether a death
goes on the air is whether there is a name to say, and that is
unchanged, while what the listener then believes is keyed by the
person.

`Perception.migratePersonKey` carries beliefs across a rename, called
from `backfillName`. A person's key changes the first time a player
walks near them, and without this everybody who knew them would lose
them at that moment. Beliefs keyed `"Unnamed"` are refused rather than
moved: they were written before this batch and belong to no particular
person, so handing them to whoever materialises first would invent a
memory rather than carry one.

`Perception.learnOfDeath` opens the hearer's store and writes the
notice. It is `dormantAttrition`'s own copy of what `P.tell` already
did, lifted into Perception where the rule lives.

`deliverDeathNews` runs before the risk gate, so the dial governs the
risk and not the news. Its hearers are the bonded partner and
`Standing.membersOf(rec.diedInGroup)` - the house asked by its name
rather than through a member who is dead. `fellowsOf` is now expressed
in terms of `membersOf` so there is one rule about who is in a house
and one place that filters the dead out of it.

`Perception.sawPerson` writes the sighting a meeting leaves, at
observed provenance, at the other person's position, both ways -
before the hostile branch, because keeping a wide berth from somebody
is still having seen them. It carries the other person's id on the
belief where the caller knows it; the scanner never does, because it
reads a name off a shell.

## Border 137, and its control

`tools/person_belief_test.py`, in the gate. It runs the shipped
dormant modules in the engine's own Kahlua VM through the tick handler
the mod registers, and then **reads the belief store**. A border
asserting that the meeting calls `sawPerson`, or that `beliefKey`
exists, would pass a tree that spelled both and still put the whole
county in one slot.

| Property | What it reads |
| --- | --- |
| two unnamed people are two keys | `beliefKey` of each, compared |
| a meeting is written down both ways | both stores, source and position |
| news reaches a head with nothing in it | a housemate who has met nobody |
| two deaths are two beliefs | the count of dead beliefs in one head |
| a house hears its own losses | the hearer is reached through the house |
| a name arriving carries the beliefs | under the new key, not the old |
| no id reaches a player | `knownName` still answers nil |

Its control is the pre-batch tree, where every property fails and
`keyA=Unnamed keyB=Unnamed` is the defect itself, printed.

Genesis does not run inside the border and there is no map:
`SpawnRegionMgr` and the meta grid are absent on purpose, declared
rather than filtered out quietly, because what is being measured is
what a meeting and a death write down. A county built from spawn
points would decide when those happen instead of the border.

## What this does not do

The county still has no names. A person gets one from the first shell
built for them, which is backwards - a name is a fact about a person,
not about their body - and fixing it means SAO deciding a survivor's
sex at genesis so the name matches the shell the engine builds later.
That is a design call and it is the operator's. `beliefKey` makes the
absence survivable rather than curing it.

`b.people` is still keyed by a rendering wherever the scanner is the
writer, because a scan reads a name off a shell and has nothing else.
Two people with the same full name collapse to one key there, resolved
lexically-least by `idByName`, as they always have. The dormant half no
longer has that problem, because its writer knows exactly who it saw.

Nothing here decides anything. A survivor can now remember meeting
somebody; whether they ever act on it is `[C72]`.

## Cost stated

The death news opens a belief store for every hearer that lacked one -
about a hundred more stores per county, each a table of four empty maps
and one notice, persisted with the world through `[C15]`'s bind.
Bounded by the living population, and the sightings a meeting writes
are bounded by how many people somebody has actually met, which over
1096 days has a median of 8.
