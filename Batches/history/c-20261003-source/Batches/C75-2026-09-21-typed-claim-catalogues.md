# C75 - Typed claim catalogues

| Field | Record |
|---|---|
| Batch | `C75` |
| Date | 2026-09-21 |
| Name | Typed claim catalogues |
| Status | Closed; complete repository gate enforced by the publishing commit. |
| Threads | [`T-002`](THREADS.md#t-002), [`T-006`](THREADS.md#t-006), [`T-008`](THREADS.md#t-008), [`T-009`](THREADS.md#t-009), [`T-030`](THREADS.md#t-030) |

## Measured contract

Speakeasy Record 51 requires a learned retriever to return claim identifiers
from one person's current knowledge. SAO already had a broad private Knowledge
surface and C47 already prevented the speaker from using scalar values outside
that surface. Those two contracts did not meet. Most knowledge facts had no
identifier, generic known-person beliefs were omitted from the all-topic bundle,
and the fence received every known fact rather than the claims chosen for one
exchange.

C74 and Speakeasy Record 52 prove one protected outage claim from source review
through Ada North's lived acquisition. That reference creates no training row
and leaves its controlled source choice excluded. The
[C75 contract](../artifacts/audits/20260922-0540Z-2240PST-typed-claim-catalogues/PLAN.md)
therefore addresses the runtime data shape without claiming that a complete
protected-world catalogue, relevance targets or a learned runtime exists.

## Implemented behavior

`Knowledge.claimCatalogue` reads the existing facts for one person, listener and
tick and returns a detached schema-versioned catalogue under a caller-owned
immutable snapshot reference. It enumerates every requested topic, including
each person in the private belief store. Canonical fact content determines
ordering, so Lua map insertion order cannot move a reference. Each catalogue
entry receives a local reference and a protected world entry also retains its
stable source claim identifier.

The compiler refuses malformed topic lists, unsupported values, cycles,
non-finite numbers, over-deep data, too many claims and a complete catalogue
whose detached content exceeds the value budget. Every list handed to Project
Zomboid's recursive Lua sorter refuses above an explicit 512-entry ceiling. It
copies conditioning and facts instead of exposing live stores.

`Knowledge.selectClaims` validates the catalogue and exact snapshot before it
accepts any reference. Unknown, duplicate, malformed or foreign references
refuse the whole selection. The result remains detached and follows catalogue
order rather than model-output order. `Knowledge.flatSelectedClaims` then
projects only top-level scalar fields and values from selected entries through
C47's established fence rule.

## Effect on a future conversation

If a survivor knows Dana's location, Marcus's death and the Knox outage, a
future retriever may select Dana's exact snapshot reference when the player asks
where Dana is. The speaker fence can then admit Dana's fields while excluding
Marcus and the outage, even though the survivor knows all three. A stale result
from another snapshot refuses instead of pointing at whichever fact later
occupies the same position.

C75 stops before the learned calls. Current inspection and speech continue to
use their existing paths, so this batch changes nothing visible in play and
produces no target, training row, model weight or runtime decision.

## Verification

Border 188 executes the shipped Lua in the installed Kahlua runtime. It proves
stable references across map insertion order, complete known-person coverage,
protected source-identifier preservation, detached catalogues and selections,
catalogue-order selection, selected-only and empty fencing, and atomic refusal
of foreign, unknown, duplicate, malformed, cyclic, non-finite, over-deep,
oversized and tampered input. Three controls independently remove the snapshot
check, widen the fence to every claim and reset the value budget per fact; each
changes its intended verdict.

The existing knowledge-surface, Java fence and world-knowledge borders remain
clean. The complete gate passes 199 distinct scripts with labels through Border
188, and the rebuilt Java artifact reports `2.8.12.0-pre-alpha`. The
[evidence record](../artifacts/audits/20260922-0540Z-2240PST-typed-claim-catalogues/README.md)
retains the complete repository gate, exact 261-file installation and responsive
main-menu startup. The existing ZombieBuddy installation/options warning remains
visible; no save was loaded.

## Limits and continuation

The future asynchronous runtime owns the immutable serialized snapshot and must
bind `snapshotRef` to its exact bytes. SAO still exposes only C74's one stable
protected-world claim. Speakeasy must expand reviewed claim coverage, resolve
the retriever target-authoring policy and build task datasets before training.
The operator's pending Mousecat ruling controls target meaning; it does not
approve this mechanical catalogue or create data by itself.
