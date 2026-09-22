# C73 radio reception

| Field | Value |
|---|---|
| Timestamp | 2026-09-21 23:51 UTC / 16:51 PST |
| Authority | ROADMAP continuation after C72; SUBSTRATE radio-acquisition row; C67 private testimony and request provenance |
| Target | Make an operating receiver at the event hour produce private reception evidence before any County Wire or player-radio claim changes a mind |
| Baseline | SAO C72, `13faca2`; C71 proves recursive possession but explicitly refuses possession as complete access |
| CAO transfer | Colonist Awareness proves communication endpoints and channel delivery before knowledge consumes a message. SAO retains that ordering and adds a record-owned receiver state because its people can exist without engine bodies. |

## Producer and evidence matrix

| Contract | Canonical producer | Persistence and consumer | Completion evidence |
|---|---|---|---|
| Loaded receiver state | A direct-root native communications `Radio` and its current `DeviceData` | Body checkpoint captures item identity, channel, on/off, audible volume, battery state, power and use rate | Installed-engine cases distinguish direct from bagged devices and refuse off, mistuned, silent or unpowered receivers. |
| Dormant receiver state | The same checkpoint, advanced from its county hour while no body exists | Identity record owns the encoded receiver state and its last advanced hour | Battery power falls by the native stored use rate; depletion turns the receiver off; older possession-only records remain unknown. |
| Hearing and wake state | C67 native/saved hearing plus C72 produced awake state | Communication admission | A deaf, asleep, dead, represented-as-dormant or evidence-unknown person receives no radio claim. |
| Reception | County Wire or an explicit player transmission, exact frequency and one admitted receiver | Recipient-private Perception receipt, bounded and idempotent by broadcast id | A receipt names broadcast, source, event time, channel, representation, device identity and the claims actually carried. Replaying it adds no knowledge or receipt. |
| Request acquisition | `callForBread` records the requesting speaker's private original, then the aired request names that speaker | A listener acquires the request through `recordAidRequest(..., "told", speakerId)` only after reception | The listener preserves original request time, origin and radio teller; an old global ask with no source cannot become private testimony. |
| Player radio verbs | A live, powered, tuned, two-way, unmuted direct-root transmitter plus each recipient's current receiver admission | Reception receipt precedes trust, camp, aid or peace effects | Only the person whose receiver admitted the transmission is affected. Household membership does not relay a broadcast. |
| Wake handoff | Advanced dormant receiver state overlays the restored native inventory before body publication | Native device power/on state resumes from the completed bodyless interval | Wake refuses missing or mismatched device state and cannot restore an exhausted battery as live. |
| Household shortage | No complete-house producer exists after C71 retired the bounded shelf scan | R9 remains the owner | C73 does not restore the nearby-holder count or automatically manufacture calls for bread. It delivers a request when an explicit request producer has actually run. |

## Ownership boundary

Project Zomboid owns radio items and loaded `DeviceData`. The record owns only a
checkpointed sidecar during the interval in which no native body exists. The
sidecar can advance battery power and the consequent off transition; it cannot
retune a receiver, add a battery, move a device out of a bag or create a radio.
At wake, the advanced state must match the exact restored direct-root item.

County Wire scheduling proves that a transmission was offered on 101.2 MHz.
Communication proves which recipients could receive it at that hour. Perception
then records private evidence and content consumers may update only those minds.
The sequence is transmission, access, receipt, claim effect.

## Verification ladder

| Layer | Check |
|---|---|
| Native device | Compile against installed Build 42.20 and execute direct-root, tuning, power, volume, transmitter and elapsed-battery cases. |
| Lua acquisition | Production Kahlua cases execute County Wire request delivery, duplicate refusal, legacy-state refusal and per-person player reception. |
| Mutation controls | Remove direct-root scope, power depletion, transactional wake, receipt-before-effect, request source, event-time, body binding, complete claim capture and per-person routing; each named result must fail. |
| Handoff | Body materialization applies and verifies the advanced device state after native restoration. |
| Repository | Complete `tools/check.sh`, then protected-main pull request and squash merge. |
| Runtime | Deploy merged main and verify one responsive Project Zomboid main-menu client without loading or modifying a save. |

Mechanical and main-menu evidence establish the transport contract and packaged
loadability. They do not establish receiver audio balance or loaded-save play
acceptance.
