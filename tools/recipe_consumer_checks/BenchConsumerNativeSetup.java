import com.sao.engine.SAOIsoPlayerShell;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.regex.Pattern;
import se.krka.kahlua.vm.KahluaTable;
import zombie.Lua.LuaManager;
import zombie.entity.ComponentType;
import zombie.entity.GameEntityFactory;
import zombie.entity.components.crafting.CraftBench;
import zombie.entity.components.spriteconfig.SpriteConfigManager;
import zombie.iso.IsoObject;
import zombie.iso.sprite.IsoSpriteManager;
import zombie.scripting.ScriptBucketCollection;
import zombie.scripting.ScriptLoadMode;
import zombie.scripting.ScriptManager;
import zombie.scripting.ScriptParser;
import zombie.scripting.entity.GameEntityScript;
import zombie.scripting.entity.components.spriteconfig.SpriteConfigScript;

/** Isolated loaded-scene setup only: actual native unclaimed Grindstone.
 * Call after the caller's existing body, Lua, items and recipe bootstrap.
 * Physical work and current-person/private admission remain ordinary owners. */
public final class BenchConsumerNativeSetup {
    private BenchConsumerNativeSetup() { }

    private static String block(String source, String kind, String name) {
        source=ScriptParser.stripComments(source);
        var m=Pattern.compile("(?m)^\\s*"+kind+"\\s+"+Pattern.quote(name)+"\\s*\\{").matcher(source);
        if (!m.find()) throw new IllegalArgumentException("Missing installed "+kind+" "+name);
        int depth=1,end=m.end();
        while (depth>0) { char c=source.charAt(end++); if(c=='{')depth++; if(c=='}')depth--; }
        return source.substring(m.start(),end);
    }

    @SuppressWarnings("unchecked")
    private static GameEntityScript registered() throws Exception {
        var manager=ScriptManager.instance;
        var existing=manager.getGameEntityScript("Base.Grindstone");
        if(existing!=null) return existing;
        var module=manager.moduleMap.get("Base");
        if(module==null) throw new IllegalStateException("Existing native Base dictionary required");
        Path game=Path.of(System.getProperty("sao.game",System.getenv().getOrDefault("PZ_DIR",
            "C:\\Program Files (x86)\\Steam\\steamapps\\common\\ProjectZomboid")));
        String definition=block(Files.readString(game.resolve(
            "media/scripts/generated/entities/blacksmith/workstations/entity_grindstone.txt")),"entity","Grindstone");
        String ui=block(definition,"component","UiConfig");
        definition=definition.replace(ui,""); // UI skin preparation is outside this nonrendering scene.
        var entity=new GameEntityScript();entity.setModule(module);entity.setModID("pz-vanilla");
        entity.InitLoadPP("Grindstone");entity.Load("Grindstone",definition);
        module.entities.getScriptMap().put("Grindstone",entity);
        module.entities.getScriptList().add(entity);
        var field=ScriptManager.class.getDeclaredField("entities");field.setAccessible(true);
        var collection=(ScriptBucketCollection<GameEntityScript>)field.get(manager);
        collection.getFullTypeToScriptMap().put("Base.Grindstone",entity);
        collection.getAllScripts().add(entity);
        entity.OnScriptsLoaded(ScriptLoadMode.Init);entity.OnPostWorldDictionaryInit();
        if(manager.getGameEntityScript("Base.Grindstone")!=entity)
            throw new IllegalStateException("Native entity registration failed");
        return entity;
    }

    public static KahluaTable prepare(SAOIsoPlayerShell body) throws Exception {
        if(body==null || body.getCell()==null || body.getCurrentSquare()==null || LuaManager.platform==null)
            throw new IllegalArgumentException("Existing real native loaded body and Lua required");
        var square=body.getCurrentSquare();
        if(body.getCell().getGridSquare(square.getX(),square.getY(),square.getZ())!=square)
            throw new IllegalArgumentException("Body square must be loaded in its actual cell");
        var entity=registered();
        var config=(SpriteConfigScript)entity.getComponentScriptFor(ComponentType.SpriteConfig);
        for(String name:config.getAllTileNames()) {
            var tile=IsoSpriteManager.instance.getSprite(name);
            if(tile==null)tile=IsoSpriteManager.instance.AddSprite(name);
            tile.name=name;
        }
        SpriteConfigManager.InitScriptsPostTileDef();
        var sprite=IsoSpriteManager.instance.getSprite("crafted_01_120");
        if(sprite==null) sprite=IsoSpriteManager.instance.AddSprite("crafted_01_120");
        sprite.name="crafted_01_120";
        var object=new IsoObject(body.getCell(),square,sprite);
        square.getObjects().add(object);square.setSolidFloor(true);
        GameEntityFactory.CreateIsoObjectEntity(object,entity,false);
        CraftBench bench=object.getComponent(ComponentType.CraftBench);
        if(object.getClass()!=IsoObject.class || object.getEntityScript()!=entity || bench==null
            || object.getUsingPlayer()!=null || !"grindstone".equals(bench.getRecipeTagQuery()))
            throw new IllegalStateException("Actual unclaimed native Grindstone components required: script="
                +object.getEntityScript()+" bench="+bench+" query="+(bench==null?null:bench.getRecipeTagQuery()));
        var result=LuaManager.platform.newTable();
        result.rawset("body",body);result.rawset("object",object);result.rawset("bench",bench);
        result.rawset("entity",entity);result.rawset("square",square);
        result.rawset("x",(double)square.getX());result.rawset("y",(double)square.getY());result.rawset("z",(double)square.getZ());
        result.rawset("initiallyUnclaimed",true);result.rawset("setupOnly",true);
        return result;
    }
}
