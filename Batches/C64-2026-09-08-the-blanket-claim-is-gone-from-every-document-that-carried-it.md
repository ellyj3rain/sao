# C64 - The blanket claim is gone from every document that carried it

| Field | Record |
|---|---|
| Batch | `C64` |
| Date | 2026-09-08 |
| Name | The blanket claim is gone from every document that carried it |
| Status | Closed append-only batch - nothing about play changed, so nothing here is owed a receipt |
| Threads | [`T-030`](THREADS.md#t-030) |

## Record

DR-025 banned the perpetual-untested claim on 2026-08-29 and Border 97
has held it out of `SESSION_STATE.md` and `PLAYABILITY.md` ever since.
The operator found it alive today, thirty-five batches later, in the
README.

It was in five places:

| Document | The wording |
|---|---|
| `README.md` | "No feature in this mod has live-play verification" |
| `mod/mod.info` | "no feature here has live-play verification yet" |
| `mod/42.20/mod.info` | the same string, and it is what a player reads |
| `PLAYABILITY.md` | "none of it is live-witnessed" |
| `PUBLISHING.md` | "none of it is a play receipt" |

Three of those are files Border 97 never opened. It read exactly two
documents, named as literals in a loop. The fourth was in a file it did
open, and its pattern walked past the wording. A ban that matches one
wording of a claim bans a wording.

The claim is false and has been since `[C19]`. `RECEIPTS.md` holds six
receipts, R-001 to R-006, several of them defects the operator found by
playing - which are receipts for everything that had to work to reach
them. The mod's own description told anyone reading the Workshop page
that none of that had happened.

The README's coordinate was `1.10.6.0-pre-alpha` against a tree at
`3.10.2.1-pre-alpha`, two tiers stale, because Border 43 walks the root
for files carrying a `| Version |` header cell and the README does not
have one - it is the public entry point, not a doc-pack file.

## What changed

The five documents say what is true. The README states how many
receipts the ledger holds and what a receipt is; the `mod.info`
descriptions say "PRE-ALPHA: expect defects. Play evidence is recorded
as it lands and most surfaces do not have any yet."

**Border 97** reads every document that speaks for the project - every
root `.md` and both `mod.info` descriptions, twenty-six of them - rather
than two files named as literals. `RECEIPTS.md` and
`DECISION_REGISTRY.md` quote the claim while explaining why it is
banned; they are exempted by name, so the exemption is a decision
somebody made rather than a hole. The pattern gained the four spellings
that got through, and the border refuses to run against fewer than three
documents, because reading two was its actual failure.

It also holds a number now. The README states the receipt count and the
border checks it against the ledger. That is the durable half: a
negative nobody can check does not decay, it just stops being true,
whereas a count that disagrees with `RECEIPTS.md` fails the gate on the
next commit.

**Border 43** reads the README's Status section for the coordinate it
names, since the README carries no header cell to be caught by.

**Border 43 had no control mechanism at all.** Its `ROOT` was the tree
the file lives in and nothing else, so it could not be pointed at a
broken tree and its control had never been run. It takes an optional
`argv[1]` now, like every other border here.

## What was measured before it was designed

The tree was searched for the claim in every wording before anything was
written, in Markdown and in `mod.info`, and five sites came back. Border
97's own scan was then read to find why it held two of them and not the
other three: the loop names two files.

Both borders were controlled against the tree as it stood at `[C63]`.
Border 97 names all five sites and the missing count. Border 43 names
the README's stale coordinate, and it could only do that after being
given the control mechanism it never had.

## Not in this batch

**Whether any particular surface has been played.** This batch removes a
false universal and does not add a receipt. What has been witnessed is
what `RECEIPTS.md` says, unchanged.

This governed record is the portable project history for this unit.
