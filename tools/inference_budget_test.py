#!/usr/bin/env python3
r"""Border 102 - the inference budget is measured, not guessed
([C28], SPEECH_ML_DESIGN.md).

The ratified talking-system design fixes model size from a
MEASUREMENT: what a model-shaped forward pass costs on the game's
own JVM, on the game's own thread. This border holds the instrument
that takes that measurement.

WHAT THIS HOLDS
---------------
  1. The bridge carries the probe: deterministic weights (no RNG -
     same numbers every run), a warm pass for the JIT, nanosecond
     timing, and the checksum riding the report so the workload
     cannot be optimized away.
  2. The debug menu carries the trigger, and the results go through
     the one logger under the BUDGET tag - the console line IS the
     receipt the design waits on.
  3. The probe runs on the calling thread and says so - the honest
     worst case, named in both the Java comment and the closing log
     line.

An optional argv[1] points the checker at another tree root, which is
how the control runs against the pre-[C28] tree.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
BRIDGE = ROOT / "java" / "src" / "com" / "sao" / "bridge" / "SAOBridge.java"
HAR = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Harness.lua"


def main():
    faults = []
    print("=" * 74)
    print("THE INFERENCE BUDGET IS MEASURED, NOT GUESSED")
    print("=" * 74)

    bridge = BRIDGE.read_text(encoding="utf-8", errors="ignore") \
        if BRIDGE.exists() else ""
    har = HAR.read_text(encoding="utf-8", errors="ignore") \
        if HAR.exists() else ""

    if "inferenceBudgetProbe" not in bridge:
        faults.append("the bridge has no budget probe - the design "
                      "fixes model size from a measurement that "
                      "nothing can take")
    else:
        body = bridge.split("inferenceBudgetProbe", 1)[1]
        body = body.split("private static float budgetForward", 1)[0]
        if "System.nanoTime" not in body:
            faults.append("the probe does not time with nanoTime - "
                          "millisecond clocks cannot see a small "
                          "model's forward pass")
        if "Math.random" in body or "Random" in body:
            faults.append("the probe uses randomness - two runs "
                          "would measure two different workloads")
        if "budgetForward(weights, vec, dim, layers);\n            long min" \
                not in body.replace("\r\n", "\n"):
            faults.append("no warm pass before timing - the first "
                          "run measures the JIT, not the model")
        if "sum=" not in body:
            faults.append("the checksum does not ride the report - "
                          "a workload whose result nobody reads is "
                          "a workload the JIT may delete")
    if "budgetForward" not in bridge or "Math.tanh" not in bridge:
        faults.append("the workload is not a model-shaped forward "
                      "pass (chained matrix-vector with a "
                      "nonlinearity) - measuring something else "
                      "budgets something else")

    if "Measure the speech budget" not in har:
        faults.append("the debug menu has no trigger - an instrument "
                      "nobody can fire takes no measurements")
    if not re.search(r'SAO\.Log\.line\("BUDGET"', har):
        faults.append("results do not go through the one logger "
                      "under the BUDGET tag - the console line is "
                      "the receipt, and it must be findable")
    if "game thread" not in har:
        faults.append("the trigger does not say the measurement is "
                      "game-thread worst case - a number without its "
                      "conditions misleads the sizing decision")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print("  102) the budget instrument: a deterministic model-shaped")
    print("       workload, warmed, nanosecond-timed, checksum-carried,")
    print("       fired from the debug menu, reported under BUDGET with")
    print("       its worst-case conditions named")
    return 0


if __name__ == "__main__":
    sys.exit(main())
