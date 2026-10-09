#!/usr/bin/env python3
"""Portable native-input classification and missing-owned refusal controls."""
import contextlib
import io
import tempfile
import unittest
from pathlib import Path

import native_proof_preflight as native


class NativeInputClassification(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="sao-preflight-controls-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.owned = self.root / "owned" / "runner.py"
        self.owned.parent.mkdir()
        self.owned.write_text("owned fixture\n", encoding="utf-8")

    def classify(self, inputs, game, roots=()):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            code = native.installed_presence(
                inputs, game, self.root / "absent-jdk", "classification control",
                installed_roots=roots)
        return code, output.getvalue()

    def test_windows_path_components_are_preserved(self):
        source = native.installed_path(r"C:\Steam\steamapps\common\ProjectZomboid")
        self.assertEqual(source.parent.name.lower(), "common")
        self.assertEqual(source.name, "ProjectZomboid")

    def test_windows_workshop_is_installed_for_both_separator_forms(self):
        for game in (r"C:\Steam\steamapps\common\ProjectZomboid",
                     "C:/Steam/steamapps/common/ProjectZomboid"):
            for source in (r"C:\Steam\steamapps\workshop\content\108600\123\mods\Example\media\lua\source.lua",
                           "C:/Steam/steamapps/workshop/content/108600/123/mods/Example/media/lua/source.lua"):
                with self.subTest(game=game, source=source):
                    code, output = self.classify([self.owned, source], game)
                    self.assertEqual(code, 0)
                    self.assertIn("SKIPPED", output)
                    self.assertNotIn("owned proof inputs absent", output)

    def test_declared_source_root_survives_absent_game_override(self):
        root = r"D:\Workshop\Example\media"
        source = "D:/Workshop/Example/media/scripts/items.txt"
        code, output = self.classify([self.owned, source], self.root / "absent-game", [root])
        self.assertEqual(code, 0)
        self.assertIn("installed proof inputs absent", output)
        self.assertIn("unchecked", output)

    def test_posix_source_and_sibling_workshop_are_installed(self):
        game = self.root / "steamapps" / "common" / "ProjectZomboid"
        source = self.root / "steamapps" / "workshop" / "content" / "108600" / "123" / "source.lua"
        code, output = self.classify([self.owned, source], game)
        self.assertEqual(code, 0)
        self.assertIn("SKIPPED", output)

    def test_missing_owned_input_remains_failure_with_game_absent(self):
        missing = self.owned.with_name("missing-owner.lua")
        root = self.root / "external-source"
        code, output = self.classify([self.owned, missing, root / "source.lua"],
                                     self.root / "absent-game", [root])
        self.assertEqual(code, 1)
        self.assertIn("owned proof inputs absent", output)
        self.assertIn(str(missing), output)
        self.assertNotIn("SKIPPED", output)

    def test_source_root_does_not_cover_similarly_named_owned_path(self):
        root = self.root / "external-source"
        missing = self.root / "external-source-owner" / "owner.lua"
        code, output = self.classify([self.owned, missing], self.root / "absent-game", [root])
        self.assertEqual(code, 1)
        self.assertIn("owned proof inputs absent", output)

    def test_complete_input_inventory_is_ready(self):
        game, jdk, source = (self.root / name for name in ("game", "jdk", "source"))
        for path in (game / "projectzomboid.jar", jdk / "java.exe", jdk / "javac.exe", source / "source.lua"):
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"presence fixture\n")
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            code = native.installed_presence([self.owned, source / "source.lua"], game, jdk,
                                               "complete control", installed_roots=[source])
        self.assertIsNone(code)
        self.assertEqual(output.getvalue(), "")


if __name__ == "__main__":
    unittest.main()
