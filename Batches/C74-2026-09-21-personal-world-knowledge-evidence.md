# C74 - Personal world-knowledge evidence

| Field | Record |
|---|---|
| Batch | `C74` |
| Date | 2026-09-21 |
| Name | Personal world-knowledge evidence |
| Status | Closed; complete repository gate enforced by the publishing commit. |
| Threads | [`T-002`](THREADS.md#t-002), [`T-006`](THREADS.md#t-006), [`T-007`](THREADS.md#t-007), [`T-008`](THREADS.md#t-008), [`T-009`](THREADS.md#t-009), [`T-030`](THREADS.md#t-030) |

## Measured contract

Speakeasy's approved world-knowledge contract requires a claim's carrier,
calendar horizon, personal acquisition path and retention to agree before the
claim can condition a decision. Its authoring compiler could inspect those
records but Survivor Awareness did not produce them. An origin region, current
age or radio in a person's inventory could therefore be mistaken for evidence
that the person knew a protected claim.

The [producer matrix](../artifacts/audits/20260922-0204Z-1904PST-world-knowledge-evidence/PLAN.md)
selects one bounded Knox event whose protected source says county residents
carry the day as lived experience. It maps the complete path from the county
calendar and a person's presence interval through acquisition, retention and a
real decision capture. Protected prose, extraction review, adjudication and
ratification remain in Speakeasy.

## Implemented behavior

`SAORecord` now maps the durable county-hour axis to an exact local calendar
instant. The mapping uses the same prehistory offset as the mature-world clock,
so hour zero in a late-start county remains anchored to the simulated 1993
history. Record days use that same axis and continue to work when day zero is
shifted onto a 1993 save.

Population admission records a person-private county-presence interval after
the person's origin ground has been selected. Initial residents begin on the
record's first lived day. Later arrivals begin at their actual admission hour
and cannot inherit events before they entered the county. People saved before
C74 have no explicit interval and remain acquisition-unknown; an origin label is
not backfilled into one. The daily historical
and live population pass advances dated claims only after their event hour.

The new world-knowledge owner writes an acquisition only when the selected
event is no later than the current county hour, lies inside that person's
presence interval and meets the protected source's adult-detail boundary. The
record binds the claim identifier, protected source and excerpt hashes, lived
path, event hour, access basis and supporting presence record. Read-only
knowledge and export surfaces return detached person-scoped copies. A separate
retention observation names the acquisition and the records supporting its age,
carrier, access and retention checks. No protected claim text enters SAO.

The evidence generator runs the production world-source, source-use,
world-knowledge and decision-capture modules in the installed Project Zomboid
Kahlua runtime. One actual source action completes while the same frozen person
record carries the acquisition. The deterministic bundle binds its event,
calendar, presence, acquisition and retention records with hashes and labels
its controlled-ground and loaded-save limits.

## Verification

Border 187 executes initial-resident, later-arrival, legacy-unknown,
child-detail, future-event, pending-calendar, other-person, detached-reader and
retained-claim cases. It
compiles the calendar implementation, generates the native evidence port twice
and verifies the same person's acquisition inside the captured event. Mutations
admit a future event, ignore the dated presence interval, invert the adult
boundary, bypass retention, expose live storage, remove the mature-save calendar
offset or change the event hash; each changes the intended verdict.

The existing calendar, person belief, decision capture, population
reconstruction and every explicit module-loading consumer remain clean. The
[evidence record](../artifacts/audits/20260922-0204Z-1904PST-world-knowledge-evidence/README.md)
retains the bounded bundle and full repository gate.

## Limits and continuation

The native action runs on controlled exact ground in the installed Kahlua
runtime. It does not claim a sampled natural county or loaded-save acceptance.
SAO establishes a producer and a verifiable port; it does not review protected
text or approve conditioning data.

Speakeasy must verify this exact bundle, review the bounded extraction,
adjudicate the acquisition checks and present the hash-bound candidate for
explicit ratification. Until then the example remains conditioning-ineligible.
R9's complete-house shortage producer and the remaining life-simulation action
families remain open.
