import java.nio.file.*;import java.util.*;import se.krka.kahlua.vm.*;import zombie.Lua.LuaManager;
/** Reuses chief's frozen actual shell/Clothing/scripts/asset-ready setup read-only. */
public final class GarmentOwnerNativeProbe {
 public static void main(String[]args)throws Exception{
  GarmentConsumerNativeProbe.main(new String[]{args[0]});
  for(Class<?>c:List.of(zombie.iso.IsoCell.class,zombie.iso.IsoGridSquare.class,zombie.util.list.PZArrayList.class,
   zombie.scripting.ScriptManager.class,zombie.scripting.objects.Item.class,zombie.characters.DummyCharacterSoundEmitter.class,zombie.characters.CharacterSoundEmitter.class,
   zombie.characters.PlayerCraftHistory.class,zombie.characters.WornItems.WornItems.class,
   java.util.Set.class,java.util.HashSet.class,java.util.LinkedHashSet.class)){
   LuaManager.exposer.setExposed(c);LuaManager.exposer.exposeLikeJava(c,LuaManager.env);
  }
  var cell=GarmentConsumerNativeProbe.body.getCell();var square=GarmentConsumerNativeProbe.body.getCurrentSquare();
  square.setSolidFloor(true); // Explicit native route/standing scene, no object/place effect.
  LuaManager.env.rawset("__cell",cell);
  var root=zombie.world.moddata.GlobalModData.instance.get("SurvivorAwareness_Records");
  LuaManager.env.rawset("__record",((KahluaTable)root.rawget("records")).rawget("garment-person"));
  LuaManager.env.rawset("instanceof",(JavaFunction)(f,n)->f.push(LuaManager.GlobalObject.instof(f.get(0),(String)f.get(1))));
  // Selected actual native type aliases normally populated by game bootstrap.
  java.lang.reflect.Field typeField=null;
  for(Class<?>type=LuaManager.Exposer.class;type!=null;type=type.getSuperclass())try{typeField=type.getDeclaredField("typeMap");break;}catch(NoSuchFieldException absent){}
  if(typeField==null)throw new IllegalStateException("original native Exposer type map required");typeField.setAccessible(true);
  @SuppressWarnings("unchecked") var types=(java.util.Map<String,Class<?>>)typeField.get(LuaManager.exposer);
  types.put("Clothing",zombie.inventory.types.Clothing.class);types.put("DrainableComboItem",zombie.inventory.types.DrainableComboItem.class);
  LuaManager.env.rawset("__summary",(JavaFunction)(f,n)->{try{Files.writeString(Path.of(System.getProperty("user.home")).resolve("measurement.json"),(String)f.get(0));return 0;}catch(Exception e){throw new RuntimeException(e);}});
  LuaManager.env.rawset("__reloadOwner",(JavaFunction)(f,n)->{try{GarmentConsumerNativeProbe.run(Files.readString(Path.of(System.getProperty("sao.ownerPath"))),"native-owned-module-reload");return f.push(true);}catch(Exception e){throw new RuntimeException(e);}});
  LuaManager.env.rawset("__replaceNativeRecord",(JavaFunction)(f,n)->{((KahluaTable)root.rawget("records")).rawset("garment-person",f.get(0));return f.push(true);});
  final zombie.scripting.objects.Item[] originalScript={null};
  LuaManager.env.rawset("__replaceGarmentScript",(JavaFunction)(f,n)->{boolean restore=(Boolean)f.get(0);
   var map=GarmentConsumerNativeProbe.module.items.getScriptMap();
   if(originalScript[0]==null)originalScript[0]=map.get("Shirt_FormalWhite");
   map.put("Shirt_FormalWhite",restore?originalScript[0]:new zombie.scripting.objects.Item());return f.push(true);});
  for(int i=1;i<args.length;i++)GarmentConsumerNativeProbe.run(Files.readString(Path.of(args[i])),args[i]);
 }
}
