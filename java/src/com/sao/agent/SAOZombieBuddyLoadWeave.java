package com.sao.agent;

import java.lang.instrument.Instrumentation;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.util.ArrayList;
import java.util.List;
import net.bytebuddy.agent.builder.AgentBuilder;
import net.bytebuddy.asm.Advice;
import net.bytebuddy.description.annotation.AnnotationDescription;
import net.bytebuddy.description.annotation.AnnotationList;
import net.bytebuddy.description.method.MethodDescription;
import net.bytebuddy.description.type.TypeDescription;
import net.bytebuddy.jar.asm.ClassReader;
import net.bytebuddy.jar.asm.ClassVisitor;
import net.bytebuddy.jar.asm.MethodVisitor;
import net.bytebuddy.jar.asm.Opcodes;
import net.bytebuddy.matcher.ElementMatcher;
import net.bytebuddy.matcher.ElementMatchers;
import net.bytebuddy.pool.TypePool;

/**
 * Restores the installed ZombieBuddy loader callback for Build 42's List
 * overload. ZombieBuddy's installed ArrayList advice does not match that
 * native signature. The installed Loader remains responsible for ordering,
 * approval, package lifecycle and registration.
 *
 * This seam is installed by SAO premain. It does not bootstrap ordinary Steam
 * launches without that premain, initialize game classes during installation,
 * or write the loader's policy/approval/registration state itself.
 */
public final class SAOZombieBuddyLoadWeave {
    public static final String TARGET = "zombie.ZomboidFileSystem";
    public static final String LOADER = "me.zed_0xff.zombie_buddy.Loader";
    private static final String UPSTREAM_ENTRY = "me.zed_0xff.zombie_buddy.patches.Patch_ZomboidFileSystem$Patch_loadMods2";
    private static final String LIST_DESCRIPTOR = "(Ljava/util/List;)V";
    private static volatile boolean installed;
    private static volatile boolean applied;
    private static volatile boolean upstreamCallback;
    private static volatile boolean compatibleUpstreamDeclared;
    private static volatile String failure;
    private static volatile String lastInvocation = "not-observed";

    private SAOZombieBuddyLoadWeave() {
    }

    public static final class Enter {
        private Enter() {
        }

        // Do not suppress loader exceptions: native loading must not continue
        // after a failed approval/loading callback as though it had succeeded.
        @Advice.OnMethodEnter
        public static void enter(@Advice.Argument(value = 0, readOnly = false) List<String> mods,
                @Advice.Origin Class<?> owner) throws Throwable {
            mods = SAOZombieBuddyLoadWeave.loadMods(mods, owner);
        }
    }

    static ElementMatcher.Junction<MethodDescription> nativeMethod() {
        return ElementMatchers.named("loadMods")
            .and(ElementMatchers.takesArguments(List.class))
            .and(ElementMatchers.returns(void.class))
            .and(ElementMatchers.not(ElementMatchers.isStatic()));
    }

    public static synchronized void install(Instrumentation instrumentation) {
        if (installed) {
            return;
        }
        try {
            new AgentBuilder.Default()
                .disableClassFormatChanges()
                .with(AgentBuilder.ClassFileBufferStrategy.Default.RETAINING)
                .with(AgentBuilder.RedefinitionStrategy.RETRANSFORMATION)
                .with(AgentBuilder.TypeStrategy.Default.REDEFINE)
                .with(new AgentBuilder.Listener.Adapter() {
                    @Override
                    public void onError(String name, ClassLoader loader,
                            net.bytebuddy.utility.JavaModule module, boolean loaded, Throwable error) {
                        if (TARGET.equals(name)) {
                            failure = String.valueOf(error);
                            SAOAgent.log("ZombieBuddy List callback: transformation failed " + error);
                        }
                    }
                })
                .type(ElementMatchers.named(TARGET))
                .transform((builder, type, loader, module, domain) -> {
                    if (type.getDeclaredMethods().filter(nativeMethod()).isEmpty()) {
                        lastInvocation = "unsupported-native-signature";
                        return builder;
                    }
                    // RETAINING preserves bytes supplied by earlier transformers.
                    // A compatible upstream callback must actually be present in
                    // this overload; a merely advertised patch signature is not
                    // proof that upstream instrumentation has run.
                    if (hasCallback(builder.make().getBytes())) {
                        upstreamCallback = true;
                        SAOAgent.log("ZombieBuddy List callback: existing callback retained");
                        return builder;
                    }
                    if (declaredCompatibleUpstream(loader)) {
                        compatibleUpstreamDeclared = true;
                        lastInvocation = "declared-upstream-unverified";
                        SAOAgent.log("ZombieBuddy List callback: compatible upstream entry declared; "
                            + "SAO bridge withheld, upstream instrumentation not established here");
                        return builder;
                    }
                    applied = true;
                    return builder.visit(Advice.to(Enter.class).on(nativeMethod()));
                })
                .installOn(instrumentation);
            installed = true;
            SAOAgent.log("ZombieBuddy List callback: premain transformer installed");
        } catch (Throwable error) {
            failure = String.valueOf(error);
            SAOAgent.log("ZombieBuddy List callback: installation failed " + error);
        }
    }

    /**
     * Stand down for the canonical compatible upstream advice in either install
     * order. Read annotations/signatures only. A declaration does not establish
     * that upstream has installed its transformer; that boundary stays explicit.
     */
    static boolean declaredCompatibleUpstream(ClassLoader loader) {
        TypePool.Resolution resolution = TypePool.Default.of(loader).describe(UPSTREAM_ENTRY);
        if (!resolution.isResolved()) {
            return false;
        }
        TypeDescription patch = resolution.resolve();
        AnnotationDescription target = annotation(patch.getDeclaredAnnotations(),
            "me.zed_0xff.zombie_buddy.Patch");
        if (target == null || !TARGET.equals(target.getValue("className").resolve(String.class))
                || !"loadMods".equals(target.getValue("methodName").resolve(String.class))) {
            return false;
        }
        for (MethodDescription.InDefinedShape method : patch.getDeclaredMethods()) {
            if (method.isPublic() && method.isStatic() && "enter".equals(method.getName())
                    && method.getReturnType().asErasure().represents(void.class)
                    && !method.getParameters().isEmpty()
                    && method.getParameters().get(0).getDeclaredAnnotations().isEmpty()
                    && annotation(method.getDeclaredAnnotations(),
                        "me.zed_0xff.zombie_buddy.Patch$OnEnter") != null
                    && TypeDescription.ForLoadedType.of(List.class).isAssignableTo(
                        method.getParameters().get(0).getType().asErasure())) {
                // The installed shape has only the native argument and @Local
                // timing state. Refuse unknown extra implicit native parameters.
                boolean localsOnly = true;
                for (int index = 1; index < method.getParameters().size(); index++) {
                    if (annotation(method.getParameters().get(index).getDeclaredAnnotations(),
                            "me.zed_0xff.zombie_buddy.Patch$Local") == null) {
                        localsOnly = false;
                    }
                }
                if (localsOnly) {
                    return true;
                }
            }
        }
        return false;
    }

    private static AnnotationDescription annotation(AnnotationList annotations, String name) {
        for (AnnotationDescription annotation : annotations) {
            if (name.equals(annotation.getAnnotationType().getName())) {
                return annotation;
            }
        }
        return null;
    }

    /** Detect a real callback in the exact native overload without loading it. */
    static boolean hasCallback(byte[] bytes) {
        boolean[] found = { false };
        new ClassReader(bytes).accept(new ClassVisitor(Opcodes.ASM9) {
            @Override
            public MethodVisitor visitMethod(int access, String name, String descriptor,
                    String signature, String[] exceptions) {
                if (!"loadMods".equals(name) || !LIST_DESCRIPTOR.equals(descriptor)
                        || (access & Opcodes.ACC_STATIC) != 0) {
                    return null;
                }
                return new MethodVisitor(Opcodes.ASM9) {
                    @Override
                    public void visitMethodInsn(int opcode, String owner, String method,
                            String callDescriptor, boolean isInterface) {
                        if (opcode == Opcodes.INVOKESTATIC && "loadMods".equals(method)
                                && ((LOADER.replace('.', '/').equals(owner)
                                    && "(Ljava/util/ArrayList;)V".equals(callDescriptor))
                                || (SAOZombieBuddyLoadWeave.class.getName().replace('.', '/').equals(owner)
                                    && "(Ljava/util/List;Ljava/lang/Class;)Ljava/util/List;".equals(callDescriptor)))) {
                            found[0] = true;
                        }
                    }
                };
            }
        }, ClassReader.SKIP_DEBUG | ClassReader.SKIP_FRAMES);
        return found[0];
    }

    /** Called by inlined advice; resolve the loader in the native owner's namespace. */
    public static List<String> loadMods(List<String> mods, Class<?> owner) throws Throwable {
        if (mods == null) {
            lastInvocation = "null-native-list";
            return null;
        }
        final Method callback;
        try {
            ClassLoader namespace = owner.getClassLoader();
            Class<?> loader = Class.forName(LOADER, false, namespace);
            callback = loader.getDeclaredMethod("loadMods", ArrayList.class);
            if (!Modifier.isPublic(loader.getModifiers()) || !Modifier.isPublic(callback.getModifiers())
                    || !Modifier.isStatic(callback.getModifiers()) || callback.getReturnType() != void.class) {
                lastInvocation = "unsupported-loader-signature";
                SAOAgent.log("ZombieBuddy List callback: unsupported Loader.loadMods(ArrayList)");
                return mods;
            }
        } catch (ClassNotFoundException | NoSuchMethodException | SecurityException absent) {
            lastInvocation = "loader-unavailable";
            SAOAgent.log("ZombieBuddy List callback: loader unavailable " + absent);
            return mods;
        }
        // Preserve the real ArrayList when present. For other List implementations,
        // feed native loading the same working list that the Loader mutated.
        ArrayList<String> working = mods instanceof ArrayList<String>
            ? (ArrayList<String>) mods : new ArrayList<>(mods);
        lastInvocation = "invoking";
        try {
            callback.invoke(null, working);
            lastInvocation = "callback-returned";
            return working;
        } catch (InvocationTargetException exception) {
            lastInvocation = "callback-threw";
            // Preserve the actual loader exception, including approval failures.
            throw exception.getCause();
        }
    }

    public static String report() {
        return "installed=" + installed + "|applied=" + applied
            + "|upstream=" + upstreamCallback + "|upstream-declared=" + compatibleUpstreamDeclared
            + "|invocation=" + lastInvocation
            + (failure == null ? "" : "|failure=" + failure);
    }
}
