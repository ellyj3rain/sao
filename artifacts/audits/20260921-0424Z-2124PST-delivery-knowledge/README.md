# C67 evidence

| Field | Value |
|---|---|
| Timestamp | 2026-09-21 04:31 UTC / 21:31 PST |
| Status | Implementation, focused verification and installed startup complete; full gate enforced by closing commit |
| Plan | [Producer matrix and scope](PLAN.md) |
| Decision | [Structured Crucible return](decision.json), DR-044 |

The candidate connects native transfers to private actor/witness memory,
physically admitted testimony, heard aid requests and personal reciprocity.
Its implementation and limits are recorded in the
[batch](../../../Batches/C67-2026-09-21-delivery-knowledge.md).

| Evidence | Scope | Current result |
|---|---|---|
| Border176 | Exact production native admission methods with controlled native ports | 61 assertions and nine defect controls passed. |
| Saved hearing | Canonical snapshot reader with controlled script/trait ports | 17 assertions and three defect controls passed. |
| Border179 lifecycle | Real source/needs/controller/capture owners in installed Kahlua | 58 cases and fourteen controls passed, including proved movement followed by conflict/reload and the native recursive-sort failure. |
| Border180 private knowledge | Real Perception/Knowledge/Disposition | 72 cases and seventeen controls passed, including original event time, private appraisal and the historical request/location boundary. |
| Border180 integration | Real Standing/Perception/Communication/Provisioning | 51 cases and thirteen controls passed; two separately identified Controller anchors/two controls passed. |
| Package and startup | Installed API build, exact installation and observed main menu | Passed; complete gate enforced by the closing commit. |

The Java build against installed Build 42.20 passed at version
`2.8.4.0-pre-alpha`. An independent read-only review found no remaining blocker
in the terminal-observation repair: native proof and original witnesses survive
reload; pending/unproved work is refused; conflicts return before material or
social projection; default completed-only readers remain compatible. That review
did not claim fresh game execution. F-092 records the motivating reproduction.

Independent review findings were applied before the closing gate. The remaining
bounded sleep/wake, radio-reception and later-testimony-appraisal producers are
named in ROADMAP, rather than inferred from missing state. DOCX companions are
draft packages until visual rendering is available.

Speakeasy Record 50 is published through
[PR 15](https://github.com/ellyj3rain/zomboid-speakeasy/pull/15), merge
`987570490761b129bb40b7e45c49e64bfb7d1796`. Three source/schema validations,
eighteen authoring tests, unchanged protected-corpus checks and four DOCX
package checks passed. Exactly ten reviewed paths landed through an isolated
worktree; the original dirty checkout was preserved. The repository has no
hosted workflows or required checks. Extraction review, personal acquisition
and conditioning eligibility remain unchanged.


## Combined verification and installation

The independent validator passed all runtime portions of Border179: 41 transfer
cases/twelve controls, 54 lifecycle cases/twelve controls, and sixteen native
holder checks with a rejecting mutation. Its first combined verdict refused an
obsolete static function signature. The [corrected anchor receipt](source-use-anchor-correction.txt)
passes all 34 required anchors and removal controls; the original
[combined output](source-use-test-check.txt) is preserved. The closing full gate
reruns the complete border.

[Border180](provisioning-result-test-check.txt) passed its 53 existing material
cases plus the private-knowledge and integration cases above. [Lua compilation](lua-syntax-test-check.txt)
passed all 76 shipped files in normal/debug modes, 152 verdicts.
[Decision capture](decision-capture-test-check.txt), [person continuity](person-handoff-test-check.txt),
[jar packaging](shipped-jar-check.txt), [version stamps](version-stamp-test-check.txt)
and [bridge arity](bridge-arity-check.txt) passed. The native production build
contains 65 classes representing all 34 sources; arity checks cover 216 bridge
methods, 318 calls and 211 distinct called methods.

All 258 installed SAO files match source. The jar SHA-256
is `5cbc33109f54644486febd81e9737c3401356e3ab23b2071d17be45437359b4b`. All 44,092 save-file sizes and
modification times and all 29 ZAO files, including hashes,
match the pre-deployment baseline. The installed agent jar uses the existing
development launch arguments. The responsive game was foregrounded, and its
[main menu](startup.png) visibly lists SAO and ZAO as loaded. No save was loaded.
[Startup verification](startup-verification.json) records that boundary.

Startup logs contain 5064 `ERROR:` lines, of which 0 name SAO.
The [grouped diagnostics](startup-diagnostics.txt) retain the existing external
animation, vehicle/template and other-mod Lua failures, including the open ZAO
tooltip formatting issue. This is not an error-free mod-stack claim. Mechanical
checks and main-menu startup do not establish loaded-save gameplay acceptance.

This startup snapshot precedes the final witness-ordering hardening. The final
published Lua is installed after the closing gate, and its exact file comparison
and startup are recorded in the local closure receipt. The built Java jar is
unchanged by that Lua-only repair.

The pre-commit hook runs the entire repository gate on this candidate. A
successful exit and hosted checks are required for publication; subsequent
publication evidence is recorded in the local closure receipt. No gate entry
point was added. DOCX companions are package-checked drafts pending visual QA.

The first full-gate attempt was stopped after Border31 detected an unused
`sleepObservedAtHours` write. The consumed sleep-state field remains; the unused
timestamp was removed. Border31 then passed all 109 written fields. The final
closing commit reruns the complete gate; the initial output is preserved locally
at `.git/c67-full-gate-initial.log`.

Border67 also required declared bounds for the new sorted lists. Private transfer
and request acquisitions already cap their maps at 64 entries; their writers
sort at most 65 before eviction and readers at most 64. Those bounds are now
declared alongside the existing production retention controls. Witness ordering
uses iterative insertion, following the existing result-ledger pattern, so the
number of contemporaneous witnesses does not consume the engine's recursive
sort stack or require witness truncation.

The [final lifecycle receipt](witness-ordering-check.txt) passes 58 production
cases and fourteen controls. It retains all 1,601 unique witnesses in ascending,
reverse and adversarial input orders, preserves detached copies and rejects
duplicates and the actor as witness entries. Restoring the former `table.sort`
reproduces an actual stack overflow in the installed Kahlua engine. The thirteen
other controls retain their named verdicts. The early gate attempt containing
this finding was stopped before commit and retained at
`.git/c67-full-gate-sort-stop.log`.

Cancellation of the early commit wrappers left two check-shell children alive.
Their overlap with the next attempt invalidated that attempt as isolated closing
evidence. The surviving check-shell trees were explicitly terminated and their
absence verified. The final closing run starts alone and writes a newly created
`.git/c67-full-gate-isolated.log`; earlier overlapping output is retained locally
for diagnosis and is not used as the complete-gate verdict.
