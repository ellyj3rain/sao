import com.sao.engine.SAOPerceptionScanner;
import java.lang.reflect.Constructor;
import java.lang.reflect.Field;
import java.util.Map;
import java.util.WeakHashMap;
import zombie.characters.IsoGameCharacter;
import zombie.characters.IsoPlayer;
import zombie.characters.IsoZombie;
import zombie.characters.SurvivorDesc;
import zombie.iso.IsoCell;
import zombie.iso.IsoChunk;
import zombie.iso.IsoChunkMap;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoObject;
import zombie.iso.SpriteDetails.IsoFlagType;
import zombie.iso.sprite.IsoSprite;
import zombie.inventory.InventoryItem;

/** Read-only feature sight and one actual supplied wound dressing in a loaded
 * installed-engine cell. The fixture does not touch a game save. */
public final class WeekOneRoleProbe {
    private static void check(boolean value, String label) {
        if (!value) throw new AssertionError(label);
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
        styles.maleStyles.add(hair);
        styles.femaleStyles.add(hair);
        zombie.GameTime.setInstance(new zombie.GameTime());
        zombie.GameTime.getInstance().updateCalendar(1993, 0, 1, 12, 0);
        zombie.characters.skills.PerkFactory.init();
        IsoCell cell = new IsoCell(1, 1);
        zombie.iso.WorldReuserThread.instance.stop();
        zombie.iso.IsoWorld.instance.currentCell = cell;
        IsoChunkMap map = cell.getChunkMap(0);
        map.setInitialPos(1, 1);
        map.ignore = false;
        IsoPlayer.numPlayers = 1;
        IsoChunk chunk = new IsoChunk(cell);
        chunk.wx = 1;
        chunk.wy = 1;
        chunk.loaded = true;
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

    private static void position(IsoGameCharacter body, IsoGridSquare square,
            float x, float y) {
        body.setX(x);
        body.setY(y);
        body.setZ(0);
        body.setCurrent(square);
        body.setSquare(square);
        square.getMovingObjects().add(body);
    }

    @SuppressWarnings("unchecked")
    private static void pinSight(IsoZombie observer, IsoPlayer patient,
            IsoCell cell) throws Exception {
        Class<?> type = Class.forName(
            "com.sao.engine.SAOPerceptionScanner$SightTracks");
        Constructor<?> ctor = type.getDeclaredConstructor(IsoCell.class);
        ctor.setAccessible(true);
        Object tracks = ctor.newInstance(cell);
        Field persons = type.getDeclaredField("persons");
        persons.setAccessible(true);
        var seen = new WeakHashMap<IsoGameCharacter, String>();
        seen.put(patient, "Morgan Hill");
        persons.set(tracks, seen);
        Field all = SAOPerceptionScanner.class.getDeclaredField("SIGHT_TRACKS");
        all.setAccessible(true);
        ((Map<IsoGameCharacter, Object>) all.get(null)).put(observer, tracks);
    }

    public static void main(String[] args) throws Exception {
        IsoCell cell = cell();
        IsoGridSquare square = cell.getGridSquare(10, 10, 0);
        check(square != null, "loaded square unavailable");
        var observer = new IsoZombie(cell, new SurvivorDesc(), 0);
        position(observer, square, 10.2f, 10.2f);
        observer.setVariable("Bandit", true);
        observer.setPersistentOutfitID(73);
        observer.setForwardDirection(1.0f, 0.0f);
        var md = observer.getModData();
        md.rawset("SAOWeekOneOrigin", "BanditsWeekOne");
        md.rawset("SAOWeekOnePersonId", "bwo-73");
        md.rawset("SAOWeekOneBrainId", 73.0);
        md.rawset("SAOWeekOneBorn", 12.5);
        md.rawset("SAOWeekOneName", "Alex Harper");
        check(SAOPerceptionScanner.weekOneObservedFeature(observer, square, "ground"),
            "current loaded ground was invisible to exact Week One body");
        check(!SAOPerceptionScanner.weekOneObservedFeature(observer, square, "fire"),
            "fire inferred from a plain ground square");
        var mailbox = new IsoObject(cell);
        mailbox.setSquare(square);
        var mailboxSprite = new IsoSprite();
        mailboxSprite.setName("street_decoration_01_18");
        mailbox.setSprite(mailboxSprite);
        square.getObjects().add(mailbox);
        check(SAOPerceptionScanner.weekOneObservedFeature(observer, mailbox, "mailbox"),
            "source mailbox sprite was not observed as an exact world object");
        check(!SAOPerceptionScanner.weekOneObservedFeature(observer, mailbox, "trash"),
            "mailbox became unrelated physical trash");
        square.getObjects().remove(mailbox);
        check(!SAOPerceptionScanner.weekOneObservedFeature(observer, mailbox, "mailbox"),
            "removed mailbox remained an action target");
        md.rawset("SAOWeekOneOrigin", "Bandits2");
        check(!SAOPerceptionScanner.weekOneObservedFeature(observer, square, "ground"),
            "foreign source used Week One role sight");
        md.rawset("SAOWeekOneOrigin", "BanditsWeekOne");

        var description = new SurvivorDesc(false);
        description.getHumanVisual().setSkinTextureName("fixture");
        var patient = new IsoPlayer(cell, description, 10, 10, 0);
        position(patient, square, 10.8f, 10.2f);
        IsoPlayer previousPlayer = IsoPlayer.players[0];
        IsoPlayer.players[0] = patient;
        var bridge = com.sao.bridge.SAOBridge.INSTANCE;
        check(bridge.weekOneCanHearPlayer(patient, observer, "bwo-73", 73.0, 12.5),
            "exact Week One body could not physically hear the current player");
        check(!bridge.weekOneCanHearPlayer(patient, observer, "bwo-74", 73.0, 12.5),
            "different person borrowed Week One hearing");
        check(!bridge.weekOneCanHearPlayer(patient, observer, "bwo-73", 74.0, 12.5),
            "different brain borrowed Week One hearing");
        check(!bridge.weekOneCanHearPlayer(patient, observer, "bwo-73", 73.0, 12.6),
            "reused brain borrowed another birth's hearing");
        md.rawset("SAOWeekOneOrigin", "Bandits2");
        check(!bridge.weekOneCanHearPlayer(patient, observer, "bwo-73", 73.0, 12.5),
            "foreign Bandit borrowed stamped Week One hearing");
        md.rawset("SAOWeekOneOrigin", "BanditsWeekOne");
        IsoPlayer.players[0] = previousPlayer;
        check(!bridge.weekOneCanHearPlayer(patient, observer, "bwo-73", 73.0, 12.5),
            "off-slot player borrowed current-player speech");
        IsoPlayer.players[0] = patient;
        pinSight(observer, patient, cell);
        var wound = patient.getBodyDamage().getBodyParts().get(0);
        wound.setBleeding(true);
        wound.setBleedingTime(8.0f);
        String care = SAOPerceptionScanner.weekOneObservedCareTarget(observer, "Morgan Hill");
        System.out.println("CARE " + care + " seen="
            + (SAOPerceptionScanner.observedCombatTarget(observer, "person", "Morgan Hill")
                == patient) + " alive=" + !patient.isDead() + " bleed=" + wound.bleeding()
            + " bandaged=" + wound.bandaged() + " world=" + patient.isExistInTheWorld()
            + " cells=" + (observer.getCell() == patient.getCell())
            + " visible=" + SAOPerceptionScanner.canSeePersonNow(observer, patient, 14));
        check(care.startsWith("CARE\t"), "visible living bleeding patient withheld");
        check(com.sao.bridge.SAOBridge.INSTANCE.weekOneObservedAttacker(
                observer, patient, "person", "Morgan Hill"),
            "exact observed attacker identity was withheld");
        var unseenDescription = new SurvivorDesc(false);
        unseenDescription.getHumanVisual().setSkinTextureName("fixture");
        var unseen = new IsoPlayer(cell, unseenDescription, 10, 10, 0);
        position(unseen, square, 10.8f, 10.2f);
        check(!com.sao.bridge.SAOBridge.INSTANCE.weekOneObservedAttacker(
                observer, unseen, "person", "Morgan Hill"),
            "co-located unobserved attacker borrowed another person's sight");
        check(SAOPerceptionScanner.weekOneBandageObservedPatient(observer,
                "Morgan Hill").startsWith("REFUSED\twound-or-bandage"),
            "patient treated without actual inventory bandage");

        var script = new zombie.scripting.objects.Item();
        script.setCanBandage(true);
        var item = new InventoryItem("Base", "Bandage", "Bandage", script);
        item.setScriptItem(script);
        item.setBandagePower(1.5f);
        item.setID(8675);
        observer.getInventory().AddItem(item);
        check(observer.getInventory().contains(item) && item.isCanBandage(),
            "physical test bandage unavailable");
        String result = SAOPerceptionScanner.weekOneBandageObservedPatient(
            observer, "Morgan Hill");
        check(result.startsWith("TREATED\t"), "observed native dressing refused: " + result);
        check(wound.bandaged() && !observer.getInventory().contains(item),
            "bandage body part and item consumption diverged");
        check(SAOPerceptionScanner.weekOneBandageObservedPatient(observer,
                "Morgan Hill").startsWith("REFUSED\twound-or-bandage"),
            "already treated wound accepted a duplicate bandage");
        IsoPlayer.players[0] = previousPlayer;
        System.out.println("PASS Week One exact feature sight, hearing, real bandage, and inverses");
    }
}
