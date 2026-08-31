| Document | Survivor Awareness Overhaul Governance |
|---|---|
| Version | `0.6.0.0-pre-alpha` |
| Design authority | ellyj3rain |
| Repository | `GOVERNANCE.md` |
| Status | ACTIVE - operating discipline for this repository. |

# Survivor Awareness Overhaul - governance

Operating discipline for this repository. `NEO.md` is the instruction surface
and states the batch and commit shape; this file states the judgement rules.
`CLAUDE.md` and `AGENTS.md` are autoload shims pointing at `NEO.md`.

The operator (ellyj3rain) is the design authority and the judge of how the
game looks and plays. Code-level verification never settles that question.

`README.md` is the human entry point. The canonical doc-pack is `MEMORY.md`,
`CORE.md`, `ARCHITECTURE.md`, `GOVERNANCE.md`, `DECISION_REGISTRY.md`,
`FINDINGS.md`, `BATCH_LOG.md`, `ROADMAP.md`, `SESSION_STATE.md`, `VERSION`.
Batch records live under `Batches/` in one alphanumeric sequence. `MEMORY.md`
indexes every root document and states which surfaces are canonical,
regulatory, append-only, or historical.

## Ground rules

- **Verified APIs only.** Ground truth is the installed game: the decompiled
  `projectzomboid.jar` and the shipped `media/lua` + `media/scripts` trees.
  Never assert engine behavior from memory. A statement without a file and
  line behind it is a hypothesis and is labelled one.
- **Tools are verified before their output is trusted.** An analysis script is
  not evidence until its own correctness is checked. Report the corrected
  figure, and say that it was corrected.
- **The engine's own seams.** `setNpc`, `AIComponent`, spawn-region tables,
  normal timed actions, normal inventory paths. Reach past a seam only when
  none exists, and record why in `DECISION_REGISTRY.md`.
- **No omniscience, no oblivion.** Symmetric failures. A fix that widens what
  a survivor can see in order to improve a decision is a defect in the
  decision model. A fix that forbids a capability outright to prevent misuse
  is the same defect mirrored.
- **Low skill stays inside the human envelope.** Incompetence is slow,
  imprecise, wasteful, badly coordinated. Incompetence is never an action a
  person would not take.
- **Declarations are promises.** Settings copy and in-game text match shipped
  behavior exactly.
- **Concepts are not copy.** Design terminology directs the work; it reaches
  the UI only when supplied or approved as player-facing text. No free-text or
  dictated speech - `SPEECH.md` is direction only.
- **Bespoke implementation.** Everything in this tree is written for this
  project. Reference reading of other mods is fine; copying is not.
- **Never name a mod in code.** `mod.info` metadata and `CREDITS.md` are
  documentation and exempt.
- **Local-first.** The project tree is canonical; remotes publish that state.

## Boundaries set by the operator

- **Consumable production and synthesis mechanics are out of scope**, by
  verbatim direction: that area is a little unsafe to mess with, and the work
  must not trip the surrounding guide rails. Wiring is permissible where a
  feature needs it; the mechanics of creation are not.
- **Two live saves survive every deploy** - one fresh in Irvington, one with
  companions. `save_compat_test` guards this and runs in the gate.
- **Never orbit the operator's play.** No test requests, no session polling.
  If a deploy refuses because the game is running, one factual line at most.

## Execution discipline

- **Operator-mediated.** Substantive direction comes from the operator. Where
  a choice is genuinely arbitrary and consequential it is surfaced rather than
  assumed; where a default is obvious it is taken and stated. Defaults are
  grounded in what the reality was - a rate that stands for a real population
  is researched, and its confidence recorded.
- **Every problem in a message is in scope.** Two complaints that look similar
  are usually two defects. Fix the whole population, not the named instance;
  if something is blocked, finish everything else and say plainly what was
  left and why. Do not narrow silently. Do not end a working turn waiting.
- **A representative example is not the design seed.** When the operator
  illustrates a principle with a case, build the principle, not the case.
- **Batches.** Work lands in numbered batches, one alphanumeric sequence,
  recorded in `BATCH_LOG.md` with a record under `Batches/`. The A era closed
  at `[A29]`, the B era closed at `[B52]`, and the C era opens at `C1`.
  Batch shape and commit shape are defined in `NEO.md`.
- **Project history and forge history are separate things.** The batch
  records, decision registry, findings ledger, and this doc-pack are the
  portable project history; they do not depend on a particular Git host. A
  forge history publishes the canonical tree and carries no project meaning of
  its own - it was reset once, at the C seam, and the pre-seam forge history
  is preserved on the `archive/` branches, untouched.
- **Versioning.** `VERSION` advances with shipped surface change, not with
  every batch.
- **Deploys.** Deploys go through `tools/deploy.sh`, which refuses while the
  game holds the jar. The refusal is correct behaviour, not a bug.

## Evidence standard

A finding is admitted to `FINDINGS.md` when it is reproducible from stated
inputs and its verification method is recorded. Log-derived findings state the
log, the counts, and the normalization used - raw counts across sessions of
different length are not comparable and are normalized before being reported
as change.

## Analysis discipline

The evidence standard governs when a finding is admitted. This governs when an
instrument's result counts as evidence at all. Every clause below was paid
for; the citations are the receipts.

- **A clean result is worthless without a control.** Validate an instrument
  against a case already known to be bad before believing it about a case
  that is not ([B32], [B32]).
- **A control against one shape does not cover a class.** [B32]'s zero was
  true for the shape it modelled and false for the class; [B32] then found a
  fourth instance the detector could never have seen.
- **Distinguish "found nothing" from "cannot see it".** What an instrument
  cannot reach is reported UNCHECKED with its reason, never omitted ([B31]).
- **An impossible number is the instrument confessing; a plausible one is the
  danger.** [B32]'s audit touched zero code files while rewriting one; [B32]
  reported 60% of between-time slots as "nothing" against a law whose content
  is that it is never nothing.
- **Hand-check a tool you have just written.** Every false positive in the B
  era died at a hand-check and none died any other way ([B31], [B32]).
- **Where the question is about the engine, ask the engine.** Not memory, and
  not the mod's own comments ([B26], [B31], [B32]).
- **Do not ship a noisy instrument.** A border that cries wolf gets ignored,
  and one that manufactures a finding sends someone to fix correct code
  ([B31], [B31]). Where an instrument cannot be made precise it is recorded as
  a method and not gated - [B32] and [B32] both declined to ship. The count of
  borders is not a target.
- **Enumerate the idioms before writing the pattern.** A sweep matches one way
  of writing a thing and the code uses two. Grep the identifier bare, count
  the hits, and if the pattern finds fewer, the pattern is the thing that is
  wrong ([B35], [B35], [B36]).
- **A control that cannot fail is not a control.** Assert that the mutation
  landed, then assert that the verdict flipped; landing alone proves nothing
  ([B34], [B36]).
- **A tool that cannot find its own motivating case is measuring something
  else.** Put the known defect back and require the tool to name it ([B35]).
- **Do not write the conclusion into the command.** A shell label written
  before the output exists survives being wrong ([B35]).
- **A mirror that re-derives the rule cannot fail on the rule.** The mirrors
  model shipped logic in Python, so mutating the Lua does not move them. A
  mirror that models a rule must also demand the rule's own expression be
  present, and its control mutates the Lua and watches the verdict flip
  ([B37], [B38]).
- **Prose is not code.** An identifier in the comment explaining a call
  satisfied the check that the call was still there. Search for the call form,
  not the name ([B37], [B35]).
