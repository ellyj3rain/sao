import com.sao.bridge.SAOBridge;
import com.sao.engine.SAOIsoPlayerShell;
import com.sao.engine.SAOReturnBody;
import java.lang.invoke.MethodHandles;
import java.lang.invoke.MethodType;
import zombie.characters.IsoPlayer;
import zombie.characters.SurvivorDesc;
import zombie.characters.SurvivorFactory;
import zombie.iso.IsoCell;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoWorld;

/** Native attachment-state methods only; no world, renderer or game loop. */
public final class ShellUnloadProbe {
    private static void check(boolean value, String message) {
        if (!value) throw new AssertionError(message);
    }

    public static void main(String[] args) throws Throwable {
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
        // Invoke the installed owner of collection removal directly. The outer
        // IsoPlayer override also releases animation/model resources, which this
        // method fixture intentionally does not construct.
        var removeMembership = MethodHandles.privateLookupIn(zombie.iso.IsoMovingObject.class, MethodHandles.lookup())
            .findSpecial(zombie.iso.IsoMovingObject.class, "removeFromWorld", MethodType.methodType(void.class),
                zombie.iso.IsoMovingObject.class);
        SAOIsoPlayerShell shell = SAOReturnBody.create("Ada", "Stone", 10, 20, 0, true);
        check(shell != null, "production shell construction failed");
        check(!bridge.isShellUnloaded(shell), "staged return shell misclassified as unloaded");
        check(!bridge.isShellUnloaded(null) && !bridge.isShellUnloaded(new Object()), "non-shell accepted as unloaded");
        IsoPlayer player = new IsoPlayer(null, new SurvivorDesc(false), 0, 0, 0, true);
        check(!bridge.isShellUnloaded(player), "ordinary native player accepted as unloaded");

        // The production constructor above provides a detached staging shell.
        // Admit it through the native cell API to exercise actual collections,
        // without the unrelated model/terrain prerequisites of activation.
        shell.removalPending = false;
        cell.addMovingObject(shell);
        check(shell.getCurrentSquare() == null && cell.getObjectList().contains(shell), "direct admission fixture invalid");
        check(!bridge.isShellUnloaded(shell), "admitted null-square shell misclassified as unloaded");
        IsoGridSquare square = new IsoGridSquare(cell, null, 10, 20, 0);
        shell.setCurrent(square);
        check(!bridge.isShellUnloaded(shell), "square-attached shell misclassified as unloaded");
        // Native chunk unloading reaches these installed collection/square
        // methods; this fixture does not stream a whole chunk or release models.
        removeMembership.invoke(shell);
        check(!cell.getObjectList().contains(shell) && !cell.getAddList().contains(shell), "native removal fixture retained membership");
        check(!bridge.isShellUnloaded(shell), "remaining current square ignored");
        shell.removeFromSquare();
        check(shell.getCurrentSquare() == null && bridge.isShellUnloaded(shell), "native removed shell not recognized");
        boolean pending = shell.removalPending;
        check(bridge.isShellUnloaded(shell) && shell.removalPending == pending
            && !cell.getObjectList().contains(shell) && !cell.getAddList().contains(shell), "attachment read changed native ownership");

        cell.setSafeToAdd(false);
        cell.addMovingObject(shell);
        check(cell.getAddList().contains(shell) && !cell.getObjectList().contains(shell), "queued admission fixture invalid");
        check(!bridge.isShellUnloaded(shell), "queued null-square shell misclassified as unloaded");
        removeMembership.invoke(shell);
        check(bridge.isShellUnloaded(shell), "native queued removal not recognized");
        shell.removalPending = true;
        check(!bridge.isShellUnloaded(shell), "captured removal shell misclassified as unloaded");
        shell.removalPending = false;
        IsoWorld.instance.currentCell = null;
        check(!bridge.isShellUnloaded(shell), "missing native cell failed open");
        IsoWorld.instance.currentCell = cell;
        IsoWorld world = IsoWorld.instance;
        IsoWorld.instance = null;
        try { check(!bridge.isShellUnloaded(shell), "missing native world failed open"); }
        finally { IsoWorld.instance = world; }
        System.out.println("PASS native shell unload state: production constructor; direct/queued native admission and removal; current-square distinction; staged/captured and ordinary-player exclusions; absent world/cell; read-only ownership. No loaded-world claim.");
        System.exit(0);
    }
}
