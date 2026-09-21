#!/usr/bin/env python3
"""Border 75 - native snapshot delegation and strict legacy save reading.

The new writer delegates to SAONativeSnapshot's versioned binary envelope.
This border checks that capture, validation and restore use that owner, and
that restoration validates before mutation. Native body roundtrips belong to
the native serializer's engine test. Legacy formats are still save contracts:
we compile their verbatim Java parser and execute valid/corrupt records against
it, including source mutations that must change the behavioral verdict.
"""
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "java/src/com/sao/engine/SAOHibernation.java"
NATIVE = ROOT / "java/src/com/sao/engine/SAONativeSnapshot.java"


def method(src, name):
    """Extract a declaration and body from Java source, preserving its code."""
    match = re.search(r"^    (?:public|private|protected) [^;{}]*?\b"
                      + re.escape(name) + r"\s*\([^)]*\)\s*\{", src, re.M)
    if not match:
        return None
    start = src.find("{", match.start())
    depth = 0
    for at in range(start, len(src)):
        if src[at] == "{":
            depth += 1
        elif src[at] == "}":
            depth -= 1
            if depth == 0:
                return src[match.start():at + 1]
    return None


def source_faults(src, native):
    faults = []
    bodies = {name: method(src, name) for name in
              ("hibernate", "validate", "awaken", "parseLegacy", "finiteFloat", "nonnegativeInt", "requireType")}
    for name, body in bodies.items():
        if body is None:
            faults.append("missing Java snapshot method: " + name)
    if faults:
        return faults
    pack, validate, wake = (bodies[name] for name in ("hibernate", "validate", "awaken"))
    if "return SAONativeSnapshot.capture(shell);" not in pack or "getFullType(" in pack:
        faults.append("new snapshots do not delegate exclusively to native capture")
    if "SAONativeSnapshot.isNative(packed)" not in validate or "return SAONativeSnapshot.validate(packed);" not in validate:
        faults.append("native envelope validation is not delegated")
    if "parseLegacy(packed);" not in validate or "return false;" not in validate:
        faults.append("legacy validation does not fail closed")
    if "!validate(packed)" not in wake or "Double.isFinite(elapsedHours)" not in wake:
        faults.append("awaken lacks snapshot and elapsed-time preflight")
    if "SAONativeSnapshot.restore(shell, packed)" not in wake:
        faults.append("awaken does not restore native snapshots through their owner")
    elif wake.find("!validate(packed)") > wake.find("SAONativeSnapshot.restore(shell, packed)"):
        faults.append("native restoration precedes validation")
    if "if (!nativeSnapshot)" not in wake:
        faults.append("legacy reconstruction can overwrite native body/equipment state")
    if (any(seam not in wake for seam in (
            "hunger + elapsedHours * HUNGER_PER_HOUR",
            "thirst + elapsedHours * THIRST_PER_HOUR",
            "while (elapsedHours > 0 && hungerAfter > 0.5f)",
            "while (elapsedHours > 0 && thirstAfter > 0.5f)",
            "shell.Eat(meal, engineFraction, false)",
            "shell.DrinkFluid(drink, engineFraction, false)"))
            or any(seam not in src for seam in (
                "return SAOPrivateInventory.carriedItems(shell);",
                "food.updateAge();",
                "food.isRotten()",
                "food.getPoisonPower() > 0"))
            or "meal.getContainer().Remove(meal)" in wake):
        faults.append("dormant metabolism bypasses elapsed demand, native partial consumption, spoilage, or nested inventory")
    if "catch (Throwable ignored)" in wake:
        faults.append("restoration failures are silently ignored")
    missing = re.search(r"if \(added == null\)\s*\{([^}]*)\}", wake)
    if not missing or "throw new IllegalStateException" not in missing.group(1):
        faults.append("legacy missing-item restoration can report success")
    if 'PREFIX_V3 = "v3;"' not in native or 'PREFIX_V4 = "v4;"' not in native or any(
            " " + name + "(" not in native for name in ("capture", "validate", "restore")):
        faults.append("the native owner lacks the versioned envelope interface")
    return faults


V1 = "v1;primary=-;h=0.1;t=0.2;hp=85;items="
V2 = "v2;primary=Base.Axe;h=0.1;t=0.2;hp=85;worn=Base.Shirt;items=Base.Axe@63*1,Base.Shirt@100*1,Base.Shirt@50*1"
VALID = [V1, V1 + ";bit=1;inf=2.5", V1.replace("items=", "items=Base.Apple*2"),
         V2, V2.replace(";worn=Base.Shirt", ";worn="), V2 + ";bit=0;inf=0",
         V2.replace("worn=Base.Shirt", "worn=Base.Shirt,Base.Shirt"),
         V1.replace("items=", "items=Mod.Item With Spaces*1")]
INVALID = ["", "v0;", "v3;bad", "v1;primary=-", V1 + ";", V1 + ";unknown=1",
           V1 + ";h=0.3", V1.replace(";hp=85", ""), V1.replace("primary=-", "primary="),
           V1.replace("primary=-", "primary=Base.Axe"), V1.replace("h=0.1", "h=NaN"),
           V1.replace("h=0.1", "h=Infinity"), V1.replace("h=0.1", "h=-0.1"),
           V1.replace("t=0.2", "t=1e999"), V1.replace("hp=85", "hp=garbage"),
           V1 + ";bit=1.5", V1 + ";bit=-1", V1 + ";inf=NaN", V1 + ";worn=",
           V1.replace("items=", "items=Base.Axe*0"), V1.replace("items=", "items=Base.Axe*-1"),
           V1.replace("items=", "items=Base.Axe*1.5"), V1.replace("items=", "items=Base.Axe*2147483648"),
           V1.replace("items=", "items=Base.Axe*2147483647,Base.Shirt*1"),
           V1.replace("items=", "items=Base.Axe*1,"), V1.replace("items=", "items=Base.Axe*1,Base.Axe*1"),
           V1.replace("items=", "items=Base.Axe"), V1.replace("items=", "items=*1"),
           V1.replace("items=", "items=Base.Axe@10*1"), V2.replace(";worn=Base.Shirt", ""),
           V2.replace("Base.Axe@63", "Base.Axe@101"), V2.replace("Base.Axe@63", "Base.Axe@NaN"),
           V2.replace("Base.Axe@63", "Base.Axe"), V2.replace("worn=Base.Shirt", "worn=Base.Missing"),
           V2.replace("worn=Base.Shirt", "worn=Base.Shirt,")]


def java_literal(value):
    # The cases are ASCII save strings; escaping is for Java source, not a shell.
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def parser_probe(src):
    pieces = []
    for name in ("LegacyItem", "LegacySnapshot"):
        record = re.search(r"    private record " + name + r"\([^;{}]+\)\s*\{\s*\}", src)
        if not record:
            raise ValueError("legacy parser record missing: " + name)
        pieces.append(record.group(0))
    for name in ("parseLegacy", "finiteFloat", "nonnegativeInt", "requireType"):
        body = method(src, name)
        if body is None:
            raise ValueError("legacy parser extraction failed: " + name)
        pieces.append(body)
    cases = [(text, True) for text in VALID] + [(text, False) for text in INVALID]
    checks = []
    for i, (text, expected) in enumerate(cases):
        checks.append("check(" + java_literal(text) + ", " + str(expected).lower() + ", " + str(i) + ");")
    return ("public class LegacySnapshotProbe {\n" + "\n".join(pieces) + "\n"
            + "static void check(String value, boolean expected, int index) { boolean valid; "
              "try { parseLegacy(value); valid = true; } catch (RuntimeException error) { valid = false; } "
              "if (valid != expected) { System.out.println(\"FAIL case=\" + index + \" expected=\" + expected + \" value=\" + value); System.exit(1); } }\n"
            + "public static void main(String[] args) { " + " ".join(checks)
            + ' System.out.println("PASS legacy cases=' + str(len(cases)) + '"); }\n}\n')


def run_probe(src, javac, java, directory):
    work = pathlib.Path(directory)
    source = work / "LegacySnapshotProbe.java"
    source.write_text(parser_probe(src), encoding="utf-8")
    compiled = subprocess.run([str(javac), "-d", str(work), str(source)],
                              capture_output=True, text=True, timeout=60)
    if compiled.returncode:
        raise RuntimeError("legacy parser probe did not compile: " + compiled.stderr)
    result = subprocess.run([str(java), "-cp", str(work), "LegacySnapshotProbe"],
                            capture_output=True, text=True, timeout=30)
    return result.returncode, result.stdout.strip() + result.stderr.strip()


def usable(command):
    if not command:
        return False
    try:
        result = subprocess.run([str(command), "-version"], capture_output=True,
                                text=True, timeout=10)
        return result.returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def main():
    if not SRC.exists() or not NATIVE.exists():
        print("FAULT: snapshot adapter or native owner is missing")
        return 1
    src = SRC.read_text(encoding="utf-8")
    native = NATIVE.read_text(encoding="utf-8")
    faults = source_faults(src, native)
    source_controls = [
        ("capture", "return SAONativeSnapshot.capture(shell);", 'return "";'),
        ("native validation", "return SAONativeSnapshot.validate(packed);", "return true;"),
        ("native restore", "SAONativeSnapshot.restore(shell, packed)", "0"),
        ("zero-hour meals", "while (elapsedHours > 0 && hungerAfter > 0.5f)", "while (hungerAfter > 0.5f)"),
        ("missing item", 'throw new IllegalStateException("legacy item type unavailable: " + entry.type);', "continue;")]
    for name, original, replacement in source_controls:
        mutated = src.replace(original, replacement, 1)
        if mutated == src or not source_faults(mutated, native):
            faults.append("CONTROL did not reject altered " + name)
    jdk = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
    javac = jdk / "javac.exe" if (jdk / "javac.exe").exists() else shutil.which("javac")
    java = jdk / "java.exe" if (jdk / "java.exe").exists() else shutil.which("java")
    if not usable(javac) or not usable(java):
        print("SKIPPED: legacy parser execution needs a JDK; source contract checked")
    else:
        try:
            with tempfile.TemporaryDirectory(prefix="sao-hibernation-pact-") as tmp:
                code, output = run_probe(src, javac, java, tmp)
                if code or "PASS legacy cases=" not in output:
                    faults.append("legacy parser: " + output)
                else:
                    print(output)
                controls = [
                    ("finite guard", 'if (!Float.isFinite(parsed)) throw new IllegalArgumentException("nonfinite legacy body value");', ""),
                    ("zero count", 'if (count == 0) throw new IllegalArgumentException("zero legacy item count");', ""),
                    ("unknown field", "!allowed.contains(key) || ", ""),
                    ("condition range", 'if (condition > 100) throw new IllegalArgumentException("legacy condition exceeds percent range");', "")]
                for name, original, replacement in controls:
                    mutated = src.replace(original, replacement, 1)
                    if mutated == src:
                        faults.append("CONTROL did not change " + name)
                        continue
                    code, output = run_probe(mutated, javac, java, tmp)
                    if code != 1 or not output.startswith("FAIL case="):
                        faults.append("CONTROL did not fail behaviorally for " + name + ": " + output)
                    else:
                        print("CONTROL " + name + ": " + output)
        except (ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
            faults.append(str(error))
    for fault in faults:
        print("FAULT: " + fault)
    if faults:
        return 1
    print("  75) hibernation pact: native envelope delegation and strict legacy reader hold")
    return 0


if __name__ == "__main__":
    sys.exit(main())
