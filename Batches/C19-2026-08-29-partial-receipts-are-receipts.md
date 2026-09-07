# C19 - Partial receipts are receipts

| Field | Record |
|---|---|
| Batch | `C19` |
| Date | 2026-08-29 |
| Name | Partial receipts are receipts |
| Status | Closed append-only batch - receipts R-001/R-002 seeded from the day's own sessions |
| Threads | [`T-030`](THREADS.md#t-030) |

## Record

The operator, on a defect systemic across their repositories: "the
entire repo will be classified as untested at runtime... even if I
actually have... there's no reporting mechanism... none of that gets
recorded ever. So it ends up being that everything is classified as
untested perpetually... it's a little tautological." The tautology
was structural: no mechanism existed by which the operator's live
reports became recorded evidence, so the blanket claim could never
be falsified - the same day that produced three play findings
([C18]) left every document still saying "no play receipt."

**The mechanism (DR-025).** `RECEIPTS.md`, canonical and append-only:
one observation per receipt, recorded when it lands - a surface
witnessed working, a defect exposed in play (which is a receipt for
everything exercised on the way to it), or an observation still open.
A batch stays open until receipts touch its surfaces; a fix made
from a receipt is pending until re-witnessed; and neither state may
ever again be stated as "nothing has ever been tested." PLAYABILITY
and SESSION_STATE lost their blanket sentences and now point at the
ledger.

**Seeded honestly.** R-001 records what the day's two sessions
actually settled - genesis, pacing, materialization, flight, company
formation, all exercised live - and what they exposed (F-048, F-049,
fixed in [C18], pending re-witness). R-002 records the unexplained
person as OPEN, with the three dead explanations named and what
would settle it.

**The border.** Border 97 (`tools/receipts_test.py`): the ledger
parses and numbers cleanly from R-001, every entry observes and
settles/exposes/leaves-open, every cited finding and batch exists,
and the blanket claim is banned from the canonical documents. Its
control caught the instrument itself first: the ban's regex missed
the motivating sentence because "play receipt" wraps across a line
break in the old document - fixed to match across whitespace, and
the control now fails on exactly the sentence DR-025 struck.

**Portable.** The operator named this defect in all three
repositories. The pattern (ledger + seeding + blanket ban) carries;
the sibling prompts are the operator's to fire.

This governed record is the portable project history for this unit.
