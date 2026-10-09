package com.sao.agent;

import com.sao.engine.SAOWorldSoundPulses;
import java.lang.instrument.Instrumentation;
import net.bytebuddy.agent.builder.AgentBuilder;
import net.bytebuddy.asm.Advice;
import net.bytebuddy.matcher.ElementMatchers;

/** Marks a WorldSound only after the installed Callout() actually emitted it. */
public final class SAOCalloutWeave {
    public static final String TARGET = "zombie.characters.IsoGameCharacter";
    private static volatile boolean installed;
    private static volatile boolean transformed;
    private static volatile String failure;

    private SAOCalloutWeave() {}

    public static final class CalloutFrame {
        @Advice.OnMethodEnter
        public static long enter(@Advice.This Object body) {
            return SAOWorldSoundPulses.beforeNativeCallout(body);
        }

        @Advice.OnMethodExit(onThrowable = Throwable.class)
        public static void exit(@Advice.This Object body, @Advice.Enter long before,
                @Advice.Thrown Throwable thrown) {
            if (thrown == null) SAOWorldSoundPulses.completedNativeCallout(body, before);
        }
    }

    public static synchronized void install(Instrumentation instrumentation) {
        if (installed) return;
        try {
            new AgentBuilder.Default().disableClassFormatChanges()
                .with(AgentBuilder.RedefinitionStrategy.RETRANSFORMATION)
                .with(new AgentBuilder.Listener.Adapter() {
                    @Override public void onTransformation(net.bytebuddy.description.type.TypeDescription type,
                            ClassLoader loader, net.bytebuddy.utility.JavaModule module, boolean loaded,
                            net.bytebuddy.dynamic.DynamicType dynamicType) {
                        if (TARGET.equals(type.getName())) transformed = true;
                    }
                    @Override public void onError(String name, ClassLoader loader,
                            net.bytebuddy.utility.JavaModule module, boolean loaded, Throwable error) {
                        if (TARGET.equals(name)) failure = String.valueOf(error);
                    }
                })
                .type(ElementMatchers.named(TARGET))
                .transform((builder, type, loader, module, domain) -> builder.visit(
                    Advice.to(CalloutFrame.class).on(ElementMatchers.named("Callout")
                        .and(ElementMatchers.takesArguments(0))
                        .and(ElementMatchers.returns(void.class)))))
                .installOn(instrumentation);
            installed = true;
            for (Class<?> type : instrumentation.getAllLoadedClasses()) {
                if (!TARGET.equals(type.getName())) continue;
                if (!instrumentation.isModifiableClass(type)) {
                    failure = "installed native Callout class is not modifiable";
                    break;
                }
                instrumentation.retransformClasses(type);
            }
            SAOAgent.log("native callout weave " + report());
        } catch (Throwable error) {
            failure = String.valueOf(error);
            SAOAgent.log("native callout weave failed: " + failure);
        }
    }

    public static String report() {
        return failure == null ? transformed ? "ready" : installed ? "waiting" : "not-installed"
            : "failed:" + failure;
    }
}
