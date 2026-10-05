"""Production sight acquisition across floors through installed native LOS."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import subprocess
from native_proof_preflight import installed_presence

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    out = args.output.resolve(); out.mkdir(parents=True, exist_ok=False)
    game = Path(os.environ.get('PZ_DIR', r'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'))
    jdk = Path(os.environ.get('JDK_BIN', r'C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin'))
    scanner = ROOT / 'java/src/com/sao/engine/SAOPerceptionScanner.java'
    probe = ROOT / 'tools/javacheck/UpperFloorSightProbe.java'
    fixture = ROOT / 'tools/luacheck/MovementCrossingProbe.java'
    jars = [game/'projectzomboid.jar', game/'ZombieBuddy.jar', ROOT/'mod/42.20/media/java/SAO.jar']
    paths = [Path(__file__), scanner, probe, fixture, *jars, jdk/'java.exe', jdk/'javac.exe']
    paths.append(Path(__file__).with_name('native_proof_preflight.py'))
    preflight = installed_presence(paths, game, jdk, "upper floor sight")
    if preflight is not None:
        raise SystemExit(preflight)
    sha = lambda data: hashlib.sha256(data).hexdigest()
    pins = lambda: {str(p): sha(p.read_bytes()) for p in paths}
    receipt = {'schema': 'sao-upper-floor-sight-proof/1', 'status': 'INCOMPLETE', 'inputs': pins(),
               'runs': [], 'controls': [],
               'boundary': 'Actual installed native LOS and production scanner on controlled loaded geometry/vision matrices. No rendered gameplay, window artwork, human recognition or physical action acceptance.'}
    def save():
        (out/'receipt.json').write_bytes((json.dumps(receipt, indent=2)+'\n').encode('utf-8'))
    def run(label, argv, expected=None):
        result = subprocess.run(list(map(str, argv)), cwd=game, capture_output=True, timeout=90)
        log = result.stdout+result.stderr
        (out/(label+'.log')).write_bytes(log)
        receipt['runs'].append({'name': label, 'command': list(map(str, argv)),
            'exitCode': result.returncode, 'log': label+'.log', 'logSha256': sha(log)})
        save()
        text = log.decode('utf-8', errors='replace')
        if expected:
            assert result.returncode != 0 and ('AssertionError: '+expected) in text, text
        else:
            assert result.returncode == 0, text
        return text
    cp = os.pathsep.join(map(str, jars))
    classes = out/'classes'; classes.mkdir()
    run('compile', [jdk/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',classes,scanner,fixture,probe])
    def execute(label, leading, expected=None):
        return run(label, [jdk/'java.exe','--enable-native-access=ALL-UNNAMED',
            '-Djava.library.path='+str(game), '-Duser.home='+str(out/(label+'-home')),
            '-cp',os.pathsep.join(map(str,[leading,classes,*jars])), 'UpperFloorSightProbe'],expected)
    production = execute('production', classes)
    checks = re.findall(r'CHECK ([a-z_]+)=true', production)
    expected_checks = re.findall(r'check\("([a-z_]+)"',probe.read_text(encoding='utf-8'))
    assert set(checks)==set(expected_checks) and len(checks)==len(expected_checks)
    receipt['assertions'] = len(checks)
    source = scanner.read_text(encoding='utf-8')
    mutations = [
        ('restore-floor-refusal', 'float oz = other.getZ();',
         'float oz = other.getZ(); if (Math.abs(oz-sz)>=0.5f) return false;', 'upper_floor_can_acquire_person'),
        ('ignore-occlusion', 'return clearPath(eye, target, true);', 'return true;', 'upper_floor_occlusion_refuses'),
        ('ignore-facing', 'alignment < CONE_COS', 'false', 'lower_floor_opposite_facing_refuses'),
        ('omit-person-floor', 'out.append(":floor:").append((int) Math.floor(other.getZ()));', '', 'scanner_retains_actual_target_floor'),
        ('ignore-loaded-square', 'eye.getCell().getGridSquare(target.getX(), target.getY(), target.getZ()) != target',
         'false', 'unloaded_square_refused'),
    ]
    for label, before, after, expected in mutations:
        # Facing is shared with several world-point owners; retain their tests
        # unchanged and replace only the final character-sight occurrence.
        assert source.count(before)>=1
        if label=='ignore-facing':
            index=source.rfind(before); mutated=source[:index]+after+source[index+len(before):]
        else:
            assert source.count(before)==1, label
            mutated=source.replace(before,after)
        directory=out/'controls'/label; directory.mkdir(parents=True)
        changed=directory/scanner.name; changed.write_bytes(mutated.encode('utf-8'))
        run('compile-'+label,[jdk/'javac.exe','-encoding','UTF-8','-cp',str(classes)+os.pathsep+cp,
                             '-d',directory,changed])
        execute(label,directory,expected)
        receipt['controls'].append({'name':label,'expectedFailure':expected,'sourceSha256':sha(changed.read_bytes())})
    assert receipt['inputs']==pins(), 'inputs changed during proof'
    receipt['status']='PASS'; save()
    print(json.dumps({'status': 'PASS', 'assertions': len(checks), 'controls':len(mutations)}))


if __name__=='__main__':
    main()
