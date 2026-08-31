| Document | Survivor Awareness Overhaul Memory |
|---|---|
| Version | `0.6.0.0-pre-alpha` |
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
| `GOVERNANCE.md` | CANONICAL | Operating discipline and model-facing instruction surface. |
| `DECISION_REGISTRY.md` | CANONICAL, APPEND-ONLY | Ratified decisions from DR-001. |
| `FINDINGS.md` | CANONICAL, APPEND-ONLY | Verified engine findings from F-001. |
| `BATCH_LOG.md` | REGULATORY | Chronological index for the batch sequence. |
| `VERSION_MAP.md` | REGULATORY | Version units replayed over the closed chronology through `[B52]`. |
| `ROADMAP.md` | CANONICAL | Thread map, backlog, live gates. |
| `SESSION_STATE.md` | CANONICAL | Where the work actually stands. |
| `KNOX_SOCIAL_AUDIT.md` | CANONICAL | Reference-design audit of the Knox social/organizational systems ([A14]). |
| `ENGINE_CONTRACT.md` | CANONICAL, INCOMPLETE | The verified engine mechanics an IsoPlayer NPC requires; lifecycle-ordered, failure-cited. |
| `VERSION` | CANONICAL | Shipped version string. Every root header's `Version` cell reads this and nothing else ([B43]). |
| `PLAYABILITY.md` | CANONICAL | What the player can actually do with the county, and what is still rough. |
| `POSITION.md` | CANONICAL | Where this project stands against what else exists. |
| `SPEECH.md` | CANONICAL | Direction for how survivors speak. Direction only - there is no free-text or dictated speech. |
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
| `Batches/` | One alphanumeric batch sequence; one record per closed batch. |
| `mod/` | The shippable mod tree (root + version-dir `mod.info`, Lua under `42.20/media/lua/`). |
| `java/` | The agent component (DR-004): shell class, bridge, bootstrap; built to `java/dist/SAOAgent.jar`. |
| `tools/` | Build and dev scripts (`build-java.sh`). |
- [PUBLISHING.md](PUBLISHING.md) - what a Workshop upload needs, read from the game's own template; blocked on art, deliberately not staged.
