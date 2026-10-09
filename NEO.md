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

A Project Zomboid Build 42 NPC framework. Survivors act on personal observations,
acquired knowledge, ordinary-life priors and defeasible inference. DR-056 ratifies
conceptual associations as a basis for anticipating possibilities and deciding
what to investigate. Inference retains its provenance and uncertainty; particular
local facts require acquisition. Survivors are durable inhabitants of the world
and remain inside the human behavioral envelope regardless of skill.

## Operating conventions

- **One alphanumeric batch sequence.** Work lands in numbered batches with a
  record under `Batches/`. Letter changes mark development eras; they do not
  create separate history systems. The A era closed at `[A29]`, the B era
  closed at `[B52]`. Current C comprises 82 historical development products,
  with all 120 source contributions preserved. The separate 35-contract map
  retains shared ownership and D dependencies. D1 acceptance is CLOSED with
  controlled person-specific reasoning and bounded native recovery; actual
  protected publication has its own receipt. D2 Leisure is closed as the
  integrated recreation product. D3 construction/crafting/repair/utilities is
  next in FIFO; the established separately owned Mousecat sequence retains
  its own product history.
  `BATCH_LOG.md` indexes delivered scope and names the active batch separately.
- **Batch shape.** A batch is a coherent development unit, closed when the
  work is done, not when a message ends. Closing a batch means the record, the
  `BATCH_LOG.md` row, and the `SESSION_STATE.md` advance, in that order, plus
  verification for the behaviors and contracts the batch affects. Existing
  applicable checks and evidence satisfy that verification; a new or changed
  instrument has a control that flips its verdict for the stated reason.
- **Product-sized batches.** Organize batches around a coherent product outcome.
  Agent assignments, individual edits, supporting tools, validation, documentation
  and publication are work inside that outcome. A batch closes when its live
  producer, decision or consumer, persistence where needed, and relevant proof
  establish the promised behavior. Supporting repairs stay with the outcome they
  serve. Preserve existing batch history; a catalogue reorganization needs its
  own explicit operator direction.
  Later improvements link back to the completed product. Continuing project
  goals retain their own outcomes and do not enlarge the active batch's closure
  requirements. Neo reconstructs accumulated verification and keeps the current
  description accurate using `neo-verification-assessment`. The operator plays
  the aggregate build and supplies ordinary feedback.
- **Scope refinement.** Product outcomes cover their whole relevant installed
  native/modded domain and adjacent mechanics. Examples guide discovery;
  substantive scope becomes clearer through implementation. Shared-contract
  catalogue consolidation preserves prior era records and does not prescribe
  future batch size. Keep the active batch on the main line while bounded
  peer assistance is delegated. Neo is a separate project whose available
  tools may be reused; its development backlog is separately owned.
- **Commit shape.** `[D#] source: ...` for implementation, `[D#] reference: ...`
  for records and documents, `[D#] governance: ...` for closings and process,
  `[REPO] ...` for repository mechanics. One batch is one logical unit and
  lands in few commits, not a stream of them. Assistance is not authorship:
  no co-author trailers or tool attribution anywhere in the forge history.
- **Append-only ledgers.** `DECISION_REGISTRY.md`, `FINDINGS.md`, and closed
  batch records are extended, never rewritten.
  The operator-authorized C consolidation of 2026-09-19 follows the A/B
  precedent: that pass produced C1-C50; every former C1-C127 record is
  preserved at local ref `archive/c-era-raw-20260919` and mapped in
  `Batches/FORMER_LABELS.md` and `Batches/C_RECATALOG.json`. Historical ledger
  entries, source comments, immutable evidence and sister citations retain
  their former identifiers. This convention does not authorize rewriting them.
- **C product catalogue and ownership map.** `Batches/C_PRODUCT_CATALOGUE.json`
  partitions the 120 preserved source contributions into 82 coherent historical
  development outcomes under the A/B method. Current records live in
  `Batches/Products/`; current C index and version credit read that generation.
  `Batches/C_SHARED_BOUNDARIES.json` and `Batches/Catalogue/` retain the separate
  35-contract ownership/interface projection for dependencies. The 2026-10-03
  map and PR137 incorrectly characterized that projection as the requested
  product consolidation. The dated corrective event preserves this history.
  Each source retains its exact bytes and its measured implementation,
  verification, publication and remaining work. Historical C labels keep their
  source generation. Product chronology, records, version replay and graph are
  reconciled together; a tier does not close unresolved component obligations.
- **Continuation and consolidation.** Reconcile the current catalogue and the
  complete operator directive before choosing work units or publication scope.
  After a scope correction, record the settled instruction, owning repository
  and required outcome in `SESSION_STATE.md` before delegating again. On
  resumption, compare dated handoffs and proposals with that current directive;
  a later clarification governs an earlier question or proposal.
  State the owning repository and requested action at consequential junctions.
  Historical identifiers provide generation-qualified provenance; current
  products organize development while shared contracts organize dependencies. An era consolidation records local
  application and public reconciliation separately. GitHub receives the current
  catalogue, version replay and provenance through the established additive
  publication procedure; retained local-only implementation stays explicit.
  A question's wording does not replace a clarified operator instruction.
- **Repurposed sources (DR-058).** Every mod and mechanic mentioned by the
  operator is source material for integration into the project's implementation
  and art. The delivered package carries the needed runtime, definitions and
  assets with source provenance and attribution. Existing API-only paths retain
  their measured evidence while incorporation is completed. Runtime and package
  ownership, source conflicts, player/NPC effects and save continuity are part
  of the integration outcome. D2 through D6 keep their established FIFO and
  substantive domains; peer communication proceeds alongside the active batch.
- **Verified APIs only.** Ground truth is the installed game
  (`projectzomboid.jar`, the shipped `media/lua` and `media/scripts` trees).
  Never assert engine behavior from memory; an unsupported statement is a
  hypothesis and is labelled one.
- **Verify the tool before trusting its output.** An analysis script is not
  evidence until its own correctness is established against a known-bad
  control.
- **Testing and validation.** Follow `GOVERNANCE.md`'s standing testing
  and validation rule. Identify changed inputs, affected behaviors and
  contracts, and reusable evidence before choosing the smallest sufficient
  checks. Preserve applicable successes across repairs, commits and
  publication; broaden for affected interfaces, fundamental behavior,
  wider defects, material uncertainty or an explicit operator request.
  `tools/check.sh` is the full suite, selected for those reasons.
  Scale analysis to new interactions and uncertainty as the project grows;
  preserve settled decisions and justified conclusions, and consolidate
  repeated work. Each check or review resolves a relevant uncertainty.
  Read the actual verdict and exit status. Skipped or unobservable
  behavior remains unverified; Border 128 holds the absent-game boundary.
  The governance rule states how to avoid redundant local hook runs and
  carries the same affected-contract selection into actual GitHub workflows
  and distinguishes product requirements from advisory repository maintenance.
- **Publishing.** A closed batch reaches `origin/main` through a branch and a
  pull request, merged by you. `main` is protected and refuses a direct push.
  The shape is CAO's, read off its merged pull requests:

  | Part | Shape |
  |---|---|
  | branch | `neo/d<n>-<short-slug>`, off the batch's own name |
  | commit | ONE, squashed, carrying the tree at the batch's close |
  | title | `[D<n>] <the batch's name from BATCH_LOG.md>` |
  | body | `.github/pull_request_template.md`, filled in - not a rationale pasted in its place |
  | merge | squash, delete the branch, by you and not left for the operator |

  Never push a branch that carries local history: the pre-seam trees hold
  material the operator had removed, and one squashed commit on
  `origin/main` is the only thing that goes out. Check
  `git rev-list --count origin/main..HEAD` at session start and say so if
  the public copy has fallen behind.
- **Operator-mediated.** Arbitrary consequential choices are surfaced.
  Obvious defaults are taken and stated.
- **Say what is not known.** An honest gap is worth more than a confident
  guess, and a guess presented as a finding is a defect.
- **Visible simulation delivery.** An authorized live observation includes
  propagating the candidate to the operator's open Mousecat. The session launcher
  selects its exact live source once through the installed desktop and records
  the outcome. Verify the current candidate, source binding and advancing frames
  before reporting it visible. App changes include installed activation and
  `installed:check`; repository edits and previews alone do not establish delivery.
  Preserve an explicit headless or source-only request. A missing client or failed
  handoff is reported as unavailable and does not become a visibility success.
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

Rewritten plainly at `[C24]` on the operator's direction; the content
is unchanged. They had been written in the register the writing rule
above bans - two of them as mirrored turns - and a law that breaks the
rule it sits beside teaches every session to break it too.

DR-056 clarifies the first law's knowledge basis: personal acquisition and
defeasible conceptual inference retain distinct authority.

1. A survivor acts on person-private observations, acquired knowledge,
   ordinary-life priors and defeasible conceptual inference (DR-056).
   General associations support expectations and inquiry; they do not
   fabricate observed local rooms, coordinates, contents or permission.
   New evidence can refine or contradict an expectation. Ignoring relevant
   acquired evidence or treating an inference as an observed fact is a
   decision-model defect.
2. Low skill changes how well somebody does a thing, never whether
   they do something no person would do. Skill moves latency,
   precision and breadth inside the human envelope and does not widen
   it.
3. The person is the record. The engine character is a body the record
   is loaded into and is never what persists.
4. Execution decides how an action is carried out. Whether it happens
   at all is decided before Execution is called.
