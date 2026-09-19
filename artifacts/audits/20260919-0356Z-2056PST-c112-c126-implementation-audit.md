# Survivor Awareness implementation audit C112 through C126

Timestamp: 2026-09-19 03:56 UTC / 20:56 PST

Purpose: Assess whether the last fifteen batches implement the project's goals and provide a sound foundation for Speakeasy ML. This also reviews the subsequent C127 recovery. Prepared for the project operator as an assessment and proposed continuation; no runtime repairs are made by this audit.

## Assessment

C126 should not be retained as a completed implementation of the ML bridge or learned late-start generation. Its original shortcut assigned survival, deaths, groups, fortifications and lessons from fixed formulas. That violates the requirement that those outcomes emerge from people and their actions. C127 already removed this shortcut. It should remain removed. The useful residue is simulation instrumentation, subject to the limitations below.

The wider audit finds thirteen batches requiring rework, one with configuration wiring worth retaining, and C126's core implementation unsuitable. These are dispositions of the inspected implementations, not rejections of the operator's ideas. The evidence supports selective reconstruction of defective mechanisms; it does not justify reverting fifteen batches wholesale.

The review also finds a direct training-data defect outside those fifteen batches: the decision exporter retains references to mutable person records and beliefs. A decision captured at one moment can therefore contain later knowledge and later state. The probe reproduced this with zero reported capture failures. Existing ratified Speakeasy choices remain ratified; the provenance and conditioning of their source snapshots need separate review. This audit does not establish that all 190 existing rows are corrupted.

The previous recovery addressed real clock and diagnostic failures, but the follow-up focused on numbering instead of this implementation question. C127's successful checks did not establish mechanical readiness for the intended ML work. Several current documents still describe the withdrawn C126 implementation as available.

## Authority and evidence

The governing behavior is the four-pillar composition in CORE and ARCHITECTURE: Perception admits information, Disposition decides, Standing channels relationships and permissions, and Execution performs actions. The durable person record must carry experience across loaded and dormant representations. Outcomes must follow actual causes; an action request is not evidence that the action occurred.

PROJECTS.md, especially the Speakeasy and dataset sections, assigns cognition to Speakeasy: a person's attributes, history and beliefs at the decision moment, together with actually available options, condition a proposed choice. Speakeasy RECORD.md entry 24 explains the four-part row; entries 42 and decisions/CONTRACT.md extend it with event-derived pathogen state and visible forms. Entries 49 through 51 preserve the crossed, afflicted, integration, animal and broader behavioral requirements. Their presence in a record does not establish implementation.

Speakeasy RECORD.md entry 45 states the intended sequence: everything works and is ready to play in theory, then ML training passes over the dataset and runtime, tuned toward first play. Its later readiness commentary reverses this into a curation-and-play prerequisite. That commentary is not a new operator ruling. Model sizing under real game load remains an unresolved measurement; it does not prevent repairing producers, data capture or the training workflow now.

Evidence grades used below: **Executed** means a bounded counterexample ran shipped Lua in the installed engine's Kahlua VM with explicit engine substitutes. **Traced** means the causal path was followed through source and, where relevant, installed engine or mod code. These establish specific defects, not the quality of a complete play session. No game world was launched. No full gate was rerun for this read-only audit. The five existing checks for C122 through C125 were run in isolated scratch space and all passed despite the counterexamples.

The inspected SAO tree is local HEAD `edee13ced379e865b745140dff74c5601ca7f5ca`, the same tree as origin/main `89e7451eea841e7d097902374d8acf293d920cc9`. Historical C126 code was read at local commit `61c28c7`. Existing untracked trajectory files and Speakeasy's modified RECORD.md were preserved.

## Disposition by batch

| Batch | Recommendation | Useful implementation to retain | Required correction |
| --- | --- | --- | --- |
| C112 clock | Rework | Shared history clock and C127 catch-up progress | Remove cached-time divergence during historical substeps; test all consumers in the real callback order. |
| C113 ordinary activity | Rework | Durable workplace coordinates and activity inputs | Give the same decision coherent loaded and dormant consequences. |
| C114 driving | Rework substantially | Engine vehicle and movement adapters | Repair route ownership, progress detection, passenger waiting and steering. |
| C115 options | Retain with downstream limits | Three inspected options reach their consumers | Their wiring does not validate the behaviors they configure. No independent wiring defect found. |
| C116 afflicted return and crossed driving | Rework | Body transition adapters and ownership intent | Enroll returned bodies in the correct controller, implement dormant recovery, record actual driving experience. |
| C117 afflicted social behavior | Rework | Optional social inputs and experience-based relations | Replace automatic daily relocation with a decision and completed movement. |
| C118 robbery and raids | Rework | Transfer, combat, travel and vehicle primitives | Connect perceived demand, response, execution result and subsequent aggressor behavior. |
| C119 Week One and nuke | Rework integration | Event adapters and the optional nuke default | Repair aid/CPR ordering; distinguish queued gestures from completed care. Wider event behavior remains unproved. |
| C120 children and activities | Rework | Age-derived capacity and activity primitives | Fix zero-wound truthiness and perception-bypassing participant discovery. |
| C121 drugs and smoking | Rework | Real use/smoking action adapters and habit records | Repair daily scheduling, frozen abstinence handling and poison-state semantics. |
| C122 keys and vehicle storage | Rework | Verified held-key start and recursive key lookup | Enforce compartment access and current position before inspection or mutation. |
| C123 animals | Rework | Genuine engine care actions and animal classification intent | Exclude animals at the actual human scan path; require approach to the hutch being used. |
| C124 combat perception | Rework | Sound-radius reads, crawler aiming and True Crawl integration | Read the installed prone mod's actual state and revalidate active targets. |
| C125 brain health | Rework substantially | Causal brain-health requirement and repaired off switch | Correct state ownership, exposure integration and live inputs; fulfill the requested graph and behavioral effects. |
| C126 trajectories | Reject core implementation | Useful module inventory and diagnostic collection | Keep fixed outcome assignment removed; withdraw completed-ML and full-fidelity claims. |

C127 is additionally subject to rework. Retain the true elapsed-time scheduler repairs, completion/fault refusal, provenance, and individually supported social corrections. Its offline samples remain diagnostic observations under their stated settings. They do not validate the historical decision exporter, all loaded execution, a model, or a full mature-world producer chain.

## Failures that affect ML readiness

### Decision moments acquire future information

**High, executed.** In tools/county_dump.py, `memberSnap` stores the original record at line 187 and belief table at line 203. Rows are serialized only after the simulation loop, at line 335. The election wrapper captures before the decision and stores selected before/after scalar fields, but the referenced tables continue changing.

The probe captures at hour 1, then changes the person's state and adds a belief at tick 200. The exported hour-1 row contains `recordStage=future`, `beliefStage=future` and that future belief, while `designationBefore=before` and `designationAfter=chosen` remain correct. `captureFailures=0`. This can silently teach a model to decide using facts unavailable at the time.

The same tool still loads tools/sweep/prelude.lua, whose `surveyClaim` answers every queried site with `ways=6 boarded=0 rooms=4`. It runs a fixed maximum of 2,160,000 callbacks without requiring the requested horizon to finish, omits completion provenance from its output, suppresses individual read failures through `ok1`, and continues after a general missing-module warning. C127 repaired a separate evidence host. New training capture needs the same standard of truthful completion and unavailable-ground handling, plus immutable decision-time snapshots and person-scoped knowledge.

### Return and travel requests do not produce their promised behavior

**High, executed and traced.** SAO_AfflictedReturn.lua:83 enumerates the loaded ZAO controller register; bodyless historical records cannot enter it. At line 115 it materializes a returned body without enrolling the person in SAO.Controller. SAO_Body.lua:323 registers the body only; Population's usual adoption route skips records that already have bodies.

The actual-Lua probe returned `hasBody=true` with `automaticController=no-agent`. Explicit controller adoption succeeded as the positive control. A second dead afflicted record outside the loaded register remained dead. A daily call to this loaded-body routine is not a dormant recovery producer.

SAO_Driving.lua:124 treats unchanged verdict text as lack of progress. Java returns `Driving` during healthy travel. A moving-body probe advanced 60.1 units before update 601 cancelled it as `stalled:Driving`; an arrival-at-600 control succeeded. The caller runs this every OnTick. Controller.lua:4794 starts a new approach to the vehicle and line 4803 then cancels locomotion, which can erase that same route. Passenger waiting is requested during WALK although SAODriver.waitSeats accepts only WAIT or START. An exactly rearward goal also produces zero steering with forward throttle in SAODriveLaw.java:99.

SAO_Driving.lua:75 records the `drive` verb when approach is accepted, before boarding or driving. ZAO_Mind consumes it as retained competence. The probe confirms this premature experience stamp. Training on these records would confuse intention, execution and accomplishment.

### Social consequences are authored before experience

**High, executed and traced.** SAO_Standing.lua:3428 moves a groupless afflicted person's home to another known unclaimed site every day without requiring rejection, a need to move, or arrival. The four-day probe alternated home coordinates `1000,10,1000,10` while the person stayed at coordinate 10; the non-afflicted control retained its home. The implementation manufactures repeated displacement instead of deriving an enclave or departure from lived pressures.

In Controller.lua:931, a robbery demand creates speech and a transient cooldown. The victim's transfer at line 1049 is queued, yet trust and the account of having handed something over change immediately. The victim then flees. The installed transfer action stops on walking or running. The robber receives no completed-yield fact to reconsider hostility and can continue into combat. At line 5926, merely finding another claim adds forcing pressure without the hostility condition claimed in the record. These missing links matter to bargaining and relationship training.

### Ordinary activity and care contain false state

**Medium, executed and traced.** The C113 live `in` choice returns without going home at Controller.lua:3905; the dormant equivalent sets home as the goal at Population.lua:1794. Controller.tick at lines 6968 through 6979 caches a value while Population advances many historical substeps inside one callback, so consumers can read stale time. WorldGenesis.lua:70 also passes a day number into Integration's tick argument. These are representation and unit inconsistencies, even after C127's scheduler repair.

C120's wound observer writes zero for a healthy child, but Disposition.lua:114 tests its truthiness. In Lua, zero is true. The stored probe shows fear increasing from 0.1 to 0.35 for a healthy child and remaining 0.35 after healing. Activity-partner discovery also uses raw nearby bodies without the person's perception or floor check. These reads need to follow the same knowledge rules as combat decisions.

For C119, Controller.lua:6353 queues aid before requesting CPR at line 6372. Gesture rejects a busy body. The actual-Lua probe yields `aid=treated,cprAfterAid=false,actions=1`; without the queued aid, CPR succeeds and queues three actions. This establishes a specific composition failure; it is not a blanket finding that the optional nuke or every Week One event fails.

### Drug history and brain health are not causally coherent

**High, executed and traced.** Drugs.lua:329 consumes the new-day flag in its minute callback before the ten-minute work is due. Probe runs differing only in their starting minute produced one daily callback versus zero. Habits.lua:303 through 382 lets clean-day counting advance during a frozen-use interval: at 25 apparent days a habit is removed, then resuming leaves only one actual clean day without restoring the habit.

Neuro.lua:155 samples an infection curve at the interval endpoint and multiplies it by elapsed time. Identical 24-hour courses produced final load 0 with one daily update and 0.9933555063 with ten-minute updates. The midpoint positive control produced 0.96. The condition therefore depends on the scheduler partition, which is fatal to loaded/dormant consistency.

Neuro.lua:147 reads `rec.terminalState`, while the authoritative state is owned by ZAO.StateStore and this SAO field has no writer. Loaded infection/wound flags used by Drugs.lua:352 are refreshed in Population's dormancy transition, so active infection or recovery can be missed. Neuro.lua:176 repeatedly treats cumulative `drinkPoisonTotal` as fresh current damage; Drugs increases that total while reducing only the body's food-sickness stat on recovery. Historical exposure can become a permanent ongoing insult.

Medical.lua:97 returns before the neuro reading when Knox is absent. A record with load 0.9 and medical skill 8 produced `Nothing obviously wrong with them.` ROADMAP.md:873 preserves the operator's requested ZAO-led, event-driven brain-health graph, integrated with memory and health markers. The implementation's scalar, fixed floors and incomplete motor/affective consumers do not fulfill it. C127 fixed the off switch, not this mechanism.

### Optional integration bypasses real world constraints

**High, traced against installed engine and mods.** SAONeeds.java:962, 1078 and 1811 enumerate vehicle containers without the engine's `canAccessContainer` check. Cooking directly changes food in them. Stored source coordinates are captured at line 1838 and not refreshed when a vehicle moves. These paths can grant knowledge or access through locked compartments and at obsolete positions.

SAOPerceptionScanner.java:162 still accepts IsoAnimal through the IsoPlayer branch and appends a human `P` row. The new `isForeignPerson` guard changes classification only; it does not remove the animal from that path. Installed engine constructors supply the inherited username `Bob`, allowing animal sightings to collapse into a human belief. SAOAnimals.java:106 and 121 search the entire ranch's hutches, then SAO_Animals.lua:112 queues egg extraction without approaching the selected hutch. The vanilla action trusts its caller to have supplied that approach.

The prone helper at SAOPerceptionScanner.java:438 omits the installed LethalStealth keys `ltsproneposition` and `ret_lts_acostado`. Its engine-floor fallback does not rescue this mod's prone state. Active combat at SAOCombat.java:112 also omits a renewed deactivation check. Existing compatibility checks 154 through 158 all pass, showing that their asserted surfaces do not cover these actual caller and consumer failures.

## What the ML bridge still needs

The data/model side has real assets: 112 ratified work-word rows, 78 ratified trade-hinge rows, the cross-module contract, nine approved world documents, corpus and voice material. Speakeasy has no trained model or training/evaluation/export implementation. Its README still waits for world-document review although RECORD entry 43 already approves those documents; training/README still says it waits for first approved data. These are stale status statements, not outstanding user decisions.

The current county_trajectory.py collects macro observations with improved refusal and provenance. Those records do not implement the four-part cognition row, teacher proposals, training, evaluation or a model consumer. The optional descriptive fitter also requires a common actual seed across horizons, while production seeds include the horizon's start date. It is not evidence of a learned accelerator. Speakeasy's cross_module_rows.py joins records by id and hour; it does not validate the behavioral truth of their fields and writes output incrementally before full validation.

| Dependency | Present producer and persistence | Observation or evidence | Remaining requirement |
| --- | --- | --- | --- |
| Durable person and causal time | Identity, History and Population records; C127 progress persistence | Scheduler probes; cached-controller mismatch found | One time meaning for all live and dormant consumers and event timestamps. |
| Knowledge and embodied state | Perception beliefs; engine adapters; ZAO state store | Animal misclassification, remote access and stale health inputs found | Correct ownership, perceived facts, unavailable-state handling and event provenance. |
| Available actions and consequences | Controller, Standing, execution adapters and timed actions | Driving, return, robbery and care counterexamples | Action candidates grounded in the person's actual situation; completion or failure feeds records and relationships. |
| Broader life simulation | Isolation, attachment, world development, organization, settlement and material APIs | SUBSTRATE lists missing branches; graph trace confirms gaps | Actual causal producers for provisioning, affiliation, governance, learning, culture and care. |
| Immutable decision snapshots | county_dump captures election context; records remain mutable | Future-information leakage reproduced | Capture by value at the decision boundary, truthful completion, person-scoped facts and executable options. |
| Ratified training material | Existing choices, world documents and cross-module rows | Current files and Speakeasy decisions | Audit source conditioning separately from ratified choice; extend coverage across the implemented life concerns. |
| Training and evaluation | Training rules and standalone arithmetic budget ceiling | No implemented training pipeline or model | Reproducible snapshots, teacher/ratification workflow, training, held-out behavioral evaluation and versioned export. |
| In-process use and late starts | Java inference/fact-constraining primitives and offline diagnostics | No deployed cognition model or validated accelerator | Import contract, real inference integration, loaded-budget measurement and causal-equivalence evidence for acceleration. |

The broader producer gap predates C112 but prevents a credible readiness conclusion. Integration.lua:122 registers work, organization and settlement with the same aggregate pressure; work has the largest coefficient, so the latter two cannot win with positive pressure. Integration.apply records branch/work selections, and the controller stores the resulting graph; the inspected branch/work fields are displayed by Inspect rather than executed as a unified decision authority. Branching.recognize promotes three recorded selections to a pattern, although selection is not completed experience or social recognition. WorldGenesis copies this graph into records without supplying the missing producers. Repairing only the recent defects would leave this substrate unfinished.

The current Population refill path also fills toward a configured population target. Consequently C127's target-12 runs maintaining 12 living people cannot establish a survival distribution or validate emergent population dynamics. That behavior predates this audit window and needs explicit reconciliation with PROJECTS' prohibition on balancing generated populations toward desired outcomes. It should not be silently carried into a learned generation objective.

## Proposed continuation

The next implementation effort should restore a trustworthy simulation and data boundary, with the full life-simulation dependency matrix kept visible throughout. Its completion should be assessed by causal behavior and usable data. A passing repository gate remains necessary verification, but the existing checks demonstrably do not settle those questions.

| Order | Work | Completion evidence |
| --- | --- | --- |
| 1 | Correct current readiness claims and preserve the rejected C126 history with a dated correction | ROADMAP, session state and version rationale describe the actual tree; invalid trajectory artifacts remain identified as historical evidence. |
| 2 | Repair causal time, ownership and state producers | Matching interval partitions; returned people enter exactly one controller; knowledge and health state follow real inputs; durable records survive representation changes. |
| 3 | Complete action consequence chains and the missing life-simulation producers | Driving, care, robbery, affiliation, material work and governance change the world through executable actions; failure and cancellation do not count as success. |
| 4 | Repair and verify decision capture, then audit existing source conditioning | Snapshot immutability, no future or hidden facts, valid available options, exact source provenance, explicit missing-data refusal and protected approved datasets. |
| 5 | Build Speakeasy's reproducible training and runtime path over the intended scope | Data snapshot, split and evaluation record; versioned model artifact; actual SAO consumption; cognition and expression assessed beyond factual fencing alone. |
| 6 | Evaluate any learned late-start acceleration against the repaired causal simulation | Evidence that history, state and subsequent behavior remain coherent without survival floors, settlement quotas or invented completed work. |

Some work can proceed together: the snapshot defect and export protection can be repaired while producer work is underway; existing corpus and approved material need not wait to be organized. Limited diagnostic training can help inspect the pipeline, but would not demonstrate readiness over the full intended scope. No new user play-session requirement is introduced here.

This report records recommendations, not new ratifications. In particular it does not choose a new brain-health design, discard the operator's decisions, certify all untouched code, or classify the whole existing dataset as invalid. Runtime changes, deployment and publishing were not performed during this audit.

## Evidence locations

All runtime Lua paths cited above are under `mod/42.20/media/lua/`; Java paths are under `java/src/`. Source anchors identify the inspected tree and may move during repairs. Batch intent is indexed at BATCH_LOG.md:219 through 233. C126's surviving false completion statements are at ROADMAP.md:899, VERSION_MAP.md:244 and tools/version_replay.py:267.

The adjacent evidence directory preserves the decision-snapshot probe and result, the C117 through C121 probe inputs and results, and the C122 through C125 evidence receipt with installed-engine traces and all five passing check outputs. It also includes a manifest tying the audit to source and engine hashes. The C114 and C116 receipts preserve their original fixtures, exact outputs and reconstructed command expressions; those expressions were transcribed from the executed calls without an additional run. The receipts identify that reconstruction explicitly.

The remaining uncertainties are the prevalence of these defects in actual play, the integrity of each historical training snapshot, performance at the intended population scale, full coverage of the broader totality requirements, and the trained models' eventual quality. None is resolved merely by the historical batch being labelled closed.
