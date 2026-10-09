import java.nio.file.*;import java.util.regex.*;
import zombie.Lua.LuaManager;import zombie.scripting.*;import zombie.scripting.objects.*;import zombie.world.*;
import se.krka.kahlua.vm.*;import se.krka.kahlua.converter.KahluaConverterManager;
/** Installed exposed String factory path, installed item definitions, isolated dictionary IDs. */
final class ResidualBookBridge {
 static final class Info extends ItemInfo {Info(Item i,short id){name=i.getName();moduleName="Base";fullType="Base."+name;registryId=id;isLoaded=true;scriptItem=i;entityScript=i;modId="pz-vanilla";}}
 static final class Dictionary extends DictionaryData {void add(Item i,short id){var info=new Info(i,id);itemIdToInfoMap.put(id,info);itemTypeToInfoMap.put(info.getFullType(),info);}}
 static void init(se.krka.kahlua.j2se.J2SEPlatform p,KahluaTable env,KahluaThread thread)throws Exception{
  zombie.GameWindow.gameThread=Thread.currentThread();zombie.core.random.RandStandard.INSTANCE.init();zombie.GameTime.setInstance(new zombie.GameTime());
  zombie.ZomboidFileSystem.instance.setCacheDir(Path.of("native-cache").toAbsolutePath().toString());zombie.ZomboidFileSystem.instance.base.set(new java.io.File("."));
  LuaManager.platform=p;LuaManager.converterManager=new KahluaConverterManager();zombie.Lua.KahluaNumberConverter.install(LuaManager.converterManager);
  LuaManager.exposer=new LuaManager.Exposer(LuaManager.converterManager,p,env);LuaManager.caller=new se.krka.kahlua.integration.LuaCaller(LuaManager.converterManager);
  var dictionary=new Dictionary();var data=WorldDictionary.class.getDeclaredField("data");data.setAccessible(true);data.set(null,dictionary);
  var module=new ScriptModule();module.name="Base";ScriptManager.instance.moduleMap.put("Base",module);
  String raw=ScriptParser.stripComments(Files.readString(Path.of("C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid/media/scripts/generated/items/literature.txt")));
  short id=7101;for(String name:new String[]{"Notebook","BookCarpentry1","ElectronicsMag1"}){
   var m=Pattern.compile("\\bitem\\s+"+name+"\\s*\\{").matcher(raw);if(!m.find())throw new AssertionError(name);int stop=m.end(),depth=1;while(depth>0){char c=raw.charAt(stop++);if(c=='{')depth++;else if(c=='}')depth--;}
   var item=new Item();item.setModule(module);item.setName(name);item.Load(name,raw.substring(m.start(),stop));item.setRegistry_id(id);module.items.getScriptMap().put(name,item);dictionary.add(item,id++);
  }
  for(Class<?> type:new Class<?>[]{zombie.inventory.InventoryItem.class,zombie.inventory.types.Literature.class,zombie.core.textures.Texture.class,java.util.ArrayList.class}){LuaManager.exposer.setExposed(type);LuaManager.exposer.exposeLikeJava(type,env);}
  var method=LuaManager.GlobalObject.class.getMethod("instanceItem",String.class);
  LuaManager.exposer.exposeGlobalClassFunction(env,LuaManager.GlobalObject.class,method,"nativeInstanceItem");
  env.rawset("nativeTexture",(JavaFunction)(f,n)->{var item=(zombie.inventory.InventoryItem)f.get(0);var texture=new zombie.core.textures.Texture();texture.setNameOnly("qualified-item-icon.png");item.setTexture(texture);return f.push(texture);});
 }
}
