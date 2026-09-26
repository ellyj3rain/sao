import java.lang.instrument.Instrumentation;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.file.AccessDeniedException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.security.MessageDigest;
import java.util.HexFormat;
import java.util.Collections;
import java.util.IdentityHashMap;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.zip.CRC32;
import java.util.zip.DataFormatException;
import java.util.zip.Inflater;
import javax.imageio.ImageIO;
import javax.imageio.IIOImage;
import javax.imageio.ImageReader;
import javax.imageio.ImageWriteParam;
import javax.imageio.ImageWriter;
import javax.imageio.stream.MemoryCacheImageInputStream;
import javax.imageio.stream.MemoryCacheImageOutputStream;
import net.bytebuddy.agent.builder.AgentBuilder;
import net.bytebuddy.ByteBuddy;
import net.bytebuddy.asm.Advice;
import net.bytebuddy.matcher.ElementMatchers;
import org.lwjgl.opengl.GL11;
import org.lwjglx.opengl.Display;

/** Publishes completed native framebuffer captures, never reconstructed tiles.
 * Capture time and simulation observation time are deliberately separate.
 */
public final class StudyViewCapture {
    public static volatile String pending;
    public static long nextCapture;
    public static long sequence;
    public static final String PREFIX = "study-live-";
    private static final int MAX_CAPTURE_BYTES = 16 * 1024 * 1024;
    private static final int MAX_PUBLICATION_DEFERRALS = 30;
    private static int publicationDeferrals;
    private static final long CAPTURE_INTERVAL_MS = 50;
    private static final ExecutorService PUBLICATION = Executors.newSingleThreadExecutor(task -> {
        Thread worker = new Thread(task, "StudyViewPublication");
        worker.setDaemon(true);
        return worker;
    });
    private static ByteBuffer captureBuffer;
    record FrameStamp(long observerSequence, double hours) { }
    private static final Map<Object, FrameStamp> FRAMES = Collections.synchronizedMap(new IdentityHashMap<>());
    private static final ThreadLocal<FrameStamp> RENDERED = new ThreadLocal<>();
    private static volatile FrameStamp pendingFrame;
    private static volatile long pendingCapturedAt;

    public static void install(Instrumentation instrumentation) {
        if (System.getProperty("study.viewDirectory") == null) return;
        new AgentBuilder.Default(new ByteBuddy().ignore(ElementMatchers.none())).disableClassFormatChanges()
            .with(AgentBuilder.RedefinitionStrategy.RETRANSFORMATION)
            .with(AgentBuilder.Listener.StreamWriting.toSystemError().withErrorsOnly())
            .type(ElementMatchers.named("zombie.core.sprite.SpriteRenderState"))
            .transform((builder, type, loader, module, domain) -> builder.visit(
                Advice.to(FrameReady.class).on(ElementMatchers.named("onReady"))))
            .installOn(instrumentation);
        new AgentBuilder.Default(new ByteBuddy().ignore(ElementMatchers.none())).disableClassFormatChanges()
            .with(AgentBuilder.RedefinitionStrategy.RETRANSFORMATION)
            .with(AgentBuilder.Listener.StreamWriting.toSystemError().withErrorsOnly())
            .type(ElementMatchers.named("zombie.core.SpriteRenderer"))
            .transform((builder, type, loader, module, domain) -> builder.visit(
                Advice.to(RenderFrame.class).on(ElementMatchers.named("postRender"))))
            .installOn(instrumentation);
        new AgentBuilder.Default(new ByteBuddy().ignore(ElementMatchers.none())).disableClassFormatChanges()
            .with(AgentBuilder.RedefinitionStrategy.RETRANSFORMATION)
            .with(AgentBuilder.Listener.StreamWriting.toSystemError().withErrorsOnly())
            .type(ElementMatchers.named("org.lwjglx.opengl.Display"))
            .transform((builder, type, loader, module, domain) -> builder.visit(
                Advice.to(Swapped.class).on(ElementMatchers.named("update")
                    .and(ElementMatchers.takesArguments(boolean.class)))))
            .installOn(instrumentation);
        new AgentBuilder.Default(new ByteBuddy().ignore(ElementMatchers.none())).disableClassFormatChanges()
            .with(AgentBuilder.RedefinitionStrategy.RETRANSFORMATION)
            .with(AgentBuilder.Listener.StreamWriting.toSystemError().withErrorsOnly())
            .type(ElementMatchers.named("zombie.core.Core"))
            .transform((builder, type, loader, module, domain) -> builder.visit(
                Advice.to(Completed.class).on(ElementMatchers.named("lambda$TakeFullScreenshot$0"))))
            .installOn(instrumentation);
    }

    public static void frameReady(Object frame) {
        FRAMES.remove(frame);
        zombie.characters.IsoPlayer anchor = zombie.characters.IsoPlayer.players[0];
        if (anchor == null || !Boolean.TRUE.equals(anchor.getModData().rawget("SAO_ObserverAnchor"))
                || !Boolean.TRUE.equals(anchor.getModData().rawget("SAO_ObserverStarted"))) return;
        // Game thread: camera and draw buffers are already populated for this
        // exact native state. Do not infer its command from a later timestamp.
        FRAMES.put(frame, new FrameStamp(StudyObserver.commandSequence(),
            zombie.GameTime.getInstance().getWorldAgeHours()));
    }

    public static void rendering() {
        var state = zombie.core.SpriteRenderer.instance.getRenderingState();
        FrameStamp frame = FRAMES.remove(state);
        RENDERED.set(state.numSprites > 0 ? frame : null);
    }

    public static void rendered(Throwable failure) {
        if (failure != null) RENDERED.remove();
    }

    public static void swapped(Throwable failure) {
        FrameStamp frame = RENDERED.get();
        RENDERED.remove();
        if (failure != null || frame == null) return;
        request(frame);
    }

    private static void request(FrameStamp frame) {
        long now = System.currentTimeMillis();
        if (!beginCapture(frame, now)) return;
        // The installed Core.TakeFullScreenshot reads this same GL_FRONT after
        // swap, but also converts, compresses and writes PNG on the render
        // thread. Only pixel readback belongs here. One pending frame bounds
        // background work; a busy publisher drops captures before GPU readback.
        try {
            readPixels();
        } catch (RuntimeException failure) {
            pendingFrame = null; pendingCapturedAt = 0; pending = null;
            System.err.println("[StudyView] capture request failed: " + failure);
        }
    }

    static boolean beginCapture(FrameStamp frame, long now) {
        if (pending != null || now < nextCapture || zombie.GameWindow.closeRequested
                || frame.observerSequence() != StudyObserver.commandSequence()) return false;
        nextCapture = now + CAPTURE_INTERVAL_MS;
        pendingFrame = frame;
        pending = PREFIX + String.format("%016d", ++sequence) + ".png";
        return true;
    }

    private static void readPixels() {
        int width = Display.getDisplayMode().getWidth();
        int height = Display.getDisplayMode().getHeight();
        if (width < 1 || width > 4096 || height < 1 || height > 2160)
            throw new IllegalStateException("capture dimensions invalid");
        int length = Math.multiplyExact(Math.multiplyExact(width, height), 3);
        if (captureBuffer == null || captureBuffer.capacity() != length)
            captureBuffer = ByteBuffer.allocateDirect(length);
        captureBuffer.clear();
        int alignment = GL11.glGetInteger(GL11.GL_PACK_ALIGNMENT);
        int readBuffer = GL11.glGetInteger(GL11.GL_READ_BUFFER);
        try {
            GL11.glPixelStorei(GL11.GL_PACK_ALIGNMENT, 1);
            GL11.glReadBuffer(GL11.GL_FRONT);
            GL11.glReadPixels(0, 0, width, height, GL11.GL_RGB, GL11.GL_UNSIGNED_BYTE, captureBuffer);
        } finally {
            GL11.glReadBuffer(readBuffer);
            GL11.glPixelStorei(GL11.GL_PACK_ALIGNMENT, alignment);
        }
        byte[] pixels = new byte[length];
        captureBuffer.rewind();
        captureBuffer.get(pixels);
        submitPixels(width, height, pixels);
    }

    static void submitPixels(int width, int height, byte[] pixels) {
        pendingCapturedAt = System.currentTimeMillis();
        String filename = pending;
        PUBLICATION.execute(() -> publishPixels(filename, width, height, pixels));
    }

    static void publishPixels(String filename, int width, int height, byte[] pixels) {
        try {
            if (pendingFrame == null || pendingFrame.observerSequence() != StudyObserver.commandSequence()) return;
            BufferedImage image = encodePixels(width, height, pixels);
            Path source = Path.of(zombie.ZomboidFileSystem.instance.getScreenshotDir(), filename);
            Files.createDirectories(source.getParent());
            writePng(image, source);
            completed(filename);
        } catch (Exception failure) {
            System.err.println("[StudyView] capture publication failed: " + failure);
        } finally {
            // Publish availability last: the render thread may immediately
            // begin another frame after observing this volatile null.
            if (filename.equals(pending)) {
                pendingFrame = null; pendingCapturedAt = 0; pending = null;
            }
        }
    }

    static BufferedImage encodePixels(int width, int height, byte[] pixels) {
        if (width < 1 || width > 4096 || height < 1 || height > 2160
                || pixels.length != Math.multiplyExact(Math.multiplyExact(width, height), 3))
            throw new IllegalArgumentException("capture pixels differ from dimensions");
        BufferedImage image = new BufferedImage(width, height, BufferedImage.TYPE_INT_RGB);
        int[] row = new int[width];
        for (int y = 0; y < height; y++) {
            int offset = (height - y - 1) * width * 3;
            for (int x = 0; x < width; x++, offset += 3)
                row[x] = (pixels[offset] & 255) << 16 | (pixels[offset + 1] & 255) << 8 | (pixels[offset + 2] & 255);
            image.setRGB(0, y, width, 1, row, 0, width);
        }
        return image;
    }

    static void writePng(BufferedImage image, Path target) throws IOException {
        var writers = ImageIO.getImageWritersByFormatName("png");
        if (!writers.hasNext()) throw new IOException("PNG encoder unavailable");
        ImageWriter writer = writers.next();
        try (var bytes = Files.newOutputStream(target);
             var output = new MemoryCacheImageOutputStream(bytes)) {
            writer.setOutput(output);
            ImageWriteParam parameters = writer.getDefaultWriteParam();
            parameters.setCompressionMode(ImageWriteParam.MODE_EXPLICIT);
            // PNG remains lossless. Stored deflate blocks avoid spending the
            // frame budget compressing a local 960x540 framebuffer; framing,
            // checksums, full decode and the existing size bound still apply.
            parameters.setCompressionQuality(1.0f);
            writer.write(null, new IIOImage(image, null, null), parameters);
        } finally { writer.dispose(); }
    }

    public static void completed(String filename) {
        if (filename == null || !filename.equals(pending)) return;
        try {
            Path source = Path.of(zombie.ZomboidFileSystem.instance.getScreenshotDir(), filename);
            FrameStamp frame = pendingFrame;
            if (frame == null || frame.observerSequence() != StudyObserver.commandSequence()) {
                Files.deleteIfExists(source);
                return;
            }
            long length = Files.size(source);
            if (length < 33 || length > MAX_CAPTURE_BYTES) throw new IOException("capture size invalid");
            byte[] bytes;
            try (var input = Files.newInputStream(source)) { bytes = input.readNBytes(MAX_CAPTURE_BYTES + 1); }
            if (bytes.length != length) throw new IOException("capture changed while reading");
            int[] dimensions = validatePng(bytes);
            int width = dimensions[0], height = dimensions[1];
            Path root = Path.of(System.getProperty("study.viewDirectory"));
            Files.createDirectories(root);
            Path target = root.resolve(filename);
            String sha = HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes));
            String manifest = "{\"schema\":\"sao-native-viewport/1\",\"sequence\":" + sequence
                + ",\"observerSequence\":" + frame.observerSequence()
                + ",\"capturedAtUnixMs\":" + (pendingCapturedAt > 0 ? pendingCapturedAt : System.currentTimeMillis())
                + ",\"hours\":" + frame.hours()
                + ",\"image\":{\"file\":\"" + filename + "\",\"sha256\":\"" + sha
                + "\",\"width\":" + width + ",\"height\":" + height + "}}\n";
            Path temporary = root.resolve("native.json.tmp");
            // Pair with the observer command's commit monitor. A command that
            // changed during rendering, readback or decoding cannot relabel the
            // captured pixels, or replace the last accepted native frame.
            synchronized (StudyObserver.class) {
                if (frame.observerSequence() != StudyObserver.commandSequence()) {
                    Files.deleteIfExists(source);
                    return;
                }
                Files.move(source, target, StandardCopyOption.REPLACE_EXISTING);
                Files.writeString(temporary, manifest);
                if (!publishManifest(temporary, root.resolve("native.json"), target)) return;
            }
            retainPublished(root);
        } catch (Exception error) {
            System.err.println("[StudyView] capture failed: " + error);
        } finally {
            pendingFrame = null;
            pendingCapturedAt = 0;
            pending = null;
        }
    }

    private static boolean publishManifest(Path temporary, Path manifest, Path candidate) throws IOException {
        try {
            Files.move(temporary, manifest, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING);
        } catch (AccessDeniedException inUse) {
            // Windows readers may briefly deny replacement. Keep their accepted
            // image/manifest pair, discard this unpublished candidate and let the
            // unchanged capture cadence retry with a current rendered frame.
            // Never sleep while holding the render thread or command monitor.
            Files.deleteIfExists(candidate);
            Files.deleteIfExists(temporary);
            publicationDeferrals = Math.min(MAX_PUBLICATION_DEFERRALS, publicationDeferrals + 1);
            if (publicationDeferrals >= MAX_PUBLICATION_DEFERRALS) throw inUse;
            if (publicationDeferrals == 1)
                System.out.println("[StudyView] publication deferred while manifest is in use; retaining previous frame");
            return false;
        }
        if (publicationDeferrals != 0)
            System.out.println("[StudyView] publication resumed after " + publicationDeferrals + " deferred frames");
        publicationDeferrals = 0;
        return true;
    }

    private static void retainPublished(Path root) throws IOException {
        // Rejected/stale captures leave sequence gaps. Retain eight published
        // images, rather than deleting only one possibly absent N-8 filename.
        try (var files = Files.list(root)) {
            for (Path old : files.filter(path -> path.getFileName().toString().matches("study-live-[0-9]{16}\\.png"))
                    .sorted((left, right) -> right.getFileName().toString().compareTo(left.getFileName().toString()))
                    .skip(8).toList()) Files.deleteIfExists(old);
        }
    }

    /** Bound allocations before decoding, and require the complete PNG stream.
     * ImageIO can finish pixels before seeing IEND, so framing/CRC validation is
     * separate from actual image decoding. Header checks alone prove neither.
     */
    static int[] validatePng(byte[] bytes) throws IOException {
        if (bytes.length < 33 || bytes.length > MAX_CAPTURE_BYTES) throw new IOException("capture size invalid");
        ByteBuffer png = ByteBuffer.wrap(bytes);
        if (png.getLong(0) != 0x89504e470d0a1a0aL || png.getInt(8) != 13 || png.getInt(12) != 0x49484452)
            throw new IOException("capture PNG header invalid");
        int width = png.getInt(16), height = png.getInt(20);
        if (width < 1 || height < 1 || width > 4096 || height > 2160)
            throw new IOException("capture dimensions invalid");
        long expected = scanlineBytes(bytes, width, height), inflated = 0;
        boolean data = false, end = false, afterData = false;
        Inflater inflater = new Inflater();
        byte[] block = new byte[8192];
        try {
            for (int offset = 8; offset < bytes.length;) {
                if (bytes.length - offset < 12) throw new IOException("capture PNG chunk truncated");
                int length = png.getInt(offset), type = png.getInt(offset + 4);
                if (length < 0 || length > bytes.length - offset - 12)
                    throw new IOException("capture PNG chunk length invalid");
                if (offset != 8 && type == 0x49484452) throw new IOException("capture PNG header duplicated");
                CRC32 crc = new CRC32();
                crc.update(bytes, offset + 4, length + 4);
                if (crc.getValue() != Integer.toUnsignedLong(png.getInt(offset + 8 + length)))
                    throw new IOException("capture PNG checksum invalid");
                int next = offset + length + 12;
                if (type == 0x49444154) {
                    if (afterData || (inflater.finished() && length != 0))
                        throw new IOException("capture PNG pixel stream has trailing data");
                    data = true;
                    inflater.setInput(bytes, offset + 8, length);
                    while (!inflater.finished() && !inflater.needsInput()) {
                        int count = inflater.inflate(block);
                        inflated += count;
                        if (inflated > expected) throw new IOException("capture PNG pixel stream exceeds dimensions");
                        if (count == 0 && !inflater.finished() && !inflater.needsInput())
                            throw new IOException("capture PNG pixel stream stalled or requires a dictionary");
                    }
                    if (inflater.getRemaining() != 0) throw new IOException("capture PNG pixel stream has trailing data");
                } else if (data) afterData = true;
                if (type == 0x49454e44) {
                    if (length != 0 || !data || next != bytes.length)
                        throw new IOException("capture PNG ending invalid");
                    end = true;
                    break;
                }
                offset = next;
            }
            if (!end) throw new IOException("capture PNG ending missing");
            // ImageIO can return all pixels without consuming the zlib trailer.
            // Require the native stream's checksum/end and exact scanline size.
            if (!inflater.finished() || inflated != expected)
                throw new IOException("capture PNG pixel stream incomplete");
        } catch (DataFormatException invalid) {
            throw new IOException("capture PNG compressed pixels invalid", invalid);
        } finally { inflater.end(); }
        var readers = ImageIO.getImageReadersByFormatName("png");
        if (!readers.hasNext()) throw new IOException("PNG decoder unavailable");
        ImageReader reader = readers.next();
        try (var input = new MemoryCacheImageInputStream(new ByteArrayInputStream(bytes))) {
            reader.setInput(input, true, true); // Skip ancillary metadata, including compressed text/profile data.
            if (reader.getWidth(0) != width || reader.getHeight(0) != height)
                throw new IOException("decoded capture dimensions differ");
            String[] warning = {null};
            reader.addIIOReadWarningListener((source, message) -> warning[0] = message);
            BufferedImage image = reader.read(0);
            if (image == null) throw new IOException("capture PNG could not be decoded");
            try {
                if (image.getWidth() != width || image.getHeight() != height || warning[0] != null)
                    throw new IOException("capture PNG decode incomplete: " + warning[0]);
            } finally { image.flush(); }
        } finally { reader.dispose(); }
        return new int[] {width, height};
    }

    private static long scanlineBytes(byte[] png, int width, int height) throws IOException {
        int depth = Byte.toUnsignedInt(png[24]), color = Byte.toUnsignedInt(png[25]);
        int channels = switch (color) { case 0, 3 -> 1; case 2 -> 3; case 4 -> 2; case 6 -> 4; default -> 0; };
        boolean validDepth = depth == 1 || depth == 2 || depth == 4 || depth == 8 || depth == 16;
        if (channels == 0 || !validDepth || (color == 3 && depth == 16)
                || (color != 0 && color != 3 && depth < 8) || png[26] != 0 || png[27] != 0
                || (png[28] != 0 && png[28] != 1)) throw new IOException("capture PNG format invalid");
        if (png[28] == 0) return (1 + ((long) width * channels * depth + 7) / 8) * height;
        int[] xs = {0, 4, 0, 2, 0, 1, 0}, ys = {0, 0, 4, 0, 2, 0, 1};
        int[] dx = {8, 8, 4, 4, 2, 2, 1}, dy = {8, 8, 8, 4, 4, 2, 2};
        long total = 0;
        for (int pass = 0; pass < 7; pass++) {
            int w = Math.max(0, (width - xs[pass] + dx[pass] - 1) / dx[pass]);
            int h = Math.max(0, (height - ys[pass] + dy[pass] - 1) / dy[pass]);
            if (w != 0 && h != 0) total += (1 + ((long) w * channels * depth + 7) / 8) * h;
        }
        return total;
    }

    public static final class FrameReady {
        @Advice.OnMethodExit public static void exit(@Advice.This Object frame) { StudyViewCapture.frameReady(frame); }
    }

    public static final class RenderFrame {
        @Advice.OnMethodEnter public static void enter() { StudyViewCapture.rendering(); }
        @Advice.OnMethodExit(onThrowable = Throwable.class)
        public static void exit(@Advice.Thrown Throwable failure) { StudyViewCapture.rendered(failure); }
    }

    public static final class Swapped {
        @Advice.OnMethodExit(onThrowable = Throwable.class)
        public static void exit(@Advice.Thrown Throwable failure) { StudyViewCapture.swapped(failure); }
    }

    public static final class Completed {
        @Advice.OnMethodExit public static void exit(@Advice.Argument(0) String filename) {
            StudyViewCapture.completed(filename);
        }
    }
}
