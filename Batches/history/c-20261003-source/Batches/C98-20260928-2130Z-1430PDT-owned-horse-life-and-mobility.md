# C98 - Owned horse life and mounted mobility

| Field | Record |
|---|---|
| Batch | C98 |
| Date | 2026-09-28 |
| Timestamp | 2026-09-28 21:30 UTC / 14:30 PDT |
| Name | Owned horse life and mounted mobility |
| Status | Closed with current-engine loaded travel acceptance. |
| Threads | T-002, T-003, T-004, T-006, T-008, T-030 |

The Horse team's complete physical implementation now ships inside SAO: animal and item definitions, models, textures, sounds, tile data, gear, recipes, animation sets, mounting and dismounting, riding movement and collision, stamina, attachments, mounted combat and network synchronization. `pack=HorseMod` and `tiledef=HorseMod 2026` load the integrated assets. The external Horse Workshop entry is no longer activated by the study profile.

The original player-number mount index could collapse every off-slot survivor onto `-1`. Mount identity now keys the native human body, single-player mounting admits SAO bodies, and the horse update walks every loaded mount rather than only active player slots. A mount can receive bounded autonomous input while retaining the Horse team's real collision, stamina, animation, fall and teardown consequences.

SAO's native pathfinder now exposes route waypoints without applying foot movement. A capable person who knows a nearby mount may answer a sufficiently long route with a maintained approach, mount, ride and dismount purpose. Exact phase results advance only from mounting, route and dismount execution. The durable person record retains the native animal id and physical relation; spatial memory records the observed horse; Mousecat exposes the mount, stamina, phase, destination and current native waypoint.

Loaded execution exposed three physical mismatches that static fixtures could not establish. Horse steering uses screen-space rotation opposite the native route vector; mounted bodies require a wider waypoint radius than feet; and an occupied model attachment may need a safe adjacent dismount square. Those seams now preserve the Horse movement owner while allowing the SAO route to complete. Source-owned horse zones also validate representative metagrid squares and retain bounded extents.

The complete-tree gate exposed imported integration defects outside that route: attachment aliases appeared global, Horse and vanilla translations were invisible to the player-surface census, ranch occupations were queried as designations, spatial tolerances were anonymous, bite audio referenced a nonexistent global attacker, Horse registered its item-tag vocabulary through the engine-wide registries pass, and five Horse behavior surfaces bypassed the persisted county draw. The source now binds those names and engine seams explicitly; the item tag lives in Horse's ordinary shared module, damage, body-part selection, mane, fall, grunt-timing and attachment-drop draws advance `SAO_Rand`, and no external Horse namespace remains.

Build 42.21 also changed native reading, square-reach and headless-fixture behavior. The retained print-reading fixture now supplies the online identity required by `ISReadABook.complete`. Water interaction uses the engine's corrected wall reach directly, while the installed-oracle border still holds closed doors, windows and walls inaccessible. Authored-world verification now admits intentional clear outdoor origins and counts the Horse study alongside the residential, service and farm variants. Observation checks select sections by their stable ids so the added horse section cannot change a dormant person's needs or inventory verdict. Pharmacology writes and checkpoints the same native additional-pain channel, and its native cognition proof drives the engine's per-moodle Java update rather than the changed Kahlua reflection surface. The cooking fixture avoids duplicate square attachment so the engine's live-body flag remains an effective detachment proof. The blinded-tree gate selects Windows Git when Windows Python is launched from WSL, preserving worktree discovery after inherited Git overrides are scrubbed.

| Verification | Result |
|---|---|
| Source and asset surface | Passed: representative definitions, models, textures, animations, movement and mount owners ship in the SAO tree. |
| Lua syntax | Passed: all 183 shipped Lua files compile in normal and debug engine modes. |
| Java build and bridge | Passed: the stamped jar builds; 262 bridge methods and 409 Lua call sites match. |
| Ownership profile | Passed: Horse is absent from activated external mods and present in the source-owned baseline. |
| Loaded acceptance | Passed on Build 42.21: the full living-world cohort spawned horse 189, began maintained travel, mounted, reached the native route destination and dismounted. The final durable relation is inactive, all four owned result tokens completed, exit code is zero and the runtime-error scanner is empty. `artifacts/audits/c98-owned-horse-life-and-mobility/loaded-receipt.json` retains the report, observation and log hashes. |

The study remains `datasetAdmission: unreviewed` and has no behavioral verdict. The receipt establishes physical execution and persistence only.
