import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;

/** Uses retained original bootstrap classes. Only nonrendering native puddle
 * initialization occurs before SP source/action/person checks begin. */
public final class NormalWorkspaceConsumerProbe {
    static void coherentTileMetadata(Path game) throws Exception {
        var selected=Set.of("carpentry_01_24","carpentry_01_25","carpentry_01_26","carpentry_01_27",
            "crafted_01_120","crafted_01_121","crafted_01_122","crafted_01_123","floors_interior_tilesandwood_01_0");
        var found=new LinkedHashMap<String,Map<String,String>>();
        try(var in=new java.io.DataInputStream(new java.io.BufferedInputStream(Files.newInputStream(game.resolve("media/newtiledefinitions.tiles"))))) {
            if(!Arrays.equals(in.readNBytes(4),new byte[]{'t','d','e','f'})||WorkspaceBuildNativeProbe.integer(in)!=1)
                throw new IllegalStateException("native tile format");
            int sets=WorkspaceBuildNativeProbe.integer(in);
            for(int s=0;s<sets;s++) {
                String name=WorkspaceBuildNativeProbe.line(in);WorkspaceBuildNativeProbe.line(in);
                WorkspaceBuildNativeProbe.integer(in);WorkspaceBuildNativeProbe.integer(in);WorkspaceBuildNativeProbe.integer(in);
                int count=WorkspaceBuildNativeProbe.integer(in);
                for(int i=0;i<count;i++) {
                    var props=new LinkedHashMap<String,String>();int n=WorkspaceBuildNativeProbe.integer(in);
                    for(int j=0;j<n;j++)props.put(WorkspaceBuildNativeProbe.line(in),WorkspaceBuildNativeProbe.line(in));
                    if(selected.contains(name+"_"+i))found.put(name+"_"+i,props);
                }
            }
        }
        if(found.size()!=selected.size())throw new AssertionError("original scene tile metadata incomplete");
        var aliases=new HashMap<String,ArrayList<String>>();
        for(var props:found.values())for(var p:props.entrySet()) {
            var values=aliases.computeIfAbsent(p.getKey(),k->new ArrayList<>());
            if(!values.contains(p.getValue()))values.add(p.getValue());
        }
        zombie.core.TilePropertyAliasMap.instance.Generate(aliases);
        for(var row:found.entrySet()) {
            var sprite=zombie.iso.sprite.IsoSpriteManager.instance.getSprite(row.getKey());
            sprite.getProperties().Clear();
            for(var p:row.getValue().entrySet())sprite.getProperties().set(p.getKey(),p.getValue());
        }
        System.out.println("WORKSPACE_NATIVE_TILE_METADATA_UNION="+found.size());
    }
    public static void main(String[] args) throws Exception {
        WorkspaceConsumerNativeProbe.main(new String[]{args[0]});
        coherentTileMetadata(Path.of(args[0]));
        for(Class<?> type:new Class<?>[]{zombie.entity.GameEntity.class,zombie.scripting.entity.GameEntityScript.class,
            zombie.scripting.entity.ComponentScript.class,zombie.entity.ComponentType.class,
            zombie.scripting.entity.components.spriteconfig.SpriteConfigScript.class,
            zombie.scripting.entity.components.crafting.CraftRecipeComponentScript.class,
            zombie.scripting.entity.components.crafting.CraftBenchScript.class,
            zombie.iso.sprite.IsoSprite.class,zombie.iso.sprite.IsoSpriteManager.class,
            zombie.core.properties.PropertyContainer.class,zombie.iso.SpriteDetails.IsoFlagType.class,
            zombie.iso.SpriteDetails.IsoObjectType.class,zombie.core.properties.IsoPropertyType.class,
            zombie.scripting.objects.ItemTag.class,zombie.scripting.objects.ResourceLocation.class}) {
            zombie.Lua.LuaManager.exposer.setExposed(type);
            zombie.Lua.LuaManager.exposer.exposeLikeJava(type,zombie.Lua.LuaManager.env);
        }
        boolean previousServer = zombie.network.GameServer.server;
        boolean previousGui = zombie.network.GameServer.guiCommandline;
        try {
            zombie.network.GameServer.server = true;
            zombie.network.GameServer.guiCommandline = false;
            zombie.iso.IsoPuddles.getInstance();
        } finally {
            zombie.network.GameServer.server = previousServer;
            zombie.network.GameServer.guiCommandline = previousGui;
        }
        if (zombie.network.GameServer.server || zombie.network.GameClient.client)
            throw new AssertionError("ordinary single-player scene required");
        System.out.println("WORKSPACE_NONRENDERING_PUDDLES_READY");
        zombie.Lua.LuaManager.env.rawset("createBuildAction",(se.krka.kahlua.vm.JavaFunction)(frame,n)->
            frame.push((double)zombie.Lua.LuaManager.GlobalObject.createBuildAction(
                (zombie.characters.IsoPlayer)frame.get(0),((Double)frame.get(1)).floatValue(),
                ((Double)frame.get(2)).floatValue(),((Double)frame.get(3)).floatValue(),
                (Boolean)frame.get(4),(String)frame.get(5),(se.krka.kahlua.vm.KahluaTable)frame.get(6))));
        zombie.Lua.LuaManager.env.rawset("removeAction",(se.krka.kahlua.vm.JavaFunction)(frame,n)-> {
            zombie.Lua.LuaManager.GlobalObject.removeAction((zombie.characters.IsoPlayer)frame.get(0),
                ((Double)frame.get(1)).byteValue(),(Boolean)frame.get(2));
            return 0;
        });
        zombie.Lua.LuaManager.env.rawset("copyTable",(se.krka.kahlua.vm.JavaFunction)(frame,n)->
            frame.push(zombie.Lua.LuaManager.GlobalObject.copyTable((se.krka.kahlua.vm.KahluaTable)frame.get(0))));
        for (int index=1; index<args.length; index++)
            RecipeIngredientNativeProbe.run(Files.readString(Path.of(args[index])));
    }
}
