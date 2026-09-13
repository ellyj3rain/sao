# C104 - Perception carries the form

| Field | Record |
| --- | --- |
| Batch | `C104` |
| Date | 2026-09-11 |
| Name | Perception carries the form |
| Status | Closed append-only batch - implementation and records |
| Threads | [`T-008`](Batches/THREADS.md#t-008), [`T-030`](Batches/THREADS.md#t-030) |

## Record

SAO's Perception scanner now reads ZAO's form and performance from a turned
body's modData and carries them into the survivor's belief set.

The controller uses that performance directly: a higher form performance
widens the flee distance by up to half again. A Puker or a Leaper therefore
reads as a more serious threat than an ordinary shambler.

## What changed

- `SAOPerceptionScanner.java` emits `ZAOForm` and `ZAOFormPerformance`.
- `SAO_Perception.lua` stores them in the zombie belief.
- `SAO_Controller.lua` uses form performance to widen the flee distance.
- `PROJECTS.md` updates the ZAO and SAO status rows.
- `SESSION_STATE.md` advances to this batch.
- `BATCH_LOG.md` gains the `[C104]` row.
- `tools/version_replay.py` classifies `[C104]`.

## Verification

The Java bridge builds, the Lua structural gate is clean, and `bash
tools/check.sh` is clean.
