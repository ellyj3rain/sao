#!/usr/bin/env python3
r"""Border 80 - the version is a machine, and the machine's output is stated.

The former version was hand-declared: 0.6.0.0 was picked at [B12] by a
policy sentence ("nineteen batches of shipped surface") and the old
VERSION_MAP walked to it in six flat minors so the number looked
earned. The operator's instruction (DR-013): the coordinate is not
picked, it is computed - classify evidenced delivered scope, run the
replay under CAO's caps, and the output is the version.

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
A/B retain the tier table below. Current C product tiers and rationales
come from Batches/C_PRODUCT_CATALOGUE.json. Its generation-qualified
sources retain separate implementation, verification and publication
status; a version tier does not close every remaining D obligation.
Delivered D tiers follow the C catalogue in POST_C_UNITS.
NEXT_BATCH names the next unconsumed D identifier.
Names, dates and threads come from BATCH_LOG.md. The
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

from catalogue import (CatalogueError, MANIFEST, index_rows, load_catalogue,
                       validate_catalogue, PRODUCT_MANIFEST, load_product_catalogue,
                       validate_product_catalogue)

ROOT = pathlib.Path(__file__).resolve().parent.parent
BATCH_LOG = ROOT / "BATCH_LOG.md"
VERSION_FILE = ROOT / "VERSION"
VERSION_MAP = ROOT / "VERSION_MAP.md"
MOD_INFOS = (ROOT / "mod" / "mod.info", ROOT / "mod" / "42.20" / "mod.info")

SCHEMA = "sao.version-model/3"
MINOR_CAP = 12
KOHAI_CAP = 16
PATCH_CAP = 24
MATURITY_LADDER = ("pre-alpha", "alpha", "beta", "rc")
REPLAY_START = "0.1.0.0-pre-alpha"

# Retained A/B (batch, tier, rationale) rows. C is read from the current
# product manifest; shared contracts and historical C generations remain unchanged.
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

]

TIER_MEANINGS = [
    ("major", "Formal release, project-identity, or supported-compatibility boundary. No unit requires it; the odometer reaches it by cap."),
    ("minor", "A new player-visible simulation capability or a new authoring/runtime contract."),
    ("kohai", "A coherent extension, integration, or structural maturation of an existing capability."),
    ("patch", "An in-place correction, verification closure, or repair that does not move a capability boundary."),
    ("maturity", "`pre-alpha -> alpha -> beta -> rc`; moves on evidence (play receipts), never on arithmetic. Everything here is pre-alpha."),
]


# Land this delivered unit only with D1's actual closure record and index row.
POST_C_UNITS = [
    ("D1", "minor", "Shared person-specific conceptual reasoning and source-bound prior-history admission establish a live authoring/runtime contract."),
]
NEXT_BATCH = "D2"


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


def log_rows():
    """Batch id -> (date, name, threads-cell), in log order. The index owns
    names and dates. Malformed and duplicate indexed rows are faults."""
    return {batch: (row["date"], row["name"], row["threads"])
            for batch, row in index_rows(BATCH_LOG.read_text(encoding="utf-8")).items()}


def classified_units(manifest=None):
    if manifest is None:
        manifest = load_product_catalogue(ROOT)
        faults = validate_product_catalogue(ROOT, manifest)
        if faults:
            raise CatalogueError("; ".join(faults))
    return UNITS + [(unit["id"], unit["tier"], unit["rationale"])
                    for unit in manifest["units"]] + POST_C_UNITS


def catalogue_inputs():
    """Validate source preservation and index agreement before any stamp write."""
    manifest = load_product_catalogue(ROOT)
    faults = validate_product_catalogue(ROOT, manifest)
    if faults:
        raise CatalogueError("; ".join(faults))
    post_ids = [unit[0] for unit in POST_C_UNITS]
    if post_ids != [f"D{i}" for i in range(1, len(POST_C_UNITS) + 1)]:
        faults.append("delivered D units must be unique D1..Dn in chronological order")
    if any(tier not in ("minor", "kohai", "patch", "hotfix")
           or not isinstance(rationale, str) or not rationale.strip()
           for _batch, tier, rationale in POST_C_UNITS):
        faults.append("delivered D units require a scope tier and nonempty rationale")
    if NEXT_BATCH != f"D{len(POST_C_UNITS) + 1}":
        faults.append("NEXT_BATCH must name the next unconsumed D identifier")
    indexed = index_rows(BATCH_LOG.read_text(encoding="utf-8"))
    units = classified_units(manifest)
    ids = [unit[0] for unit in units]
    if NEXT_BATCH in indexed:
        faults.append("NEXT_BATCH must remain unconsumed in BATCH_LOG")
    if ids != list(indexed):
        faults.append("tier table and BATCH_LOG disagree about classified delivered scope coverage/order")
    for unit in manifest["units"]:
        row = indexed.get(unit["id"])
        if row and any(row[key] != unit[field] for key, field in
                       (("path", "recordPath"), ("date", "date"), ("name", "name"))):
            faults.append(f"{unit['id']} BATCH_LOG path/date/name differs from the current manifest")
    if faults:
        raise CatalogueError("; ".join(faults))
    rows = {batch: (row["date"], row["name"], row["threads"])
            for batch, row in indexed.items()}
    return manifest, units, rows


def replay(units=None):
    v = parse_version(REPLAY_START)
    trace = []
    for batch, tier, rationale in (classified_units() if units is None else units):
        v = bump(v, tier)
        trace.append((batch, tier, rationale, fmt(v)))
    return trace


def render(inputs=None):
    manifest, units, rows = inputs if inputs is not None else catalogue_inputs()
    trace = replay(units)
    current = trace[-1][3]
    tip = units[-1][0]
    nxt = NEXT_BATCH
    lines = [
        "# Version map",
        "",
        "The regulatory version replay classifies evidenced delivered scope",
        "once per coherent product batch under CAO's unchanged caps. A/B retain",
        "their original replay. Current C products partition the retained source",
        "chronology into adjacent capability units. The separate 35-contract",
        "ownership map preserves shared boundaries without version credit. Delivered D units",
        "follow C in chronological order. Delivered means",
        "implemented: publication, rendered acceptance and remaining D work",
        "retain their separate component states. The",
        "version is a machine (DR-013): nobody picks the number - to disagree",
        "with the coordinate, disagree with the applicable A/B tier in",
        "[`tools/version_replay.py`](tools/version_replay.py), including its",
        "POST_C_UNITS for D, or C tier in",
        f"[the product manifest]({PRODUCT_MANIFEST}), state its scope and rationale, and run",
        "`python tools/version_replay.py --write`; the map and `VERSION`",
        "follow. Border 80 refuses a tree whose stated versions disagree with",
        "the machine. Names, dates, and threads below come from",
        "[`BATCH_LOG.md`](BATCH_LOG.md), which owns them.",
        "",
        "| Field | Current state |",
        "|---|---|",
        f"| Schema | `{SCHEMA}` (CAO arithmetic with explicit C catalogue adaptation) |",
        "| Form | `major.minor.kohai.patch-maturity` |",
        f"| Hard caps | minor {MINOR_CAP}; kohai {KOHAI_CAP}; patch {PATCH_CAP} |",
        f"| Replay start | `{REPLAY_START}` |",
        f"| Current version | `{current}` |",
        f"| Classified delivered scope | `A1-{tip}` |",
        f"| Current C generation | `{manifest['generation']}` |",
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
        "## Delivered-scope replay",
        "",
        "| Batch | Date | Tier | Resulting version | Name | Classification |",
        "|---|---|---|---|---|---|",
    ]
    for batch, tier, rationale, version in trace:
        date, name, _threads = rows[batch]
        lines.append(f"| `{batch}` | {date} | {tier} | `{version}` | {name} | {rationale} |")
    lines += [
        "", "## Current C products and retained source status", "",
        "Each C product tier credits its coherent capability once. Each retained",
        "source belongs to one chronological product; shared contract edges grant",
        "no additional version credit. Source labels below belong to the archived",
        "120-record generation; they are not current C identifiers.", "",
        "| Current product | Classification | Retained chronological sources |",
        "|---|---|---|",
    ]
    shared = load_catalogue(ROOT)
    for unit in manifest["units"]:
        scopes = unit["rationale"].replace("|", "\\|")
        credited = []
        for contribution in unit["sourceContributions"]:
            source = contribution["sourceId"]
            status = shared["sources"][source]
            credited.append(f"`{source}` ({status['implementation']}; "
                            f"{status['verification']}; {status['publication']})".replace("|", "\\|"))
        lines.append(f"| [{unit['id']}]({unit['recordPath']}) | {scopes} | {'; '.join(credited)} |")
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
        f"`{nxt}` is the next unused catalogue identifier. Current open extensions",
        "remain with their owners; this projection does not close them or start",
        "another batch. Subsequent delivered work determines its own tier:",
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


def validate(inputs=None):
    faults = []
    try:
        inputs = inputs if inputs is not None else catalogue_inputs()
    except (CatalogueError, OSError) as exc:
        return [str(exc)], None
    _manifest, units, _rows = inputs
    trace = replay(units)
    current = trace[-1][3]
    stated = VERSION_FILE.read_text(encoding="utf-8").strip()
    if stated != current:
        faults.append(f"VERSION states {stated}; the replay derives {current}")
    if not VERSION_MAP.exists() or VERSION_MAP.read_text(encoding="utf-8") != render(inputs):
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
    print("=" * 74)
    print("THE VERSION IS A MACHINE")
    print("=" * 74)
    try:
        inputs = catalogue_inputs()
        if write:
            VERSION_FILE.write_text(replay(inputs[1])[-1][3] + "\n", encoding="utf-8")
            VERSION_MAP.write_text(render(inputs), encoding="utf-8")
        faults, current = validate(inputs)
    except (CatalogueError, OSError) as exc:
        faults, current = [str(exc)], None
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  80) version replay: {len(inputs[1])} delivered units classified; the machine")
    print(f"      derives {current}, and VERSION, the map, and mod.info all state it")
    return 0


if __name__ == "__main__":
    sys.exit(main())
