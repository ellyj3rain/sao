import com.sao.bridge.SAOBridge;
import com.sao.engine.SAOIsoPlayerShell;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import se.krka.kahlua.converter.KahluaConverterManager;
import se.krka.kahlua.integration.LuaCaller;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.KahluaThread;
import zombie.Lua.LuaManager;
import zombie.iso.IsoCell;

/** Real unequal character/body health through the shipped inspection producer. */
public final class ObservationHealthProbe {
    public static void main(String[] args) throws Exception {
        var boot = MovementCrossingProbe.class.getDeclaredMethod("boot");
        boot.setAccessible(true);
        var cell = (IsoCell) boot.invoke(null);
        var create = MovementCrossingProbe.class.getDeclaredMethod("person", IsoCell.class);
        create.setAccessible(true);
        var body = (SAOIsoPlayerShell) create.invoke(null, cell);
        body.playerIndex = 99;
        body.setHealth(1f);
        body.getBodyDamage().setOverallBodyHealth(37.5f);
        if (body.getHealth() != 1f || body.getBodyDamage().getOverallBodyHealth() != 37.5f) {
            throw new AssertionError("Native unequal health fixture differs");
        }

        var platform = new J2SEPlatform();
        var env = platform.newEnvironment();
        var thread = new KahluaThread(platform, env);
        thread.debugOwnerThread = Thread.currentThread();
        LuaManager.platform = platform; LuaManager.env = env; LuaManager.thread = thread;
        LuaManager.converterManager = new KahluaConverterManager();
        zombie.Lua.KahluaNumberConverter.install(LuaManager.converterManager);
        LuaManager.caller = new LuaCaller(LuaManager.converterManager);
        var exposer = new LuaManager.Exposer(LuaManager.converterManager, platform, env);
        Class<?>[] types = {SAOBridge.class, SAOIsoPlayerShell.class,
            zombie.characters.IsoPlayer.class, zombie.characters.IsoGameCharacter.class,
            zombie.characters.BodyDamage.BodyDamage.class, zombie.iso.IsoGridSquare.class,
            zombie.inventory.ItemContainer.class, ArrayList.class};
        for (Class<?> type : types) exposer.setExposed(type);
        for (Class<?> type : types) exposer.exposeLikeJava(type, env);
        env.rawset("__nativeBody", body);
        env.rawset("__nativeBridge", SAOBridge.INSTANCE);
        for (String file : args) {
            thread.call(LuaCompiler.loadstring(Files.readString(Path.of(file)), file, env), null, null, null);
        }
        System.out.println("VALUE " + env.rawget("NATIVE_HEALTH_RESULT"));
    }
}
