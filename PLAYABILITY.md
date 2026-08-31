| Document | Playability - what a session shows |
|---|---|
| Version | `0.6.0.0-pre-alpha` |
| Author | ellyj3rain |
| Repository | `PLAYABILITY.md` |
| Status | CANONICAL - what the player can meet; reviewed against the tree, not inherited. |

# Playability

Written for the operator sitting down to play, surface by surface. Every
claim below is deployed code as of the last guarded deploy; none of it is
live-witnessed until your console says so. Console prefixes to watch:
`[SAO][POP]`, `[SAO][CTL]`, `[SAO][XCHG]`, `[SAO][NEED]`, `[SAO][census]`.
The console opens with the boot digest ("day 38: 54 living, 6 dead, 3
companies, 1 at war / target 216 (sized from the map)" - the target names
which of the two it is), and "SAO: the county" and "SAO: standing web" are on
every right-click - no harness spawn needed.

## The county fills itself

Within a minute of loading, genesis paces the county toward the sandbox
Population target. Each life is drawn from a real 1993 Knox-area
distribution over the engine's own profession registry - mostly clerks,
factory hands, retirees, truckers; soldiers because Fort Knox is next door;
spec-ops only if the mod that registers them stays active, and rare then.
Each is placed where that life was lived when the engine files spawn points
under the profession (the deputy starts at a station point). Lives originate
in units - family, friend, or mixed, of two or three where they come together
at all - with their relations derived from their ages, never a pre-formed
faction, and everyone's settled past is shaped by who they were: claims with
lived / witnessed / told provenance.

Fresh survivors materialize dressed for their trade - Police, Nurse,
Fireman, ArmyCamoGreen, Priest, twenty verified outfits - and their perk
levels carry their profession's engine-defined boosts. Awakened survivors
wear what they wore.

## The workday

Nobody ticks without a legible answer: need, designation, chosen rest, or
errand - the standing-web surface prints it per body. Companies deal jobs at
election: the watch walks the actual claim edge, scouts range wider,
foragers sweep before hunger bites, quartermasters shelve spare food into
real containers, and medics walk to the bleeding and hand over a bandage
(the wounded bind themselves). Chosen rest is positioned and interruptible:
the evening seat with the door in view, the smoke facing the road, the banjo
with the weapon in reach.

Every survivor carries a journal - a named notebook whose pages are their
life written down at first meeting. Loot a corpse, read who they were.

## Talking to anyone

Right-click a survivor. Talk cycles one line per game-hour through the whole
person: trade and origin, how it started, their job, their company and its
creed, the dead they carry with audible provenance ("I was there." vs
"That's what I heard, anyway."), lessons, faction bases, places to leave be.
Talk answers the moment - war, grief, territory - before the rotation.

From the same menu: ask them to walk with you (companion), ask to join their
faction (leader-trust gated), or ask a willing ungrouped companion to work a
job. An active companion takes asks - wait here, stay close, check that
building - and they are asks, never a leash: their judgment stays theirs.
As an accepted member you can counsel your leader: urge peace, urge
settling, moving dispositions at faction scale.

## The wire runs both directions

The county broadcasts its own politics and losses; whoever really owns a
receiver hears them as told-provenance claims. The player can be heard, can
call, can share a camp, and can petition houses they are nowhere near.

## Fire, water, ground

Houses count what they have to drink and send people out with every empty
bottle they own before thirst bites; when the mains stop, the wire says so
once and the ledger remembers the day the taps ran dry. The cold seek fires,
feed them from their own packs, light what has fuel when they carry the
means, and freezing wakes them out of sleep. Farm hands with real trowels
and real seeds break real ground on their own claims in the growing months
and bring in crops that flow through the same shelves, larder counts, and
who-eats-first politics as everything else; the engine scales the yield by
their Farming skill and teaches them as they work.

## The bitten

Bites are seen at a glance and everyone knows what they mean. The fearful
bitten deny it, the composed ask for the promise; mercy houses nurse with
real bandages while fearful houses put real distance; your own bite gets
named to your face. When a zombie wears a known face, whoever knew them says
so - and whoever promised walks over and keeps it.

## The world you are not watching

Unloaded survivors are governed by the same rules as loaded ones. Nothing in
the dormant world fabricates goods, because unloaded cells have no
containers - stated, not fudged. A dormant death instantiates no body;
the county learns someone turned as a claim carried by word, not as a corpse
on a road. The county's long-run physics are verified offline: 120 simulated
days hold a living mix - many companies, no mega-company, feuds declared and
peaces made. What only the live world adds: schism fuel, deaths, and you.

## The dials

The sandbox page "SurvivorAwareness" carries the tuned surface: enable,
population target, materialize and hibernate radii, refill days,
desperation, trust-to-company, errand radius, voice, dormant risk, and the
rest. Every option is read, named, and explained in-game.

## Honest gaps

Re-verified against the tree, 2026-08-28 - not inherited.

**Not yet witnessed in play.** Nothing in the A or B eras has a play
receipt. Every batch record carries its own pending list, and the offline
harnesses (individual pasts, county distribution, 120-day society) plus the
border gate are what stand in the meantime. Code-complete is not the same as
verified.

**Engine boundaries we cannot cross, and do not fake.**

- NPCs cannot drive: Build 42 has no AI vehicle pathfinding. Houses count
  their real cars and seats, and the player drives a crew; nobody else does.
- Unloaded cells hold no containers, so nothing is gathered, grown, or built
  out there.
- Vanilla's authored emergency broadcasts are prose, so survivors do not
  learn from them; they hear this mod's wire, whose claims the mod actually
  holds.
- Knox legacy inhabitants perceive nothing of their own - their bodies are
  zombie-backed and never driven (DR-009). Our people see them; the reverse
  would need a scanner they cannot carry.

**Named and deferred by design.**

- Water charity has no seam: strangers can receive food and medicine but not
  water, because no water-share path exists to hang mercy on honestly.
- Lighting a hearth uses the engine's own `setLit` behind a real inventory
  requirement, rather than vanilla's kindle timed actions, which need a
  campfire object indoor fireplaces do not have.
- Building past window barricades (real construction) is unbuilt; the engine
  surface is deep and the honest slice shipped instead.
- Skill grants at materialization are not retroactive to bodies created
  before [A19] - teaching ([B11]) closes that gap over time for anyone in a
  house.
- Instruments are a legible rest answer, not an animation.

**Third-party.** Two HUD mods (ModernStatus, Lifestyle: Hobbies) are broken
on 42.20.4 for reasons unrelated to this mod - disable or update them for a
clean UI.
