# C54 - Native person continuity

| Field | Record |
|---|---|
| Batch | `C54` |
| Date | 2026-09-19 |
| Name | Native person continuity |
| Status | Closed implementation batch; loaded-world receipt pending. |
| Threads | [`T-006`](THREADS.md#t-006), [`T-007`](THREADS.md#t-007), [`T-008`](THREADS.md#t-008) |

## Behavior

The native-person writer advances from v3's five supported components to a v4
envelope that also carries nutrition, fitness, recipes and all reading/media
collections, descriptor perk boosts, human appearance, hair/beard growth timing
and declared durable character ModData. Root and nested item identities retain
exact native fluid-component facts, so a silently removed definition cannot
turn one mixture into another during restoration.

Nutrition restores the native values plus its omitted update counter, calorie
extrema and direction flags. Unsafe weight refuses before the engine loader can
apply its damaging low-weight setter. Fitness loads into a new component before
exercise definitions initialize; its first update establishes the current
ten-minute bucket and its next update advances normally. An in-progress exercise
is a runtime action and remains R4 work.

Learning state restores directly after profession defaults without replaying
callbacks. Recipe IDs remain known even if their current definition is absent;
required perk definitions refuse. Native appearance restores after worn-item
references and before the final model reset. Outfit and forced-model script
references are checked; the growth timers use a bounded engine-field adapter.

Character metadata uses the native Kahlua codec only after strict recursive
preflight. Unsupported required values, cycles, excessive depth and unsafe
strings refuse capture. SAO and ZAO ownership keys remain runtime state and are
reapplied from the destination, including the canonical person identity.

## Compatibility and ownership

v1-v3 remain readable within the fields they actually carried. A successful
wake from an older format records its source version and county hour rather than
claiming the absent components were recovered. v4 owns ordinary appearance, so
new checkpoints and releases clear the older durable visual sidecar. The sidecar
remains for old records and for transient return-source comparison.

The C51 transaction still owns failure order. Parse or component failure occurs
on an unpublished body, preserves the durable snapshot and enters the existing
cleanup/retry path. The Afflicted return capture uses current turned possessions
and appearance with supported living components, then commits one v4 record and
clears the ordinary sidecar.

## Evidence

Border 169 compiles the production snapshot with the installed Build 42.20 jar
and executes root/nested fluid mixtures, nondefault nutrition and hidden cadence,
pending fitness state, every learning collection, a custom boost and its next XP
grant, native appearance and outfit, growth timing, nested optional metadata,
runtime-key preservation, repeated wakes, the next native component updates and
the v3 reader. Twelve controls remove one continuation or refusal seam each and
fail for the named state.

Border 163 retains the actual inventory, equipment, wound, statistics, XP,
trait, item-processing and return-source controls. Borders 162 and 164-167 retain
ownership, authorized transfer, staged-body, save-checkpoint and durable-string
failure order. The full repository gate passes with 169 numbered borders and
184 gated mirrors.

This is mechanical persistence evidence. C54 is not deployed and does not close
R4 runtime reconstruction, R5 dormant physiology, the Crossed action system or
loaded-world play acceptance.
