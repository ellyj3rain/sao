#!/usr/bin/env python3
"""Strict loose-item fixture admission and actual installed native floor ownership."""
from __future__ import annotations
import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import subprocess

import world_lab as Lab
from native_proof_preflight import installed_presence

ROOT = Lab.ROOT
GAME = Path(os.environ.get('PZ_DIR', r'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'))
JDK = Path(os.environ.get('JDK_BIN', str(Path.home() / 'Peanut Butter/JetBrains/Java/bin')))


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def extracted(source):
    prefix = source[:source.index('local function selected()')]
    apply = source[source.index('local function applyInitialLooseItems()'):source.index('local function applyInitialNeeds()')]
    tick = source[source.index('function Study.tick()'):source.index('local function guarded(fn)')]
    return ('function LoadPlacement(Config, initialState)\n' + prefix + apply + tick
            + '\nstate=initialState; Study.active=true\nreturn {tick=Study.tick,encode=json}\nend\n')


def run(out, baseline_only=False):
    out.mkdir(parents=True, exist_ok=False)
    template = ROOT / 'tools/world_lab/StudyWorld.lua'
    probe = ROOT / 'tools/world_lab/LooseItemsProbe.java'
    cases = ROOT / 'tools/world_lab/LooseItemsChecks.lua'
    inputs = [Path(__file__).resolve(), template, probe, cases, ROOT / 'tools/world_lab.py',
              ROOT / 'tools/world_lab_definition.py', ROOT / 'tools/world_lab/authored_map.py',
              ROOT / 'tools/world_lab/definition.example.json', GAME / 'projectzomboid.jar',
              GAME / 'ZombieBuddy.jar', GAME / 'media/scripts/generated/items/normal.txt',
              GAME / 'media/scripts/generated/items/literature.txt',
              GAME / 'media/lua/shared/TimedActions/ISDropWorldItemAction.lua',
              JDK / 'javac.exe', JDK / 'javap.exe', GAME / 'jre64/bin/java.exe']
    inputs.append(Path(__file__).with_name('native_proof_preflight.py'))
    preflight = installed_presence(inputs, GAME, JDK, "world lab loose items")
    if preflight is not None:
        raise SystemExit(preflight)
    receipt = {'schema': 'sao-loose-item-proof/1', 'status': 'INCOMPLETE',
               'inputsBefore': {str(p): digest(p) for p in inputs}, 'checks': [], 'controls': [], 'commands': [],
               'limits': ['Installed native instanceItem, AddWorldInventoryItem, InventoryItem/world-object lists and Kahlua persistence execute.',
                          'Floor loading/support geometry, native dictionary registration, renderer-only named empty texture and refusal injections are controlled fixtures.',
                          'No full game, live save, inventory grant, survivor purpose, belief or knowledge mutation; no gameplay acceptance.']}

    def retain():
        (out / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')

    def check(value, name):
        Lab.require(value, name); receipt['checks'].append(name); print('PASS', name, flush=True)

    def command(args, name, want_pass=True):
        completed = subprocess.run(list(map(str, args)), cwd=GAME, capture_output=True, encoding='utf-8', errors='replace', timeout=90)
        stdout, stderr = out / (name + '.stdout.log'), out / (name + '.stderr.log')
        stdout.write_text(completed.stdout, encoding='utf-8'); stderr.write_text(completed.stderr, encoding='utf-8')
        receipt['commands'].append({'name': name, 'command': list(map(str, args)), 'cwd': str(GAME), 'exitCode': completed.returncode,
                                    'stdout': str(stdout), 'stdoutSha256': digest(stdout), 'stderr': str(stderr), 'stderrSha256': digest(stderr)})
        retain()
        if want_pass:
            Lab.require(completed.returncode == 0, name + ': ' + completed.stdout[-1500:] + completed.stderr[-2400:])
        return completed

    retain()
    try:
        d = Lab.load(ROOT / 'tools/world_lab/definition.example.json')
        d['observation']['sites'] = [{'id': 'home', 'label': 'Home', 'x': 128, 'y': 128, 'z': 0}]
        row = {'id': 'floor-harmonica', 'siteId': 'home', 'x': 128, 'y': 128, 'z': 0, 'fullType': 'Base.Harmonica', 'count': 2}
        d['situation'] = {'initialLooseItems': [row]}
        Lab.validate(d); check(True, 'complete_definition_accepts_physical_loose_items')
        package = out / 'package'
        Lab.build(d, package, GAME)
        Lab.verify_package(package)
        packaged = next(package.glob('mod/*/42.20/media/lua/client/*.lua')).read_text(encoding='utf-8')
        check('initialLooseItems' in packaged and 'Base.Harmonica' in packaged
              and template.read_text(encoding='utf-8') in packaged, 'canonical_builder_binds_configuration_and_current_producer')
        legacy = copy.deepcopy(d); del legacy['situation']; Lab.validate(legacy)
        check(True, 'omitted_fixture_preserves_legacy_definition')

        def reject(name, change):
            candidate = copy.deepcopy(d); change(candidate)
            try:
                Lab.validate(candidate)
            except (ValueError, TypeError):
                receipt['controls'].append({'name': name, 'status': 'REJECTED', 'kind': 'full-definition-input'})
                return
            raise AssertionError('Validator admitted ' + name)

        for key, value in [('id', ''), ('id', 'Foreign ID'), ('siteId', 'foreign'), ('x', True), ('x', 128.5),
                           ('x', 145), ('y', float('nan')), ('z', 1), ('count', 0), ('count', 9), ('count', True),
                           ('fullType', 'Harmonica'), ('fullType', 'Base.Harmonica\n'), ('fullType', 'Base.' + 'a' * 128)]:
            reject('invalid_' + key + '_' + str(value), lambda x, k=key, v=value: x['situation']['initialLooseItems'][0].__setitem__(k, v))
        reject('foreign_actor_field', lambda x: x['situation']['initialLooseItems'][0].update(actorId='sao-1'))
        reject('missing_type', lambda x: x['situation']['initialLooseItems'][0].pop('fullType'))
        reject('duplicate_placement_id', lambda x: x['situation']['initialLooseItems'].append(copy.deepcopy(row)))
        reject('empty_list', lambda x: x['situation'].__setitem__('initialLooseItems', []))
        reject('object_instead_of_list', lambda x: x['situation'].__setitem__('initialLooseItems', {}))
        reject('count_budget', lambda x: x['situation'].__setitem__('initialLooseItems', [dict(row, id='many-'+str(i), count=8) for i in range(9)]))
        reject('placement_budget', lambda x: x['situation'].__setitem__('initialLooseItems', [dict(row, id='many-'+str(i), count=1) for i in range(33)]))
        edge = copy.deepcopy(d); edge['observation']['sites'][0]['x'] = 1; edge['situation']['initialLooseItems'][0]['x'] = -1
        try:
            Lab.validate(edge)
        except ValueError as error:
            check('world extent' in str(error), 'near_site_still_requires_world_extent')
        else:
            raise AssertionError('Out-of-world fixture admitted')

        classes = out / 'classes'; classes.mkdir()
        cp = os.pathsep.join(map(str, (GAME / 'projectzomboid.jar', GAME / 'ZombieBuddy.jar', classes)))
        command([JDK / 'javac.exe', '-encoding', 'UTF-8', '-cp', cp, '-d', classes, probe], 'compile')
        for target in ['zombie.iso.IsoGridSquare', 'zombie.Lua.LuaManager$GlobalObject']:
            command([JDK / 'javap.exe', '-classpath', GAME / 'projectzomboid.jar', '-c', '-p', target], 'bytecode-' + target.rsplit('.', 1)[-1])
        source = template.read_text(encoding='utf-8'); fixture = cases.read_text(encoding='utf-8')

        def native(runtime, label, failure=None):
            lane = out / label; lane.mkdir(); script = lane / 'checks.lua'; cache = lane / 'cache'; cache.mkdir()
            script.write_text(extracted(runtime) + fixture, encoding='utf-8')
            result = command([GAME / 'jre64/bin/java.exe', '-Djava.awt.headless=true', '-cp', cp, 'LooseItemsProbe', GAME, script, cache], label, failure is None)
            if failure:
                Lab.require(result.returncode != 0 and failure in (result.stdout + result.stderr), label + ' did not fail for ' + failure)
                receipt['controls'].append({'name': label, 'status': 'REJECTED', 'kind': 'restored-production-source', 'expectedFailure': failure,
                                            'scriptSha256': digest(script)})
            else:
                count = next(int(line.split()[-1]) for line in result.stdout.splitlines() if line.startswith('LOOSE_ITEM_CHECKS '))
                check('NATIVE_LOOSE_ITEMS_PASS' in result.stdout, 'real_native_placement_and_lua_receipt_checks')
                receipt['nativeChecks'] = count

        native(source, 'production')
        mutations = [
            ('drop_tick_join', '    applyInitialLooseItems()\n', '', 'actual_tick_places_exact_native_objects'),
            ('repeat_completed', 'not prior or prior.status == "attempted"', 'true', 'repeat_tick_does_not_duplicate'),
            ('forget_prior', 'local prior = ledger and ledger.placements[placement.id]', 'local prior = nil', 'repeat_tick_does_not_duplicate'),
            ('drop_definition_custody', 'ledger.definitionSha256 == Config.definitionSha256', 'true', 'reject_foreign_definitionSha256'),
            ('drop_save_custody', 'ledger.save == save', 'true', 'reject_foreign_save'),
            ('drop_configuration_custody', 'ledger.configuration == configuration', 'true', 'reject_foreign_configuration'),
            ('drop_floor', 'square:getFloor() and square:TreatAsSolidFloor()', 'square:TreatAsSolidFloor()', 'missing_floor_refused_before_allocation'),
            ('drop_item_type', 'item:getFullType() == placement.fullType', 'true', 'native_refusal_foreign-type'),
            ('drop_item_id', 'item:getID() == id', 'true', 'native_refusal_foreign-id'),
            ('drop_world_square', 'worldItem:getSquare() == square', 'true', 'native_refusal_foreign-square'),
            ('drop_return_identity', 'result == item', 'true', 'native_refusal_foreign-return'),
            ('allocation_before_journal', 'receipt.items[tostring(ordinal)] = itemReceipt\n                        local item = assert(instanceItem(placement.fullType), "native-item-unavailable")',
             'local item = assert(instanceItem(placement.fullType), "native-item-unavailable")\n                        receipt.items[tostring(ordinal)] = itemReceipt', 'actual_tick_places_exact_native_objects'),
        ]
        if not baseline_only:
            for name, before, after, failure in mutations:
                count = source.count(before)
                Lab.require(count == (2 if name == 'drop_item_type' else 1), 'Mutation seam differs: ' + name)
                native(source.replace(before, after), name, failure)
        receipt['status'] = 'PASS'
    except Exception as failure:
        receipt['failure'] = str(failure)
        raise
    finally:
        receipt['inputsAfter'] = {str(p): digest(p) for p in inputs}
        receipt['changedInputs'] = [p for p, sha in receipt['inputsBefore'].items() if receipt['inputsAfter'][p] != sha]
        if receipt['changedInputs']:
            receipt['status'] = 'INCOMPLETE'
        retain()
    Lab.require(not receipt['changedInputs'], 'Proof inputs changed')
    print('PASS loose items:', receipt['nativeChecks'], 'native/Lua checks;', len(receipt['controls']), 'controls')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--baseline-only', action='store_true')
    args = parser.parse_args()
    try:
        run(args.output_dir.resolve(), args.baseline_only)
    except Exception as error:
        print('FAIL loose items:', error)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
