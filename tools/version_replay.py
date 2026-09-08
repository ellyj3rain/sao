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
evidence, never on arithmetic; SAO is pre-alpha throughout because no
batch has a play receipt.

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
    ("A1", "initial", "The governed repository itself: doc-pack, instruction surface, ratified pillar composition; no framework code."),
    ("A2", "kohai", "The verified engine substrate (F-001..F-007) before anything built on it; preparation, not a shipped capability."),
    ("A3", "minor", "The first survivor in the world: spawn, walk, remove - the first player-visible capability, and the mod tree ships."),
    ("A4", "minor", "The compiled agent, the bridge, and ENGINE_CONTRACT: the runtime contract everything renders and calls through."),
    ("A5", "minor", "The four pillars as code: perception with provenance, bounded disposition, standing, the controller composition."),
    ("A6", "minor", "Combat both directions and a persistent population in real towns: the framework becomes something a player meets."),
    ("A7", "kohai", "Genesis matured to the map's own spawn-region draw, off the forbidden refill shape; policy numbers become sandbox options."),
    ("A8", "minor", "The needs layer through the engine's own timed actions - eating, drinking, interruptible; grudges, testimony, gear errands."),
    ("A9", "minor", "The voice surface and real territory: claims, permission, first aid, sharing - with the one key schema (DR-005) under it."),
    ("A10", "kohai", "Multi-floor work, the ranged doctrine, and the F-011 sight repair: the loop polished, no new boundary."),
    ("A11", "kohai", "Hibernation made whole (F-013), dormant drift, estates, sleep: persistence matured into the person outliving the scene."),
    ("A12", "minor", "The social economy opens: gifts, barter, property with teeth and manners, dormant encounters."),
    ("A13", "kohai", "Debts, gunfire attribution, coordinated flight, companionship: the economy and relations grow edges."),
    ("A14", "minor", "The society arc ratified and built (DR-006): claims and lessons, leaders, settlement, membership, habits, bonds."),
    ("A15", "kohai", "Belief-gated permission (DR-007): the permission layer's last free knowledge made earned; epistemics matured."),
    ("A16", "patch", "The approval-chain repair (F-023) and the first live witness: verification closure on the existing line."),
    ("A17", "minor", "Inhabitant adoption: other mods' live humans join the social fabric with records, contact-scaled pasts, split clocks."),
    ("A18", "minor", "The census contract (DR-010/DR-011): 1993 labor distribution, profession-keyed origins, compatibility from first principles."),
    ("A19", "minor", "The workday taxonomy and elections: every tick carries a pressure answer; a mannequin is structurally impossible."),
    ("A20", "kohai", "Feuds, full-person talk, dormant attrition: politics closes its loop and gains its voice."),
    ("A21", "patch", "The hardening rotation: bulkheads, fault gates, F-031..F-034 - repair and closure, no boundary moved."),
    ("A22", "kohai", "Schism's mechanics, the war chronicle, the invariant sweep: politics matured under its audit trail."),
    ("A23", "kohai", "The offline equilibrium harness: 120 deterministic days prove the county's physics without the game; instrument, not capability."),
    ("A24", "kohai", "The engine rotation re-read end to end; full names and per-person texture make the people legible."),
    ("A25", "kohai", "Counsel, ration policy, the governance chronicle: the commons matured at community scale."),
    ("A26", "minor", "The county wire, 101.2, both directions: a new medium, built on the engine's own radio pattern."),
    ("A27", "kohai", "Player chairmanship, the arrival draw, war parties: the political physics completed."),
    ("A28", "minor", "Derived possessions: the convenience tables die; place provides, person spots - a new derivation contract."),
    ("A29", "minor", "Day-zero innocent-county mode: a new way to start the world, innocent by construction."),
    ("B1", "minor", "The venture as a designed feature-complex: motor pool, departure argument, terms, crews, briefings."),
    ("B2", "kohai", "Skill levels drive assignment and rates across the existing work; one truth, two read paths."),
    ("B3", "minor", "The bitten arc: bite visibility, the house's answer from character, turning recognition, promises kept."),
    ("B4", "minor", "Farming through vanilla timed actions: the renewable arm of the material economy."),
    ("B5", "patch", "Performance and sensor audits; three borders born - cost and truthfulness closure."),
    ("B6", "minor", "Water as the second material axis and fire as a need: stores, runs, the shutoff day, hearth tending and lighting."),
    ("B7", "kohai", "Council abandonment and the wound's full life: decisions the state earns, on existing machinery."),
    ("B8", "kohai", "Standing moves both directions: endorsement, decay, lapse, walking out - the ratchet removed."),
    ("B9", "kohai", "The engine's own chemistry colors meetings; wire bulletins land as told knowledge in real receivers."),
    ("B10", "patch", "The foreign key domain contained, wounds persist through the pack, the county lets go at player death - repairs."),
    ("B11", "kohai", "Housemate teaching and player barter: the circle law's cost and the player in the economy."),
    ("B12", "kohai", "The verb wall collapses into the game's own menu idiom; the index completed - surface maturation."),
    ("B13", "kohai", "Need-driven promotion at election: the house reads its own counted claims and adapts."),
    ("B14", "kohai", "The repository gate and pre-commit hook: discipline made mechanical, proven by breaking the tree."),
    ("B15", "kohai", "Corpse looting with dignity rules: the one place dignity outranks need."),
    ("B16", "patch", "The undeclared-identifier audit and the edit-verification law: instruments and closure."),
    ("B17", "kohai", "Night-light gating and weather's weight: dark and storms shape the existing behaviors."),
    ("B18", "kohai", "The Ledger learns live content; the player claims ground and homes companions through existing machinery."),
    ("B19", "kohai", "Player teaching, vehicle crews, venture staffing, night watch: the player joins the work."),
    ("B20", "kohai", "Severity-first aid, the distress cry and its cost, the cook designation: professional shapes on existing lines."),
    ("B21", "kohai", "Population exchange with the zombie pool, porch music, evidence-based judging: composition with the world."),
    ("B22", "kohai", "Keepsakes and reading, derived work stations, skill-book study: identity beyond employment."),
    ("B23", "minor", "Government's complete shapes: five forms, deputies, turns, scarcity asks, division-driven schism."),
    ("B24", "patch", "The dead pact layer revived (one-character typo) and the creed distribution corrected - repairs with their border."),
    ("B25", "patch", "Work-judgment probing, quarrel drivers, identity-gate corrections: probing and repair."),
    ("B26", "patch", "Engine item-vocabulary corrections: four dead literals replaced with the engine's own surfaces."),
    ("B27", "minor", "The player as channel participant: one experience loop, inbound and outbound, restoring a missing player-visible contract."),
    ("B28", "kohai", "Newcomer reach, arrival rates, registers, trespass teaching: the road matured and measured."),
    ("B29", "patch", "Road-frequency display, ledger paging, window sizing: small surfaces made honest."),
    ("B30", "patch", "Publishing metadata and the false description repaired; attribution made precise."),
    ("B31", "patch", "The duplication border, fuel accounting, protocol borders: drift measured before unified."),
    ("B32", "patch", "The between-time chain repaired, mirror coverage, analysis discipline: the county's habits fixed with their instrument."),
    ("B33", "patch", "The two radii reconciled into one honest band; the shipped jar found stale and made current."),
    ("B34", "patch", "Menu gating, measured claim extents, queue-drop detection: silent failure classes closed."),
    ("B35", "kohai", "The claim lifecycle completed: unlearning by proximity, protection, carry-light wired to its walk."),
    ("B36", "patch", "The save-field guard, deploy survival, the catch audit: the discipline layer hardened."),
    ("B37", "patch", "The county's truths made singular: one band constant, age arithmetic, death causes, shutoff revision."),
    ("B38", "minor", "The county's scale derived from the installed map and the census graded against the real 1990 - assumption replaced by contract."),
    ("B39", "minor", "Acquisition provenance completed (unknown fails the gate) and places spent by being visited - scarcity becomes a model."),
    ("B40", "patch", "Named constants, lived provenance at genesis, the perk vocabulary map: names that keep arithmetic honest."),
    ("B41", "patch", "The gate audits itself: all mirrors run, and the player's own perception repaired after 79 batches blind."),
    ("B42", "patch", "The silent surfaces hunted as a class; census authority ratified (DR-012)."),
    ("B43", "patch", "The jar stamps its own version, session-state truth gated, the dormant economy's unwired halves wired."),
    ("B44", "patch", "Legible option labels and the Kahlua runtime boundary learned from a live crash."),
    ("B45", "patch", "Distance naming, Kahlua-gated compilation, the nil-name repair, the neighbour narration hold."),
    ("B46", "patch", "The player-reply channel repaired: two stacked defects that silenced the conversational surface."),
    ("B47", "patch", "The log-reading defect pass: census rebuilt true, noise measured down, boot truth."),
    ("B48", "patch", "The distribution arc: everybody was the same person - the hash pathology found by instrument and fixed."),
    ("B49", "patch", "Frame-time pacing disclosed on every claim; the voice cooldown moved to the wall clock; decay verified."),
    ("B50", "patch", "Engine behavior facts re-asked of the machine each run; the bridge throw contract graphed."),
    ("B51", "patch", "The dead stop growing quietly: death-time cleanup, budgeted walks, derived art, the save protocol border."),
    ("B52", "patch", "The era's integrity closed: derived counts, aligned names, the scout read whole, the answer domain sealed."),
    ("C1", "patch", "The catalog walked against the tree: 152 index links corrected, the maps drawn and held by Border 79, the gate made caller-independent."),
    ("C2", "kohai", "The version machine (DR-013): CAO's model adopted, the tier table as the one input, Border 80 holding every stated version to the replay."),
    ("C3", "kohai", "One person, one name (DR-014): the placeholder stamp gone, papers named by the menu's renderer, the neighbour's people keep his name, one menu folds his verbs through his own hands."),
    ("C4", "kohai", "The follow crosses windows and fences through the engine's own climbs; vehicle boarding pairs the seat with the mesh, folds into follow, and answers a clear order."),
    ("C5", "kohai", "World text becomes a person talking: the tell speaks the thing itself, coordinates leave every mouth, the innocent assert nothing - and the swallowed-function class is repaired and bordered."),
    ("C6", "kohai", "The inspect harness: a normal-launch panel and bound key over every store - seen/heard/told, standing, needs, last decision, tick cost - to the one JSONL, reading everything and teaching nothing."),
    ("C7", "kohai", "Superimposed, not beside (DR-015): the neighbour's per-survivor root stays as the person's one menu, retitled to the name and rebuilt from the county - never stripped, never doubled."),
    ("C8", "kohai", "The turn is real (DR-016): every dead shell reaches the engine's own die() through the corpse net, the person id rides modData through the engine's own copies, and recognition keys on what survives the turn - the [B3] arc's structural repair, javap-grounded (F-044/F-045)."),
    ("C9", "patch", "The pool is only the fungible crowd (F-046): one deletion-grade identity predicate, failing closed, at every consumer of the zombie list that deletes or choreographs - a spawn can no longer quietly take a person, and the removeFromWorld census is closed (Border 88)."),
    ("C10", "patch", "The promise swings at the body: the mercy kill aims at the one risen body carrying the person's [C8] mark, misses honestly, and carries the promise instead of taking the nearest stranger (Border 89)."),
    ("C11", "patch", "The bite kills on the engine's clock (F-047): the invented dormant formula replaced by the deterministic infection window read off the body or mirrored with citation; dormant turning mirrors shouldBecomeZombieAfterDeath (Border 90)."),
    ("C12", "kohai", "The front end speaks player (DR-017): mode-sentinels became worded switches, the coded pressure scale became the engine's own worded enum, decode tables and sentinel apologies left every label and tooltip; representation split from implementation at one declared seam (Border 91)."),
    ("C13", "patch", "No Claude-isms in the copy (DR-018): the sandbox surface rewritten in plain language, the register struck from the Ledger, and Border 92 freezing player-facing copy to a verbatim ratified declaration."),
    ("C14", "patch", "The sweep, round one: the paid-for defect classes hunted with real denominators - 216 pcall pairs, 262 call targets, 63 clock fields, every engine-authority comment - zero findings; the precise instrument promoted to Border 93, the imprecise one recorded as a method."),
    ("C15", "minor", "Whole minds survive the reload (DR-020): the perception store binds to ModData, the tick axis rebases once on load while the hours axis crosses intact, and every belief a survivor holds persists with the world - a new persistence contract for the mind (Border 94)."),
    ("C16", "kohai", "The dead census (DR-021 mechanism B, first half): an inert instrument reads the fungible crowd, the identity-bearing bodies, and the loaded and mapped extents through verified surfaces; the telemetry line carries density and projection with the sampling assumption stated (Border 95)."),
    ("C17", "kohai", "The crowd ledger (DR-021 state agreement): every pool take counted durable, restitution debt-bounded and paced on distant town ground through the engine's own virtual add, the dial off by default until the census has measured (Border 96)."),
    ("C18", "patch", "The first play receipts (F-048/F-049): a re-issued order no longer restarts the route it is already walking - which was cancelling window and fence climbs mid-transition and flipping survivors between FLEE and IDLE 292 times a session - plus the two exceptions the operator's log exposed."),
    ("C19", "kohai", "Partial receipts are receipts (DR-025): RECEIPTS.md records what play settles one observation at a time, the perpetual-untested blanket claim is banned from the doc-pack, and the day's own sessions seeded R-001/R-002 (Border 97)."),
    ("C20", "minor", "The county takes them whole (DR-022/023/024): the neighbour's people absorbed at world start and at birth through his one verified spawn seam, removed never killed, carried whole into county records, truth mirrored back, his caps neutralized and blocked on screen, verb parity kept (F-051/F-052, Border 98)."),
    ("C21", "patch", "Fail completely, never his way (DR-026): the absorption wrap spawns nobody on failure - loudly, with the Ledger carrying the seam - and never falls back to the neighbour's spawn; Border 98 inverted to hold it, its control the overruled [C20] draft."),
    ("C22", "patch", "The switch gates the field: the manual number fields on the county's own page grey and lock until their switch is on - vanilla's per-frame gating idiom, held by Border 91."),
    ("C23", "patch", "Deleted, not greyed: the overridden neighbour dials are removed at the settings-table seam before any row is built (the operator's restatement of DR-023); the [C20] grey-hook retired and refused by Border 98; DR-027 (no leash constants) recorded for the next substantive batch."),
    ("C24", "patch", "The anchor was never there (F-053, R-003): [C22]'s gating hook hung on a vanilla per-file LOCAL and silently never attached - reattached through the real global SandboxOptionsScreen onto the page panel instance, cannot-attach paths made loud through the Seams, Border 91 refuses the dead anchor with the photographed [C22] tree as its control."),
    ("C25", "minor", "Need reaches for what they know (DR-027): the ErrandRadius dial deleted everywhere - the probe is a named perception span, all four live needs and the dormant day fall back to the nearest KNOWN offering under the same property law, horizons derive from the engine's own cell, held knowledge revalidates and absence expires (Border 99)."),
    ("C26", "patch", "The click lands and the line holds (R-005/R-006, F-054, DR-028): talk answers bypass the murmur guards and the trust wall falls to the advertised split, dressing is outcome-verified by worn count with retry and fallback, and the wake law pushes foreign-claim wakes out, moves homes off held ground, and seats one body per square (Border 100)."),
    ("C27", "minor", "What one person knows, as one surface (SPEECH_ML_DESIGN.md rung 1): SAO_Knowledge answers nine topics with provenance and age, bundles the ratified conditioning (eight axes, trust, the moment), stays read-only by the one-loop law, is driven offline in the engine's own VM by Border 101, and the inspect panel gauges a person through it."),
    ("C28", "kohai", "The inference budget instrument (SPEECH_ML_DESIGN.md): a deterministic model-shaped workload timed on the game's own JVM from the debug menu, reported under BUDGET - the measurement the sizing decision cites; instrument, not capability (A23's precedent)."),
    ("C29", "minor", "The body is scaled from inside the animation player (DR-032): a Byte Buddy exit advice on the animation player's model-transform build applies a per-person size held only on SAO's own shell, uniform about the feet; the bridge sets and reports it, the body takes it from the age once dressed, the harness clicks it, and Border 104 weaves the installed class off the game and verifies it - the child bands follow in the age batch."),
    ("C30", "minor", "Age is a system on the county's people (DR-032): the bands run from six to ninety weighted from the 1990 resident population, five life stages (Getting Old's, credited) drift the living every ten minutes on the engine's own stats, the age decides the work, the pace and the size, and the old die of it on the life table (NCHS 1997, the nearest machine-readable year) - Border 105 drives it in the engine's own VM."),
    ("C31", "minor", "The child's day (DR-032): Growing Up's fear floor by age with the night, the comfort object and the kills that harden, read by the disposition's decisions and held on the engine's panic; literacy by the school years lived; the experience throttle on the shell and the birthday floors on strength and fitness; the kit from the child's own temperament; the child's head - Border 106 drives it in the engine's own VM."),
    ("C32", "minor", "Conditions are facts about a person (DR-032): drawn at the record's prevalence and gated by age, the mind's and the body's conditions bend the axes, add fear, set how long a belief is kept, what the body carries every ten minutes, what the skills lose and what a book costs; named in plain words on every surface; the two Build 42 condition mods required for the player's side - Border 107 drives it in the engine's own VM."),
    ("C33", "minor", "Habits are facts about a person (DR-032, S6): the drinker at the record's prevalence with The Alcoholic's phases, the drink taken through the engine's own fluid action or found where one is, the habit lost after three weeks dry and gained by drinking often; the users the county fell with on N and C's schedule, gone by the twentieth clean day; what a habit carries every pass, and the day that settles it - Border 108 drives it in the engine's own VM."),
    ("C34", "patch", "The moment carries the strain (DR-033): the knowledge surface reads the situation the controller's pressure names and whether the speaker is spent, beside the axes, trust and the moment; Decision 5 amended with the register floors under strain; Border 101 asks for both."),
    ("C35", "minor", "The county's gestures (DR-034): existing art copied with permission and credited - Hobbies' conversation gestures, sitting loops, instrument plays and dances, Week One's serving, coughs and claps - bound by SAO's own nodes and wired to the meeting, the voice's events, the evening seat and the porch tune; Border 109 holds file, node and name to each other."),
    ("C36", "minor", "The record on the county's calendar (DR-031, Day Zero slice 7): every vanilla channel re-keyed once per save to begin on the save day July 9, 1993 falls on, through the engine's own surface; every paper a container is filled with dated to the newest issue printed by the county's day or taken off the shelf; a sandbox switch on by default - Border 110 runs the arithmetic off the game against the installed jar."),
    ("C37", "minor", "An order lands through standing (DR-033, ruled): every ask the player makes of a person goes through SAO_Command - CAO's obedience check on the Standing that exists, a proven hand standing as a second, the envelope's own refusals - voiced with its reason and seen; Border 111 runs the check in the engine's own VM over the county sampled."),
    ("C38", "minor", "The era remembered (Day Zero slice 6): the knowledge surface carries before - born, the war, where from, home, innocent or hardened - and the day it started - the person's own first horror with its date and what it taught, the county's stamps aired as news, the record's first day for a radio owner - as claims with provenance; the chronicle reads its days as the county's own dates through the same calendar; Border 112 drives both topics in the engine's own VM."),
    ("C39", "minor", "The conditions are SAO's own (DR-032 amended): the two required mods are gone and SAO registers the county's conditions as engine character traits from shared Lua, vanilla's where vanilla has one, every cost taken from the vanilla trait its shape is anchored to; a survivor's drawn conditions ride their shell as traits, the player's chosen ones are asserted and driven through the same functions; Border 113 holds it and Border 107's requirement seam is inverted."),
    ("C40", "minor", "The county stands on its own (DR-035): nothing of this mod runs through another survivor mod unless the player asks - the absorption, the menu superimposition and the prompt hold are all behind switches that default off, so a fresh world reaches into another mod zero times; what stays always on calls none of their code, the manifests require nothing but the loader, and the description no longer claims a requirement [C39] removed; Border 114 holds the law."),
    ("C41", "minor", "The world before the spawn (DR-036, one precondition): on a save that has never been settled genesis reaches its target in one pass instead of six people at a time, and it runs ahead of the band in the tick, so the county exists in full before the first body is materialised; the pace and its unit slack are named once and stand unchanged for refill; Border 115 holds the budget, the flag and the ordering law the claim rests on."),
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
        "`pre-alpha` throughout: maturity moves on play receipts and no batch",
        "has one. The offline harnesses and the border gate are what stand in",
        "the meantime, and they are not play.",
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
