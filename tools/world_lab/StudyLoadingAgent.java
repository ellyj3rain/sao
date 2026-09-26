import java.lang.instrument.Instrumentation;
import net.bytebuddy.agent.builder.AgentBuilder;
import net.bytebuddy.asm.Advice;
import net.bytebuddy.asm.MemberSubstitution;
import net.bytebuddy.implementation.bytecode.assign.Assigner;
import net.bytebuddy.matcher.ElementMatchers;
import net.bytebuddy.description.method.MethodDescription;
import net.bytebuddy.pool.TypePool;

/** Automates the final loading-screen click in an explicitly launched study JVM.
 * GameLoadingState.update retains its native readiness and streaming checks.
 * Observer hooks are enabled only by the explicitly isolated observer property.
 */
public final class StudyLoadingAgent {
    public static void premain(String argument, Instrumentation instrumentation) {
        if (!"isolated-study".equals(argument)) throw new IllegalArgumentException("study argument required");
        // ClassGraph's concurrent scan reaches ConcurrentHashMap.fullAddCount.
        // Resolve its lazy bootstrap dependency before our transformers can be
        // entered during that first class load (native26: ClassCircularityError).
        java.util.concurrent.ThreadLocalRandom.current();
        if (Boolean.getBoolean("study.observer")) installObserver(instrumentation);
        new AgentBuilder.Default()
            .disableClassFormatChanges()
            .with(AgentBuilder.RedefinitionStrategy.RETRANSFORMATION)
            .with(AgentBuilder.Listener.StreamWriting.toSystemError().withErrorsOnly())
            .type(ElementMatchers.named("zombie.GameWindow"))
            .transform((builder, type, loader, module, domain) -> builder.visit(
                Advice.to(SaveReturn.class).on(ElementMatchers.named("save")
                    .and(ElementMatchers.takesArguments(boolean.class)))))
            .installOn(instrumentation);
        new AgentBuilder.Default()
            .disableClassFormatChanges()
            .with(AgentBuilder.RedefinitionStrategy.RETRANSFORMATION)
            .with(AgentBuilder.Listener.StreamWriting.toSystemError().withErrorsOnly())
            .type(ElementMatchers.named("zombie.gameStates.GameLoadingState"))
            .transform((builder, type, loader, module, domain) -> builder.visit(
                Advice.to(ContinueLoading.class).on(ElementMatchers.named("update"))))
            .installOn(instrumentation);
        if (!Boolean.getBoolean("study.showWindow")) new AgentBuilder.Default()
            .disableClassFormatChanges()
            .with(AgentBuilder.RedefinitionStrategy.RETRANSFORMATION)
            .with(AgentBuilder.Listener.StreamWriting.toSystemError().withErrorsOnly())
            .type(ElementMatchers.named("org.lwjglx.opengl.Display"))
            .transform((builder, type, loader, module, domain) -> builder.visit(
                MemberSubstitution.relaxed().method(ElementMatchers.named("glfwShowWindow")
                    .or(ElementMatchers.named("glfwFocusWindow")))
                    .stub().on(ElementMatchers.any())))
            .installOn(instrumentation);
        StudyViewCapture.install(instrumentation);
        finishHooks(instrumentation);
        System.out.println("[StudyLaunch] loading click automation installed");
    }

    private static void finishHooks(Instrumentation instrumentation) {
        // A transform's metadata resolution can load another engine type while
        // ByteBuddy suppresses recursive transformation. First finish loading the
        // complete hook cohort without initialization, then transform it again
        // outside any nested class-loading callback.
        var names = new java.util.LinkedHashSet<String>();
        java.util.Collections.addAll(names, "zombie.GameWindow", "zombie.gameStates.GameLoadingState",
            "org.lwjglx.opengl.Display");
        if (Boolean.getBoolean("study.observer")) java.util.Collections.addAll(names,
            "zombie.iso.IsoCell", "zombie.characters.IsoPlayer", "zombie.Lua.LuaEventManager",
            "zombie.iso.IsoWorld", "zombie.savefile.PlayerDB", "zombie.iso.IsoCamera",
            "zombie.iso.IsoCamera$FrameState", "zombie.iso.IsoChunkMap", "zombie.ui.UI3DModel",
            "zombie.ui.UIManager", "zombie.inventory.ItemPickerJava", "zombie.iso.objects.IsoTree");
        if (System.getProperty("study.viewDirectory") != null) java.util.Collections.addAll(names,
            "zombie.core.sprite.SpriteRenderState", "zombie.core.SpriteRenderer", "zombie.core.Core");
        try {
            Class<?>[] targets = new Class<?>[names.size()];
            int next = 0;
            for (String name : names)
                targets[next++] = Class.forName(name, false, ClassLoader.getSystemClassLoader());
            instrumentation.retransformClasses(targets);
            System.out.println("[StudyLaunch] native hook cohort reconciled classes=" + targets.length);
        } catch (ReflectiveOperationException | java.lang.instrument.UnmodifiableClassException failure) {
            throw new IllegalStateException("cannot reconcile native study hooks", failure);
        }
    }

    private static AgentBuilder observerBuilder() {
        return new AgentBuilder.Default().disableClassFormatChanges()
            .with(AgentBuilder.RedefinitionStrategy.RETRANSFORMATION)
            .with(AgentBuilder.Listener.StreamWriting.toSystemError().withErrorsOnly());
    }

    private static MethodDescription observerMethod(String name) {
        // Parse class bytes rather than resolving StudyObserver's native method
        // signatures while one of those engine classes is being transformed.
        return TypePool.Default.of(StudyLoadingAgent.class.getClassLoader()).describe("StudyObserver")
            .resolve().getDeclaredMethods().filter(ElementMatchers.named(name)).getOnly();
    }

    private static void installObserver(Instrumentation instrumentation) {
        if (!instrumentation.isRetransformClassesSupported())
            throw new IllegalStateException("study observer agent requires Can-Retransform-Classes: true");
        // Register cell/player advice before reflecting on any helper with native
        // signatures: reflection may resolve IsoPlayer before its first use.
        observerBuilder().type(ElementMatchers.named("zombie.iso.IsoCell"))
            .transform((builder, type, loader, module, domain) -> {
                    var streaming = observerMethod("deadForStreaming");
                    return builder.visit(MemberSubstitution.relaxed().method(ElementMatchers.named("isDead")
                        .and(ElementMatchers.isDeclaredBy(ElementMatchers.named("zombie.characters.IsoGameCharacter")))
                        .and(ElementMatchers.takesArguments(0)).and(ElementMatchers.returns(boolean.class)))
                        .replaceWith(streaming).on(ElementMatchers.named("updateInternal")));
            })
            .installOn(instrumentation);
        observerBuilder().type(ElementMatchers.named("zombie.characters.IsoPlayer"))
            .transform((builder, type, loader, module, domain) -> builder.visit(
                Advice.to(HostScheduling.class).on(ElementMatchers.named("allPlayersDead"))))
            .installOn(instrumentation);
        observerBuilder().type(ElementMatchers.named("zombie.Lua.LuaEventManager"))
            .transform((builder, type, loader, module, domain) -> builder.visit(
                Advice.to(ObserverBirth.class).on(ElementMatchers.named("triggerEvent")
                    .and(ElementMatchers.takesArguments(String.class, Object.class, Object.class)))))
            .installOn(instrumentation);
        observerBuilder().type(ElementMatchers.named("zombie.iso.IsoWorld"))
            .transform((builder, type, loader, module, domain) -> builder.visit(
                Advice.to(ObserverWorld.class).on(ElementMatchers.named("init").and(ElementMatchers.takesArguments(0)))))
            .installOn(instrumentation);
        observerBuilder().type(ElementMatchers.named("zombie.GameWindow"))
            .transform((builder, type, loader, module, domain) -> builder.visit(
                Advice.to(ObserverPoll.class).on(ElementMatchers.named("logic"))))
            .installOn(instrumentation);
        observerBuilder().type(ElementMatchers.named("zombie.savefile.PlayerDB"))
            .transform((builder, type, loader, module, domain) -> builder.visit(
                Advice.to(ObserverSave.class).on(ElementMatchers.named("savePlayerAsync"))))
            .installOn(instrumentation);
        observerBuilder().type(ElementMatchers.named("zombie.iso.IsoCamera"))
            .transform((builder, type, loader, module, domain) -> builder.visit(
                Advice.to(ObserverCamera.class).on(ElementMatchers.named("setCameraCharacter"))))
            .installOn(instrumentation);
        observerBuilder().type(ElementMatchers.named("zombie.iso.IsoCamera$FrameState"))
            .transform((builder, type, loader, module, domain) -> builder.visit(
                Advice.to(ObserverFrame.class).on(ElementMatchers.named("set"))))
            .installOn(instrumentation);
        observerBuilder().type(ElementMatchers.named("zombie.iso.IsoChunkMap"))
            .transform((builder, type, loader, module, domain) -> {
                    var admission = observerMethod("admitChunkActor");
                    return builder.visit(Advice.to(ObserverResidency.class).on(ElementMatchers.named("ProcessChunkPos")))
                        .visit(MemberSubstitution.relaxed().method(ElementMatchers.named("add")
                            .and(ElementMatchers.isDeclaredBy(java.util.Set.class))
                            .and(ElementMatchers.takesArguments(Object.class)).and(ElementMatchers.returns(boolean.class)))
                            .replaceWith(admission).on(ElementMatchers.named("ProcessChunkPos")));
            })
            .installOn(instrumentation);
        observerBuilder().type(ElementMatchers.named("zombie.ui.UI3DModel"))
            .transform((builder, type, loader, module, domain) -> builder
                .visit(Advice.to(ObserverPreview.class).on(ElementMatchers.named("setCharacter")))
                .visit(Advice.to(ObserverPreviewRender.class).on(ElementMatchers.named("render"))))
            .installOn(instrumentation);
        observerBuilder().type(ElementMatchers.named("zombie.ui.UIManager"))
            .transform((builder, type, loader, module, domain) -> builder
                .visit(Advice.to(ObserverPreviewRender.class).on(ElementMatchers.named("render")
                    .and(ElementMatchers.takesArguments(0))))
                .visit(Advice.to(ObserverDebugger.class).on(ElementMatchers.named("debugBreakpoint")
                    .and(ElementMatchers.takesArguments(String.class, long.class)))))
            .installOn(instrumentation);
        observerBuilder().type(ElementMatchers.named("zombie.iso.objects.IsoTree"))
            .transform((builder, type, loader, module, domain) -> builder.visit(
                Advice.to(ObserverCanopy.class).on(ElementMatchers.named("render")
                    .and(ElementMatchers.isPrivate()).and(ElementMatchers.takesArguments(7))
                    .and(ElementMatchers.takesArgument(5, int.class)))))
            .installOn(instrumentation);
            var getter = observerMethod("participantInstance");
            observerBuilder().type(ElementMatchers.named("zombie.inventory.ItemPickerJava"))
                .transform((builder, type, loader, module, domain) -> builder.visit(
                    MemberSubstitution.relaxed().method(ElementMatchers.named("getInstance")
                        .and(ElementMatchers.isDeclaredBy(ElementMatchers.named("zombie.characters.IsoPlayer"))))
                        .replaceWith(getter).on(ElementMatchers.any())))
                .installOn(instrumentation);
        System.out.println("[StudyObserver] isolated native host hooks installed");
    }

    public static final class ObserverWorld {
        @Advice.OnMethodEnter public static boolean enter() { return StudyObserver.beginWorld(); }
        @Advice.OnMethodExit(onThrowable = Throwable.class)
        public static void exit(@Advice.Enter boolean previous, @Advice.Thrown Throwable failure) {
            StudyObserver.endWorld(previous, failure);
        }
    }

    public static final class ObserverBirth {
        @Advice.OnMethodEnter(skipOn = Advice.OnNonDefaultValue.class)
        public static boolean enter(@Advice.Argument(0) String event, @Advice.Argument(1) Object actor) {
            return StudyObserver.suppressBirth(event, actor);
        }
    }

    public static final class ObserverSave {
        @Advice.OnMethodEnter(skipOn = Advice.OnNonDefaultValue.class)
        public static boolean enter(@Advice.Argument(0) Object actor) { return StudyObserver.suppressSave(actor); }
    }

    public static final class ObserverPoll {
        @Advice.OnMethodEnter public static void enter() { StudyObserver.poll(); }
    }

    public static final class HostScheduling {
        @Advice.OnMethodExit public static void exit(@Advice.Return(readOnly = false) boolean dead) {
            if (StudyObserver.hostOnly()) dead = false;
        }
    }

    public static final class ObserverCamera {
        @Advice.OnMethodEnter public static void enter(
                @Advice.Argument(value = 0, readOnly = false, typing = Assigner.Typing.DYNAMIC) Object actor) {
            actor = StudyObserver.cameraFor(actor);
        }
    }

    public static final class ObserverResidency {
        @Advice.OnMethodEnter public static void enter(
                @Advice.Argument(value = 0, readOnly = false, typing = Assigner.Typing.DYNAMIC) Object actor) {
            actor = StudyObserver.residencyFor(actor);
        }
    }

    public static final class ObserverFrame {
        @Advice.OnMethodExit public static void exit(@Advice.This Object frame) { StudyObserver.frameState(frame); }
    }

    public static final class ObserverPreview {
        @Advice.OnMethodEnter(skipOn = Advice.OnNonDefaultValue.class)
        public static boolean enter(@Advice.This Object widget, @Advice.Argument(0) Object character) {
            return StudyObserver.hideCharacterPreview(widget, character);
        }
    }

    public static final class ObserverPreviewRender {
        @Advice.OnMethodEnter(skipOn = Advice.OnNonDefaultValue.class)
        public static boolean enter() { return StudyObserver.hideNativeUi(); }
    }

    public static final class ObserverDebugger {
        @Advice.OnMethodEnter(skipOn = Advice.OnNonDefaultValue.class)
        public static boolean enter(@Advice.Argument(0) String source, @Advice.Argument(1) long line) {
            return StudyObserver.suppressDebugger(source, line);
        }
    }

    public static final class ObserverCanopy {
        @Advice.OnMethodEnter
        public static void enter(@Advice.Argument(5) int playerIndex,
                @Advice.Argument(value = 6, readOnly = false) boolean cutaway,
                @Advice.FieldValue(value = "cutawayAlpha", readOnly = false) float alpha) {
            if (StudyObserver.cutawayCanopy(playerIndex)) {
                cutaway = true;
                alpha = 0;
            }
        }
    }

    public static final class ContinueLoading {
        @Advice.OnMethodEnter
        public static void enter(@Advice.FieldValue(value = "forceDone", readOnly = false) boolean requested) {
            requested = true;
        }
    }

    /** A method-return receipt, not a claim that every internal writer succeeded.
     * The runner checks errors and artifacts; native reopen tests durability.
     */
    public static final class SaveReturn {
        @Advice.OnMethodEnter
        public static boolean enter(@Advice.Argument(0) boolean exitSave) {
            return exitSave && zombie.GameWindow.closeRequested && zombie.GameWindow.okToSaveOnExit
                && Thread.currentThread() == zombie.GameWindow.gameThread
                && !zombie.core.Core.getInstance().isNoSave()
                && zombie.iso.IsoWorld.instance.currentCell != null
                && "Sandbox".equals(zombie.core.Core.getInstance().getGameMode())
                && !zombie.network.GameClient.client && !zombie.network.GameClient.clientSave
                && !zombie.network.GameServer.server;
        }

        @Advice.OnMethodExit(onThrowable = Throwable.class)
        public static void exit(@Advice.Enter boolean eligible, @Advice.Thrown Throwable error) {
            if (eligible && error == null) {
                System.out.println("[StudyLaunch] native-save-returned attempt="
                    + System.getProperty("study.attempt"));
            }
        }
    }
}
