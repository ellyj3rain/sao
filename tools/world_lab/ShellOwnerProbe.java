import com.sao.engine.SAOIsoPlayerShell;
import com.sao.engine.SAOReturnBody;
import java.lang.reflect.Field;
import sun.misc.Unsafe;
import zombie.characters.IsoDummyCameraCharacter;
import zombie.characters.IsoGameCharacter;
import zombie.characters.IsoPlayer;
import zombie.characters.SurvivorDesc;
import zombie.characters.SurvivorFactory;
import zombie.iso.IsoCamera;
import zombie.iso.IsoCell;

/** Native method-level ownership check; this fixture has no rendered world. */
public final class ShellOwnerProbe {
    private static void check(boolean value, String message) {
        if (!value) throw new AssertionError(message);
    }

    public static void main(String[] args) throws Exception {
        zombie.core.random.RandStandard.INSTANCE.init();
        zombie.ZomboidFileSystem.instance.init();
        zombie.SoundManager.instance = new zombie.DummySoundManager();
        zombie.Lua.LuaManager.platform = new se.krka.kahlua.j2se.J2SEPlatform();
        zombie.Lua.LuaManager.env = zombie.Lua.LuaManager.platform.newTable();
        zombie.Lua.LuaEventManager.register(zombie.Lua.LuaManager.platform, zombie.Lua.LuaManager.env);
        SurvivorDesc.HairCommonColors.add(new zombie.core.ImmutableColor(.2f, .3f, .4f));
        var styles = new zombie.core.skinnedmodel.population.HairStyles();
        zombie.core.skinnedmodel.population.HairStyles.instance = styles;
        zombie.core.skinnedmodel.population.BeardStyles.instance = new zombie.core.skinnedmodel.population.BeardStyles();
        var hair = new zombie.core.skinnedmodel.population.HairStyle();
        hair.name = "fixture";
        styles.maleStyles.add(hair);
        styles.femaleStyles.add(hair);
        var beard = new zombie.core.skinnedmodel.population.BeardStyle();
        beard.name = "fixture";
        zombie.core.skinnedmodel.population.BeardStyles.instance.styles.add(beard);
        zombie.core.skinnedmodel.population.PopTemplateManager.instance.maleSkins.add("fixture");
        zombie.core.skinnedmodel.population.PopTemplateManager.instance.femaleSkins.add("fixture");
        SurvivorFactory.addMaleForename("FixtureMan");
        SurvivorFactory.addFemaleForename("FixtureWoman");
        SurvivorFactory.addSurname("FixtureName");
        IsoCell cell = new IsoCell(1, 1);
        zombie.iso.WorldReuserThread.instance.stop();
        cell.setSafeToAdd(true);
        SAOIsoPlayerShell shell = SAOReturnBody.create("Ada", "Stone", 10, 20, 0, true);
        check(shell != null, "native shell creation failed");

        // Only reference identities are needed for the saved owners. The body
        // whose native update executes above is constructed by production code.
        Field unsafeField = Unsafe.class.getDeclaredField("theUnsafe");
        unsafeField.setAccessible(true);
        Unsafe unsafe = (Unsafe) unsafeField.get(null);
        IsoPlayer player = (IsoPlayer) unsafe.allocateInstance(IsoPlayer.class);
        IsoGameCharacter ordinary = (IsoPlayer) unsafe.allocateInstance(IsoPlayer.class);
        IsoGameCharacter dummy = (IsoDummyCameraCharacter) unsafe.allocateInstance(IsoDummyCameraCharacter.class);
        Field cameraField = IsoCamera.class.getDeclaredField("isoCameraGameCharacter");
        cameraField.setAccessible(true);
        int checks = 0, unloadedFailures = 0;
        for (boolean paused : new boolean[] {false, true}) {
            shell.removalPending = paused;
            for (IsoPlayer owner : new IsoPlayer[] {player, null}) {
                for (IsoGameCharacter camera : new IsoGameCharacter[] {ordinary, null, dummy}) {
                    for (boolean post : new boolean[] {true, false}) {
                        IsoPlayer.setInstance(owner);
                        cameraField.set(null, camera);
                        IsoPlayer[] slots = IsoPlayer.players.clone();
                        try {
                            if (post) shell.postupdate(); else shell.update();
                        } catch (NullPointerException absentLoadedWorld) {
                            // The exception is part of this incomplete native
                            // fixture; the guard must still restore both owners.
                            check(!paused, "paused shell reached native world code");
                            unloadedFailures++;
                        }
                        check(IsoPlayer.getInstance() == owner, "shell leaked global player owner");
                        check(IsoCamera.getCameraCharacter() == camera, "shell leaked camera owner");
                        check(java.util.Arrays.equals(slots, IsoPlayer.players), "shell changed player slots");
                        checks++;
                    }
                }
            }
        }
        System.out.println("PASS native shell owners: " + checks + " cases; " + unloadedFailures
            + " unloaded-world exceptions; independent, null and dummy owners; pending removal");
        System.exit(0);
    }
}
