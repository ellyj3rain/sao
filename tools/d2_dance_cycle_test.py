#!/usr/bin/env python3
"""Actual installed animation importer/AnimationTrack.Update qualification."""
from pathlib import Path
import argparse,hashlib,json,os,re,subprocess,tempfile,sys,shutil
from native_proof_preflight import installed_presence
ROOT=Path(__file__).resolve().parents[1]
GAME=Path(os.environ.get('PZ_DIR','C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid'))
JDK=Path(os.environ.get('JDK_BIN','C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin'))
LS=Path(os.environ.get('SAO_LIFESTYLE_MEDIA','C:/Program Files (x86)/Steam/steamapps/workshop/content/108600/3403870858/mods/Lifestyle/common/media'))
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);p.add_argument('--jar',type=Path,default=ROOT/'mod/42.20/media/java/SAO.jar');p.add_argument('--baseline-only',action='store_true');a=p.parse_args()
 fixture=ROOT/'tools/d2_dance_cycle/DanceCycleProbe.java';helper=ROOT/'tools/luacheck/MovementCrossingProbe.java';source=ROOT/'java/src/com/sao/engine/SAODanceCycle.java'
 jars=[a.jar.resolve(),GAME/'projectzomboid.jar',*sorted((GAME/'jars').glob('*.jar')),GAME/'ZombieBuddy.jar']
 assets=[GAME/'media/anims_X/Bob/Bob_Idle.x']+[LS/suffix for name in ['Bob_DancingDiscoSourceDefault','Bob_DancingDiscoTargetDefault']for suffix in ['anims_X/'+name+'.fbx','AnimSets/player/actions/'+name+'.xml']]
 inputs=[Path(__file__),ROOT/'tools/native_proof_preflight.py',fixture,helper,source,*jars,GAME/'stdlib.lua',*assets]
 # Workshop assets are installed dependencies even though outside the engine root.
 absent=installed_presence([f for f in inputs if f not in assets or f.is_relative_to(GAME)],GAME,JDK,'D2 native dance cycle')
 if absent is not None:return absent
 if any(not f.is_file() for f in assets):print('SKIPPED D2 native dance cycle: installed animation assets absent; native proof unchecked');return 0
 out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
 receipt={'schema':'sao-d2-native-dance-cycle/1','status':'INCOMPLETE','inputsBefore':{str(f):sha(f)for f in inputs},'runs':[],'controls':[],
 'boundary':'Actual installed FBX Jassimp/ImportedSkeleton clips, XML settings, off-slot native body/BaseAction/current native AnimationPlayer/MultiTrack/AnimationTrack.Update producer. Controlled loaded geometry, direct native queue/variable setup, private headless animator skinning host and Lua admission guard host; expiry changes only timestamp on actual receipt. No rendered/hardware/full dance consent producer/Lua mastery/MP closure.'}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
 def run(name,cmd,cwd):
  r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=100);log=out/(name+'.log');log.write_bytes(r.stdout+r.stderr);receipt['runs'].append({'name':name,'exitCode':r.returncode,'log':str(log),'sha256':sha(log)});save();return r.returncode,log.read_text(errors='replace')
 try:
  with tempfile.TemporaryDirectory(prefix='sao-dance-cycle-')as directory:
   work=Path(directory);shutil.copyfile(GAME/'stdlib.lua',work/'stdlib.lua');cp=os.pathsep.join(map(str,jars))
   code,log=run('compile',[JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,helper,fixture],work);assert code==0,log
   def execute(name,classes):return run(name,[JDK/'java.exe','-Duser.home='+str(work),'-Djava.awt.headless=true','-Djava.library.path='+str(GAME),'--enable-native-access=ALL-UNNAMED','-cp',str(classes)+os.pathsep+str(work)+os.pathsep+cp,'DanceCycleProbe',GAME,LS],GAME)
   code,log=execute('baseline',work);assert code==0 and 'PASS native dance cycle 'in log,log[-12000:];receipt['checks']=int(re.search(r'PASS native dance cycle (\d+)',log)[1])
   controls=[
    ('native-update-omitted','fixture','t.Update(t.getDuration()/t.getSpeedDelta()+.01f);','t.Update(0);','native_Update_receipt'),
    ('native-started-omitted','source','action.isStarted()','true','unstarted_current_action_refused'),
    ('current-action-omitted','source','body.checkCurrentAction(current->current==action)','true','removed_current_action_no_receipt'),
    ('source-emission-guard-omitted','source','||!current(body,this)','||false','withdrawn_emission_then_restored_no_receipt'),
    ('token-custody-omitted','source','Objects.equals(binding.token,body.getModData().rawget("SAOExternalToken"))','true','token_replacement_no_receipt'),
    ('clip-custody-omitted','source','binding.clip.equals(body.getVariableString("PerformingAction"))','true','changed_action_clip_no_receipt'),
    ('unique-track-omitted','source','return matching==1;','return true;','ambiguous_track_no_receipt'),
    ('native-expiry-omitted','source','<=5_000_000_000L','<=Long.MAX_VALUE','expired_native_receipt'),
    ('native-clock-omitted','source','getWorldAgeHours()>=binding.engineAtHours','getWorldAgeHours()>=Double.NEGATIVE_INFINITY','backwards_native_clock_refused'),
    ('event-sequence-omitted','source','binding.sequence==sequence','true','new_loop_rejects_old_sequence'),
    ('tokenless-stringified','source','row.rawset("bodyToken",binding.token)','row.rawset("bodyToken",String.valueOf(binding.token))','tokenless_native_receipt_exact_nil'),
   ]
   for name,kind,old,new,marker in ([]if a.baseline_only else controls):
    text=(fixture if kind=='fixture'else source).read_text(encoding='utf-8-sig');assert text.count(old)==1,(name,text.count(old));text=text.replace(old,new,1)
    classes=out/name;classes.mkdir();mutant=classes/('DanceCycleProbe.java'if kind=='fixture'else 'SAODanceCycle.java');mutant.write_text(text,encoding='utf-8')
    code,log=run(name+'-compile',[JDK/'javac.exe','-encoding','UTF-8','-cp',str(work)+os.pathsep+cp,'-d',classes,mutant],work);assert code==0,log
    code,log=execute(name,classes);assert code!=0 and 'DANCE_CYCLE:'+marker+'=false'in log,(name,log[-10000:]);receipt['controls'].append({'name':name,'expectedFailure':marker,'mutantSha256':sha(mutant)})
  receipt['inputsAfter']={str(f):sha(f)for f in inputs};assert receipt['inputsBefore']==receipt['inputsAfter'],'inputs changed';receipt['status']='PASS';save();print('PASS native dance cycle',receipt['checks'],len(receipt['controls']));return 0
 except Exception as error:receipt['status']='FAIL';receipt['error']=str(error);save();raise
if __name__=='__main__':raise SystemExit(main())
