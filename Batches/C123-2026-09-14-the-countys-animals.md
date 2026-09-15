# C123 - The county's animals

| Field | Record |
| --- | --- |
| Batch | `C123` |
| Date | 2026-09-14 |
| Name | The county's animals |
| Status | Closed append-only batch - animal composition |
| Threads | [`T-001`](THREADS.md#t-001), [`T-003`](THREADS.md#t-003), [`T-007`](THREADS.md#t-007), [`T-008`](THREADS.md#t-008) |

## Record

Build 42's `IsoAnimal` is an `IsoPlayer`. The scanner had therefore
treated every cow, hen, and horse as a person, and its generic foreign
person route could file an animal as a nameless stranger in a survivor's
beliefs. C123 stops animals before that person fallthrough in the one
shared foreign-person predicate and in the named-combat lookup. A live
animal is no longer a social target, but an actual off-slot person still
is.

Ranch care reads a designated ranch from the engine's own lists. The
adapter reads its animals, troughs, hutches, and each animal's present
hunger, thirst, stress, acceptance, product readiness, wildness, and
adult state. It does not create a ranch, animal, product, food, water,
or tool. A farm hand standing on their own claimed ground can select one
nearby, non-wild need on the existing farm cadence: ready milk, wool,
eggs already in a hutch, water for a trough with space, an animal-listed
hand feed, or a pet where stress or acceptance calls for it. The engine's
own timed action makes the final validity decision.

Horse riding remains the optional Horse Mod's machinery. C123 observes a
loaded adult mount only when the mod's `HorseRiding` animation flag and
`Mounts` association agree, and retains the engine `animalId` as the
mount fact. That suppresses competing foot decisions. The mod's normal
mount entry is local-player input, so C123 does not claim or attempt a
non-local shell mount, ownership, companionship, or a new horse system.

## What changed

- `SAOPerceptionScanner.java` and `SAOBridge.java` reject `IsoAnimal`
  before human perception, foreign-body lookup, and named combat.
- `SAOAnimals.java`, `SAOBridge.java`, `SAO_Animals.lua`, and
  `SAO_Controller.lua` add the designated-ranch read, safe action
  selection, existing timed actions, and optional mounted-horse hold.
- `animal_ground_test.py` and `animal_care_ground_test.py` add Borders
  155 and 156; `check.sh`, the protocol declaration, and state invariant
  sweep make their cross-module contracts part of the normal gate.
- `build-java.sh` now supports both Git Bash's `/c/...` and WSL Bash's
  `/mnt/c/...` paths when invoking the same Windows JDK.
- `FINDINGS.md` records the animal and ranch engine surface as F-069;
  `ENGINE_CONTRACT.md` carries its re-verifiable contract addendum.

## Honest limits

- This is not a play receipt. Nobody has watched a farm hand care for a
  designated animal, retrieve its product, or drink from its tended
  trough in a live save.
- The care path requires a loaded, designated ranch, a nearby non-wild
  animal, and the actual item the action asks for. It does not feed from
  the ground, fill a trough with a fictional resource, or act on a wild
  animal.
- The optional Horse Mod observation is a no-op without its own loaded
  mount pair. Its source does not establish an NPC-shell mount, and C123
  does not infer one from the shared action constructor.
- No predator, ownership, or companionship model is added. Their engine
  or mod surfaces need separate ground and a separate batch.

## Verification

- The installed Build 42.20 jar and its shipped Lua were read before use:
  `IsoAnimal` extends `IsoPlayer`; `DesignationZoneAnimal` supplies the
  animal, trough, and hutch lists; the named `IsoAnimal` state reads and
  vanilla care constructors compile against the installed game.
- Border 155 fails against the prior person predicate and against either
  removed animal guard; it holds a real foreign person, a local player,
  an SAO shell, and an animal apart. Border 156 rejects malformed animal
  records and wild care, selects a ready milk action before lower work,
  and faults when the animal readiness source seam is mutated.
- The Java agent rebuilt from source, includes `SAOAnimals.class` in the
  distribution and shipping jars, and the complete repository gate passes.