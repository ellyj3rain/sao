"""Original NewMusic scheduler/cache/transport in native Kahlua with real source identity.
Physical actor/geometry, emitter hardware, clocks and selected-source acquisition
are controlled host inputs; separate audio-native proof qualifies native geometry.
"""
import argparse,hashlib,json,os,re,shutil,subprocess,tempfile
from pathlib import Path
from native_proof_preflight import installed_presence
ROOT=Path(__file__).resolve().parent.parent;HERE=ROOT/'tools/d2_music_scheduler'
GAME=Path(os.environ.get('PZ_GAME_DIR',r'C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid'))
NM=GAME.parent.parent/'workshop/content/108600/3739256725/mods/Talis New Music/42/media/lua'
JDK=Path(os.environ.get('JDK_BIN',r'C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin'))
OWNER=ROOT/'mod/42.20/media/lua/client/SAO_LeisureMusicWorld.lua'
IDENTITY=ROOT/'java/src/com/sao/engine/SAOLuaSourceIdentity.java'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True);ap.add_argument('--jar',type=Path,default=ROOT/'mod/42.20/media/java/SAO.jar');ap.add_argument('--baseline-only',action='store_true');args=ap.parse_args()
 out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
 files=sorted(NM.rglob('*.lua'));jars=[args.jar.resolve(),GAME/'projectzomboid.jar']
 inputs=[Path(__file__),OWNER,IDENTITY,HERE/'SchedulerProbe.java',HERE/'prelude.lua',HERE/'cases.lua',*files,*jars,GAME/'stdlib.lua']
 absent=installed_presence(inputs,GAME,JDK,'D2 d2_music_scheduler_test');
 if absent is not None:return absent
 receipt={'status':'INCOMPLETE','inputsBefore':{str(p):sha(p)for p in inputs},'runs':[],'controls':[],'boundary':__doc__}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
 def run(name,cmd,cwd):
  p=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=90);log=out/(name+'.log');log.write_bytes(p.stdout+p.stderr)
  receipt['runs'].append({'name':name,'exit':p.returncode,'log':str(log),'sha256':sha(log)});save();return p.returncode,log.read_text(errors='replace')
 try:
  manifest=out/'source-paths.tsv';manifest.write_text(''.join(p.relative_to(NM).as_posix()+'\t'+str(p)+'\n'for p in files))
  with tempfile.TemporaryDirectory(prefix='sao-scheduler-')as d:
   work=Path(d);shutil.copyfile(GAME/'stdlib.lua',work/'stdlib.lua');cp=os.pathsep.join(map(str,jars))
   code,log=run('compile',[JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,HERE/'SchedulerProbe.java'],work);assert code==0,log
   java_args=[JDK/'java.exe','-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED','-cp',str(work)+os.pathsep+cp,'SchedulerProbe',manifest,HERE/'prelude.lua',OWNER,HERE/'cases.lua']
   code,log=run('baseline',java_args,work)
   assert code==0 and 'PASS D2 scheduler 'in log,log[-7000:];receipt['checks']=int(re.search(r'PASS D2 scheduler (\d+)',log)[1])
   if not args.baseline_only:
    owner=OWNER.read_text();identity=IDENTITY.read_text()
    def mutation(text,old,new):assert old in text,old;return text.replace(old,new)
    before_callback='if intact()then pcall(captureEnding,tostring(uuid))end\n   return callback(p,profile,state,entry,item,kind,uuid)'
    after_callback='local value=callback(p,profile,state,entry,item,kind,uuid)\n   if intact()then pcall(captureEnding,tostring(uuid))end\n   return value'
    controls=[
     ('missing-native-collect','lua','originalCollect(player,out)','local ignored=player','native_cap_preserves_operator_entries'),
     ('no-selected-dedup','lua','if not seen[row.uuid]then','if true then','selected_outside_operator_range_kept'),
     ('no-native-cap','lua','if #out>=cap then break end','if false then break end','native_cap_preserves_operator_entries'),
     ('borrowed-entry','lua','entry=shallow(entry)','entry=entry','selected_native_shallow_clone_parity'),
     ('late-terminal-copy','lua',before_callback,after_callback,'copied_ending_before_original_advances'),
     ('per-listener-pulse-memory','lua','pcall(originalPulse,row.body,{[row.uuid]=candidate},state)','pcall(originalPulse,row.body,{[row.uuid]=candidate},{nowMs=state.nowMs,zombieAttractionPulseState={}})','npc_near_pulse_original_shared_uuid_once'),
     ('no-tuple-check','lua','if state[key]~=row.state[key]then return false end','if false then return false end','stale_revision_refused'),
     ('no-coordinate-check','lua','if not finite(source[key])or not finite(row.source[key])or math.abs(source[key]-row.source[key])>.01 then return false end','if false then return false end','current_source_coordinate_required'),
     ('legacy-source-part-metadata','lua','entry.partId or entry.attachedPartId','source.partId','original_vehicle_continuity_resolved'),
     ('no-vehicle-identity','lua','if row.context=="vehicle" then','if false then','selected_vehicle_sql_identity_required'),
     ('no-dependency-seal','lua','if seal.table[key]~=fn then return false end','if false then return false end','changed_dependency_invalidates_seal'),
     ('no-source-prototype','lua','not SAOJavaBridge:sameNativeLuaSourceFunction(public[key],fn)','false','replaced_original_before_install_refused'),
     ('empty-audit-admitted','lua','if not seals[name].functions[key]then return false end','if false then return false end','missing_audit_functions_refused'),
     ('callback-not-restored','lua','options.consumeAndDispatchTrackFinished=callback;scope=previous','scope=previous','callback_restored_after_pass'),
     ('scope-not-restored','lua','scope=previous','local ignored=previous','collection_scope_released_after_exception'),
     ('scalar-upvalue-ignored','java','if(!Objects.equals(av,bv))return false;','if(false)return false;','native_scalar_capture_guard'),
     ('java-callable-ignored','java','if(av!=bv)return false;','if(false)return false;','native_java_callable_capture_guard'),
     ('native-environment-ignored','java','||a.env!=env','','native_foreign_environment_guard'),
    ]
    for name,kind,old,new,marker in controls:
     command=list(java_args)
     if kind=='lua':
      variant=out/(name+'-owner.lua');variant.write_text(mutation(owner,old,new));command[-2]=variant
     else:
      isolated=work/name;isolated.mkdir();variant=isolated/'SAOLuaSourceIdentity.java';variant.write_text(mutation(identity,old,new))
      code,log=run(name+'-compile',[JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',isolated,variant],work);assert code==0,log
      command[command.index('-cp')+1]=str(isolated)+os.pathsep+str(work)+os.pathsep+cp
     code,log=run(name,command,work)
     assert code!=0 and 'D2_SCHEDULER:'+marker in log,'counterfactual did not detect '+name+'\n'+log[-6500:]
     receipt['controls'].append({'name':name,'kind':kind,'expectedFailure':marker,'status':'DETECTED'});save()
  receipt['inputsAfter']={str(p):sha(p)for p in inputs};assert receipt['inputsBefore']==receipt['inputsAfter'],'input drift';receipt['status']='PASS'
 except Exception as e:receipt['failure']=str(e);save();print('FAIL',e);return 1
 save();print('PASS D2 scheduler',receipt['checks'],len(receipt['controls']));return 0
if __name__=='__main__':raise SystemExit(main())
