# C63 - Provisioning result consumption

| Field | Record |
|---|---|
| Batch | `C63` |
| Date | 2026-09-20 |
| Timestamp | 2026-09-20 18:55 UTC / 11:55 PST |
| Name | Provisioning result consumption |
| Status | Closed, validated and deployed. |
| Threads | [`T-003`](THREADS.md#t-003), [`T-004`](THREADS.md#t-004), [`T-008`](THREADS.md#t-008), [`T-030`](THREADS.md#t-030) |

## Completed result to material state

C62 ends with an exact completed-use receipt and deliberately grants no house
stock or settlement credit. C63 gives that receipt one downstream consumer.
The action captures its current house only when the source is inside the
house's existing claim, and records that claim incarnation and the Material
setting with the completed event. Personal use and use outside a held place
remain personal. Delivery then resolves a scalar copy of that exact native
source at its current revision. A conflict or unavailable store remains
unacknowledged for retry. A released, moved or same-named re-formed claim
cannot inherit the earlier event.

`SAO_Material` projects the source into the house store by source identity. A
durable source-owner index permits one house owner for each physical source; a
move or new physical fingerprint retires the prior owner. Per-source result
order prevents round-robin retry from letting an older receipt reverse newer
ownership or evidence. Item and finite-category totals are rebuilt from at most
256 retained source rows. Native-projected stores refuse abstract `add`, `take`
and rollback mutation so a generic stock call cannot duplicate or spend the
ground behind the projection.

After reconciliation, larder and water standing claims derive from the
projected totals. Recognition may synchronize storage only when a settlement
already exists for the group. It cannot claim a settlement, invent rooms,
food, water, membership or an organization. The consumer acknowledges the
receipt last, after every required projection step succeeds. Material persists
the first applied decision and every affected house until derived writes
succeed. Each successful Standing and Recognition phase is also persisted
before acknowledgement, so acknowledgement retry cannot refresh an old count
or rewrite newer settlement evidence. Every actual house-aggregate mutation
advances a projection generation. Derived claims retain the source-observation
time and result identity; a later live quartermaster scan wins over stale source
truth, while a genuinely newer aggregate generation remains derivable. The
acknowledgement is then the durable terminal fact and transaction cleanup
follows it. Refused acknowledgement, reload, a later source conflict and
interruption between acknowledgement and cleanup all resume or clean the same
persisted decision instead of re-reading the event into a new outcome.

C62 schema-3 receipts and actions already past final binding have no C63
action-time attribution. Schema 4 marks them `legacy-unattributed` and retires
them without inferring later membership or granting house credit. New actions
refuse before native mutation when Standing cannot supply an exact
personal/held-ground answer.

The graph store now has schema 2. Its one-time upgrade retires every pre-C63
`house:*` store that lacks a native-source projection and every settlement base
that lacks completed place-development grounding. It also retires a linked
provisioning-only organization shell, or preserves an election-grounded chair
while clearing the old base-authored boundary, governance and membership. The
durable upgrade receipt records each retirement/sanitization count and states
that no earlier history was inferred. Standing schema 2 separately clears
legacy larder, water and hearth projections and assigns monotonic incarnation
identities to retained group claims with the same provenance rule. Future graph
or Standing schemas refuse without mutation; graph refusal also detaches prior
world aliases. This prevents old queue-authored stock and provisioning-authored
rooms, food, water and social facts from surviving merely because the false
producers were removed from new execution.

## False producers retired

Standing setters no longer call settlement recognition. The dormant
need-day projection no longer treats elapsed consumption as house
provisioning. Accepting `depositSpareFood` into the action queue no longer
credits shelving. These paths were requests, derived conditions or state
summaries rather than completed transfers. Shelving must publish its own
performed-action receipt before it can affect material state.

Population scheduling consumes provisioning results before dormant projection.
Integration and Labor receive accessible material while personal and house
ownership stay distinct through WorldGenesis and inspection. Quartermaster
scans and completed-result claims carry separate evidence bases; dormant need
dates write no inventory claim. Claim movement, abandonment and dissolution
retire house material, standing and existing-settlement storage projections.
A delayed receipt revalidates held ground and cannot recreate a released house.
Claim retirement is checked before a compacted non-ground observation can leave
the result waiting, so an abandoned place terminates as a retired-group no-op.
Settlement formation remains owned by place use and development.
`Settlement.claim` therefore requires a completed `place-development` result
identity and no longer creates an organization or organization membership as a
side effect. Material access returned to graph, labor and inspection readers is
a detached scalar view; mutating that view cannot bypass Material's owner APIs.
When the Material sandbox surface is off, the completed action is acknowledged
as `material-disabled` before any house, standing or settlement projection,
and Labor cannot infer quartermaster work from a retained house store. Person
access views and Standing's larder, water and hearth readers hide retained
material claims from inspection, graph and live decisions. Quartermaster scans
cannot replace those claims while disabled. The durable facts remain intact and
become visible again if the option is re-enabled.
That choice is captured when the result is published: a later toggle neither
retroactively counts a disabled event nor abandons a transaction already in
flight.

## Verification

[Border 180](../tools/provisioning_result_test.py) executes the production
WorldSources, Material, Settlement, Recognition and Provisioning modules in the
installed Project Zomboid Kahlua VM. Fifty-two production cases cover exact
projection, isolated copies, finite-category accounting, provenance-tagged
standing, acknowledgement order, no settlement creation, idempotent
replacement, graph rebind, persisted retry after observation loss, one-owner
transfer, fingerprint and result-order continuity, personal refresh/no-op/wait
partitions, claim lapse and reincarnation, downstream refusal,
ownership-preserving access views, dissolution, proved ground removal, schema-3
upgrade, retry fairness, corrupt context refusal and the 256-source bound. The
fifty-two cases also execute first-result empty container/ground projection,
graph and Standing false-output retirement,
organization sanitization, required place-development grounding, event-time
Material selection, all person/Standing/Labor Material-off boundaries,
durable derivation phases, projection generations, evidence-time ordering,
acknowledgement-refusal/reload recovery, the
acknowledged-before-cleanup crash window, prior-world detachment and future
schema refusal. Sixty-eight named controls mutate the causal schema, attribution,
retry, ordering, ownership, migration, lifecycle, player-facing contract,
false-producer, graph-summary, scheduler and dormant-sweep seams.

The retained source-action, world-source, handoff, reconstruction, settlement
and dual-mode Lua checks run beside the new border. Mechanical proof remains
separate from an observed play receipt.

The enforced full gate passes all 191 scripts through Border 180. The exact
deployment, independent review findings, unchanged save/companion manifests and
responsive startup are retained in the
[C63 evidence record](../artifacts/audits/20260920-2039Z-1339PST-provisioning-result-consumption/README.md).

## Continuation

C63 closes consumption of C62's completed food/water result into a bounded
material projection. R9 remains open for performed shelving, acquisition,
carrying, storage, sharing, hoarding, trade, conservation and place
development, each with its own action result. Settlement formation and mature
historical integration continue to wait for those causal producers. R11-R12
training work may use this seam as one grounded action-to-state example, not as
evidence that the full life simulation exists.
