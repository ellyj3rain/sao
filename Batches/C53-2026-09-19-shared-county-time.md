# C53 - Shared county time

| Field | Record |
|---|---|
| Batch | `C53` |
| Date | 2026-09-19 |
| Name | Shared county time |
| Status | Closed implementation batch; loaded-world receipt pending. |
| Threads | [`T-002`](THREADS.md#t-002), [`T-006`](THREADS.md#t-006), [`T-007`](THREADS.md#t-007), [`T-008`](THREADS.md#t-008) |

## Behavior

History owns the county's elapsed-time conversions: 9000 ticks per hour and
216000 per 24-hour day. A controller decision now refreshes that clock at the
moment it is read. Historical catch-up can therefore execute many substeps
inside one host callback without every consumer seeing the callback's opening
time. The fallback advances once per host callback only when History cannot
answer; repeated reads never manufacture time.

WorldGenesis receives an elapsed county day and converts it to the tick at that
day's start before Integration evaluates pressure and branches. Population uses
History's named ticks-per-day constant. Day Zero changes the record timeline,
and DayLength changes wall pacing; neither changes county units.

Native pacing is separate. The death-fall grace and operational tally flush use
the controller's transient host-callback counter. Voice, UI, profiling and the
historical-slice budget retain their explicit wall-millisecond clocks. ZAO's
loaded controller already reads `SAO.Controller.tick()` and its durable
pathogen progression is day-based, so no sister source change is required.

## Timestamp inventory

SUBSTRATE records each live axis, its producer, conversion boundary, durable
fields and exceptions. Generic `At` is not treated as a unit. Most controller
deadlines use county ticks; several social fields use hours or day buckets;
`Identity.createdAt` is legacy calendar-millisecond provenance;
`Identity.updatedAt` is a revision counter. Organization's zero-valued
`createdAt`/`joinedAt` placeholders have no accepted time meaning and remain
for their actual R9 producer to replace.

No unidentified legacy frame value is migrated onto the county axis. R3's
native fitness clocks, R4's same-process reconstruction, R5's drug/physiology
scheduling and later action receipts consume this contract without being
claimed complete by it.

## Evidence

Border 168 executes shipped History, Controller callback and WorldGenesis code
in the installed Kahlua VM. It covers historical substeps without another host
callback, a History reload, midnight, Day Zero on/off, nondefault DayLength,
large county-time skips, the missing-clock fallback and WorldGenesis days 0, 1
and 7. Controls remove the decision refresh, pass day as tick and put corpse
grace back on county time; each flips the verdict at the named defect.

Border 160 continues to execute the production catch-up scheduler over 90 and
365 days, including partial-day reload, unavailable timers, incomplete genesis
and real-person daily ordering. Borders 131 and 153 retain the county-hour and
quantized-tick laws. The full repository gate passes with 168 numbered borders
and 183 gated mirrors.

These are mechanical clock and callback receipts. They do not establish how a
nondefault DayLength feels in play, close R5's cadence-dependent physiology or
validate the complete Crossed action system. C53 is not deployed.
