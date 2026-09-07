| Document | Survivor Awareness Overhaul Play Receipts |
|---|---|
| Version | `2.8.0.0-pre-alpha` |
| Author | ellyj3rain |
| Repository | `RECEIPTS.md` |
| Status | CANONICAL, APPEND-ONLY - what play has actually settled, from R-001. |

# Play receipts

The borders establish that the code says what a record claims; only
play establishes that it happens in the world. This ledger records
what play HAS established, one observation at a time, when it
happens.

The rule it replaces was tautological (DR-025): the doc-pack said
"nothing has a play receipt" and no mechanism existed by which the
operator's reports could change that - so the repository claimed
perpetual untestedness even in the same hour the operator was
reporting live findings against it. A receipt is not a "the repo is
tested" stamp, and there will never be one contiguous session that
uncovers every bug; that is not how testing works. A receipt is one
of these, recorded as it lands:

- a surface WITNESSED doing what its record claims;
- a defect EXPOSED in play - which is also proof the surface was
  exercised, and is a receipt for everything that had to work to
  reach it;
- an observation still OPEN - seen, unexplained, on the record so it
  cannot silently evaporate.

A batch stays open until receipts touch its surfaces, and a fix made
from a receipt is pending until re-witnessed. Both states are normal;
neither is "nothing has ever been tested."

---

## R-001 - The first sessions: the county lives, and its movement was broken

- **Date / build**: 2026-08-29, `1.11.2.0-pre-alpha` deployed live
  (two sessions, the second after a death).
- **Observed** (operator): a populated neighborhood at spawn,
  survivors visibly panicking - which the operator found striking
  at first - then clustered around a house and frozen. Later: they
  killed a human and were eating him.
- **Settles as exercised and working**: genesis at world start (the
  spawn-town draw put a crowd exactly where people lived); pacing
  (79 population events in one session); materialization via the
  Java shell with `dressed=true model=true`; the controller ticking
  9 live agents; flight triggering from believed threats; company
  formation and parting ("kept company on the road", "part ways
  friendly") running throughout.
- **Exposed**: F-049 - the frozen crowd was a route-ordering defect
  (292 FLEE-IDLE flips in one session), fixed in [C18]; F-048 - 276
  place-reading exceptions and 2 history-generation exceptions,
  fixed/guarded in [C18]. Both fixes deployed in `1.11.2.1-pre-alpha`
  and PENDING re-witness.
- **Still open**: the kill-and-eat scene is unattributed (eating a
  body is zombie behavior; the figures were clothed and crouched in
  the corpse-loot posture - the log did not settle which).

## R-002 - The unexplained person

- **Date / build**: 2026-08-29, `1.11.2.0-pre-alpha`.
- **Observed** (operator): a survivor with no clothes, ignored by
  zombies, not hittable, unresponsive to talk and follow clicks -
  in the operator's assessment not really a figure on the map at
  all.
  Seen across a death and reload; a second naked figure appeared
  near the first.
- **Settles**: nothing yet - this is an OPEN observation. Three
  explanations were advanced during the session and all three died
  under checking (belief-table aliasing; corpse-stripping by the
  loot path; "they are the neighbour framework's people", which
  rested on a miscount of the tallying logger).
- **What would settle it**: the inspect panel (J) on such a body -
  it says whether the county knows the person at all - or the
  console's identity lines for the id under the cursor.

## R-003 - The screenshot of the ungated field

- **Date / build**: 2026-08-29, `1.12.0.3-pre-alpha`, options screen
  before any world (the log buffer never flushes at the menu, so the
  screenshot is the whole record - and it is enough).
- **Observed** (operator): on the county's sandbox page, the
  manual-population switch UNCHECKED while Population (manual) sat
  focused, editable, with 45445 typed into it and the label lit in
  vanilla's non-default yellow.
- **Settles**: the [C22] manual-field gating was DEAD at runtime on a
  byte-verified deploy - the operator's report that it did not
  work was exactly right, twice, on two builds. The yellow label is the
  second, independent proof: vanilla's own prerender coloring ran
  unopposed, so no wrap was ever attached. Cause found and named:
  the hook's anchor class is a per-file local in vanilla, the guard
  read nil and skipped silently (F-053). Fixed in [C24] by attaching
  through `SandboxOptionsScreen:create` onto the panel instance,
  with the cannot-attach paths made loud.
- **Still open**: the [C24] gating itself now needs its own witness -
  locked grey fields with switches off, waking on the click - and
  the [C23] dial deletion needs eyes on the Knox Survivors page
  (that hook's anchor was verified global, so it should have been
  live on `1.12.0.3` already).

## R-004 - The locks hold and the dials are gone

- **Date / build**: 2026-08-29, `1.12.0.4-pre-alpha` (the [C24]
  tip), options screen.
- **Observed** (operator): the fields lock correctly now, and the
  neighbour's dials are gone.
- **Settles**: both of R-003's open items, at the screen where the
  defect was photographed. The [C22]/[C24] manual-field gating is
  WITNESSED WORKING - locked until their switches are on - which
  also confirms the [C24] diagnosis end to end: same code idea, dead
  anchor before, real global now. And the [C23] deletion of the
  neighbour's two overridden population dials is WITNESSED ABSENT
  from his page, on the first build anyone actually looked.
- **Still open**: nothing from this thread. The absorption itself,
  the in-world `[SAO][SANDBOX]`/`[SAO][ABSORB]` log lines, and the
  [C25] knowledge-first behavior all still await a world.

## R-005 - Talking does far less than advertised

- **Date / build**: 2026-08-29, `1.12.0.4-pre-alpha`, in a world.
- **Observed** (operator): talking still does nothing worth the
  name - far less than advertised, and the advertisement itself is
  not what the system is supposed to be.
- **Settles**: the talk surface was structurally silent, and the
  code agrees with the operator on every count. Three mechanisms,
  found by reading the path the click takes: the WHOLE person was
  gated behind trust 0.3 (fifteen clicks and fifteen game-hours
  away, +0.02 per hourly talk), so every stranger answered from
  three stock lines; the stock-line reply itself was eaten by the
  murmur cooldown and the repeat-line guard in the voice module -
  a reply to a direct click, suppressed like a volunteered murmur;
  and the talk cooldown's brush-off went to the log file, so a
  second click looked like nothing at all ([B33]'s class, with a
  timestamp). Fixed in [C26]: answers bypass the murmur guards, the
  brush-off is spoken, and smalltalk/warnings/identity flow at any
  trust - lessons, pacts, and what a body admits stay earned, which
  is what the module's own advertisement always said.
- **Still open**: whether the opened surface FEELS like talking in
  play - and the operator's larger ruling that the interaction
  breadth itself is far from adequately modeled (DR-028's recorded
  direction).

## R-006 - Two naked strangers in the operator's kitchen

- **Date / build**: 2026-08-29, `1.12.0.4-pre-alpha`, screenshot +
  console.
- **Observed** (operator): two naked people spawned right next to
  them, inside a house that is theirs. Screenshot shows two
  unclothed figures and a clothed one at the kitchen sink.
- **Console evidence**: `sao-151`, `sao-152` materialized on the
  SAME square 10768,10268 (with `sao-153` a tile away, and `sao-30`
  on that exact square earlier) - all fresh-path, all logged
  `dressed=true model=true`; zero `awakens:` lines (no hibernation
  packs involved); `[SAO][ABSORB] 0 of his people absorbed at start`
  (fresh world - the naked pair are the county's own, NOT the
  neighbour's).
- **Settles**: R-002's naked class reproduces at SPAWN on the fresh
  path - `dressInRandomOutfit()` can return without throwing and
  dress NOTHING, and the materialize log believed the call instead
  of the body (F-054). Also settled: genesis put multiple homes on
  one square inside what is now the player's claimed house, and no
  law stopped the wake (DR-028's first half, ruled from this
  witness). Both fixed in [C26]: worn-count verification with retry
  and named fallback, loud when abnormal; foreign-claim wake
  relocation with re-homing; one body per square.
- **Still open**: whether R-002's unhittable/ignored symptoms were
  the same defect or a second one riding the same naked body -
  the J-panel on such a person still settles that.
