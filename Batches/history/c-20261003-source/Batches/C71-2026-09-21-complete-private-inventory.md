# C71 - Complete private inventory

| Field | Record |
|---|---|
| Batch | `C71` |
| Date | 2026-09-21 |
| Name | Complete private inventory |
| Status | Closed; complete repository gate enforced by the publishing commit. |
| Threads | [`T-002`](THREADS.md#t-002), [`T-003`](THREADS.md#t-003), [`T-004`](THREADS.md#t-004), [`T-006`](THREADS.md#t-006), [`T-008`](THREADS.md#t-008), [`T-030`](THREADS.md#t-030) |

## Measured contract

Loaded decisions used separate root-only scans for carried items, shelves,
vehicle compartments, ground items and corpses. Native v4 persistence already
preserved recursive item identity and direct parents, so a nested item could
exist during dormant advancement yet disappear from the same person's loaded
decision. Nearby shelf counts were also promoted to complete household larder
and water claims without claim-wide coverage.

The [coverage matrix](../artifacts/audits/20260921-1838Z-1138PST-complete-private-inventory/PLAN.md)
maps native ownership, holder identity, privacy, persistence and every affected
decision surface.

## Implemented behavior

`SAOPrivateInventory` builds a fresh actor-scoped view from Project Zomboid's
native inventory. Loaded views distinguish carried, static-container,
vehicle-part, ground-item and corpse holders. Items retain native IDs, exact
direct parents and current native objects; static, vehicle and ground holders
reuse C61's persistent identities. Vehicle access is evaluated for the named
person. Unexplored contents remain unknown, inaccessible compartments refuse,
and dormant views expose only exact v4 carriage while world access stays
unknown.

Carried and nearby decision readers now use that recursive view. Food, drink,
medicine, books, weapons, ammunition, water vessels, radio possession, animal
tools, corpse scavenging and player/survivor handovers resolve nested items from
their actual direct holder. Cached world selections retain the root permission
holder and revalidate vehicle identity, access and position before native
transfer. The view moves nothing and persists nothing.

Bounded loaded observations emit `aggregate=refused`. The quartermaster may
inspect current holders but cannot turn that radius into a house total.
Standing schema 4 retires inferred larder/water claims, and the setters accept
only completed Material reconciliation carrying explicit complete-coverage
evidence. Existing native action and result owners remain authoritative.

## Verification

Border 184 runs native nested items through the installed engine. It proves
root and nested carriage, direct-parent identity, loaded/dormant agreement,
removal, same-type replacement, holder transfer, repeated read purity, native
reload, v3/legacy refusal and aggregate refusal. Its compiled mutation removes
recursive carriage and must fail at `nested_loaded`.

The vehicle-ground border now verifies the shared holder view rather than the
retired parallel scans. Border 180 proves incomplete bounded evidence cannot
write standing totals and migrates old inferred claims. The full repository
gate compiles shipped Lua in normal and debug modes and rebuilds the Java jar.
The [evidence record](../artifacts/audits/20260921-1838Z-1138PST-complete-private-inventory/README.md)
holds the focused, full-gate, publication, installation and startup receipts.

## Limits and continuation

C71 closes private inventory observation for current decisions. A dormant
person still has no world-holder access, a bounded loaded view is not a complete
house store, and possession of a receiver does not prove reception. Dormant
spoken access, operating radio acquisition, the R12 example and the remaining
material action/result producers continue in ROADMAP and SUBSTRATE.
