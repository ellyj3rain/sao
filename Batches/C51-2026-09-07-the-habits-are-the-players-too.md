# C51 - The habits are the player's too

| Field | Record |
|---|---|
| Batch | `C51` |
| Date | 2026-09-07 |
| Name | The habits are the player's too |
| Status | Closed append-only batch - awaiting live receipts (the five dependencies on the creation screen at -3 each; a drinker player getting the shakes at twelve hours and losing them on a drink; three weeks dry and the trait stops costing anything; a survivor the county drew a habit for reading as dependent to anything that checks traits) |
| Threads | [`T-002`](THREADS.md#t-002), [`T-007`](THREADS.md#t-007) |

## Record

[C39] registered the county's conditions as engine character traits so
the player could carry what the county's people carry, and left the
habits behind. `SAO_Habits` is the same kind of module as
`SAO_Conditions` - drawn from the person's own hash at the record's
prevalence ([C33], sources beside every row), lived on the record,
drifting every ten minutes - but nothing offered one at creation,
nothing stamped one onto a survivor's shell, and nothing would have
driven one on the player if it had.

**Five registered, at vanilla's own price.** Drinker, cocaine,
opioids, stimulants and sedatives, each anchored to `base:smoker` and
taking its cost of -3. One anchor for all of them is the honest
reading rather than laziness: the conditions differ in kind, so each
named the vanilla trait closest to its own shape, while the habits do
not - every one is a body that demands a substance and pays stress and
fatigue without it, differing only in schedule. The engine ships
exactly one trait of that shape. Reaching for a sleep trait's number
to make the drinker cost more would be inventing a rate the game does
not give, which is what [C48] refused for doors and rooms. Border 113
holds every cost to its anchor's, off the installed file.

**Cannabis is not registered.** N and C's page gives it no withdrawal,
so `USER_SCHEDULE.cannabis` is nil and `Hb.drift` returns nothing for
it. A costed trait on the creation screen that does nothing to the
player would be a lie about the game. The county still draws it, since
a habit somebody has is a fact about them whether or not it bites.

**Smoking is vanilla's.** The engine ships `SMOKER` and [A14] draws
smokers from the hash at a third of the county. SAO registers no
second name for one fact - the law [C39] set for asthma and insomnia -
and `SAO_Disposition.isSmoker` answers from the trait for the player.

**Somewhere for the habit to live.** Every write path in `SAO_Habits`
needs a record and the player has none. Without a store the player's
dry clock would run from world zero and never reset, a drink would do
nothing, and the habit could never lapse: maximum withdrawal from the
first minute, forever, with no counterplay - a trait worth taking
points for and impossible to play. So a key with no record may have a
table bound to stand in for one, and `SAO_Traits` binds the player's
own modData, which the save persists. Every existing write path works
unchanged, the dry clock starts when the character does, and a lapsed
habit stays lapsed across a reload because `Hb.has` reads the record
override before the assertion.

**The withdrawal drives on the player.** `Age.playerPass` calls
`SAO.Habits.drift` on the same ten-minute pass the county's people get
in `Age.drift`, and settles the habit on the day boundary - which has
to be done there rather than inherited from the daily loop, because
the player's key is not in `SAO.Identity.all()`. What `drift` returns
is applied without a second roll: the shakes were already rolled
inside it, and rolling again would halve every figure the sources
gave.

**The drink is read, not hooked.** The county's people go through
`Hb.drank` because the controller walks them to a bottle and queues
the action; the player just drinks, and there is no event for it. So
the player's alcohol level is read off `CharacterStat.INTOXICATION`
(javap-verified on `zombie.characters.CharacterStat`) and a rise since
the last pass is a drink. A read cannot miss an action shape it was
not written for, and if the stat is ever renamed the level simply
never rises and the clock never resets, which is where this started.

**Border 124** checks the anchors against vanilla's own
`character_traits.txt`; runs the record-side claims in the engine's VM
- the unbound key at maximum withdrawal with a drink that does
nothing, the bound key resetting on a drink and lapsing after three
weeks, a quit habit outranking the assertion, and the county's draw
unchanged by asserting the player's; proves cannabis costs zero stats
with cocaine as its control; requires every habit in `Hb.ORDER` to be
either registered or explicitly unpriced, and every registered one to
have a name a player can read.

**What the gate caught.** Border 72 refused three new per-id tables
with no declared forget - `Hb.asserted`, `Hb.bound` and
`D.assertedSmoker`. All three are cleared now by a function a death
reaches, and declared in that border's census. Border 113's seam
"conditions only" was renamed to what it actually checks: SAO does not
age the player.

**A habit can be acquired, and that follows from the store rather
than from anything written for it.** `Hb.drank` is the same function
for everybody, and it carries [C33]'s gain arithmetic - four points a
drink against one off an hour, the habit at two hundred. With the
player's store bound, a player who did not take the trait and drinks
often enough becomes a drinker on exactly the schedule a survivor
does. That is the consequence of giving the player a record rather
than a special case, and it is the right one: the module's whole
claim is that a habit is a fact about a person, not a purchase. The
five drug dependencies cannot be acquired the same way, because
nothing in the county supplies them and there is no use path to
count.

**Not in this batch.** Cannabis stays unregistered and undrivable
until a source gives it a withdrawal.

This governed record is the portable project history for this unit.
