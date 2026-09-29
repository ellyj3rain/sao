"""Full Controller executes lived-home occupancy and useful nighttime continuation."""
from pathlib import Path
import os
import shutil
import subprocess


def run(work, game, jdk):
    import flee_continuity_test as fixture
    root = Path(__file__).resolve().parents[2]
    work = (Path(work) / "night-rest").resolve()
    work.mkdir()
    game, jdk = Path(game), Path(jdk)
    suffix = ".exe" if os.name == "nt" else ""
    jar = game / "projectzomboid.jar"
    subprocess.run([str(jdk / ("javac" + suffix)), "-cp", str(jar), "-d", str(work),
                    str(root / "tools/luacheck/LuaRun.java")], check=True, capture_output=True, timeout=60)
    shutil.copy2(game / "stdlib.lua", work / "stdlib.lua")
    (work / "prelude.lua").write_text(fixture.PRELUDE, encoding="utf-8")
    probe = (root / "tools/world_lab/NightRestChecks.lua").read_text(encoding="utf-8")
    (work / "probe.lua").write_text("local ok, why=pcall(function()\n" + probe
        + '\nend)\nif not ok then __result="ERROR after " .. tostring(__nightStage or "setup") .. ": " .. tostring(why) end\n', encoding="utf-8")
    source = fixture.CONTROLLER.read_text(encoding="utf-8")
    expose = "Ctl.__nightProbe=decideNightAndDrift\nCtl.__homeProbe=decideHomeAndEquipment\nCtl.__roamProbe=decideRoam\nCtl.__resourceProbe=decideLocalResources\nreturn Ctl\n"
    assert source.count("return Ctl\n") == 1
    variants = [("production", None, None, None),
                ("claim-only", '(insideHome or SAO.Standing.insideClaim(id, body:getX(), body:getY()))',
                 'SAO.Standing.insideClaim(id, body:getX(), body:getY())', 'durable lived home admits rest'),
                ("knowledge-erased", 'not (places[place.id] or places[tostring(place.id)])', 'false', 'unknown address grants no rest'),
                ("floor-ignored", 'and math.floor(body:getZ()) == math.floor(z or 0)', 'and true', 'other floor does not manufacture rest'),
                ("ten-tile-dead-zone", 'not insideHome and (dh > 10.0 or knownHome)', '(dh > 10.0)', 'outside inside ten tiles still routes home'),
                ("blanket-night-hold", 'return agent.resting == true', 'return true', 'no rest lets useful decisions continue'),
                ("cold-hold", 'setState(agent, id, "IDLE", "woken by the cold", "need")\n                return false',
                 'setState(agent, id, "IDLE", "woken by the cold", "need")\n                return true', 'cold reaches actual hearth decision'),
                ("private-rest-address", 'or occupiesKnownHome(id, body, homeX, homeY, homeZ)',
                 'or occupiesKnownHome(id, body, rec.homeX, rec.homeY, rec.homeZ)', 'shared known leader home admits rest'),
                ("string-key-ignored", 'places[place.id] or places[tostring(place.id)]', 'places[place.id]', 'persisted string building key admits rest'),
                ("current-permission-ignored", 'if not mayEnterBelieved(id, body:getX(), body:getY()) then return false, true end', '', 'occupied permission differs from address'),
                ("cold-recovery-clock-retained", 'if SAO.Needs.cold(body) >= 1.5 then\n                agent.resting = nil\n                agent.lastRestHours = nil',
                 'if SAO.Needs.cold(body) >= 1.5 then\n                agent.resting = nil', 'warming time is not sleep recovery'),
                ("denied-current-erases-home", 'if not mayEnterBelieved(id, body:getX(), body:getY()) then return false, true end',
                 'if not mayEnterBelieved(id, body:getX(), body:getY()) then return false, false end', 'denied current tile still routes to permitted home')]
    for label, old, new, failure in variants:
        if old is not None:
            assert source.count(old) == 1, label + " mutation seam drifted"
        text = source if old is None else source.replace(old, new, 1)
        (work / "controller.lua").write_text(text.replace("return Ctl\n", expose, 1), encoding="utf-8")
        result = subprocess.run([str(jdk / ("java" + suffix)), "-cp", os.pathsep.join([str(jar), str(work)]),
                                 "LuaRun", "prelude.lua", "controller.lua", "probe.lua", "--", "__result"],
                                cwd=work, text=True, capture_output=True, timeout=60)
        output = result.stdout + result.stderr
        (work / (label + ".log")).write_text(output, encoding="utf-8")
        assert result.returncode == 0, label + ": " + output
        if failure is None:
            assert "VALUE PASS night continuity" in output, output
        else:
            assert "VALUE FAIL " in output and failure in output, label + ": " + output
    print("PASS full Controller night continuation and eleven source controls")
