import java.io.Reader;
import java.lang.reflect.Field;
import java.lang.ref.WeakReference;
import java.util.HashMap;
import java.util.Map;
import java.nio.charset.StandardCharsets;
import java.nio.ByteBuffer;
import java.nio.file.Files;
import java.nio.file.Path;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.JavaFunction;
import se.krka.kahlua.vm.KahluaTable;
import se.krka.kahlua.vm.KahluaThread;
import se.krka.kahlua.vm.LuaCallFrame;
import sun.misc.Unsafe;
import zombie.inventory.InventoryItem;
import zombie.inventory.ItemContainer;
import zombie.iso.objects.IsoWindow;

/** Installed Kahlua/action execution; isolated native receivers, controlled surroundings. */
public final class WindowRepairNativeProbe {
    private static IsoWindow window;
    private static ItemContainer inventory;
    private static InventoryItem pane;
    private static Unsafe unsafe() throws Exception {
        Field field = Unsafe.class.getDeclaredField("theUnsafe");
        field.setAccessible(true);
        return (Unsafe) field.get(null);
    }
    private static void reset() throws Exception {
        // Unattached receivers avoid creating an IsoWorld, save, map, renderer or player.
        window = (IsoWindow) unsafe().allocateInstance(IsoWindow.class);
        pane = (InventoryItem) unsafe().allocateInstance(InventoryItem.class);
        pane.setModule("RepairableWindows");
        pane.setType("LargeGlassPane");
        pane.setID(713);
        inventory = new ItemContainer();
        inventory.AddItemBlind(pane);
        window.setSmashed(true);
        window.setGlassRemoved(true);
    }
    private static Object operation(String op, Object value) throws Exception {
        switch (op) {
            case "reset": reset(); return true;
            case "smashed": return window.isSmashed();
            case "glass": return window.isGlassRemoved();
            case "setSmashed": window.setSmashed(Boolean.TRUE.equals(value)); return true;
            case "setGlass": window.setGlassRemoved(Boolean.TRUE.equals(value)); return true;
            case "contains": return inventory.contains(pane);
            case "remove": inventory.Remove(pane); return true;
            case "first": return inventory.getFirstType("RepairableWindows.LargeGlassPane") == pane;
            case "poststate": return !window.isSmashed() && !window.isGlassRemoved()
                && !inventory.contains(pane) && inventory.getItems().isEmpty();
            default: throw new IllegalArgumentException(op);
        }
    }
    public static void main(String[] args) throws Exception {
        // Verify the real actor/object/material API used by the Lua adapter.
        zombie.characters.IsoGameCharacter.class.getMethod("CanSee", zombie.iso.IsoObject.class);
        zombie.characters.IsoGameCharacter.class.getMethod("getForwardDirectionX");
        zombie.characters.IsoGameCharacter.class.getMethod("getForwardDirectionY");
        zombie.iso.IsoGridSquare.class.getMethod("canStand");
        zombie.iso.IsoCell.class.getMethod("getObjectList");
        zombie.iso.IsoCell.class.getMethod("getAddList");
        IsoWindow.class.getMethod("getNorth");
        ItemContainer.class.getMethod("getFirstType", String.class);
        J2SEPlatform platform = new J2SEPlatform();
        KahluaTable env = platform.newEnvironment();
        KahluaThread thread = new KahluaThread(platform, env);
        thread.debugOwnerThread = Thread.currentThread();
        env.rawset("__nativeOp", new JavaFunction() {
            public int call(LuaCallFrame frame, int count) {
                try { return frame.push(operation((String) frame.get(0), count > 1 ? frame.get(1) : null)); }
                catch (Exception e) { throw new IllegalStateException(e); }
            }
        });
        env.rawset("__nativeRoundtrip", new JavaFunction() {
            public int call(LuaCallFrame frame, int count) {
                try {
                    ByteBuffer bytes = ByteBuffer.allocate(1048576);
                    ((KahluaTable) frame.get(0)).save(bytes);
                    bytes.flip();
                    KahluaTable restored = platform.newTable();
                    restored.load(bytes, zombie.iso.IsoWorld.WorldVersion);
                    if (bytes.hasRemaining()) throw new IllegalStateException("unconsumed native table bytes");
                    return frame.push(restored);
                } catch (Exception e) { throw new IllegalStateException(e); }
            }
        });
        // A live installed VM remains rooted while only the tested module/action
        // owners are retired. No engine character/window fields are erased.
        Map<String, WeakReference<Object>> retained = new HashMap<>();
        env.rawset("__retentionTrack", new JavaFunction() {
            public int call(LuaCallFrame frame, int count) {
                retained.put((String) frame.get(0), new WeakReference<>(frame.get(1)));
                return frame.push(true);
            }
        });
        env.rawset("__retentionAlive", new JavaFunction() {
            public int call(LuaCallFrame frame, int count) {
                WeakReference<Object> ref = retained.get((String) frame.get(0));
                if (ref == null) throw new IllegalStateException("untracked retention target");
                return frame.push(ref.get() != null);
            }
        });
        env.rawset("__retentionCollect", new JavaFunction() {
            public int call(LuaCallFrame frame, int count) {
                try {
                    for (int i = 0; i < 8; i++) { System.gc(); Thread.sleep(10); }
                    return frame.push(true);
                } catch (InterruptedException e) { Thread.currentThread().interrupt(); throw new IllegalStateException(e); }
            }
        });
        env.rawset("__nativeActionArgs", new JavaFunction() {
            public int call(LuaCallFrame frame, int count) {
                try {
                    KahluaTable action = (KahluaTable) frame.get(0);
                    // Execute the actual installed constructor-argument projection.
                    zombie.Lua.LuaManager.thread = thread;
                    zombie.Lua.LuaManager.caller = new se.krka.kahlua.integration.LuaCaller(
                        new se.krka.kahlua.converter.KahluaConverterManager());
                    zombie.core.NetTimedAction nativeAction = new zombie.core.NetTimedAction();
                    // An unattached native receiver supplies the PlayerID field;
                    // no native world, spawn, save or network is started.
                    zombie.characters.IsoPlayer receiver = (zombie.characters.IsoPlayer)
                        unsafe().allocateInstance(zombie.characters.IsoPlayer.class);
                    // PlayerID.set reads isLocal(), which uses the actual ECS map.
                    // Only initialize that empty fixture field; execute projection,
                    // PlayerID and time-data code unchanged on an unattached actor.
                    Field ecsMap = zombie.iso.IsoObject.class.getDeclaredField("ecsComponentMap");
                    ecsMap.setAccessible(true);
                    ecsMap.set(receiver, new HashMap<>());
                    zombie.core.random.RandStandard.INSTANCE.init();
                    nativeAction.set(receiver, action);
                    Field argsField = zombie.core.NetTimedAction.class.getDeclaredField("actionArgs");
                    argsField.setAccessible(true);
                    KahluaTable projected = (KahluaTable) argsField.get(nativeAction);
                    return frame.push(projected.rawget("character") == action.rawget("character")
                        && projected.rawget("window") == action.rawget("window")
                        && projected.rawget("body") == null && projected.rawget("_SAOWindowRepairBinding") == null
                        && ((zombie.network.PZNetKahluaTableImpl) projected).size() == 2);
                } catch (Throwable e) { e.printStackTrace(); throw new IllegalStateException(e); }
            }
        });
        for (String name : args) {
            try (Reader reader = Files.newBufferedReader(Path.of(name), StandardCharsets.UTF_8)) {
                Object[] returned = thread.pcall(LuaCompiler.loadis(reader, name, env), new Object[0]);
                if (!Boolean.TRUE.equals(returned[0])) {
                    System.out.println("ERROR chunk=" + name);
                    for (int i = 1; i < returned.length; i++) System.out.println(returned[i]);
                    System.exit(1);
                }
            }
        }
        Object result = thread.call(LuaCompiler.loadstring("return __windowResults", "results", env), null, null, null);
        System.out.println("VALUE " + result);
    }
}
