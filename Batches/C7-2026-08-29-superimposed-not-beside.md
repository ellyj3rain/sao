# C7 - Superimposed, not beside

| Field | Record |
|---|---|
| Batch | `C7` |
| Date | 2026-08-29 |
| Name | Superimposed, not beside |
| Status | Closed append-only batch - play verification pending (no play receipt) |
| Threads | [`T-006`](THREADS.md#t-006) |

## Record

The operator's correction of [C3]'s reading: the task was fixing how
this mod superimposes onto the neighbour's menus - still lacking, and
not what had been built. [C3] had read the use-his-UI instruction as
removal - strip his per-survivor root, grow the
county's own person submenu beside where his used to be. That is two UIs
for one load order: the miniature of the exact thing the work order
forbade. The correction is DR-015: his menu is the surface the player of
both mods already knows, so it STAYS - and the county becomes what is
inside it.

**The superimposition.** The neighbour attaches one per-survivor root per
right-click, to the nearest of his actors within his own 3.5-tile radius.
For an adopted person, the county now: keeps that root; retitles it to
the person alone ("<name>..." - DR-014's one name reaches the label,
replacing his verb-summary suffix); clears his submenu through the
engine's own `getSubMenu`/`clear`; and rebuilds it - "Talk to them"
driving the county's full talk surface, "Tell them what I've seen"
driving the same tell channel as everywhere, then his working verbs
through his own public functions, ownership-aware (his follow, wait,
return, his survivor card; his greet, recruit, offer). Unadopted people
keep his menu untouched, and his generic "Knox Survivors" root stays
his.

**One prediction, consulted twice.** `willSuperimpose` mirrors his
nearest-actor attachment exactly and is asked by BOTH the county's menu
builder (which then adds no person menu of its own) and the superimposer
(which rewrites his root) - one body can never carry two person menus,
and the two handlers cannot disagree about who owns a click. When the
prediction fails (his runtime lost the actor, or he is not loaded), the
county's own person menu returns as the fallback, with his verbs folded
in as [C3] built it.

**One definition each.** The tell option moved to `H.addTellOption` and
the talk surface exported as `H.talkTo` - the county's own menu and the
superimposed root drive the same functions; "Tell them what I've seen"
is spelled exactly once in the tree, and the acknowledgment can now
speak from a neighbour body too (`Say` is IsoGameCharacter's,
javap-verified).

**The border.** Border 86 (`tools/superimpose_test.py`): his options are
never removed, the submenu is genuinely rebuilt, the root is retitled,
the prediction is shared, and the talk/tell surfaces have one definition
each. Control: the [C3]-era strip fails eight ways for the stated
reasons.

This governed record is the portable project history for this unit.
