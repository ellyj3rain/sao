#!/usr/bin/env python3
"""Actual native perform weave scope and terminal witness controls."""
from pathlib import Path
import argparse,json,os,re,subprocess,tempfile,sys,shutil
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import d2_dance_cycle_test as fixture
from native_proof_preflight import installed_presence
HERE=Path(__file__).resolve().parent
def main():
 p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);p.add_argument('--jar',type=Path,default=fixture.ROOT/'mod/42.20/media/java/SAO.jar');p.add_argument('--baseline-only',action='store_true');a=p.parse_args()
 game,jdk,root=fixture.GAME,fixture.JDK,fixture.ROOT
 sources=[root/'java/src/com/sao/engine/SAODanceCycle.java',root/'java/src/com/sao/agent/SAODanceCycleWeave.java',root/'java/src/com/sao/agent/SAOAgent.java',root/'java/src/com/sao/bridge/SAOBridge.java']
 probe=HERE/'DanceCompletionProbe.java';helpers=[HERE/'DanceCycleProbe.java',root/'tools/luacheck/MovementCrossingProbe.java']
 jars=[a.jar.resolve(),game/'projectzomboid.jar',*sorted((game/'jars').glob('*.jar')),game/'ZombieBuddy.jar']
 assets=[game/'media/anims_X/Bob/Bob_Idle.x',fixture.LS/'anims_X/Bob_DancingDiscoSourceDefault.fbx',fixture.LS/'AnimSets/player/actions/Bob_DancingDiscoSourceDefault.xml']
 inputs=[Path(__file__),Path(fixture.__file__),root/'tools/native_proof_preflight.py',probe,*helpers,*sources,*jars,game/'stdlib.lua',*assets]
 absent=installed_presence([x for x in inputs if not x.is_relative_to(fixture.LS)],game,jdk,'D2 native dance completion')
 if absent is not None:return absent
 if any(not x.is_file()for x in assets):print('SKIPPED D2 native dance completion: installed source assets absent; native proof unchecked');return 0
 out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
 receipt={'schema':'sao-d2-native-dance-completion/1','status':'INCOMPLETE','inputsBefore':{str(x):fixture.sha(x)for x in inputs},'runs':[],'controls':[],
 'boundary':'Original native LuaTimedActionNew.perform→BaseAction.perform→Lua callback, real current off-slot actor and original imported FBX AnimationTrack.Update loop. Exact production ByteBuddy native perform weave. Controlled Lua admission/callback/loaded geometry/native queue/animation host; an explicit BaseAction hardware-fault advice throws inside original native perform to qualify onThrowable cleanup. No fabricated loop receipt or rendered-game/MP closure.'}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
 def run(name,cmd,cwd):
  r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=100);log=out/(name+'.log');log.write_bytes(r.stdout+r.stderr);receipt['runs'].append({'name':name,'exitCode':r.returncode,'log':str(log),'sha256':fixture.sha(log)});save();return r.returncode,log.read_text(errors='replace')
 try:
  with tempfile.TemporaryDirectory(prefix='sao-dance-completion-')as directory:
   work=Path(directory);shutil.copyfile(game/'stdlib.lua',work/'stdlib.lua');cp=os.pathsep.join(map(str,jars))
   code,log=run('compile',[jdk/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,*helpers,probe],work);assert code==0,log
   def execute(name,classes):return run(name,[jdk/'java.exe','-Duser.home='+str(work),'-Djava.awt.headless=true','-Djava.library.path='+str(game),'--enable-native-access=ALL-UNNAMED','-cp',str(classes)+os.pathsep+str(work)+os.pathsep+cp,'DanceCompletionProbe',game,fixture.LS],game)
   code,log=execute('baseline',work)
   assert code==0 and 'PASS native dance completion 'in log and '=false'not in log,log[-18000:];receipt['checks']=int(re.search(r'PASS native dance completion (\d+)',log)[1])
   controls=[
    ('bridge-native-readiness-omitted',sources[3],'try {return com.sao.agent.SAODanceCycleWeave.ready()&&object instanceof SAOIsoPlayerShell body','try {return object instanceof SAOIsoPlayerShell body','missing_native_hook_registration_refused'),
    ('native-entry-loop-witness-omitted',sources[0],'||!recent(binding.body.get(),binding)','||false','withdrawn_entry_restored_no_witness'),
    ('native-finally-scope-omitted',sources[1],'SAODanceCycle.exitPerform(call);',';','successful_finally_scope_cleared'),
    ('native-parent-scope-restoration-omitted',sources[0],'if(call.prior==null)PERFORM.remove();else PERFORM.set(call.prior);','PERFORM.remove();','native_parent_scope_restored'),
    ('native-completion-scope-omitted',sources[0],None,None,'outside_scope_refused'),
   ]
   for name,path,old,new,marker in ([]if a.baseline_only else controls):
    text=path.read_text(encoding='utf-8-sig')
    if old:assert text.count(old)==1,(name,text.count(old));text=text.replace(old,new,1)
    else:
     start=text.index('public static synchronized boolean completionCurrent(');end=text.index('public static synchronized boolean unregister(',start);part=text[start:end]
     for old in ['&&call!=null','&&call.binding==binding','call.action==binding.action.get()&&','&&call.sequence==sequence']:assert part.count(old)==1,(name,old);part=part.replace(old,'',1)
     text=text[:start]+part+text[end:]
    classes=out/name;classes.mkdir();mutant=classes/path.name;mutant.write_text(text,encoding='utf-8')
    code,log=run(name+'-compile',[jdk/'javac.exe','-encoding','UTF-8','-cp',str(work)+os.pathsep+cp,'-d',classes,mutant],work);assert code==0,log
    code,log=execute(name,classes);assert code!=0 and 'DANCE_COMPLETION:'+marker+'=false'in log,(name,log[-18000:]);receipt['controls'].append({'name':name,'expectedFailure':marker,'mutantSha256':fixture.sha(mutant)})
  receipt['inputsAfter']={str(x):fixture.sha(x)for x in inputs};assert receipt['inputsBefore']==receipt['inputsAfter'],'inputs changed';receipt['status']='PASS';save();print('PASS native dance completion',receipt['checks'],len(receipt['controls']));return 0
 except Exception as error:receipt['status']='FAIL';receipt['error']=str(error);save();raise
if __name__=='__main__':raise SystemExit(main())
