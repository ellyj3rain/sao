#!/usr/bin/env python3
"""D2 instrument receipt -> independent private models on installed Kahlua.

The canonical Gesture query is a controlled receiver; this proof does not
establish native instrument execution, heard participation or rendered play.
Optional Controller coverage executes its actual rest dispatcher with
controlled material eligibility and admission receivers. The separate native
leisure-choice proof owns actual item eligibility. Restored defects stay private.
"""
from pathlib import Path
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
import shutil
import subprocess
import sys
sys.dont_write_bytecode = True
import flee_continuity_test as fixture
from native_proof_preflight import installed_presence

ROOT=Path(__file__).resolve().parents[1]
LUA=ROOT/'mod/42.20/media/lua'
FILES={'cognition':LUA/'shared/SAO_Cognition.lua','models':LUA/'shared/SAO_CognitiveModels.lua'}
CASES=ROOT/'tools/d2_instrument_cognition_cases.lua'
RELOAD=ROOT/'tools/d2_instrument_cognition_reload.lua'
RUNNER=ROOT/'tools/luacheck/PhysicalMeansLuaProbe.java'

def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,default=ROOT/'_scratch/d2-meaningful-leisure/cognition-checks')
    parser.add_argument('--controller',action='store_true')
    parser.add_argument('--baseline-only',action='store_true')
    args=parser.parse_args(argv)
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
    jar=fixture.GAME/'projectzomboid.jar'
    inputs=[*FILES.values(),CASES,RELOAD,RUNNER,Path(__file__),Path(fixture.__file__),fixture.GAME/'stdlib.lua',jar]
    if args.controller:inputs.append(fixture.CONTROLLER)
    inputs.append(Path(__file__).with_name('native_proof_preflight.py'))
    preflight = installed_presence(inputs, fixture.GAME, fixture.JDK, "d2 instrument cognition")
    if preflight is not None:
        raise SystemExit(preflight)
    pins={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
    receipt={'schema':'d2-instrument-cognition/1','status':'INCOMPLETE','atUtc':datetime.now(timezone.utc).isoformat(),
             'inputs':pins,'controller':args.controller,'variants':[],'boundary':__doc__}
    def seal(): (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    def invoke(command):
        done=subprocess.run(list(map(str,command)),cwd=out,capture_output=True,text=True,encoding='utf-8',timeout=120)
        return done.returncode,done.stdout+done.stderr
    seal()
    code,log=invoke([fixture.JDK/'javac.exe','-cp',jar,'-d',out,RUNNER]);(out/'compile.log').write_text(log,encoding='utf-8');assert code==0,log
    shutil.copy2(fixture.GAME/'stdlib.lua',out/'stdlib.lua')
    sources={k:p.read_text(encoding='utf-8-sig') for k,p in FILES.items()}
    if args.controller:sources['controller']=fixture.CONTROLLER.read_text(encoding='utf-8-sig')
    prelude=(fixture.PRELUDE if args.controller else (ROOT/'tools/cognition_checks/prelude.lua').read_text())
    prelude+='\nrequire=function()end\nISInventoryTransferAction={derive=function()return {}end}\n'
    if args.controller:
        prelude+='\nstores={}\nModData={get=function(k)return stores[k]end,getOrCreate=function(k)stores[k]=stores[k] or {};return stores[k]end}\n'
    (out/'prelude.lua').write_text(prelude,encoding='utf-8')
    controls=[
      ('interrupted-sound-credit','cognition','x.actionKind,x.succeeded=receipt.verb,receipt.status=="completed"',
       'x.actionKind,x.succeeded=receipt.verb,receipt.soundEmitted and receipt.worldSoundEmitted','partial_sound_not_success'),
      ('generic-authority','cognition',' or supplied.kind=="instrument-use")',')','generic_authority_refused'),
      ('canonical-actor','cognition','receipt.actorId~=id or receipt.sequence~=sequence','false or receipt.sequence~=sequence','refuses_foreign_actor'),
      ('canonical-work','cognition','receipt.workId~="instrument:"..id..":"..tostring(sequence)','false','refuses_missing_work'),
      ('known-generation-token','cognition','or receipt.bodyGenerationKnown and not text(receipt.bodyToken,160)','or false','refuses_missing_body'),
      ('unknown-generation-token','cognition','or not receipt.bodyGenerationKnown and receipt.bodyToken~=nil','or false','refuses_unknown_with_token'),
      ('model-item-integer','models','and type(e.succeeded)=="boolean" and text(e.itemType,160)\n                and finite(e.itemId) and e.itemId==math.floor(e.itemId)',
       'and type(e.succeeded)=="boolean" and text(e.itemType,160)\n                and finite(e.itemId)','model_refuses_fractional_item'),
      ('physical-sound','cognition','if receipt.status=="completed" and (','if false and (','refuses_completed_without_sound'),
      ('cursor-replay','cognition','if prior and position <= prior then','if false then','duplicate_no_relearning'),
      ('evicted-cursor','cognition','if prior and position <= prior then','if prior and position <= prior and #s.experiences < MAX_EXPERIENCES then','evicted_cursor_refuses_replay'),
      ('model-position','models','if previousPosition and position<=previousPosition then','if false then','model_cursor_refuses_replay'),
      ('model-exact-source','models','and e.sourceId=="native:sound:BlowHarmonica" and e.actionKind=="blow-harmonica"','and true and e.actionKind=="blow-harmonica"','model_refuses_wrong_source'),
      ('model-negative','models','retain("recreate", "leisure", e.succeeded)','retain("recreate", "leisure", true)','failed_attempt_counterevidence'),
      ('model-forgets-sound','models','elseif e.kind == "instrument-use" then retain("recreate", "leisure", e.succeeded)','elseif e.kind == "instrument-use" then -- sound evidence dropped','shared_sound_expectation_changes_choice'),
      ('plan-source-forgery','models','c.category ~= "leisure" or c.sourceId ~= "native:sound:BlowHarmonica"','c.category ~= "leisure" or false','forged_plan_source_refused'),
      ('category-leak','models','if e.category=="leisure" and e.kind~="instrument-use" then return false end','-- restored category leak','legacy_cannot_claim_leisure'),
      ('unsupported-fields','models','if not plainKeys(e, EVENT_KEYS) or not text(e.id,128)','if not text(e.id,128)','model_refuses_unsupported_mastery'),
    ]
    if args.controller:
        controls += [('adoption-reconciliation','controller',
          'SAO.ProceduralPlanning.reconcileInstrument(rec.id,\n                "loaded instrument owner was absent at adoption; prior outcome is unobserved")',
          '-- instrument adoption reconciliation omitted','adoption_reconciles_absent_owner')]
    variants=[('production',None,None,None,None)]+([] if args.baseline_only else controls)
    for name,target,before,after,marker in variants:
        work=out/name;work.mkdir(exist_ok=True)
        texts=dict(sources)
        if target:
            assert texts[target].count(before)==1,(name,texts[target].count(before))
            texts[target]=texts[target].replace(before,after,1)
        paths=[out/'prelude.lua']
        for key in ['models','cognition']:
            path=work/(key+'.lua');path.write_text(texts[key],encoding='utf-8');paths.append(path)
        if args.controller:
            controller=texts['controller']
            assert controller.count('return Ctl\n')==1
            path=work/'controller.lua';path.write_text(controller.replace('return Ctl\n','Ctl.__d2Rest=decideRestActivity\nreturn Ctl\n'),encoding='utf-8');paths.append(path)
        paths.append(CASES)
        code,log=invoke([fixture.JDK/'java.exe','-cp',os.pathsep.join([str(jar),str(out)]),'PhysicalMeansLuaProbe',*paths,'--','__result'])
        logpath=work/'run.log';logpath.write_text(log,encoding='utf-8')
        receipt['variants'].append({'name':name,'exit':code,'marker':marker,'log':str(logpath),'logSha256':hashlib.sha256(logpath.read_bytes()).hexdigest()});seal()
        if marker:assert code!=0 and 'D2_INSTRUMENT:'+marker in log,(name,log)
        else:assert code==0 and 'PASS D2 instrument cognition' in log,log
        verdict=next((line for line in log.splitlines() if line.startswith(('VALUE ','ERROR '))),log.strip().splitlines()[-1])
        print(name+': '+verdict,flush=True)
    production=out/'production'
    paths=[out/'prelude.lua',production/'models.lua',production/'cognition.lua']
    if args.controller:paths.append(production/'controller.lua')
    paths += [CASES,production/'models.lua',production/'cognition.lua',RELOAD]
    code,log=invoke([fixture.JDK/'java.exe','-cp',os.pathsep.join([str(jar),str(out)]),'PhysicalMeansLuaProbe',*paths,'--','__result'])
    path=out/'module-reload.log';path.write_text(log,encoding='utf-8')
    receipt['moduleReload']={'exit':code,'log':str(path),'logSha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    assert code==0 and 'PASS D2 instrument cognition module reload 3' in log,log
    stable={p:hashlib.sha256(Path(p).read_bytes()).hexdigest()==pin for p,pin in pins.items()}
    receipt['inputStability']=stable
    assert all(stable.values()),stable
    receipt['status']='PASS';seal();print('PASS D2 instrument cognition receipt '+str(out/'receipt.json'))
    return 0

if __name__=='__main__':
    try:raise SystemExit(main())
    except Exception as error:
        print('FAIL D2 instrument cognition: '+str(error),file=sys.stderr)
        raise SystemExit(1)
