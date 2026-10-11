| Document | Survivor Awareness Overhaul Memory |
|---|---|
| Version | `2.6.11.0-pre-alpha` |
| Author | ellyj3rain |
| Repository | `MEMORY.md` |
| Status | ACTIVE - index of every root document and its standing. |

# Memory

Index of every document at the repository root, with what it is and whether it is
current. Nothing at the root is unclassified.

## Status vocabulary

| Status | Meaning |
|---|---|
| CANONICAL | Current truth. Edit in place when superseded. |
| CANONICAL, APPEND-ONLY | Current, extended through new entries; prior substance is fixed. |
| REGULATORY | Active index. May be corrected without rewriting what it organizes. |
| SHIM | Pointer file. |

## Canonical doc-pack

| File | Status | Role |
|---|---|---|
| `README.md` | CANONICAL | Human entry point. |
| `MEMORY.md` | CANONICAL | This index. |
| `CORE.md` | CANONICAL | Project identity, canonical composition, governing constraints. |
| `ARCHITECTURE.md` | CANONICAL | Ratified framework shape; the four pillars. |
| `REPRESENTATION.md` | CANONICAL | What the county represents, and which state surface carries each part. |
| `BRANCHING.md` | CANONICAL | The whole simulation's branching graph. |
| `SUBSTRATE.md` | CANONICAL | Existing and planned dependencies, and what each area of concern needs. |
| `ORGANIZATION.md` | CANONICAL | Organization, hierarchy, offices, governance forms, legitimacy, and deference. |
| `GOVERNANCE.md` | CANONICAL | Operating discipline and model-facing instruction surface. |
| `DECISION_REGISTRY.md` | CANONICAL, APPEND-ONLY | Ratified decisions from DR-001. |
| `FINDINGS.md` | CANONICAL, APPEND-ONLY | Verified engine findings from F-001. |
| `RECEIPTS.md` | CANONICAL, APPEND-ONLY | What play has actually settled, from R-001 (DR-025). |
| `BATCH_LOG.md` | REGULATORY | Authoritative current product index; C sources and ownership contracts retain separate generations. |
| `VERSION_MAP.md` | REGULATORY | Delivered product scopes replayed once, with preserved A/B classifications and source component status. |
| `ROADMAP.md` | CANONICAL | Thread map, backlog, live gates. |
| `SESSION_STATE.md` | CANONICAL | Where the work actually stands. |
| `MAPS.md` | CANONICAL | The three pictures a human reads first: runtime, knowledge, catalog. |
| `PROJECTS.md` | CANONICAL | The architecture across the three repositories: what SAO, ZAO and Speakeasy each own, and the three seams. |
| `KNOX_SOCIAL_AUDIT.md` | CANONICAL | Reference-design audit of the Knox social/organizational systems ([A14]). |
| `ENGINE_CONTRACT.md` | CANONICAL, INCOMPLETE | The verified engine mechanics an IsoPlayer NPC requires; lifecycle-ordered, failure-cited. |
| `VERSION` | CANONICAL | Shipped version string. Every root header's `Version` cell reads this and nothing else ([B43]). |
| `PLAYABILITY.md` | CANONICAL | What the player can actually do with the county, and what is still rough. |
| `POSITION.md` | CANONICAL | Where this project stands against what else exists. |
| `SPEECH.md` | CANONICAL | Direction for how survivors speak. Scheduled as the standing blocker (DR-029); still no free-text or dictated speech in the tree. |
| `SPEECH_ML_DESIGN.md` | CANONICAL | The talking system's ratified design (DR-029/030): survivors modeled as people - world model, will, mood - two learned pieces in-process with constrained decoding; no player-speech harvesting. Build follows it. |
| `CREDITS.md` | CANONICAL | Attribution. Exempt from the never-name-a-mod rule, being documentation. |
| `HANDOFF.md` | REFERENCE, HISTORICAL | B-era session handoff of 2026-08-27. Superseded at the C seam; its standing rules migrated into `GOVERNANCE.md`. Not maintained against the tip. |
| `LICENSE` | CANONICAL | GPL-3.0. |

## Instruction surface

| File | Status | Role |
|---|---|---|
| `NEO.md` | CANONICAL | The instruction surface. Read first. |
| `CLAUDE.md` | SHIM | Autoload pointer to `NEO.md`. |
| `AGENTS.md` | SHIM | Autoload pointer to `NEO.md`. |

## Directories

| Path | Role |
|---|---|
| `Batches/` | A/B records, preserved C1-C120 sources, current C products under Products/, ownership contracts under Catalogue/, and active D records. |
| `Batches/C_RECATALOG.json` | Immutable prior 127-to-50 C crosswalk with original paths and Git-blob hashes; intermediate units are source-generation identifiers. |
| `artifacts/audits/20261003-2057Z-1357PST-c-development-recatalogue/` | Historical adjacency review and superseded projection; preserved unchanged for provenance. |
| `Batches/Products/` | Current coherent historical C development products with exact source contributions and measured component status. |
| `Batches/C_PRODUCT_CATALOGUE.json` | Regulatory current product generation, source partition and version tiers. |
| `Batches/C_PRODUCT_CROSSWALK.json` | Exact generation-qualified source-to-product navigation. |
| `Batches/Catalogue/` | Canonical shared C contracts: owner, inputs, outputs, state, delivered scope, dependencies and remaining D work. |
| `Batches/C_SHARED_BOUNDARIES.json` | Regulatory source/ownership manifest; exact source/archive hashes and measured component states; separate from current product version credit. |
| `Batches/SHARED_BOUNDARIES.md` | Canonical human navigation of shared contracts and D dependencies. |
| `artifacts/continuity/` | Generated machine graph and interactive human view of development, conceptual and dependency continuity; source vectors identify currency. |
| `Batches/history/` | Historical detailed scope preserved during consolidation; current status belongs to SESSION_STATE and ROADMAP. |
| `artifacts/audits/` | Dated audit reports and immutable reproducibility evidence, including C82's source-bound native coordination shadow family; former batch labels stay historical. |
| `mod/` | The shippable mod tree (root + version-dir `mod.info`, Lua under `42.20/media/lua/`). |
| `java/` | The agent component (DR-004): shell class, bridge, bootstrap; built to `java/dist/SAOAgent.jar`. |
| `tools/` | The evidence apparatus: every border's gated mirror, `check.sh`, the offline mirrors, the pre-commit hook - plus the build and deploy scripts (`build-java.sh`, `deploy.sh`). |

- [PUBLISHING.md](PUBLISHING.md) - what a Workshop upload needs, read from the game's own template; blocked on art, deliberately not staged.
- [GROUNDED_DEAD_PROPOSAL.md](GROUNDED_DEAD_PROPOSAL.md) - PROPOSED: the zombie-population derivation (demography x lore x mechanism fork) awaiting the operator's ratification; nothing in it is behavior.

Ordinary project documentation has one current Markdown source. Separately
requested formats belong to that request and receive no automatic companion
generation or current-document status.


### 2026-10-09 10:17 UTC / 03:17 PST — observed restored-body inquiry recovery and connected asset library

Current proof: `_scratch/d2-leisure-01/source-inquiry-body-recovery-20261009/inquiry-proof.json`, `installed-receipt.json` and `checkpoint-receipt.json`. Source tests and installed-byte custody retain their separate scopes. Private library canonical documents and exact assets live at `Projects/neo-library`; native delivery provenance is source-owned in that repository.

The full inherited 35-contract/shared-goal mandate and FIFO continue: D3 construction/crafting/repair/utilities, D4 whole food/preservation, D5 comprehensive installed animal care, and D6 assessed K-through-college learning. Mousecat’s custom Zomboid engine fork playtest architecture under the universal permission mandate and controlled testing with new models when ready remain continuing outcomes. The normal user-owned save, character and scenario flow continues. Logical liaison04 is carried by the distinct sole-writer successor322; SEAL321 is the preserved predecessor, not the active claim.

Current verification assessment is Neo-owned through `neo-verification-assessment`. The D2-preclosure session snapshot under `Batches/history/d2-before-closure/` is dated history; SESSION_STATE is the current concise source.

## Current D3 record

[D3 construction, crafting, repair and utilities](Batches/D3-20261010-0143Z-1843PST-construction-crafting-repair-utilities.md)
is OPEN. Its first material-work join and scoped native evidence are recorded
there; the whole domain continues before D4-D6. [D3.1](Batches/D3.1-20261010-0344Z-2044PST-native-plank-crafting.md) is CLOSED with exact private input acquisition, native plank crafting and retained construction integration. SESSION_STATE describes current standing and the child's once-only delivered version credit.

The CLOSED [D3.2](Batches/D3.2-20261010-0430Z-2130PST-native-saw-maintenance.md) adds exact native saw maintenance, private file acquisition, measured tool effects and authenticated feedback within the same construction purpose. The CLOSED [D3.3](Batches/D3.3-20261010-0622Z-2222PST-portable-tool-maintenance.md) extends held-tool upkeep to portable blade sharpening and ordinary kit tending with private file/whetstone means, distinct measured benefit/damage and authenticated saved experience. The OPEN D3 parent retains full module scope and remaining obligations.

## Feature-scope replay and D3.7

[Batches/VERSION_SCOPE_RECONCILIATION.json](Batches/VERSION_SCOPE_RECONCILIATION.json) is the regulatory complete historical scope assessment; [the transition](Batches/Transitions/VERSION-20261010-feature-scope-credit.md) supersedes prior current tier projections while retaining original labels, source bytes and published versions. The exact prior generation is historical under Batches/history/version-20261010-before-scope/. [D3.7](Batches/D3.7-20261010-1903Z-1203PST-native-item-fixing.md) closes native item fixing through privately intended equipment reuse. D3 remains OPEN, and future children/building increments use kohai under the canonical GZDS/Neo scope rule.

## D3.8 construction-to-use source

[D3.8](Batches/D3.8-20261010-2124Z-1424PST-usable-bed-construction.md) is the CLOSED coherent wooden-bed construction/placement child, with native recipe, complete orientations, exact private materials, permitted observed footprint and ordinary recovery-use evidence. Full [D3](Batches/D3-20261010-0143Z-1843PST-construction-crafting-repair-utilities.md) stays OPEN. It receives one kohai under the corrected feature-scope version rule.

## D3.9 shelter construction source

[D3.9](Batches/D3.9-20261010-2240Z-1540PST-walls-doors-usable-shelter.md) is the CLOSED single-edge wooden wall/frame/door construction-to-use child. It retains native stages/materials, private permitted edges, actual doorway use, native shelter conditions, ordinary consumers and saved continuity. Full [D3](Batches/D3-20261010-0143Z-1843PST-construction-crafting-repair-utilities.md) stays OPEN; the child receives one kohai.

## D3.10 native floor and cover source

[D3.10](Batches/D3.10-20261011-0126Z-1826PDT-roofs-floors-usable-shelter.md) is the CLOSED native wooden surface construction-to-usable-shelter child. It retains work/use-level separation, genuine access, exact materials and physical cover, ordinary recovery and save custody. Parent D3 remains OPEN; the increment receives one kohai.

## D3.11 native stair source

[D3.11](Batches/D3.11-20261011-0439Z-2139PDT-native-stairs-usable-shelter.md) is the CLOSED native wooden-stair construction-to-usable-shelter child. Both complete orientations, exact materials, private permitted footprint, native creation/landing, genuine access, cover, return, ordinary recovery and durable independent feedback are joined. Full D3 remains OPEN; one kohai records this building progress.
