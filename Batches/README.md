# Batch records

[D1 — Shared person-specific reasoning](D1-20261004-0124Z-1824PST-shared-reasoning.md)
is open after C compression. The active entry in `BATCH_LOG.md` points to its
record without adding a delivered-scope row or version credit.

`Transitions/` preserves dated catalogue transformations separately from numbered
development units. [C compression before D](Transitions/C-20261003-compression.md)
records the 120-to-35 mapping and chronology without adding version credit.

[Public catalogue reconciliation](Transitions/C-20261004-publication-reconciliation.md)
records the additive publication boundary, exact local-unpublished owner
availability and scoped verification.

`BATCH_LOG.md` at the repository root is the authoritative current index. A/B records retain their existing catalogue. Current C contracts live under `Catalogue/`; their definitions and D dependencies are indexed by [SHARED_BOUNDARIES.md](SHARED_BOUNDARIES.md).

The C1-C120 files at this directory root are immutable source records of the pre-migration generation. Their original paths preserve historical links. `history/c-20261003-source/` freezes that generation and its indexes. `C_RECATALOG.json` retains the earlier 127-to-50 mapping; `C_SHARED_BOUNDARIES.json` maps both the current contracts and the preserved 120-record source generation. An unqualified old C label in a retained source or receipt keeps its original generation.
