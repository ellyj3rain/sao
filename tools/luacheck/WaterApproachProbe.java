import com.sao.bridge.SAOBridge;
import com.sao.engine.SAOIsoPlayerShell;
import com.sao.engine.SAONeeds;
import java.lang.reflect.Method;
import java.util.Map;
import zombie.characters.SurvivorDesc;
import zombie.iso.IsoCell;
import zombie.iso.IsoObject;
import zombie.iso.IsoGridSquare;
import zombie.iso.objects.IsoDoor;
import zombie.iso.objects.IsoWindow;
import zombie.iso.SpriteDetails.IsoFlagType;

/** Installed cell, fluid, square/reach and actual bridge methods; no game loop. */
public final class WaterApproachProbe {
    private static int checks;
    private static se.krka.kahlua.vm.KahluaTable oracleEnv;
    private static se.krka.kahlua.vm.KahluaThread oracleThread;

    private static void initOracle(IsoCell cell) throws Exception {
        var platform = new se.krka.kahlua.j2se.J2SEPlatform();
        oracleEnv = platform.newEnvironment();
        oracleThread = new se.krka.kahlua.vm.KahluaThread(platform, oracleEnv);
        oracleThread.debugOwnerThread = Thread.currentThread();
        var expose = LuaRun.class.getDeclaredMethod("exposeEngine", se.krka.kahlua.vm.KahluaTable.class,
            se.krka.kahlua.j2se.J2SEPlatform.class, se.krka.kahlua.vm.KahluaThread.class);
        expose.setAccessible(true);
        if (!Boolean.TRUE.equals(expose.invoke(null, oracleEnv, platform, oracleThread))) throw new AssertionError("oracle exposure");
        var exposer = new zombie.Lua.LuaManager.Exposer(zombie.Lua.LuaManager.converterManager, platform, oracleEnv);
        for (Class<?> type : new Class<?>[]{SAOIsoPlayerShell.class, IsoObject.class, IsoGridSquare.class, IsoCell.class, IsoFlagType.class}) {
            exposer.setExposed(type); exposer.exposeLikeJava(type, oracleEnv);
        }
        oracleEnv.rawset("nativeCell", cell);
        lua("function getCell() return nativeCell end; ISTimedActionQueue={clear=function() error('unexpected clear') end, add=function() error('unexpected queue') end};"
            + "ISPathFindAction={pathAdjacentToMultiTileObject=function() return nil end}");
        lua(java.nio.file.Files.readString(java.nio.file.Path.of("media/lua/shared/luautils.lua")));
    }

    private static Object lua(String text) throws Exception {
        return oracleThread.call(se.krka.kahlua.luaj.compiler.LuaCompiler.loadstring(text, "installed-water-oracle", oracleEnv), null, null, null);
    }

    private static boolean vanillaReach(SAOIsoPlayerShell body, IsoObject object) throws Exception {
        oracleEnv.rawset("nativeBody", body); oracleEnv.rawset("nativeObject", object);
        return Boolean.TRUE.equals(lua("return luautils.walkAdjObject(nativeBody,nativeObject,true,true)"));
    }

    private static IsoDoor door(IsoCell cell, IsoGridSquare square) {
        IsoDoor door = new IsoDoor(cell); door.setSquare(square); door.north = false;
        square.getObjects().add(door); square.getSpecialObjects().add(door);
        square.getProperties().set(IsoFlagType.doorW);
        return door;
    }

    private static void remove(IsoObject object) {
        object.getSquare().getObjects().remove(object);
        object.getSquare().getSpecialObjects().remove(object);
    }

    private static String waterLog() throws Exception {
        var path=java.nio.file.Path.of(System.getProperty("user.home"),"Zomboid","SAOAgent.log");
        return java.nio.file.Files.exists(path) ? java.nio.file.Files.readString(path) : "";
    }

    private static void reachChecks(IsoCell cell) throws Exception {
        initOracle(cell);
        var body = person(cell);
        IsoObject source = sink(cell, 11, 20);
        IsoDoor door = door(cell, source.getSquare());
        door.setOpen(true);
        body.getModData().rawset("SAOPersonId","water-probe");
        String before=waterLog();
        SAOBridge.INSTANCE.findWaterSource(body, 3, 1);
        String selected=waterLog().substring(before.length());
        String afterSelection=waterLog(); SAOBridge.INSTANCE.findWaterSource(body,3,1);
        check("installed_open_door_is_not_a_blocked_edge", body.getCurrentSquare().isSomethingTo(source.getSquare())
            && body.getCurrentSquare().canReachTo(source.getSquare()) && vanillaReach(body, source));
        check("water_open_door_matches_installed_interaction", SAOBridge.INSTANCE.waterSourceWithinReach(body));
        check("water_selection_receipt_binds_actual_fixture", selected.contains("water selected person=water-probe")
            && selected.contains("fixture=IsoObject@"+Integer.toHexString(System.identityHashCode(source)))
            && selected.contains("source=11,20,0 amount=2.0 reach=true"));
        check("unchanged_water_query_does_not_spam_receipts", waterLog().equals(afterSelection));
        door.setOpen(false);
        check("water_closed_door_refused_by_native_reach", !vanillaReach(body, source)
            && !SAOBridge.INSTANCE.waterSourceWithinReach(body));
        remove(door); source.getSquare().getProperties().unset(IsoFlagType.doorW);
        IsoWindow window = new IsoWindow(cell); window.setSquare(source.getSquare());
        source.getSquare().getObjects().add(window); source.getSquare().getSpecialObjects().add(window);
        source.getSquare().getProperties().set(IsoFlagType.windowW);
        var open = IsoWindow.class.getDeclaredField("open"); open.setAccessible(true); open.setBoolean(window, true);
        check("water_open_window_matches_installed_interaction", vanillaReach(body, source)
            && SAOBridge.INSTANCE.waterSourceWithinReach(body));
        open.setBoolean(window, false);
        check("water_closed_window_refused_by_native_reach", !vanillaReach(body, source)
            && !SAOBridge.INSTANCE.waterSourceWithinReach(body));
        remove(window); source.getSquare().getProperties().unset(IsoFlagType.windowW);
        position(body, cell, 9.9f, 20.5f);
        check("water_native_adjacent_square_limit", !vanillaReach(body, source)
            && !SAOBridge.INSTANCE.waterSourceWithinReach(body));
        position(body, cell, 10.01f, 19.01f);
        check("water_diagonal_axis_reach_matches_vanilla", vanillaReach(body, source)
            && SAOBridge.INSTANCE.waterSourceWithinReach(body));
        position(body, cell, 10.5f, 20.5f);
        source.getSquare().getProperties().set(IsoFlagType.collideW);
        source.getSquare().getProperties().set(IsoFlagType.WindowW);
        check("water_wall_square_matches_vanilla", !body.getCurrentSquare().canReachTo(source.getSquare()) && !vanillaReach(body, source)
            && !SAOBridge.INSTANCE.waterSourceWithinReach(body));
        source.getSquare().getProperties().unset(IsoFlagType.collideW);
        source.getSquare().getProperties().unset(IsoFlagType.WindowW);
        position(body, cell, 10.5f, 19.5f);
        source.getSquare().getProperties().set(IsoFlagType.collideN);
        source.getSquare().getProperties().set(IsoFlagType.WindowN);
        check("water_north_wall_matches_vanilla", !body.getCurrentSquare().canReachTo(source.getSquare()) && !vanillaReach(body, source)
            && !SAOBridge.INSTANCE.waterSourceWithinReach(body));
        source.getSquare().getProperties().unset(IsoFlagType.collideN);
        source.getSquare().getProperties().unset(IsoFlagType.WindowN);
        position(body, cell, 10.5f, 20.5f);
        body.setZ(1); body.setCurrent(cell.getGridSquare(10,20,1));
        check("water_other_floor_not_interactable", !vanillaReach(body, source)
            && !SAOBridge.INSTANCE.waterSourceWithinReach(body));
        position(body, cell, 10.5f,20.5f);
        door = door(cell, source.getSquare());
        IsoObject usable = sink(cell, 9, 21);
        check("usable_water_precedes_nearer_blocked_fixture", "9:21:0".equals(SAOBridge.INSTANCE.findWaterSource(body,3,1))
            && SAONeeds.waterSource(body)==usable && vanillaReach(body,usable));
        remove(usable); remove(door); source.getSquare().getProperties().unset(IsoFlagType.doorW);
        SAOBridge.INSTANCE.findWaterSource(body,3,1); remove(source);
        check("removed_water_cannot_remain_in_reach", !SAOBridge.INSTANCE.waterSourceWithinReach(body));
        SAONeeds.resetRuntimeForWorld();
    }

    private static void fluidChecks(IsoCell cell) throws Exception {
        var body=person(cell); position(body,cell,8.5f,9.5f);
        IsoObject source=sink(cell,9,10);
        var fluids=source.getFluidContainer();
        fluids.Empty(); fluids.addFluid(zombie.entity.components.fluids.Fluid.SodaPop,2);
        check("nonwater_fluid_is_not_a_thirst_source", source.hasFluid() && !source.isTaintedWater()
            && !source.hasWater() && SAOBridge.INSTANCE.findWaterSource(body,3,1).isEmpty());
        fluids.Empty(); fluids.addFluid(zombie.entity.components.fluids.Fluid.Water,.05f);
        check("positive_last_sip_is_selected", "9:10:0".equals(SAOBridge.INSTANCE.findWaterSource(body,3,1))
            && SAONeeds.waterSource(body)==source && SAOBridge.INSTANCE.waterSourceWithinReach(body));
        fluids.addFluid(zombie.entity.components.fluids.Fluid.Bleach,.05f);
        check("contaminated_selected_fluid_is_revalidated", SAONeeds.waterSource(body)==null
            && !SAOBridge.INSTANCE.waterSourceWithinReach(body));
        fluids.Empty(); fluids.addFluid(zombie.entity.components.fluids.Fluid.TaintedWater,2);
        check("tainted_water_is_not_selected", source.hasWater() && source.isTaintedWater()
            && SAOBridge.INSTANCE.findWaterSource(body,3,1).isEmpty());
        fluids.Empty(); fluids.addFluid(zombie.entity.components.fluids.Fluid.Water,2);
        SAOBridge.INSTANCE.findWaterSource(body,3,1); fluids.Empty();
        check("dry_selected_fluid_is_revalidated", SAONeeds.waterSource(body)==null
            && !SAOBridge.INSTANCE.waterSourceWithinReach(body));
        source.getSprite().getProperties().set(IsoFlagType.waterPiped);
        source.getModData().rawset("waterAmount",2.0);
        check("empty_component_still_has_native_pipe_reserve", source.getPrimaryFluid()==null
            && source.hasWater() && source.getFluidAmount()==2);
        check("empty_component_pipe_reserve_is_selected", "9:10:0".equals(SAOBridge.INSTANCE.findWaterSource(body,3,1))
            && SAONeeds.waterSource(body)==source && SAOBridge.INSTANCE.waterSourceWithinReach(body));
        remove(source);
        source=(IsoObject)fixture("holder",new Class<?>[]{IsoCell.class,int.class,int.class,int.class},cell,9,10,0);
        source.getSprite().getProperties().set(IsoFlagType.waterPiped);
        source.getModData().rawset("waterAmount",.05);
        check("componentless_pipe_reserve_is_selected", source.getFluidContainer()==null && source.hasWater()
            && "9:10:0".equals(SAOBridge.INSTANCE.findWaterSource(body,3,1)) && SAONeeds.waterSource(body)==source);
        var previousRoom=source.getSquare().room;
        long previousRoomId=source.getSquare().roomId;
        int oldShut=zombie.SandboxOptions.instance.waterShutModifier.getValue();
        int oldApo=zombie.SandboxOptions.instance.timeSinceApo.getValue();
        source.getSquare().room=new zombie.iso.areas.IsoRoom();
        source.getSquare().roomId=1;
        zombie.SandboxOptions.instance.waterShutModifier.setValue(14);
        zombie.SandboxOptions.instance.timeSinceApo.setValue(1);
        try {
            source.getModData().rawset("waterAmount",0.0);
            check("municipal_supply_has_native_infinite_water", source.getFluidContainer()==null
                && source.hasWater() && source.getFluidAmount()==10000);
            check("municipal_supply_is_selected", "9:10:0".equals(SAOBridge.INSTANCE.findWaterSource(body,3,1))
                && SAONeeds.waterSource(body)==source && SAOBridge.INSTANCE.waterSourceWithinReach(body));
        } finally {
            source.getSquare().room=previousRoom;
            source.getSquare().roomId=previousRoomId;
            zombie.SandboxOptions.instance.waterShutModifier.setValue(oldShut);
            zombie.SandboxOptions.instance.timeSinceApo.setValue(oldApo);
        }
        remove(source); SAONeeds.resetRuntimeForWorld();
    }

    private static Object fixture(String name, Class<?>[] types, Object... args) throws Exception {
        Method method = ResourceApproachProbe.class.getDeclaredMethod(name, types);
        method.setAccessible(true);
        return method.invoke(null, args);
    }

    private static void check(String name, boolean ok) {
        System.out.println("CHECK " + name + "=" + ok);
        if (!ok) throw new AssertionError(name);
        checks++;
    }

    private static IsoObject sink(IsoCell cell, int x, int y) throws Exception {
        IsoObject object = (IsoObject) fixture("holder", new Class<?>[]{IsoCell.class, int.class, int.class, int.class}, cell, x, y, 0);
        fixture("fluid", new Class<?>[]{IsoObject.class}, object);
        return object;
    }

    private static SAOIsoPlayerShell person(IsoCell cell) {
        SurvivorDesc desc = new SurvivorDesc(false);
        desc.getHumanVisual().setSkinTextureName("fixture");
        SAOIsoPlayerShell body = new SAOIsoPlayerShell(cell, desc, 10, 20, 0);
        position(body, cell, 10.5f, 20.5f);
        return body;
    }

    private static void position(SAOIsoPlayerShell body, IsoCell cell, float x, float y) {
        body.setX(x); body.setY(y); body.setZ(0);
        body.setCurrent(cell.getGridSquare((int)x, (int)y, 0));
    }

    private static boolean fail(SAOIsoPlayerShell body, double hours, String result) {
        IsoObject source = SAONeeds.waterSource(body);
        var square = source.getSquare();
        String target = SAOBridge.INSTANCE.resourceApproach(body, "water", square.getX(), square.getY(), square.getZ());
        if (!target.startsWith("AT:")) throw new AssertionError("native target unavailable: " + target);
        String[] bits = target.split(":");
        return SAOBridge.INSTANCE.failWaterApproach(body, result, hours,
            Integer.parseInt(bits[1]), Integer.parseInt(bits[2]), Integer.parseInt(bits[3]));
    }

    @SuppressWarnings("unchecked")
    private static Map<Object, java.util.List<?>> failures() throws Exception {
        var field = SAONeeds.class.getDeclaredField("WATER_FAILURES");
        field.setAccessible(true);
        return (Map<Object, java.util.List<?>>) field.get(null);
    }

    public static void main(String[] args) throws Exception {
        IsoCell cell = (IsoCell) fixture("boot", new Class<?>[]{});
        String phase=args.length==0 ? "all" : args[0];
        if (!java.util.Set.of("all","reach","fluid","attempt").contains(phase)) throw new AssertionError("unknown probe phase");
        if (phase.equals("all") || phase.equals("reach")) reachChecks(cell);
        if (phase.equals("all") || phase.equals("fluid")) fluidChecks(cell);
        if (phase.equals("reach") || phase.equals("fluid")) {
            System.out.println("PASS water approach checks="+checks); return;
        }
        var body = person(cell);
        IsoObject first = sink(cell, 14, 20), second = sink(cell, 16, 20);
        first.getSquare().getProperties().set(IsoFlagType.collideW);
        check("nearest_native_fixture_selected", "14:20:0".equals(SAOBridge.INSTANCE.findWaterSource(body, 8, 2)));
        check("failed_exact_approach_recorded", fail(body, 2, "done:FailedObstacle:FAILED_LOCKED_DOOR"));
        check("legacy_query_retains_unfiltered_contract", "14:20:0".equals(SAOBridge.INSTANCE.findWaterSource(body, 8)));
        SAONeeds.clearWaterSource(body);
        check("failed_fixture_does_not_monopolize_query", "16:20:0".equals(SAOBridge.INSTANCE.findWaterSource(body, 8, 2.01)));
        check("second_actual_failure_recorded", fail(body, 2.01, "done:Failed"));
        check("both_failed_candidates_yield_to_knowledge", SAOBridge.INSTANCE.findWaterSource(body, 8, 2.02).isEmpty());
        position(body, cell, 11.6f, 21.2f);
        check("small_motion_does_not_reset_failed_approach", SAOBridge.INSTANCE.findWaterSource(body, 8, 2.03).isEmpty());
        position(body, cell, 13.5f, 20.5f);
        check("adjacency_behind_native_barrier_is_still_held", SAOBridge.INSTANCE.findWaterSource(body, 8, 2.04).isEmpty());
        first.getSquare().getProperties().unset(IsoFlagType.collideW);
        check("actual_native_reach_releases_failure", "14:20:0".equals(SAOBridge.INSTANCE.findWaterSource(body, 8, 2.05))
            && SAOBridge.INSTANCE.waterSourceWithinReach(body));
        check("no_water_consumed_or_changed_by_reappraisal", first.getFluidAmount() == 2 && second.getFluidAmount() == 2);
        position(body, cell, 10.5f, 20.5f);
        check("new_owned_approach_can_fail", fail(body, 2.06, "done:stalled:ManualRoute"));
        var other = person(cell);
        check("another_person_keeps_own_candidate", "14:20:0".equals(SAOBridge.INSTANCE.findWaterSource(other, 8, 2.07)));
        check("county_time_expiry_allows_reconsideration", "14:20:0".equals(SAOBridge.INSTANCE.findWaterSource(body, 8, 2.32)));
        check("repeat_failure_recorded", fail(body, 2.32, "done:Failed"));
        second.getSquare().getObjects().remove(second);
        check("repeated_failure_has_bounded_longer_backoff", SAOBridge.INSTANCE.findWaterSource(body, 8, 2.60).isEmpty());
        check("repeated_failure_eventually_expires", "14:20:0".equals(SAOBridge.INSTANCE.findWaterSource(body, 8, 2.83)));
        check("flee_or_cancel_is_not_an_access_failure", !fail(body, 2.83, "cancelled:threat"));
        check("arrival_is_not_an_access_failure", !fail(body, 2.83, "done:arrived"));
        check("tick_fault_is_not_an_access_failure", !fail(body, 2.83, "done:tick-fault"));
        check("unloaded_route_is_not_an_access_failure", !fail(body, 2.83, "done:FailedObstacle:FAILED_UNLOADED_NEXT_SQUARE"));
        check("unknown_native_failure_is_not_new_access_evidence", !fail(body, 2.83, "done:FailedObstacle:FAILED_UNKNOWN"));
        check("invalid_clock_cannot_penalize_source", !fail(body, Double.NaN, "done:Failed"));
        check("unrelated_target_cannot_penalize_source", !SAOBridge.INSTANCE.failWaterApproach(body, "done:Failed", 2.83, 25, 25, 0));
        check("failure_requires_approach_receipt", SAOBridge.INSTANCE.findWaterSource(body, 8, 2.83).equals("14:20:0")
            && !SAOBridge.INSTANCE.failWaterApproach(body, "done:Failed", 2.83, 13, 20, 0));
        check("replacement_test_failure_recorded", fail(body, 2.84, "done:Failed"));
        first.getSquare().getObjects().remove(first);
        IsoObject replacement = sink(cell, 14, 20);
        check("replacement_fixture_is_independent", "14:20:0".equals(SAOBridge.INSTANCE.findWaterSource(body, 8, 2.85))
            && SAONeeds.waterSource(body) == replacement);
        check("replacement_attempt_recorded", fail(body, 2.85, "done:Failed"));
        SAONeeds.resetRuntimeForWorld();
        check("world_reset_discards_attempt_handles", failures().isEmpty()
            && "14:20:0".equals(SAOBridge.INSTANCE.findWaterSource(body, 8, 2.86)));
        // More failures than the capacity must neither retain every source nor
        // grow per actor without bound. Every row enters through a real query.
        for (int x = 14; x <= 30; x += 2) for (int y = 8; y <= 16; y += 2) sink(cell, x, y);
        boolean admitted = true;
        for (int i = 0; i < 22; i++) {
            admitted &= !SAOBridge.INSTANCE.findWaterSource(body, 30, 3).isEmpty();
            admitted &= fail(body, 3, "done:Failed");
        }
        check("capacity_uses_actual_queries_and_failures", admitted);
        check("failure_receipts_are_bounded", failures().get(body).size() == 16);
        check("body_owner_is_weak", failures() instanceof java.util.WeakHashMap);
        boolean weak = true;
        for (Object row : failures().get(body)) {
            var field = row.getClass().getDeclaredField("source"); field.setAccessible(true);
            weak &= field.get(row) instanceof java.lang.ref.WeakReference;
        }
        check("source_handles_are_weak", weak);
        SAONeeds.resetRuntimeForWorld();
        var platform = new se.krka.kahlua.j2se.J2SEPlatform();
        var env = platform.newEnvironment();
        var thread = new se.krka.kahlua.vm.KahluaThread(platform, env);
        thread.debugOwnerThread = Thread.currentThread();
        var expose = LuaRun.class.getDeclaredMethod("exposeEngine", se.krka.kahlua.vm.KahluaTable.class,
            se.krka.kahlua.j2se.J2SEPlatform.class, se.krka.kahlua.vm.KahluaThread.class);
        expose.setAccessible(true);
        check("actual_bridge_exposed", Boolean.TRUE.equals(expose.invoke(null, env, platform, thread)));
        env.rawset("subject", body);
        var query = se.krka.kahlua.luaj.compiler.LuaCompiler.loadstring(
            "return SAOJavaBridge:findWaterSource(subject, 8, 100.5)", "water-bridge", env);
        check("kahlua_three_argument_query_uses_native_overload", "14:20:0".equals(thread.call(query, null, null, null)));
        var failure = se.krka.kahlua.luaj.compiler.LuaCompiler.loadstring(
            "local target=SAOJavaBridge:resourceApproach(subject,'water',14,20,0); "
            + "local x,y,z=string.match(target,'^AT:(%d+):(%d+):(%d+)$'); "
            + "return SAOJavaBridge:failWaterApproach(subject,'done:Failed',100.5,tonumber(x),tonumber(y),tonumber(z))",
            "water-failure-bridge", env);
        check("kahlua_failure_receipt_reaches_native_owner", Boolean.TRUE.equals(thread.call(failure, null, null, null)));
        query = se.krka.kahlua.luaj.compiler.LuaCompiler.loadstring(
            "return SAOJavaBridge:findWaterSource(subject, 8, 100.51)", "water-requery-bridge", env);
        check("kahlua_query_applies_actual_failed_candidate", !"14:20:0".equals(thread.call(query, null, null, null)));
        query = se.krka.kahlua.luaj.compiler.LuaCompiler.loadstring(
            "return SAOJavaBridge:findWaterSource(subject, 8)", "water-legacy-bridge", env);
        check("kahlua_legacy_overload_remains_usable", "14:20:0".equals(thread.call(query, null, null, null)));
        System.out.println("PASS water approach checks=" + checks);
    }
}
