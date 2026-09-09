# C74 - The three projects and what each owns

| Field | Record |
| --- | --- |
| Batch | `C74` |
| Date | 2026-09-09 |
| Name | The three projects and what each owns |
| Status | Closed append-only batch - documents only; owes no play receipt |
| Threads | [`T-030`](THREADS.md#t-030) |

## Record

Three repositories describe one county and nothing said what the
architecture across them was. Each knew its neighbours in passing -
SAO's DR-037 says the stakes come from the zombie side and that the two
mechanisms stay unmerged; ZAO's README says SAO owns the living and ZAO
the turned; Speakeasy's record entry 23 says it and SAO are one project
in two repositories - and no document held the three together or named
the edges between them.

`PROJECTS.md` does, on the operator's direction.

## What it says

| | Repository | Licence | What it owns |
|---|---|---|---|
| SAO | `survivor-awareness` | GPL-3.0 | the living |
| ZAO | `../zombie-awareness` | GPL-3.0 | the turned |
| Speakeasy | `../zomboid-speakeasy` | MIT | how anybody decides |

And three seams, each with its own rule:

**SAO to ZAO, the turn.** Already litigated on both sides. SAO owns the
death of the person completely and ZAO owns the risen mind; exactly one
controller runs any body. What crosses is the record, not the belief
cache, and temperament is hash-derived from the id, so a mind can be
re-derived and then degraded with almost nothing stored.

**SAO to Speakeasy, the dataset.** No code crosses and the licences are
why the repositories are separate at all. Rows are built from SAO's own
people and replace the places where SAO authors a list.

**ZAO to Speakeasy, the degraded cognition.** The third edge, and the
one not yet built. A turned mind is a cognition with its inputs
failing: the same model under a transform rather than a second model.
Nothing is designed there yet and nothing should be until ZAO's G2
lands. Naming the edge is what stops it being invented twice.

## Where it lives, and why here

Canonical in SAO, pointed at from the other two. SAO holds the person
record both others read, and ZAO's README already reaches across by
relative path, so this follows practice rather than inventing a
convention. `MEMORY.md` classifies it and Border 43 holds its currency
with every other root document.

## No new border, and the reason

This batch adds none. Border 43 already reads every root document's
header against `VERSION` and refuses an unclassified root file, which
is what can honestly be checked about a document.

A border asserting that two sibling repositories carry an agreeing
pointer would be a border about project governance rather than about
the mod's behaviour. This repository wrote one of those once - a border
checking forge settings - and the operator had it deleted. The
discipline is documents and practice, not a checker.
