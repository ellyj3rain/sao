| Document | Survivor Awareness Overhaul - instruction surface |
|---|---|
| Author | ellyj3rain |
| Repository | `NEO.md` |
| Status | CANONICAL - the first file any model in this repository reads. |

# Instruction surface

`CLAUDE.md` and `AGENTS.md` are autoload shims that point here.

Host identity is a vantage, not authority. The operator (ellyj3rain) is the
design authority and the judge of how the game looks and plays. Code-level
verification never settles that question.

Read `CORE.md` for identity and composition, `ARCHITECTURE.md` for the
ratified shape, `GOVERNANCE.md` for operating discipline, and
`SESSION_STATE.md` for where the work stands.

## What this repository is

A Project Zomboid Build 42 NPC framework. Survivors act on what they have
actually perceived, are durable inhabitants of the world rather than effects
around the player, and remain inside the human behavioral envelope regardless
of skill.

## Operating conventions

- **One alphanumeric batch sequence.** Work lands in numbered batches with a
  record under `Batches/`. Letter changes mark development eras; they do not
  create separate history systems. The A era closed at `[A29]`, the B era
  closed at `[B52]`, and the chronology continues in the C era: `C1` is the
  next development batch.
- **Batch shape.** A batch is a coherent development unit, closed when the
  work is done, not when a message ends. Closing a batch means the record, the
  `BATCH_LOG.md` row, and the `SESSION_STATE.md` advance, in that order, plus
  a border for the class the batch found and a control that flips the verdict
  for the stated reason.
- **Commit shape.** `[C#] source: ...` for implementation, `[C#] reference: ...`
  for records and documents, `[C#] governance: ...` for closings and process,
  `[REPO] ...` for repository mechanics. One batch is one logical unit and
  lands in few commits, not a stream of them. Assistance is not authorship:
  no co-author trailers or tool attribution anywhere in the forge history.
- **Append-only ledgers.** `DECISION_REGISTRY.md`, `FINDINGS.md`, and closed
  batch records are extended, never rewritten.
- **Verified APIs only.** Ground truth is the installed game
  (`projectzomboid.jar`, the shipped `media/lua` and `media/scripts` trees).
  Never assert engine behavior from memory; an unsupported statement is a
  hypothesis and is labelled one.
- **Verify the tool before trusting its output.** An analysis script is not
  evidence until its own correctness is established against a known-bad
  control.
- **The gate.** `tools/check.sh` runs every border; the pre-commit hook runs
  it; CI runs it on every push. Run it before every commit and read the whole
  verdict, including the exit code.
- **Operator-mediated.** Arbitrary consequential choices are surfaced.
  Obvious defaults are taken and stated.
- **Say what is not known.** An honest gap is worth more than a confident
  guess, and a guess presented as a finding is a defect.

## Laws

1. No omniscience, no oblivion. Both are failures of the decision model.
2. Low skill never licenses behavior outside the human envelope.
3. Identity is a record. The engine object is a temporary body.
4. Execution owns *how*, never *whether*.
