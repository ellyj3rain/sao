"""Focused source inventory/lexical/provenance guards; no game or broad gate."""
import argparse
import contextlib
import hashlib
import io
import json
import pathlib
import tempfile
import unittest
import subprocess
from unittest.mock import patch

import scanner_inventory as inv
import scope_split_audit as scope
import undeclared_audit as undeclared
import duplicate_blocks as duplicates


class Guards(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name)
        self.package = self.root / 'mod/42.20'
        self.package.mkdir(parents=True)
        self.rows = []
        self.add('media/lua/client/One.lua', 'OwnedWindow = {}\n' + '\n'.join('OwnedWindow.value%d = %d' % (i, i) for i in range(20)))
        self.publish()

    def tearDown(self):
        self.tmp.cleanup()

    def add(self, relative, text, owner='FixtureOwner'):
        raw = text.encode()
        original = 'media/SAOSources/' + owner + '/' + relative
        for name, data in [(original, raw), (relative, b'-- integrated\n' + raw)]:
            p = self.package / name
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_bytes(data)
        self.rows.append({'sourceId': owner, 'selectedPath': relative,
                          'destination': relative, 'sourceSha256': inv.sha(raw),
                          'destinationSha256': inv.sha(b'-- integrated\n' + raw), 'kind': 'runtime-lua'})

    def publish(self):
        sources = {}
        for owner in {r['sourceId'] for r in self.rows}:
            rows = [r for r in self.rows if r['sourceId'] == owner]
            seal = inv.sha(json.dumps(rows, sort_keys=True, separators=(',', ':')).encode())
            sentinel = 'media/SAOSources/' + owner + '/package.txt'
            p = self.package / sentinel
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_bytes(('SAO-OWNED-SOURCE/1 ' + owner + ' ' + seal + '\n').encode())
            sources[owner] = {'originalRoot': 'media/SAOSources/' + owner, 'seal': seal, 'sentinel': sentinel}
        self.manifest = {'schema': 'sao.owned-source-package/1', 'packageId': 'SurvivorAwareness',
                         'sources': sources, 'files': self.rows, 'mergeRequired': []}
        self.write_manifest()

    def write_manifest(self):
        (self.package / 'media/SAOSources/manifest.json').write_text(json.dumps(self.manifest))

    def file(self, text):
        p = self.root / 'lexical.lua'
        p.write_text(text)
        return p

    def test_positive_exact_inventory(self):
        v = inv.Inventory(self.package)
        self.assertEqual(len(v.runtime), 1)
        self.assertEqual(len(v.originals), 1)
        self.assertEqual(v.runtime_lua(), v.structural_lua())

    def test_derived_runtime_preserves_original_selected_owner(self):
        selected = dict(self.rows[0])
        destination = 'media/lua/shared/DerivedPolicy.lua'
        raw = b'return {duration=25000}\n'
        path = self.package / destination
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(raw)
        self.rows.append(dict(selected, destination=destination,
                              destinationSha256=inv.sha(raw),
                              derivedFrom={'selectedPath': selected['selectedPath']}))
        self.publish()
        inventory = inv.Inventory(self.package)
        original = inventory.original(path)
        self.assertEqual(inventory.originals[original.resolve()]['destination'], selected['destination'])
        self.assertEqual(inventory.row(path)['derivedFrom']['selectedPath'], selected['selectedPath'])
        self.assertEqual(len(inventory.originals), 1)
        self.assertEqual(len(inventory.runtime), 2)
        path.write_bytes(b'foreign = {}')
        with self.assertRaisesRegex(ValueError, 'runtime source mismatch'):
            inv.Inventory(self.package)

    def test_runtime_tamper(self):
        (self.package / self.rows[0]['destination']).write_text('OwnedWindow = foreign')
        with self.assertRaisesRegex(ValueError, 'runtime source mismatch'):
            inv.Inventory(self.package)

    def test_original_tamper(self):
        (self.package / 'media/SAOSources/FixtureOwner/media/lua/client/One.lua').write_text('tampered')
        with self.assertRaisesRegex(ValueError, 'original source mismatch'):
            inv.Inventory(self.package)

    def test_unknown_vault_lua(self):
        (self.package / 'media/SAOSources/hidden.lua').write_text('foreign = {}')
        with self.assertRaisesRegex(ValueError, 'unqualified original vault'):
            inv.Inventory(self.package)

    def test_manifest_generation(self):
        self.manifest['files'][0]['sourceSha256'] = 'bad'
        self.write_manifest()
        with self.assertRaises(ValueError):
            inv.Inventory(self.package)

    def test_sentinel_tamper(self):
        (self.package / 'media/SAOSources/FixtureOwner/package.txt').write_text('unsealed')
        with self.assertRaisesRegex(ValueError, 'generation seal'):
            inv.Inventory(self.package)

    def test_schema(self):
        self.manifest['schema'] = 'unknown'
        self.write_manifest()
        with self.assertRaisesRegex(ValueError, 'unrecognized'):
            inv.Inventory(self.package)

    def test_traversal(self):
        for path in ['../foreign.lua', '/foreign.lua', 'C:/foreign.lua', 'media\\foreign.lua', 'a\0b']:
            with self.subTest(path=path), self.assertRaises(ValueError):
                inv.safe_path(self.package, path)

    def test_competing_producer(self):
        self.add('media/lua/client/One.lua', 'OwnedWindow = {}', 'SecondOwner')
        # Both producers claim exactly the same current destination bytes.
        self.rows[0]['destinationSha256'] = self.rows[1]['destinationSha256']
        self.publish()
        with self.assertRaisesRegex(ValueError, 'competing source producers'):
            inv.Inventory(self.package)

    def test_constructor_key(self):
        self.assertEqual(scope.audit(self.file('local o = {Yoga = 1}\nlocal Yoga = {}\n')), [])

    def test_multiline_constructor_key(self):
        self.assertEqual(scope.audit(self.file('local o = {\n Yoga = 1;\n Other = 2\n}\nlocal Yoga = {}\n')), [])

    def test_actual_global_assignment(self):
        self.assertEqual(scope.audit(self.file('Yoga = {}\nlocal Yoga = {}\n'))[0][0], 'Yoga')

    def test_constructor_callback_global_assignment(self):
        self.assertEqual(scope.audit(self.file('local o = {f=function() Yoga = {} end}\nlocal Yoga = {}\n'))[0][0], 'Yoga')

    def test_long_string_is_not_executed_lexical_scope(self):
        self.assertEqual(scope.audit(self.file('local source = [=[ Yoga = {} ]=]\nlocal Yoga = {}\n')), [])

    def test_parameter_scope(self):
        self.assertEqual(undeclared.used_before_declared(self.file('local function collect(result)\n result[1] = true\nend\nlocal function result() end\n')), [])

    def test_nested_parameter_capture(self):
        self.assertEqual(undeclared.used_before_declared(self.file('local function collect(result)\n return function() result[1] = true end\nend\nlocal function result() end\n')), [])

    def test_parameter_does_not_escape(self):
        rows = undeclared.used_before_declared(self.file('local function collect(result)\n result[1] = true\nend\nlocal function early() result() end\nlocal function result() end\n'))
        self.assertEqual(rows[0][0], 'result')

    def test_real_earlier_closure(self):
        rows = undeclared.used_before_declared(self.file('local function log() return ready and ready() end\nlocal function ready() return true end\n'))
        self.assertEqual(rows[0][0], 'ready')

    def test_owned_original_duplicate(self):
        text = '\n'.join('OwnedWindow.value%d = %d' % (i, i) for i in range(20))
        self.add('media/lua/client/Two.lua', text)
        self.publish()
        v = inv.Inventory(self.package)
        with patch('scanner_inventory.current', return_value=v), patch.object(duplicates, 'ROOT', self.root), patch.object(duplicates, 'sources', return_value=v.runtime_lua()), contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(duplicates.main(), 0)

    def test_canonical_copy_is_not_owned_baseline(self):
        v = inv.Inventory(self.package)
        p = self.package / 'media/lua/client/SAO_Unreviewed.lua'
        p.write_bytes((self.package / self.rows[0]['destination']).read_bytes())
        with patch('scanner_inventory.current', return_value=v), patch.object(duplicates, 'ROOT', self.root), patch.object(duplicates, 'sources', return_value=v.runtime_lua()), contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(duplicates.main(), 1)

    def test_locale_native_json_and_owned_table(self):
        p = self.root / 'locale'
        p.mkdir()
        (p / 'ContextMenu.json').write_text('{"ContextMenu_AddAll":"Add All"}')
        (p / 'Tooltip.txt').write_text('Tooltip_EN = {\n Tooltip_fixture = "source",\n}')
        self.assertIn('ContextMenu_AddAll', inv.locale_keys(p))
        self.assertIn('Tooltip_fixture', inv.locale_keys(p))
        self.assertNotIn('Tooltip_unknown', inv.locale_keys(p))

    def test_literal_label_requires_exact_original_call(self):
        self.add('media/lua/client/LSIsListeningEffects.lua', 'getText("Disturbed Sleep")', 'LifestyleHobbies')
        self.publish()
        v = inv.Inventory(self.package)
        p = self.package / 'media/lua/client/LSIsListeningEffects.lua'
        self.assertTrue(inv.source_literal_label(v, p, 'Disturbed Sleep'))
        self.assertFalse(inv.source_literal_label(v, p, 'Disturbed Focus'))
        self.assertFalse(inv.source_literal_label(v, self.root / 'foreign.lua', 'Disturbed Sleep'))
        self.assertFalse(inv.source_literal_label(v, p, 'Tooltip_unknown'))

    def test_duplicate_long_comment_is_not_code(self):
        p = self.file('--[[\n' + '\n'.join('ghost_%d = true' % i for i in range(20)) + '\n]]\nreal = true')
        self.assertEqual(duplicates.normalised(p), [(23, 'real = true')])

    def test_imported_tooltip_does_not_borrow_county_layout(self):
        import sandbox_surface
        data = {'Sandbox_Foreign_tooltip': 'Original source tooltip',
                'Sandbox_SurvivorAwareness_Test_tooltip': 'County tooltip'}
        faults = sandbox_surface.shape_faults(json.dumps(data))
        self.assertTrue(any('SurvivorAwareness_Test' in f for f in faults))
        self.assertFalse(any('Foreign' in f for f in faults))

    def test_private_environment_exact_owner(self):
        self.add('media/lua/client/Private.lua', 'local env = _G.FixtureEnv\nsetfenv(1, env)\nPrivateValue = 1')
        self.publish()
        v = inv.Inventory(self.package)
        self.assertEqual(v.environment(self.package / 'media/lua/client/Private.lua'), ('FixtureOwner', 'FixtureEnv'))
        self.assertIsNone(v.environment(self.root / 'foreign.lua'))
        self.assertIsNone(v.environment(self.package / 'media/lua/client/One.lua'))

    def test_private_environment_metatable_guard(self):
        text = ('local env = _G.FixtureEnv\nif getmetatable(env) == nil then\n'
                ' setmetatable(env, { __index = _G })\nend\nsetfenv(1, env)\nreturn BAR_BG')
        self.add('media/lua/client/Private.lua', text)
        self.add('media/lua/client/Bootstrap.lua', 'local env = _G.FixtureEnv\nenv.BAR_BG = {}')
        self.publish()
        v = inv.Inventory(self.package)
        p = self.package / 'media/lua/client/Private.lua'
        self.assertEqual(v.environment(p), ('FixtureOwner', 'FixtureEnv'))
        self.assertIn((v.environment(p), 'BAR_BG'), v.environment_fields())
        self.assertIsNone(inv.source_environment(text.replace('__index = _G', '__index = Foreign')))
        self.assertIsNone(inv.source_environment(text.replace('setfenv(1, env)', 'setfenv(1, _G)')))
        self.assertIsNone(inv.source_environment(text.replace('setfenv(1, env)', 'env = Foreign\nsetfenv(1, env)')))
        alias = text.replace('setfenv(1, env)', 'env.Public = _G.Public\nsetfenv(1, env)')
        self.assertEqual(inv.source_environment(alias), 'FixtureEnv')
        self.assertNotEqual(inv.source_environment(alias, include_setup=True),
                            inv.source_environment(alias.replace('_G.Public', '_G.Foreign'), include_setup=True))

    def test_runtime_private_environment_must_match_original(self):
        self.add('media/lua/client/Private.lua', 'local env = _G.FixtureEnv\nsetfenv(1, env)\nPrivateValue = 1')
        p = self.package / 'media/lua/client/Private.lua'
        p.write_text('local env = _G.ForeignEnv\nsetfenv(1, env)\nPrivateValue = 1')
        self.rows[-1]['destinationSha256'] = inv.sha(p.read_bytes())
        self.publish()
        self.assertIsNone(inv.Inventory(self.package).environment(p))

    def test_runtime_private_alias_setup_must_match_original(self):
        self.add('media/lua/client/Private.lua', 'local env = _G.FixtureEnv\n'
                 'env.Public = _G.Public\nsetfenv(1, env)\nPrivateValue = 1')
        p = self.package / 'media/lua/client/Private.lua'
        p.write_text(p.read_text().replace('_G.Public', '_G.Foreign'))
        self.rows[-1]['destinationSha256'] = inv.sha(p.read_bytes())
        self.publish()
        self.assertIsNone(inv.Inventory(self.package).environment(p))

    def test_global_annotation_requires_actual_global_flag(self):
        dump = ('\n  public void instanceMethod();\nRuntimeVisibleAnnotations:\n'
                ' se.krka.kahlua.integration.annotations.LuaMethod(name="sourceNative" global=true)\n'
                '\n  public static void notGlobal();\nRuntimeVisibleAnnotations:\n'
                ' se.krka.kahlua.integration.annotations.LuaMethod(name="foreign" global=false)\n'
                '\n  public static void unannotated();\n')
        self.assertEqual(inv.annotated_global_names(dump), {'sourceNative'})

    def test_bootstrap_requires_actual_registration_owner(self):
        platform = ' // Method se/krka/kahlua/luaj/compiler/LuaCompiler.register:'
        compiler = 'static {};\n // String loadstring\n // String loadstream\n // Field names:\n // String foreign'
        util = ('public static Table getClassMetatables(Platform, Table);\nCode:\n'
                '// String __classmetatables\n// Method getOrCreateTable:\n')
        self.assertEqual(inv.bootstrap_global_names(platform, compiler, util), {'loadstring', 'loadstream', '__classmetatables'})
        self.assertEqual(inv.bootstrap_global_names('', compiler, ''), set())
        self.assertEqual(inv.bootstrap_global_names(platform, '// String ghost', ''), set())
        self.assertEqual(inv.bootstrap_global_names('', '', util.replace('getOrCreateTable:', 'foreign:')), set())

    def test_actual_installed_instance_and_bootstrap_exports(self):
        actual = inv.engine_java_names()
        self.assertTrue({'addXp', 'addXpNoMultiplier', 'syncPlayerStats', 'syncItemFields',
                         'syncHandWeaponFields', 'getTileOverlays', 'loadstring', 'loadstream',
                         '__classmetatables', 'newrandom'} <= actual)
        self.assertNotIn('DefinitelyForeignNativeNamespace', actual)
        self.assertNotIn('randomseed', actual)

    def test_public_source_namespace_refuses_leaked_temporaries(self):
        self.add('media/lua/client/Public.lua', 'Public = {}\nfunction PublicCallback() return true end\n'
                 'function Public.run() leakedTemporary = 1 end\n')
        self.publish()
        v = inv.Inventory(self.package)
        p = self.package / 'media/lua/client/Public.lua'
        self.assertTrue(v.public_namespace(p, 'Public'))
        self.assertTrue(v.public_namespace(p, 'PublicCallback'))
        self.assertFalse(v.public_namespace(p, 'leakedTemporary'))
        self.assertFalse(v.public_namespace(self.root / 'foreign.lua', 'Public'))

    def test_private_source_function_is_not_process_global_provider(self):
        self.add('media/lua/client/Private.lua', 'local env = _G.FixtureEnv\nsetfenv(1, env)\n'
                 'function PrivateCallback() return true end')
        self.publish()
        self.assertFalse(inv.Inventory(self.package).public_namespace(
            self.package / 'media/lua/client/Private.lua', 'PrivateCallback'))

    def test_inline_module_namespace_refuses_locals_fields_and_temporaries(self):
        self.add('media/lua/client/Inline.lua', 'if not InlineRoot then InlineRoot = {} end\n'
                 'local PrivateRoot = {}\nlocal a, MultiLocal = nil, {}\n'
                 'local holder = { ConstructorField = {} }\nholder.Member = {}\n'
                 'function InlineRoot.run() Leaked = {} end\n')
        self.publish()
        v = inv.Inventory(self.package)
        p = self.package / 'media/lua/client/Inline.lua'
        self.assertTrue(v.public_namespace(p, 'InlineRoot'))
        for name in ('PrivateRoot', 'MultiLocal', 'ConstructorField', 'Member', 'Leaked'):
            self.assertFalse(v.public_namespace(p, name), name)

    def test_native_fallback_read_requires_single_root_guard(self):
        import globals_census_test as census
        self.add('media/lua/client/Fallback.lua', 'local SourceCache = SourceCache or {}\n'
                 'function use() return SourceCache end\n')
        self.publish()
        v = inv.Inventory(self.package)
        p = (self.package / 'media/lua/client/Fallback.lua').resolve()
        original = v.original(p)
        native = subprocess.run([str(census.JDK / 'java.exe'), '-cp', str(census.PZ) + ';' + str(census.OUT),
                                 'LuaGlobals', str(p), str(original)], capture_output=True, text=True, check=True)
        compiled = {str(path): {'lines': [l for l in native.stdout.splitlines() if l.endswith(' ' + str(path))]}
                    for path in (p, original)}
        self.assertEqual(census.local_fallback_reads({'SourceCache': [('GET', p)]}, v, compiled), {'SourceCache'})
        # The restored bad source creates a real unguarded native GETGLOBAL
        # before the later local guard. Do not synthesize compiler evidence.
        p.write_text('function before() return SourceCache.missing() end\n' + original.read_text())
        self.rows[-1]['destinationSha256'] = inv.sha(p.read_bytes())
        self.publish()
        v = inv.Inventory(self.package)
        bad = subprocess.run([str(census.JDK / 'java.exe'), '-cp', str(census.PZ) + ';' + str(census.OUT),
                              'LuaGlobals', str(p)], capture_output=True, text=True, check=True)
        compiled[str(p)]['lines'] = bad.stdout.splitlines()
        self.assertEqual(sum(l.startswith('GET SourceCache ') for l in bad.stdout.splitlines()), 2)
        self.assertEqual(census.local_fallback_reads({'SourceCache': [('GET', p), ('GET', p)]}, v, compiled), set())
        self.assertEqual(census.local_fallback_reads({'SourceCache': [('SET', p)]}, v, compiled), set())
        self.assertEqual(census.local_fallback_reads({'SourceCache': [('GET', self.root / 'foreign.lua')]}, v, compiled), set())
        self.assertEqual(inv.guarded_local_fallbacks('function f(SourceCache) local SourceCache = SourceCache or {} end'), set())
        self.assertEqual(inv.guarded_local_fallbacks('local SourceCache = 1\nlocal SourceCache = SourceCache or {}'), set())
        self.assertEqual(inv.guarded_local_fallbacks('-- local Ghost = Ghost or {}'), set())

    def test_native_engine_local_reassignment_does_not_export(self):
        import globals_census_test as census
        text = 'local EngineLocal = {}\nEngineLocal = {}\nNativeFixtureProvider = {}'
        p = self.file(text)
        native = subprocess.run([str(census.JDK / 'java.exe'), '-cp', str(census.PZ) + ';' + str(census.OUT),
                                 'LuaGlobals', str(p)], capture_output=True, text=True, check=True)
        self.assertIn('EngineLocal', inv.declarations(text))
        self.assertNotIn('SET EngineLocal ', native.stdout)
        self.assertIn('SET NativeFixtureProvider ', native.stdout)

    def test_namespace_foreign_write_and_missing_provider(self):
        import globals_census_test as census
        v = inv.Inventory(self.package)
        p = (self.package / self.rows[0]['destination']).resolve()
        original = v.original(p)
        sites = {'OwnedWindow': [('SET', p)], 'GhostNamespace': [('GET', p)], 'getPlayer': [('SET', p)]}
        owned, engine, context = census.namespace_classifications(sites, {'OwnedWindow': {original}, 'getPlayer': {original}}, {}, v, {'getPlayer'}, {})
        self.assertEqual(owned, {'OwnedWindow'})
        self.assertEqual(engine, set())
        self.assertEqual(context, set())
        self.assertNotIn('GhostNamespace', owned | engine | context)

    def test_private_environment_requires_real_field_provider(self):
        import globals_census_test as census
        self.add('media/lua/client/Private.lua', 'local env = _G.FixtureEnv\nsetfenv(1, env)\nreturn BAR_BG')
        self.add('media/lua/client/Bootstrap.lua', 'local env = _G.FixtureEnv\nenv.BAR_BG = {}')
        self.publish()
        v = inv.Inventory(self.package)
        p = (self.package / 'media/lua/client/Private.lua').resolve()
        sites = {'BAR_BG': [('GET', p)], 'GhostField': [('GET', p)]}
        owned, engine, context = census.namespace_classifications(sites, {}, v.environment_fields(), v, set(), {})
        self.assertEqual(context, {'BAR_BG'})
        self.assertNotIn('GhostField', owned | engine | context)

    def test_explicit_global_table_export_has_exact_provider(self):
        import globals_census_test as census
        self.add('media/lua/client/Export.lua', '_G.FixtureExport = {}')
        self.publish()
        v = inv.Inventory(self.package)
        p = (self.package / 'media/lua/client/One.lua').resolve()
        exports = v.global_exports()
        owned, engine, context = census.namespace_classifications({'FixtureExport': [('GET', p)]}, exports, {}, v, set(), {}, exports)
        self.assertEqual(owned, {'FixtureExport'})
        self.assertNotIn('GhostExport', exports)

    def test_same_name_optional_global_never_masks_private_access_or_grants_write(self):
        import globals_census_test as census
        self.add('media/lua/client/Private.lua', 'local env = _G.FixtureEnv\nsetfenv(1, env)\n'
                 'function getNowMs() return 1 end\nreturn getNowMs()')
        self.add('media/lua/client/Host.lua', 'if getNowMs then return getNowMs() end')
        self.publish()
        v = inv.Inventory(self.package)
        p = (self.package / 'media/lua/client/Private.lua').resolve()
        host = (self.package / 'media/lua/client/Host.lua').resolve()
        original = v.original(p)
        writers = {(v.environment(p), 'getNowMs'): {original}}
        self.assertTrue(census.private_access_qualified('GET', p, 'getNowMs', v, writers))
        self.assertTrue(census.private_access_qualified('SET', p, 'getNowMs', v, writers))
        self.assertFalse(census.private_access_qualified('GET', host, 'getNowMs', v, writers))
        self.assertFalse(census.private_access_qualified('SET', host, 'getNowMs', v, writers))
        self.assertFalse(census.private_access_qualified('GET', p, 'GhostField', v, writers))
        self.assertFalse(census.private_access_qualified('SET', p, 'getNowMs', v,
                                                      {(v.environment(p), 'getNowMs'): {host}}))

    def test_private_engine_alias_does_not_overwrite_process_global(self):
        import globals_census_test as census
        self.add('media/lua/client/Private.lua', 'local env = _G.FixtureEnv\nsetfenv(1, env)\nfunction getPlayer() return nil end')
        self.publish()
        v = inv.Inventory(self.package)
        p = (self.package / 'media/lua/client/Private.lua').resolve()
        original = v.original(p)
        contexts = {(('FixtureOwner', 'FixtureEnv'), 'getPlayer'): {original}}
        sites = {'getPlayer': [('SET', p), ('GET', self.root / 'ordinary.lua')]}
        _, _, approved = census.namespace_classifications(sites, {'getPlayer': {original}}, contexts, v, {'getPlayer'}, {})
        self.assertEqual(approved, {'getPlayer'})
        sites['getPlayer'].append(('SET', self.root / 'foreign.lua'))
        _, _, approved = census.namespace_classifications(sites, {'getPlayer': {original}}, contexts, v, {'getPlayer'}, {})
        self.assertEqual(approved, set())

    def test_source_speech_provenance_never_exempts_attribution(self):
        import sys, importlib.util
        with patch.object(sys, 'argv', ['operator_speech_test.py']):
            spec = importlib.util.spec_from_file_location('speech_guard_fixture', inv.ROOT / 'tools/operator_speech_test.py')
            speech = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(speech)
        word = 'sh' + 'it'
        self.add('media/lua/client/Speech.lua', 'local label="' + word + '"\n')
        self.publish()
        v = inv.Inventory(self.package)
        original = self.package / 'media/SAOSources/FixtureOwner/media/lua/client/Speech.lua'
        with patch('scanner_inventory.current', return_value=v), patch.object(speech, 'ROOT', self.root), patch.object(speech, 'tracked_files', return_value=[original]), contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(speech.main(), 0)
        canonical = self.root / 'OperatorRecord.md'
        canonical.write_text('Operator said: "Synthetic control"')
        with patch('scanner_inventory.current', return_value=v), patch.object(speech, 'ROOT', self.root), patch.object(speech, 'tracked_files', return_value=[canonical]), contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(speech.main(), 1)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', type=pathlib.Path, required=True)
    args = parser.parse_args()
    import globals_census_test as census
    if not census.build():
        raise RuntimeError('native namespace fixture compiler unavailable')
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    files = [pathlib.Path(__file__), pathlib.Path(inv.__file__), pathlib.Path(scope.__file__), pathlib.Path(undeclared.__file__),
             pathlib.Path(duplicates.__file__), inv.ROOT / 'tools/source_scanner_consumers.json',
             inv.ROOT / 'tools/check.sh', inv.ROOT / 'tools/sandbox_surface.py', inv.ROOT / 'tools/globals_census_test.py',
             inv.ROOT / 'tools/operator_speech_test.py']
    files.append(inv.GAME / 'projectzomboid.jar')
    files.append(census.SRC)
    before = {str(p): inv.sha(p.read_bytes()) for p in files}
    stream = io.StringIO()
    result = unittest.TextTestRunner(stream=stream, verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(Guards))
    (out / 'guards.log').write_text(stream.getvalue())
    receipt = {'schema': 'sao-source-scanner-guards/1', 'status': 'PASS' if result.wasSuccessful() else 'FAIL',
               'tests': result.testsRun, 'inputsBefore': before, 'inputsAfter': {str(p): inv.sha(p.read_bytes()) for p in files},
               'boundary': 'Exact small sealed package and actual production scanner functions; native namespace census/real current package checks separately pinned. No runtime, game, candidate, engine-helper or importer changes.'}
    # Restore actual bad guards in private code copies. The same named positive
    # guard tests must fail, rather than merely testing a mirrored predicate.
    variants = [
        ('runtime-byte-guard-removed', 'test_runtime_tamper',
         "if not destination.is_file() or sha(destination.read_bytes()) != row['destinationSha256']:", 'if False:'),
        ('original-byte-guard-removed', 'test_original_tamper',
         "if not original.is_file() or sha(original.read_bytes()) != row['sourceSha256']:", 'if False:'),
        ('generation-seal-guard-removed', 'test_sentinel_tamper',
         "if seal != source['seal'] or sentinel.read_bytes() != ('SAO-OWNED-SOURCE/1 ' + key + ' ' + seal + '\\n').encode():", 'if False:'),
    ]
    receipt['restoredControls'] = []
    text = pathlib.Path(inv.__file__).read_text()
    for name, test, anchor, replacement in variants:
        assert text.count(anchor) == 1, name
        broken = text.replace(anchor, replacement, 1)
        ns = {'__name__': 'private_inventory_variant', '__file__': inv.__file__}
        exec(compile(broken, inv.__file__, 'exec'), ns)
        log = io.StringIO()
        with patch.object(inv, 'Inventory', ns['Inventory']):
            mutant = unittest.TextTestRunner(stream=log).run(Guards(test))
        (out / (name + '.log')).write_text(log.getvalue())
        assert not mutant.wasSuccessful() and mutant.failures, name
        receipt['restoredControls'].append({'name': name, 'failedGuard': test, 'variantSha256': inv.sha(broken.encode())})
    log = io.StringIO()
    with patch.object(inv.Inventory, 'original_block', return_value=True):
        mutant = unittest.TextTestRunner(stream=log).run(Guards('test_canonical_copy_is_not_owned_baseline'))
    (out / 'unqualified-duplicate-waiver.log').write_text(log.getvalue())
    assert not mutant.wasSuccessful() and mutant.failures
    receipt['restoredControls'].append({'name': 'unqualified-duplicate-waiver', 'failedGuard': 'test_canonical_copy_is_not_owned_baseline'})
    # Restore the actual collector defect: annotated instance methods disappear.
    text = pathlib.Path(inv.__file__).read_text()
    anchor = 'public (?:static )?'
    assert text.count(anchor) == 1
    broken = text.replace(anchor, 'public static ', 1)
    ns = {'__name__': 'private_exposure_variant', '__file__': inv.__file__}
    exec(compile(broken, inv.__file__, 'exec'), ns)
    log = io.StringIO()
    with patch.object(inv, 'annotated_global_names', ns['annotated_global_names']):
        mutant = unittest.TextTestRunner(stream=log).run(Guards('test_actual_installed_instance_and_bootstrap_exports'))
    (out / 'instance-export-blindness.log').write_text(log.getvalue())
    assert not mutant.wasSuccessful() and mutant.failures
    receipt['restoredControls'].append({'name': 'instance-export-blindness', 'failedGuard': 'test_actual_installed_instance_and_bootstrap_exports', 'variantSha256': inv.sha(broken.encode())})
    log = io.StringIO()
    with patch.object(inv.Inventory, 'public_namespace', return_value=True):
        mutant = unittest.TextTestRunner(stream=log).run(Guards('test_public_source_namespace_refuses_leaked_temporaries'))
    (out / 'source-provenance-write-waiver.log').write_text(log.getvalue())
    assert not mutant.wasSuccessful() and mutant.failures
    receipt['restoredControls'].append({'name': 'source-provenance-write-waiver', 'failedGuard': 'test_public_source_namespace_refuses_leaked_temporaries'})
    text = pathlib.Path(census.__file__).read_text()
    anchor = "native_count(path, 'GET', name) != 1"
    assert text.count(anchor) == 1
    broken = text.replace(anchor, 'False', 1)
    ns = {'__name__': 'private_fallback_variant', '__file__': census.__file__}
    exec(compile(broken, census.__file__, 'exec'), ns)
    log = io.StringIO()
    with patch.object(census, 'local_fallback_reads', ns['local_fallback_reads']):
        mutant = unittest.TextTestRunner(stream=log).run(Guards('test_native_fallback_read_requires_single_root_guard'))
    (out / 'unguarded-extra-read-waiver.log').write_text(log.getvalue())
    assert not mutant.wasSuccessful() and mutant.failures
    receipt['restoredControls'].append({'name': 'unguarded-extra-read-waiver', 'failedGuard': 'test_native_fallback_read_requires_single_root_guard', 'variantSha256': inv.sha(broken.encode())})
    receipt['status'] = receipt['status'] if receipt['inputsBefore'] == receipt['inputsAfter'] else 'INPUT_DRIFT'
    (out / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(stream.getvalue())
    return 0 if receipt['status'] == 'PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
