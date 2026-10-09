#!/usr/bin/env python3
"""Native reading Lua, owned outcome/model join and installed Kahlua persistence.

Body, queue, job delta and ReadLiterature receiver are controlled. Installed
ISReadABook and production Study/Needs/Planning/Cognition/Models execute unchanged.
Immediate completion mood is measured, not calibrated psychology or world proof.
"""
from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,sys
sys.dont_write_bytecode=True
import study_test as fixture
from native_proof_preflight import installed_presence
ROOT=Path(__file__).resolve().parents[1]
LUA=ROOT/'mod/42.20/media/lua'
FILES={k:LUA/f for k,f in {
    'needs':'client/SAO_Needs.lua','plan':'shared/SAO_ProceduralPlanning.lua',
    'study':'client/SAO_Study.lua','models':'shared/SAO_CognitiveModels.lua','cognition':'shared/SAO_Cognition.lua'}.items()}
CASES=ROOT/'tools/d2_reading_experience/cases.lua'
RUNNER=ROOT/'tools/luacheck/PhysicalMeansLuaProbe.java'
CONTROLS=[
    ('omit-owner-outcome','study','    recordLeisureOutcome(person, work, action, valid)','    -- terminal owner omitted','partial_pages_are_attempted_not_completed'),
    ('partial-success','cognition','x.succeeded, x.stats = r.status == "completed", detached(r.mood)','x.succeeded, x.stats = true, detached(r.mood)','partial_attempt_changes_actual_comparison'),
    ('generic-authority','cognition',' or supplied.kind=="leisure-reading"','','generic_authority_refused'),
    ('forget-reading-evidence','models','        retain("recreate", "leisure", e.succeeded)\n        for name','        -- exact reading evidence omitted\n        for name','partial_attempt_changes_actual_comparison'),
    ('ignore-custody','cognition','or not r.custodyVerified or r.progress <= 0','or false or r.progress <= 0','refuses_no_custody'),
    ('ignore-time','cognition','or not finite(r.beganAt, 0, r.atHours) or not finite(r.progress, 0, 1)','or false or not finite(r.progress, 0, 1)','refuses_stale_time'),
    ('ignore-pages','cognition','or not note and r.totalPages > 0 and (r.pagesAfter <= r.pagesBefore or r.pagesAfter < r.totalPages)','or false','refuses_partial_completed_pages'),
    ('ignore-mood-binding','cognition','r.moodMeasurement ~= "immediate-native-completion"','false','refuses_unmeasured_mood'),
    ('drop-mood-evidence','models','for name, v in pairs(e.stats or {}) do retain("reading-relief", "leisure", v.after < v.before, name) end','-- measured mood evidence omitted','measured_relief_changes_actual_comparison'),
    ('forget-reload-outcome','study','        recordLeisureOutcome(person, work, nil, false)','        -- absent-runtime outcome omitted','runtime_reload_closes_attempt'),
]
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True);parser.add_argument('--baseline-only',action='store_true');args=parser.parse_args()
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
    native=[fixture.GAME/'media/lua/shared/ISBaseObject.lua',fixture.GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua',
        fixture.GAME/'media/lua/client/TimedActions/ISInventoryTransferAction.lua',fixture.GAME/'media/lua/shared/TimedActions/ISReadABook.lua']
    jar=fixture.GAME/'projectzomboid.jar'
    inputs=[Path(__file__),Path(fixture.__file__),CASES,RUNNER,jar,fixture.GAME/'stdlib.lua',*native,*FILES.values(),ROOT/'tools/native_proof_preflight.py']
    preflight=installed_presence(inputs,fixture.GAME,fixture.JDK,'D2 reading experience')
    if preflight is not None:return preflight
    sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
    pins={str(p):sha(p) for p in inputs}
    receipt={'schema':'d2-reading-experience/1','status':'INCOMPLETE','inputsBefore':pins,'runs':[],'boundary':__doc__}
    def seal(): (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    def invoke(label,command):
        done=subprocess.run(list(map(str,command)),cwd=out,capture_output=True,timeout=90)
        log=out/(label+'.log');log.write_bytes(done.stdout+done.stderr)
        receipt['runs'].append({'name':label,'exitCode':done.returncode,'log':str(log),'logSha256':sha(log)});seal()
        return done.returncode,log.read_text(encoding='utf-8',errors='replace')
    seal()
    try:
        code,log=invoke('compile',[fixture.JDK/'javac.exe','-cp',jar,'-d',out,RUNNER]);assert code==0,log
        shutil.copyfile(fixture.GAME/'stdlib.lua',out/'stdlib.lua')
        prelude=fixture.PRELUDE+'''
__stores={}
ModData={get=function(key)return __stores[key]end,getOrCreate=function(key)__stores[key]=__stores[key] or {};return __stores[key]end}
SAO.Labor={capabilityOf=function()return {}end}
SAO.Hash.unit=function()return .5 end
'''
        (out/'prelude.lua').write_text(prelude,encoding='utf-8')
        source={k:p.read_text(encoding='utf-8-sig') for k,p in FILES.items()}
        variants=[('production',None,None,None,None)]+([] if args.baseline_only else CONTROLS)
        for label,target,before,after,marker in variants:
            work=out/label;work.mkdir();text=dict(source)
            if target:
                assert text[target].count(before)==1,(label,text[target].count(before));text[target]=text[target].replace(before,after,1)
            paths=[out/'prelude.lua',*native]
            for key in ('needs','plan','study','models','cognition'):
                p=work/(key+'.lua');p.write_text(text[key],encoding='utf-8');paths.append(p)
            # Reloads the same unchanged Study owner through the installed VM.
            p=work/'reload-owner.lua';p.write_text('__reloadStudy=function()\n'+text['study']+'\nend\n',encoding='utf-8');paths.append(p)
            paths.append(CASES)
            code,log=invoke(label,[fixture.JDK/'java.exe','-cp',str(out)+os.pathsep+str(jar),'PhysicalMeansLuaProbe',*paths,'--','__result'])
            if marker:assert code!=0 and 'D2_READING:'+marker in log,(label,log[-4000:])
            else:
                assert code==0 and 'PASS D2 reading experience ' in log,log[-5000:]
                receipt['checks']=int(re.search(r'PASS D2 reading experience (\d+)',log).group(1))
                assert receipt['checks']==49,('incomplete reading contract',receipt['checks'])
            print(label+': '+('expected refusal' if marker else 'PASS'),flush=True)
        receipt['inputsAfter']={str(p):sha(p) for p in inputs};assert receipt['inputsBefore']==receipt['inputsAfter'],'changed inputs'
        receipt['status']='PASS';receipt['controls']=len(variants)-1;seal();print('PASS reading experience',receipt['checks'],'checks',receipt['controls'],'controls');return 0
    except Exception as error:
        receipt['failure']=str(error);seal();print('FAIL',error);return 1
if __name__=='__main__':raise SystemExit(main())
