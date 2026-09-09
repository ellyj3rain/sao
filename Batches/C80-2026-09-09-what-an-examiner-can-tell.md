# C80 - What an examiner can tell

| Field | Record |
| --- | --- |
| Batch | `C80` |
| Date | 2026-09-09 |
| Name | What an examiner can tell |
| Status | Closed append-only batch - awaiting its first live receipt |
| Threads | [`T-007`](THREADS.md#t-007), [`T-002`](THREADS.md#t-002) |

## Record

`[C78]` gave a body a course to run and `[C79]` let the county catch
it. Neither was visible to anybody: a survivor sickened and died out
there and the only trace was a line in the log.

This is the reading, and its whole design is one rule. It reports what
**this examiner** could tell, not what the record knows.

## Two instruments, and the difference between them is the point

`SAO_Inspect` sees everything - it reads the stores raw, provenance and
all - and its own header says a window is not a pathway. That is the
right shape for a debug panel and the wrong shape for a person looking
at another person.

DR-007 draws Knox on two ledgers: what the pathogen does, and what
anyone is permitted to know about it, *never a percentage on the
forehead*. This module is the second ledger made visible.

**What gates it is the examiner's own First Aid.** `Perks.Doctor` is
the skill vanilla already uses to decide how well somebody dresses a
wound, and `[B20]` already reads it for exactly that. Untrained, a
person sees that something is wrong and could not say what. Trained,
they can name the fever. Practised, they can say how far along it is.
Only a medic can tell whether the body is winning, because that is a
judgement rather than a symptom.

The tiers are named at the top of the file rather than written as bare
numbers in branches, because a `>= 5` in a condition is a decision
nobody can argue with.

## The split, which the border forced

`SAO_Medical.lua` holds the judgement and loads in a bare VM.
`SAO_MedicalWindow.lua` holds the window and cannot, because it needs
`ISCollapsableWindow`. Border 144 loads the first without the second,
so the rule about what a person may know is checked every run and the
renderer is only ever a renderer.

The entry sits under the person's own submenu, which is where `[B12]`
put everything you do with somebody.

## Border 144, and its control

`tools/medical_reading_test.py`, in the gate. It runs the reading in
the engine's own VM against a patient deliberately full of numbers.

| Property | Measured |
|---|---|
| no digit reaches a reading | every skill from 0 to 10 |
| looking at somebody does not change them | the record, field by field, either side |
| the untrained never learn what it is | the word at skill 0 |
| the trained can name it | the same at skill 3 |
| only the practised can place it | skill 3 against skill 6 |
| only a medic gets a verdict | skill 6 against skill 9 |

**The mutation property is not decoration.** `Course.positionOf`
repairs a missing span by writing one, so a reading that reached it
carelessly would change the patient it was only supposed to look at.
The first draft did exactly that and the assertion caught it; the
reading only asks for a position where the course has already been
stamped.

Its control is any tree without `SAO_Medical.lua`, where the county's
sickness is invisible.

**The border's first run refused for its own wording.** It searched for
"well along" and "fighting" against a patient sitting at position 0.13
with progress ahead of it, whose lines are "It set in recently" and
"holding it off" - so it reported the module silent while the module
was answering correctly. A border that searches for a line its subject
cannot emit measures its own vocabulary. The phrases it searches are
the ones this patient actually produces, and the file says so.

## What this deliberately does not do

**It does not tell the patient anything.** Reading a person does not
inform them, does not move standing, and does not enter the county's
knowledge. A look is not a conversation.

**It does not treat.** `[B20]`'s `aidWound` is the treatment surface
and already takes a doctor and a patient separately. What a medic can
do about what they have just seen is its own batch.

**It says nothing about mutation.** The course a body runs after the
turn is ZAO's, and the reading stops at the county's own living people.
