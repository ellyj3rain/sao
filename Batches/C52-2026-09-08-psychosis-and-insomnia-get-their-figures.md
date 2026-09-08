# C52 - Psychosis and insomnia get their figures

| Field | Record |
|---|---|
| Batch | `C52` |
| Date | 2026-09-08 |
| Name | Psychosis and insomnia get their figures |
| Status | Closed append-only batch - awaiting live receipts (about one adult in ten in the county carrying insomnia, and roughly seven in a thousand carrying psychosis; a survivor reacting to a threat nobody else heard) |
| Threads | [`T-002`](THREADS.md#t-002) |

## Record

Two rows in `Cn.PREVALENCE` stood at zero since [C32], each with the
reason in the file: no primary figure of the era had been read, so
nobody was drawn. Both mechanisms existed and neither could ever fire
for anybody in the county - insomnia's fatigue and psychosis's hour,
the pass where somebody hears a threat that is not there.

**Psychosis - 70 per ten thousand.** Kendler KS, Gallagher TJ, Abelson
JM, Kessler RC, "Lifetime prevalence, demographic risk factors, and
diagnostic validity of nonaffective psychosis as assessed in a US
community sample. The National Comorbidity Survey", Arch Gen
Psychiatry 1996;53(11):1022-31: by clinician diagnosis, lifetime
prevalence was 0.2% narrowly defined and 0.7% broadly. Read off the
journal's own abstract page.

Three choices there, each the conservative one and each stated in the
row. Broad rather than narrow, because what this mod's psychosis does
is hallucinate a threat and that is not confined to schizophrenia.
Clinician diagnosis rather than the computer algorithm's 2.2%, because
the paper's own finding is that the two differ substantially and the
clinicians are the check. Lifetime rather than twelve-month, for the
reason the bipolar row already gives - this is a standing fact about a
person, not a spell. The NCS sampled ages 15-54 and no upper bound is
applied: a lifetime figure measured under 55 is a floor for anyone
older, never a ceiling.

**Insomnia - 1020 per ten thousand, and it is the weakest row in the
table.** Ford DE, Kamerow DB, "Epidemiologic study of sleep
disturbances and psychiatric disorders. An opportunity for
prevention?", JAMA 1989;262(11):1479-84: of 7954 respondents in the
NIMH Epidemiologic Catchment Area study, 10.2% noted insomnia at the
first interview.

What that figure is not is written into the row. It is a complaint
recorded once, not a diagnosed chronic disorder, and this mod's
insomnia is a standing trait costing fatigue every ten minutes. The
paper's own persistent group - insomnia at both interviews, a year
apart - is the right analogue, and its abstract gives no percentage
for it. Several attempts to reach that number found only the odds
ratio it supports. So the row ships the figure that was actually read,
says it draws about one adult in ten and that this is more than the
county should carry, and names exactly what would replace it. The
alternative was a second estimate nobody had read at its source, which
is the thing this repository does not do.

**Border 125 makes the rule a mechanism.** "A figure without a source
does not ship" has governed the county's epidemiology since [C32] as a
habit. Nothing checked that a constant still matched the figure its
comment cited, and nothing stopped a row sitting at zero without
saying why - which is how these two sat undrawn with the note buried
in a long file. The border now reads both prevalence tables and holds
every row to four things: a comment naming a year or pointing at the
table above it; at least one figure in that comment; a zero only where
the comment says no figure was read, with the count of such rows
printed either way; and the constant reachable from the comment's own
figures by one of the derivations the file already uses - a percentage
times a hundred, a rate per thousand times ten, two percentages
summed, a stated range, or a midpoint to a tenth of a point, each
named in the row that uses it. Thirty-two figures across seventeen
rows, all reachable.

It found four rows on its first run: cocaine, opioids, stimulants and
sedatives all take their numbers from the report the cannabis row
cites and none of them said so. Fixed the way the diabetes row already
does it, with a pointer at the shared source rather than a repeated
citation.

**Not in this batch.** The persistence figure for insomnia, which
needs the paper's text rather than its abstract. Nothing else in the
table moved.

This governed record is the portable project history for this unit.
