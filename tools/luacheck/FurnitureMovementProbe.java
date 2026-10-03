import java.io.Reader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.KahluaTable;
import se.krka.kahlua.vm.KahluaThread;
import se.krka.kahlua.vm.JavaFunction;
import se.krka.kahlua.vm.LuaCallFrame;

/** Installed VM and complete installed Lua; map/pickup/placement receivers are controlled. */
final class FurnitureMovementProbe {
    public static void main(String[] args) throws Exception {
        // Reflection verifies the installed receiver API, not native relocation behavior.
        for (String method : new String[]{"getSquare", "getCell", "isDead", "isNpc", "isExistInTheWorld", "getVehicle"})
            zombie.characters.IsoPlayer.class.getMethod(method);
        for (String method : new String[]{"getSquare", "getSprite", "getContainerCount", "getFluidContainer", "getFluidAmount", "getFluidCapacity"})
            zombie.iso.IsoObject.class.getMethod(method);
        zombie.iso.IsoObject.class.getMethod("getContainerByIndex", int.class);
        zombie.iso.IsoGridSquare.class.getMethod("getObjects");
        zombie.iso.IsoGridSquare.class.getMethod("getBuilding");
        zombie.iso.IsoCell.class.getMethod("getGridSquare", int.class, int.class, int.class);
        zombie.inventory.ItemContainer.class.getMethod("getItems");
        zombie.inventory.InventoryItem.class.getMethod("getContainer");
        zombie.inventory.types.InventoryContainer.class.getMethod("getInventory");
        System.out.println("INSTALLED_RECEIVER_API_OK");
        J2SEPlatform platform = new J2SEPlatform();
        KahluaTable env = platform.newEnvironment();
        KahluaThread thread = new KahluaThread(platform, env);
        thread.debugOwnerThread = Thread.currentThread();
        env.rawset("print", new JavaFunction() {
            public int call(LuaCallFrame frame, int count) {
                StringBuilder line = new StringBuilder();
                for (int i = 0; i < count; i++) { if (i > 0) line.append("\t"); line.append(frame.get(i)); }
                System.out.println(line);
                return 0;
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
        System.out.println("FURNITURE_MOVEMENT_INSTALLED_VM_OK");
    }
}
