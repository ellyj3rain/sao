import java.lang.instrument.Instrumentation;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.Arrays;
import net.bytebuddy.agent.builder.AgentBuilder;
import net.bytebuddy.asm.MemberSubstitution;
import net.bytebuddy.matcher.ElementMatchers;
import net.bytebuddy.pool.TypePool;
import zombie.characters.IsoPlayer;
import zombie.characters.SurvivorDesc;
import zombie.core.Core;
import zombie.core.textures.TextureDraw;
import zombie.debug.DebugOptions;
import zombie.iso.sprite.shapers.FloorShaper;
import zombie.iso.sprite.shapers.WallShaper;
import zombie.iso.LightingJNI;

/** Native render buffers + production God-view configuration + actual lighting DLL, without a game world,
 * actor update loop, GL context or saves. A probe-only call receiver records the
 * exact arguments before forwarding them to the unchanged native JNI method.
 */
public final class NativeObserverLightingProbe {
    private static float[] received;

    public static void premain(String ignored, Instrumentation instrumentation) {
        var capture = TypePool.Default.of(NativeObserverLightingProbe.class.getClassLoader())
            .describe("NativeObserverLightingProbe").resolve().getDeclaredMethods()
            .filter(ElementMatchers.named("capture")).getOnly();
        new AgentBuilder.Default().disableClassFormatChanges()
            .with(AgentBuilder.RedefinitionStrategy.RETRANSFORMATION)
            .with(AgentBuilder.Listener.StreamWriting.toSystemError().withErrorsOnly())
            .type(ElementMatchers.named("zombie.iso.LightingJNI"))
            .transform((builder, type, loader, module, domain) -> builder.visit(
                MemberSubstitution.relaxed().method(ElementMatchers.named("playerSet")
                    .and(ElementMatchers.isDeclaredBy(ElementMatchers.named("zombie.iso.LightingJNI"))))
                    .replaceWith(capture).on(ElementMatchers.named("updatePlayer"))))
            .installOn(instrumentation);
    }

    public static void capture(float x, float y, float z, float lookX, float lookY,
            boolean first, boolean reanimated, boolean ghost, boolean shortsighted,
            float fatigue, float detection, float cone) {
        received = new float[] {x, y, z, lookX, lookY, first ? 1 : 0, reanimated ? 1 : 0,
            ghost ? 1 : 0, shortsighted ? 1 : 0, fatigue, detection, cone};
        LightingJNI.playerSet(x, y, z, lookX, lookY, first, reanimated, ghost, shortsighted,
            fatigue, detection, cone);
    }

    private static void check(boolean condition, String why) {
        if (!condition) throw new AssertionError(why);
    }

    private static void host(String name, Object value) throws Exception {
        Field field = StudyObserver.class.getDeclaredField(name); field.setAccessible(true); field.set(null, value);
    }

    private static TextureDraw darkDraw() {
        TextureDraw draw = new TextureDraw();
        draw.col0 = draw.col1 = draw.col2 = draw.col3 = 0xff000000;
        return draw;
    }

    private static Field field(Class<?> owner, String name) throws Exception {
        Field result = owner.getDeclaredField(name); result.setAccessible(true); return result;
    }

    private static void nativeCanopy(boolean observer) throws Exception {
        // Execute the installed private render overload and its real native
        // FBORenderTrees.addTree queue. No OpenGL draw or texture loading occurs:
        // empty native sprite frames yield null texture handles in this fixture.
        zombie.core.PerformanceSettings.fboRenderChunk = true;
        var manager = zombie.iso.sprite.IsoSpriteManager.instance;
        var batch = new zombie.iso.fboRenderChunk.FBORenderTrees();
        zombie.iso.fboRenderChunk.FBORenderTrees.current = batch;
        Method render = zombie.iso.objects.IsoTree.class.getDeclaredMethod("render", float.class,
            float.class, float.class, zombie.core.textures.ColorInfo.class, boolean.class, int.class, boolean.class);
        render.setAccessible(true);
        var draws = (java.util.List<?>) field(batch.getClass(), "trees").get(batch);
        var jumbo = new zombie.iso.IsoTreeJumbo.TreeDescription("probe-canopy", "probe-top", "probe-trunk", "", "", "");
        zombie.iso.IsoTreeJumbo.Jumbos.put(jumbo.main(), jumbo);
        for (String name : new String[] {jumbo.main(), jumbo.treetop(), jumbo.trunk(), "probe-small"}) {
            var sprite = new zombie.iso.sprite.IsoSprite(); sprite.name = name;
            manager.namedMap.put(name, sprite);
        }
        try {
            for (boolean large : new boolean[] {true, false}) for (int slot : new int[] {0, 1}) {
                var tree = new zombie.iso.objects.IsoTree();
                tree.sprite = manager.getSprite(large ? jumbo.main() : "probe-small");
                field(tree.getClass(), "cutawayAlpha").setFloat(tree, 1);
                int damage = tree.getHealth(), size = tree.size;
                draws.clear();
                render.invoke(tree, 12f, 12f, 0f, new zombie.core.textures.ColorInfo(1, 1, 1, 1), false, slot, false);
                boolean cut = observer && slot == 0;
                check(draws.size() == (cut && large ? 2 : 1), "native canopy did not select the trunk/treetop path");
                for (int i = 0; i < draws.size(); i++) {
                    Object draw = draws.get(i);
                    boolean hidden = cut && (!large || i == 1);
                    check(field(draw.getClass(), "transparent").getBoolean(draw) == hidden
                        && field(draw.getClass(), "cutawayAlpha").getFloat(draw) == (hidden ? 0 : 1),
                        "native canopy alpha concealed people or altered ordinary trees");
                }
                check(tree.getHealth() == damage && tree.size == size && tree.square == null,
                    "canopy rendering changed physical tree state");
            }
        } finally {
            zombie.iso.fboRenderChunk.FBORenderTrees.current = null;
            zombie.iso.IsoTreeJumbo.Jumbos.remove(jumbo.main());
            for (String name : new String[] {jumbo.main(), jumbo.treetop(), jumbo.trunk(), "probe-small"}) manager.namedMap.remove(name);
        }
    }

    private static void nativeRenderBuffers(boolean observer) throws Exception {
        FloorShaper floor = new FloorShaper();
        floor.setVertColors(0xff000000, 0xff000000, 0xff000000, 0xff000000);
        TextureDraw floorDraw = darkDraw(); floor.accept(floorDraw);
        check((floorDraw.col0 == -1 && floorDraw.col1 == -1 && floorDraw.col2 == -1 && floorDraw.col3 == -1) == observer,
            "native God-view floor remained dark or altered ordinary display");
        WallShaper wall = new WallShaper(); Arrays.fill(wall.col, 0xff000000);
        TextureDraw wallDraw = darkDraw(); wall.accept(wallDraw);
        check(((wallDraw.col0 & 0xffffff) == 0xffffff && (wallDraw.col1 & 0xffffff) == 0xffffff
            && (wallDraw.col2 & 0xffffff) == 0xffffff && (wallDraw.col3 & 0xffffff) == 0xffffff) == observer,
            "native God-view wall remained dark or altered ordinary display");
        zombie.iso.IsoObject renderedObject = new zombie.iso.IsoObject();
        renderedObject.setAlpha(0, .25f);
        check(renderedObject.getAlpha(0) == (observer ? 1 : .25f), "native God-view fading differs");
        check(DebugOptions.instance.fboRenderChunk.renderVisionPolygon.getValue() != observer,
            "God-view still uses an observer vision polygon");
        if (observer) {
            // These native methods must return before touching deliberately
            // invalid player indices, rather than calculating an observer LOS
            // polygon or refreshing every square's display-light cache.
            try {
                zombie.vispoly.VisibilityPolygon2.getInstance().renderMain(Integer.MAX_VALUE);
                Method lighting = zombie.iso.fboRenderChunk.FBORenderCell.class.getDeclaredMethod("updateChunkLighting", int.class);
                lighting.setAccessible(true);
                lighting.invoke(zombie.iso.fboRenderChunk.FBORenderCell.instance, Integer.MAX_VALUE);
            } catch (Throwable failure) { throw new AssertionError("God-view entered per-camera visibility or lighting work", failure); }
        }
    }

    private static void geometry(boolean wall) {
        for (int cy = 0; cy < 3; cy++) for (int cx = 0; cx < 3; cx++) {
            LightingJNI.chunkBeginUpdate(cx, cy, 32, 32);
            LightingJNI.chunkLevelBeginUpdate(32);
            for (int y = 0; y < 8; y++) for (int x = 0; x < 8; x++) {
                LightingJNI.squareBeginUpdate(x, y, 32);
                boolean blocked = wall && cx * 8 + x == 13;
                LightingJNI.squareSet(blocked ? 0 : 255, true, false, false,
                    blocked ? 0x07ffffff : 0, -1L, -1L, 15, true);
                LightingJNI.squareSetLightTransmission(0, 0, 0, Float.MAX_VALUE, 0,
                    0, 0, 0, Float.MAX_VALUE, 0, 0, 0, 0, Float.MAX_VALUE, 0,
                    0, 0, 0, Float.MAX_VALUE, 0);
                LightingJNI.squareEndUpdate();
            }
            LightingJNI.chunkLevelEndUpdate();
            LightingJNI.chunkEndUpdate();
        }
    }

    public static void main(String[] args) throws Exception {
        String kind = args[1]; boolean wall = Boolean.parseBoolean(args[2]);
        boolean observer = "observer".equals(kind);
        zombie.core.random.RandStandard.INSTANCE.init();
        zombie.Lua.LuaManager.platform = new se.krka.kahlua.j2se.J2SEPlatform();
        zombie.Lua.LuaManager.env = zombie.Lua.LuaManager.platform.newTable();
        zombie.Lua.LuaEventManager.register(zombie.Lua.LuaManager.platform, zombie.Lua.LuaManager.env);
        zombie.SoundManager.instance = new zombie.DummySoundManager();
        Core.debug = true;
        StudyObserver.Anchor anchor = new StudyObserver.Anchor();
        StudyObserver.View view = new StudyObserver.View();
        anchor.setX(12.5f); anchor.setY(12.5f); anchor.setZ(0);
        view.setX(18.5f); view.setY(18.5f); view.setZ(0);
        host("anchor", anchor); host("camera", view); host("ready", true);
        IsoPlayer ordinary = new IsoPlayer(null, new SurvivorDesc(false), 0, 0, 0, true);
        ordinary.setX(12.5f); ordinary.setY(12.5f);
        IsoPlayer.players[0] = "foreign".equals(kind) ? ordinary : anchor;
        IsoPlayer.players[1] = "extra-slot".equals(kind) ? ordinary : null;
        IsoPlayer.numPlayers = "extra-slot".equals(kind) ? 2 : 1;
        IsoPlayer.setInstance(IsoPlayer.players[0]);
        DebugOptions.instance.fboRenderChunk.nolighting.setValue(false);
        DebugOptions.instance.fboRenderChunk.renderVisionPolygon.setValue(true);
        DebugOptions.instance.terrain.renderTiles.forceFullAlpha.setValue(false);
        check(StudyObserver.configureGodView() == observer, "God-view configuration accepted the wrong owner");
        nativeRenderBuffers(observer);
        nativeCanopy(observer);
        System.load(args[0]); LightingJNI.configure(.005f);
        long start = System.nanoTime();
        for (int frame = 0; frame < 120; frame++) {
            LightingJNI.stateBeginUpdate(0, 0, 0, 3, 3);
            received = null;
            LightingJNI.updatePlayer(0);
            check(received != null, "native lighting call receiver missing");
            check(received[5] == 0, "observer changed native first lighting boolean");
            check(received[0] == 12.5f && received[1] == 12.5f && received[2] == 32,
                "independent camera changed native lighting coordinates");
            LightingJNI.stateEndFrame(1, 1, 1, 1, 0, 60, 60, true, 100, 15);
            if (frame == 0) geometry(wall);
            LightingJNI.stateEndUpdate();
            LightingJNI.DoLightingUpdateNew(start + frame * 33333333L, frame < 3);
        }
        int present = 0, canSee = 0, couldSee = 0, lit = 0, targetLit = 0;
        int[] data = new int[49];
        for (int y = 0; y < 24; y++) for (int x = 0; x < 24; x++) {
            if (!LightingJNI.getSquareLighting(0, x, y, 32, data)) continue;
            present++;
            if ((data[0] & 2) != 0) canSee++;
            if ((data[0] & 4) != 0) couldSee++;
            if ((data[1] & 0xffffff) != 0) lit++;
            if (data[3] > 0) targetLit++;
        }
        check(present == 576, "native lighting fixture omitted squares");
        check(canSee > 0 && canSee < 576 && (wall ? couldSee < 576 : couldSee == 576),
            "God-view changed native lighting visibility or occlusion");
        check(lit > 0 && targetLit > 0, "native visibility bits concealed zero color or dark output");
        check(LightingJNI.getSquareLighting(0, 12, 12, 32, data) && (data[1] & 0xffffff) != 0
            && data[2] > 0 && data[3] > 0, "native center RGB/dark/targetDark vanished");
        check(anchor.isDead() && !anchor.isAlive(), "God-view changed target eligibility");
        System.out.println("PASS production observer lighting: kind=" + kind + " wall=" + wall
            + " present=" + present + " canSee=" + canSee + " couldSee=" + couldSee
            + " lit=" + lit + " targetLit=" + targetLit
            + "; native floor/wall fullbright buffers, fade/mask controls, unchanged JNI visibility/RGB/dark; no rendered-world claim");
        LightingJNI.destroy();
    }
}
