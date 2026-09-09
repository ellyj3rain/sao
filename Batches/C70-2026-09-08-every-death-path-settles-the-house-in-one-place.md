# C70 - Every death path settles the house in one place

| Field | Record |
| --- | --- |
| Batch | `C70` |
| Date | 2026-09-08 |
| Name | Every death path settles the house in one place |
| Status | Closed append-only batch - carries `[C68]`'s outstanding receipt; adds none of its own |
| Threads | [`T-004`](THREADS.md#t-004), [`T-008`](THREADS.md#t-008) |

## Record

`[C68]` moved the settling of a house on a death into
`Identity.markDead`, the funnel every death path reaches, and deleted
the one call site that had been doing it for itself. It deleted the
wrong one. Or rather: it deleted one of two, and its border could only
see the one it deleted.

The site in `SAO_Controller` re-elected when the corpse had held the
chair, and logged `leadership passes from the dead`. Border 136's seam
read `SAO_Controller.lua` and asserted that phrase was gone.

The same call site existed in `SAO_Population`'s dormant attrition, in
different words:

```lua
local deadGroup = SAO.Standing.groupOf(id)
...
SAO.Identity.markDead(rec, tickCounter, ...)
...
if deadGroup and SAO.Standing.leaderOf(deadGroup) == id then
    SAO.Standing.electLeader(deadGroup)
end
```

That is the dormant half of the county - where nearly every death in a
run happens. It survived a batch written to delete it because the
border named a file and a phrase instead of the shape.

By `[C68]` it was also wrong rather than merely redundant: `deadGroup`
is captured BEFORE the death, so after the funnel has settled the house
and possibly released its last member, this ran a second election over
a group that had already ended.

## What changed

The call site is gone. `SAO_Exchange`'s election is untouched: it is a
conversation-time election ([A14]), not a death path, and re-deriving
who a house defers to when two of its members talk is exactly what it
is for.

Border 136's seam no longer reads one file for one phrase. It reads the
whole Lua tree for the SHAPE - an `electLeader` within a dozen lines
after a `markDead` - and names every site it finds. Against the `[C69]`
tree it finds one and refuses.

## What was measured before it was designed

Every `electLeader` call site in the client tree was read before any
was removed, rather than the one that matched a phrase:

| Site | What it is |
| --- | --- |
| `SAO_Population` dormant attrition | a death path. Removed. |
| `SAO_Population` road meeting | a same-group meeting is an election moment ([A22]). Kept. |
| `SAO_Exchange` conversation | leadership settles in conversation ([A14]). Kept. |

## Not in this batch

Nothing in the county's behaviour changes that a player could see. The
funnel was already settling every house correctly after `[C68]`; this
removes a second, wrong election that ran after it on one path, and
makes the border able to notice the next one.
