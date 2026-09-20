#!/usr/bin/env python3
r"""Border 50 - compile shipped Lua with the installed engine in both modes.

The live development launcher enables Core.debug. Kahlua's debug compiler
records cumulative locals in a fixed array even when simultaneous locals fit;
C58's normal-only check missed the resulting load refusal. Every file therefore
needs one explicit normal and one debug verdict. Real malformed-source and
200/201-local controls establish compiler behavior; a compiled mode-omission
mutation and damaged reports establish that incomplete evidence is refused.

The Java helper is compiled privately per run. Missing engine/JDK is SKIPPED;
missing repository source, empty input, or incomplete output is a failure.
"""
import pathlib
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
SRC = ROOT / "tools" / "luacheck" / "LuaSyntax.java"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"
    r"\projectzomboid.jar")
MODES = ("normal", "debug")
ARRAY_REFUSAL = "ArrayIndexOutOfBoundsException: Index 200 out of bounds for length 200"


def build(source, classes):
    classes.mkdir(parents=True, exist_ok=True)
    done = subprocess.run(
        [str(JDK / "javac.exe"), "-cp", str(PZ), "-d", str(classes), str(source)],
        capture_output=True, text=True, timeout=300)
    if done.returncode:
        raise RuntimeError("could not build the checker: " + done.stderr.strip())


def compile_files(classes, files):
    return subprocess.run(
        [str(JDK / "java.exe"), "-cp", f"{PZ};{classes}", "LuaSyntax"]
        + [str(path) for path in files],
        capture_output=True, text=True, timeout=600)


def verify_report(done, files, refusals=None):
    """Require each requested (path, mode), expected outcome, and process exit."""
    refusals = refusals or {}
    expected = {(str(path), mode) for path in files for mode in MODES}
    faults, seen = [], set()
    if not expected:
        faults.append("no shipped Lua files to compile; an empty set cannot pass")
    for line in done.stdout.splitlines():
        fields = line.split("\t")
        if not (len(fields) == 3 and fields[0] == "OK"
                or len(fields) == 4 and fields[0] == "FAIL" and fields[3]):
            faults.append(f"malformed compiler verdict: {line!r}")
            continue
        status, mode, path = fields[:3]
        key = (path, mode)
        if key not in expected or key in seen:
            faults.append(f"unexpected or repeated compiler verdict: {mode} {path}")
            continue
        seen.add(key)
        refusal = refusals.get(key)
        if refusal is not None:
            if status != "FAIL" or refusal not in fields[3]:
                faults.append(f"{mode} {path}: expected compiler refusal {refusal!r}, got {line!r}")
        elif status != "OK":
            faults.append(f"{mode} {path}: {fields[3]} - the engine refuses this file")
    for path, mode in sorted(expected - seen):
        faults.append(f"missing compiler verdict: {mode} {path}")
    wanted_exit = 1 if refusals else 0
    if done.returncode != wanted_exit:
        faults.append(f"compiler process exited {done.returncode}; expected {wanted_exit}")
    if faults and done.stderr.strip():
        faults.append("compiler stderr: " + done.stderr.strip()[:1500])
    return faults


def controls(work, classes):
    cases = work / "cases"
    cases.mkdir()
    syntax = cases / "malformed.lua"
    syntax.write_text("return )\n", encoding="utf-8")
    boundary = cases / "locals-200.lua"
    boundary.write_text("do local value = 1 end\n" * 200, encoding="utf-8")
    overflow = cases / "locals-201.lua"
    overflow.write_text("do local value = 1 end\n" * 201, encoding="utf-8")
    files = [syntax, boundary, overflow]
    refusals = {(str(syntax), mode): "unexpected symbol" for mode in MODES}
    refusals[(str(overflow), "debug")] = ARRAY_REFUSAL
    actual = compile_files(classes, files)
    faults = verify_report(actual, files, refusals)
    if faults:
        return ["compiler control: " + fault for fault in faults]

    # Remove the actual debug compile pass, then require the ordinary report
    # verifier to name its absent mode. This is a compiled driver mutation.
    before = "for (boolean debug : new boolean[] {false, true})"
    source = SRC.read_text(encoding="utf-8")
    if source.count(before) != 1:
        return ["mode-omission control could not locate its single mutation target"]
    mutant = work / "normal-only"
    mutant.mkdir()
    mutant_source = mutant / "LuaSyntax.java"
    mutant_source.write_text(source.replace(before,
        "for (boolean debug : new boolean[] {false})", 1), encoding="utf-8")
    build(mutant_source, mutant / "classes")
    omitted = verify_report(compile_files(mutant / "classes", files), files, refusals)
    if not any(fault.startswith("missing compiler verdict: debug ") for fault in omitted):
        faults.append("mode-omission control accepted a driver without debug compilation")

    # Damage a real passing boundary report, keeping the same validation path.
    accepted = compile_files(classes, [boundary])
    accepted_faults = verify_report(accepted, [boundary])
    if accepted_faults:
        return faults + ["200-local control: " + fault for fault in accepted_faults]
    damaged = {
        "nonzero process": (9, accepted.stdout, "compiler process exited 9"),
        "empty report": (0, "", "missing compiler verdict:"),
        "truncated report": (0, accepted.stdout.splitlines()[0] + "\nOK\tdebug\n",
                             "malformed compiler verdict:"),
        "repeated mode": (0, accepted.stdout.replace("\tdebug\t", "\tnormal\t"),
                          "unexpected or repeated compiler verdict:"),
    }
    for name, (code, stdout, reason) in damaged.items():
        result = subprocess.CompletedProcess(accepted.args, code, stdout, "")
        if not any(fault.startswith(reason) for fault in verify_report(result, [boundary])):
            faults.append(f"{name} control did not refuse damaged compiler evidence")
    return faults


def main():
    print("=" * 74)
    print("THE ENGINE'S OWN PARSER, NORMAL AND DEBUG MODES")
    print("=" * 74)
    faults = []
    files = sorted(LUA.rglob("*.lua"))
    if not SRC.is_file():
        faults.append("missing repository checker source: " + str(SRC))
    if not files:
        faults.append("no shipped Lua files to compile; an empty set cannot pass")
    if not faults and not (PZ.is_file() and (JDK / "java.exe").is_file()
                           and (JDK / "javac.exe").is_file()):
        print("  50) lua syntax: SKIPPED, engine or JDK absent")
        return 0
    if not faults:
        try:
            with tempfile.TemporaryDirectory(prefix="sao-lua-syntax-") as temporary:
                work = pathlib.Path(temporary)
                classes = work / "classes"
                build(SRC, classes)
                faults.extend(controls(work, classes))
                if not faults:
                    print("  controls: malformed syntax; 200/201 locals in both modes; "
                          "compiled mode omission; nonzero, empty, truncated and repeated reports")
                    done = compile_files(classes, files)
                    faults.extend(verify_report(done, files))
        except (OSError, subprocess.SubprocessError, RuntimeError) as error:
            faults.append("compiler check could not complete: " + str(error))
    print("\nVERDICT:")
    if faults:
        for fault in faults:
            print("  FAULT: " + fault)
        return 1
    print(f"  50) lua syntax: all {len(files)} shipped Lua files compile in normal "
          f"and debug modes ({len(files) * len(MODES)} verified verdicts)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
