#!/usr/bin/env python3
"""Focused positive and inverse controls for the current scanner repairs."""
import json
import pathlib
import re
import tempfile
from types import SimpleNamespace

from call_target_test import canonical_module, module_aliases, strip
from gmatch_progress_test import registered_dynamic
from lua_read import strip_lua
from modinfo_check import reader_controls as manifest_controls
from operator_speech_test import attribution_controls, speech_controls
from placeholder_test import creator_name_lines
from reach_scan import bare_reaches
from scanner_inventory import ROOT, sha
from source_scanner_baseline import controls, source_registration_present
from toplevel_function_test import function_sites, reader_controls as depth_controls


def main():
    count = controls() + manifest_controls() + depth_controls() + speech_controls()
    total, faults = attribution_controls()
    assert not faults
    count += total
    scoped = ('local function first()\nlocal distance=dx*dx+dy*dy\n'
              'if distance>25 then return end\nend\n'
              'local function second()\nlocal distance=math.sqrt(dx*dx+dy*dy)\n'
              'if distance>11 then return end\nend\n')
    assert [tiles for _, tiles, _ in bare_reaches(scoped)] == [5, 11]
    assert not bare_reaches('if dx*dx+dy*dy>50*50 then return end')
    assert not bare_reaches('local distance=math.sqrt(dx*dx+dy*dy)\nif distance<0 then return end')
    assert [tiles for _, tiles, _ in bare_reaches('local d2=dx*dx+dy*dy\nif d2>11 then return end')] == [11 ** .5]
    count += 4
    named = 'local function buildSource()\nfunction Core:run()\nend\nreturn Core\nend\n'
    assert function_sites(named, ('buildSource',)) == ([(2, 1, True)], 0)
    assert function_sites(named.replace('function Core:run()\nend', 'function Core:run()'), ('buildSource',))[1] != 0
    count += 2
    aliases = module_aliases([strip('SAO.Old = SAO.Middle\nSAO.Middle = SAO.Current\n-- SAO.No = SAO.Current')])
    assert canonical_module('SAO.Old', aliases) == 'SAO.Current'
    assert canonical_module('SAO.No', aliases) == 'SAO.No'
    count += 2
    lua = ROOT / 'mod/42.20/media/lua/client'
    creator = strip_lua((lua / 'SAO_PlayerCreator.lua').read_text(encoding='utf-8'), strings=False)
    ui = strip_lua((lua / 'SAO_PlayerCreatorUI.lua').read_text(encoding='utf-8'), strings=False)
    assert len(creator_name_lines(ui, creator)) == 2
    assert not creator_name_lines(ui.replace('local ctx = self.draft.context', 'local ctx = other'), creator)
    assert not creator_name_lines(ui, creator.replace('nativeName(screen)', 'otherName(screen)'))
    count += 3
    music = strip_lua((lua / 'SAO_LeisureMusic.lua').read_text(encoding='utf-8'), strings=False)
    assert registered_dynamic('SAO_LeisureMusic.lua', 'pattern', music) == ('SAO_LeisureMusic.lua', 'source-dance-choice')
    assert not registered_dynamic('SAO_LeisureMusic.lua', 'pattern', music.replace('JukeboxMenu%.', '.-'))
    assert not registered_dynamic('SAO_LeisureMusic.lua', 'otherPattern', music)
    count += 3
    # The orphan-field reader must distinguish a call-result assignment from
    # equality or comment text. This is the source Music receiver idiom.
    receiver = re.compile(r'\b[\w.]+\([^()\n]*\)\.(\w+)\s*=(?!=)')
    assert receiver.findall(strip_lua('person(id).position = plain(value)', strings=False)) == ['position']
    assert not receiver.search('person(id).position == value')
    assert not receiver.search(strip_lua('-- person(id).position = value', strings=False))
    count += 3
    guard = re.compile(r'function\s+Nb\.willSuperimpose\([^)]*\)\s*if not Nb\.bridgeOpen\(\) then return false end')
    sample = 'function Nb.willSuperimpose(player, body, context)\nif not Nb.bridgeOpen() then return false end\n'
    assert guard.search(sample)
    assert not guard.search(sample.replace('if not Nb.bridgeOpen() then return false end', 'local unused = true'))
    count += 2
    with tempfile.TemporaryDirectory() as tmp:
        package = pathlib.Path(tmp)
        runtime = package / 'media/registries.lua'
        runtime.parent.mkdir()
        original = package / 'original.lua'
        payload = b'CharacterTrait.register("TEST")\n'
        runtime.write_bytes(payload)
        original.write_bytes(payload)
        row = {'enginePath': 'media/registries.lua', 'fragment': 'original.lua', 'sha256': sha(payload)}
        inventory = SimpleNamespace(package=package, manifest={'mergeRequired': [row]})
        assert source_registration_present('media/registries.lua', inventory)
        runtime.write_bytes(payload + b'unknown()\n')
        assert not source_registration_present('media/registries.lua', inventory)
        runtime.write_bytes(payload)
        original.write_bytes(payload + b'unknown()\n')
        assert not source_registration_present('media/registries.lua', inventory)
        inventory.manifest['mergeRequired'].append(dict(row))
        assert not source_registration_present('media/registries.lua', inventory)
        count += 4
    from sandbox_surface import captured_native_keys
    native = captured_native_keys()
    assert 'IGUI_HaloNote_LearnedRecipe' in native
    assert 'SAO_Unregistered_Control' not in native
    count += 2
    from copy_ratified_test import RATIFIED
    from source_scanner_baseline import source_translation_values
    source = source_translation_values('media/lua/shared/Translate/EN/Sandbox.json')
    owned = json.loads((ROOT / 'tools/owned_copy_qualification.json').read_text(encoding='utf-8'))['values']
    assert len(owned) == 79
    allowed = {**source, **RATIFIED, **owned}
    key, value = next(iter(owned.items()))
    assert allowed[key] == value and allowed.get(key) != value + '-changed'
    assert allowed.get('Sandbox_SAO_NewUnapprovedControl') != 'unknown'
    count += 3
    print(f'scanner boundary controls: PASS {count} positive/inverse controls')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
