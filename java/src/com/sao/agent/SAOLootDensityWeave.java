package com.sao.agent;

import com.sao.engine.SAOWorldSources;
import java.lang.instrument.Instrumentation;
import net.bytebuddy.ByteBuddy;
import net.bytebuddy.agent.ByteBuddyAgent;
import net.bytebuddy.agent.builder.AgentBuilder;
import net.bytebuddy.asm.Advice;
import net.bytebuddy.description.type.TypeDescription;
import net.bytebuddy.dynamic.ClassFileLocator;
import net.bytebuddy.matcher.ElementMatchers;
import net.bytebuddy.pool.TypePool;
import zombie.characters.IsoPlayer;

/**
 * Makes one narrow native correction while R10a hydrates distant ground.
 *
 * ItemPickerJava normally caches IsoPlayer.getInstance() and its zombie-density
 * calculation consequently samples the player's current square. That is right
 * when the player is opening the container beside them and wrong when PZ is
 * populating an engine-loaded container elsewhere in the county. The same
 * method already falls back to the container's source square when its private
 * player field is null. During SAO's bounded hydration transaction only, this
 * advice exposes that native fallback and then restores the exact prior field.
 * No distribution, chance, item, seed, or result is supplied by SAO.
 */
public final class SAOLootDensityWeave {
    public static final String TARGET = "zombie.inventory.ItemPickerJava";
    public static final String METHOD = "getZombieDensityFactor";

    private static volatile boolean installed;
    private static volatile boolean transformed;
    private static volatile boolean targetWasLoaded;
    private static volatile String error;

    private SAOLootDensityWeave() {
    }

    public static final class DensityAdvice {
        private DensityAdvice() {
        }

        @Advice.OnMethodEnter
        public static void enter(
                @Advice.FieldValue(value = "player", readOnly = false) IsoPlayer current,
                @Advice.Local("saoPriorPlayer") IsoPlayer prior,
                @Advice.Local("saoHydration") boolean hydration) {
            hydration = SAOWorldSources.isHydrating();
            if (hydration) {
                prior = current;
                current = null;
            }
        }

        @Advice.OnMethodExit(onThrowable = Throwable.class)
        public static void exit(
                @Advice.FieldValue(value = "player", readOnly = false) IsoPlayer current,
                @Advice.Local("saoPriorPlayer") IsoPlayer prior,
                @Advice.Local("saoHydration") boolean hydration) {
            if (hydration) {
                current = prior;
            }
        }
    }

    public static void install() {
        try {
            install(ByteBuddyAgent.install());
        } catch (Throwable throwable) {
            error = String.valueOf(throwable);
            SAOAgent.log("world sources: loot-density self-attach unavailable ("
                + throwable + "); distant hydration is disabled");
        }
    }

    public static synchronized void install(Instrumentation instrumentation) {
        if (installed) {
            return;
        }
        try {
            boolean loaded;
            try {
                Class.forName(TARGET, false, ClassLoader.getSystemClassLoader());
                loaded = true;
            } catch (ClassNotFoundException notYet) {
                loaded = false;
            }
            targetWasLoaded = loaded;

            AgentBuilder.Listener listener = new AgentBuilder.Listener.Adapter() {
                @Override
                public void onTransformation(TypeDescription typeDescription,
                        ClassLoader classLoader, net.bytebuddy.utility.JavaModule module,
                        boolean loaded, net.bytebuddy.dynamic.DynamicType dynamicType) {
                    transformed = true;
                }

                @Override
                public void onError(String typeName, ClassLoader classLoader,
                        net.bytebuddy.utility.JavaModule module, boolean loaded,
                        Throwable throwable) {
                    if (TARGET.equals(typeName)) {
                        error = String.valueOf(throwable);
                    }
                }
            };

            new AgentBuilder.Default()
                .disableClassFormatChanges()
                .with(AgentBuilder.RedefinitionStrategy.RETRANSFORMATION)
                .with(AgentBuilder.TypeStrategy.Default.REDEFINE)
                .with(listener)
                .type(ElementMatchers.named(TARGET))
                .transform((builder, type, loader, module, domain) ->
                    builder.visit(Advice.to(DensityAdvice.class)
                        .on(ElementMatchers.named(METHOD))))
                .installOn(instrumentation);
            installed = true;

            // Hydration must fail closed before it can populate a container.
            // Loading here ensures the first readiness check has a definite
            // transformation result rather than "the advice may apply later".
            Class.forName(TARGET, true, ClassLoader.getSystemClassLoader());
            SAOAgent.log("world sources: loot density woven into " + TARGET + "." + METHOD
                + (loaded ? " (retransformed, already loaded)" : " (loaded after install)"));
        } catch (Throwable throwable) {
            error = String.valueOf(throwable);
            SAOAgent.log("world sources: loot-density weave failed (" + throwable
                + "); distant hydration is disabled");
        }
    }

    public static boolean isReady() {
        return installed && transformed && error == null;
    }

    public static String report() {
        String failure = error;
        if (failure != null) {
            return "weave=FAILED|" + failure;
        }
        return "weave=" + (isReady() ? "ready" : installed ? "waiting" : "not-installed")
            + "|target=" + (targetWasLoaded ? "retransformed" : "loaded-after-install");
    }

    public static byte[] weave(byte[] original) throws Exception {
        ClassFileLocator locator = new ClassFileLocator.Compound(
            ClassFileLocator.Simple.of(TARGET, original),
            ClassFileLocator.ForClassLoader.ofSystemLoader(),
            ClassFileLocator.ForClassLoader.of(SAOLootDensityWeave.class.getClassLoader()));
        TypePool pool = TypePool.Default.of(locator);
        TypeDescription target = pool.describe(TARGET).resolve();
        return new ByteBuddy()
            .redefine(target, locator)
            .visit(Advice.to(DensityAdvice.class).on(ElementMatchers.named(METHOD)))
            .make()
            .getBytes();
    }
}
