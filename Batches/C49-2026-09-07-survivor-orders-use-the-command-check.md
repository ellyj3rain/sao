# C49 - Survivor orders use the command check

| Field | Record |
|---|---|
| Batch | `C49` |
| Date | 2026-09-07 |
| Name | Survivor orders use the command check |
| Status | Closed append-only batch - awaiting live receipts (a housemate who stays in bed when the keeper shouts; a searcher who tells their objector no and walks out anyway; a trespasser who keeps looting after being told to go; the same three going the other way) |
| Threads | [`T-004`](THREADS.md#t-004), [`T-006`](THREADS.md#t-006) |

## Record

[C37] routed the player's asks through `SAO_Command` and listed what
it left: a survivor's order to a survivor still landed as before.
Three such orders existed and each decided for itself.

- The keeper rousing the house put every housemate in earshot on
  ALERT, with no check of any kind - including housemates who did not
  believe the warning.
- A housemate objecting to somebody leaving on a search decided
  whether the objection carried with a test written at that site:
  bonded, or same side with trust above 0.5, or leader/second with
  trust above 0.5.
- An owner telling a trespasser to go cleared their action queue and
  cooled their errand unless they were desperate.

The second is the one that mattered. DR-033 rules out a hardcoded
authority table, and there was one - covering a single order out of
everything the county says, in a file nobody reads for authority
rules. It is deleted. All three orders now go through `SAO_Command`.

**Three Standing facts became inputs.** No weights, bands or
thresholds changed; each new input is worth what a proven hand is
already worth, a second's standing.

- **Divided houses.** `formOf` reports a house as divided ([B23]) and
  `leansToward` reports which side one member is on ([B24]). The
  objection site read both, correctly, for its one order. That test
  is in `SAO_Command` now, so it applies to every order including the
  player's: a player in the chair of a divided house holds no
  leader's office over members leaning the other way. Members with no
  lean - most of the county, since `leansToward` returns nil for
  anyone without a strong creed pull - keep their leader. `secondOf`
  already returned nil in a divided house, so the second needed no
  change.
- **Designations.** DR-033 names them alongside houses and leaders.
  The watch has standing in a rousing. A member holding a dealt job
  has standing in that job without a skill comparison, which is the
  house having already assigned them the work.
- **Claims.** An owner standing on ground they hold has standing in
  the matter of somebody leaving it. The owner holds no office over a
  stranger, so this is what carries the order at all.

Bonds needed no clause. Both ways a bond forms require high trust
already - 0.6 and up at genesis, 0.75 in play - and the check weighs
trust, so the objection site's bonded clause was redundant.

**The wrapper.** `onTheirWord` in `SAO_Controller` matches the
harness's `onYourWord`: same check, same three replies, the caller
performs the act. Replies go through `V.onEvent`, not `V.answer` -
Border 46 caught the first version doing otherwise. `V.answer` skips
the talkativeness cooldown because a menu click deserves a reply
([B46]); giving the tick loop that exemption would make quiet
survivors as talkative as everyone else. A taciturn survivor refuses
without speaking and is still seen to, because `onEvent` raises the
gesture ([C35]).

**What is not an order.** Seeing another survivor act is not an order
and is not checked: watching somebody run still rouses their company.
A warning the listener believes still raises the house without a
standing test - `SAO_Perception.tell` already carries the listener's
skepticism, so gating the rise on standing as well would count it
twice. The check only gates the courtesy ALERT: `nextDecisionAt` is
cleared for everyone in earshot, so anyone who already knows about
the threat reacts on their own reading. An invitation is not an order
either: who joins a venture stays the hearer's own decision, weighed
on their own trust, lessons and nerve, and belongs to the day zero
arc's socialized-ventures slice.

**Border 122** runs in the engine's VM over Border 105's stub county
with a stub Standing installed and the real disposition loaded, the
same instrument Border 111 uses. It checks the divided house in four
configurations under both a leader and a player chair; the three
matter-standing readings and the four cases where each does not
apply; and the county sampled under a peer, the watch, an owner on
their claim and an owner despised. By text it checks each seam,
including that no authority test remains in `SAO_Controller` and that
`onTheirWord` is called exactly three times. Its control is the
pre-batch tree, which fails every seam.

**Border 111** needed one edit: `Cmd.obedience`'s fourth parameter is
`arg` rather than `job` now, since for `leave` it is a square rather
than a job name.

This governed record is the portable project history for this unit.
