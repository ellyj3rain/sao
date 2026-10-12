import com.sao.engine.SAOWindowPaneDefinitions;
import java.lang.reflect.Field;
import java.nio.ByteBuffer;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.regex.Pattern;
import zombie.ZomboidFileSystem;
import zombie.scripting.ScriptLoadMode;
import zombie.scripting.ScriptManager;
import zombie.scripting.ScriptParser;
import zombie.scripting.objects.Item;
import zombie.scripting.objects.ScriptModule;
import zombie.inventory.InventoryItemFactory;
import zombie.world.DictionaryData;
import zombie.world.ItemInfo;
import zombie.world.WorldDictionary;

/** Installed script loaders/factory and production weave; isolated dictionary
 * data, no loaded game, real save, renderer or peer runtime. */
public final class WindowPaneNativeProbe {
    private static int checks;
    private static void check(String name,boolean value){System.out.println("CHECK "+name+"="+value);checks++;if(!value)throw new AssertionError(name);}
    private static String block(Path file,String kind,String name)throws Exception{
        String text=ScriptParser.stripComments(Files.readString(file));
        var match=Pattern.compile("\\b"+kind+"\\s+"+Pattern.quote(name)+"\\s*\\{").matcher(text);
        if(!match.find())throw new AssertionError("native definition missing: "+name);
        int end=match.end(),depth=1;
        while(depth>0&&end<text.length()){char c=text.charAt(end++);if(c=='{')depth++;else if(c=='}')depth--;}
        if(depth!=0)throw new AssertionError("native definition unclosed: "+name);
        return text.substring(match.start(),end);
    }
    private static void context(String mod)throws Exception{
        for(String name:new String[]{"currentLoadFileMod","currentLoadFileAbsPath","currentLoadFileName"}){
            Field field=ScriptManager.class.getDeclaredField(name);field.setAccessible(true);field.set(null,mod);
        }
        ScriptManager.instance.currentFileName=mod;
    }
    private static ScriptModule module(String name){
        ScriptManager.instance.ParseScript(ScriptLoadMode.Init,"module "+name+" { }");
        return ScriptManager.instance.moduleMap.get(name);
    }
    private static final class Info extends ItemInfo {
        Info(Item item,short id){name=item.getName();moduleName=item.getModuleName();fullType=item.getFullName();
            registryId=id;isLoaded=true;scriptItem=item;entityScript=item;modId=item.getModID();}
    }
    private static final class Dictionary extends DictionaryData {
        void register(Item item,short id){var info=new Info(item,id);itemIdToInfoMap.put(id,info);itemTypeToInfoMap.put(info.getFullType(),info);}
        void admit(java.util.Map<String,ItemInfo> pending)throws Exception{nextInfoId=2000;parseInfoLoadList(pending);parseCurrentInfoSet();}
        short id(String type){return getItemRegistryID(type);}
        ByteBuffer bytes()throws Exception{var bytes=ByteBuffer.allocate(1048576);saveToByteBuffer(bytes);bytes.flip();return bytes;}
        void restore(ByteBuffer bytes)throws Exception{loadFromByteBuffer(bytes);}
    }
    public static void main(String[] args)throws Exception{
        Path game=Path.of(args[0]);String mode=args[1];
        String cache=System.getProperty("sao.paneFixtureCache");
        if(cache!=null)ZomboidFileSystem.instance.setCacheDir(cache);
        zombie.core.random.RandStandard.INSTANCE.init();ZomboidFileSystem.instance.init();
        if(Boolean.getBoolean("sao.paneNormalMain")){
            // Execute the supported shipping entry without the special pane
            // agent. Only the existing dedicated renderer branch is selected
            // to avoid initializing graphics in this isolated process.
            boolean server=zombie.network.GameServer.server;
            zombie.network.GameServer.server=true;
            try { Class.forName("com.sao.Main").getMethod("main",String[].class).invoke(null,(Object)new String[0]); }
            finally { zombie.network.GameServer.server=server; }
            System.out.println("CHECK normal_Main_no_pane_agent=true");
        }
        zombie.characters.skills.PerkFactory.init();
        var platform=new se.krka.kahlua.j2se.J2SEPlatform();zombie.Lua.LuaManager.platform=platform;
        zombie.Lua.LuaManager.env=platform.newEnvironment();
        zombie.Lua.LuaManager.thread=new se.krka.kahlua.vm.KahluaThread(platform,zombie.Lua.LuaManager.env);
        zombie.Lua.LuaManager.thread.debugOwnerThread=Thread.currentThread();
        zombie.Lua.LuaManager.converterManager=new se.krka.kahlua.converter.KahluaConverterManager();
        zombie.Lua.LuaManager.caller=new se.krka.kahlua.integration.LuaCaller(zombie.Lua.LuaManager.converterManager);
        if(!mode.equals("inactive"))ZomboidFileSystem.instance.getModIDs().add("SurvivorAwareness");
        zombie.core.Translator.loadFiles();
        // Use the native translation file reader for the owned English file;
        // mod directory enumeration stays controlled in this isolated process.
        Field names=zombie.core.Translator.class.getDeclaredField("itemName");names.setAccessible(true);
        var reader=zombie.core.Translator.class.getDeclaredMethod("tryFillMapFromFile",String.class,String.class,java.util.Map.class,zombie.core.Language.class,java.util.function.Function.class);reader.setAccessible(true);
        reader.invoke(null,args[3],"ItemName",names.get(null),zombie.core.Translator.getDefaultLanguage(),java.util.function.Function.identity());
        System.out.println("TRANSLATION "+((java.util.Map<?,?>)names.get(null)).get("RepairableWindows.LargeGlassPane"));
        WorldDictionary.StartScriptLoading();context("pz-vanilla");
        ScriptModule base=module("Base");
        for(String name:new String[]{"Craft_PotteryBench","Making_With_Kiln"})base.timedActionScripts.CreateFromTokenPP(ScriptLoadMode.Init,"timedAction",block(game.resolve("media/scripts/generated/timedactions.txt"),"timedAction",name));
        base.timedActionScripts.LoadScripts(ScriptLoadMode.Init);
        for(String name:new String[]{"Clay","CeramicCrucibleWithGlass","GlassPanel"})base.items.CreateFromTokenPP(ScriptLoadMode.Init,"item",block(game.resolve("media/scripts/generated/items/"+(name.equals("CeramicCrucibleWithGlass")?"drainable.txt":"normal.txt")),"item",name));
        base.items.LoadScripts(ScriptLoadMode.Init);
        Item vanilla=base.getItem("GlassPanel");check("native_panel_scale",vanilla!=null&&vanilla.getActualWeight()==.2f);
        Item foreign=null;
        if(mode.equals("equal")||mode.equals("conflict")||mode.equals("optional")){
            context("RepairableWindows");var existing=module("RepairableWindows");
            if(mode.equals("optional")){
                Path workshop=Path.of(args[2]);
                for(String name:new String[]{"LargeGlassPane","ClayLargeSheetMoldUnfired","ClayLargeSheetMold"})
                    existing.items.CreateFromTokenPP(ScriptLoadMode.Init,"item",block(workshop.resolve("media/scripts/RepairableWindows/items.txt"),"item",name));
                existing.items.LoadScripts(ScriptLoadMode.Init);
                for(String name:new String[]{"MakeLargeSheetMold","FireClayLargeSheetMold","MakeLargeGlassPane"})
                    base.craftRecipes.CreateFromTokenPP(ScriptLoadMode.Init,"craftRecipe",block(workshop.resolve("media/scripts/RepairableWindows/recipes.txt"),"craftRecipe",name));
                base.craftRecipes.LoadScripts(ScriptLoadMode.Init);
            }else{
                existing.items.CreateFromTokenPP(ScriptLoadMode.Init,"item","item LargeGlassPane { ItemType = base:normal, DisplayCategory = Material, Weight = "+(mode.equals("equal")?"0.8":"3.7")+", Icon = GlassPane, StaticModel = GlassPanel, WorldStaticModel = GlassPanel, Tags = base:glass, }");
                existing.items.LoadScripts(ScriptLoadMode.Init);
            }
            foreign=existing.getItem("LargeGlassPane");check("foreign_definition_loaded",foreign!=null);
        }
        context("fixture-before-close");
        // This actual native method is the lifecycle closure. The production
        // weave must register BEFORE it changes allowScriptItemLoading=false.
        WorldDictionary.ScriptsLoaded();
        check("native_loading_closed",!WorldDictionary.isAllowScriptItemLoading());
        System.out.println("STATUS "+SAOWindowPaneDefinitions.status());
        var pendingMethod=WorldDictionary.class.getDeclaredMethod("getItemLoadList");pendingMethod.setAccessible(true);
        @SuppressWarnings("unchecked") var pending=new java.util.LinkedHashMap<>((java.util.Map<String,ItemInfo>)pendingMethod.invoke(null));
        var pane=ScriptManager.instance.getItem("RepairableWindows.LargeGlassPane");
        if(mode.equals("inactive")){check("inactive_no_registration",pane==null);return;}
        check("owned_or_preserved_pane",pane!=null);
        if(foreign!=null)check("foreign_same_object",pane==foreign);
        check("native_panel_preserved",base.getItem("GlassPanel")==vanilla);
        if(mode.equals("conflict")){
            check("conflict_weight_preserved",pane.getActualWeight()==3.7f);
            check("conflict_supply_held",ScriptManager.instance.getCraftRecipe("Base.MakeLargeGlassPane")==null);return;
        }
        check("large_weight_and_native_assets",pane.getActualWeight()==.8f&&pane.getIcon().equals("GlassPane")&&pane.getStaticModel().equals("GlassPanel"));
        var recipe=ScriptManager.instance.getCraftRecipe("Base.MakeLargeGlassPane");
        check("ordinary_recipe_available",recipe!=null);
        check("glass_native_prerequisites",recipe.needToBeLearn()&&"MakeGlassPanel".equals(recipe.getMetaRecipe())&&recipe.getTags().contains("Glassmaking")&&recipe.getTime()==120);
        check("four_native_crucibles",recipe.getInputs().get(1).getIntAmount()==4);
        check("large_mold_kept",recipe.getInputs().get(0).isKeep());
        check("one_large_pane_result",recipe.getOutputs().get(0).getIntAmount()==1);
        check("mold_clay_scale",ScriptManager.instance.getCraftRecipe("Base.MakeLargeSheetMold").getInputs().get(0).getIntAmount()==12);
        check("kiln_native_prerequisites",ScriptManager.instance.getCraftRecipe("Base.FireClayLargeSheetMold").getTags().contains("KilnSmall"));
        check("source_attribution_restored",ScriptManager.getCurrentLoadFileMod().equals("fixture-before-close"));
        int itemCount=ScriptManager.instance.getAllItems().size(),recipeCount=ScriptManager.instance.getAllCraftRecipes().size();
        SAOWindowPaneDefinitions.beforeScriptsLoaded();
        check("outside_lifecycle_no_repeat",itemCount==ScriptManager.instance.getAllItems().size()&&recipeCount==ScriptManager.instance.getAllCraftRecipes().size());
        WorldDictionary.StartScriptLoading();SAOWindowPaneDefinitions.beforeScriptsLoaded();WorldDictionary.ScriptsLoaded();
        check("allowed_repeat_same_objects",pane==ScriptManager.instance.getItem(pane.getFullName())&&recipe==ScriptManager.instance.getCraftRecipe(recipe.getScriptObjectFullType())&&itemCount==ScriptManager.instance.getAllItems().size()&&recipeCount==ScriptManager.instance.getAllCraftRecipes().size());
        Dictionary dictionary=new Dictionary();Field data=WorldDictionary.class.getDeclaredField("data");data.setAccessible(true);data.set(null,dictionary);
        dictionary.register(vanilla,(short)1700);
        if(foreign!=null)dictionary.register(foreign,(short)1731);
        dictionary.admit(pending);
        check("native_dictionary_preserves_old_id",dictionary.id(vanilla.getFullName())==1700&&vanilla.getRegistry_id()==1700);
        if(foreign!=null)check("native_dictionary_preserves_legacy_id",dictionary.id(foreign.getFullName())==1731&&foreign.getRegistry_id()==1731);
        check("native_dictionary_admits_owned_item",dictionary.id(pane.getFullName())>=0&&pane.getRegistry_id()==dictionary.id(pane.getFullName()));
        var roundtrip=new Dictionary();roundtrip.restore(dictionary.bytes());
        check("native_dictionary_save_reload_ids",roundtrip.id(vanilla.getFullName())==1700&&roundtrip.id(pane.getFullName())==dictionary.id(pane.getFullName()));
        var produced=InventoryItemFactory.CreateItem(pane.getFullName());
        // Direct bucket bootstrap omits the full game's name projection.
        // Complete only this disposable receiver's name from native Translator;
        // foreign script definitions remain identical and unmodified.
        if(produced!=null&&produced.getDisplayName()==null)produced.setName(zombie.core.Translator.getItemNameFromFullType(pane.getFullName()));
        check("native_factory_pane",produced!=null&&produced.getActualWeight()==.8f&&produced.getFullType().equals("RepairableWindows.LargeGlassPane"));
        ByteBuffer bytes=ByteBuffer.allocate(1048576);produced.saveWithSize(bytes,false);bytes.flip();
        var restored=zombie.inventory.InventoryItem.loadItem(bytes,zombie.iso.IsoWorld.WorldVersion);
        if(restored!=null&&restored.getDisplayName()==null)restored.setName(zombie.core.Translator.getItemNameFromFullType(pane.getFullName()));
        check("legacy_native_item_save_reload",restored.getFullType().equals(produced.getFullType())&&restored.getRegistry_id()==produced.getRegistry_id()&&restored.getActualWeight()==.8f);
        System.out.println("CHECKS "+checks);
    }
}
