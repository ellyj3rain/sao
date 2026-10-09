#!/usr/bin/env python3
"""Actual native off-slot body/items/action elapsed lifecycle with original NM slots/intents/catalogue. Headless queue dispatch and audio hardware controlled."""
from pathlib import Path
import argparse,json,os,re,shutil,subprocess,tempfile
import d2_leisure_music_test as music
from native_proof_preflight import installed_presence
import d2_leisure_music.world_audio_test as world
ROOT=music.ROOT;HERE=ROOT/'tools/d2_music_supply';SUPPLY=ROOT/'mod/42.20/media/lua/client/SAO_LeisureMusicSupply.lua'
EXTRA=['shared/contracts/NMMediaContract.lua','shared/contracts/NMCoverViewResolver.lua',
'shared/slot/NMInventoryHelpers.lua','shared/helpers/NMMediaHelpers.lua','shared/slot/NMInsertedHeadphonePolicy.lua','shared/slot/NMWorldItemVisuals.lua',
'shared/music/NMTrackCatalog.lua','shared/music/NMAlbumPackBuilder.lua','shared/music/NMProjectZomboidOST.lua',
'client/ui/shared/slots/NMBatterySlotTimedAction.lua','client/ui/shared/slots/NMMediaSlotTimedAction.lua','client/ui/shared/slots/NMHeadphoneSlotTimedAction.lua']
MODULES=music.NM_PROOF_FILES+['shared/contracts/NMMediaContract.lua','shared/slot/NMInventoryHelpers.lua','shared/helpers/NMMediaHelpers.lua','shared/slot/NMInsertedHeadphonePolicy.lua','shared/slot/NMWorldItemVisuals.lua','shared/music/NMTrackCatalog.lua','shared/music/NMAlbumPackBuilder.lua','shared/music/NMProjectZomboidOST.lua']+music.NM_FILES+world.EXTRA

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--out',type=Path,required=True);ap.add_argument('--jar',type=Path,default=ROOT/'mod/42.20/media/java/SAO.jar');ap.add_argument('--baseline-only',action='store_true');ap.add_argument('--controls',help='Comma-separated scoped restored controls (baseline always runs)');a=ap.parse_args()
 out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
 jars=[a.jar.resolve(),music.GAME/'projectzomboid.jar',music.GAME/'ZombieBuddy.jar',*sorted((music.GAME/'jars').glob('*.jar'))]
 probe=ROOT/'tools/instrument_checks/InstrumentProbe.java';helpers=[ROOT/'tools/luacheck/MovementCrossingProbe.java',ROOT/'tools/luacheck/ResourceApproachProbe.java',ROOT/'tools/cognition_checks/CognitionUseProbe.java']
 native=[music.GAME/'media/lua/shared/ISBaseObject.lua',music.GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua',music.GAME/'media/lua/shared/NPCs/BodyLocations.lua']
 allNM=list(dict.fromkeys(music.NM_FILES+music.NM_PROOF_FILES+EXTRA+world.EXTRA))
 entries=[(music.GAME/'media/scripts/generated/items'/f,'Base',n)for f,n in [('drainable.txt','Battery'),('normal.txt','Headphones'),('normal.txt','Earbuds'),('drainable.txt','CarBattery1'),('radio.txt','RadioBlack')]]
 entries +=[(music.NM.parent/'scripts'/'ZZZ_NM_Headphones_Override.txt','Base','Headphones')]
 entries +=[(music.NM.parent/'scripts'/f,'NewMusic',n)for f,n in [('NM_Walkman_Items.txt','WalkmanBlue'),('NM_Boombox_Items.txt','BoomboxBlue'),('NM_ProjectZomboidOST_Items.txt','CassettePZOSTA')]]
 inputs=[Path(__file__),Path(music.__file__),Path(world.__file__),ROOT/"java/src/com/sao/engine/SAOLeisureMaterials.java",music.OWNER,SUPPLY,world.WORLD,ROOT/'mod/42.20/media/lua/shared/SAO_ProceduralPlanning.lua',ROOT/'mod/42.20/media/lua/client/SAO_LeisureAcquisition.lua',HERE/'cases.lua',HERE/'metadata.java.inc',probe,*helpers,music.FIXTURES/'prelude.lua',*native,*jars,music.GAME/'stdlib.lua',music.GAME/'media/clothing/clothingItems/Hat_EarMuffs.xml',*[p for p,m,n in entries],*[music.LS/p for p in music.LS_FILES],*[music.NM/p for p in allNM]]
 absent=installed_presence(inputs,music.GAME,music.JDK,'D2 native NewMusic source supply',installed_roots=(music.LS.parent,music.NM.parent));
 if absent is not None:return absent
 receipt={'schema':'sao-d2-music-supply/1','status':'INCOMPLETE','boundary':__doc__,'inputsBefore':{str(p):music.sha(p)for p in inputs},'runs':[],'controls':[]}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
 def run(name,cmd,work):
  p=subprocess.run(list(map(str,cmd)),cwd=work,capture_output=True,timeout=90);log=out/(name+'.log');log.write_bytes(p.stdout+p.stderr);receipt['runs'].append({'name':name,'exitCode':p.returncode,'logSha256':music.sha(log)});save();return p.returncode,log.read_text(errors='replace')
 try:
  manifest=out/'source-paths.tsv';manifest.write_text(''.join('LifestyleHobbies:'+p+'\t'+str(music.LS/p)+'\n'for p in music.LS_FILES)+''.join('NewMusic:'+p+'\t'+str(music.NM/p)+'\n'for p in allNM)+'own:planner\t'+str(ROOT/'mod/42.20/media/lua/shared/SAO_ProceduralPlanning.lua')+'\n'+'own:acquisition\t'+str(ROOT/'mod/42.20/media/lua/client/SAO_LeisureAcquisition.lua')+'\n'+'own:supply\t'+str(SUPPLY)+'\n'+'own:music\t'+str(music.OWNER)+'\n')
  table=out/'native-items.tsv';table.write_text(''.join(str(f)+'\t'+m+'\t'+n+'\n'for f,m,n in entries))
  modules=out/'modules.lua';modules.write_text('__nmModules='+ '{'+','.join(json.dumps(p)for p in MODULES)+'}\n')
  java=probe.read_text().replace('public final class InstrumentProbe','public final class MusicSupplyProbe')
  java=java.replace('public static void main(String[] args)throws Exception{',(HERE/'metadata.java.inc').read_text()+'\npublic static void main(String[] args)throws Exception{\nThread.setDefaultUncaughtExceptionHandler((t,e)->{e.printStackTrace();System.exit(1);});')
  java=java.replace('public static void main(String[] args)throws Exception{',"""public static long nativeFaultItem=-1;
    public static final class NativeRemoveFault {
        @net.bytebuddy.asm.Advice.OnMethodEnter public static void enter(@net.bytebuddy.asm.Advice.Argument(0) InventoryItem it){if(it!=null&&it.getID()==nativeFaultItem)throw new IllegalStateException("controlled-native-item-removal-fault");}
    }
    public static void main(String[] args)throws Exception{
        var instrumentation=net.bytebuddy.agent.ByteBuddyAgent.install();
        new net.bytebuddy.agent.builder.AgentBuilder.Default().disableClassFormatChanges().with(net.bytebuddy.agent.builder.AgentBuilder.RedefinitionStrategy.RETRANSFORMATION)
            .type(net.bytebuddy.matcher.ElementMatchers.named("zombie.inventory.ItemContainer"))
            .transform((builder,type,loader,module,domain)->builder.visit(net.bytebuddy.asm.Advice.to(NativeRemoveFault.class).on(net.bytebuddy.matcher.ElementMatchers.named("DoRemoveItem").and(net.bytebuddy.matcher.ElementMatchers.takesArguments(zombie.inventory.InventoryItem.class))))).installOn(instrumentation);
        """)
  java=java.replace('InventoryItem.class,zombie.inventory.ItemContainer.class','zombie.scripting.ScriptManager.class,zombie.characters.AttachedItems.AttachedItems.class,zombie.characters.AttachedItems.AttachedItem.class,zombie.characters.WornItems.WornItems.class,zombie.characters.WornItems.WornItem.class,zombie.scripting.objects.ItemBodyLocation.class,zombie.inventory.types.DrainableComboItem.class,InventoryItem.class,zombie.inventory.ItemContainer.class')
  java=java.replace('IsoCell.class,zombie.iso.IsoGridSquare.class','zombie.core.skinnedmodel.visual.ItemVisual.class,zombie.core.skinnedmodel.population.ClothingItem.class,zombie.core.skinnedmodel.visual.HumanVisual.class,zombie.inventory.types.Clothing.class,zombie.characters.WornItems.BodyLocationGroup.class,zombie.characters.WornItems.BodyLocations.class,zombie.characters.WornItems.BodyLocation.class,zombie.vehicles.BaseVehicle.class,zombie.vehicles.VehiclePart.class,zombie.radio.devices.DeviceData.class,zombie.iso.objects.IsoWorldInventoryObject.class,IsoCell.class,zombie.iso.IsoGridSquare.class')
  injection="""
        LuaCompiler.register(env);env.rawset("__bridge",SAOBridge.INSTANCE);env.rawset("__stats",body.getStats());env.rawset("__nativeBody",body);env.rawset("__nativeinstanceof",env.rawget("instanceof"));
        var materialDictionary=new MaterialDictionary();data.set(null,materialDictionary);short materialId=3100;
        for(var row:Files.readAllLines(Path.of(TABLE))){var p=row.split("\\t",3);material(Path.of(p[0]),p[1],p[2],materialId++,materialDictionary);}
        var clothXML=zombie.util.PZXmlUtil.parse(zombie.core.skinnedmodel.population.ClothingItemXML.class,Path.of(args[0],"media/clothing/clothingItems/Hat_EarMuffs.xml").toString());
        var cloth=new zombie.core.skinnedmodel.population.ClothingItem(new zombie.asset.AssetPath("Hat_EarMuffs"),zombie.core.skinnedmodel.population.ClothingItemAssetManager.instance);
        var loadedCloth=zombie.core.skinnedmodel.population.ClothingItemAssetManager.class.getDeclaredMethod("onFileTaskFinished",zombie.core.skinnedmodel.population.ClothingItem.class,Object.class);loadedCloth.setAccessible(true);loadedCloth.invoke(zombie.core.skinnedmodel.population.ClothingItemAssetManager.instance,cloth,clothXML);
        cloth.onCreated(zombie.asset.Asset.State.READY);cloth.mame="Hat_EarMuffs";ScriptManager.instance.FindItem("Base.Headphones").setClothingItemAsset(cloth);System.out.println("ACTUAL_CLOTH_READY "+cloth.isReady()+" XML_GUID="+cloth.guid+" "+cloth.getTextureChoices());
        env.rawset("__scriptManager",ScriptManager.instance);
        env.rawset("__roundtrip",(JavaFunction)(f,n)->{try{var bytes=java.nio.ByteBuffer.allocate(1048576);((se.krka.kahlua.vm.KahluaTable)f.get(0)).save(bytes);bytes.flip();var restored=platform.newTable();restored.load(bytes,249);return f.push(restored);}catch(Exception e){throw new IllegalStateException(e);}});
        var sources=platform.newTable();for(var row:Files.readAllLines(Path.of(MANIFEST))){var p=row.split("\\t",2);sources.rawset(p[0],Files.readString(Path.of(p[1])).replace("\\r\\n","\\n"));}env.rawset("__sources",sources);
        env.rawset("__placed",(JavaFunction)(f,n)->{var movedItem=(InventoryItem)f.get(0);body.getInventory().DoRemoveItem(movedItem);var obj=new zombie.iso.objects.IsoWorldInventoryObject(cell);obj.item=movedItem;obj.setSquare(body.getCurrentSquare());body.getCurrentSquare().getWorldObjects().add(obj);movedItem.setWorldItem(obj);return f.push(obj);});
        env.rawset("__vehicleSource",(JavaFunction)(f,n)->{try{
            var vehicleItem=(InventoryItem)f.get(0);body.getInventory().DoRemoveItem(vehicleItem);
            var vehicle=new zombie.vehicles.BaseVehicle(cell);vehicle.vehicleId=74;vehicle.sqlId=8312;
            var sq=body.getCurrentSquare();vehicle.setSquare(sq);vehicle.setCurrent(sq);vehicle.setX(body.getX());vehicle.setY(body.getY());vehicle.setZ(body.getZ());
            var part=new zombie.vehicles.VehiclePart(vehicle);var definition=new zombie.scripting.objects.VehicleScript.Part();definition.id="Radio";part.setScriptPart(definition);vehicle.getParts().add(part);
            var itemField=zombie.vehicles.VehiclePart.class.getDeclaredField("item");itemField.setAccessible(true);itemField.set(part,vehicleItem);part.setDeviceData(new zombie.radio.devices.DeviceData(part));
            var batteryPart=new zombie.vehicles.VehiclePart(vehicle);var batteryDefinition=new zombie.scripting.objects.VehicleScript.Part();batteryDefinition.id="Battery";batteryPart.setScriptPart(batteryDefinition);vehicle.getParts().add(batteryPart);
            var battery=zombie.inventory.InventoryItemFactory.CreateItem("Base.CarBattery1");((zombie.inventory.types.DrainableComboItem)battery).setCurrentUsesFloat(.8f);itemField.set(batteryPart,battery);
            var passengersField=zombie.vehicles.BaseVehicle.class.getDeclaredField("passengers");passengersField.setAccessible(true);passengersField.set(vehicle,new zombie.vehicles.BaseVehicle.Passenger[]{new zombie.vehicles.BaseVehicle.Passenger()});
            if(!vehicle.setPassenger(0,body,new org.joml.Vector3f()))throw new AssertionError("native passenger admission");body.setVehicle(vehicle);cell.getVehicles().add(vehicle);
            var target=platform.newTable();target.rawset("vehicle",vehicle);target.rawset("part",part);return f.push(target);
        }catch(Exception e){throw new IllegalStateException(e);}});
        env.rawset("getCell",(JavaFunction)(f,n)->f.push(cell));
        final int[] nextItem={5000};env.rawset("__newItem",(JavaFunction)(f,n)->{var it=zombie.inventory.InventoryItemFactory.CreateItem((String)f.get(0));it.setID(nextItem[0]++);return f.push(it);});
        env.rawset("__nativeQueue",(JavaFunction)(f,n)->{var row=(se.krka.kahlua.vm.KahluaTable)f.get(0);var actor=(SAOIsoPlayerShell)row.rawget("character");var action=new zombie.characters.CharacterTimedActions.LuaTimedActionNew(row,actor);row.rawset("action",action);actor.StartAction(action);return 0;});
        env.rawset("__nativeRemoveFault",(JavaFunction)(f,n)->{nativeFaultItem=((Number)f.get(0)).longValue();return 0;});
        env.rawset("__forceStopped",(JavaFunction)(f,n)->f.push(((zombie.characters.CharacterTimedActions.BaseAction)f.get(0)).forceStop));
        env.rawset("__nativeUpdate",(JavaFunction)(f,n)->{if(!body.getCharacterActions().isEmpty())body.getCharacterActions().get(0).update();return 0;});
        env.rawset("__nativePerform",(JavaFunction)(f,n)->{if(!body.getCharacterActions().isEmpty()){var action=body.getCharacterActions().get(0);if(action.getJobDelta()>=.999999){action.perform();action.complete();body.getCharacterActions().remove(action);}}return 0;});
        """.replace('TABLE',json.dumps(str(table))).replace('MANIFEST','args[1]')
  java=java.replace('env.rawset("__body",body);',injection+'env.rawset("__body",body);')
  java=java.replace('for(int i=1;i<args.length;i++){','for(int i=2;i<args.length;i++){')
  java=java.replace('System.out.println("INSTRUMENT_NATIVE_DONE");','System.out.println("INSTRUMENT_NATIVE_DONE");System.exit(0);')
  generated=out/'MusicSupplyProbe.java';generated.write_text(java)
  with tempfile.TemporaryDirectory(prefix='sao-music-supply-')as tmp:
   work=Path(tmp);shutil.copyfile(music.GAME/'stdlib.lua',work/'stdlib.lua');cp=os.pathsep.join(map(str,jars))
   code,log=run('compile',[music.JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,*helpers,generated],work);assert code==0,log
   setup=out/'native-setup.lua';setup.write_text('ScriptManager={instance=__scriptManager};instanceof=__nativeinstanceof\n')
   production={'supply':SUPPLY.read_text(),'music':music.OWNER.read_text()}
   variants=[('baseline',None,None,None,None)]+([]if a.baseline_only else [
    ('purpose','music','if not admission or admission.ownerName~=OWNER or admission.sequence~=w.sequence then return nil end','if false then return nil end','retired_purpose_no_original_dispatch'),
    ('elapsed','supply','native:getJobDelta()>=.999999','native:getJobDelta()>=0','partial_native_elapsed_cannot_dispatch'),
    ('item','supply','resolve(a.body,a.selection.media.itemKey)~=a.media or not same','resolve(a.body,a.selection.media.itemKey)==nil or not same','native_same_ID_replacement_refused'),
    ('state','supply','local function stateSame(a)return same(a.expectedState,a.export(a.deviceState))end','local function stateSame(a)return true end','changed_source_no_original_dispatch'),
    ('revision','supply','h1~=pin[2]or h2~=pin[3]or #lines~=pin[4]','false ','changed_source_refused'),
    ('orphan','supply','if runtime[id]then return false end\n local r=record(id);local saved=r and r.leisureMusicSupplyWork','if true then return false end\n local r=record(id);local saved=r and r.leisureMusicSupplyWork','orphan_partial_saved_steps_retained'),
    ('ejection','supply','producedBattery=producedBattery,selection=','producedBattery=nil,selection=','ejected_native_battery_receipt'),
    ('native-stop','supply','if a.action and a.action.action then pcall(a.action.action.forceStop,a.action.action)end','do end','partial_stop_preserves_queue_follower'),
    ('fresh-source','music','local queried,rows=pcall(candidates,id,body,false,a)','local queried,rows=true,M.offers(id,body)','fresh_offer_original_playback_after_slots'),
    ('dance-source-requirement','music','sourceRequirement.requirementId=original',
     'sourceRequirement.requirementId=row.requirementId','native_missing_supplies_admit_dance_acquisition'),
   ])
   if a.controls:
    requested=set(a.controls.split(','));allowed={row[0]for row in variants}|{'carrier-omitted'};assert requested<=allowed,requested-allowed
    variants=[row for row in variants if row[0]=='baseline' or row[0]in requested]
   def execute(name,ownerSupply,ownerMusic,extraCP=None):
    content=manifest.read_text().replace('own:supply\t'+str(SUPPLY),'own:supply\t'+str(ownerSupply)).replace('own:music\t'+str(music.OWNER),'own:music\t'+str(ownerMusic))
    activeManifest=out/(name+'-manifest.tsv');activeManifest.write_text(content)
    paths=[music.GAME,activeManifest,music.FIXTURES/'prelude.lua',setup,*native,music.LS/'shared/LSUtil.lua',ownerSupply,world.WORLD,ownerMusic,modules,HERE/'cases.lua']
    classpath=(str(extraCP)+os.pathsep if extraCP else '')+str(work)+os.pathsep+cp
    return run(name,[music.JDK/'java.exe','-Duser.home='+str(work),'-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED','-cp',classpath,'MusicSupplyProbe',*paths],work)
   for name,family,old,new,marker in variants:
    ownerSupply,ownerMusic=SUPPLY,music.OWNER
    if family:
     text=production[family];assert text.count(old)==1,(name,text.count(old));text=text.replace(old,new,1)
     path=out/(name+'-'+family+'.lua');path.write_text(text)
     if family=='supply':ownerSupply=path
     else:ownerMusic=path
    code,log=execute(name,ownerSupply,ownerMusic)
    if marker:assert code!=0 and 'D2_MUSIC_SUPPLY:'+marker in log,(name,log[-9000:]);receipt['controls'].append({'name':name,'expectedFailure':marker})
    else:assert code==0 and 'PASS D2 native Music supply 'in log,log[-18000:];receipt['checks']=int(re.search(r'PASS D2 native Music supply (\d+)',log)[1])
    print(name+': PASS',flush=True)
   if not a.baseline_only and(not a.controls or 'carrier-omitted'in requested):
    nativeSource=ROOT/'java/src/com/sao/engine/SAOLeisureMaterials.java';text=nativeSource.read_text();old='if(value!=null)row.rawset(field,value);';assert text.count(old)==1
    broken=out/'carrier-omitted';broken.mkdir();src=broken/'SAOLeisureMaterials.java';src.write_text(text.replace(old,'if(value!=null&&!field.equals("carrier"))row.rawset(field,value);'))
    code,log=run('carrier-compile',[music.JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',broken,src],work);assert code==0,log
    code,log=execute('carrier-omitted',SUPPLY,music.OWNER,broken)
    assert code!=0 and 'D2_MUSIC_SUPPLY:native_aggregate_preserves_private_carrier'in log,log[-9000:]
    receipt['controls'].append({'name':'carrier-omitted','expectedFailure':'native_aggregate_preserves_private_carrier'});print('carrier-omitted: PASS',flush=True)

  receipt['inputsAfter']={str(p):music.sha(p)for p in inputs};assert receipt['inputsBefore']==receipt['inputsAfter'],'inputs changed during proof'
  receipt['status']='PASS';save();print('PASS D2 Music supply',receipt['checks']);return 0
 except Exception as e:receipt['status']='FAIL';receipt['error']=str(e);save();raise
if __name__=='__main__':raise SystemExit(main())
