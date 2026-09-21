# C68 producer matrix

| Contract | Existing substrate | C68 producer and owner | Persistence | Evidence | Remaining boundary |
|---|---|---|---|---|---|
| Personal item request | Needs selects an actual carried item; Exchange/Controller choose the recipient | `Handover.begin` validates people, range, item identity and holder, then requests one vanilla action | Scalar pending record; live objects stay runtime-only | Border 182 queue/refusal and scalar-record cases | Reload without a supported item resolver remains unknown. |
| Performed handover | Vanilla `ISInventoryTransferAction` mutates holders | `SAOHandoverTransferAction.transferItem` repeats validity and verifies destination/source holders | Completed or terminal status with its event time | Native completion, interruption and holder-conflict cases | Loaded-save gameplay remains unobserved. |
| Gift consequence | Existing trust, voice, care and yield consumers | Handover applies the saved consequence once after completion | `effectApplied` on the completed record | Queue-only mutation control; repeat reconciliation | Open-wound treatment has its own unfinished completion boundary. |
| Debt settlement | Standing owns the existing personal debt ledger | Completed settlement handover calls the existing settle verb | Completion record plus existing Standing relation | Settlement call-site and completion-only contract anchors | Complete inventory and broader material appraisal remain open. |
| Bilateral exchange | Existing need-shaped barter identifies two possible legs | Proposal records both directions; acceptance requires both actions admitted | Term plus two handover IDs and statuses | Unaccepted, accepted-partial and accepted-complete VM cases | No player trade UI or dormant barter is claimed. |
| Partial exchange debt | DR-044 permits debt only for an accepted exchange or promise | Accepted term finalization reads one completed leg and one terminal failed leg | `debtApplied` on the term | Partial term and idempotence cases | Perceived obligation remains separate private experience. |

The implementation does not use queue acceptance as completion, reconstruct
holder truth from elapsed time, or turn a failed proposal into debt. These are
measured producer boundaries rather than new outcome rules.
