import java.awt.image.BufferedImage;
import java.lang.reflect.Field;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;
import javax.imageio.ImageIO;

/** Controlled engine stubs and GPU bytes only. No game, encoder, or save is opened. */
public final class StudyNativeMenuCapture21Test {
    private static final String SESSION = "12345678-1234-1234-1234-123456789abc";
    private static int checks;
    private static Path root;

    private static void check(boolean condition, String message) {
        checks++;
        if (!condition) throw new AssertionError(message);
    }

    private static void field(Class<?> type, String name, Object value) throws Exception {
        Field field = type.getDeclaredField(name);
        field.setAccessible(true);
        field.set(null, value);
    }

    private static Object field(Class<?> type, String name) throws Exception {
        Field field = type.getDeclaredField(name);
        field.setAccessible(true);
        return field.get(null);
    }

    private static StudyViewCapture.FrameStamp sample() {
        StudyViewCapture.FrameStamp frame = StudyParticipant.frame();
        check(frame != null && StudyViewCapture.frameCurrent(frame), "game-thread sample is not current");
        return frame;
    }

    private static void menu() {
        zombie.characters.IsoPlayer.players[0] = null;
        zombie.core.Core.gameSaveWorld = null;
        zombie.core.Core.mode = "MainMenu";
        zombie.ZomboidFileSystem.instance.directory = null;
    }

    private static zombie.characters.IsoPlayer body(int sql) {
        zombie.iso.IsoWorld.instance.currentCell = new zombie.iso.IsoCell();
        zombie.GameTime.hours = 42.5;
        zombie.core.Core.gameSaveWorld = "ChosenSave";
        zombie.core.Core.mode = "Sandbox";
        var player = new zombie.characters.IsoPlayer();
        player.sqlId = sql;
        zombie.characters.IsoPlayer.players[0] = player;
        return player;
    }

    private static void context(StudyViewCapture.FrameStamp frame, boolean observed, boolean persisted) {
        var capture = frame.participant().capture();
        check(capture != null && capture.pid() == ProcessHandle.current().pid()
            && capture.sessionId().equals(SESSION) && capture.attempt() == 1, "context identity was inferred");
        String json = capture.json(null);
        check(json.contains("\"namespace\":\"native-play\"")
            && json.contains("\"bodyObserved\":" + observed)
            && json.contains("\"binding\":\"" + (persisted ? "persisted" : "unbound") + "\""),
            "context body or binding is false");
        check(json.contains("\"worldClock\":\"" + (observed ? "observed" : "unavailable") + "\""),
            "context world clock is false");
        check(json.contains("\"worldHours\":" + (observed ? "42.5" : "null")),
            "context world hours are invented");
        check(persisted == json.contains("\"playerSqlId\":"), "unbound context claimed SQL identity");
        check(persisted == json.contains("\"playerIndex\":"), "unbound context claimed a slot");
        check(!json.contains("\"streamId\":"), "PNG context invented video stream");
    }

    private static void png(StudyViewCapture.FrameStamp menu) throws Exception {
        byte[] rgb = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12};
        check(StudyViewCapture.beginCapture(menu), "unbound menu PNG refused");
        String filename = StudyViewCapture.pending;
        StudyViewCapture.publishPixels(filename, 2, 2, rgb);
        Path manifest = root.resolve("native-view/native.json");
        String value = Files.readString(manifest);
        check(value.contains("\"captureContext\":" + menu.participant().capture().json(null)),
            "menu PNG lost exact game-thread context");
        check(value.contains("\"hours\":0.0") && value.contains("\"worldClock\":\"unavailable\""),
            "placeholder video clock was represented as observed");
        BufferedImage image = ImageIO.read(root.resolve("native-view").resolve(filename).toFile());
        check(image.getWidth() == 2 && image.getHeight() == 2
            && (image.getRGB(0, 0) & 0xffffff) == 0x070809
            && (image.getRGB(1, 1) & 0xffffff) == 0x040506, "original RGB/PNG orientation changed");
        StudyViewCapture.FrameStamp later = sample();
        check(later.participant().capture().captureEpoch() == menu.participant().capture().captureEpoch()
            && StudyViewCapture.frameCurrent(menu), "stable null-body menu churned epoch");
    }

    private static final class Gpu implements StudyVideoCapture.Readback {
        int buffers, captures, maps;
        long fences;
        boolean signal;
        final Set<Long> liveFences = new HashSet<>();
        final Set<Integer> liveBuffers = new HashSet<>();
        public int width() { return 320; }
        public int height() { return 180; }
        public void verifyContext() { }
        public int createBuffer(int width, int height) {
            check(width == 320 && height == 180, "buffer geometry changed");
            int id = ++buffers; liveBuffers.add(id); return id;
        }
        public long capture(int buffer, int width, int height) {
            check(liveBuffers.contains(buffer) && width == 320 && height == 180, "capture used foreign buffer");
            captures++; long id = ++fences; liveFences.add(id); return id;
        }
        public boolean ready(long fence) { return signal; }
        public byte[] pixels(int buffer, int width, int height) {
            check(liveBuffers.contains(buffer), "mapping used released buffer");
            maps++; byte[] pixels = new byte[width * height * 3];
            for (int at = 0; at < pixels.length; at++) pixels[at] = (byte) (at * 17 + 3);
            return pixels;
        }
        public void releaseFence(long fence) { check(liveFences.remove(fence), "fence released twice"); }
        public void releaseBuffer(int buffer) { check(liveBuffers.remove(buffer), "buffer released twice"); }
    }

    private static StudyVideoCapture.Producer currentProducer() throws Exception {
        return (StudyVideoCapture.Producer) field(StudyVideoCapture.class, "producer");
    }

    private static void tick(StudyViewCapture.FrameStamp frame) throws Exception {
        field(StudyVideoCapture.class, "nextCapture", 0L);
        StudyVideoCapture.swapped(frame);
    }

    private static void settle(StudyViewCapture.FrameStamp frame) throws Exception {
        Thread retiring = (Thread) field(StudyVideoCapture.class, "retirementWorker");
        check(retiring != null, "same-geometry source boundary did not retire stream");
        retiring.join(10000);
        check(!retiring.isAlive(), "retirement did not complete");
        field(StudyVideoCapture.class, "geometryChangedAt",
            System.nanoTime() - StudyVideoCapture.GEOMETRY_STABLE_NS - 1);
        tick(frame);
    }

    private static void sidecar(StudyVideoCapture.Producer producer, StudyViewCapture.FrameStamp frame) throws Exception {
        producer.writeNativeContext();
        Path path = producer.root.resolve("video-" + producer.streamId + "-native-context.json");
        byte[] before = Files.readAllBytes(path);
        check(new String(before).contains(frame.participant().capture().json(producer.streamId)),
            "stream sidecar lost exact source/PID/attempt/epoch binding");
        producer.writeNativeContext();
        check(Arrays.equals(before, Files.readAllBytes(path)), "immutable stream sidecar was replaced");
    }

    private static void concurrentInvalidation(StudyViewCapture.FrameStamp old) throws Exception {
        CountDownLatch entered = new CountDownLatch(1), release = new CountDownLatch(1);
        AtomicReference<Throwable> failure = new AtomicReference<>();
        zombie.characters.IsoPlayer.players[0] = new zombie.characters.IsoPlayer() {
            @Override public float getX() {
                entered.countDown();
                try {
                    if (!release.await(5, TimeUnit.SECONDS)) throw new AssertionError("controlled sample was not released");
                } catch (InterruptedException interrupted) {
                    Thread.currentThread().interrupt();
                    throw new AssertionError(interrupted);
                }
                return super.getX();
            }
        };
        Thread gameThread = new Thread(() -> {
            try { StudyParticipant.binding(); }
            catch (Throwable error) { failure.set(error); }
        }, "controlled-native-sample");
        gameThread.start();
        try {
            check(entered.await(5, TimeUnit.SECONDS), "controlled game-thread sample did not enter");
            check(!StudyViewCapture.frameCurrent(old), "old frame remained current during body replacement sample");
        } finally { release.countDown(); }
        gameThread.join(5000);
        check(!gameThread.isAlive() && failure.get() == null, "controlled game-thread sample failed");
        check(!StudyViewCapture.frameCurrent(old), "old frame resumed after body replacement");
    }

    private static void video(StudyViewCapture.FrameStamp menuA) throws Exception {
        Gpu gpu = new Gpu();
        field(StudyVideoCapture.class, "readback", gpu);
        field(StudyVideoCapture.class, "producerFactory",
            (StudyVideoCapture.ProducerFactory) (r, e, w, h, fps) -> new StudyVideoCapture.Producer(r, e, w, h, fps, false));
        tick(menuA);
        StudyVideoCapture.Producer menuProducer = currentProducer();
        check(menuProducer.captured.get() == 1 && gpu.maps == 0, "menu pixels were read before fence");
        body(-1);
        StudyViewCapture.FrameStamp bodyB = sample();
        check(!StudyViewCapture.frameCurrent(menuA), "menu A survived body B");
        gpu.signal = true;
        var poll = StudyVideoCapture.class.getDeclaredMethod("pollReady");
        poll.setAccessible(true); poll.invoke(null);
        check(menuProducer.dropped.get() == 1 && gpu.maps == 0 && menuProducer.nativeCaptureContext.get() == null,
            "stale menu PBO entered stream or context");
        tick(bodyB);
        settle(bodyB);
        StudyVideoCapture.Producer bodyProducer = currentProducer();
        check(bodyProducer != menuProducer && bodyProducer.width == menuProducer.width
            && bodyProducer.height == menuProducer.height, "same-geometry body did not start own stream");
        tick(bodyB);
        check(bodyProducer.latest.get() != null && bodyProducer.nativeCaptureContext.get().sameSource(bodyB.participant().capture()),
            "body PBO was not admitted with its context");
        sidecar(bodyProducer, bodyB);
        var foreign = menuA.participant().capture();
        boolean refused = false;
        try { bodyProducer.offerNativeContext(foreign); } catch (java.io.IOException expected) { refused = true; }
        check(refused, "another epoch relabeled the body stream");
        menu();
        StudyViewCapture.FrameStamp menuC = sample();
        check(!StudyViewCapture.frameCurrent(bodyB) && !StudyViewCapture.frameCurrent(menuA),
            "menu C accepted stale menu A or body B");
        tick(menuC);
        settle(menuC);
        StudyVideoCapture.Producer menuProducerC = currentProducer();
        tick(menuC);
        check(menuProducerC != bodyProducer && menuProducerC.nativeCaptureContext.get().sameSource(menuC.participant().capture()),
            "menu C was associated with body B stream");
        sidecar(menuProducerC, menuC);
        check(menuProducerC.nativeCaptureContext.get().worldHours() == null,
            "menu video sidecar invented world clock");
        check(gpu.captures >= 3 && gpu.maps >= 2, "source transitions skipped actual PBO path");
    }

    public static void main(String[] args) throws Exception {
        root = Path.of(args[0]); Files.createDirectories(root);
        System.setProperty("study.participantInput", "true");
        System.setProperty("study.nativePlay", "true");
        System.setProperty("study.observer", "false");
        System.setProperty("study.viewDirectory", root.resolve("native-view").toString());
        System.setProperty("study.videoEncoder", root.resolve("never-start.exe").toString());
        System.setProperty("study.videoFps", "120");
        zombie.ZomboidFileSystem.instance.screens = root.resolve("screens").toString();
        field(StudyParticipant.class, "session", SESSION);
        field(StudyParticipant.class, "attempt", 1);
        menu();
        StudyViewCapture.FrameStamp menuA = sample();
        context(menuA, false, false);
        png(menuA);
        video(menuA);
        var menuC = sample();
        context(menuC, false, false);
        var unassigned = body(-1);
        var bodyUnbound = sample();
        context(bodyUnbound, true, false);
        check(!StudyViewCapture.frameCurrent(menuC), "unbound body kept menu frame current");
        unassigned.sqlId = 7;
        var bodyPersisted = sample();
        context(bodyPersisted, true, true);
        check(!StudyViewCapture.frameCurrent(bodyUnbound), "SQL persistence did not move capture epoch");
        concurrentInvalidation(bodyPersisted);
        menu();
        var afterBody = sample();
        check(!StudyViewCapture.frameCurrent(bodyPersisted), "menu after body retained body frame");
        System.setProperty("study.nativePlay", "false");
        check(StudyParticipant.frame() == null, "legacy null-body capture behavior changed");
        check(!StudyViewCapture.frameCurrent(afterBody), "native menu frame survived native-play disable");
        System.out.println("PASS " + checks + " controlled checks");
    }
}
