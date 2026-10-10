#!/usr/bin/env python3
"""Nested owned pane preparation using installed transfer, queue and repair actions.

Kahlua and action logic are installed native code. Actor, map, inventory receivers,
dispatch and hardware/network remain controlled; no loaded game or save is changed.
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
WORKSHOP = Path(os.environ.get('SAO_WINDOW_REPAIR_DIR', r'C:\Program Files (x86)\Steam\steamapps\workshop\content\108600\3378304610\mods\RepairableWindows\42.13'))
LUA = ROOT / 'mod/42.20/media/lua'
REPAIR = LUA / 'client/SAO_WindowRepair.lua'
PLANNER = LUA / 'shared/SAO_ProceduralPlanning.lua'
CASES = ROOT / 'tools/luacheck/d3_window_preparation_cases.lua'
BASE = ROOT / 'tools/luacheck/window_repair_cases.lua'
PROBE = ROOT / 'tools/luacheck/WindowRepairNativeProbe.java'
NATIVE = [GAME / 'media/lua/shared/ISBaseObject.lua',
          GAME / 'media/lua/shared/TimedActions/ISBaseTimedAction.lua',
          GAME / 'media/lua/client/TimedActions/ISTimedActionQueue.lua',
          GAME / 'media/lua/shared/Util/AdjacentFreeTileFinder.lua',
          GAME / 'media/lua/shared/TimedActions/ISTransferAction.lua',
          GAME / 'media/lua/client/TimedActions/ISInventoryTransferAction.lua',
          WORKSHOP / 'media/lua/shared/RepairableWindows/AddWindowAction.lua']

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
    return {'command': command, 'exitCode': done.returncode, 'checks': checks,
            'failed': sorted(k for k, v in checks.items() if v != 'true'),
            'missing': sorted(expected - checks.keys()), 'extra': sorted(checks.keys() - expected),
            'logSha256': digest(out / 'output.log')}

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path)
    parser.add_argument('--required', action='store_true')
    args = parser.parse_args()
    owned = [Path(__file__), REPAIR, PLANNER, CASES, BASE, PROBE]
    installed = [*NATIVE, GAME / 'projectzomboid.jar', GAME / 'stdlib.lua', JDK / 'java.exe', JDK / 'javac.exe']
    missing = [str(p) for p in owned if not p.is_file()]
    if missing:
        print('FAIL missing owned preparation inputs: ' + ', '.join(missing)); return 1
    missing = [str(p) for p in installed if not p.is_file()]
    if missing:
        print(('FAIL' if args.required else 'UNOBSERVABLE') + ' installed preparation inputs absent: ' + ', '.join(missing))
        return 1 if args.required else 0
    temp = tempfile.TemporaryDirectory(prefix='sao-pane-preparation-') if args.out is None else None
    out = Path(temp.name) / 'proof' if temp else args.out.resolve()
    if out.exists(): raise ValueError('refuse replacing previous proof')
    out.mkdir(parents=True)
    inputs = owned + installed
    before = {str(p): digest(p) for p in inputs}
    classes = out / 'classes'; classes.mkdir()
    compiled = subprocess.run([str(JDK / 'javac.exe'), '-cp', str(GAME / 'projectzomboid.jar'),
                               '-d', str(classes), str(PROBE)], capture_output=True, text=True, timeout=90)
    (out / 'compile.log').write_text(compiled.stdout + compiled.stderr, encoding='utf-8')
    if compiled.returncode:
        print(compiled.stdout + compiled.stderr); return 1
    base = BASE.read_text(encoding='utf-8-sig').split('function __runWindowCases()', 1)[0]
    cases = CASES.read_text(encoding='utf-8-sig')
    expected = set(re.findall(r"check\('([a-z0-9_]+)',", cases))
    expected |= {f'prep_{kind}_{phase}' for kind in ('death', 'transfer', 'world')
                 for phase in ('queue_absence_is_not_ack', 'late_ack_retires')}
    sources = {'base.lua': base, 'cases.lua': cases}
    sources.update({f'native-{i}.lua': p.read_text(encoding='utf-8-sig') for i, p in enumerate(NATIVE)})
    sources.update({'planner.lua': PLANNER.read_text(encoding='utf-8-sig'),
                    'repair.lua': REPAIR.read_text(encoding='utf-8-sig'),
                    'run.lua': '__runWindowPreparationCases()\n__setupWindowRecoveryCases()',
                    'fresh-native-action.lua': NATIVE[-1].read_text(encoding='utf-8-sig'),
                    'fresh-repair.lua': REPAIR.read_text(encoding='utf-8-sig'),
                    'recovery-run.lua': '__runWindowRecoveryCases()'})
    normal = execute(out / 'normal', sources, classes, expected)
    mutations = [
        ('reserved-selection', 'getFirstTypeEvalRecurse(PANE, availablePane)', 'getFirstTypeRecurse(PANE)', 'prep_reserved_nested_shadow_is_skipped'),
        ('reserved-binding', 'or not availablePane(b.pane)', 'or false', 'prep_bound_pane_reservation_drift_refuses'),
        ('native-end', 'return ok and ended == true', 'return true', 'prep_perform_before_native_end_refuses'),
        ('outer-source', 'or source:getOutermostContainer() ~= b.inventory', 'or false', 'prep_changed_outer_owner_refuses'),
        ('native-ack', 'c.action.action and not c.acknowledged', 'false', 'prep_death_queue_absence_is_not_ack'),
        ('source-poststate', 'and not c.source:contains(c.item)', 'and true', 'prep_source_absence_measured'),
        ('exact-purpose', 'admission.correlationId ~= b.workId', 'false', 'prep_final_exact_purpose_refuses'),
        ('recovery-native-queue', 'pending ~= false', 'false', 'recovery_missing_lua_queue_does_not_ack_native'),
        ('recovery-correlation', 'admission.correlationId == work.id', 'true', 'recovery_changed_correlation_refuses_without_mutation'),
        ('recovery-clock', 'work.startedAt > at', 'false', 'recovery_clock_rewind_refuses_without_mutation'),
        ('recovery-physical-claim', 'row.nativeAttempted ~= nil', 'false', 'recovery_effect_facts_refuse_authentication'),
        ('active-saved-owner', 'return not W.reconcileSaved(id, body)', 'return false', 'recovery_active_no_runtime_uses_owner_result'),
    ]
    controls = []
    for name, old, new, detector in mutations:
        variant = dict(sources)
        count = variant['repair.lua'].count(old)
        if count != 1 or variant['fresh-repair.lua'].count(old) != 1:
            controls.append({'name': name, 'detected': False, 'mutationMatches': count}); continue
        variant['repair.lua'] = variant['repair.lua'].replace(old, new, 1)
        variant['fresh-repair.lua'] = variant['fresh-repair.lua'].replace(old, new, 1)
        result = execute(out / name, variant, classes, expected)
        result.update(name=name, detector=detector,
                      detected=result['exitCode'] == 0 and result['checks'].get(detector) == 'false')
        controls.append(result)
    after = {str(p): digest(p) for p in inputs}
    passed = normal['exitCode'] == 0 and not normal['failed'] and not normal['missing'] and not normal['extra'] and before == after and all(c['detected'] for c in controls)
    receipt = {'schema': 'sao-d3-window-preparation-proof/1', 'status': 'PASS' if passed else 'FAIL',
               'sourcePins': before, 'sourcePreserved': before == after, 'normal': normal, 'controls': controls,
               'boundary': 'Installed Kahlua/native transfer/queue/repair and table serialization; controlled actor/map/inventory receivers/dispatch/network; no loaded game.'}
    (out / 'receipt.json').write_text(json.dumps(receipt, indent=2, sort_keys=True) + '\n', encoding='utf-8')
    print(f"D3 window preparation {'PASS' if passed else 'FAIL'}: {len(normal['checks'])}/{len(expected)} cases; {sum(c['detected'] for c in controls)}/{len(controls)} controls")
    if not passed:
        print(normal)
        print([(c['name'], c.get('detected'), c.get('mutationMatches')) for c in controls])
        print((out / 'normal/output.log').read_text(encoding='utf-8')[-6000:])
    print(f'receipt {out / "receipt.json"}')
    if temp: temp.cleanup()
    return 0 if passed else 1

if __name__ == '__main__':
    raise SystemExit(main())
