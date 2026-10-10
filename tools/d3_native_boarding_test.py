#!/usr/bin/env python3
"""Installed native boarding lifecycle, equipment, nested transfer and cancellation controls.

The map, actor, dispatch and network are controlled. Installed Kahlua serialization
round-trips the person outbox; actual installed action files produce the effects.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
GAME = Path(os.environ.get('PZ_DIR', r'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'))
JDK = Path(os.environ.get('JDK_BIN', r'C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin'))
LUA = ROOT / 'mod/42.20/media/lua'
BUILD = LUA / 'client/SAO_Build.lua'
JAVA_BUILD = ROOT / 'java/src/com/sao/engine/SAOBuild.java'
PLANNER = LUA / 'shared/SAO_ProceduralPlanning.lua'
CASES = ROOT / 'tools/luacheck/d3_native_boarding_cases.lua'
BASE = ROOT / 'tools/luacheck/window_repair_cases.lua'
PROBE = ROOT / 'tools/luacheck/WindowRepairNativeProbe.java'
NATIVE = [GAME / 'media/lua/shared/ISBaseObject.lua',
          GAME / 'media/lua/shared/TimedActions/ISBaseTimedAction.lua',
          GAME / 'media/lua/client/TimedActions/ISTimedActionQueue.lua',
          GAME / 'media/lua/shared/TimedActions/ISEquipWeaponAction.lua',
          GAME / 'media/lua/client/TimedActions/ISInventoryTransferAction.lua',
          GAME / 'media/lua/shared/TimedActions/ISBarricadeAction.lua']

def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def execute(out: Path, sources: dict[str, str], classes: Path, expected: set[str]) -> dict:
    out.mkdir()
    shutil.copy2(GAME / 'stdlib.lua', out / 'stdlib.lua')
    paths = []
    for name, source in sources.items():
        path = out / name
        path.write_text(source, encoding='utf-8')
        paths.append(str(path))
    command = [str(JDK / 'java.exe'), '-cp', f"{GAME / 'projectzomboid.jar'};{classes}",
               'WindowRepairNativeProbe', *paths]
    done = subprocess.run(command, cwd=out, text=True, capture_output=True, timeout=90)
    output = done.stdout + done.stderr
    (out / 'output.log').write_text(output, encoding='utf-8')
    checks = dict(re.findall(r'([a-z0-9_]+)=(true|false)', output))
    return {'exitCode': done.returncode, 'checks': checks,
            'failed': sorted(k for k, v in checks.items() if v != 'true'),
            'missing': sorted(expected - checks.keys()), 'extra': sorted(checks.keys() - expected),
            'logSha256': digest(out / 'output.log')}

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path)
    parser.add_argument('--required', action='store_true')
    args = parser.parse_args()
    owned = [Path(__file__), BUILD, JAVA_BUILD, PLANNER, CASES, BASE, PROBE]
    installed = [*NATIVE, GAME / 'projectzomboid.jar', GAME / 'stdlib.lua', JDK / 'java.exe', JDK / 'javac.exe', JDK / 'javap.exe']
    missing_owned = [str(p) for p in owned if not p.is_file()]
    if missing_owned:
        print('FAIL missing owned boarding inputs: ' + ', '.join(missing_owned)); return 1
    missing_native = [str(p) for p in installed if not p.is_file()]
    if missing_native:
        print(('FAIL' if args.required else 'UNOBSERVABLE') + ' installed boarding inputs absent: ' + ', '.join(missing_native))
        return 1 if args.required else 0
    temp = tempfile.TemporaryDirectory(prefix='sao-native-boarding-') if args.out is None else None
    out = Path(temp.name) / 'proof' if temp else args.out.resolve()
    if out.exists(): raise ValueError('refuse replacing previous proof')
    out.mkdir(parents=True)
    inputs = owned + installed
    before = {str(p): digest(p) for p in inputs}
    api = subprocess.run([str(JDK / 'javap.exe'), '-classpath', str(GAME / 'projectzomboid.jar'),
                          'zombie.scripting.objects.ItemType', 'zombie.characters.IsoGameCharacter',
                          'zombie.characters.CharacterTimedActions.BaseAction', 'zombie.inventory.ItemContainer',
                          'java.util.ArrayList'],
                         capture_output=True, text=True, timeout=90)
    (out / 'native-api.txt').write_text(api.stdout + api.stderr, encoding='utf-8')
    type_api = api.stdout.split('Compiled from "IsoGameCharacter.java"', 1)[0]
    native_api = api.returncode == 0 and ' HAMMER;' not in type_api and all(signature in api.stdout for signature in (
        'hasEquippedTag(zombie.scripting.objects.ItemTag)', 'boolean finished()', 'boolean isForceComplete()',
        'getFirstTagEval(zombie.scripting.objects.ItemTag', 'getFirstTypeEval(java.lang.String',
        'getFirstTypeEvalRecurse(java.lang.String', 'getAllTypeEval(java.lang.String',
        'getAllTypeEvalRecurse(java.lang.String', 'getItems()', 'public E set(int, E)',
        'getOutermostContainer()', 'RemoveAll(java.lang.String, int)'))
    if not native_api:
        print('FAIL native boarding API mismatch'); return 1
    classes = out / 'classes'; classes.mkdir()
    compiled = subprocess.run([str(JDK / 'javac.exe'), '-cp', str(GAME / 'projectzomboid.jar'),
                               '-d', str(classes), str(PROBE)], capture_output=True, text=True, timeout=90)
    (out / 'compile.log').write_text(compiled.stdout + compiled.stderr, encoding='utf-8')
    if compiled.returncode:
        print(compiled.stdout + compiled.stderr); return 1
    base = BASE.read_text(encoding='utf-8-sig').split('function __runWindowCases()', 1)[0]
    cases = CASES.read_text(encoding='utf-8-sig')
    expected = set(re.findall(r"check\('([a-z0-9_]+)'", cases))
    sources = {'base.lua': base, 'cases.lua': cases}
    sources.update({f'native-{i}.lua': p.read_text(encoding='utf-8-sig') for i, p in enumerate(NATIVE)})
    sources.update({'planner.lua': PLANNER.read_text(encoding='utf-8-sig'),
                    'build.lua': BUILD.read_text(encoding='utf-8-sig'), 'run.lua': '__runBoardingCases()'})
    normal = execute(out / 'normal', sources, classes, expected)
    controls = []
    mutations = [
        ('native-door-close', 'native-5.lua', 'self.item:ToggleDoor(self.character)',
         'self.item = self.item', 'open_door_native_start_closes'),
        ('native-door-start-state', 'native-5.lua', 'self.isStarted = true',
         'self.isStarted = false', 'reopened_door_after_start_refuses'),
        ('started-door-validation', 'build.lua', 'if action.isStarted and (instanceof(target,"IsoDoor")',
         'if false and (instanceof(target,"IsoDoor")', 'reopened_thumpable_door_after_start_refuses'),
        ('complete-door-validation', 'build.lua', 'or kind=="board" and nativeValid(self)~=true',
         'or false', 'reopened_door_before_complete_refuses'),
        ('eligible-plank-selection', 'build.lua',
         'b.plank=b.inventory:getFirstTypeEval("Base.Plank",availableMaterial)\n        or b.inventory:getFirstTypeEvalRecurse("Base.Plank",availableMaterial)',
         'b.plank=b.inventory:getFirstType("Base.Plank") or b.inventory:getFirstTypeRecurse("Base.Plank")',
         'eligible_plank_after_consumed_selected'),
        ('eligible-nails-selection', 'build.lua',
         'local nails=b.inventory:getAllTypeEval("Base.Nails",availableMaterial)',
         'local nails=b.inventory:getAllType("Base.Nails")', 'eligible_nails_after_consumed_native_payment'),
        ('native-payment-preparation', 'build.lua',
         'if not b.prepared and not prepareNativePayment(b) then',
         'if false then', 'eligible_plank_native_exact_payment'),
        ('raw-plank-before-perform', 'build.lua',
         'rawType=="Plank" or fullType=="Plank"',
         'fullType=="Base.Plank"', 'foreign_plank_before_perform_refuses'),
        ('raw-plank-before-complete', 'build.lua',
         'rawType=="Plank" or fullType=="Plank"',
         'fullType=="Base.Plank"', 'consumed_foreign_plank_before_complete_refuses'),
        ('raw-nails-before-perform', 'build.lua',
         'rawType=="Nails" or fullType=="Nails"',
         'fullType=="Base.Nails"', 'foreign_nails_before_perform_refuses'),
        ('raw-nails-before-complete', 'build.lua',
         'rawType=="Nails" or fullType=="Nails"',
         'fullType=="Base.Nails"', 'consumed_foreign_nails_before_complete_refuses'),
        ('raw-container-before-perform', 'build.lua',
         'local rawType,fullType=item:getType(),item:getFullType()',
         'local rawType,fullType=item:getType(),item:getFullType()\n        if item:getContainer()~=b.inventory then rawType,fullType="","" end',
         'nil_container_plank_before_perform_refuses'),
        ('raw-container-before-complete', 'build.lua',
         'local rawType,fullType=item:getType(),item:getFullType()',
         'local rawType,fullType=item:getType(),item:getFullType()\n        if item:getContainer()~=b.inventory then rawType,fullType="","" end',
         'foreign_owned_nails_before_complete_refuses'),
        ('raw-eligibility-before-perform', 'build.lua',
         'local rawType,fullType=item:getType(),item:getFullType()',
         'local rawType,fullType=item:getType(),item:getFullType()\n        if item:getIsCraftingConsumed() then rawType,fullType="","" end',
         'consumed_foreign_nails_before_perform_refuses'),
        ('raw-eligibility-before-complete', 'build.lua',
         'local rawType,fullType=item:getType(),item:getFullType()',
         'local rawType,fullType=item:getType(),item:getFullType()\n        if item:getIsCraftingConsumed() then rawType,fullType="","" end',
         'consumed_foreign_plank_before_complete_refuses'),
        ('native-end', 'build.lua', 'return ok and ended==true', 'return true', 'perform_before_native_end_refuses'),
        ('saved-admission-binding', 'build.lua', 'or admission.correlationId~=work.id', 'or false', 'stale_admission_recovery_refuses'),
        ('saved-native-queue', 'build.lua', 'if q.current or #q.queue>0 then return false end', 'if false then return false end', 'saved_native_queue_recovery_refuses'),
        ('interrupted-recovery', 'build.lua', 'work.status~="interrupted" or work.resultSequence~=nil', 'true or work.resultSequence~=nil', 'interrupted_clock_restoration_recovers'),
        ('transfer-stop-cleanup', 'build.lua', 'self:stopLoopingSound()', 'self.loopSound=self.loopSound', 'boarding_transfer_interrupt_native_cleanup'),
        ('equip-stop-cleanup', 'build.lua', 'self:restoreWeaponType()', 'self.sound=self.sound', 'boarding_equip_interrupt_native_cleanup'),
        ('transfer-stop-ownership', 'build.lua', 'if ownsTransfer and current(c) then', 'if true then', 'boarding_transfer_replacement_preserved'),
        ('equip-stop-ownership', 'build.lua', 'if ownsAction and current(c) then', 'if true then', 'boarding_equip_replacement_preserved'),
        ('material-binding', 'build.lua', 'if materials then', 'if false then', 'board_same_id_material_refuses'),
        ('native-ack', 'build.lua', 'or c.action.action and not c.acknowledged', 'or false', 'queue_absence_is_not_ack'),
        ('private-result-authority', 'planner.lua',
         'and authority ~= BARRICADE_RESULT then return false end',
         'and false then return false end', 'generic_result_cannot_credit'),
    ]
    for name, filename, old, new, detector in mutations:
        variant = dict(sources)
        count = variant[filename].count(old)
        if count != 1:
            controls.append({'name': name, 'detected': False, 'mutationMatches': count}); continue
        variant[filename] = variant[filename].replace(old, new, 1)
        result = execute(out / name, variant, classes, expected)
        result.update(name=name, detector=detector,
                      detected=result['exitCode'] == 0 and result['checks'].get(detector) == 'false')
        controls.append(result)
    after = {str(p): digest(p) for p in inputs}
    passed = native_api and normal['exitCode'] == 0 and not normal['failed'] and not normal['missing'] and not normal['extra'] and before == after and all(c['detected'] for c in controls)
    receipt = {'schema': 'sao-d3-native-boarding-proof/1', 'status': 'PASS' if passed else 'FAIL',
               'sourcePins': before, 'sourcePreserved': before == after, 'normal': normal, 'controls': controls,
               'nativeApi': {'verified': native_api, 'exitCode': api.returncode, 'outputSha256': digest(out / 'native-api.txt')},
               'boundary': 'Installed Kahlua/action/equipment/transfer/queue and native table serialization; controlled actor/map/material receivers/dispatch/network; no loaded game.'}
    (out / 'receipt.json').write_text(json.dumps(receipt, indent=2, sort_keys=True) + '\n', encoding='utf-8')
    print(f"D3 native boarding {'PASS' if passed else 'FAIL'}: {len(normal['checks'])}/{len(expected)} cases; {sum(c['detected'] for c in controls)}/{len(controls)} controls")
    if not passed:
        print(normal)
        print([(c['name'], c.get('detected'), c.get('mutationMatches')) for c in controls])
        print((out / 'normal/output.log').read_text(encoding='utf-8')[-6000:])
    print(f'receipt {out / "receipt.json"}')
    if temp: temp.cleanup()
    return 0 if passed else 1

if __name__ == '__main__':
    raise SystemExit(main())
