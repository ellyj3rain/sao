# C86 - The engine's own names and trades, by mode

| Field | Record |
| --- | --- |
| Batch | `C86` |
| Date | 2026-09-10 |
| Name | The engine's own names and trades, by mode |
| Status | Closed append-only batch - instrument and border; no mod code |
| Threads | [`T-008`](THREADS.md#t-008), [`T-030`](THREADS.md#t-030) |

## Record

The operator ruled twice before this batch had a shape: richer
evidence first - make the evidence the rows are authored from richer
before multiplying the rows - and deepen the harness to get it, the
deterministic `[C83]`-lineage instrument, no mod code, with gaps that
prove headless-impossible coming back named rather than silently
stubbed.

Four things made the dump's rows thinner than the people in them.
Two were the harness's to answer: **names** - every row's person
rendered as `Unnamed Survivor`, because the engine's pools were never
exposed to a headless run - and **trades' pay** - every row's skills
read `-1`, because the engine's profession definitions were never
loaded. Two were the mod's, and this batch does not reach them: the
**dead** a person has seen, and the **distances** their beliefs carry.
They come back named below, as proposals, which is what the ruling
asked for.

## What the harness can now do

`LuaRun --engine <game dir>` exposes the real shipped bridge into the
environment before any chunk loads, the way the game's own LuaManager
does in play: its statics pointed here, its number converter
installed, its Exposer built over them. The bridge is loaded by name,
not by class, so `LuaRun.java` still compiles against the engine jar
alone and every border that builds the runner is untouched; the mod's
jar joins the classpath only where a caller asks for engine data.

After the chunks load, the runner does the game's own two-phase
script pass over its own generated profession files - traits before
professions, because a profession body grants traits it resolves
through the trait registry - so the engine's profession definitions
register exactly as they do at boot. And the name pools are filled by
the game's own fill functions: the game's
`media/lua/shared/NPCs/MainCreationMethods.lua` loads as a chunk,
then `tools/sweep/engine_fill.lua` calls its three fills by name,
because the boot event they are registered on never fires headless.
Measured on this install: 993 male, 1320 female, 3799 surnames, 25
professions.

The sweep prelude, which used to stub all six dormant bridge
questions away, now forwards them: `forenameCount`, `forenameAt`,
`surnameCount`, `surnameAt`, `professionBoost` and `listProfessions`
reach the real bridge when one is behind it. With no engine behind
it - a border run, or a county that did not ask for engine data - the
forwards answer nil and the shipped code keeps its own sentinels,
exactly as before this existed. The callers are pcall-wrapped and
type-check what comes back, and the county's draw is taken only after
a count comes back, so a nil costs no draw and a plain run's
sequence is untouched.

**A run that would name nobody says so.** If any pool or the
definitions registry is empty, `--engine` exits with a named error
and no answer - a run that would name nobody or skill nobody is not
an engine run that failed quietly, it is a run that did not happen.
This is the `[C69]` module-check discipline pointed at the engine's
own data.

## What a county run this way is - and is not

`python tools/county_dump.py --runs 6 --engine` runs the same
instrument over richer counties. It is **a different county from the
same save name run without the flag**, and the difference is
mechanical, not incidental: a name costs two county draws at
`Identity.create` (the forename index and the surname index, taken
only after a numeric count, so a plain run spends none), and
`listProfessions` grows the catalog the occupation draw runs against
(46 rows plain, 47 on this install). `[C66]` holds per harness
shape: the same name plus `--engine` reproduces the engine county,
the same name without it reproduces the plain one, and neither
reproduces the other - measured draw for draw, the same save landed
on `300x301x31` plain and `716x460x297` with engine data.

That is why the mode is a flag and not the default: the operator's
ratified 112 rows cite the preserved `[C83]` plain dump, and a
citation must keep answering.

Two things a row author will notice in an engine dump, named so
nobody has to discover them:

- **Beliefs are keyed by name now.** `[C71]` keyed person-beliefs on
  the name where there is one and the id where there is not; with
  names at genesis, engine-dump beliefs key on real names
  (`SurvivorName_Paul SurvivorSurname_Singh`) where plain-dump ones
  keyed on ids.
- **The names are the engine's own translation keys.** The bridge
  returns the pool entry raw, exactly as in play, so a record carries
  `SurvivorName_Elbert`. Translating is a display-layer choice with
  a named one-line proposal below, not a harness decision.

One honesty sentence about the engine's own loader, for whoever reads
its state after a run: registration completes - the registry the
bridge reads finished at 25 of 25 - but the loader's own bookkeeping
throws headless after registration (`getScriptObjectFullType`, on a
script whose object name is unset) and swallows itself into its
per-script catch, so its script list reads empty with load errors
flagged. The bridge's read path is the registry, which is why the
`ENGINE` line answers truthfully anyway.

## Border 146, and its control

`tools/engine_data_test.py`, in the gate. Everything it measures runs
the shipped modules behind the real sweep prelude - the one the dump
runs - because the merge lives there. One probe serves both modes;
the assertions differ by mode.

| Property | Measured on the shipped tree |
|---|---|
| the plain county stands | 40 of 40 keep the sentinels; the forward answers nil; the owed days still answer 1096; no draw spent |
| the engine run names people | 40 of 40 named; every forename in the pool for the person's own sex and every surname in the surname pool, read through the bridge's own answers |
| the engine run skills people | the shipped funnel (`Census.skillOf`) answers for people with an engine trade - 4 of 40 here, the rest being students, retirees and the census's own rows, which have no engine profession and answer -1 honestly |
| the catalog grows | 47 with the engine's list against 46 without it |
| the draw is the county's, in both modes | same save twice: identical, names and following draws; a different save: different both |
| the two modes are two counties | the same save, run plain and run with engine data, lands on different draws (`300x301x31` against `716x460x297`) |
| a run that would name nobody refuses | `--engine` with the fill chunks absent: a named error and no answer |

Its control is the `[C85]` tree, which fails naming six things: the
prelude has no forwards to ask (asking the stub for a count throws),
a stub that forwards nothing leaves the county unnamed even with the
engine's own pools exposed behind it, the fill chunk is absent, the
drivers have no flag, and the gate does not run this border.

## What was measured before it was designed

A full one-county engine dump, run before the border existed:
305 decision moments, 768 member-rows, zero capture failures. The
first row of the first moment is a retiree named
`SurvivorName_Elliot SurvivorSurname_Segura` with a full belief set -
and the third moment holds a burger flipper, `SurvivorName_Freddie
SurvivorSurname_Prescott`, whose skills read `cook: 2` - the engine's
own pay for the trade it drew, through the census row, with the
engine's own definition behind it. That is the richer evidence the
ruling asked for: a person, with a name, whose trade pays what the
engine says it pays.

## What comes back named, not built

The ruling asked for the headless-impossible gaps named rather than
stubbed. These two are mod-side, and each is a decision before it is
a change:

- **The dead.** A person's belief set has a `zombies` table and in
  every plain and engine dump it is empty, because the only path
  that writes a zombie belief is `P.observe`, and observe needs a
  body - the engine's sight line, through a materialised survivor.
  A dormant county has no eyes. Whether the dormant half ever
  acquires zombie beliefs - and from what, since the dead walking
  are the sister seam's other half (`../zombie-awareness`) - is a
  design decision about what the unwatched county can know, not a
  harness gap. It is proposed, not answered.
- **Distances.** The road-meeting caller computes the distance
  between two people to decide whether they meet -
  `dx * dx + dy * dy <= MEET_RANGE * MEET_RANGE`
  (`SAO_Population.lua:2346`) - and then throws it away, passing only
  the position to `sawPerson`; the belief writes
  `dist = (prev and prev.dist) or 0` (`SAO_Perception.lua:578`), so a
  person believes somebody was met at distance zero unless a belief
  from a live observation said otherwise. Keeping the distance the
  caller already computed is a small change at both ends of one seam,
  and it changes what every person-belief in every future dump
  carries - which is the operator's to rule, not the harness's.

And one display-layer choice riding on this batch, named for the same
reason: **the translation keys.** If `SurvivorName_Elbert` in a row
should read `Elbert`, that is one translation at the display layer -
the raw key is what the engine itself stores in play, so the record
is truthful as it stands. Proposed, not changed.

**The flag itself is proposed to move.** Once the operator has read
rows authored from an engine dump, `--engine` can become the
default and the plain county the opt-in; until that ruling, the
ratified rows' citations keep answering and the flag stays opt-in.

## No mod code

Nothing under `mod/` changes and no capability moves. The six
questions were always the shipped code's own; this batch only made
the harness able to answer them from the engine's own data, or
honestly answer nil. The designation deal, the belief writes and the
census reads exactly as they were.