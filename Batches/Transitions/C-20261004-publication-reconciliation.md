# Public reconciliation of the shared C catalogue

The latest settled operator directive is to reconcile the current compressed C
era on GitHub, organize accumulated SAO publication by coherent current
contracts and dependencies, and keep Mousecat as one PR in its separate
repository. The current 35 contracts organize work; historical C118-C120 labels
identify source provenance. This publication discharges the C-era catalogue
reconciliation portion of that directive.

This additive publication brings the current 35 shared contracts, 120 retained
source records and 300 contribution links to the public repository. The
2026-10-03 compression event and its captured mapping remain byte-for-byte
unchanged. Published commits and pull-request identities retain their original
source-generation labels. This follows the catalogue publication used in PR69.

The public source base is `6bfcd46e72146b941db6c26086201bc79e883a40`.
Source C118 and C119 remain published; source C120 remains local-unmerged with
its measured verification, rendered-acceptance and redistribution boundaries.
The two C34 recovery owners absent from public runtime are identified by the
[availability map](../C_PUBLICATION_AVAILABILITY.json) and the
[compression-time source audit](C-20261003-publication-source-audit.json).
Their hashes identify local engineering provenance; they confer no source
redistribution permission and do not describe code present in the shipped mod.

The current mapping adds this publication-availability binding. The frozen
mapping at compression keeps its original identity. Unknown missing owners,
foreign contracts, changed blob identities and malformed availability ledgers
remain validation failures. Introducing these local owners in a later
publication requires explicitly updating their availability and its validator.

Version replay yields `2.11.1.0-pre-alpha` from the existing A/B catalogue and
35 C contracts. Both JARs are rebuilt from the unchanged public Java source and
resources, using the existing build tool. Their entry inventory matches the
public JAR; only generated `SAOVersion.class` and the inlined version constant
in `SAOBridge.class` change. No local-unpublished runtime implementation is
included. This reconciliation adds no numbered batch or version credit. D1
remains open; subsequent D development retains its own implementation and
acceptance evidence.

## Validation scope and reusable evidence

The changed inputs are catalogue records, preserved provenance, version metadata,
root-document currency, the catalogue reader and its availability guard. The
new catalogue instrument is invoked by `tools/check.sh`. Local checks passed:

| Contract | Evidence |
|---|---|
| Catalogue and strict availability | 52 checks, including malformed and resealed ledgers |
| Availability instrument causality | Three isolated restored source guards fail for the literal motivating assertions |
| Captured-byte portability | Fresh raw Git-tree export passes catalogue checks and version replay; source records and frozen transition hashes remain exact |
| Public-only package stamp | Unchanged 44 Java sources, two resources, 96 classes; exact entry-by-entry public inventory comparison |
| Version and metadata consumers | Version replay, shipped JAR, version stamp, map references, document currency, receipts, session-state and gate reach |

The earlier source controls remain applicable because their guarded catalogue
contracts are unchanged. The public JAR comparison supplies the reusable runtime
evidence for this metadata-only change. No native trial is claimed. Original
failed portability and session-tip checks remain in the local preparation
history; corrected checks pass against the final inputs.

The local pre-commit hook invokes the full suite. Under the standing
proportionate-validation rule in `GOVERNANCE.md`, the preparation commit uses
the command-scoped `--no-verify` option to avoid repeating unaffected native
borders after these sufficient checks. This is evidence reuse, not a full-gate
pass. Protected remote `ci-verify` and `codeql-python` checks must complete
before merge and retain their own environment and observation limits.

## First remote CI finding and detector repair

PR137's first `ci-verify` run failed at the operator-speech border. The frozen
recatalogue verification inventory names `tools/operator_speech_test.py` and
its source SHA on line 1846. The former detector treated the identifier's
`operator` substring and the following hash as attributed quoted prose. The
captured inventory is preserved without alteration.

The detector now requires the standalone word `operator`; it continues to reject
prose attribution, parenthesized attribution and verbatim markers. Nine inline
controls include those actual attribution forms and identifier/hash
non-attribution. The literal frozen row reproduces the old match and remains
unattributed under the corrected detector. The complete tracked-text sweep
passes. An isolated restoration of the old regex fails both the filename/hash
control and the same frozen line for their stated reasons. This repair adds no
archive exemption. No runtime or whole local gate was rerun; the next protected
remote checks remain required.
