"""Actual Rest/SeatingManager/Planner/NPC pose owner with controlled animation delivery.

Installed seating data and animation XML, native geometry, source action,
timed callbacks and furniture-state enter/end event are real. Deferred motion
uses a declared zero-motion animation fixture; timing, queue admission, route
events and observation acquisition are controlled. Rendered motion is unverified.
"""
import argparse,hashlib,json,os,subprocess,tempfile
from pathlib import Path
from native_proof_preflight import installed_presence
ROOT=Path(__file__).resolve().parents[1]
GAME=Path(os.environ.get('PZ_GAME_DIR',r'C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid'))
JDK=Path(os.environ.get('JDK_BIN',r'C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin'))
HERE=ROOT/'tools/d2_leisure_seating'
OWNER=ROOT/'mod/42.20/media/lua/client/SAO_LeisureSeating.lua'
PLAN=ROOT/'mod/42.20/media/lua/shared/SAO_ProceduralPlanning.lua'
SOURCE=ROOT/'java/src/com/sao/engine/SAOLeisureActionSource.java'
PREPARATION=ROOT/'mod/42.20/media/lua/client/SAO_LeisurePreparation.lua'
CONTROLS=[
 ('omit-route-pump','SAO.Locomotion.tick(a.id)','-- route pump omitted','production_route_tick_reaches_seating'),
 ('pose-premature',"if not a.body:isSittingOnFurniture()or not a.body:getVariableBoolean('SitOnFurnitureStarted')then","if false then",'source_force_complete_not_pose'),
 ('animation-end'," and a.body:getVariableBoolean('SitOnFurnitureStarted')",'', 'state_entry_without_animation_end_not_success'),
 ('body-generation','and a.body:getModData().SAOExternalToken==a.token and a.record.bodyOwner==a.bodyOwner\n  and a.record.bodyOwnerToken==a.ownerToken','and true','same_body_token_replacement_refused'),
 ('seat-identity','and seat==a.seat','and true','native_seat_replacement_refused'),
 ('seat-generation','and t.runtimeInstance==a.seatRow.runtimeInstance','and true','seat_observation_generation_replaced'),
 ('skip-source-event',"native.start(self);a.started=true",'a.started=true','original_source_requested_furniture_event'),
 ('callback-clock','and stamp and stamp>=a.startedAtMs and stamp-a.startedAtMs<=POSE_LIMIT_MS','and true','regressed_clock_no_source_event'),
]
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True);ap.add_argument('--jar',type=Path,default=ROOT/'mod/42.20/media/java/SAO.jar');ap.add_argument('--baseline-only',action='store_true');args=ap.parse_args()
 out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
 sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
 probe=ROOT/'tools/instrument_checks/InstrumentProbe.java'
 helpers=[ROOT/'tools/luacheck/MovementCrossingProbe.java',ROOT/'tools/luacheck/ResourceApproachProbe.java',ROOT/'tools/cognition_checks/CognitionUseProbe.java']
 native=[GAME/'media/lua/shared/ISBaseObject.lua',GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua',GAME/'media/lua/client/TimedActions/ISTimedActionQueue.lua']
 rest=GAME/'media/lua/shared/TimedActions/ISRestAction.lua'
 nodes=[GAME/'media/AnimSets/player/sitonfurniture'/side.lower()/f'SitOnFurniture{side}.xml'for side in ['Front','Left','Right']]
 jars=[args.jar.resolve(),GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar']
 locomotion=ROOT/'mod/42.20/media/lua/client/SAO_Locomotion.lua';routeFixture=ROOT/'tools/d2_leisure_preparation/route_tick.lua'
 inputs=[Path(__file__),HERE/'prelude.lua',HERE/'cases.lua',HERE/'join_cases.lua',HERE/'fixture.java.inc',locomotion,routeFixture,OWNER,PLAN,SOURCE,PREPARATION,probe,*helpers,*native,rest,*nodes,*jars,GAME/'media/seating.txt']
 absent=installed_presence(inputs,GAME,JDK,'D2 d2_leisure_seating_test');
 if absent is not None:return absent
 receipt={'status':'INCOMPLETE','boundary':__doc__,'runs':[],'controls':[]}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
 def run(name,cmd,wd):
  p=subprocess.run(list(map(str,cmd)),cwd=wd,capture_output=True,timeout=100);log=out/(name+'.log');log.write_bytes(p.stdout+p.stderr)
  receipt['runs'].append({'name':name,'exitCode':p.returncode,'log':str(log),'sha256':sha(log)});save()
  return p.returncode,log.read_text(encoding='utf-8',errors='replace')
 try:
  receipt['inputsBefore']={str(p):sha(p)for p in inputs}
  with tempfile.TemporaryDirectory(prefix='sao-seating-')as d:
   work=Path(d);(work/'stdlib.lua').write_bytes((GAME/'stdlib.lua').read_bytes())
   java=probe.read_text(encoding='utf-8').replace('public final class InstrumentProbe','public final class D2SeatingProbe')
   java=java.replace('IsoCell.class,zombie.iso.IsoGridSquare.class','zombie.core.skinnedmodel.advancedanimation.IAnimationVariableSource.class,zombie.core.skinnedmodel.advancedanimation.IAnimationVariableSlot.class,zombie.seating.SeatingManager.class,org.joml.Vector3f.class,zombie.iso.IsoUtils.class,zombie.iso.IsoDirections.class,zombie.characters.action.ActionContext.class,zombie.scripting.objects.CharacterTrait.class,\n            IsoCell.class,zombie.iso.IsoGridSquare.class')
   java=java.replace('for(var row:new String[][]{{"normal.txt","Harmonica","__harmonica"},{"normal.txt","Whistle","__whistle"},{"weapon.txt","GuitarAcoustic","__guitar"}})','for(var row:new String[][]{})')
   java=java.replace('env.rawset("__body",body);',(HERE/'fixture.java.inc').read_text(encoding='utf-8')+'env.rawset("__body",body);')
   java=java.replace('i<args.length;i++','i<args.length-1;i++')
   generated=out/'D2SeatingProbe.java';generated.write_text(java,encoding='utf-8')
   cp=os.pathsep.join(map(str,jars));status,log=run('compile',[JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,*helpers,generated],work);assert status==0,log
   production=OWNER.read_text(encoding='utf-8')
   preparationText=PREPARATION.read_text(encoding='utf-8')
   preparationReload=out/'preparation-reload.lua';preparationReload.write_text('__reloadPreparation=function()\n'+preparationText+'\nend\n',encoding='utf-8')
   altered=out/'tampered-rest.lua';altered.write_bytes(rest.read_bytes()+b'\n-- deliberately altered source\n')
   for name,before,after,marker in [('baseline',None,None,None)]+([]if args.baseline_only else CONTROLS):
    text=production
    if before:
     assert before in text,name;text=text.replace(before,after,1)
     if name=='pose-premature':text=text.replace('if pianoReady(a)then','if a.completed or pianoReady(a)then',1)
     if name=='animation-end':text=text.replace("or not a.body:getVariableBoolean('SitOnFurnitureStarted')",'',1)
    variant=out/f'{name}-owner.lua';variant.write_text(text,encoding='utf-8')
    reload=out/f'{name}-reload.lua';reload.write_text('__reloadSeating=function()\n'+text+'\nend\n',encoding='utf-8')
    paths=[HERE/'prelude.lua',*native,locomotion,routeFixture,PLAN,variant,reload,HERE/'cases.lua']
    if not marker:paths.extend([PREPARATION,preparationReload,HERE/'join_cases.lua'])
    paths.append(altered)
    status,log=run(name,[JDK/'java.exe','-Duser.home='+str(work),'-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED','-cp',str(work)+os.pathsep+cp,'D2SeatingProbe',GAME,*paths],work)
    if marker:assert status!=0 and 'SEATING:'+marker in log,(name,log[-6000:]);receipt['controls'].append({'name':name,'failedCheck':marker})
    else:
     assert status==0 and 'PASS seating 'in log and 'PASS seating join 'in log,log[-7500:]
     receipt['checks']=int(log.split('PASS seating ')[1].splitlines()[0]);receipt['joinChecks']=int(log.split('PASS seating join ')[1].splitlines()[0])
   receipt['inputsAfter']={str(p):sha(p)for p in inputs};assert receipt['inputsBefore']==receipt['inputsAfter'],'input drift';receipt['status']='PASS'
 except Exception as error:receipt['failure']=str(error);save();print('FAIL',error);return 1
 save();print('PASS seating',receipt['checks'],len(receipt['controls']));return 0
if __name__=='__main__':raise SystemExit(main())
