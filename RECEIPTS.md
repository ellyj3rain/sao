| Document | Survivor Awareness Overhaul Play Receipts |
|---|---|
| Version | `3.11.0.0-pre-alpha` |
| Author | ellyj3rain |
| Repository | `RECEIPTS.md` |
| Status | CANONICAL, APPEND-ONLY - what play has actually settled, from R-001. |

# Play receipts

The borders establish that the code says what a record claims; only
play establishes that it happens in the world. This ledger records
what play HAS established, one observation at a time, when it
happens.

The rule it replaces was tautological (DR-025): the doc-pack said
"nothing has a play receipt" and no mechanism existed by which the
operator's reports could change that - so the repository claimed
perpetual untestedness even in the same hour the operator was
reporting live findings against it. A receipt is not a "the repo is
tested" stamp, and there will never be one contiguous session that
uncovers every bug; that is not how testing works. A receipt is one
of these, recorded as it lands:

- a surface WITNESSED doing what its record claims;
- a defect EXPOSED in play - which is also proof the surface was
  exercised, and is a receipt for everything that had to work to
  reach it;
- an observation still OPEN - seen, unexplained, on the record so it
  cannot silently evaporate.

A batch stays open until receipts touch its surfaces, and a fix made
from a receipt is pending until re-witnessed. Both states are normal;
neither is "nothing has ever been tested."

---

## R-001 - The first sessions: the county lives, and its movement was broken

- **Date / build**: 2026-08-29, `1.11.2.0-pre-alpha` deployed live
  (two sessions, the second after a death).
- **Observed** (operator): a populated neighborhood at spawn,
  survivors visibly panicking - which the operator found striking
  at first - then clustered around a house and frozen. Later: they
  killed a human and were eating him.
- **Settles as exercised and working**: genesis at world start (the
  spawn-town draw put a crowd exactly where people lived); pacing
  (79 population events in one session); materialization via the
  Java shell with `dressed=true model=true`; the controller ticking
  9 live agents; flight triggering from believed threats; company
  formation and parting ("kept company on the road", "part ways
  friendly") running throughout.
- **Exposed**: F-049 - the frozen crowd was a route-ordering defect
  (292 FLEE-IDLE flips in one session), fixed in [C18]; F-048 - 276
  place-reading exceptions and 2 history-generation exceptions,
  fixed/guarded in [C18]. Both fixes deployed in `1.11.2.1-pre-alpha`
  and PENDING re-witness.
- **Still open**: the kill-and-eat scene is unattributed (eating a
  body is zombie behavior; the figures were clothed and crouched in
  the corpse-loot posture - the log did not settle which).

## R-002 - The unexplained person

- **Date / build**: 2026-08-29, `1.11.2.0-pre-alpha`.
- **Observed** (operator): a survivor with no clothes, ignored by
  zombies, not hittable, unresponsive to talk and follow clicks -
  in the operator's assessment not really a figure on the map at
  all.
  Seen across a death and reload; a second naked figure appeared
  near the first.
- **Settles**: nothing yet - this is an OPEN observation. Three
  explanations were advanced during the session and all three died
  under checking (belief-table aliasing; corpse-stripping by the
  loot path; "they are the neighbour framework's people", which
  rested on a miscount of the tallying logger).
- **What would settle it**: the inspect panel (J) on such a body -
  it says whether the county knows the person at all - or the
  console's identity lines for the id under the cursor.

## R-003 - The screenshot of the ungated field

- **Date / build**: 2026-08-29, `1.12.0.3-pre-alpha`, options screen
  before any world (the log buffer never flushes at the menu, so the
  screenshot is the whole record - and it is enough).
- **Observed** (operator): on the county's sandbox page, the
  manual-population switch UNCHECKED while Population (manual) sat
  focused, editable, with 45445 typed into it and the label lit in
  vanilla's non-default yellow.
- **Settles**: the [C22] manual-field gating was DEAD at runtime on a
  byte-verified deploy - the operator's report that it did not
  work was exactly right, twice, on two builds. The yellow label is the
  second, independent proof: vanilla's own prerender coloring ran
  unopposed, so no wrap was ever attached. Cause found and named:
  the hook's anchor class is a per-file local in vanilla, the guard
  read nil and skipped silently (F-053). Fixed in [C24] by attaching
  through `SandboxOptionsScreen:create` onto the panel instance,
  with the cannot-attach paths made loud.
- **Still open**: the [C24] gating itself now needs its own witness -
  locked grey fields with switches off, waking on the click - and
  the [C23] dial deletion needs eyes on the Knox Survivors page
  (that hook's anchor was verified global, so it should have been
  live on `1.12.0.3` already).

## R-004 - The locks hold and the dials are gone

- **Date / build**: 2026-08-29, `1.12.0.4-pre-alpha` (the [C24]
  tip), options screen.
- **Observed** (operator): the fields lock correctly now, and the
  neighbour's dials are gone.
- **Settles**: both of R-003's open items, at the screen where the
  defect was photographed. The [C22]/[C24] manual-field gating is
  WITNESSED WORKING - locked until their switches are on - which
  also confirms the [C24] diagnosis end to end: same code idea, dead
  anchor before, real global now. And the [C23] deletion of the
  neighbour's two overridden population dials is WITNESSED ABSENT
  from his page, on the first build anyone actually looked.
- **Still open**: nothing from this thread. The absorption itself,
  the in-world `[SAO][SANDBOX]`/`[SAO][ABSORB]` log lines, and the
  [C25] knowledge-first behavior all still await a world.

## R-005 - Talking does far less than advertised

- **Date / build**: 2026-08-29, `1.12.0.4-pre-alpha`, in a world.
- **Observed** (operator): talking still does nothing worth the
  name - far less than advertised, and the advertisement itself is
  not what the system is supposed to be.
- **Settles**: the talk surface was structurally silent, and the
  code agrees with the operator on every count. Three mechanisms,
  found by reading the path the click takes: the WHOLE person was
  gated behind trust 0.3 (fifteen clicks and fifteen game-hours
  away, +0.02 per hourly talk), so every stranger answered from
  three stock lines; the stock-line reply itself was eaten by the
  murmur cooldown and the repeat-line guard in the voice module -
  a reply to a direct click, suppressed like a volunteered murmur;
  and the talk cooldown's brush-off went to the log file, so a
  second click looked like nothing at all ([B33]'s class, with a
  timestamp). Fixed in [C26]: answers bypass the murmur guards, the
  brush-off is spoken, and smalltalk/warnings/identity flow at any
  trust - lessons, pacts, and what a body admits stay earned, which
  is what the module's own advertisement always said.
- **Still open**: whether the opened surface FEELS like talking in
  play - and the operator's larger ruling that the interaction
  breadth itself is far from adequately modeled (DR-028's recorded
  direction).

## R-006 - Two naked strangers in the operator's kitchen

- **Date / build**: 2026-08-29, `1.12.0.4-pre-alpha`, screenshot +
  console.
- **Observed** (operator): two naked people spawned right next to
  them, inside a house that is theirs. Screenshot shows two
  unclothed figures and a clothed one at the kitchen sink.
- **Console evidence**: `sao-151`, `sao-152` materialized on the
  SAME square 10768,10268 (with `sao-153` a tile away, and `sao-30`
  on that exact square earlier) - all fresh-path, all logged
  `dressed=true model=true`; zero `awakens:` lines (no hibernation
  packs involved); `[SAO][ABSORB] 0 of his people absorbed at start`
  (fresh world - the naked pair are the county's own, NOT the
  neighbour's).
- **Settles**: R-002's naked class reproduces at SPAWN on the fresh
  path - `dressInRandomOutfit()` can return without throwing and
  dress NOTHING, and the materialize log believed the call instead
  of the body (F-054). Also settled: genesis put multiple homes on
  one square inside what is now the player's claimed house, and no
  law stopped the wake (DR-028's first half, ruled from this
  witness). Both fixed in [C26]: worn-count verification with retry
  and named fallback, loud when abnormal; foreign-claim wake
  relocation with re-homing; one body per square.
- **Still open**: whether R-002's unhittable/ignored symptoms were
  the same defect or a second one riding the same naked body -
  the J-panel on such a person still settles that.


Peer review and delivery correction: The additive correction receipt 22508b339d344a3612a5256b58ae7d5aee3370c1e30190c1b95cc91e68ec0b86 at _scratch/d1-finish/actual-close-01/peer-delivery-correction-01/receipt.json supersedes the packet exclusion declaration for stdlib.lua: root inspection confirms four exact nested copies. Archives remain immutable and separate because manifest/request paths collide. Sesame verifies1,942 outer/186 nested payloads, both PNGs and12 acceptance references; missing2 historical seals/4 requests/20 owned-source versions limit historical replay. Frame555 accepts queued preparation with native action pending; later seq3–11 active acknowledgments and conservative seq4–11 physiology establish ongoing recovery. Raw datasetAdmission remains unreviewed, behavioralVerdict null, and ownership/native flags source-mediated. Image inspection is1.989 seconds after capture642, a near-time association without independent visual actor identification. Pico subsequently resumed Windows execution; unresolved hem/material refinement, seven comparison-image sharing rejections and the supported Windows os.setxattr reference-materialization failure retain separate owner obligations. No alternate disclosure or transfer is performed.


CI integration correction — PR138, 2026-10-05. The first required CI run37360846215 failed and remains failed; publicationcommit0a8cae01 is retained at refs/heads/neo/d1-publication-before-ci-01. Corrective composition receipt 4cfd4c775ec44268fbc6b8fb4997d8f360dc7d28fa3ea83bc1ee6341ea9969bd at _scratch/d1-finish/actual-close-01/ci-final-addendum-01/receipt.json pins the actual repairs, source versions and failed log. Delivered D1 now retains its era, compression predecessor and declared dependencies in the graph;26 graph controls cover actual CLOSED and detached OPEN records. The current census is29 A-batches,52 B-batches,285 gated test files,16 other Python entry points,301 scripts and labels through233. The two obsolete non-Lua exemptions are removed; actual receipts/replay explicitly refuse on removed Lua with non-Lua owners retained. Metadata proof7d2f673 preserves those controls.

Field audit stamps personalMemoryAdmission/recoveryPoseExit receive persistence/private observation credit through the actual Identity registry and StudyWorld bounded record projection, with consumer-removal controls; no decision effect is invented. Three unreachable Voice event definitions (studies/confront/thanks) and stale confront urgency are removed, with exact before bytes and all remaining Voice content preserved. No artificial speech callers are added; external-call compatibility is unmeasured. Four removed/replaced Controller comparisons (flee-vector epsilon, two unsolicited shared-rest bounds, guessed nearby gift-giver distance) reduce the bare census13 to9; they are not four newly named radii. Only the obsolete Controller14/SCANNER_SIGHT_RANGE allowance is removed. Reach/field proof6e36243 passes the four readers and16 initial plus15 final controls.

Two genuine large-input recursion risks are corrected only inside Cognition.appraiseConflict serialization and Controller.leisureGroundOffers. Both reuse Perception's existing iterative merge pattern, retaining all entries, comparators and candidate selection. Current Cognition SHA50cfe4647ee986e8bd90f70762cfe8c35a394ccb36f7f96b86ca3fe5de4df103 and Controller SHA0a28899738520f99469763e0c14500c7810a5bca1f1883ef1dd02b81454447d5 supersede whole-file current-source labels earlier in this record. Scoped proof54e40d8f passes45 installed checks,18 negative controls and4 argument controls, including32768 reverse/stable inputs,32700 invalid effects refused,51200 leisure offers with late nearest16 preserved, ordinary-order equivalence and a restored recursive-engine stack-overflow fault. The existing85-check conflict baseline passes. All190 other top-level functions and nine exact recovery-owner ranges remain byte-identical; the native recovery observation and315/23 proof retain their original raw source pins and are reused only at those unchanged owner seams. Earlier102 loaded checks and portable152/335 source-profile proof retain their recorded source versions; no new whole-file profile qualification or game run is claimed. Sort/gmatch/pressure audits now pass52 sort sites/45 lists,31 pattern sites with12 installed-engine literal patterns and one exact registered dynamic split, and the source-owned10 pressure labels with2 behavioral-reader labels.

The visibleGroundSources Java bridge lacked the promised outer exception guard. Only that bridge method now catches/logs Throwable and returns null while preserving normal delegation and invalid-input refusal. Exact-method compiled probes pass16 guarded and13 restored-missing-net checks, including Exception and Error escape rejection; bridge-safety passes. One justified official build at2.12.0.0-pre-alpha compares49 sources,48 unchanged from native, and changes only the bridge class relative to the prior closure JAR;116 other members remain identical. Both final JARs share SHA5f6d142c95451e717e8f9aaff5ade6e5fb40da719aeaf16ba537b912b7f4d461. Build receipt81986aab explicitly claims compilation, not native replay. Final affected metadata, DOCX and graph checks and required remote ci-verify/codeql-python precede the protected merge. No additional delivered version is earned by correcting the unmerged D1 candidate.

Peer continuity correction: Pico supplied the exact Windows Library helper path/traceback at message1791227316.128429; the earlier waiting-for-diagnostics report is superseded. The supported helper calls os.setxattr at line64 on Windows Python3.14.6. Platform compatibility is under inspection with required identity metadata preserved. Pico subsequently reports modeling resumed with references already available locally; this supersedes the earlier reference-blocked state. Reader/full-review/comparison-image sharing approvals remain distinct owner obligations. The delivered recovery archives and their additive stdlib/queued-preparation/replay-gap/image/dataset correction remain immutable. FIFO through D6, separate Mousecat A28 ownership, sibling responsibilities and cancelled plugin publication remain unchanged.


Operator scope correction, 2026-10-05: D1 is the main execution line through its
actual protected publication. Proactive Pico/Sesame help proceeds through bounded
delegation and preserves their existing ownership. Neo is a separate project
whose existing tools/data may be reused; unavailable tools do not create a Neo
development obligation here. SAO/ZAO/Speakeasy/Post-Latent responsibilities retain
their real project owners. Future outcome labels describe substantive domains:
D2 leisure; D3 construction and repair; D4 food across the whole installed native
and modded repertoire, including dry aging and other preservation; D5 comprehensive
animal care after species/affordance assessment, including dogs when actually
added; D6 education and learning with literal K-through-college source material
and evidenced understanding, retention and transfer. Named examples are scope
entry points, and adjacent installed mechanics belong in their coherent outcome.
Product-sized batches develop their exact boundaries through implementation;
contract catalogue counts do not define or erase product history. Existing era
records, compression events, crosswalks and Mousecat continuity remain preserved.
This clarification changes active scope records without new runtime, completed
future-batch, corpus, animal-source or version credit. Earlier broader Neo
assignments and the narrow cooler-only D4 description are superseded by this
operator clarification. Cancelled plugin publication remains cancelled.


C-era consolidation correction, 2026-10-05: The operator clarified that prior
A200-to-A29 and B193-to-B52 consolidations organized coherent development batches.
The requested C120 consolidation was interpreted as a 35-unit ownership-contract
map, which is a different operation. That useful map and its immutable source
records remain retained; it is not credited as completion of the requested
product-batch consolidation. The operator now directs correcting C immediately
and concurrently with finishing D1. Bounded delegation owns the complete source-
based C product grouping and its reader/version/chronology integration; the main
execution line continues D1 publication. No arbitrary target count, further
compression of A/B, invented missing historical source or new runtime credit is
authorized by this correction. Actual historical source availability is audited
and any gap is stated rather than inferred away. Canonical product catalogue,
version replay, records and graph are reconciled from the evidenced grouping.
Existing D1 behavioral proof remains applicable while those runtime inputs remain
unchanged. Earlier statements describing the 35-contract map as the completed
operator-requested era consolidation are superseded by this clarification.


## C product correction and D1 publication integration,2026-10-05

The operator-requested C era consolidation uses82 historical development products
partitioning120 retained sources once. The35-contract map remains an ownership
projection. PR137 merge50c8994d7195bbb56117eea562f17e8c84fb7f91 published the
wrong interpretation; the corrective event preserves the public statement and
reconciles product index/version/graph without rewriting that history. D1â€™s
controlled reasoning, retained personal memory and bounded native recovery proof
remain separately measured. CI source repairs address actual absent-engine and
portable test failures; an explicit absent-engine skip does not prove gameplay.
Protected publication receives credit only from the exact remote check/merge
receipt. Prior evidence and failed verdicts remain unchanged.


## Final C product and CI portability qualification,2026-10-05

The final82-product partition passes7,409 source comparisons and9 refusal
controls, preserving all120 source records and the separate35 shared ownership
contracts. Guarded additive landing creates87 new records/manifests/provenance
outputs and verifies160 immutable source/contract/history inputs. Catalogue
proof passes62 controls; product graph proof passes30 tests and five source
mutants fail at their named witnesses. Actual current replay contains164 units
(29A,52B,82C,1D), deriving C82 at its retained predecessor coordinate and D1
at `3.8.0.0-pre-alpha`; an earlier166-row narrative is superseded by this actual164-unit replay.

Required CI at046c0f9752db28a2617f29d52939782319ac549a genuinely failed.
The source repairs add explicit owned-input preflight to38 installed-engine
drivers and preserve portable checks;45 registered CLI invocations qualify
absence behavior, while Border128 verifies115/115 explicit absent-game skips.
Portable launcher/layout/renderer/delivery tests retain real mocked execution
on platforms without Windows subprocess fields. Installed admission returns
zero; a malformed existing engine JAR actually fails compilation, rather than
skipping. Root restores the exact public attribution guard with9 controls and
qualifies the unchanged frozen audit row against the old matcher. Three stale
portable instruments retain native-sound clock freshness, independently owned
trait registration versus animation dependency, and current food-source mutation.
All three pass source-absent and installed-VM checks. No new gameplay is claimed.

The official product-coordinate build changes only two declared class-version
constants relative to the previous D1 bridge build;115 members are unchanged.
Both current JARs are SHAb60f748043ecfde309917f16083197d44f302ac0a66b53e5af7e615fc823efb2.
Packaging receiptbecd56d837f8c6dc527cc0a8a67b801ea59d18b60b56b56e5414fee0ae9e817e
retains49 Java-source pins and parsed constant-pool equivalence. The prior
bridge build receipt retains its actual historical coordinate. New remote CI
and CodeQL results must pass on the exact amended public head before the
authorized protected squash merge; no preceding failed/cancelled run is relabeled.


Corrective transformation graph qualification,2026-10-05: the new
`event:product-consolidation:C:20261005` node projects the actual82-product
correction, application status and PR137 merge identity alongside the retained
35-contract transition. Four new metadata inputs retain exact provenance pins.
The34-test graph suite passes; removing the event consumer or its pin check
produces the named failure and restores exact source bytes. All20 other existing
producer functions and D1’s contract-generation dependencies remain unchanged.
Proof694554de31d0e65e444dfbf629f4af7ba3ba716ace287acaa599e03e15c224fe
and guarded landing4018f2a0bc4146ca0362920bf3cedd8b6769e1f44458bd0e52302a638d88be63
record this additive metadata repair.


CI failure census and physical participation correction, 2026-10-05: required
ci-verify at 0b78c793c528c1609f0be21824919765e08abac8 genuinely failed; same-head
CodeQL passed. The complete retained log contains seven fault rows in five groups.
Those same groups were already present at the earlier 046 candidate and were
missed during the first repair pass. That omission, both failures and the original
logs remain recorded. The failed verdicts receive no acceptance credit.

Scatter/dependency instruments now bind actual native occupancy, all four body
ownership maps, exact constructed placement before accounting, and the approved
LeanAndLie availability/provenance. Two baselines and 23 defect controls pass.
Both actual instrument routes require material and purpose; extra, duplicate,
missing or unsupported writers fail. Installed gesture ownership passes 18 cases,
11 restored defects and four single-defense redundancy controls. The old mutant
removed one guard while another valid guard retained rejection; the repaired
control distinguishes single-defense protection from removal of both defenses.
Production Gesture remains unchanged. The 13 portable executions include 11
refusals; 13 instrument seam controls also pass.

The real activity-participant gap is repaired in activityParticipantAtHand.
Current actor/NPC/player bodies, six finite coordinates and the existing same-
floor bound precede private fresh belief and use-time native visibility. Cross-
floor visual knowledge remains available. Installed Kahlua passes 140 assertions
across seven actual callers; nine restored defects fail at their named witnesses.
Production Java admission passes 66 checks and 11 defect controls; saved hearing
passes 17 checks and three defects, with 16 source/caller controls. County admission
loads 65 modules, refuses missing owners/sources/native-executor declarations and
four invalid registration orders. Installed Appraisal/Awareness bindings hold;
unconfigured dormant people receive no fabricated memory, education or cognition.
The body-driven conflict dispatcher retains its explicit native-only owner reason.

The guarded landing changes exactly four activity/county source files. Controller
has 140 functions: the physical helper changes, 139 remain exact unchanged. Nine
recovery owner seams and both instrument routes are exact unchanged; all bytes
outside the helper and adjacent comment are preserved. Earlier whole-file source
pins remain historical. Rejected encoding and wrong-order control attempts remain
failed evidence. No Java/JAR change, new game trial or full local gate is claimed.
Required fresh remote ci-verify/codeql-python and protected squash merge remain
pending at record preparation; actual publication belongs to the external receipt.

Source proof bindings SHA256 847b9624f5230338472938743d8902e3fd6bc7133bdececeaabb48752a49bc80.
Activity/county proof SHA256 c0e50f00feeb91b2a10d383252f33825d89b54436f73ed3d8807c20a85a1c345; guarded landing 2213b47c2c43545fb6aaef58d1b4612d965cb0fcf21f457d24e5722d7bb0bb0d.


Complete gate census and shared-sort correction, 2026-10-05: the earlier statement
that failure03 had five complete failure groups was incorrect. Its seven FAULT
rows cover five groups, while the shell emitted six BORDER FINDING markers. The
sixth was shared-definition duplication, already present in failure02. Failure04
at 7ffea7af15b874ff61e885c2fa362ea17e56a02e has exactly one BORDER FINDING and no
FAULT rows: three pairwise copied-sort spans. CodeQL passed; ci-verify genuinely
failed and the guard stopped without merge. The missed shell category caused an
avoidable rerun. Corrected census retains all three original logs and all gate
finding markers: 60 findings in02, six in03 and one in04. Earlier bad completeness
claims and failed results remain historical and are superseded here.

Perception now exports its existing pure iterative merge as sortEvidence.
Cognition conflict serialization and Controller leisure ranking use that exact
owner with their original comparators. No recursive fallback or duplicate-check
exemption exists. The 11-file closure retains three runtime files and eight
exactly traced fixture changes. Installed sorting passes 48 checks including
32,768 entries, stable ties, wide serialization and 51,200 leisure offers. All
eight affected modes pass; 21 rejection controls retain missing-owner, incorrect-
comparator, recursive-sort, restored-copy and consumer-defect witnesses. The real
consumer census records 56 sources and 150 matches, including early awareness,
resumption and reading initialization; fixtures use the exact source-pinned owner.

The unchanged duplicate checker reports no copied blocks over the complete public
source tree. The unchanged sort audit passes 52 sites over 45 lists. Across the
three runtime files, 293 other function ranges are byte-identical. Nine recovery
owner ranges, both instrument routes and the current physical-participant helper
are preserved. Perception's sorting algorithm and sight consumers remain exact;
its new alias supplies the same computation to the two existing consumers. Prior
whole-file native and stage receipts retain their actual source versions. No new
Java/JAR build, native game trial or local full gate is claimed. Fresh required
remote checks and protected merge remain pending at this preparation; actual
publication is recorded by the exact external acceptance receipt.

Shared-sort closure SHA256 073ee9cc036300a4a7de69bd698a54217b3ab31029d136d19f9d350344bb6055.
Complete census SHA256 3e159461316badcde76635874f7066a82c65bb9103890a1cf3faf7154ec6f1c6.
Current combined source proof bindings SHA256 67d78c59ab13008d0599bf6d9ae2d7b5910917cebcc06e3194b5e497c0777a8e.
