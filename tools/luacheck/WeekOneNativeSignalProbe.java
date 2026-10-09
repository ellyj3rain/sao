import com.sao.bridge.SAOBridge;
import com.sao.agent.SAOCalloutWeave;
import zombie.WorldSoundManager;
import zombie.characters.IsoGameCharacter;
import zombie.characters.IsoPlayer;
import zombie.characters.IsoZombie;
import zombie.characters.SurvivorDesc;
import zombie.iso.IsoCell;
import zombie.iso.IsoChunk;
import zombie.iso.IsoChunkMap;
import zombie.iso.IsoGridSquare;
import zombie.iso.SpriteDetails.IsoFlagType;
import zombie.vehicles.BaseVehicle;
import org.joml.Vector3f;

/** Installed-engine body, native Callout and WorldSound hearing boundary. */
public final class WeekOneNativeSignalProbe {
    private static final class HeadlessPlayer extends IsoPlayer {
        HeadlessPlayer(IsoCell cell, SurvivorDesc desc) {
            super(cell, desc, 10, 10, 0);
        }
        @Override public long transmitPlayerVoiceSound(String sound) {
            return 0; // The installed Callout still emits its native WorldSound.
        }
        @Override public void SayShout(String line) {
            // The headless chat manager has no local player; Callout still
            // chooses the line, emits sound, and sets its action flag.
        }
    }

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
        SurvivorDesc.HairCommonColors.add(new zombie.core.ImmutableColor(.2f, .3f, .4f));
        var styles = new zombie.core.skinnedmodel.population.HairStyles();
        zombie.core.skinnedmodel.population.HairStyles.instance = styles;
        zombie.core.skinnedmodel.population.BeardStyles.instance =
            new zombie.core.skinnedmodel.population.BeardStyles();
        var hair = new zombie.core.skinnedmodel.population.HairStyle();
        hair.name = "fixture";
        styles.maleStyles.add(hair); styles.femaleStyles.add(hair);
        zombie.GameTime.setInstance(new zombie.GameTime());
        zombie.GameTime.getInstance().updateCalendar(1993, 0, 1, 12, 0);
        zombie.characters.skills.PerkFactory.init();
        IsoCell cell = new IsoCell(1, 1);
        zombie.iso.WorldReuserThread.instance.stop();
        zombie.iso.IsoWorld.instance.currentCell = cell;
        IsoChunkMap map = cell.getChunkMap(0);
        map.setInitialPos(1, 1); map.ignore = false;
        IsoPlayer.numPlayers = 1;
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

    private static void place(IsoGameCharacter body, IsoGridSquare square,
            float x, float y) {
        body.setX(x); body.setY(y); body.setZ(0);
        body.setCurrent(square); body.setSquare(square);
        square.getMovingObjects().add(body);
    }

    public static void main(String[] args) throws Exception {
        IsoCell cell = cell();
        IsoGridSquare square = cell.getGridSquare(10, 10, 0);
        check(square != null, "loaded native square");
        var listener = new IsoZombie(cell, new SurvivorDesc(), 0);
        place(listener, square, 10.2f, 10.2f);
        listener.setVariable("Bandit", true);
        listener.setPersistentOutfitID(73);
        var md = listener.getModData();
        md.rawset("SAOWeekOneOrigin", "BanditsWeekOne");
        md.rawset("SAOWeekOnePersonId", "bwo-73");
        md.rawset("SAOWeekOneBrainId", 73.0);
        md.rawset("SAOWeekOneBorn", 12.5);
        var description = new SurvivorDesc(false);
        description.getHumanVisual().setSkinTextureName("fixture");
        var player = new HeadlessPlayer(cell, description);
        place(player, square, 10.8f, 10.2f);
        IsoPlayer prior = IsoPlayer.players[0];
        IsoPlayer.players[0] = player;
        var bridge = SAOBridge.INSTANCE;
        try {
            check("ready".equals(SAOCalloutWeave.report()),
                "installed Callout() weave did not transform");
            check(!bridge.weekOneNativeSignalActive(player, "callout"),
                "idle player reported a native shout");
            check(!bridge.weekOneNativeSignalHeard(player, listener,
                "bwo-73", 73.0, 12.5, "callout"),
                "quiet native state became sound contact");
            WorldSoundManager.instance.soundList.clear();
            player.Callout();
            String firstCallout = bridge.weekOneNativeCalloutOccurrence(player);
            check(firstCallout != null, "native Callout has no woven occurrence");
            check(bridge.weekOneNativeSignalActive(player, "callout"),
                "installed Callout did not set native action state");
            check(bridge.weekOneNativeSignalHeard(player, listener,
                "bwo-73", 73.0, 12.5, "callout"),
                "actual native Callout sound was not heard");
            player.Callout();
            String secondCallout = bridge.weekOneNativeCalloutOccurrence(player);
            check(secondCallout != null && !secondCallout.equals(firstCallout),
                "second native Callout lost its distinct occurrence behind sticky callOut");
            check(bridge.weekOneNativeSignalHeard(player, listener,
                "bwo-73", 73.0, 12.5, "callout"),
                "second actual native Callout sound was not heard");
            check(!bridge.weekOneNativeSignalHeard(player, listener,
                "bwo-74", 73.0, 12.5, "callout"),
                "different person borrowed the sound");
            check(!bridge.weekOneNativeSignalHeard(player, listener,
                "bwo-73", 74.0, 12.5, "callout"),
                "different brain borrowed the sound");
            check(!bridge.weekOneNativeSignalHeard(player, listener,
                "bwo-73", 73.0, 12.6, "callout"),
                "reused brain borrowed another birth's sound");
            md.rawset("SAOWeekOneOrigin", "Bandits2");
            check(!bridge.weekOneNativeSignalHeard(player, listener,
                "bwo-73", 73.0, 12.5, "callout"),
                "foreign source borrowed a stamped sound");
            md.rawset("SAOWeekOneOrigin", "BanditsWeekOne");
            WorldSoundManager.instance.soundList.clear();
            WorldSoundManager.instance.addSound(player, 10, 10, 0, 30, 30);
            check(bridge.weekOneNativeCalloutOccurrence(player) == null,
                "old Callout occurrence survived sound removal");
            check(!bridge.weekOneNativeSignalHeard(player, listener,
                "bwo-73", 73.0, 12.5, "callout"),
                "unrelated same-source sound borrowed the sticky Callout flag");
            WorldSoundManager.instance.soundList.clear();
            player.Callout();
            String thirdCallout = bridge.weekOneNativeCalloutOccurrence(player);
            check(thirdCallout != null && !thirdCallout.equals(secondCallout),
                "Callout did not recover after an unrelated sound");
            var reused = WorldSoundManager.instance.soundList.get(0);
            reused.init(player, 10, 10, 0, 30, 30, 0f, 1f, (short) 2);
            check(bridge.weekOneNativeCalloutOccurrence(player) == null,
                "pooled sound reinit retained the old Callout occurrence");
            check(!bridge.weekOneNativeSignalHeard(player, listener,
                "bwo-73", 73.0, 12.5, "callout"),
                "pooled unrelated sound borrowed old Callout authority");

            var vehicle = new BaseVehicle(cell);
            vehicle.setX(10.5f); vehicle.setY(10.5f); vehicle.setZ(0);
            vehicle.setCurrent(square); vehicle.setSquare(square);
            var script = new zombie.scripting.objects.VehicleScript();
            script.getSounds().hornEnable = true;
            var scriptField = BaseVehicle.class.getDeclaredField("script");
            scriptField.setAccessible(true); scriptField.set(vehicle, script);
            var seats = BaseVehicle.class.getDeclaredField("passengers");
            seats.setAccessible(true);
            seats.set(vehicle, new BaseVehicle.Passenger[] {new BaseVehicle.Passenger()});
            check(vehicle.setPassenger(0, player, new Vector3f()),
                "native driver seat unavailable");
            player.setVehicle(vehicle);
            check(!bridge.weekOneNativeSignalActive(player, "horn"),
                "idle vehicle reported a horn");
            WorldSoundManager.instance.soundList.clear();
            boolean headlessPopulation = false;
            try { vehicle.onHornStart(); }
            catch (UnsatisfiedLinkError unavailable) {
                // The engine's zombie-population JNI is absent in this
                // headless probe. The native method has already set the horn
                // state; supply its exact WorldSound payload for hearing.
                headlessPopulation = true;
                var sound = new WorldSoundManager.WorldSound();
                sound.init(vehicle, 10, 10, 0, 150, 150);
                WorldSoundManager.instance.soundList.add(sound);
            }
            check(bridge.weekOneNativeSignalActive(player, "horn"),
                "installed horn did not set current native vehicle state");
            check(bridge.weekOneNativeSignalHeard(player, listener,
                "bwo-73", 73.0, 12.5, "horn"),
                "actual native driven horn sound was not heard");
            vehicle.onHornStop();
            check(!bridge.weekOneNativeSignalHeard(player, listener,
                "bwo-73", 73.0, 12.5, "horn"),
                "stopped native horn remained contact");
            if (headlessPopulation) System.out.println(
                "HORN headless population JNI unavailable; installed state and controlled native WorldSound verified");
            player.setVehicle(null);
            IsoPlayer.players[0] = prior;
            check(!bridge.weekOneNativeSignalActive(player, "callout"),
                "off-slot player borrowed local native action state");
        } finally {
            IsoPlayer.players[0] = prior;
        }
        System.out.println("PASS Week One installed native Callout and horn sound with identity inverses");
    }
}
