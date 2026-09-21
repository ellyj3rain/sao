# PZ_Optimization reference assessment

Reviewed [xD3I/PZ_Optimization](https://github.com/xD3I/PZ_Optimization/tree/ae971981f582b702ddcf82469f7aa8d26970cffd)
at `ae971981f582b702ddcf82469f7aa8d26970cffd`, supplied by the operator during
C65. This is a source/benchmark review, not a local compatibility or performance
receipt. No external implementation was installed or copied.

The project targets the installed engine revision, Build 42.20.4 / `b0bbce05d5`.
Loose classes shadow engine classes ahead of the jar. Its build checks public
member signatures and records original class hashes; runtime guards disable
optimization paths on revision/hash mismatch. The shadow classes still load on
that fallback, so a mismatch does not restore the new engine's own class bytes.

| Mechanism | Relevance to SAO | Evidence boundary |
|---|---|---|
| Streamer wakeup and ordered parallel chunk recalculation | C61 source hydration also reaches WorldStreamer and IsoChunk. `isBusy` includes pooled work. The pool requires the actual streamer thread and nonempty chunk references; SAO's standalone `addJobInstant` call remains synchronous. | Faster normal streaming does not establish faster dormant simulation or safe concurrency for SAO's standalone acquisition. |
| Lua prototype precompilation and Kahlua table lookup | These replace the VM/compiler substrate beneath SAO's Lua. | SAO's normal/debug compilation, table persistence, private evidence and decision determinism need comparison with the overrides loaded. |
| Renderer caching and frame scheduling | Could improve loaded play with population present. | Upstream FPS is a different measure from simulation throughput, decision cost or correctness. |
| Hot-save throttle | Changes timing of engine persistence. | SAO/ZAO's native/global-generation reconstruction and interruption behavior need unchanged results in an isolated save. |

Upstream's Windows report gives 122 to 194 mean FPS and 26.1 to 18.5 ms p99 on
its fixed route, with two stock repetitions. These are reported upstream results,
not measurements of this installation. Its parity report compares 131,133
squares in 1,653 chunks across 1, 2, 4 and 15 workers. That is useful evidence for
the normal recalculation path, not a complete SAO/ZAO compatibility proof.

The [known limitations](https://github.com/xD3I/PZ_Optimization/blob/ae971981f582b702ddcf82469f7aa8d26970cffd/README.md#known-limitations)
state single-player scope and no test with both its optimizations and
ZombieBuddy's optimizations active. The reported coexistence uses ZombieBuddy
2.3.3 with optimization switches off; this installed stack uses ZombieBuddy
2.3.2 plus SAO, ZAO, PeekAView and Staircast. No licence grant was found in the
reviewed tree or README. Source incorporation therefore has no established terms.

`performance-overlap.json` compares the pinned override inventory with the
current C65 startup's actual ZombieBuddy patch log. Thirteen patched method names
sit within six overridden classes: Display, GameWindow, GameLoadingState,
LightingJNI, FBORenderCell and WeatherFxMask. That is a concrete inspection set,
not proof of conflict: method bodies and advice ordering still need comparison.
SAO's three agent targets (SwipeStatePlayer, AnimationPlayer and ItemPickerJava)
are absent from this override inventory; indirect dependencies still apply.

The concrete evaluation sequence completes that method-body comparison, then an
isolated reproducible stock/optimized comparison with identical save, mod set,
population, camera/route and seeds. Measure chunk latency, main-thread time,
dormant throughput, allocations and tail frame time separately. Compare exact
source observations, selected actions, results and reconstructed save state
before accepting speed improvements. This is an optional integration study;
it does not change the ratified R9/R11/R12 dependency order or create a new
prerequisite for their implementation.

Primary code read: `WorldStreamer.DoChunkAlways/addJobInstant/isBusy`,
`RecalcPool`, `OrderedPublisher`, `StreamerWake`, `Overrides`, `LuaCompiler`,
`KahluaTableImpl` and `scripts/build.sh`. SAO comparison:
`java/src/com/sao/engine/SAOWorldSources.java` acquisition and release.
