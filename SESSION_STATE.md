| Document | Survivor Awareness Overhaul Session State |
|---|---|
| Version | `0.6.0.0-pre-alpha` |
| Author | ellyj3rain |
| Repository | `SESSION_STATE.md` |
| Status | CANONICAL - where the work actually stands. |

# Session state

**As of** 2026-08-28, `[B52]` close.

## Standing

**29 A-batches and 52 B-batches, and both eras are closed.** The catalog was
recatalogued at the seam: the prior assistant's diary-rate sequence (200 A
entries and 193 B entries) was consolidated into these units, each one the
piece of work it actually was, per CAO's precedent. `Batches/FORMER_LABELS.md`
resolves every former identifier; the raw history is preserved as engineering
in local Git refs. The chronology continues in
the C era; `C1` is the next batch.

The four pillars are built and the county runs on them: Perception admits,
Disposition decides, Standing channels, Execution acts. Every fact a survivor
acts on carries provenance and an age, and every acquisition says *how* it was
come by ([B39]) - seen, heard, told, lived, or `unknown` when the caller did
not say, never a silent default to the strongest claim.

Places come from the map's own `IsoMetaGrid`; what a place offers derives from
what its rooms contain rather than what the room is called ([B38]), so mods
this framework has never heard of reach the county; places are spent by being
visited and refill on the game's own `LootRespawn` ([B39]); loaded and
unloaded survivors are governed by the same rules ([B39], [B42]).

## Deploy state

`0.6.0.0-pre-alpha` at tip. The operator is playing, so `tools/deploy.sh`
refuses - it will not overwrite a locked jar. The deployed copy is at the
closed tip (`[B52]`) minus its last three behavioural increments (renames,
the scout's reading, and the pressure spelling), all of which the jar does
not carry. The jar is byte-identical; nothing behavioural is waiting.

Two live saves - one fresh in Irvington, one with companions - survive every
deploy; `save_compat_test` guards this and runs in the gate.

## Instruments

**78 numbered borders**, run by **93 gated mirrors** in `tools/`, all invoked
by `tools/check.sh`, which the pre-commit hook runs and CI runs on every push.
The figures in this paragraph are derived by Border 76 from the tree, not
maintained by hand. Border 54 keeps the rest honest: it runs every gated
mirror against a tree with the Lua removed and refuses any that still pass.

## Open items

Every batch is **OPEN** pending play receipts, and that is normal here. The
borders establish that the code says what a record claims; they cannot
establish that it feels right in the world. Only the operator can settle that.

Standing gaps, stated rather than left to be discovered: the player's own
looting does not deplete a place ([B39]); the witness rule keys on a recent
close sighting of the victim rather than on the killing itself; `carry-light`
dissent is an operator decision. The Workshop art is placeholder by choice -
[B51] generates an icon and a poster from `tools/make_art.py`, checked by
Border 73, and anyone may prefer their own drawing.

### Waiting on the operator

Three things this pass cannot settle from here.

- **The county's pace is frame time, not real time.** Everything except the
  voice cooldown counts frames, so a 144Hz machine runs a county 2.4x faster
  than a 60Hz one. Changing it touches every timer in the mod and changes how
  the game feels; it is a design call.
- **`s.relations` keeps a row for everyone who ever lived.** [B51] budgeted
  the walk, so the cost is bounded - but the rows of the dead are still in the
  save and still growing. Pruning them is irreversible on a live save. The
  four readers of a row are all about a living actor, so dropping
  `relations[deadId]` while keeping everybody's feelings ABOUT the dead looks
  safe; that is a judgement about somebody's save, not a border.
- **[B48] changes every survivor's traits, occupation and face in
  an existing save**, because the hash they are drawn from was corrected.

## The condition

The idea is the success condition, entire. The pass continues until the
operator ends it.
