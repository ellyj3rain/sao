import java.lang.instrument.Instrumentation;
import net.bytebuddy.agent.builder.AgentBuilder;
import net.bytebuddy.asm.Advice;
import net.bytebuddy.asm.MemberSubstitution;
import net.bytebuddy.implementation.bytecode.assign.Assigner;
import net.bytebuddy.matcher.ElementMatchers;
import net.bytebuddy.description.method.MethodDescription;
import net.bytebuddy.pool.TypePool;
import net.bytebuddy.asm.AsmVisitorWrapper;
import net.bytebuddy.description.type.TypeDescription;
import net.bytebuddy.implementation.Implementation;
import net.bytebuddy.jar.asm.ClassWriter;
import net.bytebuddy.jar.asm.Label;
import net.bytebuddy.jar.asm.MethodVisitor;
import net.bytebuddy.jar.asm.Opcodes;

/** Automates the final loading-screen click in an explicitly launched study JVM.
 * GameLoadingState.update retains its native readiness and streaming checks.
 * Observer hooks are enabled only by the explicitly isolated observer property.
 */
public final class StudyLoadingAgent {
    private static volatile boolean emptyBreakpointLookup;
    private static java.lang.reflect.Method participantPollMethod;
    private static java.lang.reflect.Method participantInputUpdateMethod;
    private static java.lang.reflect.Method nativeInteractionPollMethod;
    public static boolean emptyBreakpointLookupInstalled() { return emptyBreakpointLookup; }
    public static void premain(String argument, Instrumentation instrumentation) {
        boolean nativePlay = "native-play".equals(argument);
        if (!nativePlay && !"isolated-study".equals(argument)) throw new IllegalArgumentException("explicit launch mode required");
        if (nativePlay && (Boolean.getBoolean("study.observer") || !Boolean.getBoolean("study.participantInput")
                || System.getProperty("study.activeMods") != null))
            throw new IllegalArgumentException("native play requires visible participant capture and the native mod selector");
        // ClassGraph's concurrent scan reaches ConcurrentHashMap.fullAddCount.
        // Resolve its lazy bootstrap dependency before our transformers can be
        // entered during that first class load (native26: ClassCircularityError).
        java.util.concurrent.ThreadLocalRandom.current();
        if (Boolean.getBoolean("study.observer")) installObserver(instrumentation);
        else if (System.getProperty("study.participantInput") != null) installParticipantInput(instrumentation);
        new AgentBuilder.Default()
            .disableClassFormatChanges()
            .with(AgentBuilder.RedefinitionStrategy.RETRANSFORMATION)
            .with(AgentBuilder.Listener.StreamWriting.toSystemError().withErrorsOnly())
            .type(ElementMatchers.named("zombie.GameWindow"))
            .transform((builder, type, loader, module, domain) -> builder.visit(
                Advice.to(SaveReturn.class).on(ElementMatchers.named("save")
                    .and(ElementMatchers.takesArguments(boolean.class)))))
            .installOn(instrumentation);
        if (!nativePlay) new AgentBuilder.Default()
            .disableClassFormatChanges()
            .with(AgentBuilder.RedefinitionStrategy.RETRANSFORMATION)
            .with(AgentBuilder.Listener.StreamWriting.toSystemError().withErrorsOnly())
            .type(ElementMatchers.named("zombie.ZomboidFileSystem"))
            .transform((builder, type, loader, module, domain) -> builder.visit(
                Advice.to(StudyMods.class).on(ElementMatchers.named("loadMods")
                    .and(ElementMatchers.takesArguments(String.class)))))
            .installOn(instrumentation);
        if (!nativePlay) new AgentBuilder.Default()
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
        System.out.println(nativePlay ? "[NativePlay] native main menu, load, character and mod selection retained"
            : "[StudyLaunch] loading click automation installed");
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
            "zombie.ui.UIManager", "zombie.inventory.ItemPickerJava", "zombie.iso.objects.IsoTree",
            "zombie.iso.fboRenderChunk.FBORenderCutaways",
            "se.krka.kahlua.vm.KahluaThread");
        if (System.getProperty("study.viewDirectory") != null) java.util.Collections.addAll(names,
            "zombie.core.sprite.SpriteRenderState", "zombie.core.SpriteRenderer", "zombie.core.Core");
        if (System.getProperty("study.participantInput") != null && !Boolean.getBoolean("study.observer"))
            java.util.Collections.addAll(names, "zombie.input.GameKeyboard", "zombie.input.Mouse");
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

    private static MethodDescription participantMethod(String name) {
        return TypePool.Default.of(StudyLoadingAgent.class.getClassLoader()).describe("StudyParticipantInput")
            .resolve().getDeclaredMethods().filter(ElementMatchers.named(name)).getOnly();
    }

    /**
     * Replace KeyboardState.isKeyDown inside GameKeyboard.update and
     * MouseState.isButtonDown/getX/getY inside Mouse.update with native-or-leased
     * StudyParticipantInput statics. Must run before AimingReticle and Lua key
     * edges observe the frame. Observer host never installs these hooks.
     */
    private static void installParticipantInput(Instrumentation instrumentation) {
        if (Boolean.getBoolean("study.observer"))
            throw new IllegalStateException("participant input refuses the observer host");
        if (!instrumentation.isRetransformClassesSupported())
            throw new IllegalStateException("participant input agent requires Can-Retransform-Classes: true");
        // Reflect so OBSERVER_SOURCES can still compile StudyLoadingAgent without
        // listing StudyParticipantInput in that inventory tuple.
        try {
            Class.forName("StudyParticipantInput").getMethod("enableFromProperties").invoke(null);
            participantInputUpdateMethod = Class.forName("StudyParticipantInput").getMethod("beginInputUpdate");
            participantPollMethod = Class.forName("StudyParticipant").getMethod("poll");
            if (System.getProperty("study.interactionDirectory") != null) {
                Class<?> interaction = Class.forName("StudyNativeInteraction");
                interaction.getMethod("configure").invoke(null);
                nativeInteractionPollMethod = interaction.getMethod("poll");
            }
        } catch (ReflectiveOperationException failure) {
            throw new IllegalStateException("StudyParticipantInput unavailable for participant hooks", failure);
        }
        var keyDown = participantMethod("isKeyDown");
        var buttonDown = participantMethod("isButtonDown");
        var mouseX = participantMethod("getX");
        var mouseY = participantMethod("getY");
        observerBuilder().type(ElementMatchers.named("zombie.input.GameKeyboard"))
            .transform((builder, type, loader, module, domain) -> builder
                .visit(Advice.to(ParticipantInputUpdate.class).on(ElementMatchers.named("update").and(ElementMatchers.takesArguments(0))))
                .visit(MemberSubstitution.relaxed().method(ElementMatchers.named("isKeyDown")
                    .and(ElementMatchers.isDeclaredBy(ElementMatchers.named("zombie.input.KeyboardState")))
                    .and(ElementMatchers.takesArguments(int.class)).and(ElementMatchers.returns(boolean.class)))
                    .replaceWith(keyDown).on(ElementMatchers.named("update"))))
            .installOn(instrumentation);
        observerBuilder().type(ElementMatchers.named("zombie.input.Mouse"))
            .transform((builder, type, loader, module, domain) -> builder
                .visit(Advice.to(ParticipantInputUpdate.class).on(ElementMatchers.named("update").and(ElementMatchers.takesArguments(0))))
                .visit(MemberSubstitution.relaxed().method(ElementMatchers.named("isButtonDown")
                    .and(ElementMatchers.isDeclaredBy(ElementMatchers.named("zombie.input.MouseState")))
                    .and(ElementMatchers.takesArguments(int.class)).and(ElementMatchers.returns(boolean.class)))
                    .replaceWith(buttonDown).on(ElementMatchers.named("update")))
                .visit(MemberSubstitution.relaxed().method(ElementMatchers.named("getX")
                    .and(ElementMatchers.isDeclaredBy(ElementMatchers.named("zombie.input.MouseState")))
                    .and(ElementMatchers.takesArguments(0)).and(ElementMatchers.returns(int.class)))
                    .replaceWith(mouseX).on(ElementMatchers.named("update")))
                .visit(MemberSubstitution.relaxed().method(ElementMatchers.named("getY")
                    .and(ElementMatchers.isDeclaredBy(ElementMatchers.named("zombie.input.MouseState")))
                    .and(ElementMatchers.takesArguments(0)).and(ElementMatchers.returns(int.class)))
                    .replaceWith(mouseY).on(ElementMatchers.named("update"))))
            .installOn(instrumentation);
        observerBuilder().type(ElementMatchers.named("zombie.GameWindow"))
            .transform((builder, type, loader, module, domain) -> builder.visit(
                Advice.to(ParticipantPoll.class).on(ElementMatchers.named("logic"))))
            .installOn(instrumentation);
        System.out.println("[StudyParticipant] GameKeyboard/Mouse MemberSubstitution installed");
    }

    public static void participantPoll() {
        try {
            participantPollMethod.invoke(null);
            if (nativeInteractionPollMethod != null) nativeInteractionPollMethod.invoke(null);
        }
        catch (ReflectiveOperationException failure) {
            throw new IllegalStateException("native participant state publisher unavailable", failure);
        }
    }

    public static final class ParticipantPoll {
        @Advice.OnMethodExit public static void exit() { StudyLoadingAgent.participantPoll(); }
    }

    public static void participantInputUpdate() {
        try { participantInputUpdateMethod.invoke(null); }
        catch (ReflectiveOperationException failure) {
            throw new IllegalStateException("native participant input update unavailable", failure);
        }
    }

    public static final class ParticipantInputUpdate {
        @Advice.OnMethodEnter public static void enter() { StudyLoadingAgent.participantInputUpdate(); }
    }

    private static void installObserver(Instrumentation instrumentation) {
        if (!instrumentation.isRetransformClassesSupported())
            throw new IllegalStateException("study observer agent requires Can-Retransform-Classes: true");
        String lookup = System.getProperty("study.luaBreakpointLookup", "empty-map");
        if (!lookup.equals("empty-map") && !lookup.equals("native"))
            throw new IllegalArgumentException("invalid study Lua breakpoint lookup");
        if (lookup.equals("empty-map")) observerBuilder()
            .type(ElementMatchers.named("se.krka.kahlua.vm.KahluaThread"))
            .transform((builder, type, loader, module, domain) -> builder.visit(
                new AsmVisitorWrapper.ForDeclaredMethods()
                    .method(ElementMatchers.named("luaMainloop").and(ElementMatchers.takesArguments(0)),
                        new EmptyBreakpointLookup())
                    .writerFlags(ClassWriter.COMPUTE_FRAMES | ClassWriter.COMPUTE_MAXS)))
            .installOn(instrumentation);
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
        observerBuilder().type(ElementMatchers.named("zombie.iso.fboRenderChunk.FBORenderCutaways"))
            .transform((builder, type, loader, module, domain) -> builder.visit(
                Advice.to(ObserverCutaway.class).on(ElementMatchers.named("CalculatePointsOfInterest")
                    .and(ElementMatchers.takesArguments(0)))))
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
                .visit(Advice.to(ObserverUiRender.class).on(ElementMatchers.named("render")
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

    /** Retain native line tracking, stepping, populated maps and error handlers.
     * An empty native breakpoint map has no breakpoint to inspect. The jump
     * uses the original debug block's join rather than changing Core.debug.
     */
    static final class EmptyBreakpointLookup implements AsmVisitorWrapper.ForDeclaredMethods.MethodVisitorWrapper {
        @Override public MethodVisitor wrap(TypeDescription type, MethodDescription method, MethodVisitor visitor,
                Implementation.Context context, TypePool pool, int writerFlags, int readerFlags) {
            return new MethodVisitor(Opcodes.ASM9, visitor) {
                private Label nativeJoin;
                private boolean firstDebug, inserted;
                private int lookups;
                @Override public void visitFieldInsn(int opcode, String owner, String name, String descriptor) {
                    if (opcode == Opcodes.GETSTATIC && owner.equals("zombie/core/Core") && name.equals("debug")
                            && nativeJoin == null) firstDebug = true;
                    if (!inserted && opcode == Opcodes.GETFIELD && owner.equals("se/krka/kahlua/vm/KahluaThread")
                            && name.equals("breakpointMap") && descriptor.equals("Ljava/util/HashMap;")) {
                        if (nativeJoin == null) throw new IllegalStateException("native Lua debugger join unavailable");
                        Label populated = new Label();
                        super.visitInsn(Opcodes.DUP);
                        super.visitFieldInsn(opcode, owner, name, descriptor);
                        super.visitMethodInsn(Opcodes.INVOKEVIRTUAL, "java/util/HashMap", "isEmpty", "()Z", false);
                        super.visitJumpInsn(Opcodes.IFEQ, populated);
                        super.visitInsn(Opcodes.POP);
                        super.visitJumpInsn(Opcodes.GOTO, nativeJoin);
                        super.visitLabel(populated);
                        inserted = true;
                    }
                    super.visitFieldInsn(opcode, owner, name, descriptor);
                }
                @Override public void visitJumpInsn(int opcode, Label label) {
                    if (firstDebug) {
                        if (opcode != Opcodes.IFEQ) throw new IllegalStateException("native Lua debug guard differs");
                        nativeJoin = label; firstDebug = false;
                    }
                    super.visitJumpInsn(opcode, label);
                }
                @Override public void visitMethodInsn(int opcode, String owner, String name, String descriptor, boolean face) {
                    if (owner.equals("java/util/HashMap") && name.equals("containsKey") && descriptor.equals("(Ljava/lang/Object;)Z"))
                        lookups++;
                    super.visitMethodInsn(opcode, owner, name, descriptor, face);
                }
                @Override public void visitEnd() {
                    if (!inserted || lookups != 1) throw new IllegalStateException("native Lua breakpoint lookup shape differs");
                    super.visitEnd();
                    emptyBreakpointLookup = true;
                }
            };
        }
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
        @Advice.OnMethodExit(onThrowable = Throwable.class)
        public static void exit(@Advice.This Object map, @Advice.Argument(0) Object actor,
                                @Advice.Thrown Throwable failure) {
            StudyObserver.streamingFailure(map, actor, failure);
        }
    }

    public static final class ObserverFrame {
        @Advice.OnMethodExit public static void exit(@Advice.This Object frame) { StudyObserver.frameState(frame); }
    }

    public static final class ObserverCutaway {
        @Advice.OnMethodExit public static void exit(
                @Advice.FieldValue("pointOfInterest") java.util.ArrayList<?> points) {
            StudyObserver.cutawayFocus(points);
        }
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

    public static final class ObserverUiRender {
        @Advice.OnMethodEnter(skipOn = Advice.OnNonDefaultValue.class)
        public static boolean enter() { return StudyObserver.renderObserverUi(); }
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

    /** Cold study caches declare their sealed mod cohort explicitly. Route the
     * engine's initial default-mod load through that cohort before Lua boots. */
    public static final class StudyMods {
        @Advice.OnMethodEnter
        public static void enter(@Advice.Argument(value = 0, readOnly = false) String activeSet) {
            String declared = System.getProperty("study.activeMods");
            if (declared == null || declared.isBlank() || !"default".equalsIgnoreCase(activeSet)) return;
            var study = zombie.modding.ActiveMods.getById("isolatedStudy");
            study.clear();
            for (String id : declared.split(",")) {
                id = id.trim();
                if (!id.isEmpty()) study.setModActive(id, true);
            }
            activeSet = "isolatedStudy";
            System.out.println("[StudyLaunch] native mod cohort selected count=" + study.getMods().size());
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
                && (Boolean.getBoolean("study.nativePlay") || "Sandbox".equals(zombie.core.Core.getInstance().getGameMode()))
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
