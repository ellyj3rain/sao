package com.sao;

import com.sao.agent.SAOViewpointShellVisibilityWeave;
import com.sao.engine.SAOIsoPlayerShell;
import java.lang.instrument.Instrumentation;
import java.lang.reflect.Field;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import sun.misc.Unsafe;
import zombie.characters.IsoPlayer;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoMovingObject;

/** Runs the pinned Viewpoint method outside the game, with and without the advice. */
public final class VisibilityProbe {
    private static boolean agentReady;
    private static int passed;

    private VisibilityProbe() { }

    public static void premain(String args, Instrumentation instrumentation) {
        agentReady = SAOViewpointShellVisibilityWeave.install(instrumentation);
        if (!agentReady) throw new AssertionError(SAOViewpointShellVisibilityWeave.report());
    }

    private static void check(String name, boolean condition) {
        if (!condition) throw new AssertionError(name);
        passed++;
        System.out.println("PASS " + name);
    }

    private static Unsafe unsafe() throws Exception {
        Field field = Unsafe.class.getDeclaredField("theUnsafe");
        field.setAccessible(true);
        return (Unsafe) field.get(null);
    }

    private static Method capture() throws Exception {
        Class<?> owner = Class.forName(SAOViewpointShellVisibilityWeave.CAPTURE_TARGET);
        for (Method method : owner.getDeclaredMethods()) {
            if (!method.getName().equals("capture")) continue;
            if (method.getParameterCount() != 9 || method.getReturnType() != boolean.class) continue;
            method.setAccessible(true);
            return method;
        }
        throw new AssertionError("pinned capture signature absent");
    }

    private static Method inRange() throws Exception {
        Class<?> owner = Class.forName(SAOViewpointShellVisibilityWeave.RANGE_TARGET);
        Method method = owner.getDeclaredMethod("inRange", IsoMovingObject.class,
            float.class, float.class, float.class);
        method.setAccessible(true);
        return method;
    }

    private static boolean range(Method method, IsoMovingObject character) throws Exception {
        return (boolean) method.invoke(null, character, 0.0f, 0.0f, 100.0f);
    }

    private static Object call(Method method, IsoMovingObject character) throws Exception {
        try {
            return method.invoke(null, null, null, character, false, null,
                0.0f, 0.0f, 0.0f, 0.0f);
        } catch (InvocationTargetException failure) {
            if (failure.getCause() instanceof Exception exception) throw exception;
            if (failure.getCause() instanceof Error error) throw error;
            throw new AssertionError(failure.getCause());
        }
    }

    private static boolean entersOriginal(Method method, IsoMovingObject character) throws Exception {
        try {
            call(method, character);
            return false;
        } catch (NullPointerException expected) {
            // Original method dereferences the null slot immediately.
            return true;
        }
    }

    public static void main(String[] args) throws Exception {
        boolean woven = args.length == 1 && "woven".equals(args[0]);
        Unsafe unsafe = unsafe();
        Method capture = capture();
        Method range = inRange();
        IsoGridSquare square = (IsoGridSquare) unsafe.allocateInstance(IsoGridSquare.class);
        Field current = IsoMovingObject.class.getDeclaredField("current");
        current.setAccessible(true);
        SAOIsoPlayerShell staged = (SAOIsoPlayerShell) unsafe.allocateInstance(SAOIsoPlayerShell.class);
        current.set(staged, square);
        staged.removalPending = true;
        // A failed publication retains this same public visibility state while
        // SAOReturnBody keeps its real transaction handle for retry/discard.
        SAOIsoPlayerShell failedShape = (SAOIsoPlayerShell) unsafe.allocateInstance(SAOIsoPlayerShell.class);
        current.set(failedShape, square);
        failedShape.removalPending = true;
        SAOIsoPlayerShell squareless = (SAOIsoPlayerShell) unsafe.allocateInstance(SAOIsoPlayerShell.class);
        SAOIsoPlayerShell active = (SAOIsoPlayerShell) unsafe.allocateInstance(SAOIsoPlayerShell.class);
        current.set(active, square);
        IsoPlayer foreign = (IsoPlayer) unsafe.allocateInstance(IsoPlayer.class);

        check("instrumentation state", woven == agentReady);
        if (woven) {
            check("weave transformed pinned class", "ready".equals(SAOViewpointShellVisibilityWeave.report()));
            check("published pending shell shape excluded before ground blob", !range(range, staged));
            check("failed publication shell shape excluded before ground blob", !range(range, failedShape));
            check("squareless shell excluded before ground blob", !range(range, squareless));
            check("active shell retained in character range", range(range, active));
            check("foreign player retained in character range", range(range, foreign));
            check("published pending shell shape has no model capture", Boolean.FALSE.equals(call(capture, staged)));
            check("failed publication shell shape has no model capture", Boolean.FALSE.equals(call(capture, failedShape)));
            check("squareless shell has no model capture", Boolean.FALSE.equals(call(capture, squareless)));
            check("active SAO shell reaches original capture", entersOriginal(capture, active));
            check("foreign character reaches original capture", entersOriginal(capture, foreign));
        } else {
            check("original published pending shell shape enters ground blob path", range(range, staged));
            check("original failed publication shell shape enters ground blob path", range(range, failedShape));
            check("original squareless shell enters ground blob path", range(range, squareless));
            check("original pending shell reaches capture body", entersOriginal(capture, staged));
            check("original squareless shell reaches capture body", entersOriginal(capture, squareless));
        }
        System.out.println("PASS TOTAL " + passed);
    }
}
