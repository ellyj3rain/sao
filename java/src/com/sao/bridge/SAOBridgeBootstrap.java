package com.sao.bridge;

import com.sao.agent.SAOAgent;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.Collection;

/**
 * Exposes SAOBridge into the game's Lua environment once that environment is
 * stable, and re-exposes it whenever the engine replaces the environment
 * (world change / reload).
 *
 * Mechanism: reflect zombie.Lua.LuaManager's static fields (env, exposer,
 * loaded); require the same env/exposer/loaded-count across consecutive polls;
 * then exposer.setExposed + exposeLikeJava on the bridge class and rawset the
 * singleton as global "SAOJavaBridge".
 */
public final class SAOBridgeBootstrap {

    private static final String GLOBAL_NAME = "SAOJavaBridge";
    private static final int STABLE_POLLS = 4;
    private static final long POLL_MS = 500L;

    private static Thread watchdog;

    private SAOBridgeBootstrap() {
    }

    public static synchronized void start() {
        if (watchdog != null) {
            return;
        }
        watchdog = new Thread(SAOBridgeBootstrap::run, "SAO-LuaBridge");
        watchdog.setDaemon(true);
        watchdog.start();
        SAOAgent.log("Lua bridge watchdog started");
    }

    private static void run() {
        Class<?> luaManager = null;
        Object stableEnv = null;
        Object stableExposer = null;
        int stableLoaded = -1;
        int polls = 0;
        Object exposedInto = null;
        long lastFailLog = 0L;

        while (!Thread.currentThread().isInterrupted()) {
            try {
                Thread.sleep(POLL_MS);
                if (luaManager == null) {
                    luaManager = Class.forName(
                        "zombie.Lua.LuaManager", false, ClassLoader.getSystemClassLoader());
                }

                Object env = staticField(luaManager, "env");
                Object exposer = staticField(luaManager, "exposer");
                Object loaded = staticField(luaManager, "loaded");
                int loadedCount = loaded instanceof Collection<?> c ? c.size() : 0;

                if (env == null || exposer == null || loadedCount == 0) {
                    polls = 0;
                    continue;
                }
                if (env != stableEnv || exposer != stableExposer || loadedCount != stableLoaded) {
                    stableEnv = env;
                    stableExposer = exposer;
                    stableLoaded = loadedCount;
                    polls = 0;
                    continue;
                }
                polls++;
                if (polls < STABLE_POLLS) {
                    continue;
                }

                Object current = invoke(env, "rawget", new Class<?>[]{Object.class}, GLOBAL_NAME);
                if (env == exposedInto && current == SAOBridge.INSTANCE) {
                    continue;
                }

                invoke(exposer, "setExposed", new Class<?>[]{Class.class}, SAOBridge.class);
                invoke(exposer, "exposeLikeJava", new Class<?>[]{Class.class}, SAOBridge.class);
                invoke(env, "rawset", new Class<?>[]{Object.class, Object.class},
                    GLOBAL_NAME, SAOBridge.INSTANCE);

                Object check = invoke(env, "rawget", new Class<?>[]{Object.class}, GLOBAL_NAME);
                if (check == SAOBridge.INSTANCE) {
                    exposedInto = env;
                    SAOAgent.log("Lua bridge exposed global=" + GLOBAL_NAME);
                }
            } catch (InterruptedException interrupted) {
                Thread.currentThread().interrupt();
                return;
            } catch (Throwable throwable) {
                long now = System.currentTimeMillis();
                if (now - lastFailLog >= 5_000L) {
                    SAOAgent.log("bridge exposure attempt failed: " + throwable);
                    lastFailLog = now;
                }
                polls = 0;
            }
        }
    }

    private static Object staticField(Class<?> type, String name) throws Exception {
        Field field = type.getField(name);
        return field.get(null);
    }

    private static Object invoke(Object target, String name, Class<?>[] sig, Object... args)
        throws Exception {
        Method method = target.getClass().getMethod(name, sig);
        method.setAccessible(true);
        return method.invoke(target, args);
    }
}
