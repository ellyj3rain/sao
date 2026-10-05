# Native study worlds

`world_lab.py` builds a seeded, configurable native Project Zomboid world from
`definition.example.json`. Extents use the installed Build 42 cell format:
256 by 256 tiles per cell. The example is 512 by 512 tiles, with four population
origins on native road strips surrounded by sparse grassland patches. The
`definitions/echo-creek-*.json` studies instead copy an isolated extent of the
installed authored map, preserving native rooms, buildings and source assets.
Residential, service and farm origins provide different material surroundings.
The builder verifies intersecting building coverage against installed headers;
offline verification checks the copied package and cannot independently recover
the installed headers outside that package.

A definition may instead name one activated native map through `lots`. The
runner resolves that name to exactly one copied provider, verifies every authored
cell lies inside the declared extent, and binds the provider and `map.info` hash
into the run receipt. The mobile-household acceptance definition uses this path
to load Project RV's physical rooms. Its bounded situation spawns a real vehicle,
enters the remote room, moves the exterior anchor, exits beside it, and records
the ordered transition receipt. The result remains unreviewed study evidence.

Optional `generation.staticModules` declares up to 128 ordered native terrain
regions. Each supplies an inclusive `position` rectangle (`xmin`, `xmax`, `ymin`,
`ymax`) inside the world extent and exactly one native `biome` or `prefab` name.
The first matching region wins. The package emits the engine's per-map
`WorldGenOverride.lua` and seals it with the selected native source inputs.
`grass_plain` retains sparse native vegetation; road strips use the native
`normal_road_WE_00` floor/marking prefab. These are starting terrain conditions.

`world_lab_run.py` launches the installed engine with an exclusive cache, copied
mods, home and save. Its default observer host owns a detached residency anchor
and an independent view. It keeps native chunk loading, physics, rendering,
character owners and save handling. Participant-facing SAO and ZAO lookups
exclude the observer. No participating player is persisted.

The default observer is a God view independent of a person's visual experience.
Native tree cutaway reveals people beneath the canopy, retaining separate jumbo
trunks where available. Physical trees and survivors retain their collision,
perception and line-of-sight checks. Region loading
still activates native world content, including the engine's room-seen hooks
when a package contains buildings; the observer is not a globally inert world
loader. The supplied terrain example has no authored rooms.

```powershell
python tools/world_lab.py build tools/world_lab/definition.example.json `
  --out <new-package-directory> --game <installed-game-directory>
python tools/world_lab_run.py <package-directory> --out <new-run-directory> `
  --game <installed-game-directory> --jdk <jdk-bin-directory> `
  --mod mod --mod ../zombie-awareness/mod --mod <ZombieBuddy-mod-directory> `
  --host observer --watch --window hidden
```

Speakeasy's `tools/world_watch.py` connects that explicit run to Mousecat's
generic native-view protocol. Mousecat displays actual engine framebuffer
pixels, person inspection and bounded camera/time controls. Speakeasy selects
activity views from observations. Selection changes observer coordinates and
the loaded region; it does not command a person or supply a successful outcome.
Mousecat's Simulation page provides native camera zoom through minus/plus
buttons, the mouse wheel and keyboard. Larger native zoom factors show more
world geometry without resizing the captured image or expanding residency.
Current and target zoom come from the engine and remain bound to the rendered
command. A selected person's inspector shows source-owned needs, inventory,
current action, action receipts, reception and work on a separate bounded
cadence. Optional detail failures preserve the core feed and archival export.

Isolated observer rendering uses the installed uncapped selection after
startup. Live PNG capture admits a completed frame when its one publisher is
free; actual delivery depends on native rendering, readback and publication. Pixel readback happens after the
native renderer swaps its completed frame; one background worker converts,
encodes, validates and publishes it. Lossless PNG uses stored deflate blocks to
avoid compression delay in the local image feed. A busy worker drops capture requests before
GPU readback. Capture time and the rendered command remain bound to the pixels,
and a camera change cannot relabel a frame already being encoded. Inspection
continues on its separate one-second cadence.

Stop through the observer controls so the engine saves normally. The runner
then seals the copied inputs, native logs, observer state, complete image,
observations and save files. Verification and continuation are explicit:

Every launch has a wall-time limit, including `--watch`: `--timeout` defaults
to 3,600 seconds and accepts 30 seconds through seven days. The native launcher requests a normal save and exit at that
limit, including while paused. The supervisor watches native logic and image
progress independently of the world clock, detects fatal memory/producer
failures, and allows 30 seconds for shutdown before terminating its own child.
The dedicated runner joins an unnamed Windows job before spawning Java, so
Windows also terminates that child if the runner itself dies. A forced exit,
producer failure or simulation horizon that was not reached cannot become a
completed run. A watched run that saves at its wall limit records that reason.

```powershell
python tools/world_lab_run.py <package-directory> --out <run-directory> --verify
python tools/world_lab_run.py <package-directory> --out <run-directory> `
  --game <installed-game-directory> --jdk <jdk-bin-directory> `
  --host observer --resume --watch --window hidden
```

Continuation verifies the prior completed attempt and uses the saved mod order.
Each attempt has separate control/state/image paths and a new view session.
Reopen Mousecat on a fresh Speakeasy feed for that session. A failed attempt
remains failed and cannot be admitted as a completed observation.

For repeated observation, `world_lab_session.py` keeps one verified native save
behind successive bounded attempts. The first launch prepares the isolated run;
later launches use the runner's existing verified `--resume` path. The durable
session state records attempt duration, current attempt, accumulated simulated
hours and whether a normal save can continue. It remains `unreviewed` and has no
behavioral verdict.

```powershell
python tools/world_lab_session.py <package-directory> `
  --out <session-directory> --game <installed-game-directory> `
  --jdk <jdk-bin-directory> --mod <SAO-directory> --mod <ZAO-directory> `
  --watcher <Speakeasy-directory>/tools/world_watch.py `
  --registry <Mousecat-native-view-registry>
```

On Windows, session launch selects its first live feed once in an already-open
Mousecat desktop. The helper waits for the exact view ID, native session and feed
binding, opens Simulation if needed, and selects the registered label. Later
operator navigation is left alone, including during automatic continuation.
It runs hidden and independently of the simulation supervisor. Selection evidence
is saved as `mousecat-selection.json` and diagnostic output as
`mousecat-selection.log` in the session directory. An absent desktop, ambiguous
label, unavailable feed or UI failure is recorded explicitly. The helper never
launches another app. Use `--no-open-mousecat` for headless or source-only runs.
The receipt distinguishes a visible selected heading and live source frames from
verification of the rendered video itself.

Mousecat exposes **Save session** while an attempt is active and **Continue
session** after its normal save returns. Attempt duration and automatic
continuation are inside **Session settings**. Automatic continuation is off by
default. It applies only after a clean wall-time checkpoint; an explicit save
stays stopped. A successor replaces the ended feed only after Speakeasy has
published its first complete frame.

Full native physics applies within loaded regions. Durable people elsewhere
retain their simulation representation; unavailable squares are explicitly
counted. If native chunk removal precedes a person's hibernation, the physical
action owners record interruption before that body's state is captured and its
handle released. Failed cancellation or capture retains ownership for retry.
The corrected perception keeps unidentified sounds separate from known threats
and excludes a person's own footsteps. Active escape paths remain owned while
their destination is still safe relative to private beliefs and permitted.
Failed paths and changed danger still reopen the decision; observation does not
assign a successful goal.
Following also retains a valid offset beside the same companion. Consecutive
visible sightings update one threat track, and actual visible empty ground can
correct a remembered location. Hidden threats retain uncertainty and expiry.
Starting coordinates supply a navigation reference. Admission does not turn
them into property, and moving in shares ground only when the anchor actually
holds a claim. Existing ownership records remain intact.

Capture time, observation time and camera acknowledgement remain
separate evidence. All packages, observations and previews are **unreviewed**.
Scenario evaluation and explicit operator ratification precede dataset admission.

To require initial people in each observation area, add a count for each existing
site under `situation.initialPeopleBySite`:

```json
"initialPeopleBySite": {"residential": 4, "services": 4, "farm": 4}
```

The counts sum to the configured governed population and require enabled
population generation. Study startup stages them
before native population generation. The existing admissions owner generates
identities, histories and social units at real spawn-region points associated
with the sites. Persisted generated identities and separately observed native
bodies report realized coverage. Reload retains the original admission. An
already populated world or a different source binding is refused; it does not
move people or fill an area with replacement identities.

For an outcome trial, add `situation.resourceObjectives` alongside the existing
initial conditions. Each request names an existing `observation.sites` id and a
one-based ordinal in that site's actual living represented population:

```json
"resourceObjectives": [
  {"id": "food-reserve", "revision": 1, "siteId": "residential", "actorOrdinal": 1,
   "category": "food", "target": 3, "unit": "usable-food-item", "deadlineAfterHours": 12}
]
```

The study binds that actual person once and retains the binding across save,
movement and death. Other people keep autonomous purpose formation. Assignment
is recorded as `assigned-outcome-discovery` with `OperatorDirect` experimental
authority. The actor chooses the means from private knowledge and real native
affordances. A request grants no knowledge or completed action. Food targets
count distinct usable carried items; water uses `native-clean-fluid-amount` and
the actual engine amount. Up to twelve requests are accepted. Checked stock,
coverage, deadline and terminal result appear in situation provenance and the
existing person inspector. A procedure receipt can complete its work while the
desired stock remains unmet. Live known-procedure trials are not admitted here.

Native observation reserves bounded capacity before acquiring data. `StudyExport`
detaches values on the game thread and performs encoding, read-back and atomic
publication on one worker. Live completion starts its next admission cooldown;
the Lua owner alone acknowledges exact archived sequences. Capacity deferral
distinguishes encoded bytes, detached nodes and detached depth. Native stop
pauses time and drains accepted work before save. PNG publication admits a completed frame when its one publisher is free.
Optional H264 capture retains its own encoder/readback owner. Neither a capture
ceiling nor observer callback count measures rendered or displayed FPS.

Native observer diagnostics carry `sao-study-export-timing/1` rows for owner
measurement and detachment, then worker encoding, writing, read-back and
promotion. Each epoch keeps its own inclusive monotonic counters, failures,
deferrals and clipping. The observer enables the installed engine's slow Lua
callback timer during the study and restores its prior setting at successful
drain before quit. Warning logging availability is reported separately. These
rows measure admitted stages; they do not establish exclusive Lua hotspots,
monitor presentation FPS or Mousecat image delivery rates.


C88 studies enable independent ordinary and associative cognitive contestants.
Mousecat's person inspector exposes their private-evidence beliefs, hypotheses,
pre-outcome proposals and the actual selected-action result. Discovery pace
controls configure the opposing allocation share, opportunities per county hour
and association depth. Native owner checks still govern physical execution.

Full observations use `context.cognition`; `countyHours` carries the cognitive
clock separately from native engine world age. The optional cognitive archive
has a 512KiB per-person ceiling and 4MiB aggregate ceiling within the frame's
remaining byte budget. Omitted projections appear in the existing coverage
paths/counts. The live display is smaller and cached. Raw durable model state
is not duplicated in the person's record. Speakeasy's cognition trajectory
export preserves source hashes, coverage gaps and both predictions for the
performed action without admitting training examples.


`situation.initialThreats` contains one through twelve placements with exact
`id`, `siteId`, integer `x`, `y`, `z` and `count`. Each is eight through ninety-six
tiles from its declared site on the same floor, inside the world extent, with
one through thirty-two native zombies and at most 128 across the definition.
Unloaded squares wait before attempting creation. Saved receipts bind definition,
save, site, coordinates and requested count; a foreign receipt refuses. A loaded
attempt persists before the native constructor and is never automatically replayed.
Native disabled or blocked ground can refuse; partial and ambiguous attempts remain
visible. Actual native identities and cell membership describe construction.
Ordinary native AI owns subsequent behavior, while each survivor's own perception
owns awareness. `nativeZombieCount` and `nativeZombiesDisabled` expose the current
cell's native state; authored counts do not prove danger reached an actor.

The study-only `study.luaBreakpointLookup` property defaults to `empty-map` and
accepts `native` for comparisons. The empty-map path preserves native debug source,
stepping, breakpoints, watchpoints and error behavior. Its installed-VM mutation
checks are part of the normal repository gate. Performance improvement is measured
in a source-bound loaded run separately from those mechanical checks.

Initial-cohort archive inspection requires `--package` so the sealed native
origin catalog can validate `initialPeopleBySite`. Frames describe observations
and do not contain that catalog. The inspector reports an unbound cohort instead
of substituting a synthetic spawn location. Package inspection retains the exact
definition, source and native origin bindings.

An independent observer site may declare `subjectId` for persistent person
following. Unique identities are sealed with the layout and retained on normal
continuation. The bridge uses reported positions through the authored world;
missing, dead or unavailable people acquire no substitute. Current camera
controls retain their source sample clock independently of pictured zoom.

## Continuous native video

Pass `--video-encoder` with an absolute compatible FFmpeg executable and
`--video-fps` with a ceiling from 30 through 120 to the native run or persistent
session. The ceiling defaults to 120; the session forwards both settings on
initial launch and continuation. PNG remains independently available.
Initialization and at most eight fragments retain source hashes, actual native
frame sequences, capture/world-hour ranges, admission/encoding/drop counters,
qualified crop rectangles and separately qualified pose/command epochs.
Two sites use a 2560 by 720 composite and two 1280 by 720 frames. Geometry-only
receipts withhold pose, pictured zoom and person acknowledgement. Native
wall/roof fading and canopy cutaway preserve their engine alpha owner.
