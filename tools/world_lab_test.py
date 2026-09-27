#!/usr/bin/env python3
"""Border 198: study definitions, isolated packaging, truthful runtime coverage.

RuntimeChecks is a controlled fixture in installed Kahlua; NativeStudyProbe
separately exercises actual engine parameter persistence. Neither is gameplay.
"""
from __future__ import annotations

import copy
import importlib.util
from contextlib import closing
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sqlite3
import struct
import tempfile
import unittest
import zlib
from unittest.mock import patch

import world_lab as Lab
import world_lab_run as Run

GAME = Path(os.environ.get("PZ_DIR", r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"))
JDK = Path(os.environ.get("JDK_BIN", r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin"))
BASE = Lab.load(Lab.ROOT / "tools/world_lab/definition.example.json")


class DefinitionTests(unittest.TestCase):
    def test_observer_evidence_requires_detachment_advancement_and_native_image(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "native-view").mkdir()
            state = dict(schema="sao-study-observer/1", detached=True, worldAdvanced=True,
                         hours=2.4, startHours=2, nativeAlive=False, ghost=True, zombiesDontAttack=True,
                         collidable=False, playerSqlId=-1, suppressedBirths=1, suppressedSaves=1,
                         logicCalls=100, objects=0, additions=0, removals=0, squareMemberships=0)
            image = root / "native-view/study-live-0000000000000001.png"
            def chunk(kind, data):
                return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
            data = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 960, 540, 8, 6, 0, 0, 0))
                    + chunk(b"IDAT", zlib.compress(b"\0" * (540 * (960 * 4 + 1)))) + chunk(b"IEND", b""))
            image.write_bytes(data)
            view = {"schema": "sao-native-viewport/1", "sequence": 1, "capturedAtUnixMs": 1,
                    "image": {"file": image.name, "sha256": Run.digest(image), "width": 960, "height": 540}}
            Run.publish(root / "observer-state.json", state)
            Run.publish(root / "native-view/native.json", view)
            self.assertEqual(len(Run.observer_evidence(root)["files"]), 3)
            for change in ({"detached": False}, {"worldAdvanced": False}, {"objects": 1}, {"playerSqlId": 1}):
                Run.publish(root / "observer-state.json", state | change)
                with self.subTest(change=change), self.assertRaises(ValueError):
                    Run.observer_evidence(root)
            Run.publish(root / "observer-state.json", state)
            for invalid in (data[:24], data[:-12], data[:-16] + b"broken" + data[-10:],
                            data[:33] + chunk(b"IDAT", zlib.compress(b"short")) + chunk(b"IEND", b"")):
                image.write_bytes(invalid)
                view["image"]["sha256"] = Run.digest(image)
                Run.publish(root / "native-view/native.json", view)
                with self.assertRaises(ValueError):
                    Run.observer_evidence(root)
            image.unlink()
            with self.assertRaises(OSError):
                Run.observer_evidence(root)

    def test_open_observer_stop_is_required(self):
        log = ("[StudyLaunch] started attempt=1 save=world hours=2\n"
               "[StudyObserver] stop hours=2.4\n[StudyLaunch] native-save-returned attempt=1\n")
        self.assertEqual(Run.terminal(log, 1, "world", 1, True)["endHours"], 2.4)
        with self.assertRaises(ValueError):
            Run.terminal(log.replace("[StudyObserver] stop hours=2.4\n", ""), 1, "world", 1, True)

    def test_native_image_receipt_tampering(self):
        with tempfile.TemporaryDirectory() as tmp:
            cache = Path(tmp)
            image = cache / "Screenshots/study-attempt-0002.png"
            image.parent.mkdir()
            receipt = {"launchNumber": 2, "nativeImages": {}}
            Run.verify_native_images(cache, receipt)
            image.write_bytes(b"fixture-image")
            with self.assertRaisesRegex(ValueError, "native image"):
                Run.verify_native_images(cache, receipt)
            receipt["nativeImages"][image.relative_to(cache).as_posix()] = Run.digest(image)
            Run.verify_native_images(cache, receipt)
            image.write_bytes(b"changed-image")
            with self.assertRaisesRegex(ValueError, "native image"):
                Run.verify_native_images(cache, receipt)
            image.unlink()
            with self.assertRaisesRegex(ValueError, "native image"):
                Run.verify_native_images(cache, receipt)

    def test_native_terminal_receipts(self):
        lines = ["[StudyLaunch] started attempt=2 save=world hours=2.3",
                 "[StudyLaunch] horizon attempt=2 save=world start=2.3 end=2.6",
                 "[StudyLaunch] native-save-returned attempt=2"]
        log = "\n".join(lines)
        self.assertEqual(Run.terminal(log, 2, "world", .3)["endHours"], 2.6)
        for invalid in ("\n".join(lines[:2]), "\n".join(reversed(lines)), log + "\n" + lines[-1],
                        log.replace("attempt=2", "attempt=1"), log.replace("save=world", "save=foreign"),
                        log.replace("end=2.6", "end=2.4"), log.replace("start=2.3", "start=2.4")):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                Run.terminal(invalid, 2, "world", .3)
        self.assertTrue(Run.runtime_errors(log + "\n[StudyWorld] stopped: write failure", ""))
        self.assertTrue(Run.runtime_errors(log, "java.io.IOException: disk full"))
        self.assertTrue(Run.runtime_errors(log + "\nExceptionLogger.logException: save failed", ""))

    def test_saved_native_artifacts_and_controls(self):
        with tempfile.TemporaryDirectory() as tmp:
            cache = Path(tmp)
            root = cache / "Saves/Sandbox/fixture"
            root.mkdir(parents=True)
            for name in ("map.bin", "map_t.bin", "map_sand.bin", "map_meta.bin", "map_zone.bin",
                         "global_mod_data.bin", "WorldDictionary.bin"):
                (root / name).write_bytes(b"controlled-presence-only")
            (root / "map").mkdir()
            (root / "map/0.bin").write_bytes(b"controlled-chunk-presence")
            map_name = "Fixture-map"
            (root / "map_ver.bin").write_bytes(struct.pack(">ii", 249, len(map_name)) + map_name.encode("utf-16-be"))
            seed = BASE["seed"].encode("utf-8")
            (root / "map_worldgen.bin").write_bytes(struct.pack(">4sih", b"WGEN", 249, len(seed))
                                                   + seed + struct.pack(">iiii", 0, 0, 1, 1))
            (root / "mods.txt").write_text("mods\n{\n mod = Fixture,\n}\n")
            with closing(sqlite3.connect(root / "players.db")) as database:
                database.execute("CREATE TABLE localPlayers (id INTEGER, isDead BOOLEAN, data BLOB)")
                database.execute("INSERT INTO localPlayers VALUES(1,0,x'01')")
                database.commit()
            receipt = {"save": "fixture", "mapName": map_name, "mods": {"Fixture": {}}}
            self.assertTrue(Run.saved_state(cache, receipt, BASE)["alive"])
            for name, data, message in (("map_ver.bin", b"short", "truncated"),
                    ("map_worldgen.bin", b"short", "truncated"), ("mods.txt", b"mods{}", "mods differ"),
                    ("map_t.bin", b"", "missing"), ("players.db", b"broken", "database")):
                path = root / name
                original = path.read_bytes()
                path.write_bytes(data)
                with self.subTest(name=name), self.assertRaises((ValueError, sqlite3.Error)):
                    Run.saved_state(cache, receipt, BASE)
                path.write_bytes(original)
            changed = copy.deepcopy(BASE)
            changed["seed"] += "-different"
            with self.assertRaisesRegex(ValueError, "seed differs"):
                Run.saved_state(cache, receipt, changed)
            changed = copy.deepcopy(BASE)
            changed["extent"]["cellsX"] = 3
            with self.assertRaisesRegex(ValueError, "bounds differ"):
                Run.saved_state(cache, receipt, changed)
            receipt["host"] = "observer"
            with self.assertRaisesRegex(ValueError, "persisted a participating player"):
                Run.saved_state(cache, receipt, BASE)
            with closing(sqlite3.connect(root / "players.db")) as database:
                database.execute("DELETE FROM localPlayers")
                database.commit()
            self.assertEqual(Run.saved_state(cache, receipt, BASE), {"count": 0, "observerPersisted": False})

    def test_copied_mod_content_and_extra_files_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            cache = Path(tmp)
            mod = cache / "mods/Study/42.20/media/lua/client"
            mod.mkdir(parents=True)
            agent = cache / "agent.jar"
            agent.write_bytes(b"fixture-agent")
            bootstrap = mod / "ZZStudyLaunch.lua"
            bootstrap.write_bytes(b"fixture-launch")
            receipt = {"loadingAgentSha256": Run.digest(agent), "mapName": "Study", "mods": {"Study": {}},
                       "launchSha256": Run.digest(bootstrap)}
            Run.verify_inputs(cache, agent, receipt)
            bootstrap.write_bytes(b"changed")
            with self.assertRaisesRegex(ValueError, "content changed"):
                Run.verify_inputs(cache, agent, receipt)
            bootstrap.write_bytes(b"fixture-launch")
            (mod / "extra.lua").write_bytes(b"extra")
            with self.assertRaisesRegex(ValueError, "inventory changed"):
                Run.verify_inputs(cache, agent, receipt)

    def test_rectangle_and_negative_origin(self):
        value = copy.deepcopy(BASE)
        value["extent"] = {"minCellX": -2, "minCellY": -1, "cellsX": 4, "cellsY": 3}
        self.assertEqual(Lab.validate(value), value)

    def test_invalid_definitions(self):
        changes = [
            lambda d: d.update(id="../escape"),
            lambda d: d.update(seed="bad\nseed"),
            lambda d: d["extent"].update(cellsX=True),
            lambda d: d["extent"].update(cellsY=0),
            lambda d: d["origins"][0].update(x=-1),
            lambda d: d.update(origins=[{"x": 128, "y": 128, "z": 0, "profession": "carpenter"}]),
            lambda d: d["observation"]["windows"][0].update(width=10000),
            lambda d: d["observation"].update(everyHours=float("nan")),
            lambda d: d.update(targetOutcome="settlement"),
            lambda d: d["sandbox"].update(unknown={}),
        ]
        for change in changes:
            with self.subTest(change=change):
                value = copy.deepcopy(BASE)
                change(value)
                with self.assertRaises(ValueError):
                    Lab.validate(value)

    def test_static_module_bounds_exclusive_names_and_order(self):
        Lab.validate(BASE)
        reordered = copy.deepcopy(BASE)
        reordered["generation"]["staticModules"].reverse()
        self.assertNotEqual(Lab.seal(BASE), Lab.seal(reordered))
        changes = [
            lambda g: g.update(staticModules=[]),
            lambda g: g.update(staticModules={}),
            lambda g: g.update(staticModules=g["staticModules"] * 22),
            lambda g: g["staticModules"][0].update(biome="grass_plain"),
            lambda g: g["staticModules"][0].pop("prefab"),
            lambda g: g["staticModules"][0].update(prefab="../normal_road_WE_00"),
            lambda g: g["staticModules"][0].update(prefab=False),
            lambda g: g["staticModules"][0]["position"].update(xmin=-1),
            lambda g: g["staticModules"][0]["position"].update(xmax=512),
            lambda g: g["staticModules"][0]["position"].update(ymin=132),
            lambda g: g["staticModules"][0]["position"].update(ymax=131.5),
            lambda g: g["staticModules"][0]["position"].update(z=0),
            lambda g: g.update(resources="placed"),
        ]
        for change in changes:
            value = copy.deepcopy(BASE)
            change(value["generation"])
            with self.subTest(generation=value["generation"]), self.assertRaises(ValueError):
                Lab.validate(value)

    def test_legacy_road_only_packages_keep_their_shape(self):
        value = copy.deepcopy(BASE)
        value["generation"].pop("staticModules")
        value["generation"]["roads"] = {"small_road": {"p": 0.0005, "filter_edge": 5e8}}
        original = copy.deepcopy(value)
        with tempfile.TemporaryDirectory() as tmp, \
                patch.object(Lab, "engine_evidence", return_value={"jar": {"sha256": "a" * 64}}):
            out = Path(tmp) / "legacy"
            manifest = Lab.build(value, out, "unused")
            self.assertEqual(Lab.verify_package(out), (manifest, original))
            self.assertEqual(value, original)
            self.assertFalse(list(out.rglob("WorldGenOverride.lua")))

    def test_terrain_source_stays_bound_after_inventory_reseal(self):
        with tempfile.TemporaryDirectory() as tmp, \
                patch.object(Lab, "engine_evidence", return_value={"jar": {"sha256": "a" * 64}}):
            out = Path(tmp) / "package"
            manifest = Lab.build(BASE, out, "unused")
            override = next(out.rglob("WorldGenOverride.lua"))
            self.assertEqual(override.read_bytes(), Lab.static_modules_source(BASE["generation"]))
            override.write_bytes(override.read_bytes().replace(b"modules[i] = module", b"table.insert(modules, 1, module)"))
            relative = override.relative_to(out).as_posix()
            manifest["files"][relative] = Run.digest(override)
            (out / "package.json").write_bytes(Lab.canonical(manifest))
            with self.assertRaisesRegex(ValueError, "terrain override differs"):
                Lab.verify_package(out)

    def test_lua_literal_escapes_source(self):
        self.assertEqual(Lab.lua('"\\\n'), '"\\034\\092\\010"')
        self.assertNotIn("\n", Lab.lua("a\nb"))

    def test_duplicate_json_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            file = Path(tmp) / "duplicate.json"
            file.write_text('{"id":1,"id":2}', encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "duplicate"):
                Lab.load(file)

    def test_nested_numeric_overflow_refused(self):
        with self.assertRaisesRegex(ValueError, "non-finite"):
            Lab.decode('{"people":[{"record":{"value":1e999}}]}')

    def test_package_exclusive_and_deterministic(self):
        with tempfile.TemporaryDirectory() as tmp:
            a, b = Path(tmp) / "a", Path(tmp) / "b"
            with patch.object(Lab, "engine_evidence", return_value={"jar": {"sha256": "a" * 64}}):
                first = Lab.build(BASE, a, "unused")
                second = Lab.build(BASE, b, "unused")
                self.assertEqual(first, second)
                self.assertEqual(Lab.verify_package(a), (first, BASE))
                with self.assertRaisesRegex(ValueError, "already exists"):
                    Lab.build(BASE, a, "unused")
            self.assertEqual(first["datasetAdmission"], "unreviewed")
            self.assertEqual(first["status"], "built-unobserved")
            for relative in first["files"]:
                self.assertEqual((a / relative).read_bytes(), (b / relative).read_bytes())
            self.assertIn("lots=NONE", next(a.rglob("map.info")).read_text())
            self.assertTrue((a / "mod" / first["mapName"] / "common/media/maps/.keep").is_file(),
                            "native Continue cannot discover the versioned map")
            value = copy.deepcopy(BASE)
            value["seed"] += "-changed"
            self.assertNotEqual(Lab.seal(value), first["definitionSha256"])
            runtime = next(a.glob("mod/*/42.20/media/lua/client/*.lua"))
            runtime.write_bytes(runtime.read_bytes() + b"\n-- altered\n")
            with self.assertRaisesRegex(ValueError, "content changed"):
                Lab.verify_package(a)


def command(args, cwd):
    result = subprocess.run([str(x) for x in args], cwd=cwd, text=True,
                            capture_output=True, timeout=90)
    if result.returncode:
        raise AssertionError(result.stdout + result.stderr)
    return result.stdout


@unittest.skipUnless((GAME / "projectzomboid.jar").is_file(), "installed authored map unavailable")
class AuthoredMapTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix="study-authored-border-")
        cls.addClassCleanup(cls.temporary.cleanup)
        cls.work = Path(cls.temporary.name)
        cls.definition = Lab.load(Lab.ROOT / "tools/world_lab/definitions/echo-creek-residential.json")
        cls.package = cls.work / "package"
        cls.manifest = Lab.build(cls.definition, cls.package, GAME)
        cls.name = cls.manifest["mapName"]
        cls.version = cls.package / "mod" / cls.name / "42.20"
        cls.maps = cls.version / "media/maps" / cls.name
        cls.receipt = Lab.load(cls.package / "source-map.json")
        cls.source = cls.work / "source-installation"
        for relative in cls.receipt["inputs"]:
            target = cls.source / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(GAME / relative, target)

    def test_native_loaders_and_exact_extent(self):
        classes = self.work / "native-classes"
        classes.mkdir()
        command([JDK / "javac.exe", "-cp", GAME / "projectzomboid.jar", "-d", classes,
                 Lab.ROOT / "tools/world_lab/NativeAuthoredMapProbe.java"], GAME)
        launch = [JDK / "java.exe", "-ea", f"-Duser.home={classes}", "--enable-native-access=ALL-UNNAMED",
                  "-cp", str(GAME / "projectzomboid.jar") + os.pathsep + str(classes),
                  "zombie.pot.NativeAuthoredMapProbe", self.version, self.name, classes / "cache",
                  "13", "42", "14", "46"]
        definitions = [Lab.load(path) for path in sorted((Lab.ROOT / "tools/world_lab/definitions").glob("echo-creek-*.json"))]
        for definition in definitions:
            for origin in definition["origins"]:
                launch.extend(str(origin[k]) for k in ("x", "y", "z"))
        output = command(launch, GAME)
        native = [list(map(int, line.split()[1:])) for line in output.splitlines() if line.startswith("CELL ")]
        expected = [[row[k] for k in ("x", "y", "rooms", "buildings")] for row in self.receipt["cells"]]
        self.assertEqual(native, expected)
        self.assertIn("332 rooms, 76 buildings, 423 basement/access assets", output)
        self.assertEqual(sum(line.startswith("ORIGIN ") for line in output.splitlines()), 3)
        for line in output.splitlines():
            if line.startswith("ORIGIN "):
                print(line)
        print(output.splitlines()[-1])
        # Extra authored cell is actual native map-bound expansion, even though
        # it contains no scripted actor or behavior fixture.
        spill = self.maps / "15_42.lotheader"
        shutil.copyfile(GAME / "media/maps/Muldraugh, KY/15_42.lotheader", spill)
        try:
            with self.assertRaisesRegex(AssertionError, "spilled beyond"):
                command(launch, GAME)
        finally:
            spill.unlink()
        print("PASS native control refused: extra authored cell expands the loaded map")

    def test_real_copied_bytes_and_variants(self):
        self.assertEqual(Lab.verify_package(self.package)[1], self.definition)
        for relative, seal in self.receipt["inputs"].items():
            blob = (GAME / relative).read_bytes()
            self.assertEqual(seal, {"sha256": Lab.Authored.digest(blob), "bytes": len(blob)})
        variants = [Lab.validate(Lab.load(path)) for path in (Lab.ROOT / "tools/world_lab/definitions").glob("echo-creek-*.json")]
        self.assertEqual(sorted(v["sandbox"]["SurvivorAwareness.Population"] for v in variants), [2, 4, 7])
        for value in variants:
            self.assertEqual(value["sourceMap"], "Muldraugh, KY")
            self.assertEqual(value["extent"], self.definition["extent"])
        self.assertEqual(self.manifest["datasetAdmission"], "unreviewed")
        self.assertEqual(self.receipt["headerCatalog"]["count"], 4065)

    def test_native_spawn_regions_feed_actual_admissions_at_each_origin(self):
        # Reuse Border115's dependency host, not its outcomes or producer. The
        # actual installed region loader and production Admissions both run.
        import world_before_spawn_test as Spawn
        work = self.work / "spawn-kahlua"
        work.mkdir()
        command([JDK / "javac.exe", "-cp", GAME / "projectzomboid.jar", "-d", work,
                 Lab.ROOT / "tools/luacheck/LuaRun.java"], work)
        shutil.copyfile(GAME / "stdlib.lua", work / "stdlib.lua")
        installed = (GAME / "media/lua/shared/SpawnRegions.lua").read_text(encoding="utf-8")
        admissions = Spawn.ADMISSIONS.read_text(encoding="utf-8")
        for path in sorted((Lab.ROOT / "tools/world_lab/definitions").glob("echo-creek-*.json")):
            definition = Lab.load(path)
            origin = definition["origins"][0]
            target = definition["sandbox"]["SurvivorAwareness.Population"]
            name = "Study-" + definition["id"] + "-" + Lab.seal(definition)[:12]
            sources = {"media/maps/" + name + "/" + key: value
                       for key, value in Lab.spawn_sources(definition, name).items()}
            def source_table(values):
                return "{" + ",".join("[" + Lab.lua(k) + "]=function()\n" + v + "\nend" for k, v in sorted(values.items())) + "}"
            expected = Lab.lua({"x": origin["x"], "y": origin["y"], "z": origin["z"]})
            script = (Spawn.ADMISSION_HOST + '\nlocal Sources=' + source_table(sources)
                + '\nfileExists=function(path) return Sources[path]~=nil end\n'
                + 'reloadLuaFile=function(path) assert(Sources[path])() end\n'
                + 'string.contains=function(s,p) return string.find(s,p,1,true)~=nil end\n'
                + 'getWorld=function() return {getGameMode=function() return "Sandbox" end,getMap=function() return '
                + Lab.lua(name) + ' end} end\nisClient=function() return false end\ntriggerEvent=function() end\n'
                + installed + '\n__store={claims={},news={}}\n'
                + 'SAO.Census.rowOf=function() return {enginePath="unemployed",label="ordinary origin"} end\n'
                + 'SAO.Places.at=function() return nil end\nlocal Admissions=(function()\n' + admissions + '\nend)()\n'
                + 'local loaded=SpawnRegionMgr.getSpawnRegions() assert(loaded and #loaded==1,"native region not loaded")\n'
                + '\nSAO.PopulationAdmissions.ensurePopulation({population=' + str(target)
                + ',newcomers=' + str(target) + ',refillDays=3},5400)\nlocal expected=' + expected
                + '\nassert(#__created==' + str(target) + ',"cohort population differs: "..tostring(#__created))\n'
                + 'for _,rec in ipairs(__created) do assert(rec.x==expected.x and rec.y==expected.y and rec.z==expected.z'
                + ' and rec.homeX==expected.x and rec.homeY==expected.y and rec.homeZ==expected.z,"origin moved") end\n'
                + 'assert(#__claimCalls==0,"origin invented ownership")\nRESULT="PASS actual native spawn loader and admissions cohort '
                + str(target) + '"\n')
            check = work / "check.lua"
            check.write_text(script, encoding="utf-8")
            java = [JDK / "java.exe", "-cp", str(GAME / "projectzomboid.jar") + os.pathsep + str(work),
                    "LuaRun", check, "--", "RESULT"]
            print(command(java, work).strip())
            # Alter the generated point before string serialization. A real
            # origin change must flip the home/initial-position verdict.
            bad_sources = dict(sources)
            key = "media/maps/" + name + "/spawnpoints.lua"
            bad_sources[key] = bad_sources[key].replace('["posX"]=' + str(origin["x"]), '["posX"]=' + str(origin["x"] + 1))
            changed = script.replace(source_table(sources), source_table(bad_sources), 1)
            self.assertNotEqual(changed, script)
            check.write_text(changed, encoding="utf-8")
            with self.assertRaisesRegex(AssertionError, "origin moved"):
                command(java, work)

    def test_invalid_source_names_and_composition(self):
        for source in ("../Muldraugh, KY", "C:/maps", "Muldraugh, KY/../other", " bad", "Muldraugh, KY;other", "", None):
            value = copy.deepcopy(self.definition)
            value["sourceMap"] = source
            with self.subTest(source=source), self.assertRaises(ValueError):
                Lab.validate(value)
        value = copy.deepcopy(self.definition)
        value["generation"] = copy.deepcopy(BASE["generation"])
        with self.assertRaisesRegex(ValueError, "unchanged native terrain"):
            Lab.validate(value)
        value = copy.deepcopy(self.definition)
        value["extent"]["cellsX"] = 64
        with self.assertRaisesRegex(ValueError, "64 cells"):
            Lab.validate(value)
        with self.assertRaisesRegex(ValueError, "lots dependency"):
            Lab.Authored.map_info((GAME / "media/maps/Rosewood, KY/map.info").read_bytes())

    def test_corrupt_native_binary_and_metadata_controls(self):
        source = GAME / "media/maps/Muldraugh, KY"
        head = (source / "13_42.lotheader").read_bytes()
        info = Lab.Authored.header(head, 13, 42)
        pack = (source / "world_13_42.lotpack").read_bytes()
        chunks = (source / "chunkdata_13_42.bin").read_bytes()
        asset = (GAME / "media/binmap/lot_basement_house_01.pzby").read_bytes()
        bad_offset = pack[:12] + struct.pack("<q", len(pack) + 4) + pack[20:]
        controls = [
            (Lab.Authored.header, (b"NOPE" + head[4:], 13, 42)),
            (Lab.Authored.header, (head[:-1], 13, 42)),
            (Lab.Authored.lotpack, (bad_offset, info)),
            (Lab.Authored.lotpack, (pack[:-4], info)),
            (Lab.Authored.chunkdata, (b"\0\2" + chunks[2:],)),
            (Lab.Authored.chunkdata, (chunks[:-1],)),
            (Lab.Authored.binary_building, (b"NOPE" + asset[4:],)),
            (Lab.Authored.binary_building, (asset[:-1],)),
            (Lab.Authored.metadata_table, (b'objects={}; os.execute("command")', "objects")),
            (Lab.Authored.metadata_table, (b'objects={{name="a",name="b"}}', "objects")),
            (Lab.Authored.metadata_table, (b'objects={{x=1e999}}', "objects")),
            (Lab.Authored.basements, ((source / "basements.lua").read_bytes().replace(b"'Muldraugh, KY'", b"'Other'"), "Muldraugh, KY")),
        ]
        for fn, args in controls:
            with self.subTest(parser=fn.__name__, size=len(args[0])), self.assertRaises(ValueError):
                fn(*args)
        print("PASS 12 corrupt native binary / executable, duplicate, nonfinite or foreign metadata controls")

    def test_missing_source_files_and_cut_buildings(self):
        for relative in ("media/maps/Muldraugh, KY/world_13_42.lotpack",
                         "media/maps/Muldraugh, KY/objects.lua", "media/binmap/lot_basement_house_01.pzby"):
            path = self.source / relative
            blob = path.read_bytes()
            path.unlink()
            try:
                with self.subTest(source=relative), self.assertRaisesRegex(ValueError, "missing/escaped native source"):
                    Lab.Authored.prepare(self.source, self.definition, self.name, Lab.lua, Lab.canonical)
            finally:
                path.write_bytes(blob)
        value = copy.deepcopy(self.definition)
        value["extent"].update(cellsX=1, cellsY=1)
        with self.assertRaisesRegex(ValueError, "cuts building|cuts an authored room"):
            Lab.Authored.prepare(GAME, value, self.name, Lab.lua, Lab.canonical)
        # The same crop must fail if a partially overlapping building is rooted
        # in an omitted header: checking selected headers alone cannot prove it.
        value["extent"]["minCellX"] = 14
        original_contains = Lab.Authored.contains
        with patch.object(Lab.Authored, "contains", return_value=True):
            with self.assertRaisesRegex(ValueError, "cuts building rooted"):
                Lab.Authored.prepare(GAME, value, self.name, Lab.lua, Lab.canonical)
        self.assertIs(Lab.Authored.contains, original_contains)

    def test_resealed_cell_metadata_and_whole_map_spill(self):
        package = self.package
        manifest_path, receipt_path = package / "package.json", package / "source-map.json"
        original_manifest, original_receipt = manifest_path.read_bytes(), receipt_path.read_bytes()
        cases = [
            (self.maps / "map.info", lambda b: b.replace(b"lots=NONE", b"lots=Muldraugh, KY"), "map metadata differs"),
            (self.maps / "objects.lua", lambda b: b"objects={}\n", "metadata selection differs"),
            (self.maps / "spawnpoints.lua", lambda b: b.replace(b'3426', b'3427'), "spawn source differs"),
            (self.maps / "13_42.lotheader", lambda b: b[:-1], "truncated lotheader"),
            (self.maps / "15_42.lotheader", lambda b: (GAME / "media/maps/Muldraugh, KY/15_42.lotheader").read_bytes(), "inventory differs"),
        ]
        for path, change, expected in cases:
            old = path.read_bytes() if path.exists() else None
            path.write_bytes(change(old))
            try:
                receipt = copy.deepcopy(self.receipt)
                relative = path.relative_to(self.version).as_posix()
                if path.name not in ("map.info", "spawnpoints.lua"):
                    receipt["outputs"][relative] = Lab.Authored.digest(path.read_bytes())
                    source_path = "media/maps/Muldraugh, KY/" + path.name
                    if source_path in receipt["inputs"] and path.suffix in (".lotheader", ".lotpack", ".bin"):
                        receipt["inputs"][source_path] = {"sha256": Lab.Authored.digest(path.read_bytes()), "bytes": path.stat().st_size}
                receipt_path.write_bytes(Lab.canonical(receipt))
                manifest = copy.deepcopy(self.manifest)
                manifest["files"] = {p.relative_to(package).as_posix(): Lab.Authored.digest(p.read_bytes())
                                     for p in package.rglob("*") if p.is_file() and p != manifest_path}
                manifest_path.write_bytes(Lab.canonical(manifest))
                with self.subTest(file=path.name), self.assertRaisesRegex(ValueError, expected):
                    Lab.verify_package(package)
            finally:
                if old is None:
                    path.unlink()
                else:
                    path.write_bytes(old)
                manifest_path.write_bytes(original_manifest)
                receipt_path.write_bytes(original_receipt)

    def test_zone_geometry_and_source_override_are_not_silently_clipped(self):
        bounds = Lab.Authored.extent_bounds(self.definition["extent"])
        row = {"name": "native region", "type": "Region", "x": bounds[0] - 101, "y": bounds[1],
               "width": 200, "height": 100, "z": 0}
        source = ("regions=" + Lab.lua([row])).encode()
        with self.assertRaisesRegex(ValueError, "would lose native zone"):
            Lab.Authored.selected_metadata(source, "regions", bounds, "regions.lua")
        row["x"] += 1
        source = ("regions=" + Lab.lua([row])).encode()
        selected, _ = Lab.Authored.selected_metadata(source, "regions", bounds, "regions.lua")
        self.assertEqual(selected, [row], "original geometry must survive the native admission margin")
        override = ('worldgen["static_modules"]={{position={xmin=3300,xmax=3600,ymin=10800,ymax=11000},'
                    'biome=worldgen.biomes.water}}').encode()
        with self.assertRaisesRegex(ValueError, "intersects a source WorldGenOverride"):
            Lab.Authored.check_source_override(override, bounds)


def shell_owner_checks(tmp, jar):
    shell_path = Lab.ROOT / "java/src/com/sao/engine/SAOIsoPlayerShell.java"
    source = shell_path.read_text(encoding="utf-8")
    post = "super.postupdate();\n        } finally {\n            restoreGlobalOwners(keep, camera);"
    camera = "if (IsoCamera.getCameraCharacter() == camera || IsoCamera.setCameraCharacter(camera)) return;"
    Lab.require(source.count(post) == 1 and source.count(camera) == 1, "native owner control seams differ")
    variants = (("production", source, None),
                ("unguarded-postupdate", source.replace(post, "super.postupdate();\n        } finally {"),
                 "shell leaked global player owner"),
                ("unrestored-camera", source.replace(camera, "if (camera == camera) return;"),
                 "shell leaked camera owner"))
    classpath = os.pathsep.join((str(jar), str(Lab.ROOT / "mod/42.20/media/java/SAO.jar")))
    for label, code, expected in variants:
        work = tmp / label
        work.mkdir()
        changed = work / "SAOIsoPlayerShell.java"
        changed.write_text(code, encoding="utf-8")
        command([JDK / "javac.exe", "-encoding", "UTF-8", "-cp", classpath, "-d", work,
                 changed, Lab.ROOT / "tools/world_lab/ShellOwnerProbe.java"], work)
        try:
            output = command([JDK / "java.exe", f"-Duser.home={work}", "--enable-native-access=ALL-UNNAMED",
                "-cp", str(work) + os.pathsep + classpath, "ShellOwnerProbe"], work)
        except AssertionError as error:
            Lab.require(expected is not None and expected in str(error), "unexpected native owner failure: " + str(error))
            print("PASS control refused: " + label)
        else:
            Lab.require(expected is None, "native owner control survived: " + label)
            print(output.strip())


def participant_context_checks(tmp, java):
    controller = (Lab.ROOT / "mod/42.20/media/lua/client/SAO_Controller.lua").read_text(encoding="utf-8")
    start = controller.index("local function bodyForKey(")
    body = controller[start:controller.index("local function nearestHostilePerson(", start)]
    host = '''
SAO = { Body = { get = function() return nil end },
    Standing = { isPlayerKey = function() return false end },
    Participants = { player = function() return nil end } }
getSpecificPlayer = function() return nil end
local acting, foreign = {}, {}
SAOJavaBridge = { foreignBodyByName = function(self, context, name)
    assert(context == acting and name == "Test Person", 'foreign lookup lost actor cell context')
    return foreign
end }
'''
    assertion = "\nassert(bodyForKey('foreign:Test Person', acting) == foreign, 'foreign person requires a participating player')\n"
    for label, source in (("production", body), ("filtered world context", body.replace(
            'if contextBody and who ~= ""', 'contextBody = SAO.Participants.player(0)\n        if contextBody and who ~= ""'))):
        path = tmp / "foreign-context.lua"
        path.write_text(host + source + assertion, encoding="utf-8")
        try:
            command([*java, "LuaRun", path, "--", "true"], GAME)
        except AssertionError as error:
            Lab.require(label != "production" and "foreign person requires a participating player" in str(error),
                        "unexpected foreign-context failure: " + str(error))
        else:
            Lab.require(label == "production", "filtered foreign-context control survived")
    print("PASS foreign person resolution uses acting body context without a player; filtered-context control refused")


def generation_checks(tmp, jar):
    """Run generated production Lua through the real native map loader/reader."""
    work = tmp / "native-generation"
    classes = work / "classes"
    classes.mkdir(parents=True)
    command([JDK / "javac.exe", "-encoding", "UTF-8", "-cp", jar, "-d", classes,
             Lab.ROOT / "tools/world_lab/NativeGenerationProbe.java"], GAME)
    # Bind the probe's ordered predicate traversal to the installed caller:
    # native genRandomSquare takes index zero after filtering staticModules.
    bytecode = command([JDK / "javap.exe", "-classpath", jar, "-c", "-p",
                        "zombie.iso.worldgen.WorldGenChunk"], GAME)
    sections = re.split(r"\n(?=  (?:public|private|protected|static) )", bytecode)
    constructor = next(s for s in sections if "WorldGenChunk(long)" in s.split("\n", 1)[0])
    selection = next(s for s in sections if " genRandomSquare(" in s.split("\n", 1)[0])
    Lab.require(constructor.index("Method runLuaOverride:") < constructor.index("WorldGenReader.loadStaticModules:"),
                "native terrain override load order differs")
    Lab.require(re.search(r"iconst_0\s+\d+: invokeinterface[^\n]*java/util/List.get:\(I\)Ljava/lang/Object;\s+"
                          r"\d+: checkcast[^\n]*worldgen/StaticModule", selection),
                "native static module first-match caller differs")
    package = work / "package"
    manifest = Lab.build(BASE, package, GAME)
    override = next(package.rglob("WorldGenOverride.lua"))
    source = override.read_text(encoding="utf-8")
    variants = [("production", source, None)]
    for label, before, after, expected in (
        ("missing-modules", "worldgen.static_modules = modules", "worldgen.static_modules = {}",
         "native per-map override did not load all six regions"),
        ("reversed-order", "modules[i] = module", "table.insert(modules, 1, module)",
         "native first-match priority lost the origin road"),
        ("shortened-boundary", "modules[i] = module",
         "module.position.xmax = module.position.xmax - 1\n    modules[i] = module",
         "native inclusive road boundary lost"),
    ):
        Lab.require(source.count(before) == 1, "terrain mutation seam differs: " + label)
        variants.append((label, source.replace(before, after, 1), expected))
    java = [JDK / "java.exe", "-Djava.awt.headless=true", "--enable-native-access=ALL-UNNAMED",
            "-cp", str(classes) + os.pathsep + str(jar)]
    for label, code, expected in variants:
        target = work / label
        map_path = target / manifest["mapName"] / "WorldGenOverride.lua"
        map_path.parent.mkdir(parents=True)
        map_path.write_text(code, encoding="utf-8")
        result = subprocess.run([str(v) for v in [*java, "-Duser.home=" + str(target), "NativeGenerationProbe",
                                GAME, map_path, target / "cache"]], cwd=GAME, text=True,
                                capture_output=True, timeout=90)
        (target / "stdout.log").write_text(result.stdout, encoding="utf-8")
        (target / "stderr.log").write_text(result.stderr, encoding="utf-8")
        output = result.stdout + result.stderr
        if expected is None:
            Lab.require(result.returncode == 0 and "PASS native terrain loader:" in output,
                        "native terrain baseline failed: " + output)
            print(result.stdout.strip())
        else:
            Lab.require(result.returncode != 0 and expected in output,
                        "terrain control survived or failed for another reason: " + label + "\n" + output)
            print("PASS terrain control refused: " + label)


def native_checks():
    supervision_spec = importlib.util.spec_from_file_location("supervision_checks", Lab.ROOT / "tools/world_lab/supervision_checks.py")
    supervision = importlib.util.module_from_spec(supervision_spec)
    supervision_spec.loader.exec_module(supervision)
    supervision.run()
    jar = GAME / "projectzomboid.jar"
    if not jar.exists():
        print("SKIPPED study native checks: installed game unavailable")
        return
    require = Lab.require
    require((JDK / "javac.exe").exists(), "native compiler unavailable")
    with tempfile.TemporaryDirectory(prefix="study-border-") as name:
        tmp = Path(name)
        generation_checks(tmp, jar)
        probe_spec = importlib.util.spec_from_file_location("observer_probe_checks", Lab.ROOT / "tools/world_lab/observer_probe_checks.py")
        observer_probe = importlib.util.module_from_spec(probe_spec)
        probe_spec.loader.exec_module(observer_probe)
        observer_probe.run_startup(tmp, GAME, JDK)
        observer_probe.run(tmp, GAME, JDK)
        observer_probe.run_capture(tmp, GAME, JDK)
        observer_probe.run_visibility(tmp, GAME, JDK)
        unload_spec = importlib.util.spec_from_file_location("shell_unload_checks", Lab.ROOT / "tools/world_lab/shell_unload_checks.py")
        unload_probe = importlib.util.module_from_spec(unload_spec)
        unload_spec.loader.exec_module(unload_probe)
        unload_probe.run(tmp, GAME, JDK)
        transfer_spec = importlib.util.spec_from_file_location("transfer_ui_checks", Lab.ROOT / "tools/world_lab/transfer_ui_checks.py")
        transfer_probe = importlib.util.module_from_spec(transfer_spec)
        transfer_spec.loader.exec_module(transfer_probe)
        transfer_probe.run(tmp, GAME, JDK)
        night_spec = importlib.util.spec_from_file_location("night_rest_checks", Lab.ROOT / "tools/world_lab/night_rest_checks.py")
        night_probe = importlib.util.module_from_spec(night_spec)
        night_spec.loader.exec_module(night_probe)
        night_probe.run(tmp, GAME, JDK)
        shell_owner_checks(tmp, jar)
        cache = tmp / "cache"
        cache.mkdir()
        command([JDK / "javac.exe", "-cp", jar, "-d", tmp,
                 Lab.ROOT / "tools/luacheck/LuaRun.java",
                 Lab.ROOT / "tools/world_lab/NativeStudyProbe.java"], GAME)
        java = [GAME / "jre64/bin/java.exe", "-Djava.awt.headless=true",
                "--enable-native-access=ALL-UNNAMED", "-cp", str(jar) + os.pathsep + str(tmp)]
        participant_context_checks(tmp, java)
        print(command([*java, "NativeStudyProbe", cache], GAME).strip())
        participants = tmp / "participants.lua"
        participant_source = (Lab.ROOT / "mod/42.20/media/lua/shared/SAO_Participants.lua").read_text()
        participants.write_text(participant_source + '''
local marked = false
local body = { getModData = function() return { SAO_ObserverAnchor = marked } end,
    getX = function() return 128 end, getY = function() return 129 end, getZ = function() return 0 end }
getSpecificPlayer = function() return body end
assert(SAO.Participants.player(0) == body, 'ordinary participant excluded')
marked = true
assert(SAO.Participants.player(0) == nil, 'observer admitted as a participant')
local x, y, z = SAO.Participants.residencyCenter()
assert(x == 128 and y == 129 and z == 0, 'observer residency lost')
getSpecificPlayer = function() return nil end
assert(SAO.Participants.player(0) == nil and SAO.Participants.residencyCenter() == nil)
''', encoding="utf-8")
        print(command([*java, "LuaRun", participants, "--", "'PASS participant and residency separation'"], GAME).strip())
        participants.write_text(participants.read_text().replace(
            "if P.isObserver(body) then return nil end", "-- known-bad: admit observer"), encoding="utf-8")
        rejected = subprocess.run([str(v) for v in [*java, "LuaRun", participants, "--", "true"]],
                                  cwd=GAME, capture_output=True, text=True)
        require(rejected.returncode != 0 and "observer admitted" in rejected.stdout + rejected.stderr,
                "participant admission mutant survived")
        print("PASS control refused: observer admitted as participant")
        places = (Lab.ROOT / "mod/42.20/media/lua/shared/SAO_Places.lua").read_text(encoding="utf-8")
        places_check = tmp / "places.lua"
        places_check.write_text("SAO = {}\ngetCell = function() error('instance accessor used') end\n"
            "getCellSizeInSquares = function() return 384 end\nlocal Places = (function()\n"
            + places + "\nend)()\nassert(Places.cellSpan() == 384, 'native global ignored')\n"
            "assert(Places.comfortHorizon() == 192)\nPlaces.reset()\ngetCellSizeInSquares = nil\n"
            "assert(Places.cellSpan() == 256, 'current cell format differs')\nRESULT='PASS native cell-size binding'\n",
            encoding="utf-8")
        print(command([*java, "LuaRun", places_check, "--", "RESULT"], GAME).strip())
        launch = (Lab.ROOT / "tools/world_lab/StudyLaunch.lua").read_text(encoding="utf-8")
        launch_checks = (Lab.ROOT / "tools/world_lab/LaunchChecks.lua").read_text(encoding="utf-8")
        launch_path = tmp / "launch.lua"
        seam = 'playerReceipt("horizon", launchPlayer)'
        require(launch.count(seam) == 1, "launch receipt control seam differs")
        for label, code in (("production", launch), ("mutable global", launch.replace(
                seam, 'playerReceipt("horizon", getPlayer())'))):
            launch_path.write_text('local RunConfig = { attempt=1, hours=0.3 }\n' + launch_checks
                + '\n' + code + '\nRESULT = CheckLaunchReceipts()\n', encoding="utf-8")
            try:
                output = command([*java, "LuaRun", launch_path, "--", "RESULT"], GAME)
            except AssertionError as error:
                require(label == "mutable global" and "receipt switched to another body" in str(error),
                        "unexpected launch receipt failure: " + str(error))
                print("PASS control refused: launch receipt switched to another body")
            else:
                require(label == "production", "launch receipt control survived")
                print(output.strip())
        for paused in (True, False):
            launch_path.write_text('local RunConfig = { attempt=1, hours=0.3 }\n' + launch_checks
                + '\n' + launch + '\nRESULT = CheckLaunchWallLimit(' + str(paused).lower() + ')\n', encoding="utf-8")
            print(command([*java, "LuaRun", launch_path, "--", "RESULT"], GAME).strip())
        package_path = tmp / "package"
        manifest = Lab.build(BASE, package_path, GAME)
        config = {**BASE, "mapName": manifest["mapName"], "definitionSha256": Lab.seal(BASE),
                  "engineJarSha256": manifest["engine"]["jar"]["sha256"],
                  "observerSha256": manifest["observerSha256"]}
        source = Lab.TEMPLATE.read_text(encoding="utf-8")
        checks = (Lab.ROOT / "tools/world_lab/RuntimeChecks.lua").read_text(encoding="utf-8")

        def execute(runtime, expression="RESULT"):
            script = tmp / "checks.lua"
            script.write_text("local Config = " + Lab.lua(config) + "\n" + checks
                              + "\nlocal Study = (function()\n" + runtime
                              + "\nend)()\nRESULT = RunStudyChecks(Study)\n"
                              + "RESULT_CAPTURE = Study.encode({result=RESULT, failureLog=RESULT_FAILURE_LOG, "
                              + "frame=RESULT_FRAME, live=RESULT_LIVE_FRAME})\n", encoding="utf-8")
            # Windows JVM stdout otherwise uses the native console charset even
            # when Python decodes UTF-8, corrupting valid non-ASCII fixture data.
            result = subprocess.run([str(value) for value in
                [java[0], "-Dstdout.encoding=UTF-8", "-Dsun.stdout.encoding=UTF-8",
                 *java[1:], "LuaRun", script, "--", expression]], cwd=GAME, text=True,
                encoding="utf-8", capture_output=True, timeout=90)
            if result.returncode:
                raise AssertionError(result.stdout + result.stderr)
            return result.stdout

        execution = Lab.decode(execute(source, "RESULT_CAPTURE").split("VALUE ", 1)[1].strip())
        print(execution["result"])
        require("[StudyWorld] stopped:" in execution["failureLog"],
                "observer stop is invisible to native runner")
        observed = Lab.decode(execution["frame"])
        Lab.validate_frame(observed)
        live_text = execution["live"]
        live = Lab.decode(live_text)
        start = live_text.index('"inspection":') + len('"inspection":')
        _, end = json.JSONDecoder().raw_decode(live_text, start)
        require(len(live_text.encode("utf-8")) <= 1024 * 1024, "live native byte cap exceeded")
        require(len(live_text[start:end].encode("utf-8")) <= 256 * 1024, "inspection native byte cap exceeded")
        require(live["population"]["captured"] == live["population"]["total"] == 16,
                "optional inspection displaced ordinary people")
        inspection = live["inspection"]
        require(inspection["capturedAtUnixMs"] == 123450000 and inspection["sequence"] == 27,
                "inspection source clock changed")
        selected_rows = inspection["people"]["p16"]["sections"][0]["rows"]
        require(selected_rows and "\u00e9" in selected_rows[0]["label"], "selected Unicode inspection missing")
        require(len(inspection["message"]) <= 512 and "Export byte budget:" in inspection["message"]
                and inspection["omittedEvents"] > 0, "inspection omissions absent or malformed")
        print("PASS bounded inspection: 16 maximal people, escaped UTF-8, selection, omissions, failure and recovery")
        observations = tmp / "observations"
        observations.mkdir()
        first = observations / "0001.json"
        first.write_bytes(Lab.canonical(observed))
        second = copy.deepcopy(observed)
        second.update(sequence=2, hours=observed["hours"] + 1)
        (observations / "0002.json").write_bytes(Lab.canonical(second))
        require(Lab.inspect_frames(observations)["frames"] == 2, "valid frames not inspected")
        require(Lab.inspect_frames(observations, package_path)["packageSha256"] == Lab.seal(manifest),
                "valid package not bound")
        package = Lab.verify_package(package_path)
        for change in (
            lambda f: f.update(observerSha256="f" * 64),
            lambda f: f.update(map="another-map"),
            lambda f: f["windows"][0].update(width=1),
            lambda f: f["sandbox"].update(anotherOption=True),
        ):
            invalid = copy.deepcopy(observed)
            change(invalid)
            try:
                Lab.bind_frame(invalid, package)
            except ValueError:
                pass
            else:
                raise AssertionError("foreign package observation accepted")
        print("PASS package binding: complete inventory, observer, configuration and four mismatch controls")
        changes = [
            lambda f: f["coverage"].update(loadedSquares=999, unavailableSquares=-999),
            lambda f: f.update(definitionSha256="not-a-hash"),
            lambda f: f.pop("windows"),
            lambda f: f["population"].update(captured=100),
            lambda f: f["people"].append(copy.deepcopy(f["people"][0])),
            lambda f: f.update(datasetAdmission="approved"),
        ]
        for change in changes:
            invalid = copy.deepcopy(observed)
            change(invalid)
            try:
                Lab.validate_frame(invalid)
            except ValueError:
                pass
            else:
                raise AssertionError("invalid frame accepted")
        duplicate = Lab.canonical(observed).decode().replace('{', '{"sequence":999,', 1)
        try:
            Lab.decode(duplicate)
        except ValueError:
            pass
        else:
            raise AssertionError("duplicate frame keys accepted")
        print("PASS observation inspection: captured fixture, streaming session, 7 malformed controls")
        mutants = [
            ("UTF-8 budget", "local length = utf8Bytes(s) + 2", "local length = #s + 2", "UTF-8 byte limit ignored"),
            ("aggregate inspection budget", "local function inspectionSnapshot(maxBytes)",
             "local function inspectionSnapshot(maxBytes)\n    if SAO.Observation then return SAO.Observation.snapshot() end",
             "oversized optional inspection stopped production"),
            ("selected inspection priority", "table.insert(ids, 1, snapshot.selectedPersonId)",
             "table.insert(ids, snapshot.selectedPersonId)", "selected inspection omitted before other people"),
            ("inspection source immutability", "return result\nend\nlocal function objectView(object)",
             "snapshot.people[snapshot.selectedPersonId].events = {}\n    return result\nend\nlocal function objectView(object)",
             "inspection projection mutated source cache"),
            ("inspection source clock", 'result.people, result.status = {}, "failed"',
             'result.people, result.status = {}, "failed"; result.capturedAtUnixMs = getTimestampMs()',
             "failed export changed successful source timestamp"),
            ("native road selection", "originalRoads, worldgen.roads = worldgen.roads, roads",
             "originalRoads = worldgen.roads", "unrequested native roads retained"),
            ("other-world isolation", "getWorld():getMap() == Config.mapName", "true", "other-world isolation failed"),
            ("unloaded coverage", "frame.coverage.unavailableSquares + 1", "frame.coverage.unavailableSquares + 0", "unloaded geometry was claimed observed"),
            ("dataset review", 'datasetAdmission = "unreviewed"', 'datasetAdmission = "approved"', "observation ratified itself"),
            ("save identity", 'state.definitionSha256 == Config.definitionSha256', 'true', "foreign save admitted"),
            ("native writer extension", '.. ".json"', '.. ".jsonl"', "native writer disallows extension"),
            ("write acknowledgement", 'assert(received == line and extra == nil,', 'assert(true,', "failed write acknowledged"),
            ("world creation", 'Events.OnInitGlobalModData.Add(function(isNewWorld)\n    if selected() then newGame = isNewWorld == true end\nend)',
             'Events.OnNewGame.Add(function() if selected() then newGame = true end end)', "unbound reopened save admitted"),
        ]
        for label, before, after, expected in mutants:
            require(before in source, "mutation did not land: " + label)
            changed = source.replace(before, after, 1)
            require(changed != source, "mutation unchanged: " + label)
            try:
                execute(changed)
            except AssertionError as error:
                require(expected in str(error), "unexpected mutant failure: " + str(error))
                print("PASS control refused: " + label)
            else:
                raise AssertionError("surviving mutation: " + label)


if __name__ == "__main__":
    result = unittest.TextTestRunner(verbosity=1).run(
        unittest.TestSuite(unittest.defaultTestLoader.loadTestsFromTestCase(cls)
                           for cls in (DefinitionTests, AuthoredMapTests)))
    if not result.wasSuccessful():
        raise SystemExit(1)
    native_checks()
    print("Border 198: study packaging and observation checks completed; gameplay and observer independence remain separate")
