# C86 - Native study worlds

| Field | Record |
|---|---|
| Batch | C86 |
| Date | 2026-09-26 |
| Timestamp | 2026-09-26 05:26 UTC / 22:26 PST |
| Name | Native study worlds |
| Status | Closed; native verification recorded and complete gate enforced by the closing commit. |
| Threads | T-002, T-006, T-008, T-009, T-030 |

C86 adds configurable native Project Zomboid study worlds and an autonomous
observer. Definitions own dimensions in the installed 256-tile cell format,
ordered native terrain modules, population origins, copied mod inputs and
observation coverage. Each run owns an exclusive home, cache and save. People
retain their existing SAO and ZAO execution owners. The example is 512 by 512
tiles, with native roads and sparse grassland around four population origins.

The observer has separate view and region-residency references outside actor
collections, square membership, births and player saves. Infrastructure
adapters preserve scheduling, distant chunk delivery and native camera access.
God view uses native filming lighting and tree cutaway without changing actor
perception or physical trees. Ordinary NPC update and postupdate restore the
prior global player and camera. SAO and ZAO participant lookups exclude the
observer marker. Loaded bodies reconcile actual action interruption before
unload release; failed cancellation or state capture retains ownership to retry.

Speakeasy selects camera visits from observed movement, activity and awareness,
with time for individuals, nearby groups and quieter people. Mousecat displays
native framebuffer pixels and person details and sends camera/time requests.
Manual movement holds the view until R resumes automatic visits. Camera
selection changes observation and region residency. Every scenario remains
unreviewed until operator evaluation and explicit ratification.

Native capture uses a bounded background encoder, lossless stored-deflate PNG,
complete image validation, atomic publication and command/frame binding. The
runner seals copied inputs, observations, save files and normal save-return
evidence. Continuation verifies the completed prior attempt and retained mod
order. Attempts own separate command and frame paths. Startup eagerly resolves
ThreadLocalRandom before transformers so the installed mod loader can discover
patches without a cold-JVM class circularity. Earlier failed receipts stay failed.

The operator's circling report exposed several causal defects. Unclassified native
sounds, including self-produced footsteps, became enemy beliefs and unsupported
shooter attribution. The scanner now excludes the hearing body's own sounds;
perception retains other unknown sounds separately, migrates legacy heard
entries and preserves observed, told and explicit phantom threat evidence.
Repeated FLEE decisions also replaced safe unfinished paths. The controller now
retains the active body's valid escape route through native tile-centre arrival,
while still responding to changed threats, permission, floor, body or terminal
state. Held routes preserve injury cries and response accounting.

FOLLOW and PLAYERFOLLOW also redrew random beside-companion offsets during
unfinished paths. A shared helper retains the offset for the same current job,
companion and bodies, while actual companion movement still updates the goal.
Movement update preserves terminal player-follow receipts for the existing
crossing owner. New native crossings require current context and permission,
including the actual next edge; already-started crossings keep their exact
owner. Refused entry and invalid player contexts release stale movement.

Direct zombie sightings previously left successive tile positions as multiple
threats. Continuous visible sightings now update one observer-local track.
Visibility loss, filtering, world reset and restore break tracking authority.
Native visible-tile coverage corrects obsolete locations only on their recorded
floor. Real crowds, hidden memory and explicit phantoms remain. Sharing removes
private tracking authority and filters eligible reports before assigning body
ordinals, preventing reciprocal/repeated testimony from inflating one sighting.
The closing gate also found unbounded recursive evidence sorting. Both new
sorts use a private iterative merge with the same comparators, report
multiplicity and nearest-512 request selection. Border 200 verifies 4,099-entry
producer cases and rejects restored unsafe sorts; it passes 28 native cases,
49 Lua cases and 34 source controls without a new sort-bound allowance.

Native29 then exposed unsupported territory production. Primary admissions
claimed a radius around their starting coordinates without residence or ownership
evidence; move-in handling did the same when its anchor held no ground. Those
fallbacks are removed. Home/origin references, learned buildings and unit bonds
remain; a move-in can still share an actual held claim. Existing claims carry no
provenance sufficient for retrospective deletion and retain their current owner.
The observed run logged 13,383 objections and no "told to leave" transitions.
The claim mechanism can interrupt admitted resource errands, but direct errand
interruption is not established by that run.

| Verification | Observed result |
|---|---|
| Borders 198-200 | Installed engine observer, capture, terrain, startup, persistence and participant controls; 38 escape/follow source controls; native and Kahlua sound/sight acquisition, tracking, coverage, sharing and restoration controls. Closing complete gate is enforced by the pre-commit hook. |
| Borders 115 and 152 | Eleven actual admission cases with recording dependencies; four production conversation/claim cases with 18 checks. Restoring each old ownership fallback fails its named verdict. Existing claims, origin/home information, unit bonds, accepted/refused company and refill timing are preserved. |
| Native run 24, movement | Zero unfinished FLEE replacements; one native arrival, six legitimate cancellations and 16 failed requests during one bounded unload transition. At comparable hours 2.50-2.75, run 23 had 887 unfinished FLEE replacements and run 24 had zero. |
| Native run 25, UI | Pan without residency movement, ten wall seconds paused at the same world hour, person focus, automatic visits, speed changes and normal stop/save. |
| Sound/escape run 27, attempt 1 | Hour 2.0 to 2.389998; normal save return, 32 people, no persisted players, no runtime errors. |
| Sound/escape run 27, attempt 2 | Same save 73517772808093796831; resumed at 2.390368 and stopped at 4.684726; observations continue from sequence 3 through 12; normal save return, 32 people, no persisted players, no runtime errors. |
| Packaged Mousecat, run 27 attempt 3 | Final client checked at 1600 by 900 and 800 by 480. Eight foreground keyboard requests apply, including pan, pause, focus, speed, resume, automatic viewing and normal stop. Native continuation ends at 15.308191 without runtime errors; ended client retains its last image. |
| Speakeasy | 196 tests pass; external SAO validator accepts attempt 2 and intake seals ten frames as unreviewed with zero teaching targets and training rows. |
| Native run 29, movement and acquisition | Hour 2.0 to 3.013311, normal save, 32 people and no runtime errors. Zero unfinished FLEE replacements and one native arrival. Four FOLLOW replacements accompany an actually moving, fleeing companion. All 87 raw direct zombie occurrences carry track and floor; later acquisitions advance. This run precedes the named-radius declaration and territory correction. |
| Run 30 before sorting repair, save/reopen | Save 45796564428844718655: hour 2.0 to 3.033822, then 3.033896 to 3.433938. Both attempts save normally with 32 people, zero persisted players and no runtime errors. Observations continue from sequence 5 to 6-7; Speakeasy intake retains two resumed frames as unreviewed with no targets or training rows. |
| Run 30 before sorting repair, first attempt | Thirteen movement orders, all cancelled; no unfinished replacements or recorded native failures. No territory objections or told-to-leave transitions. The saved native Standing ledger has zero personal/group claims, with 22 memberships across ten companies retained. All 88 raw direct threat occurrences carry track and floor, with later acquisition timestamps advancing. These are bounded mechanics, not completed-work evidence. |
| Run 30 before sorting repair, resumed attempt | Five FOLLOW orders: four cancellations and one native arrival, with no unfinished replacements or recorded failures. No territory objections; saved claims remain zero and company memberships remain. All 32 durable IDs, seven creation/name/sex/profession/origin fields, 510 copied mod inputs and engine/package/loading-agent identities match. Four altered-copy controls reject broken continuity while mutable person state may change. |
| Final-source run 31, continuation | Save 12411292092990057651: hour 2.0 to 2.671554, then 2.671924 to 3.253744. Both saves return normally with 32 people, no persisted players and no runtime errors. All 32 durable IDs, seven identity fields and 510 copied mod files match; observations advance 1-3 to 4-6. Three resumed frames enter Speakeasy as unreviewed with zero targets/training rows. |
| Final-source run 31, movement and claims | One native arrival, 41 cancellations and seven failures; zero unfinished replacements. The failures occur in one person's bounded unload interval: one missing-square failure and six later generic failures before recovery. Twenty-three explicit FLEE cancel/replans remain separate; private threat-vector validity was not captured. Both claim stores contain zero personal/group claims, with memberships growing from 23 to 24 across ten companies. No territory objections or leave transitions occur. |

Perception restores remembered threats without granting retained runtime tracks
authority in a new session. All 56 stored zombie records at the end of run 30's
first attempt survive its first resumed observation except for cleared tracking
tokens. Later direct acquisitions advance and gain fresh tracks. Retained raw
records remain distinct from current threat-query results. Native Standing is
decoded through the installed save codec; nonempty, missing and truncated input
controls validate the reader, and a claim-erasure mutant fails its named check.

The raw run 23/24 route counts are 9,137 orders over 27,381 frames versus 29
over 6,552 frames, or 333.7 versus 4.4 per thousand frames. Both sound and route
fixes changed between these runs, and represented populations and residency
differed; these observations are not an isolated effect estimate. The bounded
unload retry ends at the existing population reconciliation sweep. Broader
productive and social behavior remains an observation task.

Early sixty-second samples delivered 10.98 native images/s in run 24 and 8.04
in run 27, compared with a 20-image/s capture target. The latter overlapped
build/check work. A run 29 sample after build/check work delivered 10.35 images/s,
with median feed capture age 64.25 ms; its meter has a known-bad metadata-counting
control. Mousecat's 60 FPS display rate is a separate measurement.
Run 30 before the sorting repair delivered 10.30 native images/s with median feed capture age
65.02 ms and no heavy build/check overlap during the sixty-second sample.
With checks idle, final-source run 31 delivers 13.03 native and 13.01 bridged
images/s, with median feed capture age 66.10 ms. Population and residency differ,
so the change is not attributed to sorting.
Run 23 profiling identifies game-thread Lua as a remaining bottleneck. Sustained
20-image/s delivery and simulation acceleration are not established.

C86 also retains fractional dormant movement across callback cadences, binds
to installed cell size and adds participant adapters to the evidence host.
ZAO A43 corrects its installed-engine facing call and participant lookups. The
coordination catalogue and twenty choices match C85; row snapshots add only
empty sounds and migration-version fields. Updated C86/A43 source provenance
retains candidate-observation standing and admits no dataset rows.

Compact evidence identities live in
`artifacts/audits/c86-native-study-worlds/verification.json`; local full reports,
images, controlled probes and measurements remain under `_scratch/c86-study/`.
Full physics applies within loaded regions, and unavailable squares and durable
positions remain explicit. Authored buildings, wider mod compositions and
macro-social consistency require further worlds and observation.

The closing gate found that the newly named 14-tile scanner range numerically
collided with the existing social-gathering radius. Border 49 now records why
visual evidence coverage and willingness to gather must vary independently;
no runtime value changes. The interrupted failing gate returned zero through
Windows process termination and created an unverified local commit. Its receipt
is explicitly invalid, retained as `interrupted-collision-gate.json`. Publication
requires the amended commit's complete gate to exit zero and reach its final
`all borders clean` verdict without an earlier border finding.
The next complete gate refused the already-detected recursive sort and a scene
manifest that became stale during its repair. Its failed receipt is retained as
`failed-sort-gate.json`. The repaired source reproduces the same catalogue and
all twenty rows; its regenerated manifest binds the final source hashes.
