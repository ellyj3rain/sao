# C70 - Treatment completion

| Field | Record |
|---|---|
| Batch | `C70` |
| Date | 2026-09-21 |
| Name | Treatment completion |
| Status | Closed; complete repository gate enforced by the publishing commit. |
| Threads | [`T-002`](THREADS.md#t-002), [`T-004`](THREADS.md#t-004), [`T-006`](THREADS.md#t-006), [`T-008`](THREADS.md#t-008), [`T-030`](THREADS.md#t-030) |

## Measured contract

Open-wound aid called vanilla `ISApplyBandage` but returned `"treated"` as soon
as the queue call did not throw. Both NPC care paths immediately changed trust,
the patient's answered-cry stamp, Doctor experience and voice. The player's
bandage menu had the same defect for trust. An interrupted action, a native
refusal or a dirty dressing that held for zero time could therefore produce a
social history of care that the named patient never received.

The [producer matrix](../artifacts/audits/20260921-1105Z-0405PST-treatment-completion/PLAN.md)
separates request admission, the native body mutation, result classification
and one-time consequence consumption.

## Implemented behavior

`SAO_Treatment` owns open-wound bandaging for SAO self-care, NPC aid and player
aid. Its durable record contains only scalar actor, patient, item, body-part
index, status, reason and consequence receipts. Bodies, inventories, body
parts, items and timed actions remain in a current-world runtime map.

The custom action calls Build 42.20's `ISApplyBandage.complete` rather than
reimplementing treatment. It publishes `completed` only when vanilla returns
success, the exact patient part is bandaged with positive life and the exact
dressing has left the actor inventory. A dirty zero-life dressing or native
refusal is `ineffective`; stop, cancellation or queue loss is `interrupted`.
Actor/patient identity, same-floor reach, exact part membership and exact item
identity are checked before the native mutation.

Trust, the patient's `aidedAt` response, SAO's additional Doctor experience,
the existing `aid` voice, treatment log and critical-care gesture each have a
saved consumption receipt. A completed result can resume after reload as its
required bodies and modules become available without repeating channels already
consumed. A pending record with no live action remains pending and reserves its
item and wound; elapsed time and queue absence after reload are not completion
evidence. Death, controller ownership exit and player death release pending
work and its live handles while terminal history remains.

Critical-care choreography now follows successful treatment. It no longer asks
the gesture action to start while the bandage action is occupying the medic.

## Verification

Border 183 executes the shipped owner in the installed Kahlua VM. It covers
queue-only state, exact patient/part persistence, effective completion,
idempotence, stop, dirty-bandage ineffectiveness, native refusal, mutation-time
patient change, request-time identity refusal, self-treatment, reload-unknown
reservation, participant release, queue refusal, staged reload consumption,
the player key domain and future-schema refusal. Its production mutation
applies care consequences at queue time and flips `queued_without_effect`.

Every shipped Lua file compiles in the installed normal and debug compilers.
The C68 handover border and the voice-vocabulary reach check remain clean. The
[evidence record](../artifacts/audits/20260921-1105Z-0405PST-treatment-completion/README.md)
holds focused, full-gate, publication, installation and startup receipts.

## Limits and continuation

C70 closes the loaded open-wound bandaging result. It does not claim dormant
treatment, disinfection/stitching completion, complete private inventory,
dormant spoken access, actual radio reception or loaded-save play acceptance.
Those obligations retain their ROADMAP and SUBSTRATE owners.
