# C22 - The switch gates the field

| Field | Record |
|---|---|
| Batch | `C22` |
| Date | 2026-08-29 |
| Name | The switch gates the field |
| Status | Closed append-only batch - awaiting its first live receipt |
| Threads | [`T-030`](THREADS.md#t-030) |

## Record

The operator, on the county's own options page, mid-setup: "I don't
think we should allow clicking anything that is manual setting before
we select that option." DR-023's principle, pointed back at our own
dials: [C12] split the mode from the number, but left both manual
number fields editable while their switches were off - a field the
player can edit that will not apply, which is the same lie the
blocked neighbour dials were cured of.

**The gating.** `SAO_Sandbox.lua` wraps
`SandboxOptionsScreenPanel:prerender` - the exact method where
vanilla gates its own Map and Multiplier rows against their governing
toggles, every frame - so the two manual fields (Population,
Newcomers) grey and go non-editable the moment their switch is
unchecked, and come back the moment it is checked. Vanilla's idiom
throughout: label to 0.4 grey, entry text recolored, setEditable off.
The player has already seen rows behave this way; ours now behave
like them.

**The border.** Border 91 (the front-end-speaks-player border) gained
the check: the gating file must exist, name both pairs, disable
editing, and hook the panel prerender - because an editable dead
field is the same class as a decode table, just lying in the other
direction.

This governed record is the portable project history for this unit.
