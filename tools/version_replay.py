#!/usr/bin/env python3
r"""Border 80 - the version is a machine, and the machine's output is stated.

The former version was hand-declared: 0.6.0.0 was picked at [B12] by a
policy sentence ("nineteen batches of shipped surface") and the old
VERSION_MAP walked to it in six flat minors so the number looked
earned. The operator's instruction (DR-013): the coordinate is not
picked, it is computed - classify each closed batch by what the work
is, run the replay under CAO's caps, and the output is the version.

THE MODEL (CAO's, adopted)
--------------------------
Form `major.minor.kohai.patch-maturity`; hard caps minor 12, kohai 16,
patch 24; a tier movement resets the coordinates beneath it; a movement
at the cap rolls the tier above (twelve minors of capability ARE a
major - that is the odometer, not an honor). Maturity moves on
evidence, never on arithmetic; SAO remains pre-alpha; individual
play receipts do not establish release maturity.

Tiers: minor = a new player-visible simulation capability or a new
authoring/runtime contract; kohai = a coherent extension, integration,
or structural maturation of an existing capability; patch = an in-place
correction, verification closure, or repair that does not move a
capability boundary.

WHAT IS DERIVED AND WHAT IS INPUT
---------------------------------
The only input is the tier table below: one row per closed batch, with
the classification argument. Names, dates, and threads come from
BATCH_LOG.md - the index owns them, this file never respells them. The
replay derives the coordinate; --write stamps VERSION and renders
VERSION_MAP.md; the border refuses a tree whose VERSION, VERSION_MAP.md
or mod.info disagree with the machine.

To disagree with the coordinate, disagree with a tier: edit that unit's
row, state the argument in its rationale, run --write. The map and
VERSION follow. Nothing else in the tree may state a version of its own
(Border 42 stamps the jar from VERSION at build; Border 43 holds the
doc-pack headers to VERSION).
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
BATCH_LOG = ROOT / "BATCH_LOG.md"
VERSION_FILE = ROOT / "VERSION"
VERSION_MAP = ROOT / "VERSION_MAP.md"
MOD_INFOS = (ROOT / "mod" / "mod.info", ROOT / "mod" / "42.20" / "mod.info")

SCHEMA = "sao.version-model/1"
MINOR_CAP = 12
KOHAI_CAP = 16
PATCH_CAP = 24
MATURITY_LADDER = ("pre-alpha", "alpha", "beta", "rc")
REPLAY_START = "0.1.0.0-pre-alpha"

# (batch, tier, classification rationale). Chronological, one row per
# closed batch, covering BATCH_LOG.md exactly.
UNITS = [
    ('A1', 'initial', 'The governed repository itself: doc-pack, instruction surface, ratified pillar composition; no framework code.'),
    ('A2', 'kohai', 'The verified engine substrate (F-001..F-007) before anything built on it; preparation, not a shipped capability.'),
    ('A3', 'minor', 'The first survivor in the world: spawn, walk, remove - the first player-visible capability, and the mod tree ships.'),
    ('A4', 'minor', 'The compiled agent, the bridge, and ENGINE_CONTRACT: the runtime contract everything renders and calls through.'),
    ('A5', 'minor', 'The four pillars as code: perception with provenance, bounded disposition, standing, the controller composition.'),
    ('A6', 'minor', 'Combat both directions and a persistent population in real towns: the framework becomes something a player meets.'),
    ('A7', 'kohai', "Genesis matured to the map's own spawn-region draw, off the forbidden refill shape; policy numbers become sandbox options."),
    ('A8', 'minor', "The needs layer through the engine's own timed actions - eating, drinking, interruptible; grudges, testimony, gear errands."),
    ('A9', 'minor', 'The voice surface and real territory: claims, permission, first aid, sharing - with the one key schema (DR-005) under it.'),
    ('A10', 'kohai', 'Multi-floor work, the ranged doctrine, and the F-011 sight repair: the loop polished, no new boundary.'),
    ('A11', 'kohai', 'Hibernation made whole (F-013), dormant drift, estates, sleep: persistence matured into the person outliving the scene.'),
    ('A12', 'minor', 'The social economy opens: gifts, barter, property with teeth and manners, dormant encounters.'),
    ('A13', 'kohai', 'Debts, gunfire attribution, coordinated flight, companionship: the economy and relations grow edges.'),
    ('A14', 'minor', 'The society arc ratified and built (DR-006): claims and lessons, leaders, settlement, membership, habits, bonds.'),
    ('A15', 'kohai', "Belief-gated permission (DR-007): the permission layer's last free knowledge made earned; epistemics matured."),
    ('A16', 'patch', 'The approval-chain repair (F-023) and the first live witness: verification closure on the existing line.'),
    ('A17', 'minor', "Inhabitant adoption: other mods' live humans join the social fabric with records, contact-scaled pasts, split clocks."),
    ('A18', 'minor', 'The census contract (DR-010/DR-011): 1993 labor distribution, profession-keyed origins, compatibility from first principles.'),
    ('A19', 'minor', 'The workday taxonomy and elections: every tick carries a pressure answer; a mannequin is structurally impossible.'),
    ('A20', 'kohai', 'Feuds, full-person talk, dormant attrition: politics closes its loop and gains its voice.'),
    ('A21', 'patch', 'The hardening rotation: bulkheads, fault gates, F-031..F-034 - repair and closure, no boundary moved.'),
    ('A22', 'kohai', "Schism's mechanics, the war chronicle, the invariant sweep: politics matured under its audit trail."),
    ('A23', 'kohai', "The offline equilibrium harness: 120 deterministic days prove the county's physics without the game; instrument, not capability."),
    ('A24', 'kohai', 'The engine rotation re-read end to end; full names and per-person texture make the people legible.'),
    ('A25', 'kohai', 'Counsel, ration policy, the governance chronicle: the commons matured at community scale.'),
    ('A26', 'minor', "The county wire, 101.2, both directions: a new medium, built on the engine's own radio pattern."),
    ('A27', 'kohai', 'Player chairmanship, the arrival draw, war parties: the political physics completed.'),
    ('A28', 'minor', 'Derived possessions: the convenience tables die; place provides, person spots - a new derivation contract.'),
    ('A29', 'minor', 'Day-zero innocent-county mode: a new way to start the world, innocent by construction.'),
    ('B1', 'minor', 'The venture as a designed feature-complex: motor pool, departure argument, terms, crews, briefings.'),
    ('B2', 'kohai', 'Skill levels drive assignment and rates across the existing work; one truth, two read paths.'),
    ('B3', 'minor', "The bitten arc: bite visibility, the house's answer from character, turning recognition, promises kept."),
    ('B4', 'minor', 'Farming through vanilla timed actions: the renewable arm of the material economy.'),
    ('B5', 'patch', 'Performance and sensor audits; three borders born - cost and truthfulness closure.'),
    ('B6', 'minor', 'Water as the second material axis and fire as a need: stores, runs, the shutoff day, hearth tending and lighting.'),
    ('B7', 'kohai', "Council abandonment and the wound's full life: decisions the state earns, on existing machinery."),
    ('B8', 'kohai', 'Standing moves both directions: endorsement, decay, lapse, walking out - the ratchet removed.'),
    ('B9', 'kohai', "The engine's own chemistry colors meetings; wire bulletins land as told knowledge in real receivers."),
    ('B10', 'patch', 'The foreign key domain contained, wounds persist through the pack, the county lets go at player death - repairs.'),
    ('B11', 'kohai', "Housemate teaching and player barter: the circle law's cost and the player in the economy."),
    ('B12', 'kohai', "The verb wall collapses into the game's own menu idiom; the index completed - surface maturation."),
    ('B13', 'kohai', 'Need-driven promotion at election: the house reads its own counted claims and adapts.'),
    ('B14', 'kohai', 'The repository gate and pre-commit hook: discipline made mechanical, proven by breaking the tree.'),
    ('B15', 'kohai', 'Corpse looting with dignity rules: the one place dignity outranks need.'),
    ('B16', 'patch', 'The undeclared-identifier audit and the edit-verification law: instruments and closure.'),
    ('B17', 'kohai', "Night-light gating and weather's weight: dark and storms shape the existing behaviors."),
    ('B18', 'kohai', 'The Ledger learns live content; the player claims ground and homes companions through existing machinery.'),
    ('B19', 'kohai', 'Player teaching, vehicle crews, venture staffing, night watch: the player joins the work.'),
    ('B20', 'kohai', 'Severity-first aid, the distress cry and its cost, the cook designation: professional shapes on existing lines.'),
    ('B21', 'kohai', 'Population exchange with the zombie pool, porch music, evidence-based judging: composition with the world.'),
    ('B22', 'kohai', 'Keepsakes and reading, derived work stations, skill-book study: identity beyond employment.'),
    ('B23', 'minor', "Government's complete shapes: five forms, deputies, turns, scarcity asks, division-driven schism."),
    ('B24', 'patch', 'The dead pact layer revived (one-character typo) and the creed distribution corrected - repairs with their border.'),
    ('B25', 'patch', 'Work-judgment probing, quarrel drivers, identity-gate corrections: probing and repair.'),
    ('B26', 'patch', "Engine item-vocabulary corrections: four dead literals replaced with the engine's own surfaces."),
    ('B27', 'minor', 'The player as channel participant: one experience loop, inbound and outbound, restoring a missing player-visible contract.'),
    ('B28', 'kohai', 'Newcomer reach, arrival rates, registers, trespass teaching: the road matured and measured.'),
    ('B29', 'patch', 'Road-frequency display, ledger paging, window sizing: small surfaces made honest.'),
    ('B30', 'patch', 'Publishing metadata and the false description repaired; attribution made precise.'),
    ('B31', 'patch', 'The duplication border, fuel accounting, protocol borders: drift measured before unified.'),
    ('B32', 'patch', "The between-time chain repaired, mirror coverage, analysis discipline: the county's habits fixed with their instrument."),
    ('B33', 'patch', 'The two radii reconciled into one honest band; the shipped jar found stale and made current.'),
    ('B34', 'patch', 'Menu gating, measured claim extents, queue-drop detection: silent failure classes closed.'),
    ('B35', 'kohai', 'The claim lifecycle completed: unlearning by proximity, protection, carry-light wired to its walk.'),
    ('B36', 'patch', 'The save-field guard, deploy survival, the catch audit: the discipline layer hardened.'),
    ('B37', 'patch', "The county's truths made singular: one band constant, age arithmetic, death causes, shutoff revision."),
    ('B38', 'minor', "The county's scale derived from the installed map and the census graded against the real 1990 - assumption replaced by contract."),
    ('B39', 'minor', 'Acquisition provenance completed (unknown fails the gate) and places spent by being visited - scarcity becomes a model.'),
    ('B40', 'patch', 'Named constants, lived provenance at genesis, the perk vocabulary map: names that keep arithmetic honest.'),
    ('B41', 'patch', "The gate audits itself: all mirrors run, and the player's own perception repaired after 79 batches blind."),
    ('B42', 'patch', 'The silent surfaces hunted as a class; census authority ratified (DR-012).'),
    ('B43', 'patch', "The jar stamps its own version, session-state truth gated, the dormant economy's unwired halves wired."),
    ('B44', 'patch', 'Legible option labels and the Kahlua runtime boundary learned from a live crash.'),
    ('B45', 'patch', 'Distance naming, Kahlua-gated compilation, the nil-name repair, the neighbour narration hold.'),
    ('B46', 'patch', 'The player-reply channel repaired: two stacked defects that silenced the conversational surface.'),
    ('B47', 'patch', 'The log-reading defect pass: census rebuilt true, noise measured down, boot truth.'),
    ('B48', 'patch', 'The distribution arc: everybody was the same person - the hash pathology found by instrument and fixed.'),
    ('B49', 'patch', 'Frame-time pacing disclosed on every claim; the voice cooldown moved to the wall clock; decay verified.'),
    ('B50', 'patch', 'Engine behavior facts re-asked of the machine each run; the bridge throw contract graphed.'),
    ('B51', 'patch', 'The dead stop growing quietly: death-time cleanup, budgeted walks, derived art, the save protocol border.'),
    ('B52', 'patch', "The era's integrity closed: derived counts, aligned names, the scout read whole, the answer domain sealed."),
    ('C1', 'kohai', 'Corrected catalog links, chronology, runtime maps and the gate environment. Replaced hand-selected version coordinates with an executable replay of classified development units under the inherited CAO caps. The catalog owns names and dates; the replay owns the coordinate.'),
    ('C2', 'patch', 'Unified person naming across the neighbour path and repaired continuity through crossings, seats and spoken interactions. The changes connected existing engine and controller paths and made swallowed execution failures visible; they did not introduce a second owner for a body.'),
    ('C3', 'kohai', 'Added the inspection harness and integrated the person state visible through it. Existing menus carry the inspection and command surfaces through shared ownership prediction, with a fallback where those menus are unavailable. The harness exposes simulation state and diagnostic controls; observation alone does not establish completed behavior.'),
    ('C4', 'kohai', 'Connected durable death, risen-body ownership, crowd identity and infection timing to the engine. Distinguished persistent people from the fungible crowd and tied promises and lethal infection to their actual bodies and clocks. The later afflicted-return defects remain separate unresolved ownership failures.'),
    ('C5', 'patch', 'Revised the front end and configuration copy into player-facing language and swept the integration surfaces. These corrections cover the inspected interfaces and compatibility conditions; they are not blanket acceptance of every installed mod.'),
    ('C6', 'kohai', 'Extended persistence so the person retains the state required to resume decisions across reload. The durable record is authoritative while engine bodies are temporary representations. Later optional drug counters and graph registrations still require their own persistence review.'),
    ('C7', 'minor', 'Added the dead census, durable crowd ledger and optional debt-bounded zombie restitution. With RestoreTakenZombies enabled, the engine addVirtualZombie surface repays prior pool takes beyond the hibernation radius, at most six per daily pulse; the setting defaults off. Measurement and this limited mutation do not establish demographic calibration or complete population dynamics.'),
    ('C8', 'patch', 'Recorded first play observations, repaired route restarting and room-item parsing, and established that partial receipts remain useful evidence. Acceptance attaches to the observed surface and conditions. These fixes and observations do not certify the whole project or prevent independent mechanical work.'),
    ('C9', 'kohai', 'Consolidated identity adoption, complete failure handling and the configuration field boundaries. Removed unavailable or unsupported interface surfaces rather than leaving declarations detached from their implementation. The work preserves the one-person and one-body ownership rules.'),
    ('C10', 'patch', 'Connected need-directed movement to remembered opportunities and repaired the interaction path from player input through Standing. Added outcome-verified dressing and claim-aware wake placement. Knowledge, permission and execution remain separate responsibilities; a reachable interface does not itself supply an action consequence.'),
    ('C11', 'minor', 'Introduced a common view of what a person knows and an arithmetic instrument for in-process inference cost. The standalone measurement supplies a ceiling under its measured conditions. It does not select the final model size or establish performance under a loaded game.'),
    ('C12', 'minor', 'Added engine body scaling, an age system on durable people, and childhood capacity and activity distinctions. Age changes human capability and expression. Later child activity integration contains a reproduced zero-wound truthiness defect and does not inherit acceptance from this record.'),
    ('C13', 'minor', 'Added durable conditions, habits and moment-specific strain as person state. These inputs are intended to condition behavior and expression rather than assign successful outcomes. Later drug and brain-health integrations expose unresolved ownership and update-cadence defects.'),
    ('C14', 'minor', 'Introduced physical gestures through the engine action surface. Gestures render a chosen interaction and remain subject to action-queue ownership, interruption and completion. Later care composition demonstrates why successful queueing is insufficient evidence of a completed interaction.'),
    ('C15', 'patch', 'Placed the historical record on the county calendar so claims and events use the intended temporal context. This corrects the record surface; shared elapsed time and historical stepping were subsequently repaired in their own units.'),
    ('C16', 'kohai', 'Added the command check for whose instruction a person accepts, within what matter and with what grounds for refusal. Standing determines authority before execution. This contract is wider than obedience to a fixed leader label.'),
    ('C17', 'kohai', 'Connected remembered era and condition information to SAO-owned person state and removed accidental dependence on external mods for the county to stand on its own. Optional integrations supply inputs while the project retains responsibility for the person record.'),
    ('C18', 'minor', 'Added the pre-spawn county, ordinary pre-collapse activity, start-date alignment, construction choices and elapsed-year simulation. Ground observations were connected to historical processing. The original clock and cadence defects were later repaired; loaded geometry, complete dormant producers and scalable late starts remain subject to the substrate assessment.'),
    ('C19', 'minor', 'Introduced constrained decoding over the facts the person may express. The constraint prevents unsupported fact selection from the supplied vocabulary. Training still has to learn appropriate cognition and expression; passing the fact constraint alone does not measure either.'),
    ('C20', 'patch', 'Connected physical entry difficulty to the available ground and routed survivor orders through the shared command check. Entry execution follows a permitted and perceived opportunity; authority is not substituted for physical access.'),
    ('C21', 'kohai', 'Conditioned speech on what a person has actually learned, extended habit state to the player, and grounded condition figures for psychosis and insomnia. The work links existing person state to its consumers rather than declaring experience from a role or elapsed date.'),
    ('C22', 'patch', "Made participation depend on the person asking and made vehicle selection respect the prospective traveller's objection. A group plan is composed from individual willingness and available equipment; a refusal should not silently discard other acceptable options."),
    ('C23', 'patch', 'Distinguished observing a death from witnessing who caused it. Attribution must follow perceived evidence. The remaining witness-rule limitation is retained as open rather than converting proximity to the victim into knowledge of the killing.'),
    ('C24', 'patch', 'Made engine-dependent verification report unavailable ground explicitly, distinguished valid skips from vacuous success, aligned the CI action pair, and established protected-main publication through merged pull requests. These are repository mechanics, not new simulation capability.'),
    ('C25', 'patch', "Connected player looting to the depletion state used by the county. Resource availability must reflect world changes produced outside the NPC controller as well as the survivor's own actions."),
    ('C26', 'patch', 'Unified elapsed county hours across historical and live processing, advanced the years pass on that clock and made day-zero starts owe no prior years. The subsequent quantized-tick and catch-up repairs extend this foundation; cached controller time and day-versus-tick consumers remain under correction.'),
    ('C27', 'patch', 'Removed blanket completion claims and made documentation and its checks express the actual evidence boundary. Code-level checks, runtime observations and player acceptance have distinct scope. The later readiness audit found this discipline had drifted again.'),
    ('C28', 'minor', 'Added run boundaries, input conditions, county trajectory measurements and a county-owned random stream. These enable accountable observations of a simulation. A reproducible outcome can still come from a defective producer and is not automatically suitable training data.'),
    ('C29', 'kohai', 'Repaired company founding and dissolution, centralized death settlement, introduced the county sweep, gave people stable belief keys, enabled dormant visits to known people and assigned names when identities are created. These adjacent changes make dormant social activity and its measurement possible. Current admission and historical-state limitations remain documented in the later audit.'),
    ('C30', 'patch', 'Recorded SAO as the living simulation, ZAO as pathogen and turned execution, and Speakeasy as cognition data and models. The separation is a licensing and ownership boundary within one project. It does not create an additional approval negotiation between its own components.'),
    ('C31', 'kohai', 'Aligned dormant walking with elapsed time, derived occupied ground from where members actually return, and measured the cost of historical movement. A place relationship follows use. Measurement of this representation does not demonstrate loaded terrain execution or sustainable population scale.'),
    ('C32', 'minor', "Added the person's infection response, dormant infection exposure and examiner-dependent clinical observation. The course and its observations carry their own clocks and evidence. Later brain-health integration requires reconciliation with this existing mechanism and ZAO's authoritative pathogen state."),
    ('C33', 'patch', 'Recognized externally controlled bodies and verified the installed engine surfaces through which an NPC could drive. Former C82 was an evidence record with no mod-code change. This unit did not introduce autonomous driving; later C42 integrated it and the implementation audit found route ownership, steering and progress defects. Control ownership must remain exclusive through approach, boarding, travel and release.'),
    ('C34', 'minor', 'Added decision-moment capture beside the county sweep, recorded the first ratified work-word rows, exposed engine names and occupations to the harness, enriched belief provenance and retained the needs that conditioned a work decision. The later audit reproduced mutable snapshot leakage in this exporter. Approved choices remain ratified while their source conditioning requires review.'),
    ('C35', 'kohai', 'Defined the full life-simulation representation, organization and deference, claims distinguished from recognition, one causal branching graph and the dependency substrate. These are ratified contracts. They do not establish that the corresponding runtime producers exist or that a graph observer completes the simulation.'),
    ('C36', 'kohai', 'Added read-only summaries of isolation, place attachment and world development from existing person and place facts, with inspection and export surfaces. These observations expose inputs for decisions. They do not themselves produce affiliation, projects, provisioning or development.'),
    ('C37', 'kohai', "Integrated the pathogen-owned forms and performance contract, keyed cross-module rows by person and decision hour, recorded ZAO's state producers and overlays, admitted observed forms into SAO perception, and connected recognition records to county events. Sister implementation remains owned and verified there. Automatic recognition, persistence and the missing general decision producers remain subjects of the substrate assessment."),
    ('C38', 'kohai', 'Exposed organizational player claims through the shared claim surface, added dormant provisioning reads and generalized inhabited places to a ranked set derived from use. A player claim is recorded with its recognition and response. Inventory, physical access and sustained action consequences still require grounded producers in both representations.'),
    ('C39', 'patch', 'Corrected stale sibling-readiness statements and recorded settled dataset, integration and configuration rulings. The 112 work-word and 78 trade-hinge choices and the cross-module row contract were ratified. The remaining implementation work must follow those decisions without asking for them again.'),
    ('C40', 'kohai', 'Added personal need alongside trust in affiliation. Individual circumstances and experienced relationships condition company formation. The later repair removes fixed membership quotas and guards private knowledge, while broader affiliation producers and their evidence remain incomplete.'),
    ('C41', 'kohai', 'Defined the county tick from elapsed hours and added ordinary street activity with durable work locations. Rework remains required: controller time can stay cached during historical substeps, and the same stay-in decision has different loaded and dormant consequences.'),
    ('C42', 'kohai', 'Extended ordinary driving and wired the three associated configuration choices. The option wiring is retained. Driving requires substantial repair: its approach can cancel itself, unchanged status text cancels moving vehicles, promised passengers are not waited for, and rearward destinations can produce forward travel.'),
    ('C43', 'kohai', 'Connected afflicted return, retained capabilities and social responses to formed people. The audit reproduced bodies returned without controller adoption, absent dormant recovery, premature driving-competence stamps and automatic daily relocation without movement. Preserve the intended behaviors and reconstruct those mechanisms.'),
    ('C44', 'kohai', 'Added demands, surrender transfers, forced entry and raiding transport using existing execution primitives. The audit found that demand and response lack a completed transaction, surrender consequences precede transfer completion, and subsequent aggressor behavior does not consume the result. Rework is required.'),
    ('C45', 'kohai', 'Integrated credited event and gesture inputs and the optional randomized nuke with its default off. A reproduced care composition defect queues treatment before CPR, causing CPR to refuse the busy body. Retain the optional scope and repair the actual event-to-action chains.'),
    ('C46', 'kohai', 'Extended age-sensitive driving and everyday activities. The audit reproduced healthy children receiving wound fear because zero is truthy in Lua, and found activity participant discovery bypassing individual perception. Capacity and activity primitives remain useful while these decisions require repair.'),
    ('C47', 'kohai', 'Connected drug and ordinary consumption adapters, withdrawal, habits and optional real smoking. The audit reproduced a frozen-use clock that still removes dependency and daily processing that depends on the session-start minute. Optional body-owned counters and cumulative poison also need persistence and state-semantics correction.'),
    ('C48', 'kohai', 'Added held-key vehicle access, vehicle storage, animal care and combat-perception compatibility. Verified key and action adapters remain useful. Rework is required for compartment access and moving positions, animal admission into human beliefs, remote hutch extraction, installed prone-state keys and active-target revalidation.'),
    ('C49', 'kohai', 'Attempted the requested event-driven brain-health integration and visualization. The off switch is repaired, but the model remains disputed: update partition changes the outcome, authoritative pathogen state is read from the wrong owner, loaded health inputs are stale, and lifetime poison is reapplied as current damage. The scalar display and incomplete consumers do not fulfill the requested graph.'),
    ('C50', 'patch', 'Removed the rejected fixed-formula trajectory generator and repaired catch-up progress, company admission and diagnostic evidence refusal and provenance. Preserve the verified repairs and independent 90/365-day observations within their stated limits. No learned model or completed ML bridge resulted. The audit also identifies unresolved time consumers, population refill assumptions, the older decision exporter and missing life-simulation producers.'),
]

TIER_MEANINGS = [
    ("major", "Formal release, project-identity, or supported-compatibility boundary. No unit requires it; the odometer reaches it by cap."),
    ("minor", "A new player-visible simulation capability or a new authoring/runtime contract."),
    ("kohai", "A coherent extension, integration, or structural maturation of an existing capability."),
    ("patch", "An in-place correction, verification closure, or repair that does not move a capability boundary."),
    ("maturity", "`pre-alpha -> alpha -> beta -> rc`; moves on evidence (play receipts), never on arithmetic. Everything here is pre-alpha."),
]


def parse_version(text):
    m = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)\.(\d+)(?:-([\w.-]+))?", text.strip())
    if not m:
        raise ValueError(f"malformed version {text!r}")
    maturity = m.group(5)
    if maturity and maturity not in MATURITY_LADDER:
        raise ValueError(f"unknown maturity {maturity!r}")
    return [int(m.group(1)), int(m.group(2)), int(m.group(3)), int(m.group(4)), maturity]


def fmt(v):
    major, minor, kohai, patch, maturity = v
    return f"{major}.{minor}.{kohai}.{patch}" + (f"-{maturity}" if maturity else "")


def bump(v, tier):
    major, minor, kohai, patch, maturity = v
    if tier == "major":
        major, minor, kohai, patch = major + 1, 0, 0, 0
    elif tier == "minor":
        if minor == MINOR_CAP:
            major, minor = major + 1, 0
        else:
            minor += 1
        kohai = patch = 0
    elif tier == "kohai":
        if kohai == KOHAI_CAP:
            if minor == MINOR_CAP:
                major, minor = major + 1, 0
            else:
                minor += 1
            kohai = 0
        else:
            kohai += 1
        patch = 0
    elif tier in ("patch", "hotfix"):
        if patch == PATCH_CAP:
            patch = 0
            if kohai == KOHAI_CAP:
                kohai = 0
                if minor == MINOR_CAP:
                    major, minor = major + 1, 0
                else:
                    minor += 1
            else:
                kohai += 1
        else:
            patch += 1
    elif tier == "initial":
        pass
    elif tier.startswith("maturity-"):
        maturity = tier.split("-", 1)[1]
        if maturity not in MATURITY_LADDER:
            raise ValueError(f"unknown maturity tier {tier!r}")
    else:
        raise ValueError(f"unknown tier {tier!r}")
    return [major, minor, kohai, patch, maturity]


ROW = re.compile(
    r"^\| \[([A-Z]\d+)\]\((Batches/[^)]+)\) \| (\d{4}-\d{2}-\d{2}) \| (.*?) \| (.*?) \|$",
    re.M)


def log_rows():
    """Batch id -> (date, name, threads-cell), in log order. The index owns
    the names and dates; this tool never respells them."""
    rows = {}
    for m in ROW.finditer(BATCH_LOG.read_text(encoding="utf-8")):
        rows[m.group(1)] = (m.group(3), m.group(4), m.group(5))
    return rows


def replay():
    v = parse_version(REPLAY_START)
    trace = []
    for batch, tier, rationale in UNITS:
        v = bump(v, tier)
        trace.append((batch, tier, rationale, fmt(v)))
    return trace


def render():
    rows = log_rows()
    trace = replay()
    current = trace[-1][3]
    tip = UNITS[-1][0]
    nxt = f"{tip[0]}{int(tip[1:]) + 1}"
    lines = [
        "# Version map",
        "",
        "The regulatory version replay: the closed batch chronology classified",
        "one unit per batch, the coordinate computed under CAO's caps. The",
        "version is a machine (DR-013): nobody picks the number - to disagree",
        "with the coordinate, disagree with a tier in",
        "[`tools/version_replay.py`](tools/version_replay.py) and run",
        "`python tools/version_replay.py --write`; the map and `VERSION`",
        "follow. Border 80 refuses a tree whose stated versions disagree with",
        "the machine. Names, dates, and threads below come from",
        "[`BATCH_LOG.md`](BATCH_LOG.md), which owns them.",
        "",
        "| Field | Current state |",
        "|---|---|",
        f"| Schema | `{SCHEMA}` (CAO's `cao.version-model/1`, adopted) |",
        "| Form | `major.minor.kohai.patch-maturity` |",
        f"| Hard caps | minor {MINOR_CAP}; kohai {KOHAI_CAP}; patch {PATCH_CAP} |",
        f"| Replay start | `{REPLAY_START}` |",
        f"| Current version | `{current}` |",
        f"| Closed chronology | `A1-{tip}` |",
        f"| Next batch | `{nxt}` |",
        "| Executable source | [`tools/version_replay.py`](tools/version_replay.py) |",
        "",
        "## Tier meanings",
        "",
        "| Tier | Meaning here |",
        "|---|---|",
    ]
    for tier, meaning in TIER_MEANINGS:
        lines.append(f"| {tier} | {meaning} |")
    lines += [
        "",
        "## Chronological replay",
        "",
        "| Batch | Date | Tier | Resulting version | Name | Classification |",
        "|---|---|---|---|---|---|",
    ]
    for batch, tier, rationale, version in trace:
        date, name, _threads = rows[batch]
        lines.append(f"| `{batch}` | {date} | {tier} | `{version}` | {name} | {rationale} |")
    lines += [
        "",
        "## The former number",
        "",
        "`0.6.0.0` was declared at [B12] by the former policy (\"nineteen",
        "batches of shipped surface\") after the prior assistant bumped through",
        "hundreds of diary entries, and the former map walked to it in six flat",
        "minors. The machine replay of the recatalogued units supersedes that",
        "walk: under the caps, twelve minors of capability roll the major - the",
        "odometer crossed `1.0.0.0` at `A26` (the county wire, the thirteenth",
        "minor) by arithmetic, not by honor. The old number undersold the",
        "catalog; neither number was ever a release claim.",
        "",
        "## Maturity",
        "",
        "`pre-alpha` throughout. Individual play receipts remain scoped to their",
        "observed surfaces. Neither catalog arithmetic nor offline checks",
        "establish release maturity.",
        "",
        "## Next movement",
        "",
        f"`{nxt}` is the next batch. Its content determines its tier after it",
        "exists:",
        "",
        f"| If {nxt} is | Result |",
        "|---|---|",
    ]
    v = parse_version(current)
    lines.append(f"| patch or hotfix | `{fmt(bump(v, 'patch'))}` |")
    lines.append(f"| kohai | `{fmt(bump(v, 'kohai'))}` |")
    lines.append(f"| minor | `{fmt(bump(v, 'minor'))}` |")
    lines.append("")
    return "\n".join(lines)


def validate():
    faults = []
    rows = log_rows()
    unit_ids = [u[0] for u in UNITS]
    if unit_ids != list(rows.keys()):
        missing = [b for b in rows if b not in unit_ids]
        extra = [b for b in unit_ids if b not in rows]
        faults.append(
            "the tier table and BATCH_LOG.md disagree about the closed "
            f"chronology (unclassified: {missing or 'none'}; not in the log: "
            f"{extra or 'none'}; or the order differs)")
    trace = replay()
    current = trace[-1][3]
    stated = VERSION_FILE.read_text(encoding="utf-8").strip()
    if stated != current:
        faults.append(f"VERSION states {stated}; the replay derives {current}")
    if not VERSION_MAP.exists() or VERSION_MAP.read_text(encoding="utf-8") != render():
        faults.append("VERSION_MAP.md is not the machine's rendering - run "
                      "python tools/version_replay.py --write")
    for info in MOD_INFOS:
        m = re.search(r"^modversion=(.*)$", info.read_text(encoding="utf-8"), re.M)
        if not m or m.group(1).strip() != current:
            rel = info.relative_to(ROOT).as_posix()
            faults.append(f"{rel} states modversion="
                          f"{m.group(1).strip() if m else 'NOTHING'}; the replay derives {current}")
    return faults, current


def main():
    write = "--write" in sys.argv[1:]
    if write:
        VERSION_FILE.write_text(replay()[-1][3] + "\n", encoding="utf-8")
        VERSION_MAP.write_text(render(), encoding="utf-8")
    faults, current = validate()
    print("=" * 74)
    print("THE VERSION IS A MACHINE")
    print("=" * 74)
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  80) version replay: {len(UNITS)} closed units classified; the machine")
    print(f"      derives {current}, and VERSION, the map, and mod.info all state it")
    return 0


if __name__ == "__main__":
    sys.exit(main())
