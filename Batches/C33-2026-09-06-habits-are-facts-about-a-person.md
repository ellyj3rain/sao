# C33 - Habits are facts about a person

| Field | Record |
|---|---|
| Batch | `C33` |
| Date | 2026-09-06 |
| Name | Habits are facts about a person |
| Status | Closed append-only batch - awaiting live receipts (a drinker's shakes on the panel, a survivor taking a drink from their pack, one walking to a cabinet for a bottle, a dependency gone in the log after the clean days) |
| Threads | [`T-002`](THREADS.md#t-002), [`T-007`](THREADS.md#t-007), [`T-006`](THREADS.md#t-006) |

## Record

The society arc's S6 gave the county its smokers ([A14]): a third of
it, a smoke when the withdrawal bites, a smoke handed over. The
operator ruled (DR-032) that the dependency model the catalogue
settled on comes into SAO's habits the same way. This batch carries
it, on the one substance the record gives a figure for and the
county has a supply of - drink - and on the dependencies the county
fell with and has no supply of at all.

**Drawn, then lived.** `SAO_Habits` draws a habit from the person's
own hash at the record's prevalence, like a condition ([C32]), and
then the habit lives on the record: the last drink, the drinks
taken, the habit quit or acquired. The drinker: alcohol dependence,
twelve-month, adults eighteen and over, 4.38 percent - the National
Longitudinal Alcohol Epidemiologic Survey of 1992 (Grant et al.,
Alcohol Health and Research World 1994), read in full; abuse without
dependence does not withdraw and is not drawn. The users: past-month use
by age from the 1993 National Household Survey on Drug Abuse
(SAMHSA's advance report of 1995, read from its tables): marijuana
4.9, 11.1, 6.7 and 1.9 percent at 12-17, 18-25, 26-34 and 35 and
over; cocaine 0.4, 1.5, 1.0 and 0.4; and, past year where the
record has no past month, heroin 0.1, stimulants 1.1, sedatives
and tranquilizers about 2.0 together. Past-month use stands in for
the dependent, and the row says why: the record's dependence
figure (1.8 percent, twelve-month, any drug, ages 15-54, the
National Comorbidity Survey) is not split by substance, and N and
C's own dependency is gained by use every few days, which a
past-month user approximates. Kentucky drank leaner than the
nation that year (binge drinking 9.2 percent against a 14.2
median, BRFSS 1993), which is noted beside the drinker's row and
not applied, since the record gives no state figure for
dependence.

**The drinker (The Alcoholic, MIT; CREDITS.md).** Hours since the
last drink; nobody drank before the record says they did, so a
drinker the world starts with has been dry since it began - the fall
cut the supply the day it came. Four withdrawal phases at 12, 24, 48
and 72 hours dry, each carrying the mod's hourly stress (0.10, 0.15,
0.25, 0.30) over the six passes of an hour, its chance of fatigue,
and past the first a little pain for its headaches (ours in size).
Three weeks dry (504 hours, the mod's dynamic trait) and the habit
is gone for good; fifty drinks close together (four points a drink,
one off an hour, gained at 200) and somebody who was not a drinker
is one. The drink itself: a drinker twelve hours dry takes a quarter
of the fullest alcoholic drink they carry through the engine's own
fluid action - Build 42 keeps beer, wine and whiskey as fluids in
the Alcoholic category, not as food, which the engine contract now
records - and with none carried walks to the nearest container
holding one, through the same forage path and the same take food
uses, respecting another house's claim as food does. Every drink one
of the county's bodies finishes, by their own hand or the player's
gift, is counted by a wrap of the drink action, the way the mod
counts the player's.

**The users (N and C's Narcotics, the page's schedule; CREDITS.md).**
A dependency lost after eighteen to twenty clean days - which of the
three is a fact about the person - with withdrawal medium from day
one (day three for sedatives), bad from day five (six) and mild from
day ten; cannabis withdraws from nothing, as the page says. The page
gives the tiers and not their sizes, so the sizes are ours and say
so: stress and fatigue per pass, and pain for opioids. Nobody in the
county has a supply, so a user's clean days run from the world's
first day and every dependency is gone by the twentieth - the county
the living start ([C28], DR-031) walks into has people sweating it
out in its first week and nobody by its third. Drugs, items and
interactions are not carried; there is nothing to take.

**Smoking** stays as it was: a third of the county (Kentucky's own
30.1 percent, BRFSS 1993, sourced in [C32]), and the end did not
help anyone quit.

**Where it reaches.** The age module carries a habit's load every
pass - withdrawal is not a chance - and once a day settles the
habits on every record, body or not. The knowledge surface and the
panel say it in plain words: "drinks", "shaking for a drink", "used
cocaine, sweating it out" (DR-017, DR-018).

**Border 108** drives the habits in the engine's own VM with a record
store installed: the drinker's share of adults near the declared
figure and nobody under eighteen; the phases by hours dry; a drink
taken remembered and the shakes reset; three weeks dry and the habit
gone, fifty drinks and a non-drinker has it; the user's tiers by
clean days and the dependency gone past the person's own eighteen to
twenty; the loads per pass; every word plain. By text it holds every
seam: the engine's fluid surfaces in Java, the bridge, the needs
module's drink and its wrap, the controller's drink and its seeking
and its respect for a claim, the age module's drift and its day, the
knowledge surface, the panel, the credits. Its control is the
pre-batch tree.

**Not in this batch.** The Alcoholic's tolerance, poisoning,
headaches and death by withdrawal; drugs as items and their effects
(the county has none, and the mods that add them are not required);
the smokers' dependency being lost (deliberate, [A14]); a hangover.

This governed record is the portable project history for this unit.
