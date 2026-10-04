# C73 - Radio reception

| Field | Record |
|---|---|
| Batch | `C73` |
| Date | 2026-09-21 |
| Name | Radio reception |
| Status | Closed; complete repository gate enforced by the publishing commit. |
| Threads | [`T-002`](THREADS.md#t-002), [`T-003`](THREADS.md#t-003), [`T-004`](THREADS.md#t-004), [`T-005`](THREADS.md#t-005), [`T-006`](THREADS.md#t-006), [`T-008`](THREADS.md#t-008), [`T-030`](THREADS.md#t-030) |

## Measured contract

C71 established exact recursive possession and explicitly refused possession as
complete access. C72 supplied the awake/asleep state needed to admit a dormant
listener. The County Wire and player-radio paths still granted claims from
`ownsRadio`: a device could be off, silent, mistuned, empty, inside a bag or
held by another household member. No recipient-private event showed that a
transmission had reached the person whose mind or relationship changed.

The [producer matrix](../artifacts/audits/20260921-2351Z-1651PST-radio-reception/PLAN.md)
separates loaded device state, dormant battery advancement, listener admission,
reception evidence and content effects. Colonist Awareness's transferable rule
is endpoint and channel proof before knowledge delivery. Survivor Awareness
adds a durable device sidecar because its native person body is temporary.

## Implemented behavior

The native inventory bridge captures every direct-root communications radio and
its item identity, channel, on/off state, audible volume, battery presence,
power, native use rate, two-way capability, mute and transmit-disable state.
The direct root matches the installed engine's carried-frequency boundary; a
radio inside a bag remains possession without becoming a current endpoint.
Loaded reception requires a living awake hearing person and an on, powered,
audible receiver tuned to the event channel. Transmission additionally requires
a two-way, unmuted device permitted to transmit.

At a body checkpoint the exact radio state and county hour enter the same staged
facts as health and sleep. While no body exists, the record advances an on
battery receiver by the native stored per-minute use rate. Depletion sets power
to zero and turns the device off. Older records with only `hasRadio` remain
unknown. A C72 pending body-release journal can still commit after upgrade, but
clears radio proof because none was captured. At materialization the complete
advanced radio set must match before any power/off overlay is applied to the
restored direct-root devices and before the body is published.

Every County Wire bulletin and beacon has a durable sequence identity.
Communication admits each recipient separately and Perception writes a bounded,
idempotent private receipt naming source, time, frequency, representation,
device identity and carried claims. Claim consumers run afterward. An aired
food request carries the original requesting speaker, so a recipient acquires
it as told testimony with its original time and origin. Historical global asks
without a speaker do not gain a private source after the fact.

Player chat and wire verbs now share the exact transmitter and receiver
contract. Aid calls, camp locations and peace petitions produce receipts for
their current listeners before any travel, belief, trust or political effect.
One member's receiver no longer gives the broadcast or trust adjustment to the
rest of their household. Knowledge reports radio news only from an actual
receipt rather than device possession.

## Verification

Border 186 executes nineteen production Kahlua cases for County Wire request
delivery, dormant access, battery exhaustion, legacy refusal, duplicate
idempotence, source-less request refusal, per-person player reception, muted
transmission, beacon evidence, channel/power bounds, current event time, body
binding and complete claim capture. Seven Lua mutations remove the request
source, endpoint gate, private receipt, per-person listener rule, current time,
body binding or complete claim copy.

The installed Build 42.20 probe constructs native radio devices and distinguishes
direct from bagged devices, televisions, receive-only sets and off, mistuned,
silent, empty or muted states. It advances the engine's stored use rate,
applies remaining and depleted power at wake, refuses a mismatched restored
device and proves that a later mismatch cannot partially change an earlier
device. Four compiled mutations make nested radios active, remove battery use,
bypass power or apply wake state before full validation; each fails at its named
assertion. The person-handoff suite adds checkpoint, C72 pending-journal
compatibility and post-restore radio controls. The
[evidence record](../artifacts/audits/20260921-2351Z-1651PST-radio-reception/README.md)
holds focused and full-gate results.

## Limits and continuation

C73 delivers an existing request when a real request producer has run. It does
not restore C71's retired nearby-shelf count or infer complete household stock;
automatic material-shortage production remains R9 work. It also does not invent
an autonomous survivor-to-survivor radio action scheduler. County Wire events,
explicit player transmissions and their selected claim effects are the live
producers closed here.

The next work is the selected R12 source/acquisition example on top of actual
reception evidence. Main-menu startup proves packaging and loadability;
loaded-save play acceptance remains separate.
