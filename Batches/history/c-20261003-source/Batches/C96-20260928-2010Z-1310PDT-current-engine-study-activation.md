# C96 - Current-engine study activation

| Field | Record |
|---|---|
| Batch | C96 |
| Date | 2026-09-28 |
| Timestamp | 2026-09-28 20:10 UTC / 13:10 PDT |
| Name | Current-engine study activation |
| Status | Closed mechanically; loaded behavioral evaluation remains unreviewed. |
| Threads | T-002, T-006, T-008, T-009, T-030 |

Steam replaced the installed 42.21 engine jar without changing its displayed
version. Loose pre-update engine classes then shadowed the current jar and
failed on the removed `ImageUtils` type. The loose class directory was moved
intact into the isolated study archive; no installed jar or media file changed.

The study runner now declares its sealed mod ids to the loading agent. The
agent selects that cohort before client Lua loads, and the launch scenario
copies the same cohort into `currentGame` so native saves retain it. Late-loaded
study Lua configures after the one-shot boot event has closed, and the current
`setOptionPauseOnFocusloss` API replaces the retired focus-loss method while
retaining compatibility with the earlier spelling. SAO and generated study
metadata admit installed Build 42.21.

The installed engine also changed far-region actor publication from direct
`Set.add` to `IsoCell.addMovingObject`. Both routes remain guarded: the older
bytecode receives the explicit substitution and the current route passes
through the installed actor-set admission owner. The native probe now accepts
either verified engine route while its observer-admission mutation still
fails.

| Verification | Result |
|---|---|
| Current engine | Jar SHA-256 `e1a69eb743ede60b213a0fe7f8b83d4fcab773036d256cc4543a336f3b058a33`. |
| Loaded cohort | Study world, Survivor Awareness, Zombie Awareness and ZombieBuddy load before world entry. |
| Native observer | Detached identity, camera, lighting, two live feeds and person inspection publish in Mousecat. |
| Save binding | Native `mods.txt` retains the same four ids in the isolated save. |
| Dataset boundary | The scenario and its behavioral observations remain unreviewed. |

The loaded study exposed a separate behavioral result: after more than twenty
accelerated county hours, ordinary reading, following, sleeping and contact
waiting produced no maintained procedural purpose. That is a producer gap for
subsequent work, not a rule or accepted dataset example.
