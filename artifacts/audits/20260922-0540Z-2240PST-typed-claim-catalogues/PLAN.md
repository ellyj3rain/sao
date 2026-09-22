# C75 typed claim catalogues

| Field | Record |
|---|---|
| Batch | `C75` |
| Timestamp | 2026-09-22 05:40 UTC / 22:40 PST |
| Scope | Give the existing read-only knowledge surface exact references inside one immutable conversation snapshot, then restrict the factual fence to an admitted subset of those references. |
| Does not do | Add knowledge, expand the one-claim protected-world port, author retriever targets, create training rows, train a model or change current speech. |

## Why this is next

Speakeasy Record 51 requires a learned retriever to select claim identifiers from
one person's current catalogue. SAO already exposes the person's bounded facts and
the C47 fence already refuses values outside that surface. The two interfaces do
not yet meet: most facts have no reference a retriever or understander can return,
and the existing fence receives every fact in the surface rather than only the
claims selected for one exchange.

C74 proved one stable protected-world claim identifier and its personal
acquisition. It did not make the rest of the knowledge surface addressable. C75
closes that interface gap without claiming the wider protected-world catalogue or
any learned data now exists.

## Contract

| Concern | Producer | Result | Refusal or boundary |
|---|---|---|---|
| Snapshot catalogue | `SAO.Knowledge` reads its existing conversation-specific facts and conditioning | Detached schema-versioned catalogue with person, listener, tick and an ordered list of `{ref, topic, fact}` entries | Reading writes no state and adds no fact absent from the existing surface |
| Claim reference | Deterministic topic order plus deterministic ordering of each fact's complete scalar/table content | Unique snapshot-local references; a protected world claim retains its stable `claimId` inside the fact | A reference has meaning only inside the exact catalogue snapshot; it is not a new durable knowledge owner |
| Person facts | Existing person-private belief store | Known people enter the same catalogue instead of remaining reachable only through one named query | No global identity or live truth lookup fills a missing belief |
| Selection | Exact reference list against one catalogue | Detached selected entries in catalogue order | Unknown, duplicate, malformed or foreign references refuse the whole selection |
| Factual fence | Existing field/value fence projection over selected entries | Only scalar fact slots from admitted claims become sayable | Conditioning, metadata and unselected owned facts do not widen the factual vocabulary |
| Legacy surface | Existing `claims` and `flatClaims` calls | Existing callers retain their behavior | C75 does not route current speech or actions through a model |

## Evidence

The C75 border will drive the shipped Lua in the installed Kahlua runtime. It must
show that insertion order does not change references, distinct facts retain
distinct references, known-person beliefs appear, selection is detached and
ordered, unknown or duplicate references refuse atomically, and an unselected
owned fact is absent from the selected fence. The existing knowledge-surface and
Java fence borders must continue to pass, followed by the complete repository
gate.

## Downstream use

This catalogue is the SAO side of the immutable input described by Speakeasy
Record 51. Speakeasy still needs its own target-authoring policy and task datasets.
SAO still needs a broader protected-world claim port than C74's single example.
Those are separate producers whose absence remains visible after this batch.
