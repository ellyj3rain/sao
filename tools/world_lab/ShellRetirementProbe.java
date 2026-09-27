import com.sao.bridge.SAOBridge;
import com.sao.engine.SAOIsoPlayerShell;
import com.sao.engine.SAOReturnBody;
import zombie.characters.IsoGameCharacter;
import zombie.characters.IsoPlayer;
import zombie.characters.SurvivorDesc;
import zombie.characters.SurvivorFactory;
import zombie.iso.IsoCell;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoWorld;

/** Actual native descriptor registration and production shell removal. */
public final class ShellRetirementProbe {
    private static void check(boolean condition, String reason) {
        if (!condition) throw new AssertionError(reason);
    }

    private static SAOIsoPlayerShell shell(IsoCell cell) throws Exception {
        SurvivorDesc desc = SurvivorFactory.CreateSurvivor();
        SAOIsoPlayerShell body = new SAOIsoPlayerShell(null, desc, 10, 20, 0);
        body.setNpc(true);
        body.playerIndex = 1;
        headlessAnimation(body);
        body.setCurrent(new IsoGridSquare(cell, null, 10, 20, 0));
        cell.addMovingObject(body);
        check(desc.getInstance() == body && IsoGameCharacter.getSurvivorMap().get(desc.getID()) == desc,
            "native descriptor registration fixture invalid");
        return body;
    }

    private static void headlessAnimation(SAOIsoPlayerShell body) throws Exception {
        var ctor = zombie.core.skinnedmodel.animation.AnimationPlayer.class.getDeclaredConstructor();
        ctor.setAccessible(true);
        var field = IsoGameCharacter.class.getDeclaredField("animPlayer");
        field.setAccessible(true);
        field.set(body, ctor.newInstance());
    }

    private static void removed(IsoCell cell, SAOIsoPlayerShell body) {
        check(!cell.getObjectList().contains(body) && !cell.getAddList().contains(body)
            && body.getCurrentSquare() == null, "native removal retained world attachment");
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
        SAOBridge bridge = SAOBridge.INSTANCE;
        var registry = IsoGameCharacter.getSurvivorMap();
        var worldRegistry = IsoWorld.instance.survivorDescriptors;
        int before = registry.size();
        int worldBefore = worldRegistry.size();

        SAOIsoPlayerShell attached = shell(cell);
        attached.removalPending = true;
        try {
            attached.retireNativeDescriptor();
            throw new AssertionError("attached shell retired descriptor");
        } catch (IllegalStateException expected) {
            check(registry.get(attached.getDescriptor().getID()) == attached.getDescriptor(),
                "attached retirement changed registry before refusing");
        }
        check(bridge.removeShell(attached), "attached fixture teardown failed");

        for (int cycle = 0; cycle < 64; cycle++) {
            SAOIsoPlayerShell body = shell(cell);
            SurvivorDesc desc = body.getDescriptor();
            check(bridge.removeShell(body), "production retirement failed");
            removed(cell, body);
            check(registry.get(desc.getID()) != desc, "retired shell remained globally registered");
            check(worldRegistry.get(desc.getID()) != desc, "retired shell remained in world descriptor registry");
            check(desc.getInstance() == null, "retired descriptor retained body reference");
            check(bridge.removeShell(body), "repeated retirement failed");
            check(registry.size() == before, "native descriptor count grew across retirement");
            check(worldRegistry.size() == worldBefore, "world descriptor count grew across retirement");
        }

        // The spawn slot-violation branch invokes this same private teardown
        // before the body has a Lua owner or a public removeShell call.
        SAOIsoPlayerShell rollback = shell(cell);
        SurvivorDesc rollbackDesc = rollback.getDescriptor();
        var rollbackMethod = SAOBridge.class.getDeclaredMethod("removeShellInternal", SAOIsoPlayerShell.class);
        rollbackMethod.setAccessible(true);
        check(!rollback.removalPending, "rollback fixture already removal-pending");
        try {
            rollbackMethod.invoke(null, rollback);
        } catch (java.lang.reflect.InvocationTargetException error) {
            throw new AssertionError("spawn rollback failed descriptor retirement", error.getCause());
        }
        removed(cell, rollback);
        check(rollback.removalPending && rollbackDesc.getInstance() == null
            && registry.get(rollbackDesc.getID()) != rollbackDesc
            && worldRegistry.get(rollbackDesc.getID()) != rollbackDesc,
            "spawn rollback failed descriptor retirement");

        SAOIsoPlayerShell failed = shell(cell);
        SurvivorDesc retained = failed.getDescriptor();
        var inventory = failed.getInventory();
        var inventoryField = IsoGameCharacter.class.getDeclaredField("inventory");
        inventoryField.setAccessible(true);
        inventoryField.set(failed, null);
        check(!bridge.removeShell(failed), "unreadable inventory removal unexpectedly succeeded");
        check(registry.get(retained.getID()) == retained && retained.getInstance() == failed,
            "failed native removal released descriptor ownership");
        check(worldRegistry.get(retained.getID()) == retained,
            "failed native removal released world descriptor ownership");
        failed.setInventory(inventory);
        check(bridge.removeShell(failed) && registry.get(retained.getID()) != retained,
            "retirement retry did not release descriptor");

        SAOIsoPlayerShell collision = shell(cell);
        SurvivorDesc old = collision.getDescriptor(), foreign = new SurvivorDesc(false);
        registry.put(old.getID(), foreign);
        worldRegistry.put(old.getID(), foreign);
        check(bridge.removeShell(collision), "collision retirement failed");
        check(registry.get(old.getID()) == foreign, "retirement erased foreign descriptor registration");
        check(worldRegistry.get(old.getID()) == foreign, "retirement erased foreign world descriptor registration");
        check(old.getInstance() == null, "unregistered owned descriptor retained body");
        registry.remove(old.getID(), foreign);
        worldRegistry.remove(old.getID(), foreign);

        SAOIsoPlayerShell rebound = shell(cell);
        SurvivorDesc shared = rebound.getDescriptor();
        IsoPlayer borrower = new IsoPlayer(null, new SurvivorDesc(false), 0, 0, 0, true);
        shared.setInstance(borrower);
        check(bridge.removeShell(rebound), "rebound retirement failed");
        check(registry.get(shared.getID()) == shared && shared.getInstance() == borrower,
            "retirement erased rebound descriptor ownership");
        check(worldRegistry.get(shared.getID()) == shared, "retirement erased rebound world descriptor ownership");
        registry.remove(shared.getID(), shared);
        worldRegistry.remove(shared.getID(), shared);

        SAOIsoPlayerShell replaced = shell(cell);
        SurvivorDesc original = replaced.getDescriptor();
        SurvivorDesc borrowed = SurvivorFactory.CreateSurvivor();
        borrowed.setInstance(borrower);
        replaced.setDescriptor(borrowed);
        check(bridge.removeShell(replaced), "replaced descriptor retirement failed");
        check(registry.get(original.getID()) != original && worldRegistry.get(original.getID()) != original
            && original.getInstance() == null, "original descriptor leaked after replacement");
        check(registry.get(borrowed.getID()) == borrowed && worldRegistry.get(borrowed.getID()) == borrowed
            && borrowed.getInstance() == borrower, "retirement erased borrowed replacement descriptor");
        registry.remove(borrowed.getID(), borrowed);
        worldRegistry.remove(borrowed.getID(), borrowed);

        SAOIsoPlayerShell staged = SAOReturnBody.create("Stage", "Person", 10, 20, 0, false);
        check(staged != null, "staged retirement construction failed");
        headlessAnimation(staged);
        SurvivorDesc stagedDesc = staged.getDescriptor();
        check(SAOReturnBody.discard(staged), "staged native discard failed");
        check(registry.get(stagedDesc.getID()) != stagedDesc
            && worldRegistry.get(stagedDesc.getID()) != stagedDesc && stagedDesc.getInstance() == null,
            "staged discard retained descriptor ownership");
        check(registry.size() == before, "retirement fixture leaked registrations");
        check(worldRegistry.size() == worldBefore, "retirement fixture leaked world registrations");
        System.out.println("PASS native shell retirement: 64 actual constructors/removals, stable descriptor roots, failed removal/retry, repeated removal, foreign registration and rebound ownership. No rendered-world claim.");
        System.exit(0);
    }
}
