# C117 - The afflicted among the living

| Field | Record |
| --- | --- |
| Batch | `C117` |
| Date | 2026-09-13 |
| Name | The afflicted among the living |
| Status | Closed append-only batch - the afflicted ruling's social half, built |
| Threads | [`T-004`](THREADS.md#t-004), [`T-006`](THREADS.md#t-006), [`T-002`](THREADS.md#t-002), [`T-008`](THREADS.md#t-008) |

## Record

`[C116]` named what was deliberately not there, so it would not be
mistaken for lost: the house argument over an afflicted member, the
cast-out and the gather, and the survivor-side standing reaction in
work, claims and recruitment - "standing's questions, and standing's
own batch." This is that batch. Three laws, all in the machinery that
already exists; no new verb decides anything, and nobody is exiled,
refused or moved by badge.

**The house argument.** In `electLeader`, beside the creed quarrel
`[B23]` built, a second fault line now runs: a member the house can
SEE is shaped - `[C116]`'s scanner stamps the form on the
person-belief, so the house's question is what its members believe,
never what is true - is a question each housemate answers out of
their own character, the law `[B3]` set for the bitten: the fearful
pull away, the composed stand by. Only members holding a FRESH belief
of the form take a stance at all (`P.believedFormOf`, new, the belief
reader for every standing-side question - fresh on the people
horizon, so the argument quiets by itself when the marks stop being
seen); a member who has not seen them does not argue, and there is no
argument without fear in the room. The stances are character-shaped -
nerve against compassion, with the county's own fear ([C31]/[C32]) on
the scale - and the bending runs on the sibling quarrel's cadence at
its magnitudes: the afraid lose trust in the subject (−0.03), the
subject hears the room turn and bends back (−0.02), and the two faces
sour at each other (−0.02). The subject is a person too, and argues
about themselves: they are the county's own mid-course people
([MUTATION.md]), not a case to be decided. The blows are `[B23]`'s
own clause - each side crosses their OWN `hostilityBar`, the short
fuse `[A27]` - and everything after the blows is the split machinery's
business, exactly as `[B3]` recorded it: no exile verb exists by
design, `checkSchism` at the meeting seams decides, and its schism of
one IS the exile ([A21]) - the cast-out is whoever the roster trusts
less. A beloved member's afraid face can be the one who walks out
alone; the machinery has no preferred victim.

**The company door.** `companyStanding` ([C111]) is the value every
company door reads - the road, the table, the visit gate, the
companion walk, the player's own asks - and this is where the
recruitment reaction lives, one law so no two doors can disagree
about the same person on the same day. When the judge believes the
other carries a form, their own fear reads the value down: weight is
`(1 − nerve) + fear − compassion`, scaled 0.6, so a composed judge
(weight ≤ 0) discounts nothing and can still take the shaped stranger
in, while the most frightened judge cannot be carried past the line
even by the deepest need. Need does not overrule who somebody is
([C111]) and neither does this; temperament's own gates
(`circleRefuses`, the mercy softening) stand untouched in front of
it. The afflicted judge at another afflicted's door reads the same
law - outcasts can take each other in, and a house of outcasts is a
county's own answer, not a category.

**The cast-out and the gather.** Once a county day, on the same clock
the return and the marks run (`dailyCounty`, so the years pass drives
it exactly as the live county does, `[C65]`), `S.outcastDrift` asks
standing's question for every groupless person whose own state says
afflicted: their own known places, ranked by the `[C76]`/`[C108]`
scorer (`Perception.returnsOf` - visits, distinct reachers, water
doubled, recency breaking ties), minus every place a living hand
holds (`claimedByOther`: no company's seat, no other person's home)
and minus what they already hold (`insideClaim` - that is where they
live). The best remaining place is taken as their home - the old
claim released, the new ground claimed through the same ruler genesis
uses, the anchor moved - and the log says why, the settle pass's own
law. Nothing is scored the county did not already measure by walking;
a cast-out who never went back anywhere has no candidate and keeps
the ground they stand on (measure, then guide - DR-021; the buildings
already there are the answer - DR-037). The home they leave was
theirs to keep ([A21]'s exile clause), and leaving it is their own
answer to the doors closing - the drift reads only their own facts.
The GATHER needs nothing new: outcasts who drift to the same
abandoned ground cross paths on the roads, and the doors above
decide - the same `companyStanding`, the same mutual bar, the same
temperament. What gathers, gathers.

**Work and claims, answered by the machinery that already owns them.**
The work reaction is the split's own: `leaveGroup` and `checkSchism`'s
exile clause both clear the designation, so the cast-out carries no
house work out the door ([B2]'s dealing follows the roster that
remains), and the work that stays is judged by the state of the work,
never by attribution ([B21] - the house does not audit who applied
which dressing). The claims reaction is the drift's own: the cast-out
takes ground through the same claim verb every home takes, and the
county's respect for it is unchanged - `mayEnter` still refuses a
break-in without hostility, whoever holds the ground ([A24], [B35]).
A member still housed keeps their work and their claim by the same
laws as anyone; the quarrel bends trust, and trust is what the
elections, the table order and the dealing already read.

## What changed

- `mod/42.20/media/lua/shared/SAO_Perception.lua` - NEW
  `P.believedFormOf(id, otherKey, tick)`: the fresh-form belief reader
  keyed the way beliefs are keyed, the one query every standing-side
  question about the afflicted asks.
- `mod/42.20/media/lua/shared/SAO_Standing.lua` - three laws: the
  affliction fault line in `electLeader` beside `[B23]`'s (stances
  from fresh beliefs + character, the bending, the per-person blows);
  the judge's own fear read into `companyStanding` (the one value
  every company door reads); NEW `S.outcastDrift` (the cast-out's
  measure-then-guide home-taking, beside `placesOf`/`onGroundOf`
  where the place machinery lives).
- `mod/42.20/media/lua/client/SAO_Population.lua` - `dailyCounty`
  calls `outcastDrift` after the return and the marks, one call site
  so both halves drive it ([C65]'s law).
- `mod/42.20/media/lua/client/SAO_AfflictedReturn.lua` - the header's
  deferral line now names this batch as the one that answered it.
- `tools/version_replay.py` - the `C117` unit row; `--write` stamps
  the coordinate.
- `BATCH_LOG.md`, `THREADS.md` (T-002, T-004, T-006),
  `SESSION_STATE.md`, `ROADMAP.md` - the pointers.

## Honest limits

- The 0.6 fear scale is the one authored number in the door law, and
  its direction is the ruling's (fear closes doors). At the extremes
  it cannot be overruled by need (max weight 1.2 against a max pull
  of ~1.0) and it vanishes for the composed; the slope between them
  is this batch's, stated so the operator can move it.
- The quarrel bends at `[B23]`'s magnitudes on `[B23]`'s cadence,
  and the blows need trust already thin: from a standing start the
  exile is weeks of county time away, which is the honest pace of a
  house talking itself out of a member. `driftStandings` and the
  roads keep pulling the other way, as they should.
- The drift is dormant-shaped: it moves the record's home anchor and
  the claim, and a materialised body re-reads its anchor through the
  machinery it already has (roam, reload, the visit gates). Nobody is
  teleported; the abstraction steps the dormant half the way it
  always has.
- The afflicted judge at an afflicted door discounts by their own
  fear the same as anyone; no solidarity is encoded. If outcasts
  gather, it is because the composed found each other - the emergence
  rule, held.
- No play receipt, as ever: nobody has watched a house argue over a
  returned member, a door refuse one, or an outcast take abandoned
  ground. All of it is verified by the gate's structural pass and
  waits on the same play receipts the return itself waits on.

## Verification

- Every surface used was swept before a line was written, per the
  prior-art law: the `[B23]` quarrel (stances, magnitudes, the
  per-person blows clause), `[B3]`'s bitten law and its "no exile
  verb exists by design" ruling, `checkSchism`'s schism-of-one exile
  clause, `[C111]`'s door list, `[C76]`/`[C108]`'s scorer and the
  settle pass's barred-ground law, DR-037/DR-021, and the belief
  surfaces (`beliefKey`, `believedPerson`, the people horizon).
- All shipped Lua files compile under the engine's own Kahlua
  compiler (Border 50); the four touched files pass the structural
  check; every Lua call site names a real surface (the bridge and
  call-target borders). The gate is clean at the new tip; the version
  machine derives 4.7.0.0-pre-alpha (minor - a new player-visible
  simulation capability: the county's society answers its mid-course
  people). Deploy follows this record, then the branch, the pull
  request, and the squash - the publishing law.

## Deferred verification

Runtime behavior is the operator's receipt boundary ([A21]'s law): a
mod-load test is a world start, and world starts are the operator's.
The argument, the door, and the drift are verified by the gate's
structural pass and await the afflicted play receipts `[C116]` already
named - the return watched in an ordinary county, now with the
house's answer, the doors' answers, and the cast-out's ground
following it.

## Next

The totality order continues: the raider vocabulary (the ten swept
gaps), Week One's moments and gestures, age attachments, drugs in
totality - then the off-switch list before runtime verification, and
the corpus and training passes beyond. The sister's `[A33]` closed
the body's half; this closes the living's; the pathogen's own course
continues its rulings in MUTATION.md's order.