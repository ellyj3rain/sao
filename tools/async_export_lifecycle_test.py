#!/usr/bin/env python3
"""Border 222: installed-VM asynchronous producer and acknowledgement controls."""
from __future__ import annotations

import os
from pathlib import Path
import shutil
import subprocess
import tempfile

import world_lab as Lab

GAME = Path(os.environ.get("PZ_DIR", r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"))
_javac = shutil.which("javac")
_jdk_candidates = [Path(os.environ["JAVA_HOME"]) / "bin"] if os.environ.get("JAVA_HOME") else []
if _javac: _jdk_candidates.append(Path(_javac).parent)
_jdk_candidates.append(Path.home() / "Peanut Butter" / "JetBrains" / "Java" / "bin")
JDK = Path(os.environ["JDK_BIN"]) if os.environ.get("JDK_BIN") else next(
    (candidate for candidate in _jdk_candidates if (candidate / "javac.exe").is_file()), _jdk_candidates[-1])


def run():
    jar = GAME / "projectzomboid.jar"
    if not jar.is_file() or not (JDK / "javac.exe").is_file():
        print("SKIPPED async producer: installed game or JDK unavailable")
        return
    source = Lab.TEMPLATE.read_text(encoding="utf-8")
    checks = (Lab.ROOT / "tools/world_lab/RuntimeChecks.lua").read_text(encoding="utf-8")
    checks += "\n" + (Lab.ROOT / "tools/world_lab/AsyncExportChecks.lua").read_text(encoding="utf-8")
    config = Lab.load(Lab.ROOT / "tools/world_lab/definition.example.json")
    config.update(mapName="AsyncStudy", definitionSha256="a" * 64,
                  engineJarSha256="b" * 64, observerSha256="c" * 64)
    with tempfile.TemporaryDirectory(prefix="async-producer-") as directory:
        work = Path(directory)
        result = subprocess.run([str(JDK / "javac.exe"), "-cp", str(jar), "-d", str(work),
            str(Lab.ROOT / "tools/luacheck/LuaRun.java")], cwd=GAME, capture_output=True, text=True)
        Lab.require(result.returncode == 0, result.stdout + result.stderr)

        def execute(runtime, treatment="normal"):
            script = work / "checks.lua"
            script.write_text("local Config = " + Lab.lua(config) + "\n" + checks
                + "\nlocal Study = (function()\n" + runtime + "\nend)()\n"
                + "RESULT = RunAsyncExportChecks(Study, " + Lab.lua(treatment) + ")\n", encoding="utf-8")
            return subprocess.run([str(GAME / "jre64/bin/java.exe"), "-Djava.awt.headless=true",
                "-cp", str(jar) + os.pathsep + str(work), "LuaRun", str(script), "--", "RESULT"],
                cwd=GAME, capture_output=True, text=True, timeout=60)

        for treatment in ("normal", "foreign-live", "foreign-archive", "failed-archive"):
            result = execute(source, treatment)
            Lab.require(result.returncode == 0 and "VALUE PASS" in result.stdout,
                        result.stdout + result.stderr)
            print(result.stdout.strip())
        controls = (
            ("mobile situation composition", 'receipt.schema, receipt.kind, receipt.phase = 1, "mobile-household-loaded", "spawn"',
             'receipt.schema, receipt.kind = 1, "mobile-household-loaded"', "normal",
             "mobile composition lost phase or retained situation receipts"),
            ("archive acknowledgement", "state.sequence = pending.sequence",
             "state.sequence = pending.sequence + 1", "normal", "archive acknowledged wrong sequence"),
            ("completion cooldown", "lastLiveAt = exportOwner:receiptCompletedAt(pending.ticket)",
             "lastLiveAt = 0", "normal", "live completion bypassed post-publication cooldown"),
            ("live provenance", 'assert(exportOwner:receiptKey(pending.ticket) == pending.key, "live export receipt changed owner")',
             '-- foreign live owner accepted', "foreign-live", "foreign live receipt accepted"),
            ("archive sequence", 'assert(exportOwner:receiptSequence(pending.ticket) == pending.sequence,\n                "archive export receipt changed sequence")',
             '-- foreign archive sequence accepted', "foreign-archive", "foreign archive sequence accepted"),
            ("drain admission", "exportStopping = true", "exportStopping = false", "normal",
             "draining producer admitted new exports"),
        )
        for label, old, new, treatment, reason in controls:
            Lab.require(source.count(old) == 1, "async control seam differs: " + label)
            mutant = source.replace(old, new)
            Lab.require(mutant != source, "async mutation did not land: " + label)
            result = execute(mutant, treatment)
            Lab.require(result.returncode != 0 and reason in result.stdout + result.stderr,
                        "async control survived or failed for wrong reason: " + label
                        + "\n" + result.stdout + result.stderr)
            print("PASS control refused: " + label)
    print("LIMIT controlled completion seam; native worker and loaded rate are separate checks")


def main():
    try:
        run()
    except Exception as failure:
        print("FAULT asynchronous observation lifecycle:", failure)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
