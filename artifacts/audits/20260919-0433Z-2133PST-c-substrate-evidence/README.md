# Substrate evidence replay

This directory records two bounded checks of the installed Project Zomboid
Kahlua VM against the shipped SAO modules. A successful replay means the
recorded behavior, including the body-release defect, still reproduces.
After that defect is repaired, this historical replay should fail until its
expectations are deliberately revised. It is not a release gate.

Run from the repository root with Python 3.11 or newer and a JDK that supports
the installed engine jar:

```powershell
python artifacts/audits/20260919-0433Z-2133PST-c-substrate-evidence/replay.py --receipt artifacts/audits/20260919-0433Z-2133PST-c-substrate-evidence/replay-receipt.json
```

`--root`, `--game` and `--java-home` override the repository, installed game and
JDK locations. The default game and JDK paths match the audited workstation.
Missing prerequisites fail explicitly. Each command has a 60-second timeout.

The runner compiles this directory's `GraphSerializationProbe.java` and the
repository's `tools/luacheck/LuaRun.java` into a private temporary directory.
It loads the actual GraphPersistence, Branching, Integration and Body Lua
files from the selected repository. It prefers `stdlib.lua` from the engine
jar; the inspected installation has no such entry, so it uses the game's
shipped install-root `stdlib.lua`. Engine source and compiled classes stay
in scratch, which is removed afterward. The runner writes no shared build,
runtime source, game save or game installation file.

The JSON receipt records the argument arrays, working directories, return
codes, output, expected-result checks, engine/module hashes and standard-library
source/hash. The scratch paths in that receipt are historical execution
locations, not prerequisites for replay. Without `--receipt`, JSON goes only
to standard output.

| Check | Expected result | Meaning |
|---|---|---|
| Direct table save/load | `RESTORED nil,nil,nil,work,1` | Function-valued reader, pressure and weight fields are omitted; branch ID and pattern count persist. |
| Fresh module initialization | `REINITIALIZED function,function,function,nil,1` | Integration restores built-in callbacks; an extension needs its owner's registration; history survives. |
| Successful body capture | `true,true,nil,NEW_SNAPSHOT,42` | Release reports success, invokes removal, clears the active body, and stores the new snapshot/time. |
| Throwing body capture | `true,true,nil,OLD_SNAPSHOT,5` | Release still reports success and removes the body while retaining the old snapshot/time. |
| Empty body capture | `true,true,nil,OLD_SNAPSHOT,5` | The actual Java serializer's failure convention reaches the same defective release result. |

The graph probe calls the installed table serializer directly with the
observed engine world version 249. It substitutes dependency availability,
ModData lookup and event registration; it explicitly invokes
`Integration.ensure()` after fresh module initialization. It does not test
the whole game's startup/event ordering or filesystem save operation.
The body probe executes shipped `Body.release` with explicit body and bridge
substitutes. It proves release behavior after capture failure, not failure
frequency or physical inventory/render teardown in a running world.

Installed-engine anchors are preserved in the `javap` text files:
`GlobalModData.save()` delegates to `KahluaTable.save(ByteBuffer)`;
`KahluaTableImpl.save(ByteBuffer)` source lines 258-276 skip unsavable entries,
and `getValueByte` lines 430-442 exclude functions. Normal initialization
reconstructs the built-ins, so these results do not establish a fresh-load
crash. `source-hashes.json`, `graph-result.txt` and `body-result.txt` preserve
the initial investigation; `replay-receipt.json` records the reproducible run.
