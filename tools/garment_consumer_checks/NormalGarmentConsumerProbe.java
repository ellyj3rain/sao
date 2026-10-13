import java.nio.*;import java.nio.file.*;import java.lang.reflect.*;import java.util.*;
import se.krka.kahlua.vm.*;import zombie.Lua.LuaManager;import zombie.iso.*;import zombie.inventory.*;import zombie.inventory.types.*;
/** Private ordinary consumer scene; real personal/source/native modules are loaded from capture. */
public final class NormalGarmentConsumerProbe {
 public static final class OriginalSourceClothing extends Clothing {
  OriginalSourceClothing(zombie.scripting.objects.Item script)throws Exception{
   super(script.getModuleName(),script.getDisplayName(),script.getName(),script,null,script.getSpriteName());
   setScriptItem(script);setRegistry_id(script); // Original Item factory script/registry publication.
   var original=(Clothing)script.InstanceItem(null);var bytes=ByteBuffer.allocate(1048576);original.save(bytes,false);bytes.flip();bytes.getShort();bytes.get();
   // Original InventoryItem.save header precedes original Clothing.load payload.
   load(bytes,IsoWorld.WorldVersion);
   if(getScriptItem()!=script||!getFullType().equals(original.getFullType())||getCondition()!=original.getCondition()||getRegistry_id()!=original.getRegistry_id())throw new AssertionError("original source/native state initialization");
  }
 }
 static IsoObject donor;static ItemContainer container;
 static void expose(Class<?>c){LuaManager.exposer.setExposed(c);LuaManager.exposer.exposeLikeJava(c,LuaManager.env);LuaManager.exposer.exposeLikeJavaRecursively(c,LuaManager.env);}
 public static void main(String[]args)throws Exception{
  GarmentOwnerNativeProbe.main(new String[]{args[0]});var body=GarmentConsumerNativeProbe.body;var cell=body.getCell();
  var region=zombie.iso.areas.isoregion.IsoRegions.class.getDeclaredField("dataRoot");region.setAccessible(true);region.set(null,new zombie.iso.areas.isoregion.data.DataRoot());
  new zombie.Lua.KahluaArrayConverter((se.krka.kahlua.j2se.J2SEPlatform)LuaManager.platform,LuaManager.converterManager).install();
  for(Class<?>c:List.of(zombie.characters.CharacterActionAnims.class,zombie.characters.IsoGameCharacter.XP.class,zombie.characters.BodyDamage.BodyPartType.class,
   zombie.characters.BodyDamage.BodyDamage.class,zombie.scripting.objects.MoodleType.class,zombie.characters.Moodles.Moodles.class,
   zombie.characters.WornItems.WornItems.class,zombie.iso.sprite.IsoSprite.class,zombie.iso.sprite.IsoSpriteManager.class,
   zombie.core.properties.PropertyContainer.class,zombie.iso.SpriteDetails.IsoFlagType.class,zombie.iso.IsoObject.class,
   zombie.characters.CharacterTimedActions.LuaTimedActionNew.class,zombie.GameTime.class))expose(c);
  for(Class<?>c:List.of(zombie.ai.states.ClimbThroughWindowState.class,zombie.ai.states.ClimbOverFenceState.class,
   zombie.ai.states.ClimbOverWallState.class,zombie.ai.states.ClimbSheetRopeState.class,zombie.ai.states.ClimbDownSheetRopeState.class,
   zombie.ai.states.CloseWindowState.class,zombie.ai.states.OpenWindowState.class))expose(c);
  for(Class<?>c:List.of(zombie.characters.CharacterTimedActions.BaseAction.class,zombie.scripting.objects.TimedActionScript.class,
   zombie.scripting.objects.CharacterTrait.class,java.util.Stack.class,java.util.Vector.class,java.util.LinkedList.class,
   zombie.iso.objects.IsoWorldInventoryObject.class,zombie.characters.BaseCharacterSoundEmitter.class,
   zombie.characters.Stats.class,zombie.characters.CharacterStat.class,zombie.characters.BodyDamage.Metabolics.class,
   zombie.characters.BodyDamage.BodyPart.class,zombie.characters.WornItems.WornItem.class,
   zombie.characters.AttachedItems.AttachedItems.class,zombie.characters.AttachedItems.AttachedItem.class,
   zombie.core.skinnedmodel.visual.ItemVisuals.class,zombie.scripting.objects.ActionSoundTime.class))expose(c);
  body.getModData().rawset("SAOExternalToken",null);
  expose(OriginalSourceClothing.class);
  String scenario=System.getProperty("sao.garment.case","normal"),layer=System.getProperty("sao.garment.layer","positive");
  LuaManager.env.rawset("__garmentCase",scenario);LuaManager.env.rawset("__garmentLayer",layer);
  LuaManager.env.rawset("__nativeGarmentEvent",(JavaFunction)(f,n)->{zombie.Lua.LuaEventManager.triggerEvent((String)f.get(0),f.get(1));return 0;});
  LuaManager.env.rawset("__nativeModData",(JavaFunction)(f,n)->f.push(zombie.world.moddata.GlobalModData.instance.getOrCreate((String)f.get(0))));
  LuaManager.env.rawset("__configureGarmentScene",(JavaFunction)(f,n)->{
   try{
    // Declared initial worn damage and unknown original material stock; no private facts/purpose.
    body.getInventory().getItems().clear();var shirt=scenario.equals("final-contracts")&&layer.equals("subclass")?new OriginalSourceClothing(GarmentConsumerNativeProbe.module.getItem("Shirt_FormalWhite")):(Clothing)GarmentConsumerNativeProbe.module.getItem("Shirt_FormalWhite").InstanceItem(null);shirt.setID(++GarmentConsumerNativeProbe.nextId);body.getInventory().AddItemBlind(shirt);shirt.setContainer(body.getInventory());body.setWornItem(zombie.scripting.objects.ItemBodyLocation.SHIRT,shirt,false);
    var part=zombie.characterTextures.BloodBodyPartType.Torso_Upper;
    if(scenario.equals("upgrade")){
     var cotton=GarmentConsumerNativeProbe.module.getItem("RippedSheets").InstanceItem(null);
     for(var covered:shirt.getCoveredParts())shirt.addPatch(body,covered,cotton);
     shirt.addRandomHole();
     part=null;for(var covered:shirt.getCoveredParts())if(shirt.getVisual().getHole(covered)>0){if(part!=null)throw new AssertionError("one actual initial random hole");part=covered;}
     if(part==null||shirt.getPatchType(part)==null)throw new AssertionError("native re-damaged retained Cotton patch");
    }else shirt.getVisual().setHole(part);
    if(scenario.equals("layers")&&!layer.equals("positive")||scenario.equals("final-contracts")&&layer.equals("zero-benefit")){
     body.setPerkLevelDebug(zombie.characters.skills.PerkFactory.Perks.Tailoring,8);
     for(String name:List.of("Needle","Thread","RippedSheets")){var item=GarmentConsumerNativeProbe.module.getItem(name).InstanceItem(null);item.setID(++GarmentConsumerNativeProbe.nextId);if(item instanceof DrainableComboItem)item.setCurrentUses(4);body.getInventory().AddItemBlind(item);item.setContainer(body.getInventory());}
    }
    if(scenario.equals("layers")&&layer.equals("positive")){
     var outer=GarmentConsumerNativeProbe.module.getItem("Jacket_Leather").InstanceItem(null);outer.setID(++GarmentConsumerNativeProbe.nextId);body.getInventory().AddItemBlind(outer);outer.setContainer(body.getInventory());body.setWornItem(zombie.scripting.objects.ItemBodyLocation.JACKET,outer,false);
    }
    var square=cell.getGridSquare(11,20,0);donor=new IsoObject(cell);donor.setSquare(square);var sprite=zombie.iso.sprite.IsoSpriteManager.instance.AddSprite("isolated_garment_donor",47001);sprite.name="isolated_garment_donor";donor.setSprite(sprite);
    container=new ItemContainer("counter",square,donor);container.setExplored(true);donor.setContainer(container);square.getObjects().add(donor);
    for(String name:List.of("Needle","Thread","RippedSheets","DenimStrips","LeatherStrips")){
     InventoryItem item=GarmentConsumerNativeProbe.module.getItem(name).InstanceItem(null);item.setID(++GarmentConsumerNativeProbe.nextId);if(item instanceof DrainableComboItem)item.setCurrentUses(4);container.AddItemBlind(item);item.setContainer(container);
    }
    var row=LuaManager.platform.newTable();row.rawset("damagePart",part);row.rawset("body",body);row.rawset("clothing",shirt);row.rawset("container",container);row.rawset("object",donor);return f.push(row);
   }catch(Exception e){throw new RuntimeException(e);}
  });
  LuaManager.env.rawset("__setOuterGarment",(JavaFunction)(f,n)->{
   var current=GarmentConsumerNativeProbe.body;
   if(Boolean.TRUE.equals(f.get(0))){var outer=GarmentConsumerNativeProbe.module.getItem("Jacket_Leather").InstanceItem(null);outer.setID(++GarmentConsumerNativeProbe.nextId);current.getInventory().AddItemBlind(outer);outer.setContainer(current.getInventory());current.setWornItem(zombie.scripting.objects.ItemBodyLocation.JACKET,outer,false);return f.push(outer);}
   var outer=current.getWornItem(zombie.scripting.objects.ItemBodyLocation.JACKET);current.setWornItem(zombie.scripting.objects.ItemBodyLocation.JACKET,null,false);if(outer!=null)current.getInventory().Remove(outer);return f.push(outer!=null);
  });
  LuaManager.env.rawset("__moveGarmentBody",(JavaFunction)(f,n)->{
   int x=((Double)f.get(0)).intValue(),y=((Double)f.get(1)).intValue();var square=body.getCell().getGridSquare(x,y,0);if(square==null)throw new AssertionError("actual loaded route endpoint");body.setX(x+.5f);body.setY(y+.5f);body.setCurrent(square);body.setSquare(square);return f.push(true);
  });
  LuaManager.env.rawset("__garmentSnapshotRebind",(JavaFunction)(f,n)->{
   try{
    var current=(com.sao.engine.SAOIsoPlayerShell)f.get(0);String snapshot=com.sao.engine.SAONativeSnapshot.capture(current);
    Files.writeString(Path.of(System.getProperty("user.home")).resolve("native-body-snapshot.txt"),snapshot);
    var make=MovementCrossingProbe.class.getDeclaredMethod("person",IsoCell.class);make.setAccessible(true);var restored=(com.sao.engine.SAOIsoPlayerShell)make.invoke(null,current.getCell());restored.setSquare(restored.getCurrentSquare());
    int count=com.sao.engine.SAONativeSnapshot.restoreStaged(restored,snapshot);
    GarmentConsumerNativeProbe.body=restored;
    System.out.println("GARMENT_NATIVE_SNAPSHOT_REBIND items="+count+" worn="+restored.getWornItems().size()+" token="+restored.getModData().rawget("SAOExternalToken"));return f.push(restored);
   }catch(Exception e){throw new RuntimeException(e);}
  });
  LuaManager.env.rawset("__retainGarmentProjection",(JavaFunction)(f,n)->{
   try{String name=(String)f.get(0);if(!List.of("person-save","private-belief","private-archive","native-outcomes").contains(name))throw new AssertionError("owned projection name");Files.writeString(Path.of(System.getProperty("user.home")).resolve(name+".json"),(String)f.get(1));return f.push(true);}catch(Exception e){throw new RuntimeException(e);}
  });
  LuaManager.env.rawset("__nativeRandom",(JavaFunction)(f,n)->f.push(n==1?(double)zombie.core.random.Rand.Next(((Double)f.get(0)).intValue()):(double)zombie.core.random.Rand.Next(((Double)f.get(0)).intValue(),((Double)f.get(1)).intValue())));
  LuaManager.env.rawset("__nativeTimestamp",(JavaFunction)(f,n)->f.push((double)System.currentTimeMillis()));
  for(int i=1;i<args.length;i++)GarmentConsumerNativeProbe.run(Files.readString(Path.of(args[i])),args[i]);
 }
}
