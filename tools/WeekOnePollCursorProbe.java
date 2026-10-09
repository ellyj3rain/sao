import java.util.AbstractSet;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.j2se.KahluaTableImpl;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.KahluaTable;
import se.krka.kahlua.vm.KahluaThread;
import com.sao.bridge.SAOBridge;
import com.sao.engine.SAOWeekOnePollCursor;

/** Installed-Kahlua proof of dense Lua indexing and bounded native visits. */
public final class WeekOnePollCursorProbe {
    private static final class CountingMap extends LinkedHashMap<Object, Object> {
        int nextCalls;
        int keySetCalls;
        @Override public Set<Object> keySet() {
            keySetCalls++;
            throw new AssertionError("snapshot keySet requested");
        }
        @Override public Set<Map.Entry<Object, Object>> entrySet() {
            Set<Map.Entry<Object, Object>> original = super.entrySet();
            return new AbstractSet<>() {
                @Override public int size() { return original.size(); }
                @Override public Iterator<Map.Entry<Object, Object>> iterator() {
                    Iterator<Map.Entry<Object, Object>> source = original.iterator();
                    return new Iterator<>() {
                        @Override public boolean hasNext() { return source.hasNext(); }
                        @Override public Map.Entry<Object, Object> next() {
                            nextCalls++;
                            return source.next();
                        }
                    };
                }
            };
        }
    }

    private static void check(boolean yes, String reason) {
        if (!yes) throw new AssertionError(reason);
    }

    private static KahluaTableImpl table(CountingMap map) {
        return new KahluaTableImpl(map);
    }

    public static void main(String[] args) throws Exception {
        SAOWeekOnePollCursor.resetRuntimeForWorld();
        CountingMap map = new CountingMap();
        for (int i = 1; i <= 1200; i++) map.put((double)i, i);
        KahluaTableImpl source = table(map);
        check(SAOWeekOnePollCursor.entries(source, "invalid", 12) == null,
            "unknown stream admitted");
        check(SAOWeekOnePollCursor.entries(source, "ClientCache", 129) == null,
            "unbounded limit admitted");
        KahluaTableImpl performance = SAOWeekOnePollCursor.entries(source,
            "ClientPerformanceRows", 32);
        check(performance != null && performance.len() == 32
            && Double.valueOf(1).equals(performance.rawget(1)),
            "current performance row stream refused");
        KahluaTableImpl hearers = SAOWeekOnePollCursor.entries(source,
            "source-performance-hearers", 128);
        check(hearers != null && hearers.len() == 128
            && Double.valueOf(1).equals(hearers.rawget(1)),
            "current source hearer stream refused");
        check(SAOWeekOnePollCursor.reset("source-performance-hearers"),
            "source hearer stream reset refused");
        CountingMap pendingMap = new CountingMap();
        pendingMap.put("person-a", true);
        pendingMap.put("person-b", true);
        KahluaTableImpl pending = table(pendingMap);
        KahluaTableImpl inquiry = SAOWeekOnePollCursor.entries(pending,
            "SourceInquiryPersons", 16);
        check(inquiry != null && inquiry.len() == 2
            && "person-a".equals(inquiry.rawget(1))
            && "person-b".equals(inquiry.rawget(2)),
            "pending source inquiry persons refused");
        check(SAOWeekOnePollCursor.reset("SourceInquiryPersons"),
            "pending source inquiry stream reset refused");

        J2SEPlatform platform = new J2SEPlatform();
        KahluaTable env = platform.newEnvironment();
        KahluaThread thread = new KahluaThread(platform, env);
        thread.debugOwnerThread = Thread.currentThread();
        zombie.Lua.LuaManager.platform = platform;
        zombie.Lua.LuaManager.env = env;
        zombie.Lua.LuaManager.converterManager =
            new se.krka.kahlua.converter.KahluaConverterManager();
        zombie.Lua.LuaManager.caller = new se.krka.kahlua.integration.LuaCaller(
            zombie.Lua.LuaManager.converterManager);
        zombie.Lua.KahluaNumberConverter.install(
            zombie.Lua.LuaManager.converterManager);
        zombie.Lua.LuaManager.thread = thread;
        zombie.Lua.LuaManager.Exposer exposer =
            new zombie.Lua.LuaManager.Exposer(
                zombie.Lua.LuaManager.converterManager, platform, env);
        exposer.setExposed(SAOBridge.class);
        exposer.exposeLikeJava(SAOBridge.class, env);
        env.rawset("SAOJavaBridge", SAOBridge.INSTANCE);
        env.rawset("cache", source);
        env.rawset("pending", pending);
        int beforeLua = map.nextCalls;
        Object luaIndex = thread.call(LuaCompiler.loadstring(
            "local b=SAOJavaBridge:weekOnePollEntries(cache,'Babe',64); " +
            "return type(SAOJavaBridge.weekOnePollEntries)=='function' " +
            "and type(SAOJavaBridge.weekOnePollReset)=='function' " +
            "and type(b)=='table' and #b==64 and b[1]==1 and b[2]==2 " +
            "and SAOJavaBridge:weekOnePollReset('Babe')==true",
            "poll-index", env), null, null, null);
        check(Boolean.TRUE.equals(luaIndex), "Lua numeric batch indexing failed");
        check(map.nextCalls - beforeLua == 64 && map.keySetCalls == 0,
            "Lua call traversed or snapshotted raw cache");
        int beforePending = pendingMap.nextCalls;
        Object luaPending = thread.call(LuaCompiler.loadstring(
            "local b=SAOJavaBridge:weekOnePollEntries(pending,'SourceInquiryPersons',16); " +
            "return type(b)=='table' and #b==2 and b[1]=='person-a' " +
            "and b[2]=='person-b'",
            "source-inquiry-index", env), null, null, null);
        check(Boolean.TRUE.equals(luaPending)
            && pendingMap.nextCalls - beforePending == 2
            && pendingMap.keySetCalls == 0,
            "Lua pending inquiry stream refused or snapshotted");

        int covered = 0;
        int calls = 0;
        while (covered < 1200) {
            int before = map.nextCalls;
            KahluaTableImpl batch = SAOWeekOnePollCursor.entries(source,
                "ClientRows", 128);
            check(batch != null && batch.len() <= 128,
                "missing or oversized dense batch");
            check(map.nextCalls - before <= 128, "raw visit limit exceeded");
            for (int n = 1; n <= batch.len(); n++) {
                Object key = batch.rawget(n);
                check(key instanceof Double && (Double)key == covered + 1,
                    "round-robin coverage skipped a raw key");
                covered++;
            }
            check(++calls <= 11, "1200 keys failed bounded sweep");
        }
        check(calls == 10 && covered == 1200,
            "1200-key sweep used unexpected budget");
        CountingMap newMap = new CountingMap();
        newMap.put(2001.0, "new");
        KahluaTableImpl replacement = table(newMap);
        KahluaTableImpl end = SAOWeekOnePollCursor.entries(replacement,
            "ClientRows", 128);
        check(end != null && end.len() == 0, "pass boundary missing");
        KahluaTableImpl firstNew = SAOWeekOnePollCursor.entries(replacement,
            "ClientRows", 128);
        check(firstNew != null && firstNew.len() == 1
            && Double.valueOf(2001).equals(firstNew.rawget(1)),
            "replacement pass did not open on latest table");
        check(SAOWeekOnePollCursor.reset("ClientRows")
            && SAOWeekOnePollCursor.entries(replacement,
                "ClientRows", 128).len() == 1,
            "explicit stream reset failed");

        // One structural change between every call invalidates HashMap's
        // saved iterator. This records the bounded but starving limitation.
        CountingMap churn = new CountingMap();
        for (int i = 1; i <= 1024; i++) churn.put((double)i, i);
        KahluaTableImpl changing = table(churn);
        int tail = 0;
        for (int minute = 0; minute < 12; minute++) {
            int before = churn.nextCalls;
            KahluaTableImpl batch = SAOWeekOnePollCursor.entries(changing,
                "Native", 128);
            check(batch != null && churn.nextCalls - before <= 128,
                "in-place churn exceeded raw visit limit");
            for (int n = 1; n <= batch.len(); n++) {
                if (Double.valueOf(1024).equals(batch.rawget(n))) tail++;
            }
            churn.put((double)(2000 + minute), minute);
        }
        check(tail == 0, "expected sustained-mutation limit changed");
        SAOWeekOnePollCursor.resetRuntimeForWorld();
        KahluaTableImpl afterWorld = SAOWeekOnePollCursor.entries(replacement,
            "Native", 64);
        check(afterWorld != null && afterWorld.len() == 1,
            "world reset retained an old table");
        System.out.println("PASS dense Lua [1]/[2], no keySet, 1200/10 bounded " +
            "round-robin, replacement/reset/world; LIMIT in-place mutation " +
            "can starve tail");
    }
}
