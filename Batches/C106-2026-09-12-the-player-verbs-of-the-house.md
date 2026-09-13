# C106 - The player verbs of the house

| Field | Record |
| --- | --- |
| Batch | `C106` |
| Date | 2026-09-12 |
| Name | The player verbs of the house |
| Status | Closed append-only batch - implementation and records |
| Threads | [`T-004`](Batches/THREADS.md#t-004), [`T-008`](Batches/THREADS.md#t-008) |

## Record

ORGANIZATION.md's player-surface contract named thirteen verbs.
Two existed in the menu (observe and ask to join); the rest were
nowhere in the game. The player could watch houses govern themselves
and never touch the machinery the contract promised: no petition,
no backing, no appeal, no claim to the chair, no way to leave.

This batch wires the remaining verbs through the one sanctioned
player-side claim surface, `SAO.PlayerInteraction.claim`, under the
[C105] law unchanged: every player action is a claim, recorded
with recognition and response; the house may ignore it; the claim
never decides anything by itself. The trust gate is the house's own
ear (`trust > TrustToCompany`), not a new threshold - an untrusted
petition is still recorded, but it urges nothing and moves nothing.

What the menu now names, in the house's own vocabulary:

- **Petition the chair** - peace with a feud house, ground of
  their own (clears the next-scout clock when heard), to decide
  together, or to name a second. A heard petition urges the form
  (`urgeForm`); an unheard one lands in the record and nothing
  else. Trusted members keep Counsel, which already does this work.
- **Ask for work** - the chair reads the house's real need state
  (larder lean, water dry, else watch) and deals it as the chair
  office's own "work assignment" decision.
- **Take or refuse the dealt work** - the refusal is a contest,
  the acceptance a claim the chair recognizes; both answer the
  office's decision.
- **Stand behind or call into question** a neighbor's lead claim -
  recognition and dissent, recorded through the same claims store
  every settled house now has (the election's own roster-recording
  from this batch gives every settled house a lead claim to back).
- **Back the chair's word** when a neighbor refused an order -
  re-issues the refused order through `onYourWord` with the
  player's standing behind it, with a real act for work, travel,
  hold, close, and walk.
- **Appeal over the chair to the house** when a claim of yours was
  refused - members who trust you back the appeal; a lone appeal
  is recorded and answered by silence.
- **Claim the chair** - the claim is recorded with the trust-backed
  recognition of the members; the office does NOT move. The
  boundary stands: an office moves only through the house's own
  offer or election, never through its claimant's assertion.
- **Leave the house** - membership and chair both vacated
  (`Org.leave` already empties offices; two explicit removals,
  `clearPlayerMember` and `clearPlayerChair`, fix the
  tostring-nil hazard the old setter would have written).
- **Call the house to a vote** - offered only where the form
  allows one (a council); a ladder house never shows the verb.
- **Stand against the pact** - the record of resistance, changing
  nothing about the pact itself.

Two bridge facts landed beside the verbs: a settled election now
records the leader's "lead" claim with the roster as recognizers
(ORGANIZATION.md's own example, giving support and contest an
ordinary target in every settled house), and a leader's acceptance
of a join petition now joins the player into the organization's
membership - so leave has something real to leave.

Every callback opens with the dial guard (`if not PI.claim(...)
then return end`), so the PlayerInteraction sandbox option governs
whole verbs, not halves of them.

## What changed

- `SAO_Harness.lua` - the person submenu gains the per-neighbor
  verbs (petition, ask for work, take/refuse work, support,
  contest, enforce, appeal, claim the chair); the county submenu
  gains the house verbs (leave, call a vote, stand against the
  pact).
- `SAO_Recognition.lua` - the election settle records the lead
  claim; petition acceptance joins the player; four new bridge
  functions (`onWorkDealt`, `onWorkAnswered`, `onAppealTaken`,
  `onOfficeClaimed`) record what the verbs do.
- `SAO_Standing.lua` - `clearPlayerMember` and `clearPlayerChair`
  (explicit removals; the chair leaving pushes "left" to the wire
  and the Chronicle).
- `SAO_Voice.lua` - ten new EVENTS keys (petitionHeard,
  petitionIgnored, backed, contested, voteCalled, appealHeard,
  appealAlone, resisted, farewell, officeClaim).
- `SAO_Radio.lua` - the "left" kind renders on the county wire.
- `SAO_UI.lua` - the "left" kind renders in the Chronicle.
- `ORGANIZATION.md` - the "Current state" paragraph now states the
  verbs exist.
- `SESSION_STATE.md` advances to this batch.
- `BATCH_LOG.md` gains the `[C106]` row; `THREADS.md` T-004 and
  T-008 gain `C106` (and T-008/T-030 gain the missing `C105` from
  the prior batch's records gap).

## Honest limits

- Enforce is offered only for refused orders with a real act -
  work, travel, hold, close, walk. Kinds without a clean act are
  honestly not offered rather than half-issued.
- Resist changes nothing but the record; the pact stands until
  the house's own machinery breaks it.
- An office claim never moves the office - recognition is a fact
  about the members, not a transfer of the seat.
- An untrusted petition urges nothing - the house's ear is the
  gate, not the menu.

## Verification

Deferred by the operator's standing order for this pass: no gate,
build, deploy, package, test, or git until the planned feature work
is finished; all of it runs once, at the end. Version stamps restamp
in that same end pass.