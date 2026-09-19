import com.sao.engine.SAOIsoPlayerShell;
import com.sao.engine.SAOReturnBody;
import java.util.Arrays;
import zombie.characters.IsoGameCharacter;
import zombie.characters.IsoPlayer;
import zombie.characters.SurvivorDesc;
import zombie.characters.SurvivorFactory;
import zombie.characters.CharacterStat;
import zombie.core.skinnedmodel.ModelManager;
import zombie.iso.IsoCell;
import zombie.iso.IsoWorld;

/** Actual shell constructor and native queue teardown; no rendered world or saves. */
public final class ReturnBodyProbe {
    private static void check(boolean value, String reason) {
        if (!value) throw new AssertionError(reason);
    }

    private static void detached(IsoCell cell, SAOIsoPlayerShell shell) {
        check(!cell.getObjectList().contains(shell) && !cell.getAddList().contains(shell),
            "staged body entered the world update lists");
        check(shell.getCurrentSquare() == null && !shell.isAddedToModelManager(),
            "staged body acquired a square or model");
    }

    private static void headlessAnimation(SAOIsoPlayerShell shell) throws Exception {
        // Native removal releases a ragdoll through getAnimationPlayer(). Supply
        // its real empty component without asking the absent renderer for a model.
        var ctor = zombie.core.skinnedmodel.animation.AnimationPlayer.class.getDeclaredConstructor();
        ctor.setAccessible(true);
        var field = IsoGameCharacter.class.getDeclaredField("animPlayer");
        field.setAccessible(true);
        field.set(shell, ctor.newInstance());
    }

    public static void main(String[] args) throws Exception {
        zombie.core.random.RandStandard.INSTANCE.init();
        zombie.ZomboidFileSystem.instance.init();
        zombie.SoundManager.instance = new zombie.DummySoundManager();
        zombie.Lua.LuaManager.platform = new se.krka.kahlua.j2se.J2SEPlatform();
        zombie.Lua.LuaManager.env = zombie.Lua.LuaManager.platform.newTable();
        zombie.Lua.LuaEventManager.register(zombie.Lua.LuaManager.platform,
            zombie.Lua.LuaManager.env);
        SurvivorDesc.HairCommonColors.add(new zombie.core.ImmutableColor(.2f, .3f, .4f));
        zombie.core.skinnedmodel.population.HairStyles.instance =
            new zombie.core.skinnedmodel.population.HairStyles();
        zombie.core.skinnedmodel.population.BeardStyles.instance =
            new zombie.core.skinnedmodel.population.BeardStyles();
        var hair = new zombie.core.skinnedmodel.population.HairStyle();
        hair.name = "fixture";
        zombie.core.skinnedmodel.population.HairStyles.instance.maleStyles.add(hair);
        zombie.core.skinnedmodel.population.HairStyles.instance.femaleStyles.add(hair);
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
        check(IsoWorld.instance.currentCell == cell, "fixture cell is not current");
        IsoPlayer[] slots = IsoPlayer.players.clone();
        IsoPlayer local = IsoPlayer.getInstance();
        int descriptors = IsoGameCharacter.getSurvivorMap().size();
        check(SAOReturnBody.create("N", "S", Double.NaN, 21, 0, false) == null,
            "nonfinite position accepted");
        SAOIsoPlayerShell shell = SAOReturnBody.create("Ada", "Stone", 10.25, 21.75, 0, true);
        check(shell != null, "detached creation failed");
        check(!SAOReturnBody.needsCleanup(shell), "successful creation requires cleanup");
        headlessAnimation(shell);
        detached(cell, shell);
        shell.getModData().rawset("SAOPersonId", "return-person");
        shell.getModData().rawset("SAOReturnToken", "return-token");
        var pendingHandle = new java.lang.ref.WeakReference<>(shell);
        shell = null; // Represents Lua releasing its last reference during reload.
        System.gc();
        shell = SAOReturnBody.find("return-person", "return-token");
        check(shell != null && shell == pendingHandle.get(), "reload GC lost the pending shell");
        check(SAOReturnBody.find("return-person", "return-token") == shell,
            "staged handle not recovered after caller reload");
        check(SAOReturnBody.find("return-person", "other-token") == null,
            "different transaction recovered another shell");
        check(shell.removalPending, "staged body is not paused");
        check(shell.populationAccounted, "return would debit population again");
        check(shell.isNpc() && shell.playerIndex > 0 && shell.getOnlineID() == -1,
            "shell NPC and off-slot identity");
        check(shell.getX() == 10.25f && shell.getY() == 21.75f && shell.getZ() == 0,
            "detached coordinates changed");
        check(shell.isFemale() && "Ada".equals(shell.getDescriptor().getForename())
                && "Stone".equals(shell.getDescriptor().getSurname()), "record identity changed");
        check(shell.getInventory().getItems().isEmpty(), "return received a starter kit");
        check(IsoGameCharacter.getSurvivorMap().size() == descriptors,
            "staged descriptor escaped before publication");
        shell.getStats().set(CharacterStat.HUNGER, .83f);
        shell.update();
        check(shell.getStats().get(CharacterStat.HUNGER) == .83f, "paused update changed body state");
        check(!SAOReturnBody.activate(shell), "detached body activated before publication");

        // The installed ModelManager honestly refuses a renderless publication.
        // Do not replace it with a fake successful renderer in this probe.
        check(!ModelManager.instance.isCreated(), "probe unexpectedly has a renderer");
        check(!SAOReturnBody.publish(shell) && !SAOReturnBody.publish(shell),
            "publication succeeded without a model manager");
        detached(cell, shell);
        check(shell.removalPending, "refused publication released pause");

        SAOIsoPlayerShell duplicate = SAOReturnBody.create("Dup", "Stone", 32, 42, 0, false);
        check(duplicate != null, "duplicate fixture creation failed");
        headlessAnimation(duplicate);
        duplicate.getModData().rawset("SAOPersonId", "return-person");
        duplicate.getModData().rawset("SAOReturnToken", "return-token");
        boolean refusedDuplicate = false;
        try { SAOReturnBody.find("return-person", "return-token"); }
        catch (IllegalStateException expected) { refusedDuplicate = true; }
        check(refusedDuplicate, "duplicate transaction silently selected a body");
        check(SAOReturnBody.discard(duplicate), "duplicate fixture cleanup failed");
        check(SAOReturnBody.find("return-person", "return-token") == shell,
            "discarded duplicate remained visible to reload");

        // Represent a partial publication using the actual native world list.
        cell.addMovingObject(shell);
        check(cell.getObjectList().contains(shell), "native publication fixture did not land");
        shell.getInventory().getItems().add(null);
        check(!SAOReturnBody.discard(shell), "invalid inventory cleanup falsely succeeded");
        check(SAOReturnBody.needsCleanup(shell), "failed cleanup lost its retry state");
        check(shell.removalPending && cell.getObjectList().contains(shell),
            "failed cleanup lost its paused handle");
        check(SAOReturnBody.find("return-person", "return-token") == shell,
            "cleanup handle lost after caller reload");
        check(!SAOReturnBody.publish(shell) && !SAOReturnBody.activate(shell),
            "discarding body republished or activated");
        shell.getInventory().getItems().clear();
        check(SAOReturnBody.discard(shell), "native cleanup retry failed");
        check(SAOReturnBody.discard(shell), "discard was not idempotent");
        check(!SAOReturnBody.needsCleanup(shell), "completed cleanup retained a retry state");
        check(SAOReturnBody.find("return-person", "return-token") == null,
            "discarded body recovered after caller reload");
        detached(cell, shell);
        check(!SAOReturnBody.publish(shell) && !SAOReturnBody.activate(shell),
            "discarded body resurrected");

        // A deferred removal retains the handle until the native queue finishes.
        SAOIsoPlayerShell queued = SAOReturnBody.create("Unnamed", "Survivor", 31, 41, 0, false);
        check(queued != null, "second detached creation failed");
        headlessAnimation(queued);
        check("Unnamed".equals(queued.getDescriptor().getForename())
                && "Survivor".equals(queued.getDescriptor().getSurname()),
            "existing placeholder identity randomized on return");
        cell.addMovingObject(queued);
        cell.setSafeToAdd(false);
        check(!SAOReturnBody.discard(queued), "queued removal declared complete while body remains");
        check(cell.getRemoveList().contains(queued) && queued.removalPending,
            "native removal queue did not retain paused body");
        cell.setSafeToAdd(true);
        check(SAOReturnBody.discard(queued), "deferred removal retry failed");
        detached(cell, queued);
        check(Arrays.equals(slots, IsoPlayer.players) && IsoPlayer.getInstance() == local,
            "local player ownership changed");
        check(IsoGameCharacter.getSurvivorMap().size() == descriptors,
            "discard leaked a survivor descriptor");
        System.out.println("PASS staged return body: actual detached constructor, paused update, "
            + "refused publication, reload rebinding, duplicate refusal, retained failed cleanup, "
            + "native queue retry, unchanged player slots");
        System.out.println("UNCHECKED successful rendered publication: no model assets or game world loaded");
    }
}
