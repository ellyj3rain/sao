package com.sao.agent;

import java.lang.instrument.Instrumentation;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;

import net.bytebuddy.agent.ByteBuddyAgent;
import net.bytebuddy.agent.builder.AgentBuilder;
import net.bytebuddy.asm.Advice;
import net.bytebuddy.matcher.ElementMatchers;

/**
 * Records the renderer that actually completed during SpriteRenderer.postRender.
 * The native capture agent starts and ends the same render-thread slot around
 * postRender; a later game-thread View.enabled value cannot label old pixels.
 */
public final class SAOViewpointFrameTelemetry {
    private static final String TARGET = "viewpoint.SceneDrawer";
    private static final ThreadLocal<String> FRAME = new ThreadLocal<>();
    private static volatile boolean installed;
    private static volatile boolean transformed;
    private static volatile String failure;

    private SAOViewpointFrameTelemetry() { }

    public static final class RenderExit {
        private RenderExit() { }

        @Advice.OnMethodExit(onThrowable = Throwable.class)
        public static void exit(@Advice.FieldValue("failed") boolean failed,
                                @Advice.Thrown Throwable thrown) {
            String mode = failed || thrown != null ? "unavailable"
                : viewpoint.render.WorldRenderer.freeCamera ? "viewpoint-free"
                : viewpoint.render.WorldRenderer.handFromPlayer ? "viewpoint-third"
                : "viewpoint-first";
            sceneRendered(mode);
        }
    }

    /** The capture agent invokes this on the render thread at postRender entry. */
    public static void frameStarted() {
        FRAME.set("isometric");
    }

    private static void sceneRendered(String mode) {
        String earlier = FRAME.get();
        if (earlier == null) return;
        FRAME.set("isometric".equals(earlier) ? mode
            : earlier.equals(mode) ? earlier : "unavailable");
    }

    /**
     * Returns null when this exact vendor hook is absent. A scene failure or
     * two differing scene draws within one swap return unavailable.
     */
    public static String frameCompleted() {
        String mode = FRAME.get();
        FRAME.remove();
        return installed && transformed && failure == null ? mode : null;
    }

    public static boolean install() {
        try {
            return install(ByteBuddyAgent.install());
        } catch (Throwable error) {
            failed(error);
            return false;
        }
    }

    public static synchronized boolean install(Instrumentation instrumentation) {
        if (installed && transformed && failure == null) return true;
        if (installed || failure != null) return false;
        try {
            Class<?> target = Class.forName(TARGET, false,
                SAOViewpointFrameTelemetry.class.getClassLoader());
            Method render = target.getDeclaredMethod("render");
            if (render.getReturnType() != void.class || Modifier.isStatic(render.getModifiers())
                    || !Modifier.isPublic(render.getModifiers())) {
                throw new IllegalStateException("bundled Viewpoint SceneDrawer.render signature changed");
            }
            target.getDeclaredField("failed");
            if (!instrumentation.isModifiableClass(target)) {
                throw new IllegalStateException("bundled Viewpoint SceneDrawer is not modifiable");
            }
            new AgentBuilder.Default().disableClassFormatChanges()
                .with(AgentBuilder.RedefinitionStrategy.RETRANSFORMATION)
                .with(AgentBuilder.TypeStrategy.Default.REDEFINE)
                .with(new AgentBuilder.Listener.Adapter() {
                    @Override public void onTransformation(
                            net.bytebuddy.description.type.TypeDescription type, ClassLoader loader,
                            net.bytebuddy.utility.JavaModule module, boolean loaded,
                            net.bytebuddy.dynamic.DynamicType dynamicType) {
                        if (TARGET.equals(type.getName())) transformed = true;
                    }
                    @Override public void onError(String name, ClassLoader loader,
                            net.bytebuddy.utility.JavaModule module, boolean loaded, Throwable error) {
                        if (TARGET.equals(name)) failed(error);
                    }
                })
                .type(ElementMatchers.named(TARGET))
                .transform((builder, type, loader, module, domain) -> builder.visit(
                    Advice.to(RenderExit.class).on(ElementMatchers.named("render")
                        .and(ElementMatchers.isPublic())
                        .and(ElementMatchers.takesArguments(0))
                        .and(ElementMatchers.returns(void.class)))))
                .installOn(instrumentation);
            installed = true;
            if (!transformed && failure == null) instrumentation.retransformClasses(target);
            if (!transformed || failure != null) {
                throw new IllegalStateException("bundled Viewpoint SceneDrawer advice did not transform");
            }
            SAOAgent.log("Viewpoint frame telemetry " + report());
            return true;
        } catch (Throwable error) {
            failed(error);
            return false;
        }
    }

    private static synchronized void failed(Throwable error) {
        if (failure != null) return;
        failure = String.valueOf(error);
        SAOAgent.log("Viewpoint frame telemetry failed: " + failure);
    }

    public static String report() {
        return failure == null ? installed && transformed ? "ready"
            : installed ? "waiting" : "not-installed" : "failed:" + failure;
    }
}
