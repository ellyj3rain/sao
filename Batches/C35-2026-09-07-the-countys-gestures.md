# C35 - The county's gestures

| Field | Record |
|---|---|
| Batch | `C35` |
| Date | 2026-09-07 |
| Name | The county's gestures |
| Status | Closed append-only batch - awaiting live receipts (a survivor seen agreeing and arguing from the harness, one dancing, one playing the guitar on the porch, an evening seat that is not the vanilla one) |
| Threads | [`T-002`](THREADS.md#t-002), [`T-007`](THREADS.md#t-007) |

## Record

The operator named Week One as existing art with a society already
living, then Lifestyle: Hobbies as holding much of it already, and
ruled (DR-034) that four groups cross into SAO copied, with each
credited author's permission as they settle it, credited per author,
and bound by SAO's own nodes. This batch carries the art and wires
it to the moments the county already has. A gesture is never
authored on its own; it is what a decision already made looks like.

**What crossed.** From Hobbies (Angry): twenty-two conversation
gestures (agreeing, listening, acknowledging, nodding, angry,
dismissive, shaking no, looking down, agony, yawn, informal bow, arm
gestures, and four frustrated endings), eight sitting loops (arms
crossed, hands on face, hands on thigh, pensive, a tear wiped, a leg
up), eight instrument plays (five guitar, three harmonica) and
sixteen dances. From Week One: the waiter's serving (SaneGuy and
Slayer) and twenty-one sounds - coughs by sex and claps (Lauren
Sinclair and AuD, as the mod credits them). Every animation file was
checked for the player's own rig before it was copied; the manifest
in `tools/gestures_manifest.json` names each file's source and
author. Nothing of either mod's logic crosses.

**How it plays.** `SAO_Gesture` carries a gesture as a timed action
that sets one animation variable and nothing else; the engine's own
actions state runs while the action does, and SAO's nodes under
`AnimSets/player/actions` - named `SAO_*`, keyed on `SAOGesture` so
nothing overlaps another mod's - select the animation. The seats ride
the engine's own sitting state: a variable set when the evening seat
begins, cleared at every stand, read by nodes in the sitting loop at
a priority above the vanilla one. Greetings and partings use the
engine's own emotes. Sounds are defined in SAO's own script over the
copied files.

**The moments.** The meeting (the politick's verdict): the speaker
gestures and the listener answers warm, sharp or neither, the way
Hobbies' own talking table has a listener answer a mood. The voice's
events, which are the county's moments already: thanks, aid, a
promise kept, a pact, peace - agreement; a feud, a grudge, colours
refused - anger or dismissal; grief - agony or a bowed head; a lesson
told or taught - the teacher's arm; a grumble, an unanswered call, a
doubted worker - a frustrated ending; bread shared - the serving; a
parting or a reunion - the engine's own wave; someone sick - a cough.
The evening seat: how a person sits is who they are and what they
carry - a lived loss sits with a tear wiped, the low with hands to
the face, the disciplined with arms crossed, the nervous leaning
forward. The porch tune: the instrument's own animation while the
music SAO already plays reaches its listeners, and those already
close half dance and half clap.

**Border 109** holds the file, the node and the name to each other:
every copied file present, rigged and credited in the manifest; every
node parsing, named `SAO_`, keyed on SAO's variable and naming a file
that exists; every name the module asks for bound; every sound the
module plays defined over a file that exists; and every moment wired
- the voice funnel, the meeting, the seat and three stands, the tune
and its listeners, the four harness receipts, the two credits. Its
control is the pre-batch tree.

**Not in this batch.** The rest of the art the operator chose and the
pages hold - the cashier, the protest, CPR, the ball, the remaining
dances and instruments, the building ambiences, the helicopters and
horns - which wait on the moments that would show them (a shop, a
crowd, a medic over a body, the record on the county's calendar); the
speaker's register floors (no speaker exists yet); the running-game
receipt.

This governed record is the portable project history for this unit.
