| Document | Knox Survivors Social-System Audit |
|---|---|
| Version | `0.6.0.0-pre-alpha` · authored at `[A14]` |
| Author | ellyj3rain |
| Repository | `KNOX_SOCIAL_AUDIT.md` |
| Status | CANONICAL - reference-design audit; mechanics translatable, files never copied. |

# Knox Survivors social-system audit

Read at `[A14]` from the rebuild repository (reference permission standing;
ideas and mechanics are translated under our ontology, files are never
lifted). This maps what the reference BUILT for social/organizational play,
so the expansion arc translates deliberately rather than rediscovering.

## 1. Identity statistics

Per-survivor `sociability` and `aggression` (0-100, stable hash), age in
years (18-70, hash-derived, pushed onto the engine descriptor), and
`createdAtHours` derived as `worldAge - character:getHoursSurvived()` —
THE ENGINE ALREADY TRACKS HOURS SURVIVED PER CHARACTER, which is the
foundation our apocalypse-clock gradient needs.

## 2. Pair relationships: bond through DOING

Relationship records accumulate `meetings`, rate-capped `nearbyHours`, and
- the deep idea - SHARED ACTIVITY DELTAS: while two survivors are near,
the deltas of their roam/loot/combat counters are matched pairwise and the
overlap is banked as `sharedRoam/sharedLoot/sharedCombat`. Fighting
together bonds; walking together bonds; looting together bonds. Proximity
alone is the weakest signal. Our encounter-trust is proximity-only - this
is the upgrade path.

## 3. Staged meetings

Two available survivors inside an attraction radius open a PHASED meeting:
REQUESTED -> interrupt both -> APPROACHING (one walks to the other) ->
GREETING with timed speech beats (opener at 0, response at +90 ticks,
resolution at +240). Outcome decided deterministically per pair+meeting
number from blended sociability/aggression: `join` (travel group formed or
loner recruited into an existing group - "We've got room, if you can pull
your weight"), `decline` (cooldown hours, "Just passing through"), or
`hostile` -> ROBBERY (aggressor demands supplies, victim holds, robbery
behavior runs; disposition `hostile` with expiry). Meetings abort on
combat, timeout, or player recruitment mid-meeting.

## 4. Groups -> factions -> settlement (the organization pipeline)

Travel groups carry `leaderId`, `memberIds`, and FORMATION SLOTS (members
follow the leader in assigned positions). At 3+ members a group promotes
to a FACTION (event: "A new survivor faction has formed"; leader speaks
"We should find somewhere to settle"). Factionless leaders then SCOUT A
HOME BASE: buildings scored `rooms*8 + min(area,240)*0.15 + water?15`,
minimum rooms/area gates, rejected-candidate memory with expiry, confirmed
home -> safehouse claim -> members become base RESIDENTS.

## 5. Bases: the settlement work loop

A base (owner: player or faction) holds `home`, `territory` bounds, typed
ZONES (labeled, enable-able), storage POLICIES (category -> depot), and a
TASK QUEUE: tasks queued with type/target/requirements/priority, CLAIMED
by a survivor, FINISHED or REQUEUED (interruption, death - tasks outlive
their workers). Job domains shipped: farming, woodcutting, barricades,
storage hauling, corpse handling. This is the deepest single subsystem
(~2,600 lines across the KS_Base* family) and the reference's answer to
"survivors occupy territory and DO things there."

## 6. Player relations and politics surface

Per-player-per-survivor: `trust` 0-100 (starts 30), `meetings`,
first/last-met stamps, talk cooldown. Verbs: TALK (+trust, cooldown
hours), RECRUIT (gated: mod enabled, survivor INDEPENDENT - not in any
group/faction, companion limit, trust threshold -> "needs_trust"),
companion ORDERS (follow/hold, directives, per-companion policy toggles
like climbing), DISMISS, duty modes (companion vs base resident,
activate-from-base). Player-affiliated survivors are EXEMPT from NPC
social AI (availableForNpcSocial) - recruitment removes them from the
independent social world, cleanly.

## 7. Presentation

- ActivityFeed: a world-event window (stable per-speaker colors) that
  routes both SPEECH ("said" lines) and EVENTS ("A new survivor faction
  has formed") - the world's newspaper.
- SurvivorCard: per-survivor inspection window.
- Notebook: tabbed rich-text (Party / Home Base / Survivors / Factions) -
  the player's ledger of the social world.
- CompanionHUD: party status overlay.
- Art assets: workshop icon/poster only - the value is the UI COMPOSITION
  patterns, not textures. All ISUI-built.

## 8. Verdict: translate / exceed / decline

TRANSLATE (CAO-shaped, under our pillars):
- Shared-activity bonding into Standing trust (doing > proximity).
- Staged meetings with speech beats onto our Voice + movement.
- The organization pipeline: company -> named faction at 3+ -> scored
  base scouting -> settlement claims (our claims generalize to buildings).
- Task-board settlement work through our vanilla-action discipline.
- Player politics verbs on a MINIMAL menu (the operator finds stock menus
  cluttered; ours stays sparse): Talk / ask-to-join-me / petition-to-join-
  them / influence standing inside their groups.
- Notebook/Card/Feed presentation patterns.

EXCEED (ours already deeper, keep ours):
- Trust as continuous relation with provenance-weighted consequences
  (suffered/witnessed/testimony) vs. KS's outcome-roll dispositions.
- Perception discipline (KS reads positions freely; we stay belief-gated).
- Needs through vanilla actions; hibernation; dormant world.

DECLINE:
- Outcome-by-roll meetings (our outcomes emerge from standing/disposition,
  not dice against sociability).
- Omniscient pair observation (KS pairs observe at any distance within
  radius regardless of sight; ours must stay perception-gated).

## 9. The expansion arc this audit opens

Apocalypse-clock knowledge gradient (sandbox start + hours survived ->
lessons known), trait-coherent backstories with formative events, lessons
from others' deaths (cautionary knowledge transmission), governance
(leaders with consumers, politics the player can influence), settlement
occupation with work, habit/judgment realism against the installed mod
population (hygiene/substances), pair bonds and witnessed-death trauma.
Recorded as DR-006; gates in ROADMAP.
