import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.security.MessageDigest;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HexFormat;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicLong;
import java.util.concurrent.atomic.AtomicReference;
import java.util.concurrent.locks.LockSupport;
import java.util.concurrent.locks.ReentrantLock;
import org.lwjgl.opengl.GL;
import org.lwjgl.opengl.GL11;
import org.lwjgl.opengl.GL15;
import org.lwjgl.opengl.GL21;
import org.lwjgl.opengl.GL32;
import org.lwjglx.opengl.Display;

/** Bounded native readback and a persistent local hardware video encoder.
 * PTS describes encoder input wall time. The segment's source clocks describe
 * its first and last actual native frames, rather than inferred FPS or world time.
 */
public final class StudyVideoCapture {
    static final int MAX_BOX_BYTES = 32 * 1024 * 1024;
    static final int MAX_PENDING_METADATA = 512;
    static final int RETAIN_SEGMENTS = 8;
    private static final Slot[] SLOTS = {new Slot(), new Slot(), new Slot()};
    private static volatile Producer producer;
    private static Readback readback = new OpenGlReadback();
    private static boolean initialized;
    private static long nextCapture;
    private static long pngAt;
    private static final ReentrantLock PUBLICATION_LOCK = new ReentrantLock();
    private static final Object LIFECYCLE_LOCK = new Object();
    private static Producer publicationOwner;
    private static volatile Thread retirementWorker;
    private static volatile boolean captureStopped;
    private static boolean geometryPending, shutdownHookInstalled;
    private static int pendingWidth, pendingHeight;
    private static long geometryChangedAt;
    private static Object nativeBody;
    private static String nativeSave;
    private static int nativeSqlId;
    private static double nativeHours;
    private static StudyViewCapture.CaptureContext nativeContext;
    private static boolean nativeSourceSeen;
    static final long GEOMETRY_STABLE_NS = TimeUnit.MILLISECONDS.toNanos(350);

    /** Construction seam controls workers in native lifecycle tests. */
    interface ProducerFactory {
        Producer create(Path root, Path executable, int width, int height, int fps) throws IOException;
    }
    private static ProducerFactory producerFactory = Producer::new;

    public record Site(String id, String label, int slot, float x, float y, float z,
                       int left, int top, int width, int height, float zoom, float targetZoom) { }
    record Crop(String id, int slot, int left, int top, int width, int height) { }
    record Frame(long sequence, long capturedAtUnixMs, long observerSequence, double worldHours,
                 Site[] sites, int width, int height, byte[] pixels,
                 StudyViewCapture.FrameCamera camera) {
        Frame(long sequence, long capturedAtUnixMs, long observerSequence, double worldHours,
              Site[] sites, int width, int height, byte[] pixels) {
            this(sequence, capturedAtUnixMs, observerSequence, worldHours,
                sites, width, height, pixels, null);
        }
    }
    private static final class Slot {
        int buffer;
        long fence;
        long submittedAtNs;
        Frame frame;
        StudyViewCapture.FrameStamp stamp;
    }

    /** Diagnostics are separate from video/admitted-frame accounting. */
    static final class Diagnostics {
        static final String[] COUNTERS = {"nativeSwapCallbacks", "missingStampSwaps", "failedSwaps",
            "stampedCaptureAttempts", "ceilingSkips", "pboBusySkips", "handoffBusySkips",
            "captureAdmissions", "fenceNotReady", "readbackTransfers", "pipeWrites", "sidecarWriteFailures", "sharedPngAdmissions"};
        static final String[] TIMERS = {"captureCallback", "pboSubmit", "fenceAge", "pboMapCopy", "pipeWriteFlush", "pngReadback"};
        static final long[] BOUNDS = {100_000, 1_000_000, 4_000_000, 16_000_000, 64_000_000, 250_000_000, 1_000_000_000};
        final AtomicLong[] counts = atoms(COUNTERS.length);
        final AtomicLong[][] timings = new AtomicLong[TIMERS.length][];
        final long startedAtNs = System.nanoTime();
        Diagnostics() { for (int i=0;i<timings.length;i++) timings[i]=atoms(3+BOUNDS.length+1); }
        static AtomicLong[] atoms(int count) {
            AtomicLong[] values=new AtomicLong[count]; for(int i=0;i<count;i++) values[i]=new AtomicLong(); return values;
        }
        void count(int index) { counts[index].incrementAndGet(); }
        void duration(int index, long elapsed) {
            elapsed=Math.max(0,elapsed); var row=timings[index];
            row[0].incrementAndGet(); row[1].addAndGet(elapsed); row[2].accumulateAndGet(elapsed,Math::max);
            int bucket=0; while(bucket<BOUNDS.length && elapsed>=BOUNDS[bucket]) bucket++;
            row[3+bucket].incrementAndGet();
        }
        String json(String streamId) {
            StringBuilder out=new StringBuilder("{\"schema\":\"sao-native-capture-diagnostics/1\",\"streamId\":\"")
                .append(streamId).append("\",\"updatedAtUnixMs\":").append(System.currentTimeMillis())
                .append(",\"elapsedNs\":").append(Math.max(0,System.nanoTime()-startedAtNs))
                .append(",\"counterBoundary\":\"native swaps counted after producer initialization; pre-admission skips remain outside video droppedFrames\",\"counts\":{");
            for(int i=0;i<COUNTERS.length;i++) { if(i>0)out.append(','); out.append('"').append(COUNTERS[i]).append("\":").append(counts[i].get()); }
            out.append("},\"histogramUpperBoundsNs\":[");
            for(int i=0;i<BOUNDS.length;i++){if(i>0)out.append(',');out.append(BOUNDS[i]);}
            out.append("],\"timings\":{");
            for(int i=0;i<TIMERS.length;i++) {
                if(i>0)out.append(','); var row=timings[i];
                out.append('"').append(TIMERS[i]).append("\":{\"calls\":").append(row[0].get())
                    .append(",\"totalNs\":").append(row[1].get()).append(",\"maximumNs\":").append(row[2].get()).append(",\"histogram\":[");
                for(int j=3;j<row.length;j++){if(j>3)out.append(',');out.append(row[j].get());} out.append("]}");
            }
            return out.append("}}\n").toString();
        }
    }

    static void nativeSwap(boolean stamped, boolean failed) {
        Producer owner=producer;
        if (!enabled() || owner==null) return;
        owner.diagnostics.count(0);
        if (!stamped) owner.diagnostics.count(1);
        if (failed) owner.diagnostics.count(2);
    }

    static void pngReadbackDuration(long elapsedNs) {
        Producer owner=producer;
        if (enabled() && owner!=null) owner.diagnostics.duration(5,elapsedNs);
    }

    /** Native lifecycle seam; tests substitute GPU operations, not accounting. */
    interface Readback {
        int width();
        int height();
        void verifyContext() throws IOException;
        int createBuffer(int width, int height);
        long capture(int buffer, int width, int height) throws IOException;
        boolean ready(long fence) throws IOException;
        byte[] pixels(int buffer, int width, int height) throws IOException;
        void releaseFence(long fence);
        void releaseBuffer(int buffer);
    }

    private static final class OpenGlReadback implements Readback {
        public int width() { return Display.getDisplayMode().getWidth(); }
        public int height() { return Display.getDisplayMode().getHeight(); }
        public void verifyContext() throws IOException {
            var capabilities = GL.getCapabilities();
            if (!(capabilities.OpenGL21 || capabilities.GL_ARB_pixel_buffer_object)
                    || !(capabilities.OpenGL32 || capabilities.GL_ARB_sync))
                throw new IOException("native context lacks asynchronous pixel buffers or fences");
        }
        public int createBuffer(int width, int height) {
            int previous = GL11.glGetInteger(GL21.GL_PIXEL_PACK_BUFFER_BINDING);
            int buffer = GL15.glGenBuffers();
            try {
                GL15.glBindBuffer(GL21.GL_PIXEL_PACK_BUFFER, buffer);
                GL15.glBufferData(GL21.GL_PIXEL_PACK_BUFFER, (long) width * height * 3, GL15.GL_STREAM_READ);
                return buffer;
            } catch (RuntimeException | LinkageError failure) {
                GL15.glDeleteBuffers(buffer);
                throw failure;
            } finally { GL15.glBindBuffer(GL21.GL_PIXEL_PACK_BUFFER, previous); }
        }
        public long capture(int buffer, int width, int height) throws IOException {
            int previous = GL11.glGetInteger(GL21.GL_PIXEL_PACK_BUFFER_BINDING);
            int alignment = GL11.glGetInteger(GL11.GL_PACK_ALIGNMENT);
            int previousRead = GL11.glGetInteger(GL11.GL_READ_BUFFER);
            try {
                GL15.glBindBuffer(GL21.GL_PIXEL_PACK_BUFFER, buffer);
                GL11.glPixelStorei(GL11.GL_PACK_ALIGNMENT, 1);
                GL11.glReadBuffer(GL11.GL_FRONT);
                GL11.glReadPixels(0, 0, width, height, GL11.GL_RGB, GL11.GL_UNSIGNED_BYTE, 0L);
                long fence = GL32.glFenceSync(GL32.GL_SYNC_GPU_COMMANDS_COMPLETE, 0);
                if (fence == 0) throw new IOException("native readback fence unavailable");
                return fence;
            } finally {
                GL11.glReadBuffer(previousRead);
                GL11.glPixelStorei(GL11.GL_PACK_ALIGNMENT, alignment);
                GL15.glBindBuffer(GL21.GL_PIXEL_PACK_BUFFER, previous);
            }
        }
        public boolean ready(long fence) throws IOException {
            int status = GL32.glClientWaitSync(fence, 0, 0);
            if (status == GL32.GL_TIMEOUT_EXPIRED) return false;
            if (status != GL32.GL_ALREADY_SIGNALED && status != GL32.GL_CONDITION_SATISFIED)
                throw new IOException("native readback fence failed");
            return true;
        }
        public byte[] pixels(int buffer, int width, int height) throws IOException {
            int previous = GL11.glGetInteger(GL21.GL_PIXEL_PACK_BUFFER_BINDING);
            try {
                GL15.glBindBuffer(GL21.GL_PIXEL_PACK_BUFFER, buffer);
                ByteBuffer mapped = GL15.glMapBuffer(GL21.GL_PIXEL_PACK_BUFFER, GL15.GL_READ_ONLY);
                if (mapped == null) throw new IOException("native readback mapping unavailable");
                byte[] bytes = new byte[Math.multiplyExact(Math.multiplyExact(width, height), 3)];
                try { mapped.get(bytes); }
                finally {
                    if (!GL15.glUnmapBuffer(GL21.GL_PIXEL_PACK_BUFFER))
                        throw new IOException("native readback contents became invalid");
                }
                return bytes;
            } finally { GL15.glBindBuffer(GL21.GL_PIXEL_PACK_BUFFER, previous); }
        }
        public void releaseFence(long fence) { GL32.glDeleteSync(fence); }
        public void releaseBuffer(int buffer) { GL15.glDeleteBuffers(buffer); }
    }

    static boolean enabled() { return System.getProperty("study.videoEncoder") != null; }

    /** Called only from the game-thread draw-state hook. */
    static Site[] snapshotSites(StudyObserver.SiteFrame[] source) {
        if (!enabled()) return new Site[0];
        if (source.length == 0) source = StudyObserver.videoFrames();
        var buffer = zombie.core.Core.getInstance().offscreenBuffer;
        if (buffer == null) return new Site[0];
        Site[] sites = new Site[source.length];
        for (int index = 0; index < source.length; index++) {
            var site = source[index];
            sites[index] = new Site(site.id(), site.label(), site.slot(), site.x(), site.y(), site.z(),
                site.left(), site.top(), site.width(), site.height(),
                buffer.getZoom(site.slot()), buffer.getTargetZoom(site.slot()));
        }
        return sites;
    }

    /** Sparse independent PNG fallback retains the existing command-bound path. */
    static boolean pngDue() {
        if (!enabled()) return true;
        if (producer != null && producer.failed()) return true;
        long now = System.nanoTime();
        if (now < pngAt) return false;
        pngAt = now + TimeUnit.SECONDS.toNanos(2);
        return true;
    }

    static boolean sharesPng() {
        return Boolean.getBoolean("study.nativePlay") && enabled() && (producer == null || !producer.failed());
    }

    /** Render thread: never waits for an encoder, worker, or GPU fence. */
    static void swapped(StudyViewCapture.FrameStamp stamp) {
        if (!enabled() || captureStopped) return;
        long callbackStarted=System.nanoTime();
        try {
            int width = readback.width(), height = readback.height();
            if (!initialized) initialize(width, height);
            if (producer == null) return;
            producer.diagnostics.count(3);
            if (zombie.GameWindow.closeRequested) {
                captureStopped = true;
                releaseSlots();
                producer.requestClose();
                return;
            }
            if (Boolean.getBoolean("study.nativePlay") && StudyViewCapture.participantMode()
                    && !StudyViewCapture.frameCurrent(stamp)) return;
            var participant = stamp.participant();
            var context = participant == null ? null : participant.capture();
            boolean nativeBoundary = Boolean.getBoolean("study.nativePlay") && nativeSourceSeen
                && (participant == null || participant.body() != nativeBody
                    || !java.util.Objects.equals(participant.save(), nativeSave)
                    || participant.playerSqlId() != nativeSqlId || stamp.hours() < nativeHours
                    || (context != null && nativeContext != null && !context.sameSource(nativeContext)));
            if (geometryPending || nativeBoundary || width != producer.width || height != producer.height) {
                if (!StudyViewCapture.participantMode())
                    throw new IOException("native framebuffer dimensions changed during video");
                if (!rollover(width, height)) return;
            }
            if (producer.failed() || producer.closing) return;
            pollReady();
            long now = System.nanoTime();
            if (now < nextCapture) { producer.diagnostics.count(4); return; }
            nextCapture = now + TimeUnit.SECONDS.toNanos(1) / producer.fps;
            Slot free = null;
            for (Slot slot : SLOTS) if (slot.fence == 0) { free = slot; break; }
            // Busy slots and encoder backpressure skip an opportunity before
            // native pixels are admitted; they are not lost captured frames.
            if (free == null) { producer.diagnostics.count(5); return; }
            if (producer.latest.get() != null) { producer.diagnostics.count(6); return; }
            free.submittedAtNs=System.nanoTime();
            try { free.fence = readback.capture(free.buffer, width, height); }
            finally { producer.diagnostics.duration(1,System.nanoTime()-free.submittedAtNs); }
            free.frame = new Frame(producer.admitCapture(), System.currentTimeMillis(), stamp.observerSequence(),
                stamp.hours(), stamp.videoSites(), width, height, null, stamp.camera());
            free.stamp = stamp;
            if (Boolean.getBoolean("study.nativePlay")) {
                nativeBody = participant == null ? null : participant.body();
                nativeSave = participant == null ? null : participant.save();
                nativeSqlId = participant == null ? -1 : participant.playerSqlId();
                nativeHours = stamp.hours(); nativeContext = context; nativeSourceSeen = true;
            }
            producer.diagnostics.count(7);
        } catch (Exception | LinkageError failure) {
            if (producer != null) {
                try { releaseSlots(); }
                catch (Exception | LinkageError cleanup) { System.out.println("[StudyVideo] readback cleanup unavailable: " + cleanup); }
                producer.fail("Native video capture unavailable");
            }
            System.out.println("[StudyVideo] native capture unavailable: " + failure);
        } finally {
            if (producer!=null) producer.diagnostics.duration(0,System.nanoTime()-callbackStarted);
        }
    }

    private static void initialize(int width, int height) throws IOException {
        synchronized (LIFECYCLE_LOCK) {
            if (captureStopped) return;
            initialized = true;
            producer = producerFactory.create(Path.of(System.getProperty("study.viewDirectory")),
                Path.of(System.getProperty("study.videoEncoder")), width, height,
                Integer.parseInt(System.getProperty("study.videoFps", "120")));
            if (!shutdownHookInstalled) {
                shutdownHookInstalled = true;
                Runtime.getRuntime().addShutdownHook(new Thread(StudyVideoCapture::shutdown, "StudyVideoShutdown"));
            }
            readback.verifyContext();
            for (Slot slot : SLOTS) slot.buffer = readback.createBuffer(width, height);
            nextCapture = 0;
        }
    }

    /** A resize cancels old GPU admissions, then coalesces until both the native
     * geometry and the single retiring encoder are ready. Never waits here. */
    private static boolean rollover(int width, int height) throws IOException {
        long now = System.nanoTime();
        if (!geometryPending) {
            releaseSlots();
            geometryPending = true;
            pendingWidth = width; pendingHeight = height; geometryChangedAt = now;
        }
        if (retirementWorker == null) {
            // Atomic file publication can be temporarily busy. Defer authority
            // transfer to another swap rather than wait on its worker here.
            if (!PUBLICATION_LOCK.tryLock()) return false;
            Producer prior = producer;
            try {
                if (publicationOwner == prior) publicationOwner = null;
                prior.retired = true;
            } finally { PUBLICATION_LOCK.unlock(); }
            prior.requestClose();
            retirementWorker = new Thread(() -> {
                try { prior.writeManifest(); }
                catch (IOException failure) { prior.fail("Native video retirement receipt unavailable"); }
                prior.close();
                if (prior.failed()) {
                    // A failed retirement blocks further epochs. Its failure
                    // remains the current truth while no successor exists.
                    PUBLICATION_LOCK.lock();
                    try {
                        if (publicationOwner == null) publicationOwner = prior;
                    } finally { PUBLICATION_LOCK.unlock(); }
                    try { prior.writeManifest(); }
                    catch (IOException failure) { System.out.println("[StudyVideo] retirement failure receipt unavailable: " + failure); }
                }
            }, "StudyVideoGeometryRetirement");
            retirementWorker.setDaemon(true); retirementWorker.start();
            return false;
        }
        if (pendingWidth != width || pendingHeight != height) {
            pendingWidth = width; pendingHeight = height; geometryChangedAt = now;
        }
        if (producer.failed() || retirementWorker.isAlive() || now - geometryChangedAt < GEOMETRY_STABLE_NS)
            return false;
        if (!producer.quiescent()) throw new IOException("retiring native video resources remain live");
        initialize(width, height);
        geometryPending = false;
        retirementWorker = null;
        return true;
    }

    private static void shutdown() {
        Producer current;
        synchronized (LIFECYCLE_LOCK) { captureStopped = true; current = producer; }
        if (current != null) current.close();
        Thread retiring = retirementWorker;
        if (retiring != null && retiring != Thread.currentThread()) {
            try { retiring.join(10000); }
            catch (InterruptedException interrupted) { Thread.currentThread().interrupt(); }
        }
    }

    private static void pollReady() throws IOException {
        // Preserve submitted native order even when a later fence signals first.
        for (;;) {
            Slot oldest = null;
            for (Slot slot : SLOTS) if (slot.fence != 0
                    && (oldest == null || slot.frame.sequence() < oldest.frame.sequence())) oldest = slot;
            if (oldest == null) return;
            if (!readback.ready(oldest.fence)) { producer.diagnostics.count(8); return; }
            if (Boolean.getBoolean("study.nativePlay") && StudyViewCapture.participantMode()
                    && !StudyViewCapture.frameCurrent(oldest.stamp)) {
                producer.dropped.incrementAndGet();
                discardSlot(oldest, false);
                continue;
            }
            producer.diagnostics.duration(2,System.nanoTime()-oldest.submittedAtNs);
            boolean transferred = false;
            try {
                byte[] bytes;
                long mappingStarted=System.nanoTime();
                try { bytes = readback.pixels(oldest.buffer, producer.width, producer.height); }
                finally { producer.diagnostics.duration(3,System.nanoTime()-mappingStarted); }
                if (Boolean.getBoolean("study.nativePlay") && StudyViewCapture.participantMode()
                        && !StudyViewCapture.frameCurrent(oldest.stamp)) continue;
                Frame frame = oldest.frame;
                if (Boolean.getBoolean("study.nativePlay") && oldest.stamp.participant() != null)
                    producer.offerNativeContext(oldest.stamp.participant().capture());
                producer.acceptCaptured(new Frame(frame.sequence(), frame.capturedAtUnixMs(), frame.observerSequence(),
                    frame.worldHours(), frame.sites(), producer.width, producer.height, bytes, frame.camera()));
                // One admitted native readback supplies both lossless PNG and
                // video. Metadata stays with that exact admission; no second
                // synchronous GL_FRONT read is needed for interactive play.
                if (sharesPng() && pngDue() && StudyViewCapture.sharedPixels(oldest.stamp,
                        producer.width, producer.height, bytes, frame.capturedAtUnixMs()))
                    producer.diagnostics.count(12);
                transferred = true;
                producer.diagnostics.count(9);
            } finally {
                if (!transferred) producer.dropped.incrementAndGet();
                discardSlot(oldest, false);
            }
        }
    }

    private static void releaseSlots() {
        Throwable first = null;
        for (Slot slot : SLOTS) {
            try { discardSlot(slot, true); }
            catch (RuntimeException | LinkageError failure) {
                if (first == null) first = failure; else first.addSuppressed(failure);
            }
        }
        if (first instanceof RuntimeException failure) throw failure;
        if (first instanceof LinkageError failure) throw failure;
    }

    private static void discardSlot(Slot slot, boolean releaseBuffer) {
        long fence = slot.fence;
        int buffer = slot.buffer;
        boolean pending = slot.frame != null;
        // Clear ownership before native disposal, so an exceptional cleanup
        // cannot count or release the same admitted capture twice.
        slot.fence = 0; slot.frame = null; slot.stamp = null; slot.submittedAtNs=0;
        if (releaseBuffer) slot.buffer = 0;
        if (releaseBuffer && pending) producer.dropped.incrementAndGet();
        try { if (fence != 0) readback.releaseFence(fence); }
        finally { if (releaseBuffer && buffer != 0) readback.releaseBuffer(buffer); }
    }

    /** Workers consume only immutable captured bytes and metadata. */
    static final class Producer implements AutoCloseable {
        final Path root;
        final Path executable;
        final String streamId = UUID.randomUUID().toString();
        final int width, height, fps;
        final boolean participantEpoch;
        final AtomicLong captured = new AtomicLong(), encoded = new AtomicLong(), dropped = new AtomicLong();
        final AtomicReference<Frame> latest = new AtomicReference<>();
        final AtomicReference<StudyViewCapture.CaptureContext> nativeCaptureContext = new AtomicReference<>();
        final Diagnostics diagnostics = new Diagnostics();
        final AtomicReference<String> failureReason = new AtomicReference<>();
        final ArrayBlockingQueue<Frame> submitted = new ArrayBlockingQueue<>(MAX_PENDING_METADATA);
        final ArrayDeque<Segment> segments = new ArrayDeque<>();
        final Thread writer;
        final Thread diagnosticWriter;
        final Object diagnosticLock = new Object();
        final Object closeLock = new Object();
        volatile boolean diagnosticsStopped;
        volatile Thread reader;
        volatile Thread failureWriter;
        volatile Process process;
        volatile boolean closing;
        volatile boolean retired;
        boolean closedManifestWritten;
        boolean nativeContextWritten;
        volatile String state = "starting";
        volatile String message = "Waiting for native video frames";
        String initFile, initSha, codecs;
        long timeScale;
        long fragmentSequence;
        long lastPtsEnd = -1;

        Producer(Path root, Path executable, int width, int height, int fps) throws IOException {
            this(root, executable, width, height, fps, true);
        }

        Producer(Path root, Path executable, int width, int height, int fps, boolean startWriter) throws IOException {
            if (width < 2 || width > 4096 || height < 2 || height > 2160 || (width & 1) != 0 || (height & 1) != 0
                    || fps < 30 || fps > 120) throw new IOException("video dimensions or rate invalid");
            this.root = root; this.executable = executable; this.width = width; this.height = height; this.fps = fps;
            participantEpoch = StudyViewCapture.participantMode();
            writer = new Thread(this::encode, "StudyVideoEncoder"); writer.setDaemon(true);
            diagnosticWriter = new Thread(this::publishDiagnostics, "StudyCaptureDiagnostics"); diagnosticWriter.setDaemon(true);
            if (participantEpoch) {
                PUBLICATION_LOCK.lock();
                try { publicationOwner = this; }
                finally { PUBLICATION_LOCK.unlock(); }
            }
            if (startWriter) { diagnosticWriter.start(); writer.start(); }
        }

        private void publishDiagnostics() {
            while (!diagnosticsStopped) {
                try { writeDiagnostics(); }
                catch (IOException | RuntimeException failure) { diagnostics.count(11); }
                LockSupport.parkNanos(TimeUnit.SECONDS.toNanos(1));
            }
            try { writeDiagnostics(); }
            catch (IOException | RuntimeException failure) { diagnostics.count(11); }
        }

        void writeDiagnostics() throws IOException {
            synchronized (diagnosticLock) {
                Files.createDirectories(root);
                String json = diagnostics.json(streamId);
                if (participantEpoch) {
                    replace("video-" + streamId + "-capture-diagnostics.json", json);
                    PUBLICATION_LOCK.lock();
                    try {
                        if (publicationOwner == this) replace("capture-diagnostics.json", json);
                    } finally { PUBLICATION_LOCK.unlock(); }
                } else replace("capture-diagnostics.json", json);
            }
        }

        void writePixels(OutputStream input, Frame frame) throws IOException {
            long started=System.nanoTime();
            try { input.write(frame.pixels()); input.flush(); diagnostics.count(10); }
            finally { diagnostics.duration(4,System.nanoTime()-started); }
        }

        boolean failed() { return failureReason.get() != null; }

        void accept(Frame frame) {
            validateFrame(frame);
            admitCapture();
            enqueue(frame);
        }

        long admitCapture() { return captured.incrementAndGet(); }

        void offerNativeContext(StudyViewCapture.CaptureContext context) throws IOException {
            if (!participantEpoch || context == null) return;
            StudyViewCapture.CaptureContext prior = nativeCaptureContext.get();
            if (prior == null) {
                if (nativeCaptureContext.compareAndSet(null, context)) return;
                prior = nativeCaptureContext.get();
            }
            if (!prior.sameSource(context)) throw new IOException("native capture context changed within stream");
        }

        /** Writer-owned immutable receipt, created before its first encoded frame. */
        void writeNativeContext() throws IOException {
            StudyViewCapture.CaptureContext context = nativeCaptureContext.get();
            if (!participantEpoch || context == null || nativeContextWritten) return;
            commit("video-" + streamId + "-native-context.json",
                (context.json(streamId) + "\n").getBytes(StandardCharsets.UTF_8));
            nativeContextWritten = true;
        }

        void acceptCaptured(Frame frame) {
            validateFrame(frame);
            if (frame.sequence() > captured.get()) throw new IllegalArgumentException("native video readback was not admitted");
            enqueue(frame);
        }

        private void validateFrame(Frame frame) {
            if (frame.width() != width || frame.height() != height || frame.pixels() == null
                    || frame.pixels().length != (long) width * height * 3)
                throw new IllegalArgumentException("native video frame dimensions differ");
            if (frame.sequence() < 1 || frame.capturedAtUnixMs() < 1 || frame.observerSequence() < 0
                    || !Double.isFinite(frame.worldHours()) || frame.worldHours() < 0 || frame.sites().length > 4)
                throw new IllegalArgumentException("native video frame metadata invalid");
            for (Site site : frame.sites()) {
                if (site.id() == null || site.label() == null || site.id().length() > 128 || site.label().length() > 512
                        || site.slot() < 0 || site.slot() > 3 || site.left() < 0 || site.top() < 0
                        || site.width() < 1 || site.height() < 1 || (long) site.left() + site.width() > width
                        || (long) site.top() + site.height() > height || !Float.isFinite(site.x())
                        || !Float.isFinite(site.y()) || !Float.isFinite(site.z()) || !Float.isFinite(site.zoom())
                        || !Float.isFinite(site.targetZoom()) || site.zoom() <= 0 || site.targetZoom() <= 0)
                    throw new IllegalArgumentException("native video site metadata invalid");
            }
        }

        private void enqueue(Frame frame) {
            if (closing || failed()) { dropped.incrementAndGet(); return; }
            if (latest.getAndSet(frame) != null) dropped.incrementAndGet();
            LockSupport.unpark(writer);
        }

        List<String> command() {
            return List.of(executable.toString(), "-hide_banner", "-loglevel", "warning", "-nostdin",
                "-filter_threads", "1", "-f", "rawvideo", "-pixel_format", "rgb24",
                "-video_size", width + "x" + height, "-framerate", Integer.toString(fps), "-analyzeduration", "0", "-probesize", "32",
                "-use_wallclock_as_timestamps", "1", "-i", "pipe:0", "-an", "-sn", "-dn",
                "-copyts", "-start_at_zero", "-vf", "vflip,format=nv12", "-c:v", "h264_nvenc",
                // The capture ceiling is not the actual native frame rate.
                // Bitrate control at that ceiling starves sparse native frames;
                // fixed quantization preserves their detail at either rate.
                "-preset", "p4", "-tune", "ull", "-profile:v", "high", "-bf", "0",
                "-rc", "constqp", "-qp", "18",
                "-g", Integer.toString(Math.max(1, fps / 4)), "-rc-lookahead", "0", "-zerolatency", "1",
                "-fps_mode", "passthrough", "-enc_time_base", "1/1000",
                // Time from the previous actual forced frame preserves native
                // gaps without emitting per-frame IDRs to repay missed times.
                // NVENC requires forced IDRs for independently decodable fragments.
                "-force_key_frames", "expr:if(isnan(prev_forced_t),1,gte(t,prev_forced_t+0.25))",
                "-forced-idr", "1", "-f", "mp4",
                "-movflags", "+frag_keyframe+empty_moov+default_base_moof+skip_trailer",
                "-video_track_timescale", "1000", "-flush_packets", "1", "pipe:1");
        }

        private void encode() {
            try {
                Files.createDirectories(root);
                writeManifest();
                if (failed()) return;
                process = new ProcessBuilder(command()).redirectError(root.resolve("video-" + streamId + ".log").toFile()).start();
                reader = new Thread(this::readEncoded, "StudyVideoPublication"); reader.setDaemon(true); reader.start();
                try (OutputStream input = process.getOutputStream()) {
                    long nextSubmission = 0;
                    Frame prior = null;
                    while (!closing || latest.get() != null) {
                        if (failed()) break;
                        Frame frame = latest.getAndSet(null);
                        if (frame == null) { LockSupport.parkNanos(TimeUnit.MILLISECONDS.toNanos(10)); continue; }
                        writeNativeContext();
                        if (prior != null && (frame.sequence() <= prior.sequence()
                                || frame.capturedAtUnixMs() < prior.capturedAtUnixMs() || frame.worldHours() < prior.worldHours()))
                            throw new IOException("native video source clocks regressed");
                        // Wall-clock rawvideo packets are quantized to the input
                        // rate. Pacing the owned pipe avoids duplicate timestamps
                        // when completed PBO frames arrive together after a stall.
                        while (System.nanoTime() < nextSubmission)
                            LockSupport.parkNanos(nextSubmission - System.nanoTime());
                        if (!submitted.offer(frameWithoutPixels(frame))) throw new IOException("video metadata backlog exceeded bound");
                        writePixels(input, frame);
                        nextSubmission = System.nanoTime() + TimeUnit.SECONDS.toNanos(1) / fps;
                        prior = frameWithoutPixels(frame);
                    }
                }
                if (!process.waitFor(5, TimeUnit.SECONDS)) throw new IOException("video encoder did not finish");
                reader.join(1000);
                if (reader.isAlive()) throw new IOException("video publication did not finish");
                if (process.exitValue() != 0) throw new IOException("video encoder returned failure");
                if (!failed()) {
                    if (!submitted.isEmpty()) throw new IOException("video encoder omitted submitted native frames");
                    synchronized (this) {
                        state = "ended";
                        message = encoded.get() == 0 ? "Native video ended before initialization" : "Native video ended";
                        writeManifest();
                    }
                }
            } catch (Exception failure) {
                fail("Native video encoder unavailable");
                System.out.println("[StudyVideo] encoder unavailable: " + failure);
            } finally {
                if (failed()) {
                    try { writeManifest(); }
                    catch (IOException failure) { System.out.println("[StudyVideo] failure receipt unavailable: " + failure); }
                }
                if (process != null && process.isAlive()) process.destroy();
                diagnosticsStopped=true;
                LockSupport.unpark(diagnosticWriter);
            }
        }

        private void readEncoded() {
            try (InputStream input = process.getInputStream()) {
                Box ftyp = readBox(input);
                Box moov = readBox(input);
                if (ftyp == null || moov == null || !ftyp.type.equals("ftyp") || !moov.type.equals("moov"))
                    throw new IOException("video initialization boxes missing");
                Init info = parseInit(moov.bytes, width, height);
                byte[] init = join(ftyp.bytes, moov.bytes);
                synchronized (this) {
                    timeScale = info.timeScale; codecs = info.codecs;
                    initFile = "video-" + streamId + "-init.mp4";
                    initSha = commit(initFile, init);
                    message = "Waiting for encoded native video";
                    writeManifest();
                }
                for (;;) {
                    Box moof = readBox(input);
                    if (moof == null) break;
                    if (!moof.type.equals("moof")) throw new IOException("video fragment does not start with moof");
                    Box mdat = readBox(input);
                    if (mdat == null || !mdat.type.equals("mdat")) throw new IOException("video media data incomplete");
                    Fragment fragment = parseFragment(moof.bytes, mdat.bytes);
                    publishFragment(fragment, join(moof.bytes, mdat.bytes));
                }
            } catch (Exception failure) {
                fail("Native video publication unavailable");
                System.out.println("[StudyVideo] publication unavailable: " + failure);
            }
        }

        private void publishFragment(Fragment fragment, byte[] bytes) throws IOException, InterruptedException {
            List<Frame> frames = new ArrayList<>();
            for (int index = 0; index < fragment.samples; index++) {
                Frame frame = submitted.poll(1, TimeUnit.SECONDS);
                if (frame == null) throw new IOException("encoded video has no matching native frame");
                if (!frames.isEmpty() && frame.sequence() <= frames.get(frames.size() - 1).sequence())
                    throw new IOException("native video frame order changed");
                frames.add(frame);
            }
            Frame first = frames.get(0), last = frames.get(frames.size() - 1);
            boolean sameView = frames.stream().allMatch(frame -> frame.observerSequence() == first.observerSequence()
                && Arrays.equals(frame.sites(), first.sites()));
            Site[] sites = sameView ? first.sites() : new Site[0];
            Crop[] firstCrops = cropsOf(first.sites());
            boolean sameCrop = frames.stream().allMatch(frame -> Arrays.equals(cropsOf(frame.sites()), firstCrops));
            // Participant pixels are the actual whole native front buffer.
            // This viewport identity describes geometry, never a body/camera
            // association; empty source sites remain empty and unaligned.
            Crop[] crops = participantEpoch
                ? new Crop[]{new Crop("participant-viewport", 0, 0, 0, width, height)}
                : sameCrop ? firstCrops : new Crop[0];
            synchronized (this) {
                if (failed()) return;
                if (fragment.pts < lastPtsEnd) throw new IOException("video fragment clock regressed");
                lastPtsEnd = fragment.pts + fragment.duration;
                String file = "video-" + streamId + "-" + String.format("%016d", ++fragmentSequence) + ".m4s";
                String sha = commit(file, bytes);
                Segment segment = new Segment(fragmentSequence, file, sha, fragment.pts * 1000.0 / timeScale,
                    fragment.duration * 1000.0 / timeScale, first, last, sites, crops,
                    cameraFramesJson(frames));
                segments.addLast(segment);
                List<Segment> expired = new ArrayList<>();
                while (segments.size() > RETAIN_SEGMENTS) expired.add(segments.removeFirst());
                encoded.addAndGet(frames.size());
                state = "running"; message = "";
                writeManifest();
                // Retired encoders have at most the bounded admitted backlog.
                // Keep original drain bytes for the immutable tail snapshots;
                // each manifest still contains at most RETAIN_SEGMENTS entries.
                if (!retired) for (Segment old : expired) Files.deleteIfExists(root.resolve(old.file));
            }
        }

        void fail(String reason) {
            if (!failureReason.compareAndSet(null, reason)) return;
            state = "failed"; message = reason; closing = true;
            Frame unsubmitted = latest.getAndSet(null);
            if (unsubmitted != null) dropped.incrementAndGet();
            LockSupport.unpark(writer);
            failureWriter = new Thread(() -> {
                try { writeManifest(); }
                catch (IOException failure) { System.out.println("[StudyVideo] failure receipt unavailable: " + failure); }
                Process child = process;
                if (child != null && child.isAlive()) child.destroy();
            }, "StudyVideoFailure");
            failureWriter.setDaemon(true); failureWriter.start();
            // Never close the pipe on the render thread: an encoder can be
            // blocked inside a write. Its owned worker/shutdown path terminates it.
        }

        void requestClose() { closing = true; LockSupport.unpark(writer); }

        @Override public void close() {
            synchronized (closeLock) {
                requestClose();
                joinWorker(writer, 6000);
                Process child = process;
                if (writer.isAlive() || (child != null && child.isAlive())) {
                    fail("Native video encoder did not finish before shutdown");
                    if (child != null && child.isAlive()) {
                        child.destroy();
                        try {
                            if (!child.waitFor(500, TimeUnit.MILLISECONDS)) {
                                child.destroyForcibly(); child.waitFor(1000, TimeUnit.MILLISECONDS);
                            }
                        } catch (InterruptedException interrupted) { Thread.currentThread().interrupt(); }
                    }
                }
                joinWorker(writer, 1000); joinWorker(reader, 1000);
                diagnosticsStopped=true; LockSupport.unpark(diagnosticWriter);
                joinWorker(diagnosticWriter, 1000); joinWorker(failureWriter, 1000);
                if (!quiescent()) {
                    fail("Native video shutdown retained live resources");
                    return;
                }
                if (participantEpoch && !closedManifestWritten) {
                    synchronized (this) {
                        if (!failed() && !state.equals("ended")) {
                            state = "ended";
                            message = encoded.get() == 0 ? "Native video ended before initialization" : "Native video ended";
                        }
                        try {
                            String json = manifestJson();
                            commit("video-" + streamId + "-closed.json", json.getBytes(StandardCharsets.UTF_8));
                            closedManifestWritten = true;
                            writeManifest();
                        } catch (IOException failure) {
                            fail("Native video terminal receipt unavailable");
                            System.out.println("[StudyVideo] terminal receipt unavailable: " + failure);
                        }
                    }
                }
            }
        }

        private static void joinWorker(Thread worker, long milliseconds) {
            if (worker == null || worker == Thread.currentThread()) return;
            try { worker.join(milliseconds); }
            catch (InterruptedException interrupted) { Thread.currentThread().interrupt(); }
        }

        boolean quiescent() {
            return !writer.isAlive() && (reader == null || !reader.isAlive())
                && (failureWriter == null || !failureWriter.isAlive()) && !diagnosticWriter.isAlive()
                && (process == null || !process.isAlive());
        }

        private String commit(String name, byte[] bytes) throws IOException {
            Path temporary = root.resolve(name + ".tmp"), target = root.resolve(name);
            Files.write(temporary, bytes, java.nio.file.StandardOpenOption.CREATE_NEW);
            Files.move(temporary, target, StandardCopyOption.ATOMIC_MOVE);
            return sha(bytes);
        }

        synchronized void writeManifest() throws IOException {
            String json = manifestJson();
            if (participantEpoch) {
                if (retired && !segments.isEmpty() && !failed()
                        && (state.equals("starting") || state.equals("running"))) {
                    String tail = "video-" + streamId + "-tail-" + String.format("%016d", segments.getLast().sequence()) + ".json";
                    if (!Files.exists(root.resolve(tail))) commit(tail, json.getBytes(StandardCharsets.UTF_8));
                }
                PUBLICATION_LOCK.lock();
                try {
                    if (publicationOwner == this) replace("latest-video.json", json);
                } finally { PUBLICATION_LOCK.unlock(); }
            } else replace("latest-video.json", json);
        }

        private String manifestJson() {
            // Counts only increase. Sampling completed/lost frames before the
            // admitted count prevents a concurrent capture from publishing a
            // stale denominator with a newer completion or loss numerator.
            long encodedFrames = encoded.get(), droppedFrames = dropped.get(), capturedFrames = captured.get();
            StringBuilder json = new StringBuilder("{\"schema\":\"sao-study-video/1\",\"streamId\":");
            json.append(quote(streamId)).append(",\"state\":").append(quote(failed() ? "failed" : state))
                .append(",\"mimeType\":\"video/mp4\",\"codecs\":").append(codecs == null ? "null" : quote(codecs))
                .append(",\"width\":").append(width).append(",\"height\":").append(height).append(",\"fps\":").append(fps)
                .append(",\"init\":").append(initFile == null ? "null" : "{\"file\":" + quote(initFile) + ",\"sha256\":" + quote(initSha) + "}")
                .append(",\"segments\":[");
            int count = 0;
            for (Segment segment : segments) {
                if (count++ > 0) json.append(',');
                json.append(segment.json());
            }
            json.append("],\"stats\":{\"capturedFrames\":").append(capturedFrames)
                .append(",\"encodedFrames\":").append(encodedFrames).append(",\"droppedFrames\":").append(droppedFrames)
                .append("},\"message\":").append(quote(failed() ? failureReason.get() : message)).append("}\n");
            return json.toString();
        }

        private void replace(String name, String json) throws IOException {
            Files.createDirectories(root);
            Path temporary = root.resolve(name + "-" + streamId + ".tmp");
            Files.writeString(temporary, json, StandardCharsets.UTF_8);
            for (int retry = 0;; retry++) {
                try {
                    Files.move(temporary, root.resolve(name), StandardCopyOption.ATOMIC_MOVE,
                        StandardCopyOption.REPLACE_EXISTING);
                    return;
                } catch (java.nio.file.AccessDeniedException inUse) {
                    if (retry >= 19) throw inUse;
                    LockSupport.parkNanos(TimeUnit.MILLISECONDS.toNanos(10));
                }
            }
        }
    }

    record Segment(long sequence, String file, String sha, double ptsStartMs, double durationMs,
                   Frame first, Frame last, Site[] sites, Crop[] crops, String cameraFramesJson) {
        String json() {
            StringBuilder value = new StringBuilder("{\"sequence\":").append(sequence)
                .append(",\"file\":").append(quote(file)).append(",\"sha256\":").append(quote(sha))
                .append(",\"ptsStartMs\":").append(ptsStartMs).append(",\"durationMs\":").append(durationMs)
                .append(",\"capturedAtUnixMs\":").append(first.capturedAtUnixMs())
                .append(",\"endCapturedAtUnixMs\":").append(last.capturedAtUnixMs())
                .append(",\"observerSequence\":").append(first.observerSequence())
                .append(",\"worldHours\":").append(first.worldHours()).append(",\"endWorldHours\":").append(last.worldHours())
                .append(",\"firstFrameSequence\":").append(first.sequence())
                .append(",\"lastFrameSequence\":").append(last.sequence()).append(",\"sites\":[");
            for (int index = 0; index < sites.length; index++) {
                if (index > 0) value.append(',');
                Site site = sites[index];
                value.append("{\"id\":").append(quote(site.id())).append(",\"label\":").append(quote(site.label()))
                    .append(",\"slot\":").append(site.slot()).append(",\"x\":").append(site.x()).append(",\"y\":").append(site.y())
                    .append(",\"z\":").append(site.z()).append(",\"left\":").append(site.left()).append(",\"top\":").append(site.top())
                    .append(",\"width\":").append(site.width()).append(",\"height\":").append(site.height())
                    .append(",\"zoom\":").append(site.zoom()).append(",\"targetZoom\":").append(site.targetZoom()).append('}');
            }
            value.append("],\"crops\":[");
            for (int index = 0; index < crops.length; index++) {
                if (index > 0) value.append(',');
                Crop crop = crops[index];
                value.append("{\"id\":").append(quote(crop.id())).append(",\"slot\":").append(crop.slot())
                    .append(",\"left\":").append(crop.left()).append(",\"top\":").append(crop.top())
                    .append(",\"width\":").append(crop.width()).append(",\"height\":").append(crop.height()).append('}');
            }
            value.append(']');
            if (cameraFramesJson != null) value.append(",\"cameraFrames\":").append(cameraFramesJson);
            return value.append('}').toString();
        }
    }

    static String cameraFramesJson(List<Frame> frames) {
        if (frames.isEmpty() || frames.stream().anyMatch(frame -> frame.camera() == null))
            return null;
        StringBuilder value = new StringBuilder("[");
        for (int index = 0; index < frames.size(); index++) {
            if (index > 0) value.append(',');
            Frame frame = frames.get(index);
            value.append("{\"frameSequence\":").append(frame.sequence())
                .append(",\"camera\":").append(frame.camera().json()).append('}');
        }
        return value.append(']').toString();
    }

    static Crop[] cropsOf(Site[] sites) {
        return Arrays.stream(sites).map(site -> new Crop(site.id(), site.slot(), site.left(), site.top(),
            site.width(), site.height())).toArray(Crop[]::new);
    }

    static Frame frameWithoutPixels(Frame frame) {
        return new Frame(frame.sequence(), frame.capturedAtUnixMs(), frame.observerSequence(), frame.worldHours(),
            frame.sites(), frame.width(), frame.height(), null, frame.camera());
    }
    record Box(String type, byte[] bytes) { }
    record Init(String codecs, long timeScale) { }
    record Fragment(int samples, long pts, long duration) { }

    static Box readBox(InputStream input) throws IOException {
        byte[] header = input.readNBytes(8);
        if (header.length == 0) return null;
        if (header.length != 8) throw new IOException("video box header truncated");
        long length = Integer.toUnsignedLong(ByteBuffer.wrap(header).getInt());
        if (length < 8 || length > MAX_BOX_BYTES) throw new IOException("video box length invalid");
        byte[] bytes = new byte[(int) length];
        System.arraycopy(header, 0, bytes, 0, 8);
        byte[] body = input.readNBytes((int) length - 8);
        if (body.length != length - 8) throw new IOException("video box incomplete");
        System.arraycopy(body, 0, bytes, 8, body.length);
        return new Box(new String(header, 4, 4, StandardCharsets.US_ASCII), bytes);
    }

    static Init parseInit(byte[] moov, int width, int height) throws IOException {
        List<Part> all = new ArrayList<>();
        inspect(moov, 0, moov.length, all);
        Part avc = unique(all, "avcC"), entry = unique(all, "avc1"), mdhd = unique(all, "mdhd");
        ByteBuffer bytes = ByteBuffer.wrap(moov).order(ByteOrder.BIG_ENDIAN);
        if (avc.length < 15 || moov[avc.offset + 8] != 1 || entry.length < 86
                || Short.toUnsignedInt(bytes.getShort(entry.offset + 32)) != width
                || Short.toUnsignedInt(bytes.getShort(entry.offset + 34)) != height)
            throw new IOException("video AVC initialization differs from native dimensions");
        validateAvc(moov, avc);
        String codecs = "avc1." + HexFormat.of().formatHex(Arrays.copyOfRange(moov, avc.offset + 9, avc.offset + 12));
        int version = moov[mdhd.offset + 8] & 255;
        if (version != 0 && version != 1) throw new IOException("video media clock version invalid");
        int location = mdhd.offset + (version == 0 ? 20 : 28);
        if (location + 4 > mdhd.offset + mdhd.length) throw new IOException("video media clock truncated");
        long scale = Integer.toUnsignedLong(bytes.getInt(location));
        if (scale < 1 || scale > 1_000_000_000) throw new IOException("video media clock invalid");
        return new Init(codecs, scale);
    }

    static Fragment parseFragment(byte[] moof, byte[] mdat) throws IOException {
        List<Part> all = new ArrayList<>(); inspect(moof, 0, moof.length, all);
        Part tfhd = unique(all, "tfhd"), tfdt = unique(all, "tfdt"), trun = unique(all, "trun");
        ByteBuffer bytes = ByteBuffer.wrap(moof).order(ByteOrder.BIG_ENDIAN);
        require(tfhd, 8); require(tfdt, 8); require(trun, 8);
        int flags = bytes.getInt(tfhd.offset + 8) & 0xffffff, at = tfhd.offset + 16;
        if ((flags & 1) != 0) at += 8;
        if ((flags & 2) != 0) at += 4;
        long defaultDuration = 0, defaultSize = 0;
        int defaultFlags = 0;
        if ((flags & 8) != 0) { within(tfhd, at, 4); defaultDuration = Integer.toUnsignedLong(bytes.getInt(at)); at += 4; }
        if ((flags & 16) != 0) { within(tfhd, at, 4); defaultSize = Integer.toUnsignedLong(bytes.getInt(at)); at += 4; }
        if ((flags & 32) != 0) { within(tfhd, at, 4); defaultFlags = bytes.getInt(at); at += 4; }
        if (at != tfhd.offset + tfhd.length) throw new IOException("video track header fields differ");
        int version = moof[tfdt.offset + 8] & 255;
        if (version != 0 && version != 1) throw new IOException("video fragment clock version invalid");
        within(tfdt, tfdt.offset + 12, version == 1 ? 8 : 4);
        long pts = version == 1 ? bytes.getLong(tfdt.offset + 12) : Integer.toUnsignedLong(bytes.getInt(tfdt.offset + 12));
        if (pts < 0) throw new IOException("video fragment clock invalid");
        flags = bytes.getInt(trun.offset + 8) & 0xffffff;
        long count = Integer.toUnsignedLong(bytes.getInt(trun.offset + 12));
        if (count < 1 || count > MAX_PENDING_METADATA) throw new IOException("video sample count exceeds bound");
        at = trun.offset + 16;
        if ((flags & 1) == 0) throw new IOException("video sample data offset missing");
        within(trun, at, 4);
        if (bytes.getInt(at) != moof.length + 8) throw new IOException("video sample data offset differs");
        at += 4;
        int firstFlags = defaultFlags;
        if ((flags & 4) != 0) { within(trun, at, 4); firstFlags = bytes.getInt(at); at += 4; }
        long duration = 0, size = 0;
        for (int index = 0; index < count; index++) {
            long d = defaultDuration, n = defaultSize;
            if ((flags & 256) != 0) { within(trun, at, 4); d = Integer.toUnsignedLong(bytes.getInt(at)); at += 4; }
            if ((flags & 512) != 0) { within(trun, at, 4); n = Integer.toUnsignedLong(bytes.getInt(at)); at += 4; }
            if ((flags & 1024) != 0) {
                within(trun, at, 4);
                if (index == 0) firstFlags = bytes.getInt(at);
                at += 4;
            }
            if ((flags & 2048) != 0) {
                within(trun, at, 4);
                if (bytes.getInt(at) != 0) throw new IOException("reordered video frames cannot bind native receipts");
                at += 4;
            }
            if (d < 1 || n < 1) throw new IOException("video sample size or duration invalid");
            duration += d; size += n;
        }
        if ((firstFlags & 0x10000) != 0 || ((firstFlags >>> 24) & 3) != 2)
            throw new IOException("video fragment does not begin with an independent frame");
        if (at != trun.offset + trun.length || size != mdat.length - 8L)
            throw new IOException("video samples differ from complete media data");
        return new Fragment((int) count, pts, duration);
    }

    record Part(String type, int offset, int length) { }

    static void inspect(byte[] bytes, int start, int end, List<Part> result) throws IOException {
        if (result.size() > 256) throw new IOException("video box count exceeds bound");
        ByteBuffer buffer = ByteBuffer.wrap(bytes);
        for (int at = start; at < end;) {
            if (end - at < 8) throw new IOException("nested video box truncated");
            long length = Integer.toUnsignedLong(buffer.getInt(at));
            if (length < 8 || length > end - at) throw new IOException("nested video box length invalid");
            String type = new String(bytes, at + 4, 4, StandardCharsets.US_ASCII);
            Part part = new Part(type, at, (int) length); result.add(part);
            int skip = switch (type) {
                case "moov", "trak", "mdia", "minf", "stbl", "moof", "traf" -> 8;
                case "stsd" -> 16;
                case "avc1" -> 86;
                default -> 0;
            };
            if (skip > 0) {
                if (skip > length) throw new IOException("video container header truncated");
                inspect(bytes, at + skip, at + (int) length, result);
            }
            at += (int) length;
        }
    }

    static Part unique(List<Part> parts, String type) throws IOException {
        List<Part> found = parts.stream().filter(part -> part.type.equals(type)).toList();
        if (found.size() != 1) throw new IOException("video box missing or duplicated: " + type);
        return found.get(0);
    }
    static void require(Part part, int payload) throws IOException {
        if (part.length < 8 + payload) throw new IOException("video box payload truncated");
    }
    static void validateAvc(byte[] bytes, Part part) throws IOException {
        int at = part.offset + 12, end = part.offset + part.length;
        within(part, at, 2);
        if ((bytes[at++] & 255) != 255) throw new IOException("video AVC NAL length format invalid");
        int count = bytes[at++] & 31;
        if (count == 0) throw new IOException("video AVC sequence parameters missing");
        for (int index = 0; index < count; index++) {
            within(part, at, 2);
            int length = Short.toUnsignedInt(ByteBuffer.wrap(bytes).getShort(at)); at += 2;
            within(part, at, length);
            if (length < 4 || (bytes[at] & 31) != 7
                    || bytes[at + 1] != bytes[part.offset + 9] || bytes[at + 2] != bytes[part.offset + 10]
                    || bytes[at + 3] != bytes[part.offset + 11]) throw new IOException("video AVC codec differs from its sequence parameters");
            at += length;
        }
        within(part, at, 1); count = bytes[at++] & 255;
        if (count == 0) throw new IOException("video AVC picture parameters missing");
        for (int index = 0; index < count; index++) {
            within(part, at, 2);
            int length = Short.toUnsignedInt(ByteBuffer.wrap(bytes).getShort(at)); at += 2;
            within(part, at, length);
            if (length < 1 || (bytes[at] & 31) != 8) throw new IOException("video AVC picture parameters invalid");
            at += length;
        }
        // High-profile configuration may append chroma/depth and SPS extension
        // records. Validate their lengths rather than accepting trailing bytes.
        if (at < end) {
            within(part, at, 4);
            at += 3; count = bytes[at++] & 255;
            for (int index = 0; index < count; index++) {
                within(part, at, 2);
                int length = Short.toUnsignedInt(ByteBuffer.wrap(bytes).getShort(at)); at += 2;
                within(part, at, length); at += length;
            }
        }
        if (at != end) throw new IOException("video AVC configuration has trailing bytes");
    }
    static void within(Part part, int at, int count) throws IOException {
        if (at < part.offset + 8 || at + count > part.offset + part.length)
            throw new IOException("video field lies outside complete box");
    }
    static byte[] join(byte[] first, byte[] last) throws IOException {
        if ((long) first.length + last.length > MAX_BOX_BYTES) throw new IOException("video fragment exceeds byte bound");
        byte[] result = Arrays.copyOf(first, first.length + last.length);
        System.arraycopy(last, 0, result, first.length, last.length); return result;
    }
    static String sha(byte[] bytes) throws IOException {
        try { return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes)); }
        catch (java.security.NoSuchAlgorithmException impossible) { throw new IOException("SHA-256 unavailable", impossible); }
    }
    static String quote(String text) {
        StringBuilder value = new StringBuilder("\"");
        for (int index = 0; index < text.length(); index++) {
            char ch = text.charAt(index);
            if (ch == '\\' || ch == '"') value.append('\\').append(ch);
            else if (ch < 32) value.append(String.format("\\u%04x", (int) ch));
            else value.append(ch);
        }
        return value.append('"').toString();
    }
}
