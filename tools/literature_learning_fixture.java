import com.sao.engine.SAOIsoPlayerShell;
import java.nio.ByteBuffer;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.regex.Pattern;
import se.krka.kahlua.vm.*;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.j2se.J2SEPlatform;
import zombie.inventory.*;
import zombie.inventory.types.Literature;
import zombie.scripting.*;
import zombie.scripting.objects.*;
import zombie.world.*;

/** Test-only native carriers, actions and save/load; source selection, actors,
 * scheduling, native presentation/audio receivers and world clock are controlled. */
class LiteratureFixture {
 static final class Info extends ItemInfo {
  Info(Item item,short id){name=item.getName();moduleName="SAO";fullType="SAO."+name;
   registryId=id;isLoaded=true;scriptItem=item;entityScript=item;modId="SurvivorAwareness";}
 }
 static final class Dictionary extends DictionaryData {
  void register(Item item,short id){var info=new Info(item,id);itemIdToInfoMap.put(id,info);itemTypeToInfoMap.put(info.getFullType(),info);}
 }
 static void install(KahluaTable env,SAOIsoPlayerShell body,SAOIsoPlayerShell other,
   KahluaThread thread,Path ownedScript)throws Exception {
  var dictionary=new Dictionary();var data=WorldDictionary.class.getDeclaredField("data");data.setAccessible(true);data.set(null,dictionary);
  var module=new ScriptModule();module.name="SAO";module.imports.add("Base");ScriptManager.instance.moduleMap.put("SAO",module);
  for(var field:ScriptManager.class.getDeclaredFields())if(ScriptBucketCollection.class.isAssignableFrom(field.getType())){
   field.setAccessible(true);((ScriptBucketCollection<?>)field.get(ScriptManager.instance)).registerModule(module);
  }
  String text=ScriptParser.stripComments(Files.readString(ownedScript));short id=7100;
  for(String name:new String[]{"BuildingsRoutesUpkeep_Civilian","BuildingsRoutesUpkeep_Engineering","BuildingsRoutesUpkeep_Military"}){
   var match=Pattern.compile("\\bitem\\s+"+name+"\\s*\\{").matcher(text);if(!match.find())throw new AssertionError(name);
   int end=match.end(),depth=1;while(depth>0){char c=text.charAt(end++);if(c=='{')depth++;if(c=='}')depth--;}
   var definition=new Item();definition.setModule(module);definition.setName(name);definition.Load(name,text.substring(match.start(),end));
   definition.setRegistry_id(id);module.items.getScriptMap().put(name,definition);dictionary.register(definition,id++);
  }
  env.rawset("__newPamphlet",(JavaFunction)(frame,count)->{
   var value=InventoryItemFactory.CreateItem("SAO.BuildingsRoutesUpkeep_"+frame.get(0));
   if(!(value instanceof Literature))throw new AssertionError("Native literature type");
   if(!"SAO_Literature_OnCreate".equals(value.getLuaCreate()))throw new AssertionError("Native OnCreate binding");
   value.initialiseItem();return frame.push(value);
  });
  env.rawset("__literalHash",(JavaFunction)(frame,count)->{
   try{return frame.push(java.util.HexFormat.of().formatHex(java.security.MessageDigest.getInstance("SHA-256")
    .digest(((String)frame.get(0)).getBytes(java.nio.charset.StandardCharsets.UTF_8))));}
   catch(Exception e){throw new IllegalStateException(e);}
  });
  env.rawset("__nativeSpatialContext",(JavaFunction)(frame,count)->{
   try{
    var cell=body.getCell();var regions=zombie.iso.areas.isoregion.IsoRegions.class.getDeclaredField("dataRoot");
    regions.setAccessible(true);regions.set(null,new zombie.iso.areas.isoregion.data.DataRoot());
    var building=new zombie.iso.areas.IsoBuilding(cell);building.def=new zombie.iso.BuildingDef();building.def.id=316;
    var occupied=new zombie.iso.areas.IsoRoom();occupied.def=new zombie.iso.RoomDef(3161,"occupied-room");
    occupied.def.setBuilding(building.def);occupied.building=building;occupied.roomDef="occupied-room";
    var beyond=new zombie.iso.areas.IsoRoom();beyond.def=new zombie.iso.RoomDef(3162,"unseen-room");
    beyond.def.setBuilding(building.def);beyond.building=building;beyond.roomDef="unseen-room";
    for(int x=9;x<=11;x++)for(int y=19;y<=21;y++){
     var sq=cell.getGridSquare(x,y,0);sq.setRoomID(3161);sq.setRoom(occupied);sq.setSolidFloor(true);
    }
    for(int x=12;x<=14;x++)for(int y=19;y<=21;y++){
     var sq=cell.getGridSquare(x,y,0);sq.setRoomID(3162);sq.setRoom(beyond);sq.setSolidFloor(true);
    }
    var sq=cell.getGridSquare(12,20,0);var door=new zombie.iso.objects.IsoDoor(cell);
    door.setSquare(sq);door.north=false;door.setSprite(new zombie.iso.sprite.IsoSprite());sq.getObjects().add(door);sq.getSpecialObjects().add(door);
    sq.getProperties().set(zombie.iso.SpriteDetails.IsoFlagType.collideW);sq.getProperties().set(zombie.iso.SpriteDetails.IsoFlagType.cutW);
    sq.ReCalculateVisionBlocked(cell.getGridSquare(11,20,0));cell.getGridSquare(11,20,0).ReCalculateVisionBlocked(sq);
    body.setForwardDirection(1,0);other.setForwardDirection(1,0);
    var view=com.sao.engine.SAOConceptObservation.observe(body,8);
    return frame.push(view);
   }catch(Exception e){throw new IllegalStateException(e);}
  });
  env.rawset("__newRecipient",(JavaFunction)(frame,count)->{
   try{
    var make=MovementCrossingProbe.class.getDeclaredMethod("person",zombie.iso.IsoCell.class);make.setAccessible(true);
    var actor=(SAOIsoPlayerShell)make.invoke(null,body.getCell());actor.setSquare(actor.getCurrentSquare());
    actor.getCurrentSquare().getMovingObjects().add(actor);body.getCell().getObjectList().add(actor);actor.setHealth(100);actor.setForwardDirection(1,0);
    return frame.push(actor);
   }catch(Exception e){throw new IllegalStateException(e);}
  });
  env.rawset("__itemReload",(JavaFunction)(frame,count)->{
   try{var bytes=ByteBuffer.allocate(2*1024*1024);((InventoryItem)frame.get(0)).saveWithSize(bytes,false);bytes.flip();
    return frame.push(InventoryItem.loadItem(bytes,249));}catch(Exception e){throw new IllegalStateException(e);}
  });
  env.rawset("__give",(JavaFunction)(frame,count)->{
   var item=(InventoryItem)frame.get(0);var actor=Boolean.TRUE.equals(frame.get(1))?other:body;
   if(item.getContainer()!=null)item.getContainer().Remove(item);actor.getInventory().AddItem(item);return 0;
  });
  env.rawset("__clearInventory",(JavaFunction)(frame,count)->{body.getInventory().getItems().clear();other.getInventory().getItems().clear();
   body.getCharacterActions().clear();other.getCharacterActions().clear();return 0;});
  env.rawset("__queueNative",(JavaFunction)(frame,count)->{
   var action=(KahluaTable)frame.get(0);var actor=(SAOIsoPlayerShell)action.rawget("character");
   var nativeAction=new zombie.characters.CharacterTimedActions.LuaTimedActionNew(action,actor);action.rawset("action",nativeAction);
   actor.StartAction(nativeAction);return frame.push(true);
  });
  env.rawset("__nativeAction",(JavaFunction)(frame,count)->{
   var a=(zombie.characters.CharacterTimedActions.LuaTimedActionNew)frame.get(0);String op=(String)frame.get(1);
   if(op.equals("start"))a.start();else if(op.equals("progress")){a.setJobDelta(((Number)frame.get(2)).floatValue());a.update();}
   else if(op.equals("perform"))a.perform();else if(op.equals("complete"))a.complete();else if(op.equals("stop"))a.stop();
   else throw new AssertionError(op);return 0;
  });
  env.rawset("__reloadOwners",(JavaFunction)(frame,count)->{
   try{for(int index=0;index<2;index++)thread.call(LuaCompiler.loadstring(Files.readString(Path.of((String)frame.get(index))),"reloaded-owner",env),null,null,null);
    return 0;}catch(Exception e){throw new IllegalStateException(e);}
  });
  env.rawset("__freshLearning",(JavaFunction)(frame,count)->{
   try{
    var platform=new J2SEPlatform();var fresh=platform.newEnvironment();var vm=new KahluaThread(platform,fresh);vm.debugOwnerThread=Thread.currentThread();
    var bytes=ByteBuffer.allocate(4*1024*1024);((KahluaTable)frame.get(0)).save(bytes);bytes.flip();var restored=platform.newTable();restored.load(bytes,249);
    fresh.rawset("__person",restored);fresh.rawset("__hours",frame.get(1));
    String prelude="SAO={Identity={get=function(id)if id==__person.id then return __person end end},History={countyHours=function()return __hours end,ageOf=function()return __person.testAge end},Disposition={traits=function()return {discipline=.85}end}};getGameTime=function()return {getYear=function()return 1993 end}end";
    vm.call(LuaCompiler.loadstring(prelude,"fresh-owned-person",fresh),null,null,null);
    for(int index=2;index<count;index++)vm.call(LuaCompiler.loadstring(Files.readString(Path.of((String)frame.get(index))),"fresh-learning-source",fresh),null,null,null);
    return frame.push(vm.call(LuaCompiler.loadstring("return SAO.ConceptKnowledge.assessedRelations(__person.id)","fresh-query",fresh),null,null,null));
   }catch(Exception e){throw new IllegalStateException(e);}
  });
 }
}
