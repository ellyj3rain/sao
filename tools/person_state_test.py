"""Actual person-state export in installed Kahlua and production county calendar.

Native moodles, needs, body custody, observed room/frontier rows and source
admissions are controlled. Production traits, Conditions, Neuro, recall,
situation appraisal and exporter execute. The JSON fixture is the actual
exporter result; this is mechanical proof rather than a loaded-game trial.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import flee_continuity_test as fixture
from native_proof_preflight import installed_presence

ROOT=Path(__file__).resolve().parents[1]
FILES={name:ROOT/f'mod/42.20/media/lua/{scope}/SAO_{module}.lua' for name,scope,module in [
    ('hash','shared','Hash'),('history','shared','History'),('conditions','shared','Conditions'),
    ('disposition','shared','Disposition'),('neuro','shared','Neuro'),('memory','shared','PersonalMemory'),
    ('needs','client','Needs'),('perception','shared','Perception'),('concepts','shared','ConceptKnowledge'),
    ('awareness','shared','PersonalAwareness'),('situation','shared','SituationAppraisal'),('person','shared','PersonState')]}
FILES['cases']=ROOT/'tools/person_state_cases.lua'

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output',type=Path,default=ROOT/'_scratch/d1-person-state/verification-01')
    ap.add_argument('--baseline-only',action='store_true');args=ap.parse_args()
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
    jar=fixture.GAME/'projectzomboid.jar';package=ROOT/'mod/42.20/media/java/SAO.jar'
    runner=ROOT/'tools/luacheck/PersonStateLuaProbe.java';record=ROOT/'java/src/com/sao/engine/SAORecord.java'
    paths=[*FILES.values(),runner,record,package,Path(__file__),Path(fixture.__file__),jar,fixture.GAME/'stdlib.lua']
    paths.append(Path(__file__).with_name('native_proof_preflight.py'))
    preflight = installed_presence(paths, fixture.GAME, fixture.JDK, "person state")
    if preflight is not None:
        raise SystemExit(preflight)
    pins=lambda:{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    receipt={'schema':'sao-person-state-proof/1','status':'INCOMPLETE','inputs':pins(),'runs':[],'boundary':__doc__}
    def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    def invoke(command):
        p=subprocess.run(list(map(str,command)),cwd=out,capture_output=True,text=True,timeout=120)
        return p.returncode,p.stdout+p.stderr
    save();command=[fixture.JDK/'javac.exe','-cp',os.pathsep.join([str(jar),str(package)]),'-d',out,record,runner]
    code,log=invoke(command);(out/'compile.log').write_bytes(log.encode('utf-8'))
    receipt['compile']={'command':list(map(str,command)),'exit':code};save();assert code==0,log
    shutil.copyfile(fixture.GAME/'stdlib.lua',out/'stdlib.lua')
    (out/'prelude.lua').write_text(fixture.PRELUDE+'\nrequire=function()end\nSandboxVars={SurvivorAwareness={Neuroinflammation=true}}\nISInventoryTransferAction={derive=function()return {}end}\n',encoding='utf-8')
    original={k:p.read_text(encoding='utf-8') for k,p in FILES.items()}
    controls=[
        ('omit-weekone-source','person','audit.weekOneSource=copy(rec.weekOne.sourceEvent)',
         'audit.weekOneSource=nil','weekone_source_provenance_export'),
        ('ignore-moodle-metadata','person','receipt.status=="available" and receipt.source=="native-moodles"','true','missing_health_not_healthy'),
        ('ignore-brain-metadata','person','brain and brain.status=="available"','true','missing_brain_history_not_healthy'),
        ('expose-private-health','person','situation.psychology=nil','-- private health leaked','model_view_omits_diagnoses'),
        ('ignore-body-custody','person','local bound=ownedBody(rec,body)','local bound=true','missing_active_custody_refused'),
        ('omit-ordinary-axis','person','effective[axis]=traits[axis]','if axis~="talkativeness" then effective[axis]=traits[axis] end','actual_eight_traits'),
        ('ignore-owned-current-time','person','tick~=currentTick','false','future_query_clock_refused'),
        ('ignore-recall-age-status','memory','metadata.status=="unavailable"','false','unavailable_recall_metadata_refused'),
    ]
    for name,key,old,new,marker in [('production',None,None,None,None)]+([] if args.baseline_only else controls):
        texts=dict(original)
        if old:
            assert texts[key].count(old)==1,(name,texts[key].count(old));texts[key]=texts[key].replace(old,new,1)
        texts['cases']=texts['cases'].replace('if not value then error("PERSON_STATE:"..name)end',
            '__lastPersonStateCheck=name;if not value then error("PERSON_STATE:"..name)end')
        texts['cases']='local function runCases()\n'+texts['cases']+'\nend\nlocal ok,why=pcall(runCases);if not ok then error(tostring(why).." after PERSON_STATE:"..tostring(__lastPersonStateCheck))end\n'
        for k,value in texts.items():(out/(k+'.lua')).write_text(value,encoding='utf-8')
        command=[fixture.JDK/'java.exe','-cp',os.pathsep.join([str(jar),str(out),str(package)]),'PersonStateLuaProbe',
            'prelude.lua',*[k+'.lua' for k in FILES],'--','__result']
        code,log=invoke(command);(out/(name+'.log')).write_bytes(log.encode('utf-8'))
        receipt['runs'].append({'name':name,'command':list(map(str,command)),'exit':code,'marker':marker,
            'logSha256':hashlib.sha256((out/(name+'.log')).read_bytes()).hexdigest(),
            'mutation':{'file':key,'before':old,'after':new} if old else None});save()
        assert (code!=0 and 'PERSON_STATE:'+marker in log) if marker else (code==0 and 'PASS person state:' in log),log
        print(name+': '+next((line for line in log.splitlines() if 'VALUE ' in line or 'ERROR ' in line),log.strip()),flush=True)
    frame=out/'person-state-frame.json';data=json.loads(frame.read_text())
    assert data['context']['personState']['schema']=='sao-person-state/1'
    assert data['context']['personState']['modelView']['recall']['episodes'][0]['id']=='reading-with-friend'
    receipt['fixture']={'path':str(frame),'sha256':hashlib.sha256(frame.read_bytes()).hexdigest(),
        'producer':'SAO.PersonState.query','schema':'sao-person-state/1'}
    receipt['inputs_after']=pins();assert receipt['inputs_after']==receipt['inputs'],'source inputs changed'
    receipt['status']='PASS';save()

if __name__=='__main__':main()
