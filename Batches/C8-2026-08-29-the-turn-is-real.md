# C8 - The turn is real

| Field | Record |
|---|---|
| Batch | `C8` |
| Date | 2026-08-29 |
| Name | The turn is real |
| Status | Closed append-only batch - play verification pending (no play receipt) |
| Threads | [`T-002`](THREADS.md#t-002), [`T-008`](THREADS.md#t-008) |

## Record

The operator's ruling, opening the ontology-hardening order (DR-016):
SAO owns death of the person completely - the record, the corpse's
identity, and ensuring the turn actually fires under the game's own
rules - and never drives what rises. The code's inherited "the corpse
is the engine's" posture is ruled a gap, not a principle. This batch
makes the turn real and moves identity onto the channel that actually
survives it, with every engine claim re-verified against the installed
jar before anything was built on it (F-044, F-045).

**What javap settled first.** Three claims in the sibling repository's
evidence trail fell under the hand-check, and the batch was shaped by
what replaced them:

- *The corpse IS populated from the dying character.* The
  `IsoDeadBody(IsoGameCharacter)` constructor copies the character's
  modData onto the corpse unconditionally (offsets 1102-1113), and the
  descriptor too for every non-zombie, non-animal character - IsoPlayer
  included (1007-1019). Stamping the LIVING body suffices; no
  `OnDeadBodySpawn` correlation machinery was needed, and none was
  built.
- *The engine arms the turn itself - when `die()` runs.* `IsoPlayer`'s
  own constructor registers a died-listener that calls
  `body.reanimateLater()` under `shouldBecomeZombieAfterDeath()` - the
  sandbox Transmission switch over real infection
  (`ZOMBIE_INFECTION >= 0.001`, unconditional under Everyone's
  Infected, never under None), with the delay read from
  `ZombieLore.Reanimate`. SAO writes no timer arithmetic; it never
  needed to.
- *But `die()` has exactly one single-player call site* -
  `PlayerOnGroundState.execute()` - and `updateInternal()`'s own call
  is server-gated. A shell that dies without its state machine
  reaching the on-ground state (the quiet course deaths: fever, blood
  loss, the bite running out) is a dead character standing in the
  world. No corpse, no armed timer, no turn - the reason the whole
  [B3] recognition arc may never once have fired.

**The corpse net.** On the controller's death sighting the body is
held in `pendingCorpses` through a named grace
(`CORPSE_GRACE_TICKS = 120`, so the engine's own death fall gets its
animation first), then the bridge's `ensureCorpse` calls the engine's
own `die()` - public, final, and idempotent by its own guards
(`onDeathDone` + `diedBody`), so when the state machine got there
first the net does nothing at all. `IsoZombie` bodies are refused
(`NOT_OURS`): the risen and the neighbour's people are never ours to
fold into corpses. The death-screen event cannot fire from this path -
`OnPlayerDeath` is `isLocalPlayer()`-gated in the engine itself.

**The stamp.** One write at each materialization site - the shell's
modData at `Body.materialize`, the adopted neighbour's body at
adoption - puts the person id on the body under `SAOPersonId`. The
engine's own two `copyTable` calls carry it character -> corpse ->
risen body, and `IsoObject.save` persists it on a corpse across
save/reload. **The key name is PROPOSED, not ratified: the operator
approves it, and the sibling project reads the same key verbatim.**
Renaming before ratification costs nothing live - stamps rewrite at
every materialization.

**Recognition moves onto what survives.** The scanner's Z row and
`findNamedCorpsesNear` read the modData mark first and emit `@<id>`
(with `:` encoded `~`, because Knox ids carry the protocol's own
separator); the descriptor name remains as display-only fallback for
bodies that never died through the player path. One Lua decoder -
`Identity.resolveBodyTag` - reads both forms for every consumer: the
perception parser's turned-sighting, the mourning walk, the
corpse-loot refusal, and the missing-person search. Descriptor-keyed
recognition died with F-045: `reanimate()` builds the zombie a fresh
descriptor carrying gender and voice only, and the server-side
descriptor registry is a no-op in single-player.

**The contract corrected.** Addendum D's row claiming "identity
survives death and reanimation" through `SurvivorDesc` now states what
javap actually proved - the field exists; the flow half-dies. The
sibling repository's F-002/F-003 corrections are carried to the
operator as a portable prompt, not written into its tree from here.

**The border.** Border 87 (`tools/turn_real_test.py`): the stamp at
both materialization sites, the net with its named grace and its
`NOT_OURS` refusal, id-first recognition with the `~` encoding and the
one decoder at all consumer sites, and the corrected contract row.
Control: the pre-[C8] tree itself (the real defect, reconstructed from
`git show HEAD:` before the batch), which fails all fifteen ways.

This governed record is the portable project history for this unit.
