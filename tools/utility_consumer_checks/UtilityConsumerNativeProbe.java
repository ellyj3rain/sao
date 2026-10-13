import java.nio.*;import java.nio.file.*;import java.lang.reflect.*;import java.util.*;
import se.krka.kahlua.vm.*;import zombie.Lua.LuaManager;import zombie.iso.*;import zombie.inventory.*;import zombie.scripting.*;import zombie.scripting.objects.*;
/** Private ordinary person wrapper over the retained native utility scene bootstrap. */
public final class UtilityConsumerNativeProbe {
 static com.sao.engine.SAOIsoPlayerShell body;static int nextId=74000;static boolean initialSceneOpen=true;
 static class Info extends zombie.world.ItemInfo{Info(Item d,short id){name=d.getName();moduleName="Base";fullType="Base."+name;registryId=id;isLoaded=true;scriptItem=d;entityScript=d;modId="pz-vanilla";}}
 static class Dictionary extends zombie.world.DictionaryData{void add(Item d,short id){var i=new Info(d,id);itemIdToInfoMap.put(id,i);itemTypeToInfoMap.put(i.getFullType(),i);}}
 static String block(String text,String name){text=ScriptParser.stripComments(text);var m=java.util.regex.Pattern.compile("(?m)^\\s*item\\s+"+java.util.regex.Pattern.quote(name)+"\\s*\\{").matcher(text);if(!m.find())throw new AssertionError(name);int depth=1,end=m.end();while(depth>0){char c=text.charAt(end++);if(c=='{')depth++;if(c=='}')depth--;}return text.substring(m.start(),end);}
 static void expose(Class<?>c){LuaManager.exposer.setExposed(c);LuaManager.exposer.exposeLikeJava(c,LuaManager.env);LuaManager.exposer.exposeLikeJavaRecursively(c,LuaManager.env);}
 // Read-only plain fixture artifact encoding, following existing RecipePolicyNativeProbe.json.
    static String json(Object value) {
        if(value==null)return "null";
        if(value instanceof String s)return "\""+s.replace("\\","\\\\").replace("\"","\\\"").replace("\n","\\n").replace("\r","\\r").replace("\t","\\t")+"\"";
        if(value instanceof Number || value instanceof Boolean)return value.toString();
        if(value instanceof KahluaTable t && t.getMetatable()==null){
            List<String> entries=new ArrayList<>();var it=t.iterator();while(it.advance())entries.add(json(String.valueOf(it.getKey()))+":"+json(it.getValue()));
            Collections.sort(entries);return "{"+String.join(",",entries)+"}";
        }
        throw new AssertionError("nonplain projection "+value.getClass());
    }
 // Original native metadata bank initialization; no copied asset or semantic sprite label.
 static void nativeSpriteMetadata(Path game)throws Exception {
  boolean server=zombie.network.GameServer.server,gui=zombie.network.GameServer.guiCommandline;
  try{zombie.network.GameServer.server=true;zombie.network.GameServer.guiCommandline=false;
   IsoWorld.instance.LoadTileDefinitionsPropertyStrings(zombie.iso.sprite.IsoSpriteManager.instance,game.resolve("media/newtiledefinitions.tiles").toString(),1);
   var generate=IsoWorld.class.getDeclaredMethod("GenerateTilePropertyLookupTables");generate.setAccessible(true);generate.invoke(IsoWorld.instance);
   IsoWorld.instance.LoadTileDefinitions(zombie.iso.sprite.IsoSpriteManager.instance,game.resolve("media/newtiledefinitions.tiles").toString(),1);
  }finally{zombie.network.GameServer.server=server;zombie.network.GameServer.guiCommandline=gui;}
  for(String key:List.of("carpentry_02_54","fixtures_sinks_01_0")){var sprite=zombie.iso.sprite.IsoSpriteManager.instance.namedMap.get(key);if(sprite==null||!key.equals(sprite.name))throw new AssertionError("original source sprite missing "+key);}
 }
 // The ordinary loader supplies source metadata. Bare loadstring leaves nested
 // prototypes on a stale defines.lua filename; annotate exact captured input only.
 static void sourceMetadata(se.krka.kahlua.vm.Prototype p,Path source){p.filename=source.toAbsolutePath().normalize().toString();p.file=source.getFileName().toString();for(var child:p.prototypes)sourceMetadata(child,source);}
 static void loadOriginal(Path source)throws Exception{var chunk=se.krka.kahlua.luaj.compiler.LuaCompiler.loadstring(Files.readString(source),source.toString(),LuaManager.env);sourceMetadata(chunk.prototype,source);var result=LuaManager.thread.pcall(chunk,new Object[0]);if(!Boolean.TRUE.equals(result[0]))throw new AssertionError(Arrays.toString(result));}
 public static void main(String[]args)throws Exception{
  if(System.getProperty("sao.ownedPackage")!=null){zombie.core.Core.gameSaveWorld="isolated-owned-household";zombie.core.Core.gameMode="Sandbox";}
  ServiceObserverProbe.main(new String[0]);
  // Original dedicated native initialization avoids graphical setup only. Actual
  // puddle climate/defaults/query remain native; restore SP before every owner action.
  boolean oldServer=zombie.network.GameServer.server,oldGui=zombie.network.GameServer.guiCommandline;
  try{zombie.network.GameServer.server=true;zombie.network.GameServer.guiCommandline=false;zombie.iso.IsoPuddles.getInstance();}
  finally{zombie.network.GameServer.server=oldServer;zombie.network.GameServer.guiCommandline=oldGui;}
  body=(com.sao.engine.SAOIsoPlayerShell)LuaManager.env.rawget("body");Path game=Path.of(args[0]);nativeSpriteMetadata(game);
  for(int x=8;x<=14;x++)for(int y=18;y<=23;y++)for(int z=0;z<=1;z++){
   var square=body.getCell().getGridSquare(x,y,z);var sprite=new zombie.iso.sprite.IsoSprite();sprite.getProperties().set(zombie.iso.SpriteDetails.IsoFlagType.solidfloor);square.getObjects().add(new IsoObject(body.getCell(),square,sprite));square.getProperties().set(zombie.iso.SpriteDetails.IsoFlagType.solidfloor);square.setSolidFloor(true);square.setCachedIsFree(false);
  }
  new zombie.Lua.KahluaArrayConverter((se.krka.kahlua.j2se.J2SEPlatform)LuaManager.platform,LuaManager.converterManager).install();
  for(Class<?>c:List.of(zombie.SandboxOptions.DoubleSandboxOption.class,zombie.scripting.objects.ItemBodyLocation.class,zombie.characters.WornItems.WornItems.class,zombie.characters.WornItems.WornItem.class,zombie.characters.skills.PerkFactory.class,zombie.characters.CharacterActionAnims.class,zombie.characters.IsoGameCharacter.XP.class,zombie.characters.CharacterStat.class,zombie.characters.Stats.class,zombie.characters.Moodles.Moodles.class,zombie.characters.BodyDamage.Metabolics.class,zombie.inventory.types.Literature.class,zombie.inventory.types.DrainableComboItem.class,zombie.characters.skills.PerkFactory.Perks.class,zombie.characters.CharacterTimedActions.LuaTimedActionNew.class,zombie.scripting.objects.CharacterTrait.class,zombie.scripting.objects.TimedActionScript.class,zombie.scripting.objects.ActionSoundTime.class,zombie.world.moddata.GlobalModData.class))expose(c);
  var map=LuaManager.exposer.typeMap;map.put("IsoObject",IsoObject.class);map.put("IsoThumpable",zombie.iso.objects.IsoThumpable.class);map.put("IsoGenerator",zombie.iso.objects.IsoGenerator.class);map.put("HandWeapon",zombie.inventory.types.HandWeapon.class);map.put("Literature",zombie.inventory.types.Literature.class);map.put("InventoryItem",InventoryItem.class);map.put("DrainableComboItem",zombie.inventory.types.DrainableComboItem.class);map.put("IsoPlayer",zombie.characters.IsoPlayer.class);map.put("IsoGameCharacter",zombie.characters.IsoGameCharacter.class);
  LuaManager.env.rawset("instanceof",(JavaFunction)(f,n)->f.push(LuaManager.GlobalObject.instof(f.get(0),(String)f.get(1))));
  var module=ScriptManager.instance.getModule("Base");var dictionary=new Dictionary();var df=zombie.world.WorldDictionary.class.getDeclaredField("data");df.setAccessible(true);df.set(null,dictionary);
  short registry=400;
  for(String[]pair:new String[][]{{"Generator","normal"},{"PipeWrench","weapon"},{"ElectronicsMag4","literature"},{"WaterBottle","normal"}}){
   Path source=game.resolve("media/scripts/generated/items/"+pair[1]+".txt");Item d=module.getItem(pair[0]);
   if(d==null){for(String[]entry:new String[][]{{"currentLoadFileMod","pz-vanilla"},{"currentLoadFileName",source.getFileName().toString()},{"currentLoadFileAbsPath",source.toString()}}){var field=ScriptManager.class.getDeclaredField(entry[0]);field.setAccessible(true);field.set(null,entry[1]);}d=new Item();d.setModule(module);d.setModID("pz-vanilla");d.InitLoadPP(pair[0]);d.Load(pair[0],block(Files.readString(source),pair[0]));module.items.getScriptMap().put(pair[0],d);}
   d.setDisplayName(pair[0]);d.setRegistry_id(registry);dictionary.add(d,registry++);
  }
  zombie.inventory.ItemTags.Init(ScriptManager.instance.getAllItems());
  body.setPrimaryHandItem(null);body.setSecondaryHandItem(null);body.getInventory().getItems().clear();body.getModData().rawset("SAOExternalToken",null);
  LuaManager.env.rawset("__nativeModData",(JavaFunction)(f,n)->f.push(zombie.world.moddata.GlobalModData.instance.getOrCreate((String)f.get(0))));
  // Initial-world native fluid constructor only. Original effect/query methods unchanged.
  LuaManager.env.rawset("__utilityInitialSprite",(JavaFunction)(f,n)->{
   String key=(String)f.get(1);if(!initialSceneOpen||!List.of("carpentry_02_54","fixtures_sinks_01_0").contains(key))throw new AssertionError("initial source metadata phase/key refused");var sprite=zombie.iso.sprite.IsoSpriteManager.instance.namedMap.get(key);if(sprite==null||!key.equals(sprite.name))throw new AssertionError("actual registered sprite missing");((IsoObject)f.get(0)).setSprite(sprite);return 0;
  });
  LuaManager.env.rawset("__newTaintedProvider",(JavaFunction)(f,n)->{try{
   int x=((Double)f.get(0)).intValue(),y=((Double)f.get(1)).intValue(),z=((Double)f.get(2)).intValue();var square=body.getCell().getGridSquare(x,y,z);if(square==null)throw new AssertionError("native initial reservoir square missing");
   var object=new ServiceObserverProbe.Collector(body.getCell(),square);var fluid=zombie.entity.components.fluids.FluidContainer.CreateContainer();fluid.setCapacity(20);fluid.addFluid(zombie.entity.components.fluids.Fluid.TaintedWater,((Double)f.get(3)).floatValue());
   var add=zombie.entity.GameEntity.class.getDeclaredMethod("addComponent",zombie.entity.Component.class);add.setAccessible(true);add.invoke(object,fluid);square.getObjects().add(object);return f.push(object);
  }catch(Exception e){throw new RuntimeException(e);}});
  LuaManager.env.rawset("__setupUtilityPersonScene",(JavaFunction)(f,n)->{
   var square=body.getCell().getGridSquare(12,21,0);var donor=new IsoObject(body.getCell());donor.setSquare(square);var sprite=zombie.iso.sprite.IsoSpriteManager.instance.AddSprite("isolated_utility_donor",48001);sprite.name="isolated_utility_donor";donor.setSprite(sprite);var container=new ItemContainer("counter",square,donor);container.setExplored(true);donor.setContainer(container);square.getObjects().add(donor);
   for(String name:List.of("PipeWrench","ElectronicsMag4")){var item=module.getItem(name).InstanceItem(null);item.setID(++nextId);container.AddItemBlind(item);item.setContainer(container);}
   var bottle=module.getItem("WaterBottle").InstanceItem(null);bottle.setID(++nextId);if(bottle.getFluidContainer()==null)throw new AssertionError("original native WaterBottle component absent");bottle.getFluidContainer().Empty();body.getInventory().AddItemBlind(bottle);bottle.setContainer(body.getInventory());
   body.getStats().set(zombie.characters.CharacterStat.THIRST,.8f);
   var row=LuaManager.platform.newTable();row.rawset("body",body);row.rawset("donor",donor);row.rawset("container",container);row.rawset("bottle",bottle);return f.push(row);
  });
  LuaManager.env.rawset("__moveUtilityBody",(JavaFunction)(f,n)->{int x=((Double)f.get(0)).intValue(),y=((Double)f.get(1)).intValue(),z=((Double)f.get(2)).intValue();var square=body.getCell().getGridSquare(x,y,z);if(square==null)throw new AssertionError("actual loaded route endpoint");body.getCurrentSquare().getMovingObjects().remove(body);body.setX(x+.5f);body.setY(y+.5f);body.setZ(z);body.setCurrent(square);body.setSquare(square);square.getMovingObjects().add(body);return f.push(true);});
  LuaManager.env.rawset("__nativeTimestamp",(JavaFunction)(f,n)->f.push((double)System.currentTimeMillis()));
  LuaManager.env.rawset("__nativeRandom",(JavaFunction)(f,n)->f.push(n==1?(double)zombie.core.random.Rand.Next(((Double)f.get(0)).intValue()):(double)zombie.core.random.Rand.Next(((Double)f.get(0)).intValue(),((Double)f.get(1)).intValue())));
  LuaManager.env.rawset("__utilityEnvironmentTick",(JavaFunction)(f,n)->{
   var events=new ArrayList<zombie.Lua.Event>();var byName=new HashMap<String,zombie.Lua.Event>();zombie.Lua.LuaEventManager.getEvents(events,byName);var onTick=byName.get("OnTick");if(onTick==null)throw new AssertionError("native OnTick event absent");
   int called=0;for(var callback:new ArrayList<>(onTick.callbacks)){
    String filename=callback.prototype.filename;String file=callback.prototype.file;
    if(filename==null||filename.isBlank())filename=file;

    if(filename!=null&&filename.endsWith("SAO_HouseholdService.lua")){
     var result=LuaManager.thread.pcall(callback,new Object[0]);if(!Boolean.TRUE.equals(result[0]))throw new AssertionError("original environmental callback "+filename+" "+Arrays.toString(result));called++;
    }
   }return f.push((double)called);
  });
  LuaManager.env.rawset("__utilityAdvanceNativeTimer",(JavaFunction)(f,n)->{
   var a=(zombie.characters.CharacterTimedActions.BaseAction)f.get(0);float step=zombie.GameTime.getInstance().getMultiplier();if(!Float.isFinite(step)||step<=0||a.maxTime<=0)throw new AssertionError("actual native action duration/multiplier required");
   int bound=(int)Math.ceil(a.maxTime/step)+8,count=0;while(a.getJobDelta()<1&&!a.forceStop&&a.isStarted()&&count<bound){a.update();count++;}System.out.println("UTILITY_NATIVE_TIMER frames="+count+" current="+a.getCurrentTime()+" duration="+a.maxTime+" delta="+a.getJobDelta());return f.push((double)count);
  });
  // Read-only actual receiver measurements. These rows grant no source/work admission.
  LuaManager.env.rawset("__utilityNativeActionFacts",(JavaFunction)(f,n)->{
   var a=(zombie.characters.CharacterTimedActions.BaseAction)f.get(0);var row=LuaManager.platform.newTable();row.rawset("forceStop",a.forceStop);row.rawset("started",a.isStarted());row.rawset("forceComplete",a.isForceComplete());row.rawset("finished",a.finished());row.rawset("nativeClass",a.getClass().getName());row.rawset("inCharacterActions",body.getCharacterActions().contains(a));row.rawset("sameLuaTable",a instanceof zombie.characters.CharacterTimedActions.LuaTimedActionNew lua&&lua.getTable()==f.get(1));return f.push(row);
  });
  LuaManager.env.rawset("__utilityNativeSourceFacts",(JavaFunction)(f,n)->{
   if(f.get(0)==null)return f.push(null);var object=(IsoObject)f.get(0);var row=LuaManager.platform.newTable();var square=object.getSquare();row.rawset("nativeClass",object.getClass().getName());row.rawset("objectIndex",(double)object.getObjectIndex());
   if(square!=null){row.rawset("x",(double)square.getX());row.rawset("y",(double)square.getY());row.rawset("z",(double)square.getZ());row.rawset("powered",square.haveElectricity());row.rawset("inCurrentSquareObjects",square.getObjects().contains(object));}
   row.rawset("amount",(double)object.getFluidAmount());row.rawset("hasWater",object.hasWater());row.rawset("tainted",object.isTaintedWater());row.rawset("external",object.getUsesExternalWaterSource());var primary=object.getPrimaryFluid();if(primary!=null)row.rawset("primaryFluid",primary.getFluidTypeString());var script=object.getEntityScript();if(script!=null)row.rawset("nativeEntityId",script.getFullName());return f.push(row);
  });
  LuaManager.env.rawset("__utilityWriteProjection",(JavaFunction)(f,n)->{
   try{var output=Path.of(System.getProperty("user.home")).toAbsolutePath().normalize();String label=(String)f.get(0);if(!label.matches("[a-z0-9-]+"))throw new AssertionError("private projection label");Files.writeString(output.resolve(label+".json"),json(f.get(1)));return f.push(true);}catch(Exception e){throw new RuntimeException(e);}
  });
  // Original native module discovery/cache; one selected owned H source.
  LuaManager.exposer.exposeAll();
  var pathsField=LuaManager.class.getDeclaredField("paths");pathsField.setAccessible(true);var paths=(List<String>)pathsField.get(null);paths.clear();paths.add("media/lua/shared/");paths.add("media/lua/client/");
  String selectedPackage=System.getProperty("sao.ownedPackage");
  if(selectedPackage!=null){
  Path packageRoot=Path.of(selectedPackage);
  for(var file:Files.walk(packageRoot).filter(Files::isRegularFile).toList()){String relative=packageRoot.relativize(file).toString().replace('\\','/');zombie.ZomboidFileSystem.instance.activeFileMap.put(relative.toLowerCase(Locale.ROOT),file.toAbsolutePath().toString());}
  LuaManager.env.rawset("__utilityOwnedCallbackFacts",(JavaFunction)(f,n)->{var c=(LuaClosure)f.get(0);var events=new ArrayList<zombie.Lua.Event>();var names=new HashMap<String,zombie.Lua.Event>();zombie.Lua.LuaEventManager.getEvents(events,names);int count=0;for(var candidate:names.get("OnTick").callbacks)if(candidate==c)count++;var row=LuaManager.platform.newTable();row.rawset("count",(double)count);row.rawset("filename",c.prototype.filename);return f.push(row);});
  LuaManager.env.rawset("__utilityOwnedPackage",packageRoot.toString().replace('\\','/'));
  }
  for(int i=1;i<args.length;i++){loadOriginal(Path.of(args[i]));if(Path.of(args[i]).getFileName().toString().endsWith("-scene.lua"))initialSceneOpen=false;}
 }
}
