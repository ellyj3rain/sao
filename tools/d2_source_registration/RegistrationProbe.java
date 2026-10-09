import java.nio.file.*;
import java.util.*;
import java.lang.reflect.*;
import zombie.scripting.ScriptParser;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.*;

/** Actual installed registration parsers and native registry receivers; no rendering host. */
public final class RegistrationProbe {
 static int checks;
 static void check(String name,boolean v){if(!v)throw new AssertionError(name);checks++;System.out.println("CASE "+name);}
 static Object field(Object o,String name)throws Exception{Field f=o.getClass().getDeclaredField(name);f.setAccessible(true);return f.get(o);}
 static Object parse(Class<?>type,String text)throws Exception{Object obj=type.getConstructor().newInstance();Method m=type.getDeclaredMethod("parse",String.class);m.setAccessible(true);m.invoke(obj,text);return obj;}
 static String signature(Object o,boolean omitPage)throws Exception{var keys=new TreeMap<String,String>();for(Field f:o.getClass().getFields()){if(Modifier.isStatic(f.getModifiers())||(omitPage&&f.getName().equals("page")))continue;Object v=f.get(o);keys.put(f.getName(),v instanceof int[]?Arrays.toString((int[])v):String.valueOf(v));}return o.getClass().getSimpleName()+keys;}
 static Map<String,String> optionMap(String text,boolean perks)throws Exception{Object parsed=parse(perks?zombie.characters.skills.CustomPerks.class:zombie.sandbox.CustomSandboxOptions.class,text);var rows=(List<?>)field(parsed,perks?"perks":"options");var out=new LinkedHashMap<String,String>();for(Object row:rows){String id=(String)row.getClass().getField("id").get(row);check("unique_native_"+id,out.put(id,signature(row,!perks))==null);}return out;}
 static Map<String,String> pageMap(String text)throws Exception{Object parsed=parse(zombie.sandbox.CustomSandboxOptions.class,text);var rows=(List<?>)field(parsed,"options");var out=new LinkedHashMap<String,String>();for(Object row:rows)out.put((String)row.getClass().getField("id").get(row),(String)row.getClass().getField("page").get(row));return out;}
 static void merge(Map<String,String>target,Map<String,String>rows){for(var entry:rows.entrySet()){String old=target.putIfAbsent(entry.getKey(),entry.getValue());check("native_fragment_nonconflict_"+entry.getKey(),old==null||old.equals(entry.getValue()));}}
 public static void main(String[]args)throws Exception{
  Thread.setDefaultUncaughtExceptionHandler((t,e)->{e.printStackTrace();System.exit(1);});
  var platform=new J2SEPlatform();var env=platform.newEnvironment();var thread=new KahluaThread(platform,env);thread.debugOwnerThread=Thread.currentThread();LuaCompiler.register(env);
  zombie.Lua.LuaManager.platform=platform;zombie.Lua.LuaManager.env=env;zombie.Lua.LuaManager.thread=thread;zombie.Lua.LuaManager.converterManager=new se.krka.kahlua.converter.KahluaConverterManager();zombie.Lua.LuaManager.caller=new se.krka.kahlua.integration.LuaCaller(zombie.Lua.LuaManager.converterManager);
  zombie.ZomboidFileSystem.instance.base.set(Path.of(args[2]).toFile());
  ((zombie.ZomboidFileSystem.PZFolder)field(zombie.ZomboidFileSystem.instance,"workdir")).set(Path.of(args[2]).toFile());
  zombie.tileDepth.TileGeometryManager.getInstance().initGameData();
  Path merged=Path.of(args[0]);var expected=new LinkedHashMap<String,List<Path>>();for(String row:Files.readAllLines(Path.of(args[1]))){String[]parts=row.split("\t",2);expected.computeIfAbsent(parts[0],k->new ArrayList<>()).add(Path.of(parts[1]));}
  var saoPages=new LinkedHashMap<String,String>();for(String line:Files.readAllLines(Path.of(args[3]))){String[]parts=line.split("\t",2);check("unique_sao_page_"+parts[0],saoPages.put(parts[0],parts[1])==null);}check("seven_source_page_option_count",saoPages.size()==156);
  for(String name:List.of("sandbox-options.txt","perks.txt")){
   boolean perks=name.equals("perks.txt");var all=new LinkedHashMap<String,String>();for(Path original:expected.get("media/"+name))merge(all,optionMap(Files.readString(original),perks));var actual=optionMap(Files.readString(merged.resolve("media/"+name)),perks);check("actual_native_merged_"+name,all.equals(actual));
   if(perks){var registeredPerks=(zombie.characters.skills.CustomPerks)parse(zombie.characters.skills.CustomPerks.class,Files.readString(merged.resolve("media/"+name)));registeredPerks.init();for(String id:actual.keySet()){var perk=zombie.characters.skills.PerkFactory.Perks.FromString(id);check("actual_native_perk_registered_"+id,perk!=null&&perk!=zombie.characters.skills.PerkFactory.Perks.None&&perk.isCustom());}}
   if(!perks){String sourceText=Files.readString(merged.resolve("media/"+name));var actualPages=pageMap(sourceText);Object parsed=parse(zombie.sandbox.CustomSandboxOptions.class,sourceText);var options=new zombie.SandboxOptions();((zombie.sandbox.CustomSandboxOptions)parsed).initInstance(options);for(String id:actual.keySet())check("native_sandbox_bound_"+id,options.getOptionByName(id)!=null);for(var row:saoPages.entrySet()){check("native_sao_page_"+row.getKey(),row.getValue().equals(actualPages.get(row.getKey())));check("native_sao_page_bound_"+row.getKey(),row.getValue().equals(options.getOptionByName(row.getKey()).getPageName()));}
    var originalPath=expected.get("media/sandbox-options.txt").stream().filter(path->path.toString().contains("LifestyleHobbies")).findFirst().orElseThrow();
    var originalText=Files.readString(originalPath);var originalDefs=(zombie.sandbox.CustomSandboxOptions)parse(zombie.sandbox.CustomSandboxOptions.class,originalText);var ownedDefs=(zombie.sandbox.CustomSandboxOptions)parsed;
    int initial=new zombie.SandboxOptions().getNumOptions();var externalLast=new zombie.SandboxOptions();ownedDefs.initInstance(externalLast);originalDefs.initInstance(externalLast);var ownedLast=new zombie.SandboxOptions();originalDefs.initInstance(ownedLast);ownedDefs.initInstance(ownedLast);
    check("native_dual_registration_keeps_both_indexed",externalLast.getNumOptions()==initial+actual.size()+pageMap(originalText).size()&&ownedLast.getNumOptions()==externalLast.getNumOptions());
    check("native_external_last_page_owner","LifestyleHC".equals(externalLast.getOptionByName("LSHygiene.OuthouseRange").getPageName()));
    check("native_sao_last_page_owner","SAO_LifestyleHobbies_Hygiene".equals(ownedLast.getOptionByName("LSHygiene.OuthouseRange").getPageName()));
    for(var pair:List.of(externalLast,ownedLast)){pair.set("LSHygiene.OuthouseRange","33");check("native_saved_id_lifestyle",pair.getOptionByName("LSHygiene.OuthouseRange").asConfigOption().getValueAsString().equals("33"));}
    var sampleValues=new LinkedHashMap<String,Object>();sampleValues.put("NewMusic.MaxTrackingRange",1777);sampleValues.put("ComputerMod.DiscSpawnChance",33);sampleValues.put("ProjectArcade.SfxVolumePct",47);sampleValues.put("FWOFitness.XPMultiplier",2.0);sampleValues.put("FWOWorkingTreadmill.FitnessXPMultiply",3.0);sampleValues.put("KnoxAquarium.ComfortRange",9);
    for(var entry:sampleValues.entrySet()){options.set(entry.getKey(),entry.getValue().toString());check("native_saved_id_"+entry.getKey(),options.getOptionByName(entry.getKey()).asConfigOption().getValueAsString().equals(entry.getValue().toString()));}
   }
  }
  for(String name:List.of("tileGeometry.txt","tileDepthTextureAssignments.txt")){
   var root=ScriptParser.parse(ScriptParser.stripComments(Files.readString(merged.resolve("media/"+name))));check("single_native_wrapper_"+name,root.children.size()==1);var block=root.children.get(0);check("native_version_"+name,block.getValue("VERSION")!=null);
   if(name.equals("tileGeometry.txt")){
    Object geometry=new zombie.tileDepth.TileGeometryFile();Method method=geometry.getClass().getDeclaredMethod("parseFile",String.class);method.setAccessible(true);method.invoke(geometry,Files.readString(merged.resolve("media/"+name)));var rows=(List<?>)field(geometry,"tilesets");var seen=new HashSet<String>();int tiles=0;for(Object tileset:rows){check("native_tileset_unique_"+field(tileset,"name"),seen.add((String)field(tileset,"name")));tiles+=((List<?>)field(tileset,"tiles")).size();}var wantedTilesets=new LinkedHashMap<String,String>();for(Path original:expected.get("media/"+name)){var fragment=ScriptParser.parse(ScriptParser.stripComments(Files.readString(original))).children.get(0);for(var tile:fragment.children){var printed=new StringBuilder();tile.prettyPrint(0,printed);wantedTilesets.put(tile.getValue("name").getValue().trim(),printed.toString());}}var actualTilesets=new LinkedHashMap<String,String>();for(var tile:block.children){var printed=new StringBuilder();tile.prettyPrint(0,printed);actualTilesets.put(tile.getValue("name").getValue().trim(),printed.toString());}check("native_geometry_full_fragment_parity",actualTilesets.equals(wantedTilesets));check("native_horse_geometry_retained",seen.contains("rugs_animals_horse"));check("native_imported_geometry_present",seen.stream().anyMatch(v->v.startsWith("LS_"))&&seen.stream().anyMatch(v->v.startsWith("pa_")));System.out.println("NATIVE_GEOMETRY "+rows.size()+" tilesets "+tiles+" tiles");
   }else{
    Object depth=new zombie.tileDepth.TileDepthTextureAssignments(merged.resolve("media").toString());Method method=depth.getClass().getDeclaredMethod("parseFile",String.class);method.setAccessible(true);method.invoke(depth,Files.readString(merged.resolve("media/"+name)));var actual=(Map<?,?>)field(depth,"assignments");var wanted=new HashMap<String,String>();wanted.put("VERSION","1");for(Path original:expected.get("media/"+name)){var fragment=ScriptParser.parse(ScriptParser.stripComments(Files.readString(original))).children.get(0);for(var value:fragment.values)if(!value.getKey().trim().equals("VERSION"))wanted.put(value.getKey().trim(),value.getValue().trim());}check("native_depth_exact_merge",actual.equals(wanted));System.out.println("NATIVE_DEPTH "+actual.size());
   }
  }
  var table=zombie.util.PZXmlUtil.parse(zombie.FileGuidTable.class,merged.resolve("media/fileGuidTable.xml").toString());table.loaded();check("native_fileguid_two",table.files.size()==2);for(var pair:table.files){check("native_guid_binding",table.getGuidFromFilePath(pair.path)!=null);}
  var traits=platform.newTable();var tags=platform.newTable();Set<String>registered=new HashSet<>();
  traits.rawset("register",(JavaFunction)(frame,count)->{String name=(String)frame.get(0);check("native_trait_single_registration_"+name,registered.add(name));return frame.push(zombie.scripting.objects.CharacterTrait.register(name));});
  tags.rawset("register",(JavaFunction)(frame,count)->frame.push(zombie.scripting.objects.ItemTag.register((String)frame.get(0))));env.rawset("CharacterTrait",traits);env.rawset("ItemTag",tags);
  thread.call(LuaCompiler.loadstring(Files.readString(merged.resolve("media/registries.lua")),"actual-canonical-registry",env),null,null,null);check("actual_source_traits_registered",registered.size()==40);for(String name:registered)check("actual_native_trait_identity_"+name,zombie.scripting.objects.CharacterTrait.get(zombie.scripting.objects.ResourceLocation.of(name))!=null);
  check("actual_source_item_tag_registered",tags.rawget("LSInvention")!=null);
  System.out.println("PASS native registrations "+checks);System.exit(0);
 }
}
