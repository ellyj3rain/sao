# C61 - Demand-led native hydration

| Field | Record |
|---|---|
| Batch | `C61` |
| Date | 2026-09-20 |
| Name | Demand-led native hydration |
| Status | Closed through the enforced full commit gate. |
| Threads | [`T-003`](THREADS.md#t-003), [`T-006`](THREADS.md#t-006), [`T-007`](THREADS.md#t-007), [`T-008`](THREADS.md#t-008), [`T-030`](THREADS.md#t-030) |

## Native ground

Dormant search now hydrates bounded building chunks through Project Zomboid's
native streamer and loot generator. A density weave removes the local-player
zombie-density contribution only while SAO performs that bodyless hydration.
Persistent UUIDs in native object and item ModData identify static containers,
fluids and ground items across save/reload; physical fingerprints make moved or
replaced sources conflict instead of aliasing.

The Java adapter returns exact source, item, fluid, quantity and revision rows.
Lua persists a bounded observation ledger, rejects incomplete or oversized
protocols, retries loaded reconciliation and compacts old chunks, places,
conflicts and result receipts. Loaded survivor and player mutations rescan the
same source truth. Vehicle sources are observed with unsupported access until
their separate persistence surface is proven.

## Consumer boundary

Room names and distribution tables remain search possibilities. They no longer
answer current stock, spending or refill. A person learns a complete native
observation only by reaching the place. Observed stock enters that person's
private belief, while executable availability requires a separately proven
`accessible` result.

The first implementation treated arrival as access and consumption. Review
rejected it because it bypassed floors, paths, barriers, permission, carrying
and native physiology. The final path awards no food or water day and performs
no offscreen mutation. Reservation remains as bounded substrate and cannot
select the `unknown` or `unsupported` states emitted by production.

## Verification

[Border 178](../tools/world_sources_test.py) executes the production ledger in
the installed Kahlua VM. It covers unknown-access refusal, exact identity,
source locking, separate-source concurrency, private beliefs, replacement and
movement conflicts, incomplete protocol rejection, retry, compaction and
reservation protection. The same border weaves installed engine bytes and runs
the shipped jar as a real premain agent, proving the already-loaded target is
retransformed. The Java build succeeds against installed Build 42.20.4 and all
74 Lua sources compile in normal and debug modes.

The staged commit hook also resolves the installed VM. Its first run caught and
repaired a stale global-census allowance and a Border 140 module-list omission;
the corrected walking control again proves 150 tiles per day, 5 per hour and no
near-goal overshoot. Neither repair changes production movement behavior.

The [evidence record](../artifacts/audits/20260920-0844Z-0144PST-native-world-sources/README.md)
holds the review findings, repairs, runtime receipts and final gate. Mechanical
proof and loaded-world acceptance remain separately named.

## Continuation

The next implementation unit is specified across R6, R7 and R9: choose one
exact source interaction point; prove floor, route, door/barrier, claim and
vehicle permission; transfer the exact item or fluid; invoke native carried
consumption; and publish an exact-once durable result tied to the observed
revision. Interruption releases ownership, reload reconciles it, and only a
completed result may credit need or provisioning. R10b historical integration
waits for that performed-action substrate.
