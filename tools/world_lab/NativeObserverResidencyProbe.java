import java.util.ArrayList;
import java.util.Collections;
import zombie.iso.IsoCell;
import zombie.iso.IsoChunk;
import zombie.iso.IsoChunkMap;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoWorld;
import zombie.iso.LightingJNI;

/** Executes installed chunk ownership methods without starting a world or streamer. */
public final class NativeObserverResidencyProbe {
    private static void check(boolean value, String message) {
        if (!value) throw new AssertionError(message);
    }

    private static void lightingReadiness(IsoChunkMap map) throws Exception {
        var field = LightingJNI.class.getDeclaredField("updateCounter");
        field.setAccessible(true);
        int[] counters = (int[]) field.get(null);
        boolean previousInit = LightingJNI.init;
        int previousCounter = counters[map.playerId];
        try {
            // The DLL is deliberately not loaded. A native dispatch therefore
            // produces UnsatisfiedLinkError, independently of our assertions.
            LightingJNI.init = true;
            counters[map.playerId] = -1;
            try { StudyObserver.prepareRegionLighting(map); }
            catch (UnsatisfiedLinkError error) {
                throw new AssertionError("uninitialized regional lighting attempted native teleport", error);
            }
            counters[map.playerId] = 0;
            LightingJNI.init = false;
            try { StudyObserver.prepareRegionLighting(map); }
            catch (UnsatisfiedLinkError error) {
                throw new AssertionError("unloaded lighting library attempted native teleport", error);
            }
            LightingJNI.init = true;
            boolean dispatched = false;
            try { StudyObserver.prepareRegionLighting(map); }
            catch (UnsatisfiedLinkError expected) {
                check(expected.getMessage().contains("LightingJNI.teleport"), "unrelated native failure in lighting control");
                dispatched = true;
            }
            check(dispatched, "established regional lighting did not dispatch teleport");
        } finally {
            LightingJNI.init = previousInit;
            counters[map.playerId] = previousCounter;
        }
        System.out.println("PASS actual lighting counters gate teleport: absent state/library skips; established counter dispatches; native completion untested");
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
        IsoWorld.instance.currentCell = cell;
        var meta = IsoWorld.instance.getMetaGrid();
        meta.minX = meta.minY = 0; meta.maxX = meta.maxY = 2;
        IsoChunkMap primary = cell.getChunkMap(0), secondary = cell.getChunkMap(1);
        lightingReadiness(secondary);
        primary.worldX = secondary.worldX = 32;
        primary.worldY = secondary.worldY = 32;
        primary.ignore = secondary.ignore = false;
        int width = IsoChunkMap.chunkGridWidth, half = width / 2;
        int left = 32 - half, top = 32 - half;
        ArrayList<IsoChunk> chunks = new ArrayList<>();
        int loadedCount = 0, pendingCount = 0;
        for (int x = 0; x < width; x++) for (int y = 0; y < width; y++) {
            IsoChunk chunk = new IsoChunk(cell);
            chunk.wx = left + x; chunk.wy = top + y;
            chunk.assignLoadID();
            chunk.refs.add(primary);
            chunk.loaded = (x + y) % 2 == 0;
            IsoChunkMap.SharedChunks.put((chunk.wx << 16) + chunk.wy, chunk);
            if (chunk.loaded) {
                loadedCount++;
                IsoGridSquare square = new IsoGridSquare(cell, null, chunk.wx * 8, chunk.wy * 8, 0);
                chunk.setSquare(0, 0, 0, square); square.chunk = chunk;
                primary.getChunks()[x + y * width] = chunk;
            } else pendingCount++;
            chunks.add(chunk);
        }
        int pooled = IsoChunkMap.chunkStore.size();
        int deliveries = IsoChunk.loadGridSquare.size();
        IsoChunkMap.bSettingChunk.lock();
        try { StudyObserver.loadRegion(cell, secondary); }
        finally { IsoChunkMap.bSettingChunk.unlock(); }
        check(loadedCount > 0 && pendingCount > 0, "fixture lacks loaded or pending chunks");
        for (IsoChunk chunk : chunks) {
            check(Collections.frequency(chunk.refs, primary) == 1
                    && Collections.frequency(chunk.refs, secondary) == 1,
                "regional full-grid ownership missing or duplicated");
            if (chunk.loaded) {
                check(secondary.getChunk(chunk.wx - left, chunk.wy - top) == chunk,
                    "loaded shared chunk absent after region buffer swap");
                check(cell.getGridSquareDirect((chunk.wx - left) * 8, (chunk.wy - top) * 8, 0, 1)
                        == chunk.getGridSquare(0, 0, 0), "loaded regional square lookup missing");
            }
        }
        // Calling the native acquisition method again must not duplicate custody.
        for (IsoChunk chunk : chunks) {
            secondary.LoadChunkForLater(chunk.wx, chunk.wy, chunk.wx - left, chunk.wy - top);
            check(Collections.frequency(chunk.refs, secondary) == 1, "repeated native acquisition duplicated ownership");
        }
        primary.Unload();
        for (IsoChunk chunk : chunks) {
            check(chunk.refs.size() == 1 && chunk.refs.get(0) == secondary,
                "primary unload removed secondary ownership");
            check(IsoChunkMap.SharedChunks.get((chunk.wx << 16) + chunk.wy) == chunk
                    && chunk.getLoadID() != -1, "primary unload released a shared regional chunk");
            if (chunk.loaded) check(secondary.getChunk(chunk.wx - left, chunk.wy - top) == chunk,
                "primary unload invalidated the secondary loaded pointer");
        }
        check(IsoChunkMap.chunkStore.size() == pooled && IsoChunk.loadGridSquare.size() == deliveries,
            "shared ownership test unexpectedly pooled or queued a chunk");
        System.out.println("PASS installed regional full-grid custody: " + loadedCount + " loaded and "
            + pendingCount + " pending chunks; native primary unload preserves secondary ownership");
    }
}
