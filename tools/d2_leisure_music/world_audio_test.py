#!/usr/bin/env python3
"""Original public renderer, Music caller and original world scheduler joining proof."""
from pathlib import Path
import argparse,json,os,re,shutil,subprocess,sys,tempfile
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import d2_leisure_music_test as music
from native_proof_preflight import installed_presence
JOIN=music.ROOT/'tools/d2_music_scheduler'
WORLD=music.ROOT/'mod/42.20/media/lua/client/SAO_LeisureMusicWorld.lua'
EXTRA=['shared/audio/NMFadeMath.lua','shared/audio/NMOcclusionMath.lua','shared/slot/NMInventoryHelpers.lua',
 'shared/vehicle/NMVehicleHelpers.lua','shared/registry/NMRegistryPolicy.lua','shared/registry/NMWorldRegistrySnapshot.lua',
 'client/cache/NMClientVehicleAttachmentResolver.lua','client/cache/NMClientVehicleSourceUpdater.lua','client/cache/NMClientWorldSourceCache.lua',
 'shared/state/NMAuthorityStateCommon.lua','shared/state/NMAuthorityState.lua','shared/intent/NMIntentAuthority.lua',
 'shared/audio/NMZombieAttraction.lua','client/runtime/NMClientOwnershipConflictPolicy.lua','client/runtime/NMClientVehicleContinuity.lua',
 'client/runtime/NMClientDetachedOrchestration.lua','client/runtime/NMClientDetachedPlaybackPass.lua','client/runtime/NMClientSPLocalRuntime.lua',
 'client/runtime/NMClientTrackProgressionDispatch.lua','client/runtime/NMClientTrackFinishedDispatch.lua','client/runtime/NMClientPlaybackTick.lua','client/runtime/NMClientMainRuntime.lua']

def main():
 p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);p.add_argument('--jar',type=Path,default=music.ROOT/'mod/42.20/media/java/SAO.jar');p.add_argument('--baseline-only',action='store_true');a=p.parse_args();out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
 native=[music.GAME/'media/lua/shared/ISBaseObject.lua',music.GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua']
 jars=[a.jar.resolve(),music.GAME/'projectzomboid.jar',*sorted((music.GAME/'jars').glob('*.jar'))]
 inputs=[Path(__file__),Path(music.__file__),music.OWNER,music.ORG,WORLD,JOIN/'music_join_prelude.lua',JOIN/'WorldSchedulerProbe.java',JOIN/'music_join_cases.lua',music.FIXTURES/'world-audio-cases.lua',*native,*jars,music.GAME/'stdlib.lua',*[music.LS/n for n in music.LS_FILES],*[music.NM/n for n in music.NM_FILES+music.NM_PROOF_FILES+EXTRA]]
 absent=installed_presence(inputs,music.GAME,music.JDK,'D2 world_audio_test',installed_roots=(music.LS.parent,music.NM.parent));
 if absent is not None:return absent
 receipt={'schema':'sao-d2-newmusic-public-source/2','status':'INCOMPLETE','inputsBefore':{str(p):music.sha(p)for p in inputs},'runs':[],
 'boundary':'Original NewMusic profiles/state/authority/intent/payload/power/helpers/world cache/SP snapshot/fade/occlusion/renderer/debounce and original detached scheduler; native Kahlua/Stats/persistence and real native source-identity Bridge. Actual Music-to-World-to-original-scheduler-to-predispatch-ending-copy-to-Music-completion join qualified. Physical actor/item/vehicle/grid/visibility/hearing/media/queue/clock/emitter and Planner admission host controlled. Separate native audio proof retains geometry/hearing coverage. No rendering/hardware/full cadence/MP or learned-content claim.'}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
 def run(name,args,cwd):
  r=subprocess.run(list(map(str,args)),cwd=cwd,capture_output=True,timeout=90);path=out/(name+'.log');path.write_bytes(r.stdout+r.stderr);receipt['runs'].append({'name':name,'exitCode':r.returncode,'sha256':music.sha(path)});save();return r.returncode,path.read_text(errors='replace')
 try:
  keys={**music.pins(),**{'NewMusic:'+n:[]for n in music.NM_PROOF_FILES+EXTRA}}
  manifest=out/'source-paths.tsv';manifest.write_text(''.join(k+'\t'+str((music.LS if k.startswith('LifestyleHobbies:')else music.NM)/k.split(':',1)[1])+'\n'for k in keys),encoding='utf-8')
  controls=[
   ('public-custody','local target=P and P.resolveLeisureAudioSource and P.resolveLeisureAudioSource(id,body,offer.audioSourceKey)','local target=__target','lost_visibility_interrupts'),
   ('native-hearing','and SAO.Perception.canHearLeisureSource(id,a.body,acquired,range)==true','and true','native_hearing_required'),
   ('power','if not sourcePower(a.body,target,device,profile,state,a.offer.sourceContext)then','if false then','live_power_loss_interrupts'),
   ('end-confirmation','a.heard and proven and (heard or a.publicEndingHeard)','a.heard and endReceipt and (heard or a.publicEndingHeard)','premature_public_confirmation_refused'),
   ('shared-channel','channel.isWorldEmitter==true','true','personal_channel_not_public_sound'),
   ('revision','if state[field]~=b[field]then','if false then','foreign_playback_interrupts'),
   ('vehicle-controls','return body:getVehicle()==target.vehicle','return true','unoccupied_radio_control_refused'),
   ('physical-stop','a.cleanupSucceeded=true\n            else a.cleanupSucceeded=pcall','NMPlaybackRuntime.forceStop(body,a.playback.deviceUUID,"defect-listener-stop");a.cleanupSucceeded=true\n            else a.cleanupSucceeded=pcall','listener_interrupt_preserves_public_playback'),
   ('public-source-hearing','SAO.Perception.canHearLeisureSource(id,a.body,observed,range)==true','true','unheard_music_cannot_extend_source_scheduler'),
   ('public-source-binding','if sameBinding then rows[#rows+1]','if true then rows[#rows+1]','changed_source_tuple_cannot_extend_scheduler'),
   ('public-terminal-copy','a.publicEndingReceipt=plain(receipt);a.publicEndingHeard=true','local ignored=receipt','music_completed_after_original_native_dispatch'),
  ]
  owner=music.OWNER.read_text(encoding='utf-8')
  with tempfile.TemporaryDirectory(prefix='sao-world-audio-')as tmp:
   work=Path(tmp);shutil.copyfile(music.GAME/'stdlib.lua',work/'stdlib.lua');cp=os.pathsep.join(map(str,jars))
   code,log=run('compile',[music.JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,JOIN/'WorldSchedulerProbe.java'],work);assert code==0,log
   receipt['controls']=[]
   for name,before,after,marker in [('baseline',None,None,None)]+([]if a.baseline_only else controls):
    text=owner
    if before:assert text.count(before)==1,(name,text.count(before));text=text.replace(before,after,1)
    op=out/(name+'-owner.lua');op.write_text(text,encoding='utf-8')
    code,log=run(name,[music.JDK/'java.exe','-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED','-cp',str(work)+os.pathsep+cp,'WorldSchedulerProbe',manifest,JOIN/'music_join_prelude.lua',*native,music.LS/'shared/LSUtil.lua',music.ORG,WORLD,op,music.FIXTURES/'world-audio-cases.lua',JOIN/'music_join_cases.lua'],work)
    if marker:
     assert code!=0 and ('D2_WORLD_AUDIO:'+marker in log or 'D2_WORLD_JOIN:'+marker in log),(name,log[-6000:]);receipt['controls'].append({'name':name,'expectedFailure':marker})
    else:
     assert code==0 and 'PASS D2 world audio 'in log and 'PASS D2 world scheduler join 'in log,log[-7000:]
     receipt['checks']=int(re.search(r'PASS D2 world audio (\d+)',log)[1]);receipt['joinChecks']=int(re.search(r'PASS D2 world scheduler join (\d+)',log)[1])
  receipt['inputsAfter']={str(p):music.sha(p)for p in inputs};assert receipt['inputsBefore']==receipt['inputsAfter'],'input drift'
  receipt['status']='PASS';save();print('PASS D2 world audio',receipt['checks'],'checks;',receipt['joinChecks'],'join checks;',len(receipt['controls']),'controls');return 0
 except Exception as e:receipt['status']='FAIL';receipt['error']=str(e);save();raise
if __name__=='__main__':raise SystemExit(main())
