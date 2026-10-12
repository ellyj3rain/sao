import java.nio.file.*;
import java.util.*;
import se.krka.kahlua.vm.*;
import zombie.Lua.LuaManager;
import com.sao.engine.SAOWorldSources;
public final class SiteObserverNativeProbe {
 static void floors(Path game,com.sao.engine.SAOIsoPlayerShell body)throws Exception{
  var names=Set.of("carpentry_01_24","carpentry_01_25","carpentry_01_26","carpentry_01_27","crafted_01_120","crafted_01_121","crafted_01_122","crafted_01_123","floors_interior_tilesandwood_01_0");
  var found=new LinkedHashMap<String,Map<String,String>>();
  try(var in=new java.io.DataInputStream(new java.io.BufferedInputStream(Files.newInputStream(game.resolve("media/newtiledefinitions.tiles"))))){
   if(!Arrays.equals(in.readNBytes(4),new byte[]{'t','d','e','f'})||WorkspaceBuildNativeProbe.integer(in)!=1)throw new IllegalStateException("native tile format");
   int sets=WorkspaceBuildNativeProbe.integer(in);for(int s=0;s<sets;s++){String name=WorkspaceBuildNativeProbe.line(in);WorkspaceBuildNativeProbe.line(in);WorkspaceBuildNativeProbe.integer(in);WorkspaceBuildNativeProbe.integer(in);WorkspaceBuildNativeProbe.integer(in);int count=WorkspaceBuildNativeProbe.integer(in);
    for(int i=0;i<count;i++){var props=new LinkedHashMap<String,String>();int n=WorkspaceBuildNativeProbe.integer(in);for(int j=0;j<n;j++)props.put(WorkspaceBuildNativeProbe.line(in),WorkspaceBuildNativeProbe.line(in));if(names.contains(name+"_"+i))found.put(name+"_"+i,props);}
   }
  }
  var fp=found.get("floors_interior_tilesandwood_01_0");if(fp==null||!fp.containsKey("solidfloor"))throw new IllegalStateException("original native floor metadata required");
  var aliases=new HashMap<String,ArrayList<String>>();for(var props:found.values())for(var p:props.entrySet()){var values=aliases.computeIfAbsent(p.getKey(),k->new ArrayList<>());if(!values.contains(p.getValue()))values.add(p.getValue());}
  zombie.core.TilePropertyAliasMap.instance.Generate(aliases);
  for(var row:found.entrySet()){var sprite=zombie.iso.sprite.IsoSpriteManager.instance.getSprite(row.getKey());if(sprite==null)sprite=zombie.iso.sprite.IsoSpriteManager.instance.AddSprite(row.getKey());sprite.name=row.getKey();sprite.getProperties().Clear();for(var p:row.getValue().entrySet())sprite.getProperties().set(p.getKey(),p.getValue());}
  var sprite=zombie.iso.sprite.IsoSpriteManager.instance.getSprite("floors_interior_tilesandwood_01_0");
  for(int x=8;x<=22;x++)for(int y=17;y<=24;y++){var square=body.getCell().getGridSquare(x,y,0);var floor=new zombie.iso.IsoObject(body.getCell(),square,sprite);square.getObjects().add(floor);square.setSolidFloor(true);}
 }
 public static void main(String[] args)throws Exception {
  WorkspaceBuildNativeProbe.main(new String[]{args[0]});
  var body=WorkspaceBuildNativeProbe.body;body.getModData().rawset("SAOPersonId","workspace-person");
  body.getCell().getObjectList().add(body);body.getCurrentSquare().getMovingObjects().add(body);
  floors(Path.of(args[0]),body);
  LuaManager.env.rawset("__position",(JavaFunction)(f,n)->{int x=((Double)f.get(0)).intValue(),y=((Double)f.get(1)).intValue();var s=body.getCell().getGridSquare(x,y,0);
    body.getSquare().getMovingObjects().remove(body);body.setX(x+.5f);body.setY(y+.5f);body.setCurrent(s);body.setSquare(s);body.setLast(s);s.getMovingObjects().add(body);return f.push(true);});
  var sao=LuaManager.platform.newTable();var bodies=LuaManager.platform.newTable();var active=LuaManager.platform.newTable();active.rawset("workspace-person",body);bodies.rawset("active",active);sao.rawset("Body",bodies);LuaManager.env.rawset("SAO",sao);
  var root=zombie.world.moddata.GlobalModData.instance.getOrCreate("SurvivorAwareness_Records");var records=LuaManager.platform.newTable();var record=LuaManager.platform.newTable();record.rawset("id","workspace-person");record.rawset("dead",false);records.rawset("workspace-person",record);root.rawset("records",records);
  WorkspaceBuildNativeProbe.expose(SAOWorldSources.class);
  LuaManager.env.rawset("__actorRecord",record);
  LuaManager.env.rawset("__sceneRoom",(JavaFunction)(f,n)->{var square=(zombie.iso.IsoGridSquare)f.get(0);boolean assigned=(Boolean)f.get(1);square.room=assigned?new zombie.iso.areas.IsoRoom():null;square.roomId=assigned?101:-1;return f.push(true);});
  var originals=new HashMap<String,zombie.scripting.entity.components.crafting.CraftRecipe>();
  LuaManager.env.rawset("__sourceRecipeRegistration",(JavaFunction)(f,n)->{try{
   String entity=(String)f.get(0);boolean restore=(Boolean)f.get(1);var e=zombie.scripting.ScriptManager.instance.getGameEntityScript(entity);
   var original=((zombie.scripting.entity.components.crafting.CraftRecipeComponentScript)e.getComponentScriptFor(zombie.entity.ComponentType.CraftRecipe)).getCraftRecipe();String id=original.getScriptObjectFullType();originals.putIfAbsent(id,original);
   var field=zombie.scripting.ScriptManager.class.getDeclaredField("craftRecipes");field.setAccessible(true);var collection=(zombie.scripting.ScriptBucketCollection)field.get(zombie.scripting.ScriptManager.instance);
   collection.getFullTypeToScriptMap().put(id,restore?originals.get(id):new zombie.scripting.entity.components.crafting.CraftRecipe());return f.push(true);
  }catch(Exception e){throw new IllegalStateException(e);}});
  LuaManager.env.rawset("__replaceSceneFloor",(JavaFunction)(f,n)->{var square=(zombie.iso.IsoGridSquare)f.get(0);var old=(zombie.iso.IsoObject)f.get(1);var replacement=new zombie.iso.IsoObject(body.getCell(),square,old.getSprite());square.getObjects().set(0,replacement);return f.push(replacement);});
  LuaManager.env.rawset("__restoreSceneFloor",(JavaFunction)(f,n)->{var square=(zombie.iso.IsoGridSquare)f.get(0);square.getObjects().set(0,(zombie.iso.IsoObject)f.get(1));return f.push(true);});
  LuaManager.env.rawset("__nativeSiteRoundtrip",(JavaFunction)(f,n)->{try{var bytes=java.nio.ByteBuffer.allocate(1048576);((KahluaTable)f.get(0)).save(bytes);bytes.flip();var result=LuaManager.platform.newTable();result.load(bytes,zombie.iso.IsoWorld.WorldVersion);return f.push(result);}catch(Exception e){throw new IllegalStateException(e);}});
  for(int i=1;i<args.length;i++)WorkspaceBuildNativeProbe.run(Files.readString(Path.of(args[i])),args[i]);
 }
}
