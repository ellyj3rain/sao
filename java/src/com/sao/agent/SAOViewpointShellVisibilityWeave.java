package com.sao.agent;

import com.sao.engine.SAOIsoPlayerShell;
import java.lang.instrument.Instrumentation;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import net.bytebuddy.agent.ByteBuddyAgent;
import net.bytebuddy.agent.builder.AgentBuilder;
import net.bytebuddy.asm.Advice;
import net.bytebuddy.description.method.MethodDescription;
import net.bytebuddy.matcher.ElementMatcher;
import net.bytebuddy.matcher.ElementMatchers;
import zombie.characters.IsoGameCharacter;
import zombie.iso.IsoMovingObject;

/** Keeps a staged SAO body out of the bundled Viewpoint character renderer. */
public final class SAOViewpointShellVisibilityWeave {
    public static final String CAPTURE_TARGET = "viewpoint.models.ModelCapture";
    public static final String RANGE_TARGET = "viewpoint.models.Characters";
    private static volatile boolean installed;
    private static volatile boolean captureTransformed;
    private static volatile boolean rangeTransformed;
    private static volatile String failure;

    private SAOViewpointShellVisibilityWeave() { }

    public static final class RangeEnter {
        private RangeEnter() { }

        // Characters.snapshot calls inRange for each modeled character before
        // its ground blob and fresh snapshot. A skipped range check is false.
        @Advice.OnMethodEnter(skipOn = Advice.OnNonDefaultValue.class)
        public static boolean skip(@Advice.Argument(0) IsoMovingObject character) {
            return character instanceof SAOIsoPlayerShell shell
                && (shell.removalPending || shell.getCurrentSquare() == null);
        }
    }

    public static final class CaptureEnter {
        private CaptureEnter() { }

        // ModelCapture.capture returns boolean. A non-default enter result skips
        // its body and returns false before it appends anything to ModelDraws.
        @Advice.OnMethodEnter(skipOn = Advice.OnNonDefaultValue.class)
        public static boolean skip(@Advice.Argument(2) IsoGameCharacter character) {
            return character instanceof SAOIsoPlayerShell shell
                && (shell.removalPending || shell.getCurrentSquare() == null);
        }
    }

    private static ElementMatcher.Junction<MethodDescription> captureMethod() {
        return ElementMatchers.named("capture")
            .and(ElementMatchers.isStatic())
            .and(ElementMatchers.returns(boolean.class))
            .and(ElementMatchers.takesArguments(9))
            .and(ElementMatchers.takesArgument(0, ElementMatchers.named("viewpoint.core.Frame")))
            .and(ElementMatchers.takesArgument(1, ElementMatchers.named(
                "zombie.core.skinnedmodel.model.ModelSlotRenderData")))
            .and(ElementMatchers.takesArgument(2, IsoGameCharacter.class))
            .and(ElementMatchers.takesArgument(3, boolean.class))
            .and(ElementMatchers.takesArgument(4, ElementMatchers.named(
                "viewpoint.models.ModelCapture$Pose")))
            .and(ElementMatchers.takesArgument(5, float.class))
            .and(ElementMatchers.takesArgument(6, float.class))
            .and(ElementMatchers.takesArgument(7, float.class))
            .and(ElementMatchers.takesArgument(8, float.class));
    }

    private static ElementMatcher.Junction<MethodDescription> rangeMethod() {
        return ElementMatchers.named("inRange")
            .and(ElementMatchers.isStatic())
            .and(ElementMatchers.returns(boolean.class))
            .and(ElementMatchers.takesArguments(4))
            .and(ElementMatchers.takesArgument(0, IsoMovingObject.class))
            .and(ElementMatchers.takesArgument(1, float.class))
            .and(ElementMatchers.takesArgument(2, float.class))
            .and(ElementMatchers.takesArgument(3, float.class));
    }

    /** Source patches register only after this exact client weave is ready. */
    public static boolean install() {
        try {
            return install(ByteBuddyAgent.install());
        } catch (Throwable error) {
            failed(error);
            return false;
        }
    }

    public static synchronized boolean install(Instrumentation instrumentation) {
        if (rangeTransformed && captureTransformed && failure == null) return true;
        if (installed || failure != null) return false;
        try {
            ClassLoader loader = SAOViewpointShellVisibilityWeave.class.getClassLoader();
            Class<?> captureTarget = Class.forName(CAPTURE_TARGET, false, loader);
            Class<?> rangeTarget = Class.forName(RANGE_TARGET, false, loader);
            Method capture = captureTarget.getDeclaredMethod("capture",
                Class.forName("viewpoint.core.Frame", false, loader),
                Class.forName("zombie.core.skinnedmodel.model.ModelSlotRenderData", false, loader),
                IsoGameCharacter.class, boolean.class,
                Class.forName("viewpoint.models.ModelCapture$Pose", false, loader),
                float.class, float.class, float.class, float.class);
            if (capture.getReturnType() != boolean.class
                    || !Modifier.isStatic(capture.getModifiers())) {
                throw new IllegalStateException("bundled Viewpoint capture signature changed");
            }
            Method inRange = rangeTarget.getDeclaredMethod("inRange",
                IsoMovingObject.class, float.class, float.class, float.class);
            if (inRange.getReturnType() != boolean.class
                    || !Modifier.isStatic(inRange.getModifiers())) {
                throw new IllegalStateException("bundled Viewpoint range signature changed");
            }
            if (!instrumentation.isModifiableClass(captureTarget)
                    || !instrumentation.isModifiableClass(rangeTarget)) {
                throw new IllegalStateException("bundled Viewpoint character classes are not modifiable");
            }
            new AgentBuilder.Default().disableClassFormatChanges()
                .with(AgentBuilder.RedefinitionStrategy.RETRANSFORMATION)
                .with(AgentBuilder.TypeStrategy.Default.REDEFINE)
                .with(new AgentBuilder.Listener.Adapter() {
                    @Override public void onTransformation(net.bytebuddy.description.type.TypeDescription type,
                            ClassLoader loader, net.bytebuddy.utility.JavaModule module, boolean loaded,
                            net.bytebuddy.dynamic.DynamicType dynamicType) {
                        if (CAPTURE_TARGET.equals(type.getName())) captureTransformed = true;
                        if (RANGE_TARGET.equals(type.getName())) rangeTransformed = true;
                    }
                    @Override public void onError(String name, ClassLoader loader,
                            net.bytebuddy.utility.JavaModule module, boolean loaded, Throwable error) {
                        if (CAPTURE_TARGET.equals(name) || RANGE_TARGET.equals(name)) failed(error);
                    }
                })
                .type(ElementMatchers.named(CAPTURE_TARGET).or(ElementMatchers.named(RANGE_TARGET)))
                .transform((builder, type, targetLoader, module, domain) ->
                    CAPTURE_TARGET.equals(type.getName())
                        ? builder.visit(Advice.to(CaptureEnter.class).on(captureMethod()))
                        : builder.visit(Advice.to(RangeEnter.class).on(rangeMethod())))
                .installOn(instrumentation);
            installed = true;
            if (!rangeTransformed && failure == null) instrumentation.retransformClasses(rangeTarget);
            if (!captureTransformed && failure == null) instrumentation.retransformClasses(captureTarget);
            if (!rangeTransformed || !captureTransformed || failure != null) {
                throw new IllegalStateException("bundled Viewpoint character advice did not transform");
            }
            SAOAgent.log("Viewpoint staged-body capture weave " + report());
            return true;
        } catch (Throwable error) {
            failed(error);
            return false;
        }
    }

    private static synchronized void failed(Throwable error) {
        if (failure != null) return;
        failure = String.valueOf(error);
        SAOAgent.log("Viewpoint staged-body capture weave failed: " + failure);
    }

    public static String report() {
        return failure == null ? rangeTransformed && captureTransformed ? "ready"
            : installed ? "waiting" : "not-installed"
            : "failed:" + failure;
    }
}
