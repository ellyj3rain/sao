import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import se.krka.kahlua.converter.KahluaConverterManager;
import se.krka.kahlua.integration.LuaCaller;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.JavaFunction;
import se.krka.kahlua.vm.KahluaTable;
import se.krka.kahlua.vm.KahluaThread;
import zombie.Lua.LuaManager;
import zombie.core.Core;
import zombie.ui.UIManager;

/** Runs export fixtures with the installed VM's actual DoLuaError dispatch. */
public final class NativeStudyExportProbe {
    private static int debuggerRequests;

    public static void main(String[] args) throws Exception {
        J2SEPlatform platform = new J2SEPlatform();
        KahluaTable env = platform.newEnvironment();
        KahluaThread thread = new KahluaThread(platform, env);
        thread.debugOwnerThread = Thread.currentThread();
        KahluaThread debugThread = new KahluaThread(platform, env);
        debugThread.debugOwnerThread = Thread.currentThread();
        LuaManager.env = env;
        LuaManager.thread = thread;
        LuaManager.debugthread = debugThread;
        LuaManager.debugcaller = new LuaCaller(new KahluaConverterManager());
        // Keep the UI breakpoint branch separate, as the native debugger does;
        // DoLuaError still runs on every native stack-trace error dispatch.
        UIManager.defaultthread = debugThread;
        env.rawset("DoLuaError", (JavaFunction) (frame, count) -> {
            debuggerRequests++;
            return 0;
        });
        env.rawset("studyNativeErrorDispatches", (JavaFunction) (frame, count) -> {
            // Both counters only increase. An unchanged sum requires zero
            // new debugException dispatches and zero DoLuaError requests.
            frame.push((double) (KahluaThread.errorCount + debuggerRequests));
            return 1;
        });
        Core.debug = true;
        try {
            int errorsBefore = KahluaThread.errorCount;
            int requestsBefore = debuggerRequests;
            Object caught = thread.call(LuaCompiler.loadstring(
                "return pcall(function() assert(false, 'native export debugger calibration') end)",
                "export-debugger-calibration", env), null, null, null);
            if (!Boolean.FALSE.equals(caught) || KahluaThread.errorCount <= errorsBefore
                    || debuggerRequests <= requestsBefore) {
                throw new AssertionError("caught assertion did not reach native error and DoLuaError dispatch");
            }
            System.out.println("PASS native caught assertion reaches debugException and DoLuaError");
            String source = Files.readString(Path.of(args[0]), StandardCharsets.UTF_8);
            thread.call(LuaCompiler.loadstring(source, args[0], env), null, null, null);
            Object result = thread.call(LuaCompiler.loadstring("return " + args[1], "export-result", env),
                null, null, null);
            System.out.println("VALUE " + result);
        } catch (Throwable failure) {
            System.out.println("ERROR " + failure.getMessage());
            System.exit(1);
        }
    }
}
