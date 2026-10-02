import com.sao.engine.SAOIsoPlayerShell;
import com.sao.engine.SAONativeSnapshot;
import com.sao.engine.SAOHibernation;
import com.sao.engine.SAOPrivateInventory;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.regex.Pattern;
import se.krka.kahlua.converter.KahluaConverterManager;
import se.krka.kahlua.integration.LuaCaller;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.JavaFunction;
import se.krka.kahlua.vm.KahluaTable;
import se.krka.kahlua.vm.KahluaThread;
import zombie.Lua.LuaManager;
import zombie.characters.IsoPlayer;
import zombie.inventory.InventoryItem;
import zombie.inventory.ItemContainer;
import zombie.inventory.types.Food;
import zombie.inventory.types.InventoryContainer;
import zombie.scripting.ScriptManager;
import zombie.scripting.ScriptParser;
import zombie.scripting.objects.Item;
import zombie.scripting.objects.ScriptModule;
import zombie.world.DictionaryData;
import zombie.world.ItemInfo;
import zombie.world.WorldDictionary;

/** Installed cooler Lua, actual engine bodies/items/time and strict native codecs.
 * Controlled cell/audio/appearance bootstrap; events, network sends and UI are
 * explicit offline fixtures. No rendered game, real save or multiplayer run. */
public final class ModMechanicsProbe {
    private static final class Info extends ItemInfo {
        Info(Item item, short id) {
            name = item.getName(); moduleName = item.getModule().name;
            fullType = moduleName + "." + name; registryId = id;
            isLoaded = true; scriptItem = item; entityScript = item;
            modId = moduleName.equals("Base") ? "pz-vanilla" : "TienCoolers";
        }
    }
    private static final class Dictionary extends DictionaryData {
        void register(Item item, short id) {
            var info = new Info(item, id);
            itemIdToInfoMap.put(id, info); itemTypeToInfoMap.put(info.getFullType(), info);
        }
    }
    private static InventoryItem item(Path file, String moduleName, String name,
            short registryId, int instanceId, Dictionary dictionary) throws Exception {
        // getModule(String) falls back to Base for an unregistered module.
        // Register the installed Workshop namespace before invoking the factory.
        var module = ScriptManager.instance.moduleMap.get(moduleName);
        if (module == null) {
            module = new ScriptModule(); module.name = moduleName;
            ScriptManager.instance.moduleMap.put(moduleName, module);
            ScriptManager.instance.moduleList.add(module);
        }
        var existing = module.items.getScriptMap().get(name);
        if (existing == null) {
            String text = ScriptParser.stripComments(Files.readString(file));
            var match = Pattern.compile("\\bitem\\s+" + Pattern.quote(name) + "\\s*\\{").matcher(text);
            if (!match.find()) throw new AssertionError("Installed item absent: " + name);
            int end = match.end(), depth = 1;
            while (depth > 0 && end < text.length()) {
                char c = text.charAt(end++);
                if (c == '{') depth++; else if (c == '}') depth--;
            }
            if (depth != 0) throw new AssertionError("Installed item unclosed: " + name);
            var definition = new Item(); definition.setModule(module); definition.setName(name);
            definition.Load(name, text.substring(match.start(), end));
            definition.setRegistry_id(registryId);
            module.items.getScriptMap().put(name, definition); dictionary.register(definition, registryId);
        }
        InventoryItem value = zombie.inventory.InventoryItemFactory.CreateItem(moduleName + "." + name);
        if (value == null) throw new AssertionError("Native factory refused " + name);
        value.setID(instanceId); value.setName(name);
        return value;
    }
    private static SAOIsoPlayerShell body(zombie.iso.IsoCell cell, String id, int index) throws Exception {
        var create = MovementCrossingProbe.class.getDeclaredMethod("person", zombie.iso.IsoCell.class);
        create.setAccessible(true);
        var result = (SAOIsoPlayerShell) create.invoke(null, cell); result.playerIndex = index;
        result.setSquare(result.getCurrentSquare()); result.setNpc(true);
        cell.getObjectList().add(result);
        result.getCurrentSquare().getMovingObjects().add(result);
        result.getModData().rawset("SAOPersonId", id);
        return result;
    }
    private static KahluaTable set(Path game, Path mod, zombie.iso.IsoCell cell,
            String id, int index, int itemId, Dictionary dictionary, boolean nested) throws Exception {
        var result = LuaManager.platform.newTable(); var person = body(cell, id, index);
        var generated = game.resolve("media/scripts/generated/items");
        var cooler = (InventoryContainer) item(generated.resolve("container.txt"), "Base", "Cooler", (short) 3101, itemId, dictionary);
        var ice = item(mod.resolve("media/scripts/TienCooler_items.txt"), "TienCoolers", "IceBag", (short) 3102, itemId + 1, dictionary);
        var food = (Food) item(generated.resolve("food.txt"), "Base", "Apple", (short) 3103, itemId + 2, dictionary);
        var loose = (Food) item(generated.resolve("food.txt"), "Base", "Apple", (short) 3103, itemId + 3, dictionary);
        if (nested) {
            var bag = (InventoryContainer) item(generated.resolve("container.txt"), "Base", "Bag_GolfBag", (short) 3104, itemId + 4, dictionary);
            person.getInventory().AddItem(bag); bag.getInventory().AddItem(cooler);
            result.rawset("bag", bag);
        } else person.getInventory().AddItem(cooler);
        cooler.getInventory().AddItem(ice); cooler.getInventory().AddItem(food);
        person.getInventory().AddItem(loose);
        result.rawset("body", person); result.rawset("cooler", cooler);
        result.rawset("ice", ice); result.rawset("food", food); result.rawset("loose", loose);
        return result;
    }
    public static void main(String[] args) throws Exception {
        Path game = Path.of(args[0]), mod = Path.of(args[1]);
        var boot = MovementCrossingProbe.class.getDeclaredMethod("boot"); boot.setAccessible(true);
        var cell = (zombie.iso.IsoCell) boot.invoke(null);
        for (int i = 0; i < IsoPlayer.players.length; i++) IsoPlayer.players[i] = null;
        var platform = new J2SEPlatform(); var env = platform.newEnvironment();
        var thread = new KahluaThread(platform, env); thread.debugOwnerThread = Thread.currentThread();
        LuaManager.platform = platform; LuaManager.env = env; LuaManager.thread = thread;
        zombie.ui.UIManager.defaultthread = thread;
        LuaManager.converterManager = new KahluaConverterManager();
        zombie.Lua.KahluaNumberConverter.install(LuaManager.converterManager);
        LuaManager.caller = new LuaCaller(LuaManager.converterManager);
        var exposer = new LuaManager.Exposer(LuaManager.converterManager, platform, env);
        Class<?>[] types = {SAOIsoPlayerShell.class, IsoPlayer.class, zombie.characters.IsoGameCharacter.class,
            zombie.iso.IsoMovingObject.class, zombie.iso.IsoObject.class, zombie.iso.IsoGridSquare.class,
            InventoryItem.class, InventoryContainer.class, Food.class, zombie.inventory.types.DrainableComboItem.class,
            ItemContainer.class, Item.class, ArrayList.class, zombie.GameTime.class,
            zombie.iso.IsoWorld.class, zombie.iso.IsoCell.class,
            cell.getObjectList().getClass(), cell.getAddList().getClass()};
        for (Class<?> type : types) exposer.setExposed(type);
        for (Class<?> type : types) exposer.exposeLikeJava(type, env);
        var dictionary = new Dictionary();
        var data = WorldDictionary.class.getDeclaredField("data"); data.setAccessible(true); data.set(null, dictionary);
        env.rawset("__a", set(game, mod, cell, "cool-a", 99, 4101, dictionary, true));
        env.rawset("__b", set(game, mod, cell, "cool-b", 98, 4201, dictionary, false));
        var player = set(game, mod, cell, "player", 0, 4301, dictionary, false);
        IsoPlayer.players[0] = (IsoPlayer) player.rawget("body"); env.rawset("__p", player);
        env.rawset("__print", (JavaFunction) (frame, count) -> { System.out.println(frame.get(0)); return 0; });
        env.rawset("__world", (JavaFunction) (frame, count) -> {
            frame.push(zombie.iso.IsoWorld.instance); return 1;
        });
        env.rawset("__replaceWorld", (JavaFunction) (frame, count) -> {
            zombie.iso.IsoWorld.instance.currentCell = Boolean.TRUE.equals(frame.get(0))
                ? new zombie.iso.IsoCell(1, 1) : cell;
            return 0;
        });
        env.rawset("__recordRoundTrip", (JavaFunction) (frame, count) -> {
            try {
                var source = (KahluaTable) frame.get(0);
                var buffer = java.nio.ByteBuffer.allocate(65536);
                source.save(buffer); buffer.flip();
                var restored = LuaManager.platform.newTable();
                restored.load(buffer, 249);
                if (buffer.hasRemaining()) throw new AssertionError("Unconsumed native record bytes");
                frame.push(restored); return 1;
            } catch (Exception failure) { throw new IllegalStateException(failure); }
        });
        env.rawset("__slot", (JavaFunction) (frame, count) -> {
            frame.push(IsoPlayer.players[((Double) frame.get(0)).intValue()]); return 1;
        });
        env.rawset("__time", (JavaFunction) (frame, count) -> {
            zombie.GameTime.getInstance().setTimeOfDay(((Double) frame.get(0)).floatValue());
            frame.push(zombie.GameTime.getInstance().getWorldAgeHours()); return 1;
        });
        env.rawset("__random", (JavaFunction) (frame, count) -> {
            frame.push((double) zombie.core.random.Rand.Next(((Double) frame.get(0)).intValue())); return 1;
        });
        env.rawset("__instanceof", (JavaFunction) (frame, count) -> {
            Object value = frame.get(0); String name = (String) frame.get(1); boolean matches = false;
            for (Class<?> type = value == null ? null : value.getClass(); type != null; type = type.getSuperclass())
                if (type.getSimpleName().equals(name)) { matches = true; break; }
            frame.push(matches); return 1;
        });
        env.rawset("__capture", (JavaFunction) (frame, count) -> {
            try { frame.push(SAONativeSnapshot.capture((IsoPlayer) frame.get(0))); return 1; }
            catch (Exception failure) { throw new IllegalStateException(failure); }
        });
        env.rawset("__bodySet", (JavaFunction) (frame, count) -> {
            try {
                frame.push(set(game, mod, cell, (String) frame.get(0), 96,
                    ((Double) frame.get(1)).intValue(), dictionary, true)); return 1;
            } catch (Exception failure) { throw new IllegalStateException(failure); }
        });
        env.rawset("__snapshotValid", (JavaFunction) (frame, count) -> {
            frame.push(SAOHibernation.validate((String) frame.get(0))); return 1;
        });
        env.rawset("__snapshotVersion", (JavaFunction) (frame, count) -> {
            try { frame.push((double) SAONativeSnapshot.formatVersion((String) frame.get(0))); return 1; }
            catch (Exception failure) { throw new IllegalStateException(failure); }
        });
        env.rawset("__snapshotRest", (JavaFunction) (frame, count) -> {
            frame.push(SAONativeSnapshot.restState((String) frame.get(0))); return 1;
        });
        env.rawset("__radioCapture", (JavaFunction) (frame, count) -> {
            frame.push(SAOPrivateInventory.captureRadioState((IsoPlayer) frame.get(0))); return 1;
        });
        env.rawset("__radioValid", (JavaFunction) (frame, count) -> {
            frame.push(SAOPrivateInventory.validateRadioState((String) frame.get(0))); return 1;
        });
        env.rawset("__bodyRemove", (JavaFunction) (frame, count) -> {
            // Fixture teardown uses native cell collections. Production Bridge's
            // unregister/audio lifecycle is deliberately outside this caller proof.
            IsoPlayer person = (IsoPlayer) frame.get(0);
            cell.getObjectList().remove(person); cell.getAddList().remove(person);
            if (person.getCurrentSquare() != null)
                person.getCurrentSquare().getMovingObjects().remove(person);
            person.setCurrent(null); person.setSquare(null);
            frame.push(Boolean.TRUE); return 1;
        });
        env.rawset("__releaseReady", (JavaFunction) (frame, count) -> {
            IsoPlayer person = (IsoPlayer) frame.get(0);
            frame.push(person.getVehicle() == null && person.getCharacterActions().isEmpty()); return 1;
        });
        env.rawset("__newBody", (JavaFunction) (frame, count) -> {
            try { frame.push(body(cell, (String) frame.get(0), 97)); return 1; }
            catch (Exception failure) { throw new IllegalStateException(failure); }
        });
        env.rawset("__wake", (JavaFunction) (frame, count) -> {
            frame.push(SAOHibernation.awaken((IsoPlayer) frame.get(0), (String) frame.get(1), (Double) frame.get(2))); return 1;
        });
        env.rawset("__detach", (JavaFunction) (frame, count) -> {
            IsoPlayer person = (IsoPlayer) frame.get(0);
            if (Boolean.TRUE.equals(frame.get(1))) {
                person.getCurrentSquare().getMovingObjects().remove(person);
                person.setCurrent(null); person.setSquare(null);
            } else {
                person.setCurrent(cell.getGridSquare(10, 20, 0)); person.setSquare(person.getCurrentSquare());
                person.getCurrentSquare().getMovingObjects().add(person);
            }
            return 0;
        });
        for (int i = 2; i < args.length; i++) {
            String source = Files.readString(Path.of(args[i]));
            thread.call(LuaCompiler.loadstring(source, args[i], env), null, null, null);
        }
        System.out.println("MOD_MECHANICS_NATIVE_OK");
    }
}
