#!/usr/bin/env python3
"""Installed-Kahlua physical/dormant time ownership and resume admission."""
import os
import argparse
import ast
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from native_proof_preflight import installed_presence

ROOT=Path(__file__).resolve().parent.parent
TOOLS=ROOT/'tools'
LUA=ROOT/'mod/42.20/media/lua'
GAME=Path(os.environ.get("PZ_DIR", r'C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid'))
JDK=Path(os.environ.get('JDK_BIN', str(Path.home()/'Peanut Butter/JetBrains/Java/bin')))


def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--out',type=Path)
    args=parser.parse_args()
    holder=tempfile.TemporaryDirectory() if args.out is None else None
    out=Path(holder.name) if holder else args.out.resolve();out.mkdir(parents=True,exist_ok=True)
    # Reuse the established walk-rate environment without importing its CLI or
    # changing shared compilation outputs. Runtime modules remain production.
    tree=ast.parse((TOOLS/'walk_rate_test.py').read_text(encoding='utf-8'))
    values={node.targets[0].id:ast.literal_eval(node.value) for node in tree.body
        if isinstance(node,ast.Assign) and isinstance(node.targets[0],ast.Name)
        and node.targets[0].id in ('PRELUDE','MODULES')}
    modules=values['MODULES']+['shared/SAO_BodySnapshot.lua']
    files=[LUA/m for m in modules]+[Path(__file__),TOOLS/'population_resume_cases.lua',TOOLS/'walk_rate_test.py',
        TOOLS/'luacheck/LuaRun.java',GAME/'projectzomboid.jar',GAME/'stdlib.lua']
    files.append(Path(__file__).with_name('native_proof_preflight.py'))
    preflight = installed_presence(files, GAME, JDK, "population resume")
    if preflight is not None:
        raise SystemExit(preflight)
    pins={str(p):digest(p) for p in files}
    receipt={'schema':'sao.population-resume-proof/1','status':'INCOMPLETE','inputs':pins,'commands':[]}
    def save(): (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    def run(command,tag,expected=None):
        result=subprocess.run([str(v) for v in command],cwd=out,capture_output=True,text=True,timeout=90)
        log=result.stdout+result.stderr;(out/(tag+'.log')).write_text(log)
        receipt['commands'].append({'command':[str(v) for v in command],'exit':result.returncode,
            'log':tag+'.log','logSha256':digest(out/(tag+'.log')),'expectedFailure':expected});save()
        if expected:
            assert expected in log and 'VALUE PASS population resume' not in log, log
        else:assert result.returncode==0 and 'ERROR ' not in log,log
        return log
    shutil.copyfile(GAME/'stdlib.lua',out/'stdlib.lua')
    classes=out/'classes';classes.mkdir(exist_ok=True)
    run([JDK/'javac.exe','-cp',GAME/'projectzomboid.jar','-d',classes,TOOLS/'luacheck/LuaRun.java'],'compile')
    (out/'prelude.lua').write_text(values['PRELUDE'])
    texts={m:(LUA/m).read_text(encoding='utf-8') for m in modules}
    dormant='client/SAO_DormantPopulation.lua';population='client/SAO_Population.lua'
    variants=[('production',None,None,None,None),
        ('replayed-physical-hours',dormant,'if finite(rec.releasedAtHours) and rec.releasedAtHours >= 0 then','if false then',
         'represented interval replayed as dormant travel'),
        ('lost-dormant-interval',dormant,'sinceH = math.max(0, nowH - walkAt)','sinceH = 0',
         'real post-release dormant interval lost'),
        ('discard-later-walk',dormant,'math.max(walkAt or rec.releasedAtHours, rec.releasedAtHours)',
         'rec.releasedAtHours','physical boundary repeatedly spent or double counted'),
        ('movement-before-admission',population,'    local px, py = residencyPos()\n    if px then',
         '    if not pending then dormantCountyPass(conf) end\n    local px, py = residencyPos()\n    if px then',
         'dormant movement ran before native admission')]
    for tag,module,before,after,expected in variants:
        paths=[]
        for name in modules:
            source=texts[name]
            if name==module:
                assert source.count(before)==1,'mutation target differs: '+tag
                source=source.replace(before,after)
            path=out/(tag+'-'+Path(name).name);path.write_text(source,encoding='utf-8');paths.append(path)
        log=run([JDK/'java.exe','-cp',str(classes)+';'+str(GAME/'projectzomboid.jar'),'LuaRun',out/'prelude.lua',
            *paths,TOOLS/'population_resume_cases.lua','--','RESULT'],tag,expected)
        if not expected:
            assert 'VALUE PASS population resume ' in log,log
            receipt['baseline']=log[log.index('VALUE PASS population resume '):].strip()
        print('PASS '+tag)
    receipt['changedInputs']=[str(p) for p in files if digest(p)!=pins[str(p)]]
    assert not receipt['changedInputs'],'inputs changed during proof'
    receipt.update(status='PASS',defectControls=len(variants)-1);save()
    print('Receipt '+str(out/'receipt.json'))
    if holder:holder.cleanup()
    return 0


if __name__=='__main__':
    try:raise SystemExit(main())
    except Exception as error:
        print('FAIL population resume: '+str(error),file=sys.stderr);raise SystemExit(1)
