| Document | The Grounded Dead - a derivation for ratification |
|---|---|
| Version | `3.10.2.2-pre-alpha` |
| Author | ellyj3rain |
| Repository | `GROUNDED_DEAD_PROPOSAL.md` |
| Status | RATIFIED WITH AMENDMENTS (DR-021) - mechanism B plus the presence layer and the state-agreement constraint; this file is now the derivation appendix. Final numbers await the [C16] measurement. |

# The grounded dead

The operator's item 6, 2026-08-29: the county's zombie count is
arbitrary - consistent with neither the depicted region's real
population nor the lore. [B38] grounded the LIVING the right way
(derive the scale from the installed map, grade it against the real
demography); this document extends the same method to the dead and
stops at the line the order drew: **numbers are the operator's; the
derivation and its confidence are the work.** Nothing below changes
behavior. Player-facing sandbox knobs stay knobs.

## 1 · The demographic base (confidence: medium)

The map states where people were. The operator's install carries
twelve spawn regions - twelve settlements - and the real 1990 census
anchors the towns the map depicts or imitates:

| Anchor (1990 census) | People |
|---|---|
| Muldraugh, KY | ~1,300 |
| West Point, KY | ~1,200 |
| Brandenburg, KY | ~1,900 |
| A rural KY village of the map's smaller-town footprint | 300-800 |

Twelve settlements at a defensible median of ~900, plus the
unincorporated rural surround real counties carry (roughly a third
again over town totals in 1990 Meade/Hardin), puts the mapped area's
pre-Event population at:

**~10,800 base, honestly ranged 9,000-16,000.**

Method note: the anchor towns are checkable census facts; the
fictional towns (Rosewood, Riverside, March Ridge) are banded by
footprint against the real ones, which is a judgement, stated. The
region count is read from the install by [B38]'s own counter, so a
map mod moves this number the same way it moves the living.

## 2 · The Event's course (confidence: the lore is explicit; the split is judgement)

The Knox Event seals people IN: the exclusion zone closes on July 9
with the residents inside it, there is no civilian evacuation, and by
the end of the month the free world writes the zone off. So the dead
are not "some zombies" - they are the trapped population, minus:

- **The still-dead** (destroyed in the outbreak's violence, fires,
  and the military action at the perimeter): 5-15%.
- **The living at world start**: the county's own target (216 on a
  full Knox), the player, the neighbour framework's people, and the
  unaffiliated - under 3% on any honest reading; survival in the
  lore's zone is the exception that the game is about.

**Walking dead ≈ 82-92% of the base: ~8,000-13,500 across the full
map, with ~9,500 as the single defensible point estimate.**

For scale: that is roughly 44 dead for every living person the county
maintains - the lore's loneliness, in a ratio.

## 3 · What the engine does today (confidence: high on the knobs, none on the total)

Vanilla Apocalypse ships `ZombieConfig.PopulationMultiplier 0.65`
(the "Normal" row of `defines.lua`'s table - 2.5/1.6/1.2/0.65/0.15/0),
start multiplier 1.0, peak 1.5 at day 28, respawn on. The ABSOLUTE
count those produce is not readable from Java or Lua: the crowd is
owned by `ZombiePopulationManager` backed by the native
`PZPopMan64.dll` (the sibling's F-006), and no structural pass can
state the engine's implied total. Anyone who claims the default map
"has N zombies" without measuring is doing what the old bite formula
did.

## 4 · The mechanism fork (the operator picks)

**A - Guidance only.** SAO documents the derived total and the
sandbox rows that approach it; the player sets vanilla's own knobs.
Cost: nothing; honesty: total. It cannot close the loop, because
nobody has measured what a multiplier yields on this install.

**B - Measure first, then guide (recommended).** One inspect-harness
line - a dead census: real zombies in loaded cells, sampled per-cell
density, extrapolated to the install's cell count, written to the
one JSONL. An instrument in the [C6] discipline: reads everything,
teaches nothing, changes nothing. With a measured
zombies-per-multiplier curve on THIS install, the §2 target becomes
a defensible multiplier recommendation instead of a guess, and the
recommendation ships as documentation and a sandbox-preset note.

**C - Active management.** SAO counts the dead and culls or spawns
toward the derived budget. REJECTED here, and argued: the crowd is
native and opaque (F-006), every cull is a deletion the [C9] border
exists to interrogate, and one mod fighting the engine's own
population manager is the two-systems-one-street shape DR-015 just
removed from the menus.

## 5 · What ratification looks like

The operator states: the target (a number or a range from §2, or
their own), the mechanism (A/B/C), and - if B - whether the measured
recommendation may ship as a preset note. On ratification this
document's numbers move to DECISION_REGISTRY as a DR and this file
becomes the derivation appendix; until then nothing in the tree acts
on it.
