import java.lang.reflect.Field;
import java.nio.file.Files;
import java.nio.file.Path;
import zombie.GameTime;
import zombie.characters.CharacterTimedActions.BaseAction;
import zombie.ui.SpeedControls;

/** Installed clock/action methods in the observer fixture, not a world stepper. */
public final class NativeObserverClockProbe {
    private static void check(boolean value, String message) {
        if (!value) throw new AssertionError(message);
    }

    private static Field field(Class<?> owner, String name) throws Exception {
        Field result = owner.getDeclaredField(name);
        result.setAccessible(true);
        return result;
    }

    private static long command(Path control, String properties) throws Exception {
        long sequence = Math.max(StudyObserver.commandSequence(),
            field(StudyObserver.class, "rejectedSequence").getLong(null)) + 1;
        Files.writeString(control, "sequence=" + sequence + "\n" + properties);
        field(StudyObserver.class, "nextPoll").setLong(null, 0);
        StudyObserver.poll();
        check(StudyObserver.commandSequence() == sequence, "native clock command was not acknowledged");
        return sequence;
    }

    private static double[] measure(int updates, float fpsMultiplier) throws Exception {
        GameTime time = GameTime.getInstance();
        // A short interval inside one ten-minute bucket avoids unrelated terrain,
        // erosion and radio initialization. The installed update method itself
        // advances world hours; the fixture never writes the measured endpoint.
        time.setTimeOfDay(9.0125f);
        time.fpsMultiplier = fpsMultiplier;
        field(GameTime.class, "minutesMod").setInt(time, 0);
        field(GameTime.class, "randomAmbientToday").setBoolean(time, false);
        field(GameTime.class, "gunFireEventToday").setBoolean(time, false);
        double start = time.getWorldAgeHours();
        BaseAction action = new BaseAction(null);
        action.reset();
        action.useProgressBar = false;
        action.maxTime = 10000;
        for (int index = 0; index < updates; index++) {
            time.update(false);
            // Native world dispatch gates character updates while paused. This
            // fixture checks the action's actual timer, not its physical effects.
            if (!GameTime.isGamePaused()) action.update();
        }
        return new double[] {time.getWorldAgeHours() - start, action.getCurrentTime()};
    }

    private static boolean near(double actual, double expected, double tolerance) {
        return Double.isFinite(actual) && Math.abs(actual - expected) <= tolerance;
    }

    public static void run(Path control, SpeedControls controls) throws Exception {
        GameTime time = GameTime.getInstance();
        double[] baseline = null;
        String[] buttons = {"play", "fastForward", "fasterForward"};
        float[] multipliers = {1, 5, 20};
        for (int slot = 1; slot <= 3; slot++) {
            command(control, "paused=false\nspeed=" + slot + "\n");
            float expected = multipliers[slot - 1];
            check(controls.getCurrentGameSpeed() == slot && time.getTrueMultiplier() == expected,
                "native speed " + slot + " multiplier did not match installed preset");
            check(StudyObserver.snapshot().contains("\"nativeMultiplier\":" + expected),
                "observer receipt omitted actual native multiplier");
            double[] actual = measure(20, 1);
            // The installed button handler is the independent preset oracle.
            controls.ButtonClicked(buttons[slot - 1]);
            double[] oracle = measure(20, 1);
            check(actual[0] > 0 && near(actual[0], oracle[0], 0.000001),
                "observer world-clock advance differs from native button preset");
            check(actual[1] > 0 && near(actual[1], oracle[1], 0.00001),
                "observer timed-action advance differs from native button preset");
            if (baseline == null) baseline = actual;
            check(near(actual[0] / baseline[0], expected, 0.05)
                && near(actual[1] / baseline[1], expected, 0.0001),
                "native clock and action rates did not scale together");
            double[] slowerFrames = measure(10, 2);
            check(near(slowerFrames[0], actual[0], 0.00002)
                && near(slowerFrames[1], actual[1], 0.0001),
                "native FPS multiplier did not preserve clock/action interval");
            System.out.println("[StudyClockProbe] speed=" + slot + " multiplier=" + expected
                + " hours=" + actual[0] + " actionTime=" + actual[1]);
        }
        // External native speed adjustments also belong to the native owners;
        // an unrelated camera command must not overwrite their current value.
        time.setMultiplier(7);
        command(control, "viewX=11\nresidencyY=3\n");
        check(controls.getCurrentGameSpeed() == 3 && time.getTrueMultiplier() == 7,
            "camera-only command changed native speed multiplier");
        command(control, "paused=true\n");
        check(GameTime.isGamePaused() && measure(20, 1)[0] == 0,
            "paused observer clock advanced");
        command(control, "speed=2\n");
        check(GameTime.isGamePaused() && measure(20, 1)[0] == 0,
            "changing paused preset resumed the native clock");
        float pausedMultiplier = time.getTrueMultiplier();
        command(control, "viewY=12\nresidencyX=22\n");
        check(GameTime.isGamePaused() && time.getTrueMultiplier() == pausedMultiplier,
            "camera-only command changed native pause intent");
        command(control, "paused=false\n");
        check(controls.getCurrentGameSpeed() == 2 && time.getTrueMultiplier() == 5,
            "resume discarded preset selected while paused");
        check(near(measure(20, 1)[0] / baseline[0], 5, 0.05),
            "resumed native clock did not advance at selected preset");
        System.out.println("PASS native observer clock: production commands match installed button presets; "
            + "world-hour and BaseAction timer deltas; FPS compensation; pause, paused selection, resume; "
            + "camera/residency commands preserve native clock. No loaded-world parity claim.");
    }
}
