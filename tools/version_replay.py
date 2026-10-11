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
at the cap rolls the coordinate above without declaring a completed
feature collection or release. Maturity moves on
evidence, never on arithmetic; SAO remains pre-alpha; individual
play receipts do not establish release maturity.

Tiers: minor = completed coherent feature/module scope with required integration;
kohai = coherent building progress within an unfinished feature/module;
patch = in-place correction. An API, action, artifact or child closure alone
does not establish feature completion. Major semantic boundaries are
operator-selected; mechanical carries do not declare a release.

WHAT IS DERIVED AND WHAT IS INPUT
---------------------------------
A/B tiers are reconciled against feature scope in the table below. Current C product tiers and rationales
come from Batches/C_PRODUCT_CATALOGUE.json. Its generation-qualified
sources retain separate implementation, verification and publication
status; a version tier does not close every remaining D obligation.
Delivered D capability tiers follow C in POST_C_UNITS. Closed parent
aggregations are recorded separately in POST_C_AGGREGATIONS and grant no tier.
NEXT_BATCH names the declared unconsumed scope; an explicit active parent keeps
that identity while delivered children close independently.
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

from catalogue import (CatalogueError, MANIFEST, index_rows, active_batch, batch_parent,
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
    ('A1', 'initial', 'Initial repository baseline with no framework code; retain initial rather than manufacturing a feature credit.'),
    ('A2', 'kohai', 'Establishes engine truths and unblocks construction: meaningful foundation advance before the embodied framework is complete.'),
    ('A3', 'kohai', "The one-body G1 gate, mod layout and snapshot-back are building pieces. A4/A5 still supply native rendering and composed behavior before A6's integrated framework outcome."),
    ('A4', 'kohai', 'Enables the native delivery path for the still-building survivor framework. A bridge/build contract alone does not earn a completed-feature minor.'),
    ('A5', 'kohai', 'The four pillars run as substrates with movement transplanted; their integrated embodied survival outcome arrives in A6.'),
    ('A6', 'minor', 'Closes the initial integrated framework: native offense/incoming pressure, perception provenance, real town population, flight/traversal and durable death compose into survivors the player can meet.'),
    ('A7', 'kohai', "Meaningful extension of A6's populated world and emerging society: origin/refill corrected while trust, equipment, homing and company acquire consumers."),
    ('A8', 'minor', 'A complete needs loop reads real stats and satisfies them through interruptible native eating/drinking. Standing-gated grudges, testimony and gear errands integrate that outcome.'),
    ('A9', 'kohai', 'Keys, Say moments, initial territory, bandaging and spare-food sharing advance the still-forming social/property collection; A12/A14 provide its broader enforcement and organization closure.'),
    ('A10', 'kohai', 'Multi-floor work, gun doctrine and panic broadcasts extend the established loop; scanner, water-Z and orphan-route defects are supporting repairs.'),
    ('A11', 'kohai', "Whole packs, dormant metabolism/drift, estates and moving-in extend A6's persistent people. F-013/F-014 repairs do not create another framework feature credit."),
    ('A12', 'minor', 'Completes a coherent exchange/property outcome: objections respected, claims constrain taking, noticed gifts and real barter/debts connect goods to relationships and dormant encounters.'),
    ('A13', 'kohai', 'Adds consequences/consumers to existing exchange and ties; leadership remains deferred and the society collection is still advancing toward A14.'),
    ('A14', 'minor', 'S1-S7 join acquired pasts/lessons, consumed leadership/succession, named settlement, player membership, native habits and consequential bonds: documented collection closure beyond APIs.'),
    ('A15', 'kohai', "Post-arc corrections plus earned place permission, teaching and talk deepen existing society/standing; they preserve A14's credit rather than repeat it."),
    ('A16', 'patch', 'Repairs jar approval and foreign-human discrimination, with scale tuning and witness of prior work; no separate completed feature scope is established.'),
    ('A17', 'minor', 'Completes a coexistence mode: exact foreign records and contact-scaled pasts participate in exchange, knowledge, company and mourning while original foreign-body ownership is preserved.'),
    ('A18', 'minor', 'Completes census/origin generation through installed profession discovery, grounded weights, stable mod classification, claim affinities, descriptor truth and profession-keyed home/bond origins.'),
    ('A19', 'minor', 'Deferred workday seams close: each state answers pressure, elections deal work, medics/watch/foragers/quartermasters perform real rounds, and rest/aid/player requests enter the same loop.'),
    ('A20', 'kohai', 'Earned feuds gain spatial/economic consumers and talk conveys the person; dormant attrition deepens persistent society while governance keeps advancing.'),
    ('A21', 'kohai', 'Mixed repair and meaningful advance: internal hostility creates new companies/ground and road elections split houses, with feud history/Chronicle consumers. Patch alone understates scope.'),
    ('A22', 'kohai', 'Road elections, player-death grief and dormant standing rendering extend society; clock/census/medic/state sweeps repair its existing machinery.'),
    ('A23', 'kohai', 'Creates a coherent deterministic instrument and extends testimony onto roads. Era/roadmap closure is bookkeeping, not another simulation minor or automatic major.'),
    ('A24', 'kohai', 'Garment/condition/drink persistence, names/journals, requests, creed seams and XP deepen existing people/work; engine re-read and fixes are supporting evidence.'),
    ('A25', 'kohai', 'Adds community ration/dissent and consumed counsel/history to existing politics; part of the governance collection subsequently completed in B23.'),
    ('A26', 'minor', 'Documents a closed loop: native DynamicRadio bulletins, actual two-way player transmission, listening houses/answers, aid/news/camp calls and carried delivery/debts integrate producer and consumer.'),
    ('A27', 'kohai', 'Chair consent/work, arrival forces and raid legs complete an iteration of political physics; they extend society/governance rather than create another baseline society credit.'),
    ('A28', 'minor', 'Completes grounded supply: real containers provide noticed possessions, foragers collect goods, sanctioned shelving supplies deliveries and fresh larder claims drive margins/winter. Ventures continue into B1.'),
    ('A29', 'kohai', 'Explicitly opens a macro-arc and lists propagation, panic, socialized ventures and vehicle composition as following slices. Innocence is a completed piece, not completion of that arc.'),
    ('B1', 'minor', 'The designed complex joins real motor-pool/seats, standing/temperament objection, patience/worry and belief transfer with crew entry/exit. NPC driving is expressly absent from its scope.'),
    ('B2', 'kohai', 'Real perk reads and XP integrate into delivered workday roles; native barricading is a meaningful extension rather than a complete new construction module.'),
    ('B3', 'minor', 'Closes observed bite to character-dependent care/distance/promise, recognized turning, fulfilled combat promise and carried grief/lesson/news.'),
    ('B4', 'minor', 'Native plow/seed/water/harvest with plant truth and gear feed real shelves, larder politics and XP: a complete producer-to-consumer farming loop.'),
    ('B5', 'patch', 'Bounds existing scans, checks sensors/exits/fields and supplies failing controls for corrections. Verification closure changes no feature scope.'),
    ('B6', 'minor', 'Dry-house fill/walk/carry/deposit and rationed stores combine with calendar shutoff. Cold-to-hearth, carried fuel/light and firewood errands yield consumed warmth/dormant effects.'),
    ('B7', 'kohai', 'Fresh resource failure drives abandonment through existing settlement; infection/cleaning/dressings/handover extend care. Advances existing governance and needs.'),
    ('B8', 'kohai', 'Makes standing bidirectional through neutral drift, lapsed hostility, departure and feud closure. Meaningful social extension under existing organization/governance.'),
    ('B9', 'kohai', "Native mood chemistry colors meetings and actual aired claims become told knowledge in real receiver holders; integrates existing encounters and A26's radio medium."),
    ('B10', 'patch', 'Corrects key leakage and save/death omissions in delivered coexistence, bitten life and player standing. Retain repair credit.'),
    ('B11', 'kohai', 'Housemate teaching and state-priced conserved trade extend prior work/XP and barter; learning continues through later player teaching/books.'),
    ('B12', 'kohai', "Coherently restructures existing verbs into the game's hierarchy; old hand-declared version movement and index repair do not establish a new feature completion."),
    ('B13', 'kohai', 'One skill/class-grounded promotion per election consumes current wound/larder/hearth/war counts. Meaningful incremental work/governance adaptation.'),
    ('B14', 'kohai', 'Structural advance makes existing discipline executable and demonstrates refusal/clearance. A new tooling contract alone does not complete a simulation feature.'),
    ('B15', 'kohai', 'Real corpse loot applies character/creed/known-dead restraint to conserved acquisition; one accessor/action boundary is not a complete new material module.'),
    ('B16', 'patch', 'Finds declaration/debug-handler defects, checks prior functions and tightens discipline. Instrumentation/correction without a new gameplay outcome.'),
    ('B17', 'kohai', 'Native lights, night decisions, storm hearing and rain-sensitive farm effort extend consumers. Fog is expressly deferred: no complete weather module.'),
    ('B18', 'kohai', 'Live content, refresh/death notices and player ground with companion homing extend surfaces/property; deliberately creates no new player organization.'),
    ('B19', 'kohai', 'Seating priority, release, return briefing and fairness deepen B1; player teaching and derived rotating watch extend work/sleep. No duplicate venture credit.'),
    ('B20', 'kohai', 'Severity, distress consequences and safe native cooking add professional consumers to the workday; the cooking seam alone does not close a separate utilities/crafting module.'),
    ('B21', 'kohai', 'Population exchange, real music/morale, registry capabilities and outcome judgment integrate delivered collections; coherent increments rather than a new framework completion.'),
    ('B22', 'kohai', 'Keepsakes/book circulation, work stations and finite skill-book study deepen people/work. Reading is integrated competence support, not independent closure merely because a native action is new.'),
    ('B23', 'minor', 'Deputies/turns, five derived forms, insider influence, division-to-schism and scarcity radio asks/performed gifts/debts close a coherent governance collection with visible consequences.'),
    ('B24', 'patch', 'A designation typo and census/conviction confusion had silenced promised alliances/government. Restored outcomes remain repairs, not renewed feature credits.'),
    ('B25', 'patch', 'Probes existing mechanisms and repairs misaligned gates, retaining corrected severity. No new completed feature.'),
    ('B26', 'patch', 'Dead medical/tool/smoke/seed literals are replaced with native categories/tags and absence is reported honestly; repairs unblock promised behavior.'),
    ('B27', 'patch', 'The record calls these inbound/outbound violations and rejects a separate pathway. Generic perception/tell/listening repairs the already-owned one-loop communication law.'),
    ('B28', 'patch', 'Fixes player resolution, false arrival-rate copy, register terminology and omitted first-offense teaching; admission arithmetic is left unchanged.'),
    ('B29', 'patch', 'Restores layout and truthful frequency display; no new feature scope.'),
    ('B30', 'patch', 'Corrects false/stale copy, dependency/license deployment and attribution. Publication preparation creates no capability credit.'),
    ('B31', 'patch', 'Repairs drift, never-empty tanks and wire mismatches, with exposed native limits and controls. No new venture/module closure.'),
    ('B32', 'patch', 'Repairs cooldown starvation and mirror/trait-sign mistakes while strengthening analysis; restores intended existing activities.'),
    ('B33', 'patch', 'Fixes hysteresis thrash, stale shipping classes and diagnostics. Restores established framework operation.'),
    ('B34', 'patch', 'Measures promised extents and verifies actual queue admission to repair silent drops. Correct trade/Ledger audits create no new feature tier.'),
    ('B35', 'kohai', 'Proximity unlearning/protection and carry-light gain real consumers, with voice fixes; meaningful social/property extension, while dissent remains unresolved.'),
    ('B36', 'patch', 'Mechanical preservation and justified catches harden existing data/delivery contracts; no new simulation module.'),
    ('B37', 'patch', 'Singular constants, unused age arithmetic and repaired water/death facts restore consistency. An API with no consumer earns no feature credit.'),
    ('B38', 'kohai', 'Meaningfully extends population/material derivation with map scale, demographic correction and age/arrival/room consumers. Parts of existing census/economy do not earn minor solely as a new contract.'),
    ('B39', 'kohai', 'Repairs provenance and adds bounded stock/respawn to the material abstraction. Player looting remains outside the count, so avoid claiming complete property/material simulation closure.'),
    ('B40', 'patch', 'Repairs tunables, origin knowledge and Doctor/FirstAid mismatch; restores expected work/vocabulary.'),
    ('B41', 'patch', 'Runs unexecuted mirrors and repairs the native type gate that invalidated player perception. Recovery of promised channels is repair credit.'),
    ('B42', 'patch', 'Repairs counters/placeholders/history/menu reach and removes guess-as-fact foreign import by operator direction; no separate feature credit.'),
    ('B43', 'patch', 'Computes version/header truth and connects unwired existing work. Stamping APIs and recovered economic halves remain repairs.'),
    ('B44', 'patch', 'Corrects sentinel/unit copy and the actual Kahlua next crash. A runtime fact or vocabulary law does not complete a new feature.'),
    ('B45', 'patch', 'Normalizes names, uses native compilation, fixes nil mourning and controls duplicate narration; integrity corrections to established surfaces.'),
    ('B46', 'patch', 'Centralizes tick resolution and corrects reticence gating of direct questions. The bug report establishes restoration, not a new communication module.'),
    ('B47', 'patch', 'Repairs reads, noise, panel silence and initialization-order claims; diagnostics/provenance repairs create no feature credit.'),
    ('B48', 'patch', 'Corrects hash pathology and false measured ranges. The save impact and magnitude of a repair do not turn it into a feature minor.'),
    ('B49', 'patch', 'Moves only the ear-facing cooldown, corrects frame-time claims and verifies unchanged decay. Larger clock policy stays with the operator.'),
    ('B50', 'patch', 'Repairs reach guards/verification assumptions and computes safety coverage. A bridge graph/API inventory alone is not feature completion.'),
    ('B51', 'patch', 'Connects uncalled cleanup and bounds dead-record cost, with reproducible art/save checking; relation pruning remains a separate unresolved decision.'),
    ('B52', 'patch', 'Derives false counts and repairs naming/parser/domain mismatches. Terminal-era labeling and integrity closure do not manufacture a feature or major credit.'),
]

TIER_MEANINGS = [
    ('major', 'Operator-selected completed feature grouping, release, identity or compatibility boundary. A mechanical carry does not declare that semantic boundary.'),
    ('minor', 'Completion of a coherent full feature or module with its required integration and sufficient evidence.'),
    ('kohai', 'Coherent building progress within an unfinished feature or module, including integrated child delivery.'),
    ('patch', 'In-place correction or verification repair of established behavior.'),
    ('maturity', '`pre-alpha -> alpha -> beta -> rc`; moves on evidence, never arithmetic. SAO remains pre-alpha.'),
]


# Add credit owners only with their actual closure record and index row.
POST_C_UNITS = [
    ('D1', 'minor', 'Completed declared reasoning module joins person-private conceptual inquiry, ordinary purpose comparisons, dated prior recall, durable unfinished purposes and guarded native recovery. The source retains its controlled reasoning and bounded native evidence without claiming completed curriculum or general learned policy.'),
    ('D2', 'minor', 'The complete declared Leisure module joins personally acquired opportunities, ordinary comparisons, native recreation across its selected families, authenticated outcomes, interruption and durable experience. This integrated module closure supports minor; it is not an isolated recreation API or building subset.'),
    ('D3.1', 'kohai', 'D3.1 delivers a coherent integrated increment within the still-OPEN D3 feature. Native crafting, maintenance, usable water or power contributes building progress; a new execution path does not close the complete construction/crafting/repair/utilities module.'),
    ('D3.2', 'kohai', 'D3.2 delivers a coherent integrated increment within the still-OPEN D3 feature. Native crafting, maintenance, usable water or power contributes building progress; a new execution path does not close the complete construction/crafting/repair/utilities module.'),
    ('D3.3', 'kohai', 'D3.3 delivers a coherent integrated increment within the still-OPEN D3 feature. Native crafting, maintenance, usable water or power contributes building progress; a new execution path does not close the complete construction/crafting/repair/utilities module.'),
    ('D3.4', 'kohai', 'D3.4 delivers a coherent integrated increment within the still-OPEN D3 feature. Native crafting, maintenance, usable water or power contributes building progress; a new execution path does not close the complete construction/crafting/repair/utilities module.'),
    ('D3.5', 'kohai', 'D3.5 delivers a coherent integrated increment within the still-OPEN D3 feature. Native crafting, maintenance, usable water or power contributes building progress; a new execution path does not close the complete construction/crafting/repair/utilities module.'),
    ('D3.6', 'kohai', 'D3.6 delivers a coherent integrated increment within the still-OPEN D3 feature. Native crafting, maintenance, usable water or power contributes building progress; a new execution path does not close the complete construction/crafting/repair/utilities module.'),
    ('D3.7', 'kohai', 'Native firearm fixing through exact private donor acquisition, installed payment and measured condition/returned contents, same-target equipment reuse, authenticated experience and saved custody is coherent building progress within the OPEN D3 module.'),
    ('D3.8', 'kohai', 'Installed wooden-bed construction and both full orientations join private recovery motivation, exact material acquisition, observed permitted placement, native payment/allparts and ordinary bed recovery use as coherent building progress within OPEN D3.'),
    ('D3.9', 'kohai', 'The complete selected single-edge wooden wall/frame/door family joins private shelter concern, exact material and stage construction, measured doorway use and reached native shelter conditions through ordinary consumption as integrated building progress within OPEN D3.'),
    ('D3.10', 'kohai', 'Native wooden floor/roof-cover construction, genuine work-level access and return to the original ordinary shelter consumer deliver integrated surface progress within OPEN D3.'),
]
# A closed parent that only aggregates previously credited descendants maps to
# their exact credit-owner IDs. It is a chronological record, never a new tier.
POST_C_AGGREGATIONS = {}
NEXT_BATCH = "D3"


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


def post_c_faults(indexed, active, units=None, aggregations=None, next_batch=None):
    """Separate explicit closed chronology from capability credit and open scope."""
    units = POST_C_UNITS if units is None else units
    aggregations = POST_C_AGGREGATIONS if aggregations is None else aggregations
    next_batch = NEXT_BATCH if next_batch is None else next_batch
    faults = []
    valid_units = []
    for unit in units:
        if (not isinstance(unit, (tuple, list)) or len(unit) != 3
                or not isinstance(unit[0], str)):
            faults.append("delivered D units require identifier, scope tier and rationale")
            continue
        label, tier, rationale = unit
        try:
            batch_parent(label)
        except CatalogueError as exc:
            faults.append(str(exc))
            continue
        if not label.startswith("D"):
            faults.append("post-C credit owners must be D identifiers")
        if tier not in ("major", "minor", "kohai", "patch", "hotfix") or not isinstance(rationale, str) or not rationale.strip():
            faults.append("delivered D units require a scope tier and nonempty rationale")
        if active is not None and tier in ("minor", "major") and label.startswith(active + "."):
            faults.append(f"{label}: a child building the OPEN {active} feature requires kohai or patch, not completion credit")
        valid_units.append(label)
    if len(valid_units) != len(set(valid_units)):
        faults.append("duplicate delivered D credit owner")
    if not isinstance(aggregations, dict):
        return faults + ["closed parent aggregations must be an explicit mapping"]
    closed = [label for label in indexed if label.startswith("D")]
    if set(valid_units) & set(aggregations):
        faults.append("closed parent aggregation cannot also receive version credit")
    if set(closed) != set(valid_units) | set(aggregations):
        faults.append("closed D records and explicit credit/aggregation coverage disagree")
    if [label for label in closed if label in valid_units] != valid_units:
        faults.append("delivered D capability credit must follow indexed chronological order")
    for parent, owners in aggregations.items():
        try:
            batch_parent(parent)
        except CatalogueError as exc:
            faults.append(str(exc))
            continue
        if (not parent.startswith("D") or not isinstance(owners, (tuple, list))
                or not owners or any(not isinstance(owner, str) for owner in owners)
                or len(owners) != len(set(owners))):
            faults.append("closed parent aggregation requires unique descendant credit owners")
            continue
        # Freeze the parent's aggregation at its closure position. Later child
        # work receives later credit without rewriting the closed parent history.
        descendants = [owner for owner in valid_units if owner.startswith(parent + ".")
                       and owner in closed and parent in closed
                       and closed.index(owner) < closed.index(parent)]
        if list(owners) != descendants:
            faults.append("closed parent aggregation must name its exact credited descendants at closure in order")
        if parent in closed and any(owner not in closed or closed.index(owner) >= closed.index(parent) for owner in owners):
            faults.append("closed parent aggregation must follow its credited descendants")
    try:
        batch_parent(next_batch)
    except CatalogueError as exc:
        faults.append(str(exc))
    if not isinstance(next_batch, str) or not next_batch.startswith("D"):
        faults.append("NEXT_BATCH must name a declared unconsumed D scope")
    if active is not None and active != next_batch:
        faults.append("NEXT_BATCH must retain the explicitly active D scope")
    if isinstance(next_batch, str) and next_batch in indexed:
        faults.append("NEXT_BATCH must remain unconsumed in BATCH_LOG")
    return faults


def catalogue_inputs():
    """Validate source preservation and index agreement before any stamp write."""
    manifest = load_product_catalogue(ROOT)
    faults = validate_product_catalogue(ROOT, manifest)
    if faults:
        raise CatalogueError("; ".join(faults))
    text = BATCH_LOG.read_text(encoding="utf-8")
    indexed = index_rows(text)
    active = active_batch(text)
    faults.extend(post_c_faults(indexed, active[0] if active else None))
    if faults:
        raise CatalogueError("; ".join(faults))
    units = classified_units(manifest)
    ids = [unit[0] for unit in units]
    if ids != [label for label in indexed if label not in POST_C_AGGREGATIONS]:
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
    tip = next(reversed(rows))
    nxt = NEXT_BATCH
    hierarchy = any("." in label for label in rows) or bool(POST_C_AGGREGATIONS)
    lines = [
        "# Version map",
        "",
        "The regulatory version replay classifies evidenced delivered scope",
        "once per coherent product batch under CAO's unchanged caps. All eras use",
        "the feature-scope reconciliation. Current C products partition the retained source",
        "chronology into adjacent capability units. The separate 35-contract",
        "ownership map preserves shared boundaries without version credit. Delivered D units",
        "follow C in chronological order. A delivered unit implements its coherent",
        "product outcome with sufficient applicable checks. Neo maintains its",
        "current assessment from accumulated simulation and operator feedback.",
        "Later improvements link back to that unit. The",
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
        "| Feature-scope reconciliation | [20261010](Batches/VERSION_SCOPE_RECONCILIATION.json); prior replay retained |",
        f"| {'Unconsumed scope' if hierarchy else 'Next batch'} | `{nxt}` |",
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
    if hierarchy:
        lines += ["", "Dotted labels record child scope. Each capability row above receives credit once;",
                  "child delivery leaves its explicitly active parent open. Closed parent aggregation",
                  "records name existing credit owners separately. Completed-feature scope can receive minor after kohai progress; repeated aggregation grants no tier."]
    if POST_C_AGGREGATIONS:
        lines += ["", "## Closed parent aggregations", "",
                  "These chronological closure records aggregate already credited descendants and grant no additional tier.", "",
                  "| Parent | Date | Credited descendants | Name |", "|---|---|---|---|"]
        for parent in rows:
            if parent in POST_C_AGGREGATIONS:
                day, name, _threads = rows[parent]
                owners = ", ".join(f"`{owner}`" for owner in POST_C_AGGREGATIONS[parent])
                lines.append(f"| `{parent}` | {day} | {owners} | {name} |")
    lines += [
        "", "## Current C products and retained source history", "",
        "Each C product tier credits its coherent capability once. Each retained",
        "source belongs to one chronological product; shared contract edges grant",
        "no additional version credit. Retained sources link to the archived",
        "120-record generation. SESSION_STATE and PLAYABILITY describe current",
        "delivered behavior and continuing work.", "",
        "| Current product | Classification | Retained chronological sources |",
        "|---|---|---|",
    ]
    for unit in manifest["units"]:
        scopes = unit["rationale"].replace("|", "\\|")
        credited = []
        for contribution in unit["sourceContributions"]:
            source = contribution["sourceId"]
            credited.append(f"[{source}]({contribution['path']})")
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
        "The maturity coordinate remains `pre-alpha`. Neo maintains the current",
        "product assessment from delivered behavior, accumulated simulation",
        "and operator feedback.",
        "",
        "## Next movement",
        "",
        (f"`{nxt}` remains the declared unconsumed scope; subsequent delivered children or new capability units"
         if hierarchy else f"`{nxt}` is the next unused catalogue identifier. Current open extensions"),
        "remain with their owners; this projection does not close them or start",
        "another batch. Subsequent delivered work determines its own tier:",
        "",
        f"| {'If newly delivered scope is' if hierarchy else 'If ' + nxt + ' is'} | Result |",
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
