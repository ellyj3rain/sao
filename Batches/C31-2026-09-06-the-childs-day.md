# C31 - The child's day

| Field | Record |
|---|---|
| Batch | `C31` |
| Date | 2026-09-06 |
| Name | The child's day |
| Status | Closed append-only batch - awaiting live receipts (a child who breaks and runs before an adult would, a bear in a schoolbag, a child's strength on the panel, an eight-year-old who cannot read the book) |
| Threads | [`T-002`](THREADS.md#t-002), [`T-007`](THREADS.md#t-007), [`T-006`](THREADS.md#t-006) |

## Record

[C29] gave a child a body and [C30] gave the county its children.
This batch gives a child their day: what they fear and what eases
it, what they can read, how fast they learn and how strong they
are, what they carry, and what their head looks like. Every system
is Growing Up's (PZ Chronicles; read with the authors' permission
as the operator settled it, CREDITS.md), carried at SAO's own seams
with the mod's numbers; where a number is ours the code says so.

**Fear.** `SAO_Disposition.fear` is a floor by age - 0.55 at eight
and under, falling straight to nothing at eighteen - eased for good
by every zombie of the child's own killing (half a hundredth each)
and, while it is carried, by a comfort object (0.60 off, the mod's
figure: enough that a frightened child with a bear can sleep), and
raised at night, ten to five, by a fifth under twelve and a tenth
to fourteen. It reads the body and the engine's own clock where
there are any and is the floor alone in a bare VM. The decisions
read it: a frightened child breaks further out (up to four tiles
more), holds against a smaller crowd, will not engage past half,
runs rather than walks, and needs more nerve to stand and shoot.
Nothing changes for anyone grown - the ranges Border 63 holds the
comments to now include the county's children, and the two that
widen say so in the comment. The engine's own panic never drops
below the floor either: `SAO_Age` holds it at the ten-minute pass,
this module's cadence for everything age does, rather than every
second as the mod does.

**Literacy.** The mod counts easy reads until a child can read.
The county's children lived their school years before the fall, so
the reads are the years: none before eight, slow to eleven, reading
from twelve (`SAO_History.literacyOf`). A child who cannot read has
no road through a book - the controller's study branch passes them
over and says why. What a slow reader takes from a book is the
throttle's business, not a second gate.

**The throttle and the floors.** Every grant of experience through
the bridge is scaled by the shell's `xpScale` - a quarter under
ten, half under fourteen, full from fourteen - except strength,
fitness and sprinting, which the mod exempts because the floors
pace them and a quarter of a small packet rounds to nothing. The
floors are the mod's birthday table: the strength and fitness a
child of each age has at least, reaching the engine's adult five at
eighteen, set on a first body through the engine's own
`setPerkLevelDebug`. An eight-year-old is 0 and 0; a seventeen-
year-old 4 and 5.

**The kit.** The mod offers six kid types to a player, each a
package of traits, items and milestones. Here the type falls out of
the child's own eight axes - the aggressive one is the bully, the
nerveless the crybaby, the quiet one shy, the disciplined the nerd,
the bold self-starter the jock, the rest scouts (the mod's own
default) - so it is derived, never dealt. The type decides only
what the child carries (`SAO_History.kitOf`: a schoolbag, the
type's things from the mod's lists, and for most under twelve and
some to fourteen a bear or a doll - the share is ours and says so).
What the types' milestones fade with age - the fear, the slow
learning - already fades above. Every item is verified against the
shipped scripts. The kit is a first body's; an awakened child
carries what their snapshot restores.

**The head.** No beard, and none of the styles no child wears -
the bald, the balding and receding, the mohawks and spikes, the
mullet - replaced from a pool of ordinary cuts by the person's own
hash, so it is the same head every time. Every name is one the
game's own hair definitions declare; the accessors are javap-
verified. Applied whenever a body exists to carry it, since a
restored snapshot can bring a style back.

**Border 106** drives the history and the disposition in the
engine's own VM against the stub county: the floor at six, eight,
thirteen and eighteen; the night by age and hour; literacy, the
throttle and the floors by age; the kit (a schoolbag first, the
comfort share by band, nothing for anyone grown, all six types
reached, the same kit twice); a child's fear equal to the floor
where there is no body, an adult's zero, the flee distance widened
by exactly four times the fear, a frightened child refusing to
engage. By text it holds the body to the floors, the kit and the
learning pace, the appearance to the verified accessors and to
style names the game's own definitions file declares, the age
module to the panic floor, the controller to the literacy gate, the
bridge to the scaled grant and its three exemptions, and Border 63
to loading the county so its ranges include children. Its control
is the pre-batch tree.

**Not in this batch.** Nightmares that wake a sleeper: SAO's sleep
is the agent's state, not the engine's, so the mod's hook has no
seat here yet. Growth spurts (hunger), the cooking and driving
penalties, the wound grief, the voice lines and sounds: the first
three are player-facing penalties on actions SAO's people do not
take that way; the last two are the operator's speech and audio
question, not this record's.

This governed record is the portable project history for this unit.
