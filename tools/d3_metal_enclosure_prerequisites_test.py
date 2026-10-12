#!/usr/bin/env python3
"""D3.15 installed metal-enclosure prerequisite contracts, independent of SAO runtime."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
GAME = Path(os.environ.get('PZ_DIR', r'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'))
JDK = Path(os.environ.get('JAVA_BIN', r'C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin'))
PROBE = ROOT / 'tools/resource_production_checks/MetalEnclosurePrerequisiteProbe.java'
ENTITIES = ['windowframelvl1', 'windowframelvl2', 'fencelvl1', 'fencelvl2', 'smallpolelfence',
            'bigmetalfence', 'smallwirefence', 'bigwirefence', 'polefencegate', 'polefencegatesmall',
            'wirefencegate', 'wirefencegatesmall']
NATIVE = [f'media/scripts/generated/entities/walls/entity_metal_{name}.txt' for name in ENTITIES]
NATIVE += [f'media/scripts/generated/items/{name}.txt' for name in ['literature', 'drainable', 'normal', 'weapon']]
NATIVE += ['media/scripts/generated/timedactions.txt', 'media/lua/server/BuildRecipeCode/buildRecipeCode.lua',
           'media/lua/server/BuildingObjects/ISBuildIsoEntity.lua',
           'media/lua/client/BuildingObjects/TimedActions/ISBuildAction.lua',
           'media/lua/shared/TimedActions/ISReadABook.lua']

def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--no-controls', action='store_true', help='Diagnostic positive run only; does not qualify instruments.')
    args = parser.parse_args()
    work = args.output.resolve()
    if work.exists():
        print('FAIL: output already exists; select a new receipt directory')
        return 1
    work.mkdir(parents=True)
    jars = [GAME / 'projectzomboid.jar', GAME / 'ZombieBuddy.jar', *sorted((GAME / 'jars').glob('*.jar'))]
    required = [PROBE, *[GAME / p for p in NATIVE], GAME / 'stdlib.lua', JDK / 'java.exe', JDK / 'javac.exe', *jars]
    absent = [str(p) for p in required if not p.is_file()]
    if absent:
        (work / 'receipt.json').write_text(json.dumps({'status': 'FAIL_REQUIRED_INPUTS', 'absent': absent}, indent=2)+'\n')
        print('FAIL native prerequisite inputs: '+', '.join(absent))
        return 1
    for p in NATIVE:
        target = work / 'native' / p
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(GAME / p, target)
    classes = work / 'classes'
    classes.mkdir()
    shutil.copy2(GAME / 'stdlib.lua', classes / 'stdlib.lua')
    source = PROBE.read_text()
    positive = work / PROBE.name
    positive.write_text(source)
    cp = os.pathsep.join(map(str, jars))
    receipt = {
        'schema': 'sao-d315-native-enclosure-prerequisites/1', 'status': 'INCOMPLETE',
        'nativePins': {p: sha(GAME / p) for p in NATIVE},
        'compiledInputs': {str(p): sha(p) for p in jars},
        'toolPins': {str(p): sha(p) for p in [PROBE, Path(__file__), JDK / 'javac.exe', JDK / 'java.exe']},
        'stdlibPin': sha(GAME / 'stdlib.lua'),
        'runs': [], 'controls': [],
        'boundary': ('Actual installed native item/entity/recipe/face parsing, skill and learned admission, '
                     'ReadLiterature knowledge, exact manual BuildLogic inventory allocation/payment/use. '
                     'Controlled native IsoPlayer/world/clock/cosmetic fixture; no SAO runtime or moving production inputs. '
                     'No world object construction, placement/collision, window/fence/gate traversal, enclosure/cover, '
                     'recovery, persistence, rendering, loaded operator game or server execution.'),
        'metadataAdaptations': ['Omit UiConfig for unattended entity loading.',
                                'Omit unsupported Researchablerecipes item property as in qualified D3.14 loader.'],
    }
    def save():
        (work / 'receipt.json').write_text(json.dumps(receipt, indent=2)+'\n')
    def invoke(name, command):
        done = subprocess.run(list(map(str, command)), cwd=classes, capture_output=True, timeout=90)
        log = work / (name+'.log')
        log.write_bytes(done.stdout+done.stderr)
        receipt['runs'].append({'name': name, 'command': list(map(str, command)), 'exitCode': done.returncode,
                                'log': log.name, 'sha256': sha(log)})
        save()
        return done.returncode, log.read_text(errors='replace')
    command = [JDK / 'java.exe', '--enable-native-access=ALL-UNNAMED', '-Duser.home='+str(classes),
               '-Djava.awt.headless=true', '-cp', str(classes)+os.pathsep+cp,
               'MetalEnclosurePrerequisiteProbe', work / 'native']
    def compile_probe(path, name):
        code, log = invoke(name+'-compile', [JDK / 'javac.exe', '-encoding', 'UTF-8', '-cp', cp, '-d', classes, path])
        if code != 0:
            raise AssertionError(log)
    def verdicts(log):
        pairs = re.findall(r'^CHECK ([A-Za-z0-9_]+)=(true|false)$', log, re.M)
        if len(dict(pairs)) != len(pairs):
            raise AssertionError('duplicate native verdicts')
        return dict(pairs)
    save()
    try:
        compile_probe(positive, 'positive')
        code, log = invoke('native-positive', command)
        checks = verdicts(log)
        receipt['checks'] = checks
        save()
        assert code == 0 and 'COMPLETE native metal enclosure prerequisite verdicts|checks=156|families=12' in log, log[-9000:]
        assert len(checks) == 156 and all(v == 'true' for v in checks.values()), {k:v for k,v in checks.items() if v!='true'}
        mutations = [
            ('visibility-as-knowledge', 'boolean actual=body.isRecipeActuallyKnown(recipe),visible=',
             'boolean actual=CraftRecipeManager.hasPlayerLearnedRecipe(recipe,body),visible=',
             'MetalWindowFrameLvl1_actual_knowledge_independent_visibility'),
            ('omitted-native-reading', 'body.ReadLiterature(book);', ';', 'MetalWindowFrameLvl1_native_read_acquires_recipe'),
            ('invented-frame-rods', 'boolean exact=recipe.getInputs().size()==p.names().length;',
             'boolean exact=recipe.getInputs().size()==p.names().length && (!p.name().startsWith("MetalWindowFrame") || recipe.getInputs().size()==3);',
             'MetalWindowFrameLvl1_exact_native_inputs_keep_record'),
            ('gate-open-face-omission', 'gate?Set.of("n","w","n_open","w_open"):Set.of("n","w")',
             'gate?Set.of("n","w"):Set.of("n","w")', 'MetalPoleFenceGate_complete_native_faces'),
            ('use-as-object-payment', 'body.getInventory().contains(item)&&item.getCurrentUses()==charges[n]-p.amounts()[n]',
             '!body.getInventory().contains(item)&&item.getCurrentUses()==0', 'MetalWindowFrameLvl1_exact_native_payment'),
            ('omitted-native-payment', 'data.processDestroyAndUsedItems(body);', ';', 'MetalWindowFrameLvl1_exact_native_payment'),
            ('invented-grade2-knowledge', '5,false,null,new String[]{"BlowTorch","MetalBar","WeldingRods"}',
             '5,true,"MetalworkMag3",new String[]{"BlowTorch","MetalBar","WeldingRods"}', 'MetalFenceLvl2_identity_time_knowledge'),
        ]
        if not args.no_controls:
            for name, old, new, detector in mutations:
                assert source.count(old) == 1, (name, source.count(old))
                path = work / name / PROBE.name
                path.parent.mkdir()
                path.write_text(source.replace(old, new, 1))
                compile_probe(path, name)
                code, log = invoke(name, command)
                observed = verdicts(log)
                detected = (code == 0 and observed.get(detector) == 'false' and set(observed) == set(checks)
                            and 'COMPLETE native metal enclosure prerequisite verdicts|checks=156|families=12' in log)
                receipt['controls'].append({'name': name, 'detector': detector, 'detected': detected,
                                            'before': old, 'after': new, 'mutantSha256': sha(path), 'checks': observed})
                save()
                assert detected, (name, log[-6000:])
            # Restore the positive class so the output directory remains replayable.
            compile_probe(positive, 'restore-positive')
        receipt['installedUnchanged'] = all(sha(GAME / p) == h for p,h in receipt['nativePins'].items())
        receipt['compiledInputsUnchanged'] = all(sha(Path(p)) == h for p,h in receipt['compiledInputs'].items())
        receipt['toolsUnchanged'] = all(sha(Path(p)) == h for p,h in receipt['toolPins'].items())
        assert receipt['installedUnchanged'] and receipt['compiledInputsUnchanged'] and receipt['toolsUnchanged']
        receipt['status'] = 'PASS_NATIVE_PREREQUISITES' if not args.no_controls else 'PASS_POSITIVE_ONLY_UNQUALIFIED_INSTRUMENT'
        save()
        print(receipt['status']+': 156 native checks across12 entities; '+str(len(receipt['controls']))+' detecting controls')
        print(work / 'receipt.json')
        return 0
    except Exception as error:
        receipt['status'] = 'FAIL'
        receipt['error'] = str(error)
        save()
        print('FAIL native enclosure prerequisites: '+str(error)[-9000:])
        return 1

if __name__ == '__main__':
    sys.exit(main())
