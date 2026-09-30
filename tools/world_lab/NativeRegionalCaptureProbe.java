import java.awt.image.BufferedImage;
import java.lang.reflect.Field;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.util.HexFormat;
import javax.imageio.ImageIO;

/** Capture-publication fixture only. No renderer, game window or world loop. */
public final class NativeRegionalCaptureProbe {
    private static void check(boolean value, String why) { if (!value) throw new AssertionError(why); }
    public static void main(String[] args) throws Exception {
        zombie.core.random.RandStandard.INSTANCE.init();
        zombie.ZomboidFileSystem.instance.init();
        Path root = Files.createTempDirectory(Path.of(System.getProperty("user.home")), "regional-capture-");
        Path screenshots = Path.of(zombie.ZomboidFileSystem.instance.getScreenshotDir());
        Files.createDirectories(screenshots);
        System.setProperty("study.viewDirectory", root.toString());
        Field sequence = StudyObserver.class.getDeclaredField("sequence"); sequence.setAccessible(true); sequence.setLong(null, 17);
        int[] colors = {0xffff0000, 0xff0000ff, 0xff00ff00};
        BufferedImage image = new BufferedImage(8, 8, BufferedImage.TYPE_INT_RGB);
        for (int y = 0; y < 8; y++) for (int x = 0; x < 8; x++) image.setRGB(x, y, colors[y < 4 ? (x < 4 ? 0 : 1) : 2]);
        String name = "study-live-0000000000000001.png";
        StudyViewCapture.writePng(image, screenshots.resolve(name));
        StudyObserver.SiteFrame[] sites = {
            new StudyObserver.SiteFrame("residential", "Residential", 0, 64, 64, 0, 0, 0, 4, 4),
            new StudyObserver.SiteFrame("services", "Services", 1, 192, 64, 0, 4, 0, 4, 4),
            new StudyObserver.SiteFrame("farm", "Farm", 2, 320, 64, 0, 0, 4, 4, 4)};
        Field stamp = StudyViewCapture.class.getDeclaredField("pendingFrame"); stamp.setAccessible(true);
        stamp.set(null, new StudyViewCapture.FrameStamp(17, 42.5, sites));
        StudyViewCapture.sequence = 1; StudyViewCapture.pending = name;
        StudyViewCapture.completed(name);
        String manifest = Files.readString(root.resolve("native.json"));
        check(manifest.contains("\"hours\":42.5") && manifest.contains("\"observerSequence\":17"), "regional capture lost shared rendered clock");
        for (int index = 0; index < 3; index++) {
            Path path = root.resolve(name.replace(".png", "-site" + index + ".png"));
            BufferedImage crop = ImageIO.read(path.toFile());
            check(crop.getWidth() == 4 && crop.getHeight() == 4 && crop.getRGB(0, 0) == colors[index],
                "regional capture reused another viewport pixels");
            String hash = HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(Files.readAllBytes(path)));
            check(manifest.contains(hash) && manifest.contains("\"id\":\"" + sites[index].id() + "\""), "regional capture hash or site seal differs");
        }
        String stale = "study-live-0000000000000002.png";
        StudyViewCapture.writePng(image, screenshots.resolve(stale));
        stamp.set(null, new StudyViewCapture.FrameStamp(16, 42.5, sites));
        StudyViewCapture.sequence = 2; StudyViewCapture.pending = stale; StudyViewCapture.completed(stale);
        check(Files.readString(root.resolve("native.json")).equals(manifest), "stale region capture replaced current clock/pixels");
        System.out.println("PASS sealed regional crops retain distinct actual framebuffer rectangles and one command/clock; stale frame rejected");
    }
}
