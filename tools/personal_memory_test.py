"""Source-owned autobiography, pure recall and actual Neuro in installed Kahlua.

Admissions receipts and native moodle receivers are controlled; production
PersonalMemory, Conditions, Neuro, History and compiled SAORecord execute,
including the Crossed load floor and actual county-calendar offset. Native
table serialization and module reload preserve original history. This establishes
bounded recall mechanics, not calibrated forgetting, native gameplay or mastery.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
from native_proof_preflight import installed_presence

ROOT = Path(__file__).resolve().parents[1]
GAME = Path(os.environ.get("PZ_DIR", r'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'))
JDK = Path(os.environ.get("JDK_BIN", r'C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin'))
FILES = {
    'history': ROOT/'mod/42.20/media/lua/shared/SAO_History.lua',
    'conditions': ROOT/'mod/42.20/media/lua/shared/SAO_Conditions.lua',
    'neuro': ROOT/'mod/42.20/media/lua/shared/SAO_Neuro.lua',
    'memory': ROOT/'mod/42.20/media/lua/shared/SAO_PersonalMemory.lua',
    'cases': ROOT/'tools/personal_memory_cases.lua',
}
PRELUDE = '''
SAO={};require=function()end
SandboxVars={SurvivorAwareness={Neuroinflammation=true}}
'''
RELOAD_CASES = '''
local F=__memoryFixture
F.check('reload_requires_current_source_binding',SAO.PersonalMemory.query(F.rec.id).status=='unavailable')
F.check('reload_rebinds_canonical_owner',SAO.PersonalMemory.bindInitialProvider(SAO.PopulationAdmissions,F.reader))
F.check('reload_recalls_preserved_person',SAO.PersonalMemory.query(F.rec.id).episodes[1].id=='outing-1')
F.check('reload_exact_once_attachment',SAO.PersonalMemory.attachInitial(F.rec))
__result=F.result()
'''
CONTROLS = [
    ('foreign-record', 'record(rec.id)~=rec', 'false', 'foreign_record_refused'),
    ('future-admission', 'value.admittedAtHours>now', 'false', 'future_initial_refused'),
    ('prebirth', 'year<birthYear', 'false', 'prebirth_episode_refused'),
    ('future-calendar', 'year>=1994', 'false', 'future_start_calendar_refused'),
    ('future-episode', 'acquired>cutoff', 'false', 'future_episode_refused'),
    ('leap-century', 'y%4==0 and (y%100~=0 or y%400==0)', 'y%4==0', 'invalid_century_leap'),
    ('foreign-owner', 'row.ownerId~=id', 'false', 'foreign_episode_owner_refused'),
    ('source-hash', 'value.sourceSha256~=value.definitionSha256', 'false', 'initial_source_digest_mismatch_refused'),
    ('custody', 'not equal(initial,state.initial)', 'false', 'historical_source_never_replaced'),
    ('detached-query', 'local row=copy(episode)', 'local row=episode', 'pure_query_preserves_actual_history'),
    ('aging', 'local ageDays=currentDay-date(episode.acquiredOn)', 'local ageDays=date(state.initial.startDate)-date(episode.acquiredOn)', 'county_elapsed_days_affect_recall'),
    ('ignore-neuro', 'return SAO.Neuro.clarityOf(rec)', 'return 1', 'actual_neuro_projection_affects_evidence'),
    ('crossed-absolute-threshold', 'retained>=RECALL_THRESHOLD and clarity>0', 'accessibility>=RECALL_THRESHOLD', 'crossed_retains_prior_person_episode'),
    ('zero-readiness', 'retained>=RECALL_THRESHOLD and clarity>0', 'retained>=RECALL_THRESHOLD', 'zero_native_readiness_withholds_recall'),
    ('destructive-aging', 'else inaccessible=inaccessible+1 end', 'else inaccessible=inaccessible+1;if ageDays>3650 then episode.valence=0 end end', 'aging_keeps_history'),
    ('reload-unbound', 'if not provider or issuer~=SAO.PopulationAdmissions then return false,nil end',
     'if not provider then return true,rec.personalMemory and rec.personalMemory.initial end\n    if issuer~=SAO.PopulationAdmissions then return false,nil end', 'reload_requires_current_source_binding'),
    ('ignore-health-retention', 'retention,retentionSource=factor,"conditions"', 'retention,retentionSource=1,"conditions"', 'health_condition_changes_retained_evidence'),
    ('restore-calendar-offset', 'local ageDays=currentDay-date(episode.acquiredOn)', 'local ageDays=date(state.initial.startDate)-date(episode.acquiredOn)+now/24', 'catchup_no_future_knowledge'),
    ('future-recall', 'if ageDays<0 then notYetAcquired=notYetAcquired+1', 'if false then notYetAcquired=notYetAcquired+1', 'catchup_no_future_knowledge'),
    ('omission-hidden', 'return edges,"truncated",total-#edges', 'return edges,"truncated",0', 'exact_source_relation_omissions'),
]

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output', type=Path, default=ROOT/'_scratch/d1-personal-memory/verification-01')
    ap.add_argument('--baseline-only', action='store_true')
    ap.add_argument('--variants', nargs='*')
    args=ap.parse_args()
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
    jar=GAME/'projectzomboid.jar';runner=ROOT/'tools/luacheck/PhysicalMeansLuaProbe.java'
    record=ROOT/'java/src/com/sao/engine/SAORecord.java'
    package=ROOT/'mod/42.20/media/java/SAO.jar'
    paths=[*FILES.values(),runner,record,package,Path(__file__),jar,GAME/'stdlib.lua']
    paths.append(Path(__file__).with_name('native_proof_preflight.py'))
    preflight = installed_presence(paths, GAME, JDK, "personal memory")
    if preflight is not None:
        raise SystemExit(preflight)
    def pins():return {str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    receipt={'schema':'sao.personal-memory-proof/1','status':'INCOMPLETE','inputs':pins(),
             'runs':[],'boundary':__doc__,'changedContracts':['initial source admission','person-private retained history',
             'pure recall','Neuro composition','calendar aging','modal relational evidence','native serialization/reload']}
    def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    def run(command):
        result=subprocess.run(list(map(str,command)),cwd=out,text=True,capture_output=True,timeout=120)
        return result.returncode,result.stdout+result.stderr
    save()
    # Extend the existing serialization probe only in its private generated
    # copy, exposing the actual production Java calendar method to Kahlua.
    runner_text=runner.read_text(encoding='utf-8').replace('public final class PhysicalMeansLuaProbe',
        'public final class PersonalMemoryCalendarProbe')
    marker='        try {\n            int index=0;'
    expose='''        env.rawset("__countyCalendar",(JavaFunction)(frame,count)->{
            return frame.push(com.sao.engine.SAORecord.countyInstant(
                ((Number)frame.get(0)).intValue(), ((Number)frame.get(1)).intValue(),
                ((Number)frame.get(2)).intValue(), ((Number)frame.get(3)).doubleValue(),
                ((Number)frame.get(4)).intValue()));
        });
'''
    assert runner_text.count(marker)==1
    runner_text=runner_text.replace(marker,expose+marker)
    private_runner=out/'PersonalMemoryCalendarProbe.java';private_runner.write_text(runner_text,encoding='utf-8')
    code,log=run([JDK/'javac.exe','-cp',os.pathsep.join([str(jar),str(package)]),'-d',out,record,private_runner])
    (out/'compile.log').write_bytes(log.encode('utf-8'));assert code==0,log
    shutil.copyfile(GAME/'stdlib.lua',out/'stdlib.lua')
    (out/'prelude.lua').write_text(PRELUDE,encoding='utf-8')
    (out/'reload_cases.lua').write_text(RELOAD_CASES,encoding='utf-8')
    originals={key:p.read_text(encoding='utf-8') for key,p in FILES.items()}
    controls=[] if args.baseline_only else [v for v in CONTROLS if not args.variants or v[0] in args.variants]
    for name,old,new,marker in [('production',None,None,None),*controls]:
        sources=dict(originals)
        if old:
            assert sources['memory'].count(old)==1,(name,sources['memory'].count(old))
            sources['memory']=sources['memory'].replace(old,new)
        for owner,source in sources.items():(out/(owner+'.lua')).write_text(source,encoding='utf-8')
        command=[JDK/'java.exe','-cp',os.pathsep.join([str(jar),str(out),str(package)]),'PersonalMemoryCalendarProbe',
                 'prelude.lua','history.lua','conditions.lua','neuro.lua','memory.lua','cases.lua','memory.lua','reload_cases.lua','--','__result']
        code,log=run(command);log_path=out/(name+'.log');log_path.write_bytes(log.encode('utf-8'))
        receipt['runs'].append({'name':name,'exitCode':code,'command':list(map(str,command)),
            'log':log_path.name,'logSha256':hashlib.sha256(log.encode()).hexdigest(),'marker':marker})
        save()
        if marker:assert code!=0 and 'PERSONAL_MEMORY:'+marker in log,log
        else:assert code==0 and 'PASS personal memory:' in log,log
        print(name+': '+next((line for line in log.splitlines() if 'VALUE ' in line or 'ERROR ' in line),log.strip()),flush=True)
    assert receipt['inputs']==pins(),'relevant source inputs changed'
    receipt['status']='PASS';save()

if __name__=='__main__':
    try:main()
    except Exception as error:
        print('FAIL personal memory: '+str(error),file=sys.stderr)
        raise SystemExit(1)
