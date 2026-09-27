import java.nio.file.Files;
import java.nio.file.Path;

public final class WeaveDiagnosticsProbe {
    private static void check(String name, boolean result) {
        System.out.println("CHECK " + name + "=" + result);
        if (!result) throw new AssertionError(name);
    }
    public static void main(String[] args) throws Exception {
        String log = Files.readString(Path.of(System.getProperty("user.home"), "Zomboid", "SAOAgent.log"));
        String report = com.sao.agent.SAOOrientationWeave.report();
        System.out.println("REPORT " + report);
        if (args[0].equals("failure")) {
            check("actual_transform_failure_reported", report.startsWith("sound-pulses=failed:"));
            check("actual_transform_failure_logged", log.contains("orientation sound weave failed class=zombie.WorldSoundManager$WorldSound phase=transform"));
            check("repeated_transform_failure_logged_once", log.lines().filter(s -> s.contains("orientation sound weave failed class=")).count() == 1);
            check("failed_transform_not_ready", !log.contains("orientation sound weave transformed class="));
        } else {
            check("entry_point_registered_weave", WeaveDiagnosticsAgent.entryReport.equals("sound-pulses=ready")
                || WeaveDiagnosticsAgent.entryReport.equals("sound-pulses=waiting"));
            check("native_transform_ready", report.equals("sound-pulses=ready"));
            check("native_transform_logged", log.contains("orientation sound weave transformed class=zombie.WorldSoundManager$WorldSound loaded=" + args[1]));
            check("native_transform_loader_logged", log.contains("loader=jdk.internal.loader.ClassLoaders$AppClassLoader@"));
            check("repeated_transform_success_logged_once", log.lines().filter(s -> s.contains("orientation sound weave transformed class=")).count() == 1);
            check("registration_logged_once", log.lines().filter(s -> s.contains("orientation sound weave registered class=")).count() == 1);
            check("healthy_transform_no_failure", !log.contains("orientation sound weave failed class="));
        }
        System.out.println("PASS actual weave diagnostics");
        System.exit(0);
    }
}
