| Document | Survivor Awareness Overhaul Session State |
|---|---|
| Version | `4.0.0.0-pre-alpha` |
| Author | ellyj3rain |
| Repository | `SESSION_STATE.md` |
| Status | CANONICAL - where the work actually stands. |

# Session state

**As of** 2026-09-08, `[C67]` close - founding a company dissolved
it. No company had ever formed in this project, in a sweep or in a
save, since companies were built. A company was founded by joining one
member and then the other; `joinGroup` elects, and `electLeader`
performs the widow release at a roster of one, so the first join made a
house of one and freed its only member and the second join did it
again. The house was empty before the second line finished. Everything
downstream of a company was therefore unreachable code that read as if
it worked - the election, the creed, the designations, the chair, the
steward, feuds, pacts, schisms, and the radio news of all of them.
`S.formCompany` writes the roster whole and elects once, at the three
sites where a company is born: the road, the table, and Knox adoption.
The widow release is not removed and is not the defect - it is a rule
about a roster that SHRANK, and it is right; `electLeader` is called
from both directions and cannot tell growth from loss, so a house being
born read as a house ending. Twenty-four counties against the real
shipped map went from 0 of 24 forming a company to 24 of 24, and the
row that names the defect is the trust line: 264 pairs already stood
above the company bar in the broken tree and not one of them could keep
company. Border 135 measures the house rather than the call, because
the defect called the right verb the right number of times.

**Before that**, `[C66]` - the county carries its own
randomness. Forty-two places asked the engine through `ZombRand`,
which carries no state SAO can see, set or write down, so no county
could be run twice: a reported defect could not be reproduced, and a
sweep moving one sandbox dial could not tell the dial from the draw.
`[C65]` recorded that as a fact about the corpus; the operator ruled
the other way and took the wider option, so `SAO_Rand` is the county's
draw and nothing else in the tree asks the engine. It is
counter-based, so the state is a seed string and a count that persist
into ModData as-is, and the arithmetic is `[B48]`'s already-verified
split-multiply FNV rather than a second answer to a question this
repository has answered. The seed comes off `IsoWorld.getWorld()` and
the save's start date, both javap-verified, and stays private. The
first draft RAMPED - `SAO.Hash.of(seed, counter)` read FNV's low
digits and 1626 of 1999 draws mod one hundred were exactly the one
before plus one, which is `[B48]`'s arithmetic progression through a
different door on top of `[B38]`'s parity finding - and only measuring
caught it. Four forms were measured before one was picked; the counter
goes first and the answer comes from above the low sixteen bits, at
chi-square 0.0, 1.9 and 101.6 for moduli 2, 6 and 100 against critical
values of 10.83, 20.52 and 148.2. Border 134 measures the draw rather
than reading the formula, because a border that read the formula would
have passed the ramp. `[C65]` before it - the years pass leaves a
trajectory. The operator ruled that a late start cannot afford
first-principles generation at distance and chose a learned trajectory
model fitted to the generator's own per-year runs; there were no runs.
`[C45]` mutates state in place, so the county at the end answers what
it is like now and destroys what happened, which is the thing being
modelled, and the only lines reaching the telemetry file during a span
were incidental death and lesson events with no boundary around them.
`SAO_Telemetry` was already built on that exact argument at `[B38]` -
"a daily snapshot answers what the county is like now and destroys
what happened" - and had never been pointed at the years. Every line
now carries the run it belongs to while one is open and none outside
it; `T.run` opens and closes a span and `T.conditions` records what it
was run under, none of which is recoverable from the county lines
afterwards. The identifier is made once and kept in the save, because
a span sliced across hundreds of passes and a reload is one run. The
county line gained need, groups, claims and fortification - `dry` and
`hungry` among them, declared in `T.county` since `[B38]` and never
assigned - and `oneYearsDay` writes one line per simulated day. Border
133 drives the real module in the engine's VM with `getFileWriter`
stubbed, so every assertion is made against the JSONL actually
emitted. Reading the module also found its own comment wrong: it says
the county is written once a day and its only caller runs once per
session load. `[C64]` before it - the blanket claim is gone
from every document that carried it. DR-025 banned the
perpetual-untested claim on 2026-08-29 and Border 97 has held it out
of this file and `PLAYABILITY.md` ever since; the operator found it
alive thirty-five batches later in `README.md`. It was in five
places - `README.md`, both `mod.info` descriptions, `PLAYABILITY.md`
and `PUBLISHING.md` - and three of those are files the border never
opened, because it read exactly two documents named as literals in a
loop. The claim is false and has been since `[C19]`: `RECEIPTS.md`
holds six receipts, several of them defects found by playing, and the
`mod.info` description told anyone reading the Workshop page that none
of it had happened. Border 97 reads every root document and both
`mod.info` files now, twenty-six of them, with the two that quote the
claim while explaining the ban exempted by name; it gained the four
spellings that got through, and it refuses to run against fewer than
three documents because reading two was its actual failure. It also
holds a number: the README states how many receipts the ledger holds
and the border checks it, which is the durable half, because a
negative nobody can check does not decay - it stops being true. Border
43 reads the README's own coordinate, which stood two tiers behind
the tree because the README carries no header cell for that border to
catch it by, and Border 43 gained the `argv[1]`
control mechanism it had never had. `[C63]` before it - a day-zero
start owes no
years. DR-036 has two halves and they were deciding the same fact
separately: `[C43]` moves the record's own first day onto a 1993
save's start when the day-zero switch is on, so the outbreak arrives
eight days in, while `[C45]` counted the calendar days from the
record's day 0 to that same start and lived them before anybody was
spawned. `daysBehindAtStart` knew nothing about the switch. Measured
off the game against the built class, a July 20 1993 start ran eleven
days of collapse, an October 1 start eighty-four and a December 15
start a hundred and fifty-nine, each handed to a player whose record
said the outbreak was still eight days away - which is the artificial
structure DR-036 exists to avoid, produced by DR-036's own two halves.
`daysBehindAtStart` takes the switch now and asks `mayShift`, the same
refusal `shiftTo` makes, so a save the record may be moved onto owes
nothing and a 1996 start still owes its thousand. `countyMonth0` is
handed that number rather than deriving it again, which would have
read a shifted July start's months eleven days early for the whole
save, and `SAO_History.daysOwed` is the one reader on the Lua side,
off the same sandbox switch `SAO_Record.placeTimeline` reads. The
switch was taken over a flag set by `shiftTo` because `shiftTo` runs
from a module that legitimately never runs when the record option is
off. Border 132 holds it, controlled against the `[C62]` tree where
the same December start still owes its 3816 hours. The first draft of
the fix was killed by the same measurement that found the defect.
`[C62]` before it - one clock for the county, and
the years pass moves it. `[C45]` lives the days a later save owes by
calling the county's own systems one simulated day at a time, and it
never moved the clock those systems read. Sixty-eight places in the
tree asked `GameTime` for the world age in hours, `GameTime` does not
advance while the years run, and so every system that gates on a
CHANGE of day saw one day for the whole span: attrition stamped
`lastRiskDay` on the first simulated day and killed nobody after it,
the water and food stamps never advanced so nobody grew thirsty or
went looking, `driftStandings` returned on `lastDriftDay` every day
but the first, three simulated years of winter ran in the save's
start month, and a save begun at three in the morning sent everybody
home for the whole span because the hour of day was frozen too. A
1996 save ran a thousand days and came out of them with the same
people, the same feelings and the same needs.
`SAO_History` carries the county's clock now, beside `[C61]`'s: the
day being lived while the years run, the days behind the record plus
the game's own hours after them, meeting at the same number so a
stamp made during the years stays in the past. With it come the
calendar month those hours fall in, anchored in
`SAORecord.countyMonth0` so a simulated January is cold, the hour of
day, which is noon while the years run because a simulated day models
daylight, and the record day, which `clockMonths` reads so what a
person has had time to learn grows across the span. Sixty-seven sites and four season
reads were swept, leaving `SAO_History` the only module in the tree
that asks the engine, and `runTheYears` publishes the day it is
living before it lives it rather than once a slice. Border 131 holds
it, and its control is `driftStandings` on three consecutive
simulated days: two feelings a day here, and nothing after the first
day on the pre-batch tree. Border 118, `[C45]`'s own, could not have
caught this - it checks that the years pass calls those systems,
which it did. `[C61]` before it - one clock for how long this
has been going on. Three readers answer how far into the collapse a
save is, and `SAO_History.clockMonths` - the number that ages what
every person KNOWS, through the split clock into contact months and
from there the lesson pool and the claims a person carries - was
reading `SandboxVars.TimeSinceApo` while [C42] had already ruled the
fall is read from the record's calendar and never from the dial. So a
1996 save ran about a thousand days of county forward ([C45]) and
then told every survivor in it they were one month in: the county's
history and the county's people disagreeing about the same fact. It
reads the calendar now, and answers zero before the fall, because a
county that has not had its outbreak has nobody who has lived through
one. The dial remains the answer only where the calendar cannot be
read at all, so the module stays offline by construction. Border 130
holds it; its own first seam compared identifiers rather than call
forms and failed on this batch's own comment, which is the prose-is-
not-code rule in GOVERNANCE.md paid for again. `[C60]` before it -
the player's looting spends a
place. The standing gap since [B39]: a survivor taking something
calls `SAO_Places.take` and the place is spent for everybody, and the
player's looting called nothing, so a shop the player had stripped
still read as full stock and the county kept sending foragers to it.
Read rather than hooked - the engine marks a container looted when it
has been emptied (`isHasBeenLooted`, javap-verified, a flag SAO never
writes), so the ground itself is the reading, walked the way the
needs layer already walks containers and taken to the place ledger on
the player's own ten-minute pass. The tally is raised and never
lowered, held at the place's capacity, and the refill stamp moves
only when the count raises it, so standing in an untouched room does
not reset its clock. What the county BELIEVES about a place is
untouched: a survivor who thought a shop was stocked still thinks so
until they go and look, which is Perception's business. Border 129
holds it. `[C59]` before it - main is protected and batches
arrive by pull request. `[C56]` through `[C58]` were pushed straight
to `origin/main`: thirty-one commits, no branch, no pull request, no
merge. CAO is the standard for how this repository publishes and its
`main` carries squash-merged pull requests; this one was taking
direct pushes. Nothing stopped them because nothing was set to -
CAO's `main` is protected and SAO's answered 404, so on CAO those
pushes would have been rejected at the server. `main` is protected
now on the same shape with this repository's own checks: pull request
required, `ci-verify` and `codeql-python` required and strict,
admins included, linear history, no force pushes, no deletions.
NEO.md's publishing convention said to push to `main` - the mistake
written down as the rule two batches after it was made - and now says
branch, pull request, merge, and to merge it rather than leave it
open. The thirty-one commits stay: force-pushing the public record to
make it look like the process was followed is worse than the record
showing that it was not. `[C58]` before it - the codeql-action halves
travel together. Two dependabot pull requests had stood open and
failing since 2026-08-31 with the same error: a configuration loaded
for 4.37.7 while running 4.37.9. `init` and `analyze` are two
dependencies to dependabot and one action to CodeQL, so a pull request
bumping either half alone produces a mismatch CodeQL refuses, and
neither could ever have passed because the fix is in neither. Both
pins move to v4.37.9 in one commit - the tag read off the upstream
repository rather than taken from the pull requests - and the config
groups the action so a future bump carries both halves. CodeQL itself
was passing on `main` throughout; the failures were on those two
branches only. `[C57]` before it - a skip is not a vacuous pass.
The C era was published to `origin/main` at `[C56]`: twenty-nine
commits, one per batch from `[C29]`, and one carrying `[C28]`'s tree
for everything before it, because Border 103 refuses the tree of
every batch up to `[C27]` - they hold the quoted speech and profanity
this repository was deleted and recreated over on 2026-08-31, and
publishing them one at a time would have put it back. The published
tree matches this one exactly.
CI then refused it, for a defect beside the one `[C56]` fixed: Border
54 runs every gated mirror against a tree with no Lua and refuses any
that still pass, and it read a border that DECLINES to judge - returns
0 and says SKIPPED because it reads the installed game - as one
passing on nothing. Eleven did, on a machine without the game. A fifth
state now, on the argument `run_blind`'s own docstring already makes.
Eight of the eleven predate `[C56]`, so they were read that way on
every machine but this one, and CI Verify has never succeeded on this
repository - not on the 2026-08-31 publish, not on either dependabot
pull request. `[C56]` before it - borders skip when the game is
absent. The operator asked why nothing had reached the public
repository. `origin/main` stood at the single squashed root pushed
2026-08-31 and the local tree was 112 commits ahead, the whole C era
from `[C8]` to `[C55]`. Publishing was never in the close order, so
nothing pushed for eight days; NEO.md carries the step now on the
operator's ruling of 2026-09-08 - one squashed commit to
`origin/main` at each close, after the deploy, and the divergence
checked at session start. And a push would have failed CI: the
workflow runs the gate on a machine without the game, its own comment
says the borders that read the install report SKIPPED, and fifteen
exited 1 instead, which `check.sh` reads as the gate refusing. That
comment said six; thirty-four tools read the install now, so a count
in prose went stale in silence and eleven borders acquired the wrong
behaviour unseen. All thirty-four skip cleanly. Border 128 holds it
and was itself wrong three times first, each time accusing a tool.
The four Laws in NEO.md are rewritten plainly on the operator's
direction, content unchanged - two were mirrored turns, the register
the writing rule directly above them bans. `[C55]` before it - seeing
a death is not seeing
who did it (Law 1). The standing gap since [B39] said the witness
rule keys on a recent sighting of the victim rather than on the
killing. Read at the code it is narrower one way - the freshness
window is two seconds, so a fresh close sighting of the victim IS
being there - and much worse another: nothing ever asked whether the
witness saw the KILLER. The engine's attacker tag named who did it
and both the death site and the wounding site spent that name on a
witness whose only belief was about the victim, so a survivor ten
tiles from somebody shot from forty could drop eight tenths of trust
in, and declare a blood feud on, a person behind a wall they had
never laid eyes on. The death still lands, mourns and travels down
the roads, because Law 1 calls oblivion a failure too; the name
lands only where they could have seen who, and the log says when it
does not. Each half of the county is asked in the currency it has -
a fresh observed belief of the killer at the place for a live
witness, the positional question for a dormant one, which is [B47]'s
rule. Border 127 lifts both predicates out of the controller and
runs them in the engine's VM; its own first lift was wrong and it
said so rather than passing. `[C54]` before it - the objection picks
the car
(Day Zero slice 5). Most of the slice was already built: the
quartermaster appraises the yard, a runnable car doubles a venture's
range, the party is capped by the car's real free seats, the trip
burns the real tank by the real distance. One link was a defect.
`roadworthy` read the whole motor pool and returned one car, and the
venture then applied the goer's own objection to that one, so
somebody who has learned that noise is a debt discarded the yard and
walked past a quiet runner they would have taken - and nothing looked
wrong, because the log said the loud car was left where it sat, which
was true and complete about the wrong question. That is F-057, and
the shape is general: a chooser returning its own best candidate to a
caller holding a veto turns the veto into a refusal of the whole set.
The loudness ceiling goes in with the ask now; passing nothing gives
the old answer, which is what the panel does; a yard of only loud
runners still ends in a walk; and the second loudness test at the
call site is deleted rather than left reading like a live guard.
Border 126 holds it, its control the pre-batch tree handing the loud
car to the person who refuses it. `[C53]` before it - who goes along
weighs who is
asking (Day Zero slice 4; DR-033). [B19]'s joining weighed everything
about the hearer and nothing about the trip or the caller. The
caller's office over that person now enters the pull in
SAO_Command's own currency - a leader's call above a second's above a
peer's, no number invented at the site, and the divided house
arriving with it - and a warpath asks the hearer's own envelope, so
nobody is persuaded into a fight they would not take. Ported to the
joining mirror in the same batch, per that script's own doctrine.
The mirror then refused the first claim made about the change: an
average party size compared across houses answered that the office
cost company, which was a bad measurement, and isolating the term
gave a worse and truer one - it carried nobody in 690 invitations.
That is F-056. The pull's median in the converged county is 1.28
against a threshold of 0.55 and 96 percent of invitations clear it
before any term is consulted, so nothing in the calculation can
decide anything once trust has saturated; who comes along is settled
by the three refusals and the caps. The threshold is an authored
number and moving it is a design call, so a sixth sweep was added
instead - a house that formed recently, which is the house a
day-zero county is made of, and where the office carries 46.
`[C52]` before it - psychosis and insomnia get
their figures. Two rows in the conditions table had stood at zero
since [C32], each with the reason in the file: no primary figure of
the era had been read, so nobody was drawn and neither mechanism
could fire for anybody in the county. Psychosis draws at 70 per ten
thousand now, off Kendler et al., Arch Gen Psychiatry
1996;53(11):1022-31 - broad nonaffective psychosis, clinician
diagnosis rather than the algorithm's, lifetime, 0.7 percent, each
of those three the conservative choice and each stated in the row.
Insomnia draws at 1020, off Ford and Kamerow, JAMA
1989;262(11):1479-84, where 10.2 percent of 7954 ECA respondents
noted insomnia at the first interview - and the row says plainly
that this is a complaint recorded once rather than a chronic
diagnosis, that it draws about one adult in ten and that this is
more than the county should carry, and names the persistence figure
that would replace it. Border 125 turns the sourcing rule into a
mechanism rather than a habit: every row names a year or points at
the table above it, every constant must be reachable from the
comment's own figures by a derivation the row names, and a zero must
say out loud that no figure was read. Thirty-two figures across
seventeen rows; it caught four habit rows citing nothing of their
own. `[C51]` before it - the habits are the player's
too (DR-032, the society arc's S6). [C39] registered the county's
conditions as engine traits so the player could carry what the
county's people carry, and left the habits behind: nothing offered
one at creation, nothing stamped one onto a survivor's shell, and
nothing would have driven one if it had. Five are registered now -
drinker, cocaine, opioids, stimulants, sedatives - each anchored to
`base:smoker` and taking its cost of -3, because the habits differ
only in schedule and the engine ships exactly one trait of that
shape. Cannabis is skipped: its source gives it no withdrawal, so a
costed trait doing nothing would be a lie about the game, and the
county still draws it. Smoking is left to vanilla's own SMOKER. The
player gets somewhere for the habit to live - their own modData,
bound as a stand-in record - without which the dry clock would run
from world zero and never reset, a drink would do nothing, and the
habit could never lapse. The withdrawal drives on their own
ten-minute pass, applied without a second roll, and a drink is read
off `CharacterStat.INTOXICATION` rising rather than hooked to an
action. A player who drinks often enough becomes a drinker, which
follows from binding a store rather than from anything written for
it. Border 124 holds it; Border 72 caught three per-id tables with
no forget, and they have one. `[C50]` before it - what a survivor
says follows
what they have learned (DR-036, Day Zero slice 3). Every line table
in SAO_Voice was flat, so a county that had learned nothing still
fled saying "Too many" and warned each other with "Dead nearby" -
a count and a name that somebody acquires by living through
something, and on a day-zero start that is the case the mode exists
to make different. The five tables about the dead and about violence
carry two registers now, and the register comes from the speaker's
own lesson store on the boundary the county already drew: innocence
is having learned nothing yet ([B1]/T-002). No threshold was
invented and nothing new is stored. The taught lists are the lines
that were already there, and an unreadable lesson store returns them
- a missing answer keeps the old behaviour rather than making the
whole county sound like it has seen nothing. The crossing is
audible: SAO_Lessons already dated the first lesson and called it
the day the world changed for that person, so `learn` reads whether
the store was empty before it writes and raises one murmur when it
was, which means the quiet cross over in silence and nobody can say
it twice. Border 123 holds it. The wire is the other half of the
slice and is unbuilt. `[C49]` before it - survivor orders use the
command check (DR-033). [C37] routed the player's asks through
SAO_Command and left survivor-to-survivor orders alone; three
existed and each decided for itself. The keeper rousing the house
checked nothing. An owner telling a trespasser to go was obeyed by
anyone not starving. A housemate objecting to somebody leaving used
a hardcoded authority test written at that one site - bonded, or
same side above 0.5, or leader/second above 0.5 - which is the kind
of table DR-033 rules out. It is deleted and all three go through
SAO_Command. No weights or thresholds changed: three Standing facts
became inputs, each worth what a proven hand is worth. A divided
house withholds the leader's office from members leaning the other
way and keeps it over members with no lean ([B23], [B24]), which now
governs the player in a chair too. A designation gives standing in
its own matter. A claim gives standing in the matter of leaving it.
Seeing another survivor act is still not an order and is not
checked, and a warning the listener believes still raises the house
without a standing test, since Perception already carries the
skepticism. Border 122 holds it; Border 46 caught the first version
replying on the player's voice path and it uses the murmur path
instead. `[C48]` before it - how hard a place is to get
into (DR-037). The scout weighed rooms, area and water and could not
see a door, so a glass-fronted shop with eleven ways in beat a house
with three whenever it had one more room. It counts them now, off
the loaded ground and with the boarding's own predicate, so what the
scout counts and what somebody would later have to shut are the same
things. It is a TIE-BREAK and not a weight: pricing a door against a
room would invent a rate nothing in the county gives, so where two
places are within one room's worth the one with fewer ways in wins,
and the margin is the score's own named unit. Border 121 fails if
the count ever appears inside the score. `[C47]` before it - the
fence (SPEECH_ML_DESIGN
Decision 4, ratified 2026-08-29 and called there the hardest single
piece in the design). No-invention is enforced by constrained
decoding rather than by instruction: a speaker is handed a
vocabulary it cannot escape, every fact position fillable only from
that person's own claims. The slots are read off the knowledge
surface rather than listed anywhere, the comparison is exact and
never advisory, an unknown slot is refused rather than allowed, and
a fence that throws refuses rather than permits. Built before any
model, because it is what makes a wrong one harmless - and because
it needed neither a corpus nor a budget measurement, both of which
still wait. Border 120 proves it over a corpus off the game,
near-misses included. `[C46]` before it - the ground is read during the years. The
engine holds only an eight by eight chunk window around each player,
so during the years no claim is in any cell; a chunk is loaded on
its own instead, read, and let go - one claim a simulated day on a
rotation, ground read inside thirty days left alone. The county
learns the ways into the place a person holds and how many are shut,
off ground actually read, and the panel says it. It writes NOTHING:
saving a chunk writes into the player's own save through shared
static buffers and no part of this mod has a live receipt, so Border
119 refuses any save, barricade or placement in that path and Border
118 admits the look only on that evidence. Doing something to the
ground during the years is the next piece and is where the risk
lives. `[C45]` before it - the years between (DR-036's
other half). A save beginning after the record's year now runs the
county's own machinery forward over the days it owes before anybody
is materialised: the dormant day, the meetings on the road,
attrition, the softening of old feelings, the age table's roll and
the settling of habits, every one of them the call the live county
already makes. Houses, leaders and feuds arrive out of the dormant
encounters as they do in play, and nothing is placed. The cadence is
daily and measured (F-055): the ten-minute pass exists to drift a
body's stats and nobody in the years has a body, so three years cost
about two minutes rather than five and a half hours. Sliced at sixty
milliseconds a pass so it cannot hang, after genesis, holding the
band. Border 118 refuses a simulated day that reaches for a group, a
bond, a claim or a death directly. `[C44]` before it - they either
build or they do
not (DR-036, ruled through Crucible). Asked what had to exist before
the years between are simulated, the operator rejected the framing:
nothing is forced, the county is not handed settlements, and a pass
that authored one would destroy the only measurement there is. So
the county gets a capability - a person who holds ground, after the
fall has come, standing on their own claim and carrying a hammer, a
plank and two nails they found themselves, boards a window through
the engine's own barricade calls at the shipped action's own price,
the materials leaving their bag. Every clause can fail. The panel
reports what a person managed and says nothing when they managed
none, which is the honest reading of a county that has not. Border
117 holds that no genesis, population, absorption or harness path
places one. `[C43]` before it - the record's timeline moves
onto the start date (DR-036). The lore is canonically 1993 and
`[C36]` pinned it to the dates it carries, so a player who set a
March start sat in a quiet world until July. A player now picks any
date in 1993 and, with the Day Zero switch on, the record's own
first day lands on it: its week of ordinary county, then the
collapse, then the rest in shipped order, with the broadcasts and
the dated papers moving with it, and a start later in the year
moving the timeline backwards onto it. The week is the record's own
number rather than a setting - a dial for it was invented in a first
draft and removed. A 1994 or later start is refused the move, because
that save is owed the years between simulated forward instead, which
is DR-036's other half and unbuilt. `[C42]` before it - before the
fall, an ordinary
life (DR-036): an audit of what the day-zero switch actually reached
found two things - no lessons seeded, duty-only arms - and that not
one decision in the tree asked whether the fall had happened, though
the county had written three stamps for it since `[B1]` and read
them only to print a chronicle. The county can be asked now
(`fallHasCome`), derived from those stamps and the record's calendar
and never from the sandbox dial, and the night watch, the journey
for a weapon or for ammunition, and scouting somewhere defensible
all wait for it - while eating, drinking, warmth, treatment,
mourning and going home deliberately do not. `[C41]` before it - the
world before the spawn
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

`4.0.0.0-pre-alpha` at tip - the version machine's output ([C2],
DR-013; the twelfth minor rolled the tier by the odometer's own
law). The game install carries the `[C62]` tip. `[C45]` through
`[C51]` reached it on 2026-09-07 and `[C52]` through `[C62]` on 2026-09-08, each
after its own commit passed the gate, the game having been closed
since the `[C44]` deploy. Verified rather than assumed at each
deploy - the deployed `mod.info` reads the version the machine
derived and the deployed `SAO.jar` is byte-identical to the
committed build. `[C56]` touches only the instruments and the
documents, so there is nothing behavioural in it to deploy.
`[C62]` reached it on the same day, after its own commit passed the
gate and its pull request merged, and was checked rather than assumed:
both `mod.info` files read the coordinate the machine derived,
`SAO_History.lua` carries the county's clock, `SAO_Standing.lua` reads
it at all thirty-four of its sites, and `SAO.jar` is byte-identical to
the committed build. `[C63]` through `[C67]` reached it as they closed. `[C67]` is what
is owed now, and it is the one an existing save feels immediately:
survivors who already trust each other can keep company from the
next session, where before they never could.
The play receipts the C era owes are the next
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

**135 numbered borders**, run by **150 gated mirrors** in `tools/`, all invoked
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
