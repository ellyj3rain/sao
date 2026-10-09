"""Original native Radio/default-interface text, SP transmission and DeviceData update.
Installed item parser, off-slot bodies, ByteBuddy weave and captured emissions are
real. Native text-presentation receiver and sound hardware are controlled sinks;
no loaded/rendered/heard radio, official programme catalogue or MP claim.
"""
import argparse,hashlib,json,os,subprocess,tempfile
from pathlib import Path
from native_proof_preflight import installed_presence
ROOT=Path(__file__).resolve().parent.parent;HERE=ROOT/'tools/d2_radio_capture'
GAME=Path(os.environ.get('PZ_GAME_DIR',r'C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid'))
JDK=Path(os.environ.get('JDK_BIN',r'C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin'))
ENGINE=ROOT/'java/src/com/sao/engine/SAORadioPlayback.java';WEAVE=ROOT/'java/src/com/sao/agent/SAORadioPlaybackWeave.java'
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True);ap.add_argument('--jar',type=Path,default=ROOT/'mod/42.20/media/java/SAO.jar');ap.add_argument('--baseline-only',action='store_true');ap.add_argument('--reuse-control-receipt',type=Path);args=ap.parse_args()
 out=args.output.resolve();out.mkdir(parents=True,exist_ok=False);sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
 probe=ROOT/'tools/instrument_checks/InstrumentProbe.java';helpers=[ROOT/'tools/luacheck/MovementCrossingProbe.java',ROOT/'tools/luacheck/ResourceApproachProbe.java',ROOT/'tools/cognition_checks/CognitionUseProbe.java']
 jars=[args.jar.resolve(),GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar']
 inputs=[Path(__file__),ENGINE,WEAVE,HERE/'fixture.java.inc',probe,*helpers,*jars,GAME/'stdlib.lua',GAME/'media/scripts/generated/items/radio.txt']
 absent=installed_presence(inputs,GAME,JDK,'D2 d2_radio_capture_test');
 if absent is not None:return absent
 receipt={'status':'INCOMPLETE','inputsBefore':{str(p):sha(p)for p in inputs},'boundary':__doc__,'runs':[],'controls':[]}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
 def run(name,cmd,cwd):
  p=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=90);log=out/(name+'.log');log.write_bytes(p.stdout+p.stderr)
  receipt['runs'].append({'name':name,'exit':p.returncode,'log':str(log),'sha256':sha(log)});save();return p.returncode,log.read_text(errors='replace')
 try:
  with tempfile.TemporaryDirectory(prefix='sao-radio-capture-')as d:
   work=Path(d);(work/'stdlib.lua').write_bytes((GAME/'stdlib.lua').read_bytes())
   java=probe.read_text().replace('import se.krka.kahlua.vm.KahluaThread;', 'import se.krka.kahlua.vm.KahluaThread;\nimport se.krka.kahlua.vm.KahluaTable;').replace('public final class InstrumentProbe','public final class D2RadioCaptureProbe')
   java=java.replace('public static final class Emitter', (HERE/'fixture.java.inc').read_text()+'\n    public static final class Emitter')
   java=java.replace('{"weapon.txt","GuitarAcoustic","__guitar"}', '{"weapon.txt","GuitarAcoustic","__guitar"},{"radio.txt","WalkieTalkie1","__npcRadio"},{"radio.txt","RadioBlack","__operatorRadio"}')
   java=java.replace('System.out.println("INSTRUMENT_NATIVE_DONE");','exercise(body,other,(zombie.inventory.types.Radio)env.rawget("__npcRadio"),(zombie.inventory.types.Radio)env.rawget("__operatorRadio"),thread,env);')
   generated=out/'D2RadioCaptureProbe.java';generated.write_text(java)
   cp=os.pathsep.join(map(str,jars));code,log=run('compile',[JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,generated,*helpers],work);assert code==0,log
   code,log=run('baseline',[JDK/'java.exe','-Djdk.attach.allowAttachSelf=true','-XX:+EnableDynamicAgentLoading','-Duser.home='+str(work),'-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED','-cp',str(work)+os.pathsep+cp,'D2RadioCaptureProbe',GAME],work)
   assert code==0 and 'PASS native radio capture' in log,log[-7000:];receipt['checks']=int(log.split('PASS native radio capture ')[1].split()[0])
   if not args.baseline_only:
    def mutate(source,old,new):
     assert old in source,'missing counterfactual source anchor: '+old
     return source.replace(old,new)
    engine=ENGINE.read_text();weave=WEAVE.read_text()
    default_branch='if(name.equals("zombie.radio.devices.WaveSignalDevice"))return builder.visit(Advice.to(Text.class)\n                        .on(ElementMatchers.named("AddDeviceText").and(ElementMatchers.takesArguments(\n                            zombie.characters.IsoPlayer.class,String.class,float.class,float.class,float.class,String.class,String.class,int.class))));'
    variants=[
     ('no-original-distribution','original_distribution_private_capture',engine,mutate(weave,'SAORadioPlayback.distribute(radio,args);','/* counterfactual: omit exact original distribution extension */')),
     ('no-default-interface-capture','original_distribution_private_capture',engine,mutate(weave,default_branch,'if(name.equals("zombie.radio.devices.WaveSignalDevice"))return builder;')),
     ('no-body-generation-guard','native_body_generation_refused',mutate(engine,'&&listener.bodyToken.equals(String.valueOf(body.getModData().rawget("SAOExternalToken")))',''),weave),
     ('no-current-hearing-guard','native_deaf_emission_not_captured',mutate(engine,'||!SAOPerceptionScanner.canReceiveRadioNow(body)',''),weave),
     ('no-current-radio-custody','lost_receiver_custody_not_captured',mutate(engine,'if(source instanceof Radio radio)return equipped(body)==radio;','if(source instanceof Radio radio)return true;'),weave),
     ('no-original-failure-guard','failed_original_method_not_captured',mutate(engine,'||failure!=null',''),weave),
     ('no-private-event-scope','operator_event_and_private_scope',mutate(engine,'return "OnDeviceText".equals(event)&&parent instanceof Radio radio&&PORTABLE.get()==radio;','return false;'),weave),
     ('no-private-manager-scope','private_manager_operator_route_preserved',engine,mutate(weave,'return SAORadioPlayback.privateChat();','return false;')),
     ('no-finally-scope-clear','operator_event_and_private_scope',mutate(engine,'if(previous==null)PORTABLE.remove();else PORTABLE.set(previous);','if(previous!=null)PORTABLE.set(previous);'),weave),
     ('no-native-frame-guard','same_native_frame_not_double_updated',mutate(engine,'if(previousFrame!=null&&previousFrame==frame)return true;','if(false)return true;'),weave),
     ('no-channel-currentness','changed_channel_invalidates_emission',mutate(engine,'&&parent.getDeviceData().getChannel()==event.channel',''),weave),
     ('no-media-currentness','changed_media_invalidates_emission',mutate(engine,'&&parent.getDeviceData().getMediaIndex()==event.mediaIndex',''),weave),
     ('no-event-expiry','stale_event_refused',mutate(engine,'5_000_000_000L','Long.MAX_VALUE'),weave),
     ('no-emission-source-binding','world_listener_cannot_capture_separate_radio',mutate(mutate(engine,'||listener.source.get()!=call.parent',''),'||listener.source.get()!=target',''),weave),
     ('no-explicit-recipient-binding','foreign_default_recipient_refused',mutate(mutate(engine,'radio.getPlayer()!=recipient','false'),'||call.recipient!=null&&call.recipient!=body',''),weave),
     ('no-engine-regression-guard','regressed_clock_no_emission',mutate(engine,'||engineHours<listener.engineAtRegistration',''),weave),
     ('raw-engine-as-county','exact_county_native_offset',mutate(engine,'listener.countyAtRegistration+(engineHours-listener.engineAtRegistration)','engineHours'),weave),
    ]
    reusable=None
    if args.reuse_control_receipt:
     reusable=json.loads(args.reuse_control_receipt.read_text())
     for path,before in reusable['inputsBefore'].items():
      if Path(path).resolve()not in (Path(__file__).resolve(),(HERE/'fixture.java.inc').resolve()):assert sha(Path(path))==before,'reused evidence input drift '+path
     prefix=(HERE/'fixture.java.inc').read_text().split('        var recorded=')[0]
     prior_generated=args.reuse_control_receipt.parent/'D2RadioCaptureProbe.java'
     assert prefix in prior_generated.read_text(),'reused fixture prefix drift'
     full_fixture_identical=sha(HERE/'fixture.java.inc')==reusable['inputsBefore'][str(HERE/'fixture.java.inc')]
     receipt['reusedFixtureScope']={'fullFixtureIdentical':full_fixture_identical,'before':'actual recorded-media start','prefixSha256':hashlib.sha256(prefix.encode()).hexdigest(),'priorGeneratedSha256':sha(prior_generated)}
     receipt['reusedReceipt']={'path':str(args.reuse_control_receipt.resolve()),'sha256':sha(args.reuse_control_receipt)}
    for name,marker,engine_source,weave_source in variants:
     isolated=work/name;isolated.mkdir();classes=isolated/'classes';classes.mkdir()
     es=isolated/'SAORadioPlayback.java';ws=isolated/'SAORadioPlaybackWeave.java';es.write_text(engine_source);ws.write_text(weave_source)
     receipt.setdefault('variantInputs',{})[name]={'engine':sha(es),'weave':sha(ws),'expected':'RADIO_CAPTURE:'+marker}
     previous=next((c for c in reusable['controls']if c['name']==name and c['status']=='DETECTED'),None)if reusable else None
     if previous and not full_fixture_identical and ('check(\"'+marker+'\"')not in prefix:previous=None
     if previous:
      assert reusable['variantInputs'][name]==receipt['variantInputs'][name],'changed reused variant '+name
      oldrun={'log':previous['reusedFrom'],'sha256':previous['logSha256']}if 'reusedFrom'in previous else next(r for r in reusable['runs']if r['name']==name)
      oldlog=Path(oldrun['log'])
      assert sha(oldlog)==oldrun['sha256'] and 'RADIO_CAPTURE:'+marker in oldlog.read_text(),'reused control log drift'
      receipt['controls'].append(dict(previous,reusedFrom=oldrun['log'],logSha256=oldrun['sha256']));save();continue
     code,log=run(name+'-compile' ,[JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',classes,es,ws],work);assert code==0,log
     code,log=run(name,[JDK/'java.exe','-Djdk.attach.allowAttachSelf=true','-XX:+EnableDynamicAgentLoading','-Duser.home='+str(work),'-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED','-cp',str(classes)+os.pathsep+str(work)+os.pathsep+cp,'D2RadioCaptureProbe',GAME],work)
     assert code!=0 and 'RADIO_CAPTURE:'+marker in log,'counterfactual did not fail intended guard '+name+'\n'+log[-5000:]
     receipt['controls'].append({'name':name,'expectedFailure':marker,'status':'DETECTED'});save()
   receipt['inputsAfter']={str(p):sha(p)for p in inputs};assert receipt['inputsAfter']==receipt['inputsBefore'],'input drift';receipt['status']='PASS'
 except Exception as e:receipt['failure']=str(e);save();print('FAIL',e);return 1
 save();print('PASS native radio capture',receipt['checks'],len(receipt['controls']));return 0
if __name__=='__main__':raise SystemExit(main())
