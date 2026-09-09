# C81 - Another controller holds them

| Field | Record |
| --- | --- |
| Batch | `C81` |
| Date | 2026-09-09 |
| Name | Another controller holds them |
| Status | Closed append-only batch - awaiting its first live receipt |
| Threads | [`T-002`](THREADS.md#t-002), [`T-001`](THREADS.md#t-001) |

## Record

The county held one fact as `rec.knox` - a boolean named after a single
mod - and read it in twenty-four places across seven files to decide
four different things: never conjure a body for them, never walk them
on the dormant day, never let attrition take them, and presume their
occupation rather than asserting it.

None of those is a question about Knox Survivors. Every one is the same
question: **is somebody else driving this body.** Writing it as a mod's
name put that mod into the logic of a project whose own rule is that a
mod is never named in logic (DR-035), and the next population framework
would have wanted a second boolean and twenty-four more branches.

## What it is now

`SAO.Claims` answers the property. `heldBy` names WHO, because a claim
with no owner cannot be released by the right party or reported to
anybody - which is the same conclusion the sister project reached
reading two other mods' claim surfaces, that a query answering who and
how is a different instrument from one answering yes or no.

The holder's name is a constant in one file. `SAO.Body.knox` is
`SAO.Body.foreign`: a live handle to a body this county did not make
and will not drive.

**A legacy save is not rewritten.** A record from before this carries
the old boolean and nothing else, and it is read once as a claim by the
only holder that flag could ever have meant. Tidying a field name in
somebody's save is a judgement about their save, so nothing does it.

## Border 145, and its control

`tools/foreign_claim_test.py`, in the gate.

| Property | Measured |
|---|---|
| the retired spellings are gone | `rec.knox`, `Body.knox`, `knoxCount` across the tree |
| a holder's name stays in its own integration | every file, against a declared set |
| a declaration cannot outlive its case | each declared file must exist |
| the property answers for a legacy record | the old boolean alone |
| and for one claimed through it | `Claims.claim` |
| and not for somebody nobody holds | a bare record |
| release gives the body back | after `Claims.release` |
| reading a legacy record does not rewrite it | `heldBy` still nil afterward |

Its control is any tree before this batch, where the name IS the
condition in two dozen branches.

**It found a site the enumeration missed.** `SAO_Sandbox.lua` names the
mod to remove two of its sandbox rows from the settings screen, because
absorbing its people makes those dials mean nothing. That is a
legitimate integration and the name there is a settings key, which is
data - so it is declared, with its reason, the way `save_compat`'s
accepted drops are. A declaration that stops describing anything fails
the border on itself.

## What this cost, which was the interesting part

Renaming a field the whole tree reads is not a rename. Four other
borders carried declarations naming `Body.knox`, and each had to be
told the new name or it was checking nothing: the registry-surface
border wanted a reader for `Body.foreign`, the forget-on-death border
wanted the function that clears it, and the self-contained border
wanted `SAO_Claims.lua` declared as a file allowed to name a foreign
mod at all.

**And nine module lists went stale at once.** Every border that runs
the county in a VM enumerates the modules it loads, and none of them
knew about `SAO_Claims` - so `SAO.Claims` was nil, every call site
errored inside a pcall, and the whole population pass went quiet. Six
unrelated borders refused at once, reporting that nobody walks, nobody
seeks and nobody catches anything. That is the same failure a missing
`SAO_Census` caused twice before: a harness result is only as good as
its module list.

`SAO_History` is guarded rather than listed, because it is offline by
construction and a bare VM may hold it without the claim surface. A
county with no claims module has no held people, which is the right
answer rather than a crash.

## What this deliberately does not do

**It does not untangle what the flag conflated**, and F-066 records
that it conflated three things. Two readers ask a claim, one asks
provenance, and one asks an adoption state; they coincide today because
one mod produces all three at once. The tree's own prose disagrees with
itself about it - `SAO_Absorb` says the county takes his people over
completely, and the materialise pass says of the same flag that their
body is his business.

Splitting them changes which people the county spawns, walks and kills.
That is a behaviour change wanting a measurement and a ruling, not a
rename. What the rename buys is that it becomes possible: three call
sites asking three differently-named questions can change
independently, where twenty-four branches on one boolean could not.
