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
  closed at `[B52]`, and the chronology continues in the C era; the tip is
  `BATCH_LOG.md`'s last row.
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
  verdict, including the exit code. A border that reads the installed game
  reports SKIPPED and returns 0 where the game is absent, because CI has no
  game and a machine without one has no defect; Border 128 holds that.
- **Publishing (operator ruling, 2026-09-08; corrected at `[C59]`).** A
  closed batch reaches `origin/main` as ONE squashed commit through a BRANCH
  AND A PULL REQUEST, merged once its checks pass - never by pushing to
  `main`. This is CAO's model and was always the standard here; `[C56]` to
  `[C58]` were pushed straight to `main` because nothing stopped them, and
  `main` is protected now the way CAO's is (pull request required, `ci-verify`
  and `codeql-python` required and strict, admins included, linear history, no
  force pushes, no deletions). The public repository never receives branch
  history; the local tree keeps it all. Open the pull request, wait for the
  checks, merge it, and do not leave it open for the operator to chase. Check
  `git rev-list --count origin/main..HEAD` at session start and say so if the
  public copy has fallen behind.
- **Operator-mediated.** Arbitrary consequential choices are surfaced.
  Obvious defaults are taken and stated.
- **Say what is not known.** An honest gap is worth more than a confident
  guess, and a guess presented as a finding is a defect.
- **Write plainly (DR-018, widened 2026-08-30 and 2026-09-06).** State
  what a thing is or does in ordinary words and stop. This covers every
  word the operator reads: batch names, section headings, ruling names,
  border names, commit messages, code comments, ledger prose, question
  labels and chat replies - not only player-facing copy. Banned: titles
  with a turn in them ("X, not Y"; mirrored or chiastic phrases),
  possessive-abstract names ("the county's own word"),
  noun-comma-participle names ("the ground, looked at"), present-tense
  narration of what code does as if it were a scene, and metaphor
  standing in for information. A title is a description. Do not attempt
  colour on your own judgement - colour is the operator's to write or
  ratify. Survivor speech in-game is exempt; it is a person talking.

## Laws

Rewritten plainly at `[C56]` on the operator's direction; the content
is unchanged. They had been written in the register the writing rule
above bans - two of them as mirrored turns - and a law that breaks the
rule it sits beside teaches every session to break it too.

1. A survivor acts on what they have actually perceived. Knowing what
   they could not have seen is a defect, and so is failing to react to
   what they did see. Both are faults in the decision model rather
   than in the numbers.
2. Low skill changes how well somebody does a thing, never whether
   they do something no person would do. Skill moves latency,
   precision and breadth inside the human envelope and does not widen
   it.
3. The person is the record. The engine character is a body the record
   is loaded into and is never what persists.
4. Execution decides how an action is carried out. Whether it happens
   at all is decided before Execution is called.
