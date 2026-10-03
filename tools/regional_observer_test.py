"""Border 220: native regional observer, pixels, saves and Lua representation."""
import copy
import hashlib
import json
import os
import re
from pathlib import Path
import shutil
import sqlite3
import struct
import subprocess
import tempfile
import unittest
import zlib
from unittest.mock import patch
from contextlib import closing

import world_lab as Lab
import world_lab_run as Run

GAME = Path(os.environ.get("PZ_DIR", r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"))
_javac = shutil.which("javac")
_jdk_candidates = [Path(os.environ["JAVA_HOME"]) / "bin"] if os.environ.get("JAVA_HOME") else []
if _javac: _jdk_candidates.append(Path(_javac).parent)
_jdk_candidates.append(Path.home() / "Peanut Butter" / "JetBrains" / "Java" / "bin")
JDK = Path(os.environ["JDK_BIN"]) if os.environ.get("JDK_BIN") else next(
    (candidate for candidate in _jdk_candidates if (candidate / "javac.exe").is_file()), _jdk_candidates[-1])

INITIAL_PLACEMENT_FIXTURE = '''
local rec={id='initial-1',x=100,y=200,z=0,forename='Named',epistemicMonths=1,kitGranted=true,
 initialStudyOrigin={definitionSha256=string.rep('a',64),saveName='NativeSave',siteId='farm'}}
local records={['initial-1']=rec}
local mode,body,calls='failure',nil,0
SAO={Identity={all=function() return records end,knownName=function() return nil end},
 Log={line=function() end,tally=function() end},Claims={isHeld=function() return false end},
 History={countyHours=function() return 123 end},Controller={adopt=function() end}}
SAO.Body={recover=function() return true end,hasRepresentation=function() return body~=nil end,
 get=function() return body end,materialize=function()
  calls=calls+1
  if mode=='failure' then return nil,'native-square-unavailable' end
  if mode=='unknown' then return nil end
  body={getX=function() return 100 end,getY=function() return 200 end,getZ=function() return 0 end}
  return body
 end}
function InitialPlacementChecks()
 local conf={materialize=20,hibernate=50}
 SAO.PopulationRepresentation.materializeBand(100,200,conf)
 local receipt=rec.initialStudyPlacement
 assert(receipt and receipt.status=='refused' and receipt.reason=='native-square-unavailable'
  and receipt.causeAvailable and receipt.observedAtCountyHours==123,'native placement cause lost')
 assert(receipt.definitionSha256==rec.initialStudyOrigin.definitionSha256 and receipt.saveName=='NativeSave'
  and receipt.siteId=='farm','native placement source binding lost')
 mode='unknown'
 SAO.PopulationRepresentation.materializeBand(100,200,conf)
 receipt=rec.initialStudyPlacement
 assert(receipt.status=='refused' and receipt.reason=='native-placement-cause-unavailable'
  and receipt.causeAvailable==false,'missing native placement cause was invented')
 mode='success'
 SAO.PopulationRepresentation.materializeBand(100,200,conf)
 receipt=rec.initialStudyPlacement
 assert(receipt.status=='represented' and receipt.reason==nil and calls==3,'native placement success differs')
 SAO.PopulationRepresentation.materializeBand(100,200,conf)
 assert(calls==3 and rec.initialStudyPlacement==receipt,'existing body received another placement attempt')
 rec.initialStudyOrigin,rec.initialStudyPlacement,body=nil,nil,nil mode='failure'
 SAO.PopulationRepresentation.materializeBand(100,200,conf)
 assert(rec.initialStudyPlacement==nil and calls==4,'ordinary placement received study provenance')
 return 'PASS five initial placement owner checks; controlled receivers in installed Kahlua'
end
'''


def initial_placement_checks(root, command):
    source = (Lab.ROOT / "mod/42.20/media/lua/client/SAO_PopulationRepresentation.lua").read_text()
    variants = [("production", source, None)]
    for label, before, after, expected in (
        ("cause-omitted", "local body, placementReason = SAO.Body.materialize", "local body = SAO.Body.materialize",
         "native placement cause lost"),
        ("source-binding-invented", "local origin = rec.initialStudyOrigin",
         'local origin = {definitionSha256="invented",saveName="invented",siteId="invented"}',
         "native placement source binding lost"),
        ("unknown-cause-invented", "causeAvailable = body ~= nil or placementReason ~= nil",
         "causeAvailable = true", "missing native placement cause was invented"),
    ):
        assert source.count(before) == 1, "initial placement mutation seam differs"
        changed = source.replace(before, after, 1)
        assert changed != source
        variants.append((label, changed, expected))
    for label, runtime, expected in variants:
        path = root / ("initial-placement-" + label + ".lua")
        path.write_text(INITIAL_PLACEMENT_FIXTURE + '\n(function()\n' + runtime
                        + '\nend)()\nRESULT=InitialPlacementChecks()\n')
        output = execute([*command, path, "--", "RESULT"], root, expected)
        print(output.splitlines()[-1] if expected is None else "PASS initial placement control refused: " + label)


def require_region_initialization(source):
    source = re.sub(r'/\*.*?\*/|//[^\n]*', '', source, flags=re.S)
    end_world = source.split('public static void endWorld(', 1)[1].split('public static void initializeRegion(', 1)[0]
    initializer = source.split('public static void initializeRegion(', 1)[1].split('public static void loadRegion(', 1)[0]
    assert 'initializeRegion(cell, index, resident.getX(), resident.getY());' in end_world, \
        'secondary host startup omitted region initialization'
    assert 'loadRegion(owner, map);' in initializer, 'region initialization omitted full-grid custody'
    assert 'prepareRegionLighting(map);' in initializer, 'region initialization omitted tested lighting preparation'


class RegionalDefinitions(unittest.TestCase):
    def test_secondary_startup_calls_executed_region_loader(self):
        source = (Lab.ROOT / 'tools/world_lab/StudyObserver.java').read_text()
        require_region_initialization(source)
        for call, expected in (
            ('initializeRegion(cell, index, resident.getX(), resident.getY());', 'secondary host startup'),
            ('loadRegion(owner, map);', 'full-grid custody'),
            ('prepareRegionLighting(map);', 'tested lighting preparation'),
        ):
            self.assertEqual(source.count(call), 1)
            changed = source.replace(call, '/* ' + call + ' */', 1)
            self.assertNotEqual(changed, source)
            with self.subTest(call=call), self.assertRaisesRegex(AssertionError, expected):
                require_region_initialization(changed)

    def setUp(self):
        self.definition = Lab.load(Lab.ROOT / "tools/world_lab/definition.example.json")
        self.definition["observation"]["sites"] = [dict(id=f"area-{i}", label=f"Area {i}", x=64 + 128*i, y=64, z=0) for i in range(3)]
        self.definition["situation"] = {"initialNeedsBySite": {"area-1": {"hunger": {"min": 0.4, "max": 0.6}}}}

    def test_sites_and_one_time_needs_are_validated_without_behavior_assignments(self):
        self.assertEqual(Lab.validate(copy.deepcopy(self.definition)), self.definition)
        for change in (dict(id="area-0"), dict(x=64), dict(x=-1), dict(label="\nlabel")):
            corrupt = copy.deepcopy(self.definition); corrupt["observation"]["sites"][1].update(change)
            with self.subTest(change=change), self.assertRaises(ValueError): Lab.validate(corrupt)
        corrupt = copy.deepcopy(self.definition); corrupt["situation"]["initialNeedsBySite"]["missing"] = {"hunger": {"min": 0, "max": 1}}
        with self.assertRaises(ValueError): Lab.validate(corrupt)
        corrupt = copy.deepcopy(self.definition); del corrupt["observation"]["sites"]
        with self.assertRaises(ValueError): Lab.validate(corrupt)

    def test_existing_one_view_definition_remains_compatible(self):
        value = Lab.load(Lab.ROOT / "tools/world_lab/definition.example.json")
        self.assertEqual(Lab.validate(copy.deepcopy(value)), value)

    def test_native_save_rejects_any_of_three_infrastructure_slots(self):
        with tempfile.TemporaryDirectory() as name:
            cache = Path(name); root = cache / "Saves/Sandbox/fixture"; root.mkdir(parents=True)
            for filename in ("map.bin", "map_t.bin", "map_sand.bin", "map_meta.bin", "map_zone.bin", "global_mod_data.bin", "WorldDictionary.bin"):
                (root / filename).write_bytes(b"fixture-presence-only")
            (root / "map").mkdir(); (root / "map/0.bin").write_bytes(b"fixture")
            map_name = "Fixture-map"; seed = self.definition["seed"].encode()
            (root / "map_ver.bin").write_bytes(struct.pack(">ii", 249, len(map_name)) + map_name.encode("utf-16-be"))
            extent = self.definition["extent"]
            bounds = (extent["minCellX"], extent["minCellY"], extent["minCellX"] + extent["cellsX"] - 1, extent["minCellY"] + extent["cellsY"] - 1)
            (root / "map_worldgen.bin").write_bytes(struct.pack(">4sih", b"WGEN", 249, len(seed)) + seed + struct.pack(">iiii", *bounds))
            (root / "mods.txt").write_text("mods\n{\n mod = Fixture,\n}\n")
            receipt = dict(save="fixture", mapName=map_name, mods={"Fixture": {}}, host="observer")
            with closing(sqlite3.connect(root / "players.db")) as database, database: database.execute("CREATE TABLE localPlayers (id INTEGER, isDead BOOLEAN, data BLOB)")
            self.assertEqual(Run.saved_state(cache, receipt, self.definition), dict(count=0, observerPersisted=False))
            for slot in range(3):
                with closing(sqlite3.connect(root / "players.db")) as database, database:
                    database.execute("INSERT INTO localPlayers VALUES(?,1,x'01')", (slot + 1,))
                with self.assertRaisesRegex(ValueError, "persisted a participating player"):
                    Run.saved_state(cache, receipt, self.definition)
                with closing(sqlite3.connect(root / "players.db")) as database, database: database.execute("DELETE FROM localPlayers")

    def test_run_receipt_reader_denial_is_bounded_and_retains_previous_receipt(self):
        with tempfile.TemporaryDirectory() as name:
            path = Path(name) / "run.json"; Run.publish(path, {"status": "prepared"})
            replace = os.replace
            calls = []
            def temporary_denial(source, target):
                calls.append(1)
                if len(calls) <= 2:
                    self.assertEqual(Lab.load(path), {"status": "prepared"})
                    raise PermissionError("controlled old receipt reader")
                replace(source, target)
            with patch.object(Run.os, "replace", side_effect=temporary_denial), patch.object(Run.time, "sleep"):
                Run.publish(path, {"status": "running"})
            self.assertEqual(Lab.load(path), {"status": "running"})
            with patch.object(Run.os, "replace", side_effect=PermissionError("persistent denial")) as denied, patch.object(Run.time, "sleep"):
                with self.assertRaises(PermissionError): Run.publish(path, {"status": "ended"})
                self.assertEqual(denied.call_count, 20)
            self.assertEqual(Lab.load(path), {"status": "running"})

    def test_region_hash_witness_is_required_for_saved_evidence(self):
        def png(width, height, color):
            def chunk(kind, body):
                return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body))
            pixels = b"".join(b"\0" + bytes(color) * width for _ in range(height))
            return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(pixels)) + chunk(b"IEND", b"")
        with tempfile.TemporaryDirectory() as name:
            root = Path(name); native = root / "native-view"; native.mkdir()
            frame_name = "study-live-0000000000000001.png"
            def descriptor(filename, width, height, color):
                data = png(width, height, color); (native / filename).write_bytes(data)
                return dict(file=filename, width=width, height=height, sha256=hashlib.sha256(data).hexdigest())
            state = dict(schema="sao-study-observer/1", detached=True, worldAdvanced=True, hours=3, startHours=2,
                         nativeAlive=False, ghost=True, zombiesDontAttack=True, collidable=False, playerSqlId=-1,
                         suppressedBirths=3, suppressedSaves=3, logicCalls=10, objects=0, additions=0, removals=0, squareMemberships=0, sites=[])
            view = dict(schema="sao-native-viewport/1", sequence=1, capturedAtUnixMs=1,
                        image=descriptor(frame_name, 8, 8, (0, 0, 0)), views=[])
            for slot, (left, top, color) in enumerate(((0, 0, (255, 0, 0)), (4, 0, (0, 0, 255)), (0, 4, (0, 255, 0)))):
                site = dict(id=f"area-{slot}", label=f"Area {slot}", slot=slot, playerSqlId=-1, nativeAlive=False,
                            ghost=True, collidable=False, anchorIdentity=f"a{slot}", viewIdentity=f"b{slot}")
                state["sites"].append(site)
                view["views"].append(dict(id=site["id"], label=site["label"], slot=slot, left=left, top=top,
                                          image=descriptor(frame_name.replace(".png", f"-site{slot}.png"), 4, 4, color)))
            Run.publish(root / "observer-state.json", state); Run.publish(native / "native.json", view)
            self.assertEqual(len(Run.observer_evidence(root)["files"]), 6)
            image = native / view["views"][2]["image"]["file"]; image.write_bytes(png(4, 4, (255, 0, 0)))
            with self.assertRaisesRegex(ValueError, "regional pixels differ"): Run.observer_evidence(root)


def execute(args, cwd, expected=None):
    result = subprocess.run([str(value) for value in args], cwd=cwd, text=True, capture_output=True, timeout=90)
    output = result.stdout + result.stderr
    if expected is None:
        if result.returncode: raise AssertionError(output[-8000:])
    elif result.returncode == 0 or expected not in output:
        raise AssertionError("regional negative control survived: " + output[-3000:])
    return output


def native_checks(root):
    source = Lab.ROOT / "tools/world_lab"
    classes = root / "classes"; classes.mkdir()
    native = os.pathsep.join(str(GAME / name) for name in ("projectzomboid.jar", "ZombieBuddy.jar"))
    execute([JDK / "javac.exe", "-cp", native, "-d", classes,
             *(source / name for name in ("StudyObserver.java", "StudyViewCapture.java", "StudyVideoCapture.java", "StudyLoadingAgent.java", "StudyExport.java",
                                          "NativeObserverSitesProbe.java", "NativeRegionalCaptureProbe.java", "NativeObserverResidencyProbe.java")),
             Lab.ROOT / "tools/luacheck/LuaRun.java"], root)
    manifest = root / "agent.mf"; manifest.write_text("Manifest-Version: 1.0\nPremain-Class: StudyLoadingAgent\nCan-Retransform-Classes: true\n\n")
    agent = root / "observer.jar"
    execute([JDK / "jar.exe", "cfm", agent, manifest, "-C", classes, "."], root)
    def probe(name, extra=None, expected=None):
        home = root / ("home-" + name + ("-" + extra.name if extra else "")); home.mkdir()
        classpath = os.pathsep.join(str(value) for value in ([extra] if extra else []) + [classes]) + os.pathsep + native
        return execute([GAME / "jre64/bin/java.exe", "-Djava.awt.headless=true", f"-Duser.home={home}",
                        "-Dstudy.observer=true", f"-javaagent:{agent}=isolated-study", "--enable-native-access=ALL-UNNAMED",
                        "-cp", classpath, name], GAME, expected)
    for name in ("NativeObserverSitesProbe", "NativeRegionalCaptureProbe", "NativeObserverResidencyProbe"):
        output = probe(name)
        print("\n".join(line for line in output.splitlines() if line.startswith("PASS ")))
    for filename, old, new, name, why in (
        ("StudyObserver.java", "LightingJNI.init && LightingJNI.getUpdateCounter(slot) >= 0", "LightingJNI.init",
         "NativeObserverResidencyProbe", "uninitialized regional lighting attempted native teleport"),
        ("StudyObserver.java", "var chunk = map.LoadChunkForLater(x, y, x - left, y - top);",
         "var chunk = IsoChunkMap.SharedChunks.get((x << 16) + y);", "NativeObserverResidencyProbe",
         "regional full-grid ownership missing or duplicated"),
        ("StudyObserver.java", "frame.camCharacter = view;", "frame.camCharacter = camera;", "NativeObserverSitesProbe", "native frame did not use its actual regional position"),
        ("StudyObserver.java", "extraAnchors.length > 0 && rx == vx && ry == vy && rz == vz", "false", "NativeObserverSitesProbe", "loaded regional camera visit unnecessarily scrolled native residency"),
        ("StudyObserver.java", "if (failure != null) failContext(failure);", "if (false) failContext(failure);", "NativeObserverSitesProbe", "missing native map did not preserve a failed clock receipt"),
        ("StudyLoadingAgent.java", "StudyObserver.streamingFailure(map, actor, failure);", "/* immediate native failure receipt removed */", "NativeObserverSitesProbe", "native streaming exception lost its immediate cause receipt"),
        ("StudyViewCapture.java", "full.getSubimage(site.left(), site.top(), site.width(), site.height())", "full.getSubimage(0, 0, site.width(), site.height())", "NativeRegionalCaptureProbe", "regional capture reused another viewport pixels")):
        bad = root / ("bad-" + filename + "-" + hashlib.sha256(old.encode()).hexdigest()[:8]); bad.mkdir()
        code = (source / filename).read_text(); assert code.count(old) == 1, "regional control seam differs"
        path = bad / filename; path.write_text(code.replace(old, new))
        execute([JDK / "javac.exe", "-cp", str(classes) + os.pathsep + native, "-d", bad, path], root)
        # Advice is loaded from the agent jar. For agent mutations, replace its
        # exact classes in an isolated jar as well as the probe classpath.
        if filename == "StudyLoadingAgent.java":
            bad_agent = bad / "observer.jar"
            shutil.copyfile(agent, bad_agent)
            execute([JDK / "jar.exe", "uf", bad_agent,
                     *(part for compiled in sorted(bad.glob("StudyLoadingAgent*.class"))
                       for part in ("-C", bad, compiled.name))], root)
            home = bad / "home"; home.mkdir()
            execute([GAME / "jre64/bin/java.exe", "-Djava.awt.headless=true", f"-Duser.home={home}",
                     "-Dstudy.observer=true", f"-javaagent:{bad_agent}=isolated-study", "--enable-native-access=ALL-UNNAMED",
                     "-cp", str(bad) + os.pathsep + str(classes) + os.pathsep + native, name], GAME, why)
        else: probe(name, bad, why)
        print("PASS regional control rejected: " + why)
    participants = (Lab.ROOT / "mod/42.20/media/lua/shared/SAO_Participants.lua").read_text()
    population = (Lab.ROOT / "mod/42.20/media/lua/client/SAO_PopulationRepresentation.lua").read_text()
    fixture = '''local bodies, records, visits, releases = {}, {}, {}, {}
for i=0,2 do
 local x=64+128*i
 bodies[i]={getX=function() return x end,getY=function() return 64 end,getZ=function() return 0 end,getModData=function() return {SAO_ObserverAnchor=true} end}
 local id='person-'..i; records[id]={id=id,x=x,y=64,z=0}
end
records.far={id='far',x=1000,y=1000,z=0}
getSpecificPlayer=function(i) return bodies[i] end
SAO={Identity={all=function() return records end},Log={line=function() end,tally=function() end},Claims={isHeld=function() return false end}}
SAO.Body={recover=function(rec) visits[rec.id]=(visits[rec.id] or 0)+1;return true end,hasRepresentation=function() return true end,
get=function(id) local r=records[id];return {getX=function() return r.x end,getY=function() return r.y end,getZ=function() return r.z end} end,
release=function(rec) releases[rec.id]=true;return true end}
'''
    checks = '''
assert(#SAO.Participants.residencyCenters()==3,'secondary residency centers lost')
for i=0,2 do assert(SAO.Participants.player(i)==nil,'regional observer became participant') end
SAO.PopulationRepresentation.materializeBand(64,64,{materialize=20,hibernate=50})
for i=0,2 do local id='person-'..i;assert(not releases[id],'secondary-area body hibernated');assert(visits[id]==1,'representation ran more than once') end
assert(releases.far,'far body did not leave loaded residency')
RESULT='PASS actual Lua secondary population retained in one nearest-center pass; detached observers excluded'
'''
    lua = root / "residency.lua"; lua.write_text(fixture + participants + "\n(function()\n" + population + "\nend)()\n" + checks)
    command = [GAME / "jre64/bin/java.exe", "-Djava.awt.headless=true", "-cp", str(classes) + os.pathsep + native, "LuaRun", lua, "--", "RESULT"]
    print(execute(command, GAME).splitlines()[-1])
    lua.write_text(lua.read_text().replace("math.min(d, dist(point.x, point.y, center.x, center.y))", "dist(point.x, point.y, px, py)"))
    execute(command, GAME, "secondary-area body hibernated"); print("PASS regional control rejected: slot-zero-only representation")
    shutil.copyfile(GAME / "stdlib.lua", root / "stdlib.lua")
    initial_placement_checks(root, [GAME / "jre64/bin/java.exe", "-cp", str(classes) + os.pathsep + native, "LuaRun"])


if __name__ == "__main__":
    result = unittest.TextTestRunner(verbosity=1).run(unittest.defaultTestLoader.loadTestsFromTestCase(RegionalDefinitions))
    if not result.wasSuccessful(): raise SystemExit(1)
    if not (GAME / "projectzomboid.jar").is_file() or not (JDK / "javac.exe").is_file():
        print("SKIP Border 220 installed native engine/JDK unavailable; regional gameplay unverified")
    else:
        with tempfile.TemporaryDirectory(prefix="sao-region-") as name: native_checks(Path(name))
    print("Border 220: regional method/publication/representation checks complete; live native acceptance is separate")
