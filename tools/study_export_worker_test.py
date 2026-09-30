#!/usr/bin/env python3
"""Border 222: actual installed Kahlua exposure, immutable worker and native bytes."""
from __future__ import annotations

import os
from pathlib import Path
import subprocess
import tempfile

import world_lab as Lab

GAME = Path(os.environ.get("PZ_DIR", r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"))
JDK = Path(os.environ.get("JDK_BIN", str(Path.home() / "Peanut Butter/JetBrains/Java/bin")))

TRIALS = r'''
__marker = arrayMeta
__encode = function(value) return json(value) end
__count = function(value) local budget={left=64*1024*1024}; json(value,nil,budget); return 64*1024*1024-budget.left end
local emptyArray = array()
local sparse = array(); sparse[1] = "first"; sparse[3] = "third"
local controls = ""; for i=0,31 do controls=controls..string.char(i) end
__trials = {
    {}, emptyArray, {true,false,4}, sparse,
    {[1]="first",[3]="third"}, {[1]="one",title="mixed"},
    {z="last",a="first",[true]="boolean",[2.5]="number"},
    "plain", "café", "水", "🙂", 'quote"slash\\'..controls,
    {numbers={0,-0,1.25,1e20,1e-12,9007199254740991}, nested={tags=emptyArray}},
    {unicodeKeys={['水']="value",['🙂']="face"}}
}
__saveName = "Säv水🙂"
__saveHex = (__saveName:gsub('.',function(c) return string.format('%02x',string.byte(c)) end))
'''


def run():
    jar = GAME / "projectzomboid.jar"
    if not jar.is_file() or not (JDK / "javac.exe").is_file():
        print("SKIPPED async worker: installed game or JDK unavailable")
        return
    source = (Lab.ROOT / "tools/world_lab/StudyWorld.lua").read_text(encoding="utf-8")
    prefix = source.split("local function jsonFits(value, budget)", 1)[0]
    Lab.require(prefix != source, "production encoder extraction seam missing")
    helper = (Lab.ROOT / "tools/world_lab/StudyExport.java").read_text(encoding="utf-8")
    with tempfile.TemporaryDirectory(prefix="study-export-worker-") as directory:
        work = Path(directory)
        fixture = work / "checks.lua"
        fixture.write_text(prefix + "\n" + TRIALS, encoding="utf-8")
        classpath = str(jar) + os.pathsep + str(GAME / "ZombieBuddy.jar")
        names = ("StudyExport.java", "StudyObserver.java", "StudyViewCapture.java", "NativeAsyncStudyExportProbe.java")

        observer = (Lab.ROOT / "tools/world_lab/StudyObserver.java").read_text(encoding="utf-8")

        def execute(text, label, observer_text=observer, treatment="normal"):
            lane = work / label; lane.mkdir()
            (lane / "StudyExport.java").write_text(text, encoding="utf-8")
            (lane / "StudyObserver.java").write_text(observer_text, encoding="utf-8")
            inputs = [lane / "StudyExport.java", lane / "StudyObserver.java"] + [Lab.ROOT / "tools/world_lab" / name for name in names[2:]]
            result = subprocess.run([str(JDK / "javac.exe"), "-cp", classpath, "-d", str(lane), *map(str, inputs)],
                cwd=GAME, capture_output=True, text=True, timeout=60)
            Lab.require(result.returncode == 0, result.stdout + result.stderr)
            cache = lane / "cache"; cache.mkdir()
            return subprocess.run([str(GAME / "jre64/bin/java.exe"), "-Djava.awt.headless=true", "-cp",
                classpath + os.pathsep + str(lane), "NativeAsyncStudyExportProbe", str(fixture), str(cache), treatment],
                cwd=GAME, capture_output=True, text=True, timeout=90)

        result = execute(helper, "normal")
        Lab.require(result.returncode == 0 and "VALUE PASS" in result.stdout, result.stdout + result.stderr)
        timing_lines = [line[len("TIMING_JSON "):] for line in result.stdout.splitlines() if line.startswith("TIMING_JSON ")]
        Lab.require(len(timing_lines) == 1, "native timing snapshot missing or repeated")
        timing = Lab.decode(timing_lines[0])
        units = {"ownerMeasure": "nodes", "ownerDetach": "nodes", "workerEncode": "output-bytes",
                 "workerWrite": "input-bytes", "workerReadback": "input-bytes", "workerPromote": "files"}
        Lab.require(timing["schema"] == "sao-study-export-timing/1" and timing["inclusive"] is True
                    and type(timing["capturedAtUnixMs"]) is int and timing["capturedAtUnixMs"] > 0
                    and set(timing["stages"]) == set(units), "diagnostic scope or fixed keys differ")
        for name, row in timing["stages"].items():
            Lab.require(row["unit"] == units[name] and isinstance(row["clipped"], bool), "diagnostic quantity units differ")
            for field in ("calls", "totalNs", "maximumNs", "examined", "failures", "deferred"):
                Lab.require(type(row[field]) is int and 0 <= row[field] <= 9007199254740991, "diagnostic integer bound differs")
            Lab.require(row["maximumNs"] <= row["totalNs"] and row["failures"] <= row["calls"]
                        and row["deferred"] <= row["calls"], "diagnostic counter row is incoherent")
        Lab.require("SLOW Lua event callback" in result.stdout + result.stderr
                    and "native-slow-callback-probe" in result.stdout + result.stderr,
                    "installed inclusive callback timing was not exercised\n" + (result.stdout + result.stderr)[-2800:])
        print(result.stdout.strip())
        controls = (
            ("budget", "charge(KahluaUtil.numberToString(number).length());", "charge(0);", "production Lua exact UTF-8 bytes 3"),
            ("pending", 'if ("pending".equals(receipt.status)) throw new IllegalStateException("pending export cannot be released");',
             'if (false) throw new IllegalStateException("pending export cannot be released");', "pending publication cannot be acknowledged accepted"),
            ("epoch", "if (closed || epoch != receipt.epoch || Thread.currentThread().isInterrupted()) return;",
             "if (closed || Thread.currentThread().isInterrupted()) return;", "retired epoch cannot promote a completed worker snapshot"),
            ("newline", "if (newline) output.append('\\n');", "if (false) output.append('\\n');", "archive JSON plus native newline is byte-identical"),
            ("owner timing", "if (timings != null) timings.record(Stage.OWNER_MEASURE, started,",
             "if (false && timings != null) timings.record(Stage.OWNER_MEASURE, started,",
             "actual byte preflight records one owner sample and examined node"),
            ("retired timing", "encodeMeasured(frame, bytes, archive != null, receipt.epoch.timings())",
             "encodeMeasured(frame, bytes, archive != null, epoch.timings())",
             "retired worker cannot charge a new epoch's diagnostic counters"),
            ("bounded timing", "if (increment > LIMIT - value) { clipped = true; return LIMIT; }",
             "if (increment > LIMIT - value) { clipped = true; return value + increment; }",
             "diagnostic saturation preserves byte result and reports clipping"),
        )
        for label, old, new, reason in controls:
            Lab.require(helper.count(old) == 1, "worker control seam differs: " + label)
            result = execute(helper.replace(old, new), "control-" + label)
            Lab.require(result.returncode != 0 and reason in result.stdout + result.stderr,
                "worker mutation survived or failed for wrong reason: " + label + "\n" + result.stdout + result.stderr)
            print("PASS control refused: " + label)
        write = "temporary.add(path); Files.write(path, data);"
        Lab.require(helper.count(write) == 1, "native temporary write seam differs")
        corrupt = helper.replace(write, write + ' Files.writeString(path, "corrupted readback");')
        result = execute(corrupt, "readback-fault", treatment="corrupt-readback")
        Lab.require(result.returncode == 0 and "VALUE PASS readback-fault" in result.stdout, result.stdout + result.stderr)
        print("PASS treatment: native temporary readback corruption refused")
        old = 'if (!Arrays.equals(data, Files.readAllBytes(path))) throw new IOException("export read-back differs");'
        Lab.require(corrupt.count(old) == 1, "native readback identity seam differs")
        result = execute(corrupt.replace(old, "// readback omitted"), "control-readback", treatment="corrupt-readback")
        Lab.require(result.returncode != 0 and "terminal receipt failed" in result.stdout + result.stderr,
                    "readback identity mutation survived or failed for wrong reason\n" + result.stdout + result.stderr)
        print("PASS control refused: readback identity")
        controls = (
            ("stop pause", "if (controls != null) controls.SetCurrentGameSpeed(0);", "// native stop pause omitted",
             "stop request pauses native clock before acknowledgement"),
            ("timeout state", "if (runtimeFailure == null) runtimeFailure = message;\n            refreshFailureSnapshot();\n            System.err.println",
             "if (runtimeFailure == null) runtimeFailure = message;\n            System.err.println",
             "timeout publishes failed observer state with retained native clock"),
            ("native callback timing", "option.setValue(true);", "option.setValue(false);",
             "native slow Lua callback timing is enabled for the study owner"),
        )
        for label, old, new, reason in controls:
            Lab.require(observer.count(old) == 1, "native observer control seam differs: " + label)
            result = execute(helper, "control-" + label.replace(" ", "-"), observer.replace(old, new))
            Lab.require(result.returncode != 0 and reason in result.stdout + result.stderr,
                "native observer mutation survived or failed for wrong reason: " + label + "\n" + result.stdout + result.stderr)
            print("PASS control refused: " + label)
    print("Border 222 PASS: installed-engine worker and publication controls")
    print("LIMIT actual installed VM and native writer; loaded simulation rate remains separate")


def main():
    try:
        run()
    except Exception as failure:
        print("FAULT native observation export worker:", failure)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
