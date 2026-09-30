import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.nio.file.Files;
import java.nio.file.Path;
import zombie.GameWindow;
import zombie.characters.IsoPlayer;
import zombie.core.Core;
import zombie.iso.IsoCamera;
import zombie.iso.IsoCell;

/** Installed engine method probe. It creates no game window or world loop. */
public final class NativeObserverSitesProbe {
    private static void check(boolean value, String message) {
        if (!value) throw new AssertionError(message);
    }
    private static void host(String name, Object value) throws Exception {
        Field field = StudyObserver.class.getDeclaredField(name);
        field.setAccessible(true); field.set(null, value);
    }
    public static void main(String[] args) throws Exception {
        zombie.core.random.RandStandard.INSTANCE.init();
        zombie.ZomboidFileSystem.instance.init();
        zombie.SoundManager.instance = new zombie.DummySoundManager();
        zombie.Lua.LuaManager.platform = new se.krka.kahlua.j2se.J2SEPlatform();
        zombie.Lua.LuaManager.env = zombie.Lua.LuaManager.platform.newTable();
        zombie.Lua.LuaEventManager.register(zombie.Lua.LuaManager.platform, zombie.Lua.LuaManager.env);
        IsoCell cell = new IsoCell(1, 1);
        zombie.iso.WorldReuserThread.instance.stop();
        zombie.iso.IsoWorld.instance.currentCell = cell;
        StudyObserver.installCellAdmission(cell);
        GameWindow.gameThread = Thread.currentThread();
        for (String key : new String[] {"minX", "minY", "originX", "originY", "originZ"}) System.setProperty("study." + key, "0");
        System.setProperty("study.maxX", "512"); System.setProperty("study.maxY", "512");
        System.setProperty("study.siteCount", "3");
        for (int index = 0; index < 3; index++) {
            String prefix = "study.site." + index + ".";
            System.setProperty(prefix + "id", "area-" + index);
            System.setProperty(prefix + "label", "Area " + index);
            System.setProperty(prefix + "x", Integer.toString(64 + 128 * index));
            System.setProperty(prefix + "y", "64");
            System.setProperty(prefix + "z", "0");
        }
        StudyObserver.beginWorld();
        StudyObserver.Anchor[] residents = new StudyObserver.Anchor[3];
        StudyObserver.View[] views = new StudyObserver.View[3];
        for (int index = 0; index < 3; index++) {
            residents[index] = new StudyObserver.Anchor(); views[index] = new StudyObserver.View();
            residents[index].playerIndex = index; residents[index].sqlId = -1;
            residents[index].setX(64 + 128 * index); residents[index].setY(64);
            views[index].setX(64 + 128 * index); views[index].setY(64);
            IsoPlayer.players[index] = residents[index]; cell.getChunkMap(index).ignore = false;
        }
        IsoPlayer.numPlayers = 3; IsoPlayer.players[3] = null; IsoPlayer.setInstance(residents[0]);
        host("anchor", residents[0]); host("camera", views[0]); host("cell", cell);
        host("extraAnchors", new StudyObserver.Anchor[] {residents[1], residents[2]});
        host("extraCameras", new StudyObserver.View[] {views[1], views[2]});
        host("ready", true); host("initializing", false);
        Core.debug = true;
        check(StudyObserver.hostOnly(), "three infrastructure slots are not detached");
        for (int index = 0; index < 3; index++) {
            check(StudyObserver.cameraFor(residents[index]) == views[index], "camera collapsed to primary slot");
            check(StudyObserver.residencyFor(views[index]) == residents[index], "residency collapsed to primary slot");
            check(!residents[index].isAlive() && residents[index].isGhostMode() && !residents[index].isCollidable(), "observer became a physical participant");
            IsoCamera.FrameState frame = new IsoCamera.FrameState(); frame.playerIndex = index;
            StudyObserver.frameState(frame);
            check(frame.camCharacter == views[index] && frame.camCharacterX == 64 + 128 * index,
                "native frame did not use its actual regional position");
        }
        Method set = StudyObserver.class.getDeclaredMethod("setResidency", int.class, float.class, float.class, float.class);
        set.setAccessible(true); set.invoke(null, 2, 360f, 70f, 0f);
        check(residents[2].getX() == 360 && residents[0].getX() == 64 && residents[1].getX() == 192,
            "targeted region command moved another residency slot");
        var regionalMap = cell.getChunkMap(2);
        regionalMap.worldX = 45; regionalMap.worldY = 8;
        // Native ProcessChunkPos invalidates these caches on a real map move.
        for (String key : new String[] {"xMinTiles", "yMinTiles", "xMaxTiles", "yMaxTiles"}) {
            Field cache = zombie.iso.IsoChunkMap.class.getDeclaredField(key); cache.setAccessible(true); cache.setInt(regionalMap, -1);
        }
        var loaded = new zombie.iso.IsoChunk(cell);
        loaded.wx = 45; loaded.wy = 8; loaded.loaded = true;
        var square = new zombie.iso.IsoGridSquare(cell, null, 362, 70, 0);
        loaded.setSquare(2, 6, 0, square); square.chunk = loaded;
        int center = zombie.iso.IsoChunkMap.chunkGridWidth / 2;
        regionalMap.getChunks()[center + center * zombie.iso.IsoChunkMap.chunkGridWidth] = loaded;
        Method viewSet = StudyObserver.class.getDeclaredMethod("setView", int.class, float.class, float.class, float.class);
        viewSet.setAccessible(true);
        Method visit = StudyObserver.class.getDeclaredMethod("cameraResidency", int.class,
            float.class, float.class, float.class, float.class, float.class, float.class);
        visit.setAccessible(true);
        visit.invoke(null, 2, 362f, 70f, 0f, 362f, 70f, 0f); viewSet.invoke(null, 2, 362f, 70f, 0f);
        check(residents[2].getX() == 360 && views[2].getX() == 362 && residents[0].getX() == 64,
            "loaded regional camera visit unnecessarily scrolled native residency");
        visit.invoke(null, 2, 362f, 70f, 0f, 400f, 70f, 0f);
        check(residents[2].getX() == 362, "independent regional residency request was silently retained");
        set.invoke(null, 2, 360f, 70f, 0f);
        loaded.loaded = false;
        visit.invoke(null, 2, 362f, 70f, 0f, 362f, 70f, 0f);
        check(residents[2].getX() == 362, "unloaded camera target was claimed inside proven residency");
        loaded.loaded = true;
        int boundary = regionalMap.getWorldXMaxTiles() - zombie.iso.IsoChunkMap.CHUNK_SIZE_IN_SQUARES;
        visit.invoke(null, 2, (float) boundary, 70f, 0f, (float) boundary, 70f, 0f);
        check(residents[2].getX() == boundary, "native loaded-boundary request did not relocate residency");
        regionalMap.getChunks()[center + center * zombie.iso.IsoChunkMap.chunkGridWidth] = null;
        set.invoke(null, 2, 360f, 70f, 0f);
        IsoPlayer.players[1] = null;
        check(!StudyObserver.hostOnly(), "missing regional infrastructure slot was accepted");
        IsoPlayer.players[1] = residents[1];
        System.out.println("PASS three native sites retain distinct rendering, streaming and participant exclusion");
        System.out.println("PASS actual loaded native interior retains residency while detached View moves; unloaded/boundary requests still relocate");
        Path state = Files.createTempFile("regional-observer-state-", ".json");
        host("stateFile", state); host("stopIssued", true);
        host("lastSnapshot", "{\"schema\":\"sao-study-observer/1\",\"status\":\"active\",\"hours\":3.25,"
            + "\"updatedAtUnixMs\":1,\"failure\":null}");
        String healthy = StudyObserver.snapshot();
        var map = cell.getChunkMap(2);
        cell.chunkMap[2] = null;
        try { StudyObserver.poll(); }
        catch (RuntimeException failure) {
            throw new AssertionError("missing native map did not preserve a failed clock receipt", failure);
        }
        check(Files.readString(state).contains("\"status\":\"failed\"")
            && Files.readString(state).contains("chunk map unavailable: slot=2")
            && Files.readString(state).contains("\"hours\":3.25"),
            "missing native map did not preserve a failed clock receipt");
        cell.chunkMap[2] = map;
        host("contextFailed", false); host("runtimeFailure", null); host("lastSnapshot", healthy);
        zombie.iso.IsoWorld.instance.currentCell = null;
        StudyObserver.poll();
        check(Files.readString(state).contains("native world replaced the owned observer cell"),
            "disposed native world was silently refreshed");
        zombie.iso.IsoWorld.instance.currentCell = cell;
        host("contextFailed", false); host("runtimeFailure", null); host("lastSnapshot", healthy);
        // Execute the transformed installed streaming method until its real
        // chunk-array lookup fails. No streaming thread or native world starts.
        Field chunks = zombie.iso.IsoChunkMap.class.getDeclaredField("chunksSwapA"); chunks.setAccessible(true);
        Object priorChunks = chunks.get(map); chunks.set(map, null);
        Field chunksB = zombie.iso.IsoChunkMap.class.getDeclaredField("chunksSwapB"); chunksB.setAccessible(true);
        Object priorChunksB = chunksB.get(map); chunksB.set(map, null);
        map.worldX = 46; map.worldY = 8;
        Throwable nativeFailure = null;
        try { map.ProcessChunkPos(residents[2]); }
        catch (Throwable failure) { nativeFailure = failure; }
        finally { chunks.set(map, priorChunks); chunksB.set(map, priorChunksB); }
        check(nativeFailure != null && Files.readString(state).contains("native observer streaming failed: slot=2")
            && Files.readString(state).contains("cause=" + nativeFailure.getClass().getSimpleName()),
            "native streaming exception lost its immediate cause receipt");
        String failed = Files.readString(state);
        StudyObserver.poll();
        check(Files.readString(state).equals(failed), "failed native context kept refreshing stale world state");
        Files.delete(state);
        System.out.println("PASS missing/disposed map and actual native streaming exceptions publish one failed receipt with original clock/cause");
    }
}
