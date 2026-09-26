import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.ByteArrayInputStream;
import java.io.PrintStream;
import java.lang.reflect.Field;
import java.nio.ByteBuffer;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.security.MessageDigest;
import java.util.Arrays;
import java.util.HexFormat;
import java.util.Set;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.zip.CRC32;
import java.util.zip.DeflaterOutputStream;
import java.util.zip.InflaterInputStream;
import javax.imageio.ImageIO;
import com.sun.nio.file.ExtendedOpenOption;

/** Calls the production capture-completion boundary, without game/GL startup. */
public final class NativeViewCaptureProbe {
    private static Path screenshots, publication;
    private static long sequence;
    private static int cases;

    private static void check(boolean value, String message) {
        if (!value) throw new AssertionError(message);
    }

    private static void capture(byte[] bytes, String label, boolean accepted) throws Exception {
        capture(bytes, label, accepted, StudyObserver.commandSequence());
    }

    private static void capture(byte[] bytes, String label, boolean accepted, long frameSequence) throws Exception {
        Path manifest = publication.resolve("native.json");
        byte[] previous = Files.isRegularFile(manifest) ? Files.readAllBytes(manifest) : null;
        String filename = seedCapture(bytes, frameSequence);
        StudyViewCapture.completed(filename);
        check(StudyViewCapture.pending == null, label + " left the capture pending");
        boolean published = Files.isRegularFile(publication.resolve(filename));
        if (accepted) {
            check(published && Files.isRegularFile(manifest), label + " was rejected");
            check(Arrays.equals(bytes, Files.readAllBytes(publication.resolve(filename))), label + " pixels changed");
            String sha = HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes));
            check(Files.readString(manifest).contains("\"sha256\":\"" + sha + "\""), label + " hash differs");
            check(Files.readString(manifest).contains("\"observerSequence\":" + frameSequence + ","),
                label + " lacks exact observer command binding");
            check(Files.readString(manifest).contains("\"hours\":42.5,"), label + " lost rendered frame time");
        } else {
            check(!published, label + " capture was published");
            check(previous != null && Arrays.equals(previous, Files.readAllBytes(manifest)), label + " replaced the valid manifest");
            if (frameSequence == StudyObserver.commandSequence())
                check(Files.isRegularFile(screenshots.resolve(filename)), label + " consumed invalid source");
            else check(!Files.exists(screenshots.resolve(filename)), label + " retained stale capture bytes");
        }
        cases++;
    }

    private static String seedCapture(byte[] bytes, long frameSequence) throws Exception {
        String filename = StudyViewCapture.PREFIX + String.format("%016d", ++sequence) + ".png";
        Files.write(screenshots.resolve(filename), bytes);
        StudyViewCapture.sequence = sequence;
        // A synthetic already-rendered frame receipt; no GL/rendering is being
        // claimed by this publication-boundary fixture.
        Field pendingFrame = StudyViewCapture.class.getDeclaredField("pendingFrame");
        pendingFrame.setAccessible(true);
        pendingFrame.set(null, new StudyViewCapture.FrameStamp(frameSequence, 42.5));
        StudyViewCapture.pending = filename;
        return filename;
    }

    private static void publicationLocks(byte[] valid) throws Exception {
        check(System.getProperty("os.name").startsWith("Windows"), "Windows publication lock probe requires Windows");
        Path manifest = publication.resolve("native.json");
        Field deferrals = StudyViewCapture.class.getDeclaredField("publicationDeferrals");
        deferrals.setAccessible(true);
        Field maximum = StudyViewCapture.class.getDeclaredField("MAX_PUBLICATION_DEFERRALS");
        maximum.setAccessible(true);
        int limit = maximum.getInt(null);
        check(limit > 1 && limit <= 30, "publication deferral limit is unbounded");
        // NOSHARE_DELETE exercises the actual Windows replacement failure, not
        // a mocked Files.move. A fresh frame after close must recover normally.
        for (int episode : new int[] {1, limit}) {
            byte[] accepted = Files.readAllBytes(manifest);
            Set<Path> acceptedImages;
            try (var files = Files.list(publication)) {
                acceptedImages = Set.copyOf(files.filter(path -> path.toString().endsWith(".png")).toList());
            }
            try (var reader = Files.newByteChannel(manifest,
                    Set.of(StandardOpenOption.READ, ExtendedOpenOption.NOSHARE_DELETE))) {
                check(reader.isOpen(), "publication reader did not open");
                for (int i = 1; i <= episode; i++) {
                    String filename = seedCapture(valid, StudyObserver.commandSequence());
                    ByteArrayOutputStream logged = new ByteArrayOutputStream();
                    PrintStream previousError = System.err;
                    try (var errors = new PrintStream(logged)) {
                        System.setErr(errors);
                        try { StudyViewCapture.completed(filename); }
                        finally { System.setErr(previousError); }
                    }
                    String error = logged.toString(java.nio.charset.StandardCharsets.UTF_8);
                    if (i < limit) check(error.isEmpty(), "transient publication denial poisoned the run: " + error);
                    else check(error.contains("[StudyView] capture failed: java.nio.file.AccessDeniedException"),
                        "persistent publication denial was hidden");
                    check(StudyViewCapture.pending == null, "publication denial blocked later captures");
                    check(Arrays.equals(accepted, Files.readAllBytes(manifest)), "denied publication replaced the accepted manifest");
                    check(!Files.exists(publication.resolve(filename)), "denied publication retained an unpublished candidate");
                    check(!Files.exists(publication.resolve("native.json.tmp")), "denied publication retained staging data");
                    check(acceptedImages.stream().allMatch(Files::isRegularFile), "denied publication removed an accepted image");
                    cases++;
                }
            }
            capture(valid, "publication recovery", true);
            check(deferrals.getInt(null) == 0, "successful publication did not reset deferrals");
        }
    }

    private static void asynchronousPixels() throws Exception {
        byte[] rgb = {(byte)255,0,0, 0,(byte)255,0, 0,0,(byte)255, (byte)255,(byte)255,(byte)255};
        BufferedImage expected = StudyViewCapture.encodePixels(2, 2, rgb);
        check((expected.getRGB(0,0) & 0xffffff) == 0x0000ff
            && (expected.getRGB(1,0) & 0xffffff) == 0xffffff
            && (expected.getRGB(0,1) & 0xffffff) == 0xff0000
            && (expected.getRGB(1,1) & 0xffffff) == 0x00ff00,
            "native RGB orientation or color changed");
        boolean refused = false;
        try { StudyViewCapture.encodePixels(3,2,rgb); }
        catch (IllegalArgumentException error) { refused = true; }
        check(refused, "mismatched raw pixel dimensions accepted");
        Field executorField = StudyViewCapture.class.getDeclaredField("PUBLICATION");
        executorField.setAccessible(true);
        ExecutorService executor = (ExecutorService) executorField.get(null);
        CountDownLatch held = new CountDownLatch(1), entered = new CountDownLatch(1);
        executor.execute(() -> {
            entered.countDown();
            try { held.await(5, TimeUnit.SECONDS); }
            catch (InterruptedException error) { Thread.currentThread().interrupt(); }
        });
        check(entered.await(2,TimeUnit.SECONDS), "publication worker did not start");
        var frame = new StudyViewCapture.FrameStamp(StudyObserver.commandSequence(),42.5);
        long capturedBefore = System.currentTimeMillis();
        check(StudyViewCapture.beginCapture(frame,capturedBefore), "first asynchronous capture refused");
        String filename = StudyViewCapture.pending;
        StudyViewCapture.submitPixels(2,2,rgb);
        check(filename.equals(StudyViewCapture.pending), "background publication did not retain one pending frame");
        check(!StudyViewCapture.beginCapture(frame,capturedBefore+1000), "busy publisher admitted another capture");
        Thread.sleep(80);
        long releasedAt = System.currentTimeMillis();
        held.countDown();
        long deadline = System.nanoTime()+TimeUnit.SECONDS.toNanos(5);
        while (StudyViewCapture.pending != null && System.nanoTime()<deadline) Thread.sleep(10);
        check(StudyViewCapture.pending == null, "asynchronous publication did not finish");
        BufferedImage actual = ImageIO.read(publication.resolve(filename).toFile());
        check(actual.getRGB(0,0)==expected.getRGB(0,0), "asynchronous publication changed pixels");
        String manifest = Files.readString(publication.resolve("native.json"));
        long timestamp = Long.parseLong(manifest.split("\\\"capturedAtUnixMs\\\":")[1].split(",")[0]);
        check(timestamp >= capturedBefore && timestamp < releasedAt, "capture timestamp describes encoding completion");
        cases++;
    }

    private static byte[] chunk(int type, byte[] bytes) {
        ByteBuffer output = ByteBuffer.allocate(bytes.length + 12);
        output.putInt(bytes.length).putInt(type).put(bytes);
        CRC32 crc = new CRC32(); crc.update(output.array(), 4, bytes.length + 4);
        output.putInt((int) crc.getValue());
        return output.array();
    }

    private static byte[] idat(byte[] png) throws Exception {
        ByteBuffer data = ByteBuffer.wrap(png);
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        for (int offset = 8; offset < png.length;) {
            int length = data.getInt(offset);
            if (data.getInt(offset + 4) == 0x49444154) output.write(png, offset + 8, length);
            offset += length + 12;
        }
        return output.toByteArray();
    }

    private static byte[] replaceIdat(byte[] png, byte[] replacement) throws Exception {
        ByteBuffer data = ByteBuffer.wrap(png);
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        output.write(png, 0, 8);
        boolean written = false;
        for (int offset = 8; offset < png.length;) {
            int length = data.getInt(offset);
            if (data.getInt(offset + 4) == 0x49444154) {
                if (!written) output.write(chunk(0x49444154, replacement));
                written = true;
            } else output.write(png, offset, length + 12);
            offset += length + 12;
        }
        return output.toByteArray();
    }

    public static void main(String[] args) throws Exception {
        zombie.core.random.RandStandard.INSTANCE.init();
        zombie.ZomboidFileSystem.instance.init();
        screenshots = Path.of(zombie.ZomboidFileSystem.instance.getScreenshotDir());
        publication = Files.createTempDirectory(Path.of(System.getProperty("user.home")), "view-publication-");
        Files.createDirectories(screenshots);
        Files.createDirectories(publication);
        System.setProperty("study.viewDirectory", publication.toString());
        Field applied = StudyObserver.class.getDeclaredField("sequence"); applied.setAccessible(true);
        applied.setLong(null, 17);
        BufferedImage image = new BufferedImage(7, 5, BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < image.getHeight(); y++) for (int x = 0; x < image.getWidth(); x++)
            image.setRGB(x, y, 0xff000000 | x * 31 << 16 | y * 47 << 8 | (x + y) * 17);
        ByteArrayOutputStream encoded = new ByteArrayOutputStream();
        check(ImageIO.write(image, "png", encoded), "PNG fixture encoder unavailable");
        image.flush();
        byte[] valid = encoded.toByteArray();
        capture(valid, "valid PNG", true);
        capture(Arrays.copyOf(valid, 24), "24-byte header", false);
        capture(Arrays.copyOf(valid, 33), "header without pixels", false);
        capture(Arrays.copyOf(valid, valid.length - 12), "missing IEND", false);
        capture(Arrays.copyOf(valid, valid.length - 1), "truncated IEND", false);
        capture(replaceIdat(valid, new byte[] {0, 0, 0, 0}), "invalid compressed pixels", false);
        byte[] compressed = idat(valid);
        capture(replaceIdat(valid, Arrays.copyOf(compressed, compressed.length / 2)), "truncated compressed pixels", false);
        capture(replaceIdat(valid, Arrays.copyOf(compressed, compressed.length - 1)), "truncated zlib checksum", false);
        byte[] raw;
        try (var input = new InflaterInputStream(new ByteArrayInputStream(compressed))) { raw = input.readAllBytes(); }
        raw[0] = 5; // A complete checksummed stream with an invalid PNG row filter.
        ByteArrayOutputStream invalidFilter = new ByteArrayOutputStream();
        try (var deflate = new DeflaterOutputStream(invalidFilter)) { deflate.write(raw); }
        capture(replaceIdat(valid, invalidFilter.toByteArray()), "invalid decoded filter", false);
        byte[] corrupt = valid.clone(); corrupt[29] ^= 1;
        capture(corrupt, "invalid chunk checksum", false);
        capture(Arrays.copyOf(valid, valid.length + 1), "trailing data", false);
        byte[] oversized = valid.clone();
        ByteBuffer.wrap(oversized).putInt(16, Integer.MAX_VALUE);
        byte[] header = chunk(0x49484452, Arrays.copyOfRange(oversized, 16, 29));
        System.arraycopy(header, 0, oversized, 8, header.length);
        capture(oversized, "oversized dimensions", false);
        capture(valid, "stale observer command", false, 16);
        if (args.length > 0) capture(Files.readAllBytes(Path.of(args[0])), "native screenshot", true);
        for (int i = 0; i < 12; i++) {
            capture(valid, "gapped valid " + i, true);
            capture(valid, "gapped stale " + i, false, 16);
        }
        try (var files = Files.list(publication)) {
            check(files.filter(path -> path.getFileName().toString().matches("study-live-[0-9]{16}\\.png")).count() == 8,
                "published image retention exceeded 8 after sequence gaps");
        }
        publicationLocks(valid);
        asynchronousPixels();
        System.out.println("PASS capture PNG publication: " + cases + " cases; complete image decode, bounded dimensions, framing/checksums, exact command binding and Windows denial/recovery; invalid/stale files preserve prior frame. No native renderer run.");
    }
}
