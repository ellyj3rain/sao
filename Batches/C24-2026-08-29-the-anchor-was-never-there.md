# C24 - The anchor was never there

| Field | Record |
|---|---|
| Batch | `C24` |
| Date | 2026-08-29 |
| Name | The anchor was never there |
| Status | Closed append-only batch - awaiting its first live receipt |
| Threads | [`T-030`](THREADS.md#t-030) |

## Record

The operator photographed the proof on `1.12.0.3`: 45445 typed into
Population (manual) while "Set the population manually" sat unchecked
(R-003). The deploy was byte-verified twice, so the defect had to be
in the code as written - and it was, one line deep. [C22] hung its
gating hook on `SandboxOptionsScreenPanel`, and vanilla declares that
class as a per-file LOCAL (`SandboxOptions.lua:5`, read directly).
The hook's `if` guard read a nil global and skipped - silently, by
design - so the gating never existed at runtime through two deploys,
while Border 91 held the hook's TEXT and passed a corpse (F-053).

This is [C3]'s lesson landing on our own tree: the neighbour's `KS`
was a per-file local and the [B45] hold had never engaged; now a
vanilla class did the identical thing to us, and the census had
classified the name as an engine global on say-so - answering WHO
owns it without probing WHETHER it exists.

**The fix.** The screen class itself IS a real global
(`SandboxOptionsScreen`, line 3 of the same file). The county wraps
its `create`, finds its own page panel by its own controls, and wraps
that panel's prerender at the instance - where vanilla's per-frame
gating idiom (F-050) actually runs, on the exact
`panel.controls`/`panel.labels` full-name keys the createPanel site
builds. The [C23] dial deletion was verified live all along: its
anchor (`ServerSettingsScreen`, its file's line 6) is a real global.

**The rules that survive the batch.** An engine global is cited with
its DECLARING line, never its use sites - use sites look identical
for locals. And a hook whose anchor may be absent fails LOUDLY
through the Seams: both cannot-attach paths now call
`Seams.wentDark("sandbox-gating", ...)`, because a guard that skips
in silence converts a missing anchor into dead code that passes every
text-reading border. Border 91 now refuses the dead anchor by name,
requires attachment through the one real global onto the panel
instances, and requires both loud paths; its control is the [C22]
tree itself - the exact code the operator photographed failing.

This governed record is the portable project history for this unit.
