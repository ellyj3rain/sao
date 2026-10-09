"""Compile the Week One private store against the installed game and test save IO with stubs.

The game is not started. Fixtures and compiler output stay under --output.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
GAME = Path(os.environ.get("PZ_DIR", "C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid"))
JDK = Path(os.environ.get("JDK_BIN", str(Path.home() / "Peanut Butter/JetBrains/Java/bin")))
SOURCE = ROOT / "java/src/com/sao/engine/SAOWeekOnePrivateStore.java"
BRIDGE = ROOT / "java/src/com/sao/bridge/SAOBridge.java"
PROBE = ROOT / "tools/weekone_private_store_java/PrivateStoreProbe.java"
STUBS = {
    "zombie/ZomboidFileSystem.java": (
        "package zombie; public final class ZomboidFileSystem {"
        "public static final ZomboidFileSystem instance = new ZomboidFileSystem();"
        "public String directory; public String getCurrentSaveDir() { return directory; }}"
    ),
    "zombie/network/GameClient.java": (
        "package zombie.network; public final class GameClient {"
        "public static boolean client; }"
    ),
}


def pin(path: Path) -> dict:
    data = path.read_bytes()
    return {"path": str(path), "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def main(output: Path) -> int:
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    dependency = GAME / "projectzomboid.jar"
    sources = [SOURCE, BRIDGE, PROBE, ROOT / "VERSION", Path(__file__).resolve()]
    before = [pin(path) for path in sources]
    for path in [dependency, JDK / "javac.exe", JDK / "java.exe"]:
        if not path.is_file():
            raise FileNotFoundError(path)
    stub_sources = output / "stub-source"
    for name, body in STUBS.items():
        path = stub_sources / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(body, encoding="utf-8")
    stub_classes = output / "stub-classes"
    product_classes = output / "product-classes"
    stub_classes.mkdir()
    product_classes.mkdir()
    results = []

    def run(label: str, args: list[Path | str]) -> subprocess.CompletedProcess[str]:
        proc = subprocess.run([str(arg) for arg in args], text=True,
                              capture_output=True, check=False)
        stdout = output / f"{label}.stdout.log"
        stderr = output / f"{label}.stderr.log"
        stdout.write_text(proc.stdout, encoding="utf-8")
        stderr.write_text(proc.stderr, encoding="utf-8")
        results.append({"label": label, "exitCode": proc.returncode,
                        "stdout": pin(stdout), "stderr": pin(stderr)})
        print(f"{label}: {proc.returncode}", flush=True)
        return proc

    run("installed-api-compile", [JDK / "javac.exe", "-cp", dependency,
        "-d", product_classes, SOURCE])
    generated = output / "generated/com/sao/SAOVersion.java"
    generated.parent.mkdir(parents=True)
    version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
    generated.write_text(
        "package com.sao; public final class SAOVersion { "
        f'public static final String VALUE = "{version}"; }}\n', encoding="utf-8")
    bridge_classes = output / "bridge-classes"
    bridge_classes.mkdir()
    bridge_cp = os.pathsep.join([str(dependency), str(GAME / "ZombieBuddy.jar")])
    bridge_sources = os.pathsep.join([str(ROOT / "java/src"), str(output / "generated")])
    run("bridge-installed-api-compile", [JDK / "javac.exe", "-cp", bridge_cp,
        "-sourcepath", bridge_sources, "-d", bridge_classes, BRIDGE, generated])
    run("stub-compile", [JDK / "javac.exe", "-d", stub_classes,
        *sorted(stub_sources.rglob("*.java"))])
    if all(row["exitCode"] == 0 for row in results):
        cp = os.pathsep.join([str(stub_classes), str(product_classes)])
        run("probe-compile", [JDK / "javac.exe", "-cp", cp,
            "-d", stub_classes, PROBE])
        if results[-1]["exitCode"] == 0:
            fixture = output / "fixture"
            fixture.mkdir()
            run("probe", [JDK / "java.exe", "-cp", cp,
                "PrivateStoreProbe", fixture])
            if results[-1]["exitCode"] == 0:
                mutation_source = output / "mutation/com/sao/engine/SAOWeekOnePrivateStore.java"
                mutation_source.parent.mkdir(parents=True)
                original = SOURCE.read_text(encoding="utf-8")
                guard = 'if (GameClient.client) return "REFUSED";'
                if original.count(guard) != 4:
                    raise AssertionError("client guard count changed")
                mutation_source.write_text(original.replace(
                    guard, 'if (false) return "REFUSED";'), encoding="utf-8")
                mutation_classes = output / "mutation-classes"
                mutation_classes.mkdir()
                run("inverse-compile", [JDK / "javac.exe", "-cp", dependency,
                    "-d", mutation_classes, mutation_source])
                if results[-1]["exitCode"] == 0:
                    inverse_cp = os.pathsep.join([str(stub_classes), str(mutation_classes)])
                    inverse_fixture = output / "inverse-fixture"
                    inverse_fixture.mkdir()
                    run("inverse-probe", [JDK / "java.exe", "-cp", inverse_cp,
                        "PrivateStoreProbe", inverse_fixture])
                path_read = "if (!MessageDigest.isEqual(bound, identity))"
                path_write = "out.write(identity);"
                if original.count(path_read) != 1 or original.count(path_write) != 2:
                    raise AssertionError("save-local identity header binding changed")
                path_mutation = output / "path-mutation/com/sao/engine/SAOWeekOnePrivateStore.java"
                path_mutation.parent.mkdir(parents=True)
                path_hash = "hash(save.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8))"
                path_mutation.write_text(original.replace(path_read,
                    f"if (!MessageDigest.isEqual(bound, {path_hash}))").replace(
                    path_write, f"out.write({path_hash});", 1), encoding="utf-8")
                path_classes = output / "path-mutation-classes"
                path_classes.mkdir()
                run("portability-inverse-compile", [JDK / "javac.exe", "-cp", dependency,
                    "-d", path_classes, path_mutation])
                if results[-1]["exitCode"] == 0:
                    path_cp = os.pathsep.join([str(stub_classes), str(path_classes)])
                    path_fixture = output / "path-inverse-fixture"
                    path_fixture.mkdir()
                    run("portability-inverse-probe", [JDK / "java.exe", "-cp", path_cp,
                        "PrivateStoreProbe", path_fixture])
    after = [pin(path) for path in sources]
    probe = next((row for row in results if row["label"] == "probe"), None)
    passing = 0
    reported = None
    if probe is not None:
        text = Path(probe["stdout"]["path"]).read_text(encoding="utf-8")
        passing = len(re.findall(r"^PASS ", text, re.MULTILINE))
        match = re.search(r"^CHECKS (\d+) FAILURES (\d+)$", text, re.MULTILINE)
        if match:
            reported = {"checks": int(match.group(1)), "failures": int(match.group(2))}
    inverse = next((row for row in results if row["label"] == "inverse-probe"), None)
    inverse_reason = ""
    if inverse is not None:
        inverse_reason = Path(inverse["stderr"]["path"]).read_text(encoding="utf-8")
    path_inverse = next((row for row in results if row["label"] == "portability-inverse-probe"), None)
    path_inverse_reason = ""
    if path_inverse is not None:
        path_inverse_reason = Path(path_inverse["stderr"]["path"]).read_text(encoding="utf-8")
    expected_inverses = {"inverse-probe", "portability-inverse-probe"}
    status = ("PASS" if len(results) == 9
              and all(row["exitCode"] == 0 for row in results
                      if row["label"] not in expected_inverses)
              and inverse is not None and inverse["exitCode"] != 0
              and "client-read-refused: expected REFUSED" in inverse_reason
              and path_inverse is not None and path_inverse["exitCode"] != 0
              and "copied-save-retired: expected RETIRED" in path_inverse_reason
              and before == after and reported == {"checks": passing, "failures": 0}
              else "FAIL")
    receipt = {"schema": "sao.weekone-private-store-java-test/1",
               "status": status,
               "scope": "installed PZ API compile and synthetic isolated save directories, complete save copy and sidecar transplant; no game or dedicated server acceptance",
               "sourcesBefore": before, "sourcesAfter": after,
               "gameJar": pin(dependency), "results": results,
               "passingControls": passing, "reported": reported,
               "inverse": {"fault": "client guard removed in isolated copy",
                           "expectedFailureObserved":
                           "client-read-refused: expected REFUSED" in inverse_reason},
               "portabilityInverse": {"fault": "absolute save path restored as sidecar header binding",
                                      "expectedFailureObserved":
                                      "copied-save-retired: expected RETIRED" in path_inverse_reason}}
    receipt_path = output / "receipt.json"
    receipt_path.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": status, "controls": passing,
                      "receipt": pin(receipt_path)}), flush=True)
    return 0 if status == "PASS" else 1


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    raise SystemExit(main(args.output))
