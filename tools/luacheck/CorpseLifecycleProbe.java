import com.sao.bridge.SAOBridge;
import com.sao.engine.SAOIsoPlayerShell;
import com.sao.engine.SAONativeDeath;
import java.lang.reflect.*;
import zombie.characters.IsoGameCharacter;
import zombie.iso.*;
import zombie.iso.objects.IsoDeadBody;

/** Installed native corpse construction, scheduler and shell retirement. */
public final class CorpseLifecycleProbe {
    private static int checks;
    private static void check(String name, boolean ok) {
        System.out.println("CHECK " + name + "=" + ok);
        if (!ok) throw new AssertionError(name);
        checks++;
    }
    private static Object fixture(String name, Class<?>[] types, Object... args) throws Exception {
        Method m = MovementCrossingProbe.class.getDeclaredMethod(name, types);
        m.setAccessible(true); return m.invoke(null, args);
    }
    private static IsoDeadBody corpse(SAOIsoPlayerShell body) throws Exception {
        Field f = IsoGameCharacter.class.getDeclaredField("diedBody"); f.setAccessible(true);
        return (IsoDeadBody) f.get(body);
    }
    private static SAOIsoPlayerShell person(IsoCell cell) throws Exception {
        var body = (SAOIsoPlayerShell) fixture("person", new Class<?>[] { IsoCell.class }, cell);
        body.setNpc(true); body.playerIndex = 4;
        // Headless audio only; death, geometry, cell and corpse code remain native.
        body.getFMODParameters().parameterList.clear();
        var square = body.getCurrentSquare(); body.setSquare(square); body.setForwardDirection(1, 0);
        square.getMovingObjects().add(body); cell.getObjectList().add(body);
        body.getModData().rawset("SAOPersonId", "corpse-lifecycle-" + checks);
        return body;
    }
    private static void lethal(SAOIsoPlayerShell body) {
        body.getBodyDamage().setOverallBodyHealth(0); body.setHealth(0);
    }
    private static void drain(IsoCell cell) throws Exception {
        Method m = IsoCell.class.getDeclaredMethod("ObjectDeletionAddition");
        m.setAccessible(true); m.invoke(cell);
    }
    public static void main(String[] args) throws Exception {
        IsoCell cell = (IsoCell) fixture("boot", new Class<?>[0]);
        var platform = new se.krka.kahlua.j2se.J2SEPlatform();
        zombie.Lua.LuaManager.platform = platform; zombie.Lua.LuaManager.env = platform.newEnvironment();
        zombie.Lua.LuaManager.thread = new se.krka.kahlua.vm.KahluaThread(platform, zombie.Lua.LuaManager.env);
        zombie.Lua.LuaManager.thread.debugOwnerThread = Thread.currentThread();
        zombie.Lua.LuaManager.converterManager = new se.krka.kahlua.converter.KahluaConverterManager();
        zombie.Lua.KahluaNumberConverter.install(zombie.Lua.LuaManager.converterManager);
        zombie.Lua.LuaManager.caller = new se.krka.kahlua.integration.LuaCaller(zombie.Lua.LuaManager.converterManager);
        System.out.println("Native transmission=" + zombie.SandboxOptions.instance.lore.transmission.getValue());
        Field regions = zombie.iso.areas.isoregion.IsoRegions.class.getDeclaredField("dataRoot");
        regions.setAccessible(true); regions.set(null, new zombie.iso.areas.isoregion.data.DataRoot());
        zombie.core.Core.soundDisabled = true;
        var bridge = SAOBridge.INSTANCE;
        check("not_character_unchanged", bridge.ensureCorpse(new Object()).equals("NOT_A_CHARACTER"));

        var living = person(cell); var origin = living.getCurrentSquare();
        check("living_unchanged", bridge.ensureCorpse(living).equals("ALIVE") && !SAONativeDeath.hasCorpse(living));
        living.setCurrent(null); living.setCurrentSquareFromPosition();
        check("living_position_resolves", living.getCurrentSquare() == origin);
        lethal(living);
        check("initial_fall_not_retired", !SAONativeDeath.hasCorpse(living) && !living.isOnDeathDone());
        living.setCurrent(null); living.postupdate();
        check("initial_fall_native_postupdate_runs", living.getCurrentSquare() == origin);
        living.setOnDeathDone(true);
        check("completion_flag_without_corpse_not_retired", !SAONativeDeath.hasCorpse(living));
        living.setCurrent(null); living.postupdate();
        check("pending_native_postupdate_runs", living.getCurrentSquare() == origin);
        living.removeFromWorld(); living.removeFromSquare();
        check("null_square_not_corpse", bridge.ensureCorpse(living).equals("DIE_PENDING") && corpse(living) == null);

        var body = person(cell); origin = body.getCurrentSquare(); lethal(body);
        int prior = origin.getDeadBodys().size();
        String verdict = bridge.ensureCorpse(body);
        System.out.println("NATIVE die=" + verdict + " current=" + body.getCurrentSquare() + " square=" + body.getSquare()
            + " last=" + body.getLastSquare() + " object=" + cell.getObjectList().contains(body)
            + " add=" + cell.getAddList().contains(body) + " remove=" + cell.getRemoveList().contains(body));
        check("bridge_native_die", verdict.equals("DIED"));
        var dead = corpse(body);
        check("actual_native_corpse", dead != null && body.isOnDeathDone() && dead.getSquare() == origin
            && origin.getDeadBodys().contains(dead) && origin.getStaticMovingObjects().contains(dead));
        check("native_source_detached", body.getCurrentSquare() == null && !origin.getMovingObjects().contains(body)
            && !cell.getObjectList().contains(body) && SAONativeDeath.isDetached(body));
        var keepPlayer = zombie.characters.IsoPlayer.getInstance();
        var keepCamera = IsoCamera.getCameraCharacter();
        try { body.update(); } catch (Throwable error) { throw new AssertionError("retired_update_must_not_run", error); }
        check("retired_update_returns", body.getCurrentSquare() == null);
        var bucket = new zombie.MovingObjectUpdateSchedulerUpdateBucket(zombie.UpdateSchedulerSimulationLevel.FULL);
        bucket.add(body); bucket.postupdate(0);
        check("native_scheduled_postupdate_cannot_reinsert", body.getCurrentSquare() == null && !origin.getMovingObjects().contains(body));
        check("retired_preserves_global_owners", zombie.characters.IsoPlayer.getInstance() == keepPlayer && IsoCamera.getCameraCharacter() == keepCamera);
        check("exact_corpse_ack", bridge.ensureCorpse(body).equals("ALREADY_CORPSE"));
        body.die(); check("native_die_idempotent", corpse(body) == dead && origin.getDeadBodys().size() == prior + 1);
        check("other_shell_not_retired_by_nearby_corpse", !SAONativeDeath.hasCorpse(living));

        var queued = person(cell); origin = queued.getCurrentSquare(); lethal(queued); cell.setSafeToAdd(false);
        check("deferred_removal_is_pending", bridge.ensureCorpse(queued).equals("DIE_PENDING"));
        check("deferred_actual_corpse_with_live_cell_ownership", corpse(queued) != null && queued.getCurrentSquare() == null
            && cell.getObjectList().contains(queued) && cell.getRemoveList().contains(queued) && !SAONativeDeath.isDetached(queued));
        zombie.MovingObjectUpdateScheduler.instance.startFrame();
        check("native_startframe_cannot_reattach_corpse_shell", queued.getCurrentSquare() == null);
        queued.postupdate();
        check("pending_retired_postupdate_cannot_reinsert", !origin.getMovingObjects().contains(queued));
        drain(cell); cell.setSafeToAdd(true);
        check("native_drain_detaches", SAONativeDeath.isDetached(queued) && !cell.getRemoveList().contains(queued));
        check("ack_after_native_drain", bridge.ensureCorpse(queued).equals("ALREADY_CORPSE"));

        // The legacy foreign-character branch is not changed by shell-specific retirement.
        var desc = new zombie.characters.SurvivorDesc(false); desc.getHumanVisual().setSkinTextureName("fixture");
        var foreign = new zombie.characters.IsoPlayer(cell, desc, 10, 20, 0, false);
        foreign.setHealth(0); foreign.getBodyDamage().setOverallBodyHealth(0); foreign.setCurrent(null);
        check("foreign_null_square_contract_unchanged", bridge.ensureCorpse(foreign).equals("ALREADY_CORPSE"));
        System.out.println("PASS corpse lifecycle " + checks + " checks");
    }
}
