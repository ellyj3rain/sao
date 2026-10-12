import java.nio.file.*;
import java.util.*;
import se.krka.kahlua.vm.JavaFunction;
import zombie.Lua.LuaManager;

/** Original prop declarations on the retained same native individual/scene. */
public final class PropWorkspaceConsumerProbe {
    static void metadata(Path game)throws Exception {
        var names=Set.of("carpentry_01_24","carpentry_01_25","carpentry_01_26","carpentry_01_27",
            "crafted_01_120","crafted_01_121","crafted_01_122","crafted_01_123",
            "floors_interior_tilesandwood_01_0","crafted_02_93","crafted_02_94");
        var found=new LinkedHashMap<String,Map<String,String>>();var ids=new LinkedHashMap<String,Integer>();
        var calculate=zombie.iso.IsoWorld.class.getDeclaredMethod("getSpriteID",int.class,int.class,int.class);calculate.setAccessible(true);
        try(var in=new java.io.DataInputStream(new java.io.BufferedInputStream(Files.newInputStream(game.resolve("media/newtiledefinitions.tiles"))))) {
            if(!Arrays.equals(in.readNBytes(4),new byte[]{'t','d','e','f'})||WorkspaceBuildNativeProbe.integer(in)!=1)throw new AssertionError("native tile format");
            int sheets=WorkspaceBuildNativeProbe.integer(in);
            for(int sheet=0;sheet<sheets;sheet++) {
                String name=WorkspaceBuildNativeProbe.line(in);WorkspaceBuildNativeProbe.line(in);
                WorkspaceBuildNativeProbe.integer(in);WorkspaceBuildNativeProbe.integer(in);int sheetId=WorkspaceBuildNativeProbe.integer(in);
                int count=WorkspaceBuildNativeProbe.integer(in);
                for(int tile=0;tile<count;tile++) {
                    var props=new LinkedHashMap<String,String>();int number=WorkspaceBuildNativeProbe.integer(in);
                    for(int property=0;property<number;property++)props.put(WorkspaceBuildNativeProbe.line(in),WorkspaceBuildNativeProbe.line(in));
                    String full=name+"_"+tile;
                    if(names.contains(full)){found.put(full,props);ids.put(full,(Integer)calculate.invoke(zombie.iso.IsoWorld.instance,1,sheetId,tile));}
                }
            }
        }
        if(found.size()!=names.size())throw new AssertionError("original prop sprite metadata required");
        var manager=zombie.iso.sprite.IsoSpriteManager.instance;
        // Register only new original prop sprites before any prop is placed.
        for(String name:List.of("crafted_02_93","crafted_02_94")){
            manager.namedMap.remove(name);var sprite=manager.AddSprite(name,ids.get(name));sprite.name=name;
        }
        var aliases=new HashMap<String,ArrayList<String>>();
        for(var props:found.values())for(var property:props.entrySet()){
            var values=aliases.computeIfAbsent(property.getKey(),key->new ArrayList<>());
            if(!values.contains(property.getValue()))values.add(property.getValue());
        }
        zombie.core.TilePropertyAliasMap.instance.Generate(aliases);
        for(var row:found.entrySet()){
            var sprite=manager.getSprite(row.getKey());sprite.getProperties().Clear();
            for(var property:row.getValue().entrySet())sprite.getProperties().set(property.getKey(),property.getValue());
        }
        // Existing sparse scene floors still reference their original named
        // placeholders. Bind exact registered source sprites before decisions,
        // rather than interpreting old alias indices under the expanded map.
        var body=RecipeIngredientNativeProbe.currentBody;
        for(int x=8;x<=22;x++)for(int y=17;y<=24;y++){
            var square=body.getCell().getGridSquare(x,y,0);
            for(int index=0;index<square.getObjects().size();index++){
                var object=square.getObjects().get(index);
                if(object.getSprite()!=null&&object.getSprite().name!=null&&names.contains(object.getSprite().name))object.setSprite(manager.getSprite(object.getSprite().name));
            }
        }
    }
    public static void main(String[]args)throws Exception {
        LoggingWorkspaceConsumerProbe.main(new String[]{args[0]});Path game=Path.of(args[0]);
        WorkspaceConsumerNativeProbe.addItem(game,"Twine","drainable");WorkspaceConsumerNativeProbe.addItem(game,"Moveable","moveable");WorkspaceConsumerNativeProbe.addItem(game,"Saw_Flint","weapon");
        String actions=Files.readString(game.resolve("media/scripts/generated/timedactions.txt"));
        var timed=new zombie.scripting.objects.TimedActionScript();timed.setModule(RecipePolicyNativeProbe.module);timed.InitLoadPP("BuildWallNoTool");
        timed.Load("BuildWallNoTool",ConstructionPolicyNativeProbe.block(actions,"timedAction","BuildWallNoTool"));
        RecipePolicyNativeProbe.module.timedActionScripts.getScriptMap().put("BuildWallNoTool",timed);
        ConstructionPolicyNativeProbe.entity("Log_Stool",ConstructionPolicyNativeProbe.block(Files.readString(game.resolve("media/scripts/generated/entities/furniture/entity_log_stool.txt")),"entity","Log_Stool"));
        ConstructionPolicyNativeProbe.register();zombie.inventory.ItemTags.Init(zombie.scripting.ScriptManager.instance.getAllItems());var stool=ConstructionPolicyNativeProbe.entities.get("Log_Stool");
        stool.OnScriptsLoaded(zombie.scripting.ScriptLoadMode.Init);stool.OnPostWorldDictionaryInit();
        metadata(game);ConstructionPolicyNativeProbe.register();
        zombie.inventory.ItemTags.Init(zombie.scripting.ScriptManager.instance.getAllItems());
        zombie.entity.components.spriteconfig.SpriteConfigManager.InitScriptsPostTileDef();zombie.entity.components.crafting.recipe.CraftRecipeManager.Init();
        for(Class<?>type:new Class<?>[]{zombie.inventory.types.Moveable.class,zombie.inventory.types.DrainableComboItem.class,
            zombie.iso.objects.IsoWindow.class,zombie.iso.objects.IsoGenerator.class,zombie.iso.TileOverlays.class,zombie.SandboxOptions.class,zombie.characters.skills.PerkFactory.class,zombie.scripting.objects.ItemKey.class,zombie.scripting.objects.ItemKey.Weapon.class}){
            LuaManager.exposer.setExposed(type);LuaManager.exposer.exposeLikeJava(type,LuaManager.env);LuaManager.exposer.exposeLikeJavaRecursively(type,LuaManager.env);
        }
        LuaManager.env.rawset("getTileOverlays",(JavaFunction)(frame,n)->frame.push(zombie.iso.TileOverlays.instance));
        LuaManager.env.rawset("instanceItem",(JavaFunction)(frame,n)->frame.push(zombie.Lua.LuaManager.GlobalObject.instanceItem(frame.get(0).toString())));
        LuaManager.env.rawset("__furnitureBreakSound",(JavaFunction)(frame,n)->frame.push(frame.get(0) instanceof String name ? zombie.iso.objects.IsoThumpable.GetBreakFurnitureSound(name):zombie.iso.objects.IsoThumpable.GetBreakFurnitureSound((zombie.iso.sprite.IsoSprite)frame.get(0))));
        LuaManager.env.rawset("triggerEvent",(JavaFunction)(frame,n)->{
            String name=(String)frame.get(0);
            if(n==1)zombie.Lua.LuaEventManager.triggerEvent(name);
            else if(n==2)zombie.Lua.LuaEventManager.triggerEvent(name,frame.get(1));
            else throw new AssertionError("declared native event arity");return 0;
        });
        LuaManager.env.rawset("__className",(JavaFunction)(frame,n)->frame.push(frame.get(0).getClass().getName()));
        LuaManager.env.rawset("__changePropScript",(JavaFunction)(frame,n)->{
            var object=(zombie.iso.IsoObject)frame.get(0);
            var other=zombie.scripting.ScriptManager.instance.getGameEntityScript((String)frame.get(1));
            zombie.entity.components.script.EntityScriptInfo info=object.getComponent(zombie.entity.ComponentType.Script);
            if(info==null||other==null||object.getEntityScript()==other)throw new AssertionError("actual distinct registered native script required");
            info.setOriginalScript(other);
            return frame.push(object.getEntityScript()==other);
        });
        LuaManager.env.rawset("__configurePropScene",(JavaFunction)(frame,n)->{
            var body=RecipeIngredientNativeProbe.currentBody;var container=RecipeIngredientNativeProbe.currentContainer;
            RecipeIngredientNativeProbe.currentObject.getProperties().Clear();
            for(int index=container.getItems().size()-1;index>=0;index--){var item=container.getItems().get(index);container.Remove(item);item.setContainer(null);}
            for(int index=body.getInventory().getItems().size()-1;index>=0;index--){var item=body.getInventory().getItems().get(index);
                if(!List.of("Base.Scissors","Base.Saw").contains(item.getFullType())){body.getInventory().Remove(item);item.setContainer(null);}}
            for(String name:List.of("Stone2","Stone2","Log","TreeBranch2","TreeBranch2","TreeBranch2","Twine")){
                var item=RecipePolicyNativeProbe.item(name);if(name.equals("Twine"))item.setCurrentUses(5);item.getContainer().Remove(item);container.AddItemBlind(item);item.setContainer(container);
            }
            System.out.println("PROP_NATIVE_STARTING_DONOR_ITEMS="+container.getItems().size()+" heldSaw="+body.getInventory().getCountTypeRecurse("Base.Saw"));
            return frame.push(true);
        });
        for(int index=1;index<args.length;index++)RecipeIngredientNativeProbe.run(Files.readString(Path.of(args[index])));
    }
}
