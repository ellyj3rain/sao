#!/usr/bin/env python3
"""Installed native corpse ownership and retired-shell scheduling, with defect controls."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from native_proof_preflight import installed_presence

ROOT = Path(__file__).resolve().parent.parent
GAME = Path(os.environ.get('PZ_DIR', r'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'))
JDK = Path(os.environ.get('JDK_BIN', r'C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin'))
SHELL = 'java/src/com/sao/engine/SAOIsoPlayerShell.java'
DEATH = 'java/src/com/sao/engine/SAONativeDeath.java'
BRIDGE = 'java/src/com/sao/bridge/SAOBridge.java'
GUARD = 'if (SAONativeDeath.hasCorpse(this)) { SAOOrientation.forget(this); return; }'
CONTROLS = [
    ('retired-update', SHELL, 'public void update() {\n        if (removalPending) { SAOOrientation.forget(this); return; }\n        ' + GUARD,
     'public void update() {\n        if (removalPending) { SAOOrientation.forget(this); return; }', 'retired_update_must_not_run'),
    ('retired-postupdate', SHELL, 'public void postupdate() {\n        if (removalPending) { SAOOrientation.forget(this); return; }\n        ' + GUARD,
     'public void postupdate() {\n        if (removalPending) { SAOOrientation.forget(this); return; }', 'native_scheduled_postupdate_cannot_reinsert'),
    ('scheduler-reattachment', SHELL, 'if (SAONativeDeath.hasCorpse(this)) return;', '', 'native_startframe_cannot_reattach_corpse_shell'),
    ('completion-flag-only', DEATH, 'return corpse(shell) != null;', 'return shell != null && shell.isDead() && shell.isOnDeathDone();', 'completion_flag_without_corpse_not_retired'),
    ('native-cell-ownership', DEATH, 'if (cell == null || cell.getObjectList().contains(shell)\n                || cell.getAddList().contains(shell) || cell.getRemoveList().contains(shell)) return false;', '', 'deferred_removal_is_pending'),
    ('unwitnessed-null-square', BRIDGE, 'if (shell.getCurrentSquare() == null) return "DIE_PENDING";', 'if (shell.getCurrentSquare() == null) return "ALREADY_CORPSE";', 'null_square_not_corpse'),
]

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def run_command(cmd, out, name, cwd):
    (out / (name + '-command.json')).write_text(json.dumps(cmd, indent=2))
    result = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=180)
    (out / (name + '.stdout')).write_text(result.stdout)
    (out / (name + '.stderr')).write_text(result.stderr)
    return {'command': cmd, 'cwd': str(cwd), 'exitCode': result.returncode,
            'stdoutSha256': sha(out / (name + '.stdout')), 'stderrSha256': sha(out / (name + '.stderr'))}, result.stdout + result.stderr

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--output-dir', type=Path)
    ap.add_argument('--variants', nargs='+')
    args = ap.parse_args()
    import tempfile
    out = (args.output_dir or Path(tempfile.mkdtemp(prefix='sao-corpse-'))).resolve()
    out.mkdir(parents=True, exist_ok=True)
    if (out / 'receipt.json').exists():
        raise RuntimeError('Refusing to overwrite corpse proof receipt')
    sources = sorted((ROOT / 'java/src').rglob('*.java'))
    inputs = sources + [ROOT / 'VERSION', ROOT / 'tools/luacheck/CorpseLifecycleProbe.java',
                      ROOT / 'tools/luacheck/MovementCrossingProbe.java', Path(__file__),
                      GAME / 'projectzomboid.jar', GAME / 'ZombieBuddy.jar']
    inputs.append(Path(__file__).with_name('native_proof_preflight.py'))
    preflight = installed_presence(inputs, GAME, JDK, "corpse lifecycle")
    if preflight is not None:
        raise SystemExit(preflight)
    pins = {str(p): sha(p) for p in inputs}
    frozen = out / 'sources'
    for p in sources:
        dest = frozen / p.relative_to(ROOT)
        dest.parent.mkdir(parents=True, exist_ok=True); shutil.copyfile(p, dest)
    for name in ('CorpseLifecycleProbe.java', 'MovementCrossingProbe.java'):
        shutil.copyfile(ROOT / 'tools/luacheck' / name, frozen / name)
    generated = frozen / 'SAOVersion.java'
    generated.write_text('package com.sao; public final class SAOVersion { public static final String VALUE = '
                         + json.dumps((ROOT / 'VERSION').read_text().strip()) + '; }')
    classes = out / 'classes'; classes.mkdir()
    cp = os.pathsep.join(str(GAME / n) for n in ('projectzomboid.jar', 'ZombieBuddy.jar'))
    source_args = out / 'sources.txt'
    source_args.write_text('\n'.join('"' + str(p).replace('\\', '/') + '"' for p in sorted(frozen.rglob('*.java'))))
    receipt = {'schema': 1, 'status': 'INCOMPLETE', 'inputs': pins, 'variants': [],
               'scope': 'Actual installed native die/corpse/scheduler with controlled loaded-square fixture; no rendered game or saved-world mutation.'}
    def save():
        (out / 'receipt.json').write_text(json.dumps(receipt, indent=2))
    save()
    compile_result, output = run_command([str(JDK / 'javac.exe'), '-cp', cp, '-d', str(classes), '@' + str(source_args)], out, 'compile', ROOT)
    receipt['compile'] = compile_result; save()
    if compile_result['exitCode']:
        raise RuntimeError('Production compile failed: ' + output[-2000:])
    def execute(label, overlay=None):
        dest = out / label; dest.mkdir()
        parts = ([str(overlay)] if overlay else []) + [str(classes), cp]
        result, output = run_command([str(JDK / 'java.exe'), '-Djava.library.path=' + str(GAME), '-cp', os.pathsep.join(parts), 'CorpseLifecycleProbe'], dest, 'run', GAME)
        row = {'id': label, 'run': result}
        receipt['variants'].append(row); save()
        return row, output
    row, output = execute('production')
    row['checks'] = output.count('CHECK ')
    row['passed'] = row['run']['exitCode'] == 0 and 'PASS corpse lifecycle' in output
    save()
    if not row['passed']: raise RuntimeError('Production failed: ' + output[-2500:])
    print(output[output.find('CHECK '):].strip())
    selected = set(args.variants) if args.variants else {c[0] for c in CONTROLS}
    if selected - {c[0] for c in CONTROLS}: raise RuntimeError('Unknown control')
    for label, filename, before, after, marker in CONTROLS:
        if label not in selected: continue
        text = (frozen / filename).read_text()
        if text.count(before) != 1: raise RuntimeError('Control anchor drift: ' + label)
        source = out / ('mutant-' + label) / Path(filename).name
        source.parent.mkdir(); source.write_text(text.replace(before, after, 1))
        overlay = source.parent / 'classes'; overlay.mkdir()
        compiled, output = run_command([str(JDK / 'javac.exe'), '-cp', str(classes) + os.pathsep + cp, '-d', str(overlay), str(source)], source.parent, 'compile', ROOT)
        if compiled['exitCode']: raise RuntimeError('Control compile failed: ' + label + ': ' + output[-1500:])
        row, output = execute(label, overlay)
        row.update({'compile': compiled, 'expectedFailure': marker,
                    'passed': row['run']['exitCode'] != 0 and ('AssertionError: ' + marker) in output})
        save()
        if not row['passed']: raise RuntimeError('Control failed: ' + label + ': ' + output[-1800:])
        print('CONTROL rejected ' + label)
    receipt['inputsAfter'] = {str(p): sha(p) for p in inputs}
    receipt['changedInputs'] = [p for p in pins if pins[p] != receipt['inputsAfter'][p]]
    receipt['status'] = 'PASS' if not receipt['changedInputs'] else 'INPUT_DRIFT'
    save()
    if receipt['changedInputs']: raise RuntimeError('Inputs changed during proof')
    print('PASS corpse lifecycle proof', out)
    return 0

if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        print('FAIL corpse lifecycle:', error, file=sys.stderr)
        raise SystemExit(1)
