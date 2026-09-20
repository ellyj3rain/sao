# C60 - Perception and world access

| Field | Record |
|---|---|
| Batch | `C60` |
| Date | 2026-09-20 |
| Name | Perception and world access |
| Status | Closed through the enforced full commit gate. |
| Threads | [`T-002`](THREADS.md#t-002), [`T-003`](THREADS.md#t-003), [`T-006`](THREADS.md#t-006), [`T-008`](THREADS.md#t-008), [`T-030`](THREADS.md#t-030) |

## Loaded evidence and access

The actual scanner output now excludes Build 42 animals before emitting person
rows. Activity participation at the cashier counter and in ball play requires a
fresh firsthand person belief and a current same-floor, facing, range and
occlusion check. Installed Lethal Stealth prone state reaches the existing
stance reader, and combat drops a target when the engine deactivates it.

Material access now keeps acquisition separate from use. Vehicle source caches
retain their live vehicle and part, refuse removed or unloaded vehicles, refresh
position and ask `canAccessContainer` again. Every remembered material source
requires the actor's current floor and reach. Ground offers must still occupy
their observed loaded square. SAO's world-container action derives from the
vanilla transfer action, preserves its native item/container rules and rechecks
current loaded reach, obstruction and vehicle permission throughout execution.

## R10a substrate

The [evidence record](../artifacts/audits/20260920-0517Z-2217PST-perception-world-access/README.md)
inventories every loaded source cache and the installed unloaded substrate.
Meta-grid rooms establish geography and resource possibility; they do not prove
stock, quantity or access. Actual containers, fluids, vehicle parts and world
items are loaded truth. The present `SAO_Places` room-name and visit-count model
therefore remains a legacy proxy rather than grounded dormant supply.

R10a is planned as an ordered implementation contract: validate durable native
source identities; record explicit unknown/available/spent/inaccessible/conflict
observations; reserve without crediting acquisition; reconcile loaded chunks
against native truth and refuse conflicts; then migrate material consumers off
room-derived availability. This plan is concrete and owned, while its producer
and reconciliation implementation remains the next unit.

## Verification and review

Borders 154, 155, 157, 176 and 177 cover vehicle source authority, animal
classification, combat/mod state, private activity partners and use-time world
access. Border 177 mutates loaded membership, floor, obstruction, ground-item
membership, vehicle permission and timed-action revalidation. The full scope
scanner now receives all shipped Lua files and refuses an empty invocation.

The required review panel found two blocking defects in the first implementation:
cached source reach ignored floors and loaded vehicle membership, and generic
vehicle transfers lost their permission check after selection. It also found a
ground-offer access gap. The final implementation above closes all three; the
reviewers report no remaining severity. Java compiles against the installed
42.20.4 jar and all 73 Lua sources compile in normal and debug modes.
The first enforced gate reached the complete native and historical suites and
refused only two stale reach-collision allowances for the raw cashier/playmate
arithmetic C60 removed. Deleting those obsolete explanations makes the gate
derive the current source again; the closing commit reruns the complete gate.

## Continuation

The loaded half of R6 is closed within the audited paths. Dormant R6 proof waits
for the already specified R10a ledger and reconciliation implementation. R7
then owns action results and interruptions beyond the access checks established
here; R8-R15 retain their existing dependency order. Loaded-world play
acceptance remains a separate receipt.
