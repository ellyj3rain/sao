import java.lang.reflect.*;
import java.nio.file.*;
import java.util.*;
import se.krka.kahlua.vm.*;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import zombie.Lua.LuaManager;
import zombie.iso.*;
import zombie.inventory.*;
import zombie.entity.ComponentType;
import zombie.entity.components.crafting.recipe.*;
import com.sao.engine.SAOIsoPlayerShell;

/** Private native construction effect fixture. Loaded map and skill scene input;
 * actual shell/items/BuildLogic/action/create/factory. No SAO admission claim. */
public final class WorkspaceBuildNativeProbe {
  static SAOIsoPlayerShell body; static int itemId=800;
  static Object fixture(String name,Class<?>[] signature,Object...args)throws Exception {
    var m=MovementCrossingProbe.class.getDeclaredMethod(name,signature);m.setAccessible(true);return m.invoke(null,args);
  }
  static void run(String source,String label)throws Exception {
    var result=LuaManager.thread.pcall(LuaCompiler.loadstring(source,label,LuaManager.env),new Object[0]);
    if(!Boolean.TRUE.equals(result[0]))throw new AssertionError(Arrays.toString(result));
  }
  static void expose(Class<?> type){ConstructionPolicyNativeProbe.expose(type);}
  static InventoryItem give(String type)throws Exception {
    boolean before=zombie.network.GameServer.server;zombie.network.GameServer.server=true;
    InventoryItem item;try{item=ConstructionPolicyNativeProbe.module.getItem(type).InstanceItem(null);}finally{zombie.network.GameServer.server=before;}
    item.setID(++itemId);body.getInventory().AddItemBlind(item);item.setContainer(body.getInventory());return item;
  }
  static int integer(java.io.DataInputStream in)throws Exception{return Integer.reverseBytes(in.readInt());}
  static String line(java.io.DataInputStream in)throws Exception {
    var bytes=new java.io.ByteArrayOutputStream();int c;while((c=in.read())!='\n'){if(c<0)throw new java.io.EOFException();bytes.write(c);}return bytes.toString(java.nio.charset.StandardCharsets.UTF_8).trim();
  }
  static void tileMetadata(Path game)throws Exception {
    var selected=Set.of("carpentry_01_24","carpentry_01_25","carpentry_01_26","carpentry_01_27","crafted_01_120","crafted_01_121","crafted_01_122","crafted_01_123");
    var found=new LinkedHashMap<String,Map<String,String>>();
    try(var in=new java.io.DataInputStream(new java.io.BufferedInputStream(Files.newInputStream(game.resolve("media/newtiledefinitions.tiles"))))){
      if(!Arrays.equals(in.readNBytes(4),new byte[]{'t','d','e','f'})||integer(in)!=1)throw new IllegalStateException("native tile format");
      int sets=integer(in);for(int s=0;s<sets;s++){String name=line(in);line(in);integer(in);integer(in);integer(in);int count=integer(in);
        for(int i=0;i<count;i++){var props=new LinkedHashMap<String,String>();int n=integer(in);for(int j=0;j<n;j++)props.put(line(in),line(in));if(selected.contains(name+"_"+i))found.put(name+"_"+i,props);}
      }
    }
    var aliases=new HashMap<String,ArrayList<String>>();for(var props:found.values())for(var p:props.entrySet()){var values=aliases.computeIfAbsent(p.getKey(),k->new ArrayList<>());if(!values.contains(p.getValue()))values.add(p.getValue());}
    zombie.core.TilePropertyAliasMap.instance.Generate(aliases);
    for(var row:found.entrySet()){var sprite=zombie.iso.sprite.IsoSpriteManager.instance.getSprite(row.getKey());for(var p:row.getValue().entrySet())sprite.getProperties().set(p.getKey(),p.getValue());}
    for(String face:List.of("S","E")){var grid=new zombie.iso.sprite.IsoSpriteGrid(face.equals("S")?2:1,face.equals("S")?1:2);
      for(String name:face.equals("S")?List.of("carpentry_01_24","carpentry_01_25"):List.of("carpentry_01_26","carpentry_01_27")){var sprite=zombie.iso.sprite.IsoSpriteManager.instance.getSprite(name);var pos=found.get(name).get("SpriteGridPos").split(",");grid.setSprite(Integer.parseInt(pos[0]),Integer.parseInt(pos[1]),sprite);sprite.setSpriteGrid(grid);}
    }
  }
  public static void main(String[] args)throws Exception {
    var cell=(IsoCell)fixture("boot",new Class<?>[0]);
    ConstructionPolicyNativeProbe.main(new String[]{args[0]});
    tileMetadata(Path.of(args[0]));
    var rc=zombie.iso.areas.isoregion.IsoRegionWorker.class.getDeclaredConstructor();rc.setAccessible(true);
    var rf=zombie.iso.areas.isoregion.IsoRegions.class.getDeclaredField("regionWorker");rf.setAccessible(true);rf.set(null,rc.newInstance());
    var polygon=zombie.pathfind.PolygonalMap2.instance;
    var pc=Class.forName("zombie.pathfind.PolygonalMap2$PMThread").getDeclaredConstructor(zombie.pathfind.PolygonalMap2.class);pc.setAccessible(true);
    var pf=zombie.pathfind.PolygonalMap2.class.getDeclaredField("thread");pf.setAccessible(true);pf.set(polygon,pc.newInstance(polygon));
    zombie.entity.GameEntityManager.Init(1);
    body=(SAOIsoPlayerShell)fixture("person",new Class<?>[]{IsoCell.class},cell);
    body.setSquare(body.getCurrentSquare());body.setForwardDirection(1,0);
    body.LevelPerk(zombie.characters.skills.PerkFactory.Perks.Woodwork,false);
    body.getInventory().getItems().clear();var hammer=give("Hammer");
    var recipe=((zombie.scripting.entity.components.crafting.CraftRecipeComponentScript)ConstructionPolicyNativeProbe.entities.get("Wood_TableLvl1").getComponentScriptFor(ComponentType.CraftRecipe)).getCraftRecipe();
    System.out.println("HAMMER_VALID "+CraftRecipeManager.isItemValidForInputScript(recipe.getInputs().get(0),hammer,body));
    for(Class<?> type:new Class<?>[]{SAOIsoPlayerShell.class,IsoCell.class,IsoGridSquare.class,
        zombie.iso.objects.IsoThumpable.class,zombie.iso.sprite.IsoSprite.class,zombie.iso.sprite.IsoSpriteManager.class,
        zombie.core.properties.PropertyContainer.class,zombie.iso.SpriteDetails.IsoFlagType.class,
        zombie.iso.SpriteDetails.IsoObjectType.class,zombie.core.properties.IsoPropertyType.class,
        zombie.entity.GameEntityFactory.class,zombie.characters.skills.PerkFactory.Perks.class,
        zombie.characters.CharacterTimedActions.LuaTimedActionNew.class,zombie.characters.CharacterTimedActions.BaseAction.class,
        zombie.characters.DummyCharacterSoundEmitter.class,zombie.characters.PlayerCraftHistory.class,zombie.inventory.types.HandWeapon.class,zombie.scripting.objects.TimedActionScript.class,
        zombie.characters.IsoGameCharacter.XP.class,zombie.util.list.PZArrayList.class,zombie.scripting.objects.CharacterTrait.class,
        CraftRecipeData.class,zombie.entity.components.crafting.BaseCraftingLogic.class})expose(type);
    var env=LuaManager.env;env.rawset("__body",body);env.rawset("__cell",cell);env.rawset("__hammer",hammer);
    env.rawset("__position",(JavaFunction)(f,n)->{int x=((Double)f.get(0)).intValue(),y=((Double)f.get(1)).intValue();var square=cell.getGridSquare(x,y,0);body.setX(x+.5f);body.setY(y+.5f);body.setCurrent(square);body.setSquare(square);return f.push(true);});
    env.rawset("__debugEligible",(JavaFunction)(f,n)->f.push(CraftRecipeManager.isItemValidForInputScript((zombie.scripting.entity.components.crafting.InputScript)f.get(0),(InventoryItem)f.get(1),body)));
    env.rawset("__give",(JavaFunction)(f,n)->{try{return f.push(give((String)f.get(0)));}catch(Exception e){throw new IllegalStateException(e);}});
    env.rawset("__sprite",(JavaFunction)(f,n)->f.push(zombie.iso.sprite.IsoSpriteManager.instance.getSprite((String)f.get(0))));
    env.rawset("__newThumpable",(JavaFunction)(f,n)->f.push(new zombie.iso.objects.IsoThumpable(cell,(IsoGridSquare)f.get(0),(String)f.get(1),(Boolean)f.get(2),(KahluaTable)f.get(3))));
    env.rawset("__instanceof",(JavaFunction)(f,n)->f.push(LuaManager.GlobalObject.isType(f.get(0),(String)f.get(1))));
    env.rawset("__summary",(JavaFunction)(f,n)->{try{Files.writeString(Path.of(System.getProperty("user.home")).resolve("measurement.json"),(String)f.get(0));return 0;}catch(Exception e){throw new IllegalStateException(e);}});
    for(int i=1;i<args.length;i++)run(Files.readString(Path.of(args[i])),args[i]);
  }
}
