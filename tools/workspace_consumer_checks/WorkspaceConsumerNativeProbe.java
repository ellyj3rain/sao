import java.lang.reflect.*;
import java.nio.file.*;
import java.util.*;
import se.krka.kahlua.vm.*;
import zombie.Lua.LuaManager;
import zombie.scripting.*;
import zombie.scripting.objects.*;
import zombie.entity.ComponentType;
import zombie.inventory.ItemTags;
import zombie.entity.components.crafting.recipe.CraftRecipeManager;

/** Isolated consumer scene on the existing native ingredient person. Native
 * registered construction is added to that same source module; no workspace
 * is precreated and no source is labelled acquired by this bootstrap. */
public final class WorkspaceConsumerNativeProbe {
    static void addItem(Path game,String name,String file)throws Exception {
        var module=RecipePolicyNativeProbe.module;if(module.getItem(name)!=null)return;
        String raw=ConstructionPolicyNativeProbe.block(Files.readString(game.resolve("media/scripts/generated/items/"+file+".txt")),"item",name)
            .replaceAll("(?im)^\\s*Researchablerecipes\\s*=.*$","");
        var item=new Item();item.setModule(module);item.setModID("pz-vanilla");item.InitLoadPP(name);item.Load(name,raw);item.setDisplayName(name);
        module.items.getScriptMap().put(name,item);
    }
    static void bootstrap(Path game)throws Exception {
        var module=RecipePolicyNativeProbe.module;ConstructionPolicyNativeProbe.module=module;
        for(String[] entry:new String[][]{{"Hammer","weapon"},{"Plank","weapon"},{"Nails","normal"},{"StoneWheel","normal"},{"HandAxe","weapon"},{"Saw","weapon"},{"Log","normal"}})addItem(game,entry[0],entry[1]);
        for(String[] entry:new String[][]{{"Wood_TableLvl1","furniture/entity_carpentry_table_lvl1.txt"},{"Grindstone","blacksmith/workstations/entity_grindstone.txt"}})
            ConstructionPolicyNativeProbe.entity(entry[0],ConstructionPolicyNativeProbe.block(Files.readString(game.resolve("media/scripts/generated/entities/"+entry[1])),"entity",entry[0]));
        String actions=Files.readString(game.resolve("media/scripts/generated/timedactions.txt"));
        for(String name:List.of("BuildWallHammer","BuildLowHammer","UseGrindingStone"))if(module.timedActionScripts.getScriptMap().get(name)==null){
            var timed=new TimedActionScript();timed.setModule(module);timed.InitLoadPP(name);timed.Load(name,ConstructionPolicyNativeProbe.block(actions,"timedAction",name));
            module.timedActionScripts.getScriptMap().put(name,timed);
        }
        ConstructionPolicyNativeProbe.register();CraftRecipeManager.Init();
        for(var entity:ConstructionPolicyNativeProbe.entities.values())entity.OnScriptsLoaded(ScriptLoadMode.Init);
        ConstructionPolicyNativeProbe.register();ItemTags.Init(ScriptManager.instance.getAllItems());
        for(var entity:ConstructionPolicyNativeProbe.entities.values()){
            entity.OnPostWorldDictionaryInit();
            var sprite=(zombie.scripting.entity.components.spriteconfig.SpriteConfigScript)entity.getComponentScriptFor(ComponentType.SpriteConfig);
            for(String name:sprite.getAllTileNames())zombie.iso.sprite.IsoSpriteManager.instance.AddSprite(name).name=name;
        }
        zombie.entity.components.spriteconfig.SpriteConfigManager.InitScriptsPostTileDef();CraftRecipeManager.Init();
        WorkspaceBuildNativeProbe.tileMetadata(game);
        SiteObserverNativeProbe.floors(game,RecipeIngredientNativeProbe.currentBody);
        var ctor=zombie.iso.areas.isoregion.IsoRegionWorker.class.getDeclaredConstructor();ctor.setAccessible(true);
        var region=zombie.iso.areas.isoregion.IsoRegions.class.getDeclaredField("regionWorker");region.setAccessible(true);region.set(null,ctor.newInstance());
        var polygon=zombie.pathfind.PolygonalMap2.instance;
        var pc=Class.forName("zombie.pathfind.PolygonalMap2$PMThread").getDeclaredConstructor(zombie.pathfind.PolygonalMap2.class);pc.setAccessible(true);
        var field=zombie.pathfind.PolygonalMap2.class.getDeclaredField("thread");field.setAccessible(true);field.set(polygon,pc.newInstance(polygon));
        zombie.entity.GameEntityManager.Init(1);
        for(Class<?> type:new Class<?>[]{zombie.entity.components.build.BuildLogic.class,zombie.entity.components.spriteconfig.SpriteConfigManager.class,
            zombie.entity.components.spriteconfig.SpriteConfigManager.ObjectInfo.class,zombie.entity.components.spriteconfig.SpriteConfigManager.FaceInfo.class,zombie.entity.components.spriteconfig.SpriteConfigManager.TileInfo.class,
            zombie.iso.objects.IsoThumpable.class,zombie.entity.GameEntityFactory.class,zombie.characters.skills.PerkFactory.Perks.class,zombie.entity.components.crafting.BaseCraftingLogic.class})
            {LuaManager.exposer.setExposed(type);LuaManager.exposer.exposeLikeJava(type,LuaManager.env);}
        LuaManager.env.rawset("__workspaceBody",RecipeIngredientNativeProbe.currentBody);
        LuaManager.env.rawset("__workspaceContainer",RecipeIngredientNativeProbe.currentContainer);
        LuaManager.env.rawset("__workspaceSource",RecipeIngredientNativeProbe.currentObject);
        LuaManager.env.rawset("__prepareWorkspaceNative",(JavaFunction)(f,n)->{
            try{
                var body=RecipeIngredientNativeProbe.currentBody;var container=RecipeIngredientNativeProbe.currentContainer;
                body.getInventory().getItems().clear();container.getItems().clear();
                RecipeIngredientNativeProbe.currentObject.getProperties().unset("GenericCraftingSurface");
                var result=LuaManager.platform.newTable();result.rawset("body",body);result.rawset("container",container);result.rawset("object",RecipeIngredientNativeProbe.currentObject);
                var registry=(KahluaTable)zombie.world.moddata.GlobalModData.instance.get("SurvivorAwareness_Records").rawget("records");
                result.rawset("record",registry.rawget("ingredient-person"));result.rawset("id","ingredient-person");
                var target=RecipePolicyNativeProbe.item("Scissors");target.getContainer().Remove(target);body.getInventory().AddItemBlind(target);target.setContainer(body.getInventory());target.setSharpness(.1f);result.rawset("target",target);
                for(String name:List.of("Hammer","Saw","HandAxe")){
                    var item=RecipePolicyNativeProbe.item(name);item.getContainer().Remove(item);body.getInventory().AddItemBlind(item);item.setContainer(body.getInventory());result.rawset(name,item);
                }
                for(int index=0;index<4;index++){
                    var nail=RecipePolicyNativeProbe.item("Nails");nail.getContainer().Remove(nail);body.getInventory().AddItemBlind(nail);nail.setContainer(body.getInventory());
                    var plank=RecipePolicyNativeProbe.item("Plank");plank.getContainer().Remove(plank);container.AddItemBlind(plank);plank.setContainer(container);
                }
                for(int index=0;index<2;index++){
                    var stone=RecipePolicyNativeProbe.item("Stone2");stone.getContainer().Remove(stone);container.AddItemBlind(stone);stone.setContainer(container);
                }
                body.setPerkLevelDebug(zombie.characters.skills.PerkFactory.Perks.Woodwork,1);
                body.setPerkLevelDebug(zombie.characters.skills.PerkFactory.Perks.Maintenance,2);
                return f.push(result);
            }catch(Exception error){throw new IllegalStateException(error);}
        });
        LuaManager.env.rawset("__workspaceGive",(JavaFunction)(f,n)->{
            try{var item=RecipePolicyNativeProbe.item((String)f.get(0));item.getContainer().Remove(item);
                var container=Boolean.TRUE.equals(f.get(1))?RecipeIngredientNativeProbe.currentContainer:RecipeIngredientNativeProbe.currentBody.getInventory();
                container.AddItemBlind(item);item.setContainer(container);return f.push(item);
            }catch(Exception e){throw new IllegalStateException(e);}
        });
    }
    public static void main(String[] args)throws Exception {
        RecipeIngredientNativeProbe.main(new String[]{args[0]});bootstrap(Path.of(args[0]));
        if(!(LuaManager.env.rawget("__prepareWorkspaceNative") instanceof JavaFunction))throw new AssertionError("new workspace prepare not registered");
        System.out.println("WORKSPACE_BOOTSTRAP_COMPLETE");
        for(int i=1;i<args.length;i++)RecipeIngredientNativeProbe.run(Files.readString(Path.of(args[i])));
    }
}
