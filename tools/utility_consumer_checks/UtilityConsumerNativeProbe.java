import java.nio.*;import java.nio.file.*;import java.lang.reflect.*;import java.util.*;
import se.krka.kahlua.vm.*;import zombie.Lua.LuaManager;import zombie.iso.*;import zombie.inventory.*;import zombie.scripting.*;import zombie.scripting.objects.*;
/** Private ordinary person wrapper over the retained native utility scene bootstrap. */
public final class UtilityConsumerNativeProbe {
 static com.sao.engine.SAOIsoPlayerShell body;static int nextId=74000;static boolean initialSceneOpen=true;static boolean networkScenario=Boolean.getBoolean("sao.waterNetwork");
 static class Info extends zombie.world.ItemInfo{Info(Item d,short id){name=d.getName();moduleName=d.getModuleName();fullType=d.getFullName();registryId=id;isLoaded=true;scriptItem=d;entityScript=d;modId="pz-vanilla";}}
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
 // Frozen asset-ready metadata port before original SP Item.Load; no rendered asset.
 static void textureMetadata()throws Exception {
  var slot=sun.misc.Unsafe.class.getDeclaredField("theUnsafe");slot.setAccessible(true);var unsafe=(sun.misc.Unsafe)slot.get(null);var texture=(zombie.core.textures.Texture)unsafe.allocateInstance(zombie.core.textures.Texture.class);
  var field=zombie.core.textures.Texture.class.getDeclaredField("name");field.setAccessible(true);String name="media/inventory/Question_On.png";field.set(texture,name);
  for(String d:List.of("width","height","widthOrig","heightOrig")){field=zombie.core.textures.Texture.class.getDeclaredField(d);field.setAccessible(true);field.setInt(texture,32);}
  field=zombie.core.textures.Texture.class.getDeclaredField("s_sharedTextureTable");field.setAccessible(true);((Map<String,zombie.core.textures.Texture>)field.get(null)).put(name,texture);zombie.core.textures.Texture.nullTextures.remove(name);
 }
 static void scriptMetadata(Path path,String mod)throws Exception {
  for(String[]e:new String[][]{{"currentLoadFileMod",mod},{"currentLoadFileName",path.getFileName().toString()},{"currentLoadFileAbsPath",path.toString()}}){var f=ScriptManager.class.getDeclaredField(e[0]);f.setAccessible(true);f.set(null,e[1]);}
 }
 static void initialWorkshop(Path game,Dictionary dictionary)throws Exception {
  textureMetadata();var base=ScriptManager.instance.getModule("Base");short reg=500;
  for(String[]pair:new String[][]{{"MetalPipe","weapon"},{"SmallSheetMetal","normal"},{"ScrapMetal","normal"},{"Screws","normal"},{"ElectronicsScrap","normal"},{"EngineParts","normal"},{"BlowTorch","drainable"},{"WeldingMask","clothing"},{"Screwdriver","weapon"}}){
   var path=game.resolve("media/scripts/generated/items/"+pair[1]+".txt");scriptMetadata(path,"pz-vanilla");var item=new Item();item.setModule(base);item.setModID("pz-vanilla");item.InitLoadPP(pair[0]);item.Load(pair[0],block(Files.readString(path),pair[0]));base.items.getScriptMap().put(pair[0],item);item.setDisplayName(pair[0]);item.setRegistry_id(reg);dictionary.add(item,reg++);
  }
  Path selected=Path.of(System.getProperty("sao.selectedSource"));var scripts=selected.resolve("mod/42.20/media/scripts");
  for(String name:List.of("Items","Recipes","Models")){var path=scripts.resolve("SAO_WaterNetwork_"+name+".txt");scriptMetadata(path,"SAO");ScriptManager.instance.ParseScript(ScriptLoadMode.Init,Files.readString(path));}
  var sao=ScriptManager.instance.getModule("SAO");sao.items.LoadScripts(ScriptLoadMode.Init);sao.craftRecipes.LoadScripts(ScriptLoadMode.Init);sao.models.LoadScripts(ScriptLoadMode.Init);
  if(sao.items.isHasLoadErrors()||sao.craftRecipes.isHasLoadErrors()||sao.models.isHasLoadErrors())throw new AssertionError("original owned script registration");
  for(String name:List.of("WaterValve","WaterPump")){var item=sao.getItem(name);item.setRegistry_id(reg);dictionary.add(item,reg++);}
  zombie.inventory.ItemTags.Init(ScriptManager.instance.getAllItems());
  for(var recipe:sao.craftRecipes.getScriptList())recipe.OnPostWorldDictionaryInit();zombie.entity.components.crafting.recipe.CraftRecipeManager.Init();
  var recipe=ScriptManager.instance.getCraftRecipe("SAO.MakeWaterPump");var perk=recipe.getAutoLearnAnySkill(0).getPerk();body.setPerkLevelDebug(perk,4);
  for(var r:sao.craftRecipes.getScriptList()){boolean before=body.isRecipeActuallyKnown(r);r.checkAutoLearnAnySkills(body,false);System.out.println("ORDINARY_INITIAL_AUTOLEARN id="+r.getScriptObjectFullType()+" before="+before+" after="+body.isRecipeActuallyKnown(r)+" skill="+body.getPerkLevel(perk));}
  for(var r:sao.craftRecipes.getScriptList())System.out.println("ORDINARY_INITIAL_RECIPE id="+r.getScriptObjectFullType()+" perk="+body.getPerkLevel(perk)+" actualKnown="+body.isRecipeActuallyKnown(r)+" learnedEligible="+zombie.entity.components.crafting.recipe.CraftRecipeManager.hasPlayerLearnedRecipe(r,body)+" required="+r.characterHasRequiredSkills(body));
  for(Class<?> type:List.of(zombie.iso.objects.IsoWorldInventoryObject.class,zombie.entity.components.resources.ResourceType.class,zombie.scripting.objects.Item.class,zombie.scripting.entity.components.crafting.CraftRecipe.class,zombie.scripting.entity.components.crafting.InputScript.class,zombie.scripting.entity.components.crafting.OutputScript.class,zombie.scripting.entity.components.crafting.CraftRecipe.RequiredSkill.class,zombie.characters.skills.PerkFactory.Perk.class,zombie.entity.components.crafting.recipe.CraftRecipeManager.class,zombie.entity.components.crafting.recipe.CraftRecipeData.class,zombie.entity.components.crafting.recipe.HandcraftLogic.class,zombie.entity.components.crafting.BaseCraftingLogic.class,zombie.inventory.ItemTags.class,java.util.Collection.class,java.util.Iterator.class))expose(type);
 }
 // Initial finite loaded chunk-map only: original registered floors and native squares.
 static void initialLoadedGeometry()throws Exception {
  var cell=body.getCell();var map=cell.getChunkMap(0);int width=IsoChunkMap.chunkGridWidth;
  var floors=zombie.iso.sprite.IsoSpriteManager.instance.namedMap.values().stream().filter(p->p.name!=null&&p.name.startsWith("floors_")&&p.getProperties().has(zombie.iso.SpriteDetails.IsoFlagType.solidfloor)).sorted(java.util.Comparator.comparing(p->p.name)).toList();
  if(floors.isEmpty())throw new AssertionError("original registered floor metadata unavailable");var sprite=floors.get(0);int count=0;
  for(int iy=0;iy<width;iy++)for(int ix=0;ix<width;ix++){
   int index=iy*width+ix;var chunk=map.getChunks()[index];if(chunk==null){chunk=new IsoChunk(cell);chunk.wx=map.getWorldXMin()+ix;chunk.wy=map.getWorldYMin()+iy;chunk.loaded=true;map.getChunks()[index]=chunk;}
   for(int x=0;x<8;x++)for(int y=0;y<8;y++){
    int wx=chunk.wx*8+x,wy=chunk.wy*8+y;var q=cell.getGridSquare(wx,wy,0);if(q==null){q=new IsoGridSquare(cell,null,wx,wy,0);q.chunk=chunk;chunk.setSquare(x,y,0,q);}
    if(q.getObjects().isEmpty()){q.getObjects().add(new IsoObject(cell,q,sprite));q.RecalcAllWithNeighbours(true);count++;}
   }
  }
  System.out.println("ORDINARY_INITIAL_GEOMETRY width="+width+" minChunkX="+map.getWorldXMin()+" minChunkY="+map.getWorldYMin()+" nativeFloor="+sprite.name+" addedFloors="+count);
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
  body=(com.sao.engine.SAOIsoPlayerShell)LuaManager.env.rawget("body");Path game=Path.of(args[0]);nativeSpriteMetadata(game);if(networkScenario)initialLoadedGeometry();
  for(int x=8;x<=14;x++)for(int y=18;y<=23;y++)for(int z=0;z<=1;z++){
   var square=body.getCell().getGridSquare(x,y,z);var sprite=new zombie.iso.sprite.IsoSprite();sprite.getProperties().set(zombie.iso.SpriteDetails.IsoFlagType.solidfloor);square.getObjects().add(new IsoObject(body.getCell(),square,sprite));square.getProperties().set(zombie.iso.SpriteDetails.IsoFlagType.solidfloor);square.setSolidFloor(true);square.setCachedIsFree(false);
  }
  expose(java.util.Set.class);expose(body.getCell().getObjectList().getClass());expose(body.getCell().getAddList().getClass());System.out.println("ORDINARY_NATIVE_OBJECTSET class="+body.getCell().getObjectList().getClass().getName()+" containsBody="+body.getCell().getObjectList().contains(body));
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
  if(networkScenario)initialWorkshop(game,dictionary);
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
   if(networkScenario)for(Object[]entry:new Object[][]{{"MetalPipe",5},{"SmallSheetMetal",2},{"ScrapMetal",4},{"Screws",8},{"ElectronicsScrap",2},{"EngineParts",2},{"BlowTorch",1},{"WeldingMask",1},{"Screwdriver",1}}){
    for(int k=0;k<(int)entry[1];k++){var item=module.getItem((String)entry[0]).InstanceItem(null);if(item instanceof zombie.inventory.types.DrainableComboItem drain&&item.getFullType().equals("Base.BlowTorch"))drain.setCurrentUses(4);item.setID(++nextId);container.AddItemBlind(item);item.setContainer(container);System.out.println("ORDINARY_INITIAL_WORKSHOP item="+item.getFullType()+" id="+item.getID()+" uses="+item.getCurrentUses()+" floatUses="+item.getCurrentUsesFloat()+" maxUses="+item.getMaxUses()+" nativeClass="+item.getClass().getName()+" registered="+(item.getScriptItem()==ScriptManager.instance.getItem(item.getFullType())));}
   }
   var bottle=module.getItem("WaterBottle").InstanceItem(null);bottle.setID(++nextId);if(bottle.getFluidContainer()==null)throw new AssertionError("original native WaterBottle component absent");bottle.getFluidContainer().Empty();body.getInventory().AddItemBlind(bottle);bottle.setContainer(body.getInventory());
   body.getStats().set(zombie.characters.CharacterStat.THIRST,.8f);
   var row=LuaManager.platform.newTable();row.rawset("body",body);row.rawset("donor",donor);row.rawset("container",container);row.rawset("bottle",bottle);return f.push(row);
  });
  LuaManager.env.rawset("__moveUtilityBody",(JavaFunction)(f,n)->{int x=((Double)f.get(0)).intValue(),y=((Double)f.get(1)).intValue(),z=((Double)f.get(2)).intValue();var square=body.getCell().getGridSquare(x,y,z);if(square==null)throw new AssertionError("actual loaded route endpoint");body.getCurrentSquare().getMovingObjects().remove(body);body.setX(x+.5f);body.setY(y+.5f);body.setZ(z);body.setCurrent(square);body.setSquare(square);square.getMovingObjects().add(body);return f.push(true);});
  LuaManager.env.rawset("__ordinaryInitialPower",(JavaFunction)(f,n)->{
   if(!initialSceneOpen)throw new AssertionError("initial environment only");var g=(zombie.iso.objects.IsoGenerator)f.get(0);g.setFuel(7);g.setConnected(true);g.setActivated(true);System.out.println("ORDINARY_INITIAL_NATIVE_POWER fuel="+g.getFuel()+" connected="+g.isConnected()+" active="+g.isActivated()+" pumpSquareElectricity="+body.getCell().getGridSquare(10,20,0).haveElectricity()+" nativeClass="+g.getClass().getName());if(g.getFuel()!=7||!g.isConnected()||!g.isActivated()||!body.getCell().getGridSquare(10,20,0).haveElectricity())throw new AssertionError("actual initial native power unavailable");return 0;
  });
  LuaManager.env.rawset("__ordinaryInitialMountingWall",(JavaFunction)(f,n)->{
   if(!initialSceneOpen)throw new AssertionError("initial existing geometry only");var q=body.getCell().getGridSquare(10,20,0);var sprite=zombie.iso.sprite.IsoSpriteManager.instance.namedMap.values().stream().filter(a->a.cutW&&!a.cutN&&!a.getProperties().has(zombie.iso.SpriteDetails.IsoFlagType.WallSE)).findFirst().orElseThrow();var wall=new IsoObject(body.getCell(),q,sprite);q.AddTileObject(wall);if(q.getWall(false)!=wall)throw new AssertionError("actual original wall receiver");System.out.println("ORDINARY_INITIAL_WALL sprite="+sprite.name+" cutW="+sprite.cutW+" actualWall=true");return 0;
  });
  LuaManager.env.rawset("__ordinaryInitialStairs",(JavaFunction)(f,n)->{
   for(int k=0;k<3;k++){var above=body.getCell().getGridSquare(11+k,20,1);for(int a=above.getObjects().size()-1;a>=0;a--){var object=above.getObjects().get(a);if(object.getProperties()!=null&&object.getProperties().has(zombie.iso.SpriteDetails.IsoFlagType.solidfloor))above.RemoveTileObject(object);}above.RecalcAllWithNeighbours(true);
    var q=body.getCell().getGridSquare(11+k,20,0);String name="carpentry_02_"+(90-k);var sprite=zombie.iso.sprite.IsoSpriteManager.instance.namedMap.get(name);if(sprite==null||!name.equals(sprite.getName()))throw new AssertionError("native registered household stairs");var object=new IsoObject(body.getCell(),q,sprite);q.AddTileObject(object);if(!q.HasStairsWest()||above.isSolidFloor())throw new AssertionError("native stair footprint/well");}
   if(!body.getCell().getGridSquare(10,20,1).isSolidFloor())throw new AssertionError("real household landing floor");return 0;
  });
  LuaManager.env.rawset("__reviewInitialInputs",(JavaFunction)(f,n)->{if(!initialSceneOpen)throw new AssertionError("initial scene only");var row=LuaManager.platform.newTable();for(String[] pair:new String[][]{{"tool","Base.PipeWrench"},{"pump","SAO.WaterPump"},{"riser","Base.MetalPipe"},{"bypass1","Base.MetalPipe"},{"bypass2","Base.MetalPipe"},{"bypass3","Base.MetalPipe"},{"tail","Base.MetalPipe"},{"feed","Base.MetalPipe"},{"loose","Base.MetalPipe"}}){var item=ScriptManager.instance.getItem(pair[1]).InstanceItem(null);item.setID(++nextId);body.getInventory().AddItemBlind(item);item.setContainer(body.getInventory());row.rawset(pair[0],item);}body.setPrimaryHandItem((InventoryItem)row.rawget("tool"));var q=body.getCell().getGridSquare(12,22,0);var sprite=zombie.iso.sprite.IsoSpriteManager.instance.namedMap.values().stream().filter(a->a.cutW&&!a.cutN&&!a.getProperties().has(zombie.iso.SpriteDetails.IsoFlagType.WallSE)).findFirst().orElseThrow();var wall=new IsoObject(body.getCell(),q,sprite);q.AddTileObject(wall);if(q.getWall(false)!=wall)throw new AssertionError("actual mounting wall");return f.push(row);});
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
  LuaManager.env.rawset("__utilityNativeInventoryFacts",(JavaFunction)(f,n)->{
   var rows=LuaManager.platform.newTable();int count=0;for(var item:body.getInventory().getItems()){
    var row=LuaManager.platform.newTable();row.rawset("itemId",Integer.toString(item.getID()));row.rawset("itemType",item.getFullType());row.rawset("nativeClass",item.getClass().getName());row.rawset("uses",(double)item.getCurrentUses());row.rawset("usesFloat",(double)item.getCurrentUsesFloat());row.rawset("maxUses",(double)item.getMaxUses());row.rawset("held",body.getInventory().contains(item));row.rawset("containerExact",item.getContainer()==body.getInventory());row.rawset("registeredExact",item.getScriptItem()==ScriptManager.instance.getItem(item.getFullType()));row.rawset("craftingConsumed",item.getIsCraftingConsumed());row.rawset("hasWorldItem",item.getWorldItem()!=null);row.rawset("hasTexture",item.getTex()!=null);if(item.getTex()!=null)row.rawset("textureName",item.getTex().getName());row.rawset("primary",body.getPrimaryHandItem()==item);if(item.hasModData())row.rawset("networkPartMarker",item.getModData().rawget("SAOWaterNetworkPart"));rows.rawset((double)++count,row);
   }return f.push(rows);
  });
  LuaManager.env.rawset("__utilityPlacedNetworkFacts",(JavaFunction)(f,n)->{
   var rows=LuaManager.platform.newTable();int count=0;
   for(int x=8;x<=14;x++)for(int y=18;y<=23;y++)for(int z=0;z<=1;z++){
    var square=body.getCell().getGridSquare(x,y,z);if(square==null)continue;
    for(int a=0;a<square.getWorldObjects().size();a++){var object=square.getWorldObjects().get(a);var item=object.getItem();if(item==null)continue;var row=LuaManager.platform.newTable();row.rawset("itemId",Integer.toString(item.getID()));row.rawset("itemType",item.getFullType());row.rawset("nativeClass",object.getClass().getName());row.rawset("itemClass",item.getClass().getName());row.rawset("x",(double)x);row.rawset("y",(double)y);row.rawset("z",(double)z);row.rawset("backlinkExact",item.getWorldItem()==object);row.rawset("containerNull",item.getContainer()==null);row.rawset("containerInventory",item.getContainer()==body.getInventory());row.rawset("held",body.getInventory().contains(item));row.rawset("scriptExact",item.getScriptItem()==ScriptManager.instance.getItem(item.getFullType()));row.rawset("condition",(double)item.getCondition());row.rawset("objectIndex",(double)object.getWorldObjectIndex());row.rawset("rotationX",(double)item.getWorldXRotation());row.rawset("rotationY",(double)item.getWorldYRotation());row.rawset("rotationZ",(double)item.getWorldZRotation());if(item.hasModData())row.rawset("marker",item.getModData().rawget("SAOWaterNetworkPart"));rows.rawset((double)++count,row);}
   }return f.push(rows);
  });
  LuaManager.env.rawset("__utilityCurrentGeneratorFacts",(JavaFunction)(f,n)->{
   var g=(zombie.iso.objects.IsoGenerator)f.get(0);var row=LuaManager.platform.newTable();row.rawset("fuel",(double)g.getFuel());row.rawset("active",g.isActivated());row.rawset("connected",g.isConnected());row.rawset("nativeClass",g.getClass().getName());row.rawset("poweredSquare",g.getSquare().haveElectricity());if(g.hasModData())row.rawset("ownedFuelConnection",g.getModData().rawget("SAOHouseholdFuelConnection"));return f.push(row);
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
  for(int i=1;i<args.length;i++){loadOriginal(Path.of(args[i]));if(Path.of(args[i]).getFileName().toString().endsWith("-scene.lua")||Path.of(args[i]).getFileName().toString().endsWith("-network_scene.lua"))initialSceneOpen=false;}
 }
}
