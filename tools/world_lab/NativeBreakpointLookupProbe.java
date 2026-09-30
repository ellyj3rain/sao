import java.lang.instrument.Instrumentation;
import java.lang.reflect.Field;
import java.util.ArrayList;
import java.util.HashMap;
import net.bytebuddy.agent.builder.AgentBuilder;
import net.bytebuddy.asm.Advice;
import net.bytebuddy.matcher.ElementMatchers;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.vm.KahluaThread;
import zombie.Lua.LuaManager;
import zombie.core.Core;

/** Execute installed Lua bytecode and native debugger branches without a world.
 * Only the probe replaces the interactive breakpoint loop with a receipt.
 */
public final class NativeBreakpointLookupProbe {
    public static int debuggerCalls;
    public static String debuggerSource;
    public static long debuggerLine;
    public static void premain(String argument, Instrumentation instrumentation) {
        new AgentBuilder.Default().disableClassFormatChanges()
            .with(AgentBuilder.RedefinitionStrategy.RETRANSFORMATION)
            .type(ElementMatchers.named("zombie.ui.UIManager"))
            .transform((builder, type, loader, module, domain) -> builder.visit(
                Advice.to(Capture.class).on(ElementMatchers.named("debugBreakpoint")
                    .and(ElementMatchers.takesArguments(String.class, long.class)))))
            .installOn(instrumentation);
    }
    public static final class Capture {
        @Advice.OnMethodEnter(skipOn = Advice.OnNonDefaultValue.class)
        public static boolean enter(@Advice.Argument(0) String source, @Advice.Argument(1) long line) {
            debuggerCalls++; debuggerSource = source; debuggerLine = line; return true;
        }
    }
    static final class CountedMap extends HashMap<String, ArrayList<Long>> {
        int lookups;
        @Override public boolean containsKey(Object key) { lookups++; return super.containsKey(key); }
    }
    private static void check(boolean value, String reason) {
        if (!value) throw new AssertionError(reason);
    }
    private static Field field(String name) throws Exception {
        Field field = KahluaThread.class.getDeclaredField(name); field.setAccessible(true); return field;
    }
    public static void main(String[] args) throws Exception {
        boolean optimized = args[0].equals("empty-map");
        check(StudyLoadingAgent.emptyBreakpointLookupInstalled() == optimized, "actual Lua lookup transformation differs");
        Core.debug = false;
        var platform = new J2SEPlatform(); var environment = platform.newEnvironment();
        var thread = new KahluaThread(platform, environment);
        thread.debugOwnerThread = Thread.currentThread();
        LuaManager.platform = platform; LuaManager.env = environment; LuaManager.thread = thread;
        LuaManager.debugthread = new KahluaThread(platform, environment);
        LuaManager.debugthread.debugOwnerThread = Thread.currentThread();
        LuaManager.debugcaller = new se.krka.kahlua.integration.LuaCaller(new se.krka.kahlua.converter.KahluaConverterManager());
        environment.rawset("DoLuaError", (se.krka.kahlua.vm.JavaFunction) (frame, count) -> 0);
        var closure = LuaCompiler.loadstring("local total=0\nfor i=1,100 do total=total+i end\nreturn total", "lookup-probe.lua", environment);
        closure.prototype.filename = "lookup-probe.lua";
        CountedMap map = new CountedMap(); field("breakpointMap").set(thread, map);
        Core.debug = true;
        check(Double.valueOf(5050).equals(thread.call(closure, null, null, null)), "empty-map native Lua outcome changed");
        check(optimized ? map.lookups == 0 : map.lookups > 0, "empty native map still performs instruction lookups");
        check(field("currentfile").get(thread).equals(closure.prototype.filename)
            && field("currentLine").getInt(thread) > 0, "native error source bookkeeping changed");
        map.put("unrelated.lua", new ArrayList<>(java.util.List.of(1L))); map.lookups = 0;
        check(Double.valueOf(5050).equals(thread.call(closure, null, null, null)) && map.lookups > 0
            && debuggerCalls == 0, "populated native breakpoint map was bypassed");
        map.clear(); map.lookups = 0;
        check(Double.valueOf(5050).equals(thread.call(closure, null, null, null))
            && (optimized ? map.lookups == 0 : map.lookups > 0), "cleared allocated map bypass differs");
        thread.step = true; thread.stepInto = true; debuggerCalls = 0;
        thread.call(closure, null, null, null);
        check(debuggerCalls > 0 && debuggerSource.equals(closure.prototype.filename), "native stepping lost its current source");
        thread.step = false; thread.stepInto = false; debuggerCalls = 0;
        map.put(closure.prototype.filename, new ArrayList<>(java.util.List.of(1L, 2L, 3L)));
        thread.call(closure, null, null, null);
        check(debuggerCalls > 0, "native line breakpoint no longer reaches debugger");
        map.clear(); debuggerCalls = 0;
        var failed = LuaCompiler.loadstring("local absent=nil\nreturn absent.value", "lookup-error.lua", environment);
        failed.prototype.filename = "lookup-error.lua";
        Object[] receipt = thread.pcall(failed, new Object[0]);
        System.out.println("ERROR_RECEIPT " + java.util.Arrays.toString(receipt) + " debugger=" + debuggerCalls
            + " source=" + debuggerSource + " expected=" + failed.prototype.filename + " line=" + debuggerLine);
        check(Boolean.FALSE.equals(receipt[0]) && debuggerCalls > 0
            && debuggerSource.equals(failed.prototype.filename) && debuggerLine >= 0,
            "native Lua error outcome or current failure location changed");
        check(Core.debug, "observer optimization changed global debug mode");
        System.out.println("PASS installed Lua lookup, source position, stepping, breakpoint and error controls: " + args[0]);
    }
}
