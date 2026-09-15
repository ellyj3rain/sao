| Document | Survivor Awareness Overhaul Session State |
|---|---|
| Version | `5.3.0.0-pre-alpha` |
| Author | ellyj3rain |
| Repository | `SESSION_STATE.md` |
| Status | CANONICAL - where the work actually stands. |

# Session state

**As of** 2026-09-15, `[C126]` close - learned trajectory and headless simulation for post-1993 starts.
The years pass no longer freezes at one 60-day slice: catch-up runs every frame until the span ends ([C112] cadence vs [C62] years clock). Headless LuaRun compiles against bundled Kahlua when the game jar is absent; `SAO_SWEEP_CACHE` is the Knox extract. 11 towns size the county at 198. Measured curve: 198 alive at day 1, 45 at day 30, 7 at day 90, 0 and 5 at two 1096-day seeds. The invented exponential $k=0.00205$ with an 8% floor is refused (Border 159). `SAO_Trajectory` interpolates those anchors. Fast extrapolation is opt-in. Default is first-principles years, which now complete (~27s headless for 1096 days). Corpus: `tools/sweep/trajectories.jsonl`. Version `5.3.0.0-pre-alpha`. Open pending the play receipt: nobody has started a late-year save in a live game.
Next: playtest of a 1996 start, and more seeds on the curve.

**As of** 2026-09-14, `[C125]` close - the neuroinflammation knot.

**As of** 2026-09-14, `[C125]` close - the neuroinflammation knot.
Brain health is represented as a single continuous scalar `rec.neuroinflammation`
bounded in `[0.0, 1.0]`, never an enum, stage, or discrete bucket. Multi-source
insults accumulate from active Knox infection via Antibodies' sine activation
curve (`math.sin(pos * math.pi) * 0.08`), peripheral wound sepsis (`0.015`),
drug/alcohol toxicity from the C121 ladder (`0.02 * min(1.0, poison / 50.0)`),
and severe late-stage withdrawal stress (`0.03`). Afflicted survivors maintain
a persistent `0.30` baseline floor representing permanent neurological scarring;
Crossed bodies sit at `0.90` (humanity burned out by runaway inflammation).
When insult sources clear and bodies rest, neuroinflammation clears exponentially
toward baseline (`math.exp(-0.04 * deltaHours)`). Cognitive clarity (`1.0 - load`)
feeds into `SAO.Conditions.memoryFactor`, causing memories and lessons to degrade
rapidly under severe inflammation. Clinical diagnosis in `SAO_Medical.lua` gates
observations across Doctor skill tiers (<2, 2..4, 5..7, 8+), and `SAOMedicalWindow`
renders an Antibodies-style visual curve progress bar. `SAO_Inspect.lua` displays
load, clarity, and motor stability. Advances occur daily in dormant attrition and
every ten minutes in active passes. The sandbox off-switch `SurvivorAwareness.Neuroinflammation`
disables the entire graph cleanly. Border 158 holds the kinetics, math, memory
integration, and UI controls. The version machine derives `5.3.0.0-pre-alpha` as a minor
capability: brain health operates as a continuous, unified graph across pathogen,
drug, and trauma insults. Open pending the play receipt: nobody has treated an
inflamed survivor or watched their memory degrade in a live save.
Next: playtest preparation with primitive simulation capability integrating with
the sibling Zomboid-Speakeasy repository.

**As of** 2026-09-14, `[C124]` close - combat perception compatibility.
Combat perception operates across the engine and mod ecosystem without
duplicating or fighting other systems. Acoustic sound events emitted
through `WorldSoundManager` use the weapon's own `soundRadius`, which
suppressors scale; the scanner scales reach by weather hearing, so
suppressed gunfire naturally reaches fewer county ears for free. Crawler
zombies, downed bodies (`isOnFloor`), and modded prone or crawling stances
now direct floor-level aiming (`setAimAtFloor`, `setAuthorizeShoveStomp`)
so melee attacks strike downward instead of missing high. Bodies in prone
or crawl stances present a reduced visual silhouette beyond near sense,
tagged as `+p` on persons and `:prone` on zombies. Stealth mods that
deactivate zombies via `isUseless()` are skipped by perception and
combat targeting, and existing targets set by motivation mods are
honored rather than stolen. Script weapon stats in melee scoring, vanilla
reload timed actions, and uninspected clothing ensure line-by-line
compatibility. Border 157 holds the acoustic attenuation, floor aiming,
silhouette reduction, useless zombie skipping, target preservation, and
mutation tests. The version machine derives the coordinate derived at that close as a minor
capability: combat perception and targeting cleanly co-exist with the
modded ecosystem. Open pending the play receipt: nobody has watched a
survivor target a crawling zombie at floor level or observe a suppressed
shot in a live save. Next: the neuroinflammation knot (`C125`, ZAO-led,
with its source sweep first).

**As of** 2026-09-14, `[C123]` close - the county's animals.
Build 42's `IsoAnimal` is an `IsoPlayer`. The scanner had therefore
treated every cow, hen, and horse as a person, and its generic foreign
person route could file an animal as a nameless stranger in a survivor's
beliefs. C123 stops animals before that person fallthrough in the one
shared foreign-person predicate and in the named-combat lookup. A live
animal is no longer a social target, but an actual off-slot person still
is.

Ranch care reads a designated ranch from the engine's own lists. The
adapter reads its animals, troughs, hutches, and each animal's present
hunger, thirst, stress, acceptance, product readiness, wildness, and
adult state. It does not create a ranch, animal, product, food, water,
or tool. A farm hand standing on their own claimed ground can select one
nearby, non-wild need on the existing farm cadence: ready milk, wool,
eggs already in a hutch, water for a trough with space, an animal-listed
hand feed, or a pet where stress or acceptance calls for it. The engine's
own timed action makes the final validity decision.

Horse riding remains the optional Horse Mod's machinery. C123 observes a
loaded adult mount only when the mod's `HorseRiding` animation flag and
`Mounts` association agree, and retains the engine `animalId` as the
mount fact. That suppresses competing foot decisions. The mod's normal
mount entry is local-player input, so C123 does not claim or attempt a
non-local shell mount, ownership, companionship, or a new horse system.
Border 155 holds the animal-not-person predicate, and Border 156 holds
the ranch care selection and action construction. The version machine
derives the coordinate for that close as a minor capability: the county's living
animals are distinguished from people and cared for lawfully by farm
hands. Open pending the play receipt: nobody has watched a survivor care
for a designated animal, retrieve its product, or drink from its tended
trough in a live save. Next: the totality order continues with
combat-perception compatibility (`[C124]`), then the neuroinflammation knot
(`C125`, ZAO-led, with its source sweep first).

**As of** 2026-09-14, `[C122]` close - vehicles, keys, and containers.
The vehicle port's key call was incomplete. The installed jar shows that
the no-argument `tryStartEngine()` supplies `false`; the boolean form
reads `true` as a held-key condition after the debug, easy-use, and
ignition paths. `haveThisKeyId` reads a loose key and recursively reads
a key-ring container, so the driver now carries that inventory answer
into the engine's start call. The appraisal carries the same fact to the
motor pool, which favours the keyed runner over a larger locked vehicle
while keeping the engine start as the final verdict. A person without a
key does not gain a start permission.

Vehicle parts now count as material ground when they have real item
containers and stand inside the ordinary scan radius. The larder, food,
drink, and dose-source reads, cook, and nearest-store reads now include
those containers, so camper and cargo trailer storage works even where a
vehicle has no engine part. The pass
does not enter scripted interiors, teleport a person, search a place for
a key, fabricate supplies, or read unloaded cells. Border 154 holds the
Java and Lua transfer, the radius and part guards, and a Kahlua-VM case
where a keyed two-seat runner outranks a larger locked runner; its held-
key-start, part-container, and food-source controls all flip the verdict. The version
machine derives the coordinate for that close as a minor capability: vehicles now
supply lawful starts and mobile storage to existing execution and needs.
The play receipt remains open: nobody has watched a survivor start a
vehicle from a held key or use a vehicle compartment in a live save.
Next: the totality order continues with animals (`[C123]`), combat-
perception compatibility (`[C124]`), then the neuroinflammation knot
(`C125`, ZAO-led, with its source sweep first).

**As of** 2026-09-14, `[C121]` close - the carry, the ladder, and the
smoke break. Drugs in totality, the batch the operator ruled real
smoking onto as an option and nothing more - so the smoke break is a
dial, on by default, moving nobody's habit. The
prior-art sweep was paid first and found C33's record wrong in the
way the record law names: N and C's Narcotics was held "source not
public" and "no code read", and the Workshop folder ships its Lua
uncompiled - [C121] read it, and the correction stands dated beside
the original in CREDITS.md, the original line left standing. THE
CARRY: where N and C's Narcotics is loaded, the county's own bodies
run their machinery - NEW `SAO_Drugs.lua` drives their own globals on
the county's shells, on their own clock shape (one pass per ten
in-game minutes, one per minute, exactly their OnTick cadence for the
player), and no body is driven twice because their driver finds only
the four player slots and the county's shells never appear in it
(their withdrawal fires only on their own trait, observed on the body
and stamped on the record). THE YIELD: the county's own habit
schedule yields family by family the moment their trait is observed,
so the two withdrawals never stack - SAO_Habits reads the stamp, and
a use stamped without the trait does not yield. METHADONE: their
level freezes the county's opioid clock through Habits' own
freeze/resume pair. THE LADDER: The Alcoholic's late withdrawal
carried at their own read figures - the sickness building through the
phases at their rate and caps, the poison past their line onto the
engine's own food-sickness stat with the running total the relief
reads, the death past their line with the cause marked FIRST (the
funnel's later marking no-ops; the body dies through their own call),
and the per-drink relief at their column - stress and unhappiness
halved then eased, fatigue halved, the poison worked out at half, a
tolerant drink holding less, the tolerance itself building at their
eight drinks a day. THE VERBS: a person in withdrawal who carries
their dose takes it, and one who does not seeks it where the county
believes a supply might be - never from a place somebody has claimed -
and a smoker not yet in withdrawal takes a smoke break now and then
at their own pace (the dial governs only the visible act; who smokes
is a fact about the person either way). The gate refused the batch's
first pass and every finding was fixed at its root: the dynamic
global lookup died on Kahlua - the engine registers no `_G` (read in
the jar), so an index by string would throw nil and kill the whole
pass silently inside the pcall - and the carry now names their
fifteen globals directly, checked as functions, never written, argued
in the globals census; the smoke dial was read live-only and moved to
the needs module that owns the body's acts; the tooltip copy was
ratified; and Border 13 was taught the loaded-neighbour vocabulary -
their `Drugs` display category is a word vanilla has no item for, so
the literal is verified against their own shipped scripts, named, and
faults if the mod is absent and the want unsatisfiable. The version
machine derives the coordinate for that close (minor - a new player-visible
simulation capability: the county's habits are lived in the body, not
just scheduled). Open, as ever, on the play receipts: nobody has
watched a county body take a benzo and calm, seek a bag from a
believed supply, smoke on a porch at their own pace, or drink
themselves past the poison line and live or die by it. Next: the
totality order continues - ground moves (`[C122]`), the county's
animals (`[C123]`), combat-perception compat (`[C124]`) - then the
neuroinflammation knot (ZAO-led, the prior-art sweep re-verifying
F-011 against the installed Antibodies), the crossed-doctrine
batches, the off-switch list before runtime verification.

**As of** 2026-09-14, `[C120]` close - a child at the wheel, a ball
in the street. The age attachments, the totality order's age half:
Growing Up's figures carried where a figure survives the
translation, rendered through the county's own machinery and never
their staged machines. The prior-art sweep was paid first and
found C31's not-carried list stale in four places - driving,
growth spurts, wound grief, voice lines all have county machinery
now - and still honestly blocked: their nightmares, Getting Old's
stumble, the cooking penalty, their adaptation milestones, their
four-stage grief machine with its doom spiral. The wheel: the
venture's own claim gate reads the census's age before the door
opens, so a child under their credited ten does not claim wheels
at all and the car stays where it sits, and a driver of ten to
seventeen takes the wheel with their credited thirty percent
penalty on the drive's speed cap (`CHILD_DRIVE_PENALTY` beside
`DRIVING_AGE` in `SAO_History`; the steering lag and brake scale
are not carried). The spurt: once a county day a child under
sixteen draws their credited eight percent and a spurt lands as
real engine hunger - their fifteen points on the 0..1 stat every
meal decision already reads - and says so once; the dormant half
feels nothing, no body no hunger. The wound: the age pass's
ten-minute cadence now scans a child's own body for bites and
scratches (a cut is any edge's and the scan cannot know whose) and
stamps the count on the record, and a hurt child carries the fear
- `WOUND_FEAR` on every decision that reads it - until the same
scan counts it healed and the voice says so; their stages, spiral
and delayed relief do not cross. The mouth: age outranks the
lesson where the table says so - eight line tables carry a child
register drawn from the census's own stage (FLEE, ALERT, ENGAGE,
TREAT, warned, turnedSeen, firstLesson, grief; Growing Up's lines
split by age band, credited, the words SAO's own), three flat
banks the spurt, wound and healing raise only at child sites, and
where childhood reads the same the table falls back to the lesson
register exactly as before. And the ball: Week One's orphaned
throw FBX crosses as the eighteenth credited file and rides the
ROAM arrival - a child who actually carries a ball, a playmate
actually within `PLAY_REACH`'s five named tiles (a throw travels
further than a counter's arm crowd; its two bare-five collisions
argued in ALLOWED - the manual hand-off and the kindness window),
the jock kit now handing a baseball out, paced at two county
hours, the catch and the return named as having no machinery. The
gate refused the batch's first pass once - Border 49 caught the
two bare fives against the new name, and both were argued in
ALLOWED rather than wired, neither a play reach - and Border 123
was taught the third speaker before the register landed: three
walks (grown innocent, grown taught, child) over every split
table with three-way disjointness held, the flat control shared,
every child register swept structurally so a child line cannot
copy a grown one under another name, and the child lines held
clear of the acquired vocabulary - an age is not knowledge. Border
63 gained the honest note that the wound term is runtime record
state the stub county cannot carry, so the sampled 4.2..11.8 range
describes the sample it can reach. The gate ran clean with the
batch in the tree, the jar rebuilt and shipped after the stamp;
the version machine derives the coordinate for that close (minor - a new
player-visible simulation capability: the county's children live
their age at the wheel, in hunger, in hurt, in mouth and in the
street). Open, as ever, on the play receipts: nobody has watched a
child leave a car where it sits, a teen drive at seventy percent
of the cap, a spurt voiced, a hurt child frightened until the
scan counts it healed, a child's own words at a grown moment, or a
ball thrown to somebody on a stretch of street. Next: the totality
order continues - drugs in totality (`[C121]`) - then the
crossed-doctrine batches, the common-enemy weight, the off-switch
list before runtime verification.

**As of** 2026-09-14, `[C119]` close - Week One's moments and the
government's answer. Two halves under one law, both the totality
ruling's: the moments the county already occasions, dressed in the
credited art's shapes, and the nuke re-expressed as a per-world fate
behind a dial, per the spectrum ruling (optional, randomized, never
the default). Seventeen more of the animator's files crossed
(SaneGuy and Slayer, credited): the cashier, three protest stands,
three CPR stages, four dances, six instrument plays - every node
SAO's own, keyed on `SAOGesture`, and the manifest now holding the
clip name inside each file (the waiter's `waiterAnim` case
generalized, 95 files and 72 nodes). The moments: the counter at the
ROAM arrival seam (a street leg at the filed trade ground with
somebody within `COUNTER_REACH` - the counter's own named four tiles,
argued against the teaching stand-off and the porch band in ALLOWED -
paced at two county hours, the customer whoever the county actually
put there); the protest when BOTH members of a dissenting pair hold
the shape (`[A25]`'s grumble grown a body, the voice still saying
the grievance); the CPR at a medic's aid when the hurt body is down
or nearly dead (three queued actions - start, long loop, letting-go -
and the bandage still real); and the bard's own clip following the
carried instrument (the county already picks up whatever
InstrumentWeapon the world holds, so a bard with a flute plays the
flute, not the guitar's shape; the four dances join the porch crowd
through the pick every dance already uses). The nuke, NEW
`SAO_Nuke.lua`: a dial `SurvivorAwareness.WeekOneNuke`, default OFF;
when on, the first county day after the fall draws the fate once -
delay 5 to 21 days, 1 to 4 circles, towns drawn without replacement
from the ten credited coordinates, radii 500 to 1000 - off the
engine's own dice and persisted in ModData (one fate per save, a new
county a novel apocalypse), the countdown on the fall's own calendar
(an overdue strike in a begun-fallen world fires the first county day
- the player walks into a struck county), and after the strike only
engine truth: their credited fire (`SetOnFire` on every body in the
circles), `BurnWalls` as squares stream in (the burnt set kept per
square), the two credited kabooms near and far, and the sickness on
the engine's own food-sickness stat rising where the circles hold,
once a county day on the `dailyCounty` hook, so the years pass
drives a struck county exactly as the live one does. No script
anywhere: no winter, no hazmat, no hydro, no screen flash, no
vehicles burned, no dream quest, no siren, no staggered booms, and
the dormant half feels no fire or fallout (the dormant-risk dial is
theirs). The gate refused the batch's first pass five times and each
finding was fixed at its root: the two typed customer reaches became
`COUNTER_REACH` (Border 47) and their collisions argued (Border 49),
the dial's owner declared to the option-reach border, the tooltip
reflowed to the layout and its copy ratified, and the gestures
border taught the manifest's `anim` key and the carried-instrument
seam. The gate ran clean with the batch in the tree, the jar
rebuilt and shipped after the stamp; the version machine derives
the coordinate for that close (minor - a new player-visible simulation
capability: the county's trades, politics and medicine wear bodies,
and a world can ask for the government's answer). Open, as ever, on
the play receipts: nobody has watched a cashier with a customer, two
dissenters standing together, a medic kneeling over a body that is
down, a flute that looks like a flute, or - for the one world that
asks - the government's answer arriving on the day the draw said.
Next: the totality order continues - age attachments (`[C120]`),
drugs in totality (`[C121]`) - then the crossed-doctrine batches,
the common-enemy weight, the off-switch list before runtime
verification.

**As of** 2026-09-14, `[C118]` close - the demand, the break-in, and
the haul. The raider vocabulary, the ten swept gaps of the totality
ruling, built as per-person decision machinery under the emergence
rule: no raider class, no raid timeline, no badge, no authored
outcome. The forcing bar is real now - `D.wouldForceEntry` was the
honest hard-false it shipped as; it is character against situation,
aggression fighting discipline with initiative half-weighted, and
the walk's own pressing carried in by the caller (half a person's
worth for a destination claimed by a standing enemy, half again for
hunger past the county's desperation line; fleeing always licensed,
zero authored constants) - so the composed still decline every lock
and the pressed or the aggressive take it on. The breach is plumbed:
a barrier verdict ends the route, not the want - the seam reads the
destination from the locomotion job's own goal, the declined window
re-licenses and smashes by the machinery the FLEE state already
owns, and the locked or barricaded door and the barricaded window
answer the new bridge verb `batterBarrier` (NEW `SAOMovement.batter`
- one engine hit per verdict-hit-re-order cycle, the engine's own
`WeaponHit` with the held weapon, the edge toward the goal asked
first, at the price the player pays: planks, door health, and the
thump drawing whatever hears it; bounded at forty swings a walk,
and an empty hand stops honestly - fists do not batter). The word
before the blow: at the confrontation seam an armed character with a
grudge at talking distance whose own `D.wouldDemand` says so speaks
the demand - Voice "demand", once per pair per county day, no combat
that tick, and the window is the other side's machinery to answer;
before the flee seam the frightened answer out of their own
`D.wouldYieldTo` (one whole person's worth of fright) - spare food
only, the second-best, through the same vanilla transfer every
kindness uses with none of the kindness, once a day, trust bent
-0.05, and each side reads only its own beliefs so a demand may meet
no hand and a hand may rise with no word. And the feud's answer
carries home: a warpath walk (`[A27]`'s one leg in six) that arrives
on ground answering hostile takes the enemy's stores through the
forager's own `takeWantedFromNearby`, the same cap a skilled sweep
tops out at. Honest limits recorded: no sabotage verb (the batter's
plank-fall is its honest seed), entry only and never claim-flipping,
the unarmed cannot batter, the yield hands over spare food only,
forty swings is the one authored number in the breach. The gate ran
clean with the batch in the tree, the jar rebuilt and shipped; the
version machine derives the coordinate for that close (minor - a new
player-visible simulation capability: the county raids itself). Open,
as ever, on the play receipts: nobody has watched a batter heard
across a street, a robbery survived by handing it over, or a warpath
walk come home heavier than it left. Next: the totality order
continues - Week One's moments and gestures, age attachments, drugs
in totality - then the off-switch list before runtime verification.

**As of** 2026-09-13, `[C117]` close - the afflicted among the living.
The social half of the afflicted arc, the batch `[C116]` named as
standing's own: the return brought them back, and this is the county's
answer to them. Three laws, all through machinery that already exists
- no badge decides anything, and nobody is exiled, refused, or moved
by category. The belief reader `P.believedFormOf(id, otherKey, tick)`
is the one query every standing-side question asks: the form read off
a person-belief keyed the way beliefs are keyed, fresh on the people
horizon, so an argument quiets by itself when the marks stop being
seen - a member who has not seen the shaped face does not argue, and
there is no argument without fear in the room. The house argument
runs in `electLeader` beside the creed quarrel `[B23]` built: each
housemate holding a fresh belief of the form answers out of character
(`[B3]`'s law for the bitten at the deeper bend) - weight
`(1 - nerve) + fear - compassion`, above zero and they are afraid,
else they stand by - trust bends on the sibling quarrel's magnitudes
and cadence (afraid -0.03 toward the subject, the subject -0.02 back
at every afraid face, afraid and standing faces -0.02 at each
other), the blows cross each side's OWN `hostilityBar` per person,
and everything after the blows is the split machinery's business:
no exile verb exists by design, `checkSchism` decides, and its
schism of one IS the exile - the cast-out is whoever the roster
trusts less, no preferred victim. The company door reads the same
law everywhere at once, because `[C111]` made the value the one law:
`companyStanding` discounts by the judge's own fear (weight scaled
0.6, only when positive), so the composed can still take a shaped
stranger in and the most frightened cannot be carried past the line
even by the deepest need - the road, the table, the visit gate, the
companion walk, and the player's own asks all read the same value,
and an afflicted judge at an afflicted door discounts by their own
fear the same as anyone; no solidarity is encoded. And once a county
day, on the clock the return and the marks run, `S.outcastDrift`
asks the cast-out's question for every groupless person whose own
state says afflicted: their own known places ranked by the
`[C76]`/`[C108]` scorer, minus every place a living hand holds and
what they already hold, and the best remaining place becomes their
home through the same claim verb genesis uses, the log saying why -
measure, then guide, the settle pass's law applied to one person,
and a cast-out who never went back anywhere keeps the ground they
stand on. The gather needs nothing new: outcasts crossing paths at
the same abandoned ground go through the ordinary doors, and what
gathers, gathers. Work and claims are answered by the machinery
that owns them - the split clears the designation, `[B21]` judges
the state of the work never the attribution, and `mayEnter` still
refuses a break-in without hostility, whoever holds the ground. The
gate ran clean with the batch in the tree, the jar rebuilt and
shipped with the new stamp; the version machine derives
the coordinate for that close (minor - a new player-visible simulation
capability: the county's society answers its mid-course people).
Open, as ever, on the play receipts: nobody has watched a house
argue over a returned member, a door refuse one, or an outcast take
abandoned ground. Next: the totality order the same sitting set -
the raider vocabulary (the ten swept gaps), Week One's moments and
gestures, age attachments, drugs in totality - then the off-switch
list before runtime verification.

**As of** 2026-09-13, `[C116]` close - the afflicted come back. The
operator's totality ruling of the same sitting names the afflicted as
important as the crossed, and this batch carries them, closing on the
way both seam halves the sister's `[A32]` recorded as owed by this
side. The return is a fact-reading, not a decision: once per county
day, `SAO_AfflictedReturn.adopt` mints a live body where a reverted
person's risen corpse stands (or at their last ground), through the
same `materialize` every awakening uses - the mint runs FIRST and the
flags turn only on success, so a refused mint leaves a death record a
death record and the next county day tries again. `rec.dead` flips -
not an undoing of the death (`diedAtHours` and `deathCause` stay
durable) but the county's present-tense judgment the reversion
overturned - and everything the death funnel dropped stays dropped:
they come back with no beliefs, no voice, no company, a stranger to
their own house, which is what coming back from that is, and the
material the next batch's social half argues over. The presentation
chain's one missing link closes with two stamp paths - the adoption
mints the returnee with the pathogen's own form marks, and
`Return.stampLive` re-stamps every live afflicted body once a
county day (covering the recovery-flipped infected who never died),
so the scanner's marks and the belief parser's form read make the
ghoul shape visible on the living. A formed neighbor enters the
county's fear - `nearestFormedPerson` behind the hostile override,
`isZombieThreat` excluding `fromPerson` so they are feared and never
fought - the pathogen pressure reads `nearestBelievedThreat` at full
weight, the parser observes the form through Adaptation, the live
afflicted near a crossed carrier are exposed through the sister's own
`expose` (odds never copied), and the reunion machinery already
standing fires for the returned everywhere they go. The seam halves:
`Drv.order` stamps the demonstrated `drive` verb (ending
`ZAO_Mind`'s always-empty retained-verbs), and `SAOBridge`'s
`driveBegin`/`tickDrive` dispatch IsoZombies first over a
`crossedDrives` map of their own - `SAOCrossedDriver`, the driving
map's second entry, walks the dead's own pathing (`pathToLocationF`,
one leg per scan; SAOMovement is player-surface and was NOT
widenable, by design law), boards seat 0 through the character-typed
engine surface `[C82]`/`[C114]` verified (javap before a line was
written), starts the engine lawfully, drives the bearing to the
named ground capped at the drive dial's default, parks and shuts off
- no WAIT phase, the crossed wait for nobody, and a thrown tick is
answered `DRIVE_FAILED` because the sister's verdict machine ends a
trip only on Succeeded, IDLE, or a `DRIVE_` verdict. The risen corpse
is the sister's half, named `[A33]` in both repos (ZAO owns the
turned body and releases it once this side has re-adopted); until it
lands, corpse and returnee share a county, honestly. The gate ran
clean with the batch in the tree, all 63 Lua files compiling under
the engine's own Kahlua, the jar rebuilt and shipped first; the
version machine derives the coordinate for that close (minor - a new
player-visible capability: the county's mid-course people return to
it, and the crossed can drive). Open, as ever, on the play receipts:
nobody has watched the dead come back or a crossed body under
wheels. Next: the afflicted among the living - the house argument,
the cast-out and the gather, the standing reaction - then the
totality order the same sitting set.

**As of** 2026-09-13, `[C115]` close - the dials the rulings named.
The operator's screen-revision ruling of the same sitting (the
sister project's record 45): the sandbox screen carried "an absence
of everything I said should be configurable over this past three
days" - the numbers the operator ruled over the 09-11/13 era sat in
code as constants while the screen showed other things. Three dials
now carry them, each default the ruled figure so nothing about the
county changes: RoadMeetingWorth (the 0.02 the operator moved
personally at `[C111]`, read per meeting), OpennessHorizonMonths
(the half year `[C111]` stated "so the operator can move it," read
per pull-hour recompute), and DriveSpeedCap (`[C114]`'s credited
30 km/h, crossing the bridge at order time because Java cannot read
SandboxVars - Lua reads the dial, `driveBegin` gains the parameter,
the per-shell drive state carries it, and `SPEED_CAP_KMH` stands
renamed `DEFAULT_SPEED_CAP_KMH` with its credit intact). Named as
deliberately NOT dials, in the record and the options header: the
county clock (`[C112]`), the street hour (prior art carried whole),
era and calendar facts (the record's stamps, never the dial), and
per-person temperament (emergent from identity by design). Three
borders were amended to the new truth rather than the code bent
back: Border 29 claims the two module-owned dials and graduates
ROAD_TRUST out of its magic-number table; Border 152 reads the dial
seams; Border 92 declares the six new strings under the ruling, the
wording following the ratified plain register. The gate ran clean
with the batch in the tree, 31 options on the surface; the jar was
rebuilt and shipped before it ran; the version machine derives
the coordinate for that close (kohai - the screen matured to carry what the
rulings reserved, nothing new simulated). This batch is the first
named step of the pre-alpha-to-alpha order the same sitting set:
this revision, then readiness, then the training passes - the dials
exist so the tuning has something to turn. Open, as ever, on the
play receipts: nobody has watched a goer drive at a non-default cap.

**As of** 2026-09-13, `[C114]` close - a real person at the wheel.
The driving half of the Week One port (`[C110]`) is built, and the
doorway `[C82]` mapped is exercised at last: a live goer who took
wheels on a venture walks to the claimed car, enters seat 0, starts
the engine lawfully (the no-argument `tryStartEngine` - a refusal is
honored, never routed around), and drives it to the venture's ground
by the bearing, capped at Week One's own credited 30 km/h town
figure, `[C31]`'s order-time fuel burn becoming real fuel spent on a
real trip. Every load-bearing engine fact was disassembled from the
installed B42.20 jar before a line was written - the ungated
control reads, the steering sign (Left -1, Right +1), the
physics-activity rules that would dead-lock a resting NPC-driven
car, answered with the engine's own public `setPhysicsActive` at
board and at ignition. The promised company rides (`[B19]`'s seat
cap made real): escorts board passenger seats, the driver holds at
the wheel for them, latecomers' rides fail honestly and they walk.
A drive is committed - the seat law on the books since `[B1]` holds
the decisions off while the body is at the wheel, and `setState`'s
new exit rule parks the car on any transition out. Every refusal
falls back to the ordinary walk, and on arrival the last stretch is
walked so the venture's close-out runs unchanged. The drive is era
general by design: `[B19]`'s claims, `[C31]`'s burn and `[C82]`'s
doorway were never era-gated; pre-fall is where the Day Zero receipt
watches it. The ghost driver, the forced-engine trio, the
never-steering regulator and the horn are named as
deliberately-not-taken in the code and in CREDITS. Until the end
pass rebuilds the jar, the Lua degrades to the ordinary walk -
the new bridge verbs need it, deferred there by the standing order.
Open pending the play receipt: a goer under wheels, watched. With
this close, all three build rulings of `[C110]` are built - need
alongside trust (`[C111]`), every timer on the county's clock
(`[C112]`), and the pre-fall streets and driving (`[C113]`,
`[C114]`). Next: the nine world documents with the operator (the
review `[C110]` named as waiting, which gates the sister's corpus,
voice, and training), then the end pass.

**As of** 2026-09-13, `[C113]` close - the street hour and the trade's
ground. The Day Zero arc's last unbuilt named slice, normal life on
open streets, is built, as the streets half of the Week One port the
operator ruled at `[C110]`. Slayer's authored street-hour curve
(twenty-four values, read from the installed mod and carried whole,
credited) is re-expressed from a spawner's count into a per-person
propensity - `SAO.History.streetAffinity` - rolled at the leg
boundary on both halves of the county: out means the day-goal chooser
answers, staying in means home, and the authored curve itself thins
the small hours and feeds the evening streets. The street-occupations
idea crosses as the census trade's own ground: a stable workplace
(`rec.workX`, one fact both halves share) walked to behind need and
ahead of company, so the mail carrier and the gardener of the prior
art are SAO's own people in SAO's own trades. All of it gated by
`fallHasCome`'s reason being "before" - an unreadable calendar gets
the survival law, not a street crowd - and all of it dead the moment
the county's own stamps say the fall has come, the thinning left to
the county's machinery rather than any timeline. The weights, the
spawner, the scripted timeline, and the density math never cross,
named as such in CREDITS. What does not cross is credited as
deliberately-not-taken; the driving half of the port is `[C114]`, the
next batch. Open pending its play receipt - an ordinary county
watched at eight in the morning and three at night.

**As of** 2026-09-12, `[C112]` close - the tick is the county's clock.
The queue's item 4 is paid, as the operator ruled - every timer moves,
with the preference stated for a robust system over a quick one: one
law in `SAO_History.ticks` - a tick is a 9000th of a county hour, the
derivation being what a frame was at 60fps on the default day - so
every span constant keeps its number while the domain becomes the
county's clock. No sixty site conversions: Controller's and
Population's counters both READ the one clock (which also ends the two
frame clocks stamping the belief axis with diverging numbers), the two
modulo cadences became last-fired-plus-a-span stamps (a skipping clock
steps over a modulo), the years' calibrated 3600-a-day fake advance is
deleted in favor of the clock's own day, and [C15]'s reload rebase is
replaced by a foreign-stamp domain check because the tick axis crosses
sessions now - ahead-of-now is a domain mark, and dropping it to 0
reads as long ago (same guard on `rec.nextDormantMoveAt`, the one
persisted future due-time). Voice keeps [B49]'s wall clock: the
player's ears are in real time. One reload's relearn per old save, by
design. The feel on the county's clock is a play receipt. Next: the
pre-fall streets and NPC driving (the Week One port), then the world
documents with the operator, then the end pass.

**As of** 2026-09-12, `[C111]` close - need stands alongside trust.
The queue's item 3 is paid: a road meeting is worth 0.02 (twenty-five
meetings to the default line, not two hundred), and need is a
co-determinant of company through one law in Standing -
`companyStanding(id, other)`, the trust one person holds toward
another plus their own pull (appetite from `contactFactor`, isolation
from `[C94]`'s state surface - which gated nothing until now - and the
county's openness: months since the fall on the split clock over a
horizon of six, so an ordinary county forms houses through acquaintance
and a county deep in collapse lets need carry the line). Need
substitutes for trust not yet built and never cancels trust already
spent against somebody. Every company door reads it - the road, the
table, the visit gate, the companion seam, and the player's asks
(walk, join, designation) - while judgment, office, and defection
doors keep trust alone, and temperament (circles, capacity, hostility,
mercy) gates exactly where it did. A house can now grow past a pair
out of meetings and the lonely can found one; the play receipt and a
border for the law belong to the end pass. Next: the timers onto the
county's clock, then the pre-fall streets.

**As of** 2026-09-12, `[C110]` close - the rulings land. The operator
took the end-of-feature-work ask and ruled the same day: the 78
trades-hinge rows are ratified and the cross-module contract is
ratified (the sister's records 41 and 42 - 190 ratified rows in all);
and on this tree's side, three builds open. Group formation reads
need alongside trust, weighted by the world's own age at the start
(DR-038) - a meeting is worth more, and most people need to be around
people, so trust is not the sole determinant of whether a group forms.
Every timer moves onto the county's clock, as one robust system, not
scattered arithmetic. And the pre-fall county gets its streets:
Week One's CODE is taken and ported under SAO's ontology, the same
multi-mod port plan as the people mods before it ([C29] through
[C33]) - the hour-of-day street curve, the street occupations, the
NPC-driven vehicles, the thinning past the outbreak day, on SAO's own
people through the four pillars, gated by `fallHasCome`, credited per
author, never programmed zombies on a scripted timeline. This batch
moved the pointers only (the roadmap's sister-note now states both
ratifications); the three builds are their own batches, and the
world-document review is taken up next on the dataset's side.

**As of** 2026-09-12, `[C109]` close - beside this tree, corrected.
Records only, no code: the roadmap's closing note still said the
sister's G0 was open because Antibodies was not installed, false since
its `[A6]` (2026-09-09) found it installed, read what it exposes, and
closed the gate - and false again in the other direction since its
`[A29]` moved recovery reads to this side's own record, so the named
read `[A6]` left open never shipped. The note now says what closed and
where. The Speakeasy half carried forward too: the cross-module
contract is active, the rows are cut against the event-driven pathogen
state (its records 38 and 39), and the seventy-eight trades-hinge rows
wait on the ruling. With this, every planned feature the tree can
build without an operator design call is built: what remains is the
operator's own calls (recruitment's cognition question, frame-time
pacing, the trades-hinge ruling, the world-document review, the shape
of normal life on open streets before the fall) and the end pass.

**As of** 2026-09-12, `[C108]` close - the place ontology. DR-006 S4,
the operator's named error, is paid: a group's ground is no longer
one rectangle under one name. `[C76]`'s scorer became a ranking
(`Perception.returnsOf`) - the same visits, the same water doubling,
recency breaking ties - recomputed from use and never stored, so
nothing accumulates and nothing expires; a place stops being the
group's when its people stop going, the same fact that made it
theirs. `Standing.placesOf`/`onGroundOf` answer where a group HOLDS
(cached against a belief version and the member roster, so a
derivation is never served stale), while `groupClaimOf` keeps
answering where a group IS - the twenty-nine seat-reading sites did
not move. The readers where holding several changes the answer now
read the set: no house settles over another's stash while honouring
their base, a feud's shadow falls around every place the enemy
holds, and a pact delivery is kept standing on any of the ally's
ground. The settling pass reads the top of the ranking itself, so
the seat and the set are one law. Queue item 2 of the roadmap's
remaining work is paid; what is left of the queue is the operator's
own design calls (recruitment's cognition question, frame-time
pacing) and the end pass.

**As of** 2026-09-12, `[C107]` close - what a settled house does with
its ground. `[C76]` settled the dormant house, but the hearth, the
larder and the water store stayed the controller's, because the live
round reads real shelves through a body and a dormant house has none -
so every consumer of those words (flight, the lean-house ladder, the
forager need-pull, the abandon council, the bread ask and the charity
that answers it) was inert in the half of the county nearly every
house lives in. `dormantProvision` now derives the words from facts
that already existed: the members' real reachings (`lastFoodDay`/
`lastWaterDay`, the same stamps attrition trusts) against the
county's own patience constants, and the seat's own `offersNow`
ledger - lean when nobody reached food inside food patience, full
when everybody did AND the seat still offers, the hearth honestly
dark because no member has a body. No counts are faked: the claims are
word-only, `[C105]`'s "actually counted" stays the live round's, and a
house really living on its ground enters the settlement graph by
explicit derivation. A lean house calls for bread like a live one; a
house with any materialised member is left to the live round. Queue
item 1 of the roadmap's remaining work is paid whole.

**As of** 2026-09-12, `[C106]` close - the player verbs of the house.
ORGANIZATION.md's player-surface contract named thirteen verbs and
the menu carried two of them; the rest are wired now through
`SAO.PlayerInteraction.claim`, under the `[C105]` law unchanged -
every player action is a claim, the house may ignore it, the claim
decides nothing by itself, and the trust gate is the house's own
ear, not a new threshold. Petition (peace, ground, form), ask for
work, take or refuse the dealt work, support or contest a lead,
back the chair's word over a refused order, appeal over the chair,
claim the chair, leave, call a vote where the form allows one, and
stand against the pact - all recorded, all gated on the
PlayerInteraction dial whole. A settled election now records the
leader's lead claim with the roster as recognizers, and petition
acceptance joins the player into the organization's membership.
The office never moves through its claimant's assertion; the
boundary holds.

**As of** 2026-09-12, `[C105]` close - the recognition bridge. The
graph's write side, which had zero callers since the `[C104]` era, now
runs through `SAO_Recognition.lua`: a recording bridge driven only by
real county events - settled elections, chair offers taken or
declined, join petitions answered, order verdicts from the chair, real
provisioning on claimed ground, pacts, schisms, promises, tells, and
real items shelved - so organizations, offices, settlements, stores,
and player claims come to exist in a running game without any pass
authoring them. Three read-side violations fell with it:
`PlayerInteraction.response()` no longer writes on read,
`recognizedBy()` counts only other-recognizers, and support no longer
self-recognizes.

**As of** 2026-09-12, the dormant county carries the branching graph.
`SAO_WorldGenesis.lua` observes the same graph over unloaded records that the
live controller runs over bodies. It records what the county’s own systems
already produced - including standing group, leader, and claim - and it does
not create an organization, an office, a settlement, or a success state.

**As of** 2026-09-12, the pathogen seam is event-driven. SAO emits infection,
death, and turn events, and mutation knowledge comes only from proximity or
testimony during the elapsed-years pass or live Perception.

**As of** 2026-09-11, `[C104]` close - Perception carries the form.
SAO's scanner reads ZAO's form and performance from a turned body's modData,
stores them in the survivor's belief set, and the controller widens the flee
distance by up to half again as form performance rises.

**Before that**, `[C103]` - the form overlay. ZAO's `[A22]` adds world-space
form labels and the corrected gate that only infected, dead, or turned bodies
carry a form.

**Before that**, `[C102]` - the form registry and the pathogen roll. ZAO's
`[A20]` adds six source-port forms, a 10 percent default roll, and normalized
performance.

**Before that**, `[C101]` - the state surface. ZAO's `[A19]` adds
`ZAO_State.lua`, the runtime state surface, and a matching state producer.

**Before that**, `[C100]` - the ZAO state producer. ZAO's `[A18]` adds
`tools/state_dump.py`, which emits one pathogen-state row per SAO decision
moment, keyed by person id and decision hour.

**Before that**, `[C99]` - the first cross-module rows. Speakeasy record 33
adds the first cross-module rows to `decisions/cross-module/`. The ZAO state
in these rows is derived from the pathogen facts SAO already records, and the
mutation-specific fields stay null until ZAO supplies them.

**Before that**, `[C98]` - the cross-module row exporter. Speakeasy record 32
adds `tools/cross_module_rows.py`, which takes an SAO decision dump and a ZAO
state dump keyed by the same person id, adds the `pathogen` block to the
person half, adds the `visibleForms` block to the situation half, and writes
one cross-module row per line.

**Before that**, `[C97]` - the pathogen's forms enter the branching graph.
ZAO's `[A17]` settled the six integration rulings, and `PROJECTS.md` now
names the seam: the pathogen owns the mutation roll, crossed is terminal,
retained form traits are state rather than new branches, forms and attribute
mutations stack, and forms enter Perception as visible facts. Speakeasy's
record 31 proposes the cross-module row contract that follows from the same
rulings.

**Before that**, `[C96]` - world development becomes a live state.
The third category from the dependency substrate is built.
`SAO_WorldDevelopment.lua` reads identity, place attachment and standing;
reports home, ground, larder, water, hearth, motor pool, fortification and a
coarse development summary; and writes nothing. The seven underlying facts
remain visible beside the summary. `SAO_Inspect.lua` shows the state and
writes it to the JSONL stream. Border 151 drives the shipped module in the
engine's own VM against stub identity, place-attachment and standing facts,
and holds a rootless person, a homed person, a stocked person, a developed
person and a dead person. Mod state, instrument and border, so kohai.

**Before that**, `[C95]` - place attachment becomes a live state.
The second category from the dependency substrate is built.
`SAO_PlaceAttachment.lua` reads identity, perception, places and standing;
reports home, the current building, known and visited places, personal and
group claims, the most-returned-to place and a coarse attachment summary; and
writes nothing. The four underlying facts - home, ground, visited places and
known places - remain visible beside the summary. `SAO_Inspect.lua` shows the
state and writes it to the JSONL stream. Border 150 drives the shipped module
in the engine's own VM against stub identity, perception, place and standing
facts, and holds a rootless person, a homed person, a grounded person, a
settled person and a dead person. Mod state, instrument and border, so kohai.

**Before that**, `[C94]` - isolation becomes a live state. The
first category from the dependency substrate is built. `SAO_Isolation.lua`
reads identity, perception, standing, disposition and history; reports
appetite, group size, known people, trusted people, recent people, hours
since contact, contact and isolation; and writes nothing. Appetite and
isolation are separate facts, so a loner alone and a house person alone are
not the same reading. `SAO_Inspect.lua` shows the state and writes it to the
JSONL stream. Border 149 drives the shipped module in the engine's own VM
against stub identity, perception, standing, disposition and history facts, and
holds a solitary person, a grouped person, a saturated social person, a dead
person and the separation of appetite from isolation. Mod state, instrument
and border, so kohai.

**Before that**, `[C93]` - the dependency substrate. The operator
directed the next step: ground the work in the underlying dependency substrate
before building the category areas. `SUBSTRATE.md` is the canonical map now. It
records the current runtime substrate, the current non-runtime substrate, the
planned substrate, what makes each area of concern possible, the
cross-repository seams, and the external mod posture. Documents only, no mod
code, so patch.

**Before that**, `[C92]` - the branching system. The operator
corrected the scope: the branching shape applies to the entire simulation, not
to labor alone. `BRANCHING.md` is the canonical contract now. The whole county
is one branching graph of state, pressure, and action; a branch is a causal path
from pressure to consequence; every branch carries spectrums rather than
binaries; a repeated branch can become a pattern, a role can gain jurisdiction
and become an office, and organization authorizes or contests branches without
creating ability; and the player perturbs the graph through free-form
conversation. Documents only, no mod code, so patch.

**Before that**, `[C91]` - claims and recognition. The operator
corrected the organization contract: some social facts are not self-declared. A
person may claim an office, membership, a resource, a role, or a bond; the
claim is separate from recognition, and the model now records the claim, the
recognizers, and the response. Coercion can make a claim effective without
making it legitimate. The governance names are analytical, not speech lines;
no character says `I am despotic` or `I am localist`. Documents only, no mod
code, so patch.

**Before that**, `[C90]` - organization and deference. The operator
named the next missing model: hierarchy, governance form, offices, and
deference. Democratic, despotic, and localist were examples, not implementation
targets. `ORGANIZATION.md` is the canonical contract now. It defines an
organization as a durable group with members, a decision method, and a
boundary; an office as a decision right with jurisdiction; governance as
unsettled, democratic, despotic, localist, federated, or communal; legitimacy as
consent, competence, custom, election, inheritance, coercion, resource control,
emergency, or tradition; and deference as a decision about one matter, with
refusal, appeal, contest, exit, and resistance as real outcomes. Documents only,
no mod code, so patch.

**Before that**, `[C89]` - what the county represents. The
operator set the representation target after the trades-hinge proposal
landed: the game represents a living county under survival pressure; work
comes from pressure, person, relationship, and material state; organization
appears after a repeated pattern exists; and a survivor may know of nobody
and want nobody nearby. `REPRESENTATION.md` is the canonical contract now.
It names what each existing state surface carries, what it may cause, and
what it may never cause. It names `designation` as the one overconcentrated
surface: a work word should describe repeated work after it happens, while
today the same string also causes controller behavior, study choices,
rationing, and command standing. The contract also states the labor target:
labor is broader than a fixed job list, and ease is a valid state because
rebuilding requires surplus, choice, and work that is not immediately forced
by survival. The gate also gained one repair: the
undeclared-local border now uses the same interpreter variable as the rest of
the gate. Documents and a gate repair, no mod code, so patch.

**Before that**, `[C88]` - what decided a moment. The
next dataset proposal takes a new target the trades open up, and
this is its instrument. The survey measured the dormant
trades-hinge surface rather than assuming it: exactly two moments
inside the election the dump already wraps - the deal yielding to
a member's own best hand when their pay for another job beats the
dealt pay by three or more, and an unmet house need pulling the
best-suited hand into the gap - and the `[C86]` harvest counted
four redirects in six engine counties, all cook pay 4 against a
dealt forager pay 0, and eight need-pull promotions, all zero-pay,
with no Foraging pay anywhere in the whole harvest: no profession
in the catalog boosts it, so the forager pull is the class the
county's own rule points at, never a trade's decision. The row now
carries the house's need state as the election opened - the
shelves' and water's words, whether the hearth burns, who the house
feuds with - read through the same verbs the need-pull reads,
once, at entry, with a house holding nothing reading as absence
rather than a dressed-up zero; a full engine county reproduces
`[C86]`'s County000 exactly, so the capture consumed no draw.
Border 148 forces both moments through the tree's own instrument -
the forcing wrapped around the county's tick so a forced election
lands as a real captured row - and its control is the `[C87]`
tree failing five things, among them that its rows cannot see the
lean shelves the border set. The 120-county harvest with the
capture in place is running; the next batch authors the dataset
proposal from it, and the `--engine` flag still moves to the
default only after the operator has read those rows. Tools and a
border only, no mod code, so patch.

**Before that**, `[C87]` - what a belief carries. The
operator ruled on the gaps `[C86]` came back with, same day:
distances kept - the meeting caller computed the distance between
two people and threw it away, so a first meeting read distance zero
and a re-meeting carried the first one forever - and name keys
translated at the display layer, a row reading `Elliot Segura` with
the engine's own key staying beside it. Both are built: the
distance travels the seam both ways, a caller that knows no
distance keeps the carried-then-zero seed, and the plain reading is
measured against the engine's own English table entry for entry -
6008 of 6008. The dead are ruled to the sister seam, decided with
the ZAO trilateral work rather than unilaterally here, and the next
dataset proposal takes a new target the trades open up - rows where
the person's trade is the situation's hinge - which is the next
batch's instrument, not this one's. Border 147 holds both rulings
in the gate; its control is the `[C86]` tree failing thirteen
things. The first mod change in five batches, one seam, the seed
doctrine unchanged, so kohai.

**Before that**, `[C86]` - the engine's own names and
trades, by mode. The operator ruled richer evidence first - make the
evidence the rows are authored from richer before multiplying the
rows - and deepen the harness to get it; of the four things that made
the dump's rows thinner than the people in them, two were the
harness's and now answer from the engine's own data. `--engine` on
the dump and the sweep exposes the real shipped bridge and loads the
game's own name pools and profession definitions, so a county run
this way names its people out of the engine's own pools and reads
their trades' pay through the engine's own definitions - and is a
different county from the same save run plain, because a name costs
two county draws and the catalog grew, which is why the mode is a
flag: the ratified 112 rows cite the preserved plain dump. A run that
would name nobody refuses instead. Border 146 holds it in the gate,
its control the `[C85]` tree failing six things; the two mod-side
gaps - the dead a person has seen, the distances their beliefs
carry - come back named as proposals, not built. A full one-county
validation measured 305 moments and 768 member-rows with real names,
real skills and name-keyed beliefs, zero capture failures. Instrument
and border, no mod code, so patch.

**Before that**, `[C85]` - the sister's rows are
ratified. The operator read the 112 rows' record the same day the
proposal landed and ruled: ratified, with the scope they gave - the
rows stand, and ratifying them does not preclude improving the
dataset later. `decisions/work-words.jsonl` is intent now, the
dataset's first: 83 choices that took a dealt word and 29 that
founded a position the group created and named, in 22 words by 22
persons, with the limitations the sister's record 28 states standing
as named. The ruling is the sister's record entry 29, landed
same-turn with this close; this batch changes only the two pointers
that said the proposal awaited the ruling, `PROJECTS.md`'s standing
table and `ROADMAP.md`'s beside-this-tree, plus the state surfaces
every close walks. Documents only, so patch.

**Before that**, `[C84]` - the sister's first rows are
in. The operator's chosen target for the dataset's first proposal -
the work words a company deals, record 21's founding example, at a
hundred-plus rows - is authored and landed in
`../zomboid-speakeasy` as `decisions/work-words.jsonl`: 112
member-rows taken from `[C83]`'s dump across all six county runs,
one row per person per run, 71 of the dump's one shared population
of 187. Each row's fourth part was written as that person from the
row's own evidence, with the tree's dealing held in a separate file
until every choice was written, then joined as a column beside the
authored choice so the ruling can read one against the other: 83
rows chose a dealt word and 29 founded a position the group created
and named, and of the 58 rows where the tree dealt a work word the
authored choice took that word 42 times. Nothing in it is ratified -
rows arrive as a proposal the operator rules on - and this batch
changes only the two places this repository said the sister carries
no rows, `PROJECTS.md`'s standing table and `ROADMAP.md`'s
beside-this-tree, plus the state surfaces every close walks.
Documents only, so patch.

**Before that**, `[C83]` - a decision-moment dump
beside the county sweep. The sister's record 24 ratified where the dataset's rows come
from: a person's own record put to a language model, which decides as
that person, in that situation, among the options actually available.
The operator chose the first target and the scale - the work words a
company deals, record 21's founding example, at a hundred-plus rows -
and a row's first three parts are the county's to supply.
`tools/county_dump.py` is the instrument: it runs the same counties
the sweep runs and watches the verb that deals the work, taking the
moment down whole before the deal - every member's record, traits,
conditions, habits, lessons and age, the census's class and skills,
the whole belief set with each belief's provenance, the trust each
member holds toward each other, the creed, the claim, the county
hour - and what the tree dealt lands beside it as the authored
outcome the dataset exists to replace. Serialization is generic so
the instrument cannot quietly curate what the model sees, and a
capture that cannot happen is counted loudly. Not a border, not in
the gate; the dump is data against the install that produced it, and
re-running a county name reproduces the county (`[C66]`), which is
what makes a row's citation answerable. The choice - a row's fourth
part - is the language model's to make in the sister repository,
arriving as a proposal the operator rules on.

**Before that**, `[C82]` - no player at the wheel. T-001's ledger
had held NPC driving as engine-absent - named, never
promised - and the second seam is why that got asked: ZAO's `[A12]`
ruled the crossed's vocabulary a bidirectional goal, and what the
crossed need from driving feeds forward into this project's half of
it. Disassembled method by method off the installed jar, every
identity gate along the driving path exists to exclude the blocked
local player, and none requires one: `isKeyboardControlled()` is an
identity compare against `IsoPlayer.players[0]`, so an NPC answers
false; `BaseVehicle.updateControls()` gates on the
driver-cast-to-player blocking movement, so an NPC passes;
`CarController.updateControls()` reads keyboard and joypad only for
player and pad, so an NPC's written `ClientControls` stand;
`tryStartEngine()` bounds any driver by the same keys, hotwire,
sandbox and condition rules a player faces; and the physics tick
reads `isEnable` with no driver-identity gate at all. F-067.

**What this does not establish is that NPC driving works.** Nothing
shipped exercises the doorway - the reference mod's own sources
contain no driving, only a health controller that rejects vehicle
targets - so live behaviour and cadence stay hypothesis until a
receipt, and T-001's ledger moves from engine-absent to
surface-mapped, receipt-owed. The crossed's requirements ride in the
record as named consumers - the turned aimed with a car, arrival and
departure, noise that moves - and none of it is designed here; the
seam stays a goal in both directions.

**Before that**, `[C81]` - another controller holds them. The
county's one fact named after a single mod answered four different
questions, all of them `is somebody else driving this body`.
`SAO.Claims` answers the property, `heldBy` names who, and a legacy
save is not rewritten. F-066 records what the flag conflated and the
rename did not untangle - a claim, a provenance and an adoption
state - which wants a measurement and a ruling rather than a
rename.

**Before that**, `[C80]` - what an examiner can tell.
`[C78]` and `[C79]` gave the county a sickness and nobody could see any
of it. `SAO_Medical.readingOf` reports what THIS examiner could tell
rather than what the record knows, gated on their own First Aid - the
skill `[B20]` already reads to decide how well they dress a wound.
Untrained, something is wrong and they could not say what; trained,
they can name the fever; practised, they can place it in the course;
only a medic gets a judgement about whether the body is winning.

`SAO_Inspect` is the opposite instrument and says so of itself - it
sees everything, and a window is not a pathway. This is DR-007's second
ledger made visible: what anyone is permitted to know, never a
percentage on the forehead.

The module splits because Border 144 forced it. The judgement lives in
a file that loads in a bare VM; the window lives in one that cannot,
because it needs `ISCollapsableWindow`. So the rule is checked every
run and the renderer stays a renderer. The border holds that no digit
reaches a reading at any skill, and that looking at somebody does not
change them - which is not decoration, because `Course.positionOf`
repairs a missing span by writing one and the first draft mutated its
own patient.

**Before that**, `[C79]` - the unwatched county can catch it. `[C78]`'s own record had to say that its fight reached almost
nobody: `knoxInfected` had exactly one writer, the block releasing a
body to the dormant county, so the unwatched county could not contract
Knox at all and its people died of thirst, of hunger and of the county's
risk but never of the thing the game is about.

A bad day is not only a fatal day now. When the county takes somebody
the encounter either kills them or they get away from it having been
opened up, and a bite infects with certainty on this build (F-047), so
getting away is catching it. Which happens follows from how well they
handle danger, read off the modifiers the pass already computes -
`risk` is how likely the county is to take them and `handles` is the
same facts counted again for a different question. A due bite is not a
roll and never takes the bite path, which Border 90 holds.

**And it found a defect in `[C78]`.** Border 143 ran 120 people for 200
days and nobody had ever thrown an infection off. Raising the constant
looked like the fix and was not: `Course.advance` integrated the
course's REMAINING half instead of its elapsed one, passing `pos` as the
segment start where `pos` is ground already covered - so against a
daily cadence and a two-day window every body forfeited the first half
of every course and could not win at any value. Border 142 could not
have caught it; it holds the model, and the model was right. What was
wrong was the caller's idea of which segment had elapsed, and that is
only visible when somebody runs a course over days.

Measured on the shipped tree over 200 days: a housed county threw off
**8** and an unhoused one **2**, with 37 still carrying it and 37 dead
and risen. Care is a fourfold difference. The rate is not asserted -
that is a distribution and belongs to the sweep.

**Before that**, `[C78]` - the body fights the infection.
`[C11]` and F-047 established that a bite infects with certainty on this
build and kills at exactly `infectionTime + pickMortalityDuration`, and
`dormantAttrition` read the record's mirror of that hour as a due date -
its own comment says past it, death is not a risk, it is due. So every
bitten person in the county died on schedule and nothing they had done
beforehand made any difference. The hour still stands and the body can
now get there first: a contest on inputs the pass already computes for
its risk - days since water, days since food, a septic wound, a house
keeping them, a burning hearth, a pact, their age, what they carry -
against a course whose length is the sandbox's own mortality window.
The model is Antibodies' (lonegamedev, MIT), credited in `CREDITS.md`
and rebuilt rather than imported, because it is built player-first on
`player:getModData()` and the county has hundreds of people.

Three defects were caught before it shipped. The first `gainFor`
sampled the curve at each step's midpoint, which made the CADENCE
decide the answer - one step across a course returns `pi/2` where
twenty-four steps sum to 1, so a dormant body would have out-fought a
loaded one, which is `[C75]`'s defect in another module. It is the exact
integral now, `(cos(pi*a) - cos(pi*b))/2`, additive over any partition.
`qualityOf` clamped to `[0, 1]`, which made four bonus terms dead code
that read as a model - a body wanting for nothing was already at the
cap, so a house, a hearth, a pact and having survived it before all
bought nothing. And the first constant made every well-kept survivor
immune: 1.15 against a win at 1.0 meant anything above quality 0.87
won, and a healthy survivor sits at exactly 1.0. Constitution is
hash-drawn per person now, so two people living the same way do not die
the same way, and the constant is 0.55 - a median body kept well still
loses. **The odds are the operator's** and that is a starting position.

Border 142 (`tools/course_test.py`) runs the shipped module in the
engine's own VM and holds seven properties, the load-bearing one being
that one step, twenty-four and a thousand give the same total. It loads
only `SAO_Log`, `SAO_Hash` and `SAO_Course`, so the module's claim to be
offline by construction is checked every time the gate runs. The loaded
path is untouched: a materialised body's infection is still the
engine's, and the same model reading a live body is the follow-up.

**Before that**, `[C77]` - what the walking costs. `[C75]`
named two growths it could not measure at the time and both are
measured now, over six counties: a whole county holds a median of 110
known buildings and the survivor who knows most knows 109 of the map's
2,831, while the place-knowledge cache holds about eight hundred keys.
Neither is a problem. `know_cache` is session state and
`IngameState.exit()` reinitialises Lua when a world is left, so it
cannot reach the next world (F-064) - and `Places.reset` having no
caller is the engine doing the job rather than an oversight. `b.known`
is persisted, and `[C75]`'s record calling it "pruned nowhere in the
tree" was wrong: `Perception.forget` drops the whole belief store and
`Identity.markDead` calls it, so it is bounded by the living rather
than by everyone who ever lived (F-065). Both misreadings came from
searching a narrow spelling instead of the mechanism - one level too
low in one case, the wrong method in the other - which is `[C70]`'s
defect and the prose-is-not-code clause reached from two more
directions. Nothing under `mod/` changes; what remains from `[C75]`'s
cost is how many ticks a real catching-up county takes, which is a
play receipt.

**Before that**, `[C76]` - a house takes ground where its
people already go. `setGroupClaim`, `setHearth`, `setLarder` and
`setWaterStore` had call sites in `SAO_Controller` alone, which needs
materialised bodies, so a dormant house - and after `[C71]`, `[C72]`
and `[C75]` houses form, reconvene and stand - still had nowhere to be,
and every survival modifier reading a hearth, a larder or a water store
was inert unless a player was watching. The live path scouts through
the bridge with a body; the dormant half needs none, because
`Perception.learnBuilding` has recorded every arrival since `[B37]`
with the bounds, the offers and a visit count whose own comment says
what it means - somewhere returned to is somewhere that gave them
something. So a house settles on the building its members keep
returning to, visits summed across them and multiplied by how many have
been, because a place a house SHARES is what a base is. Nothing is
placed: a house whose people never went back anywhere takes no ground,
and a house of one takes none either. The refusals are the live path's
own, lifted into `barredGround` so the two readers share one law. One
house a pass, `[B51]`'s discipline, because `b.known` grows with the
walking. A house cannot LEAVE and this does not pretend it can - that
is DR-006 S4's ontology error and its own batch. Border 141 measures
the claim rather than the call, controlled against the `[C75]` tree
where no dormant house ever takes ground.

**Before that**, `[C75]` - a day of walking is a day of
walking. The dormant walk stepped four tiles per PASS, and a pass is
hundreds of frames in the live county and one whole simulated day in
the years, so a day delivered four tiles: 1.8 tiles per person per
simulated day, measured, across a map fifteen thousand tiles wide.
`[C45]` chose one move per simulated day deliberately and reasoned
about how often each frame-paced gate opens; it never asked what one
move is worth in ground. The step is a rate over the county's own clock
now, at `[C25]`'s ratified day-reach scaled by the pace of the age
(DR-040), so a day of clock carries a day's walking in either half and
a goal further off takes the days it takes. A sourced real-world figure
was tried first and abandoned: nothing in the installed build says what
a tile is in metres, and the shipped map is not to a consistent scale
(F-062).

**What that was costing.** Twenty-four counties before and after, same
seeds: houses founded went from a median of 20 to 43, houses standing
after three years from a mean of 0.3 to 1.1 and from 8 of 24 counties
to 14, people alive at the end from a median of 2 to 5, deaths from 284
to 269. Nothing in the batch touched a company, a meeting, a trust
number or the goal path - so `[C67]`, `[C68]`, `[C71]` and `[C72]` were
each doing more than their own measurements could show. The social
model was never the thing that was failing.

**What it costs.** A county sweep went from about a minute to between
seven and seventeen, because a walker who crosses their neighbourhood
crosses five of `nearestOffering`'s cache quanta a day instead of one a
week. Two growths follow and neither is measured yet: `Pl.know_cache`,
never evicted with `Pl.reset` uncalled anywhere, which is session state;
and `Perception`'s `b.known`, an entry per building per person, pruned
nowhere, and persisted through `[C15]`'s bind. Both are queued in
`ROADMAP.md` with the measurement first.

**Before that**, `[C74]` - the three projects and what each
owns. Three repositories describe one county and no document held them
together or named the edges between them. `PROJECTS.md` does, canonical
here and pointed at from the other two: SAO owns the living, ZAO
(`../zombie-awareness`) owns the turned, Speakeasy
(`../zomboid-speakeasy`) owns how anybody decides, and none of them
places an outcome. Three seams - the turn, already litigated on both
sides; the dataset, where no code crosses and the licences are the
whole reason the repositories are separate; and the degraded cognition
between ZAO and Speakeasy, which is not yet built and should not be
until ZAO's G2 lands. It adds no border, because a border asserting
that sibling repositories carry agreeing pointers would be about
governance rather than the mod's behaviour, and this repository wrote
one of those once and had it deleted.

**Before that**, `[C73]` - a person is named when they are
made (DR-039). `backfillName` read a name off the engine descriptor the
first time a body was materialised for somebody, so a survivor nobody
had ever stood near carried the `Unnamed` sentinel for the life of the
save - 271 of 271 in a dormant county. A name is a fact about a person
and not about their body, and `Identity.create` is the one funnel every
person is made through, so they are named there. The names are the
engine's own - `SurvivorFactory`'s three public static pools, reached
through four bridge methods as a length and an index so `SAO.Rand`
makes the draw and a county still runs twice the same way ([C66]);
this project ships no name list. The pools are split by sex, so the
record carries one as a hash fact, drawn at Kentucky's own rate rather
than a half: 51.551 percent female on July 1 1993, off the Census
Bureau's intercensal county estimates. The shell agrees with the
record now, where the descriptor used to draw its own sex and
contradict the name. Where there is no engine there are no names and
nothing throws, which `[C71]` made survivable. Border 139 reads the
records rather than the call, controlled against the `[C72]` tree,
which comes out `Unnamed`.

**Before that**, `[C72]` - the dormant day can go to a
person. `chooseDayPlace` decided where a dormant survivor walks from
thirst, hunger, lessons, beliefs and barred ground, and it had no
social term in it, so nobody in this county had ever decided to go to
another person and every meeting was two need-driven walks coinciding
within three tiles. It is `chooseDayGoal` now and the goal may be a
place or a person, chosen from whoever they believe is somewhere,
against the county's own company line, ranked by trust over the age of
the sighting, with `initiative` deciding whether they set out at all.
People who arrive together have seen each other, and somebody believed
to be where you are standing is not somewhere to go - which is what
makes a genesis belief a durable anchor rather than one spent on the
first day. Border 138 measures the goal rather than the call and is
controlled against the `[C71]` tree, which already holds the belief and
sets out 0 times in 40.

**The sweep barely moved, and the reason is the finding.** Twenty-four
counties before and after, on the tree that actually shipped: houses
standing 6 of 24 against 8 of 24, a difference this sample cannot
separate from noise. The figures in `[C72]`'s own record are 5 of 24
and were measured before two of that batch's changes landed; F-063
carries the correction, and the ledger's append-only rule is why it is
an entry rather than an edit.
Instrumented at each exit of the chooser, seeking is not out-ranked -
need takes 47 percent of day-goals and a place 52 - and in 790 of 806
choices there was no eligible person to go to at all, because a belief
about a living person comes from a meeting and meetings almost never
happen. **A dormant survivor walks 1.8 tiles per simulated day**,
measured on both trees. The years pass advances its counter by 3600
ticks per simulated day and calls `dormantLife` once, so a day gets one
move of at most four tiles, against about eighty moves the same code
gives that person in live play. Three simulated years carry somebody
under two kilometres across a map fifteen thousand tiles wide. That is
`[C62]`'s class for the third time - a cadence written in frames does
not survive being driven a day at a time - it is F-061, and it means
every measurement this project has taken of its own social life,
`[C67]`'s and `[C68]`'s included, was taken in a county whose people
barely move.

**Before that**, `[C71]` - every person has their own
belief key. A survivor's beliefs about people are keyed by
`Identity.displayName`, which renders `"Unnamed"` for a record with no
name, and `backfillName` reads a name off the engine shell the first
time a body is built for somebody - so a county that materialises
nobody has no names. Measured in the engine's own VM against the
shipped map: 271 people, 271 of them `"Unnamed"`, one distinct display
name for the whole county. Every belief about every one of them landed
on one string, so the county's memory of its dead was a single slot per
head and each death overwrote the last. Three things compounded it,
each found by the new border refusing to pass: the death news read
`P.beliefs[hearer]` without opening one, so it reached nobody who had
never been told anything by anybody and the median county held ONE
person with any belief about any person at all; that pass returns
before anything when `DormantRisk` is zero, so a dial meaning the
county stops collecting also silenced news of deaths that had already
happened; and its hearers were `fellowsOf` on a corpse, which `[C68]`
takes off the roster at the moment of death, so the company half of
the news has reached nobody since. `Identity.beliefKey` is the name
where there is one and the id where there is not, `knownName` still
refuses the sentinel so no id reaches a player (DR-017),
`migratePersonKey` carries beliefs across a rename, `learnOfDeath`
opens the store, `deliverDeathNews` runs before the risk gate and asks
the house by its name through `Standing.membersOf`, and
`Perception.sawPerson` writes the sighting a dormant meeting leaves -
which had never been written at all, so over eight counties of 1096
days not one survivor believed a living person was anywhere. People
holding any belief about any person go from a median of 1 per county
to 100. Border 137 measures the belief rather than the call and is
controlled against the `[C70]` tree, which prints `keyA=Unnamed
keyB=Unnamed`. Two instruments were wrong and travel with it: Border
18 read `java/out`, a gitignored build directory, and called it the
shipping surface, so in a fresh worktree it accused two correct bridge
calls of not existing; it reads the shipped jar now and says which
surface answered. Border 28 read a key migration as an acquisition,
when a belief moved between keys keeps the provenance it already had.

**Before that**, `[C70]` - every death path settles the
house in one place. `[C68]` moved the settling of a house on a death
into the funnel every death path reaches and deleted the one call site
doing it itself, but there were two, and its border could only see the
one it deleted: it read `SAO_Controller.lua` for the phrase that site
used, while the same call site in `SAO_Population`'s dormant attrition
- the half of the county nearly every death happens in - was worded
differently and survived a batch written to delete it. It was wrong by
then rather than redundant, because it captured the group BEFORE the
death and re-elected over a house that had already ended. Border 136's
seam now reads the whole tree for the shape rather than one file for
one phrase.

**Before that**, `[C69]` - the county sweep is a tool in
the tree. The sweep found `[C67]` and `[C68]`, the two largest defects
this project has had, and it lived in a scratch directory; it has been
rebuilt from nothing more than once and both rebuilds reintroduced a
gap that invalidated their own results. `tools/county_sweep.py` runs N
counties in the engine's own VM, one process each, against a world read
off the installed game - every town's spawn points as its own region
and the buildings of every cell they occupy, out of the `.lotheader`
files. It is not a border and is not in the gate: a border is a point
and a county is a distribution, so it reports min, median, max and mean
and asserts nothing. Its durable half is the module check - every
`SAO.X` the loaded code references is resolved against what is loaded
before any county runs, because twice a sweep reported a complete set
of numbers that meant nothing for want of one module, and the eight
modules a dormant county correctly does not run are declared by name
with the argument for each.

**Before that**, `[C68]` - a death leaves the company.
`Identity.markDead` is the funnel every death path reaches and it
forgets nine things about a dead survivor while never touching
`s.groups`. `electLeader` and `groupSize` have always filtered the dead
when they run, so the roster has always MEANT living membership, and
nothing ran them on a death: a corpse answered as a member, could hold
`leads` while `leaderOf` still named them, and the store grew for the
life of the save. The part that cost a survivor something is the widow
release, which fired when a housemate LEFT and never when one DIED - so
somebody whose company died around them was left alone in a house the
rule says may not exist, never released, never inheriting its ground.
One call site re-elected, and only when the corpse had been the leader,
so the dormant half of the county had no equivalent at all.
`S.releaseDead` removes the row and settles the house; `markDead` calls
it beside the other nine forgets. Roster rows belonging to the dead
fall from a median of 25 per county to 0, and houses standing at day
1096 are unchanged, so this removes phantom houses rather than real
ones. Border 136 kills a chair as well as a member, because this batch
deleted the one call site that handled a leader's death.

**Before that**, `[C67]` - founding a company dissolved
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

`5.3.0.0-pre-alpha` at tip - the version machine's output ([C2],
DR-013; the units `[C113]` through `[C126]` moved it here: the
Week One port's two minors, the raider, moments, age, drugs,
vehicle-ground, animal, combat perception, neuroinflammation, and trajectory minors, with `[C115]`'s dial kohai among them).
`[C126]` reached the install on 2026-09-15 after the source rebuild and
the full gate: the deployed `mod.info` reads `5.3.0.0-pre-alpha`, and
the distribution, shipped, and installed jars match at MD5
`ECDBB1F4991A2EC51BB2F732A819EC63`. The prescribed deploy also copies
root `LICENSE` and `CREDITS.md`; their installed copies match the root,
and no other installed file differs from `mod/`.
`[C124]` reached the install on 2026-09-14 after the source rebuild and
the full gate: the deployed `mod.info` reads the coordinate derived at that close, and
the distribution, shipped, and installed jars match at MD5
`F323E54DEAAAD958DC9A94E6C3BBB172`. The prescribed deploy also copies
root `LICENSE` and `CREDITS.md`; their installed copies match the root,
and no other installed file differs from `mod/`.
`[C123]` reached the install on 2026-09-14 after the source rebuild and
the full gate: the deployed `mod.info` reads the coordinate derived at that close, and
the distribution, shipped, and installed jars match at MD5
`570E4D0B276D6C5BBCA2115A2541CFF0`. The prescribed deploy also copies
root `LICENSE` and `CREDITS.md`; their installed copies match the root,
and no other installed file differs from `mod/`.
`[C122]` reached the install on 2026-09-14 after the source rebuild and
the full gate: the deployed `mod.info` reads the coordinate derived at that close, and
the distribution, shipped, and installed jars match at MD5
`2EEE6219A5A0516837018D76A34F799E`. The prescribed deploy also copies
root `LICENSE` and `CREDITS.md`; their installed copies match the root,
and no other installed file differs from `mod/`.
`[C62]` reached it on the same day, after its own commit passed the
gate and its pull request merged, and was checked rather than assumed:
both `mod.info` files read the coordinate the machine derived,
`SAO_History.lua` carries the county's clock, `SAO_Standing.lua` reads
it at all thirty-four of its sites, and `SAO.jar` is byte-identical to
the committed build. `[C63]` through `[C70]` reached it as they closed. `[C71]` and `[C72]` are what is
owed now: together they change what every dormant survivor can know
about another person and give them a reason to walk to one, which an
existing save feels from the next session. `[C67]` and
`[C68]` are what is owed now, and together they are the pair an
existing save feels immediately: survivors who already trust each
other can keep company from the next session, where before they
never could, and their houses now settle when one of them dies.
`[C69]` changes nothing under `mod/` and owes no receipt.
`[C84]` is documents only and owes no deploy.
`[C85]` is documents only and owes no deploy.
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

**159 numbered borders**, run by **174 gated mirrors** in `tools/`, all invoked
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
- **Settled at `[C73]`, kept here for the record: the county had no
  names, and a person got one from the first shell built for them.** `backfillName` reads a forename and surname
  off the engine descriptor when a body is first materialised, so a
  survivor nobody has ever stood near is `Unnamed` for the life of the
  save - 271 of 271 in a swept county. `[C71]` makes the absence
  survivable by keying beliefs on the person rather than on what they
  are called; it does not cure it. Curing it means SAO drawing a
  forename at genesis, and the engine's name pools are split by sex
  (`SurvivorFactory.getRandomForename(boolean)`, javap-verified), so
  SAO would have to decide a survivor's sex at genesis and then make
  the shell the engine builds later agree with it. That is a design
  call about what the county's people are, not a repair.

## The condition

The idea is the success condition, entire. The pass continues until the
operator ends it.
claim is separate from recognition, and the model now records the claim, the
recognizers, and the response. Coercion can make a claim effective without
making it legitimate. The governance names are analytical, not speech lines;
no character says `I am despotic` or `I am localist`. Some parts of the model
are also a player-facing loop: the player may petition, support, contest, claim,
vote, enforce, resist, join, or leave. Documents only, no mod
code, so patch.
claim is separate from recognition, and the model now records the claim, the
recognizers, and the response. Coercion can make a claim effective without
making it legitimate. The governance names are analytical, not speech lines;
no character says `I am despotic` or `I am localist`. Some parts of the model
are also a player-facing loop: the player may petition, support, contest, claim,
vote, enforce, resist, join, or leave. Those actions are reachable through
free-form conversation, not only through a menu. Documents only, no mod
code, so patch.
