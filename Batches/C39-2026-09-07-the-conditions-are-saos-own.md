# C39 - The conditions are SAO's own

| Field | Record |
|---|---|
| Batch | `C39` |
| Date | 2026-09-07 |
| Name | The conditions are SAO's own |
| Status | Closed append-only batch - awaiting live receipts (the nine traits on the creation screen with vanilla's own costs; a player who took one carrying it; a survivor drawn dementia reading as demented to anything that asks; SAO loading with no other mod enabled) |
| Threads | [`T-007`](THREADS.md#t-007), [`T-006`](THREADS.md#t-006) |

## Record

[C32] made Infirmities and Even More Traits hard requirements of
SAO so the player could carry the conditions the county's people
carry. It took no code from either and gained nothing mechanical;
what it bought was a trait framework, and it charged every user of
SAO two mod subscriptions for it. The operator ruled that wrong on
2026-09-07 - port the source instead, unless a page forbids reuse -
and DR-032 is amended. Neither page forbids it: Infirmities' terms
allow use and extension with credit, and Even More Traits is itself
a credited community port of another author's mod.

**The traits are ours now.** `SAO_Traits` registers a character
trait for each condition `SAO_Conditions` already derives, from
shared Lua, idempotently. Where vanilla already ships the condition
it uses vanilla's: asthma is `ASTHMATIC` and insomnia is
`INSOMNIAC`, because two names for one fact is the defect this
batch exists to remove. Nine are SAO's own - dementia, ADHD,
bipolar, depression, anxiety, haunted, dyslexia, psychosis,
diabetes - and the player takes them at creation.

**The cost is not picked.** Every condition names the vanilla trait
whose shape is closest to what SAO actually does to a person and
takes that trait's own cost, so the county's conditions are priced
on the game's scale and follow it if the game moves: dementia is
priced as illiterate because it takes what you know, ADHD and
dyslexia as the slow reader, bipolar as needing more sleep,
depression as the insomniac, anxiety as the agoraphobe, haunted as
the hemophobe, psychosis as hard of hearing because the senses
report what is not there, diabetes as the hearty appetite. Border
113 reads vanilla's own `character_traits.txt` and refuses any cost
that is not its anchor's.

**The condition rides the trait.** SAO_Body already keeps that law
for the trade - where the census life has an engine profession, the
body wears it, so anything that reads descriptors sees the truth -
and the conditions now keep it too: what the record drew is stamped
onto the shell at materialisation as the engine's own trait. A
survivor SAO drew asthma for is asthmatic to the engine.

**The player is read, not drawn.** A person whose conditions are
asserted answers from the assertion rather than from their hash, so
the player's chosen traits reach every surface in the tree - the
fear, the memory horizon, the learning pace, the reading time, the
drift, the plain words. The age module gains a player pass on the
same ten-minute cadence, running only the conditions: what the
condition carries, dementia's day, psychosis's hour. Not the stage
drift, the fear floor or the day of old age - SAO does not own the
player's ageing.

**What was taken, and from whom.** One technique, credited: trait
registration from shared Lua rather than through `registries.lua`
and a script definition, because the engine runs every mod's
registries file in one pass in load order and a mod that throws
there takes down every mod after it. The reasoning is Even More
Traits'; the calls it rests on were verified here against the
installed jar before use (ENGINE_CONTRACT Addendum F), and the
implementation is SAO's own. Both manifests are lighter by a
`require=` line.

**Border 113** holds the shape: nine traits defined and two left to
vanilla; every cost equal to its named anchor's cost as read out of
the shipped vanilla script that run; the registration in shared Lua
with no registries file and no trait script of ours; the stamp at
materialisation; the assertion beating the draw, driven in the
engine's own VM; the player's pass wired; a word for every trait;
and neither manifest requiring another mod. Its control is the
pre-batch tree.

**Not in this batch.** The habits ([C33]) as traits - the drinker
and the users are a schedule, not a switch, and vanilla's own
smoker trait is the only one of them the engine prices; icons for
the nine (no art is invented here); mutual exclusion against other
mods' traits; the moodles a condition might show.

This governed record is the portable project history for this unit.
