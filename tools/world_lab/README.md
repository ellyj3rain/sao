# Native study worlds

`world_lab.py` builds a seeded, configurable native Project Zomboid world from
`definition.example.json`. Extents use the installed Build 42 cell format:
256 by 256 tiles per cell. The example is 512 by 512 tiles, with four population
origins on native road strips surrounded by sparse grassland patches. Authored
buildings and broader mod compositions need their own packages and evidence.

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
