import java.lang.reflect.Field;
import java.nio.file.Files;
import java.nio.file.Path;
import zombie.GameTime;
import zombie.characters.IsoPlayer;
import zombie.core.Core;
import zombie.core.textures.MultiTextureFBO2;
import zombie.iso.IsoCamera;
import zombie.ui.SpeedControls;

/** Production commands and installed projection methods; no OpenGL/world run. */
public final class NativeObserverZoomProbe {
    private static void check(boolean value, String message) {
        if (!value) throw new AssertionError(message);
    }
    private static Field field(String name) throws Exception {
        Field value = StudyObserver.class.getDeclaredField(name);
        value.setAccessible(true);
        return value;
    }
    private static void command(Path path, String properties, boolean applied) throws Exception {
        long before = StudyObserver.commandSequence();
        long next = Math.max(before, field("rejectedSequence").getLong(null)) + 1;
        Files.writeString(path, "sequence=" + next + "\n" + properties);
        field("nextPoll").setLong(null, 0);
        StudyObserver.poll();
        check(StudyObserver.commandSequence() == (applied ? next : before),
            applied ? "native zoom command was not acknowledged" : "invalid zoom command acknowledged");
    }
    public static void run(Path control, SpeedControls speed) throws Exception {
        Core core = Core.getInstance();
        MultiTextureFBO2 buffer = core.offscreenBuffer;
        buffer.zoomEnabled = true;
        // Exercise an actual configured subset, not a copied list of defaults.
        buffer.setZoomLevelsFromOption("50;100;150;250");
        buffer.setZoomAndTargetZoom(0, 1);
        core.setAutoZoom(0, true);
        command(control, "paused=true\nspeed=3\n", true);
        GameTime time = GameTime.getInstance();
        time.setMultiplier(7); // Unrelated native owner must also survive zoom.
        Object player = IsoPlayer.getInstance(), camera = IsoCamera.getCameraCharacter();
        Object selected = field("selectedPersonId").get(null);
        float px = IsoPlayer.players[0].getX(), py = IsoPlayer.players[0].getY();
        float vx = IsoCamera.getCameraCharacter().getX(), vy = IsoCamera.getCameraCharacter().getY();
        double hours = time.getWorldAgeHours();
        int width = buffer.getWidth(0), height = buffer.getHeight(0);
        check(width > 0 && height > 0, "native projection dimensions unavailable");
        float next = core.getNextZoom(0, 1);
        check(next == 1.5f, "native zoom level oracle did not use the configured subset");
        for (String bad : new String[] {"zoomStep=0\n", "zoomStep=2\n", "zoomStep=NaN\n",
                "zoomStep=1\nspeed=1\n", "zoomStep=1\nselectedPersonId=sao-probe\n",
                "zoomStep=1\nviewX=40\n"}) {
            command(control, bad, false);
            check(buffer.getZoom(0) == 1 && buffer.getTargetZoom(0) == 1 && core.getAutoZoom(0),
                "invalid zoom command partially changed native view");
        }
        command(control, "zoomStep=1\n", true);
        check(buffer.getZoom(0) == next && buffer.getTargetZoom(0) == next
                && buffer.getWidth(0) > width && buffer.getHeight(0) > height,
            "native zoom did not enlarge rendered world projection");
        check(!core.getAutoZoom(0), "native automatic zoom can overwrite observer zoom");
        check(StudyObserver.snapshot().contains("\"viewport\":{\"zoom\":1.5,\"targetZoom\":1.5,\"zoomLevels\":[0.5, 1.0, 1.5, 2.5]}"),
            "observer viewport omitted actual configured native zoom");
        command(control, "zoomStep=-1\n", true);
        check(buffer.getZoom(0) == 1 && buffer.getWidth(0) == width && buffer.getHeight(0) == height,
            "native inverse zoom failed to restore projection");
        for (int index = 0; index < 8; index++) command(control, "zoomStep=1\n", true);
        check(buffer.getZoom(0) == 2.5f, "observer exceeded native maximum zoom");
        for (int index = 0; index < 8; index++) command(control, "zoomStep=-1\n", true);
        check(buffer.getZoom(0) == 0.5f, "observer exceeded native minimum zoom");
        check(GameTime.isGamePaused() && speed.getCurrentGameSpeed() == 0
                && time.getTrueMultiplier() == 7 && time.getWorldAgeHours() == hours,
            "zoom command changed native time owners");
        check(IsoPlayer.getInstance() == player && IsoCamera.getCameraCharacter() == camera
                && selected.equals(field("selectedPersonId").get(null))
                && IsoPlayer.players[0].getX() == px && IsoPlayer.players[0].getY() == py
                && IsoCamera.getCameraCharacter().getX() == vx && IsoCamera.getCameraCharacter().getY() == vy,
            "zoom command changed person, camera or residency owners");
        buffer.zoomEnabled = false;
        command(control, "zoomStep=1\n", false);
        check(buffer.getZoom(0) == 0.5f, "disabled native zoom was changed");
        buffer.zoomEnabled = true;
        command(control, "paused=false\n", true);
        check(speed.getCurrentGameSpeed() == 3 && time.getTrueMultiplier() == 20,
            "zoom command changed paused native speed intent");
        command(control, "zoomStep=1\n", true);
        check(speed.getCurrentGameSpeed() == 3 && time.getTrueMultiplier() == 20,
            "zoom command changed native time owners");
        System.out.println("PASS native observer zoom: installed configured levels and projection dimensions; "
            + "out/in/bounds; invalid, mixed and disabled rejection; pause/speed/person/coordinate ownership. "
            + "No rendered-world or expanded-residency claim.");
    }
}
