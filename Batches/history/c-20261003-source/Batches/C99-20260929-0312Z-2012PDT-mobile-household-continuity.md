# C99 - Mobile household continuity

| Field | Record |
|---|---|
| Batch | C99 |
| Date | 2026-09-28 |
| Timestamp | 2026-09-29 03:12 UTC / 20:12 PDT |
| Name | Mobile household continuity |
| Status | Source implementation and installed-Kahlua verification complete; loaded physical-room acceptance open. |
| Threads | T-002, T-003, T-004, T-006, T-008, T-030 |

A camper is now represented as one moving place rather than unrelated vehicle,
inventory and teleport states. `SAO_MobileHousehold` assigns a durable id on the
native vehicle, observes its script, exact part containers, passengers, speed,
position and towing edges, and retains completed entry, exit, separation and
failure transitions in GlobalModData. Project RV's persistent vehicle id is an
interchange alias; it does not replace SAO's identity owner.

Physical Project RV room entry is joined to this record. The transition assigns
one provider room, records the exterior anchor and occupant, releases a native
seat when needed, and moves the survivor into the real room where ordinary
appliances and objects remain native. Exit re-finds the moving vehicle through
its durable id and uses the native seat-outside pairing when possible. A
towable without a passenger mesh places the survivor beside the exterior
anchor. Motion refreshes the exterior anchor while a person is inside.

The procedural planner treats the mobile household as person-private spatial
knowledge. It can retain inspection, approach, entry, occupant/store
reconciliation and departure as one purpose, while exact physical occupancy
can begin directly at reconciliation without inventing an earlier route
receipt. On held ground, night pressure may select a known accessible camper or
motorhome, use its physical room when available, recover through the existing
native rest owner while stationary, and leave after dawn. Refused native entry
is recorded and cannot be replaced by a successful belief.

Mousecat adds a compact moving-place section with physical state, exterior
anchor, speed, occupants, stored items and weight, material revision, towing,
transitions and failures. It reads the same persistent state and performs no
simulation work.

The physical assets remain external and attributed to Project RV Interior,
KI5, Rolling Refuge and their support runtime. C99 contains no copied source or
media from them. Their activated assets are domain evidence and physical
providers; the causal continuity, planning and observation owner is SAO.

| Verification | Result |
|---|---|
| Production Lua compilation | Passed in normal and debug engine modes. |
| Border 212 | Passed thirteen identity, store, towing, planning, movement, room, rest, refusal, exit and persistence cases plus three source mutations. |
| Planning and observation regressions | Passed: 17 procedural-planning cases and 43 observation cases plus native health controls. |
| Source-integration lineage | Passed: six implementation families; the four physical mobile packages are domain evidence and activation grants no ownership. |
| Loaded acceptance | Open: Build 42.21 must complete entry, room use, exterior movement and exit in one native receipt before the physical transition is called loaded-proven. |

The scenario and all behavioral observations remain unreviewed and cannot enter
the dataset without operator ratification.
