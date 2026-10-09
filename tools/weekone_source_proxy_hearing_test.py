#!/usr/bin/env python3
"""Actual Week One source callback into private hearing, without game launch."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

from weekone_continuity_test import GAME, JDK, PRELUDE, ROOT, SOURCE

CASES = ROOT / "tools/weekone_source_proxy_hearing_cases.lua"
RUNNER = ROOT / "tools/luacheck/LuaRun.java"
CONTROLS = (
    ("callback", "        W.observeLoadedPerformanceHearings()\n",
     "        -- omitted source-proxy hearing callback\n",
     "first source-proxy callback missed native acquisition before personal claim"),
    ("scanner", "return SAOJavaBridge:perceiveAudibleSounds(body)",
     "return true",
     "first source-proxy callback missed native acquisition before personal claim"),
    ("generation", "if exact == body and actualBrain == brain then",
     "if true then",
     "changed source brain generation borrowed the person's hearing"),
    ("distance", "if id ~= performance.id and dx * dx + dy * dy <= 16 * 16 then",
     "if id ~= performance.id then",
     "distant performance triggered a source-proxy scanner claim"),
)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--baseline-only", action="store_true")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    inputs = [SOURCE, CASES, RUNNER, Path(__file__),
              GAME / "projectzomboid.jar", GAME / "stdlib.lua"]
    if not all(path.is_file() for path in inputs +
               [JDK / "java.exe", JDK / "javac.exe"]):
        raise RuntimeError("required current Kahlua/JDK or source is missing")
    pins = {str(path): sha(path) for path in inputs}
    receipt = {"status": "INCOMPLETE", "inputSha256": pins, "runs": [],
               "boundary": "Actual Week One source callback, existing SAO person crosswalk, native scanner and hearing methods controlled; source proxy cache and sound action controlled. No game or rendered claim."}

    def save():
        (output / "receipt.json").write_text(
            json.dumps(receipt, indent=2) + "\n", encoding="utf-8")

    try:
        with tempfile.TemporaryDirectory(prefix="sao-weekone-proxy-hearing-") as temp:
            work = Path(temp)
            (work / "stdlib.lua").write_bytes((GAME / "stdlib.lua").read_bytes())
            built = subprocess.run([str(JDK / "javac.exe"), "-cp",
                str(GAME / "projectzomboid.jar"), "-d", str(work), str(RUNNER)],
                capture_output=True, text=True, timeout=120)
            if built.returncode:
                raise RuntimeError("LuaRun compile: " + built.stderr)
            (work / "prelude.lua").write_text(PRELUDE, encoding="utf-8")
            cases = "function __cases()\n" + CASES.read_text(encoding="utf-8") + \
                "\nend\nfunction __safe() local ok,value=pcall(__cases) " + \
                "if ok then return value end return 'FAIL:'..tostring(__step)..':'..tostring(value) end"
            (work / "cases.lua").write_text(cases, encoding="utf-8")
            source = SOURCE.read_text(encoding="utf-8")

            def run(name, current):
                (work / "source.lua").write_text(current, encoding="utf-8")
                done = subprocess.run([str(JDK / "java.exe"), "-cp",
                    str(GAME / "projectzomboid.jar") + ";" + str(work),
                    "LuaRun", str(work / "prelude.lua"), str(work / "source.lua"),
                    str(work / "cases.lua"), "--", "__safe()"], cwd=work,
                    capture_output=True, text=True, timeout=90)
                log = output / (name + ".log")
                log.write_text(done.stdout + done.stderr, encoding="utf-8")
                receipt["runs"].append({"name": name, "exit": done.returncode,
                    "logSha256": sha(log)})
                save()
                return done.returncode, done.stdout + done.stderr

            code, message = run("baseline", source)
            if code or "VALUE PASS source proxy first-callback hearing" not in message:
                raise AssertionError("source-proxy baseline: " + message[-2500:])
            if not args.baseline_only:
                for name, before, after, expected in CONTROLS:
                    if source.count(before) != 1:
                        raise AssertionError("inverse anchor count: " + name)
                    code, message = run(name, source.replace(before, after, 1))
                    if "VALUE FAIL:" not in message or expected not in message:
                        raise AssertionError(name + " missed its cause: " + message[-2500:])
            if pins != {str(path): sha(path) for path in inputs}:
                raise AssertionError("source changed during focused proof")
            receipt["status"] = "PASS"
            save()
    except BaseException as error:
        receipt["error"] = f"{type(error).__name__}: {error}"
        save()
        raise
    print(f"PASS source-proxy hearing: 1 first-callback case and {len(receipt['runs'])-1} inverses")
    print(output / "receipt.json")


if __name__ == "__main__":
    main()
