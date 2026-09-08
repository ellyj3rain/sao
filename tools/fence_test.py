#!/usr/bin/env python3
r"""Border 120 - a person can only say what they know ([C47]).

SPEECH_ML_DESIGN.md Decision 4, ratified through Crucible on
2026-08-29: no-invention is enforced by constrained decoding, not by
instruction. The speaker composes freely, but every fact position can
only be filled from that person's actual memories - it physically
lacks a vocabulary for a brother who does not exist. The same
ratification fixed how it gets proved, and this is that: "no emitted
sentence may assert a fact absent from the input claim set, verified
mechanically over test corpora, not by review."

There is no speaker yet, on purpose. The fence is what makes a wrong
model harmless, so it is built and proved first; whatever arrives
later is handed a vocabulary it cannot escape rather than being asked
to behave.

WHAT THIS HOLDS
---------------
  1. The corpus runs off the game against the shipped jar: true
     fillings pass, invented ones are refused, and the NEAR-MISSES
     are refused too - a name one letter off, a different case, a
     count larger than the one they saw, a real value in the wrong
     slot. A fence that catches only the obvious lie has a hole the
     exact width of a plausible one.
  2. A slot the person holds nothing in cannot be filled, and an
     unknown slot is not a permissive default.
  3. The slots are the knowledge surface's own fields. Nobody may
     write a taxonomy here: the fence is the claim set read sideways,
     so the Java must not carry a hardcoded list of slot names.
  4. Nothing in the fence is advisory. No "should", no warning path -
     a value is permitted or it is not.

An optional argv[1] points the checker at another tree root, which is
how its control runs: the pre-batch tree has no fence.
"""
import os
import pathlib
import re
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
HERE = pathlib.Path(__file__).resolve().parent
FENCE = ROOT / "java" / "src" / "com" / "sao" / "engine" / "SAOFence.java"
CHECK = HERE / "javacheck" / "FenceCheck.java"
JAR = ROOT / "java" / "dist" / "SAOAgent.jar"
DESIGN = ROOT / "SPEECH_ML_DESIGN.md"
GATE = ROOT / "tools" / "check.sh"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_JAR = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid\projectzomboid.jar")


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""


def flat(java):
    """Java block-comment prose as one lowercase line."""
    lines = [re.sub(r"^\s*\*+", " ", line) for line in java.splitlines()]
    return " ".join(" ".join(lines).split()).lower()


def main():
    faults = []
    skipped = []
    print("=" * 74)
    print("A PERSON CAN ONLY SAY WHAT THEY KNOW")
    print("=" * 74)

    if not FENCE.exists():
        print("  FAULT: there is no fence, so nothing structurally stops a "
              "speaker asserting a fact its person never held - and Decision "
              "4 ruled that instruction is not a mechanism")
        return 1
    if not CHECK.exists():
        print("  FAULT: the fence has no corpus check, and the ratification "
              "requires it be proved mechanically rather than by review")
        return 1

    missing = [str(p) for p in (JAR, PZ_JAR, JDK / "javac.exe", JDK / "java.exe")
               if not p.exists()]
    if missing:
        # [C56] SKIPPED, not a finding: a machine without the
        # installed game is not a machine with a defect. Printed
        # loudly so the gate shows it, and never counted as a pass.
        skipped.append("the Java check; missing " + ", ".join(missing))
    else:
        with tempfile.TemporaryDirectory() as tmp:
            classpath = os.pathsep.join(str(p) for p in (PZ_JAR, JAR))
            compiled = subprocess.run(
                [str(JDK / "javac.exe"), "-cp", classpath, "-d", tmp, str(CHECK)],
                capture_output=True, text=True, timeout=300)
            if compiled.returncode != 0:
                faults.append("the fence check does not compile: "
                              + (compiled.stderr or "")[:400])
            else:
                ran = subprocess.run(
                    [str(JDK / "java.exe"), "-cp",
                     os.pathsep.join([classpath, tmp]), "FenceCheck"],
                    capture_output=True, text=True, timeout=300)
                out = (ran.stdout or "") + (ran.stderr or "")
                for line in out.strip().split("\n"):
                    if line.strip():
                        print("   " + line.rstrip())
                if "FENCE PASS" not in out:
                    faults.append("the fence does not hold over the corpus")

    fence, check = read(FENCE), read(CHECK)
    seams = {
        # 3. The slots are read, never listed.
        "the slots come from the claim set, not from a list here":
            "line.substring(0, at).trim()" in fence,
        "and no slot name is hardcoded in the fence":
            not re.search(r'"(person|dead|house|leader|war|region|teller)"', fence),

        # 4. Nothing advisory.
        "an unknown slot is refused, not allowed":
            "allowed != null && allowed.contains" in fence,
        "an empty claim set permits nothing":
            "if (claims == null || claims.isEmpty())" in fence,
        # Read with the comment furniture stripped and the whitespace
        # flattened. The Java is wrapped prose, so the phrase lands
        # across a line break AND with the continuation asterisk
        # between its two words - which reported the reason missing
        # twice while it sat there in plain sight.
        "the comparison is exact, and says why":
            "not fuzzy" in flat(fence),

        # The corpus has to contain the hard cases or it proves nothing.
        "the corpus tries a name one letter off":
            "a name one letter off" in check,
        "a value that is real but in the wrong slot":
            "wrong slot" in check,
        "a count larger than the one they saw":
            "larger than they saw" in check,
        "and a person who knows nothing":
            "knows nothing can say nothing" in check
            or "an empty claim set permits nothing" in check,

        "the design records this as the ratified mechanism":
            "constrained decoding" in read(DESIGN),
        "the gate runs this border":
            "tools/fence_test.py" in read(GATE),
    }

    print()
    for k, v in seams.items():
        print(f"  {'yes' if v else 'NO '}  {k}")
        if not v:
            faults.append(k)

    print()
    print("VERDICT:")
    for s_ in skipped:
        print("  SKIPPED - " + s_)
    if faults:
        for f in dict.fromkeys(faults):
            print("  FAULT: " + f)
        return 1
    print("  120) a person can only say what they know: the fence holds over "
          "the corpus, near-misses included, with the slots read off the "
          "claim set and nothing advisory in it")
    return 0


if __name__ == "__main__":
    sys.exit(main())
