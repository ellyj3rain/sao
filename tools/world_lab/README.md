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

Live capture targets twenty frames per second. Pixel readback happens after the
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
