package com.sao.engine;

import zombie.iso.IsoCell;
import zombie.iso.IsoChunk;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoObject;
import zombie.iso.IsoWorld;
import zombie.iso.objects.IsoBarricade;
import zombie.iso.objects.interfaces.BarricadeAble;

/**
 * [C46] The ground a claim stands on, loaded during the years.
 *
 * The operator ruled the years between run for real - the ground is
 * loaded and the work happens - rather than the pass recording an
 * outcome and dressing the world to match on arrival (DR-036, DR-037).
 * This is the loading half of that, and only that half.
 *
 * WHY IT HAS TO BE DONE THIS WAY. The engine holds a sliding window of
 * 8 x 8 chunks - 64 x 64 squares - around each player
 * (IsoChunkMap.CHUNKS_PER_WIDTH), and it follows them. There is no
 * window to put a distant claim in, so `cell.getGridSquare` answers
 * nothing for ground nobody is standing near. A chunk can however be
 * loaded on its own: constructed against the cell, pointed at its
 * world coordinates and read off disk, which is what the engine's own
 * streamer does. That is what happens here.
 *
 * WHAT IT DOES NOT DO, DELIBERATELY. It writes nothing. No barricade is
 * added, no object is placed and no chunk is saved. `IsoChunk.Save`
 * writes into the player's own save directory through shared static
 * buffers (javap -c: ChunkMapFilenames.getDir on Core.gameSaveWorld,
 * the static sliceBuffer under WriteLock), and this mod has no live
 * receipt for any of it yet. Reading tells the county what its places
 * are actually like; writing is the next piece and is not smuggled in
 * with this one.
 *
 * THE GUARDS.
 *   - A chunk the live world already holds is never touched here. It
 *     is read through the cell instead, which is free and safe, and
 *     counted separately so the report says which half came from where.
 *   - A hard cap on chunks per call, so one claim cannot become a
 *     stall.
 *   - Every engine call inside a catch: this runs at world creation
 *     while the streamer is busy, and a survey that throws must cost
 *     the county nothing.
 */
public final class SAOGround {

    /** IsoChunkMap.CHUNK_SIZE_IN_SQUARES, verified against the jar. */
    public static final int CHUNK_SIDE = 8;

    /** The most chunks one survey may touch. A claim is a nine-square
     *  box, so it spans four at worst; this is room for that and a
     *  mistake, and not room for a stall. */
    public static final int CHUNK_BUDGET = 8;

    private SAOGround() {
    }

    private static IsoCell cell() {
        try {
            IsoWorld world = IsoWorld.instance;
            return world == null ? null : world.getCell();
        } catch (Throwable throwable) {
            return null;
        }
    }

    /** A window or door that could still take a plank. */
    private static boolean boardable(IsoObject object) {
        if (!(object instanceof BarricadeAble able)) {
            return false;
        }
        try {
            if (object.getObjectIndex() == -1) {
                return false;
            }
            IsoBarricade already = IsoBarricade.GetBarricadeOnSquare(
                object.getSquare(), null);
            return already == null || already.canAddPlank();
        } catch (Throwable throwable) {
            return false;
        }
    }

    private static boolean barricaded(IsoObject object) {
        try {
            return object instanceof BarricadeAble
                && IsoBarricade.GetBarricadeOnSquare(object.getSquare(), null) != null;
        } catch (Throwable throwable) {
            return false;
        }
    }

    private static void readSquare(IsoGridSquare square, int[] tally) {
        if (square == null) {
            return;
        }
        try {
            for (int i = 0; i < square.getObjects().size(); i++) {
                IsoObject object = square.getObjects().get(i);
                if (!(object instanceof BarricadeAble)) {
                    continue;
                }
                tally[2]++;                       // ways in
                if (barricaded(object)) {
                    tally[3]++;                   // already boarded
                } else if (boardable(object)) {
                    tally[4]++;                   // could still be boarded
                }
            }
        } catch (Throwable ignored) {
        }
    }

    /**
     * Look at the ground a claim stands on and report what is there:
     * "chunks=n live=n ways=n boarded=n open=n", or "" when nothing
     * could be read.
     *
     * `chunks` is the ones loaded off disk for this look and let go
     * again; `live` is the ones the world already held, which were read
     * where they sat.
     */
    public static String surveyClaim(int minX, int minY, int maxX, int maxY, int z) {
        IsoCell cell = cell();
        if (cell == null) {
            return "";
        }
        // loaded, live, ways in, boarded, still open
        int[] tally = new int[5];
        int fromChunkX = Math.floorDiv(minX, CHUNK_SIDE);
        int toChunkX = Math.floorDiv(maxX, CHUNK_SIDE);
        int fromChunkY = Math.floorDiv(minY, CHUNK_SIDE);
        int toChunkY = Math.floorDiv(maxY, CHUNK_SIDE);
        int touched = 0;
        for (int cx = fromChunkX; cx <= toChunkX; cx++) {
            for (int cy = fromChunkY; cy <= toChunkY; cy++) {
                if (touched >= CHUNK_BUDGET) {
                    return report(tally);
                }
                touched++;
                boolean live = false;
                try {
                    live = cell.isInChunkMap(cx, cy);
                } catch (Throwable ignored) {
                }
                if (live) {
                    // The world owns it. Read it where it sits and
                    // touch nothing: this is the player's ground.
                    tally[1]++;
                    for (int x = Math.max(minX, cx * CHUNK_SIDE);
                         x <= Math.min(maxX, cx * CHUNK_SIDE + CHUNK_SIDE - 1); x++) {
                        for (int y = Math.max(minY, cy * CHUNK_SIDE);
                             y <= Math.min(maxY, cy * CHUNK_SIDE + CHUNK_SIDE - 1); y++) {
                            try {
                                readSquare(cell.getGridSquare(x, y, z), tally);
                            } catch (Throwable ignored) {
                            }
                        }
                    }
                    continue;
                }
                IsoChunk chunk = null;
                try {
                    chunk = new IsoChunk(cell);
                    chunk.wx = cx;
                    chunk.wy = cy;
                    chunk.LoadFromDisk();
                } catch (Throwable throwable) {
                    chunk = null;
                }
                if (chunk == null) {
                    continue;
                }
                tally[0]++;
                for (int x = Math.max(minX, cx * CHUNK_SIDE);
                     x <= Math.min(maxX, cx * CHUNK_SIDE + CHUNK_SIDE - 1); x++) {
                    for (int y = Math.max(minY, cy * CHUNK_SIDE);
                         y <= Math.min(maxY, cy * CHUNK_SIDE + CHUNK_SIDE - 1); y++) {
                        try {
                            readSquare(chunk.getGridSquare(
                                x - cx * CHUNK_SIDE, y - cy * CHUNK_SIDE, z), tally);
                        } catch (Throwable ignored) {
                        }
                    }
                }
                // And let it go. Nothing is written and nothing is
                // kept: the reference dies with this loop.
            }
        }
        return report(tally);
    }

    private static String report(int[] tally) {
        return "chunks=" + tally[0] + " live=" + tally[1] + " ways=" + tally[2]
            + " boarded=" + tally[3] + " open=" + tally[4];
    }
}
