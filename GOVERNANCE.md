| Document | Survivor Awareness Overhaul Governance |
|---|---|
| Version | `3.11.2.0-pre-alpha` |
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
- **Owned source integration.** SAO's canonical services own person identity,
  private knowledge, decisions, Standing, attribution and persistence. Approved
  source integration retains its license, revision and attribution. Installed
  modules may own shared native physical mechanics under DR-053.
- **Source identifiers.** Compatibility adapters retain the exact installed
  API identifiers they invoke. Source names and revisions belong in provenance,
  metadata and attribution; product copy uses the canonical mechanic's name.
- **Local-first.** The project tree is canonical; remotes publish that state.

## Boundaries set by the operator

- **Food source integration.** DR-053 authorizes the requested ordinary food
  preservation and animal-feed mechanics through shared native recipes and
  actions. It supersedes the earlier consumable-production exclusion for those
  concerns. The wider synthesis exclusion retains its original scope.
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
- **Batch scope follows the product.** Each batch names a coherent behavior or
  capability and includes the execution, state, integration, tests and records
  needed to deliver it. Delegate bounded tasks within that batch; agent boundaries
  do not determine the product's chronology. Ancillary work and individual fixes
  remain inside the outcome they support. Closure requires a changed production
  path and evidence appropriate to the stated outcome. A new general simulation
  pass follows meaningful NPC behavior changes and a specific observation question.
- **Project history and forge history are separate things.** The batch
  records, decision registry, findings ledger, and this doc-pack are the
  portable project history; they do not depend on a particular Git host. A
  forge history publishes the canonical tree and carries no project meaning of
  its own - it was reset once, at the C seam, and the pre-seam forge history
  is preserved on the `archive/` branches, untouched.
- **Versioning.** `VERSION` advances with shipped surface change, not with
  every batch.
  An authorized catalog consolidation replays the consolidated units under
  the same tier rules. The 2026-09-19 C consolidation recalculates the source
  coordinate from 5.3.0.1 to 2.7.14.1, both pre-alpha. This is catalog
  arithmetic; it changes neither runtime behavior nor release maturity.
  The former-label crosswalk and Git-blob hashes preserve provenance. Raw
  archive refs stay local under the publishing boundary in NEO.md.
- **Deploys.** Deploys go through `tools/deploy.sh`, which refuses while the
  game holds the jar. The refusal is correct behaviour, not a bug.

## Evidence standard

A finding is admitted to `FINDINGS.md` when it is reproducible from stated
inputs and its verification method is recorded. Log-derived findings state the
log, the counts, and the normalization used - raw counts across sessions of
different length are not comparable and are normalized before being reported
as change.

## Testing and validation

Validation is proportional to the actual changes, their dependencies and the
larger task objective. Before running checks, identify the changed inputs, the
behaviors or contracts they can affect, the uncertainties necessary to establish
the requested outcome, and the existing results that remain applicable. Run the
smallest sufficient set of checks that covers those effects.

A passing result remains valid while the implementation, test, dependencies,
configuration and environment relevant to that result remain unchanged. Preserve
enough provenance to establish that applicability: the result and actual exit
status, the relevant input revisions or hashes, test identity, dependency and
configuration scope, environment, and a retained log or receipt. Reuse applicable
results across subsequent edits, documentation repairs, commits and publication.
A changed commit identifier alone does not invalidate unchanged relevant inputs.

Preserve independently valid successes when another check fails. A failed or
incomplete result is never passing evidence, and a failed full run is never
reported as a passing full suite. Rerun the failed check and checks affected by its
repair. Checks that were skipped, could not run or could not observe the relevant
behavior remain explicitly unverified. Inherited or assumed coverage is
distinguished from verification completed in the task.

Documentation, formatting, version, inventory and other metadata changes receive
their relevant checks. They require runtime tests for demonstrated effects on
runtime inputs, generated runtime artifacts, runtime packaging contracts or other
runtime dependencies.
A documentation count correction receives the count and affected document checks;
it does not restart unrelated simulation tests.

Broaden validation when changes cross shared interfaces, alter fundamental
behavior, reveal a wider defect, or leave a material uncertainty that focused
checks cannot resolve. Use the full suite when the scope or risk warrants it,
relevant dependencies cannot be bounded confidently, or the operator explicitly
requests it. Commit and publication events alone do not justify repeating an
already valid full-suite result. This rule supersedes blanket requirements to run
everything before every commit.

Order validation so cheap checks that can invalidate the candidate precede
expensive checks. Do not duplicate an equivalent check already running against
the same relevant inputs. Preserve an active run's inputs and provenance while
preparing independent work; apply later repairs with checks for their actual
effects.

Once the uncertainties necessary to establish the requested outcome are resolved,
proceed. Additional checks require a specific reason grounded in changed inputs,
an observed failure, uncovered behavior or material risk. Test volume, repeated
clean runs and procedural activity are not completion criteria.

Report briefly what ran, which valid evidence was reused and why it applies,
why any broader run was necessary, and what remains unverified. An existing
instrument's controls remain reusable under the same applicability rule; writing
a new test or framework is warranted only by a concrete gap.

### Process and project maturity

As the project grows, analysis deepens where a change introduces new
interactions or uncertainty. Established knowledge and valid verification reduce
the work required elsewhere. Preserve settled decisions, applicable evidence,
completed checks and justified conclusions across the task. Reopen them when a
relevant change or new finding warrants it.

Create room for deeper work by retiring redundant procedure, consolidating
repeated analysis and carrying forward justified conclusions. The accumulated
size of the project does not automatically become the workload of every change.
Evaluate each proposed check or review by the uncertainty it resolves and its
relevance to the larger objective. Verification builds on previous work so that
increasing complexity remains manageable.

### Existing hook and required CI

`tools/check.sh` is the complete suite. The current local hook in
`tools/pre-commit` invokes it with `--staged`; that flag narrows the initial Lua
file selection and still runs all borders. When that automatic invocation would
repeat applicable evidence beyond the sufficient scoped checks, record the
checks, reuse and reason in the batch record, and use the hook's existing
command-scoped `git commit --no-verify` option. This permits evidence reuse;
it is not a passing gate result. Persistent hook disabling is unnecessary.

The required GitHub `ci-verify` job in
`.github/workflows/ci-verify.yml` currently invokes the full suite for pull
requests and main pushes. Main branch protection requires `ci-verify` and
`codeql-python`. Report that concrete external publication constraint
when it causes additional work; it does not create a local requirement to
repeat the suite. Required remote checks still complete before merge. Their
results retain their own environment and skipped-observation boundaries.

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
