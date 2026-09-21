# C71 evidence

| Field | Value |
|---|---|
| Timestamp | 2026-09-21 18:38 UTC / 11:38 PST |
| Status | Complete repository gate clean; publication and installation pending |
| Plan | [Producer and consumer matrix](PLAN.md) |

C71 gives each person one fresh read-only inventory view while Project Zomboid
and the existing action owners retain every item and mutation. The
[batch record](../../../Batches/C71-2026-09-21-complete-private-inventory.md)
states the behavior and remaining boundaries.

| Evidence | Scope | Current result |
|---|---|---|
| Border 184 private inventory | Real native nested items in the installed engine | Loaded, dormant and reloaded rows agree by item and direct holder; removal, replacement and transfer refresh; legacy snapshots and aggregate totals refuse. Removing recursive carriage fails at `nested_loaded`. |
| Decision consumers | Java and Lua food, drink, medicine, gear, gifts, radio, corpse and ground-item reads | Carried reads use one recursive owner; loaded world searches preserve C61 holder identity and actor-specific access. |
| Material-claim boundary | Standing schema 4 and provisioning reconciliation | Inferred larder/water totals retire; only completed native-source results with complete coverage can publish a claim-wide total. |
| Native person regression | C51/C64 dormant continuation and physiology | Production plus all 36 compiled mutation controls pass after nested traversal moves to the shared reader. |
| Vehicle and provisioning regressions | Existing vehicle-holder, source-result and delivery owners | Borders 154 and 180 remain clean under the new inventory view and schema. |
| Full closure gate | Whole repository against the installed engine and JDK | `full-gate.txt` ends with `[check] all borders clean`. |

The controlled proof establishes exact observation, privacy, coverage refusal
and compatibility with existing action owners. A main-menu startup receipt
establishes packaging and loadability only; loaded-save behavior and
player-visible acceptance remain separate observations.
