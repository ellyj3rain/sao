"""Original installed native preparation actions and actual NPC hand/worn effects.

Actual Planner, native LuaTimedActionNew callbacks (SP perform before complete),
queue management and source digest gate run. Animation timing, route events,
UI/event/network sinks and affordance acquisition are controlled fixtures.
"""
import argparse,hashlib,json,os,subprocess,tempfile
from pathlib import Path
from native_proof_preflight import installed_presence
ROOT=Path(__file__).resolve().parents[1]
GAME=Path(os.environ.get('PZ_GAME_DIR',r'C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid'))
JDK=Path(os.environ.get('JDK_BIN',r'C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin'))
HERE=ROOT/'tools/d2_leisure_preparation'
OWNER=ROOT/'mod/42.20/media/lua/client/SAO_LeisurePreparation.lua'
PLAN=ROOT/'mod/42.20/media/lua/shared/SAO_ProceduralPlanning.lua'
CTL=ROOT/'mod/42.20/media/lua/client/SAO_Controller.lua'
CONTROLS=[
 ('omit-route-pump','SAO.Locomotion.tick(a.id)','-- route pump omitted','production_route_tick_reaches_preparation'),
 ('secondary-heavy-hole','for slot=1,2 do','for slot=1,1 do','secondary_only_heavy_item_refused'),
 ('early-complete','if not valid(self) or not finishedTime(self) or a.effectObserved or a.completedCallback','if not valid(self) or a.effectObserved or a.completedCallback','early_complete_refused'),
 ('body-generation','and a.body:getModData().SAOExternalToken==a.bodyToken and a.row.bodyToken==a.bodyToken','and true','replaced_body_token_no_effect'),
 ('item-identity','and item(a.body,tostring(selected:getID()),selected:getFullType())==selected','and true','replacement_item_identity_no_effect'),
 ('two-hands','else act=class:new(a.body,selected,50,primary,twoHands==true,false) end','else act=class:new(a.body,selected,50,primary,twoHands==true,false);act.twoHands=false end','native_two_hand_barbell_effect'),
 ('native-primary-effect','local ok,result=pcall(native.complete,self)','local ok,result=true,true','native_primary_effect'),
 ('planner-retirement','purpose.status~="maintained"','false','retired_purpose_refused'),
 ('urgent-preemption','if urgent then Ctl.interruptLeisure','if false then Ctl.interruptLeisure','controller_preempts___bleeding'),
 ('native-source-hash','if (!expected.equals(hash)) return null;','if (false) return null;','actual_source_hash_tamper'),
]
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True);ap.add_argument('--jar',type=Path,default=ROOT/'mod/42.20/media/java/SAO.jar');ap.add_argument('--baseline-only',action='store_true');args=ap.parse_args()
 out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
 sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
 probe=ROOT/'tools/instrument_checks/InstrumentProbe.java'
 helpers=[ROOT/'tools/luacheck/MovementCrossingProbe.java',ROOT/'tools/luacheck/ResourceApproachProbe.java',ROOT/'tools/cognition_checks/CognitionUseProbe.java']
 native=[GAME/'media/lua/shared/ISBaseObject.lua',GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua',GAME/'media/lua/client/TimedActions/ISTimedActionQueue.lua']
 sources=[GAME/'media/lua/shared/TimedActions'/f'{name}.lua'for name in ['ISWearClothing','ISEquipWeaponAction','ISUnequipAction']]
 jars=[args.jar.resolve(),GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar']
 items=[GAME/'media/scripts/generated/items'/name for name in ['weapon.txt','container.txt','clothing.txt','normal.txt']]
 locomotion=ROOT/'mod/42.20/media/lua/client/SAO_Locomotion.lua';routeFixture=HERE/'route_tick.lua'
 inputs=[Path(__file__),HERE/'prelude.lua',HERE/'cases.lua',locomotion,routeFixture,OWNER,PLAN,CTL,probe,*helpers,*native,*sources,*jars,*items,GAME/'media/lua/shared/NPCs/BodyLocations.lua',ROOT/'java/src/com/sao/engine/SAOLeisureActionSource.java']
 absent=installed_presence(inputs,GAME,JDK,'D2 d2_leisure_preparation_test');
 if absent is not None:return absent
 receipt={'status':'INCOMPLETE','boundary':__doc__,'inputsBefore':{str(p):sha(p)for p in inputs},'runs':[],'controls':[]}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
 def run(name,cmd,wd):
  p=subprocess.run(list(map(str,cmd)),cwd=wd,capture_output=True,timeout=100);log=out/(name+'.log');log.write_bytes(p.stdout+p.stderr)
  receipt['runs'].append({'name':name,'exitCode':p.returncode,'log':str(log),'sha256':sha(log)});save()
  return p.returncode,log.read_text(encoding='utf-8',errors='replace')
 try:
  with tempfile.TemporaryDirectory(prefix='sao-preparation-')as d:
   work=Path(d);(work/'stdlib.lua').write_bytes((GAME/'stdlib.lua').read_bytes())
   java=probe.read_text(encoding='utf-8').replace('public final class InstrumentProbe','public final class D2PreparationProbe')
   java=java.replace('IsoCell.class,zombie.iso.IsoGridSquare.class','zombie.core.skinnedmodel.visual.HumanVisual.class,zombie.inventory.types.Clothing.class,zombie.inventory.types.InventoryContainer.class,zombie.inventory.types.HandWeapon.class,zombie.scripting.objects.ItemBodyLocation.class,zombie.scripting.objects.ItemType.class,zombie.characters.WornItems.WornItems.class,zombie.characters.WornItems.BodyLocationGroup.class,zombie.characters.WornItems.BodyLocations.class,zombie.characters.WornItems.BodyLocation.class,\n            IsoCell.class,zombie.iso.IsoGridSquare.class')
   java=java.replace('for(var row:new String[][]{{"normal.txt","Harmonica","__harmonica"},{"normal.txt","Whistle","__whistle"},{"weapon.txt","GuitarAcoustic","__guitar"}})', 'for(var row:new String[][]{{"weapon.txt","DumbBell","__dumbbell"},{"weapon.txt","BarBell","__barbell"},{"container.txt","Bag_Schoolbag","__bag"},{"clothing.txt","WeldingMask","__mask"}})')
   java=java.replace('{"weapon.txt","DumbBell","__dumbbell"}', '{"normal.txt","Generator","__heavy"},{"weapon.txt","DumbBell","__dumbbell"}')
   injection='''for(String name:new String[]{"ISWearClothing","ISEquipWeaponAction","ISUnequipAction"}) {
            String key=("media/lua/shared/TimedActions/"+name+".lua").toLowerCase(java.util.Locale.ENGLISH);
            var relative=zombie.ZomboidFileSystem.class.getDeclaredField("relativeMap");relative.setAccessible(true);
            ((java.util.Map<String,String>)relative.get(zombie.ZomboidFileSystem.instance)).put(key,key);
            zombie.ZomboidFileSystem.instance.activeFileMap.put(key,Path.of(args[0],"media/lua/shared/TimedActions/"+name+".lua").toString());
        }
        env.rawset("__replacement",zombie.inventory.InventoryItemFactory.CreateItem("Base.DumbBell"));
        env.rawset("__tamperRejected",(JavaFunction)(frame,count)->{
            try {
                String key="media/lua/shared/timedactions/isequipweaponaction.lua";
                var fs=zombie.ZomboidFileSystem.instance;
                String original=fs.activeFileMap.get(key);
                var altered=Path.of(args[args.length-1]);
                fs.activeFileMap.put(key,altered.toString());
                boolean rejected=com.sao.engine.SAOLeisureActionSource.read("ISEquipWeaponAction")==null;
                if(original==null)fs.activeFileMap.remove(key);else fs.activeFileMap.put(key,original);
                return frame.push(rejected&&com.sao.engine.SAOLeisureActionSource.read("ISEquipWeaponAction")!=null);
            }catch(Exception e){throw new IllegalStateException(e);}
        });
        '''
   java=java.replace('env.rawset("__body",body);',injection+'env.rawset("__body",body);')
   java=java.replace('i<args.length;i++','i<args.length-1;i++')
   generated=out/'D2PreparationProbe.java';generated.write_text(java,encoding='utf-8')
   cp=os.pathsep.join(map(str,jars));status,log=run('compile',[JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,*helpers,generated],work);assert status==0,log
   ctl=CTL.read_text(encoding='utf-8');ctl=ctl[ctl.index('local LEISURE_WORK_OWNERS'):ctl.index('function Ctl.chooseOrdinaryPurpose')]
   production=OWNER.read_text(encoding='utf-8');planner=PLAN.read_text(encoding='utf-8')
   altered=out/'tampered-native.lua';altered.write_bytes(sources[1].read_bytes()+b'\n-- altered source\n')
   for name,before,after,marker in [('baseline',None,None,None)]+([]if args.baseline_only else CONTROLS):
    ownerText=production;planText=planner;ctlText=ctl
    variantCP=cp
    if before:
     if name=='native-source-hash':
      source=(ROOT/'java/src/com/sao/engine/SAOLeisureActionSource.java').read_text(encoding='utf-8');assert before in source
      mutant=out/'hash-gate-off';mutant.mkdir();path=mutant/'SAOLeisureActionSource.java';path.write_text(source.replace(before,after,1),encoding='utf-8')
      status,log=run('compile-hash-control',[JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',mutant,path],work);assert status==0,log
      variantCP=str(mutant)+os.pathsep+cp
     elif name=='planner-retirement':assert before in planText;planText=planText.replace(before,after)
     elif name=='urgent-preemption':assert before in ctlText;ctlText=ctlText.replace(before,after,1)
     else:
      assert before in ownerText,name;ownerText=ownerText.replace(before,after,1)
      if name=='body-generation':ownerText=ownerText.replace('and a.record.bodyOwner==a.bodyOwner and a.record.bodyOwnerToken==a.ownerToken','and true',1)
      if name=='item-identity':ownerText=ownerText.replace('and self.item==selected','',1)
    variants=[]
    for label,text in [('owner',ownerText),('planner',planText),('controller',ctlText),('reload','__reloadPreparation=function()\n'+ownerText+'\nend\n')]:
     path=out/f'{name}-{label}.lua';path.write_text(text,encoding='utf-8');variants.append(path)
    paths=[HERE/'prelude.lua',*native,locomotion,routeFixture,GAME/'media/lua/shared/NPCs/BodyLocations.lua',variants[1],variants[0],variants[2],variants[3],HERE/'cases.lua',altered]
    status,log=run(name,[JDK/'java.exe','-Duser.home='+str(work),'-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED','-cp',str(work)+os.pathsep+variantCP,'D2PreparationProbe',GAME,*paths],work)
    if marker:
     assert status!=0 and 'PREPARATION:'+marker in log,(name,log[-5000:]);receipt['controls'].append({'name':name,'failedCheck':marker})
    else:
     assert status==0 and 'PASS preparation 'in log,log[-6500:];receipt['checks']=int(log.split('PASS preparation ')[1].splitlines()[0])
   receipt['inputsAfter']={str(p):sha(p)for p in inputs};assert receipt['inputsBefore']==receipt['inputsAfter'],'input drift';receipt['status']='PASS'
 except Exception as error:receipt['failure']=str(error);save();print('FAIL',error);return 1
 save();print('PASS preparation',receipt['checks'],len(receipt['controls']));return 0
if __name__=='__main__':raise SystemExit(main())
