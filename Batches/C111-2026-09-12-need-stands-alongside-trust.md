# C111 - Need stands alongside trust

| Field | Record |
| --- | --- |
| Batch | `C111` |
| Date | 2026-09-12 |
| Name | Need stands alongside trust |
| Status | Closed append-only batch - mod state and law |
| Threads | [`T-004`](THREADS.md#t-004), [`T-006`](THREADS.md#t-006) |

## Record

The queue's item 3 said a road meeting was worth `ROAD_TRUST` 0.005, so
the company line from nothing was two hundred meetings with the same
person and a house could only ever grow out of trust settled at genesis
- and it deferred the call to the cognition rows (DR-038). The operator
ruled on it directly (2026-09-12): a meeting should be worth more, most
people not only want but NEED to be around people, and trust is not
always the principal determinant of whether a group forms - which
depends on how far along into the apocalypse the world is. The design
question is answered at the level it was asked; DR-038's rows may later
refine the words a person uses, but the mechanism no longer waits on
them.

This batch pays that ruling as two laws, both in `SAO_Standing.lua`:

**`companyPull(id)`** - how much a person needs company, from three
factors that are all facts the county already held.

- *Appetite* is who somebody is: `History.contactFactor`, the same
  0.10-1.00 hash that scales how fast a past settles. A hermit's need
  carries almost nothing.
- *Isolation* is where they are right now: `[C94]`'s state surface,
  which existed for seventeen batches and gated nothing - this is the
  job it was built for.
- *Openness* is the county's condition: months since the fall on the
  split clock (`[C61]`, `clockMonths`) over a horizon of six. An
  ordinary county forms its houses through acquaintance and need
  carries nobody; a county six months into collapse is a county where
  being alone is what kills you, and a fully isolated sociable
  person's need can carry the whole company line. The horizon is the
  one number here that is not already the county's - half a year of
  collapse, stated so the operator can move it. Openness rides the
  clock as the world is played, and a world generated already deep
  reads deep from its first minute, so one law covers both and nothing
  consults a dial.

**`companyStanding(id, otherKey)`** - the value one person brings to a
company door: their trust toward the other, plus their own pull. Need
substitutes for trust not yet built; it never cancels trust already
spent against somebody, so the pull only reads where trust is not
negative - two people who have already quarrelled do not shack up out
of loneliness. Each door keeps its own comparison and its own bar
(mercy softens it where it did before); the VALUE is the one law, so
the road, the table, and the player's own company cannot disagree
about the same person on the same day.

Both degrade to zero - the old law, trust alone - whenever any factor
cannot be read: offline, a bare VM, a dead or unknown id. The pull is
read once a county hour and held (a person's need does not change
inside one), so the live seams can ask per tick without paying the
belief-store walk each time.

## What changed here

- `SAO_Standing.lua` gains `companyPull(id)` and
  `companyStanding(id, otherKey)`.
- `ROAD_TRUST` rises 0.005 -> 0.02 (`SAO_Population.lua`): the default
  line of 0.5 is twenty-five meetings instead of two hundred - still
  acquaintance built over weeks, never one conversation.
- Every company door now reads the pair standing:
  - the road (`dormantEncounters`' formation seam) and the table
    (`SAO_Exchange.lua`'s live seam), both mutual - both sides must
    clear, each by their own pull;
  - the visit gate (`chooseWhoToGoTo`) - the lonely go looking before
    trust alone would carry them. The RANK stays pure trust over
    sighting age, because the pull is the same for every candidate and
    orders nobody;
  - the companion seam (`SAO_Controller.lua`) - an ungrouped survivor
    short of company walks with somebody half-trusted rather than stay
    alone;
  - the player's own asks (`SAO_Harness.lua`): "ask to walk" reads the
    effective line, so somebody whose need already carried them past
    it says "already would" and the ask is for those the need almost
    carried; "ask to join" reads the judge's pull, so a small,
    short-handed house in a deep county takes the petitioner; and the
    work-designation menu's "willing" reads the same line the
    companion seam holds.
- Temperament is untouched: circles, capacity, hostility, and the
  mercy softening gate exactly where they did. Need opens the door; it
  does not overrule who somebody is.

Doors that still read trust alone, deliberately: leaving a house for
the player (a defection that must trust the player clearly more than
the people being left), the counsel and petition menus' hearing bars
(office and loyalty, not company), and `SAO_Recognition`'s appeal and
claim bars (the house's memory of who would have them). `[C111]`
applies where the company line decides ENTRY into company; it does not
apply to judgment, office, or defection.

## Honest limits

- The six-month horizon is the one authored number in the pull. It is
  stated in the code comment and here so the operator can move it; the
  direction it scales (deeper world, more need) is the ruling's, the
  half-year mark itself is this batch's.
- The twenty-five-meetings arithmetic is a rate, not a schedule:
  `MEET_COOLDOWN` caps one meeting per pair per roughly thirty to
  sixty seconds of adjacency, and how often two people's paths cross
  is the county's own. Whether a fresh county actually grows houses
  out of meetings is a play receipt.
- Need still does not make anybody seek company they have never met:
  the visit gate ranks people they already believe exist, and
  strangers still have to cross paths to meet. Putting people on the
  streets to cross is the pre-fall normal-life batch's work, not this
  one's.
- A border for this law belongs to the end pass with the rest of the
  deferred verification; none was written here, per the standing
  order.
- END PASS, 2026-09-13: that border landed as Border 152
  (`tools/company_pull_test.py`). The pull is measured in the VM
  against the shipped Standing - appetite, isolation, the six-month
  horizon, the memo that holds within a county hour, the
  negative-trust veto, the unreadable-id zero, and the ordinary
  county where need carries nobody - and every door's seam (road,
  table, companion, the player's asks) plus temperament's
  still-standing gate are held in text.

## Verification

Deferred by the operator's standing order for this pass: no gate,
build, deploy, package, test, or git until the planned feature work
is finished; all of it runs once, at the end. Version stamps restamp
in that same end pass.