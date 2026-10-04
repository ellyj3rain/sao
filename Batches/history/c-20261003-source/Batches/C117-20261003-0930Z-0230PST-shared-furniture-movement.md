| Document | C117 - Shared furniture movement |
|---|---|
| Timestamp | 2026-10-03 09:30 UTC / 02:30 PST |
| Thread | T-030 |
| Version | `3.11.1.0-pre-alpha` |
| Tier | kohai |
| Status | Closed source batch; loaded acceptance remains open |

# Shared furniture movement

The optional installed single-player furniture push/pull path gains exact
pending identity and measured physical completion. The installed module keeps
animation, native relocation, inventory transfer, effort and feedback. A bounded
SAO queue owns the delayed push because the installed private queue has no
cancellation identity and later resolves by coordinates and sprite. The original
animation runs with that queue disabled, leaving one physical move owner.

Each move captures actor, cell, source object, entire footprint, target squares
and exact contents including nested inventories. Physical execution rechecks
those captures. Pickup and placement may replace IsoObjects; completion therefore
requires removed originals, unique new destination members and the same actual
InventoryItem instances. Partial effects and rescued contents do not count as
completed relocation. Multi-part delegation measures one outer operation.

Native carry wrappers and object events retain LG plumbing/electricity ownership.
A bath registered with its tub system refuses before effects. Optional WaterPipes
support is bounded to verified empty native fixtures and empty compatible virtual
registrations, preserving registration properties while its owning commands
relocate the state with the actual actor. Unsupported water state and unrelated
destination registration refuse before movement. General bathing eligibility
composition and broader utility mechanics remain open.

Bounded detached scalar diagnostics record results. They grant no person
knowledge or practice. The existing installed player actions are the live caller;
NPC furniture planning, admitted work and private learning remain future work.
Multiplayer retains the installed path. Pico owns the appearance pipeline.

## Evidence and validation scope

The [source inspection](../artifacts/audits/20261003-0922Z-0222PST-furniture-movement/installed-sources.json)
and [scope](../artifacts/audits/20261003-0922Z-0222PST-furniture-movement/scope.md)
retain actual installed dependencies and the affected contracts. This batch adds
one optional Lua owner, its installed-source proof and namespace/gate registration.
The bodyless simulator never loads or references this adapter, so its existing
owner contracts remain unchanged. Documentation and version stamps receive their
own checks.

The [final installed-source proof](../artifacts/audits/20261003-0922Z-0222PST-furniture-movement/verification.json)
passes 47 checks and eleven named source mutations, exit zero. Complete installed
FPP core/actions/client, WaterPipes readers/commands and bathing readers execute
in installed Kahlua. Native API reflection passes. Map, geometry, bodies, items
and native pickup/placement receivers are controlled; actual LG callback behavior
and native loaded-world relocation remain unverified.

The final runtime hash is
`7d35ef9f1e81b186820f249e59ba3cd9c5d88769b5287b0e402b99e24606b5e5`.
Before/after source pins match. Controls restore premature scheduling, source,
content and nested-content substitution, false completion, wet-bath/virtual-water
bypass, destination-registry overwrite, expiry omission, reentrant reset failure
and nonscalar diagnostics. Each reaches its named failing assertion. Initial
failures and intermediate proofs remain separate from this final pass.

The independent correctness review found no material issue. A final small repair
bounds externally supplied reset reasons to scalar text, with an executing
control. Namespace, person-lifetime and gate-reach checks pass; final document,
version and package checks retain their own logs. The build stamps both identical
shipped JARs from the derived `3.11.1.0-pre-alpha` coordinate.

The first proposed dormant-owner omission control failed because its scanner
correctly sees no reference to this player-only adapter. Those unnecessary edits
were removed; both simulator files match the base tree. That failed result is
not passing evidence. The subsequent local work does not repeat simulation runs.
Eighteen relevant installed source pins match the earlier C112 owner-matrix
inspection (`0065d836582b73ffd2f9f1c4826df176b2f77762079e4ef6e5d20ca30ed44029`);
that comparison reuses source findings, not runtime acceptance.

Applicable independent successes survive the final reason sanitizer and metadata
repairs; the final installed-source proof covers the changed runtime and controls.
No unrelated observation, education or long simulation suite is rerun. The local
commit uses GOVERNANCE.md's command-scoped `--no-verify` path because the sufficient
focused checks are recorded; it is not a full local gate pass. GitHub's required
`ci-verify` still runs the full suite and `codeql-python` must pass before merge.
Their absent-game checks retain explicit unverified boundaries.

## Continuation

Loaded native-world furniture acceptance, NPC planning and learning, multiplayer
ownership, nonempty WaterPipes fixtures and general bath pickup/rotate/scrap
eligibility remain open. The larger integration queue and retained education,
culture and individual behavior work continue. No learning model, baseline save
or observer implementation changes in this batch.

The stale GZDS follow-up pointers now link its already merged B2.17 / PR25,
`9cc109d83bac2c38023641cf799668b3dd2e08ec`, verified against GitHub during C117.


The first required remote CI run (`37113894008`) failed its session-state
currency check: the new As-of batch link was on a following line while the
existing parser reads that same line. The link now shares its line; the focused
`session_state_test.py` passes. All runtime proof inputs remain unchanged and
its valid result is reused. The first remote run is recorded as failed, with
its independent successful checks retained. Required remote checks run again
for the corrected commit because branch protection imposes that constraint.
