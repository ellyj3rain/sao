# C6 - The inspect harness

| Field | Record |
|---|---|
| Batch | `C6` |
| Date | 2026-08-29 |
| Name | The inspect harness |
| Status | Closed append-only batch - play verification pending (no play receipt) |
| Threads | [`T-009`](THREADS.md#t-009) |

## Record

The operator's terms, met whole: normal launch, not `-debug`; a bound key
or panel; the selected survivor's seen / heard / told, standing, needs,
last decision, tick cost, and the population counts; the same lines to a
local JSONL; the panel can see everything; the survivors gain nothing
from it.

**The panel.** `SAO_Inspect.lua`, in the Ledger's own idiom (a native
ISCollapsableWindow, rebuilt on the 500ms cadence, rows shortened rather
than clipped). It opens from "Inspect (panel)" under SAO Debug on a
right-clicked survivor, or from a bound key that works anywhere - `J` by
default, owned by the options screen ("[SAO]" section,
`shared/SAO_Binding.lua` in the engine's own keyBinding idiom) - falling
to the nearest survivor when nobody is selected. It shows: the county's
counts; the person's name, id, designation, and occupation; their state
and the pressure answer verbatim (the DR-011 vocabulary, not a
paraphrase); the walk verdict; hunger, thirst, and health off the body;
trust in the player, hostility, and their house; and the whole belief
store tallied by provenance - seen, heard, told, lived, and UNKNOWN
counted loudly if it ever appears, because a panel that can see
everything is where a [B39] violation would first become visible.

**The cost line.** The Controller measures what one tick costs
(`Ctl.lastTickMs`), a wall-clock measurement at the tick's own seam. A
measurement is not a timer: nothing gates on it, and the frame-time
pacing law ([B49]) is untouched.

**The JSONL.** The same lines the panel renders go through
`SAO.Telemetry.event("inspect", ...)` on a slow cadence - the one
writer, behind the one sandbox dial, required inert. No second file, no
second format, no second switch.

**The window is not a pathway.** The panel reads the stores raw - that
is its licence - and never observes, tells, adjusts, orders, or marks.
Border 85 (`tools/inspect_inert_test.py`) holds the window shut: the
surface must exist, bind through the options screen, never gate on debug
mode, touch no mutating surface, and reach the JSONL only through the
telemetry door. Control: the pre-fix tree fails three ways (no surface,
no binding, no cost measure) - the absence was the original defect.

This governed record is the portable project history for this unit.
