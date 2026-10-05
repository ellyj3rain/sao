"""Decision-time PersonState capture with actual installed Lua owners and native table serialization."""
from pathlib import Path
import argparse,hashlib,json,os,shutil,subprocess
import person_state_test as owners
import flee_continuity_test as fixture
from native_proof_preflight import installed_presence
ROOT=Path(__file__).resolve().parents[1]
FILES=dict(owners.FILES)
FILES.pop('cases')
FILES.update(models=ROOT/'mod/42.20/media/lua/shared/SAO_CognitiveModels.lua',cognition=ROOT/'mod/42.20/media/lua/shared/SAO_Cognition.lua')
FILES['cases']=ROOT/'tools/person_state_cases.lua'
FILES['decision_cases']=ROOT/'tools/decision_person_state_cases.lua'
def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--output',type=Path,required=True);ap.add_argument('--baseline-only',action='store_true');args=ap.parse_args()
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
    jar=fixture.GAME/'projectzomboid.jar';package=ROOT/'mod/42.20/media/java/SAO.jar'
    runner=ROOT/'tools/luacheck/DecisionPersonStateLuaProbe.java';record=ROOT/'java/src/com/sao/engine/SAORecord.java'
    paths=[*FILES.values(),runner,record,package,Path(__file__),Path(owners.__file__),Path(fixture.__file__),jar,fixture.GAME/'stdlib.lua']
    paths.append(Path(__file__).with_name('native_proof_preflight.py'))
    preflight = installed_presence(paths, fixture.GAME, fixture.JDK, "decision person state")
    if preflight is not None:
        raise SystemExit(preflight)
    pins=lambda:{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    receipt={'schema':'sao-decision-person-state-proof/1','status':'INCOMPLETE','inputs':pins(),'runs':[],'boundary':__doc__}
    def save():(out/'receipt.json').write_bytes((json.dumps(receipt,indent=2)+'\n').encode('utf8'))
    def invoke(command):
        p=subprocess.run(list(map(str,command)),cwd=out,capture_output=True,text=True,timeout=120);return p.returncode,p.stdout+p.stderr
    save();command=[fixture.JDK/'javac.exe','-cp',os.pathsep.join(map(str,[jar,package])),'-d',out,record,runner]
    code,log=invoke(command);(out/'compile.log').write_bytes(log.encode('utf8'));receipt['compile']={'command':list(map(str,command)),'exit':code};save();assert code==0,log
    shutil.copyfile(fixture.GAME/'stdlib.lua',out/'stdlib.lua')
    (out/'prelude.lua').write_bytes((fixture.PRELUDE+'\nrequire=function()end\nlocal stores={}\nModData={get=function(k)return stores[k]end,getOrCreate=function(k)stores[k]=stores[k]or{};return stores[k]end}\nSandboxVars={SurvivorAwareness={Neuroinflammation=true}}\nISInventoryTransferAction={derive=function()return {}end}\n').encode('utf8'))
    original={k:p.read_text(encoding='utf-8-sig') for k,p in FILES.items()}
    controls=[
        ('capture-after-proposals','    local frozenPersonState = decisionPersonState(id,frame,now)','    local frozenPersonState','capture_before_proposal',True),
        ('shallow-capture','local frozen=detachedPersonState(value)','local frozen=value','preproposal_deep_freeze',False),
        ('ignore-frame-hour','if frame.worldHours~=now then','if false then','historic_frame_no_later_state',False),
        ('ignore-owner-actor','value.actorId~=id','false','foreign_query_metadata_refused',False),
        ('omit-snapshot-sidecar','out.decisionPersonState=detachedPersonState(value.decisionPersonState)','out.decisionPersonState=nil','actual_snapshot_available',False),
        ('ignore-clock-change','if current~=now or not tickOk or currentTick~=tick then','if false then','clock_changed_during_query_refused',False),
        ('allow-compact-overflow','if not removed then return nil end','if not removed then break end','compact_oversized_state_explicit_refusal',False),
    ]
    for name,old,new,marker,after in [('production',None,None,None,False)]+([] if args.baseline_only else controls):
        texts=dict(original)
        if old:
            assert texts['cognition'].count(old)==1,(name,texts['cognition'].count(old));texts['cognition']=texts['cognition'].replace(old,new,1)
            if after:texts['cognition']=texts['cognition'].replace('    local allocation = s.allocation','    frozenPersonState = decisionPersonState(id,frame,now)\n    local allocation = s.allocation',1)
        texts['cases']=texts['cases']+'\n'+texts.pop('decision_cases')
        texts['cases']=texts['cases'].replace('if not value then error("DECISION_STATE:"..name)end','__lastDecisionCheck=name;if not value then error("DECISION_STATE:"..name)end')
        texts['cases']='local function runCases()\n'+texts['cases']+'\nend\nlocal ok,why=pcall(runCases);if not ok then error(tostring(why).." after DECISION_STATE:"..tostring(__lastDecisionCheck))end\n'
        for key,value in texts.items():(out/(key+'.lua')).write_bytes(value.encode('utf8'))
        command=[fixture.JDK/'java.exe','-cp',os.pathsep.join(map(str,[jar,out,package])),'DecisionPersonStateLuaProbe','prelude.lua',*[key+'.lua' for key in texts],'--','__result']
        code,log=invoke(command);logpath=out/(name+'.log');logpath.write_bytes(log.encode('utf8'))
        receipt['runs'].append({'name':name,'command':list(map(str,command)),'exit':code,'marker':marker,'logSha256':hashlib.sha256(logpath.read_bytes()).hexdigest(),'mutation':{'file':'cognition','before':old,'after':new,'afterProposals':after} if old else None});save()
        assert (code!=0 and 'DECISION_STATE:'+marker in log) if marker else (code==0 and 'PASS decision person state:' in log),log
        if name=='production':shutil.copyfile(out/'person-state-frame.json',out/'decision-person-state-frame.json')
        print(name+': '+next((line for line in log.splitlines() if 'VALUE ' in line or 'ERROR ' in line),log.strip()),flush=True)
    frame=out/'decision-person-state-frame.json';value=json.loads(frame.read_bytes());side=value['context']['cognition']['episodes'][0]['decisionPersonState']
    assert side['status']=='available' and side['personState']==value['context']['personState']
    receipt['fixture']={'path':str(frame),'sha256':hashlib.sha256(frame.read_bytes()).hexdigest(),'producer':'SAO.Cognition.choose -> SAO.Cognition.snapshot','schema':'sao-person-decision-state/1'}
    receipt['inputs_after']=pins();assert receipt['inputs_after']==receipt['inputs'],'source inputs changed';receipt['status']='PASS';save()
if __name__=='__main__':main()
