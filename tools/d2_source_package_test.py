"""Owned package import/custody controls. No game runtime or rendering claim."""
import argparse
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import sys
import d2_source_package as package


class PackageControls(unittest.TestCase):
    def fixture(self, temporary):
        root=Path(temporary);workshop=root/'workshop';mod=root/'mod'
        source=workshop/'source'
        for version in ('common','42','42.13'):
            (source/version/'media/lua/shared').mkdir(parents=True)
        (source/'42/mod.info').write_text('id=SourceA\npack=SourcePack\ntiledef=SourceTiles 51\n')
        (source/'common/media/lua/shared/Action.lua').write_text('SourceAction={version=1}\n')
        (source/'42/media/lua/shared/Action.lua').write_text('SourceAction={version=2}\n')
        (source/'42.13/media/lua/shared/Old.lua').write_text('old=true\n')
        (source/'42/media/textures').mkdir();(source/'42/media/textures/Art.png').write_bytes(b'actual-source-art')
        return root,workshop,mod,{'SourceA':('source','42','Author','Exact installed terms')}

    def test_selected_payload_original_vault_native_asset_and_seal(self):
        with tempfile.TemporaryDirectory() as tmp:
            root,workshop,mod,sources=self.fixture(tmp)
            with patch.dict(package.SOURCES,sources,clear=True):
                manifest,outputs,collisions=package.build_plan(workshop,mod)
            self.assertFalse(collisions)
            self.assertEqual(outputs['media/SAOSources/SourceA/media/lua/shared/Action.lua'],(workshop/'source/42/media/lua/shared/Action.lua').read_bytes())
            self.assertEqual(outputs['media/textures/Art.png'],b'actual-source-art')
            self.assertFalse(any('Old.lua' in name for name in outputs))
            self.assertIn('SAO.SourceIntegration.active("SourceA")',outputs['media/lua/shared/Action.lua'].decode())
            for relative,data in outputs.items():
                path=mod/relative;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
            self.assertEqual(package.validate_owned(mod)['status'],'PASS')
            (mod/'media/textures/Art.png').write_bytes(b'foreign-art')
            self.assertEqual(package.validate_owned(mod)['errors'][0]['kind'],'owned-runtime-or-asset-mismatch')

    def test_missing_original_and_false_sentinel_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            root,workshop,mod,sources=self.fixture(tmp)
            with patch.dict(package.SOURCES,sources,clear=True):
                manifest,outputs,collisions=package.build_plan(workshop,mod)
            for relative,data in outputs.items():
                path=mod/relative;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
            (mod/'media/SAOSources/SourceA/media/lua/shared/Action.lua').unlink()
            (mod/'media/SAOSources/SourceA/package.txt').write_text('invented grant\n')
            kinds={row['kind'] for row in package.validate_owned(mod)['errors']}
            self.assertEqual(kinds,{'owned-original-mismatch','owned-source-seal-mismatch'})

    def test_existing_owned_foreign_bytes_are_never_overwritten(self):
        with tempfile.TemporaryDirectory() as tmp:
            root,workshop,mod,sources=self.fixture(tmp)
            path=mod/'media/textures/Art.png';path.parent.mkdir(parents=True);path.write_bytes(b'canonical art')
            with patch.dict(package.SOURCES,sources,clear=True):
                _,_,collisions=package.build_plan(workshop,mod)
            self.assertEqual(collisions[0]['kind'],'owned-existing-destination')
            self.assertEqual(path.read_bytes(),b'canonical art')

    def test_translation_namespace_preserves_canonical_and_source_keys(self):
        with tempfile.TemporaryDirectory() as tmp:
            root,workshop,mod,sources=self.fixture(tmp)
            path='media/lua/shared/Translate/EN/IG_UI.json'
            incoming=workshop/'source/42'/path;incoming.parent.mkdir(parents=True);incoming.write_text('{"IGUI_Source":"Actual source",}')
            existing=mod/path;existing.parent.mkdir(parents=True);existing.write_text('{"IGUI_SAO":"Canonical"}')
            with patch.dict(package.SOURCES,sources,clear=True):
                manifest,outputs,collisions=package.build_plan(workshop,mod)
            self.assertFalse(collisions)
            merged=json.loads(outputs['media/SAOSources/Merged/'+path])
            self.assertEqual(merged,{'IGUI_SAO':'Canonical','IGUI_Source':'Actual source'})
            self.assertEqual(existing.read_text(),'{"IGUI_SAO":"Canonical"}')
            incoming.write_text('{"IGUI_SAO":"Other meaning"}')
            with patch.dict(package.SOURCES,sources,clear=True):
                _,_,collisions=package.build_plan(workshop,mod)
            self.assertEqual(collisions[0]['kind'],'translation-key-value-conflict')

    def test_runtime_availability_adaptation_is_scoped_to_source(self):
        raw=b'if isModActive("SourceA") and getActivatedMods():contains("Other") then physical() end\n'
        adapted,changes=package.adapt_lua(raw,'SourceA')
        self.assertIn(b'SAO.SourceIntegration.active("SourceA")',adapted)
        self.assertIn(b'getActivatedMods():contains("Other")',adapted)
        self.assertIn(b'physical()',adapted)
        self.assertNotIn(b'getActivatedMods=',adapted)
        self.assertEqual(changes[0]['count'],1)

    def test_sealed_independent_rewrite_replans_exact_bytes_and_refuses_changed_inputs(self):
        with tempfile.TemporaryDirectory() as tmp:
            root, workshop, mod, sources = self.fixture(tmp)
            selected = 'media/lua/shared/Action.lua'
            key = ('SourceA', selected)
            with patch.dict(package.SOURCES, sources, clear=True):
                manifest, outputs, collisions = package.build_plan(workshop, mod)
            self.assertFalse(collisions)
            for relative, data in outputs.items():
                path = mod / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
            owned = b'-- independently qualified SAO action\nSAO_Action={version=2}\n'
            (mod / selected).write_bytes(owned)
            row = next(row for row in manifest['files'] if row['selectedPath'] == selected)
            pin = {'sourceSha256': row['sourceSha256'],
                   'destinationSha256': package.sha(owned),
                   'adaptations': [{'kind': 'sao-owned-player-dj-action',
                                    'qualifiedBy': 'tools/test_owned_action.py'}]}
            row['destinationSha256'] = pin['destinationSha256']
            row['bytes'] = len(owned)
            row['adaptations'] = pin['adaptations']
            seal = package.sha(json.dumps(manifest['files'], sort_keys=True, separators=(',', ':')).encode())
            manifest['sources']['SourceA']['seal'] = seal
            (mod / manifest['sources']['SourceA']['sentinel']).write_bytes(
                ('SAO-OWNED-SOURCE/1 SourceA ' + seal + '\n').encode())
            sealed_path = mod / 'media/SAOSources/manifest.json'
            sealed_path.write_bytes((json.dumps(manifest, indent=2, ensure_ascii=False) + '\n').encode())
            with patch.dict(package.SOURCES, sources, clear=True), \
                 patch.dict(package.SAO_OWNED_REPLACEMENTS, {key: pin}, clear=True):
                replanned, replanned_outputs, collisions = package.build_plan(workshop, mod)
                self.assertFalse(collisions)
                self.assertEqual(replanned, manifest)
                self.assertEqual(replanned_outputs[selected], owned)
                self.assertEqual(replanned_outputs['media/SAOSources/manifest.json'], sealed_path.read_bytes())
                self.assertEqual(package.validate_owned(mod)['status'], 'PASS')

                (mod / selected).write_bytes(owned + b' changed')
                with self.assertRaisesRegex(ValueError, 'destination changed'):
                    package.build_plan(workshop, mod)
                (mod / selected).write_bytes(owned)

                source_path = workshop / 'source/42/media/lua/shared/Action.lua'
                original_source = source_path.read_bytes()
                source_path.write_bytes(b'SourceAction={version=3}\n')
                with self.assertRaisesRegex(ValueError, 'source changed'):
                    package.build_plan(workshop, mod)
                source_path.write_bytes(original_source)

                private_original = mod / 'media/SAOSources/SourceA' / selected
                private_original.write_bytes(b'changed private original')
                with self.assertRaisesRegex(ValueError, 'private original changed'):
                    package.build_plan(workshop, mod)
                private_original.write_bytes(source_path.read_bytes())

                row['destinationSha256'] = '0' * 64
                sealed_path.write_bytes((json.dumps(manifest, indent=2) + '\n').encode())
                with self.assertRaisesRegex(ValueError, 'destination pin changed'):
                    package.build_plan(workshop, mod)

    def test_source_identical_native_translation_is_idempotent(self):
        with tempfile.TemporaryDirectory() as tmp:
            _, workshop, mod, sources = self.fixture(tmp)
            relative = 'media/lua/shared/Translate/CH/Recipes_CH.txt'
            raw = b'Recipes_CH {\n    Recipe_Source = "Source",\n}\n'
            incoming = workshop / 'source/42' / relative
            incoming.parent.mkdir(parents=True)
            incoming.write_bytes(raw)
            existing = mod / relative
            existing.parent.mkdir(parents=True)
            existing.write_bytes(raw)
            with patch.dict(package.SOURCES, sources, clear=True):
                manifest, outputs, collisions = package.build_plan(workshop, mod)
                self.assertFalse(collisions)
                self.assertEqual(outputs[relative], raw)
                row = next(row for row in manifest['files'] if row['selectedPath'] == relative)
                self.assertEqual(row['adaptations'], [])
                existing.write_bytes(b'changed native table')
                with self.assertRaisesRegex(ValueError, 'missing native translation table'):
                    package.build_plan(workshop, mod)

    def test_materialize_refuses_collision_before_any_package_write(self):
        with tempfile.TemporaryDirectory() as tmp:
            root, workshop, mod, sources = self.fixture(tmp)
            art = mod / 'media/textures/Art.png'
            art.parent.mkdir(parents=True)
            art.write_bytes(b'other owner')
            report_path = root / 'report.json'
            arguments = ['d2_source_package.py', '--workshop', str(workshop),
                         '--mod', str(mod), '--output', str(report_path), '--materialize']
            with patch.dict(package.SOURCES, sources, clear=True), patch.object(sys, 'argv', arguments):
                self.assertEqual(package.main(), 1)
            report = json.loads(report_path.read_text(encoding='utf-8'))
            self.assertEqual(report['status'], 'COLLISIONS_REFUSED')
            self.assertEqual(art.read_bytes(), b'other owner')
            self.assertFalse((mod / 'media/lua/shared/Action.lua').exists())
            self.assertFalse((mod / 'media/SAOSources/manifest.json').exists())


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True);args=ap.parse_args()
    suite=unittest.defaultTestLoader.loadTestsFromTestCase(PackageControls)
    result=unittest.TextTestRunner(verbosity=2).run(suite)
    args.output.mkdir(parents=True,exist_ok=False)
    (args.output/'receipt.json').write_text(json.dumps({'status':'PASS' if result.wasSuccessful() else 'FAIL','checks':result.testsRun,'failures':len(result.failures),'errors':len(result.errors),'boundary':__doc__},indent=2)+'\n')
    return 0 if result.wasSuccessful() else 1


if __name__=='__main__':raise SystemExit(main())
