# C72 dormant spoken access

| Field | Value |
|---|---|
| Timestamp | 2026-09-21 22:24 UTC / 15:24 PST |
| Authority | ROADMAP continuation after C71; SUBSTRATE dormant-spoken-access row; C67 hearing and testimony contract |
| Target | Produce fatigue, rest, sleep and wake while the person has no engine body, before dormant spoken admission |
| Baseline | SAO C71, `11e1cd8`; C67 already measures hearing and refuses asleep or sleep-unknown participants |
| CAO transfer | CAO communication reads the current spawned RimWorld pawn's native `Awake()` state. It has no bodyless-person transition to replicate; SAO retains the shared native-first rule but needs a durable record owner because its body is temporary. |

## Producer and evidence matrix

| Contract | Canonical producer | Persistence and consumer | Completion evidence |
|---|---|---|---|
| Initial state | New Identity records explicitly own fatigue `0`, endurance `1`, sleep need `1`, awake state and `generated-default` provenance | Identity global mod data; dormant physiology | A new person can begin the clock without pretending an older record had the same state. |
| Native acquisition | `SAONativeSnapshot.restState` reads FATIGUE, ENDURANCE and saved sleep traits from a validated native envelope without a body | BodySnapshot commit stores values, origin and county hour | Installed-engine probe returns the exact source values and both sleep-trait multipliers. Invalid or unsupported envelopes remain unknown. |
| Awake advancement | History county hours plus installed `ZomboidGlobals.fatigueIncrease` and current StatsDecrease multiplier | Record fatigue/endurance/sleep need and last physiology hour | One-hour case agrees with the engine-derived law. Saved less/more-sleep traits produce distinct expected rates. |
| Rest and sleep | At-home state, 22:00-06:00 window, existing loaded threshold and charged non-slot recovery law | Durable sleeping/resting flags; movement and Communication consume them | A tired person sleeps at 22:00, does not move or converse, recovers and is explicitly woken at 06:00. |
| Older saves | No producer until a valid native capture; the older `generated-empty-traits` speech marker is hearing provenance only | Communication continues to return `sleep-unobserved` | A marked pre-C72 record stays unknown; a mutation that defaults it flips the verdict. |
| Loaded/bodyless handoff | PhysicalFacts captures current sleep/rest; BodySnapshot captures native rest values; Body applies the completed overlay after native awaken | Same Identity record across temporary bodies | Handoff suite proves exact fatigue/endurance plus asleep and seated posture, including refusal when the apply/posture seam is removed. |
| Spoken admission | Existing C67 Communication contract | Adjacent dormant encounter and private testimony/request acquisition | Physiology runs before encounter scheduling; asleep refuses and the produced morning wake admits. Measured hearing remains unchanged. |
| Radio reception | No completed producer | Radio possession alone remains insufficient | Remains the next batch: require operating receiver, tuned channel and recipient reception evidence. |

## Rate and ownership boundary

The installed Build 42.20 ratio is `fatigueIncrease * 3600 *
StatsDecreaseMultiplier` per county hour. Endurance supplies the engine's awake
factor and saved sleep traits supply the persisted personal multiplier. The
loaded non-slot sleeper already uses eight-hour fatigue recovery and four-hour
endurance recovery; dormant sleep uses that same charged law. C72 does not
invent thermoregulation, activity expenditure, shelter quality or radio access.

Only the record advances while no body exists. The native envelope supplies the
last measured starting point. On materialization, native awaken runs first and
the record's completed interval replaces fatigue, endurance, sleep and seated
posture. No body or item is constructed merely to inspect saved state.

## Verification ladder

| Layer | Check |
|---|---|
| Native format | Build/package and `native_person_test.py`, including exact rest read/apply and all 36 compiled historical mutations. |
| Body handoff | `person_handoff_test.py`, including executable rest-state and posture controls. |
| Bodyless behavior | Border 185 production Kahlua cases plus sleep-write, legacy-default and recovery mutations. |
| Scheduler and cost | Physiology runs before encounters and remains inside dormant life's one declared full-store walk. |
| Repository | Complete `tools/check.sh` under the installed engine/JDK, then protected-main pull request and squash merge. |
| Runtime | Deploy from merged main and verify one responsive Project Zomboid main-menu client without loading or modifying a save. |

Mechanical and startup evidence do not establish player-visible sleep quality or
loaded-save acceptance. Those observations remain separate receipts.
