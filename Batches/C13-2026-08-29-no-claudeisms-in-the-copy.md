# C13 - No Claude-isms in the copy

| Field | Record |
|---|---|
| Batch | `C13` |
| Date | 2026-08-29 |
| Name | No Claude-isms in the copy |
| Status | Closed append-only batch - play verification pending (no play receipt) |
| Threads | [`T-030`](THREADS.md#t-030) |

## Record

The operator's second mid-play correction (DR-018, quoted there):
"'The road never quickens' - that is the worst... you do this pretty
much every time you're creating copy or front end... it's a
Claude-ism." And the refinement, in the same breath: "I don't wanna
say it has to be boring. No. You're just bad at making things
interesting." [C12] had fixed WHAT the surface said (no engine
language) and shipped it in the assistant's house register - present
tense narration, evocative-verb miniatures, metaphor standing where
information should be. The register itself was the defect.

**The rewrite.** Every label, value, and tooltip on the sandbox
surface now states what the thing does, in ordinary words: "Enable
survivors", "Set the population manually", "Newcomer arrival
speed-up" with values None through Very high, "Off-screen danger
multiplier". The Ledger's "N between death and the ground" became
"N corpse conversion(s) pending". Survivor speech is untouched: a
person talking is diegetic voice, not UI copy, and the [C5] direction
stands unless the operator says otherwise.

**Plain is the baseline, not the law.** Per the operator's
refinement, this is not a rule that copy must be dull - it is a rule
that the assistant does not attempt color on its own judgment. Copy
with personality is written or ratified by the operator; until then,
plain ships, because better dull than bad.

**The mechanism.** No regex recognizes bad prose, so Border 92
(`tools/copy_ratified_test.py`) holds what a gate can hold: the
shipped copy matches a verbatim declaration, string for string, and
anything new or reworded fails the gate until re-declared - which is
the deliberate act of putting copy in front of the operator's eyes.
The two struck phrases stay struck as literal tripwires. The copy
shipped in this batch is itself the assistant's plain draft
AWAITING those eyes: the operator redlines it by editing the strings
and the declaration together, and the border makes that a conscious,
paired act. Control: the pre-[C13] surface, which fails forty ways.

This governed record is the portable project history for this unit.
