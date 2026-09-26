import com.sao.engine.SAOIsoPlayerShell;
import com.sao.engine.SAOPerceptionScanner;
import com.sao.engine.SAOReturnBody;
import zombie.WorldSoundManager;
import zombie.characters.SurvivorDesc;
import zombie.characters.SurvivorFactory;
import zombie.characters.IsoZombie;
import zombie.iso.IsoCell;
import zombie.iso.IsoChunk;
import zombie.iso.IsoChunkMap;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoWorld;

/** Actual native sounds and production scanner; no game or rendering loop. */
public final class SoundEvidenceProbe {
    private static boolean passed = true;

    private static void check(String name, boolean value) {
        passed &= value;
        System.out.println("CHECK " + name + "=" + value);
    }

    private static String scan(SAOIsoPlayerShell listener,
            WorldSoundManager.WorldSound... sounds) {
        WorldSoundManager.instance.soundList.clear();
        for (var sound : sounds) WorldSoundManager.instance.soundList.add(sound);
        return SAOPerceptionScanner.scan(listener);
    }

    private static WorldSoundManager.WorldSound sound(Object source,
            int x, int y, int radius, int volume) {
        return new WorldSoundManager.WorldSound().init(source, x, y, 0, radius, volume);
    }

    private static void ground(IsoCell cell) {
        var map = cell.getChunkMap(0);
        map.setInitialPos(2, 2);
        map.ignore = false;
        zombie.characters.IsoPlayer.numPlayers = 1;
        // Real loaded native squares, placed in the native chunk map's public
        // read buffer. No loader, generated world, actors' AI or renderer runs.
        for (int wx = 0; wx < 5; wx++) for (int wy = 1; wy < 4; wy++) {
            IsoChunk chunk = new IsoChunk(cell);
            chunk.wx = wx; chunk.wy = wy; chunk.loaded = true;
            for (int z = 0; z <= 1; z++) for (int x = 0; x < 8; x++) for (int y = 0; y < 8; y++) {
                var square = new IsoGridSquare(cell, null, wx * 8 + x, wy * 8 + y, z);
                square.chunk = chunk;
                chunk.setSquare(x, y, z, square);
            }
            int ix = wx - map.getWorldXMin(), iy = wy - map.getWorldYMin();
            map.getChunks()[iy * IsoChunkMap.chunkGridWidth + ix] = chunk;
        }
        if (cell.getGridSquare(11, 20, 0) == null) throw new AssertionError("native grid fixture is not loaded");
    }

    private static void place(zombie.characters.IsoGameCharacter body, IsoCell cell, float x, float y, int z) {
        body.setX(x); body.setY(y); body.setZ(z);
        body.setCurrent(cell.getGridSquare((int) Math.floor(x), (int) Math.floor(y), z));
    }

    private static IsoZombie zombie(IsoCell cell, float x, float y) {
        IsoZombie body = new IsoZombie(cell);
        body.setHealth(1.0f);
        place(body, cell, x, y, 0);
        cell.getZombieList().add(body);
        return body;
    }

    private static String view(SAOIsoPlayerShell observer, String known, String label) {
        String rows = SAOPerceptionScanner.scan(observer, known);
        if (label != null) System.out.println("ROW " + label + "=" + rows);
        return rows;
    }

    private static java.util.List<String> tracks(String rows) {
        var result = new java.util.ArrayList<String>();
        for (String row : rows.split("\\|")) {
            if (!row.startsWith("Z:")) continue;
            var matcher = java.util.regex.Pattern.compile(":track:([^:|]+)").matcher(row);
            if (matcher.find()) result.add(matcher.group(1));
        }
        return result;
    }

    private static void sight(IsoCell cell, SAOIsoPlayerShell listener, SAOIsoPlayerShell other) throws Exception {
        WorldSoundManager.instance.soundList.clear();
        ground(cell);
        place(listener, cell, 10.75f, 20.75f, 0);
        listener.setForwardDirection(1.0f, 0.0f);
        var a = zombie(cell, 11.25f, 20.25f);
        String first = view(listener, "", "first");
        check("native_first_visible_body", tracks(first).size() == 1 && first.contains(":floor:0"));
        place(a, cell, 12.25f, 20.25f, 0);
        String moved = view(listener, "11,20,0", "moved");
        check("continuous_body_keeps_track", tracks(first).equals(tracks(moved)));
        check("known_empty_tile_is_visible", moved.contains("V:11:20:0"));
        var b = zombie(cell, 12.25f, 20.25f);
        String pair = view(listener, "12,20,0", "pair");
        check("same_tile_bodies_have_distinct_tracks", tracks(pair).size() == 2
            && !tracks(pair).get(0).equals(tracks(pair).get(1)));
        place(a, cell, 15.25f, 20.25f, 0); place(b, cell, 15.25f, 20.25f, 0);
        listener.setForwardDirection(-1.0f, 0.0f);
        String hidden = view(listener, "15,20,0", "hidden");
        check("hidden_tile_has_no_positive_or_negative_sight", hidden.isEmpty());
        listener.setForwardDirection(1.0f, 0.0f);
        String returned = view(listener, "", "returned");
        check("visibility_gap_starts_new_tracks", tracks(returned).size() == 2
            && java.util.Collections.disjoint(tracks(pair), tracks(returned)));
        place(other, cell, 10.75f, 20.75f, 0); other.setForwardDirection(1.0f, 0.0f);
        String another = view(other, "", null);
        check("observers_have_private_track_epochs", java.util.Collections.disjoint(tracks(first), tracks(another)));
        listener.setCurrent(null);
        view(listener, "", null);
        place(listener, cell, 10.75f, 20.75f, 0);
        String rebound = view(listener, "", "rebound");
        check("missing_eye_ends_native_tracking_session", java.util.Collections.disjoint(tracks(returned), tracks(rebound)));
        var reset = com.sao.bridge.SAOBridge.class.getDeclaredMethod("resetRuntimeForWorld");
        reset.setAccessible(true);
        reset.invoke(com.sao.bridge.SAOBridge.INSTANCE);
        String nextWorld = view(listener, "", null);
        check("bridge_world_reset_ends_tracking_epoch", tracks(nextWorld).size() == 2
            && java.util.Collections.disjoint(tracks(rebound), tracks(nextWorld)));
        cell.getZombieList().clear();
        String empty = view(listener, "15,20,0", "empty");
        check("visible_empty_tile_reported", empty.equals("V:15:20:0"));
        check("bridge_forwards_known_tiles", com.sao.bridge.SAOBridge.INSTANCE.perceive(
            listener, "15,20,0").equals("V:15:20:0"));
        check("unknown_floor_not_certified", view(listener, "11,20,1", "floor").isEmpty());
        check("unloaded_tile_not_certified", view(listener, "60,20,0", "unloaded").isEmpty());
        check("behind_tile_not_certified", view(listener, "6,20,0", "back").isEmpty());
        check("distant_tile_not_certified", view(listener, "25,20,0", "distant").isEmpty());
        check("oversize_known_tile_request_is_bounded", view(listener, "1,2,0;".repeat(3000), null).isEmpty());
        cell.getZombieList().add(a);
        String beforeWall = view(listener, "", null);
        var wall = cell.getGridSquare(11, 20, 0);
        wall.getProperties().set(zombie.iso.SpriteDetails.IsoFlagType.collideW);
        wall.getProperties().set(zombie.iso.SpriteDetails.IsoFlagType.cutW);
        wall.ReCalculateVisionBlocked(cell.getGridSquare(10, 20, 0));
        String blocked = view(listener, "12,20,0", "occluded");
        check("occluded_known_tile_not_certified", blocked.isEmpty());
        check("intervening_wall_hides_actual_body", tracks(blocked).isEmpty());
        wall.getProperties().unset(zombie.iso.SpriteDetails.IsoFlagType.collideW);
        wall.getProperties().unset(zombie.iso.SpriteDetails.IsoFlagType.cutW);
        wall.ReCalculateVisionBlocked(cell.getGridSquare(10, 20, 0));
        String unblocked = view(listener, "", null);
        check("wall_gap_ends_continuous_tracking", tracks(unblocked).size() == 1
            && java.util.Collections.disjoint(tracks(beforeWall), tracks(unblocked)));
        cell.getZombieList().clear();
        for (int i = 0; i < 22; i++) zombie(cell, 11.25f + i % 4, 20.25f + i / 4 * 0.15f);
        String crowd = view(listener, "", "crowd");
        check("twenty_two_native_bodies_stay_distinct", tracks(crowd).size() == 22
            && new java.util.HashSet<>(tracks(crowd)).size() == 22);
    }

    private static void run() throws Exception {
        zombie.core.random.RandStandard.INSTANCE.init();
        zombie.ZomboidFileSystem.instance.init();
        zombie.SoundManager.instance = new zombie.DummySoundManager();
        zombie.Lua.LuaManager.platform = new se.krka.kahlua.j2se.J2SEPlatform();
        zombie.Lua.LuaManager.env = zombie.Lua.LuaManager.platform.newEnvironment();
        zombie.Lua.LuaManager.thread = new se.krka.kahlua.vm.KahluaThread(
            zombie.Lua.LuaManager.platform, zombie.Lua.LuaManager.env);
        zombie.Lua.LuaManager.thread.debugOwnerThread = Thread.currentThread();
        zombie.Lua.LuaManager.caller = new se.krka.kahlua.integration.LuaCaller(
            zombie.Lua.LuaManager.converterManager);
        zombie.Lua.LuaEventManager.register(zombie.Lua.LuaManager.platform, zombie.Lua.LuaManager.env);
        SurvivorDesc.HairCommonColors.add(new zombie.core.ImmutableColor(.2f, .3f, .4f));
        var styles = new zombie.core.skinnedmodel.population.HairStyles();
        zombie.core.skinnedmodel.population.HairStyles.instance = styles;
        zombie.core.skinnedmodel.population.BeardStyles.instance = new zombie.core.skinnedmodel.population.BeardStyles();
        var hair = new zombie.core.skinnedmodel.population.HairStyle(); hair.name = "fixture";
        styles.maleStyles.add(hair); styles.femaleStyles.add(hair);
        var beard = new zombie.core.skinnedmodel.population.BeardStyle(); beard.name = "fixture";
        zombie.core.skinnedmodel.population.BeardStyles.instance.styles.add(beard);
        zombie.core.skinnedmodel.population.PopTemplateManager.instance.maleSkins.add("fixture");
        zombie.core.skinnedmodel.population.PopTemplateManager.instance.femaleSkins.add("fixture");
        SurvivorFactory.addMaleForename("FixtureMan"); SurvivorFactory.addFemaleForename("FixtureWoman");
        SurvivorFactory.addSurname("FixtureName");
        IsoCell cell = new IsoCell(1, 1);
        zombie.iso.WorldReuserThread.instance.stop();
        IsoWorld.instance.currentCell = cell;
        cell.setSafeToAdd(true);

        var listener = SAOReturnBody.create("Listener", "Fixture", 10, 20, 0, true);
        var other = SAOReturnBody.create("Other", "Fixture", 12, 20, 0, true);
        if (listener == null || other == null) throw new AssertionError("native shell construction failed");
        listener.setX(10.75f); listener.setY(20.75f);
        listener.setCurrent(new IsoGridSquare(cell, null, 10, 20, 0));
        if (!cell.getZombieList().isEmpty() || !cell.getObjectList().isEmpty())
            throw new AssertionError("fixture must isolate auditory acquisition");

        // Real footsteps carry the source actor and integer tile coordinates.
        // The listener's sub-tile position defeats the former <0.5 distance filter.
        var own = sound(listener, 10, 20, 6, 20);
        if (own.source != listener) throw new AssertionError("native sound lost source identity");
        String ownRows = scan(listener, own);
        check("own_floor_offset_ignored", ownRows.isEmpty());
        System.out.println("ROW own=" + ownRows);

        var audible = sound(other, 12, 20, 10, 20);
        String otherRows = scan(listener, audible);
        check("other_source_audible", otherRows.startsWith("S:12:20:") && !otherRows.contains("|"));
        System.out.println("ROW other=" + otherRows);

        var unclassified = sound(null, 13, 20, 10, 20);
        String unknownRows = scan(listener, unclassified);
        check("unattributed_audible", unknownRows.startsWith("S:13:20:") && !unknownRows.contains("|"));
        System.out.println("ROW unattributed=" + unknownRows);

        check("out_of_range_ignored", scan(listener, sound(other, 40, 20, 3, 20)).isEmpty());
        var silent = sound(other, 12, 20, 10, 0);
        silent.stresshumans = false;
        check("silent_nonstress_ignored", scan(listener, silent).isEmpty());
        var stress = sound(other, 12, 20, 10, 0);
        stress.stresshumans = true;
        check("native_stress_sound_retained", scan(listener, stress).startsWith("S:12:20:"));

        String mixed = scan(listener, own, audible, unclassified, silent,
            sound(other, 40, 20, 3, 20));
        check("mixed_sources_keep_only_audible_others", mixed.equals(otherRows + "|" + unknownRows));
        listener.setX(13.75f);
        listener.setCurrent(new IsoGridSquare(cell, null, 13, 20, 0));
        check("own_recent_footprint_ignored_after_move", scan(listener, own).isEmpty());
        sight(cell, listener, other);
    }

    public static void main(String[] args) {
        try {
            run();
            System.out.println(passed ? "PASS native sound evidence" : "FAIL native sound evidence");
            System.exit(passed ? 0 : 1);
        } catch (Throwable failure) {
            failure.printStackTrace();
            System.exit(2);
        }
    }
}
