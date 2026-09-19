#!/usr/bin/env python3
"""Replay the recorded substrate counterexamples on the installed Kahlua VM."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile


HERE = Path(__file__).resolve().parent
DEFAULT_ROOT = HERE.parents[2]
DEFAULT_GAME = Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
DEFAULT_JAVA = Path.home() / "Peanut Butter" / "JetBrains" / "Java"
EXPECTED_GRAPH = [
    "RESTORED nil,nil,nil,work,1",
    "REINITIALIZED function,function,function,nil,1",
]
EXPECTED_BODY = (
    "VALUE true,true,nil,NEW_SNAPSHOT,42 / "
    "true,true,nil,OLD_SNAPSHOT,5 / true,true,nil,OLD_SNAPSHOT,5"
)


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--game", type=Path, default=DEFAULT_GAME)
    parser.add_argument("--java-home", type=Path, default=DEFAULT_JAVA)
    parser.add_argument("--receipt", type=Path,
                        help="Also write the JSON result to this file.")
    args = parser.parse_args()
    root, game = args.root.resolve(), args.game.resolve()
    suffix = ".exe" if os.name == "nt" else ""
    javac = args.java_home / "bin" / ("javac" + suffix)
    java = args.java_home / "bin" / ("java" + suffix)
    jar = game / "projectzomboid.jar"
    sources = [
        HERE / "GraphSerializationProbe.java",
        HERE / "body-prelude.lua",
        HERE / "body-cases.lua",
        root / "tools/luacheck/LuaRun.java",
        root / "mod/42.20/media/lua/shared/SAO_GraphPersistence.lua",
        root / "mod/42.20/media/lua/shared/SAO_Branching.lua",
        root / "mod/42.20/media/lua/shared/SAO_Integration.lua",
        root / "mod/42.20/media/lua/client/SAO_Body.lua",
    ]
    receipt = {
        "status": "FAIL", "commands": [], "inputs": [],
        "limits": [
            "Known-defect replay, not a release gate or a complete save test.",
            "Installed Kahlua VM and table serializer; no game/world launched.",
            "Graph dependencies and event registration are explicit substitutes.",
            "Body and bridge are substitutes; shipped Body.release executes.",
            "No physical inventory, render teardown, or whole-game load is tested.",
            "Fresh module initialization explicitly calls Integration.ensure.",
            "The serializer is called directly with observed world version 249.",
            "Passing confirms the recorded defects still reproduce.",
        ],
    }

    try:
        for path in [javac, java, jar, *sources]:
            if not path.is_file():
                raise RuntimeError(f"Required input missing: {path}")
        receipt["inputs"] = [
            {"path": str(path), "sha256": digest(path)}
            for path in [jar, *sources]
        ]
        # Neither the classes nor the engine's Lua source enter the repository.
        with tempfile.TemporaryDirectory(prefix="sao-substrate-replay-") as tmp:
            scratch = Path(tmp)
            classes = scratch / "classes"
            classes.mkdir()
            with zipfile.ZipFile(jar) as archive:
                members = sorted(
                    (name for name in archive.namelist()
                     if name.rsplit("/", 1)[-1] == "stdlib.lua"),
                    key=lambda name: (len(name), name),
                )
                if members:
                    (scratch / "stdlib.lua").write_bytes(archive.read(members[0]))
                    receipt["stdlib_source"] = f"{jar}!/{members[0]}"
                else:
                    stdlib = game / "stdlib.lua"
                    if not stdlib.is_file():
                        raise RuntimeError(
                            "No stdlib.lua in the engine jar or install root")
                    shutil.copyfile(stdlib, scratch / "stdlib.lua")
                    receipt["stdlib_source"] = str(stdlib)
                    receipt["stdlib_note"] = (
                        "Installed jar has no stdlib.lua entry; used its shipped "
                        "install-root companion, copied only into private scratch.")
            receipt["stdlib_sha256"] = digest(scratch / "stdlib.lua")

            def execute(command):
                entry = {"argv": [str(part) for part in command],
                         "cwd": str(scratch), "timeout_seconds": 60}
                receipt["commands"].append(entry)
                completed = subprocess.run(
                    entry["argv"], cwd=scratch, capture_output=True,
                    text=True, encoding="utf-8", errors="replace", timeout=60,
                    check=False,
                )
                entry.update(returncode=completed.returncode,
                             stdout=completed.stdout, stderr=completed.stderr)
                if completed.returncode:
                    raise RuntimeError(
                        f"Command failed ({completed.returncode}): {command[0]}")
                return completed.stdout

            execute([javac, "-encoding", "UTF-8", "-classpath", jar,
                     "-d", classes, sources[0], sources[3]])
            classpath = os.pathsep.join((str(classes), str(jar)))
            graph = execute([java, "-cp", classpath,
                             "GraphSerializationProbe", root])
            graph_lines = graph.splitlines()
            sizes = [int(match.group(1)) for line in graph_lines
                     if (match := re.fullmatch(r"SERIALIZED bytes=(\d+)", line))]
            if len(sizes) != 1 or sizes[0] <= 0:
                raise RuntimeError("Graph probe did not report a nonempty save")
            for expected in EXPECTED_GRAPH:
                if graph_lines.count(expected) != 1:
                    raise RuntimeError(f"Graph result changed: expected {expected}")
            body = execute([java, "-cp", classpath, "LuaRun", sources[1],
                            sources[-1], sources[2], "--", "RESULT"])
            if body.splitlines().count(EXPECTED_BODY) != 1:
                raise RuntimeError("Body release result changed from recorded evidence")
            receipt["checks"] = {
                "serialized_bytes": sizes[0],
                "unsupported_closures_omitted": True,
                "branch_id_and_pattern_preserved": True,
                "builtins_reconstructed_on_initialization": True,
                "extension_requires_own_registration": True,
                "successful_body_capture_control": True,
                "throwing_capture_still_releases_body": True,
                "empty_capture_still_releases_body": True,
            }
        receipt["status"] = "PASS: recorded counterexamples reproduced"
    except (OSError, RuntimeError, subprocess.TimeoutExpired,
            zipfile.BadZipFile) as error:
        receipt["error"] = str(error)

    rendered = json.dumps(receipt, indent=2)
    if args.receipt:
        args.receipt.write_text(rendered + "\n", encoding="utf-8")
    print(rendered)
    return 0 if receipt["status"].startswith("PASS:") else 1


if __name__ == "__main__":
    sys.exit(main())
