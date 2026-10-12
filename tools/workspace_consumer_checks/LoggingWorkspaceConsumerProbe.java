import java.nio.file.Files;
import java.nio.file.Path;
import java.lang.reflect.Field;
import java.util.Map;
import se.krka.kahlua.vm.JavaFunction;
import zombie.Lua.LuaManager;

/** One actual native damaged tree and the existing actor/tool scene. No Log,
 * recipe knowledge, acquired-source fact or workspace is fabricated. */
public final class LoggingWorkspaceConsumerProbe {
    static Field field(Class<?> owner,String name)throws Exception {
        var value=owner.getDeclaredField(name);value.setAccessible(true);return value;
    }
    static void textureMetadata()throws Exception {
        var slot=sun.misc.Unsafe.class.getDeclaredField("theUnsafe");slot.setAccessible(true);
        var unsafe=(sun.misc.Unsafe)slot.get(null);
        var texture=(zombie.core.textures.Texture)unsafe.allocateInstance(zombie.core.textures.Texture.class);
        String name="media/inventory/Question_On.png";
        field(zombie.core.textures.Texture.class,"name").set(texture,name);
        for(String dimension:new String[]{"width","height","widthOrig","heightOrig"})
            field(zombie.core.textures.Texture.class,dimension).setInt(texture,32);
        ((Map<String,zombie.core.textures.Texture>)field(zombie.core.textures.Texture.class,"s_sharedTextureTable").get(null)).put(name,texture);
        zombie.core.textures.Texture.nullTextures.remove(name);
    }
    static void nativeSpriteIds(Path game)throws Exception {
        var names=java.util.Set.of("carpentry_01_24","carpentry_01_25","carpentry_01_26","carpentry_01_27",
            "crafted_01_120","crafted_01_121","crafted_01_122","crafted_01_123","floors_interior_tilesandwood_01_0");
        var ids=new java.util.LinkedHashMap<String,Integer>();
        var calculate=zombie.iso.IsoWorld.class.getDeclaredMethod("getSpriteID",int.class,int.class,int.class);calculate.setAccessible(true);
        try(var in=new java.io.DataInputStream(new java.io.BufferedInputStream(Files.newInputStream(game.resolve("media/newtiledefinitions.tiles"))))) {
            if(!java.util.Arrays.equals(in.readNBytes(4),new byte[]{'t','d','e','f'})||WorkspaceBuildNativeProbe.integer(in)!=1)throw new AssertionError("native tile source format");
            int sheets=WorkspaceBuildNativeProbe.integer(in);
            for(int sheet=0;sheet<sheets;sheet++) {
                String name=WorkspaceBuildNativeProbe.line(in);WorkspaceBuildNativeProbe.line(in);
                WorkspaceBuildNativeProbe.integer(in);WorkspaceBuildNativeProbe.integer(in);int sheetId=WorkspaceBuildNativeProbe.integer(in);
                int count=WorkspaceBuildNativeProbe.integer(in);
                for(int tile=0;tile<count;tile++) {
                    int properties=WorkspaceBuildNativeProbe.integer(in);
                    for(int property=0;property<properties;property++){WorkspaceBuildNativeProbe.line(in);WorkspaceBuildNativeProbe.line(in);}
                    String spriteName=name+"_"+tile;
                    if(names.contains(spriteName))ids.put(spriteName,(Integer)calculate.invoke(zombie.iso.IsoWorld.instance,1,sheetId,tile));
                }
            }
        }
        if(ids.size()!=names.size())throw new AssertionError("exact original sprite identity source required");
        var manager=zombie.iso.sprite.IsoSpriteManager.instance;
        for(var entry:ids.entrySet()) {
            manager.namedMap.remove(entry.getKey());var sprite=manager.AddSprite(entry.getKey(),entry.getValue());sprite.name=entry.getKey();
            if(zombie.iso.sprite.IsoSprite.getSprite(manager,entry.getValue())!=sprite)throw new AssertionError("native numeric sprite registration");
            System.out.println("LOGGING_NATIVE_SPRITE_REGISTRY "+entry.getKey()+"="+entry.getValue());
        }
        WorkspaceBuildNativeProbe.tileMetadata(game);NormalWorkspaceConsumerProbe.coherentTileMetadata(game);
    }
    static void nativeDictionary()throws Exception {
        var output=Path.of(System.getProperty("user.home")).toAbsolutePath().normalize();
        var cache=output.resolve("native-cache");Files.createDirectories(cache);
        var filesystem=zombie.ZomboidFileSystem.instance;filesystem.setCacheDir(cache.toString());
        zombie.core.Core.gameSaveWorld="isolated-native-logging";
        var actualCache=Path.of(filesystem.getCacheDir()).toAbsolutePath().normalize();
        var actualSave=Path.of(filesystem.getCurrentSaveDir()).toAbsolutePath().normalize();
        if(!actualCache.startsWith(output)||!actualSave.startsWith(output))throw new AssertionError("private native cache/save paths required");
        Files.createDirectories(actualSave);
        System.out.println("LOGGING_NATIVE_DICTIONARY_PATH cache="+actualCache+" save="+actualSave);
        zombie.world.WorldDictionary.setIsNewGame(true);zombie.world.WorldDictionary.ScriptsLoaded();zombie.world.WorldDictionary.init();
    }
    public static void main(String[] args)throws Exception {
        textureMetadata(); // Native inventory prototypes capture metadata during bootstrap.
        NormalWorkspaceConsumerProbe.main(new String[]{args[0]});Path game=Path.of(args[0]);nativeSpriteIds(game);
        for(String[] item:new String[][]{{"TreeBranch2","weapon"},{"Sapling","weapon"},{"LargeBranch","weapon"},{"Twigs","normal"}})
            WorkspaceConsumerNativeProbe.addItem(game,item[0],item[1]);
        RecipePolicyNativeProbe.register();zombie.inventory.ItemTags.Init(zombie.scripting.ScriptManager.instance.getAllItems());
        System.out.println("LOGGING_NATIVE_LOG_REGISTRATION key="+zombie.scripting.objects.ItemKey.Normal.LOG
            +" exact="+zombie.scripting.ScriptManager.instance.getItem("Base.Log")
            +" factoryLookup="+zombie.scripting.ScriptManager.instance.FindItem(zombie.scripting.objects.ItemKey.Normal.LOG.toString(),false));
        textureMetadata();
        // Retained recipe bootstrap parses in dedicated-server mode. Re-read
        // the same installed declarations in SP to initialize native textures.
        for(String[] entry:new String[][]{{"Log","normal"},{"TreeBranch2","weapon"},{"Sapling","weapon"},{"LargeBranch","weapon"},{"Twigs","normal"}}) {
            String raw=ConstructionPolicyNativeProbe.block(Files.readString(game.resolve("media/scripts/generated/items/"+entry[1]+".txt")),"item",entry[0])
                .replaceAll("(?im)^\\s*Researchablerecipes\\s*=.*$","");
            RecipePolicyNativeProbe.module.getItem(entry[0]).Load(entry[0],raw);
        }
        var diagnosticLog=zombie.inventory.InventoryItemFactory.CreateItem("Base.Log");
        System.out.println("LOGGING_NATIVE_FACTORY_LOG="+diagnosticLog+" texturePresent="+(diagnosticLog.getTex()!=null));
        if(diagnosticLog.getTex()!=null)System.out.println("LOGGING_NATIVE_FACTORY_LOG_TEXTURE_NAME="+diagnosticLog.getTex().getName());
        for(Class<?> type:new Class<?>[]{zombie.iso.objects.IsoTree.class,zombie.characters.CharacterActionAnims.class,
            zombie.scripting.objects.CharacterProfession.class,zombie.characters.SurvivorDesc.class}) {
            LuaManager.exposer.setExposed(type);LuaManager.exposer.exposeLikeJava(type,LuaManager.env);
            LuaManager.exposer.exposeLikeJavaRecursively(type,LuaManager.env);
        }
        LuaManager.env.rawset("__changeRequestRecipeDefinition",(JavaFunction)(frame,n)-> {
            try {
                String full=(String)frame.get(0);String name=full.substring(full.indexOf('.')+1);
                var changed=new zombie.scripting.entity.components.crafting.CraftRecipe();
                changed.setModule(RecipePolicyNativeProbe.module);changed.InitLoadPP(name);
                changed.Load(name,"craftRecipe "+name+" { inputs { item 1 [Base.Plank], } }");
                RecipePolicyNativeProbe.module.craftRecipes.getScriptMap().put(name,changed);
                RecipePolicyNativeProbe.register();
                zombie.entity.components.crafting.recipe.CraftRecipeManager.Init();
                return frame.push(zombie.scripting.ScriptManager.instance.getCraftRecipe(full)==changed);
            } catch(Exception failure) { throw new IllegalStateException(failure); }
        });
        LuaManager.env.rawset("__coldReloadConstructedParts",(JavaFunction)(frame,n)-> {
            try {
                nativeDictionary();
                var parts=(se.krka.kahlua.vm.KahluaTable)frame.get(0);int count=0;
                for(int index=1;parts.rawget((double)index)!=null;index++) {
                    var part=(se.krka.kahlua.vm.KahluaTable)parts.rawget((double)index);
                    var square=RecipeIngredientNativeProbe.currentBody.getCell().getGridSquare(
                        ((Double)part.rawget("x")).intValue(),((Double)part.rawget("y")).intValue(),((Double)part.rawget("z")).intValue());
                    int slotIndex=((Double)part.rawget("objectIndex")).intValue();var original=square.getObjects().get(slotIndex);
                    var sprite=original.getSprite();var numeric=zombie.iso.sprite.IsoSprite.getSprite(zombie.iso.sprite.IsoSpriteManager.instance,sprite.id);
                    System.out.println("LOGGING_NATIVE_PART_BEFORE_SAVE sprite="+original.getSpriteName()+" id="+sprite.id+" numericSame="+(numeric==sprite)+" numericName="+(numeric==null?null:numeric.name)+" fixedId="+zombie.iso.IsoChunk.Fix2x(square,sprite.id)+" surface="+RecipeIngredientNativeProbe.currentBody.canUseAsGenericCraftingSurface(original));
                    var bytes=java.nio.ByteBuffer.allocate(1024*1024);original.save(bytes);int length=bytes.position();bytes.flip();
                    var restored=zombie.iso.IsoObject.factoryFromFileInput(RecipeIngredientNativeProbe.currentBody.getCell(),bytes);
                    restored.setSquare(square);restored.load(bytes,zombie.iso.IsoWorld.getWorldVersion(),false);
                    if(bytes.remaining()!=0||restored==original||!restored.getClass().equals(original.getClass()))throw new AssertionError("exact native object roundtrip");
                    System.out.println("LOGGING_NATIVE_PART_AFTER_LOAD sprite="+restored.getSpriteName()+" actualSprite="+(restored.getSprite()==null?null:restored.getSprite().name)+" id="+(restored.getSprite()==null?null:restored.getSprite().id)+" surface="+RecipeIngredientNativeProbe.currentBody.canUseAsGenericCraftingSurface(restored)+" relationPresent="+(restored.getModData().rawget("SAOPhysicalResult")!=null));
                    square.getObjects().set(slotIndex,restored);int special=square.getSpecialObjects().indexOf(original);
                    if(special>=0)square.getSpecialObjects().set(special,restored);
                    System.out.println("LOGGING_NATIVE_PART_COLD_RELOAD part="+index+" bytes="+length+" class="+restored.getClass().getName());count++;
                }
                return frame.push((double)count);
            }catch(Exception failure){throw new IllegalStateException(failure);}
        });
        LuaManager.env.rawset("__alterConstructedParts",(JavaFunction)(frame,n)-> {
            try {
                var parts=(se.krka.kahlua.vm.KahluaTable)frame.get(0);String mode=(String)frame.get(1);int count=0;
                for(int index=1;parts.rawget((double)index)!=null;index++) {
                    var part=(se.krka.kahlua.vm.KahluaTable)parts.rawget((double)index);
                    var square=RecipeIngredientNativeProbe.currentBody.getCell().getGridSquare(((Double)part.rawget("x")).intValue(),((Double)part.rawget("y")).intValue(),((Double)part.rawget("z")).intValue());
                    int slotIndex=((Double)part.rawget("objectIndex")).intValue();var original=square.getObjects().get(slotIndex);var current=original;
                    if(mode.equals("replace")) {
                        var bytes=java.nio.ByteBuffer.allocate(1024*1024);original.save(bytes);bytes.flip();
                        current=zombie.iso.IsoObject.factoryFromFileInput(RecipeIngredientNativeProbe.currentBody.getCell(),bytes);
                        current.setSquare(square);current.load(bytes,zombie.iso.IsoWorld.getWorldVersion(),false);
                        square.getObjects().set(slotIndex,current);int special=square.getSpecialObjects().indexOf(original);
                        if(special>=0)square.getSpecialObjects().set(special,current);
                        if(current==original)throw new AssertionError("distinct replacement native object required");
                    }
                    if(mode.equals("corrupt"))((se.krka.kahlua.vm.KahluaTable)current.getModData().rawget("SAOPhysicalResult")).rawset("workId","foreign-physical-work");
                    else current.getModData().rawset("SAOPhysicalResult",null);
                    System.out.println("LOGGING_NATIVE_CHANGED_PART mode="+mode+" index="+index+" sprite="+current.getSpriteName()+" surface="+RecipeIngredientNativeProbe.currentBody.canUseAsGenericCraftingSurface(current));count++;
                }
                return frame.push((double)count);
            }catch(Exception failure){throw new IllegalStateException(failure);}
        });
        LuaManager.env.rawset("__configureLoggingScene",(JavaFunction)(frame,n)-> {
            var body=RecipeIngredientNativeProbe.currentBody;var square=body.getCell().getGridSquare(11,21,0);
            var sprite=zombie.iso.sprite.IsoSpriteManager.instance.AddSprite("vegetation_trees_01_0",8100);
            sprite.name="vegetation_trees_01_0";
            var tree=new zombie.iso.objects.IsoTree(square,sprite);tree.setHealth(1);square.getObjects().add(tree);
            body.setPrimaryHandItem((zombie.inventory.InventoryItem)frame.get(0));
            body.setSecondaryHandItem((zombie.inventory.InventoryItem)frame.get(0));
            body.setTimedActionInstantCheat(false);
            body.getStats().set(zombie.characters.CharacterStat.ENDURANCE,1);
            return frame.push(tree);
        });
        for(int index=1;index<args.length;index++)RecipeIngredientNativeProbe.run(Files.readString(Path.of(args[index])));
    }
}
