import java.lang.instrument.Instrumentation;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.List;

import com.sao.agent.SAOViewpointFrameTelemetry;

/** Controlled render-thread and native-capture binding; no GL or game launch. */
public final class CameraProbe {
    private static Instrumentation instrumentation;
    private static int checks;

    public static void premain(String arguments, Instrumentation supplied) {
        instrumentation = supplied;
    }

    private static void check(boolean value, String reason) {
        checks++;
        if (!value) throw new AssertionError(reason);
    }

    private static Method privateMethod(Class<?> owner, String name, Class<?>... types)
            throws Exception {
        Method method = owner.getDeclaredMethod(name, types);
        method.setAccessible(true);
        return method;
    }

    @SuppressWarnings("unchecked")
    public static void main(String[] arguments) throws Exception {
        check(instrumentation != null, "instrumentation unavailable");
        SAOViewpointFrameTelemetry.frameStarted();
        check(SAOViewpointFrameTelemetry.frameCompleted() == null,
            "uninstalled source reported a ready camera");
        check(SAOViewpointFrameTelemetry.install(instrumentation),
            "pinned SceneDrawer render was not instrumented");
        check("ready".equals(SAOViewpointFrameTelemetry.report()), "telemetry weave not ready");
        Method scene = privateMethod(SAOViewpointFrameTelemetry.class, "sceneRendered", String.class);

        SAOViewpointFrameTelemetry.frameStarted();
        check("isometric".equals(SAOViewpointFrameTelemetry.frameCompleted()),
            "an absent Viewpoint draw was not isometric");
        SAOViewpointFrameTelemetry.frameStarted();
        scene.invoke(null, "viewpoint-first");
        check("viewpoint-first".equals(SAOViewpointFrameTelemetry.frameCompleted()),
            "first-person draw did not label its frame");
        SAOViewpointFrameTelemetry.frameStarted();
        scene.invoke(null, "viewpoint-third");
        check("viewpoint-third".equals(SAOViewpointFrameTelemetry.frameCompleted()),
            "third-person draw did not label its frame");
        SAOViewpointFrameTelemetry.frameStarted();
        scene.invoke(null, "viewpoint-free");
        check("viewpoint-free".equals(SAOViewpointFrameTelemetry.frameCompleted()),
            "free-camera draw did not label its frame");
        SAOViewpointFrameTelemetry.frameStarted();
        scene.invoke(null, "viewpoint-first");
        scene.invoke(null, "viewpoint-third");
        check("unavailable".equals(SAOViewpointFrameTelemetry.frameCompleted()),
            "two differing draws invented one camera");
        SAOViewpointFrameTelemetry.frameStarted();
        scene.invoke(null, "unavailable");
        check("unavailable".equals(SAOViewpointFrameTelemetry.frameCompleted()),
            "failed scene draw was reported ready");
        check(SAOViewpointFrameTelemetry.frameCompleted() == null,
            "completed render slot leaked into later frame");

        Method start = privateMethod(StudyViewCapture.class, "telemetryStart");
        Method end = privateMethod(StudyViewCapture.class, "telemetryEnd",
            StudyViewCapture.FrameStamp.class);
        Field startedField = StudyViewCapture.class.getDeclaredField("TELEMETRY_STARTED");
        startedField.setAccessible(true);
        ThreadLocal<Boolean> started = (ThreadLocal<Boolean>) startedField.get(null);
        Object person = new Object();
        var participant = new StudyViewCapture.ParticipantFrame("{}", person, "controlled-save", 0, 1, 1);
        var stamp = new StudyViewCapture.FrameStamp(0, 20.0,
            new StudyObserver.SiteFrame[0], new StudyVideoCapture.Site[0], participant);
        check(Boolean.TRUE.equals(start.invoke(null)), "native capture missed telemetry start");
        started.set(true);
        scene.invoke(null, "viewpoint-third");
        var camera = (StudyViewCapture.FrameCamera) end.invoke(null, stamp);
        started.remove();
        check(camera != null && "viewpoint-third".equals(camera.mode()) && camera.ready(),
            "native capture sampled a later camera");
        check(camera.json().contains("\"mode\":\"viewpoint-third\""),
            "native camera JSON changed mode");
        var stamped = stamp.withCamera(camera);
        check(stamped.camera() == camera, "native frame lost camera at render exit");
        var videoFrame = new StudyVideoCapture.Frame(1, 1000, 0, 20.0,
            new StudyVideoCapture.Site[0], 4, 4, null, stamped.camera());
        check(StudyVideoCapture.frameWithoutPixels(videoFrame).camera() == camera,
            "PBO/video handoff dropped camera");
        check(StudyVideoCapture.cameraFramesJson(List.of(videoFrame)).contains("\"frameSequence\":1"),
            "video fragment did not bind camera to encoded frame sequence");

        var menu = new StudyViewCapture.FrameStamp(0, 0.0,
            new StudyObserver.SiteFrame[0], new StudyVideoCapture.Site[0],
            new StudyViewCapture.ParticipantFrame("{}", null, "", 0, -1, 1));
        check(Boolean.TRUE.equals(start.invoke(null)), "menu render telemetry unavailable");
        started.set(true);
        var menuCamera = (StudyViewCapture.FrameCamera) end.invoke(null, menu);
        started.remove();
        check(menuCamera != null && "unavailable".equals(menuCamera.mode()) && !menuCamera.ready(),
            "native menu was mislabeled as an isometric game frame");
        check(StudyVideoCapture.cameraFramesJson(List.of(
            new StudyVideoCapture.Frame(2, 1001, 0, 20.0,
                new StudyVideoCapture.Site[0], 4, 4, null))) == null,
            "legacy video frame acquired invented camera");
        System.out.println("PASS " + checks);
    }
}
