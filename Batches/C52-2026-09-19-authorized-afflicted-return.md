# C52 - Authorized afflicted return

| Field | Record |
|---|---|
| Batch | `C52` |
| Date | 2026-09-19 |
| Name | Authorized afflicted return |
| Status | Closed implementation batch; loaded-world receipt pending. |
| Threads | [`T-001`](THREADS.md#t-001), [`T-002`](THREADS.md#t-002), [`T-006`](THREADS.md#t-006), [`T-007`](THREADS.md#t-007), [`T-008`](THREADS.md#t-008) |

## Behavior

An Afflicted return is now one durable transaction between the repositories.
ZAO owns the recovery event and exact turned source. SAO owns the returning
person, supported living state, staged shell and controller adoption. The
transaction records its authorization and phase before either side relinquishes
ownership. Repeated callbacks, Lua reload and an acknowledged source removal
resume the same transaction rather than minting another person or body.

The source is held before publication. Its current possessions replace the
historical living inventory while its pre-death statistics, wounds and
experience come from the matching death sequence. SAO publishes the restored
person only after ZAO confirms that the authorized source was removed. Loaded
returns receive a controller; offscreen returns finish as durable living state
without inventing a loaded body. Ordinary dead records remain unable to
materialize.

Returned people are critically viable and still injured. ZAO clears native
lethal and fake Knox state, restores only the weighted health needed to reach
the return floor, and preserves wounds, treatment, fractures, ordinary wound
infection, adverse statistics and experience. SAO records Knox as systemically
dormant. There is no spontaneous Afflicted-to-Crossed roll.

## Persistence and refusal

OnSave checkpoints supported person state, native visual state, position,
physical facts and pending return journals. Versioned checksummed fragments
carry snapshots beyond Kahlua's native string limit. Recursive item checks
refuse oversized ModData strings that the installed serializer otherwise loads
as silently corrupted fields. A failed checkpoint retains the last valid
snapshot and prevents reconstruction from claiming it is current.

Source preservation covers loaded, fake-dead, virtualized and exact
reanimated-registry ownership. A missing unique source cannot authorize a
replacement clone. Per-identity callback failure keeps that source held and
unavailable while unrelated sources continue. Completed native saves are
covered; atomic recovery from interruption between the engine's separate save
surfaces remains R4 work.

## Evidence

The [joint evidence record](../artifacts/audits/20260919-0735Z-0035PST-r1-return-evidence/README.md)
preserves source hashes, full-gate logs and compact native receipts. Production
Lua runs under the installed Kahlua VM. Installed world-version-249 probes run
the native person, source and physiology serializers and operations. Named
controls remove authorization, owner checks, persistence, corruption guards,
injury preservation and lethal-state clearing and require the corresponding
failure.

Both repository gates pass. These are controlled VM and installed-engine
checks. They do not establish a rendered loaded-world return, a complete
running-save reopen, or recovery from interruption between separate native
save files.

## Crossed boundary

This batch does not close Crossed behavior. The audit found ZAO A32's claimed
Crossed decision pass unreachable: canonical Crossed state uses form `none`,
while the controller gates that pass behind a non-`none` form. Reaching the
existing pass would still provide only a small special-body routine, not the
canonical human-looking, cognitively intact person's weapons, tools, plans,
ordinary actions and social behavior.

The stored Crossed-to-Afflicted exposure is likewise only a daily proximity
proxy and changes pathogen state without transferring body ownership. Afflicted
people are not food; that interaction requires its own deliberate action and
result. F-084 and R4-R10 retain the full producer, representation, action,
transition and persistence repair rather than crediting it to this return
transaction.
