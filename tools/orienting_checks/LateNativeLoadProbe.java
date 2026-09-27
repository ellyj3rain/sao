import com.sao.agent.SAOOrientationWeave;
import com.sao.engine.*;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import zombie.WorldSoundManager;
import zombie.iso.IsoCell;

/** Real installed agents plus a controlled later nested native load. This
 * reproduces the loaded-but-unwoven state, not the unobserved live call stack. */
public final class LateNativeLoadProbe {
    private static void check(String name, boolean value) { OrientationProbe.check(name, value); }
    public static void main(String[] args) throws Exception {
        try {
            check("real_zombiebuddy_agent_installed", OrientationProbe.field(
                me.zed_0xff.zombie_buddy.Loader.class, "g_instrumentation").get(null) != null);
            check("premain_has_no_sound_transform", SAOOrientationWeave.report().equals("sound-pulses=waiting"));
            LateNativeLoadAgent.resolveDuringLaterTransform();
            Class<?> target = LateNativeLoadAgent.loadedSound();
            check("late_nested_native_load_exercised", LateNativeLoadAgent.nestedLoad && target != null);
            check("late_native_same_loader", target.getClassLoader() == SAOOrientationWeave.class.getClassLoader());
            check("late_load_after_install_unwoven", SAOOrientationWeave.report().equals("sound-pulses=waiting"));
            var boot = MovementCrossingProbe.class.getDeclaredMethod("boot"); boot.setAccessible(true);
            IsoCell cell = (IsoCell) boot.invoke(null);
            Path root = Path.of(args[0]), game = Path.of(args[1]);
            for (String name : List.of("look.xml", "tags.xml", "children.xml", "enter.xml", "exit.xml"))
                zombie.ZomboidFileSystem.instance.activeFileMap.put("media/saoorienting/" + name,
                    root.resolve("mod/42.20/media/SAOOrienting/" + name).toString());
            var skin = OrientationProbe.skeleton(game);
            var body = OrientationProbe.body(cell, skin);
            check("late_sensor_head_layer_ready", SAOOrientationAnimation.ensure(body));
            var sounds = WorldSoundManager.instance.soundList; sounds.clear();
            var missed = WorldSoundManager.instance.getNew();
            missed.init(null, 10, 26, 0, 30, 30, 0f, 1f, (short) 2); sounds.add(missed);
            check("missed_init_has_no_token", SAOWorldSoundPulses.heard(body, missed) == null);
            String first = SAOPerceptionScanner.scan(body);
            check("native_sensor_reconciles_late_class", SAOOrientationWeave.report().equals("sound-pulses=ready"));
            check("sensor_keeps_missed_occurrence_unclassified", first.contains("S:10:26:") && !first.contains(":cue:")
                && SAOWorldSoundPulses.heard(body, missed) == null);
            missed.init(null, 10, 26, 0, 30, 30, 0f, 1f, (short) 2);
            String second = SAOPerceptionScanner.scan(body);
            String token = SAOWorldSoundPulses.heard(body, missed);
            check("later_real_init_acquires_token", token != null && second.contains(":cue:" + token));
            check("late_reconciled_cue_orients", SAOOrientation.request(body, token, 10, 26, 1, 1, true));
            double remaining = ((Number) SAOOrientation.state(body).rawget("remainingSeconds")).doubleValue();
            for (int i = 0; i < 8; i++) SAOPerceptionScanner.scan(body);
            check("repeated_sensor_does_not_restart_pulse", !SAOOrientation.request(body, token, 10, 26, 1, 1, true)
                && remaining == ((Number) SAOOrientation.state(body).rawget("remainingSeconds")).doubleValue());
            var deaf = OrientationProbe.body(cell, skin);
            deaf.getCharacterTraits().set(zombie.scripting.objects.CharacterTrait.DEAF, true);
            check("late_reconcile_preserves_private_hearing", !SAOPerceptionScanner.scan(deaf).contains("S:10:26:")
                && !SAOOrientation.request(deaf, token, 10, 26, 1, 1, true));
            String log = Files.readString(Path.of(System.getProperty("user.home"), "Zomboid", "SAOAgent.log"));
            check("late_reconcile_logged_once", log.split("sound weave sensor reconciliation", -1).length - 1 == 1);
            check("late_transform_logged_once", log.split("sound weave transformed", -1).length - 1 == 1);
            sounds.clear();
            System.out.println("PASS installed late native sound bootstrap checks=" + OrientationProbe.checks);
            System.exit(0);
        } catch (Throwable failure) { failure.printStackTrace(); System.exit(1); }
    }
}
