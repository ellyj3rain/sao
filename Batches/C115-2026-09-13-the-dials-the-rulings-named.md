# C115 - The dials the rulings named

| Field | Record |
| --- | --- |
| Batch | `C115` |
| Date | 2026-09-13 |
| Name | The dials the rulings named |
| Status | Closed append-only batch - the screen-revision ruling, built |
| Threads | [`T-001`](THREADS.md#t-001), [`T-004`](THREADS.md#t-004) |

## Record

The operator ruled 2026-09-13 (the sister project's record 45, the
same sitting that named the pre-alpha-to-alpha goal): the sandbox
screen carries "an absence of everything I said should be
configurable over this past three days" - the numbers the operator
ruled over the 2026-09-11/13 era were sitting in code as constants,
and the screen showed other things. This batch moves them onto the
screen. Every default is the ruled figure; nothing about the
county's behavior changes at the defaults, and that is the point -
the dial is the reserved move, not a new policy.

**The three dials, each credited to its ruling:**

- **RoadMeetingWorth** (double, 0.0-0.1, default 0.02) - what a road
  meeting is worth. The operator moved this number personally at
  `[C111]` (0.005 to 0.02, "a meeting should be worth more"), and the
  constant's own comment said so. Read per meeting in the dormant
  crossing path (`SAO_Population.lua`'s `roadTrust()`), fallback the
  ruled figure.
- **OpennessHorizonMonths** (double, 1.0-24.0, default 6.0) - the
  horizon `[C111]` stated "so the operator can move it." Read per
  pull-hour recompute in `companyPull` (`SAO_Standing.lua`), fallback
  the stated half year; openness still rides the county's own clock,
  and the dial moves where the horizon sits, not how openness rides.
- **DriveSpeedCap** (double, 5.0-80.0, default 30.0) - `[C114]`'s
  cap, Week One's own credited town figure. Java cannot read
  SandboxVars, so the value crosses the bridge at order time:
  `SAO_Driving.lua` reads the dial and passes it into
  `SAOBridge.driveBegin` (which gains a sixth parameter), which
  hands it to `SAODriver.begin`, which stores it on the per-shell
  `SAODriveState`. The constant stays as `DEFAULT_SPEED_CAP_KMH`
  with its credit intact - the dial moves the number, not the
  credit. A ride never orders a cap; the DRIVE phase check falls
  back to the default when the state carries none.

**What deliberately did NOT become a dial, named so it is not
mistaken for lost:**

- **The county clock** (`[C112]`) - a tick is a 9000th of a county
  hour, the machine-speed correction; it is the county's own time,
  not a policy, and the operator's ruling on it was the clock itself,
  not a preference for its value.
- **The street hour** (`[C113]`) - Slayer's authored twenty-four
  value curve, carried whole with credit as prior art. Carrying it
  whole IS the ruling; splitting it into dials would be re-authoring
  their work.
- **Era and calendar facts** (`[C111]`/`[C113]`) - read from the
  record's own stamps and calendar, never a dial; the screen cannot
  rule on what day it is.
- **Per-person temperament** - nerve, appetite, compassion,
  talkativeness are emergent from identity by design; the options
  header has said so since `[C12]` and the ruling changes nothing.

**The borders the batch touched, honestly:** three borders hold
seams this batch moved, and each was amended to the new truth rather
than the code bent back to the old spelling - `option_reach_test`
(Border 29) gains OWNED_ELSEWHERE claims for the two module-owned
dials and graduates ROAD_TRUST out of its magic-number table (the
option half of the same border now tracks it); `company_pull_test`
(Border 152) reads the dial seams instead of the hardcoded
literals; `copy_ratified_test` (Border 92) declares the six new
strings under the screen-revision ruling, the wording following the
ratified plain-register family. `sandbox_surface` (Border 16)
passes with 31 options, every dial read, named, and explained, every
fallback matching its declared default.

**The end-state order this batch serves:** the same sitting named
the pre-alpha-to-alpha bar - everything works and is ready to play,
then a few training passes over the full dataset and the runtime,
tuned to a result sufficient for a first time play. This revision is
the first named step of that order; the dials exist so the tuning
passes have something to turn.

## What changed

- `mod/42.20/media/sandbox-options.txt` - three options declared,
  each commented with the ruling that named it.
- `mod/42.20/media/lua/shared/Translate/EN/Sandbox.json` - three
  names and tooltips, the plain register, every tooltip broken with
  `\\n`.
- `mod/42.20/media/lua/client/SAO_Population.lua` - `ROAD_TRUST`
  constant becomes `roadTrust()`, reading the dial per meeting.
- `mod/42.20/media/lua/shared/SAO_Standing.lua` - `companyPull`
  reads the horizon dial; the `[C111]` comment block updated to the
  graduation.
- `mod/42.20/media/lua/client/SAO_Driving.lua` - `Drv.order` reads
  the cap and passes it across the bridge.
- `java/src/com/sao/engine/SAODriveState.java` - `speedCapKmh` field.
- `java/src/com/sao/engine/SAODriver.java` - `begin` gains the cap
  parameter; `SPEED_CAP_KMH` renamed `DEFAULT_SPEED_CAP_KMH` with the
  credit kept; the DRIVE cap check reads the state's cap with the
  credited default standing when unset.
- `java/src/com/sao/bridge/SAOBridge.java` - `driveBegin` gains the
  `speedCapKmh` parameter, passed through to the driver.
- `tools/option_reach_test.py`, `tools/company_pull_test.py`,
  `tools/copy_ratified_test.py` - the three seam amendments above.
- `tools/version_replay.py` - the `C115` unit row; `--write` stamps
  the coordinate.
- `BATCH_LOG.md`, `THREADS.md` (T-001, T-004), `SESSION_STATE.md` -
  the pointers.

## Honest limits

- The dials are read per meeting / per pull-hour recompute / per
  order, so mid-session changes land on the next meeting, the next
  county hour, and the next trip respectively - deliberately, so no
  cached trust or held pull is silently retrofitted.
- `DriveSpeedCap` bounds the DRIVE phase's throttle cut only; the
  engine's own physics, the unloaded-space brake, and every refusal
  are unchanged at any cap.
- No play receipt, as ever: nobody has watched a goer drive at a
  non-default cap. The receipt `[C114]` owes (a goer under wheels,
  watched) covers this surface too - the default cap is the same
  figure the port carried.

## Verification

The gate ran clean on 2026-09-13 with the batch in the tree (all
borders, 31 options on the surface), the jar rebuilt and shipped to
the tree before it ran, and the version machine's `--write` run
after the log row landed. Deploy follows this record, then the
branch, the pull request, and the squash - the publishing law.

## Next

The end-state order the same sitting set (the sister project's
record 45): readiness - everything works and is ready to play, in
theory - then the ML training passes over the full dataset and the
runtime, tuned to a result sufficient for a first time play, the
pre-alpha-to-alpha bar. The dials this batch shipped exist so those
passes have something to turn. The play receipts remain the
operator's experiential debt, named OPEN in the threads.