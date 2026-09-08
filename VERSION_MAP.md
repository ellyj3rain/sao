# Version map

The regulatory version replay: the closed batch chronology classified
one unit per batch, the coordinate computed under CAO's caps. The
version is a machine (DR-013): nobody picks the number - to disagree
with the coordinate, disagree with a tier in
[`tools/version_replay.py`](tools/version_replay.py) and run
`python tools/version_replay.py --write`; the map and `VERSION`
follow. Border 80 refuses a tree whose stated versions disagree with
the machine. Names, dates, and threads below come from
[`BATCH_LOG.md`](BATCH_LOG.md), which owns them.

| Field | Current state |
|---|---|
| Schema | `sao.version-model/1` (CAO's `cao.version-model/1`, adopted) |
| Form | `major.minor.kohai.patch-maturity` |
| Hard caps | minor 12; kohai 16; patch 24 |
| Replay start | `0.1.0.0-pre-alpha` |
| Current version | `3.1.0.0-pre-alpha` |
| Closed chronology | `A1-C42` |
| Next batch | `C43` |
| Executable source | [`tools/version_replay.py`](tools/version_replay.py) |

## Tier meanings

| Tier | Meaning here |
|---|---|
| major | Formal release, project-identity, or supported-compatibility boundary. No unit requires it; the odometer reaches it by cap. |
| minor | A new player-visible simulation capability or a new authoring/runtime contract. |
| kohai | A coherent extension, integration, or structural maturation of an existing capability. |
| patch | An in-place correction, verification closure, or repair that does not move a capability boundary. |
| maturity | `pre-alpha -> alpha -> beta -> rc`; moves on evidence (play receipts), never on arithmetic. Everything here is pre-alpha. |

## Chronological replay

| Batch | Date | Tier | Resulting version | Name | Classification |
|---|---|---|---|---|---|
| `A1` | 2026-08-26 | initial | `0.1.0.0-pre-alpha` | Repository and governance surface | The governed repository itself: doc-pack, instruction surface, ratified pillar composition; no framework code. |
| `A2` | 2026-08-26 | kohai | `0.1.1.0-pre-alpha` | Engine control-surface verification | The verified engine substrate (F-001..F-007) before anything built on it; preparation, not a shipped capability. |
| `A3` | 2026-08-26 | minor | `0.2.0.0-pre-alpha` | First survivor in the world | The first survivor in the world: spawn, walk, remove - the first player-visible capability, and the mod tree ships. |
| `A4` | 2026-08-26 | minor | `0.3.0.0-pre-alpha` | Java agent and engine-comprehension contract | The compiled agent, the bridge, and ENGINE_CONTRACT: the runtime contract everything renders and calls through. |
| `A5` | 2026-08-26 | minor | `0.4.0.0-pre-alpha` | Four-pillar substrates live | The four pillars as code: perception with provenance, bounded disposition, standing, the controller composition. |
| `A6` | 2026-08-26 | minor | `0.5.0.0-pre-alpha` | Combat transplant, perception depth, persistent world | Combat both directions and a persistent population in real towns: the framework becomes something a player meets. |
| `A7` | 2026-08-26 | kohai | `0.5.1.0-pre-alpha` | World-origin genesis; standing emerges in play | Genesis matured to the map's own spawn-region draw, off the forbidden refill shape; policy numbers become sandbox options. |
| `A8` | 2026-08-25 | minor | `0.6.0.0-pre-alpha` | Needs via engine timed actions; grudges, testimony, gear | The needs layer through the engine's own timed actions - eating, drinking, interruptible; grudges, testimony, gear errands. |
| `A9` | 2026-08-25 | minor | `0.7.0.0-pre-alpha` | Canonical keys, voice surface, claims, first aid, sharing | The voice surface and real territory: claims, permission, first aid, sharing - with the one key schema (DR-005) under it. |
| `A10` | 2026-08-26 | kohai | `0.7.1.0-pre-alpha` | Multi-floor work, ranged doctrine, audit alternation | Multi-floor work, the ranged doctrine, and the F-011 sight repair: the loop polished, no new boundary. |
| `A11` | 2026-08-26 | kohai | `0.7.2.0-pre-alpha` | Hibernation persistence, dormant drift, estates, sleep | Hibernation made whole (F-013), dormant drift, estates, sleep: persistence matured into the person outliving the scene. |
| `A12` | 2026-08-26 | minor | `0.8.0.0-pre-alpha` | Property enforcement, completed policy screen, gifts, barter | The social economy opens: gifts, barter, property with teeth and manners, dormant encounters. |
| `A13` | 2026-08-26 | kohai | `0.8.1.0-pre-alpha` | Attribution, debts, coordinated flight, companionship | Debts, gunfire attribution, coordinated flight, companionship: the economy and relations grow edges. |
| `A14` | 2026-08-26 | minor | `0.9.0.0-pre-alpha` | Society arc: claims and lessons, leaders, settlement, membership, habits, bonds | The society arc ratified and built (DR-006): claims and lessons, leaders, settlement, membership, habits, bonds. |
| `A15` | 2026-08-26 | kohai | `0.9.1.0-pre-alpha` | Belief-gated permission and first-offense innocence | Belief-gated permission (DR-007): the permission layer's last free knowledge made earned; epistemics matured. |
| `A16` | 2026-08-26 | patch | `0.9.1.1-pre-alpha` | Approval-chain repair, first live witness, county scale, coexistence | The approval-chain repair (F-023) and the first live witness: verification closure on the existing line. |
| `A17` | 2026-08-26 | minor | `0.10.0.0-pre-alpha` | Inhabitant adoption and the passive social economy | Inhabitant adoption: other mods' live humans join the social fabric with records, contact-scaled pasts, split clocks. |
| `A18` | 2026-08-26 | minor | `0.11.0.0-pre-alpha` | Registry census and profession-keyed origins | The census contract (DR-010/DR-011): 1993 labor distribution, profession-keyed origins, compatibility from first principles. |
| `A19` | 2026-08-26 | minor | `0.12.0.0-pre-alpha` | The workday taxonomy, elections, and one death law | The workday taxonomy and elections: every tick carries a pressure answer; a mannequin is structurally impossible. |
| `A20` | 2026-08-26 | kohai | `0.12.1.0-pre-alpha` | Feuds, full-person talk, dormant attrition | Feuds, full-person talk, dormant attrition: politics closes its loop and gains its voice. |
| `A21` | 2026-08-26 | patch | `0.12.1.1-pre-alpha` | Hardening rotation: bulkheads, the ledger, peace | The hardening rotation: bulkheads, fault gates, F-031..F-034 - repair and closure, no boundary moved. |
| `A22` | 2026-08-26 | kohai | `0.12.2.0-pre-alpha` | Schism, the war chronicle, the invariant sweep | Schism's mechanics, the war chronicle, the invariant sweep: politics matured under its audit trail. |
| `A23` | 2026-08-26 | kohai | `0.12.3.0-pre-alpha` | Era boundary 0.5; offline equilibrium verification | The offline equilibrium harness: 120 deterministic days prove the county's physics without the game; instrument, not capability. |
| `A24` | 2026-08-26 | kohai | `0.12.4.0-pre-alpha` | Engine rotation, pack v2, full names, per-person texture | The engine rotation re-read end to end; full names and per-person texture make the people legible. |
| `A25` | 2026-08-26 | kohai | `0.12.5.0-pre-alpha` | Counsel verb; ration policy and the governance chronicle | Counsel, ration policy, the governance chronicle: the commons matured at community scale. |
| `A26` | 2026-08-26 | minor | `1.0.0.0-pre-alpha` | The county wire, both directions, pacts, calls, debts | The county wire, 101.2, both directions: a new medium, built on the engine's own radio pattern. |
| `A27` | 2026-08-26 | kohai | `1.0.1.0-pre-alpha` | Player chairmanship; arrival draw; war parties; temperament corrections | Player chairmanship, the arrival draw, war parties: the political physics completed. |
| `A28` | 2026-08-26 | minor | `1.1.0.0-pre-alpha` | Derived possessions, the economy loop, presumption and reunion, venture worry | Derived possessions: the convenience tables die; place provides, person spots - a new derivation contract. |
| `A29` | 2026-08-26 | minor | `1.2.0.0-pre-alpha` | Day-zero innocent-county mode | Day-zero innocent-county mode: a new way to start the world, innocent by construction. |
| `B1` | 2026-08-26 | minor | `1.3.0.0-pre-alpha` | Venture machinery: departures, terms, crews, briefings | The venture as a designed feature-complex: motor pool, departure argument, terms, crews, briefings. |
| `B2` | 2026-08-26 | kohai | `1.3.1.0-pre-alpha` | Skill levels drive assignment and rates | Skill levels drive assignment and rates across the existing work; one truth, two read paths. |
| `B3` | 2026-08-26 | minor | `1.4.0.0-pre-alpha` | Bite visibility, house response, turning recognition, promises kept | The bitten arc: bite visibility, the house's answer from character, turning recognition, promises kept. |
| `B4` | 2026-08-26 | minor | `1.5.0.0-pre-alpha` | Farming through vanilla actions | Farming through vanilla timed actions: the renewable arm of the material economy. |
| `B5` | 2026-08-26 | patch | `1.5.0.1-pre-alpha` | Performance and sensor audits; three borders born | Performance and sensor audits; three borders born - cost and truthfulness closure. |
| `B6` | 2026-08-26 | minor | `1.6.0.0-pre-alpha` | Water stores and runs, shutoff event; hearth tending and lighting | Water as the second material axis and fire as a need: stores, runs, the shutoff day, hearth tending and lighting. |
| `B7` | 2026-08-26 | kohai | `1.6.1.0-pre-alpha` | Council abandonment; wound infection treatment | Council abandonment and the wound's full life: decisions the state earns, on existing machinery. |
| `B8` | 2026-08-26 | kohai | `1.6.2.0-pre-alpha` | Reputation endorsement; standing decay and lapse | Standing moves both directions: endorsement, decay, lapse, walking out - the ratchet removed. |
| `B9` | 2026-08-26 | kohai | `1.6.3.0-pre-alpha` | Moodle-colored meetings; bulletins as told knowledge | The engine's own chemistry colors meetings; wire bulletins land as told knowledge in real receivers. |
| `B10` | 2026-08-26 | patch | `1.6.3.1-pre-alpha` | Foreign key domain; wound persistence; player-death release | The foreign key domain contained, wounds persist through the pack, the county lets go at player death - repairs. |
| `B11` | 2026-08-26 | kohai | `1.6.4.0-pre-alpha` | Housemate teaching; player barter | Housemate teaching and player barter: the circle law's cost and the player in the economy. |
| `B12` | 2026-08-26 | kohai | `1.6.5.0-pre-alpha` | Native menu restructure; version 0.6; index completion | The verb wall collapses into the game's own menu idiom; the index completed - surface maturation. |
| `B13` | 2026-08-26 | kohai | `1.6.6.0-pre-alpha` | Need-driven promotion at election | Need-driven promotion at election: the house reads its own counted claims and adapts. |
| `B14` | 2026-08-26 | kohai | `1.6.7.0-pre-alpha` | Repository gate and pre-commit hook | The repository gate and pre-commit hook: discipline made mechanical, proven by breaking the tree. |
| `B15` | 2026-08-26 | kohai | `1.6.8.0-pre-alpha` | Corpse looting with dignity rules | Corpse looting with dignity rules: the one place dignity outranks need. |
| `B16` | 2026-08-26 | patch | `1.6.8.1-pre-alpha` | Undeclared-identifier audit; edit-verification law | The undeclared-identifier audit and the edit-verification law: instruments and closure. |
| `B17` | 2026-08-26 | kohai | `1.6.9.0-pre-alpha` | Night-light gating; weather effects | Night-light gating and weather's weight: dark and storms shape the existing behaviors. |
| `B18` | 2026-08-26 | kohai | `1.6.10.0-pre-alpha` | Ledger window; player claims and household | The Ledger learns live content; the player claims ground and homes companions through existing machinery. |
| `B19` | 2026-08-26 | kohai | `1.6.11.0-pre-alpha` | Player teaching; vehicle crews; venture staffing; scout reports; night watch | Player teaching, vehicle crews, venture staffing, night watch: the player joins the work. |
| `B20` | 2026-08-26 | kohai | `1.6.12.0-pre-alpha` | Severity-first aid; the distress cry and its cost; the cook designation | Severity-first aid, the distress cry and its cost, the cook designation: professional shapes on existing lines. |
| `B21` | 2026-08-26 | kohai | `1.6.13.0-pre-alpha` | Population exchange with the zombie pool; music gathering; capability survey; evidence-based judging | Population exchange with the zombie pool, porch music, evidence-based judging: composition with the world. |
| `B22` | 2026-08-26 | kohai | `1.6.14.0-pre-alpha` | Keepsakes and reading; derived work stations; skill-book study | Keepsakes and reading, derived work stations, skill-book study: identity beyond employment. |
| `B23` | 2026-08-26 | minor | `1.7.0.0-pre-alpha` | Government forms; scarcity asks; division-driven schism | Government's complete shapes: five forms, deputies, turns, scarcity asks, division-driven schism. |
| `B24` | 2026-08-26 | patch | `1.7.0.1-pre-alpha` | Dead pact layer found and mirrored; county-normalized creeds | The dead pact layer revived (one-character typo) and the creed distribution corrected - repairs with their border. |
| `B25` | 2026-08-26 | patch | `1.7.0.2-pre-alpha` | Work-judgment probing; quarrel drivers; identity-gate corrections | Work-judgment probing, quarrel drivers, identity-gate corrections: probing and repair. |
| `B26` | 2026-08-26 | patch | `1.7.0.3-pre-alpha` | Engine item-vocabulary corrections | Engine item-vocabulary corrections: four dead literals replaced with the engine's own surfaces. |
| `B27` | 2026-08-26 | minor | `1.8.0.0-pre-alpha` | Player as channel participant, inbound and outbound | The player as channel participant: one experience loop, inbound and outbound, restoring a missing player-visible contract. |
| `B28` | 2026-08-26 | kohai | `1.8.1.0-pre-alpha` | Newcomer reach, arrival rates, registers, trespass teaching | Newcomer reach, arrival rates, registers, trespass teaching: the road matured and measured. |
| `B29` | 2026-08-26 | patch | `1.8.1.1-pre-alpha` | Road-frequency display; ledger paging; window sizing | Road-frequency display, ledger paging, window sizing: small surfaces made honest. |
| `B30` | 2026-08-26 | patch | `1.8.1.2-pre-alpha` | Publishing metadata and false-description repair | Publishing metadata and the false description repaired; attribution made precise. |
| `B31` | 2026-08-27 | patch | `1.8.1.3-pre-alpha` | Duplication border; fuel accounting; protocol borders | The duplication border, fuel accounting, protocol borders: drift measured before unified. |
| `B32` | 2026-08-27 | patch | `1.8.1.4-pre-alpha` | Between-time chain repair; mirror coverage; analysis discipline; trait correlations | The between-time chain repaired, mirror coverage, analysis discipline: the county's habits fixed with their instrument. |
| `B33` | 2026-08-27 | patch | `1.8.1.5-pre-alpha` | Radius reconciliation; shipped-jar currency; failure visibility | The two radii reconciled into one honest band; the shipped jar found stale and made current. |
| `B34` | 2026-08-27 | patch | `1.8.1.6-pre-alpha` | Menu gating; measured claim extents; queue-drop detection; ledger and trade audits | Menu gating, measured claim extents, queue-drop detection: silent failure classes closed. |
| `B35` | 2026-08-27 | kohai | `1.8.2.0-pre-alpha` | Claim unlearning and protection; voice reachability; carry-light wiring | The claim lifecycle completed: unlearning by proximity, protection, carry-light wired to its walk. |
| `B36` | 2026-08-27 | patch | `1.8.2.1-pre-alpha` | Save-field guard; deploy survival; catch audit; governance clauses | The save-field guard, deploy survival, the catch audit: the discipline layer hardened. |
| `B37` | 2026-08-27 | patch | `1.8.2.2-pre-alpha` | Band constant; claim visibility; age arithmetic; death causes; shutoff belief revision | The county's truths made singular: one band constant, age arithmetic, death causes, shutoff revision. |
| `B38` | 2026-08-27 | minor | `1.9.0.0-pre-alpha` | Map-derived scale; 1990 grounding; arrival units; telemetry; age; room offers | The county's scale derived from the installed map and the census graded against the real 1990 - assumption replaced by contract. |
| `B39` | 2026-08-27 | minor | `1.10.0.0-pre-alpha` | Acquisition provenance; place depletion; dormant option parity | Acquisition provenance completed (unknown fails the gate) and places spent by being visited - scarcity becomes a model. |
| `B40` | 2026-08-27 | patch | `1.10.0.1-pre-alpha` | Named constants; lived provenance at genesis; perk vocabulary map | Named constants, lived provenance at genesis, the perk vocabulary map: names that keep arithmetic honest. |
| `B41` | 2026-08-27 | patch | `1.10.0.2-pre-alpha` | Book routing; constant enforcement; mirror-run coverage; player perception repair | The gate audits itself: all mirrors run, and the player's own perception repaired after 79 batches blind. |
| `B42` | 2026-08-27 | patch | `1.10.0.3-pre-alpha` | Silent-surface repairs and census authority (DR-012) | The silent surfaces hunted as a class; census authority ratified (DR-012). |
| `B43` | 2026-08-27 | patch | `1.10.0.4-pre-alpha` | Jar version stamping; session-state truth; dormant economic parity; reach census | The jar stamps its own version, session-state truth gated, the dormant economy's unwired halves wired. |
| `B44` | 2026-08-28 | patch | `1.10.0.5-pre-alpha` | Legible option labels; the Kahlua runtime boundary | Legible option labels and the Kahlua runtime boundary learned from a live crash. |
| `B45` | 2026-08-28 | patch | `1.10.0.6-pre-alpha` | Distance naming; Kahlua-gated compilation; nil-name repair; neighbor narration hold | Distance naming, Kahlua-gated compilation, the nil-name repair, the neighbour narration hold. |
| `B46` | 2026-08-28 | patch | `1.10.0.7-pre-alpha` | Player-reply channel repair | The player-reply channel repaired: two stacked defects that silenced the conversational surface. |
| `B47` | 2026-08-28 | patch | `1.10.0.8-pre-alpha` | Log-reading defect pass: census repair, instrumentation, noise, visibility, boot truth | The log-reading defect pass: census rebuilt true, noise measured down, boot truth. |
| `B48` | 2026-08-28 | patch | `1.10.0.9-pre-alpha` | Distribution arc: lesson instrumentation, hash-pathology fix, verified ranges | The distribution arc: everybody was the same person - the hash pathology found by instrument and fixed. |
| `B49` | 2026-08-28 | patch | `1.10.0.10-pre-alpha` | Frame-time pacing disclosure; standing-decay verification | Frame-time pacing disclosed on every claim; the voice cooldown moved to the wall clock; decay verified. |
| `B50` | 2026-08-28 | patch | `1.10.0.11-pre-alpha` | Engine behavior facts; bridge throw graph | Engine behavior facts re-asked of the machine each run; the bridge throw contract graphed. |
| `B51` | 2026-08-28 | patch | `1.10.0.12-pre-alpha` | Death-time cleanup; derived art; dead-relation rows; save-protocol border | The dead stop growing quietly: death-time cleanup, budgeted walks, derived art, the save protocol border. |
| `B52` | 2026-08-28 | patch | `1.10.0.13-pre-alpha` | Derived counts; distance naming; scout completeness; answer-domain closure | The era's integrity closed: derived counts, aligned names, the scout read whole, the answer domain sealed. |
| `C1` | 2026-08-28 | patch | `1.10.0.14-pre-alpha` | Catalog consistency and the three maps | The catalog walked against the tree: 152 index links corrected, the maps drawn and held by Border 79, the gate made caller-independent. |
| `C2` | 2026-08-28 | kohai | `1.10.1.0-pre-alpha` | The version machine | The version machine (DR-013): CAO's model adopted, the tier table as the one input, Border 80 holding every stated version to the replay. |
| `C3` | 2026-08-28 | kohai | `1.10.2.0-pre-alpha` | One person, one name; the neighbour folded | One person, one name (DR-014): the placeholder stamp gone, papers named by the menu's renderer, the neighbour's people keep his name, one menu folds his verbs through his own hands. |
| `C4` | 2026-08-28 | kohai | `1.10.3.0-pre-alpha` | Follow through the crossing; the wheels fold in | The follow crosses windows and fences through the engine's own climbs; vehicle boarding pairs the seat with the mesh, folds into follow, and answers a clear order. |
| `C5` | 2026-08-29 | kohai | `1.10.4.0-pre-alpha` | The spoken word, and the swallowed functions | World text becomes a person talking: the tell speaks the thing itself, coordinates leave every mouth, the innocent assert nothing - and the swallowed-function class is repaired and bordered. |
| `C6` | 2026-08-29 | kohai | `1.10.5.0-pre-alpha` | The inspect harness | The inspect harness: a normal-launch panel and bound key over every store - seen/heard/told, standing, needs, last decision, tick cost - to the one JSONL, reading everything and teaching nothing. |
| `C7` | 2026-08-29 | kohai | `1.10.6.0-pre-alpha` | Superimposed, not beside | Superimposed, not beside (DR-015): the neighbour's per-survivor root stays as the person's one menu, retitled to the name and rebuilt from the county - never stripped, never doubled. |
| `C8` | 2026-08-29 | kohai | `1.10.7.0-pre-alpha` | The turn is real | The turn is real (DR-016): every dead shell reaches the engine's own die() through the corpse net, the person id rides modData through the engine's own copies, and recognition keys on what survives the turn - the [B3] arc's structural repair, javap-grounded (F-044/F-045). |
| `C9` | 2026-08-29 | patch | `1.10.7.1-pre-alpha` | The pool is only the fungible crowd | The pool is only the fungible crowd (F-046): one deletion-grade identity predicate, failing closed, at every consumer of the zombie list that deletes or choreographs - a spawn can no longer quietly take a person, and the removeFromWorld census is closed (Border 88). |
| `C10` | 2026-08-29 | patch | `1.10.7.2-pre-alpha` | The promise swings at the body | The promise swings at the body: the mercy kill aims at the one risen body carrying the person's [C8] mark, misses honestly, and carries the promise instead of taking the nearest stranger (Border 89). |
| `C11` | 2026-08-29 | patch | `1.10.7.3-pre-alpha` | The bite kills on the engine's clock | The bite kills on the engine's clock (F-047): the invented dormant formula replaced by the deterministic infection window read off the body or mirrored with citation; dormant turning mirrors shouldBecomeZombieAfterDeath (Border 90). |
| `C12` | 2026-08-29 | kohai | `1.10.8.0-pre-alpha` | The front end speaks player | The front end speaks player (DR-017): mode-sentinels became worded switches, the coded pressure scale became the engine's own worded enum, decode tables and sentinel apologies left every label and tooltip; representation split from implementation at one declared seam (Border 91). |
| `C13` | 2026-08-29 | patch | `1.10.8.1-pre-alpha` | No Claude-isms in the copy | No Claude-isms in the copy (DR-018): the sandbox surface rewritten in plain language, the register struck from the Ledger, and Border 92 freezing player-facing copy to a verbatim ratified declaration. |
| `C14` | 2026-08-29 | patch | `1.10.8.2-pre-alpha` | The sweep, round one | The sweep, round one: the paid-for defect classes hunted with real denominators - 216 pcall pairs, 262 call targets, 63 clock fields, every engine-authority comment - zero findings; the precise instrument promoted to Border 93, the imprecise one recorded as a method. |
| `C15` | 2026-08-29 | minor | `1.11.0.0-pre-alpha` | Whole minds survive the reload | Whole minds survive the reload (DR-020): the perception store binds to ModData, the tick axis rebases once on load while the hours axis crosses intact, and every belief a survivor holds persists with the world - a new persistence contract for the mind (Border 94). |
| `C16` | 2026-08-29 | kohai | `1.11.1.0-pre-alpha` | The dead census | The dead census (DR-021 mechanism B, first half): an inert instrument reads the fungible crowd, the identity-bearing bodies, and the loaded and mapped extents through verified surfaces; the telemetry line carries density and projection with the sampling assumption stated (Border 95). |
| `C17` | 2026-08-29 | kohai | `1.11.2.0-pre-alpha` | The crowd ledger | The crowd ledger (DR-021 state agreement): every pool take counted durable, restitution debt-bounded and paced on distant town ground through the engine's own virtual add, the dial off by default until the census has measured (Border 96). |
| `C18` | 2026-08-29 | patch | `1.11.2.1-pre-alpha` | The first play receipts | The first play receipts (F-048/F-049): a re-issued order no longer restarts the route it is already walking - which was cancelling window and fence climbs mid-transition and flipping survivors between FLEE and IDLE 292 times a session - plus the two exceptions the operator's log exposed. |
| `C19` | 2026-08-29 | kohai | `1.11.3.0-pre-alpha` | Partial receipts are receipts | Partial receipts are receipts (DR-025): RECEIPTS.md records what play settles one observation at a time, the perpetual-untested blanket claim is banned from the doc-pack, and the day's own sessions seeded R-001/R-002 (Border 97). |
| `C20` | 2026-08-29 | minor | `1.12.0.0-pre-alpha` | The county takes them whole | The county takes them whole (DR-022/023/024): the neighbour's people absorbed at world start and at birth through his one verified spawn seam, removed never killed, carried whole into county records, truth mirrored back, his caps neutralized and blocked on screen, verb parity kept (F-051/F-052, Border 98). |
| `C21` | 2026-08-29 | patch | `1.12.0.1-pre-alpha` | Fail completely, never his way | Fail completely, never his way (DR-026): the absorption wrap spawns nobody on failure - loudly, with the Ledger carrying the seam - and never falls back to the neighbour's spawn; Border 98 inverted to hold it, its control the overruled [C20] draft. |
| `C22` | 2026-08-29 | patch | `1.12.0.2-pre-alpha` | The switch gates the field | The switch gates the field: the manual number fields on the county's own page grey and lock until their switch is on - vanilla's per-frame gating idiom, held by Border 91. |
| `C23` | 2026-08-29 | patch | `1.12.0.3-pre-alpha` | Deleted, not greyed | Deleted, not greyed: the overridden neighbour dials are removed at the settings-table seam before any row is built (the operator's restatement of DR-023); the [C20] grey-hook retired and refused by Border 98; DR-027 (no leash constants) recorded for the next substantive batch. |
| `C24` | 2026-08-29 | patch | `1.12.0.4-pre-alpha` | The anchor was never there | The anchor was never there (F-053, R-003): [C22]'s gating hook hung on a vanilla per-file LOCAL and silently never attached - reattached through the real global SandboxOptionsScreen onto the page panel instance, cannot-attach paths made loud through the Seams, Border 91 refuses the dead anchor with the photographed [C22] tree as its control. |
| `C25` | 2026-08-29 | minor | `2.0.0.0-pre-alpha` | Need reaches for what they know | Need reaches for what they know (DR-027): the ErrandRadius dial deleted everywhere - the probe is a named perception span, all four live needs and the dormant day fall back to the nearest KNOWN offering under the same property law, horizons derive from the engine's own cell, held knowledge revalidates and absence expires (Border 99). |
| `C26` | 2026-08-29 | patch | `2.0.0.1-pre-alpha` | The click lands and the line holds | The click lands and the line holds (R-005/R-006, F-054, DR-028): talk answers bypass the murmur guards and the trust wall falls to the advertised split, dressing is outcome-verified by worn count with retry and fallback, and the wake law pushes foreign-claim wakes out, moves homes off held ground, and seats one body per square (Border 100). |
| `C27` | 2026-08-30 | minor | `2.1.0.0-pre-alpha` | What one person knows, as one surface | What one person knows, as one surface (SPEECH_ML_DESIGN.md rung 1): SAO_Knowledge answers nine topics with provenance and age, bundles the ratified conditioning (eight axes, trust, the moment), stays read-only by the one-loop law, is driven offline in the engine's own VM by Border 101, and the inspect panel gauges a person through it. |
| `C28` | 2026-08-30 | kohai | `2.1.1.0-pre-alpha` | The inference budget instrument | The inference budget instrument (SPEECH_ML_DESIGN.md): a deterministic model-shaped workload timed on the game's own JVM from the debug menu, reported under BUDGET - the measurement the sizing decision cites; instrument, not capability (A23's precedent). |
| `C29` | 2026-09-06 | minor | `2.2.0.0-pre-alpha` | The body is scaled from inside the animation player | The body is scaled from inside the animation player (DR-032): a Byte Buddy exit advice on the animation player's model-transform build applies a per-person size held only on SAO's own shell, uniform about the feet; the bridge sets and reports it, the body takes it from the age once dressed, the harness clicks it, and Border 104 weaves the installed class off the game and verifies it - the child bands follow in the age batch. |
| `C30` | 2026-09-06 | minor | `2.3.0.0-pre-alpha` | Age is a system on the county's people | Age is a system on the county's people (DR-032): the bands run from six to ninety weighted from the 1990 resident population, five life stages (Getting Old's, credited) drift the living every ten minutes on the engine's own stats, the age decides the work, the pace and the size, and the old die of it on the life table (NCHS 1997, the nearest machine-readable year) - Border 105 drives it in the engine's own VM. |
| `C31` | 2026-09-06 | minor | `2.4.0.0-pre-alpha` | The child's day | The child's day (DR-032): Growing Up's fear floor by age with the night, the comfort object and the kills that harden, read by the disposition's decisions and held on the engine's panic; literacy by the school years lived; the experience throttle on the shell and the birthday floors on strength and fitness; the kit from the child's own temperament; the child's head - Border 106 drives it in the engine's own VM. |
| `C32` | 2026-09-06 | minor | `2.5.0.0-pre-alpha` | Conditions are facts about a person | Conditions are facts about a person (DR-032): drawn at the record's prevalence and gated by age, the mind's and the body's conditions bend the axes, add fear, set how long a belief is kept, what the body carries every ten minutes, what the skills lose and what a book costs; named in plain words on every surface; the two Build 42 condition mods required for the player's side - Border 107 drives it in the engine's own VM. |
| `C33` | 2026-09-06 | minor | `2.6.0.0-pre-alpha` | Habits are facts about a person | Habits are facts about a person (DR-032, S6): the drinker at the record's prevalence with The Alcoholic's phases, the drink taken through the engine's own fluid action or found where one is, the habit lost after three weeks dry and gained by drinking often; the users the county fell with on N and C's schedule, gone by the twentieth clean day; what a habit carries every pass, and the day that settles it - Border 108 drives it in the engine's own VM. |
| `C34` | 2026-09-06 | patch | `2.6.0.1-pre-alpha` | The moment carries the strain | The moment carries the strain (DR-033): the knowledge surface reads the situation the controller's pressure names and whether the speaker is spent, beside the axes, trust and the moment; Decision 5 amended with the register floors under strain; Border 101 asks for both. |
| `C35` | 2026-09-07 | minor | `2.7.0.0-pre-alpha` | The county's gestures | The county's gestures (DR-034): existing art copied with permission and credited - Hobbies' conversation gestures, sitting loops, instrument plays and dances, Week One's serving, coughs and claps - bound by SAO's own nodes and wired to the meeting, the voice's events, the evening seat and the porch tune; Border 109 holds file, node and name to each other. |
| `C36` | 2026-09-07 | minor | `2.8.0.0-pre-alpha` | The record on the county's calendar | The record on the county's calendar (DR-031, Day Zero slice 7): every vanilla channel re-keyed once per save to begin on the save day July 9, 1993 falls on, through the engine's own surface; every paper a container is filled with dated to the newest issue printed by the county's day or taken off the shelf; a sandbox switch on by default - Border 110 runs the arithmetic off the game against the installed jar. |
| `C37` | 2026-09-07 | minor | `2.9.0.0-pre-alpha` | An order lands through standing | An order lands through standing (DR-033, ruled): every ask the player makes of a person goes through SAO_Command - CAO's obedience check on the Standing that exists, a proven hand standing as a second, the envelope's own refusals - voiced with its reason and seen; Border 111 runs the check in the engine's own VM over the county sampled. |
| `C38` | 2026-09-07 | minor | `2.10.0.0-pre-alpha` | The era remembered | The era remembered (Day Zero slice 6): the knowledge surface carries before - born, the war, where from, home, innocent or hardened - and the day it started - the person's own first horror with its date and what it taught, the county's stamps aired as news, the record's first day for a radio owner - as claims with provenance; the chronicle reads its days as the county's own dates through the same calendar; Border 112 drives both topics in the engine's own VM. |
| `C39` | 2026-09-07 | minor | `2.11.0.0-pre-alpha` | The conditions are SAO's own | The conditions are SAO's own (DR-032 amended): the two required mods are gone and SAO registers the county's conditions as engine character traits from shared Lua, vanilla's where vanilla has one, every cost taken from the vanilla trait its shape is anchored to; a survivor's drawn conditions ride their shell as traits, the player's chosen ones are asserted and driven through the same functions; Border 113 holds it and Border 107's requirement seam is inverted. |
| `C40` | 2026-09-07 | minor | `2.12.0.0-pre-alpha` | The county stands on its own | The county stands on its own (DR-035): nothing of this mod runs through another survivor mod unless the player asks - the absorption, the menu superimposition and the prompt hold are all behind switches that default off, so a fresh world reaches into another mod zero times; what stays always on calls none of their code, the manifests require nothing but the loader, and the description no longer claims a requirement [C39] removed; Border 114 holds the law. |
| `C41` | 2026-09-07 | minor | `3.0.0.0-pre-alpha` | The world before the spawn | The world before the spawn (DR-036, one precondition): on a save that has never been settled genesis reaches its target in one pass instead of six people at a time, and it runs ahead of the band in the tick, so the county exists in full before the first body is materialised; the pace and its unit slack are named once and stand unchanged for refill; Border 115 holds the budget, the flag and the ordering law the claim rests on. |
| `C42` | 2026-09-07 | minor | `3.1.0.0-pre-alpha` | Before the fall, an ordinary life | Before the fall, an ordinary life (DR-036): an audit of the day-zero switch found it reached two things and that no decision anywhere asked whether the fall had happened, though the county had written three stamps for it since [B1] and read them only to print a chronicle; the county can be asked now - derived from those stamps and the calendar, never from the dial - and the night watch, the journey for a weapon or ammunition and scouting somewhere defensible all wait for it, while eating, warmth, treatment and mourning deliberately do not; Border 116 holds it. |

## The former number

`0.6.0.0` was declared at [B12] by the former policy ("nineteen
batches of shipped surface") after the prior assistant bumped through
hundreds of diary entries, and the former map walked to it in six flat
minors. The machine replay of the recatalogued units supersedes that
walk: under the caps, twelve minors of capability roll the major - the
odometer crossed `1.0.0.0` at `A26` (the county wire, the thirteenth
minor) by arithmetic, not by honor. The old number undersold the
catalog; neither number was ever a release claim.

## Maturity

`pre-alpha` throughout: maturity moves on play receipts and no batch
has one. The offline harnesses and the border gate are what stand in
the meantime, and they are not play.

## Next movement

`C43` is the next batch. Its content determines its tier after it
exists:

| If C43 is | Result |
|---|---|
| patch or hotfix | `3.1.0.1-pre-alpha` |
| kohai | `3.1.1.0-pre-alpha` |
| minor | `3.2.0.0-pre-alpha` |
