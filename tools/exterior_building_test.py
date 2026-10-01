#!/usr/bin/env python3
"""Personal exterior acquisition against installed native vision and source owners.

Compiles production Java ahead of the packaged runtime. Uses actual loaded-square
fixtures and exact native door, LOS, movement and container methods. No rendered
world timing, prevalence or dataset acceptance is inferred from this check.
"""
from pathlib import Path
import hashlib
import json
import os
import re
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]
GAME=Path(os.environ.get('PZ_DIR',r'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'))
JDK=Path(os.environ.get('JDK_BIN',r'C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin'))
SCANNER=ROOT/'java/src/com/sao/engine/SAOPerceptionScanner.java'

CONTROLS=[
    ('if (!emitted.add(boundaryKey)) continue;', 'if (!emitted.add(Long.toString(def.getID()))) continue;',
        'distinct_visible_doors_same_building_offered'),
    ('!canSeeWorldSquareNow(observer, outside, RANGE)', 'false', 'behind_body_not_acquired'),
    ('observer.getModData().rawget("SAO_ObserverAnchor") != null', 'false', 'god_camera_does_not_acquire_leads'),
    ('!outside.isFree(false)', 'false', 'blocked_exterior_approach_not_offered'),
]

def main():
    required=(GAME/'projectzomboid.jar',GAME/'stdlib.lua',JDK/'java.exe',JDK/'javac.exe')
    if not all(path.is_file() for path in required):
        print('Border 227 SKIPPED: installed engine VM or JDK absent; native exterior acquisition unverified')
        return 0
    cp=os.pathsep.join(map(str,[GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar',ROOT/'mod/42.20/media/java/SAO.jar']))
    output=ROOT/'_scratch/c110-validation/exterior-native';output.mkdir(parents=True,exist_ok=True)
    receipt={'schema':'sao-exterior-native-proof/1','status':'RUNNING','runs':[],
        'engineSha256':hashlib.sha256((GAME/'projectzomboid.jar').read_bytes()).hexdigest(),
        'scannerSha256':hashlib.sha256(SCANNER.read_bytes()).hexdigest()}
    def execute(args,name,expected=None):
        done=subprocess.run(list(map(str,args)),cwd=GAME,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=120)
        text=done.stdout+done.stderr;(output/(name+'.log')).write_text(text,encoding='utf-8')
        passed=(done.returncode!=0 and expected in text) if expected else done.returncode==0
        receipt['runs'].append({'name':name,'exit':done.returncode,'passed':passed,'expectedFailure':expected})
        (output/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
        if not passed:raise RuntimeError(name+'\n'+text[-7000:])
        return text
    try:
        with tempfile.TemporaryDirectory(prefix='sao-exterior-native-') as directory:
            work=Path(directory);classes=work/'classes';classes.mkdir();home=work/'home';home.mkdir()
            execute([JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',classes,
                *sorted((ROOT/'java/src').rglob('*.java')),ROOT/'tools/luacheck/MovementCrossingProbe.java',
                ROOT/'tools/luacheck/ExteriorBuildingProbe.java'],'compile')
            def run(name,first=None,expected=None):
                return execute([JDK/'java.exe',f'-Duser.home={home}',f'-Djava.library.path={GAME}',
                    '--enable-native-access=ALL-UNNAMED','-cp',os.pathsep.join(map(str,([first] if first else [])+[classes]))+os.pathsep+cp,
                    'ExteriorBuildingProbe'],name,expected)
            baseline=run('production');checks=re.findall(r'^CHECK ([a-z_]+)=true$',baseline,re.M)
            assert len(checks)==20 and len(set(checks))==20,checks
            source=SCANNER.read_text(encoding='utf-8-sig')
            for index,(before,after,target) in enumerate(CONTROLS):
                assert source.count(before)==1,(target,'mutation anchor drift')
                mutation=work/f'control-{index}';mutation.mkdir();java=mutation/'SAOPerceptionScanner.java'
                java.write_text(source.replace(before,after,1),encoding='utf-8')
                execute([JDK/'javac.exe','-encoding','UTF-8','-cp',str(classes)+os.pathsep+cp,'-d',mutation,java],f'compile-control-{index}')
                run(f'control-{index}',mutation,target)
            receipt.update(status='PASS',checks=len(checks),controls=len(CONTROLS))
            (output/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
            print(f'Border 227 PASS: exterior native; {len(checks)} installed checks; {len(CONTROLS)} production controls')
            return 0
    except Exception as error:
        receipt.update(status='FAIL',error=str(error));(output/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
        print('FAULT exterior native:',error);return 1

if __name__=='__main__':raise SystemExit(main())
