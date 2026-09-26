import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.io.ByteArrayOutputStream;
import java.io.PrintStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.util.Arrays;
import java.util.Set;
import com.sun.nio.file.ExtendedOpenOption;
import sun.misc.Unsafe;
import zombie.GameWindow;
import zombie.characters.IsoGameCharacter;
import zombie.characters.IsoPlayer;
import zombie.characters.IsoZombie;
import zombie.characters.SurvivorDesc;
import zombie.core.Core;
import zombie.iso.IsoCamera;
import zombie.iso.IsoCell;

/** Native method probe only: no generated terrain, renderer, native physics or
 * running game loop. Run with the actual isolated-study agent and installed jar.
 */
public final class NativeObserverProbe {
    private static void check(boolean value, String why) {
        if (!value) throw new AssertionError(why);
    }

    private static Field field(Class<?> owner, String name) throws Exception {
        Field result = owner.getDeclaredField(name);
        result.setAccessible(true);
        return result;
    }

    private static void host(String name, Object value) throws Exception {
        field(StudyObserver.class, name).set(null, value);
    }

    private static String quietPoll() throws Exception {
        host("nextPoll", 0L); host("nextState", 0L);
        ByteArrayOutputStream logged = new ByteArrayOutputStream();
        PrintStream previous = System.err;
        try (var errors = new PrintStream(logged)) {
            System.setErr(errors);
            try { StudyObserver.poll(); } finally { System.setErr(previous); }
        }
        return logged.toString(java.nio.charset.StandardCharsets.UTF_8);
    }

    private static void membershipScan(IsoCell cell, StudyObserver.Anchor anchor, StudyObserver.View view) throws Exception {
        var map = cell.chunkMap[0];
        var active = map.getChunks(); var old = active[0]; boolean ignored = map.ignore;
        var chunk = new zombie.iso.IsoChunk(cell);
        chunk.setMinMaxLevel(-2, 4); chunk.loaded = true;
        var basement = new zombie.iso.IsoGridSquare(cell, null, 0, 0, -2);
        var roof = new zombie.iso.IsoGridSquare(cell, null, 7, 7, 4);
        chunk.setSquare(0, 0, -2, basement); chunk.setSquare(7, 7, 4, roof);
        basement.getMovingObjects().add(anchor); basement.getStaticMovingObjects().add(view);
        roof.getMovingObjects().add(view); roof.getStaticMovingObjects().add(anchor);
        Method scan = StudyObserver.class.getDeclaredMethod("squareMemberships"); scan.setAccessible(true);
        active[0] = chunk; map.ignore = false;
        try {
            check((Integer) scan.invoke(null) == 4, "observer scan omitted basement or roof membership");
            chunk.loaded = false;
            check((Integer) scan.invoke(null) == 0, "observer scan included undelivered chunks");
            chunk.loaded = true; map.ignore = true;
            check((Integer) scan.invoke(null) == 0, "observer scan included ignored chunk map");
        } finally { active[0] = old; map.ignore = ignored; }
    }

    private static void statePublicationLocks(Path control) throws Exception {
        Path state = control.resolveSibling("observer-state.json");
        host("stateFile", state);
        quietPoll();
        byte[] previous = Files.readAllBytes(state);
        // Real Windows reader sharing, through the production polling/command
        // path. A deferred receipt must not reject or apply a command twice.
        try (var reader = Files.newByteChannel(state,
                Set.of(StandardOpenOption.READ, ExtendedOpenOption.NOSHARE_DELETE))) {
            Files.writeString(control, "sequence=6\nviewX=12\n");
            check(quietPoll().isEmpty(), "transient state publication poisoned the run");
            check(StudyObserver.commandSequence() == 6 && !StudyObserver.snapshot().contains("\"rejectedSequence\":6"),
                "state sharing denial rejected an applied command");
            check(Arrays.equals(previous, Files.readAllBytes(state)), "state sharing denial changed prior acknowledgement");
        }
        check(quietPoll().isEmpty() && Files.readString(state).contains("\"sequence\":6"),
            "deferred observer acknowledgement did not recover");
        check(field(StudyObserver.class, "stateDeferrals").getInt(null) == 0, "state deferrals did not reset");
        try (var reader = Files.newByteChannel(state,
                Set.of(StandardOpenOption.READ, ExtendedOpenOption.NOSHARE_DELETE))) {
            Files.writeString(control, "sequence=7\nstop=true\n");
            check(quietPoll().isEmpty(), "transient stopping state poisoned the run");
            check(!GameWindow.closeRequested, "stop quit before final state publication");
        }
        check(quietPoll().isEmpty() && GameWindow.closeRequested && Files.readString(state).contains("\"sequence\":7"),
            "stop did not complete after final state publication");
        // A permanently denied stop remains bounded and visibly failed, while
        // native exit still preserves the world's normal save/quit route.
        GameWindow.closeRequested = false;
        host("stopping", false); host("stopIssued", false);
        int limit = field(StudyObserver.class, "MAX_STATE_DEFERRALS").getInt(null);
        check(limit > 1 && limit <= 30, "state publication retry limit is unbounded");
        try (var reader = Files.newByteChannel(state,
                Set.of(StandardOpenOption.READ, ExtendedOpenOption.NOSHARE_DELETE))) {
            Files.writeString(control, "sequence=8\nstop=true\n");
            String errors = "";
            for (int i = 0; i < limit && !GameWindow.closeRequested; i++) errors += quietPoll();
            check(errors.contains("[StudyObserver] FAILED cannot publish observer state:")
                && field(StudyObserver.class, "statePublicationFailed").getBoolean(null),
                "persistent state publication denial was hidden");
            check(GameWindow.closeRequested, "permanently denied final state blocked native stop");
            check(Files.readString(state).contains("\"sequence\":7"), "failed stop fabricated a durable acknowledgement");
        }
    }

    public static void main(String[] args) throws Exception {
        check(Boolean.getBoolean("study.observer"), "observer agent property required");
        zombie.core.random.RandStandard.INSTANCE.init();
        zombie.ZomboidFileSystem.instance.init();
        zombie.SoundManager.instance = new zombie.DummySoundManager();
        zombie.Lua.LuaManager.platform = new se.krka.kahlua.j2se.J2SEPlatform();
        zombie.Lua.LuaManager.env = zombie.Lua.LuaManager.platform.newTable();
        zombie.Lua.LuaEventManager.register(zombie.Lua.LuaManager.platform, zombie.Lua.LuaManager.env);
        IsoCell cell = new IsoCell(1, 1);
        zombie.iso.WorldReuserThread.instance.stop();
        StudyObserver.installCellAdmission(cell);
        cell.setSafeToAdd(true);
        zombie.iso.IsoWorld.instance.currentCell = cell;
        GameWindow.gameThread = Thread.currentThread();
        Path control = Path.of(System.getProperty("user.home"), "observer-control.properties");
        for (String name : new String[] {"minX", "minY", "originX", "originY", "originZ"})
            System.setProperty("study." + name, "0");
        System.setProperty("study.maxX", "512"); System.setProperty("study.maxY", "512");
        System.setProperty("study.observerControl", control.toString());
        boolean creation = StudyObserver.beginWorld();
        check(!zombie.SystemDisabler.doPlayerCreation, "native creation guard did not engage");
        zombie.SystemDisabler.doPlayerCreation = creation;

        StudyObserver.Anchor anchor = new StudyObserver.Anchor();
        host("anchor", anchor);
        // Loading-thread publication may expose only anchor.
        try { StudyObserver.poll(); }
        catch (Throwable failure) { throw new AssertionError("partially initialized poll reached native world", failure); }
        check(!StudyObserver.hostOnly(), "partially initialized observer was published");
        StudyObserver.View view = new StudyObserver.View();
        host("anchor", anchor); host("camera", view); host("cell", cell);
        IsoPlayer.numPlayers = 1; IsoPlayer.players[0] = anchor; anchor.playerIndex = 0;
        IsoPlayer.setInstance(anchor);
        host("ready", true); host("initializing", false);
        check(((Long) field(StudyObserver.class, "suppressedBirths").get(null)) == 1,
            "native constructor birth event was not suppressed before dispatch");
        check(Boolean.TRUE.equals(anchor.getModData().rawget(StudyObserver.MARKER)), "host marker absent");
        check(anchor.isDead() && !anchor.isAlive(), "anchor eligible for native alive-player scans");
        check(!IsoPlayer.allPlayersDead(), "native dead-player speed fallback was not separated from host scheduling");
        check(!IsoPlayer.allPlayersAsleep(), "host incorrectly triggers native all-players-asleep acceleration");
        check(!anchor.isCollidable() && anchor.isInvisible() && anchor.isGhostMode(), "anchor body flags incorrect");
        check(!cell.getObjectList().contains(anchor) && !cell.getAddList().contains(anchor)
            && !cell.getObjectList().contains(view) && !cell.getAddList().contains(view), "constructor published host body");
        check(anchor.getMovingSquare() == null && view.getMovingSquare() == null,
            "constructor published host square membership");
        membershipScan(cell, anchor, view);
        check(!anchor.isAddedToModelManager() && !view.isAddedToModelManager(), "constructor published host model");
        Field modelReady = field(zombie.core.skinnedmodel.ModelManager.class, "created");
        Object models = zombie.core.skinnedmodel.ModelManager.instance;
        boolean wasReady = modelReady.getBoolean(models);
        // Make the native Add guard eligible, without constructing GL resources.
        // Correct host overrides must not enter this deliberately incomplete
        // model fixture. Removing them reaches native model publication and fails.
        modelReady.setBoolean(models, true);
        try { anchor.setSceneCulled(false); view.setSceneCulled(false); }
        catch (Throwable failure) { throw new AssertionError("native scene unculling entered model publication", failure); }
        finally { modelReady.setBoolean(models, wasReady); }
        check(!anchor.isAddedToModelManager() && !view.isAddedToModelManager(), "native scene unculling published host model");
        String stats = anchor.getStats().toString();
        for (int i = 0; i < 10; i++) { anchor.preupdate(); anchor.update(); anchor.postupdate(); }
        check(stats.equals(anchor.getStats().toString()), "host update changed needs");
        check(((Long) field(StudyObserver.class, "suppressedUpdates").get(null)) == 30,
            "ordinary character update was reached");

        IsoCamera.setCameraCharacter(anchor);
        check(IsoCamera.getCameraCharacter() == view, "native camera setter conflated view with residency");
        check(StudyObserver.residencyFor(view) == anchor, "streaming does not follow residency");
        check(StudyObserver.participantInstance() == null, "loot context sees observer as participant");
        // Read an actual installed JNI lighting cache without initialized JNI,
        // a square, or terrain. A diagnostic getter that tries to refresh it
        // enters native lighting and fails instead of observing these values.
        var lightCache = new zombie.iso.LightingJNI.JNILighting(0, null);
        Class<?> lightType = lightCache.getClass();
        field(lightType, "updateTick").setInt(lightCache, 23);
        field(lightType, "vis").setByte(lightCache, (byte) 5);
        var color = (zombie.core.textures.ColorInfo) field(lightType, "lightInfo").get(lightCache);
        color.r = 0.25f; color.g = 0.5f; color.b = 0.75f;
        field(lightType, "cacheDarkMulti").setFloat(lightCache, 0.125f);
        field(lightType, "cacheTargetDarkMulti").setFloat(lightCache, 0.375f);
        Method readLight = StudyObserver.class.getDeclaredMethod("cachedLight", Object.class);
        readLight.setAccessible(true);
        Object observedLight = readLight.invoke(null, lightCache);
        Method lightJson = observedLight.getClass().getDeclaredMethod("json"); lightJson.setAccessible(true);
        check(lightJson.invoke(observedLight).equals("{\"updateTick\":23,\"visibility\":5,\"r\":0.25,\"g\":0.5,\"b\":0.75,\"dark\":0.125,\"targetDark\":0.375}"),
            "native lighting diagnostics changed or misread cached values");
        check(field(lightType, "updateTick").getInt(lightCache) == 23 && field(lightType, "vis").getByte(lightCache) == 5
            && color.r == 0.25f && color.g == 0.5f && color.b == 0.75f,
            "native lighting diagnostics mutated cache");
        check(readLight.invoke(null, new Object[] {null}) == null, "missing native lighting cache was fabricated");
        IsoPlayer ordinary = new IsoPlayer(null, new SurvivorDesc(false), 0, 0, 0, true);
        // Exercise the actual native direct/queued cell entry points and its
        // private queue merge. No source caller can publish our infrastructure
        // through these bound owners; ordinary native Set semantics remain.
        cell.setSafeToAdd(true);
        cell.addMovingObject(anchor); cell.addMovingObject(view); cell.addMovingObject(ordinary);
        check(cell.getObjectList().contains(ordinary) && !cell.getObjectList().contains(anchor)
            && !cell.getObjectList().contains(view), "native direct actor publication accepted observer");
        cell.getObjectList().clear();
        cell.setSafeToAdd(false);
        cell.addMovingObject(anchor); cell.addMovingObject(view); cell.addMovingObject(ordinary);
        check(cell.getAddList().contains(ordinary) && !cell.getAddList().contains(anchor)
            && !cell.getAddList().contains(view), "native queued actor publication accepted observer");
        Method merge = IsoCell.class.getDeclaredMethod("ObjectDeletionAddition"); merge.setAccessible(true);
        merge.invoke(cell);
        check(cell.getObjectList().size() == 1 && cell.getObjectList().contains(ordinary)
            && cell.getAddList().isEmpty(), "native actor queue merge changed ordinary admission");
        cell.getObjectList().clear();
        for (var owner : java.util.List.of(cell.getObjectList(), cell.getAddList(), cell.getRemoveList())) {
            check(owner.addAll(java.util.List.of(anchor, ordinary, view)) && owner.size() == 1
                && owner.contains(ordinary), "bulk actor publication accepted observer");
            check(!owner.addAll(java.util.List.of(anchor, ordinary, view)), "duplicate actor admission changed Set result");
            check(owner.equals(java.util.Set.of(ordinary)) && java.util.Set.of(ordinary).equals(owner)
                && owner.hashCode() == java.util.Set.of(ordinary).hashCode(), "ordinary actor Set equality changed");
            check(owner.toArray(zombie.iso.IsoMovingObject[]::new)[0] == ordinary
                && owner.stream().count() == 1 && owner.parallelStream().count() == 1,
                "ordinary actor Set traversal changed");
            var iterator = owner.iterator(); iterator.next(); iterator.remove();
            check(owner.isEmpty(), "ordinary actor iterator removal changed");
        }
        cell.setSafeToAdd(true);
        check(!StudyObserver.deadForStreaming(anchor), "observer excluded from native chunk delivery");
        check(anchor.isDead() && !anchor.isAlive(), "streaming adapter changed native target eligibility");
        check(StudyObserver.deadForStreaming(ordinary) == ordinary.isDead(),
            "ordinary streaming eligibility changed");
        // Execute the real installed cell method as far as its chunk-update
        // invocation. A deliberately absent map makes that exact dispatch fail
        // before native streaming/physics can run; the fixture does not load a
        // world or replace the update loop.
        var priorMap = cell.chunkMap[0];
        boolean dispatched = false;
        cell.chunkMap[0] = null;
        try {
            Method update = IsoCell.class.getDeclaredMethod("updateInternal"); update.setAccessible(true);
            update.invoke(cell);
        } catch (java.lang.reflect.InvocationTargetException invocation) {
            Throwable failure = invocation.getCause();
            dispatched = failure instanceof NullPointerException && failure.getMessage() != null
                && failure.getMessage().contains("IsoChunkMap.update()");
            if (!dispatched) failure.printStackTrace();
        } finally { cell.chunkMap[0] = priorMap; }
        check(dispatched, "native cell skipped observer chunk delivery");
        java.util.Set<Object> streamed = new java.util.HashSet<>();
        check(!StudyObserver.admitChunkActor(streamed, anchor) && !StudyObserver.admitChunkActor(streamed, view)
            && streamed.isEmpty(), "far streaming admitted observer actor");
        check(StudyObserver.admitChunkActor(streamed, ordinary) && streamed.contains(ordinary)
            && !StudyObserver.admitChunkActor(streamed, ordinary), "ordinary streaming admission changed");
        IsoPlayer.setInstance(ordinary);
        check(StudyObserver.participantInstance() == ordinary, "ordinary participant filtered from loot context");
        IsoCamera.setCameraCharacter(ordinary);
        check(IsoCamera.getCameraCharacter() == ordinary, "ordinary camera ownership changed");
        IsoPlayer.setInstance(anchor); IsoCamera.setCameraCharacter(anchor);

        Unsafe unsafe = (Unsafe) field(Unsafe.class, "theUnsafe").get(null);
        Object preview = unsafe.allocateInstance(zombie.ui.UI3DModel.class);
        ((zombie.ui.UI3DModel) preview).setCharacter(anchor);
        ((zombie.ui.UI3DModel) preview).render();
        check(!((zombie.ui.UI3DModel) preview).isVisible(), "observer avatar preview remains visible");
        Object database = unsafe.allocateInstance(zombie.savefile.PlayerDB.class);
        Method save = zombie.savefile.PlayerDB.class.getDeclaredMethod("savePlayerAsync", IsoPlayer.class);
        save.setAccessible(true);
        try { save.invoke(database, anchor); }
        catch (ReflectiveOperationException failure) {
            throw new AssertionError("native player DB attempted to persist observer", failure);
        }
        check(anchor.sqlId == -1 && ((Long) field(StudyObserver.class, "suppressedSaves").get(null)) == 1,
            "native player DB attempted to persist observer");

        // Execute the actual installed target-eligibility method. This zombie is
        // only a receiver fixture; its full AI/update loop is not being simulated.
        IsoZombie targetProbe = (IsoZombie) unsafe.allocateInstance(IsoZombie.class);
        field(IsoZombie.class, "vectorToTarget").set(targetProbe, new zombie.iso.Vector2());
        Method attack = IsoZombie.class.getDeclaredMethod("getShouldAttack"); attack.setAccessible(true);
        targetProbe.target = anchor;
        check(!(Boolean) attack.invoke(targetProbe), "native zombie attack method accepts host");
        targetProbe.target = ordinary;
        check((Boolean) attack.invoke(targetProbe), "ordinary-player attack eligibility control is insensitive");
        Core.debug = true;
        ordinary.setInvisible(true, true);
        check(!(Boolean) attack.invoke(targetProbe), "native ghost eligibility branch not exercised");

        float x = anchor.getX(), y = anchor.getY();
        Files.writeString(control, "sequence=1\nresidencyX=513\n");
        StudyObserver.poll();
        check(StudyObserver.snapshot().contains("\"sequence\":0"), "out-of-bounds command acknowledged");
        check(StudyObserver.snapshot().contains("\"rejectedSequence\":1"), "rejected command missing receipt");
        check(anchor.getX() == x && anchor.getY() == y, "rejected command moved residency");
        check(StudyObserver.snapshot().contains("\"detached\":true"), "native collection invariant failed");
        check(!IsoGameCharacter.getSurvivorMap().containsValue(anchor.getDescriptor()), "host descriptor registered as survivor");
        // Minimal UI receiver state only. The actual installed speed-control
        // methods execute, while drawing/buttons/textures remain outside scope.
        zombie.ui.SpeedControls speed = (zombie.ui.SpeedControls) unsafe.allocateInstance(zombie.ui.SpeedControls.class);
        for (String name : new String[] {"play", "pause", "fastForward", "fasterForward", "wait", "stepForward"}) {
            zombie.ui.HUDButton button = (zombie.ui.HUDButton) unsafe.allocateInstance(zombie.ui.HUDButton.class);
            field(zombie.ui.HUDButton.class, "name").set(button, name);
            field(zombie.ui.SpeedControls.class, name).set(null, button);
        }
        zombie.ui.UIManager.setSpeedControls(speed);
        Files.writeString(control, "sequence=2\nresidencyX=20\nviewX=10\npaused=true\nspeed=3\n");
        host("nextPoll", 0L); StudyObserver.poll();
        check(StudyObserver.snapshot().contains("\"sequence\":2"), "valid view/residency/pause command was not acknowledged");
        check(anchor.getX() == 20 && view.getX() == 10, "view and residency controls are not independent");
        check(speed.getCurrentGameSpeed() == 0, "native pause command did not apply");
        IsoCamera.frameState.set(0);
        check(IsoCamera.frameState.camCharacter == view && IsoCamera.frameState.camCharacterX == 10,
            "native renderer frame state uses residency instead of view");
        Files.writeString(control, "sequence=3\npaused=false\n");
        host("nextPoll", 0L); StudyObserver.poll();
        check(speed.getCurrentGameSpeed() == 3, "resume did not retain requested native speed");
        Files.writeString(control, "sequence=2\nresidencyX=100\n");
        host("nextPoll", 0L); StudyObserver.poll();
        check(anchor.getX() == 20 && StudyObserver.snapshot().contains("\"sequence\":3"), "stale command was applied");
        Files.writeString(control, "sequence=4\nviewX=30\nspeed=9\n");
        host("nextPoll", 0L); StudyObserver.poll();
        check(view.getX() == 10 && StudyObserver.snapshot().contains("\"sequence\":3"), "partially invalid command moved view or acknowledged");
        Class.forName("zombie.inventory.ItemPickerJava", false, NativeObserverProbe.class.getClassLoader());
        Class.forName("zombie.iso.LightingJNI", false, NativeObserverProbe.class.getClassLoader());
        zombie.ui.UIManager.debugBreakpoint("intentional-probe.lua", 7);
        Files.writeString(control, "sequence=5\npaused=true\n");
        host("nextPoll", 0L); StudyObserver.poll();
        check(StudyObserver.snapshot().contains("\"status\":\"failed\"")
            && StudyObserver.snapshot().contains("intentional-probe.lua:7"), "debugger suppression concealed native failure");
        check(StudyObserver.snapshot().contains("\"sequence\":5"), "debugger failure blocked subsequent controls");
        statePublicationLocks(control);
        System.out.println("PASS native observer: detached constructors; birth/save interception; native attack method with living/ghost controls; camera/frame/loot ownership; avatar preview excluded; scheduling; no needs update; independent coordinates, pause/resume/speed, stale and invalid control rejection; debugger failure remains visible while controls continue. No rendered-world or native-physics claim.");
        System.exit(0);
    }
}
