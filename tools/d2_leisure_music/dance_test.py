#!/usr/bin/env python3
"""Original source dance cycles with an acquired actually playing source host."""
from pathlib import Path
import argparse,json,os,re,shutil,subprocess,sys,tempfile
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import d2_leisure_music_test as music
import d2_leisure_music.world_audio_test as world
from native_proof_preflight import installed_presence
def main():
 p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);p.add_argument('--diagnostic',action='store_true');p.add_argument('--baseline-only',action='store_true');args=p.parse_args()
 out=args.out.resolve();out.mkdir(parents=True,exist_ok=False)
 native=[music.GAME/'media/lua/shared/ISBaseObject.lua',music.GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua']
 jars=[music.GAME/'projectzomboid.jar',*sorted((music.GAME/'jars').glob('*.jar'))]
 inputs=[Path(__file__),music.ROOT/'tools/native_proof_preflight.py',Path(music.__file__),Path(world.__file__),music.OWNER,music.ORG,music.FIXTURES/'prelude.lua',music.FIXTURES/'MusicProbe.java',music.FIXTURES/'world-audio-cases.lua',music.FIXTURES/'dance-cases.lua',*native,*jars,music.GAME/'stdlib.lua',*[music.LS/n for n in music.LS_FILES],*[music.NM/n for n in music.NM_FILES+music.NM_PROOF_FILES+world.EXTRA]]
 absent=installed_presence(inputs,music.GAME,music.JDK,'D2 source dance cycles',installed_roots=(music.LS.parent,music.NM.parent))
 if absent is not None:return absent
 before={str(f):music.sha(f)for f in inputs}
 receipt={'schema':'sao-d2-source-dance/1','status':'INCOMPLETE','inputsBefore':before,'runs':[],
 'boundary':'Complete original PlayerIsDancingToMusic/PlayerVoiceTracks/PlayerDanceMoves/LSUtil/PlayerTracker and shared original NewMusic renderer/audibility with four actor-local original emitter-call tracing sites after source pin verification. Native Kahlua/Stats/table persistence; physical body/queue/private acquisition/native hearing/clock/RNG/audio hardware/XP receiver hosts controlled. Genre inputs controlled source state for repertoire matrix. One real source animation/physiology callback closes one bounded source cycle, not an invented timer or social partner. Root native/physical/genre/consent/rendered joins separate.'}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
 def run(name,cmd,cwd):
  r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=90);log=out/(name+'.log');log.write_bytes(r.stdout+r.stderr)
  receipt['runs'].append({'name':name,'exitCode':r.returncode,'log':str(log),'logSha256':music.sha(log)});save();return r.returncode,log.read_text(errors='replace')
 try:
  keys={**music.pins(),**{'NewMusic:'+n:[]for n in music.NM_PROOF_FILES+world.EXTRA}}
  manifest=out/'source-paths.tsv';manifest.write_text(''.join(k+'\t'+str((music.LS if k.startswith('LifestyleHobbies:')else music.NM)/k.split(':',1)[1])+'\n'for k in keys))
  full=(music.FIXTURES/'world-audio-cases.lua').read_text();anchor='local function offer()';assert full.count(anchor)==1
  combined=out/'combined-dance-cases.lua';combined.write_text(full.split(anchor)[0]+(music.FIXTURES/'dance-cases.lua').read_text())
  controls=[
   ('hearing','SAO.Perception.canHearLeisureSource(id,body,offer.audioObservation,range)==true','true','native_receiver_hearing_required'),
   ('actual-sound','channel.emitter:isPlaying(channel.soundId) and audibility','true and audibility','no_actual_audio_no_dance_offer'),
   ('cycle-proof','a.danceCycle and a.danceCycle.sourceCallbackCompleted==true','a.danceCycle and true','partial_original_callback_not_completed'),
   ('private-notes','env.HaloTextHelper={addTextWithArrow=function(actor,text)','env.HaloTextHelper=HaloTextHelper;local unused={addTextWithArrow=function(actor,text)','private_dance_Halo_never_operator'),
   ('native-moods','local before=measure(body);local result=sourceGroup(actor,moods)','local before=measure(body);local result=nil','source_real_metabolic_and_mood_effects'),
   ('owned-audio-cleanup','a.emitter:stopSound(handle)','do end ','captured_source_audio_owned_cleanup'),
   ('failed-cycle','if self.criticalFailure==0 then self:forceComplete() end','self:forceComplete()','original_failed_move_stays_in_source_sequence'),
   ('dead-injury-replay','if not danceDeathRetired then a.action:stop()end','a.action:stop()','dead_failure_cleanup_no_injury_XP_or_effect_replay'),
  ]
  owner=music.OWNER.read_text()
  with tempfile.TemporaryDirectory(prefix='sao-dance-')as tmp:
   work=Path(tmp);shutil.copyfile(music.GAME/'stdlib.lua',work/'stdlib.lua');cp=os.pathsep.join(map(str,jars))
   code,log=run('compile',[music.JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,music.FIXTURES/'MusicProbe.java'],work);assert code==0,log
   receipt['controls']=[]
   for name,old,new,marker in [('baseline',None,None,None)]+([]if args.baseline_only else controls):
    text=owner
    if old:
     expected=3 if name=='owned-audio-cleanup'else 1
     assert text.count(old)==expected,(name,text.count(old));text=text.replace(old,new)
    variant=out/(name+'-owner.lua');variant.write_text(text)
    code,log=run(name,[music.JDK/'java.exe','-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED','-cp',str(work)+os.pathsep+cp,'MusicProbe',manifest,music.FIXTURES/'prelude.lua',*native,music.LS/'shared/LSUtil.lua',music.ORG,variant,combined],work)
    if marker:assert code!=0 and 'D2_DANCE:'+marker in log,(name,log[-6000:]);receipt['controls'].append({'name':name,'expectedFailure':marker})
    else:assert code==0 and 'PASS D2 source dance 'in log,log[-9000:];receipt['checks']=int(re.search(r'PASS D2 source dance (\d+)',log)[1])
  receipt['inputsAfter']={str(f):music.sha(f)for f in inputs}
  if args.diagnostic:receipt['status']='DIAGNOSTIC';receipt['inputDrift']=before!=receipt['inputsAfter']
  else:assert before==receipt['inputsAfter'],'changed inputs during proof';receipt['status']='PASS'
  save();print(receipt['status'],'D2 source dance',receipt['checks'],len(receipt['controls']));return 0
 except Exception as e:receipt['status']='FAIL';receipt['error']=str(e);save();raise
if __name__=='__main__':raise SystemExit(main())
