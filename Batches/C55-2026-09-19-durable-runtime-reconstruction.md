# C55 - Durable/runtime reconstruction

| Field | Record |
|---|---|
| Batch | `C55` |
| Date | 2026-09-19 |
| Name | Durable/runtime reconstruction |
| Status | Closed implementation batch; loaded-world receipt pending. |
| Threads | [`T-006`](THREADS.md#t-006), [`T-007`](THREADS.md#t-007), [`T-008`](THREADS.md#t-008) |

## Behavior

R4 separates durable authorities from the objects that only make sense inside
one running world. Branching persists patterns and offices, while Integration
builds a fresh function-bearing graph at startup. Built-ins install once in
stable order and extensions re-register by stable ID. The runtime extension
registry has a 128-entry ceiling before Kahlua sorts caller-supplied IDs. History store memos,
Identity's name index, Places state, durable random-stream objects, controllers,
courses, needs and Java bridge maps all release the prior world's objects before
the next world advances.

Pending work receives an explicit save and reconstruction result. A pending
corpse is materialized during `OnSave` before native serialization; successful
creation removes the pending record, while failure preserves its body and report
for retry. An in-progress fitness exercise is runtime work: restore keeps its
durable regularity and exercise timestamps but cancels `currentExe`, so a reload
cannot turn interruption into completion credit.

## Interrupted return saves

Project Zomboid writes participating return state through separate global and
native body surfaces. A completed round trip could not prove recovery if one
surface reached the new save and the other did not. ZAO A36 therefore adds a
narrow write-ahead generation journal for identities that entered the
Afflicted-return protocol. After Lua `OnSave` and before native body persistence,
the journal captures the SAO record slice, ZAO pathogen/recovery slice and the
exact source receipt or absence tombstone. The file is checksummed, forced and
atomically replaced; generation markers bind both global tables and native
bodies to that record.

Replay runs after global mod data loads and before native reanimated bodies load.
It reconciles person, event, incarnation and token before retaining, replacing,
reconstructing or retiring a source. The mechanism covers ordinary and native
reanimated sources, cancellation after a held source, completed retirement and
repeated saves. Old unmarked worlds remain readable and acquire generation
markers on their next save. The journal does not duplicate general world state.

## Evidence

Border 170 runs the shipped Lua in the installed Kahlua VM. It serializes the
actual graph and stores, starts a fresh Lua environment, starts a second world in
the same process, and checks extension callbacks, caches, indexes, random streams,
pending corpse success/failure and Java map teardown. Border 169 additionally
proves that exercise regularity and timestamps survive while `currentExe` does
not, including a repeated restoration.

ZAO Border 8 verifies bytecode lifecycle order: global data is available and the
journal replays before native reanimated-player load; `OnSave` and journal
preparation occur before native save, which precedes global-data save. It then
executes native-old/global-old, native-old/global-new,
native-new/global-old and native-new/global-new pairings. Missing native sources,
stale native sources, retirement, cancellation and repeated preparation pass;
missing or corrupt current journals refuse. Mutation controls remove the new
hooks and reconciliation branches and fail.

The repository gates remain the final batch check. These are controlled
installed-engine and VM receipts. They do not establish loaded-world play
acceptance, R5 physiology, R7's general action receipts or the complete Crossed
human action system.
