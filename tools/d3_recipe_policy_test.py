#!/usr/bin/env python3
"""Registered native recipe projection/exact-selection qualification; no game effects."""
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
import tempfile

ROOT = Path(__file__).resolve().parent.parent
GAME = Path(os.environ.get('PZ_DIR', r'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'))
JDK = Path(os.environ.get('JDK_BIN', r'C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin'))
POLICY = ROOT / 'mod/42.20/media/lua/shared/SAO_RecipePolicy.lua'
PROBE = ROOT / 'tools/recipe_policy_checks/RecipePolicyNativeProbe.java'
CASES = ROOT / 'tools/recipe_policy_checks/cases.lua'

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def execute(out, classes, source, expected):
    out.mkdir()
    shutil.copy2(GAME / 'stdlib.lua', out / 'stdlib.lua')
    policy = out / 'policy.lua'
    policy.write_text(source, encoding='utf-8')
    command = [str(JDK / 'java.exe'), '--enable-native-access=ALL-UNNAMED', f'-Duser.home={out}',
               f'-Dsao.game={GAME}', '-cp', f'{GAME / "projectzomboid.jar"};{classes}',
               'RecipePolicyNativeProbe', str(GAME), str(policy), str(CASES)]
    result = subprocess.run(command, cwd=out, text=True, capture_output=True, timeout=90)
    log = out / 'output.log'
    log.write_text(result.stdout + result.stderr, encoding='utf-8')
    checks = dict(re.findall(r'CHECK ([A-Za-z0-9_]+)=(true|false)', result.stdout))
    projections = {name: json.loads(row) for name, row in re.findall(r'^PROJECTION (\w+) (\{.*\})$', result.stdout, re.M)}
    (out / 'projections.json').write_text(json.dumps(projections,indent=2,sort_keys=True)+'\n',encoding='utf-8')
    return {'command': command, 'exitCode': result.returncode, 'checks': checks,
            'missing': sorted(expected - checks.keys()),
            'failed': sorted(k for k, v in checks.items() if v != 'true'),
            'logSha256': digest(log), 'projectionSha256': digest(out / 'projections.json')}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path)
    parser.add_argument('--required', action='store_true')
    parser.add_argument('--control', action='append')
    args = parser.parse_args()
    owned = [Path(__file__), POLICY, PROBE, CASES]
    native = [GAME / 'projectzomboid.jar', GAME / 'stdlib.lua', JDK / 'java.exe', JDK / 'javac.exe', JDK / 'javap.exe', Path(sys.executable)]
    native += sorted((GAME / 'media/scripts/generated/items').rglob('*.txt'))
    native += [GAME / 'media/scripts/generated/recipes' / name for name in
               ['recipes_fixing.txt', 'recipes.txt', 'recipes_carpentry.txt', 'recipes_metalWelding.txt', 'recipes_ammunition.txt']]
    native += [GAME / 'media/scripts/generated/timedactions.txt',
               GAME / 'media/scripts/generated/fluids.txt', GAME / 'media/scripts/generated/energies.txt',
               GAME / 'media/scripts/generated/entities/blacksmith/workstations/entity_grindstone.txt']
    missing = [str(p) for p in owned + native if not p.is_file()]
    if missing:
        print(('FAIL' if any(not p.is_file() for p in owned) else 'NATIVE_UNAVAILABLE') + ': ' + ', '.join(missing))
        return 1 if args.required or any(not p.is_file() for p in owned) else 0
    temporary = tempfile.TemporaryDirectory(prefix='sao-recipe-policy-') if args.out is None else None
    out = Path(temporary.name) / 'proof' if temporary else args.out.resolve()
    if out.exists():
        raise ValueError('refuse replacing previous proof')
    out.mkdir(parents=True)
    before = {str(p): digest(p) for p in owned + native}
    api_command=[str(JDK / 'javap.exe'),'-classpath',str(GAME / 'projectzomboid.jar'),'-c',
        'zombie.scripting.entity.components.crafting.CraftRecipe',
        'zombie.scripting.entity.components.crafting.InputScript',
        'zombie.scripting.entity.components.crafting.OutputScript',
        'zombie.entity.components.crafting.recipe.CraftRecipeManager',
        'zombie.entity.components.crafting.recipe.CraftRecipeData',
        'zombie.entity.components.crafting.BaseCraftingLogic',
        'zombie.entity.components.crafting.recipe.HandcraftLogic']
    api=subprocess.run(api_command,capture_output=True,text=True,timeout=90)
    (out / 'native-bytecode.txt').write_text(api.stdout+api.stderr,encoding='utf-8')
    if api.returncode:
        print('FAIL native ABI read');return 1
    classes = out / 'classes'
    classes.mkdir()
    compile_command = [str(JDK / 'javac.exe'), '-cp', str(GAME / 'projectzomboid.jar'), '-d', str(classes), str(PROBE)]
    compiled = subprocess.run(compile_command, capture_output=True, text=True, timeout=90)
    (out / 'compile.log').write_text(compiled.stdout + compiled.stderr, encoding='utf-8')
    if compiled.returncode:
        print(compiled.stdout + compiled.stderr)
        return 1
    expected = set(re.findall(r'check\("([a-z0-9_]+)"', CASES.read_text(encoding='utf-8')))
    expected |= {'fluid_channel_retained_refused', 'energy_channel_retained_refused'}
    source = POLICY.read_text(encoding='utf-8')
    normal = execute(out / 'normal', classes, source, expected)
    mutations = [
        ('reservation', 'reservationContext.canUse(item, slot.index, fresh) == true', 'true', 'reserved_items_refuse'),
        ('tags-status', 'and CraftRecipeManager.isItemValidForInputScript(slot.script, item, body) then',
         'then', 'native_status_refuse'),
        ('kept-state', 'native:isKeep() and "native-effect-unmeasured"', 'native:isKeep() and "unchanged"', 'kept_change_declared'),
        ('mapped-effect', 'actualEffect = "unmeasured", callbackEffect = "native-unresolved"',
         'actualEffect = "known", callbackEffect = "native-unresolved"', 'native_mapped_output_unknown'),
        ('partial-selection', 'if logic:isInputSatisfied(slot.script) then break end', 'break', 'partial_uses_split_selection'),
        ('exact-target', '(target == nil or tostring(item:getID()) == tostring(target))', 'true', 'foreign_target_refuse'),
        ('station-custody', 'not w.object:isUsingPlayer(body)', 'false', 'station_custody_refuse'),
        ('projection-demand', 'result[key] = copied', 'if key ~= "desiredAmount" then result[key] = copied end', 'source_demand_explicit'),
        ('state-recheck', 'or item:getCurrentUses() ~= baseline.uses or item:getCondition() ~= baseline.condition',
         'or false', 'input_state_change_refuse'),
        ('double-spend', 'not used[item] and', 'true and', 'same_item_no_double_spend'),
        ('body-ui-effect', 'logic:getRecipeData():setRecipe(policy.recipe)', 'logic:setRecipe(policy.recipe)', 'no_body_preference_effect'),
        ('energy-identity', 'energies = values(native:getPossibleInputEnergies(), "getEnergyTypeString")',
         'energies = values(native:getPossibleInputEnergies())', 'energy_identity_plain'),
    ]
    controls = []
    names = {m[0] for m in mutations}
    if args.control and set(args.control) - names:
        raise ValueError('unknown control')
    for name, old, new, detector in mutations:
        if args.control and name not in args.control:
            continue
        count = source.count(old)
        if count != 1:
            controls.append({'name': name, 'detected': False, 'mutationMatches': count})
            continue
        control = execute(out / name, classes, source.replace(old, new, 1), expected)
        control.update(name=name, detector=detector, detected=control['checks'].get(detector) == 'false')
        controls.append(control)
    after = {str(p): digest(p) for p in owned + native}
    passed = normal['exitCode'] == 0 and not normal['missing'] and not normal['failed'] and before == after and all(c['detected'] for c in controls)
    receipt = {'schema': 'sao-d3-recipe-policy-proof/1', 'status': 'PASS' if passed else 'FAIL',
               'sourcePins': before, 'sourcePreserved': before == after, 'normal': normal, 'controls': controls,
               'compile': {'command': compile_command, 'exitCode': compiled.returncode, 'logSha256': digest(out / 'compile.log')},
               'nativeApi': {'command':api_command,'exitCode':api.returncode,'sha256':digest(out / 'native-bytecode.txt')},
               'executables': {str(p): digest(p) for p in classes.glob('*.class')},
               'boundary': 'Installed registered metadata, item states, CraftRecipeManager predicates, HandcraftLogic manual validation and Kahlua serialization. Controlled unattached body skill/knowledge and station geometry/custody; selected source dictionary with unrelated UI/translation preparation omitted. Instrument-only native parsed fluid/energy/variable/overlap recipes are explicit controls. No effects, attached game, provider, shipping build, native action dispatch or consumer completion.'}
    (out / 'receipt.json').write_text(json.dumps(receipt, indent=2, sort_keys=True) + '\n', encoding='utf-8')
    print(f'D3 recipe policy {receipt["status"]}: {len(normal["checks"])}/{len(expected)} cases; {sum(c["detected"] for c in controls)}/{len(controls)} controls')
    if not passed:
        print('failed', normal['failed'], 'missing', normal['missing'])
        print('controls', [(c['name'], c['detected'], c.get('mutationMatches')) for c in controls])
        print((out / 'normal/output.log').read_text(encoding='utf-8')[-5000:])
    print(f'receipt {out / "receipt.json"}')
    if temporary:
        temporary.cleanup()
    return 0 if passed else 1

if __name__ == '__main__':
    raise SystemExit(main())
