package com.sao.engine;

import zombie.WorldSoundManager;
import zombie.characters.IsoZombie;
import zombie.characters.SurvivorDesc;
import zombie.iso.IsoCell;
import zombie.iso.IsoChunk;
import zombie.iso.IsoChunkMap;
import zombie.iso.IsoGridSquare;
import zombie.iso.SpriteDetails.IsoFlagType;

/** Installed-engine check that the exact proxy hears in the ordinary scan. */
public final class WeekOnePrivateHearingProbe {
    private static void check(boolean value, String name) {
        if (!value) throw new AssertionError(name);
    }

    private static IsoCell cell() throws Exception {
        zombie.core.random.RandStandard.INSTANCE.init();
        zombie.ZomboidFileSystem.instance.init();
        zombie.SoundManager.instance = new zombie.DummySoundManager();
        zombie.Lua.LuaManager.platform = new se.krka.kahlua.j2se.J2SEPlatform();
        zombie.Lua.LuaManager.env = zombie.Lua.LuaManager.platform.newTable();
        zombie.Lua.LuaEventManager.register(zombie.Lua.LuaManager.platform,
            zombie.Lua.LuaManager.env);
        zombie.GameTime.setInstance(new zombie.GameTime());
        zombie.characters.skills.PerkFactory.init();
        IsoCell cell = new IsoCell(1, 1);
        zombie.iso.WorldReuserThread.instance.stop();
        zombie.iso.IsoWorld.instance.currentCell = cell;
        IsoChunkMap map = cell.getChunkMap(0);
        map.setInitialPos(1, 1); map.ignore = false;
        IsoChunk chunk = new IsoChunk(cell);
        chunk.wx = 1; chunk.wy = 1; chunk.loaded = true;
        for (int x = 0; x < 8; x++) for (int y = 0; y < 8; y++) {
            IsoGridSquare square = new IsoGridSquare(cell, null, 8 + x, 8 + y, 0);
            square.chunk = chunk;
            square.getProperties().set(IsoFlagType.solidfloor);
            chunk.setSquare(x, y, 0, square);
        }
        int ix = chunk.wx - map.getWorldXMin();
        int iy = chunk.wy - map.getWorldYMin();
        map.getChunks()[iy * IsoChunkMap.chunkGridWidth + ix] = chunk;
        return cell;
    }

    public static void main(String[] args) throws Exception {
        IsoCell cell = cell();
        IsoGridSquare square = cell.getGridSquare(10, 10, 0);
        check(square != null, "native loaded listener square");
        IsoZombie listener = new IsoZombie(cell, new SurvivorDesc(), 0);
        listener.setX(10.2f); listener.setY(10.2f); listener.setZ(0);
        listener.setCurrent(square); listener.setSquare(square);
        square.getMovingObjects().add(listener);
        listener.setVariable("Bandit", true);
        listener.setPersistentOutfitID(73);
        var md = listener.getModData();
        md.rawset("SAOWeekOneOrigin", "BanditsWeekOne");
        md.rawset("SAOWeekOnePersonId", "bwo-73");
        md.rawset("SAOWeekOneBrainId", 73.0);
        md.rawset("SAOWeekOneBorn", 12.5);
        md.rawset("SAOWeekOneName", "Ari Vale");
        check(SAOSenses.hearing(listener, true) == 0,
            "ordinary zombie hearing admission unexpectedly changed");
        check(SAOPerceptionScanner.hearingForScan(listener) > 0,
            "exact Week One person has no scanner hearing");
        WorldSoundManager.instance.soundList.clear();
        var sound = new WorldSoundManager.WorldSound();
        sound.init(new Object(), 12, 10, 0, 18, 18);
        WorldSoundManager.instance.soundList.add(sound);
        check(SAOPerceptionScanner.scan(listener).contains("S:12:10:"),
            "exact Week One body did not acquire native world sound");

        md.rawset("SAOWeekOneBrainId", 74.0);
        check(SAOPerceptionScanner.hearingForScan(listener) == 0
            && !SAOPerceptionScanner.scan(listener).contains("S:12:10:"),
            "mismatched brain borrowed human hearing");
        md.rawset("SAOWeekOneBrainId", 73.0);
        md.rawset("SAOWeekOneOrigin", "Bandits2");
        check(SAOPerceptionScanner.hearingForScan(listener) == 0
            && !SAOPerceptionScanner.scan(listener).contains("S:12:10:"),
            "foreign zombie borrowed Week One hearing");
        md.rawset("SAOWeekOneOrigin", "BanditsWeekOne");
        md.rawset("SAOWeekOneBorn", Double.NaN);
        check(SAOPerceptionScanner.hearingForScan(listener) == 0,
            "invalid birth marker borrowed human hearing");
        WorldSoundManager.instance.soundList.clear();
        System.out.println("PASS Week One exact scanner hearing and three inverses");
    }
}
