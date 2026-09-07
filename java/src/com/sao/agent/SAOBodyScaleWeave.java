package com.sao.agent;

import java.lang.instrument.Instrumentation;
import net.bytebuddy.ByteBuddy;
import net.bytebuddy.agent.ByteBuddyAgent;
import net.bytebuddy.agent.builder.AgentBuilder;
import net.bytebuddy.asm.Advice;
import net.bytebuddy.description.type.TypeDescription;
import net.bytebuddy.dynamic.ClassFileLocator;
import net.bytebuddy.matcher.ElementMatchers;
import net.bytebuddy.pool.TypePool;

/**
 * [C29] Weaves {@link SAOBodyScale#apply(Object)} into the exit of
 * AnimationPlayer.updateModelTransformsInternal, the method that builds
 * a body's per-bone model transforms for the renderer.
 *
 * Done with Byte Buddy advice rather than the constant-pool surgery of
 * the melee patch: inserting a call moves every offset after it, and
 * the stack-map frames of a class-file-69 method with it, which is
 * exactly what an advice weaver exists to get right. Byte Buddy ships
 * inside ZombieBuddy, on the classpath at compile and run time, and is
 * what ZombieBuddy itself patches this build with - the same proven
 * path Main already takes to self-attach for the melee patch.
 *
 * Two entry points: {@link #install(Instrumentation)} for the running
 * game (retransforms the class if it is already loaded), and
 * {@link #weave(byte[])} for Border 104, which weaves the installed
 * jar's real class bytes offline and checks the result.
 */
public final class SAOBodyScaleWeave {
    public static final String TARGET = "zombie.core.skinnedmodel.animation.AnimationPlayer";
    public static final String METHOD = "updateModelTransformsInternal";

    private static volatile boolean installed;
    private static volatile boolean targetWasLoaded;
    private static volatile String error;

    private SAOBodyScaleWeave() {
    }

    /** The advice: after the model transforms are built, scale ours.
     *  Inlined into the game's class; it may reference only what the
     *  system class loader can resolve, which SAO's jar is once
     *  ZombieBuddy has added it. */
    public static final class Exit {
        private Exit() {
        }

        @Advice.OnMethodExit
        public static void exit(@Advice.This Object self) {
            SAOBodyScale.apply(self);
        }
    }

    /** Self-attach (the ZombieBuddy load path) and install. */
    public static void install() {
        try {
            install(ByteBuddyAgent.install());
        } catch (Throwable throwable) {
            error = String.valueOf(throwable);
            SAOAgent.log("body scale: self-attach unavailable (" + throwable
                + "); bodies keep their size");
        }
    }

    public static synchronized void install(Instrumentation instrumentation) {
        if (installed) {
            return;
        }
        try {
            boolean loaded = false;
            try {
                Class.forName(TARGET, false, ClassLoader.getSystemClassLoader());
                loaded = true;
            } catch (ClassNotFoundException notYet) {
                loaded = false;
            }
            targetWasLoaded = loaded;
            new AgentBuilder.Default()
                .disableClassFormatChanges()
                .with(AgentBuilder.RedefinitionStrategy.RETRANSFORMATION)
                .with(AgentBuilder.TypeStrategy.Default.REDEFINE)
                .type(ElementMatchers.named(TARGET))
                .transform((builder, type, loader, module, domain) ->
                    builder.visit(Advice.to(Exit.class).on(ElementMatchers.named(METHOD))))
                .installOn(instrumentation);
            installed = true;
            SAOAgent.log("body scale woven into " + TARGET + "." + METHOD
                + (loaded ? " (retransformed, already loaded)" : " (applies on first load)"));
        } catch (Throwable throwable) {
            error = String.valueOf(throwable);
            SAOAgent.log("body scale: weave failed (" + throwable + "); bodies keep their size");
        }
    }

    /** Weave the advice into the given class bytes of the target, off
     *  the game, for the border. The advice class is located through
     *  this jar's loader; the target through the bytes handed in plus
     *  the system loader for everything it references. */
    public static byte[] weave(byte[] original) throws Exception {
        ClassFileLocator locator = new ClassFileLocator.Compound(
            ClassFileLocator.Simple.of(TARGET, original),
            ClassFileLocator.ForClassLoader.ofSystemLoader(),
            ClassFileLocator.ForClassLoader.of(SAOBodyScaleWeave.class.getClassLoader()));
        TypePool pool = TypePool.Default.of(locator);
        TypeDescription target = pool.describe(TARGET).resolve();
        return new ByteBuddy()
            .redefine(target, locator)
            .visit(Advice.to(Exit.class).on(ElementMatchers.named(METHOD)))
            .make()
            .getBytes();
    }

    /** "weave=installed|target=loaded" or the error. */
    public static String report() {
        String failure = error;
        if (failure != null) {
            return "weave=FAILED|" + failure;
        }
        return "weave=" + (installed ? "installed" : "not-installed")
            + "|target=" + (targetWasLoaded ? "retransformed" : "on-first-load");
    }
}
