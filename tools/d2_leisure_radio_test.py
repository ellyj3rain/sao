#!/usr/bin/env python3
"""Native Kahlua/Stats, original radio actions/interactions; receiver host controlled."""
from pathlib import Path
import argparse,hashlib,json,os,subprocess,tempfile,shutil,re
from native_proof_preflight import installed_presence
ROOT=Path(__file__).resolve().parents[1]
GAME=Path(r'C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid')
JDK=Path(r'C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin')
OWNER=ROOT/'mod/42.20/media/lua/client/SAO_LeisureRadio.lua'
HERE=ROOT/'tools/d2_leisure_radio'
FILES=['shared/RadioCom/ISRadioInteractions.lua','shared/RadioCom/ISRadioAction.lua','shared/TimedActions/ISDeviceBatteryAction.lua','shared/TimedActions/ISDeviceMediaAction.lua']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);p.add_argument('--baseline-only',action='store_true');args=p.parse_args()
 out=args.out.resolve();out.mkdir(parents=True,exist_ok=False)
 jars=[GAME/'projectzomboid.jar',*sorted((GAME/'jars').glob('*.jar'))]
 native=[GAME/'media/lua/shared/ISBaseObject.lua',GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua']
 probe=ROOT/'tools/d2_leisure_music/MusicProbe.java'
 inputs=[Path(__file__),OWNER,HERE/'prelude.lua',HERE/'cases.lua',probe,*native,*jars,GAME/'stdlib.lua',*[GAME/'media/lua'/f for f in FILES]]
 absent=installed_presence(inputs,GAME,JDK,'D2 native radio source');
 if absent is not None:return absent
 before={str(f):sha(f)for f in inputs}
 receipt={'schema':'sao-d2-native-radio-source/1','status':'INCOMPLETE','inputsBefore':before,'runs':[],
 'boundary':'Native Kahlua/Stats/table save-load and pinned original ISRadioAction/ISDeviceMediaAction/ISRadioInteractions callbacks, with only audited actor-local cooldown binding. Physical body/device/queue, native emission work/current capability, native frame, XP receiver, power/geometry and clocks are controlled. No native Java weave, full distribution scheduler, rendered audio, or loaded-gameplay claim. Completion is one actual host-received native content line, not a whole tape/show.'}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
 def run(name,cmd,cwd):
  r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=90);log=out/(name+'.log');log.write_bytes(r.stdout+r.stderr)
  receipt['runs'].append({'name':name,'exitCode':r.returncode,'log':str(log),'logSha256':sha(log)});save()
  return r.returncode,log.read_text(errors='replace')
 controls=[
 ('body','SAO.Needs.ownsRecoveryBody(id,body)==true','true','foreign_body_refused'),
 ('offer','same(row,offer)','true','spoof_offer_refused'),
 ('planner','not P.admitHobbyWork(id,purposeId,w.sequence,OWNER)','false','planner_refused_before_receiver'),
 ('event-current','not SAOJavaBridge:nativeRadioPlaybackEventCurrent(body,w.workId,row.sequence,a.device)','false','expired_native_emission_refused'),
 ('work','row.workId~=w.workId','false','foreign_work_event_refused'),
 ('after-admission','row.atHours<w.admittedAtHours','false','preadmission_content_refused'),
 ('county-clock','device,current.sourceKey,w.admittedAtHours','device,current.sourceKey','county_offset_preserves_emission_clock'),
 ('channel','row.channel~=a.data:getChannel()','false','foreign_channel_event_refused'),
 ('media','row.mediaIndex~=a.data:getMediaIndex()','false','foreign_media_event_refused'),
 ('source','row.sourceKey~=a.offer.sourceKey','false','foreign_source_event_refused'),
 ('skill-private','local row=a.skillRequests[sequence]','local row=person(id).leisureRadioSkillRequests[#person(id).leisureRadioSkillRequests]','durable_skill_tampering_refused'),
 ('source-pins','h1~=pin[2]or h2~=pin[3]or #lines~=pin[4]','false','changed_source_refused'),
 ('native-frame','tick.frameNo~=a.lastSourceFrame','true','same_native_frame_no_double_cooldown'),
 ('action-start','not started or not valid(id,a)or self:getJobDelta()<1','not valid(id,a)','premature_action_refused'),
 ('battery-preparation','if current.batteryItemKey then','if false then','missing_battery_queues_native_insert'),
 ('battery-energy','if data:getIsBatteryPowered()then return data:getPower()>0 end','if data:getIsBatteryPowered()then return data:getPower()>0 or data:canBePoweredHere()end','battery_power_capability_is_not_current_charge'),
 ('battery-custody','resolveItem(a.body,a.offer.batteryItemKey)~=a.batteryItem','false','lost_selected_battery_refused_before_remove'),
 ('battery-charge','a.batteryItem:getCurrentUsesFloat()~=a.offer.batteryCharge','false','changed_selected_battery_charge_refused'),
 ('battery-native-complete','if action.deviceData~=a.data then error("native-battery-parameter-not-exact-device")end','if action.deviceData~=a.data then error("native-battery-parameter-not-exact-device")end;action.complete=function()return true end','original_battery_insertion_consumes_selected_spare'),
 ]
 try:
  text=OWNER.read_text();manifest=out/'source-paths.tsv';manifest.write_text(''.join('native:'+f+'\t'+str(GAME/'media/lua'/f)+'\n'for f in FILES))
  with tempfile.TemporaryDirectory(prefix='sao-radio-')as tmp:
   work=Path(tmp);shutil.copyfile(GAME/'stdlib.lua',work/'stdlib.lua');cp=os.pathsep.join(map(str,jars))
   code,log=run('compile',[JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,probe],work);assert code==0,log
   receipt['controls']=[]
   for name,old,new,marker in [('baseline',None,None,None)]+([]if args.baseline_only else controls):
    changed=text
    if new in ('true','false'):new='('+new+')'
    if old:
     if name=='action-start':assert changed.count(old)==2;changed=changed.replace(old,new,1)
     else:assert changed.count(old)==1,(name,changed.count(old));changed=changed.replace(old,new,1)
    variant=out/(name+'-owner.lua');variant.write_text(changed)
    code,log=run(name,[JDK/'java.exe','-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED','-cp',str(work)+os.pathsep+cp,'MusicProbe',manifest,HERE/'prelude.lua',*native,variant,HERE/'cases.lua'],work)
    if marker:
     assert code!=0 and 'D2_RADIO:'+marker in log,(name,log[-4500:]);receipt['controls'].append({'name':name,'expectedFailure':marker})
    else:
     assert code==0 and 'PASS D2 native radio 'in log,log[-6500:];receipt['checks']=int(re.search(r'PASS D2 native radio (\d+)',log)[1])
  receipt['inputsAfter']={str(f):sha(f)for f in inputs};assert before==receipt['inputsAfter'],'changed inputs during proof'
  receipt['status']='PASS';save();print('PASS D2 native radio',receipt['checks'],len(receipt['controls']));return 0
 except Exception as e:receipt['status']='FAIL';receipt['error']=str(e);save();raise
if __name__=='__main__':raise SystemExit(main())
