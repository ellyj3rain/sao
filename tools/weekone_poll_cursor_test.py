"""Exercise the shipped Java Week One cursor and its preserved rejected preimage."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
GAME = Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
JDK = Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
SOURCE = ROOT / "java/src/com/sao/engine/SAOWeekOnePollCursor.java"
PROBE = ROOT / "tools/WeekOnePollCursorProbe.java"
DIST = ROOT / "java/dist/SAOAgent.jar"
SHIPPED = ROOT / "mod/42.20/media/java/SAO.jar"
PREIMAGE = ROOT / "_scratch/d2-leisure-01/cursor-allowlist-20261008/preimage/SAO.jar"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def invoke(args, cwd):
    run = subprocess.run([str(arg) for arg in args], cwd=cwd,
                         capture_output=True, text=True, timeout=90)
    return {"exit": run.returncode, "output": run.stdout + run.stderr}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    paths = [SOURCE, PROBE, Path(__file__), DIST, SHIPPED, PREIMAGE,
             GAME / "projectzomboid.jar", GAME / "ZombieBuddy.jar",
             GAME / "stdlib.lua", JDK / "javac.exe", JDK / "java.exe"]
    absent = [str(path) for path in paths if not path.is_file()]
    if absent:
        raise RuntimeError("missing cursor proof input: " + ", ".join(absent))
    if sha(DIST) != sha(SHIPPED):
        raise RuntimeError("source and shipped agent jars differ")
    pins = {str(path): sha(path) for path in paths}
    receipt = {"schema": "sao-weekone-poll-cursor-proof/1", "status": "INCOMPLETE",
               "inputs": pins, "runs": [],
               "boundary": "Shipped Kahlua and Java bridge stream admission and bounded raw iteration; no loaded game or fairness guarantee under sustained cache mutation."}

    def save():
        (out / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n",
                                          encoding="utf-8")

    save()
    shutil.copyfile(GAME / "stdlib.lua", out / "stdlib.lua")
    common = [GAME / "projectzomboid.jar", GAME / "ZombieBuddy.jar"]
    current_cp = ";".join(map(str, [*common, SHIPPED]))
    compile_run = invoke([JDK / "javac.exe", "-encoding", "UTF-8", "-cp",
                          current_cp, "-d", out, PROBE], out)
    receipt["runs"].append({"name": "compile", **compile_run})
    save()
    if compile_run["exit"]:
        raise RuntimeError("cursor probe compile failed")
    for name, jar, expected_exit, expected_text in [
        ("shipped", SHIPPED, 0, "PASS dense Lua [1]/[2]"),
        ("preimage-rejected", PREIMAGE, 1, "current performance row stream refused"),
    ]:
        cp = ";".join(map(str, [out, *common, jar]))
        run = invoke([JDK / "java.exe", "-cp", cp,
                      "WeekOnePollCursorProbe"], out)
        receipt["runs"].append({"name": name, "jarSha256": sha(jar), **run})
        save()
        if run["exit"] != expected_exit or expected_text not in run["output"]:
            raise RuntimeError(name + " cursor result differs: " + run["output"])
    if {str(path): sha(path) for path in paths} != pins:
        raise RuntimeError("cursor source changed during proof")
    receipt["status"] = "PASS"
    save()
    print("PASS shipped cursor streams, dense Kahlua bridge, bounded 1200-key sweep; preimage rejects")


if __name__ == "__main__":
    main()
