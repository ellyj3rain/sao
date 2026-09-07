# C29 - The body is scaled from inside the animation player

| Field | Record |
|---|---|
| Batch | `C29` |
| Date | 2026-09-06 |
| Name | The body is scaled from inside the animation player |
| Status | Closed append-only batch - awaiting its live receipt (a survivor seen at three quarters) |
| Threads | [`T-002`](THREADS.md#t-002), [`T-007`](THREADS.md#t-007), [`T-008`](THREADS.md#t-008) |

## Record

The operator ruled (DR-032) that the county is to have children, and
that a child's body comes first, through SAO's own Java agent. The
day's reading had already settled why: the vanilla renderer scales no
character. The model instance's scale field is read by the vehicle
class alone; the model script's scale by the drawers of world objects
and items; a calf is its own mesh. An earlier record in this batch's
own day claimed otherwise and was withdrawn against the jar
(ENGINE_CONTRACT Addendum F). What the renderer does read is the
animation player's per-bone model transforms - built in one private
method, `updateModelTransformsInternal`, as each bone's local
transform times its parent's, then multiplied by the skinning bone
offsets and drawn by `Model`. That is the one place a body can change
size, and it is where this batch puts SAO.

**The weave.** `SAOBodyScaleWeave` installs a Byte Buddy exit advice
on that method - the advice calls `SAOBodyScale.apply(this)` and
nothing else - through the same self-attach Main already uses for the
melee patch (ZombieBuddy bundles Byte Buddy 1.18.8 and its agent, and
patches this build with them itself). It retransforms the class if it
is already loaded and applies on first load if not. Under an agent
launch, premain installs it with the instrumentation it is handed.
Advice rather than the melee patch's constant-pool surgery, because
inserting a call moves every offset and stack-map frame after it.

**The scaler.** `SAOBodyScale.apply` resolves the player's character
(its own, or its parent player's, so what a body holds is drawn at the
body's size), and only for SAO's own shell reads a size - a public
field on `SAOIsoPlayerShell`, `bodyScale`, 1 for an adult. Every other
character costs one instanceof. At any other size it multiplies every
entry of every model transform except the homogeneous row: uniform,
about the model origin, which is at the feet, so a scaled body stands
where it stood. NaN, zero and negatives are not sizes and answer 1;
the rest is held to 0.3 to 2.0 so a bad curve shows as a very small
or very large person rather than an invisible one.

**The size.** `SAO_History.heightScaleOf(id)`: an adult answers 1; a
child the fraction of an adult's height from Growing Up's
height-by-age table (128 cm at 8 to 178 at 18, on its growth curve),
with the author's permission as the operator settled it, credited in
CREDITS.md; under 8 the line is carried down and says it is ours.
Nobody in the county is under 19 yet, so today every body answers 1
and skips the call; the child bands arrive with the age batch. The
body reads its size once, after it is dressed, through the bridge's
`setBodyScale`; `getBodyScale` and `bodyScaleReport` read back.

**The receipt.** The harness carries "Scale this survivor to three
quarters" and "Restore this survivor's size": one click, a smaller
person, and the report line - the weave's state and the scaler's
counters - saying why. That click is the live receipt this batch
waits on.

**Border 104** holds the weave to one method with one exit advice,
the size to the shell alone, the arithmetic to the twelve entries
and never the homogeneous row, both load paths installing, the body
sized after it is dressed, the harness carrying click and report,
and - the real defect, off the game - the installed jar's own
`AnimationPlayer` bytes woven by SAO's weaver: the original never
mentions the scaler, the woven class does, and the woven class links
and verifies in a throwaway loader over the game jar, so a broken
frame fails at the gate and not in play. Its control is the
pre-batch tree, which faults every way.

**Not in this batch.** Children themselves (the bands, the fear
floor, the literacy progression, the experience throttle, the
archetypes - the age batch); proportions (a bigger head and hands are
a per-bone scale, a later weave on the same seam); child zombies;
any change for anyone grown.

This governed record is the portable project history for this unit.
