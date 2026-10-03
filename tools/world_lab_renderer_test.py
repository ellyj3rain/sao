"""Focused native observer composite sizing and continuation option controls."""
import ast
import os
from pathlib import Path
import subprocess
import tempfile
import types
import unittest
from unittest.mock import patch

import world_lab_run as Run


def sites(count):
    return [dict(id=f"site-{slot}", label=f"Subject {slot}", x=slot * 100, y=100, z=0) for slot in range(count)]


def resume_wiring(source):
    """Inspect executable call order; a later legacy resize would undo sizing."""
    tree = ast.parse(source)
    run = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == "run")
    calls = [n for n in ast.walk(run) if isinstance(n, ast.Call)]
    renderer = [n for n in calls if isinstance(n.func, ast.Name) and n.func.id == "prepare_renderer"]
    selections = [n for n in calls if isinstance(n.func, ast.Attribute) and isinstance(n.func.value, ast.Name)
                  and n.func.value.id == "ObserverLayout" and n.func.attr == "sites"]
    resizes = [n for n in calls if isinstance(n.func, ast.Attribute) and isinstance(n.func.value, ast.Name)
               and n.func.value.id == "ObserverLayout" and n.func.attr == "resize"]
    if len(renderer) != 1 or len(selections) != 1 or resizes or renderer[0].lineno <= selections[0].lineno:
        return False
    keywords = {k.arg: k.value for k in renderer[0].keywords}
    value = keywords.get("dimensions")
    return (isinstance(value, ast.Call) and isinstance(value.func, ast.Name) and value.func.id == "renderer_dimensions"
            and len(value.args) == 1 and isinstance(value.args[0], ast.Name) and value.args[0].id == "selected_sites")


class RendererOptions(unittest.TestCase):
    def test_one_two_three_four_native_composite_sources(self):
        expected = {0: (960, 540), 1: (960, 540), 2: (2560, 720), 3: (1920, 1080), 4: (1920, 1080)}
        for count, dimensions in expected.items():
            with self.subTest(count=count):
                self.assertEqual(Run.renderer_dimensions(sites(count)), dimensions)
                self.assertLessEqual(dimensions[0], 4096); self.assertLessEqual(dimensions[1], 2160)
        for invalid in ({}, "two", sites(5)):
            with self.assertRaises(ValueError): Run.renderer_dimensions(invalid)

    def test_resume_refreshes_only_owned_options_and_removes_duplicates(self):
        with tempfile.TemporaryDirectory() as name:
            cache = Path(name); path = cache / "options.ini"
            unrelated = "version=8\nsoundVolume=0\nzoomLevels1=50;75;100;150\n# retained comment\n"
            path.write_text(unrelated + "width=1920\nwidth=960\nheight=1080\nheight=540\nframeRate=30\n"
                            "frameRate=60\nuncappedFPS=true\nuncappedFPS=false\nvsync=true\n", encoding="utf-8")
            dimensions = Run.renderer_dimensions(sites(2))
            Run.prepare_renderer(cache, dimensions=dimensions)
            expected = unrelated + "width=2560\nheight=720\nframeRate=120\nuncappedFPS=false\nvsync=false\n"
            self.assertEqual(path.read_text(encoding="utf-8"), expected)
            Run.prepare_renderer(cache, dimensions=dimensions)
            self.assertEqual(path.read_text(encoding="utf-8"), expected)
            Run.prepare_renderer(cache, dimensions=Run.renderer_dimensions(sites(4)))
            self.assertEqual(path.read_text(encoding="utf-8"), expected.replace("2560", "1920").replace("height=720", "height=1080"))
            Run.prepare_renderer(cache, dimensions=Run.renderer_dimensions(sites(1)))
            self.assertIn("width=960\nheight=540\n", path.read_text(encoding="utf-8"))

    def test_default_call_preserves_existing_dimensions_and_startup_limit(self):
        with tempfile.TemporaryDirectory() as name:
            cache = Path(name); path = cache / "options.ini"
            path.write_text("width=2560\nheight=720\nvsync=true\nframeRate=30\nuncappedFPS=true\n")
            Run.prepare_renderer(cache)
            self.assertEqual(path.read_text(), "width=2560\nheight=720\nframeRate=120\nuncappedFPS=false\nvsync=false\n")

    def test_invalid_dimensions_never_change_owned_cache(self):
        with tempfile.TemporaryDirectory() as name:
            cache = Path(name); path = cache / "options.ini"; original = "width=960\nheight=540\n"
            path.write_text(original)
            for dimensions in ((0, 720), (4097, 720), (2560, 2161), (2560, 0), (True, 720), (2560, "720"), (), {}):
                with self.subTest(dimensions=dimensions), self.assertRaises(ValueError):
                    Run.prepare_renderer(cache, dimensions=dimensions)
                self.assertEqual(path.read_text(), original)

    @unittest.skipUnless(os.name == "nt", "Native runner preparation requires Windows")
    def test_initial_preparation_writes_same_native_dimensions(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name); game = root / "game"; game.mkdir(); (game / "projectzomboid.jar").write_bytes(b"fixture-engine")
            package = root / "package"; map_source = package / "mod" / "FixtureMap"; map_source.mkdir(parents=True)
            folders = [root / identity for identity in ("SurvivorAwareness", "ZombieBuddy")]
            for folder in [*folders, map_source]:
                folder.mkdir(exist_ok=True); (folder / "mod.info").write_text("fixture metadata")
            def metadata(source):
                return source / "mod.info", {"id": source.name}
            def agent(destination, *_):
                path = destination / "StudyLoadingAgent.jar"; path.write_bytes(b"fixture-agent"); return path
            manifest = dict(engine={"jar": {"sha256": Run.digest(game / "projectzomboid.jar")}},
                            mapName="FixtureMap", definitionSha256="a" * 64)
            for count in (1, 2, 4):
                definition = {"observation": {"sites": sites(count)}}
                with patch.object(Run.Lab, "verify_package", return_value=(manifest, definition)), \
                     patch.object(Run.Profiles, "mod_metadata", side_effect=metadata), \
                     patch.object(Run, "build_observer_adapter", side_effect=agent), \
                     patch.object(Run, "native_lots_evidence", return_value=None):
                    cache, _, _, _, _ = Run.prepare(package, root / f"run-{count}", game, root / "jdk", folders)
                width, height = Run.renderer_dimensions(sites(count))
                options = (cache / "options.ini").read_text()
                self.assertIn(f"width={width}\nheight={height}\n", options)
                self.assertEqual(options.count("width="), 1); self.assertEqual(options.count("height="), 1)
                self.assertIn("frameRate=120\n", options); self.assertIn("uncappedFPS=false\n", options)

    def test_production_resume_uses_selected_layout_without_later_resize(self):
        source = Path(Run.__file__).read_text(encoding="utf-8")
        self.assertTrue(resume_wiring(source))
        before = "prepare_renderer(cache, dimensions=renderer_dimensions(selected_sites))"
        self.assertEqual(source.count(before), 1)
        for after in ("prepare_renderer(cache)", before + "\n            ObserverLayout.resize(cache, selected_sites)"):
            mutation = source.replace(before, after)
            self.assertNotEqual(mutation, source); self.assertFalse(resume_wiring(mutation))

    def test_source_controls_detect_portrait_dimensions_and_duplicate_option_keys(self):
        source = Path(Run.__file__).read_text(encoding="utf-8")
        controls = [("two-site-portrait", "return 2560, 720", "return 1920, 1080"),
                    ("duplicate-dimensions", 'keys.update(("width", "height"))', "keys.update(())")]
        for label, before, after in controls:
            self.assertEqual(source.count(before), 1)
            changed = source.replace(before, after); self.assertNotEqual(changed, source)
            module = types.ModuleType("renderer_control_" + label); module.__dict__["__file__"] = Run.__file__
            exec(compile(changed, "<renderer-control>", "exec"), module.__dict__)
            if label == "two-site-portrait":
                self.assertNotEqual(module.renderer_dimensions(sites(2)), (2560, 720))
            else:
                with tempfile.TemporaryDirectory() as name:
                    cache = Path(name); path = cache / "options.ini"; path.write_text("width=1920\nheight=1080\n")
                    module.prepare_renderer(cache, dimensions=(2560, 720))
                    self.assertEqual(path.read_text().count("width="), 2)
        self.assertEqual(Run.renderer_dimensions(sites(2)), (2560, 720))

    def test_installed_engine_two_site_split_differs_from_four(self):
        game = Path(os.environ.get("PZ_DIR", r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"))
        javap = Path(os.environ.get("JDK_BIN", str(Path.home() / "Peanut Butter/JetBrains/Java/bin"))) / "javap.exe"
        if not (game / "projectzomboid.jar").is_file() or not javap.is_file():
            self.skipTest("Installed engine/JDK unavailable; native viewport split unverified")
        result = subprocess.run([str(javap), "-classpath", str(game / "projectzomboid.jar"), "-c", "-p", "zombie.iso.IsoCamera"],
                                capture_output=True, text=True, timeout=30, check=True)
        def method(name):
            body = result.stdout.split(f"public static int {name}(int);", 1)[1]
            return body.split("\n  public ", 1)[0]
        width, height = method("getScreenWidth"), method("getScreenHeight")
        self.assertIn("iconst_1", width); self.assertIn("if_icmple", width); self.assertIn("idiv", width)
        self.assertIn("iconst_2", height); self.assertIn("if_icmple", height); self.assertIn("idiv", height)
        # Bytecode confirms native W/2,H for two; W/2,H/2 for four.
        two, four = Run.renderer_dimensions(sites(2)), Run.renderer_dimensions(sites(4))
        self.assertEqual((two[0] // 2, two[1]), (1280, 720))
        self.assertEqual((four[0] // 2, four[1] // 2), (960, 540))
        self.assertEqual((two[0] // 2) * 9, two[1] * 16)
        self.assertEqual((four[0] // 2) * 9, (four[1] // 2) * 16)


if __name__ == "__main__":
    raise SystemExit(0 if unittest.main(exit=False).result.wasSuccessful() else 1)
