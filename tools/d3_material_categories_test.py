#!/usr/bin/env python3
"""D3 exact native material categories, private carriage, source encoding and persistence.

Installed item scripts/factory, native inventory traversal and Kahlua serialization
are real. World geometry and personal inspection history use controlled fixtures.
This proves material admission, not acquisition or native work completion.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
from native_proof_preflight import installed_presence

ROOT = Path(__file__).resolve().parents[1]
GAME = Path(os.environ.get('PZ_DIR', r'C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid'))
JDK = Path(os.environ.get('JDK_BIN', r'C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin'))
WINDOWS = Path(os.environ.get('SAO_WINDOW_REPAIR_DIR', r'C:/Program Files (x86)/Steam/steamapps/workshop/content/108600/3378304610/mods/RepairableWindows/42.13'))
NEEDS = ROOT/'java/src/com/sao/engine/SAONeeds.java'
WORLD = ROOT/'java/src/com/sao/engine/SAOWorldSources.java'
BRIDGE = ROOT/'java/src/com/sao/bridge/SAOBridge.java'
BUILD = ROOT/'java/src/com/sao/engine/SAOBuild.java'
LUA = ROOT/'mod/42.20/media/lua/shared/SAO_WorldSources.lua'
MATERIAL = ROOT/'mod/42.20/media/lua/shared/SAO_Material.lua'

JAVA = r'''
import com.sao.bridge.SAOBridge;
import com.sao.engine.SAOIsoPlayerShell;
import com.sao.engine.SAONeeds;
import com.sao.engine.SAONativeSnapshot;
import com.sao.engine.SAOPrivateInventory;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import zombie.inventory.InventoryItem;
import zombie.inventory.types.InventoryContainer;
import zombie.iso.IsoCell;
import zombie.scripting.ScriptManager;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.JavaFunction;
import se.krka.kahlua.vm.KahluaTable;

public final class D3MaterialProbe {
    private static int checks;
    private static void check(String name, boolean ok) {
        if (!ok) throw new AssertionError("D3_MATERIALS:"+name);
        checks++; System.out.println("CHECK "+name);
    }
    METADATA
    private static final class FacingWindow extends zombie.iso.objects.IsoWindow {
        private final boolean north;
        FacingWindow(IsoCell cell, boolean north) { super(cell); this.north=north; }
        @Override public boolean getNorth() { return north; }
    }
    private static void nativeFacing(IsoCell cell,SAOIsoPlayerShell body)throws Exception {
        var position=MovementCrossingProbe.class.getDeclaredMethod("position",SAOIsoPlayerShell.class,IsoCell.class,float.class,float.class);
        position.setAccessible(true);
        for(boolean north:new boolean[]{true,false})for(boolean same:new boolean[]{true,false}){
            var square=cell.getGridSquare(10,20,0);
            var window=new FacingWindow(cell,north);window.setSquare(square);square.getObjects().add(window);
            float x=north||same?10.25f:9.75f,y=!north||same?20.25f:19.75f;
            position.invoke(null,body,cell,x,y);
            float side=same?-1:1,dx=north?0:side,dy=north?side:0;
            body.setForwardDirection(-dx,-dy);
            String name=(north?"north":"west")+"_"+(same?"same":"opposite");
            check("native_edge_away_refused_"+name,!com.sao.engine.SAOBuild.canSeeBoardable(body,window));
            body.faceThisObject(window);
            check("native_edge_turn_direction_"+name,Math.abs(body.getForwardDirectionX()-dx)<.001f&&Math.abs(body.getForwardDirectionY()-dy)<.001f);
            check("native_edge_board_facing_"+name,com.sao.engine.SAOBuild.canSeeBoardable(body,window));
            square.getObjects().remove(window);
        }
        position.invoke(null,body,cell,10.5f,20.5f);
    }
    private static String cats(InventoryItem item)throws Exception {
        var cls=Class.forName("com.sao.engine.SAOWorldSources$ItemRow");
        var of=cls.getDeclaredMethod("of",InventoryItem.class);of.setAccessible(true);
        var categories=cls.getDeclaredField("categories");categories.setAccessible(true);
        return String.join(",",(List<String>)categories.get(of.invoke(null,item)));
    }
    private static String source(String kind, String sourceId, InventoryItem... items)throws Exception {
        var itemCls=Class.forName("com.sao.engine.SAOWorldSources$ItemRow");
        var sourceCls=Class.forName("com.sao.engine.SAOWorldSources$Source");
        var snapshotCls=Class.forName("com.sao.engine.SAOWorldSources$Snapshot");
        var of=itemCls.getDeclaredMethod("of",InventoryItem.class);of.setAccessible(true);
        var ctor=sourceCls.getDeclaredConstructor(String.class,String.class,String.class,int.class,int.class,int.class,long.class,boolean.class);ctor.setAccessible(true);
        var source=ctor.newInstance(sourceId,"opaque-fingerprint",kind,10,20,0,42L,true);
        var field=sourceCls.getDeclaredField("items");field.setAccessible(true);
        for(var item:items)((ArrayList<Object>)field.get(source)).add(of.invoke(null,item));
        var finish=sourceCls.getDeclaredMethod("finish");finish.setAccessible(true);finish.invoke(source);
        var snapCtor=snapshotCls.getDeclaredConstructor(int.class,int.class);snapCtor.setAccessible(true);
        var snapshot=snapCtor.newInstance(1,2);
        var add=snapshotCls.getDeclaredMethod("add",sourceCls);add.setAccessible(true);add.invoke(snapshot,source);
        var mode=snapshotCls.getDeclaredField("mode");mode.setAccessible(true);mode.set(snapshot,"native-offscreen");
        var snapFinish=snapshotCls.getDeclaredMethod("finish");snapFinish.setAccessible(true);snapFinish.invoke(snapshot);
        var encode=Class.forName("com.sao.engine.SAOWorldSources").getDeclaredMethod("encode",snapshotCls);encode.setAccessible(true);
        return (String)encode.invoke(null,snapshot);
    }
    public static void main(String[] args)throws Exception {
        Thread.setDefaultUncaughtExceptionHandler((t,e)->{e.printStackTrace();System.exit(1);});
        var boot=MovementCrossingProbe.class.getDeclaredMethod("boot");boot.setAccessible(true);
        var cell=(IsoCell)boot.invoke(null);
        var person=MovementCrossingProbe.class.getDeclaredMethod("person",IsoCell.class);person.setAccessible(true);
        var body=(SAOIsoPlayerShell)person.invoke(null,cell);
        var other=(SAOIsoPlayerShell)person.invoke(null,cell);
        nativeFacing(cell,body);
        var init=ResourceApproachProbe.class.getDeclaredMethod("initFluids");init.setAccessible(true);init.invoke(null);
        var platform=new se.krka.kahlua.j2se.J2SEPlatform();var env=platform.newEnvironment();
        var thread=new se.krka.kahlua.vm.KahluaThread(platform,env);thread.debugOwnerThread=Thread.currentThread();
        zombie.Lua.LuaManager.platform=platform;zombie.Lua.LuaManager.env=env;zombie.Lua.LuaManager.thread=thread;
        LuaCompiler.register(env);
        var dictionary=new MaterialDictionary();
        var data=zombie.world.WorldDictionary.class.getDeclaredField("data");data.setAccessible(true);data.set(null,dictionary);
        var nativeItems=new java.util.HashMap<String,InventoryItem>();short registryId=3100;
        for(var row:Files.readAllLines(Path.of(args[1]))){var fields=row.split("\\t",3);
            var item=material(Path.of(fields[0]),fields[1],fields[2],registryId++,dictionary);nativeItems.put(item.getFullType(),item);}
        var pane=nativeItems.get("RepairableWindows.LargeGlassPane");pane.setID(918273645);
        var hammer=nativeItems.get("Base.Hammer");hammer.setID(87123456);
        check("exact_pane",SAONeeds.wantsMaterial(pane,"glass-pane"));
        for(var type:List.of("Base.GlassPanel","Base.GlassTumbler","RepairableWindows.ClayLargeSheetMold"))
            check("nonpane_"+type,!SAONeeds.wantsMaterial(nativeItems.get(type),"glass-pane"));
        var fragment=new InventoryItem("RepairableWindows","fragment","LargeGlassPaneFragment","fixture");
        check("pane_fragment_refused",!SAONeeds.wantsMaterial(fragment,"glass-pane"));
        for(var type:List.of("Base.Hammer","Base.BallPeenHammer","Base.HammerStone"))
            check("native_hammer_"+type,SAONeeds.wantsMaterial(nativeItems.get(type),"hammer"));
        for(var type:List.of("Base.BallPeenHammerHead","Base.Saw","Base.GlassPanel"))
            check("nonhammer_"+type,!SAONeeds.wantsMaterial(nativeItems.get(type),"hammer"));
        int condition=hammer.getCondition();hammer.setCondition(0);
        check("zero_condition_hammer_refused",!SAONeeds.wantsMaterial(hammer,"hammer"));hammer.setCondition(condition);
        var broken=zombie.inventory.InventoryItem.class.getDeclaredField("broken");broken.setAccessible(true);
        broken.setBoolean(hammer,true);check("broken_hammer_refused",!SAONeeds.wantsMaterial(hammer,"hammer"));broken.setBoolean(hammer,false);
        hammer.setIsCraftingConsumed(true);check("consumed_hammer_refused",!SAONeeds.wantsMaterial(hammer,"hammer"));hammer.setIsCraftingConsumed(false);
        hammer.requiresEquippedBothHands=true;
        check("two_handed_hammer_refused",!SAONeeds.wantsMaterial(hammer,"hammer"));
        check("two_handed_hammer_not_projected",!List.of(cats(hammer).split(",")).contains("hammer"));
        body.getInventory().AddItem(hammer);
        check("two_handed_hammer_not_counted",SAOBridge.INSTANCE.constructionMaterialCount(body,"hammer")==0);
        body.getInventory().Remove(hammer);hammer.requiresEquippedBothHands=false;
        var log=nativeItems.get("Base.Log");log.setID(77110001);
        var saw=nativeItems.get("Base.Saw");saw.setID(77110002);
        check("exact_log",SAONeeds.wantsMaterial(log,"log"));
        check("plank_not_log",!SAONeeds.wantsMaterial(nativeItems.get("Base.Plank"),"log"));
        for(var type:List.of("Base.Saw","Base.GardenSaw"))
            check("native_saw_"+type,SAONeeds.wantsMaterial(nativeItems.get(type),"saw"));
        check("hammer_not_saw",!SAONeeds.wantsMaterial(hammer,"saw"));
        int sawCondition=saw.getCondition();saw.setCondition(0);
        check("zero_condition_saw_refused",!SAONeeds.wantsMaterial(saw,"saw"));saw.setCondition(sawCondition);
        broken.setBoolean(saw,true);check("broken_saw_refused",!SAONeeds.wantsMaterial(saw,"saw"));broken.setBoolean(saw,false);
        saw.setIsCraftingConsumed(true);check("consumed_saw_refused",!SAONeeds.wantsMaterial(saw,"saw"));saw.setIsCraftingConsumed(false);
        log.setIsCraftingConsumed(true);check("consumed_log_refused",!SAONeeds.wantsMaterial(log,"log"));log.setIsCraftingConsumed(false);
        check("source_log_category",List.of(cats(log).split(",")).contains("log"));
        check("source_saw_category",List.of(cats(saw).split(",")).contains("saw"));
        var file=nativeItems.get("Base.File");file.setID(77110003);
        for(var type:List.of("Base.File","Base.SmallFileSet"))
            check("native_file_"+type,SAONeeds.wantsMaterial(nativeItems.get(type),"file"));
        for(var item:List.of(hammer,saw,nativeItems.get("Base.Plank"),nativeItems.get("Base.GlassPanel")))
            check("nonfile_"+item.getFullType(),!SAONeeds.wantsMaterial(item,"file"));
        int fileCondition=file.getCondition();file.setCondition(0);
        check("zero_condition_file_refused",!SAONeeds.wantsMaterial(file,"file"));file.setCondition(fileCondition);
        broken.setBoolean(file,true);check("broken_file_refused",!SAONeeds.wantsMaterial(file,"file"));broken.setBoolean(file,false);
        file.setIsCraftingConsumed(true);check("consumed_file_refused",!SAONeeds.wantsMaterial(file,"file"));file.setIsCraftingConsumed(false);
        check("source_file_category",List.of(cats(file).split(",")).contains("file"));
        var whetstone=nativeItems.get("Base.Whetstone");whetstone.setID(77110004);
        for(var type:List.of("Base.Whetstone","Base.CrudeWhetstone"))
            check("native_whetstone_"+type,SAONeeds.wantsMaterial(nativeItems.get(type),"whetstone"));
        check("file_not_whetstone",!SAONeeds.wantsMaterial(file,"whetstone"));
        int stoneCondition=whetstone.getCondition();whetstone.setCondition(0);
        check("zero_condition_whetstone_refused",!SAONeeds.wantsMaterial(whetstone,"whetstone"));whetstone.setCondition(stoneCondition);
        broken.setBoolean(whetstone,true);check("broken_whetstone_refused",!SAONeeds.wantsMaterial(whetstone,"whetstone"));broken.setBoolean(whetstone,false);
        whetstone.setIsCraftingConsumed(true);check("consumed_whetstone_refused",!SAONeeds.wantsMaterial(whetstone,"whetstone"));whetstone.setIsCraftingConsumed(false);
        check("source_whetstone_category",List.of(cats(whetstone).split(",")).contains("whetstone"));
        check("source_pane_category",cats(pane).contains("glass-pane"));
        check("source_hammer_category",List.of(cats(hammer).split(",")).contains("hammer"));
        var bag=(InventoryContainer)nativeItems.get("Base.Bag_Schoolbag");
        body.getInventory().AddItem(bag);bag.getInventory().AddItem(pane);bag.getInventory().AddItem(hammer);
        bag.getInventory().AddItem(log);bag.getInventory().AddItem(saw);
        bag.getInventory().AddItem(file);bag.getInventory().AddItem(whetstone);
        var plank=nativeItems.get("Base.Plank");var nails=nativeItems.get("Base.Nails");
        body.getInventory().AddItem(plank);bag.getInventory().AddItem(nails);
        var nailsBox=nativeItems.get("Base.NailsBox");other.getInventory().AddItem(nailsBox);
        check("nested_pane_count",SAOBridge.INSTANCE.constructionMaterialCount(body,"glass-pane")==1);
        check("nested_hammer_count",SAOBridge.INSTANCE.constructionMaterialCount(body,"hammer")==1);
        check("nested_log_count",SAOBridge.INSTANCE.constructionMaterialCount(body,"log")==1);
        check("nested_saw_count",SAOBridge.INSTANCE.constructionMaterialCount(body,"saw")==1);
        check("nested_file_count",SAOBridge.INSTANCE.constructionMaterialCount(body,"file")==1);
        check("nested_whetstone_count",SAOBridge.INSTANCE.constructionMaterialCount(body,"whetstone")==1);
        check("plank_count",SAOBridge.INSTANCE.constructionMaterialCount(body,"plank")==1);
        check("nails_count",SAOBridge.INSTANCE.constructionMaterialCount(body,"nails")==1);
        nails.setIsCraftingConsumed(true);
        check("consumed_nails_not_counted",SAOBridge.INSTANCE.constructionMaterialCount(body,"nails")==0);
        nails.setIsCraftingConsumed(false);
        check("nails_box_does_not_satisfy_loose_nails",SAOBridge.INSTANCE.constructionMaterialCount(other,"nails")==0);
        check("other_inventory_not_counted",SAOBridge.INSTANCE.constructionMaterialCount(other,"glass-pane")==0);
        check("unsupported_category_refused",SAOBridge.INSTANCE.constructionMaterialCount(body,"food")==0);
        check("nonbody_refused",SAOBridge.INSTANCE.constructionMaterialCount(pane,"glass-pane")==0);
        var packed=SAONativeSnapshot.capture(body);
        var dormant=SAOPrivateInventory.encodeDormant("opaque-person",packed);
        check("dormant_exact_pane",dormant.contains("id=918273645|type=RepairableWindows.LargeGlassPane"));
        check("dormant_exact_hammer",dormant.contains("id=87123456|type=Base.Hammer"));
        check("dormant_exact_file",dormant.contains("id=77110003|type=Base.File"));
        var restored=(SAOIsoPlayerShell)person.invoke(null,cell);SAONativeSnapshot.restoreStaged(restored,packed);
        check("restored_pane_count",SAOBridge.INSTANCE.constructionMaterialCount(restored,"glass-pane")==1);
        check("restored_hammer_count",SAOBridge.INSTANCE.constructionMaterialCount(restored,"hammer")==1);
        check("restored_log_count",SAOBridge.INSTANCE.constructionMaterialCount(restored,"log")==1);
        check("restored_saw_count",SAOBridge.INSTANCE.constructionMaterialCount(restored,"saw")==1);
        check("restored_file_count",SAOBridge.INSTANCE.constructionMaterialCount(restored,"file")==1);
        check("restored_whetstone_count",SAOBridge.INSTANCE.constructionMaterialCount(restored,"whetstone")==1);
        var snapshot=source("container","C:opaque-material-owner:0",pane,hammer,plank,nails,log,saw,file,whetstone);
        check("offscreen_source_file",snapshot.contains("|q:file=1.000000"));
        check("offscreen_source_pane",snapshot.contains("|q:glass-pane=1.000000"));
        check("offscreen_source_hammer",snapshot.contains("|q:hammer=1.000000"));
        env.rawset("__nativeSnapshot",snapshot);
        env.rawset("__groundPane",source("ground","G:opaque-pane",pane));
        env.rawset("__groundHammer",source("ground","G:opaque-hammer",hammer));
        env.rawset("__groundLog",source("ground","G:opaque-log",log));
        env.rawset("__groundSaw",source("ground","G:opaque-saw",saw));
        env.rawset("__groundFile",source("ground","G:opaque-file",file));
        env.rawset("__groundWhetstone",source("ground","G:opaque-whetstone",whetstone));
        env.rawset("print",(JavaFunction)(f,n)->{System.out.println(f.get(0));return 0;});
        env.rawset("__roundTrip",(JavaFunction)(f,n)->{try{var bytes=java.nio.ByteBuffer.allocate(1024*1024);
            ((KahluaTable)f.get(0)).save(bytes);bytes.flip();var value=platform.newTable();value.load(bytes,249);return f.push(value);
            }catch(Exception e){throw new IllegalStateException(e);}});
        env.rawset("__reloadWorld",(JavaFunction)(f,n)->{try{thread.call(LuaCompiler.loadstring(Files.readString(Path.of(args[3])),"reloaded-world",env),null,null,null);return 0;
            }catch(Exception e){throw new IllegalStateException(e);}});
        for(int i=2;i<args.length;i++)thread.call(LuaCompiler.loadstring(Files.readString(Path.of(args[i])),args[i],env),null,null,null);
        System.out.println("PASS D3 native material categories "+checks);System.exit(0);
    }
}
'''

PRELUDE = r'''
SAO={History={countyHours=function()return 12 end},Log={line=function()end}}
__stores={};ModData={getOrCreate=function(key)__stores[key]=__stores[key]or{};return __stores[key]end,
 get=function(key)return __stores[key]end}
Events=setmetatable({},{__index=function(t,k)local event={Add=function()end,Remove=function()end};rawset(t,k,event);return event end})
local bodyA,bodyB={},{}
local records={a={id="a"},b={id="b"}}
SAO.Identity={get=function(id)return records[id]end}
SAO.Body={get=function(id)return id=="a"and bodyA or bodyB end}
SAO.Standing={mayAttemptBelieved=function()return true end}
__known={};SAO.Perception={knownPlaces=function(id)return __known[id]or{}end}
__bodyA,__bodyB=bodyA,bodyB
'''

CASES = r'''
local W=SAO.WorldSources
local checks=0
local function check(name,ok)assert(ok,"D3_MATERIALS:"..name);checks=checks+1;print("CHECK "..name)end
local parsed=W.parse(__nativeSnapshot)
check("native_snapshot_parses",parsed~=nil)
check("native_snapshot_applies",W.applySnapshot(parsed))
local id="C:opaque-material-owner:0"
local projection=W.sourceProjection(id)
check("source_projection_pane",projection.quantities["glass-pane"]==1 and projection.items["918273645"].categories["glass-pane"])
check("source_projection_hammer",projection.quantities.hammer==1 and projection.items["87123456"].categories.hammer)
projection.quantities["glass-pane"]=40
check("projection_is_detached",W.sourceProjection(id).quantities["glass-pane"]==1)
local place={id=42,cx=12,cy=20,minX=8,minY=16,maxX=16,maxY=24}
local options,why=W.actionOptions(place,"glass-pane","a",__bodyA,1,"standing","acquire")
check("observation_does_not_grant_private_access",not options and why=="not-privately-observed")
local sources,revision,access,facts=W.beliefSnapshot(place)
__known.a={[42]={sources=sources,sourceRevision=revision,sourceAccess=access,sourceFacts=facts}}
options=W.actionOptions(place,"glass-pane","a",__bodyA,1,"standing","acquire")
check("private_pane_option_exact",options and #options.options==1 and options.options[1].parameters.itemId==918273645
 and options.options[1].parameters.sourceId==id and options.options[1].parameters.itemType=="RepairableWindows.LargeGlassPane")
local other,otherWhy=W.actionOptions(place,"glass-pane","b",__bodyB,1,"standing","acquire")
check("second_person_stays_unknown",not other and otherWhy=="not-privately-observed")
local key="SurvivorAwareness_WorldSources"
__stores[key]=__roundTrip(__stores[key]);__known=__roundTrip(__known)
__reloadWorld();W=SAO.WorldSources
local saved=W.sourceProjection(id)
check("saved_pane_category",saved.items["918273645"].categories["glass-pane"] and saved.quantities["glass-pane"]==1)
check("saved_hammer_category",saved.items["87123456"].categories.hammer and saved.quantities.hammer==1)
check("saved_log_category",saved.items["77110001"].categories.log and saved.quantities.log==1)
check("saved_saw_category",saved.items["77110002"].categories.saw and saved.quantities.saw==1)
check("saved_file_category",saved.items["77110003"].categories.file and saved.quantities.file==1)
check("saved_whetstone_category",saved.items["77110004"].categories.whetstone and saved.quantities.whetstone==1)
options=W.actionOptions(place,"hammer","a",__bodyA,1,"standing","acquire")
check("saved_private_hammer_option_exact",options and #options.options==1 and options.options[1].parameters.itemId==87123456)
for _,entry in ipairs({{"log",77110001},{"saw",77110002},{"file",77110003},{"whetstone",77110004}})do
 local own=W.actionOptions(place,entry[1],"a",__bodyA,1,"standing","acquire")
 local other,reason=W.actionOptions(place,entry[1],"b",__bodyB,1,"standing","acquire")
 check("saved_private_option_"..entry[1],own and #own.options==1 and own.options[1].parameters.itemId==entry[2])
 check("other_stays_unknown_"..entry[1],not other and reason=="not-privately-observed")
end
local _,unknownWhy=W.actionOptions(place,"imaginary-material","a",__bodyA,1,"standing","acquire")
check("unknown_category_refused",unknownWhy=="unsupported-category")
for _,entry in ipairs({{__groundPane,"G:opaque-pane","glass-pane",918273645},{__groundHammer,"G:opaque-hammer","hammer",87123456},
 {__groundLog,"G:opaque-log","log",77110001},{__groundSaw,"G:opaque-saw","saw",77110002},{__groundFile,"G:opaque-file","file",77110003},{__groundWhetstone,"G:opaque-whetstone","whetstone",77110004}})do
 check("ground_native_snapshot_applies_"..entry[3],W.applySnapshot(W.parse(entry[1])))
 local fact=W.beliefFact(entry[2],"visible-ground")
 check("ground_private_category_"..entry[3],fact and fact.candidates[entry[3]] and fact.candidates[entry[3]].id==entry[4]
  and fact.quantities[entry[3]]==1 and fact.access=="unknown" and not fact.explored)
end
local receipt={status="completed",reservationId="controlled-material-result",sourceId=id,
 sourceFingerprint="opaque-fingerprint",provisioningGroup="controlled-group",at=12,order=1}
local ok,store=SAO.Material.reconcileSource("controlled-group",receipt,saved,"held-group")
check("material_pane_category",ok and store.categories["glass-pane"]==1 and store.nativeSources[id].items["918273645"].categories["glass-pane"])
check("material_hammer_category",store.categories.hammer==1 and store.nativeSources[id].items["87123456"].categories.hammer)
check("material_log_category",store.categories.log==1 and store.nativeSources[id].items["77110001"].categories.log)
check("material_saw_category",store.categories.saw==1 and store.nativeSources[id].items["77110002"].categories.saw)
check("material_file_category",store.categories.file==1 and store.nativeSources[id].items["77110003"].categories.file)
local persisted=__roundTrip(SAO.Material.stores)
check("material_saved_categories",persisted["house:controlled-group"].categories["glass-pane"]==1 and persisted["house:controlled-group"].categories.hammer==1)
check("material_saved_file",persisted["house:controlled-group"].categories.file==1)
check("material_whetstone_category",store.categories.whetstone==1 and store.nativeSources[id].items["77110004"].categories.whetstone)
check("material_saved_whetstone",persisted["house:controlled-group"].categories.whetstone==1)
print("PASS D3 source material categories "..checks)
'''


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', type=Path, required=True)
    ap.add_argument('--jar', type=Path, default=ROOT/'mod/42.20/media/java/SAO.jar')
    ap.add_argument('--baseline-only', action='store_true')
    ap.add_argument('--portable-maintenance-only', action='store_true', help='Fresh portable means controls; unchanged controls retain prior evidence')
    args = ap.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    jars = [args.jar.resolve(), GAME/'projectzomboid.jar', GAME/'ZombieBuddy.jar', *sorted((GAME/'jars').glob('*.jar'))]
    helpers = [ROOT/'tools/luacheck/MovementCrossingProbe.java', ROOT/'tools/luacheck/ResourceApproachProbe.java']
    metadata = ROOT/'tools/d2_leisure_materials/metadata.java.inc'
    scripts = GAME/'media/scripts/generated/items'
    rows = [(WINDOWS/'media/scripts/RepairableWindows/items.txt', 'RepairableWindows', name)
            for name in ['LargeGlassPane', 'ClayLargeSheetMold']]
    rows += [(scripts/file, 'Base', name) for file,name in [
        ('weapon.txt','Hammer'), ('weapon.txt','BallPeenHammer'), ('weapon.txt','HammerStone'),
        ('normal.txt','BallPeenHammerHead'), ('normal.txt','Saw'), ('normal.txt','GardenSaw'), ('normal.txt','Log'), ('normal.txt','GlassPanel'),
        ('normal.txt','GlassTumbler'), ('weapon.txt','Plank'), ('normal.txt','Nails'),
        ('normal.txt','NailsBox'), ('container.txt','Bag_Schoolbag'), ('weapon.txt','File'), ('normal.txt','SmallFileSet'), ('normal.txt','Whetstone'), ('normal.txt','CrudeWhetstone')]]
    inputs = list(dict.fromkeys([Path(__file__), NEEDS, WORLD, BRIDGE, BUILD, LUA, MATERIAL, metadata,
        ROOT/'java/src/com/sao/engine/SAOPrivateInventory.java', ROOT/'java/src/com/sao/engine/SAONativeSnapshot.java',
        *helpers, *jars, GAME/'stdlib.lua', *[row[0] for row in rows]]))
    absent = installed_presence(inputs, GAME, JDK, 'D3 native material categories', installed_roots=(WINDOWS,))
    if absent is not None:
        return absent
    receipt = {'schema':'sao-d3-material-categories/1', 'status':'INCOMPLETE', 'boundary':__doc__,
               'inputsBefore':{str(p):sha(p) for p in inputs}, 'runs':[], 'controls':[]}
    def save():
        (out/'receipt.json').write_text(json.dumps(receipt, indent=2)+'\n', encoding='utf-8')
    def run(name, command, work):
        result = subprocess.run(list(map(str, command)), cwd=work, capture_output=True, timeout=90)
        log = out/(name+'.log')
        log.write_bytes(result.stdout+result.stderr)
        receipt['runs'].append({'name':name, 'exitCode':result.returncode, 'logSha256':sha(log)})
        save()
        return result.returncode, log.read_text(encoding='utf-8', errors='replace')
    save()
    try:
        table = out/'native-items.tsv'
        table.write_text(''.join(str(file)+'\t'+module+'\t'+name+'\n' for file,module,name in rows), encoding='utf-8')
        generated = out/'D3MaterialProbe.java'
        generated.write_text(JAVA.replace('    METADATA', metadata.read_text()), encoding='utf-8')
        prelude = out/'prelude.lua'; prelude.write_text(PRELUDE, encoding='utf-8')
        cases = out/'cases.lua'; cases.write_text(CASES, encoding='utf-8')
        with tempfile.TemporaryDirectory(prefix='sao-d3-materials-') as temp:
            work = Path(temp)
            shutil.copyfile(GAME/'stdlib.lua', work/'stdlib.lua')
            cp = os.pathsep.join(map(str,jars))
            code, log = run('compile', [JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,*helpers,generated], work)
            assert code == 0, log
            def probe(name, variant=None, owner=LUA, material=MATERIAL):
                classpath = (str(variant)+os.pathsep if variant else '')+str(work)+os.pathsep+cp
                return run(name, [JDK/'java.exe','-Duser.home='+str(work),'-Djava.awt.headless=true',
                    '--enable-native-access=ALL-UNNAMED','-cp',classpath,'D3MaterialProbe',GAME,table,prelude,owner,material,cases], work)
            code, log = probe('baseline')
            assert code == 0 and 'PASS D3 native material categories ' in log and 'PASS D3 source material categories ' in log, log
            if not args.baseline_only:
                controls = [
                    ('fragment',NEEDS,'"RepairableWindows.LargeGlassPane".equals(item.getFullType())',
                     'item.getFullType().startsWith("RepairableWindows.LargeGlassPane")','pane_fragment_refused'),
                    ('glass-tag',NEEDS,'"RepairableWindows.LargeGlassPane".equals(item.getFullType())',
                     '("RepairableWindows.LargeGlassPane".equals(item.getFullType()) || item.hasTag(zombie.scripting.objects.ItemTag.GLASS))','nonpane_Base.GlassPanel'),
                    ('hammer-tag',NEEDS,'item.hasTag(zombie.scripting.objects.ItemTag.HAMMER)',
                     '(item.hasTag(zombie.scripting.objects.ItemTag.HAMMER) || "Tool".equals(item.getDisplayCategory()))','nonhammer_Base.Saw'),
                    # Native setCondition(0) also marks broken; remove the coupled gates together.
                    ('hammer-condition',NEEDS,'&& item.getCondition() > 0 && !item.isBroken()','', 'zero_condition_hammer_refused'),
                    ('hammer-broken',NEEDS,'&& !item.isBroken()','', 'broken_hammer_refused'),
                    ('hammer-two-handed',NEEDS,'&& !item.isRequiresEquippedBothHands()','', 'two_handed_hammer_refused'),
                    ('native-edge-facing',BUILD,
                     'boolean primarySide = here == target || here == edge.getOppositeSquare();',
                     'boolean primarySide = false;',
                     'native_edge_away_refused_north_same'),
                    ('hammer-consumed',NEEDS,'&& !item.getIsCraftingConsumed();',';', 'consumed_hammer_refused'),
                    ('log-type',NEEDS,'"Base.Log".equals(item.getFullType())','true','plank_not_log'),
                    ('log-consumed',NEEDS,'&& !item.getIsCraftingConsumed();',';','consumed_log_refused'),
                    ('saw-tag',NEEDS,'item.hasTag(zombie.scripting.objects.ItemTag.SAW)',
                     'true','hammer_not_saw'),
                    ('saw-condition',NEEDS,'&& item.getCondition() > 0 && !item.isBroken()','', 'zero_condition_saw_refused'),
                    ('saw-broken',NEEDS,'&& !item.isBroken()','', 'broken_saw_refused'),
                    ('saw-consumed',NEEDS,'&& !item.getIsCraftingConsumed();',';', 'consumed_saw_refused'),
                    ('file-tag',NEEDS,'item.hasTag(zombie.scripting.objects.ItemTag.FILE)','true','nonfile_Base.Hammer'),
                    ('file-condition',NEEDS,'&& item.getCondition() > 0 && !item.isBroken()','', 'zero_condition_file_refused'),
                    ('file-broken',NEEDS,'&& !item.isBroken()','', 'broken_file_refused'),
                    ('file-consumed',NEEDS,'&& !item.getIsCraftingConsumed();',';', 'consumed_file_refused'),
                    ('pane-source',WORLD,'if (SAONeeds.wantsMaterial(item, "glass-pane")) out.add("glass-pane");','', 'source_pane_category'),
                    ('hammer-source',WORLD,'if (SAONeeds.wantsMaterial(item, "hammer")) out.add("hammer");','', 'source_hammer_category'),
                    ('log-source',WORLD,'if (SAONeeds.wantsMaterial(item, "log")) out.add("log");','', 'source_log_category'),
                    ('saw-source',WORLD,'if (SAONeeds.wantsMaterial(item, "saw")) out.add("saw");','', 'source_saw_category'),
                    ('file-source',WORLD,'if (SAONeeds.wantsMaterial(item, "file")) out.add("file");','', 'source_file_category'),
                    ('file-count',BRIDGE,'|| category.equals("file")','', 'nested_file_count'),
                    ('recursive-count',BRIDGE,'com.sao.engine.SAOPrivateInventory.carriedItems(person)) {',
                     'new java.util.ArrayList<>(person.getInventory().getItems())) {','nested_pane_count'),
                    ('boxed-nails-count',BRIDGE,'&& (!category.equals("nails")\n                            || "Base.Nails".equals(item.getFullType()))','',
                     'nails_box_does_not_satisfy_loose_nails'),
                ]
                portable_controls = [
                    ('whetstone-tag',NEEDS,'item.hasTag(zombie.scripting.objects.ItemTag.WHETSTONE)','true','file_not_whetstone'),
                    ('whetstone-condition',NEEDS,'&& item.getCondition() > 0 && !item.isBroken()','','zero_condition_whetstone_refused'),
                    ('whetstone-consumed',NEEDS,'&& !item.getIsCraftingConsumed();',';','consumed_whetstone_refused'),
                    ('whetstone-source',WORLD,'if (SAONeeds.wantsMaterial(item, "whetstone")) out.add("whetstone");','','source_whetstone_category'),
                    ('whetstone-count',BRIDGE,'|| category.equals("whetstone")','','nested_whetstone_count'),
                ]
                controls = portable_controls if args.portable_maintenance_only else controls + portable_controls
                for name,source,old,new,marker in controls:
                    production = source.read_text(encoding='utf-8')
                    start, end = 0, len(production)
                    if source == NEEDS and name.split('-')[0] in ('hammer', 'saw', 'log', 'file', 'whetstone'):
                        start = production.index('case "'+name.split('-')[0]+'":')
                        end = production.index('case ', start + 6)
                    target = production[start:end]
                    assert target.count(old) == 1, (name,target.count(old))
                    variant = out/name; variant.mkdir()
                    mutated = variant/source.name
                    mutated.write_text(production[:start]+target.replace(old,new,1)+production[end:], encoding='utf-8')
                    code, log = run(name+'-compile',[JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',variant,mutated],work)
                    assert code == 0, log
                    code, log = probe(name,variant)
                    assert code != 0 and 'D3_MATERIALS:'+marker in log, (name,log)
                    receipt['controls'].append({'name':name,'expectedFailure':marker})
                owner = out/'without-pane-admission.lua'
                production = LUA.read_text(encoding='utf-8')
                assert production.count('"glass-pane", "hammer",') == 1
                owner.write_text(production.replace('"glass-pane", "hammer",','"hammer",',1), encoding='utf-8')
                code, log = probe('lua-pane-admission',owner=owner)
                assert code != 0 and 'D3_MATERIALS:native_snapshot_parses' in log, log
                receipt['controls'].append({'name':'lua-pane-admission','expectedFailure':'native_snapshot_parses'})
                ground = out/'without-ground-materials.lua'
                old = '"glass-pane","hammer","plank","nails"'
                assert production.count(old) == 1
                ground.write_text(production.replace(old,'"plank","nails"',1), encoding='utf-8')
                code, log = probe('ground-pane-admission',owner=ground)
                assert code != 0 and 'D3_MATERIALS:ground_private_category_glass-pane' in log, log
                receipt['controls'].append({'name':'ground-pane-admission','expectedFailure':'ground_private_category_glass-pane'})
                material = out/'without-material-pane.lua'
                production = MATERIAL.read_text(encoding='utf-8')
                assert production.count('"glass-pane", "hammer",') == 1
                material.write_text(production.replace('"glass-pane", "hammer",','"hammer",',1), encoding='utf-8')
                code, log = probe('material-pane-admission',material=material)
                assert code != 0 and 'D3_MATERIALS:material_pane_category' in log, log
                receipt['controls'].append({'name':'material-pane-admission','expectedFailure':'material_pane_category'})
                for name, source, old, new, marker, key in (
                    ('lua-file-admission', LUA, '"drink", "file", "food"', '"drink", "food"', 'native_snapshot_parses', 'owner'),
                    ('ground-file-admission', LUA, '"nails","log","saw","file",', '"nails","log","saw",', 'ground_private_category_file', 'owner'),
                    ('material-file-admission', MATERIAL, '"drink", "file", "food"', '"drink", "food"', 'material_file_category', 'material'),
                    ('lua-whetstone-admission', LUA, '"water", "weapons", "whetstone"', '"water", "weapons"', 'native_snapshot_parses', 'owner'),
                    ('ground-whetstone-admission', LUA, '"file","whetstone"', '"file"', 'ground_private_category_whetstone', 'owner'),
                    ('material-whetstone-admission', MATERIAL, '"tools", "whetstone"', '"tools"', 'material_whetstone_category', 'material'),
                ):
                    production = source.read_text(encoding='utf-8')
                    assert production.count(old) == 1, (name, production.count(old))
                    variant = out/(name+'.lua')
                    variant.write_text(production.replace(old,new,1), encoding='utf-8')
                    code, log = probe(name, **{key:variant})
                    assert code != 0 and 'D3_MATERIALS:'+marker in log, (name,log)
                    receipt['controls'].append({'name':name,'expectedFailure':marker})
            receipt['inputsAfter'] = {str(p):sha(p) for p in inputs}
            assert receipt['inputsAfter'] == receipt['inputsBefore'], 'changed input during proof'
            receipt['status'] = 'PASS';save()
            print('PASS D3 material categories; controls='+str(len(receipt['controls'])))
            return 0
    except Exception as error:
        receipt['status'] = 'FAIL';receipt['error'] = str(error);save()
        print('FAIL D3 material categories: '+str(error))
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
