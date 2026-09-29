import com.sao.bridge.SAOBridge;
import com.sao.engine.SAOIsoPlayerShell;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.regex.Pattern;
import se.krka.kahlua.converter.KahluaConverterManager;
import se.krka.kahlua.integration.LuaCaller;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.JavaFunction;
import se.krka.kahlua.vm.KahluaThread;
import zombie.Lua.LuaManager;
import zombie.inventory.InventoryItem;
import zombie.inventory.ItemContainer;
import zombie.inventory.types.DrainableComboItem;
import zombie.inventory.types.Food;
import zombie.iso.IsoCell;
import zombie.scripting.ScriptManager;
import zombie.scripting.ScriptParser;
import zombie.scripting.objects.Item;
import zombie.scripting.objects.ItemTag;
import zombie.scripting.objects.ScriptModule;
import zombie.world.DictionaryData;
import zombie.world.ItemInfo;
import zombie.world.WorldDictionary;

/** Installed item definitions and real native receivers through installed Lua. */
public final class PharmacologyProbe {
    private static final class Info extends ItemInfo {
        Info(Item item, short id) {
            name = item.getName(); moduleName = item.getModuleName(); fullType = moduleName + "." + name;
            registryId = id; isLoaded = true; scriptItem = item; entityScript = item;
            modId = "pz-vanilla";
        }
    }
    private static final class Dictionary extends DictionaryData {
        void register(Item item, short id) {
            var info = new Info(item, id);
            itemIdToInfoMap.put(id, info); itemTypeToInfoMap.put(info.getFullType(), info);
        }
    }
    private static InventoryItem item(Path game, ScriptModule module, Dictionary dictionary,
            String file, String name, short id) throws Exception {
        String text = ScriptParser.stripComments(Files.readString(game.resolve("media/scripts/generated/items/" + file)));
        var match = Pattern.compile("\\bitem\\s+" + Pattern.quote(name) + "\\s*\\{").matcher(text);
        if (!match.find()) throw new AssertionError("Installed item missing: " + name);
        int end = match.end(), depth = 1;
        while (depth > 0 && end < text.length()) {
            char c = text.charAt(end++);
            if (c == '{') depth++; else if (c == '}') depth--;
        }
        if (depth != 0) throw new AssertionError("Unclosed installed item: " + name);
        var definition = new Item(); definition.setModule(module); definition.setName(name);
        definition.Load(name, text.substring(match.start(), end));
        definition.setRegistry_id(id);
        module.items.getScriptMap().put(name, definition); dictionary.register(definition, id);
        InventoryItem value = zombie.inventory.InventoryItemFactory.CreateItem("Base." + name);
        if (value == null) throw new AssertionError("Native item factory refused " + name);
        value.setID(id);
        value.setName(name); // Fixture has no loaded translation catalog.
        System.out.println("ITEM " + value.getFullType() + "=" + value.getClass().getName());
        return value;
    }
    public static void main(String[] args) throws Exception {
        // Reuse the existing isolated native shell/cell bootstrap, not a Lua
        // body or inventory facade. Its main method is never invoked.
        var boot = MovementCrossingProbe.class.getDeclaredMethod("boot"); boot.setAccessible(true);
        var cell = (IsoCell) boot.invoke(null);
        // Shared owned registries load before characters in a real world.
        zombie.scripting.objects.CharacterTrait.register("SurvivorAwareness:drugSensitivity");
        var create = MovementCrossingProbe.class.getDeclaredMethod("person", IsoCell.class); create.setAccessible(true);
        var body = (SAOIsoPlayerShell) create.invoke(null, cell); body.playerIndex = 99;
        var otherBody=(SAOIsoPlayerShell)create.invoke(null,cell);otherBody.playerIndex=98;
        // Build 42.21's isolated shell constructor leaves aggregate health at
        // zero. Live bodies have a calculated positive health value, which is
        // also the native precondition for moodle projection.
        body.getBodyDamage().setOverallBodyHealth(100.0f);
        otherBody.getBodyDamage().setOverallBodyHealth(100.0f);
        System.out.println("NATIVE_HEAD_PAIN " + body.getBodyDamage().getBodyPart(zombie.characters.BodyDamage.BodyPartType.Head).getAdditionalPain());

        var platform = new J2SEPlatform(); var env = platform.newEnvironment();
        var thread = new KahluaThread(platform, env); thread.debugOwnerThread = Thread.currentThread();
        LuaManager.platform = platform; LuaManager.env = env; LuaManager.thread = thread;
        zombie.ui.UIManager.defaultthread = thread;
        LuaManager.converterManager = new KahluaConverterManager();
        zombie.Lua.KahluaNumberConverter.install(LuaManager.converterManager);
        LuaManager.caller = new LuaCaller(LuaManager.converterManager);
        var exposer = new LuaManager.Exposer(LuaManager.converterManager, platform, env);
        Class<?>[] types = {SAOBridge.class, SAOIsoPlayerShell.class, zombie.characters.IsoPlayer.class,
            zombie.characters.IsoGameCharacter.class, InventoryItem.class, Food.class, DrainableComboItem.class,
            ItemContainer.class, Item.class, ItemTag.class, ArrayList.class, zombie.iso.IsoCell.class,
            zombie.util.list.PZArrayList.class,
            zombie.characters.Stats.class, zombie.characters.CharacterStat.class,
            zombie.iso.IsoGridSquare.class, zombie.iso.IsoObject.class,
            zombie.characters.BodyDamage.BodyDamage.class, zombie.characters.BodyDamage.BodyPart.class,
            zombie.characters.BodyDamage.BodyPartType.class, zombie.characters.BodyDamage.Fitness.class,
            zombie.scripting.objects.ResourceLocation.class, body.getCharacterTraits().getClass(),
            zombie.characters.Moodles.Moodles.class,zombie.scripting.objects.MoodleType.class,
            zombie.scripting.objects.CharacterTrait.class, zombie.scripting.logic.RecipeCodeOnEat.class,
            zombie.entity.components.fluids.FluidContainer.class, zombie.entity.components.fluids.Fluid.class,
            zombie.entity.components.fluids.FluidProperties.class, zombie.entity.components.fluids.SealedFluidProperties.class,
            zombie.core.properties.PropertyContainer.class, zombie.characters.CharacterSoundEmitter.class,
            zombie.audio.BaseSoundEmitter.class,
            zombie.iso.SpriteDetails.IsoFlagType.class, zombie.iso.sprite.IsoSprite.class};
        for (Class<?> type : types) exposer.setExposed(type);
        for (Class<?> type : types) exposer.exposeLikeJava(type, env);
        zombie.Lua.LuaEventManager.register(platform, env);
        var arrays = platform.newTable();
        arrays.rawset("new", (JavaFunction) (frame, count) -> { frame.push(new ArrayList<>()); return 1; });
        env.rawset("__nativeArrays", arrays);
        env.rawset("__nativePrint", (JavaFunction) (frame, count) -> {
            System.out.println(frame.get(0)); return 0;
        });
        env.rawset("__nativeInstanceof", (JavaFunction) (frame, count) -> {
            Object value = frame.get(0); String name = (String) frame.get(1);
            boolean matches = false;
            for (Class<?> type = value == null ? null : value.getClass(); type != null; type = type.getSuperclass()) {
                if (type.getSimpleName().equals(name)) { matches = true; break; }
            }
            frame.push(matches); return 1;
        });
        env.rawset("__nativeModuleDotType", (JavaFunction) (frame, count) -> {
            frame.push(LuaManager.GlobalObject.moduleDotType((String) frame.get(0), (String) frame.get(1))); return 1;
        });
        env.rawset("__realBody", body); env.rawset("__realBridge", SAOBridge.INSTANCE);
        env.rawset("__otherBody",otherBody);
        env.rawset("__nativeMetabolism",(JavaFunction)(frame,count)->{
            frame.push(com.sao.engine.SAOHibernation.advanceDormantMetabolism(body,
                ((Number)frame.get(0)).doubleValue()));return 1;
        });
        env.rawset("__roundTrip",(JavaFunction)(frame,count)->{
            try {
                var buffer=java.nio.ByteBuffer.allocate(1024*1024);
                ((se.krka.kahlua.vm.KahluaTable)frame.get(0)).save(buffer);buffer.flip();
                var restored=platform.newTable();restored.load(buffer,zombie.iso.IsoWorld.getWorldVersion());
                frame.push(restored);return 1;
            } catch(java.io.IOException exception) {throw new RuntimeException(exception);}
        });
        env.rawset("__nativeLoot",(JavaFunction)(frame,count)->{
            try {
                var parse=zombie.inventory.ItemPickerJava.class.getDeclaredMethod("ParseProceduralDistributions");
                parse.setAccessible(true);parse.invoke(null);
                var result=platform.newTable();
                for (var name:zombie.inventory.ItemPickerJava.ProceduralDistributions.keySet()) {
                    var pool=zombie.inventory.ItemPickerJava.ProceduralDistributions.get(name);
                    if(pool.items==null)continue;
                    for(var entry:pool.items)if(entry.itemName.startsWith("SAO."))
                        result.rawset(name+":"+entry.itemName,(double)entry.chance);
                }
                frame.push(result);return 1;
            } catch(Exception exception) {throw new RuntimeException(exception);}
        });
        env.rawset("__nativeItemTag", env.rawget("ItemTag"));
        env.rawset("__nativeCharacterStat", env.rawget("CharacterStat"));
        env.rawset("__nativeCharacterTrait", env.rawget("CharacterTrait"));
        env.rawset("__nativeBodyPartType", env.rawget("BodyPartType"));
        env.rawset("__nativeResourceLocation", env.rawget("ResourceLocation"));
        env.rawset("__nativeMoodleType", env.rawget("MoodleType"));

        var dictionary = new Dictionary();
        var data = WorldDictionary.class.getDeclaredField("data"); data.setAccessible(true); data.set(null, dictionary);
        var initFluids = ResourceApproachProbe.class.getDeclaredMethod("initFluids"); initFluids.setAccessible(true); initFluids.invoke(null);
        var module = ScriptManager.instance.getModule("Base");
        Path game = Path.of(args[0]);
        var pack = item(game, module, dictionary, "drainable.txt", "CigarettePack", (short) 1701);
        var single = item(game, module, dictionary, "food.txt", "CigaretteSingle", (short) 1702);
        var matches = item(game, module, dictionary, "drainable.txt", "Matches", (short) 1703);
        var pills = item(game, module, dictionary, "drainable.txt", "Pills", (short) 1704);
        if (!(pack instanceof DrainableComboItem) || !(single instanceof Food)
                || !pack.hasTag(ItemTag.CONSUMABLE) || !pack.hasTag(ItemTag.SMOKABLE)) {
            throw new AssertionError("Installed native item contract differs");
        }
        body.getInventory().AddItem(pack); body.getInventory().AddItem(single);
        body.getInventory().AddItem(matches); body.getInventory().AddItem(pills);
        if (body.getInventory().getItems().size() != 4) throw new AssertionError("Native inventory did not admit fixture items");
        var receiptSingle = zombie.inventory.InventoryItemFactory.CreateItem("Base.CigaretteSingle");
        receiptSingle.setID(1705); receiptSingle.setName("CigaretteSingle"); body.getInventory().AddItem(receiptSingle);
        env.rawset("__pack", pack); env.rawset("__single", single);
        env.rawset("__matches", matches); env.rawset("__pills", pills);
        env.rawset("__receiptSingle", receiptSingle);
        var bottle = item(game, module, dictionary, "normal.txt", "WaterBottle", (short) 1706);
        bottle.getFluidContainer().Empty(); bottle.getFluidContainer().addFluid(zombie.entity.components.fluids.Fluid.Water, 1);
        body.getInventory().AddItem(bottle); env.rawset("__bottle", bottle);
        var sink = new zombie.iso.IsoObject(cell, body.getCurrentSquare(), "fixtures_sinks_01_0");
        body.getCurrentSquare().getObjects().add(sink);
        var makeFluid = ResourceApproachProbe.class.getDeclaredMethod("fluid", zombie.iso.IsoObject.class); makeFluid.setAccessible(true); makeFluid.invoke(null, sink);
        sink.getSprite().name="fixtures_sinks_01_0";
        env.rawset("__sink", sink);
        var owned = new ScriptModule(); owned.name = "SAO";
        ScriptManager.instance.moduleMap.put("SAO", owned);
        ScriptManager.instance.moduleList.add(owned);
        String definitions = ScriptParser.stripComments(Files.readString(Path.of(args[1])));
        var matchesOwned = Pattern.compile("\\bitem\\s+(\\w+)\\s*\\{").matcher(definitions);
        short nextId = 1800;
        var nativeItems = platform.newTable();
        while (matchesOwned.find()) {
            int end = matchesOwned.end(), depth = 1;
            while (depth > 0 && end < definitions.length()) {
                char c = definitions.charAt(end++);
                if (c == '{') depth++; else if (c == '}') depth--;
            }
            if (depth != 0) throw new AssertionError("Unclosed owned item");
            String name = matchesOwned.group(1);
            var definition = new Item(); definition.setModule(owned); definition.setName(name);
            definition.Load(name, definitions.substring(matchesOwned.start(), end));
            definition.setRegistry_id(nextId);
            owned.items.getScriptMap().put(name, definition); dictionary.register(definition, nextId);
            var value = zombie.inventory.InventoryItemFactory.CreateItem("SAO." + name);
            if (!(value instanceof DrainableComboItem) || !value.hasTag(ItemTag.CONSUMABLE)) {
                throw new AssertionError("Owned native consumable refused: " + name);
            }
            value.setID(nextId++); value.setName(name); body.getInventory().AddItem(value);
            nativeItems.rawset(name, value);
            System.out.println("OWNED " + value.getFullType() + "=" + value.getClass().getName());
        }
        env.rawset("__ownedItems", nativeItems);
        final int[] nativeItemSequence = {3000};
        env.rawset("__copyNativeItem", (JavaFunction) (frame, count) -> {
            var value = zombie.inventory.InventoryItemFactory.CreateItem((String)frame.get(0));
            value.setID(nativeItemSequence[0]++); body.getInventory().AddItem(value);
            frame.push(value); return 1;
        });
        // The game invokes each native moodle update from Java. Build 42.21 no
        // longer exposes that call faithfully through Kahlua, while the full
        // fixture update also enters unrelated weather-region infrastructure.
        var moodlesField = zombie.characters.Moodles.Moodles.class.getDeclaredField("moodles");
        moodlesField.setAccessible(true);
        @SuppressWarnings("unchecked")
        var moodleMap = (java.util.Map<zombie.scripting.objects.MoodleType, zombie.characters.Moodles.Moodle>)
            moodlesField.get(body.getMoodles());
        env.rawset("__nativeTiredMoodleUpdate", (JavaFunction) (frame, count) -> {
            moodleMap.get(zombie.scripting.objects.MoodleType.TIRED).Update(); return 0;
        });
        for (int i = 2; i < args.length; i++) {
            thread.call(LuaCompiler.loadstring(Files.readString(Path.of(args[i])), args[i], env), null, null, null);
        }
        System.out.println("VALUE " + env.rawget("PHARMACOLOGY_RESULT"));
    }
}
