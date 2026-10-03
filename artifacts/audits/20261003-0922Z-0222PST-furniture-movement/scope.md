# Furniture movement integration

C117 follows DR-053's shared physical ownership rule. The installed furniture
push/pull implementation remains the relocation owner; Rebalanced Prop Moving
retains pickup, placement, rotation and scrap rules. Optional plumbing,
electricity and bathing sources retain their fixture and contents state.

The source pins in `installed-sources.json` identify the installed Build 42.21
and Workshop inputs inspected for this slice. They are source inspection, not
loaded-game evidence. This adapter ships original integration code; inspected
third-party modules remain installed dependencies rather than copied sources.

| Observed seam | Consequence for integration |
|---|---|
| Single-player effort completion schedules a later shove commit | Effort acknowledgement does not establish furniture relocation. |
| The installed private pending queue resolves by coordinates and sprite | Own the single-player delay with exact captured handles; preserve native animation and physical relocation. |
| Multi-part executeMove delegates to executeServerMove | One outer transaction measures the result and avoids duplicate notifications. |
| Pickup and placement preserve native carrying wrappers and object events | Keep the composed native path; do not replay plumbing/electricity object events. |
| WaterPipes registration uses its separate movement event and retains old barrels | Reconcile only verified relocation through its owning state and exact actor. |
| Direct relocation bypasses bathing pickup eligibility | Refuse a member still registered with the tub system before changing anything. |

Validation starts with Lua structure/compiler and exact installed-source
execution. Controlled map, body and item receivers exercise effect sequencing,
identity, deferred cancellation, contents and fixture state; their results do
not establish native loaded-world movement. Runtime proof retains its own hashes,
actual exit codes and rejected defect controls. Namespace,
cache lifetime, gate reach and documentation/package checks cover the new module's
repository contracts. The required remote ci-verify and codeql-python jobs remain
a separate publication constraint. Existing unrelated observation, education,
feeding and repair evidence is not repeated for this isolated adapter.

NPC furniture planning, admitted NPC work and private learning remain further
implementation. This slice uses the existing installed player's push/pull caller.
The bathing module's general pickup/rotate/scrap false-verdict override, bathing
clothing custody, wider utility behavior, multiplayer ownership and loaded-game
acceptance remain separate open work. Pico owns the appearance pipeline.
