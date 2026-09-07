# C32 - Conditions are facts about a person

| Field | Record |
|---|---|
| Batch | `C32` |
| Date | 2026-09-06 |
| Name | Conditions are facts about a person |
| Status | Closed append-only batch - awaiting live receipts (a condition on the panel, a survivor who runs from a sound nobody heard, a demented elder's skill falling by the day, the two required mods enabling) |
| Threads | [`T-002`](THREADS.md#t-002), [`T-007`](THREADS.md#t-007), [`T-006`](THREADS.md#t-006) |

## Record

The operator ruled (DR-032) that the county's people carry the
conditions the record says people carried - the mind's and the
body's - and that knowledge decays per person, not at one rate; and
that the way in is both: the Build 42 condition mods required for
the player's side, and the memory conditions carried into SAO for
the county's. The engine ships none of it for a character
(ENGINE_CONTRACT Addendum F). This batch holds it the way age
([C30]) and the child's day ([C31]) are held.

**Drawn, not dealt.** `SAO_Conditions` draws each condition from the
person's own hash at the record's prevalence, gated by age, so a
condition is a fact about who somebody is and two sessions agree.
The draws are independent (the record gives no joint figures), so a
person can carry two. The figures are per ten thousand with the
source beside each; a figure without a source does not ship, and
Border 107 refuses a row that still waits for one.

**The prevalence.** Read the same evening from the primary documents
or their own abstracts, and named beside each row in the code:
dementia by age from the East Boston study (JAMA 1989: 3.0, 18.7
and 47.2 percent at 65-74, 75-84 and 85 and over) with the Canadian
Study of Health and Aging (CMAJ 1994: 34.5 at 85 and over), the last
band taking the midpoint; ADHD in school-age children, 3 to 5
percent (the 1998 NIH consensus statement), none past seventeen
since the record gave no adult figure; major depression, thirty-day,
4.9 percent (the National Comorbidity Survey, Am J Psychiatry 1994);
anxiety as generalized anxiety current 1.6 plus panic one-month
about 1 (the same survey, 1994); PTSD lifetime 7.8 (Arch Gen
Psychiatry 1995 - lifetime, so it runs high, and the row says so);
bipolar I 0.4 (Psychol Med 1997); a reading disability at 6.5
(learning disability ever, NHIS 1988), drawn at all ages because it
stays with a person; asthma and diabetes by age from the 1993
National Health Interview Survey's own table (Series 10 No. 190).
Psychosis and insomnia have their mechanisms and no primary figure
yet, so nobody is drawn for either until one is read - a figure
without a source does not ship. The smoker's third ([A14]) has its
source now too: 30.1 percent of Kentucky adults, BRFSS 1993.

**What they do.** Read by the modules that already decide, and
nothing for anyone without one:

- *The axes.* A condition bends a temperament axis the way the past
  does, inside the human envelope (`SAO_Disposition.trait`): the low
  lose initiative and appetite, the anxious and the haunted some
  nerve; a high spell gives initiative and talk and a low one takes
  them; a focused day gives discipline and a scattered one takes it.
  The bends are ours - the mods trade in vanilla traits and pills,
  and the county's people have axes and no pills.
- *Fear.* The anxious carry a quarter at any age and the haunted a
  constant low fear that spikes at fresh horror - a death seen just
  now - on the same scale as a child's ([C31]); the decisions read it
  and the engine's panic holds it at the ten-minute pass, for
  everyone now rather than the child alone.
- *Memory.* `SAO_Perception` keeps a belief for the person's own
  horizon: the demented keep the recent half as long, the old past
  seventy-five a fifth less (the record's pattern - the old keep the
  old and lose the recent - as a number of ours), the haunted keep a
  threat half again as long (Scotty's hypervigilance). The settled
  past never decayed and still does not; what moves is the recent.
- *The body.* `SAO_Age` carries a condition's load every ten minutes
  in the drift's own terms: the low and the sleepless tire, the
  anxious and the haunted carry stress, the short of breath lose
  stamina, a low spell loses stamina and a high one sheds stress.
- *Dementia's day.* Once a day the bridge walks a demented body's
  skills the way Neurodiverse Traits does: each outside the passive
  and agility families, an even chance of losing 2.5 percent of the
  next level, and a level whose experience falls under its floor is
  lost through the engine's own `LoseLevel`. Seeded from the person
  and the day.
- *Psychosis's hour.* Three times in a hundred passes a psychotic
  person hears a threat nobody else does: a heard belief placed six
  to twelve tiles off on a bearing that is a fact about the moment,
  held and fled from like any heard belief and forgotten by the same
  decay, marked so the record can tell a phantom from a sound.
- *Learning and reading.* The dyslexic learn a tenth slower and take
  a quarter longer over a book (Custom Traits' figures); a focused
  day learns a third faster and a scattered one a third slower (the
  learner traits the mod swaps, which vanilla makes plus and minus
  thirty percent), multiplied into the shell's learning pace beside
  the child's and refreshed each pass since a focus changes by the
  day. The diabetic look for food sooner.
- *In plain words.* The knowledge surface carries the conditions
  beside the axes and the inspect panel says them - "forgets things",
  "anxious", "in a low spell", "reads slowly", "hears things",
  "short of breath" - never a code (DR-017, DR-018).

**The required mods.** Both manifests now `require=` Infirmities
(`twbInfirmities`, 3579088411, which itself requires Moodle Framework
and TchernoLib) and Even More Traits (`EvenMoreTraits4220`,
3777663603), and the description says so; CREDITS carries them as
hard dependencies with their terms. The NPC-mod rule stands: no NPC
mod is required or named. Two of the ruling's names have their
answer in CREDITS: Humans: Are Weak cannot be required (no Workshop
upload) and its non-commercial source-available terms are not
compatible with GPL-3.0, so nothing crosses; the Build 42 ADHD Trait
turned out to be a comic mechanic (the character dies after fifteen
seconds standing still), not a memory condition, and is read and not
taken.

**Border 107** drives the conditions in the engine's own VM over six
thousand people: every share near its declared figure and nobody
outside the age gate; dementia by band among the old; the same
answer twice; both spells and both kinds of day reached; every bend
small and every trait inside the envelope; the plain adult fearing
nothing and keeping beliefs at one, the anxious fearing a quarter,
the haunted keeping a threat half again as long and people the same,
the demented keeping the recent half as long, the dyslexic learning
a tenth slower and reading a quarter longer, the diabetic eating
earlier by 0.05; every word plain. By text it holds every seam and
both manifests' `require=` line. Border 63 now samples the
conditions too, so its ranges describe the whole county. Its control
is the pre-batch tree, which faults twenty-four ways.

**Not in this batch.** Substances and the dependency model (the
next batch); nightmares and narcolepsy (SAO's sleep is the agent's
state); epilepsy and Parkinson's (a fall needs a verified surface
the engine has not been asked for); medications and self-help
(Scotty's), pills (Neurodiverse Traits); the player's own conditions,
which the two required mods give them.

This governed record is the portable project history for this unit.
