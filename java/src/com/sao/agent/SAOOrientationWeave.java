package com.sao.agent;

import com.sao.engine.SAOWorldSoundPulses;
import java.lang.instrument.Instrumentation;
import net.bytebuddy.agent.ByteBuddyAgent;
import net.bytebuddy.agent.builder.AgentBuilder;
import net.bytebuddy.asm.Advice;
import net.bytebuddy.matcher.ElementMatchers;

/** One exact native pulse seam, including already loaded classes and pool reuse. */
public final class SAOOrientationWeave {
    private static volatile boolean installed;
    private static volatile boolean transformed;
    private static volatile String failure;
    private static volatile Instrumentation nativeInstrumentation;
    private static volatile boolean sensorReconciled;
    private static boolean transformationLogged;
    private static boolean failureLogged;
    public static final String TARGET = "zombie.WorldSoundManager$WorldSound";
    private SAOOrientationWeave() {}

    public static final class PulseExit {
        @Advice.OnMethodExit
        public static void exit(@Advice.This Object sound) { SAOWorldSoundPulses.initialized(sound); }
    }

    public static void install() {
        try { install(ByteBuddyAgent.install()); }
        catch (Throwable error) { failed("attach", null, false, error); }
    }

    private static String loaderName(ClassLoader loader) {
        return loader == null ? "bootstrap" : loader.getClass().getName() + "@"
            + Integer.toHexString(System.identityHashCode(loader));
    }

    private static synchronized void failed(String phase, ClassLoader loader, boolean loaded, Throwable error) {
        String detail = String.valueOf(error);
        if (detail.length() > 1024) detail = detail.substring(0, 1024);
        failure = detail;
        if (failureLogged) return;
        failureLogged = true;
        SAOAgent.log("orientation sound weave failed class=" + TARGET + " phase=" + phase
            + " loaded=" + loaded + " loader=" + loaderName(loader) + " error=" + detail);
    }

    private static synchronized void transformed(ClassLoader loader, boolean loaded) {
        transformed = true;
        if (transformationLogged) return;
        transformationLogged = true;
        SAOAgent.log("orientation sound weave transformed class=" + TARGET + " loaded=" + loaded
            + " loader=" + loaderName(loader));
    }

    public static synchronized void install(Instrumentation instrumentation) {
        if (installed) return;
        // Prevent first-use bootstrap class loading from recurring in a transformer.
        java.util.concurrent.ThreadLocalRandom.current().nextInt();
        try {
            new AgentBuilder.Default().disableClassFormatChanges()
                .with(AgentBuilder.RedefinitionStrategy.RETRANSFORMATION)
                .with(new AgentBuilder.Listener.Adapter() {
                    @Override public void onTransformation(net.bytebuddy.description.type.TypeDescription type,
                            ClassLoader loader, net.bytebuddy.utility.JavaModule module, boolean loaded,
                            net.bytebuddy.dynamic.DynamicType dynamicType) {
                        if (TARGET.equals(type.getName())) transformed(loader, loaded);
                    }
                    @Override public void onError(String name, ClassLoader loader,
                            net.bytebuddy.utility.JavaModule module, boolean loaded, Throwable error) {
                        if (TARGET.equals(name)) failed("transform", loader, loaded, error);
                    }
                })
                .type(ElementMatchers.named(TARGET))
                .transform((builder, type, loader, module, domain) -> builder.visit(
                    Advice.to(PulseExit.class).on(ElementMatchers.named("init").and(
                        ElementMatchers.takesArguments(Object.class, int.class, int.class, int.class,
                            int.class, int.class, float.class, float.class, short.class)))))
                .installOn(instrumentation);
            nativeInstrumentation = instrumentation;
            installed = true;
            // installOn holds Byte Buddy's circularity lock while taking its
            // loaded-class snapshot. A native dependency loaded after that
            // snapshot is deliberately skipped by the transformer and absent
            // from the first retransformation pass. Reconcile after the lock
            // has been released; do not manufacture tokens for missed sounds.
            for (Class<?> type : instrumentation.getAllLoadedClasses()) {
                if (!TARGET.equals(type.getName())) continue;
                if (!instrumentation.isModifiableClass(type)) {
                    failed("reconcile", type.getClassLoader(), true,
                        new IllegalStateException("native sound class is not modifiable"));
                    continue;
                }
                try { instrumentation.retransformClasses(type); }
                catch (Throwable error) { failed("reconcile", type.getClassLoader(), true, error); }
            }
            SAOAgent.log("orientation sound weave registered class=" + TARGET + " " + report());
        } catch (Throwable error) { failed("install", null, false, error); }
    }

    /** Called by the actual scanner after attachment is established. Later mod
     * transformers can resolve WorldSound recursively after premain's complete
     * snapshot. Instrumentation skips those nested loads; an early reconciliation
     * cannot cover them. This ordinary execution boundary is outside that load
     * callback, and the exact target is checked once, never once per sound. */
    public static void atNativeSensorBoundary() {
        if (transformed || sensorReconciled) return;
        reconcileAtSensorBoundary();
    }

    private static synchronized void reconcileAtSensorBoundary() {
        if (transformed || sensorReconciled) return;
        sensorReconciled = true;
        ClassLoader loader = SAOOrientationWeave.class.getClassLoader();
        try {
            Instrumentation instrumentation = nativeInstrumentation;
            if (!installed || instrumentation == null)
                throw new IllegalStateException("sound transformer was not installed before native sensor");
            Class<?> target = Class.forName(TARGET, false, loader);
            loader = target.getClassLoader();
            boolean modifiable = instrumentation.isModifiableClass(target);
            SAOAgent.log("orientation sound weave sensor reconciliation class=" + TARGET
                + " loaded=true modifiable=" + modifiable + " loader=" + loaderName(loader));
            if (!modifiable) throw new IllegalStateException("native sound class is not modifiable");
            if (!transformed) instrumentation.retransformClasses(target);
            if (!transformed)
                throw new IllegalStateException("native sensor reconciliation returned without transforming sound class");
            // Existing objects are intentionally untouched: a missed occurrence
            // has no trustworthy init receipt. Only subsequent native init calls
            // establish new tokens, including a real reuse of a pooled object.
        } catch (Throwable error) { failed("native-sensor", loader, true, error); }
    }
    public static String report() {
        return failure == null ? "sound-pulses=" + (transformed ? "ready" : installed ? "waiting" : "not-installed")
            : "sound-pulses=failed:" + failure;
    }
}
