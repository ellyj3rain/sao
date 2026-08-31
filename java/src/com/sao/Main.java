package com.sao;

import com.sao.agent.SAOAgent;
import com.sao.agent.SAOCombatGate;
import com.sao.agent.SAOMeleeTransformer;
import com.sao.bridge.SAOBridgeBootstrap;
import java.lang.instrument.Instrumentation;

/**
 * ZombieBuddy entry point. ZB reads javaJarFile/javaPkgName from mod.info,
 * adds the jar to the classpath in-process, and invokes <pkg>.Main.main().
 * This is the shipping load path: no agent, no launcher, no env vars.
 *
 * The melee-callback patch needs Instrumentation. Under an agent launch,
 * premain provided it; here we self-attach through ByteBuddyAgent — which
 * ZombieBuddy bundles and demonstrably uses for its own transformations under
 * normal launches, so the acquisition path is proven in this environment. If
 * it fails, the combat gate simply stays not-ready and combat refuses to
 * start; everything else is unaffected.
 */
public final class Main {

    private Main() {
    }

    public static void main(String[] args) {
        SAOAgent.log("loaded via ZombieBuddy java-mod path");
        try {
            Class.forName("zombie.characters.IsoPlayer", false, ClassLoader.getSystemClassLoader());
        } catch (ClassNotFoundException exception) {
            SAOAgent.log("ERROR IsoPlayer not loadable from ZB context: " + exception);
            return;
        }

        if (meleePatchUnnecessary()) {
            // 42.20.4+ shape ([A24]): the OnAnimEvent_* callbacks are
            // gone and every local-player gate is virtual - the shell
            // override governs natively. The gate is genuinely ready
            // WITHOUT instrumentation; no transformer needed at all.
            SAOCombatGate.markPatchReady(SAOMeleeTransformer.EXPECTED_PATCH_COUNT);
            SAOAgent.log("melee gates are virtual on this build; no patch needed");
        } else if (!SAOCombatGate.isPatchReady()) {
            installMeleePatch();
        }
        SAOBridgeBootstrap.start();
    }

    /** True when SwipeStatePlayer no longer carries the OnAnimEvent_*
     * callbacks the patch targets - the 42.20.4+ virtual-gate shape. */
    private static boolean meleePatchUnnecessary() {
        try {
            Class<?> swipe = Class.forName("zombie.ai.states.SwipeStatePlayer",
                false, ClassLoader.getSystemClassLoader());
            for (java.lang.reflect.Method method : swipe.getDeclaredMethods()) {
                String name = method.getName();
                if ("OnAnimEvent_AttackCollisionCheck".equals(name)
                    || "OnAnimEvent_PlaySwingSound".equals(name)
                    || "OnAnimEvent_PlaySwingSoundAlways".equals(name)) {
                    return false;
                }
            }
            return true;
        } catch (Throwable throwable) {
            return false;
        }
    }

    private static void installMeleePatch() {
        try {
            Instrumentation instrumentation = net.bytebuddy.agent.ByteBuddyAgent.install();
            instrumentation.addTransformer(new SAOMeleeTransformer(), true);
            SAOAgent.log("melee transformer installed via self-attach");
            try {
                Class<?> swipe = Class.forName(
                    "zombie.ai.states.SwipeStatePlayer", false,
                    ClassLoader.getSystemClassLoader());
                // Already loaded: retransform so the patch applies now.
                if (instrumentation.isModifiableClass(swipe)) {
                    instrumentation.retransformClasses(swipe);
                    SAOAgent.log("SwipeStatePlayer retransformed; patch calls="
                        + SAOCombatGate.getPatchedCallCount());
                }
            } catch (ClassNotFoundException notLoadedYet) {
                SAOAgent.log("SwipeStatePlayer not loaded yet; patch applies on first load");
            }
        } catch (Throwable throwable) {
            SAOAgent.log("self-attach unavailable (" + throwable
                + "); combat stays gated until an agent launch");
        }
    }
}
