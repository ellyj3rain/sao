# C102 - Native skill-book study

| Field | Record |
|---|---|
| Batch | C102 |
| Date | 2026-09-29 |
| Timestamp | 2026-09-29 23:20 UTC / 16:20 PST |
| Name | Native skill-book study |
| Status | Mechanically closed through the enforced repository gate; loaded behavior remains unobserved. |
| Threads | T-002, T-003, T-004, T-006, T-008, T-030 |

The retained C96 study produced no maintained purpose through ordinary reading.
Inspection of the installed Build 42.21 bytecode establishes a concrete execution
gap: `IsoGameCharacter.ReadLiterature` applies literature effects and learned
recipes, but does not advance skill-book pages or their XP multiplier. The
Controller called that instant method while the C95 planner treated it as
pending reading. Its book-fetch fallback also removed inventory directly.

`SAO_Study` now executes the installed `ISReadABook` timed action for a useful
privately carried manual. A person without a designation can select one; an
assigned trade and interrupted reading affect preference among carried books.
Native skill range, literacy, lighting, duration, resumed pages and XP multiplier
remain authoritative. The person retains an exact work identity, book type,
item ID, purpose and admission. Reading completion advances its matching purpose
once while practical skill use remains a separate step. Per-subject reading
history survives later study in another domain.
Failed reading admission with a useful carried manual retains that knowledge
and does not create a false missing-book purpose.

The Controller holds the purpose through ordinary decision ticks and permits
danger or immediate needs to interrupt it. A different native action retires
reading before queue admission, preserving the newly selected urgent action.
Body handoff interrupts live reading before the existing native checkpoint.
The shared death funnel clears reading's exact runtime owner and native queue
while retaining the durable person and interrupted purpose.
Saved page state remains native; missing runtime becomes interrupted work,
and current restored pages remain visible without a loaded body requirement.
Mousecat's existing person feed exposes subject, pages, status and interruption
without counting a finished book as practical completion.

| Verification | Result |
|---|---|
| Border 214 | 35 checks execute the installed reading source, production planner, Needs queue owner, actual rest fallback and shared death funnel in Kahlua, using controlled bodies and queues. |
| Named controls | Body-token change, loss of the exact carried item, omission of native completion, survival admission before owner retirement, loss of retained reading history, missing death cleanup, lost reading-time adjustment and false missing-book fallback each flip their corresponding verdict. |
| Existing planner | 17 privacy, persistence, independent model interpretation and receipt cases pass with owner, token and private-store controls. |
| Existing behavior | Book vocabulary, cognition, observation, runtime reconstruction, cache lifetime, child literacy and person-condition focused checks pass. |
| Source review | Survival queue ordering, separate practice counting, positive partial-progress reload, absent-body observation and later-subject history findings corrected and rechecked. |
| Existing simulation evidence | The bodyless county sweep declares native study's absent executor. Fresh capture preserves all 20 coordination decisions and the catalogue; the current manifest records exact source hashes without changing samples. |
| Repository gate | The closing commit requires the complete `tools/check.sh --staged` gate; publication requires passing CI. |

No game or saved session was launched. Controlled callback execution does not
establish autonomous loaded frequency, animation, pacing or behavioral quality.
Book search/acquisition beyond carried manuals and later practical domain work
remain producers to implement. No scenario, training row or dataset rule was
admitted.
