| Document | Survivor Awareness Overhaul Session State |
|---|---|
| Version | `3.0.0.0-pre-alpha` |
| Author | ellyj3rain |
| Repository | `SESSION_STATE.md` |
| Status | CANONICAL - where the work actually stands. |

# Session state

**As of** 2026-09-07, `[C41]` close - the world before the spawn
(DR-036, one precondition of it): genesis paced at six people a pass
whatever the state of the save, so a sixty-person county took about
a minute of play to exist and the first survivors a player met had
woken into a world with almost nobody in it. On a save that has
never been settled the budget is now the county's own target, and
genesis already runs ahead of the band in the tick, so the county
exists in full before the first body is materialised; the pace
stands unchanged for refill afterwards. DR-036 is the goal this
serves and is much larger than this batch: day zero is the
generator, a later start is that same machinery run forward before
the player arrives, and a start with the box unchecked is a
first-class case too. `[C40]` before it - the county stands on its own
(DR-035, the operator's assessment): nothing of this mod runs
through another survivor mod unless the player asks. The absorption
and the menu superimposition are behind one switch that defaults
off, and the older prompt hold - which replaced two of their
functions with wrappers of ours - defaults off too, so a fresh world
reaches into another mod zero times. What stays always on calls none
of their code: their people are never treated as threats and never
confused with ours. Both manifests require nothing but the loader,
and their description no longer claims the requirement `[C39]`
removed - which no border read until Border 114. `[C39]` before it -
the conditions are SAO's own
(DR-032 amended by the operator): the two required mods are gone.
`[C32]` had made them hard requirements so the player could carry
the conditions the county's people carry, took no code from either
and gained nothing mechanical; SAO now registers those conditions as
engine character traits from shared Lua - vanilla's own where
vanilla has one, every cost taken from the vanilla trait its shape
is anchored to - stamps a survivor's drawn conditions onto their
shell, and drives the player's chosen ones through the same
functions the county's people use. Border 113 holds it; Border
107's requirement seam is inverted to its opposite. `[C38]` before
it - the era remembered (Day Zero
slice 6): the knowledge surface carries "before" - born, the war,
where from, home, innocent or hardened - and "the day it started" -
the person's own first horror with its date and what it taught, the
county's stamps aired as news, the record's first day for a radio
owner - as claims with provenance; the chronicle reads its days as
the county's own dates through the same calendar; Border 112 drives
both topics in the engine's own VM. `[C37]` before it - an order
lands through standing
(DR-033, ruled; the command arc's first slice): every ask the player
makes of a person in the county's menus goes through `SAO_Command`,
Standing's command surface - CAO's obedience check carried over
whole on the Standing that exists (the office held, the trust, a
proven hand standing as a second, conformity read off the initiative
axis) and then the envelope's own reasons - refusal voiced with its
reason and seen, the panel's row in plain words; Border 111 runs the
check in the engine's own VM over the county sampled. `[C36]` before
it - the record on the county's
calendar (DR-031, Day Zero slice 7): every vanilla channel re-keyed
once per save to begin on the save day July 9, 1993 falls on, through
the engine's own surface; every paper a container is filled with
dated to the newest issue printed by the county's day, or taken off
the shelf; a sandbox switch on by default; Border 110 runs the
arithmetic off the game against the installed jar. `[C35]` before it
- the county's gestures (DR-034):
existing art copied with permission and credited - Hobbies'
conversation gestures, sitting loops, instrument plays and dances,
Week One's serving, coughs and claps - bound by SAO's own nodes on
variables only SAO sets, and wired to the moments the county already
has: the meeting's verdict, the voice's events, the evening seat, the
porch tune and its listeners. Border 109 holds file, node and name to
each other. `[C34]` before it - the moment carries the strain
(DR-033): the knowledge surface reads the situation the controller's
pressure names (under threat, working, resting) and whether the
speaker is spent, beside the axes, trust and the moment; Decision 5
is amended with the register floors under strain; Border 101 asks for
both. DR-033 also records the day's direction - talk is text, orders
follow standing, the county runs without the engine - and the three
forks ruled through Crucible without a rule to author. `[C33]` before
it - habits are facts about a person
(DR-032, S6): the drinker is drawn at the record's prevalence and
then lives on the record - The Alcoholic's four withdrawal phases by
the hours dry, a drink taken through the engine's own fluid action
or found where one is through the forage path, the habit gone after
three weeks dry and gained by drinking often; the users the county
fell with sweat it out on N and C's schedule and are clean by the
twentieth day; every drink a body finishes is counted; the age
module carries the load every pass and settles the habits daily; the
panel and the knowledge surface say it plainly. Border 108 drives it
in the engine's own VM. `[C32]` before it - conditions are facts about a
person (DR-032): the mind's and the body's conditions are drawn
from the person's own hash at the record's prevalence, gated by
age, and read by everything that decides - the axes bend inside the
envelope, the anxious and the haunted carry fear, the demented and
the old keep the recent less long and the haunted keep a threat
longer, the body carries a condition's load every ten minutes, the
demented lose skill by the day, the psychotic hear a threat nobody
else does, the dyslexic learn and read slower - and said in plain
words on the panel and the knowledge surface. Infirmities and Even
More Traits are required in both manifests for the player's side.
Border 107 drives it in the engine's own VM. `[C31]` before it - the
child's day (DR-032): a
child's fear has a floor by age, deepened at night and eased by a
comfort object and by their own kills, and the disposition's
decisions read it while the engine's panic holds it; a child under
eight cannot read the book; experience is throttled and strength
and fitness floored by age; the kit falls out of the child's own
temperament; the head is a child's. Border 106 drives it in the
engine's own VM, and Border 63's ranges now sample the whole county.
`[C30]` before it - age is a system on the county's
people (DR-032): the bands run from six to ninety, weighted from the
1990 resident population; Getting Old's five stages drift the living
every ten minutes on the engine's own stats; the age decides the
work (student, retiree), the pace and the size; and the old die of
it on the life table, a fact about the person and the day. Border
105 drives it in the engine's own VM. Children now exist in the
county and are drawn small through [C29]'s seam; the child's day
followed as `[C31]`. `[C29]` before it - the body is scaled from inside
the animation player (DR-032): the renderer scales no character on
its own, so SAO weaves a Byte Buddy exit advice onto the one method
that builds a body's per-bone model transforms and applies a size
held only on its own shell, uniform about the feet; the bridge sets
and reports it, the body takes it from the age once dressed, the
harness carries the click, and Border 104 weaves the installed class
off the game and has the JVM verify it. Nobody is under 19 yet, so
every body still answers 1; the receipt this waits on is the harness
click seen at three quarters. The same day, records only: DR-031
records the operator's ruling that the game's shipped record
of the fall (the broadcast schedule and the dated newspapers) is the
living start's to schedule, verified against the installed jar
before it was written down (ENGINE_CONTRACT Addendum E) and scoped
as Day Zero slice 7; the Speakeasy world document knox-event.md keys
that record to its absolute 1993 dates. At the `[C28]` close, the
inference budget instrument is in the jar: a deterministic model-shaped workload
timed on the game's own JVM from the debug menu, reported under
BUDGET (Border 102); the measurement it takes is what the
talking-system's sizing decision will cite. The design doc also
carries two more ratified verdicts: the 1993 world model comes as
researched, operator-ratified world documents plus curated period
text, and the speech-ML pipeline lives as its own tracked project
beside SAO - named by the operator: Zomboid-Speakeasy, scaffolded
at genesis with its charter and store rules. `[C27]` before it - the talking system's design
was ratified whole through Crucible (SPEECH_ML_DESIGN.md, DR-029:
two learned pieces in-process, data split by job, constrained
decoding, voice both-layers, the full two-way exchange) and rung 1
is built to it: SAO_Knowledge answers nine topics with provenance
and age, bundles the ratified conditioning, stays read-only by the
one-loop law, is DRIVEN offline in the engine's own VM every gate
run (Border 101), and the inspect panel gauges a person through it.
Next per the ratified order: the in-process inference budget
measured on the real game, then the data pipeline as its own
tracked project. `[C26]` before it - the operator's mid-play report
built into one law: nothing REPORTED that was not VERIFIED. Talk
answers now land (the murmur guards spare answers, the brush-off is
spoken, the trust wall came down to the advertised split - R-005);
dressing is outcome-verified with a worn report after two of the
county's own stood naked at the operator's sink while the log said
dressed=true (R-006, F-054); and DR-028's wake law holds the lines -
foreign claims push a wake out through the nearest wall and move the
home, own ground and the between stay fair game, one body per square
(Border 100). `[C25]` before it built DR-027: the errand dial deleted
everywhere, the probe a named perception span, all four live needs
plus the dormant day reaching for the nearest KNOWN offering under
the same claim law (Border 99; the odometer rolled the twelfth minor
over into a new tier by its own law).
`[C24]` before it fixed what the operator photographed (R-003): the
[C22] gating hook hung on a vanilla per-file LOCAL and silently
never attached (F-053); reattached through the real global onto the
panel instance, cannot-attach paths loud. The [C23] dial deletion and the
[C24] gating are both WITNESSED at the options screen (R-004): the
fields lock and his dials are gone. The ontology-hardening order
(seven items, operator's word, 2026-08-29) is closed except for what
the operator holds: `[C8]`-`[C11]` closed items 1-4, `[C12]`/`[C13]`
landed the two mid-play copy corrections (DR-017, DR-018), `[C14]`
ran item 7's first sweep round clean, and the Crucible session
settled items 5-6 (DR-019/020/021) - `[C15]` landed DR-020 and `[C16]`
the DR-021 census instrument, and `[C17]` the crowd ledger and
its restitution slice; the crowded-area bulk beyond restitution and
the highway corridors are the measured next slice. `[C18]` is the
first unit whose findings came from a RUNNING GAME (F-048/F-049). The
deploy hold was lifted on the operator's word the same day; the
deployed copy is the `[C28]` tip - the knowledge surface and the
budget instrument are live in the install.

## Standing

**29 A-batches and 52 B-batches, and both eras are closed.** The catalog was
recatalogued at the seam: the prior assistant's diary-rate sequence (200 A
entries and 193 B entries) was consolidated into these units, each one the
piece of work it actually was, per CAO's precedent. `Batches/FORMER_LABELS.md`
resolves every former identifier; the raw history is preserved as engineering
in local Git refs. The C era is open: `[C1]` walked the published catalog
against the tree (152 index links corrected from the record filenames, the
runtime map corrected against the code, Border 79 extended to hold the
class); `[C2]` made the version a machine (DR-013) - the coordinate is the
replay's output, held by Border 80; `[C3]` gave every person one name on
every surface (DR-014) and folded the neighbour framework's person-verbs
into the one menu; `[C4]` taught the follow to cross windows and fences
through the engine's own climbs and folded vehicles into follow and a
clear order, the seat and the mesh moving together; `[C5]` made world
text a person talking (the tell speaks the thing itself, coordinates
left every mouth) and repaired the swallowed-function class inside
P.tell; `[C6]` built the inspect harness - a normal-launch panel and
bound key over every store, to the one JSONL, reading everything and
teaching nothing; `[C7]` corrected [C3]'s menu reading on the operator's
word (DR-015) - the neighbour's per-survivor root stays as the person's
one menu, retitled and rebuilt from the county; `[C8]` made the turn
real (DR-016) - every dead shell reaches the engine's own `die()`
through the corpse net, the person id rides modData through the
engine's own copies (key `SAOPersonId`, PROPOSED, operator to
ratify), and recognition keys on what survives the turn (F-044/045,
Border 87); `[C9]` closed the blind deletion as a class (F-046) - one
deletion-grade identity predicate, failing closed, at every consumer
of the zombie list, and the removeFromWorld census closed (Border
88); `[C10]` aimed the kept promise at the one risen body carrying
the person's mark, honest about a miss, never the nearest stranger
(Border 89); `[C11]` replaced the invented bite formula with the
engine's own deterministic infection window, read off the body or
mirrored with citation, dormant turning mirroring the engine's own
predicate (F-047, Border 90); `[C12]` split representation from
implementation on the sandbox surface (DR-017) - mode-sentinels
became worded switches, the coded pressure scale became worded enum
values, and the one word-to-sentinel translation lives in the policy
reader (Border 91); `[C13]` struck the assistant's register from the
player's screen (DR-018) - the sandbox copy rewritten plain, and
Border 92 freezing player-facing copy to a verbatim ratified
declaration; `[C14]` ran the ontology sweep's first round - 216
pcall pairs, 262 call targets, 63 clock fields, every
engine-authority comment, zero findings - and promoted the
call-target instrument to Border 93; `[C15]` made whole minds
survive the reload (DR-020) - the perception store binds to ModData,
the tick axis rebases once on load, the hours axis crosses intact
(Border 94); `[C16]` built the dead census - an inert instrument
over the crowd, the identity split, and the extents, its projection
carrying its own sampling assumption (Border 95); `[C17]` built the
crowd ledger (DR-021's state agreement) - every pool take counted
durable, restitution debt-bounded, paced, distant, and off by
default (Border 96); `[C18]` took the first play receipts - a
re-issued order no longer restarts the route it is already walking,
which was cancelling climbs mid-transition and flipping survivors
between FLEE and IDLE 292 times a session; `[C19]` ended the
perpetual-untested tautology (DR-025) - RECEIPTS.md records what play
settles one observation at a time, R-001/R-002 seeded from the day's
own sessions (Border 97); `[C20]` built the absorption on the verified body law
(DR-022/023/024) - the neighbour's people taken whole at world start
and at birth through his one spawn seam, removed never killed, truth
mirrored back, his caps neutralized and screen-blocked, verb parity
kept (F-050..F-052, Border 98); `[C21]` inverted the wrap's failure
on the operator's word (DR-026) - a failed absorption spawns nobody,
loudly, and never falls back to his spawn; `[C22]` locked the manual
number fields behind their switches on the county's own page
(vanilla's per-frame gating idiom, Border 91); `[C23]` deleted the
overridden neighbour dials at the settings-table seam - no rows built
at all - and recorded DR-027, the no-leash ruling; `[C24]` fixed what
the operator photographed: `[C22]`'s hook hung on a vanilla per-file
LOCAL and silently never attached (F-053, R-003) - reattached through
the real global onto the panel instance, cannot-attach paths loud,
Border 91 refusing the dead anchor; and `[C25]` built DR-027's
knowledge-first acquisition - the errand dial deleted everywhere,
the probe a named perception span, all four live needs and the
dormant day reaching for the nearest KNOWN offering under the same
property law, horizons derived from the engine's own cell, held
knowledge revalidated and absence expiring (Border 99); and `[C26]`
made the county verify what it reports (R-005/R-006, F-054, DR-028) -
talk answers land, dressing is judged by what is worn, and the wake
law keeps foreign lines while a settled block populates its own
houses (Border 100); and `[C27]` built the knowledge surface to the
ratified talking-system design - what one person knows, as one
surface, read-only, driven offline (Border 101); and `[C28]` built
the inference budget instrument (Border 102).

The four pillars are built and the county runs on them: Perception admits,
Disposition decides, Standing channels, Execution acts. Every fact a survivor
acts on carries provenance and an age, and every acquisition says *how* it was
come by ([B39]) - seen, heard, told, lived, or `unknown` when the caller did
not say, never a silent default to the strongest claim.

Places come from the map's own `IsoMetaGrid`; what a place offers derives from
what its rooms contain rather than what the room is called ([B38]), so mods
this framework has never heard of reach the county; places are spent by being
visited and refill on the game's own `LootRespawn` ([B39]); loaded and
unloaded survivors are governed by the same rules ([B39], [B42]).

## Deploy state

`3.0.0.0-pre-alpha` at tip - the version machine's output ([C2],
DR-013; the twelfth minor rolled the tier by the odometer's own
law). The game install carries the `[C41]` tip, deployed 2026-09-07 at
the `[C41]` close; `[C33]` through `[C40]` reached the install the
same day, the first window the game was closed since the `[C32]`
deploy of 2026-09-06. The play receipts the C era owes are the next
thing the tree cannot produce for itself - the operator chose to
keep building before testing, so `[C29]` (a survivor scaled from
the harness), `[C30]` (a child in the street, an elder's slower
walk, a death of old age in the log), `[C31]` (a child who runs
before an adult would, a bear in a schoolbag, a child's strength on
the panel), `[C32]` (a condition on the panel, a survivor who runs
from a sound nobody heard, the two required mods enabling) and
`[C33]` (a drinker's shakes on the panel, a drink taken from the pack,
a walk to a cabinet for a bottle) wait together; this session's
play doubles as the live receipt the sibling project's death seam
needs before its mechanics open.

Two live saves - one fresh in Irvington, one with companions - survive every
deploy; `save_compat_test` guards this and runs in the gate.

## Instruments

**115 numbered borders**, run by **130 gated mirrors** in `tools/`, all invoked
by `tools/check.sh`, which the pre-commit hook runs and CI runs on every push.
The figures in this paragraph are derived by Border 76 from the tree, not
maintained by hand. Border 54 keeps the rest honest: it runs every gated
mirror against a tree with the Lua removed and refuses any that still pass.

## Open items

Play evidence accrues in `RECEIPTS.md` one observation at a time
(DR-025) - a batch is open until receipts touch its surfaces, and
that is normal here. The borders establish that the code says what a
record claims; only play settles that it happens in the world, and
what play has settled so far is in the ledger, never a blanket claim
in either direction.

Standing gaps, stated rather than left to be discovered: the player's own
looting does not deplete a place ([B39]); the witness rule keys on a recent
close sighting of the victim rather than on the killing itself; `carry-light`
dissent is an operator decision. The Workshop art is placeholder by choice -
[B51] generates an icon and a poster from `tools/make_art.py`, checked by
Border 73, and anyone may prefer their own drawing.

### Standing publication rule (2026-08-31)

The public repository receives squashed, clean commits only. On the
operator's ruling, after their session speech was found quoted
through the published records, the repository was deleted and
recreated on 2026-08-31 with a single clean root - the old commits
are gone from GitHub's servers entirely (verified: the former SHAs
resolve to nothing). Border 103 keeps the tree clean; local history
remains full; branch histories are never pushed raw.

### Open diagnostics

- The border gate intermittently exits 1 in compound shell runs
  immediately after a deploy or jar build, and passes clean on
  immediate re-run - observed twice on 2026-08-30, output
  uncaptured both times (redirected). Not reproduced under direct
  runs. Next occurrence: capture the full output before re-running,
  then find which border flickers and why.

### Waiting on the operator

Three things this pass cannot settle from here. (The 2026-08-29
Crucible session settled three others: the identity key is
`SAOPersonId` (DR-019), whole minds persist (DR-020, landed [C15]),
and the grounded dead run measure-then-guide with the optional
presence layer and the pool-taking state agreement (DR-021, the
census lands [C16]). The presence layer defaults OFF until the
measurement argues otherwise - stated as amendable, not ratified.)

- **The grounded dead's final numbers.** Ratified against the [C16]
  measurement, not before (DR-021).

- **The county's pace is frame time, not real time.** Everything except the
  voice cooldown counts frames, so a 144Hz machine runs a county 2.4x faster
  than a 60Hz one. Changing it touches every timer in the mod and changes how
  the game feels; it is a design call.
- **`s.relations` keeps a row for everyone who ever lived.** [B51] budgeted
  the walk, so the cost is bounded - but the rows of the dead are still in the
  save and still growing. Pruning them is irreversible on a live save. The
  four readers of a row are all about a living actor, so dropping
  `relations[deadId]` while keeping everybody's feelings ABOUT the dead looks
  safe; that is a judgement about somebody's save, not a border.
- **[B48] changes every survivor's traits, occupation and face in
  an existing save**, because the hash they are drawn from was corrected.

## The condition

The idea is the success condition, entire. The pass continues until the
operator ends it.
