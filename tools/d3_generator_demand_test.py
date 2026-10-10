#!/usr/bin/env python3
"""D3.6 reached cooking demand and private utility experience in installed Kahlua.

Cooking bodies, source readers and thermal receivers are controlled; separate
native generator probes establish material expenditure and consumer power.
"""
from pathlib import Path
from hashlib import sha256
import argparse, json, os, re, shutil, subprocess, tempfile

ROOT=Path(__file__).resolve().parents[1]
GAME=Path(os.environ.get('PZ_DIR',r'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'))
JDK=Path(os.environ.get('JDK_BIN',r'C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin'))
LUA=ROOT/'mod/42.20/media/lua'
MODELS=LUA/'shared/SAO_CognitiveModels.lua'
COOKING=LUA/'client/SAO_Cooking.lua'
COGNITION=LUA/'shared/SAO_Cognition.lua'
CASES=ROOT/'tools/luacheck/d3_generator_demand_cases.lua'
RUNNER=ROOT/'tools/luacheck/LuaRun.java'

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out',type=Path); parser.add_argument('--required',action='store_true')
    args=parser.parse_args()
    owned=[Path(__file__),MODELS,COOKING,COGNITION,CASES,RUNNER,ROOT/'tools/cooking_checks/prelude.lua']
    missing=[str(p) for p in owned if not p.is_file()]
    if missing: print('FAIL mandatory owned inputs absent: '+', '.join(missing)); return 1
    native=[GAME/p for p in ['projectzomboid.jar','stdlib.lua','media/lua/shared/ISBaseObject.lua',
        'media/lua/shared/TimedActions/ISBaseTimedAction.lua','media/lua/shared/TimedActions/ISToggleStoveAction.lua']]
    missing=[str(p) for p in native+[JDK/'java.exe',JDK/'javac.exe'] if not p.is_file()]
    if missing:
        print(('FAIL required' if args.required else 'UNCHECKED')+' installed runtime absent: '+', '.join(missing))
        return int(args.required)
    temporary=tempfile.TemporaryDirectory(prefix='sao-generator-demand-') if args.out is None else None
    out=Path(temporary.name)/'proof' if temporary else args.out.resolve()
    if out.exists(): raise ValueError('refuse replacing retained evidence')
    out.mkdir(parents=True); classes=out/'classes'; classes.mkdir()
    pins={str(p):sha256(p.read_bytes()).hexdigest() for p in owned+native}
    shutil.copy2(GAME/'stdlib.lua',out/'stdlib.lua')
    compiled=subprocess.run([str(JDK/'javac.exe'),'-cp',str(native[0]),'-d',str(classes),str(RUNNER)],capture_output=True,text=True)
    (out/'compile.log').write_text(compiled.stdout+compiled.stderr)
    if compiled.returncode: print(compiled.stderr); return 1
    sources={p:p.read_text(encoding='utf-8-sig') for p in [MODELS,COGNITION,COOKING]}
    runs=[]
    def execute(label,changes=()):
        changed=dict(sources)
        for path,before,after in changes:
            assert changed[path].count(before)==1,(label,before)
            changed[path]=changed[path].replace(before,after,1)
        paths=[]
        for path,text in changed.items():
            target=out/(label+'-'+path.name); target.write_text(text,encoding='utf-8'); paths.append(target)
        command=[str(JDK/'java.exe'),'-cp',str(classes)+os.pathsep+str(native[0]),'LuaRun',
            str(owned[-1]),*[str(p) for p in native[2:]],*[str(p) for p in paths],str(CASES),'--','__generatorDemandResults']
        result=subprocess.run(command,cwd=out,capture_output=True,text=True,timeout=60)
        (out/(label+'.log')).write_text(result.stdout+result.stderr)
        checks=dict(re.findall(r'^([a-z0-9_]+)=(true|false)$',result.stdout.replace('VALUE ',''),re.M))
        assert result.returncode==0 and len(checks)==44,(label,result.returncode,len(checks),result.stdout[-2500:])
        runs.append({'name':label,'exit':result.returncode,'checks':checks})
        return checks
    try:
        checks=execute('candidate'); assert all(v=='true' for v in checks.values()),checks
        controls=[('omit-consumer-bound',MODELS,'not text(e.consumerId,160)','not text(e.consumerId,256)','model_rejects_consumer_bound_inspect'),
            ('omit-predeposit-refusal',COOKING,'if state.kind == "stove" and state.powered == false then','if false then','unpowered_before_deposit_preserves_food'),
            ('omit-supplier-coverage',COGNITION,'receipt.sourceCovered~=true or receipt.consumerPowered~=true','receipt.consumerPowered~=true','activation_without_coverage_cannot_teach_power')]
        for label,path,before,after,target in controls:
            assert execute(label,[(path,before,after)])[target]=='false',(label,target)
        assert pins=={str(p):sha256(p.read_bytes()).hexdigest() for p in owned+native}
        receipt={'status':'PASS','cases':44,'controls':len(controls),'inputs':pins,'runs':runs,'boundary':__doc__}
        (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
        print('PASS generator demand/models/cognition: 44 cases, 3 executed controls'); return 0
    except (AssertionError,RuntimeError) as error:
        (out/'receipt.json').write_text(json.dumps({'status':'FAIL','error':str(error),'inputs':pins,'runs':runs},indent=2)+'\n')
        print('FAIL',error); return 1

if __name__=='__main__': raise SystemExit(main())
