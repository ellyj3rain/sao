# C114 - Uncapped native observation

| Field | Record |
|---|---|
| Date | 2026-10-02 22:44 UTC / 15:44 PST |
| Scope | Native renderer and capture pacing for isolated observation |
| Public parent | `ffa1e7220e47ffc62e033b84182f86f086ae10e4` |
| Threads | T-030 |
| Version | `3.10.3.2-pre-alpha` |
| Status | Implemented; required verification has separate receipts |

The operator requests removal of artificial ceilings, with any selected ceiling
at least 120 FPS. The old capture admission waited 50 ms for one view and 100 ms
for multiple views. Capture now admits a ready native frame immediately while
retaining one outstanding publication. Frame identity, native pixel readback,
checksums, stale-command refusal and eight-frame retention keep their owners.

New and continued isolated observer caches start with native frameRate 120,
uncappedFPS false and VSync false. Installed Core.loadOptions resets a persisted
true uncapped option to false and 60 FPS. After that load, the observer calls the
same Core.setFramerate(1) entry point used by the native uncapped selection.
Existing detached observer ownership and debug guards precede the operation.
Its runtime log reports the effective native flag. Ordinary player ownership
refuses this observer operation. Prelaunch exceptions restore prior options
through the existing saved-run transaction.

Border 198 exercises immediate capture admission and the installed runtime
renderer flag. Restoring the 50 ms timer fails the named readiness assertion;
restoring the native 60 FPS selection fails the effective flag assertion.
The busy-publisher control still rejects removal of the one-frame bound.
Border 233 exercises saved option replacement, duplicate normalization,
idempotence and preservation of other options. It has thirteen tests.

Independent review identified the native options reset before completion; the
revised native API join resolves that finding. Installed visibility checks pass
six native cases and ten source controls. Capture publication passes eleven
source controls. These probes establish admission and configuration, not actual
rendering throughput. The complete closing gate retains its own verdict.

The first closing gate detected a missing C114 version classification. Its
interruption returned zero to Git on Windows despite the explicit failure.
That local commit is retained privately and removed from the public candidate.
The corrected patch classification, generated version map, metadata and stamped
JARs enter a fresh complete normal hook. The failed log remains retained.

The second complete hook exits one for current document headers that still
state the prior patch version; all runtime borders pass. Current Version cells
and the README Status coordinate are synchronized with the generated VERSION.
Historical ledger entries retain their original coordinates. The final normal
hook runs on the synchronized candidate, with all earlier receipts retained.

Speakeasy Record 86 shortens active polling from ten to one millisecond.
Mousecat A23.3 yields immediately after each completed live request. Both keep
sequential ownership and terminal/error backoff. The image protocol remains
lossless PNG publication. Continuous encoded video and achieved 120 FPS remain
separate work and measurements.

The completed twenty-minute C113 pass saved normally at hour 32.38853073120117,
with both original people alive and no native runtime errors. Its 45-second
sample observed 3.56 distinct native captures per second. The C114 benchmark
reopens a separately copied and verified save; the original attempt remains
unchanged. Native FPS, delivered images and browser presentation are distinct.

A 45.277-second interval in the uncapped copy records 123.153 native observer
update callbacks per second and 2.164 composite capture publications per second.
The normal-speed world advances 0.375038 game hours. The callback counter is
incremented in the observer update and does not measure rendered or displayed
FPS. This is one native workload and supplies no controlled speedup estimate.
The image-delivery bottleneck remains open after the artificial limits are
removed. The isolated runtime log confirms renderer uncapped=true.

The benchmark finishes normally at hour 34.346580505371094 with exit zero,
native save returned and an empty runtime-error list. Original saved files
verify unchanged. Its last 300 sampled frames span 133.364 seconds and yield
2.242 distinct composite images/s, with median capture age 200 ms at the local
reader. Rendered and browser FPS remain unmeasured. Compact source-bound
evidence is retained in artifacts/audits/c114-uncapped-observation/verification.json.

The operator's further behavior observation remains open: distinguish perceived
living people, animals, apparent death, undead and inanimate objects through
private evidence and uncertainty. Recognition, threat appraisal, willingness
and native ability to use violence require separate examination. The prior pass
established no confrontation and supplies no basis to force aggression.
