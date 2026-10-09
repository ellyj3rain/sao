#!/usr/bin/env python3
"""Exercise Viewpoint mouse readiness and coordinate fallback under installed Kahlua."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "mod/42.20/media/lua/client/SAO_Viewpoint_Mouse.lua"
PROBE = ROOT / "tools/luacheck/PhysicalMeansLuaProbe.java"
GAME = Path("C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid")
JDK = Path("C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin")

PRELUDE = r'''
Events = { OnGameStart = { handlers = {} } }
function Events.OnGameStart.Add(fn)
    table.insert(Events.OnGameStart.handlers, fn)
end
ISCoordConversion = { ToWorld = function(x, y, z) return x + 1, y + 2 end }
Viewpoint = nil
'''

CASES = r'''
local checks = 0
local function check(name, good)
    if not good then error("VIEWPOINT_MOUSE:" .. name) end
    checks = checks + 1
end
check("pending_marker_clear", SAOViewpointMouseLoaded ~= true)
check("ordinary_unwrapped", ISCoordConversion.viewpointWrapped ~= true)
check("retry_registered_once", #Events.OnGameStart.handlers == 1)
Viewpoint = { Mouse = { worldX = function() return 41 end,
    worldY = function() return 52 end } }
Events.OnGameStart.handlers[1]()
check("wrapped_after_java", SAOViewpointMouseLoaded == true
    and ISCoordConversion.viewpointWrapped == true)
local converter = ISCoordConversion.ToWorld
local x, y = converter(2, 3, 0)
check("native_cursor_position", x == 41 and y == 52)
Events.OnGameStart.handlers[1]()
check("idempotent_wrap", ISCoordConversion.ToWorld == converter)
Viewpoint.Mouse.worldX = function() return nil end
x, y = converter(2, 3, 0)
check("ordinary_coordinate_fallback", x == 3 and y == 5)
__result = checks
'''


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def change(body: bytes, old: bytes, new: bytes) -> bytes:
    assert body.count(old) == 1, f"moved test anchor: {old!r}"
    return body.replace(old, new, 1)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True, type=Path)
    out = parser.parse_args().out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    inputs = [SOURCE, PROBE, GAME / "projectzomboid.jar", GAME / "stdlib.lua",
              Path(__file__)]
    before = {str(path): sha(path) for path in inputs}
    receipt = {"schema": "sao-viewpoint-mouse-controlled/1", "status": "INCOMPLETE",
               "inputsBefore": before, "runs": []}

    def save() -> None:
        (out / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")

    def run(name: str, args: list[str]) -> tuple[int, str]:
        done = subprocess.run(args, cwd=out, capture_output=True, timeout=120)
        log = out / f"{name}.log"
        log.write_bytes(done.stdout + done.stderr)
        receipt["runs"].append({"name": name, "exitCode": done.returncode,
                                "logSha256": sha(log)})
        save()
        return done.returncode, log.read_text(errors="replace")

    save()
    try:
        (out / "prelude.lua").write_text(PRELUDE)
        (out / "cases.lua").write_text(CASES)
        (out / "stdlib.lua").write_bytes((GAME / "stdlib.lua").read_bytes())
        with tempfile.TemporaryDirectory(prefix="sao-viewpoint-mouse-") as directory:
            classes = Path(directory)
            code, log = run("compile", [str(JDK / "javac.exe"), "-encoding", "UTF-8",
                                        "-cp", str(GAME / "projectzomboid.jar"),
                                        "-d", str(classes), str(PROBE)])
            assert code == 0, log
            cp = os.pathsep.join((str(classes), str(GAME / "projectzomboid.jar")))
            source = SOURCE.read_bytes()
            variants = [
                ("production", source, None),
                ("premature-marker", change(source,
                    b"wrap()\nif not SAO.Viewpoint.mouseEventsInstalled then",
                    b"wrap()\nSAOViewpointMouseLoaded = true\nif not SAO.Viewpoint.mouseEventsInstalled then"),
                 "pending_marker_clear"),
                ("no-retry", change(source,
                    b"Events.OnGameStart.Add(wrap)",
                    b"Events.OnGameStart.Add(function() end)"), "wrapped_after_java"),
                ("no-fallback", change(source,
                    b"return toWorld(x, y, z)", b"return nil, nil"),
                 "ordinary_coordinate_fallback"),
            ]
            for name, body, expected in variants:
                path = out / (name + ".lua")
                path.write_bytes(body)
                code, log = run(name, [str(JDK / "java.exe"), "-cp", cp,
                                       "PhysicalMeansLuaProbe", str(out / "prelude.lua"),
                                       str(path), str(out / "cases.lua"), "--", "__result"])
                if expected:
                    assert code != 0 and "VIEWPOINT_MOUSE:" + expected in log, (name, log)
                else:
                    assert code == 0 and "VALUE " in log, log
                    receipt["checks"] = int(float(log.split("VALUE ", 1)[1].split()[0]))
        after = {str(path): sha(path) for path in inputs}
        assert after == before, "source changed during test"
        receipt.update(status="PASS", inputsAfter=after, inverseControls=3)
        save()
        print(f"PASS {receipt['checks']} checks, 3 inverse controls")
        return 0
    except Exception as error:
        receipt.update(status="FAIL", error=str(error))
        save()
        raise


if __name__ == "__main__":
    raise SystemExit(main())
